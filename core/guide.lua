-- core/guide.lua: merges the static profession list (GoldFinderGuides) with the player's state. Pure: bands and
-- state come in, one row per band comes out.

local _, GF = ...

-- bands: tramos de GoldFinderGuides; st = { rank, known = {nombre en minusculas = true}, trainer = recetas
-- anotadas del instructor {nombre = {n, req, cost, npc, zone, x, y}}, recipe(hechizo) -> {r = materiales},
-- plan = plan de PlanRoute (o nil), have(id) -> unidades, price(id) -> cobre o nil }.
-- Devuelve una fila por tramo con done/current/upcoming, la habilidad requerida (approx si es estimada), lo que
-- falta del tramo (left fabricaciones, mats, cost) y alt = { what, n, cost } si el plan elige otra receta mas
-- barata para esos puntos.
local function GuideMerge(bands, st)
  local rank = st.rank or 0
  local function costOf(list, mult)
    local mats, cost, unknown = {}, 0, false
    for _, m in ipairs(list or {}) do
      local need = math.ceil(m[2] * mult - 1e-9)
      local have = st.have(m[1]) or 0
      local missing = math.max(0, need - have)
      local p = st.price(m[1])
      if missing > 0 then
        if p then cost = cost + missing * p else unknown = true end
      end
      mats[#mats + 1] = { id = m[1], need = need, have = have, missing = missing }
    end
    return mats, (not unknown) and cost or nil
  end
  local rows = {}
  for _, b in ipairs(bands) do
    local key = (b.n or ""):lower()
    local row = { band = b, from = b.f, to = b.t, name = b.n, spell = b.s, crafts = b.c, learn = b.l,
      item = b.i, req = b.q, approx = b.a == true, icy = b.src == "icy",
      known = st.known[key] == true, opt = b.o and { item = b.o, name = b.on } or nil }
    local rec = b.n and st.trainer[key]
    if rec and rec.req then
      row.req, row.approx, row.trainerRec = rec.req, false, rec
    end
    row.done = b.t <= rank
    row.current = (not row.done) and b.f <= rank
    row.upcoming = b.f > rank
    if not row.done and b.n then
      local lo = math.max(b.f, rank)
      local span = math.max(1, b.t - b.f)
      row.left = math.max(1, math.ceil((b.c or 1) * (b.t - lo) / span - 1e-9))
      local x = b.s and st.recipe(b.s)
      if x then row.mats, row.cost = costOf(x.r, row.left) end
      local best, bestOv
      for _, s in ipairs(st.plan and st.plan.steps or {}) do
        local ov = math.min(s.to, b.t) - math.max(s.from, lo)
        if ov > 0 and (not best or ov > bestOv) then best, bestOv = s, ov end
      end
      if best and best.c.name:lower() ~= key then
        local _, c = costOf(best.c.cr and best.c.cr.r, best.n or 1)
        if c and (not row.cost or c < row.cost) then
          row.alt = { what = best.c.name, n = best.n, cost = c, learn = best.c.learn }
        end
      end
    end
    rows[#rows + 1] = row
  end
  return rows
end

-- guides = GoldFinderGuides; devuelve el nombre de la receta que la guia pone a tu habilidad actual (tramo
-- f <= rank < t) de esa profesion, o nil si no hay guia o tramo. Se busca por linea de habilidad o por nombre.
local function GuideBandName(guides, prof, skillLine, rank)
  if not (guides and prof and rank) then return nil end
  for _, g in pairs(guides) do
    if (skillLine and g.line == skillLine) or (g.name and g.name:lower() == prof:lower()) then
      for _, b in ipairs(g.bands or {}) do
        if b.f <= rank and rank < b.t then return b.n end
      end
      return nil
    end
  end
  return nil
end

GF.GuideMerge = GuideMerge
GF.GuideBandName = GuideBandName
