-- Offline tests for core/materials.lua (Lua 5.1): the categories of the Materials tab and the one it opens on.
-- Run from the addon folder:  lua tests/materials_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local GF = {}
assert(loadfile("core/materials.lua"))("GoldFinderForever", GF)
local CATS = GF.MATERIAL_CATEGORIES

-- the categories
check("four categories in a fixed order", #CATS == 4 and CATS[1].id == "leather" and CATS[2].id == "cloth"
  and CATS[3].id == "ore" and CATS[4].id == "herb")
check("lookup by id", GF.MaterialCategory("ore") == CATS[3] and GF.MaterialCategory("nope") == nil and GF.MaterialCategory(nil) == nil)

-- which items belong
check("leather is trade goods class 7, subclass 6", GF.MaterialMatches(CATS[1], 7, 6))
check("cloth is 7/5, ore 7/7, herbs 7/9", GF.MaterialMatches(CATS[2], 7, 5) and GF.MaterialMatches(CATS[3], 7, 7) and GF.MaterialMatches(CATS[4], 7, 9))
check("an item of another category does not match", not GF.MaterialMatches(CATS[1], 7, 5) and not GF.MaterialMatches(CATS[4], 7, 6))
check("another class does not match", not GF.MaterialMatches(CATS[1], 2, 6) and not GF.MaterialMatches(CATS[1], nil, nil))
check("no category does not match and does not raise", not GF.MaterialMatches(nil, 7, 6))
local seen, unique = {}, true
for _, c in ipairs(CATS) do local k = c.class .. ":" .. c.sub; if seen[k] then unique = false end; seen[k] = true end
check("no two categories share the same item subclass", unique)

-- the default for a character
local function prof(name, rank) return { [name] = { rank = rank } } end
local function merge(...) local out = {} for _, t in ipairs({ ... }) do for k, v in pairs(t) do out[k] = v end end return out end
check("a skinner opens on leather", GF.DefaultMaterialCategory(prof("Skinning", 100)).id == "leather")
check("a leatherworker opens on leather", GF.DefaultMaterialCategory(prof("Leatherworking", 50)).id == "leather")
check("a tailor opens on cloth", GF.DefaultMaterialCategory(prof("Tailoring", 20)).id == "cloth")
for _, p in ipairs({ "Mining", "Blacksmithing", "Engineering", "Jewelcrafting" }) do
  check(p .. " opens on ore", GF.DefaultMaterialCategory(prof(p, 10)).id == "ore")
end
check("an herbalist opens on herbs", GF.DefaultMaterialCategory(prof("Herbalism", 1)).id == "herb")
check("an alchemist opens on herbs", GF.DefaultMaterialCategory(prof("Alchemy", 1)).id == "herb")
check("the profession with the highest skill decides",
  GF.DefaultMaterialCategory(merge(prof("Skinning", 100), prof("Tailoring", 150), prof("Herbalism", 10))).id == "cloth")
check("a tie goes to the first category in the list",
  GF.DefaultMaterialCategory(merge(prof("Tailoring", 100), prof("Skinning", 100))).id == "leather")
check("two professions of the same category", GF.DefaultMaterialCategory(merge(prof("Mining", 80), prof("Blacksmithing", 90))).id == "ore")
check("professions with no material (cooking, fishing, first aid) fall back to leather",
  GF.DefaultMaterialCategory(merge(prof("Cooking", 150), prof("Fishing", 100), prof("First Aid", 200))).id == "leather")
check("a lowercase or longer profession name still matches", GF.DefaultMaterialCategory(prof("herbalism (journeyman)", 10)).id == "herb")
check("no professions, nil, a string or broken entries fall back to leather",
  GF.DefaultMaterialCategory({}).id == "leather" and GF.DefaultMaterialCategory(nil).id == "leather"
  and GF.DefaultMaterialCategory("x").id == "leather"
  and GF.DefaultMaterialCategory({ Mining = "bad", [5] = { rank = 3 }, Tailoring = {} }).id == "leather")

-- the choice made by hand
check("a valid choice wins over the professions", GF.CurrentMaterialCategory({ matCat = "herb", prof = prof("Skinning", 300) }).id == "herb")
check("an unknown choice is ignored", GF.CurrentMaterialCategory({ matCat = "gems", prof = prof("Tailoring", 5) }).id == "cloth")
check("no choice follows the professions", GF.CurrentMaterialCategory({ prof = prof("Mining", 5) }).id == "ore")
check("a character record without professions", GF.CurrentMaterialCategory({}).id == "leather" and GF.CurrentMaterialCategory(nil).id == "leather")

-- the selector
check("next goes forward and wraps", GF.NextMaterialCategory("leather", 1) == "cloth" and GF.NextMaterialCategory("herb", 1) == "leather")
check("previous goes back and wraps", GF.NextMaterialCategory("cloth", -1) == "leather" and GF.NextMaterialCategory("leather", -1) == "herb")
check("an unknown id starts from the first", GF.NextMaterialCategory("x", 1) == "cloth" and GF.NextMaterialCategory(nil, -1) == "herb")
local id, n = "leather", 0
repeat id = GF.NextMaterialCategory(id, 1); n = n + 1 until id == "leather" or n > 10
check("four steps come back to the start", n == 4)

-- wiring
local function read(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return (s:gsub("\13", "")) end
local toc, main, en, es = read("GoldFinderForever.toc"), read("GoldFinder.lua"), read("locales/enUS.lua"), read("locales/esES.lua")
check("the toc loads the module before the main file", toc:find("core/materials.lua", 1, true) ~= nil
  and toc:find("core/materials.lua", 1, true) < toc:find("GoldFinder.lua", 1, true))
check("the view uses the category helpers", main:find("GF.CurrentMaterialCategory(char)", 1, true) ~= nil
  and main:find("GF.NextMaterialCategory(cat.id, step)", 1, true) ~= nil and main:find("GF.MaterialMatches(cat, classID, subClassID)", 1, true) ~= nil)
check("the tab is labelled Materials", main:find('L["tab.materials"]', 1, true) ~= nil and main:find('L["tab.leather"]', 1, true) == nil)
check("the choice is saved per character, not as an option", main:find("Char().matCat =", 1, true) ~= nil)
for _, k in ipairs({ "tab.materials", "mat.category", "mat.leather", "mat.cloth", "mat.ore", "mat.herb", "mat.leather.h", "mat.cloth.h", "mat.ore.h",
  "mat.herb.h", "mat.leather.l", "mat.cloth.l", "mat.ore.l", "mat.herb.l", "win.matEmpty" }) do
  check("both languages have " .. k, en:find('["' .. k .. '"]', 1, true) ~= nil and es:find('["' .. k .. '"]', 1, true) ~= nil)
end
check("the old leather-only texts are gone", en:find('"tab.leather"', 1, true) == nil and en:find('"win.hLeather"', 1, true) == nil
  and en:find('"win.leatherEmpty"', 1, true) == nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
