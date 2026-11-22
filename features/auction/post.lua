-- features/auction/post.lua: the "Subastar" button of the Bolsas list. One click makes one call to the auction API;
-- nothing is posted without a click. Container: data comes from d, the plan from GF.AuctionPlan.

local _, GF = ...

-- d: Cfg, AHApi, TSMValue, RefPrice, SellQty, VendorPrice, Money, Print, BankerName, ScanAgeMin
function GF.InitAuction(d)
  local UI = GF.UI
  local Skin = UI.Skin
  local CALLER, AH_CUT = GF.CALLER, GF.AH_CUT
  local Cfg, AHApi, TSMValue, RefPrice, SellQty, VendorPrice, Money, Print, BankerName, ScanAgeMin =
    d.Cfg, d.AHApi, d.TSMValue, d.RefPrice, d.SellQty, d.VendorPrice, d.Money, d.Print, d.BankerName, d.ScanAgeMin
  local format, floor = string.format, math.floor
  local L = GF.L

  local DURATION = { [12] = 1, [24] = 2, [48] = 3 }   -- horas -> valor de duracion de la API (igual que Auctionator)
  local function Hours() return (tonumber(Cfg("postDuration")) or 24) <= 12 and 12 or 24 end
  local function AHOpen() return AuctionHouseFrame and AuctionHouseFrame:IsShown() and C_AuctionHouse and true or false end
  local function Pos(v) return (type(v) == "number" and v > 0) and v or nil end
  -- estado de la ultima publicacion: on = varias unidades en curso (como multisellInProgress de Auctionator),
  -- serial = para el tiempo maximo de espera, post = publicacion pendiente de "Publicado":
  -- { what (objeto, precio y duracion), per (unidades por subasta creada), n (subastas creadas), armed, tick }
  local busy = { on = false, serial = 0, post = nil }
  local StartCheck

  -- primer hueco de las bolsas con ese objeto que la subasta acepta (solo con la subasta abierta)
  local function FindLoc(id)
    if not (AHOpen() and GF.BagApiReady() and ItemLocation and C_AuctionHouse.IsSellItemValid) then return nil end
    for _, s in ipairs(GF.BagSlots()) do
      if s.id == id and not s.locked then
        local loc = ItemLocation:CreateFromBagAndSlot(s.bag, s.slot)
        local ok, valid = pcall(C_AuctionHouse.IsSellItemValid, loc, false)
        if ok and valid and loc:IsValid() then return loc end
      end
    end
    return nil
  end

  local function IsCommodity(loc)
    if not (C_AuctionHouse.GetItemCommodityStatus and Enum and Enum.ItemCommodityStatus) then return false end
    local ok, st = pcall(C_AuctionHouse.GetItemCommodityStatus, loc)
    return ok and st == Enum.ItemCommodityStatus.Commodity
  end

  -- PRECIO EN VIVO: si el ultimo escaneo es viejo, el primer clic en Subastar consulta la casa de subastas por ese
  -- objeto (un clic = una consulta, nunca una publicacion); al llegar el resultado el plan se recalcula con el precio
  -- real y el siguiente clic publica. Publicar exige un clic directo, por eso son dos clics. Guardado 2 minutos.
  local LIVE_TTL, CHECK_WAIT = 120, 8
  local live = {}      -- [id] = { price, at }
  local check          -- consulta en curso: { id, commodity, key, at }
  local function LiveFresh(id)
    local e = live[id]
    return e and (GetTime() - e.at) < LIVE_TTL and e or nil
  end
  local function LiveLowest(id)
    local e = LiveFresh(id)
    return e and e.price or nil   -- a failed check has no price: the saved one stays
  end
  local function NeedsCheck(id)
    if LiveFresh(id) then return false end   -- checked already (with or without a result): never loop
    return GF.AuctionNeedsLive(ScanAgeMin and ScanAgeMin() or nil, Cfg("postRefreshMin"))
  end

  -- plan con los datos del momento: Auctionator (la mas barata), TSM (mercado y ventas al dia), reservas de SellQty
  local function Plan(id, loc)
    local v1 = AHApi()
    local okL, lowest = false, nil
    if v1 then okL, lowest = pcall(v1.GetAuctionPriceByItemID, CALLER, id) end
    lowest = okL and Pos(lowest) or nil
    local stored = lowest
    local liveP = LiveLowest(id)
    if liveP then lowest = liveP end
    local market = Pos(TSMValue("DBMarket", id)) or Pos(TSMValue("DBRegionMarketAvg", id)) or Pos(RefPrice(id))
    -- TSM redondea los valores a entero: las ventas al dia se piden x1000 (como hace su tooltip)
    local spd = Pos(TSMValue("DBRegionSoldPerDay * 1000", id))
    local available = SellQty(id)
    if loc and C_AuctionHouse.GetAvailablePostCount then
      local ok, n = pcall(C_AuctionHouse.GetAvailablePostCount, loc)
      if ok and type(n) == "number" then available = math.min(available, n) end
    end
    -- armas y armaduras: Auctionator las guarda por variante (nivel de objeto, sufijo), no por id
    local classID = select(6, C_Item.GetItemInfoInstant(id))
    local p = GF.AuctionPlan({
      variant = (classID == 2 or classID == 4) and not (loc and IsCommodity(loc)),
      lowest = lowest, market = market, vendor = VendorPrice(id) or 0, available = available,
      soldPerDay = spd and spd / 1000, cut = AH_CUT, money = Money,
      minPct = tonumber(Cfg("postMinPct")), maxPct = tonumber(Cfg("postMaxPct")),
      undercut = tonumber(Cfg("postUndercut")), capDays = tonumber(Cfg("postCapDays")),
    })
    p.hours, p.lowest, p.market = Hours(), lowest, market
    p.live, p.stored = liveP ~= nil, stored
    -- publicacion de varias unidades en curso (la subasta las crea de una en una): no se publica otra hasta acabar
    if p.post and busy.on then p.post, p.code, p.reason = false, "busy", L["auction.reason.busy"] end
    if loc and p.qty > 0 then
      local ok, dep
      if IsCommodity(loc) then
        if C_AuctionHouse.CalculateCommodityDeposit then
          ok, dep = pcall(C_AuctionHouse.CalculateCommodityDeposit, id, DURATION[p.hours], p.qty)
        end
      elseif C_AuctionHouse.CalculateItemDeposit then
        ok, dep = pcall(C_AuctionHouse.CalculateItemDeposit, loc, DURATION[p.hours], p.qty)
      end
      if ok and type(dep) == "number" then p.deposit = dep end
    end
    return p
  end

  local function Tooltip(tt, id, toBanker)
    local p = Plan(id, FindLoc(id))
    tt:AddLine(L["auction.tip.title"], 1, 0.82, 0)
    if not AHOpen() then tt:AddLine(L["auction.tip.open"], 1, 0.3, 0.3, true) end
    if p.post then
      tt:AddDoubleLine(L["auction.tip.unit"], Money(p.unit), 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine(L["auction.tip.qty"], tostring(p.qty), 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine(L["auction.tip.total"], Money(p.unit * p.qty), 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine(L["auction.tip.receive"], Money(floor(p.unit * p.qty * (1 - AH_CUT))), 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine(L["auction.tip.deposit"], p.deposit and Money(p.deposit) or L["auction.tip.depositOpen"], 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine(L["auction.tip.duration"], p.hours .. " h", 1, 1, 1, 1, 1, 1)
    end
    tt:AddLine((p.post and "" or L["auction.tip.notPosted"]) .. p.reason, p.post and 0.42 or 1, p.post and 0.71 or 0.3,
      p.post and 1 or 0.3, true)
    if p.live then
      local dr = GF.AuctionDrift(p.stored, p.lowest)
      tt:AddLine(dr and format(L["auction.tip.live"], string.format("%+.0f%%", dr)) or L["auction.tip.liveNoRef"], 0.35, 0.9, 0.55, true)
    elseif p.post and NeedsCheck(id) then
      tt:AddLine(L["auction.tip.willCheck"], 1, 0.82, 0.3, true)
    end
    if p.min then
      tt:AddLine(format(L["auction.tip.range"], Money(p.min), Money(p.normal), Money(p.max)),
        0.6, 0.6, 0.6, true)
    end
    if toBanker then
      tt:AddLine(format(L["auction.tip.banker"], BankerName()), 0.42, 0.71, 1, true)
    end
    tt:AddLine(L["auction.tip.shift"], 0.6, 0.6, 0.6, true)
  end

  local function RefreshShown()
    for _, u in ipairs(UI.instances) do if u:IsVisible() then pcall(u.refresh) end end
  end

  -- "Publicado" una sola vez, con las unidades que la subasta creo de verdad; despues se olvida la publicacion
  local function PostDone()
    local q = busy.post
    busy.post = nil
    if q and q.n > 0 then Print(format(L["auction.posted"], q.n * q.per, q.what)) end
  end
  -- ventana corta: solo cuenta AUCTION_HOUSE_AUCTION_CREATED que llegue en 5 s desde la publicacion o la
  -- confirmacion (cada subasta creada la alarga); si no llega, se olvida y otra subasta posterior no la imprime
  local function PostArm(q)
    q.armed, q.tick = true, q.tick + 1
    local t = q.tick
    C_Timer.After(5, function()
      if busy.post == q and q.tick == t then busy.on = false; PostDone(); RefreshShown() end
    end)
  end

  -- lanza la consulta en vivo; true si la dejo en marcha (el clic termina ahi), false si no se pudo y se sigue con
  -- el precio guardado como siempre
  function StartCheck(id, loc)
    local CA = C_AuctionHouse
    if not (CA and CA.SendSearchQuery and (CA.GetItemKeyFromItem or CA.MakeItemKey)) then return false end
    if check and (GetTime() - check.at) < CHECK_WAIT then Print(L["auction.checking"]); return true end
    local okK, key = pcall(function()
      if CA.GetItemKeyFromItem then return CA.GetItemKeyFromItem(loc) end
      return CA.MakeItemKey(id)
    end)
    if not (okK and key) then return false end
    local commodity = IsCommodity(loc)
    local sorts = {}
    if Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price then
      sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
    end
    local ok = pcall(CA.SendSearchQuery, key, sorts, true)
    if not ok then return false end
    check = { id = id, commodity = commodity, key = key, at = GetTime() }
    Print(L["auction.checking"])
    RefreshShown()
    local mine = check
    C_Timer.After(CHECK_WAIT, function()
      if check == mine then
        check = nil
        live[id] = { price = nil, at = GetTime() }   -- no answer: the next click uses the saved price instead of asking again
        Print(L["auction.checkTimeout"])
        RefreshShown()
      end
    end)
    return true
  end

  local function ReadRows(c)
    local CA, rows = C_AuctionHouse, {}
    if c.commodity then
      local n = (CA.GetNumCommoditySearchResults and CA.GetNumCommoditySearchResults(c.id)) or 0
      for i = 1, math.min(n, 30) do
        local info = CA.GetCommoditySearchResultInfo and CA.GetCommoditySearchResultInfo(c.id, i)
        if info then rows[#rows + 1] = { price = info.unitPrice, mine = info.containsOwnerItem } end
      end
    else
      local n = (CA.GetNumItemSearchResults and CA.GetNumItemSearchResults(c.key)) or 0
      for i = 1, math.min(n, 30) do
        local info = CA.GetItemSearchResultInfo and CA.GetItemSearchResultInfo(c.key, i)
        if info then rows[#rows + 1] = { price = info.buyoutAmount, mine = info.containsOwnerItem } end
      end
    end
    return rows
  end

  local function CheckDone(eventItemId)
    local c = check
    if not c or (eventItemId and eventItemId ~= c.id) then return end
    local ok, rows = pcall(ReadRows, c)
    local price = ok and GF.AuctionPickLowest(rows) or nil
    check = nil
    local stored
    local v1 = AHApi()
    if v1 then local okS, st = pcall(v1.GetAuctionPriceByItemID, CALLER, c.id); stored = okS and Pos(st) or nil end
    if price then
      live[c.id] = { price = price, at = GetTime() }
      local dr = GF.AuctionDrift(stored, price)
      local name = C_Item.GetItemInfo(c.id) or format(L["auction.item"], c.id)
      Print(dr and format(L["auction.checked"], name, Money(price), string.format("%+.0f%%", dr))
        or format(L["auction.checkedNoRef"], name, Money(price)))
    else
      live[c.id] = { price = nil, at = GetTime() }   -- no listing or unreadable: the next click uses the saved price
      Print(L["auction.checkFailed"])
    end
    RefreshShown()
  end

  -- una publicacion por clic; si la subasta esta ocupada (limite de mensajes) no se hace nada
  local function Post(id)  -- (StartCheck es local de este ambito: ver arriba)
    if not AHOpen() then Print(L["auction.openFirst"]); return end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
      Print(L["auction.busyAH"])
      return
    end
    local loc = FindLoc(id)
    if not loc then Print(L["auction.cantPost"]); return end
    if NeedsCheck(id) and StartCheck(id, loc) then return end
    local p = Plan(id, loc)
    if not p.post then Print(format(L["auction.notPosted"], p.reason)); return end
    local dur = DURATION[p.hours]
    local commodity = IsCommodity(loc)
    local fn = commodity and C_AuctionHouse.PostCommodity or C_AuctionHouse.PostItem
    if type(fn) ~= "function" then Print(L["auction.unsupported"]); return end
    -- varias unidades de un objeto que no es mercancia: la subasta las crea de una en una (multisell);
    -- los botones Subastar quedan desactivados hasta que acaba, falla o pasa el tiempo maximo
    busy.on, busy.serial = not commodity and p.qty > 1, busy.serial + 1
    local serial = busy.serial
    -- tiempo maximo: si la subasta no avisa (o no confirmas), se olvida esta publicacion
    C_Timer.After(math.max(30, p.qty * 2), function()
      if busy.serial == serial and (busy.on or busy.post) then busy.on = false; PostDone(); RefreshShown() end
    end)
    local name = C_Item.GetItemInfo(id) or format(L["auction.item"], id)
    local q = { what = format(L["auction.what"], name, Money(p.unit), p.hours), id = id,
      per = commodity and p.qty or 1, n = 0, tick = 0 }
    busy.post = q
    local ok, res
    if commodity then ok, res = pcall(fn, loc, dur, p.qty, p.unit)
    else ok, res = pcall(fn, loc, dur, p.qty, nil, p.unit) end
    if not ok then
      busy.on, busy.post = false, nil
      Print(format(L["auction.rejected"], tostring(res)))
      RefreshShown()
      return
    end
    -- si el cliente pide confirmar (dialogo de Blizzard), el marco de venta necesita la publicacion pendiente;
    -- "Publicado" se imprime solo cuando la subasta avisa de que la creo (AUCTION_HOUSE_AUCTION_CREATED)
    if res then
      pcall(function()
        local sf = commodity and AuctionHouseFrame.CommoditiesSellFrame or AuctionHouseFrame.ItemSellFrame
        if commodity then sf:CachePendingPost(loc, dur, p.qty, p.unit)
        else sf:CachePendingPost(loc, dur, p.qty, nil, p.unit) end
      end)
      Print(L["auction.confirm"])
    else
      PostArm(q)
    end
    RefreshShown()
  end

  -- avisos de la subasta: publicado (cuando la subasta la crea), error al publicar, progreso de varias unidades
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_POST_ERROR", "AUCTION_MULTISELL_UPDATE",
    "AUCTION_MULTISELL_FAILURE", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, e, a1, a2)
    local q = busy.post
    if e == "COMMODITY_SEARCH_RESULTS_UPDATED" then
      if check and check.commodity then CheckDone(a1) end
      return
    elseif e == "ITEM_SEARCH_RESULTS_UPDATED" then
      if check and not check.commodity and type(a1) == "table" and a1.itemID == check.id then CheckDone(check.id) end
      return
    elseif e == "AUCTION_HOUSE_POST_ERROR" then
      busy.on = false
      PostDone()
      Print(L["auction.postError"])
    elseif e == "AUCTION_HOUSE_AUCTION_CREATED" then
      -- antes de confirmar (o fuera de la ventana) la subasta creada no es la nuestra
      if q and q.armed then
        q.n = q.n + 1
        if busy.on then PostArm(q) else PostDone() end
      end
    elseif e == "AUCTION_MULTISELL_UPDATE" then
      if q and q.armed and a1 then q.n = math.max(q.n, a1); PostArm(q) end
      if a1 and a2 and a1 >= a2 then busy.on = false; PostDone() end
    elseif e == "AUCTION_MULTISELL_FAILURE" then
      busy.on = false
      PostDone()
    end
    RefreshShown()
  end)
  -- dialogo de confirmacion de Blizzard: aceptar abre la ventana de 5 s; cancelar olvida la publicacion
  local function OnConfirm() local q = busy.post; if q and not q.armed then PostArm(q) end end
  local function OnCancel()
    local q = busy.post
    if q and not q.armed then busy.on, busy.post = false, nil; RefreshShown() end
  end
  for fname, fn in pairs({ ConfirmPostItem = OnConfirm, ConfirmPostCommodity = OnConfirm, CancelSell = OnCancel }) do
    if C_AuctionHouse and type(C_AuctionHouse[fname]) == "function" then
      pcall(hooksecurefunc, C_AuctionHouse, fname, fn)
    end
  end

  -- estado del boton de un objeto: "checking" (consulta en vivo en curso), "posting" (publicacion en curso) o nil
  local function State(id)
    if check and check.id == id then return "checking" end
    local q = busy.post
    if q and q.id == id then return "posting" end
    return nil
  end

  Skin.Auction = {
    State = State,
    Plan = function(id) return Plan(id, FindLoc(id)) end,
    Tooltip = Tooltip,
    Post = Post,
    AuctionPlan = GF.AuctionPlan,
  }
end
