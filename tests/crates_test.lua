-- Offline tests for core/crates.lua (Lua 5.1): the Waylaid Crates are never advised for sale and are recognised by id.
-- Run from the addon folder:  lua tests/crates_test.lua

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
loadCore("core/crates.lua", GF)
loadCore("core/decision.lua", GF, { GoldFinderForeverDB = {} })

-- the list
local seen = {}
local n = 0
for id in pairs(GF.WAYLAID_CRATES) do n = n + 1; seen[id] = true end
check("thirty crates are known", n == 30)
check("the first and the last are crates", GF.IsWaylaidCrate(248682) and GF.IsWaylaidCrate(248713))
check("a known id in the middle is one", GF.IsWaylaidCrate(248692))
check("ids that were never seen are not guessed", not GF.IsWaylaidCrate(248700) and not GF.IsWaylaidCrate(248701))
check("neighbours outside the range are not crates", not GF.IsWaylaidCrate(248681) and not GF.IsWaylaidCrate(248714))
check("an ordinary item is not one", not GF.IsWaylaidCrate(2589) and not GF.IsWaylaidCrate(0) and not GF.IsWaylaidCrate(nil))

-- the decision
local S
local function reset()
  S = { ah = {}, vendor = {}, bags = {}, bank = {}, cfg = { minGain = 2000, crossChars = false, questItems = true }, keep = {} }
end
reset()
local deps = {
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return S.ah[id] end } end,
  VendorPrice = function(id) return S.vendor[id] end,
  TSMValue = function() return nil end,
  Cfg = function(k) return S.cfg[k] end,
  Char = function() return { keep = S.keep } end,
  Counts = function(id) return S.bags[id] or 0, S.bank[id] or 0 end,
  SkillUpNeed = function() return nil end,
  RouteNeedFor = function() return nil end,
  ReagentInfo = function() return nil end,
  QuestNeed = function() return nil end,
  RecipeToLearn = function() return nil end,
  RecipeForOthers = function() return nil end,
  OtherNeed = function() return nil end,
  IsUtilityItem = function() return false end,
  RefPrice = function() return nil end,
  ToBanker = function() return nil end,
  ItemInfoInstant = function(id) return id end,
  ItemQuality = function() return 1 end,
}
local Decide, SellQty = GF.NewDecision(deps)

S.ah[248692] = 500000; S.vendor[248692] = 20000; S.bags[248692] = 3
local d = Decide(248692, 3, 0, false)
check("a crate that would sell very well is still kept", d.verdict == "KEEP")
check("with its own reason code", d.code == "crate")
check("and a reason that says it serves Favor", d.reason:find("Favor", 1, true) ~= nil)
check("none of the stack is offered for sale", SellQty(248692) == 0 and SellQty(248692, true) == 0)

S.bags[248692], S.bank[248692] = 0, 5
d = Decide(248692, 0, 5, false)
check("a crate only in the bank is kept too", d.verdict == "KEEP" and d.code == "crate")

reset()
S.ah[2589] = 500000; S.vendor[2589] = 5; S.bags[2589] = 3
d = Decide(2589, 3, 0, false)
check("an ordinary item with the same prices is not blocked", d.verdict ~= "KEEP" and SellQty(2589) == 3)

reset()
S.keep[248692] = true; S.bags[248692] = 1
d = Decide(248692, 1, 0, false)
check("your own manual keep still comes first", d.verdict == "KEEP" and d.code == "manual")

-- wiring
local main = read("GoldFinder.lua")
local toc = read("GoldFinderForever.toc")
local ci, di = toc:find("core/crates.lua", 1, true), toc:find("core/decision.lua", 1, true)
check("the file is in the toc, before the decision that uses it", ci ~= nil and di ~= nil and ci < di)
check("the Materials advice says Keep: Favor for a crate", main:find('elseif d.code == "crate" then advice = L["advice.keepCrate"]', 1, true) ~= nil)
for _, k in ipairs({ "decision.crate", "advice.keepCrate" }) do
  check("both languages have " .. k, read("locales/enUS.lua"):find('["' .. k .. '"]', 1, true) ~= nil and read("locales/esES.lua"):find('["' .. k .. '"]', 1, true) ~= nil)
end

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
