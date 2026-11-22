-- features/route/plan.lua: combined farming spots (FarmCombos) and the routes-and-plan summary of the guide window
-- (RouteSummary: compare your route with the others, and per material decide buy, farm or wait). Container: data and
-- game readers come from d, called at use time; GoldFinderDB, GoldFinderRoutes and C_Item are read from d too (the main
-- file passes a table that falls back to the real globals).

local _, GF = ...

-- d: Skin, AHApi, AnnotateZones, BuildGuide, BuyPrice, Char, Counts, GatherZones, GuideKey, Money, ProfOn, RefPrice,
--    RouteFor, Sess
function GF.InitRoutePlan(d)
  local Skin, AHApi, AnnotateZones, BuildGuide, BuyPrice, Char, Counts, GatherZones, GuideKey, Money, ProfOn,
    RefPrice, RouteFor, Sess =
    d.Skin, d.AHApi, d.AnnotateZones, d.BuildGuide, d.BuyPrice, d.Char, d.Counts, d.GatherZones, d.GuideKey,
    d.Money, d.ProfOn, d.RefPrice, d.RouteFor, d.Sess
  local format = string.format
  local L = GF.L
  local C_Item = d.C_Item

  -- FARMEO COMBINADO: criaturas/zonas donde ya conseguiste VARIOS de los materiales que te faltan
  -- para los proximos pasos (de todas tus profesiones). Se apoya en lo que el addon aprende al abrir botines.
  local function FarmCombos()
    local SS = d.GoldFinderDB.sources
    local out = {}
    if not SS then return out end
    local groups = {}
    for prof, pd in pairs(Char().prof) do
      if ProfOn(prof) and GuideKey(prof) then
        local taken = 0
        for _, it in ipairs(BuildGuide(prof, pd) or {}) do
          if it.kind == "craft" and not it.done and taken < 3 then
            taken = taken + 1
            for _, m in ipairs(it.mats or {}) do
              local src = m.have < m.need and SS[m.id] or nil
              if src then
                local nm = C_Item.GetItemInfo(m.id)
                if not nm then
                  if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(m.id) end
                  nm = "item:" .. m.id
                end
                for zone, z in pairs(src) do
                  local k = zone .. "|" .. (z.mob or "")
                  local g = groups[k]
                  if not g then
                    g = { zone = zone, mob = z.mob, list = {}, seen = {}, score = 0 }
                    groups[k] = g
                  end
                  local tag = nm .. " (" .. (it.st.what or (prof .. " " .. it.st.upto)) .. ")"
                  if not g.seen[tag] then
                    g.seen[tag] = true
                    g.list[#g.list + 1] = tag
                    g.score = g.score + (z.n or 1)
                  end
                end
              end
            end
          end
        end
      end
    end
    for _, g in pairs(groups) do
      if #g.list >= 2 then out[#out + 1] = g end
    end
    table.sort(out, function(a, b)
      if #a.list ~= #b.list then return #a.list > #b.list end
      return a.score > b.score
    end)
    return out
  end

  -- RUTAS Y PLAN: compara tu ruta (el planificador, con tus recetas) con otras (GoldFinderRoutes) usando tus precios de
  -- la subasta, y decide material por material si conviene COMPRAR, FARMEAR o esperar. Para farmear se usa tu ritmo de la
  -- sesion (unidades por hora de ese objeto y oro por hora): se farmea si tu tiempo vale menos que comprarlo.
  local function OwnRouteNeed(prof, cap)
    local plan = RouteFor(Char(), prof, cap)
    local need = {}
    for _, m in ipairs(plan and plan.mats or {}) do need[m.id] = m.need end
    return need
  end

  local function OtherRouteNeed(route, rank, cap)
    local need = {}
    for _, st in ipairs(route.steps) do
      local span = st.to - st.from
      local f
      if span <= 0 then f = (rank < st.from and cap >= st.to) and 1 or 0
      else f = (math.min(st.to, cap) - math.max(rank, st.from)) / span end
      if f > 0 then
        for _, m in ipairs(st.mats) do
          if not m[3] or rank >= m[3] then need[m[1]] = (need[m[1]] or 0) + m[2] * f end
        end
        for _, m in ipairs(st.makes or {}) do need[m[1]] = (need[m[1]] or 0) - m[2] * f end
      end
    end
    return need
  end

  -- Que te falta de cada material (descontando bolsas + banco) y que conviene hacer con cada uno
  local function RoutePlan(need)
    local v1 = AHApi()
    local sess = Sess()
    local hrs = (sess.secs or 0) / 3600
    local gph = (hrs >= 1 / 6 and (sess.total or 0) > 0) and (sess.total / hrs) or nil
    local rows, cost, unknown = {}, 0, 0
    for id, q in pairs(need) do
      local bags, bank = Counts(id)
      local miss = math.ceil(q) - bags - bank
      if miss > 0 then
        -- el mismo precio de compra que el planificador (lo mas barato de subasta y vendedor)
        local price = BuyPrice(id)
        local buy = price and price * miss or nil
        if buy then cost = cost + buy else unknown = unknown + 1 end
        local it = sess.items and sess.items[id]
        local rate = (it and hrs >= 1 / 6 and it.count > 0) and (it.count / hrs) or nil
        local farmH = rate and (miss / rate) or nil
        local farmVal = (farmH and gph) and (farmH * gph) or nil
        local ref = RefPrice(id)
        local verdict
        if buy and farmVal then verdict = (farmVal < buy * 0.9) and "farm" or "buy"
        elseif buy then verdict = "buy"
        elseif farmH then verdict = "farm"
        else verdict = "none" end
        rows[#rows + 1] = {
          id = id, miss = miss, buy = buy, farmH = farmH, farmVal = farmVal, verdict = verdict,
          low = (price and ref and price <= ref * 0.85) or false,
          high = (price and ref and price >= ref * 1.15) or false,
        }
      end
    end
    table.sort(rows, function(a, b) return (a.buy or 0) > (b.buy or 0) end)
    return rows, cost, unknown
  end

  -- Lineas del plan: material por material, que conviene hacer (los 5 mas caros)
  local function PlanText(rows)
    local lines, n = {}, 0
    for _, r in ipairs(rows) do
      if n >= 5 then break end
      n = n + 1
      local nm = C_Item.GetItemInfo(r.id)
      if not nm then
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r.id) end
        nm = "item:" .. r.id
      end
      local act
      if r.verdict == "buy" then
        act = format(L["plan.buy"], Money(r.buy or 0))
          .. (r.low and L["plan.lowPrice"] or "")
          .. (r.farmH and format(L["plan.farmOpt"], r.farmH) or "")
      elseif r.verdict == "farm" then
        act = format(L["plan.farm"], r.farmH)
          .. (r.buy and format(L["plan.buyOpt"], Money(r.buy), r.high and L["plan.highPrice"] or "") or "")
      else
        act = L["plan.noData"]
      end
      lines[#lines + 1] = format(L["plan.line"], nm, r.miss, act)
    end
    return lines
  end

  local function RouteSummary(prof, key, pd)
    local routes = d.GoldFinderRoutes and d.GoldFinderRoutes[key]
    if not routes or not pd.rank then return nil end
    local cap = pd.maxRank or 300
    if pd.rank >= cap then cap = math.min(300, cap + 75) end
    local out = {}

    -- zonas que sugieren otras guias para el tramo actual
    for _, r in ipairs(routes) do
      for _, z in ipairs(r.zones or {}) do
        if pd.rank < z.to then
          out[#out + 1] = format(L["plan.zones"], r.name, z.from, z.to, AnnotateZones(z.zone),
            z.note and (" (" .. z.note .. ")") or "")
          break
        end
      end
    end

    local others = {}
    for _, r in ipairs(routes) do
      if r.steps and #r.steps > 0 then
        local rows, c, u = RoutePlan(OtherRouteNeed(r, pd.rank, cap))
        others[#others + 1] = { name = r.name, rows = rows, cost = c, unknown = u }
      end
    end
    local own = RouteFor(Char(), prof, cap)

    if not GatherZones(prof) then
      -- profesion de fabricacion: tu ruta (coste del plan con BuyPrice y lo que cuesta aprender) contra las otras guias
      if not own then
        local why = Skin.Route.NoRouteReason(pd)
        if why then out[#out + 1] = format(L["plan.yourRoute"], why) end
        for _, o in ipairs(others) do
          if #o.rows > 0 then
            out[#out + 1] = format(L["plan.buyHead"], o.name, cap, Money(o.cost),
              o.unknown > 0 and format(L["plan.unpricedMats"], o.unknown) or "")
            for _, l in ipairs(PlanText(o.rows)) do out[#out + 1] = l end
          end
        end
      elseif #others > 0 then
        local mine = { name = L["plan.yourName"], rows = RoutePlan(OwnRouteNeed(prof, cap)), cost = own.cost, unknown = own.unknown,
          sell = own.sell, truncated = own.truncated, to = own.to }
        local lines, best = Skin.Route.RouteVerdict(mine, others, cap)
        for _, l in ipairs(lines) do out[#out + 1] = l end
        if best then
          for _, l in ipairs(PlanText(best.rows)) do out[#out + 1] = l end
          if #best.rows == 0 then out[#out + 1] = L["plan.haveAll"] end
        end
      end
    else
      -- profesion de recoleccion: la otra guia ofrece una alternativa comprando
      for _, o in ipairs(others) do
        if #o.rows > 0 then
          out[#out + 1] = format(L["plan.alt"], o.name, Money(o.cost),
            o.unknown > 0 and format(L["plan.unpricedMats"], o.unknown) or "")
          for _, l in ipairs(PlanText(o.rows)) do out[#out + 1] = l end
        end
      end
    end
    if #out == 0 then return nil end
    return table.concat(out, "\n")
  end

  return { FarmCombos = FarmCombos, RouteSummary = RouteSummary }
end
