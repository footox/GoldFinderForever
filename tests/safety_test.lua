-- Offline tests for the sell/keep safety rules (Lua 5.1): profession tools are never sold, items without auction
-- data are not sent to the vendor, reservations add up (own max + every alt), BuyPrice takes the cheaper source,
-- and the one-click Subastar refuses variant gear and items without a market reference. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\safety_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

---------------------------------------------------------------------------
-- Decide / SellQty with stubbed WoW APIs
---------------------------------------------------------------------------
local function loadCore(path, GF, env)
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable(env or {}, { __index = _G }))
  fn("GoldFinder", GF)
end
local GF = {}
loadCore("core/config.lua", GF)
loadCore("core/quest_need.lua", GF)
loadCore("core/decision.lua", GF, { GoldFinderDB = {} })

local S   -- per-test state
local function reset()
  S = { ah = {}, vendor = {}, tsm = {}, quality = {}, class = {}, bags = {}, bank = {},
        su = {}, route = {}, reagent = {}, alts = {}, cfg = { minGain = 2000, crossChars = true }, keep = {} }
end
reset()
local deps = {
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return S.ah[id] end } end,
  VendorPrice = function(id) return S.vendor[id] end,
  TSMValue = function(source, id) return S.tsm[source .. ":" .. id] end,
  Cfg = function(k) return S.cfg[k] end,
  Char = function() return { keep = S.keep } end,
  Counts = function(id) return S.bags[id] or 0, S.bank[id] or 0 end,
  SkillUpNeed = function(id) return S.su[id] end,
  RouteNeedFor = function(_, id) return S.route[id] end,
  ReagentInfo = function(id) return S.reagent[id] end,
  RecipeToLearn = function() return nil end,
  RecipeForOthers = function() return nil end,
  OtherNeed = function(id, all)
    local list = S.alts[id]
    if not list or #list == 0 then return nil end
    local best, sum, names = nil, 0, {}
    for _, z in ipairs(list) do
      sum = sum + z.need
      names[#names + 1] = z.who
      if not best or z.need > best.need then best = z end
    end
    if all then return { need = sum, who = table.concat(names, ", "), n = #list, list = list, first = best } end
    return best
  end,
  IsUtilityItem = function() return false end,
  RefPrice = function() return nil end,
  ToBanker = function() return nil end,
  ItemInfoInstant = function(id) local c = S.class[id] or {}; return id, nil, nil, nil, nil, c[1], c[2] end,
  ItemQuality = function(id) return S.quality[id] end,
}
local Decide, SellQty = GF.NewDecision(deps)
local f

-- 1a. profession tools: never to the vendor
for _, id in ipairs({ 2901, 7005, 5956, 6219, 6218, 6339, 11130, 11145, 16207 }) do
  reset(); S.vendor[id] = 20; S.quality[id] = 1
  local d = Decide(id, 1, 0, false)
  check("tool " .. id .. " is KEEP (herramienta de profesion)", d.verdict == "KEEP" and d.reason == "herramienta de profesion")
end
reset(); S.vendor[6256] = 5; S.quality[6256] = 1; S.class[6256] = { 2, 20 }
check("fishing pole (weapon subclass 20) is KEEP", Decide(6256, 1, 0, false).verdict == "KEEP")
reset(); S.vendor[777] = 5; S.quality[777] = 1; S.class[777] = { 2, 20 }
check("any fishing pole by class is KEEP", Decide(777, 1, 0, false).reason == "herramienta de profesion")
check("tool: nothing to sell", SellQty(777) == 0)

-- 1b. no Auctionator price
reset(); S.vendor[100] = 50; S.quality[100] = 1
local d = Decide(100, 3, 0, false)
check("unknown white item: NONE, not VENDOR", d.verdict == "NONE" and d.reason == "sin datos de subasta: escanea")
reset(); S.vendor[100] = 50; S.quality[100] = 0
check("unknown gray junk: still VENDOR", Decide(100, 3, 0, false).verdict == "VENDOR")
reset(); S.vendor[100] = 50; S.quality[100] = 1
check("bound item without AH price: VENDOR", Decide(100, 3, 0, true).verdict == "VENDOR")
reset(); S.vendor[100] = 100; S.quality[100] = 1; S.tsm["DBMarket:100"] = 10000
d = Decide(100, 5, 0, false)
check("no AH price but TSM worth it: AH at TSM net", d.verdict == "AH" and d.unit == 9500 and d.ahNet == 9500)
reset(); S.vendor[100] = 100; S.quality[100] = 1; S.tsm["DBRegionMarketAvg:100"] = 10000
check("TSM region fallback is used", Decide(100, 5, 0, false).verdict == "AH")
reset(); S.vendor[100] = 100; S.quality[100] = 1; S.tsm["DBMarket:100"] = 108
check("TSM barely above vendor: VENDOR", Decide(100, 5, 0, false).verdict == "VENDOR")
reset(); S.vendor[100] = 50; S.ah[100] = 40
check("previous behaviour: AH below vendor is VENDOR", Decide(100, 3, 0, false).verdict == "VENDOR")
-- R1b: no vendor price and no Auctionator price also consults TSM
reset(); S.quality[300] = 1; S.tsm["DBMarket:300"] = 10000
d = Decide(300, 5, 0, false)
check("no vendor, no AH, TSM worth it: AH at TSM net", d.verdict == "AH" and d.unit == 9500 and d.ahNet == 9500)
reset(); S.quality[300] = 1
d = Decide(300, 5, 0, false)
check("no vendor, no AH, no TSM: NONE escanea", d.verdict == "NONE" and d.reason == "sin datos de subasta: escanea")
reset(); S.quality[300] = 1; S.tsm["DBMarket:300"] = 100
d = Decide(300, 1, 0, false)
check("no vendor, no AH, TSM below min gain: NONE escanea",
  d.verdict == "NONE" and d.reason == "sin datos de subasta: escanea")
reset(); S.quality[300] = 0
check("no vendor gray without data: not VENDOR", Decide(300, 1, 0, false).verdict == "NONE")
reset(); S.quality[300] = 1; S.tsm["DBMarket:300"] = 10000
check("bound, no vendor: no TSM verdict", Decide(300, 5, 0, true).verdict == "NONE")
reset(); S.quality[300] = 1; S.ah[300] = 10000
check("previous behaviour: no vendor with AH price is AH", Decide(300, 5, 0, false).verdict == "AH")

-- 2. reservations: own = max(route, reagent, SkillUp); alts = sum of every alt; total = own + alts
local function reserves()
  reset()
  S.ah[200] = 100000; S.vendor[200] = 10; S.quality[200] = 1
  S.route[200] = { need = 10, prof = "Leatherworking", upto = 120 }
  S.reagent[200] = { need = 8, prof = "Leatherworking", recipe = "Armor Kit" }
  S.su[200] = { need = 5, profs = { "Leatherworking" }, target = 110 }
  S.alts[200] = { { need = 4, who = "Ashes", prof = "Tailoring" }, { need = 3, who = "Bob", prof = "Tailoring" } }
end
reserves()
d = Decide(200, 17, 0, false)
check("17 held vs 10 own + 4 + 3 alts: KEEP", d.verdict == "KEEP" and d.reserve == 17)
reserves()
d = Decide(200, 18, 0, false)
check("18 held: AH with 1 surplus", d.verdict == "AH" and d.sellQty == 1 and d.reserve == 17)
check("reserve label names prof and alts", d.reserveFor and d.reserveFor:find("Leatherworking", 1, true)
  and d.reserveFor:find("Ashes", 1, true) and d.reserveFor:find("Bob", 1, true))
reserves(); S.bags[200] = 18
check("SellQty agrees: 1", SellQty(200) == 1)
reserves(); S.bags[200] = 5; S.bank[200] = 20
check("SellQty: bank counts toward the reserve, bags cap", SellQty(200) == 5)
-- R2: withBank = total surplus over the reserve (17), for crafting with what you own
check("SellQty withBank: total surplus", SellQty(200, true) == 25 - 17)
reserves(); S.bags[200] = 0; S.bank[200] = 20
check("SellQty: bank only, nothing to sell from bags", SellQty(200) == 0 and SellQty(200, true) == 3)
reserves(); S.cfg.crossChars = false; S.bags[200] = 18
check("crossChars off: only own reserve (8 to sell)", SellQty(200) == 8 and Decide(200, 18, 0, false).reserve == 10)
reserves()
d = Decide(200, 10, 0, false)
check("own max not summed: 10 held is KEEP for own route", d.verdict == "KEEP" and d.reason:find("ruta", 1, true))
reserves()
d = Decide(200, 12, 0, false)
check("12 held: KEEP for the alts", d.verdict == "KEEP" and d.forOther ~= nil)
reserves(); S.keep[200] = true; S.bags[200] = 50
check("manual keep: SellQty 0", SellQty(200) == 0 and Decide(200, 50, 0, false).verdict == "KEEP")

-- real OtherNeed: largest alt for the label, sum of every alt (each once) for the reserve
a = assert(src:find("local function OtherNeed", 1, true), "OtherNeed start")
b = assert(src:find("local function GamePlan", 1, true), "OtherNeed end")
local me = { prof = {} }
local needs = { Ashes = 4, Bob = 6 }
local oenv = setmetatable({
  Char = function() return me end,
  Cfg = function() return false end,
  StockOf = function() return 0 end,
  RouteNeedFor = function(c, id) return needs[c.name] and { need = needs[c.name], prof = "Tailoring", upto = 100 } end,
  ReagentInfoFor = function() return nil end,
  GoldFinderDB = { chars = { ["Me-Realm"] = me, ["Ashes-Realm"] = { name = "Ashes", prof = {} },
    ["Bob-Realm"] = { name = "Bob", prof = {} }, ["Cid-Realm"] = { name = "Cid", prof = {} } } },
}, { __index = _G })
f = assert(loadstring(src:sub(a, b - 1) .. "\nreturn OtherNeed"))
setfenv(f, oenv)
local OtherNeed = f()
local one, all = OtherNeed(1), OtherNeed(1, true)
check("OtherNeed: largest alt for the label", one.who == "Bob" and one.need == 6)
check("OtherNeed all: sum of every alt", all.need == 10 and all.n == 2 and all.who == "Ashes, Bob")
needs = {}
check("OtherNeed: nobody needs it", OtherNeed(1) == nil and OtherNeed(1, true) == nil)

-- R1b: each alt's need is the MAX of its sources (SkillUp, route, reagents), minus what that alt already holds
local stock, su = {}, true
local altA = { name = "Ashes", prof = {}, suNeed = { [1] = { n = 3, p = "Tailoring", t = 50 } } }
local rneed, rgneed = { Ashes = 10 }, {}
local oenv2 = setmetatable({
  Char = function() return me end,
  Cfg = function(k) return k == "useSkillUp" and su end,
  StockOf = function(who) return stock[who] end,
  RouteNeedFor = function(c) return rneed[c.name] and { need = rneed[c.name], prof = "Tailoring", upto = 100 } end,
  ReagentInfoFor = function(c) return rgneed[c.name] and { need = rgneed[c.name], prof = "Tailoring", recipe = "X" } end,
  GoldFinderDB = { chars = { ["Me-Realm"] = me, ["Ashes-Realm"] = altA,
    ["Bob-Realm"] = { name = "Bob", prof = {} } } },
}, { __index = _G })
f = assert(loadstring(src:sub(a, b - 1) .. "\nreturn OtherNeed"))
setfenv(f, oenv2)
OtherNeed = f()
local o = OtherNeed(1)
check("alt need: route 10 beats SkillUp 3 (max, not first)", o and o.need == 10 and o.upto == 100)
rgneed.Ashes = 20
check("alt need: reagent reserve 20 is the max", OtherNeed(1).need == 20)
rgneed.Ashes = nil; stock.Ashes = 4
check("alt need: minus what the alt holds (10 - 4)", OtherNeed(1).need == 6)
stock.Ashes = 12
check("alt need: alt holds enough, nothing asked", OtherNeed(1) == nil)
stock.Ashes = nil; rneed.Ashes = nil
o = OtherNeed(1)
check("alt need: SkillUp only still counts (3)", o and o.need == 3 and o.su == true)
rneed.Ashes, rneed.Bob = 10, 5
check("alt need: still summed over alts (10 + 5)", OtherNeed(1, true).need == 15)

---------------------------------------------------------------------------
-- BuyPrice: cheaper of AH and known vendor price
---------------------------------------------------------------------------
local prices, vsell = {}, {}
loadCore("core/routeplanner.lua", GF)
local penv = setmetatable({
  CALLER = "GoldFinder", AH_CUT = 0.05, GoldFinderDB = { vendorBuy = {} },
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return prices[id] end } end,
  VendorPrice = function(id) return vsell[id] end,
  Counts = function() return 0, 0 end,
  Cfg = function() return nil end,
}, { __index = _G })
local BuyPrice = GF.NewRoutePlanner(penv).BuyPrice
prices[1], penv.GoldFinderDB.vendorBuy[1] = 100, 60
check("vendor cheaper than AH: vendor price", BuyPrice(1) == 60)
prices[2], penv.GoldFinderDB.vendorBuy[2] = 50, 60
check("AH cheaper than vendor: AH price", BuyPrice(2) == 50)
prices[3] = 70
check("only AH known", BuyPrice(3) == 70)
penv.GoldFinderDB.vendorBuy[4] = 30
check("only vendor known", BuyPrice(4) == 30)
vsell[5] = 10
local p5, est = BuyPrice(5)
check("nothing known: vendor x4 estimate", p5 == 40 and est == true)

---------------------------------------------------------------------------
-- AuctionPlan: one-click refused for variant gear and without a market reference
---------------------------------------------------------------------------
loadCore("core/locale.lua", GF)
loadCore("locales/enUS.lua", GF)
loadCore("core/auction.lua", GF)
local AuctionPlan = GF.AuctionPlan
local p = AuctionPlan({ lowest = 900, market = 1000, vendor = 0, available = 3, variant = true })
check("variant gear: no one-click", not p.post and p.code == "variant")
p = AuctionPlan({ lowest = 800, vendor = 0, available = 2 })
check("no market reference: no one-click",
  not p.post and p.code == "noref")
p = AuctionPlan({ lowest = 900, market = 1000, vendor = 0, available = 20, soldPerDay = 3.2 })
check("cap wording: per post", p.reason:find("cap of 7 per posting", 1, true) ~= nil)
-- R1b: no Auctionator price (TSM-only verdict): no one-click until the auction house is scanned
p = AuctionPlan({ market = 1000, vendor = 0, available = 5 })
check("TSM only: no one-click, scan first",
  not p.post and p.code == "scan")
check("TSM only: range still shown", p.min == 600 and p.normal == 1000)

---------------------------------------------------------------------------
-- R1b: "sin datos de subasta: escanea" rows stay listed in Bolsas, never reach the merchant or the mail plan
---------------------------------------------------------------------------
a = assert(src:find("-- FILTRO DE BOLSAS", 1, true), "bag filter start marker")
b = assert(src:find("-- FIN DE FILTRO DE BOLSAS", 1, true), "bag filter end marker")
f = assert(loadstring(src:sub(a, b - 1) .. "\nreturn BagListed"))
setfenv(f, setmetatable({}, { __index = _G }))
local BagListed = f()
local scan = { id = 9, verdict = "NONE", reason = "sin datos de subasta: escanea", vendor = 0, count = 2 }
check("escanea row is listed in Bolsas", BagListed(scan) == true)
check("plain NONE row stays hidden", BagListed({ verdict = "NONE" }) == false)
check("AH/VENDOR/KEEP rows listed", BagListed({ verdict = "AH" }) and BagListed({ verdict = "VENDOR" })
  and BagListed({ verdict = "KEEP" }))
loadCore("core/vendor.lua", GF)
local scanV = { id = 9, verdict = "NONE", reason = "sin datos de subasta: escanea", vendor = 50, count = 2 }
check("escanea row not in the merchant panel", #GF.VendorSellRows({ scanV }) == 0)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
