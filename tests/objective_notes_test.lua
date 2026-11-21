-- Offline tests for the objective tracker block and the recipe list notes (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\objective_notes_test.lua
-- ObjectiveBlock turns a NextStepList entry into the block the objective tracker draws (header and lines);
-- RecipeNoteText / RecipeNoteLines format the skill-up chance and the cost or gain per point of a recipe;
-- PlanRoute's plan.eff holds the planner's own cost per point of each recipe at the current skill.

local src = assert(io.open("GoldFinder.lua")):read("*a")
local a = assert(src:find("-- TEXTOS DE OBJETIVOS Y RECETAS", 1, true), "start marker")
local b = assert(src:find("-- FIN DE TEXTOS DE OBJETIVOS Y RECETAS", 1, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn ObjectiveBlock, RecipeNoteText, RecipeNoteLines"
local f = assert(loadstring(chunk))
setfenv(f, setmetatable({}, { __index = _G }))
local ObjectiveBlock, RecipeNoteText, RecipeNoteLines = f()

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local names = { [10] = "Tiger Meat", [11] = "Soothing Spices" }
local function nameOf(id) return names[id] end
local function texts(block)
  local t = {}
  for _, l in ipairs(block.lines) do t[#t + 1] = l.text end
  return table.concat(t, "|")
end

-- 1. A route step: header "Cooking 176 > 201: Jungle Stew x25" and only the missing materials.
local e = { prof = "Cooking", rank = 176, from = 176, upto = 201, what = "Jungle Stew", qty = 25,
  mats = { { id = 10, need = 24, have = 0 }, { id = 11, need = 25, have = 30 } } }
local block, waiting = ObjectiveBlock(e, nameOf)
check("route header", block.header == "Cooking 176 > 201: Jungle Stew x25")
check("block id is the profession", block.id == "Cooking")
check("missing material line", texts(block) == "0/24 Tiger Meat")
check("material line kind and key", block.lines[1].kind == "mat" and block.lines[1].key == "m10")
check("all names known: not waiting", waiting == false)

-- 2. All materials in hand: one ready line.
e.mats[1].have = 24
block = ObjectiveBlock(e, nameOf)
check("ready line", texts(block) == "Materiales listos" and block.lines[1].kind == "ready")

-- 3. Unknown name: placeholder and waiting.
e.mats[1] = { id = 99, need = 2, have = 1 }
block, waiting = ObjectiveBlock(e, nameOf)
check("unknown name placeholder and waiting", texts(block) == "1/2 objeto 99" and waiting == true)

-- 4. A trainer recipe to learn comes first, then the rank trainer when due.
local learnText = function() return "aprendela con el instructor de la profesion: Craig (5)" end
e = { prof = "Cooking", rank = 176, from = 176, upto = 201, what = "Jungle Stew", qty = 25, mats = {},
  unknown = true, learn = { npc = "Craig" },
  train = { name = "Artisan", npc = "Ironforge Cook", zone = "Ironforge" }, trainState = "ready" }
block = ObjectiveBlock(e, nameOf, learnText)
check("learn line", block.lines[1].kind == "learn"
  and block.lines[1].text == "Aprende: aprendela con el instructor de la profesion: Craig (5)")
check("train line", block.lines[2].kind == "train"
  and block.lines[2].text == "Entrena Artisan con Ironforge Cook (Ironforge)")
check("no ready line without materials", #block.lines == 2)
e.trainState = "blocked"
block = ObjectiveBlock(e, nameOf, learnText)
check("blocked rank (below the cap) is not due", #block.lines == 1)
e.trainState = "capblocked"
block = ObjectiveBlock(e, nameOf, learnText)
check("cap reached without requirements", block.lines[2].text
  == "Entrena Artisan con Ironforge Cook (Ironforge) cuando cumplas los requisitos")

-- 5. Gathering, train-only and auction-plan headers.
block = ObjectiveBlock({ gather = true, prof = "Mining", rank = 80, from = 65, upto = 125, zone = "Durotar", mats = {} }, nameOf)
check("gather header", block.header == "Mining 80 > 125: Durotar" and #block.lines == 0)
block = ObjectiveBlock({ trainOnly = true, prof = "Cooking", rank = 225, from = 225, upto = 225, mats = {},
  train = { name = "Artisan" }, trainState = "cap" }, nameOf)
check("train-only header", block.header == "Cooking 225: entrena el siguiente rango"
  and texts(block) == "Entrena Artisan")
block = ObjectiveBlock({ game = true, prof = "Cooking", rank = 176, recipe = "Jungle Stew",
  mats = { { id = 10, need = 1, have = 0 } } }, nameOf)
check("auction plan header", block.header == "Cooking 176: Jungle Stew" and texts(block) == "0/1 Tiger Meat")

-- 6. At most five missing materials, then "...".
local many = {}
for i = 1, 7 do many[i] = { id = 10, need = i, have = 0 } end
block = ObjectiveBlock({ prof = "Cooking", rank = 1, upto = 2, what = "X", qty = 1, mats = many }, nameOf)
check("five materials then more", #block.lines == 6 and block.lines[6].text == "...")

-- 7. Recipe note text: chance and cost or gain per point with the given money formatter.
local money = function(c) return c .. "c" end
local DOT = " \194\183 "
check("chance only", RecipeNoteText(1, nil, money) == "100%")
check("cost per point", RecipeNoteText(0.5, 200, money) == "50%" .. DOT .. "|cffff8080-200c|r")
check("gain per point", RecipeNoteText(1, -200.4, money) == "100%" .. DOT .. "|cff80ff80+200c|r")
check("even", RecipeNoteText(0.25, 0.2, money) == "25%" .. DOT .. "0")
check("no chance: no note", RecipeNoteText(nil, 5, money) == nil)
check("grey recipe", RecipeNoteText(0, nil, money) == "0%")
local lines = RecipeNoteLines(1, -200, money)
check("tooltip lines (gain)", lines[1] == "GoldFinder Forever: 100% de subir un punto"
  and lines[2] == "Ganancia por punto: 200c")
lines = RecipeNoteLines(0.5, 300, money)
check("tooltip lines (cost)", lines[2] == "Coste por punto: 300c" and #lines == 2)
check("tooltip lines (no price)", #RecipeNoteLines(0.5, nil, money) == 1)

-- 8. PlanRoute records each recipe's cost per point at the current skill (plan.eff), from its own model.
local pa = assert(src:find("local recipeIdx", 1, true))
local pb = assert(src:find("-- FIN DEL PLANIFICADOR DE RUTA", 1, true))
local prices = { [10] = 100 }
local env = setmetatable({
  CALLER = "GoldFinder", AH_CUT = 0.05,
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return prices[id] end } end,
  VendorPrice = function() return nil end,
  Counts = function() return 0, 0 end,
  Cfg = function(k) return ({ sellCap = 5 })[k] end,
  C_Item = { GetItemInfo = function() return nil end },
  UnitFactionGroup = function() return "Horde" end,
  GoldFinderDB = {},
  GoldFinderRecipes = { spells = { [1] = { n = "Known", s = 165, y = 100, g = 130, k = 1, r = { { 10, 10 } } } } },
}, { __index = _G })
local pf = assert(loadstring(src:sub(pa, pb - 1) .. "\nreturn PlanRoute"))
setfenv(pf, env)
local PlanRoute = pf()
local plan = PlanRoute("Leatherworking", { rank = 110, maxRank = 150, skillLine = 165,
  crafts = { Known = { r = { { 10, 10 } } } }, learned = { Known = true } }, 120)
-- at 110: chance (130-110)/(130-100) = 2/3; cost 10*100 = 1000 per craft, nothing to sell: 1000 / (2/3) = 1500
check("plan.eff cost per point", plan and plan.eff and math.abs((plan.eff.known or 0) - 1500) < 1e-6)

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
