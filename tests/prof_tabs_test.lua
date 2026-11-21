-- Offline tests for ProfTabKeys (Lua 5.1): which GoldFinder tabs (Ruta, Fabricar) the professions window shows for
-- the open profession. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\prof_tabs_test.lua

local GF = {}
local f = assert(loadfile("core/proftabs.lua"))
setfenv(f, setmetatable({}, { __index = _G }))
f("GoldFinder", GF)
local ProfTabKeys = GF.ProfTabKeys

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function keys(...) return table.concat(ProfTabKeys(...), ",") end

local crafter = { crafts = { ["Roast Boar"] = { o = 1 } }, rank = 50, skillLine = 185 }
local gatherer = { crafts = {}, rank = 120, skillLine = 182 }

check("crafting profession with a route: Ruta then Fabricar", keys(crafter, true, true, true) == "ruta,fabricar")
check("route with nothing to plan: only Fabricar", keys(crafter, true, true, false) == "fabricar")
check("Fabricar setting off: only Ruta", keys(crafter, false, true, true) == "ruta")
check("Ruta setting off: only Fabricar", keys(crafter, true, false, true) == "fabricar")
check("both settings off: no tabs", keys(crafter, false, false, true) == "")
check("gathering profession (no crafts): no tabs", keys(gatherer, true, true, true) == "")
check("profession never cached: no tabs", keys(nil, true, true, true) == "")
check("profession without crafts table: no tabs", keys({ rank = 1 }, true, true, true) == "")

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
