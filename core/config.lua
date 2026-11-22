-- core/config.lua: constants, option defaults and the Cfg lookup. Shared through the addon namespace (GF).

local _, GF = ...

GF.CALLER = "GoldFinder"
GF.AH_CUT = 0.05

GF.DEFAULTS = {
  tip = true,        -- consejo en los tooltips
  track = true,      -- registrar el cuero que recoges
  minGain = 2000,    -- copper: la subasta debe ganar al menos esto (20 de plata) frente al vendedor
  reserve = 20,      -- fabricaciones de cada receta para las que se reserva material (subir profesion)
  nextSteps = false, -- opcional: ventana flotante con el siguiente paso de las guias de profesion
  crossChars = false, -- opcional: avisar de materiales que sirven a las profesiones de mis otros personajes
  questItems = true,  -- no recomendar vender, subastar ni enviar objetos que piden tus misiones (y su cadena)
  gamePlan = false,   -- opcional: siguiente paso segun mis recetas y los precios de la subasta (en vez de la guia)
  trackerGather = false, -- opcional: Pesca y Desuello tambien dan su paso (zona por tramo) en el seguimiento
  shopping = false,    -- opcional: pestana Compras (lista de materiales que faltan)
  readyAlert = false,   -- opcional: aviso (chat y sonido) al reunir los materiales de un paso
  mailPanel = false,    -- opcional: panel junto al correo con lo que conviene enviar al banquero
  bankPanel = false,    -- opcional: panel junto al banco con lo que conviene depositar
  vendorBox = false,    -- opcional: cuadrito junto al vendedor con las recetas que te sirven (el tooltip siempre las indica)
  sellPanel = true,     -- panel junto al vendedor con lo que conviene venderle (cada objeto con su boton Vender)
  useSkillUp = false,   -- opcional: usar la lista de materiales de SkillUp Forever (si esta instalado) para decidir que guardar
  craftTab = true,      -- pestana Fabricar (que compensa fabricar con tus materiales)
  routeTab = true,      -- pestana Ruta (planificador de ruta de profesion)
  profTabs = true,      -- pestanas Ruta y Fabricar tambien en la ventana de profesiones (si su pestana esta activa)
  routeSpan = 25,       -- puntos de habilidad que planifica la ruta
  sellCap = 5,          -- ruta: unidades de cada objeto fabricado que se valoran a precio de subasta (el resto, a precio del vendedor)
  banker = "",        -- nombre del personaje banquero al que se envia lo que hay que subastar
  trackerMode = "objetivos", -- siguiente paso: "objetivos" (bloque en el seguimiento de objetivos) o "flotante"
  recipeNotes = true,   -- probabilidad de subir y coste o ganancia por punto en la lista de recetas de profesiones
  -- boton Subastar (precio y cantidad como una operacion de TSM)
  postMinPct = 60,      -- precio minimo: % del valor de mercado (nunca por debajo de lo que paga el vendedor)
  postMaxPct = 200,     -- precio maximo: % del valor de mercado (si la mas barata pasa de aqui, precio normal)
  postUndercut = 1,     -- cobre por debajo de la subasta mas barata
  postCapDays = 2,      -- tope de unidades: lo que se vende en la region en estos dias (si TSM lo sabe)
  postDuration = 24,    -- duracion de la subasta en horas (12 o 24)
  language = "auto",    -- idioma: "auto" (el del cliente), "enUS" o "esES"
}

-- SavedVariables value if set, else the default. GoldFinderDB is read at call time (it is replaced on login).
function GF.Cfg(k)
  local db = GoldFinderDB
  if db and db[k] ~= nil then return db[k] end
  return GF.DEFAULTS[k]
end
