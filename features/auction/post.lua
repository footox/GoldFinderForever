-- features/auction/post.lua: the "Subastar" button of the Bolsas list. One click makes one call to the auction API;
-- nothing is posted without a click. Container: data comes from d, the plan from GF.AuctionPlan.

local _, GF = ...

-- d: Cfg, AHApi, TSMValue, RefPrice, SellQty, VendorPrice, Money, Print, BankerName
function GF.InitAuction(d)
  local UI = GF.UI
  local Skin = UI.Skin
  local CALLER, AH_CUT = GF.CALLER, GF.AH_CUT
  local Cfg, AHApi, TSMValue, RefPrice, SellQty, VendorPrice, Money, Print, BankerName =
    d.Cfg, d.AHApi, d.TSMValue, d.RefPrice, d.SellQty, d.VendorPrice, d.Money, d.Print, d.BankerName
  local format, floor = string.format, math.floor

  local DURATION = { [12] = 1, [24] = 2, [48] = 3 }   -- horas -> valor de duracion de la API (igual que Auctionator)
  local function Hours() return (tonumber(Cfg("postDuration")) or 24) <= 12 and 12 or 24 end
  local function AHOpen() return AuctionHouseFrame and AuctionHouseFrame:IsShown() and C_AuctionHouse and true or false end
  local function Pos(v) return (type(v) == "number" and v > 0) and v or nil end
  -- estado de la ultima publicacion: on = varias unidades en curso (como multisellInProgress de Auctionator),
  -- serial = para el tiempo maximo de espera, post = publicacion pendiente de "Publicado":
  -- { what (objeto, precio y duracion), per (unidades por subasta creada), n (subastas creadas), armed, tick }
  local busy = { on = false, serial = 0, post = nil }

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

  -- plan con los datos del momento: Auctionator (la mas barata), TSM (mercado y ventas al dia), reservas de SellQty
  local function Plan(id, loc)
    local v1 = AHApi()
    local okL, lowest = false, nil
    if v1 then okL, lowest = pcall(v1.GetAuctionPriceByItemID, CALLER, id) end
    lowest = okL and Pos(lowest) or nil
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
    -- publicacion de varias unidades en curso (la subasta las crea de una en una): no se publica otra hasta acabar
    if p.post and busy.on then p.post, p.reason = false, "publicacion en curso: espera a que termine" end
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
    tt:AddLine("Subastar con un clic", 1, 0.82, 0)
    if not AHOpen() then tt:AddLine("Abre la casa de subastas para publicarlo.", 1, 0.3, 0.3, true) end
    if p.post then
      tt:AddDoubleLine("Precio c/u", Money(p.unit), 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine("Cantidad", tostring(p.qty), 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine("Total", Money(p.unit * p.qty), 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine("Recibes (tras la comision)", Money(floor(p.unit * p.qty * (1 - AH_CUT))), 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine("Deposito", p.deposit and Money(p.deposit) or "(con la subasta abierta)", 1, 1, 1, 1, 1, 1)
      tt:AddDoubleLine("Duracion", p.hours .. " h", 1, 1, 1, 1, 1, 1)
    end
    tt:AddLine((p.post and "" or "No se publica: ") .. p.reason, p.post and 0.42 or 1, p.post and 0.71 or 0.3,
      p.post and 1 or 0.3, true)
    if p.min then
      tt:AddLine(format("Minimo %s / normal %s / maximo %s", Money(p.min), Money(p.normal), Money(p.max)),
        0.6, 0.6, 0.6, true)
    end
    if toBanker then
      tt:AddLine("Tu banquero es " .. BankerName() .. ": puedes enviarselo, o publicarlo aqui mismo.", 0.42, 0.71, 1, true)
    end
    tt:AddLine("Mayus+clic (o Mayus+clic en la fila): abrirlo en la pestana Selling de Auctionator.", 0.6, 0.6, 0.6, true)
  end

  local function RefreshShown()
    for _, u in ipairs(UI.instances) do if u:IsVisible() then pcall(u.refresh) end end
  end

  -- "Publicado" una sola vez, con las unidades que la subasta creo de verdad; despues se olvida la publicacion
  local function PostDone()
    local q = busy.post
    busy.post = nil
    if q and q.n > 0 then Print(format("Publicado: %d x %s", q.n * q.per, q.what)) end
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

  -- una publicacion por clic; si la subasta esta ocupada (limite de mensajes) no se hace nada
  local function Post(id)
    if not AHOpen() then Print("Abre la casa de subastas primero."); return end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
      Print("La casa de subastas esta ocupada: espera un momento y vuelve a pulsar Subastar.")
      return
    end
    local loc = FindLoc(id)
    if not loc then Print("No puedo publicar ese objeto (ligado, bloqueado o ya no esta en la bolsa)."); return end
    local p = Plan(id, loc)
    if not p.post then Print("No se publica: " .. p.reason); return end
    local dur = DURATION[p.hours]
    local commodity = IsCommodity(loc)
    local fn = commodity and C_AuctionHouse.PostCommodity or C_AuctionHouse.PostItem
    if type(fn) ~= "function" then Print("Este cliente no permite publicar desde GoldFinder."); return end
    -- varias unidades de un objeto que no es mercancia: la subasta las crea de una en una (multisell);
    -- los botones Subastar quedan desactivados hasta que acaba, falla o pasa el tiempo maximo
    busy.on, busy.serial = not commodity and p.qty > 1, busy.serial + 1
    local serial = busy.serial
    -- tiempo maximo: si la subasta no avisa (o no confirmas), se olvida esta publicacion
    C_Timer.After(math.max(30, p.qty * 2), function()
      if busy.serial == serial and (busy.on or busy.post) then busy.on = false; PostDone(); RefreshShown() end
    end)
    local name = C_Item.GetItemInfo(id) or ("objeto " .. id)
    local q = { what = format("%s a %s c/u (%d h)", name, Money(p.unit), p.hours),
      per = commodity and p.qty or 1, n = 0, tick = 0 }
    busy.post = q
    local ok, res
    if commodity then ok, res = pcall(fn, loc, dur, p.qty, p.unit)
    else ok, res = pcall(fn, loc, dur, p.qty, nil, p.unit) end
    if not ok then
      busy.on, busy.post = false, nil
      Print("La casa de subastas rechazo la publicacion: " .. tostring(res))
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
      Print("Confirma la publicacion en la ventana de Blizzard")
    else
      PostArm(q)
    end
    RefreshShown()
  end

  -- avisos de la subasta: publicado (cuando la subasta la crea), error al publicar, progreso de varias unidades
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_POST_ERROR", "AUCTION_MULTISELL_UPDATE",
    "AUCTION_MULTISELL_FAILURE" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, e, a1, a2)
    local q = busy.post
    if e == "AUCTION_HOUSE_POST_ERROR" then
      busy.on = false
      PostDone()
      Print("La casa de subastas no acepto la publicacion.")
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

  Skin.Auction = {
    Plan = function(id) return Plan(id, FindLoc(id)) end,
    Tooltip = Tooltip,
    Post = Post,
    AuctionPlan = GF.AuctionPlan,
  }
end
