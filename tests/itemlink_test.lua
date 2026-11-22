-- Offline tests for ItemLink (Lua 5.1): an item name that has been seen once stays, and a missing one is asked for and
-- reported. The function is extracted from the main file and run against a fake client.
-- Run from the addon folder:  lua tests/itemlink_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local f = assert(io.open("GoldFinder.lua", "rb"))
local src = f:read("*a"); f:close()
src = src:gsub("\r\n", "\n")
local a = assert(src:find("local missingNow = {}", 1, true), "start marker")
local b = assert(src:find("local function Median(t)", a, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn ItemLink, function() return nameMissing, missingNow end, function() nameMissing = false end"

local function session(opts)
  local S = { requested = {}, infos = opts.infos or {}, tooltipText = opts.tooltipText or {} }
  local tip = {
    SetOwner = function() end, ClearLines = function() end,
    SetItemByID = function(_, id) S.currentTip = S.tooltipText[id] end,
    SetHyperlink = function() end,
  }
  local env = setmetatable({
    C_Item = {
      GetItemInfo = function(id) local l = S.infos[id]; if l then return "name", l end return nil end,
      RequestLoadItemDataByID = function(id) S.requested[#S.requested + 1] = id end,
    },
    CreateFrame = function() return tip end,
    UIParent = {},
    RETRIEVING_ITEM_INFO = "Retrieving item information",
    pcall = pcall,
  }, { __index = _G })
  env._G = env
  env.GoldFinderScanTipTextLeft1 = { GetText = function() return S.currentTip end }
  local fn = assert(loadstring(chunk))
  setfenv(fn, env)
  S.ItemLink, S.state, S.reset = fn()
  return S
end

-- 1. a loaded item gives its link and is not reported as missing
local S = session({ infos = { [100] = "|cff1eff00|Hitem:100|h[Heavy Hide]|h|r" } })
check("a loaded item gives its link", S.ItemLink(100) == "|cff1eff00|Hitem:100|h[Heavy Hide]|h|r")
local miss, ids = S.state()
check("a loaded item is not reported as missing", miss == false and ids[100] == nil)

-- 2. a name seen once stays, even when the client forgets it
S.infos[100] = nil
check("the client forgot it: the link seen before is still returned", S.ItemLink(100) == "|cff1eff00|Hitem:100|h[Heavy Hide]|h|r")
miss = S.state()
check("and it is still not reported as missing", miss == false and #S.requested == 0)

-- 3. an item never seen: placeholder, reported, requested
local S2 = session({})
check("an item never seen shows its id", S2.ItemLink(200) == "item:200")
local m2, i2 = S2.state()
check("it is reported as missing with its id", m2 == true and i2[200] == true)
check("and its data is requested from the game", #S2.requested == 1 and S2.requested[1] == 200)

-- 4. it arrives later
S2.infos[200] = "|Hitem:200|h[Thick Leather]|h"
check("when it arrives the link is returned", S2.ItemLink(200) == "|Hitem:200|h[Thick Leather]|h")
S2.infos[200] = nil
check("and it stays afterwards", S2.ItemLink(200) == "|Hitem:200|h[Thick Leather]|h")
S2.reset()
S2.ItemLink(200)
check("a name that stayed does not mark the drawing as missing again", select(1, S2.state()) == false)

-- 5. the tooltip fallback still works and its result stays too
local S3 = session({ tooltipText = { [300] = "Deviate Scale" } })
check("the hidden tooltip gives a name when the client has no info", S3.ItemLink(300) == "Deviate Scale")
S3.tooltipText[300] = nil
check("and that name stays", S3.ItemLink(300) == "Deviate Scale")
local S4 = session({ tooltipText = { [400] = "Retrieving item information" } })
check("the 'retrieving' text is not taken as a name", S4.ItemLink(400) == "item:400")

-- 6. several items are independent
local S5 = session({ infos = { [1] = "L1" } })
S5.ItemLink(1); S5.ItemLink(2)
local m5, i5 = S5.state()
check("only the item without a name is reported", m5 == true and i5[1] == nil and i5[2] == true)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
