-- Offline tests for own farm data (Lua 5.1): looted leather is recorded per zone even when no profession needs it,
-- and the leather tab shows where you got it instead of Zygor's farm table. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\sources_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")
local a = assert(src:find("local function IsLeather", 1, true), "start marker")
local b = assert(src:find("-- Recetas (patrones, planos...)", 1, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn { RecordSources = RecordSources, SourceText = SourceText, FarmText = FarmText }"

local loot = {}
local env = setmetatable({
  GoldFinderDB = {},
  GetRealZoneText = function() return "Arathi Highlands" end,
  UnitExists = function() return true end,
  UnitIsDead = function() return true end,
  UnitName = function() return "Highland Raptor" end,
  GetNumLootItems = function() return #loot end,
  GetLootSlotLink = function(i) return "item:" .. loot[i].id end,
  GetLootSlotInfo = function(i) return nil, nil, loot[i].qty end,
  NeededByAny = function(id) return id == 2589 end,   -- only Linen Cloth is needed by a profession
  C_Item = { GetItemInfoInstant = function(id)
    if id == 4234 then return id, nil, nil, nil, nil, 7, 6 end   -- Heavy Leather: trade goods / leather
    return id, nil, nil, nil, nil, 15, 0
  end },
}, { __index = _G })
local f = assert(loadstring(chunk))
setfenv(f, env)
local M = f()

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

loot = { { id = 4234, qty = 2 }, { id = 9999, qty = 1 }, { id = 2589, qty = 3 } }
M.RecordSources()
local s = env.GoldFinderDB.sources
check("leather recorded although no profession needs it", s[4234] and s[4234]["Arathi Highlands"].n == 2
  and s[4234]["Arathi Highlands"].mob == "Highland Raptor")
check("needed material still recorded", s[2589] and s[2589]["Arathi Highlands"].n == 3)
check("unneeded non-leather not recorded", s[9999] == nil)

check("farm text from own data", M.FarmText(4234) == "Lo has conseguido en: Arathi Highlands (2, Highland Raptor)")
check("farm text empty without data", M.FarmText(4304) == nil)

os.exit(failures == 0 and 0 or 1)
