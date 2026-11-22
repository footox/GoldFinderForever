-- Offline tests for core/config.lua, core/money.lua and adapters/wow.lua (Lua 5.1): they share state only
-- through the addon namespace (the second vararg of each file). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\core_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local function load(path, GF, env)
  local f = assert(loadfile(path))
  setfenv(f, setmetatable(env or {}, { __index = _G }))
  f("GoldFinder", GF)
end

local GF = {}
load("core/config.lua", GF)
load("core/money.lua", GF)

-- config
check("constants", GF.CALLER == "GoldFinder" and GF.AH_CUT == 0.05)
check("default returned without DB", GF.Cfg("minGain") == 2000 and GF.Cfg("tip") == true)
local env = { GoldFinderForeverDB = { minGain = 5000, tip = false } }
local GF2 = {}
load("core/config.lua", GF2, env)
check("DB value wins, including false", GF2.Cfg("minGain") == 5000 and GF2.Cfg("tip") == false)
check("unset key falls back to default", GF2.Cfg("reserve") == 20)
env.GoldFinderForeverDB = nil
check("DB is read at call time", GF2.Cfg("minGain") == 2000)
check("unknown key is nil", GF2.Cfg("nope") == nil)

-- money without the game formatter
check("plain money", GF.Money(123456) == "12g 34s 56c")
check("nil money is zero", GF.Money(nil) == "0g 0s 0c")
check("short money keeps copper under 1g", GF.ShortMoney(9999) == "0g 99s 99c")
check("short money drops copper from 1g", GF.ShortMoney(12345) == "1g 23s 0c")
check("short money drops silver from 100g", GF.ShortMoney(1234567) == "123g 0s 0c")

-- money with an injected formatter, and the wow adapter's lookup order
GF.CoinText = function(c) return "<" .. c .. ">" end
check("injected formatter used", GF.Money(77) == "<77>")
local W = {}
load("adapters/wow.lua", W, { C_CurrencyInfo = { GetCoinTextureString = function(c) return "modern" .. c end },
  GetCoinTextureString = function(c) return "legacy" .. c end })
check("adapter prefers C_CurrencyInfo", W.CoinText(5) == "modern5")
local W2 = {}
load("adapters/wow.lua", W2, { GetCoinTextureString = function(c) return "legacy" .. c end })
check("adapter falls back to the legacy global", W2.CoinText(5) == "legacy5")
local W3 = {}
load("adapters/wow.lua", W3, {})
check("adapter returns nil when no API exists", W3.CoinText(5) == nil)
local out
load("adapters/wow.lua", W3, { DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) out = m end } })
W3.Print(42)
check("print goes to the chat frame with the prefix", out == "|cffffd100GoldFinder Forever:|r 42")

if failures > 0 then print("FAILED: " .. failures); os.exit(1) else print("ALL PASS") end
