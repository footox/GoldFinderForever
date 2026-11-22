-- features/route/helpers.lua: texts and calculations the guide, the shopping list, the learned-recipe notice and Fabricar
-- share: recipe learned, why there is no route, route comparison and the profit of one craft. They live in
-- Skin.Route. Container: data comes from d; GoldFinderForeverDB, GoldFinderRecipes, C_Item, CALLER and AH_CUT are read from
-- d at call time (the main file passes a table that falls back to the real globals).

local _, GF = ...

-- d: Skin, AHApi, BuyPrice, Cfg, Money, RecipeLookup, SellQty, SellValue, VendorPrice
function GF.InitRouteHelpers(d)
  local AHApi, BuyPrice, Cfg, Money, RecipeLookup, SellQty, SellValue, VendorPrice =
    d.AHApi,
    d.BuyPrice,
    d.Cfg,
    d.Money,
    d.RecipeLookup,
    d.SellQty,
    d.SellValue,
    d.VendorPrice
  local format = string.format
  local L = GF.L
  local RK = {}
  d.Skin.Route = RK

  -- Receta recien aprendida (NEW_RECIPE_LEARNED): se apunta solo en la profesion que la ensena (por la linea de
  -- habilidad de GoldFinderRecipes o por lo anotado del instructor) y, si la profesion ya tiene recetas guardadas,
  -- se anade a crafts con los datos de GoldFinderRecipes para que la ruta la siga usando sin abrir la ventana.
  -- Devuelve la profesion o nil.
  function RK.LearnRecipe(c, recipeID, name, faction)
    if not (c and c.prof and name) then return nil end
    local spells = d.GoldFinderRecipes and d.GoldFinderRecipes.spells
    local byId = spells and recipeID and spells[recipeID] or nil
    local TR = d.GoldFinderForeverDB.trainerRecipes and d.GoldFinderForeverDB.trainerRecipes[faction or "?"]
    local key = name:lower()
    local profs = {}
    for prof in pairs(c.prof) do profs[#profs + 1] = prof end
    table.sort(profs)
    for _, prof in ipairs(profs) do
      local pd = c.prof[prof]
      local x
      if pd.skillLine then
        if byId then x = (byId.s == pd.skillLine) and byId or nil
        else x = RecipeLookup(pd.skillLine, name) end
      end
      local rec = TR and TR[prof] and TR[prof][key]
      if x or rec then
        pd.learned = pd.learned or {}
        pd.learned[name] = true
        x = x or (rec and pd.skillLine and RecipeLookup(pd.skillLine, rec.n)) or nil
        if type(pd.crafts) == "table" and not pd.crafts[name] and x and x.r and x.o then
          local r = {}
          for i, m in ipairs(x.r) do r[i] = { m[1], m[2] } end
          pd.crafts[name] = { r = r, o = x.o, q = x.q or 1 }
        end
        return prof
      end
    end
    return nil
  end

  -- Profesion de fabricacion sin plan: por que (o nil si no hay nada que hacer).
  function RK.NoRouteReason(pd)
    if not pd.crafts then return L["route.noRoute.open"] end
    local top = pd.maxRank or 300
    if pd.rank and pd.rank >= top then
      if top >= 300 then return nil end
      return L["route.noRoute.train"]
    end
    return L["route.noRoute.visit"]
  end

  -- Ruta hasta el tope que no llega (faltan recetas): texto para las compras; nil si llega.
  function RK.CapReason(r)
    if not (r and r.truncated) then return nil end
    return format(L["route.cap"], r.to, r.cap)
  end

  -- Comparacion de tu ruta (coste del plan: BuyPrice + aprender recetas, y lo que recupera vendiendo) con las otras
  -- guias (mismo BuyPrice). Devuelve las lineas y la ruta cuyos materiales mostrar (nil: ninguna).
  -- Sin precio de algun material, o si tu ruta no llega al objetivo, no se declara ganadora.
  function RK.RouteVerdict(mine, others, cap)
    local out, head = {}, {}
    local all = { mine }
    for _, o in ipairs(others) do all[#all + 1] = o end
    local anyUnknown = false
    for _, o in ipairs(all) do
      head[#head + 1] = format("%s %s%s", o.name, Money(o.cost), o.unknown > 0 and format(L["route.unpriced"], o.unknown) or "")
      if o.unknown > 0 then anyUnknown = true end
    end
    out[#out + 1] = format(L["route.head"], cap, table.concat(head, "  |  "))
    local sell = mine.sell or 0
    local mineNet = mine.cost - sell
    if sell > 0 then
      out[#out + 1] = format(L["route.recovers"], Money(sell),
        mineNet < 0 and L["route.endGain"] or L["route.endCost"], Money(math.abs(mineNet)))
    end
    local cheapest = others[1]
    for i = 2, #others do
      if others[i].cost < cheapest.cost then cheapest = others[i] end
    end
    if mine.truncated then
      out[#out + 1] = format(L["route.truncated"], mine.to or 0, cap, cheapest.name)
      return out, cheapest
    end
    if anyUnknown then
      out[#out + 1] = L["route.scanFirst"]
      return out, nil
    end
    -- Tu ruta elige recetas que recuperan oro vendiendo lo fabricado; de las otras guias no se sabe que se vende,
    -- asi que solo se declara ganadora una ruta cuando lo es pase lo que pase: la tuya si compra menos, la otra si
    -- cuesta menos que lo que a ti te queda despues de vender. Si no, se muestran los numeros y decides tu.
    if mine.cost <= cheapest.cost then
      out[#out + 1] = format(L["route.bestOwn"], Money(cheapest.cost - mine.cost))
      return out, mine
    elseif cheapest.cost < mineNet then
      out[#out + 1] = format(L["route.bestOther"], cheapest.name, Money(mineNet - cheapest.cost))
    else
      out[#out + 1] = format(L["route.lessBuy"], cheapest.name, cheapest.name)
    end
    return out, cheapest
  end

  -- Fabricar una receta: ganancia por fabricacion con tus materiales (gain: lo que sacarias vendiendolos) y
  -- comprandolos (gainBuy: BuyPrice, lo mas barato de subasta y vendedor), cuantas puedes hacer solo con lo que te
  -- sobra (SellQty con el banco: sin lo reservado para tu ruta) y el total de esas n valorado como la ruta: solo
  -- sellCap unidades a precio de subasta, el resto a precio del vendedor. noPrice = algun material sin precio.
  function RK.CraftProfit(cr)
    local v1 = AHApi()
    local n, matSell, matBuy, noPrice = nil, 0, 0, false
    for _, m in ipairs(cr.r) do
      local can = math.floor((SellQty(m[1], true) or 0) / m[2])
      n = n and math.min(n, can) or can
      local bp = BuyPrice(m[1])
      if not bp then noPrice = true end
      matSell = matSell + m[2] * SellValue(m[1])
      matBuy = matBuy + m[2] * (bp or 0)
    end
    local ahOut = v1 and v1.GetAuctionPriceByItemID(d.CALLER, cr.o) or nil
    if ahOut and ahOut <= 0 then ahOut = nil end
    -- un objeto que se liga al recogerlo no se puede subastar
    if select(14, d.C_Item.GetItemInfo(cr.o)) == 1 then ahOut = nil end
    local q = cr.q or 1
    local vend = VendorPrice(cr.o) or 0
    local unit = math.max(ahOut and ahOut * (1 - d.AH_CUT) or 0, vend)
    local outVal = unit * q
    n = n or 0
    local units = n * q
    local ahU = math.min(units, math.max(0, Cfg("sellCap") or 5))
    return { n = n, q = q, outVal = outVal, viaAH = ahOut ~= nil, noPrice = noPrice,
      gain = outVal - matSell, gainBuy = (not noPrice) and (outVal - matBuy) or nil,
      total = ahU * unit + (units - ahU) * vend - n * matSell }
  end

  return d.Skin.Route
end
