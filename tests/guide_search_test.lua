-- Offline tests for core/guide_search.lua (Lua 5.1): "what do I use this material for" in the profession guide.
-- Run from the addon folder:  lua tests/guide_search_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function read(p)
  local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n"))
end

local GF = {}
assert(loadfile("core/guide_search.lua"))("GoldFinderForever", GF)

local names = { [1] = "Light Leather", [2] = "Medium Leather", [3] = "Fine Thread", [4] = "Heavy Leather", [5] = "Coarse Thread" }
local function nameOf(id) return names[id] end
local spells = {
  [100] = { r = { { 1, 2 }, { 3, 1 } } },     -- Light Leather x2, Fine Thread
  [200] = { r = { { 2, 4 }, { 3, 1 } } },     -- Medium Leather x4, Fine Thread
  [300] = { r = { { 4, 3 }, { 5, 1 } } },     -- Heavy Leather x3, Coarse Thread
  [400] = { r = { { 99, 1 } } },              -- an item whose name is not loaded
}
local items = {
  { kind = "tip", text = "tip" },
  { band = { n = "Light Armor Kit" }, spell = 100, name = "a" },
  { band = { n = "Cured Medium Hide" }, spell = 200, name = "b" },
  { band = { n = "Heavy Leather Belt", s = 300 }, name = "c" },       -- spell only inside the band
  { band = { n = "Unknown" }, spell = 400, name = "d" },
  { band = { n = "No recipe" }, name = "e" },
  { kind = "section" },
}

local r = GF.GuideBandsUsing(items, spells, nameOf, "thread")
check("a material used by three steps finds three", #r == 3)
check("the steps keep the guide's order", r[1].name == "a" and r[2].name == "b" and r[3].name == "c")
check("it reports the material and quantity used", #r[1].uses == 1 and r[1].uses[1].name == "Fine Thread" and r[1].uses[1].qty == 1)
check("the spell can be read from the band", r[3].uses[1].name == "Coarse Thread")
check("tips, sections and steps without a recipe are dropped", #GF.GuideBandsUsing(items, spells, nameOf, "x") == 0)

r = GF.GuideBandsUsing(items, spells, nameOf, "leather")
check("part of a name matches several materials", #r == 3 and #r[1].uses == 1 and r[3].uses[1].name == "Heavy Leather")
check("the quantity per craft is kept", r[2].uses[1].qty == 4 and r[3].uses[1].qty == 3)
r = GF.GuideBandsUsing(items, spells, nameOf, "  HEAVY lea  ")
check("any case and surrounding spaces are fine", #r == 1 and r[1].name == "c")
check("an exact name works", #GF.GuideBandsUsing(items, spells, nameOf, "Medium Leather") == 1)
check("a material nobody uses finds nothing", #GF.GuideBandsUsing(items, spells, nameOf, "mithril") == 0)
check("an empty search is not a search", GF.GuideBandsUsing(items, spells, nameOf, "") == nil and GF.GuideBandsUsing(items, spells, nameOf, "   ") == nil and GF.GuideBandsUsing(items, spells, nameOf, nil) == nil)
check("a name that is not loaded yet simply does not match", #GF.GuideBandsUsing(items, spells, nameOf, "item") == 0)
check("the originals are not modified", items[2].uses == nil)
check("the copy keeps the other fields", GF.GuideBandsUsing(items, spells, nameOf, "fine")[1].spell == 100)
check("no list and no data do not fail", #GF.GuideBandsUsing(nil, spells, nameOf, "x") == 0 and #GF.GuideBandsUsing(items, nil, nameOf, "x") == 0)

local L = { ["gsearch.uses"] = "Uses: %s" }
check("the text lists materials with quantities", GF.UsesText({ { name = "Heavy Leather", qty = 3 }, { name = "Coarse Thread", qty = 1 } }, L) == "Uses: Heavy Leather x3, Coarse Thread x1")

-- wiring
local main = read("GoldFinder.lua")
local hyb = read("features/guide/hybrid.lua")
check("the file is in the toc", read("GoldFinderForever.toc"):find("core/guide_search.lua", 1, true) ~= nil)
check("the guide window has the search box", main:find('local sb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")', 1, true) ~= nil)
check("typing redraws the guide, Esc clears it", main:find("if user then f.query = txt; f.searchTries = 0; RefreshGuide() end", 1, true) ~= nil
  and main:find('self:SetText(""); self:ClearFocus(); f.query = ""; RefreshGuide()', 1, true) ~= nil)
check("the list is filtered after it is built", main:find("GF.GuideBandsUsing(items, GoldFinderRecipes and GoldFinderRecipes.spells, SearchName, f.query)", 1, true) ~= nil)
check("an unknown material name is asked for only once", main:find("if not askedSearch[id] and C_Item.RequestLoadItemDataByID then askedSearch[id] = true", 1, true) ~= nil)
check("a step shows which material it uses", hyb:find("if it.uses then", 1, true) ~= nil and hyb:find("GF.UsesText(it.uses, L)", 1, true) ~= nil)
for _, k in ipairs({ "gsearch.hint", "gsearch.found", "gsearch.none", "gsearch.uses" }) do
  check("both languages have " .. k, read("locales/enUS.lua"):find('["' .. k .. '"]', 1, true) ~= nil and read("locales/esES.lua"):find('["' .. k .. '"]', 1, true) ~= nil)
end

-- a name that was not loaded yet: the guide is drawn again a moment later, three times at most for what was typed
check("an unknown material name flags a retry", main:find("searchMissing = true", 1, true) ~= nil)
check("the retry is bounded and only while the same text is typed in an open guide", main:find("if f.searchTries < 3 then", 1, true) ~= nil
  and main:find("g and g:IsShown() and g.query == asked", 1, true) ~= nil and main:find("C_Timer.After(1.5, function()", 1, true) ~= nil)
check("typing resets the number of retries", main:find("f.searchTries = 0; RefreshGuide()", 1, true) ~= nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
