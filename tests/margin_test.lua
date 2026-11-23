-- Offline tests for the configurable minimum margin over the vendor (Lua 5.1): the decision follows the option and the default is 10%.
-- Run from the addon folder:  lua tests/margin_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function read(p)
  local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n"))
end
local function loadCore(path, GF, env)
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable(env or {}, { __index = _G }))
  fn("GoldFinder", GF)
end

local GF = {}
loadCore("core/config.lua", GF)
loadCore("core/locale.lua", GF)
loadCore("locales/enUS.lua", GF)
do local f = io.open("core/crates.lua", "rb"); if f then f:close(); loadCore("core/crates.lua", GF) end end
loadCore("core/decision.lua", GF, { GoldFinderForeverDB = {} })

check("the default margin is 10 percent", GF.DEFAULTS.minMargin == 10)

local ITEM = 500
local S
local function reset(margin)
  S = { price = nil, vendor = nil, cfg = { minGain = 0, crossChars = false, questItems = true, minMargin = margin }, tsm = nil }
end
local function api() return { GetAuctionPriceByItemID = function() return S.price end } end
local deps = {
  AHApi = api,
  VendorPrice = function() return S.vendor end,
  TSMValue = function() return S.tsm end,
  Cfg = function(k) return S.cfg[k] end,
  Char = function() return { keep = {} } end,
  Counts = function() return 1, 0 end,
  SkillUpNeed = function() return nil end, RouteNeedFor = function() return nil end, ReagentInfo = function() return nil end,
  QuestNeed = function() return nil end, RecipeToLearn = function() return nil end, RecipeForOthers = function() return nil end,
  OtherNeed = function() return nil end, IsUtilityItem = function() return false end, RefPrice = function() return nil end,
  ToBanker = function() return nil end, ItemInfoInstant = function(id) return id end, ItemQuality = function() return 1 end,
}
local Decide = GF.NewDecision(deps)

-- vendor 1000; auction price p gives a net of p * 0.95
local function verdict(margin, ahGross)
  reset(margin); S.price, S.vendor = ahGross, 1000
  return Decide(ITEM, 1, 0, false).verdict
end

-- net 1150 (gross 1210.5) is 15% over the vendor
check("with the default margin, a 15% advantage recommends the auction", verdict(nil, 1211) == "AH")
check("with margin 10 written out, the same", verdict(10, 1211) == "AH")
check("with margin 20, a 15% advantage is not enough: vendor", verdict(20, 1211) == "VENDOR")
check("with margin 20, a 30% advantage is enough", verdict(20, 1400) == "AH")
check("with margin 0, an advantage of even 1% recommends the auction", verdict(0, 1070) == "AH")
check("with margin 0, no advantage at all is still the vendor", verdict(0, 1000) == "VENDOR")
check("a bad margin falls back to 10%", verdict("x", 1211) == "AH" and verdict(-3, 1000) == "VENDOR")

-- the same rule when there is no Auctionator price and TSM decides
local function tsmVerdict(margin, tsm)
  reset(margin); S.price, S.vendor, S.tsm = nil, 1000, tsm
  return Decide(ITEM, 1, 0, false).verdict
end
check("TSM path: a 15% advantage with the default margin recommends the auction", tsmVerdict(nil, 1211) == "AH")
check("TSM path: margin 20 turns it into the vendor", tsmVerdict(20, 1211) == "VENDOR")

-- wiring
local main = read("GoldFinder.lua")
check("the options panel has the slider after the minimum profit", main:find('number("minMargin", L["opt.minMargin.l"], 0, 200, 1, L["opt.minMargin.t"])', 1, true) ~= nil)
check("the decision no longer has the fixed 10% in it", not read("core/decision.lua"):find("vendor * 1.10", 1, true) and not read("core/decision.lua"):find("vendor * 1.1 ", 1, true))
for _, k in ipairs({ "opt.minMargin.l", "opt.minMargin.t", "tip.littleMargin" }) do
  check("both languages have " .. k, read("locales/enUS.lua"):find('["' .. k .. '"]', 1, true) ~= nil and read("locales/esES.lua"):find('["' .. k .. '"]', 1, true) ~= nil)
end
check("the margin message takes the percentage in both languages", select(2, read("locales/enUS.lua"):match('%["tip.littleMargin"%] = "([^\n]*)"'):gsub("%%d", "")) == 1
  and select(2, read("locales/esES.lua"):match('%["tip.littleMargin"%] = "([^\n]*)"'):gsub("%%d", "")) == 1)
check("and it formats without error", pcall(string.format, GF.locales.enUS["tip.littleMargin"], 30))

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
