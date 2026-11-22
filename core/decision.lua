-- core/decision.lua: sell, auction or keep. The rules live here; everything that reads the game or other
-- sections arrives through the deps table of GF.NewDecision, so the tests inject stubs.

local _, GF = ...

-- d: AHApi, VendorPrice, TSMValue, Cfg, Char, Counts, SkillUpNeed, RouteNeedFor, ReagentInfo, QuestNeed,
--    RecipeToLearn, RecipeForOthers, OtherNeed, IsUtilityItem, RefPrice, ToBanker, ItemInfoInstant, ItemQuality
function GF.NewDecision(d)
  local CALLER, AH_CUT, QUEST_ALL = GF.CALLER, GF.AH_CUT, GF.QUEST_ALL
  local format = string.format
  local L = GF.L
  local AHApi, VendorPrice, TSMValue, Cfg, Char, Counts, SkillUpNeed, RouteNeedFor, ReagentInfo, QuestNeed, RecipeToLearn, RecipeForOthers, OtherNeed, IsUtilityItem, RefPrice, ToBanker =
    d.AHApi, d.VendorPrice, d.TSMValue, d.Cfg, d.Char, d.Counts, d.SkillUpNeed, d.RouteNeedFor, d.ReagentInfo, d.QuestNeed, d.RecipeToLearn, d.RecipeForOthers, d.OtherNeed, d.IsUtilityItem, d.RefPrice, d.ToBanker
  local Decide, SellQty

  -- REGLAS DE VENTA
  -- herramientas de profesion clasicas (sin efecto "Usar:", el vendedor las paga y no suelen tener precio de
  -- subasta): nunca se recomiendan al vendedor. Las canas de pescar se detectan tambien por subclase (arma 2, sub 20).
  local TOOL_IDS = {
    [2901] = true,   -- Mining Pick
    [7005] = true,   -- Skinning Knife
    [5956] = true,   -- Blacksmith Hammer
    [6219] = true,   -- Arclight Spanner
    [10498] = true,  -- Gyromatic Micro-Adjustor
    [6256] = true,   -- Fishing Pole
    [6218] = true,   -- Runed Copper Rod
    [6339] = true,   -- Runed Silver Rod
    [11130] = true,  -- Runed Golden Rod
    [11145] = true,  -- Runed Truesilver Rod
    [16207] = true,  -- Runed Arcanite Rod
  }
  local function IsProfessionTool(id)
    if TOOL_IDS[id] then return true end
    local _, _, _, _, _, classID, subClassID = d.ItemInfoInstant(id)
    return classID == 2 and subClassID == 20
  end

  local Quality = d.ItemQuality

  -- sin precio de Auctionator: TSM decide si compensa la subasta; sin ningun dato no se manda al vendedor
  -- (salvo la basura gris). Sin precio de vendedor (vendor 0) y TSM sin valor que compense: NONE "escanea".
  -- Devuelve veredicto, codigo del motivo ("tsm", "scan" o nil) y valor por unidad.
  local function NoAuctionVerdict(vendor, tsm, quality, qty)
    if quality == 0 and vendor > 0 then return "VENDOR", nil, vendor end
    if tsm and tsm > 0 then
      local net = tsm * (1 - AH_CUT)
      if net > vendor * 1.10 and (net - vendor) * math.max(qty, 1) >= Cfg("minGain") then
        return "AH", "tsm", net
      end
      if vendor > 0 then return "VENDOR", nil, vendor end
    end
    return "NONE", "scan", 0
  end
  -- FIN DE REGLAS DE VENTA

  -- reserva de un objeto: { own, alts, total, label, su, z, rg, o }
  local function Reserve(id)
    local r = { su = SkillUpNeed(id), z = RouteNeedFor(Char(), id), rg = ReagentInfo(id) }
    r.o = Cfg("crossChars") and OtherNeed(id, true) or nil
    -- misiones: se suman a lo de tus profesiones (entregar la mision consume ademas de fabricar)
    r.q = Cfg("questItems") ~= false and QuestNeed and QuestNeed(id) or nil
    r.prof = math.max(r.su and r.su.need or 0, r.z and r.z.need or 0, r.rg and r.rg.need or 0)
    r.own = r.prof + (r.q and r.q.n or 0)
    r.alts = r.o and r.o.need or 0
    r.total = r.own + r.alts
    local names, seen = {}, {}
    local function add(n) if n and not seen[n] then seen[n] = true; names[#names + 1] = n end end
    if r.su then for _, p in ipairs(r.su.profs or {}) do add(p) end end
    if r.z then add(r.z.prof) end
    if r.rg then add(r.rg.prof) end
    if r.o then add(r.o.who) end
    r.otherLabel = #names > 0 and table.concat(names, ", ") or nil
    if r.q and #(r.q.quests or {}) > 0 then add(format(L["decision.questLabel"], table.concat(r.q.quests, ", "))) end
    r.label = #names > 0 and table.concat(names, ", ") or nil
    return r
  end

  function Decide(id, bags, bank, bound)
    local v1 = AHApi()
    local ah = (not bound and v1) and v1.GetAuctionPriceByItemID(CALLER, id) or nil
    if ah and ah <= 0 then ah = nil end
    local vendor = VendorPrice(id) or 0
    local ahNet = ah and ah * (1 - AH_CUT) or 0
    local have = bags + bank
    local d = { ahNet = ahNet, vendor = vendor, unit = math.max(ahNet, vendor), verdict = "NONE", sellQty = 0 }

    if GoldFinderDB and Char().keep[id] then
      d.verdict, d.code, d.reason, d.manual = "KEEP", "manual", L["decision.manual"], true
      return d
    end
    if IsProfessionTool(id) then
      d.verdict, d.code, d.reason = "KEEP", "tool", L["decision.tool"]
      return d
    end
    local r = Reserve(id)
    d.reserve, d.reserveFor, d.reserveOther = r.total, r.label, r.otherLabel
    if r.q then d.quest = r.q end
    -- lo que se puede vender o publicar: lo de las bolsas que no hace falta para la reserva
    d.sellQty = math.max(0, math.min(bags, have - r.total))
    if r.own > 0 and have <= r.own then
      local su, z, rg, q = r.su, r.z, r.rg, r.q
      d.verdict, d.code, d.need = "KEEP", "reserve", r.own
      if q and (r.prof < have or r.prof == 0) then
        local titles = q.titles and #q.titles > 0 and q.titles or (not q.chain and q.quests) or nil
        if titles and #titles > 0 then
          d.code, d.reason = "quest", format(L["decision.quest"], table.concat(titles, ", "))
        else
          d.code, d.reason = "chain", format(L["decision.chain"], table.concat(q.chainTitles or q.quests or {}, ", "))
        end
        if q.n < QUEST_ALL then d.reason = format(L["decision.have"], d.reason, have, r.own) end
      elseif su and su.need >= have then
        d.code = "skillup"
        d.reason = format(L["decision.skillup"], table.concat(su.profs, ", "), tostring(su.target or "?"), have, su.need)
      elseif z and z.need >= have then
        d.code, d.reason = "route", format(L["decision.route"], z.prof, z.need, z.upto, have)
      else
        d.code, d.reason = "reagent", format(L["decision.reagent"], rg.prof, rg.recipe, have, rg.need)
      end
      return d
    end
    local recipe = RecipeToLearn(id)
    if recipe then
      d.verdict, d.code, d.reason = "KEEP", "recipe", recipe
      return d
    end
    if Cfg("crossChars") then
      local ro = RecipeForOthers(id)
      if ro then
        d.verdict = "KEEP"
        d.code = "otherRecipe"
        d.reason = ro.unknown and format(L["decision.otherRecipeUnknown"], ro.note)
          or format(L["decision.otherRecipe"], ro.who, ro.prof, ro.rank,
          ro.req and format(L["decision.req"], ro.req) or "",
          ro.ready and L["decision.canLearnNow"] or L["decision.lacksSkill"])
        d.forOther = ro.who
        return d
      end
      local o = r.o
      if o and have <= r.total then
        local one = o.first or o
        d.verdict, d.code, d.need = "KEEP", "otherNeed", r.total
        if (o.n or 1) > 1 then
          d.reason = format(L["decision.othersNeed"], o.who, have, r.total)
        elseif one.su then
          d.reason = format(L["decision.otherSkillup"], one.who, one.need, one.prof)
        else
          d.reason = format(L["decision.otherNeeds"], one.who, one.prof,
            one.upto and format(L["decision.upto"], one.upto) or "", have, r.total)
        end
        d.forOther = o.who
        return d
      end
    end
    local qty = math.max(d.sellQty, 1)
    -- objetos de uso (bolsa de dormir, juguetes...): nunca al vendedor; si valen en la subasta, se sigue evaluando
    local utility = IsUtilityItem(id)
    if utility then d.code, d.reason = "utility", L["decision.utility"] end
    -- sin precio de Auctionator y sin ligar: TSM decide (con o sin precio de vendedor)
    if not ah and not bound and (vendor == 0 or not utility) then
      local tsm = TSMValue("DBMarket", id)
      if not (tsm and tsm > 0) then tsm = TSMValue("DBRegionMarketAvg", id) end
      local verdict, code, unit = NoAuctionVerdict(vendor, tsm, Quality(id), qty)
      d.verdict, d.code, d.unit = verdict, code, unit
      d.reason = code and L["decision." .. code] or nil
      if verdict == "AH" then
        d.ahNet = unit
        d.toBanker = ToBanker() or nil
      end
      return d
    end
    if vendor > 0 and vendor >= ahNet and not utility then
      d.verdict, d.unit = "VENDOR", vendor
      return d
    end
    if ah then
      local ref = RefPrice(id)
      if ref and ah <= ref * 0.85 and ahNet * qty >= Cfg("minGain") then
        d.verdict, d.code, d.reason = "KEEP", "lowprice", L["decision.lowprice"]
        return d
      end
      local worth = ahNet > vendor * 1.10 and (ahNet - vendor) * qty >= Cfg("minGain")
      if vendor == 0 or worth then
        d.verdict, d.unit = "AH", ahNet
        d.toBanker = ToBanker() or nil
        return d
      end
    end
    if vendor > 0 and not utility then d.verdict, d.unit = "VENDOR", vendor end
    return d
  end

  -- Cuantas unidades conviene vender o publicar: las que tienes en bolsas menos lo que hay que reservar
  -- (fijado a mano, herramientas, materiales de tus profesiones y, si esta activado, de tus otros personajes).
  -- withBank: cuenta tambien el banco (lo que te sobra en total, p. ej. para fabricar), no solo lo de las bolsas.
  function SellQty(id, withBank)
    local bags, bank = Counts(id)
    if withBank then bags, bank = bags + bank, 0 end
    if bags <= 0 then return 0 end
    if Char().keep[id] or IsProfessionTool(id) then return 0 end
    local r = Reserve(id)
    return math.max(0, math.min(bags, bags + bank - r.total))
  end

  return Decide, SellQty
end
