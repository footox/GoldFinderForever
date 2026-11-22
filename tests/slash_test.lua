-- Offline tests for core/slash.lua (Lua 5.1): a command name owned by another addon is never taken over.
-- Run from the addon folder:  lua tests/slash_test.lua

local failures = 0

local function check(name, cond)

  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end

end



local GF = {}

assert(loadfile("core/slash.lua"))("GoldFinderForever", GF)



local cmds = { OTHER = function() end, GOLDFINDERFOREVER = function() end }

local g = { SLASH_OTHER1 = "/other", SLASH_OTHER2 = "/GF", SLASH_GOLDFINDERFOREVER1 = "/gff" }

check("/gf owned by another addon is taken", GF.CommandTaken(cmds, g, "GOLDFINDERFOREVER", "/gf"))

check("comparison ignores case", GF.CommandTaken(cmds, g, "GOLDFINDERFOREVER", "/GF"))

check("a free name is not taken", not GF.CommandTaken(cmds, g, "GOLDFINDERFOREVER", "/zzz"))

check("our own registration does not count",

  not GF.CommandTaken({ GOLDFINDERFOREVER = true }, { SLASH_GOLDFINDERFOREVER1 = "/gf" }, "GOLDFINDERFOREVER", "/gf"))

check("nothing registered", not GF.CommandTaken({}, {}, "GOLDFINDERFOREVER", "/gf"))

check("nil tables do not error", not GF.CommandTaken(nil, nil, "X", "/gf"))



-- RunDataCommand: the /gff data entry into the data addon
local function api(fn) return { Command = fn } end
local lines, why = GF.RunDataCommand(api(function(m) return { "a:" .. m, "b" } end), "near vendor")
check("data: passes the text and returns the lines", lines and #lines == 2 and lines[1] == "a:near vendor" and why == nil)
local l2, w2 = GF.RunDataCommand(nil, "help")
check("data: no addon is 'missing'", l2 == nil and w2 == "missing")
local l3, w3 = GF.RunDataCommand({}, "help")
check("data: an old addon without Command is 'missing'", l3 == nil and w3 == "missing")
local l4, w4 = GF.RunDataCommand({ Command = "x" }, "help")
check("data: Command that is not a function is 'missing'", l4 == nil and w4 == "missing")
local l5, w5 = GF.RunDataCommand(api(function() error("boom") end), "help")
check("data: an error is 'failed' and not raised", l5 == nil and w5 == "failed")
local l6, w6 = GF.RunDataCommand(api(function() return "not a list" end), "help")
check("data: a non-list result is 'failed'", l6 == nil and w6 == "failed")
local l7 = GF.RunDataCommand(api(function() return { "ok", 5, {}, "ok2" } end), "x")
check("data: only strings are kept", l7 and #l7 == 2 and l7[2] == "ok2")
local many = {}
for i = 1, 100 do many[i] = "line" .. i end
local l8 = GF.RunDataCommand(api(function() return many end), "x")
check("data: output is capped", l8 and #l8 == GF.DATA_MAX_LINES)
local seen
GF.RunDataCommand(api(function(m) seen = m; return {} end), nil)
check("data: a nil text becomes an empty string", seen == "")
GF.RunDataCommand(api(function(m) seen = m; return {} end), 42)
check("data: a non-string text becomes an empty string", seen == "")

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end

print("ALL PASS")

