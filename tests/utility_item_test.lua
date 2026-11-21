-- Offline tests for IsUtilityItem (Lua 5.1): items you use (an on-use effect that is not a consumable nor gray junk,
-- e.g. Cozy Sleeping Bag) are never recommended for vendor sale. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\utility_item_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")
local a = assert(src:find("local function IsUtilityItem", 1, true), "start marker")
local b = assert(src:find("-- FIN DE OBJETOS DE USO", 1, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn IsUtilityItem"

-- id -> { class, quality, spell }
local items = {
  [1] = { class = 15, quality = 1, spell = "Cozy Sleeping Bag" },   -- misc, white, on-use: utility
  [2] = { class = 0, quality = 1, spell = "Healing Potion" },       -- consumable: not utility
  [3] = { class = 15, quality = 0, spell = "Junk Use" },            -- gray junk with a use: not utility
  [4] = { class = 7, quality = 1 },                                  -- trade good, no use: not utility
  [5] = { class = 4, quality = 2 },                                  -- armor, no use: not utility
  [6] = { class = 4, quality = 2, spell = "Trinket Use" },           -- armor/trinket with on-use: utility
}
local env = setmetatable({
  C_Item = {
    GetItemInfoInstant = function(id) local t = items[id]; return id, nil, nil, nil, nil, t and t.class, 0 end,
    GetItemSpell = function(id) local t = items[id]; if t and t.spell then return t.spell, 100 end end,
    GetItemQualityByID = function(id) local t = items[id]; return t and t.quality end,
  },
}, { __index = _G })
local f = assert(loadstring(chunk))
setfenv(f, env)
local IsUtilityItem = f()

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
check("misc item with a use is utility (sleeping bag)", IsUtilityItem(1) == true)
check("consumable is not utility", IsUtilityItem(2) == false)
check("gray junk is not utility", IsUtilityItem(3) == false)
check("trade good is not utility", IsUtilityItem(4) == false)
check("gear without use is not utility", IsUtilityItem(5) == false)
check("trinket with on-use is utility", IsUtilityItem(6) == true)
check("unknown item is not utility", IsUtilityItem(999) == false)
os.exit(failures == 0 and 0 or 1)
