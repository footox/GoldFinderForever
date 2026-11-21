-- Offline tests for adapters/wow.lua and adapters/bags.lua (Lua 5.1): fallbacks between client APIs, nil safety and
-- error isolation. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\adapters_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local function load(path, env)
  local GF = {}
  local f = assert(loadfile(path))
  setfenv(f, setmetatable(env or {}, { __index = _G }))
  f("GoldFinder", GF)
  return GF
end

-- merchant: legacy API, modern table API, nothing
local legacy = load("adapters/wow.lua", { GetMerchantItemInfo = function() return "n", "t", 120, 5, -1, true, false end })
local _, _, price, qty = legacy.MerchantItemInfo(1)
check("merchant: legacy API used when present", price == 120 and qty == 5)
local modern = load("adapters/wow.lua", { C_MerchantFrame = { GetItemInfo = function()
  return { name = "n", texture = "t", price = 300, stackCount = 2, numAvailable = -1, isUsable = true, hasExtendedCost = true }
end } })
local n, _, p2, q2, _, _, ext = modern.MerchantItemInfo(1)
check("merchant: fallback maps table fields", n == "n" and p2 == 300 and q2 == 2 and ext == true)
check("merchant: no API returns nil", load("adapters/wow.lua", {}).MerchantItemInfo(1) == nil)

-- addon loaded
check("addon: namespace first", load("adapters/wow.lua", { C_AddOns = { IsAddOnLoaded = function(x) return x == "A" end },
  IsAddOnLoaded = function() return false end }).IsAddOnLoaded("A") == true)
check("addon: legacy global fallback", load("adapters/wow.lua", { IsAddOnLoaded = function(x) return x == "B" end }).IsAddOnLoaded("B") == true)
check("addon: nothing available is false", load("adapters/wow.lua", {}).IsAddOnLoaded("C") == false)

-- spell texture
check("spell: modern first", load("adapters/wow.lua", { C_Spell = { GetSpellTexture = function() return 11 end },
  GetSpellTexture = function() return 22 end }).SpellTexture(1) == 11)
check("spell: legacy when modern has no icon", load("adapters/wow.lua", { C_Spell = { GetSpellTexture = function() return nil end },
  GetSpellTexture = function() return 22 end }).SpellTexture(1) == 22)
check("spell: nothing is nil", load("adapters/wow.lua", {}).SpellTexture(1) == nil)

-- Safe
local W = load("adapters/wow.lua", {})
local a, b = W.Safe(function(x, y) return x + 1, y end, 1, "z")
check("safe: returns the results", a == 2 and b == "z")
check("safe: swallows errors", W.Safe(function() error("boom") end) == nil)

-- bags
local bagsData = {
  [0] = { { itemID = 10, stackCount = 5, isBound = true }, nil, { itemID = 11, isLocked = true } },
  [1] = { { itemID = 10, stackCount = 2 } },
}
local sizes = { [0] = 3, [1] = 1 }
local B = load("adapters/bags.lua", { NUM_BAG_SLOTS = 1, C_Container = {
  GetContainerNumSlots = function(bag) return sizes[bag] or 0 end,
  GetContainerItemInfo = function(bag, slot) return bagsData[bag] and bagsData[bag][slot] end,
} })
local slots = B.BagSlots()
check("bags: ready with the container API", B.BagApiReady() == true)
check("bags: lists only occupied slots", #slots == 3)
check("bags: fields", slots[1].bag == 0 and slots[1].slot == 1 and slots[1].id == 10 and slots[1].count == 5 and slots[1].bound == true)
check("bags: count defaults to 1 and keeps locked", slots[2].id == 11 and slots[2].count == 1 and slots[2].locked == true)
check("bags: second bag read", slots[3].bag == 1 and slots[3].id == 10 and slots[3].count == 2)
local none = load("adapters/bags.lua", {})
check("bags: missing API gives an empty list", none.BagApiReady() == false and #none.BagSlots() == 0)
local flaky = load("adapters/bags.lua", { NUM_BAG_SLOTS = 0, C_Container = {
  GetContainerNumSlots = function() return 2 end,
  GetContainerItemInfo = function(_, slot) if slot == 1 then error("secret") end return { itemID = 7 } end,
} })
local fs = flaky.BagSlots()
check("bags: a failing slot read is skipped", #fs == 1 and fs[1].id == 7 and fs[1].slot == 2)

if failures > 0 then print("FAILED: " .. failures); os.exit(1) else print("ALL PASS") end
