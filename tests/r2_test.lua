-- Offline tests for the R2 planner consistency fixes (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\r2_test.lua
-- Loads the planner block ("local recipeIdx" .. "FIN DEL PLANIFICADOR DE RUTA"), the route helpers
-- ("AYUDAS DE RUTA" .. "FIN DE AYUDAS DE RUTA") and the recipe note texts, with stubbed WoW APIs.

local src = assert(io.open("GoldFinder.lua")):read("*a")
local function block(from, to, tail)
  local a = assert(src:find(from, 1, true), "start marker " .. from)
  local b = assert(src:find(to, a, true), "end marker " .. to)
  return src:sub(a, b - 1) .. tail
end

-- the planner lives in core/routeplanner.lua and gets its dependencies from the stubbed env below
local GF = {}
for _, path in ipairs({ "core/config.lua", "core/routeplanner.lua" }) do
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable({}, { __index = _G }))
  fn("GoldFinder", GF)
end

local prices, vendor, vendorBuy, stock, faction, cfg, surplus, bound = {}, {}, {}, {}, "Horde", { sellCap = 5 }, {}, {}
local env = setmetatable({
  CALLER = "GoldFinder", AH_CUT = 0.05, format = string.format,
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return prices[id] end } end,
  VendorPrice = function(id) return vendor[id] end,
  Counts = function(id) return stock[id] or 0, 0 end,
  Cfg = function(k) return cfg[k] end,
  C_Item = { GetItemInfo = function(id) if bound[id] then return "x", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, 1 end return nil end },
  UnitFactionGroup = function() return faction end,
  SuOwned = function() return false end,
  geterrorhandler = function() return function(err) error(err, 0) end end,
  GetRealZoneText = function() return nil end,
  SellQty = function(id, withBank) return surplus[id] or 0 end,
  Money = function(c) return tostring(math.floor(c + 0.5)) .. "c" end,
  Skin = {},
  GoldFinderRecipes = { spells = {
    [1] = { n = "Known", s = 165, y = 100, g = 130, k = 1, r = { { 10, 10 } }, o = 20, q = 1 },
    [2] = { n = "Cheap", s = 165, y = 110, g = 140, k = 1, r = { { 11, 1 } }, o = 21, q = 1 },
    [3] = { n = "Bolt", s = 197, y = 100, g = 130, k = 1, r = { { 10, 20 } }, o = 30, q = 1 },
    [4] = { n = "Batch", s = 165, y = 100, g = 130, k = 1, r = { { 12, 1 } }, o = 22, q = 5 },
  } },
}, { __index = _G })
local function load(chunk)
  local f = assert(loadstring(chunk))
  setfenv(f, env)
  return f()
end
local function loadPlanner()
  return GF.NewRoutePlanner(env)
end
local function loadHelpers()
  local P = loadPlanner()
  env.RecipeLookup, env.BuyPrice, env.SellValue = P.RecipeLookup, P.BuyPrice, P.SellValue
  env.Skin = {}
  load(block("-- AYUDAS DE RUTA", "-- FIN DE AYUDAS DE RUTA", "\nreturn nil"))
  return env.Skin.Route, P
end

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function lw() return { rank = 100, maxRank = 150, skillLine = 165,
  crafts = { Known = { r = { { 10, 10 } }, o = 20, q = 1 } }, learned = { Known = true } } end
local function joined(lines) return table.concat(lines or {}, "\n") end

prices[10], prices[11], prices[12] = 100, 50, 10

-- 1. Truncated route: "Known" turns grey at 130, so a 150 target stops at 130.
env.GoldFinderDB = {}
local P = loadPlanner()
local p = P.PlanRoute("Leatherworking", lw(), 150)
check("1 truncated: to < target", p and p.to == 130 and p.target == 150 and p.truncated == true)
p = P.PlanRoute("Leatherworking", lw(), 120)
check("1 complete route not truncated", p and p.to == 120 and p.truncated == false)

-- 3. Learn cost amortization does not depend on the target: every view picks the same first recipe.
env.GoldFinderDB = { trainerRecipes = { Horde = { Leatherworking = {
  cheap = { n = "Cheap", req = 100, cost = 30000, npc = "T", zone = "Z" } } } } }
P = loadPlanner()
local short = P.PlanRoute("Leatherworking", lw(), 101)
local long = P.PlanRoute("Leatherworking", lw(), 140)
check("3 same recipe for short and long targets", short.steps[1].c.name == long.steps[1].c.name
  and short.steps[1].c.name == "Cheap")

-- 7. Unpriced reagent: no 1e7 penalty in plan.eff (false = "sin precio"); priced recipe keeps its number.
env.GoldFinderDB = {}
P = loadPlanner()
local pdU = lw()
pdU.crafts.Cheap = { r = { { 13, 1 } }, o = 21, q = 1 }   -- item 13 has no price at all
env.GoldFinderRecipes.spells[2].r = { { 13, 1 } }
p = P.PlanRoute("Leatherworking", pdU, 105)
check("7 unpriced recipe eff is false", p and p.eff.cheap == false)
check("7 priced recipe eff is a number", p and type(p.eff.known) == "number" and p.eff.known < 1e6)
env.GoldFinderRecipes.spells[2].r = { { 11, 1 } }
local notes = load(block("-- TEXTOS DE OBJETIVOS Y RECETAS", "-- FIN DE TEXTOS DE OBJETIVOS Y RECETAS",
  "\nreturn { text = RecipeNoteText, lines = RecipeNoteLines }"))
local money = function(c) return c .. "c" end
check("7 note text says sin precio", (notes.text(1, false, money) or ""):find("sin precio", 1, true) ~= nil)
check("7 note tooltip says sin precio", (notes.lines(1, false, money)[2] or ""):find("sin precio", 1, true) ~= nil)
check("7 note text without plan unchanged", notes.text(1, nil, money) == "100%")

-- 8. sellCap counts units: a recipe giving 5 items sells only 5 units at AH price in total.
env.GoldFinderDB = {}
P = loadPlanner()
prices[22] = 1000
p = P.PlanRoute("Leatherworking", { rank = 100, maxRank = 150, skillLine = 165,
  crafts = { Batch = { r = { { 12, 1 } }, o = 22, q = 5 } }, learned = { Batch = true } }, 110)
-- 12 crafts x 5 = 60 units; 5 at 1000 * 0.95, the rest at vendor price 0
check("8 cap in units", p and p.steps[1].n > 5 and p.steps[1].ahUnits == 5 and math.abs(p.sell - 5 * 950) < 1e-6)

-- 6. Own reserve: the profession that needs most, whatever the pairs order.
env.GoldFinderDB = {}
P = loadPlanner()
local c = { off = {}, prof = {
  Leatherworking = lw(),
  Tailoring = { rank = 100, maxRank = 150, skillLine = 197, crafts = { Bolt = { r = { { 10, 20 } }, o = 30, q = 1 } },
    learned = { Bolt = true } },
} }
local z = P.RouteNeedFor(c, 10)
local tp = P.RouteFor(c, "Tailoring", 160)
local tneed
for _, m in ipairs(tp.mats) do if m.id == 10 then tneed = m.need end end
check("6 max need across professions", z and z.prof == "Tailoring" and z.need == tneed)

-- Helpers block
local RK
RK, P = loadHelpers()
check("helpers block loads", type(RK) == "table")

-- 2. Recipe learned at the trainer: only its profession, and the route keeps using it.
env.GoldFinderDB = { trainerRecipes = { Horde = { Leatherworking = {
  cheap = { n = "Cheap", req = 100, cost = 300, npc = "T", zone = "Z" } } } } }
RK, P = loadHelpers()
c = { off = {}, prof = { Leatherworking = lw(),
  Tailoring = { rank = 100, maxRank = 150, skillLine = 197, crafts = {}, learned = { Bolt = true } } } }
local who = RK.LearnRecipe(c, 2, "Cheap", "Horde")
check("2 only the owning profession", who == "Leatherworking" and c.prof.Leatherworking.learned.Cheap
  and not c.prof.Tailoring.learned.Cheap)
local cr = c.prof.Leatherworking.crafts.Cheap
check("2 crafts entry from GoldFinderRecipes", cr and cr.o == 21 and cr.q == 1 and cr.r[1][1] == 11 and cr.r[1][2] == 1)
p = P.PlanRoute("Leatherworking", c.prof.Leatherworking, 110)
check("2 route keeps using the learned recipe", p and p.steps[1].c.name == "Cheap" and #p.learns == 0)
c = { off = {}, prof = { Leatherworking = lw() } }
check("2 by name via trainer record", RK.LearnRecipe(c, nil, "Cheap", "Horde") == "Leatherworking"
  and c.prof.Leatherworking.crafts.Cheap ~= nil)
c = { off = {}, prof = { Leatherworking = { rank = 1, skillLine = 165, learned = {} } } }
RK.LearnRecipe(c, 2, "Cheap", "Horde")
check("2 never opened: crafts stays nil", c.prof.Leatherworking.crafts == nil and c.prof.Leatherworking.learned.Cheap)

-- 5. Crafting profession without a plan: reason text.
check("5 at cap", RK.NoRouteReason({ rank = 150, maxRank = 150, crafts = {} }) == "Entrena el siguiente rango para seguir")
check("5 never opened", RK.NoRouteReason({ rank = 50, maxRank = 75 }) == "Abre la ventana de la profesion una vez")

-- 1. Compras text for a truncated route.
check("1 cap reason", RK.CapReason({ truncated = true, to = 130, cap = 150 })
  == "ruta hasta 130 (faltan recetas para llegar a 150: visita al instructor)")
check("1 cap reason complete", RK.CapReason({ truncated = false, to = 150, cap = 150 }) == nil)

-- 4. Route comparison: truncated own route and unknown prices never declare a winner.
local other = { name = "Icy Veins", cost = 5000, unknown = 0, rows = {} }
local lines, best = RK.RouteVerdict({ name = "Tu ruta", cost = 1000, unknown = 0, sell = 0, truncated = true, to = 130 },
  { other }, 150)
local txt = joined(lines)
check("4 truncated: says it only reaches to", txt:find("tu ruta solo llega a 130", 1, true) ~= nil
  and not txt:find("Conviene", 1, true))
lines = RK.RouteVerdict({ name = "Tu ruta", cost = 1000, unknown = 1, sell = 0, to = 150 }, { other }, 150)
txt = joined(lines)
check("4 unknown prices: no winner", txt:find("sin precio", 1, true) ~= nil and not txt:find("Conviene", 1, true))
lines, best = RK.RouteVerdict({ name = "Tu ruta", cost = 1000, unknown = 0, sell = 0, to = 150 }, { other }, 150)
check("4 priced and complete: own route wins", joined(lines):find("Conviene |cffffd100tu ruta|r", 1, true) ~= nil
  and best and best.name == "Tu ruta")

-- 9. Fabricar: buy prices from BuyPrice (vendor), no price = "sin precio", gain when buying, capped total.
env.GoldFinderDB = { vendorBuy = { [40] = 20 } }
RK = loadHelpers()
prices[50] = 1000
local r = RK.CraftProfit({ r = { { 40, 2 } }, o = 50, q = 1 })
check("9b vendor-sold reagent priced", r.gainBuy and math.abs(r.gainBuy - (950 - 40)) < 1e-6 and not r.noPrice)
check("9a no materials owned: n == 0", r.n == 0)
r = RK.CraftProfit({ r = { { 41, 1 } }, o = 50, q = 1 })
check("9b no price at all: sin precio", r.noPrice == true and r.gainBuy == nil)
surplus[40] = 20   -- 10 crafts possible with the surplus; reserved units are not in SellQty
stock[40] = 100
r = RK.CraftProfit({ r = { { 40, 2 } }, o = 50, q = 1 })
check("9c only surplus counts", r.n == 10)
-- 5 at AH (950), 5 at vendor (0); materials sold value 0 (no AH, no vendor sell price)
check("9c total capped at sellCap units", math.abs(r.total - 5 * 950) < 1e-6)

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
