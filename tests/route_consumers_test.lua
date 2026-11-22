-- Offline tests for the route planner consumers (Lua 5.1): next-step entry, keep-for-profession need, plan cache
-- and gathering zones. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\route_consumers_test.lua
-- Loads the planner from core/routeplanner.lua and runs it with stubbed WoW APIs.

local src = assert(io.open("GoldFinder.lua")):read("*a")
-- the planner lives in core/routeplanner.lua and gets its dependencies from the stubbed env below
local GF = {}
for _, path in ipairs({ "core/config.lua", "core/routeplanner.lua" }) do
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable({}, { __index = _G }))
  fn("GoldFinder", GF)
end

local prices, stock, suOwned, here = {}, {}, {}, nil
local countsCalls = 0
local cfg = { sellCap = 5, routeSpan = 25 }
local env = setmetatable({
  CALLER = "GoldFinder", AH_CUT = 0.05,
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return prices[id] end } end,
  VendorPrice = function() return nil end,
  Counts = function(id) countsCalls = countsCalls + 1; return stock[id] or 0, 0 end,
  Cfg = function(k) return cfg[k] end,
  C_Item = { GetItemInfo = function() return nil end },
  UnitFactionGroup = function() return "Horde" end,
  SuOwned = function(_, prof) return suOwned[prof] or false end,
  geterrorhandler = function() return function(err) error(err, 0) end end,
  GetRealZoneText = function() return here end,
  GoldFinderRecipes = { spells = {
    [1] = { n = "Known", s = 165, y = 100, g = 130, k = 1, r = { { 10, 10 } }, o = 20, q = 1 },
    [2] = { n = "Cheap", s = 165, y = 110, g = 140, k = 1, r = { { 11, 1 } }, o = 21, q = 1 },
  } },
  GoldFinderRoutes = {
    fishing = { { name = "Forever guides", steps = {}, zones = {
      { from = 1, to = 75, zone = "Durotar o Mulgore", note = "cualquier agua" },
    } } },
    mining = { { name = "Icy Veins", steps = {}, zones = {
      { from = 1, to = 65, zone = "Durotar, Mulgore o Tirisfal Glades", note = "cobre" },
      { from = 65, to = 125, zone = "Silverpine Forest o The Barrens", note = "estano" },
    } } },
    skinning = { { name = "Icy Veins", steps = {}, zones = { { from = 1, to = 75, zone = "Durotar" } } } },
  },
}, { __index = _G })

local function load()
  return GF.NewRoutePlanner(env)
end

prices[10], prices[11] = 100, 50
local function pd() return { rank = 100, maxRank = 150, skillLine = 165,
  crafts = { Known = { r = { { 10, 10 } }, o = 20, q = 1 } }, learned = { Known = true } } end
local TRAINER = { cheap = { n = "Cheap", req = 100, cost = 300, npc = "Trainer", zone = "Orgrimmar", x = "1.0", y = "2.0" } }

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

-- 1. Next step = first plan step: recipe, crafts, band and its materials (reagents x crafts, bags + bank).
env.GoldFinderForeverDB = {}
local M = load()
stock[10] = 7
local c = { prof = { Leatherworking = pd() }, off = {} }
local plan = M.RouteFor(c, "Leatherworking", 125)
local st = plan.steps[1]
local e = M.RouteStepEntry("Leatherworking", c.prof.Leatherworking, plan)
check("next step: recipe and crafts", e.what == "Known" and e.qty == st.n and e.qty > 0)
check("next step: band", e.from == 100 and e.upto == st.to and e.rank == 100)
check("next step: materials", #e.mats == 1 and e.mats[1].id == 10 and e.mats[1].need == 10 * st.n
  and e.mats[1].have == 7)
check("next step: known recipe has no learn info", not e.unknown and e.learn == nil)
check("next step: skill line kept", e.skillLine == 165)

-- 2. Trainer recipe as first step: unknown with trainer, zone, coordinates and cost.
env.GoldFinderForeverDB = { trainerRecipes = { Horde = { Leatherworking = TRAINER } } }
M = load()
c = { prof = { Leatherworking = pd() }, off = {} }
plan = M.RouteFor(c, "Leatherworking", 110)
e = M.RouteStepEntry("Leatherworking", c.prof.Leatherworking, plan)
check("trainer step: recipe", e.what == "Cheap" and e.mats[1].id == 11)
check("trainer step: learn info", e.unknown == true and e.learn and e.learn.npc == "Trainer"
  and e.learn.zone == "Orgrimmar" and e.learn.x == "1.0" and e.learn.y == "2.0" and e.learn.cost == 300
  and e.learn.trainer == true)
check("no plan: no entry", M.RouteStepEntry("Leatherworking", c.prof.Leatherworking, nil) == nil)

-- 3. Keep for profession: { need, upto, prof } from the plan materials; nil when the route does not use it.
env.GoldFinderForeverDB = {}
M = load()
c = { prof = { Leatherworking = pd() }, off = {} }
local z = M.RouteNeedFor(c, 10)
local p60 = M.RouteFor(c, "Leatherworking", 160)
local want, upto = nil, 0
for _, m in ipairs(p60.mats) do if m.id == 10 then want = m.need end end
for _, s in ipairs(p60.steps) do upto = math.max(upto, s.to) end
check("keep: need from plan mats", z and z.need == want and want > 0)
check("keep: upto and prof", z and z.upto == upto and z.prof == "Leatherworking")
check("keep: unused material is nil", M.RouteNeedFor(c, 999) == nil)
check("keep: returns a fresh table", M.RouteNeedFor(c, 10) ~= z)
c.off.Leatherworking = true
check("keep: profession turned off is nil", M.RouteNeedFor(c, 10) == nil)
c.off.Leatherworking = nil
suOwned.Leatherworking = true
check("keep: profession planned by SkillUp is nil", M.RouteNeedFor(c, 10) == nil)
suOwned.Leatherworking = nil
local g = { prof = { Mining = { rank = 50, maxRank = 75 }, Skinning = { rank = 10 } }, off = {} }
local okG, resG = pcall(M.RouteNeedFor, g, 2770)
check("keep: gathering professions do not error", okG and resG == nil)

-- 4. Plan cache: reused until invalidated or until skill / profession data change.
c = { prof = { Leatherworking = pd() }, off = {} }
local p1 = M.RouteFor(c, "Leatherworking", 125)
local before = countsCalls
local p2 = M.RouteFor(c, "Leatherworking", 125)
check("cache: same plan, no recompute", p1 == p2 and countsCalls == before)
M.InvalidateRoutes()
check("cache: invalidated", M.RouteFor(c, "Leatherworking", 125) ~= p1)
p1 = M.RouteFor(c, "Leatherworking", 125)
c.prof.Leatherworking.rank = 101
local p3 = M.RouteFor(c, "Leatherworking", 125)
check("cache: skill change recomputes", p3 ~= p1 and p3.from == 101)
c.prof.Leatherworking = pd()
check("cache: new profession data recomputes", M.RouteFor(c, "Leatherworking", 125) ~= p3)

-- 5. Gathering: Mining uses GoldFinderRoutes zones; Skinning has no next step here (task T5).
here = nil
e = M.GatherStepEntry("Mining", { rank = 70, skillLine = 186 })
check("mining: band and first zone", e and e.gather and e.from == 65 and e.upto == 125
  and e.zone == "Silverpine Forest" and e.note == "estano" and #e.mats == 0)
here = "The Barrens"
e = M.GatherStepEntry("Mining", { rank = 10 })
check("mining: current zone preferred, next band", e.zone == "Durotar" and e.nxt and e.nxt.zone == "The Barrens")
check("skinning: no gathering step", M.GatherStepEntry("Skinning", { rank = 10 }) == nil)
check("fishing: no gathering step by default", M.GatherStepEntry("Fishing", { rank = 10 }) == nil)
cfg.trackerGather = true
e = M.GatherStepEntry("Fishing", { rank = 10, skillLine = 356 })
check("fishing: option on gives the zone band", e and e.gather and e.zone == "Durotar" and e.upto == 75)
e = M.GatherStepEntry("Skinning", { rank = 10, skillLine = 393 })
check("skinning: option on gives its zone band", e and e.gather and e.zone == "Durotar" and e.upto == 75)
check("option on: crafting professions unaffected", M.GatherStepEntry("Leatherworking", { rank = 10 }) == nil)
check("option on does not change GatherZones (guide stays as is)", M.GatherZones("Fishing") == nil)
cfg.trackerGather = nil
check("mining past last band: nil", M.GatherStepEntry("Mining", { rank = 200 }) == nil)

os.exit(failures == 0 and 0 or 1)
