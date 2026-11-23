-- Offline tests for core/recipe_known.lua (Lua 5.1): which of your own characters already know a recipe.
-- Run from the addon folder:  lua tests/recipe_known_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function read(p)
  local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n"))
end

local GF = {}
assert(loadfile("core/recipe_known.lua"))("GoldFinderForever", GF)

local function norm(n) return (n:lower():gsub("^%s+", ""):gsub("%s+$", "")) end

local me = { prof = { Cooking = { learned = { ["Roast Raptor"] = true } }, Skinning = { learned = { ["Heavy Hide"] = true } } } }
local chars = {
  ["Twistice-Realm"] = me,
  ["Ashes-Realm"] = { prof = { Cooking = { learned = { ["Roast Raptor"] = true, ["Big Bear Steak"] = true } } } },
  ["Brann-Realm"] = { prof = { Cooking = { learned = { ["roast raptor"] = true } } } },
  ["Cleo-Realm"] = { prof = { Cooking = { learned = { ["Big Bear Steak"] = true } } } },
  ["Dora-Realm"] = { prof = { Cooking = { learned = { ["Roast Raptor"] = true } } }, off = { Cooking = true } },
  ["Eli-Realm"] = { prof = { Cooking = {} } },
  ["Broken"] = "not a table",
}

local r = GF.RecipeKnownBy(chars, me, "cooking", "roast raptor", norm)
check("three characters know it", #r == 3)
check("you come first", r[1].mine == true and r[1].name == "Twistice")
check("then the others in alphabetical order", r[2].name == "Ashes" and r[3].name == "Brann")
check("the realm is not part of the name", r[2].name == "Ashes")
check("the profession is reported", r[1].prof == "Cooking")
check("a character that does not know it is left out", (function() for _, k in ipairs(r) do if k.name == "Cleo" then return false end end return true end)())
check("a hidden profession is ignored", (function() for _, k in ipairs(r) do if k.name == "Dora" then return false end end return true end)())
check("a character without a recipe list is left out", (function() for _, k in ipairs(r) do if k.name == "Eli" then return false end end return true end)())
check("names are compared with the caller's normaliser", #GF.RecipeKnownBy(chars, me, "cooking", "big bear steak", norm) == 2)
check("another profession does not match", #GF.RecipeKnownBy(chars, me, "skinning", "roast raptor", norm) == 0)
check("nobody knows it: empty list", #GF.RecipeKnownBy(chars, me, "cooking", "nothing", norm) == 0)
check("no characters: empty list, no error", #GF.RecipeKnownBy(nil, me, "cooking", "x", norm) == 0)
check("the result does not depend on the table order", (function()
  for _ = 1, 5 do
    local x = GF.RecipeKnownBy(chars, me, "cooking", "roast raptor", norm)
    if x[1].name ~= "Twistice" or x[2].name ~= "Ashes" or x[3].name ~= "Brann" then return false end
  end
  return true
end)())

local L = { ["tip.recipeKnownBy"] = "Known by: %s", ["tip.recipeYou"] = "you" }
check("the text lists you and the others", GF.KnownByText(r, L) == "Known by: you, Ashes, Brann")
check("nobody: no text", GF.KnownByText({}, L) == nil and GF.KnownByText(nil, L) == nil)

-- wiring
local main = read("GoldFinder.lua")
local toc = read("GoldFinderForever.toc")
check("the file is in the toc, after its dependencies", toc:find("core/recipe_known.lua", 1, true) ~= nil)
check("RecipeForOthers returns the list of those who know it", main:find("return out, GF.RecipeKnownBy(GoldFinderForeverDB.chars, mine, key, target, NormRecipe)", 1, true) ~= nil)
check("the tooltip prints it", main:find("local list, knownBy = RecipeForOthers(id, true, true)", 1, true) ~= nil
  and main:find('tooltip:AddLine("  " .. known', 1, true) ~= nil)
local panel = read("features/vendor/panel.lua")
check("the tooltip still speaks when everybody already knows it", main:find("(#list == 0 and #(knownBy or {}) == 0)", 1, true) ~= nil)
check("the merchant box prints it", panel:find("GF.KnownByText(knownBy, L)", 1, true) ~= nil)
for _, k in ipairs({ "tip.recipeKnownBy", "tip.recipeYou" }) do
  check("both languages have " .. k, read("locales/enUS.lua"):find('["' .. k .. '"]', 1, true) ~= nil and read("locales/esES.lua"):find('["' .. k .. '"]', 1, true) ~= nil)
end
check("nothing is sent to anyone (no chat or mail call)", not read("core/recipe_known.lua"):find("SendChatMessage", 1, true) and not read("core/recipe_known.lua"):find("SendMail", 1, true))

-- the "you" of the recipe rows is localised, not a hard-coded Spanish word
check("the recipe rows use a localised 'you', not a hard-coded Spanish 'Tu'", not main:find('and "Tu" or', 1, true) and main:find('L["tip.recipeWhoYou"]', 1, true) ~= nil)
check("both languages have the 'you' of the rows, and it is not the same word", read("locales/enUS.lua"):find('["tip.recipeWhoYou"] = "You"', 1, true) ~= nil
  and read("locales/esES.lua"):find('["tip.recipeWhoYou"] = "Tu"', 1, true) ~= nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
