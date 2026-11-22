-- features/guide/hybrid.lua: the hybrid profession guide. The own list (GoldFinderGuides) with the character's state on
-- top: finished bands, the current one with what is missing, and the cheapest planner alternative. Container: data
-- comes from d, the merge from GF.GuideMerge.

local _, GF = ...

-- d: BuyPrice, Cfg, Char, Counts, GatherZones, GuideKey, Money, PickZone, RouteFor, ShortMoney, StepMats, TrainerLearn, TrainList, TrainReq, WhereText
function GF.InitGuide(d)
  local UI = GF.UI
  local Skin = UI.Skin
  local BuyPrice, Cfg, Char, Counts, GatherZones, GuideKey, Money, PickZone, RouteFor, ShortMoney, StepMats, TrainerLearn, TrainList, TrainReq, WhereText =
    d.BuyPrice,
    d.Cfg,
    d.Char,
    d.Counts,
    d.GatherZones,
    d.GuideKey,
    d.Money,
    d.PickZone,
    d.RouteFor,
    d.ShortMoney,
    d.StepMats,
    d.TrainerLearn,
    d.TrainList,
    d.TrainReq,
    d.WhereText
  local format = string.format
  local L = GF.L
  local BuildGuide


  -- Lista propia de la profesion (o nil)
  local function GuideStatic(prof, pd)
    for _, g in pairs(GoldFinderGuides or {}) do
      if (pd.skillLine and g.line == pd.skillLine) or g.name:lower() == prof:lower() then return g end
    end
    return nil
  end

  function BuildGuide(prof, pd)
    if not GuideKey(prof) then return nil end
    local T = TrainList(prof)
    local rank = pd.rank or 0
    local maxR = pd.maxRank or rank
    local g = GuideStatic(prof, pd)
    local items = {}
    local zones = (g and g.zones) or GatherZones(prof)
    if zones then
      for _, z in ipairs(zones) do
        local from, to, zt, note = z[1] or z.from, z[2] or z.to, z[3] or z.zone, z[4] or z.note
        local zone = PickZone(zt)
        items[#items + 1] = {
          kind = "gather", st = { upto = to, zone = zone }, done = to <= rank, from = from,
          e = { gather = true, prof = prof, zone = zone, upto = to, note = note },
        }
      end
    elseif g and g.bands then
      local known = {}
      for n in pairs(pd.crafts or {}) do known[n:lower()] = true end
      for n in pairs(pd.learned or {}) do known[n:lower()] = true end
      local TR = GoldFinderDB.trainerRecipes and GoldFinderDB.trainerRecipes[UnitFactionGroup("player") or "?"]
      local R = GoldFinderRecipes and GoldFinderRecipes.spells or {}
      local plan = pd.crafts and RouteFor(Char(), prof, math.min(300, rank + 75)) or nil
      local rows = GF.GuideMerge(g.bands, {
        rank = rank, known = known, trainer = TR and TR[prof] or {}, plan = plan,
        recipe = function(id) return R[id] end,
        have = function(id) local bg, bk = Counts(id); return bg + bk end,
        price = function(id) return (BuyPrice(id)) end,
      })
      for _, row in ipairs(rows) do
        local learn = row.trainerRec and TrainerLearn(row.trainerRec) or nil
        if not learn and row.learn == "t" then
          -- sin visita: el instructor del rango que ensena esa habilidad (GoldFinderTrainers o el anotado)
          for _, d in ipairs(T or {}) do
            if d.max > (row.req or 0) then
              learn = { npc = d.npc, zone = d.zone, x = d.x, y = d.y, trainer = true, rank = d.name }
              break
            end
          end
        elseif row.learn == "i" then
          learn = { item = row.item }
        end
        items[#items + 1] = { kind = "craft", band = row, done = row.done, from = row.from, mats = row.mats,
          st = { upto = row.to, qty = row.left or row.crafts, what = row.name },
          unknown = (row.name and not row.known) or nil, learn = learn }
      end
    else
      -- sin lista propia: pasos de tu ruta desde la habilidad actual
      local plan = RouteFor(Char(), prof, rank + (Cfg("routeSpan") or 25))
      local learnSeen = {}
      for _, st in ipairs(plan and plan.steps or {}) do
        local it = { kind = "craft", st = { upto = st.to, qty = st.n, what = st.c.name }, done = false, from = st.from,
          mats = StepMats(st) }
        if st.c.learn and not learnSeen[st.c] then
          learnSeen[st.c] = true
          it.unknown = true
          it.learn = TrainerLearn(st.c.learn)
        end
        items[#items + 1] = it
      end
    end
    -- rangos del instructor: cada uno antes del primer tramo que pasa de la habilidad que pide entrenarlo
    for _, d in ipairs(T or {}) do
      local rq = TrainReq(prof, d.max)
      local at = #items + 1
      for idx, it in ipairs(items) do
        if it.kind ~= "train" and it.st and it.st.upto > math.max(d.max - 75, (rq and rq.skill) or 0) then
          at = idx; break
        end
      end
      table.insert(items, at, { kind = "train", d = d, done = d.max <= maxR,
        e = { train = d, trainState = "guide", prof = prof } })
    end
    local cur
    if pd.maxRank and rank >= pd.maxRank then
      for _, it in ipairs(items) do
        if it.kind == "train" and not it.done then cur = it; break end
      end
    end
    if not cur then
      for _, it in ipairs(items) do
        if it.kind ~= "train" and not it.done and (not cur or it.st.upto < cur.st.upto) then cur = it end
      end
    end
    if cur then cur.current = true end
    return items
  end

  -- Textos de un tramo de la lista propia: cabecera (habilidad, icono, receta, fabricaciones) y lineas secundarias
  -- (como se aprende, receta opcional, alternativa con tus precios y lo que falta del tramo actual).
  -- Devuelve head, sub (lista de lineas) y true si algun nombre de objeto aun no estaba cargado.
  local function ItemName(id)
    local nm = C_Item.GetItemInfo(id)
    if nm then return nm, false end
    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return "item:" .. id, true
  end
  function Skin.GuideBand(it)
    local b, grey, miss = it.band, it.done, false
    -- icono del objeto que se fabrica: en Forever el icono del hechizo de profesion es el generico de la profesion
    local rec = b.spell and GoldFinderRecipes and GoldFinderRecipes.spells and GoldFinderRecipes.spells[b.spell]
    local icon
    if rec and rec.o then
      -- sin el objeto en memoria el juego devuelve un icono provisional (cuadrado azul): se pide y se redibuja
      if C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(rec.o) then
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(rec.o) end
        miss = true
      end
      icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(rec.o) or nil
    end
    icon = icon or (b.spell and GF.SpellTexture(b.spell)) or nil
    local head = (icon and format("|T%s:16:16:0:-2|t ", tostring(icon)) or "")
      .. (grey and "" or "|cffffd100") .. format("%d-%d", b.from, b.to) .. (grey and "  " or "|r  ")
      .. (b.name or L["guide.noRecipe"])
      .. (b.name and format("  |cffb3b3b3x%d|r", it.st.qty or b.crafts or 0) or "")
      .. (b.icy and "  |cff8a8a96(Icy Veins)|r" or "")
    local sub = {}
    if grey or not b.name then return head, sub, miss end
    if not b.known then
      if b.learn == "i" then
        local nm, m = ItemName(b.item)
        miss = miss or m
        sub[#sub + 1] = format(L["guide.vendorRecipe"], nm, b.req or 0)
      elseif b.learn == "u" then
        sub[#sub + 1] = format(L["guide.unknownSource"], b.req or 0)
      else
        local l = it.learn
        local who = (l and l.npc) and format(L["guide.npcIn"], l.npc, WhereText(l)) or L["guide.trainer"]
        local cost = b.trainerRec and b.trainerRec.cost and b.trainerRec.cost > 0 and (", " .. Money(b.trainerRec.cost)) or ""
        sub[#sub + 1] = format(L["guide.learnWith"], who, b.req or 0, cost,
          b.approx and L["guide.approx"] or "")
      end
    elseif it.current then
      sub[#sub + 1] = L["guide.known"]
    end
    if b.opt then
      local nm, m = ItemName(b.opt.item)
      miss = miss or m
      sub[#sub + 1] = format(L["guide.optional"], b.opt.name or "?", nm)
    end
    if b.alt then
      sub[#sub + 1] = format(L["guide.alt"], b.alt.what, b.alt.n or 0,
        ShortMoney(b.alt.cost), b.cost and format(L["guide.versus"], ShortMoney(b.cost)) or "")
    end
    if it.current and b.mats and #b.mats > 0 then
      local parts = {}
      for _, m in ipairs(b.mats) do
        local nm, mm = ItemName(m.id)
        miss = miss or mm
        if m.missing > 0 then parts[#parts + 1] = format("|cffffa640%s %d|r", nm, m.missing) end
      end
      sub[#sub + 1] = (#parts > 0) and (format(L["guide.missing"], table.concat(parts, ", "))
        .. (b.cost and (" (~" .. ShortMoney(b.cost) .. ")") or ""))
        or L["guide.ready"]
    end
    return head, sub, miss
  end

  return { BuildGuide = BuildGuide }
end
