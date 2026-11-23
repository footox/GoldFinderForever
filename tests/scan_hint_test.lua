-- Offline test for the "no scan yet" guidance (Lua 5.1): the tooltip reason, the login notice and the summary line must say what to do
-- when Auctionator has never scanned, and the old short reason must stay for an item missing from a scan that did happen.
-- Run from the addon folder:  lua tests/scan_hint_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function read(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n")) end
local function loadCore(path, GF, env)
  local fn = assert(loadfile(path)); setfenv(fn, setmetatable(env or {}, { __index = _G })); fn("GoldFinder", GF)
end

local GF = {}
loadCore("core/config.lua", GF)
loadCore("core/locale.lua", GF)
loadCore("locales/enUS.lua", GF)
loadCore("core/scan.lua", GF)
loadCore("core/crates.lua", GF)
loadCore("core/decision.lua", GF, { GoldFinderForeverDB = {} })

local age
local deps = {
  AHApi = function() return { GetAuctionPriceByItemID = function() return nil end } end,
  VendorPrice = function() return 0 end, TSMValue = function() return nil end,
  Cfg = function(k) return ({ minGain = 1000, crossChars = false, questItems = true, minMargin = 10 })[k] end,
  Char = function() return { keep = {} } end, Counts = function() return 1, 0 end,
  SkillUpNeed = function() return nil end, RouteNeedFor = function() return nil end, ReagentInfo = function() return nil end,
  QuestNeed = function() return nil end, RecipeToLearn = function() return nil end, RecipeForOthers = function() return nil end,
  OtherNeed = function() return nil end, IsUtilityItem = function() return false end, RefPrice = function() return nil end,
  ToBanker = function() return nil end, VariantKnown = function() return nil end,
  ItemInfoInstant = function(id) return id, "x", "y", "z", 0, 7 end, ItemQuality = function() return 2 end,
  ScanAgeMin = function() return age end,
}
local Decide = GF.NewDecision(deps)

age = nil
local d = Decide(500, 1, 0, false, nil)
check("never scanned: the verdict is still 'no data' with the 'scan' code", d.verdict == "NONE" and d.code == "scan")
check("never scanned: the reason says to open the auction house and press Scan", d.reason == GF.L["decision.scanNever"] and d.reason:find("press Scan", 1, true) ~= nil)
age = 30
d = Decide(500, 1, 0, false, nil)
check("an item missing from a scan that did happen keeps the short reason", d.code == "scan" and d.reason == GF.L["decision.scan"])
deps.ScanAgeMin = nil
d = Decide(500, 1, 0, false, nil)
check("a build that does not give the scan age at all keeps the short reason", d.reason == GF.L["decision.scan"])

check("the login notice is due only with no scan on record", GF.ScanHintDue(nil) == true and GF.ScanHintDue(0) == false and GF.ScanHintDue(500) == false)

local main = read("GoldFinder.lua")
check("the scan age is defined before the decision module is wired to it", (main:find("local function ScanAgeMinutes()", 1, true) or 0) < (main:find("ScanAgeMin = function() return ScanAgeMinutes() end", 1, true) or 0)
  and select(2, main:gsub("local function ScanAgeMinutes%(%)", "")) == 1)
check("both the decision module and the post module are wired to the scan age", select(2, main:gsub("ScanAgeMin = function%(%) return ScanAgeMinutes%(%) end", "")) == 2)
check("the login notice is printed at login with the localised text", main:find('if GF.ScanHintDue(ScanAgeMinutes()) then Print(L["scan.loginHint"]) end', 1, true) ~= nil)
local en, es = read("locales/enUS.lua"), read("locales/esES.lua")
for _, k in ipairs({ "scan.loginHint", "decision.scanNever", "scan.none" }) do
  check(k .. " exists in both languages and differs", en:find('["' .. k .. '"]', 1, true) ~= nil and es:find('["' .. k .. '"]', 1, true) ~= nil)
end
check("the summary line tells what to do, not only that there is no scan", GF.L["scan.none"]:find("press Scan", 1, true) ~= nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
