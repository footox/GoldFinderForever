-- core/proftabs.lua: which GoldFinder tabs (Ruta, Fabricar) the professions window shows. Pure: flags in, keys out.

local _, GF = ...

-- Pestanas que tocan para la profesion abierta: solo las profesiones con recetas que fabrican algo
-- (recoleccion: ninguna); Ruta solo si su pestana esta activa y hay algo que planificar.
local function ProfTabKeys(pd, craftOn, routeOn, hasRoute)
  local keys = {}
  if not (pd and type(pd.crafts) == "table" and next(pd.crafts) ~= nil) then return keys end
  if routeOn and hasRoute then keys[#keys + 1] = "ruta" end
  if craftOn then keys[#keys + 1] = "fabricar" end
  return keys
end

GF.ProfTabKeys = ProfTabKeys
