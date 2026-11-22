-- Route benchmark (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tools\route_benchmark.lua
-- Compares, for every crafting profession, the expected material cost of levelling 1 -> 300 along three routes under
-- the SAME cost model (cost of one skill point = materials / (skill-up chance x points per craft), one price per item,
-- no resale, nothing in the bags, every recipe known):
--   planner : the route PlanRoute builds (what the addon follows)
--   guide   : the fixed list in GoldFinderGuides (one recipe per band)
--   oracle  : at every skill point the cheapest recipe that can still give a point (a lower bound for this model)
-- Prices are synthetic (seeded, log-uniform per item, spread given as the first argument, default 4x) because real auction prices are not available offline; many
-- scenarios are run, so the result says how the routes compare in general, not at today's real prices.

local function loadData(path)
  local env = setmetatable({}, { __index = _G })
  local fn = assert(loadfile(path))
  setfenv(fn, env)
  fn("GoldFinder", {})
  return env
end
local Guides = loadData("GoldFinderGuides.lua").GoldFinderGuides
local Recipes = loadData("GoldFinderRecipes.lua").GoldFinderRecipes

local GF = {}
for _, path in ipairs({ "core/config.lua", "core/routeplanner.lua" }) do
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable({}, { __index = _G }))
  fn("GoldFinder", GF)
end

local SCENARIOS = 30
local SPREAD = tonumber(arg and arg[1]) or 4   -- price range factor: each item costs 100 x [1/sqrt(SPREAD), sqrt(SPREAD)]
local seed
local function rnd(id)
  -- deterministic pseudo-random in [0,1) from (seed, id)
  local x = (id * 2654435761 + seed * 40503) % 4294967296
  x = (x * 1103515245 + 12345) % 4294967296
  return x / 4294967296
end
local function price(id) return math.floor(100 * (SPREAD ^ (rnd(id) - 0.5))) + 1 end   -- log-uniform around 100 copper

local function chance(x, sk)
  if sk < x.y then return 1 end
  return math.max(0, (x.g - sk) / (x.g - x.y))
end
local function pointCost(x, sk)
  local p = chance(x, sk)
  if p <= 0 then return nil end
  local c = 0
  for _, m in ipairs(x.r) do c = c + m[2] * price(m[1]) end
  return c / (p * (x.k or 1))
end

local env = setmetatable({
  CALLER = "GoldFinder", AH_CUT = 0.05,
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return price(id) end } end,
  VendorPrice = function() return nil end,
  Counts = function() return 0, 0 end,
  Cfg = function(k) return ({ sellCap = 0 })[k] end,
  C_Item = { GetItemInfo = function() return nil end },
  UnitFactionGroup = function() return "Horde" end,
  GoldFinderDB = {}, GoldFinderRecipes = Recipes,
}, { __index = _G })

local function median(t)
  table.sort(t)
  return t[math.ceil(#t / 2)]
end

local keys = {}
for k, g in pairs(Guides) do if g.bands then keys[#keys + 1] = k end end
table.sort(keys)

print(string.format("%-16s %9s %9s %9s %9s %9s", "profession", "guide/plan", "worst", "plan/orcl", "worst", "uncovered"))
for _, key in ipairs(keys) do
  local g = Guides[key]
  local list = {}
  for _, x in pairs(Recipes.spells) do if x.s == g.line then list[#list + 1] = x end end
  local gp, po = {}, {}
  local uncovered = 0
  for s = 1, SCENARIOS do
    seed = s
    -- fresh planner per scenario (it caches prices per call)
    local PlanRoute = GF.NewRoutePlanner(env).PlanRoute
    local pd = { rank = 1, maxRank = 300, skillLine = g.line, crafts = {}, learned = {} }
    for _, x in ipairs(list) do pd.crafts[x.n] = { r = x.r, o = x.o, q = x.q }; pd.learned[x.n] = true end
    local plan = PlanRoute(g.name, pd, 300)
    local planCost, guideCost, oracleCost, ok = 0, 0, 0, true
    if not plan then ok = false else
      local byName = {}
      for _, x in ipairs(list) do byName[x.n] = x end
      for _, st in ipairs(plan.steps) do
        local x = byName[st.c.name]
        for sk = st.from, st.to - 1 do planCost = planCost + (x and pointCost(x, sk) or 0) end
      end
      for sk = 1, plan.to - 1 do
        local best
        for _, x in ipairs(list) do
          local c = pointCost(x, sk)
          if c and (not best or c < best) then best = c end
        end
        oracleCost = oracleCost + (best or 0)
        local band
        for _, b in ipairs(g.bands) do if b.f <= sk and sk < b.t then band = b end end
        local x = band and band.s and Recipes.spells[band.s]
        local c = x and pointCost(x, sk)
        if c then guideCost = guideCost + c else guideCost = nil; break end
      end
      if plan.to < 300 then uncovered = uncovered + 1 end
    end
    if ok and guideCost and planCost > 0 and oracleCost > 0 then
      gp[#gp + 1] = guideCost / planCost
      po[#po + 1] = planCost / oracleCost
    end
  end
  if #gp > 0 then
    local gw, pw = math.min(unpack(gp)), math.max(unpack(po))
    print(string.format("%-16s %9.2f %9.2f %9.3f %9.3f %9d", g.name, median(gp), gw, median(po), pw, uncovered))
  else
    print(string.format("%-16s (no comparable scenarios)", g.name))
  end
end
print("guide/plan: median cost of the fixed guide divided by the planner's (>1 means the planner is cheaper); worst = min.")
print("plan/orcl: planner cost divided by the per-point lower bound (1.000 = optimal for this model); worst = max.")
print("uncovered: scenarios where the planner route stopped before 300.")
