-- core/routeplanner.lua: profession route planner (recipe colors, costs, the cheapest path from the current
-- skill to the target) and the own-route helpers built on it. The game, prices and the other sections arrive
-- through d, read at call time; the recipe/route data tables are d.GoldFinderRecipes / d.GoldFinderRoutes.

local _, GF = ...

-- d: Cfg, Counts, VendorPrice, AHApi, SuOwned (plus GoldFinderForeverDB, GoldFinderRecipes, GoldFinderRoutes,
--    UnitFactionGroup, GetRealZoneText, geterrorhandler, C_Item, which fall back to the game globals)
function GF.NewRoutePlanner(d)
  local CALLER, AH_CUT = GF.CALLER, GF.AH_CUT
  local recipeIdx
  local function RecipeLookup(skillLine, name)
    local R = d.GoldFinderRecipes
    if not (R and R.spells and skillLine and name) then return nil end
    if not recipeIdx then
      recipeIdx = {}
      for _, x in pairs(R.spells) do
        local t = recipeIdx[x.s]
        if not t then t = {}; recipeIdx[x.s] = t end
        local key = x.n:lower()
        if not t[key] then t[key] = x end
      end
    end
    local t = recipeIdx[skillLine]
    return t and t[name:lower()] or nil
  end

  local function SkillUpChance(x, skill)
    if skill < x.y then return 1 end
    return math.max(0, (x.g - skill) / (x.g - x.y))
  end

  local function RecipeColor(x, skill)
    if skill < x.y then return 0 end
    if skill < (x.y + x.g) / 2 then return 1 end
    if skill < x.g then return 2 end
    return 3
  end

  -- PLANIFICADOR DE RUTA: para subir de la habilidad actual a la objetivo, en cada punto de habilidad elige la receta
  -- (de las que ya sabes) con menor coste neto esperado por punto: (materiales - valor de lo fabricado) / (probabilidad
  -- de subir x puntos por fabricacion). Los materiales que ya tienes cuentan por lo que sacarias vendiendolos y se
  -- van gastando. Es una estimacion: cantidades esperadas, sin sobrantes, y los intermedios se compran hechos.
  -- Lo fabricado solo vale precio de subasta en sus primeras sellCap unidades (lo que el mercado absorbe); el resto
  -- vale lo que paga el vendedor. Asi la ruta no apuesta a vender decenas de copias del mismo objeto.
  local function BuyPrice(id)
    local v1 = d.AHApi()
    local ah = v1 and v1.GetAuctionPriceByItemID(CALLER, id) or nil
    if ah and ah <= 0 then ah = nil end
    local vb = d.GoldFinderForeverDB.vendorBuy and d.GoldFinderForeverDB.vendorBuy[id]
    if vb and vb <= 0 then vb = nil end
    -- lo mas barato de la subasta y del vendedor que lo vende (precio visto en su ventana)
    if ah and vb then return math.min(ah, vb), false end
    if ah or vb then return ah or vb, false end
    local vs = d.VendorPrice(id)
    if vs and vs > 0 then return vs * 4, true end   -- el vendedor suele vender a 4 veces lo que paga
    return nil
  end

  local function SellValue(id, noAH)
    local v1 = d.AHApi()
    local ah = (not noAH and v1) and v1.GetAuctionPriceByItemID(CALLER, id) or nil
    if ah and ah <= 0 then ah = nil end
    return math.max(ah and ah * (1 - AH_CUT) or 0, d.VendorPrice(id) or 0)
  end

  local function PlanRoute(prof, pd, target)
    if not (pd.crafts and pd.rank and pd.skillLine) then return nil end
    local top = math.min(target, pd.maxRank or 300)
    if pd.rank >= top then return nil end
    local bpCache, svCache = {}, {}
    local function buyP(id)
      local c = bpCache[id]
      if c == nil then
        local pr, est = BuyPrice(id)
        c = { pr or false, est }
        bpCache[id] = c
      end
      return c[1] or nil, c[2]
    end
    local function sellV(id)
      local c = svCache[id]
      if c == nil then c = SellValue(id); svCache[id] = c end
      return c
    end
    local cands = {}
    -- learn = receta del instructor que aun no sabes ({ n, req, cost, npc, zone, x, y }), nil si ya la sabes.
    local function addCand(name, x, cr, learn)
      local outVal, outVend = 0, 0
      if cr.o then
        local bound = select(14, d.C_Item.GetItemInfo(cr.o)) == 1
        outVal = SellValue(cr.o, bound) * (cr.q or 1)
        outVend = SellValue(cr.o, true) * (cr.q or 1)
      end
      local unitBuy = 0
      for _, m in ipairs(cr.r) do unitBuy = unitBuy + m[2] * (buyP(m[1]) or 0) end
      cands[#cands + 1] = { name = name, x = x, cr = cr, o = cr.o, outVal = outVal, outVend = outVend, unitBuy = unitBuy,
        made = 0, q = cr.q or 1, learn = learn }
    end
    local known = {}
    for name, cr in pairs(pd.crafts) do
      known[name:lower()] = true
      local x = RecipeLookup(pd.skillLine, name)
      if x then addCand(name, x, cr) end
    end
    for name in pairs(pd.learned or {}) do known[name:lower()] = true end
    -- Recetas que aun no sabes pero ensena tu instructor (anotadas al abrir su ventana): entran en la ruta desde la
    -- habilidad que piden, con sus materiales y objeto de GoldFinderRecipes y el precio de aprenderlas.
    local TR = d.GoldFinderForeverDB.trainerRecipes and d.GoldFinderForeverDB.trainerRecipes[d.UnitFactionGroup("player") or "?"]
    for key, t in pairs(TR and TR[prof] or {}) do
      local x = not known[key] and RecipeLookup(pd.skillLine, t.n)
      if x then addCand(t.n, x, { r = x.r, o = x.o, q = x.q }, t) end
    end
    if #cands == 0 then return nil end

    local stock = {}
    local function held(id)
      local v = stock[id]
      if v == nil then
        local b, k = d.Counts(id)
        v = b + k
        stock[id] = v
      end
      return v
    end

    local cap = math.max(0, d.Cfg("sellCap") or 5)
    -- Valor medio de las proximas n fabricaciones de c: precio de subasta hasta cap unidades, despues el del vendedor.
    -- cap cuenta unidades (fabricaciones x q), no fabricaciones; outVal y outVend ya son por fabricacion (x q).
    local function nextValue(c, n)
      local units = n * c.q
      local ah = math.min(units, math.max(cap - c.made * c.q, 0))
      return (ah * c.outVal + (units - ah) * c.outVend) / c.q / n
    end

    local steps, need, learns = {}, {}, {}
    -- coste neto por punto de cada receta a la habilidad actual (el mismo calculo que elige la ruta): lo leen las
    -- notas de la lista de recetas de la ventana de profesiones. Negativo = ganancia por punto.
    local firstEff = {}
    local sk = pd.rank
    while sk < top do
      local best, bestEff, bestP
      for _, c in ipairs(cands) do
        local pch = SkillUpChance(c.x, sk)
        if pch > 0 and c.learn and not c.learned and sk < (c.learn.req or 0) then pch = 0 end
        if pch > 0 then
          local cost, unpriced = 0, false
          for _, m in ipairs(c.cr.r) do
            local h = held(m[1])
            local use = math.min(h, m[2])
            local buy = m[2] - use
            local bp = buy > 0 and buyP(m[1]) or nil
            if buy > 0 and not bp then unpriced = true end
            cost = cost + use * sellV(m[1]) + buy * (buy > 0 and (bp or 1e7) or 0)
          end
          local eff = (cost - nextValue(c, 1 / (pch * c.x.k))) / (pch * c.x.k)
          -- Aprenderla se paga una vez: se reparte entre los puntos que aun puede dar antes de ponerse gris, sin
          -- depender del objetivo (todas las vistas eligen la misma receta con la misma habilidad).
          if c.learn and not c.learned then
            eff = eff + (c.learn.cost or 0) / math.max(1, c.x.g - sk)
          end
          -- sin precio de algun material: la penalizacion solo sirve para elegir; la nota dice "sin precio" (false)
          if sk == pd.rank then firstEff[c.name:lower()] = (not unpriced) and eff or false end
          if not best or eff < bestEff - 1e-9 then best, bestEff, bestP = c, eff, pch end
        end
      end
      if not best then break end
      if best.learn and not best.learned then
        best.learned = true
        learns[#learns + 1] = { t = best.learn, at = sk }
      end
      local frac = 1 / (bestP * best.x.k)
      best.made = best.made + frac
      for _, m in ipairs(best.cr.r) do
        local total = m[2] * frac
        local h = held(m[1])
        stock[m[1]] = h - math.min(h, total)
        need[m[1]] = (need[m[1]] or 0) + total
      end
      local last = steps[#steps]
      if last and last.c == best then
        last.to = sk + 1
        last.crafts = last.crafts + frac
      else
        steps[#steps + 1] = { c = best, from = sk, to = sk + 1, crafts = frac }
      end
      sk = sk + 1
    end
    if #steps == 0 then return nil end

    local mats, cost, sell, unknown = {}, 0, 0, 0
    for id, q in pairs(need) do
      local qn = math.ceil(q - 1e-9)
      local b, k = d.Counts(id)
      local have = b + k
      local missing = math.max(qn - have, 0)
      local pr, est
      if missing > 0 then pr, est = buyP(id) end
      local mc = pr and pr * missing or nil
      if missing > 0 then
        if mc then cost = cost + mc else unknown = unknown + 1 end
      end
      mats[#mats + 1] = { id = id, need = qn, have = have, missing = missing, price = pr, cost = mc, est = est }
    end
    table.sort(mats, function(a, b) return (a.cost or 0) > (b.cost or 0) end)
    local learnCost = 0
    for _, l in ipairs(learns) do learnCost = learnCost + (l.t.cost or 0) end
    cost = cost + learnCost
    local sold = {}
    for _, st in ipairs(steps) do
      st.n = math.ceil(st.crafts - 1e-9)
      -- cap cuenta unidades: una receta que da q objetos vende q por fabricacion
      local q = st.c.q
      local units = st.n * q
      local used = sold[st.c] or 0
      local ah = math.min(units, math.max(cap - used, 0))
      st.value = (ah * st.c.outVal + (units - ah) * st.c.outVend) / q
      st.ahUnits = ah
      sold[st.c] = used + units
      sell = sell + st.value
    end
    -- truncated: ninguna receta (sabida o del instructor) da puntos desde "to"; la ruta no llega al objetivo
    return { prof = prof, pd = pd, from = pd.rank, to = sk, target = top, truncated = sk < top, steps = steps, mats = mats,
      cost = cost, sell = sell, unknown = unknown, cap = cap, learns = learns, learnCost = learnCost, eff = firstEff }
  end

  ---------------------------------------------------------------------------
  -- RUTA PROPIA (sustituye a las guias de Zygor): el siguiente paso, la guia y los materiales que conviene
  -- guardar salen del planificador de ruta (PlanRoute) con tus recetas, las del instructor y tus precios.
  -- Los planes se guardan por personaje, profesion y objetivo; se rehacen solos si cambia la habilidad, el
  -- tope o las recetas, y InvalidateRoutes los borra al cambiar bolsas, precios o lo que ensena el instructor.
  ---------------------------------------------------------------------------
  local ROUTE_WINDOW = 60   -- solo se reservan los materiales de los proximos ROUTE_WINDOW puntos de habilidad
  local routeCache = {}

  local function InvalidateRoutes()
    routeCache = {}
  end

  -- Plan de la profesion prof de un personaje hasta la habilidad target (nil si no hay plan). Para otros
  -- personajes se cuentan tus bolsas y tu banco en lugar de los suyos: es una aproximacion.
  local function RouteFor(c, prof, target)
    local pd = c and c.prof and c.prof[prof]
    if not (pd and pd.rank and target) then return nil end
    local byChar = routeCache[c]
    if not byChar then byChar = {}; routeCache[c] = byChar end
    local k = prof .. "|" .. target
    local e = byChar[k]
    local cap = d.Cfg("sellCap")
    if not (e and e.pd == pd and e.rank == pd.rank and e.max == pd.maxRank and e.cap == cap) then
      local ok, plan = xpcall(function() return PlanRoute(prof, pd, target) end, d.geterrorhandler())
      e = { pd = pd, rank = pd.rank, max = pd.maxRank, cap = cap, plan = (ok and plan) or false }
      byChar[k] = e
    end
    return e.plan or nil
  end

  -- Material que gasta la ruta de alguna profesion del personaje en sus proximos ROUTE_WINDOW puntos:
  -- { need = unidades que pide la ruta, upto = habilidad hasta la que sirve, prof } o nil.
  local function RouteNeedFor(c, id)
    -- la profesion que mas pide (orden alfabetico en empates: el resultado no depende del orden de pairs)
    local profs, best = {}, nil
    for prof in pairs(c.prof or {}) do profs[#profs + 1] = prof end
    table.sort(profs)
    for _, prof in ipairs(profs) do
      local pd = c.prof[prof]
      if pd.rank and not (c.off and c.off[prof]) and not d.SuOwned(c, prof) then
        local plan = RouteFor(c, prof, pd.rank + ROUTE_WINDOW)
        if plan then
          local idx = plan.needIdx
          if not idx then
            idx = {}
            for _, m in ipairs(plan.mats) do idx[m.id] = { need = m.need, upto = 0 } end
            for _, st in ipairs(plan.steps) do
              for _, m in ipairs(st.c.cr.r) do
                local n = idx[m[1]]
                if n and st.to > n.upto then n.upto = st.to end
              end
            end
            plan.needIdx = idx
          end
          local n = idx[id]
          if n and n.need > 0 and not (best and best.need >= n.need) then
            best = { need = n.need, upto = n.upto, prof = prof }
          end
        end
      end
    end
    return best
  end

  -- Materiales de un paso del plan (receta x fabricaciones) con lo que tienes (bolsas + banco)
  local function StepMats(st)
    local mats = {}
    for _, m in ipairs(st.c.cr.r) do
      local bags, bank = d.Counts(m[1])
      mats[#mats + 1] = { id = m[1], need = m[2] * st.n, have = bags + bank }
    end
    return mats
  end

  -- Donde aprender una receta del instructor anotada al abrir su ventana
  local function TrainerLearn(l)
    return { npc = l.npc, zone = l.zone, x = l.x, y = l.y, cost = l.cost, trainer = true }
  end

  -- Siguiente paso de la ruta: la primera receta del plan, cuantas veces, el tramo y sus materiales
  local function RouteStepEntry(prof, pd, plan)
    local st = plan and plan.steps[1]
    if not st then return nil end
    local e = { prof = prof, rank = pd.rank, qty = st.n, what = st.c.name, from = st.from, upto = st.to,
      skillLine = pd.skillLine, mats = StepMats(st) }
    if st.c.learn then
      e.unknown = true
      e.learn = TrainerLearn(st.c.learn)
    end
    local nx = plan.steps[2]
    if nx then e.nxt = { what = nx.c.name, upto = nx.to } end
    return e
  end

  -- Recoleccion (Mineria, Herboristeria): zonas por tramo de GoldFinderRoutes (Icy Veins)
  local function GatherZones(prof)
    local p = (prof or ""):lower()
    if not (p:find("min", 1, true) or p:find("herb", 1, true)) then return nil end
    for k, routes in pairs(d.GoldFinderRoutes or {}) do
      if p:find(k, 1, true) then
        for _, rt in ipairs(routes) do
          if rt.zones and #rt.zones > 0 then return rt.zones end
        end
      end
    end
    return nil
  end

  -- De "Durotar, Mulgore o Tirisfal Glades": la zona donde estas si esta en la lista; si no, la primera
  local function PickZone(text)
    local here = d.GetRealZoneText and d.GetRealZoneText() or nil
    local first
    for name in (text .. ","):gsub(" o ", ", "):gmatch("%s*([^,]+),") do
      first = first or name
      if name == here then return name end
    end
    return first or text
  end

  -- Pesca y Desuello: zonas por tramo de GoldFinderRoutes, solo si el jugador activo la opcion trackerGather
  -- (GatherZones sigue siendo solo Mineria y Herboristeria: la guia y el resumen de rutas dependen de ello)
  local function ExtraGatherZones(prof)
    if not d.Cfg("trackerGather") then return nil end
    local p = (prof or ""):lower()
    if not (p:find("skin", 1, true) or p:find("fish", 1, true)) then return nil end
    for k, routes in pairs(d.GoldFinderRoutes or {}) do
      if p:find(k, 1, true) then
        for _, rt in ipairs(routes) do
          if rt.zones and #rt.zones > 0 then return rt.zones end
        end
      end
    end
    return nil
  end

  local function GatherStepEntry(prof, pd)
    local zones = GatherZones(prof) or ExtraGatherZones(prof)
    if not (zones and pd.rank) then return nil end
    for i, z in ipairs(zones) do
      if pd.rank < z.to then
        local nz = zones[i + 1]
        return { gather = true, prof = prof, rank = pd.rank, from = z.from, upto = z.to, zone = PickZone(z.zone),
          note = z.note, skillLine = pd.skillLine, mats = {},
          nxt = nz and { zone = PickZone(nz.zone), upto = nz.to } or nil }
      end
    end
    return nil
  end

  return {
    RecipeLookup = RecipeLookup,
    SkillUpChance = SkillUpChance,
    RecipeColor = RecipeColor,
    BuyPrice = BuyPrice,
    SellValue = SellValue,
    PlanRoute = PlanRoute,
    InvalidateRoutes = InvalidateRoutes,
    RouteFor = RouteFor,
    RouteNeedFor = RouteNeedFor,
    StepMats = StepMats,
    TrainerLearn = TrainerLearn,
    RouteStepEntry = RouteStepEntry,
    GatherZones = GatherZones,
    PickZone = PickZone,
    GatherStepEntry = GatherStepEntry,
  }
end
