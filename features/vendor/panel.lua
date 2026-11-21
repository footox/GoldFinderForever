-- features/vendor/panel.lua: the merchant windows. The sell panel lists what the decision sends to the vendor, each
-- with Sell and Keep buttons (nothing is sold without a click); the recipe box lists merchant recipes that one
-- of your characters can still learn. This file is the container: data and actions come from d, drawing from GF.UI.

local _, GF = ...

-- d: Cfg, BagRows, SellQty, Char, ShortMoney, Money, Print, RecipeForOthers, RecordVendorPrices, InvalidateRoutes
function GF.InitVendor(d)
  local UI = GF.UI
  local Flat, Text, Btn, NewFrame, PAL, Skin = UI.Flat, UI.Text, UI.Btn, UI.NewFrame, UI.PAL, UI.Skin
  local Cfg, BagRows, SellQty, Char, ShortMoney, Money, Print = d.Cfg, d.BagRows, d.SellQty, d.Char, d.ShortMoney, d.Money, d.Print
  local RecipeForOthers, RecordVendorPrices, InvalidateRoutes = d.RecipeForOthers, d.RecordVendorPrices, d.InvalidateRoutes
  local format = string.format

  local SELL_LINES = 12

  local function RefreshSellPanel()
    local f = GoldFinderSellPanel
    local open = MerchantFrame and MerchantFrame:IsShown()
    if not Cfg("sellPanel") or not open then
      if f then f:Hide() end
      return
    end
    local CC = C_Container
    if not (CC and CC.GetContainerNumSlots and CC.GetContainerItemInfo and CC.UseContainerItem) then return end
    if not f then
      f = NewFrame("Frame", "GoldFinderSellPanel", MerchantFrame, "BackdropTemplate")
        or CreateFrame("Frame", "GoldFinderSellPanel", MerchantFrame)
      f:SetWidth(360)
      f:SetFrameStrata("HIGH")
      local okB = f.SetBackdrop and pcall(f.SetBackdrop, f, {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
      })
      if not okB then local bg = Flat(f, "BACKGROUND", PAL.bg); bg:SetAllPoints() end
      f:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 2, -12)
      f.title = Text(f, 13, PAL.gold, "CENTER")
      f.title:SetPoint("TOP", f, "TOP", 0, -16)
      f.title:SetText("GoldFinder Forever")
      f.sub = Text(f, 12, PAL.text)
      f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -36)
      f.sub:SetText("Para vender")
      f.empty = Text(f, 12, PAL.dim)
      f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -60)
      f.empty:SetText("Nada que venderle a este vendedor")
      -- lista con barra de desplazamiento (y rueda del raton): muestra SELL_LINES filas y el resto se desplaza
      f.scroll = NewFrame("ScrollFrame", "GoldFinderSellPanelScroll", f, "UIPanelScrollFrameTemplate")
        or CreateFrame("ScrollFrame", "GoldFinderSellPanelScroll", f)
      f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -54)
      f.scroll:SetPoint("RIGHT", f, "RIGHT", -34, 0)
      f.content = CreateFrame("Frame", nil, f.scroll)
      f.content:SetSize(310, 1)
      f.scroll:SetScrollChild(f.content)
      f.total = Text(f, 12, PAL.gold)
      f.total:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 16)
      f.rows = {}
      -- vende al vendedor las pilas de ese objeto (pilas enteras, sin pasar de las unidades que no estan reservadas)
      f.sell = function(id, qty)
        if not (MerchantFrame and MerchantFrame:IsShown()) then return end
        local sold, left = 0, 0
        for _, s in ipairs(GF.BagSlots()) do
          if s.id == id and not s.locked and not s.noValue then
            if sold + s.count <= qty then
              CC.UseContainerItem(s.bag, s.slot)
              sold = sold + s.count
            else
              left = left + s.count
            end
          end
        end
        if sold < qty and left > 0 then
          Print(format("Vendidas %d unidades; quedan pilas que superan lo que conviene vender (lo demas esta reservado).", sold))
        end
        C_Timer.After(0.5, function() pcall(RefreshSellPanel) end)
      end
    end
    for _, row in ipairs(f.rows) do row:Hide() end

    local rows = BagRows()
    for _, r in ipairs(rows) do
      local classID = select(6, C_Item.GetItemInfoInstant(r.id))
      if classID == 12 then r.quest = true end   -- objetos de mision
    end
    local list, total = GF.VendorSellRows(rows, SellQty)
    for i = 1, #list do
      local e = list[i]
      local row = f.rows[i]
      if not row then
        row = CreateFrame("Frame", nil, f.content)
        row:SetSize(306, 24)
        row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 4, -(i - 1) * 26)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.btn = Btn(row, "Vender", 56, 20)
        row.btn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        -- Guardar: no volver a recomendar venderlo (lo fija, igual que en la pestana Bolsas; ahi se suelta)
        row.keep = Btn(row, "Guardar", 60, 20)
        row.keep:SetPoint("RIGHT", row.btn, "LEFT", -4, 0)
        row.keep:SetScript("OnClick", function()
          if not row.id then return end
          Char().keep[row.id] = true
          for _, u in ipairs(UI.instances) do pcall(u.refresh) end
          pcall(RefreshSellPanel)
        end)
        row.money = Text(row, 11, PAL.text, "RIGHT")
        row.money:SetPoint("RIGHT", row.keep, "LEFT", -6, 0)
        row.money:SetWidth(64)
        row.name = Text(row, 11, PAL.text)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.money, "LEFT", -4, 0)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
          if not self.id then return end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetItemByID(self.id)
          GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.btn:SetScript("OnClick", function() if row.id then f.sell(row.id, row.qty) end end)
        f.rows[i] = row
      end
      row.id, row.qty = e.id, e.qty
      row.icon:SetTexture(C_Item.GetItemIconByID(e.id))
      local name = C_Item.GetItemNameByID(e.id) or ("objeto " .. e.id)
      row.name:SetText(format("%s |cffffffffx%d|r", name, e.qty))
      row.money:SetText(ShortMoney(e.value))
      row:Show()
    end
    local visible = math.min(#list, SELL_LINES)
    f.content:SetHeight(math.max(1, #list * 26))
    f.scroll:SetHeight(math.max(1, visible * 26))
    f.scroll:SetShown(#list > 0)
    local y = -56 - visible * 26
    if #list == 0 then f.empty:Show(); y = y - 22 else f.empty:Hide() end
    f.total:SetText("Total: " .. Money(total))
    f.total:SetShown(#list > 0)
    f:SetHeight(-y + 40)
    f:Show()
  end

  ---------------------------------------------------------------------------
  -- VENDEDOR: al abrirlo, un cuadrito lista las recetas que ese vendedor tiene y que alguno de tus
  -- personajes (tu o los demas, si esta activado el aviso de otros personajes) aun no sabe.
  ---------------------------------------------------------------------------
  local function RefreshVendor()
    local f = GoldFinderVendor
    if not Cfg("vendorBox") or not Cfg("crossChars") or not (MerchantFrame and MerchantFrame:IsShown() and GetMerchantNumItems) then
      if f then f:Hide() end
      return
    end
    local lines, n = {}, 0
    for i = 1, (GetMerchantNumItems() or 0) do
      local link = GetMerchantItemLink(i)
      local id = link and tonumber(link:match("item:(%d+)"))
      local list = id and RecipeForOthers(id, true, true) or nil
      if list and #list > 0 then
        local price = select(3, GF.MerchantItemInfo(i))
        n = n + 1
        lines[#lines + 1] = format("%s  |cffb3b3b3%s|r", link, price and price > 0 and ShortMoney(price) or "")
        for _, ro in ipairs(list) do
          local col = ro.ready and "|cff59eb8d" or "|cffffa640"
          if ro.unknown then
            lines[#lines + 1] = "   |cffffd100" .. ro.note .. "|r"
          else
            lines[#lines + 1] = format("   |cff6bb5ff%s|r (%s %d%s): %s%s|r", ro.who, ro.prof, ro.rank,
              ro.req and (", pide " .. ro.req) or "", col, ro.ready and "puede aprenderla" or "aun le falta habilidad")
          end
        end
      end
    end
    if n == 0 then
      if f then f:Hide() end
      return
    end
    if not f then
      -- dialogo clasico (como el panel de venta): titulo "GoldFinder Forever" y debajo el subtitulo
      f = Skin.Panel("GoldFinderVendor", MerchantFrame, "dialog")
      f:SetWidth(360)
      f:SetFrameStrata("HIGH")
      f.head = Skin.Head(f, "GoldFinder Forever")
      f.title = Text(f, 12, PAL.text)
      f.title:SetPoint("TOPLEFT", 18, -36)
      f.title:SetText("Recetas que te sirven aqui")
      f.body = Text(f, 12, PAL.text)
      f.body:SetPoint("TOPLEFT", 18, -56)
      f.body:SetWidth(324)
      f.body:SetSpacing(3)
      f.body:SetJustifyV("TOP")
    end
    -- debajo del panel de venta si esta abierto; si no, junto a la ventana del vendedor
    f:ClearAllPoints()
    local sp = GoldFinderSellPanel
    if sp and sp:IsShown() then f:SetPoint("TOPLEFT", sp, "BOTTOMLEFT", 0, -4)
    else f:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 2, -12) end
    f.body:SetText(table.concat(lines, "\n"))
    f:SetHeight(56 + (f.body:GetStringHeight() or 0) + 18)
    f:Show()
  end

  local vendorEvents = CreateFrame("Frame")
  for _, ev in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED" }) do
    pcall(vendorEvents.RegisterEvent, vendorEvents, ev)
  end
  local function RefreshMerchantPanels()
    pcall(RefreshSellPanel)
    pcall(RefreshVendor)
  end
  vendorEvents:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_CLOSED" then
      if GoldFinderSellPanel then GoldFinderSellPanel:Hide() end
      if GoldFinderVendor then GoldFinderVendor:Hide() end
      return
    end
    if event == "BAG_UPDATE_DELAYED" then
      if MerchantFrame and MerchantFrame:IsShown() then RefreshMerchantPanels() end
      return
    end
    pcall(RecordVendorPrices)
    InvalidateRoutes()
    -- los nombres de las recetas y de los objetos pueden tardar en cargar: se mira dos veces
    C_Timer.After(0.3, RefreshMerchantPanels)
    if event == "MERCHANT_SHOW" then C_Timer.After(1.5, RefreshMerchantPanels) end
  end)

  return { RefreshSellPanel = RefreshSellPanel, RefreshVendor = RefreshVendor, Refresh = RefreshMerchantPanels }
end
