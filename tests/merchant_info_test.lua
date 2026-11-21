-- Offline tests for MerchantItemInfo (Lua 5.1): it uses GetMerchantItemInfo when present and falls back to
-- C_MerchantFrame.GetItemInfo otherwise. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\merchant_info_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")
local a = assert(src:find("-- MERCADER: lectura de un objeto", 1, true), "start marker")
local b = assert(src:find("-- FIN DE MERCADER", 1, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn MerchantItemInfo"

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local function load(env)
  local f = assert(loadstring(chunk))
  setfenv(f, setmetatable(env, { __index = _G }))
  return f()
end

local legacy = load({ GetMerchantItemInfo = function() return "n", "t", 120, 5, -1, true, false end })
local _, _, price, qty = legacy(1)
check("legacy API used when present", price == 120 and qty == 5)

local modern = load({ C_MerchantFrame = { GetItemInfo = function()
  return { name = "n", texture = "t", price = 300, stackCount = 2, numAvailable = -1, isUsable = true, hasExtendedCost = true }
end } })
local n, _, p2, q2, _, _, ext = modern(1)
check("fallback maps table fields", n == "n" and p2 == 300 and q2 == 2 and ext == true)

check("no API returns nil", load({})(1) == nil)

if failures > 0 then print("FAILED: " .. failures); os.exit(1) else print("ALL PASS") end
