-- Offline tests for features/route/plan.lua (FarmCombos, RouteSummary). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\route_plan_feature_test.lua

local GF = { L = setmetatable({}, { __index = function(_, k) return k end }) }
GF.NoteText = function(n) return n end   -- the module reads the note and zone text through the locale helpers
GF.ZoneText = function(t) return t end
local fn = assert(loadfile("features/route/plan.lua"))
setfenv(fn, setmetatable({}, { __index = _G }))
fn("GoldFinder", GF)

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local guide = {
  { kind = "craft", st = { what = "Roast Raptors", upto = 225 }, mats = { { id = 1, have = 0, need = 5 }, { id = 2, have = 0, need = 5 } } },
  { kind = "craft", done = true, st = { what = "Done", upto = 100 }, mats = { { id = 3, have = 0, need = 5 } } },
}
local env = {
  GoldFinderForeverDB = { sources = {
    [1] = { ["The Barrens"] = { mob = "Raptor", n = 3 } },
    [2] = { ["The Barrens"] = { mob = "Raptor", n = 2 } },
    [3] = { ["Durotar"] = { mob = "Scorpid", n = 9 } },
  } },
  C_Item = { GetItemInfo = function(id) return "Item" .. id end },
  Char = function() return { prof = { Cooking = { rank = 200 } } } end,
  ProfOn = function() return true end,
  GuideKey = function() return "cooking" end,
  BuildGuide = function() return guide end,
  Skin = { Route = { NoRouteReason = function() return nil end } },
  Money = function(n) return tostring(n) end,
  Counts = function() return 0, 0 end,
  Sess = function() return { secs = 0, total = 0 } end,
  RouteFor = function() return nil end,
  GatherZones = function() return nil end,
  AnnotateZones = function(t) return t end,
  BuyPrice = function() return nil end,
  RefPrice = function() return nil end,
  AHApi = function() return nil end,
}
local P = GF.InitRoutePlan(env)

local combos = P.FarmCombos()
check("one combo: two materials share a spot", #combos == 1)
check("combo names the zone and mob", combos[1] and combos[1].zone == "The Barrens" and combos[1].mob == "Raptor")
check("combo lists both materials with their step", combos[1] and #combos[1].list == 2
  and combos[1].list[1] == "Item1 (Roast Raptors)")
check("done steps are ignored", not (combos[1] and combos[1].zone == "Durotar"))

env.GoldFinderForeverDB.sources = nil
check("no source data: no combos", #P.FarmCombos() == 0)

env.GoldFinderRoutes = nil
check("no routes: no summary", P.RouteSummary("Cooking", "cooking", { rank = 200, maxRank = 225 }) == nil)

env.GoldFinderRoutes = { cooking = { { name = "Guide A", zones = { { from = 1, to = 300, zone = "Durotar" } } } } }
local s = P.RouteSummary("Cooking", "cooking", { rank = 200, maxRank = 225 })
check("zone hint line is built for the current band", s == "plan.zones" or (s and s:find("plan.zones", 1, true) ~= nil))

if failures > 0 then os.exit(1) end
print("ALL PASS")
