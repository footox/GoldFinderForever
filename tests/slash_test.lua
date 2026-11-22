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



if failures > 0 then print(failures .. " FAILED"); os.exit(1) end

print("ALL PASS")

