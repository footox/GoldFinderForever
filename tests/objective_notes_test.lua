-- Offline tests for the objective tracker block and the recipe list notes (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\objective_notes_test.lua
-- ObjectiveBlock turns a NextStepList entry into the block the objective tracker draws (header and lines);
-- RecipeNoteText / RecipeNoteLines format the skill-up chance and the cost or gain per point of a recipe;
-- PlanRoute's plan.eff holds the planner's own cost per point of each recipe at the current skill.

local GF = {}
for _, path in ipairs({ "core/locale.lua", "locales/enUS.lua", "core/objective_text.lua" }) do
  local f = assert(loadfile(path))
  setfenv(f, setmetatable({}, { __index = _G }))
  f("GoldFinder", GF)
end
local ObjectiveBlock, RecipeNoteText, RecipeNoteLines = GF.ObjectiveBlock, GF.RecipeNoteText, GF.RecipeNoteLines

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
check("ready line", texts(block) == "Materials ready" and block.lines[1].kind == "ready")

-- 3. Unknown name: placeholder and waiting.
e.mats[1] = { id = 99, need = 2, have = 1 }
block, waiting = ObjectiveBlock(e, nameOf)
check("unknown name placeholder and waiting", texts(block) == "1/2 item 99" and waiting == true)

-- 4. A trainer recipe to learn comes first, then the rank trainer when due.
local learnText = function() return "aprendela con el instructor de la profesion: Craig (5)" end
e = { prof = "Cooking", rank = 176, from = 176, upto = 201, what = "Jungle Stew", qty = 25, mats = {},
  unknown = true, learn = { npc = "Craig" },
  train = { name = "Artisan", npc = "Ironforge Cook", zone = "Ironforge" }, trainState = "ready" }
block = ObjectiveBlock(e, nameOf, learnText)
check("learn line", block.lines[1].kind == "learn"
  and block.lines[1].text == "Learn: aprendela con el instructor de la profesion: Craig (5)")
check("train line", block.lines[2].kind == "train"
  and block.lines[2].text == "Train Artisan with Ironforge Cook (Ironforge)")
check("no ready line without materials", #block.lines == 2)
e.trainState = "blocked"
block = ObjectiveBlock(e, nameOf, learnText)
check("blocked rank (below the cap) is not due", #block.lines == 1)
e.trainState = "capblocked"
block = ObjectiveBlock(e, nameOf, learnText)
check("cap reached without requirements", block.lines[2].text
  == "Train Artisan with Ironforge Cook (Ironforge) when you meet the requirements")

-- 5. Gathering, train-only and auction-plan headers.
block = ObjectiveBlock({ gather = true, prof = "Mining", rank = 80, from = 65, upto = 125, zone = "Durotar", mats = {} }, nameOf)
check("gather header", block.header == "Mining 80 > 125: Durotar" and #block.lines == 0)
block = ObjectiveBlock({ trainOnly = true, prof = "Cooking", rank = 225, from = 225, upto = 225, mats = {},
  train = { name = "Artisan" }, trainState = "cap" }, nameOf)
check("train-only header", block.header == "Cooking 225: train the next rank"
  and texts(block) == "Train Artisan")
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
check("tooltip lines (gain)", lines[1] == "GoldFinder Forever: 100% chance to gain a point"
  and lines[2] == "Gain per point: 200c")
lines = RecipeNoteLines(0.5, 300, money)
check("tooltip lines (cost)", lines[2] == "Cost per point: 300c" and #lines == 2)
check("tooltip lines (no price)", #RecipeNoteLines(0.5, nil, money) == 1)

-- 7b. How many of the recipe the bags can make: "(4)" after the cost, and a tooltip line
check("count next to the chance", RecipeNoteText(1, nil, money, 4) == "100% (4)")
check("count after the cost", RecipeNoteText(0.5, 200, money, 3) == "50%" .. DOT .. "|cffff8080-200c|r (3)")
check("count after the gain", RecipeNoteText(1, -200.4, money, 12) == "100%" .. DOT .. "|cff80ff80+200c|r (12)")
check("count after 'no price'", RecipeNoteText(0.5, false, money, 2) == "50%" .. DOT .. "no price (2)")
check("zero, nil, negative and non-number counts add nothing", RecipeNoteText(1, nil, money, 0) == "100%"
  and RecipeNoteText(1, nil, money, nil) == "100%" and RecipeNoteText(1, nil, money, -3) == "100%"
  and RecipeNoteText(1, nil, money, "4") == "100%")
check("no chance: still no note, even with a count", RecipeNoteText(nil, 5, money, 4) == nil)
lines = RecipeNoteLines(1, -200, money, 4)
check("tooltip: the count is the last line", #lines == 3 and lines[3] == "You can make 4 with what is in your bags")
check("tooltip: no count line for zero or nil", #RecipeNoteLines(1, -200, money, 0) == 2 and #RecipeNoteLines(1, -200, money, nil) == 2)

local Craft = GF.CraftableCount
local have = { [1] = 7, [2] = 2, [3] = 100 }
local function count(id) return have[id] or 0 end
check("craftable: the scarcest reagent decides", Craft({ { 1, 2 }, { 2, 1 }, { 3, 5 } }, count) == 2)
check("craftable: a missing reagent gives 0", Craft({ { 1, 2 }, { 99, 1 } }, count) == 0)
check("craftable: whole crafts only", Craft({ { 1, 2 } }, count) == 3)
check("craftable: a single reagent", Craft({ { 3, 4 } }, count) == 25)
check("craftable: broken entries are ignored", Craft({ {}, "x", { 1 }, { 1, 0 }, { "a", 1 }, { 3, 10 } }, count) == 10)
check("craftable: nothing usable means unknown, not zero", Craft({ {}, "x" }, count) == nil and Craft({}, count) == nil)
check("craftable: no reagents or no counter is unknown", Craft(nil, count) == nil and Craft({ { 1, 1 } }, nil) == nil
  and Craft({ { 1, 1 } }, "x") == nil)
check("craftable: a counter that raises counts as none", Craft({ { 1, 1 } }, function() error("boom") end) == 0)
check("craftable: a counter that returns junk counts as none", Craft({ { 1, 1 } }, function() return "lots" end) == 0
  and Craft({ { 1, 1 } }, function() return -5 end) == 0 and Craft({ { 1, 1 } }, function() return nil end) == 0)

-- 7c. the wiring: the row notes pass the recipe and a fresh count, and the main file hands Counts over
local function read(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return (s:gsub("\13", "")) end
local tr, main = read("features/tracker/objectives.lua"), read("GoldFinder.lua")
check("the row note asks for the count of the recipe", tr:find("GF.RecipeNoteText(chance, eff, ShortMoney, CanMake(recipe))", 1, true) ~= nil)
check("the row tooltip asks for it too", tr:find("GF.RecipeNoteLines(chance, eff, ShortMoney, CanMake(recipe))", 1, true) ~= nil)
check("the recipe is kept in the cache but the count is not", tr:find("recipe = x }", 1, true) ~= nil
  and tr:find("count = ", 1, true) == nil)
check("the main file gives the tracker feature Counts", main:find("Counts = function(...) return Counts(...) end,\n  Char", 1, true) ~= nil
  or main:find("Char = function(...) return Char(...) end,\n  Counts = function(...) return Counts(...) end,", 1, true) ~= nil)
check("both languages have the new text", read("locales/enUS.lua"):find('["note.canMake"]', 1, true) ~= nil
  and read("locales/esES.lua"):find('["note.canMake"]', 1, true) ~= nil)

-- 8. PlanRoute records each recipe's cost per point at the current skill (plan.eff), from its own model.
-- the planner lives in core/routeplanner.lua and gets its dependencies from the stubbed env below
local GF = {}
for _, path in ipairs({ "core/config.lua", "core/routeplanner.lua" }) do
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable({}, { __index = _G }))
  fn("GoldFinder", GF)
end
local prices = { [10] = 100 }
local env = setmetatable({
  CALLER = "GoldFinder", AH_CUT = 0.05,
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return prices[id] end } end,
  VendorPrice = function() return nil end,
  Counts = function() return 0, 0 end,
  Cfg = function(k) return ({ sellCap = 5 })[k] end,
  C_Item = { GetItemInfo = function() return nil end },
  UnitFactionGroup = function() return "Horde" end,
  GoldFinderForeverDB = {},
  GoldFinderRecipes = { spells = { [1] = { n = "Known", s = 165, y = 100, g = 130, k = 1, r = { { 10, 10 } } } } },
}, { __index = _G })
local PlanRoute = GF.NewRoutePlanner(env).PlanRoute
local plan = PlanRoute("Leatherworking", { rank = 110, maxRank = 150, skillLine = 165,
  crafts = { Known = { r = { { 10, 10 } } } }, learned = { Known = true } }, 120)
-- at 110: chance (130-110)/(130-100) = 2/3; cost 10*100 = 1000 per craft, nothing to sell: 1000 / (2/3) = 1500
check("plan.eff cost per point", plan and plan.eff and math.abs((plan.eff.known or 0) - 1500) < 1e-6)

-- 8. Material icons, useful data and the friendly note when the guide proposes another recipe.
do
  local money = function(c) return c .. "c" end
  local ee = { prof = "Leatherworking", rank = 103, from = 103, upto = 105, what = "Fine Leather Belt", qty = 6,
    guide = "Light Leather Pants", chance = 0.4, missingCost = 250, mats = { { id = 10, need = 6, have = 0 } } }
  local b = ObjectiveBlock(ee, nameOf, nil, function() return 134400 end, money)
  check("material line carries its icon", b.lines[1].text == "|T134400:14|t 0/6 Tiger Meat")
  check("cost of what is missing", b.lines[2].kind == "info" and b.lines[2].text == "Missing materials: about 250c")
  check("chance per craft", b.lines[3].kind == "info" and b.lines[3].text == "Chance to level per craft: 40%")
  check("guide note is the last line", b.lines[#b.lines].kind == "note"
    and b.lines[#b.lines].text == "Cheaper than the guide (Light Leather Pants)")
  b = ObjectiveBlock(ee, nameOf)
  check("no icon provider: plain material line", b.lines[1].text == "0/6 Tiger Meat")
  check("no money formatter: no cost line", b.lines[2].text == "Chance to level per craft: 40%")
  ee.guide, ee.chance, ee.missingCost = nil, 1, nil
  b = ObjectiveBlock(ee, nameOf, nil, function() return nil end, money)
  check("sure skill-up, no guide difference: only the material, missing icon skipped",
    #b.lines == 1 and b.lines[1].text == "0/6 Tiger Meat")
  ee.mats[1].have = 6
  ee.guide, ee.missingCost = "Light Leather Pants", 0
  b = ObjectiveBlock(ee, nameOf, nil, nil, money)
  check("ready line then the note, no cost line when nothing is missing", #b.lines == 2
    and b.lines[1].kind == "ready" and b.lines[2].kind == "note")
end


print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
