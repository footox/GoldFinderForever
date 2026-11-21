-- Offline tests for the auction house tab helpers (Lua 5.1): AHViewKeys (which views the auction house tab shows)
-- and AHBagOrder (bag rows with the auction verdict first). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\ah_tab_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")
local a = assert(src:find("-- VISTAS DE LA CASA DE SUBASTAS", 1, true), "start marker")
local b = assert(src:find("-- FIN DE VISTAS DE LA CASA DE SUBASTAS", 1, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn AHViewKeys, AHBagOrder"
local f = assert(loadstring(chunk))
setfenv(f, setmetatable({}, { __index = _G }))
local AHViewKeys, AHBagOrder = f()

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function keys(...) return table.concat(AHViewKeys(...), ",") end

check("shopping on: Bolsas, Compras, Cuero", keys(true, false) == "bolsas,compras,cuero")
check("shopping off but materials missing: Compras still shown", keys(false, true) == "bolsas,compras,cuero")
check("shopping off and nothing missing: no Compras", keys(false, false) == "bolsas,cuero")
check("never Resumen, Fabricar, Ruta, Sesion or Ajustes", not keys(true, true):find("resumen")
  and not keys(true, true):find("fabricar") and not keys(true, true):find("ruta")
  and not keys(true, true):find("sesion") and not keys(true, true):find("ajustes"))

local rows = {
  { id = 1, verdict = "VENDOR" }, { id = 2, verdict = "KEEP" }, { id = 3, verdict = "AH", toBanker = true },
  { id = 4, verdict = "AH" }, { id = 5, verdict = "NONE" }, { id = 6, verdict = "AH" }, { id = 7, verdict = "VENDOR" },
  { id = 8, verdict = "AH", bound = true },
}
local ids = {}
for _, r in ipairs(AHBagOrder(rows)) do ids[#ids + 1] = r.id end
local order = table.concat(ids, ",")
check("auctionable first, then AH via banker or bound, then vendor, keep, none (stable): " .. order,
  order == "4,6,3,8,1,7,2,5")
check("input rows are not reordered", rows[1].id == 1 and rows[4].id == 4 and #rows == 8)
check("empty list", #AHBagOrder({}) == 0)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
