-- Offline tests for GF.StripDefaults (Lua 5.1): only what the player changed stays in the saved data.
-- Run from the addon folder:  lua tests/implicit_defaults_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local GF = {}
assert(loadfile("core/config.lua"))("GoldFinderForever", GF)
local D = GF.DEFAULTS

-- a table that holds the defaults, as the Settings registration leaves it
local function baked()
  local db = {}
  for k, v in pairs(D) do db[k] = v end
  return db
end

local db = baked()
local n = GF.StripDefaults(db)
local left = 0
for _ in pairs(db) do left = left + 1 end
check("every option equal to its default is removed", left == 0)
local total = 0
for _ in pairs(D) do total = total + 1 end
check("it reports how many it removed", n == total and total > 20)

-- a real choice survives
local db2 = baked()
db2.nextSteps = false          -- default is true: an explicit choice
db2.shopping = false
db2.mailPanel = true           -- default is false
db2.routeSpan = 40             -- default 25
db2.language = "esES"          -- default "auto"
GF.StripDefaults(db2)
check("an explicit false against a default true is kept", db2.nextSteps == false and db2.shopping == false)
check("an explicit true against a default false is kept", db2.mailPanel == true)
check("a different number is kept", db2.routeSpan == 40)
check("a different string is kept", db2.language == "esES")
check("the unchanged options are gone", db2.tip == nil and db2.sellPanel == nil and db2.postMinPct == nil and db2.banker == nil)

-- not options: never touched
local db3 = baked()
db3.chars = { ["A B"] = { prof = {}, keep = {} } }
db3.welcomeSeen = true
db3.guidePos = { "TOP", "TOP", 1, 2 }
db3.sources = { [1] = { vendor = { 3 } } }
db3.trackerCollapsed = true
GF.StripDefaults(db3)
check("characters, flags and positions are untouched", db3.chars and db3.chars["A B"] and db3.welcomeSeen == true
  and db3.guidePos[3] == 1 and db3.sources[1].vendor[1] == 3 and db3.trackerCollapsed == true)

-- idempotent and safe
local again = GF.StripDefaults(db3)
check("running it twice removes nothing more", again == 0)
check("nil, a string and a number do not raise and remove nothing",
  GF.StripDefaults(nil) == 0 and GF.StripDefaults("x") == 0 and GF.StripDefaults(5) == 0)
check("an empty table is fine", GF.StripDefaults({}) == 0)

-- types are compared strictly
local db4 = { routeSpan = "25", postMinPct = 60.0, tip = 1 }
GF.StripDefaults(db4)
check("a string '25' is not the number 25", db4.routeSpan == "25")
check("60.0 equals 60", db4.postMinPct == nil)
check("1 is not true", db4.tip == 1)

-- the behaviour that matters: after stripping, Cfg follows a changed default
local saved = baked()
GF.StripDefaults(saved)
GoldFinderForeverDB = saved
local before = GF.Cfg("shopping")
GF.DEFAULTS.shopping = not GF.DEFAULTS.shopping   -- a later version flips the default
check("a flipped default reaches a profile that only held the old default", GF.Cfg("shopping") == (not before))
GF.DEFAULTS.shopping = not GF.DEFAULTS.shopping
local chosen = baked()
chosen.shopping = false
GF.StripDefaults(chosen)
GoldFinderForeverDB = chosen
GF.DEFAULTS.shopping = true
check("a real choice survives a changed default", GF.Cfg("shopping") == false)

-- wiring in the main file
local function read(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return (s:gsub("\13", "")) end
local main = read("GoldFinder.lua")
check("PLAYER_LOGOUT is registered", main:find('"PLAYER_LOGOUT"', 1, true) ~= nil)
check("the logout handler strips the defaults", main:find('event == "PLAYER_LOGOUT"', 1, true) ~= nil
  and main:find("pcall(GF.StripDefaults, GoldFinderForeverDB)", 1, true) ~= nil)
check("/gff route and cap print through Cfg, not the raw table", main:find('GoldFinderForeverDB.routeSpan', 1, true) == nil
  and main:find('GoldFinderForeverDB.sellCap', 1, true) == nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
