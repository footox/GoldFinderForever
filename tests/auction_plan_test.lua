-- Offline tests for AuctionPlan (Lua 5.1): price and quantity for the one-click "Subastar" button
-- (TSM-like operation: market reference, min/normal/max, undercut, vendor floor, post cap). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\auction_plan_test.lua

local GF = {}
local f = assert(loadfile("core/auction.lua"))
setfenv(f, setmetatable({}, { __index = _G }))
f("GoldFinder", GF)
local AuctionPlan = GF.AuctionPlan

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function plan(t)
  t.money = function(c) return c .. "c" end
  return AuctionPlan(t)
end

-- defaults: minPct 60, maxPct 200, undercut 1, capDays 2
local p = plan({ lowest = 900, market = 1000, vendor = 0, available = 20 })
check("undercut the lowest: 899 x20", p.post and p.unit == 899 and p.qty == 20)
check("min, normal and max from market (600, 1000, 2000)", p.min == 600 and p.normal == 1000 and p.max == 2000)

p = plan({ lowest = 3000, market = 1000, vendor = 0, available = 5 })
check("lowest above max: normal price", p.post and p.unit == 1000 and p.qty == 5)

p = plan({ market = 1000, vendor = 0, available = 5 })
-- changed (R1b): no Auctionator price means the verdict is TSM-only: scan before one-click posting
check("no Auctionator price: no one-click, scan first", not p.post and p.normal == 1000
  and p.reason == "escanea la casa de subastas antes de publicar")

p = plan({ lowest = 500, market = 1000, vendor = 0, available = 5 })
check("below the minimum: wait", not p.post and p.reason:find("debajo del minimo: espera", 1, true) ~= nil)
check("below the minimum: reason shows the minimum", p.reason:find("600c", 1, true) ~= nil)

p = plan({ lowest = 600, market = 1000, vendor = 0, available = 5 })
check("undercut never goes under the minimum", p.post and p.unit == 600)

p = plan({ available = 5, vendor = 100 })
check("no market and no lowest: no price", not p.post and p.reason == "sin precio: escanea")

-- vendor floor: 1000 * 1.05 / 0.95 = 1105.26 -> 1106
p = plan({ lowest = 1050, market = 1000, vendor = 1000, available = 3 })
check("vendor floor raises the minimum (1106)", p.min == 1106)
check("lowest under the vendor floor: wait", not p.post and p.reason:find("debajo del minimo", 1, true) ~= nil)
p = plan({ market = 1000, vendor = 1000, available = 3 })
-- changed (R1b): without a lowest it is not posted; the normal price is still bounded by the vendor floor
check("normal price bounded by the vendor floor", not p.post and p.normal == 1106)

p = plan({ lowest = 900, market = 1000, vendor = 0, available = 20, soldPerDay = 3.2 })
check("cap by sold per day: ceil(3.2 * 2) = 7", p.post and p.qty == 7 and p.reason:find("tope", 1, true) ~= nil)
p = plan({ lowest = 900, market = 1000, vendor = 0, available = 20, soldPerDay = 0.1 })
check("cap is at least 1", p.post and p.qty == 1)
p = plan({ lowest = 900, market = 1000, vendor = 0, available = 4, soldPerDay = 3.2 })
check("no cap when available is under it", p.post and p.qty == 4 and not p.reason:find("tope", 1, true))
p = plan({ lowest = 900, market = 1000, vendor = 0, available = 20, soldPerDay = 3.2, capDays = 1 })
check("capDays setting: ceil(3.2 * 1) = 4", p.qty == 4)

p = plan({ lowest = 900, market = 1000, vendor = 0, available = 0 })
check("qty 0: all reserved", not p.post and p.reason == "todo reservado para tus profesiones")

p = plan({ lowest = 900, market = 1000, vendor = 0, available = 2, minPct = 95, maxPct = 120, undercut = 5 })
check("settings: minPct 95 makes 900 wait", not p.post and p.min == 950)
p = plan({ lowest = 1100, market = 1000, vendor = 0, available = 2, minPct = 95, maxPct = 120, undercut = 5 })
check("settings: undercut 5 -> 1095, max 1200", p.post and p.unit == 1095 and p.max == 1200)

p = plan({ lowest = 800, vendor = 0, available = 2 })
-- changed (R1): without a market reference the lowest alone is not trusted for one-click posting
check("no market: no one-click (needs a reference)", not p.post
  and p.reason == "sin precio de referencia: usa Auctionator (Mayus+clic)")

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
