-- Offline tests for core/trainer_marks.lua (Lua 5.1): what a trainer teaches that the guide still needs.
-- Run from the addon folder:  lua tests/trainer_marks_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local GF = {}
assert(loadfile("core/trainer_marks.lua"))("GoldFinderForever", GF)

-- WantedRecipes: the craft items of the guide that are not done
local items = {
  { kind = "craft", done = false, st = { what = "Light Leather Pants" } },
  { kind = "craft", done = true, st = { what = "Rugged Leather Pants" } },
  { kind = "train", done = false, st = { what = "Journeyman" } },
  { kind = "gather", done = false, st = { what = "Fishing" } },
  { kind = "craft", done = false, st = {} },
  { kind = "craft", done = false },
  "garbage",
  { kind = "craft", done = false, st = { what = "Fine Leather Boots" } },
}
local w = GF.WantedRecipes(items)
check("wanted: the craft items still ahead, lower case", w["light leather pants"] and w["fine leather boots"])
check("wanted: done items, trainers, gathering and broken entries are left out",
  not w["rugged leather pants"] and not w["journeyman"] and not w["fishing"])
check("wanted: nil, a string or an empty list give an empty set",
  next(GF.WantedRecipes(nil)) == nil and next(GF.WantedRecipes("x")) == nil and next(GF.WantedRecipes({})) == nil)

-- TrainerMarks
local recs = {
  { n = "Fine Leather Boots", req = 90, cost = 250 },
  { n = "Light Leather Pants", req = 100, cost = 500 },
  { n = "Dark Leather Belt", req = 120, cost = 1000 },
  { n = "Embossed Leather Cloak", req = 100, cost = 800 },
  { n = "Cured Medium Hide", req = 1, cost = 0 },
}
local wanted = { ["fine leather boots"] = true, ["light leather pants"] = true, ["dark leather belt"] = true, ["cured medium hide"] = true }
local known = { ["cured medium hide"] = true }
local m = GF.TrainerMarks(recs, wanted, known)
check("marks: used recipes are the wanted ones the player does not know", #m.used == 3)
check("marks: ordered by required skill", m.used[1].name == "Fine Leather Boots" and m.used[2].name == "Light Leather Pants"
  and m.used[3].name == "Dark Leather Belt")
check("marks: the total is the sum of their costs", m.usedCost == 1750 and m.unpriced == 0)
check("marks: a recipe not in the guide counts as other", m.others == 1)
check("marks: a recipe already known is counted apart and never used", m.knownN == 1)

local m2 = GF.TrainerMarks({ { n = "A", req = 5 }, { n = "B", req = 5, cost = 30 }, { n = "C", req = 5, cost = -4 }, { n = "D", req = "x", cost = "y" } },
  { a = true, b = true, c = true, d = true }, {})
check("marks: a recipe without a price is listed and counted as unpriced", #m2.used == 4 and m2.unpriced == 3 and m2.usedCost == 30)
check("marks: a missing or odd requirement sorts last", m2.used[4].name == "D" and m2.used[4].req == nil)
local m3 = GF.TrainerMarks({ { n = "Zeta", req = 10, cost = 1 }, { n = "Alpha", req = 10, cost = 1 } }, { zeta = true, alpha = true }, {})
check("marks: the same skill orders by name", m3.used[1].name == "Alpha" and m3.used[2].name == "Zeta")
local m4 = GF.TrainerMarks({ "x", {}, { n = 5 }, { n = "" }, { n = "Real", req = 3, cost = 9 } }, { real = true }, {})
check("marks: broken records are ignored", #m4.used == 1 and m4.others == 0 and m4.knownN == 0)
local m5 = GF.TrainerMarks(nil, nil, nil)
check("marks: nothing at all is an empty result", #m5.used == 0 and m5.others == 0 and m5.knownN == 0 and m5.usedCost == 0)
check("marks: wrong argument types do not raise", #GF.TrainerMarks("x", 5, "y").used == 0)
check("marks: matching ignores the case of the recorded name", #GF.TrainerMarks({ { n = "FINE LEATHER BOOTS", req = 1, cost = 1 } }, wanted, {}).used == 1)

-- TrainerPanelLines
local L = setmetatable({
  ["tm.item"] = "- %s (skill %d) %s", ["tm.itemNoReq"] = "- %s %s", ["tm.noPrice"] = "no price", ["tm.total"] = "Total: %s",
  ["tm.none"] = "Nothing here.", ["tm.others"] = "%d others.", ["tm.known"] = "%d known.",
}, { __index = function(_, k) return k end })
local function money(c) return c .. "c" end
local sec = { { prof = "Leatherworking", recs = recs, wanted = wanted, known = known } }
local lines = GF.TrainerPanelLines(sec, L, money)
check("panel: heading, three recipes, total, others and known", #lines == 7 and lines[1] == "|cffffd24dLeatherworking|r")
check("panel: each recipe says its skill and cost", lines[2] == "- Fine Leather Boots (skill 90) 250c" and lines[4] == "- Dark Leather Belt (skill 120) 1000c")
check("panel: the total", lines[5] == "Total: 1750c")
check("panel: the counts of others and known are dimmed", lines[6] == "|cff9aa0a61 others.|r" and lines[7] == "|cff9aa0a61 known.|r")
local none = GF.TrainerPanelLines({ { prof = "Cooking", recs = { { n = "X", req = 1, cost = 1 } }, wanted = {}, known = {} } }, L, money)
check("panel: nothing used says so and still counts the others", none[2] == "Nothing here." and none[3] == "|cff9aa0a61 others.|r")
local np = GF.TrainerPanelLines({ { prof = "P", recs = { { n = "Free", req = 7 } }, wanted = { free = true }, known = {} } }, L, money)
check("panel: no price is said, and there is no total of nothing", np[2]:find("no price", 1, true) and #np == 2)
local nr = GF.TrainerPanelLines({ { prof = "P", recs = { { n = "NoReq", cost = 4 } }, wanted = { noreq = true }, known = {} } }, L, money)
check("panel: a recipe with no requirement uses the short form", nr[2] == "- NoReq 4c")
local esc = GF.TrainerPanelLines({ { prof = "A|cffff0000B", recs = { { n = "Ev|il", req = 1, cost = 1 } }, wanted = { ["ev|il"] = true }, known = {} } }, L, money)
check("panel: a | in a game name never starts a colour code", esc[1] == "|cffffd24dA||cffff0000B|r" and esc[2] == "- Ev||il (skill 1) 1c")
check("panel: two professions give two blocks", #GF.TrainerPanelLines({ sec[1], sec[1] }, L, money) == 14)
check("panel: no sections, nil or a string give no lines", #GF.TrainerPanelLines({}, L, money) == 0 and #GF.TrainerPanelLines(nil, L, money) == 0
  and #GF.TrainerPanelLines("x", L, money) == 0)

-- wiring
local function read(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return (s:gsub("\13", "")) end
local toc, main, en, es = read("GoldFinderForever.toc"), read("GoldFinder.lua"), read("locales/enUS.lua"), read("locales/esES.lua")
check("the toc loads the core before the panel and both before the main file", toc:find("core/trainer_marks.lua", 1, true)
  and toc:find("features/trainer/marks.lua", 1, true)
  and toc:find("core/trainer_marks.lua", 1, true) < toc:find("features/trainer/marks.lua", 1, true)
  and toc:find("features/trainer/marks.lua", 1, true) < toc:find("GoldFinder.lua", 1, true))
check("the main file starts the panel with the trainer sections", main:find("GF.InitTrainerMarks({", 1, true) ~= nil
  and main:find("local function TrainerSections()", 1, true) ~= nil and main:find("GF.WantedRecipes(", 1, true) ~= nil)
check("the option is on by default and on both option pages", read("core/config.lua"):find("trainerMarks = true", 1, true) ~= nil
  and main:find('{ "trainerMarks", L["set.trainerMarks"] }', 1, true) ~= nil and main:find('check("trainerMarks"', 1, true) ~= nil)
for _, k in ipairs({ "tm.title", "tm.item", "tm.itemNoReq", "tm.noPrice", "tm.total", "tm.none", "tm.others", "tm.known", "tm.fail",
  "set.trainerMarks", "opt.trainerMarks.l", "opt.trainerMarks.t" }) do
  check("both languages have " .. k, en:find('["' .. k .. '"]', 1, true) ~= nil and es:find('["' .. k .. '"]', 1, true) ~= nil)
end

-- the panel must be started AFTER the local function it is handed: a closure only sees the locals declared before it, so an
-- earlier call would reach for a nil global (and the pcall around the panel hid it)
local defAt = main:find("local function TrainerSections()", 1, true)
local callAt = main:find("GF.InitTrainerMarks({", 1, true)
check("TrainerSections is defined before the panel is started", defAt ~= nil and callAt ~= nil and defAt < callAt)
check("the panel is started once", select(2, main:gsub("GF.InitTrainerMarks%(", "")) == 1)
check("the panel gets a way to print its errors", main:find("Print = function(...) return Print(...) end,\n})", callAt or 1, true) ~= nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
