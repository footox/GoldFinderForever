-- Offline tests for the auction price of equipment (Lua 5.1): asked by the item's link (the variant's own entry), with the old
-- price by id as the fallback. Case that started it: a green staff priced 44 silver by id and 1 gold 50 by link.
-- Run from the addon folder:  lua tests/gear_price_test.lua

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
do local f = io.open("core/crates.lua", "rb"); if f then f:close(); loadCore("core/crates.lua", GF) end end   -- present once the Waylaid Crates are merged
loadCore("core/decision.lua", GF, { GoldFinderForeverDB = {} })

local STAFF, CLOTH, BAR = 1111, 2589, 3333
local LINK = "|cff1eff00|Hitem:1111::::::::30:::::::::|h[Staff]|h|r"
local S
local function reset()
  S = { byId = {}, byLink = {}, vendor = {}, class = { [STAFF] = 2, [BAR] = 4, [CLOTH] = 7 }, calls = { id = 0, link = 0 },
        cfg = { minGain = 2000, crossChars = false, questItems = true }, linkApi = true, linkError = false }
end
reset()
local function api()
  local v1 = { GetAuctionPriceByItemID = function(_, id) S.calls.id = S.calls.id + 1; return S.byId[id] end }
  if S.linkApi then
    v1.GetAuctionPriceByItemLink = function(_, link)
      S.calls.link = S.calls.link + 1
      if S.linkError then error("boom") end
      return S.byLink[link]
    end
  end
  return v1
end
local deps = {
  AHApi = api,
  VendorPrice = function(id) return S.vendor[id] end,
  TSMValue = function() return nil end,
  Cfg = function(k) return S.cfg[k] end,
  Char = function() return { keep = {} } end,
  Counts = function() return 1, 0 end,
  SkillUpNeed = function() return nil end, RouteNeedFor = function() return nil end, ReagentInfo = function() return nil end,
  QuestNeed = function() return nil end, RecipeToLearn = function() return nil end, RecipeForOthers = function() return nil end,
  OtherNeed = function() return nil end, IsUtilityItem = function() return false end, RefPrice = function() return nil end,
  ToBanker = function() return nil end,
  ItemInfoInstant = function(id) return id, "x", "y", "z", 0, S.class[id] end,
  ItemQuality = function() return 2 end,
}
local Decide = GF.NewDecision(deps)

-- the case that started it: 44 silver by id, 1 gold 50 by link, vendor 42 silver 10
S.byId[STAFF], S.byLink[LINK], S.vendor[STAFF] = 4400, 15000, 4210
local d = Decide(STAFF, 1, 0, false, LINK)
check("equipment with a link is priced by its variant: auction wins", d.verdict == "AH")
check("the net price is the link price minus the cut", math.abs(d.ahNet - 15000 * (1 - GF.AH_CUT)) < 0.01)
check("the link was asked", S.calls.link == 1)

S.calls.link, S.calls.id = 0, 0
d = Decide(STAFF, 1, 0, false)
check("without a link it is priced by id, as before (the old advice)", d.verdict == "VENDOR" and S.calls.link == 0 and S.calls.id == 1)

-- fallbacks
S.byLink[LINK] = nil
d = Decide(STAFF, 1, 0, false, LINK)
check("a link with no price falls back to the id price", d.verdict == "VENDOR" and S.calls.id >= 2)
S.byLink[LINK] = 0
d = Decide(STAFF, 1, 0, false, LINK)
check("a link price of zero falls back to the id price", d.verdict == "VENDOR")
S.byLink[LINK] = 15000; S.linkError = true
d = Decide(STAFF, 1, 0, false, LINK)
check("an error in the link API falls back to the id price, never breaks the advice", d.verdict == "VENDOR")
S.linkError = false; S.linkApi = false
d = Decide(STAFF, 1, 0, false, LINK)
check("an Auctionator without the link function falls back to the id price", d.verdict == "VENDOR")
S.linkApi = true

-- only equipment is asked by link
S.calls.link = 0
S.byId[CLOTH], S.vendor[CLOTH] = 50000, 10
S.byLink[LINK] = 99999
d = Decide(CLOTH, 1, 0, false, LINK)
check("a material is not asked by link, even if a link is given", S.calls.link == 0 and d.verdict == "AH")
S.byId[BAR], S.byLink[LINK], S.vendor[BAR] = 100, 20000, 10
d = Decide(BAR, 1, 0, false, LINK)
check("armor is asked by link too", S.calls.link == 1 and d.verdict == "AH")

-- bound items are never priced for the auction
S.calls.id, S.calls.link = 0, 0
d = Decide(STAFF, 1, 0, true, LINK)
check("a bound item is not looked up at the auction house", S.calls.id == 0 and S.calls.link == 0)

-- the link price is really lower than the id price: the advice follows it (no blind trust in one source)
reset()
S.byId[STAFF], S.byLink[LINK], S.vendor[STAFF] = 50000, 1000, 4210
d = Decide(STAFF, 1, 0, false, LINK)
check("when the variant is cheaper than the generic entry, the vendor wins", d.verdict == "VENDOR")

-- wiring
check("the bag adapter keeps the link of each slot", read("adapters/bags.lua"):find("link = info.hyperlink", 1, true) ~= nil)
local main = read("GoldFinder.lua")
check("the bag rows pass the link to the decision", main:find("{ bags = 0, bound = s.bound, link = s.link }", 1, true) ~= nil
  and main:find("Decide(id, e.bags, bank, e.bound, e.link)", 1, true) ~= nil)
check("the tooltip passes the link of the item", main:find("local link = GF.TooltipItemLink(data, tooltip)", 1, true) ~= nil
  and main:find("Decide(id, bags, bank, false, link)", 1, true) ~= nil)

-- the link of a tooltip (behaviour, not text): GetItem returns the NAME first and the link second
local LK = "|cff1eff00|Hitem:1111::::::::30:::::::::|h[Staff]|h|r"
check("the tooltip data link is used when present", GF.TooltipItemLink({ hyperlink = LK }, nil) == LK)
check("without it, the second value of GetItem is the link (not the name)", GF.TooltipItemLink({}, { GetItem = function() return "Staff", LK end }) == LK)
check("the name is never taken as a link", GF.TooltipItemLink({}, { GetItem = function() return "Staff", nil end }) == nil)
check("an error in GetItem gives nil, never an error", GF.TooltipItemLink({}, { GetItem = function() error("boom") end }) == nil)
check("an empty link is no link", GF.TooltipItemLink({ hyperlink = "" }, { GetItem = function() return "Staff", "" end }) == nil)
check("no data and no tooltip: nil", GF.TooltipItemLink(nil, nil) == nil and GF.TooltipItemLink({}, {}) == nil)
check("the data link wins over the tooltip item", GF.TooltipItemLink({ hyperlink = LK }, { GetItem = function() return "N", "other" end }) == LK)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
