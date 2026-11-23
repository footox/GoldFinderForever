-- Offline test for the tooltip line "Already known by" (Lua 5.1): it must appear whatever the advice is (keep, auction, vendor or no data)
-- and only once. The real TipAdvice and RecipeLines functions are taken from the main file and run against stubs.
-- Run from the addon folder:  lua tests/tooltip_known_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function read(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n")) end
local function loadCore(path, GF)
  local fn = assert(loadfile(path)); fn("GoldFinder", GF)
end

local GF = {}
loadCore("core/locale.lua", GF)
loadCore("locales/enUS.lua", GF)
loadCore("core/recipe_known.lua", GF)

local src = read("GoldFinder.lua")
-- a function ends at the first line that is just "end" in column 0
local function extract(startMarker)
  local a = assert(src:find(startMarker, 1, true), "start marker " .. startMarker)
  local b = assert(src:find("\nend\n", a, true), "end of " .. startMarker)
  return src:sub(a, b + 4)
end
local chunk = extract("local function RecipeLines(tooltip, id)") .. "\n" .. extract("local function TipAdvice(tooltip, data)") ..
  "\nreturn TipAdvice"

local function session(o)
  local S = { lines = {} }
  local tooltip = { AddLine = function(_, text) S.lines[#S.lines + 1] = text end }
  local env = setmetatable({
    GF = GF, L = GF.L, format = string.format, floor = math.floor, ipairs = ipairs, pairs = pairs, table = table, math = math, tostring = tostring,
    Cfg = function(k) if k == "crossChars" then return o.crossChars ~= false end if k == "tip" then return true end return nil end,
    Counts = function() return 1, 0 end,
    Money = function(c) return tostring(c) end,
    Decide = function() return o.decision end,
    RecipeForOthers = function() if o.isRecipe == false then return nil end return {}, o.knownBy end,
    OtherStock = function() return nil end, OtherNeed = function() return nil end, BankerName = function() return "Banker" end,
  }, { __index = _G })
  S.GF = GF
  GF.TooltipItemLink = function() return nil end
  GF.UnitsForAuction = function() return nil end
  GF.MarginFactor = function() return 1.1 end
  local fn = assert(loadstring(chunk))
  setfenv(fn, env)
  S.run = fn()
  S.tooltip = tooltip
  return S
end

local ME = { { name = "Twistice", mine = true, prof = "Cooking" } }
local KNOWN = GF.L["tip.recipeKnownBy"]:gsub("%%s", "you")
local function count(S) local n = 0 for _, l in ipairs(S.lines) do if l:find(KNOWN, 1, true) then n = n + 1 end end return n end

local verdicts = {
  KEEP = { verdict = "KEEP", reason = "keep it", ahNet = 0, vendor = 0, reserve = 0, sellQty = 1 },
  AH = { verdict = "AH", ahNet = 5000, vendor = 100, reserve = 0, sellQty = 1, unit = 5000 },
  VENDOR = { verdict = "VENDOR", ahNet = 100, vendor = 200, reserve = 0, sellQty = 1, unit = 200 },
  NONE = { verdict = "NONE", reason = "no data", ahNet = 0, vendor = 0, reserve = 0, sellQty = 0 },
}
for _, v in ipairs({ "KEEP", "AH", "VENDOR", "NONE" }) do
  local S = session({ decision = verdicts[v], knownBy = ME })
  S.run(S.tooltip, { id = 100 })
  check(v .. ": the tooltip says who already knows the recipe, once", count(S) == 1)
end

local S1 = session({ decision = verdicts.VENDOR, knownBy = { { name = "Twistice", mine = true }, { name = "Ashes", mine = false } } })
S1.run(S1.tooltip, { id = 100 })
check("it lists you and the others", (function() for _, l in ipairs(S1.lines) do if l:find("you, Ashes", 1, true) then return true end end return false end)())

local S2 = session({ decision = verdicts.VENDOR, isRecipe = false, knownBy = nil })
S2.run(S2.tooltip, { id = 100 })
check("an item that is not a recipe gets no such line", count(S2) == 0)

local S3 = session({ decision = verdicts.VENDOR, knownBy = {} })
S3.run(S3.tooltip, { id = 100 })
check("a recipe nobody knows yet gets no such line", count(S3) == 0)

local S4 = session({ decision = verdicts.VENDOR, knownBy = ME, crossChars = false })
S4.run(S4.tooltip, { id = 100 })
check("with the other-characters option off there is no such line", count(S4) == 0)

local S5 = session({ decision = verdicts.AH, knownBy = ME })
S5.run(S5.tooltip, { id = 100 })
check("the line comes after the advice, not before it", (function()
  local at, adv
  for i, l in ipairs(S5.lines) do
    if l:find(KNOWN, 1, true) then at = i end
    if l:find("GoldFinder", 1, true) then adv = adv or i end
  end
  return at and adv and at > adv
end)())

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
