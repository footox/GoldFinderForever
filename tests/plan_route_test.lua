-- Offline tests for PlanRoute (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\plan_route_test.lua
-- Loads the planner from core/routeplanner.lua and runs it with stubbed WoW APIs.

local src = assert(io.open("GoldFinder.lua")):read("*a")
-- the planner lives in core/routeplanner.lua and gets its dependencies from the stubbed env below
local GF = {}
for _, path in ipairs({ "core/config.lua", "core/routeplanner.lua" }) do
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable({}, { __index = _G }))
  fn("GoldFinder", GF)
end

local prices, vendor, stock, faction = {}, {}, {}, "Horde"
local env = setmetatable({
  CALLER = "GoldFinder", AH_CUT = 0.05,
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return prices[id] end } end,
  VendorPrice = function(id) return vendor[id] end,
  Counts = function(id) return stock[id] or 0, 0 end,
  Cfg = function(k) return ({ sellCap = 5 })[k] end,
  C_Item = { GetItemInfo = function() return nil end },
  UnitFactionGroup = function() return faction end,
}, { __index = _G })

local function load()
  return GF.NewRoutePlanner(env).PlanRoute
end

-- Two recipes: "Known" (yellow 100, grey 130) is known; "Cheap" (orange until 110) is only at the trainer.
env.GoldFinderRecipes = { spells = {
  [1] = { n = "Known", s = 165, y = 100, g = 130, k = 1, r = { { 10, 10 } }, o = 20, q = 1 },
  [2] = { n = "Cheap", s = 165, y = 110, g = 140, k = 1, r = { { 11, 1 } }, o = 21, q = 1 },
} }
prices[10], prices[11] = 100, 50
local function pd() return { rank = 100, maxRank = 150, skillLine = 165,
  crafts = { Known = { r = { { 10, 10 } }, o = 20, q = 1 } }, learned = { Known = true } } end

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function names(plan)
  local t = {}
  for _, st in ipairs(plan.steps) do t[#t + 1] = st.c.name end
  return table.concat(t, ",")
end

-- 1. Without trainer data the route uses only known recipes (previous behaviour).
env.GoldFinderDB = {}
local PlanRoute = load()
local p = PlanRoute("Leatherworking", pd(), 110)
check("no trainer data: only known recipes", names(p) == "Known" and #p.learns == 0 and p.learnCost == 0)

-- 2. A cheaper trainer recipe available now is learned once and used; its cost is in the total.
env.GoldFinderDB = { trainerRecipes = { Horde = { Leatherworking = {
  cheap = { n = "Cheap", req = 100, cost = 300, npc = "Trainer", zone = "Orgrimmar", x = "1.0", y = "2.0" } } } } }
PlanRoute = load()
p = PlanRoute("Leatherworking", pd(), 110)
check("trainer recipe used", names(p) == "Cheap")
check("trainer recipe learned once", #p.learns == 1 and p.learns[1].t.n == "Cheap" and p.learns[1].at == 100)
check("learn cost added to total", p.learnCost == 300 and p.cost == 300 + 10 * 50)

-- 3. A trainer recipe is not used before the skill it requires.
env.GoldFinderDB.trainerRecipes.Horde.Leatherworking.cheap.req = 105
PlanRoute = load()
p = PlanRoute("Leatherworking", pd(), 110)
check("required skill respected", p.steps[1].c.name == "Known" and p.steps[1].to == 105 and p.learns[1].at == 105)

-- 4. A recipe already known is never offered as a trainer recipe.
local known = pd()
known.learned.Cheap = true
known.crafts.Cheap = { r = { { 11, 1 } }, o = 21, q = 1 }
p = PlanRoute("Leatherworking", known, 110)
check("known recipe not relearned", #p.learns == 0)

-- 5. Another faction's trainer data is ignored.
faction = "Alliance"
PlanRoute = load()
p = PlanRoute("Leatherworking", pd(), 110)
check("other faction ignored", #p.learns == 0)

os.exit(failures == 0 and 0 or 1)
