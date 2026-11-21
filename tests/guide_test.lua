-- Offline tests for GuideMerge (Lua 5.1): merges the static profession list (GoldFinderGuides) with the player's
-- state (skill, known recipes, recorded trainer recipes, live route plan, bags). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\guide_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")
local a = assert(src:find("-- MEZCLA DE LA GUIA", 1, true), "start marker")
local b = assert(src:find("-- FIN DE MEZCLA DE LA GUIA", 1, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn GuideMerge"
local f = assert(loadstring(chunk))
setfenv(f, setmetatable({}, { __index = _G }))
local GuideMerge = f()

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

-- Static list: three bands; the second is a trainer recipe with an estimated requirement, the third is item-taught.
local bands = {
  { f = 1, t = 30, s = 1, n = "Light Armor Kit", c = 30, l = "t", q = 1 },
  { f = 30, t = 60, s = 2, n = "Cured Light Hide", c = 30, l = "t", q = 30, a = true },
  { f = 60, t = 90, s = 3, n = "Fancy Gloves", c = 20, l = "i", i = 500, q = 55, o = 600, on = "Cheap Belt" },
}
local recipes = {
  [1] = { r = { { 10, 1 } } },
  [2] = { r = { { 11, 1 }, { 12, 1 } } },
  [3] = { r = { { 13, 4 } } },
}
local have = { [11] = 5 }
local prices = { [10] = 10, [11] = 100, [12] = 5, [13] = 50, [14] = 1 }
local function state(t)
  t.recipe = function(id) return recipes[id] end
  t.have = function(id) return have[id] or 0 end
  t.price = function(id) return prices[id] end
  t.known = t.known or {}
  t.trainer = t.trainer or {}
  return t
end

-- 1. Flags: bands below the skill are done, the band holding the skill is current, the rest upcoming.
local rows = GuideMerge(bands, state({ rank = 45 }))
check("three rows", #rows == 3)
check("band below skill done", rows[1].done and not rows[1].current and not rows[1].upcoming)
check("band holding skill current", rows[2].current and not rows[2].done and not rows[2].upcoming)
check("band above skill upcoming", rows[3].upcoming and not rows[3].done and not rows[3].current)

-- 2. Current band: remaining crafts scale with the skill left in the band; missing materials from bags.
-- 30 crafts over 30 points, 15 points left -> 15 crafts: 15 x item 11 (have 5), 15 x item 12 (have 0).
check("remaining crafts", rows[2].left == 15)
local m = {}
for _, x in ipairs(rows[2].mats) do m[x.id] = x end
check("mats need and have", m[11].need == 15 and m[11].have == 5 and m[12].need == 15 and m[12].have == 0)
check("missing listed", m[11].missing == 10 and m[12].missing == 15)
check("own cost from missing", rows[2].cost == 10 * 100 + 15 * 5)

-- 3. Approx flag kept for the estimated trainer requirement; exact for the others.
check("estimated requirement flagged", rows[2].approx == true and rows[2].req == 30)
check("exact item requirement", rows[3].approx == false and rows[3].req == 55 and rows[3].learn == "i" and rows[3].item == 500)
check("optional item recipe passed through", rows[3].opt and rows[3].opt.item == 600 and rows[3].opt.name == "Cheap Belt")

-- 4. Recorded trainer data overrides the estimate (requirement, cost, where).
rows = GuideMerge(bands, state({ rank = 45, trainer = {
  ["cured light hide"] = { n = "Cured Light Hide", req = 35, cost = 450, npc = "Kamari", zone = "Orgrimmar", x = "63.0", y = "45.0" } } }))
check("trainer override req", rows[2].req == 35 and rows[2].approx == false)
check("trainer record attached", rows[2].trainerRec and rows[2].trainerRec.npc == "Kamari" and rows[2].trainerRec.cost == 450)

-- 5. Known recipes are marked (no learn line needed).
rows = GuideMerge(bands, state({ rank = 45, known = { ["cured light hide"] = true } }))
check("known recipe", rows[2].known and not rows[3].known)

-- 6. Alternative from the live plan: a different recipe for the band's points, with its cost.
local plan = { steps = {
  { from = 45, to = 58, n = 13, c = { name = "Cheap Kit", cr = { r = { { 14, 2 } } } } },
  { from = 58, to = 60, n = 2, c = { name = "Cured Light Hide", cr = { r = { { 11, 1 }, { 12, 1 } } } } },
  { from = 60, to = 90, n = 20, c = { name = "Fancy Gloves", cr = { r = { { 13, 4 } } } } },
} }
rows = GuideMerge(bands, state({ rank = 45, plan = plan }))
check("alternative on current band", rows[2].alt and rows[2].alt.what == "Cheap Kit" and rows[2].alt.n == 13)
check("alternative cost from prices", rows[2].alt.cost == 13 * 2 * 1)
check("same recipe gives no alternative", rows[3].alt == nil)

-- 7. An alternative that is not cheaper than the static band is not offered.
prices[14] = 1000
rows = GuideMerge(bands, state({ rank = 45, plan = plan }))
check("dearer alternative hidden", rows[2].alt == nil)
prices[14] = 1

-- 8. Done bands get no alternative nor materials; skill at the top of a band moves to the next.
rows = GuideMerge(bands, state({ rank = 60, plan = plan }))
check("band ending at skill is done", rows[2].done and rows[2].alt == nil and rows[2].mats == nil)
check("next band current at its start", rows[3].current and rows[3].left == 20)

os.exit(failures == 0 and 0 or 1)
