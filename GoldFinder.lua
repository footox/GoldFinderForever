-- GoldFinder (version compacta)
-- Ayuda a decidir que hacer con lo que llevas: VENDER al vendedor, SUBASTAR o
-- GUARDAR (porque lo usa tu profesion o el precio esta bajo), y mide cuanto
-- oro por hora te da el desuello. Solo informa: nunca compra ni publica solo.

local _, GF = ...

local CALLER, AH_CUT, DEFAULTS = GF.CALLER, GF.AH_CUT, GF.DEFAULTS
local Print, Money, ShortMoney, Cfg = GF.Print, GF.Money, GF.ShortMoney, GF.Cfg

-- Datos por personaje (profesiones, recetas, objetos fijados, sesion): cada uno tiene lo suyo.
local LEGACY_OWNER = "Twistice"   -- personaje al que pertenecen los datos guardados antes de las fichas
-- En WoW Forever UnitName devuelve el nombre y el APELLIDO (no hay reino): el nombre completo es "Nombre Apellido",
-- el que hace falta para enviar correo o cuchichear. La ficha de cada personaje se guarda con ese nombre completo;
-- las fichas antiguas ("Nombre-Reino") se renombran la primera vez que entra ese personaje.
-- FICHAS DE PERSONAJE
local function FullName()
  local n, sn = UnitName("player")
  n = n or "?"
  if type(sn) == "string" and sn ~= "" and not n:find(sn, 1, true) then
    local sep = (Constants and Constants.CharacterNameSeparatorConsts
      and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR) or " "
    return n .. sep .. sn
  end
  return n
end

local function FirstName(full)
  return (full or ""):match("^(%S+)") or full or ""
end

local Char, CleanPhantomChars, ResolveFullName
do
  -- Nombres completos ("Nombre Apellido") conocidos con ese nombre de pila: fichas y, si esta, inventario de
  -- BagBrother. Dos o mas = nombre de pila ambiguo (p. ej. dos personajes "Ashes"): no se adivina cual es.
  local function KnownFullNames(first)
    local low, out, seen = (first or ""):lower(), {}, {}
    local function add(nm)
      if type(nm) == "string" and nm:find(" ", 1, true) and not seen[nm] and FirstName(nm):lower() == low then
        seen[nm] = true
        out[#out + 1] = nm
      end
    end
    for key in pairs((GoldFinderDB and GoldFinderDB.chars) or {}) do add(key) end
    local db = _G.BrotherBags
    if type(db) == "table" then
      for _, cc in pairs(db) do
        if type(cc) == "table" then for nm in pairs(cc) do add(nm) end end
      end
    end
    table.sort(out)
    return out
  end

  -- Nombre completo a partir del nombre de pila; si hay dos o mas personajes con ese nombre de pila (o ninguno)
  -- se devuelve tal cual: el usuario elige el banquero en la lista de Ajustes.
  function ResolveFullName(name)
    if not name or name == "" or name:find(" ", 1, true) then return name end
    local list = KnownFullNames(name)
    if #list == 1 then return list[1] end
    return name
  end

  -- Une la tabla src en dst un nivel: lo que dst ya tiene se queda, solo se completa lo que falta.
  local function Union(dst, src)
    for k, v in pairs(src) do if dst[k] == nil then dst[k] = v end end
  end
  -- Une una profesion: rango y maximo, el mayor; recetas aprendidas, fabricaciones, materiales y demas listas se
  -- suman (manda dst si chocan); los demas valores (skillLine...) solo se completan si dst no los tiene.
  local function MergeProf(dp, sp)
    for k, v in pairs(sp) do
      local cur = dp[k]
      if cur == nil then
        dp[k] = v
      elseif (k == "rank" or k == "maxRank") and type(v) == "number" and type(cur) == "number" then
        if v > cur then dp[k] = v end
      elseif type(cur) == "table" and type(v) == "table" then
        Union(cur, v)
      end
    end
  end
  -- Une la ficha src en dst, campo a campo: las tablas se suman un nivel (manda dst), los valores sueltos solo se
  -- copian si dst no los tiene, las profesiones se unen una a una. La sesion va entera y suNeed va junto a
  -- suTracked (se copian los dos solo si dst no tiene suNeed), para no mezclar dos sesiones o dos planes.
  local function MergeInto(dst, src)
    for k, v in pairs(src) do
      local cur = dst[k]
      if k == "suNeed" or k == "suTracked" then
        if dst.suNeed == nil and src.suNeed ~= nil then dst.suNeed, dst.suTracked = src.suNeed, src.suTracked end
      elseif cur == nil then
        dst[k] = v
      elseif k == "session" then
        -- dst ya tiene su sesion: se queda la suya
      elseif k == "prof" and type(cur) == "table" and type(v) == "table" then
        for pn, pd in pairs(v) do
          local dp = cur[pn]
          if dp == nil then
            cur[pn] = pd
          elseif type(dp) == "table" and type(pd) == "table" then
            MergeProf(dp, pd)
          end
        end
      elseif type(cur) == "table" and type(v) == "table" then
        Union(cur, v)
      end
    end
  end

  -- fichas antiguas "Nombre-Reino" (y fantasmas "Nombre-" o "Nombre-?") con ese nombre de pila exacto; primero
  -- las que tienen reino
  local function OldKeys(chars, first)
    local olds = {}
    for k, v in pairs(chars) do
      local n2, r2 = k:match("^([^-]+)%-(.*)$")
      if n2 and n2 == first and type(v) == "table" then
        olds[#olds + 1] = { k = k, v = v, real = (r2 ~= "" and r2 ~= "?") }
      end
    end
    table.sort(olds, function(a, b)
      if a.real ~= b.real then return a.real end
      return a.k < b.k
    end)
    return olds
  end

  -- temp: ficha en memoria mientras el juego aun no da el apellido (FullName devuelve solo el nombre de pila).
  -- No se guarda en chars["Nombre"] ni se une nada con el nombre de pila solo: cuando llega el nombre completo,
  -- temp se une a la ficha definitiva (manda temp, es lo mas reciente). done: nombre completo ya revisado en
  -- esta sesion (las fichas antiguas solo se buscan una vez).
  local temp, done

  function Char()
    GoldFinderDB.chars = GoldFinderDB.chars or {}
    local chars = GoldFinderDB.chars
    local name = FirstName(UnitName("player") or "?")
    local full = FullName()
    if not full:find(" ", 1, true) then
      temp = temp or { prof = {}, keep = {}, off = {} }
      return temp
    end
    local c = chars[full]
    if done ~= full then
      done = full
      -- las fichas antiguas solo se reclaman si ningun otro personaje conocido comparte el nombre de pila: con
      -- dos "Ashes" no se sabe de quien son y se dejan como estan
      local alone = true
      for _, k in ipairs(KnownFullNames(name)) do if k ~= full then alone = false end end
      if alone then
        -- manda la ficha completa si ya existe; si no, la que tiene reino; el resto solo completa lo que falta
        for _, o in ipairs(OldKeys(chars, name)) do
          if not c then c = o.v; chars[full] = c else MergeInto(c, o.v) end
          chars[o.k] = nil
        end
      end
    end
    if temp then
      if c then MergeInto(temp, c) end
      c, temp = temp, nil
      chars[full] = c
    end
    if not c then
      c = { prof = {}, keep = {} }
      chars[full] = c
    end
    c.prof, c.keep, c.off = c.prof or {}, c.keep or {}, c.off or {}

    -- Datos de versiones antiguas (comunes a la cuenta): se unen a la ficha de su personaje (nombre de pila exacto).
    local L = GoldFinderDB.legacy
    if L and LEGACY_OWNER and name == LEGACY_OWNER then
      for k, v in pairs(L.prof or {}) do
        local cur = c.prof[k]
        if not cur then
          c.prof[k] = v
        elseif not cur.learned and v.learned then
          v.rank = cur.rank or v.rank
          v.skillLine = cur.skillLine or v.skillLine
          c.prof[k] = v
        end
      end
      for k, v in pairs(L.keep or {}) do c.keep[k] = v end
      if L.session and not c.session then c.session = L.session end
      GoldFinderDB.legacy = nil
    end
    return c
  end

  -- Une y borra las fichas duplicadas sin reino ("Nombre-" o "Nombre-?") que crearon versiones anteriores: solo en
  -- la ficha del nombre completo ("Nombre Apellido") cuando es el unico personaje conocido con ese nombre de pila.
  -- Con dos o mas (o ninguno) se dejan: Char() las reclama al entrar su personaje si no hay duda.
  function CleanPhantomChars()
    local chars = GoldFinderDB and GoldFinderDB.chars
    if not chars then return end
    local phantoms = {}
    for key in pairs(chars) do
      local name, realm = key:match("^([^-]+)-(.*)$")
      if name and (realm == "" or realm == "?") then phantoms[#phantoms + 1] = { key = key, name = name } end
    end
    table.sort(phantoms, function(a, b) return a.key < b.key end)
    for _, ph in ipairs(phantoms) do
      local list = KnownFullNames(ph.name)
      local real = #list == 1 and chars[list[1]] or nil
      if type(real) == "table" and FirstName(list[1]) == ph.name and type(chars[ph.key]) == "table" then
        MergeInto(real, chars[ph.key])
        chars[ph.key] = nil
      end
    end
    -- banquero guardado solo con el nombre de pila: se completa si no hay duda (fichas o BagBrother)
    local b = GoldFinderDB.banker
    if type(b) == "string" and b ~= "" and not b:find(" ", 1, true) then
      GoldFinderDB.banker = ResolveFullName(b)
    end
  end
end
-- FIN DE FICHAS DE PERSONAJE

-- Profesiones que el jugador ha dejado fuera en Ajustes (no reservan materiales ni avisan).
local function ProfOn(prof)
  return not Char().off[prof]
end

local UpdateTracker   -- ventana flotante del siguiente paso (se define mas abajo)

-- Personaje banquero: a el se envia por correo lo que hay que subastar (opcional, ver Ajustes).
-- En el propio banquero no se aplica: ahi se vende normalmente.
local function BankerName()
  local b = Cfg("banker")
  if type(b) ~= "string" then return nil end
  b = b:match("^%s*(.-)%s*$")
  if b == "" then return nil end
  return b
end

-- name = nombre completo o, en datos antiguos, solo el nombre de pila
local function IsMe(name)
  local full = FullName():lower()
  local n = name:lower()
  return n == full or (not n:find(" ", 1, true) and n == FirstName(full):lower())
end

local function ToBanker()
  local b = BankerName()
  if not b then return false end
  return not IsMe(b)
end

local nameMissing = false   -- se activa si algun nombre de objeto aun no esta cargado
-- Respaldo para objetos que el cliente aun no conoce (GetItemInfo no devuelve nada): el tooltip
-- si los pregunta al servidor, asi que se lee el nombre de un tooltip oculto.
local scanTip
local nameCache = {}
local function TooltipName(id)
  if nameCache[id] then return nameCache[id] end
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "GoldFinderScanTip", nil, "GameTooltipTemplate")
  end
  scanTip:SetOwner(UIParent, "ANCHOR_NONE")
  scanTip:ClearLines()
  local ok = pcall(scanTip.SetItemByID, scanTip, id)
  if not ok then pcall(scanTip.SetHyperlink, scanTip, "item:" .. id) end
  local fs = _G["GoldFinderScanTipTextLeft1"]
  local t = fs and fs:GetText()
  if t and t ~= "" and t ~= RETRIEVING_ITEM_INFO then
    nameCache[id] = t
    return t
  end
  return nil
end

local function ItemLink(id)
  local _, link = C_Item.GetItemInfo(id)
  if link then return link end
  local nm = TooltipName(id)
  if nm then return nm end
  nameMissing = true
  if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
  return "item:" .. id
end

local function Median(t)
  local n = #t
  if n == 0 then return nil end
  table.sort(t)
  if n % 2 == 1 then return t[(n + 1) / 2] end
  return (t[n / 2] + t[n / 2 + 1]) / 2
end

-- Historial de Auctionator: mediana de los minimos diarios y dias con datos
local function DayStats(entry)
  local vals = {}
  for day, hi in pairs(entry.h or {}) do
    vals[#vals + 1] = (entry.l and entry.l[day]) or hi
  end
  return Median(vals), #vals
end

local function AHApi()
  return Auctionator and Auctionator.API and Auctionator.API.v1
end

local function TSMValue(source, id)
  if not (TSM_API and TSM_API.GetCustomPriceValue) then return nil end
  local ok, val = pcall(TSM_API.GetCustomPriceValue, source, "i:" .. id)
  if ok and type(val) == "number" then return val end
  return nil
end

-- Precio al que el vendedor te compra: primero el dato del juego, luego la cache de Auctionator
local function VendorPrice(id)
  local sell = select(11, C_Item.GetItemInfo(id))
  if sell and sell > 0 then return sell end
  local v1 = AHApi()
  return v1 and v1.GetVendorPriceByItemID(CALLER, id) or nil
end

-- Precio de referencia: media de la region (TSM) o el tipico de 3+ dias de Auctionator
local function RefPrice(id)
  local region = TSMValue("DBRegionSaleAvg", id)
  if region and region > 0 then return region end
  local db = Auctionator and Auctionator.Database and Auctionator.Database.db
  local e = db and db[tostring(id)]
  if e then
    local typical, ndays = DayStats(e)
    if typical and ndays >= 3 then return typical end
  end
  return nil
end

-- Unidades en bolsas y en el banco
local function Counts(id)
  local bags = C_Item.GetItemCount(id) or 0
  local total = C_Item.GetItemCount(id, true) or bags
  return bags, math.max(total - bags, 0)
end

---------------------------------------------------------------------------
-- PROFESION: memoriza los materiales de las recetas que aprendiste y que aun
-- no son grises (las que suben tu habilidad). Se actualiza al abrir la
-- ventana de la profesion. Asi sabemos que NO vender.
---------------------------------------------------------------------------
local function CacheProfession()
  local T = C_TradeSkillUI
  if not (GoldFinderDB and T and T.GetAllRecipeIDs and T.GetRecipeInfo and T.GetRecipeSchematic) then return end
  if T.IsTradeSkillReady and not T.IsTradeSkillReady() then return end
  if (T.IsTradeSkillGuild and T.IsTradeSkillGuild()) or (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) then return end
  local base = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
  local prof = base and (base.professionName or base.parentProfessionName) or "Profesion"
  local reagents, count, learned, recipes, crafts = {}, 0, {}, {}, {}
  for _, rid in ipairs(T.GetAllRecipeIDs() or {}) do
    local info = T.GetRecipeInfo(rid)
    if info and info.learned and info.name then learned[info.name] = true end   -- recetas que ya sabes
    if info and info.learned then
      -- relativeDifficulty: 0 optimo, 1 medio, 2 facil, 3 gris. Las grises ya no suben habilidad: no se reservan sus materiales.
      local keepMats = (info.relativeDifficulty or 3) <= 2
      local schem = T.GetRecipeSchematic(rid, false)
      local rr = {}
      for _, slot in ipairs(schem and schem.reagentSlotSchematics or {}) do
        local itemID = slot.reagents and slot.reagents[1] and slot.reagents[1].itemID
        if itemID then
          local per = slot.quantityRequired or 1   -- unidades por fabricacion (la reserva se calcula al consultar)
          rr[#rr + 1] = { itemID, per }
          if keepMats then
            local e = reagents[itemID]
            if not e then e = { per = 0, recipe = info.name }; reagents[itemID] = e; count = count + 1 end
            if per > e.per then e.per, e.recipe = per, info.name end
          end
        end
      end
      if keepMats and info.name and #rr > 0 then recipes[info.name] = { d = info.relativeDifficulty, r = rr } end
      -- objeto que produce (para valorar si compensa fabricar)
      local oid, oq = schem and schem.outputItemID, schem and (schem.quantityMin or schem.quantityMax)
      if not oid and T.GetRecipeOutputItemData then
        local okO, od = pcall(T.GetRecipeOutputItemData, rid)
        if okO and type(od) == "table" then oid = od.itemID end
      end
      if oid and info.name and #rr > 0 then crafts[info.name] = { o = oid, q = oq or 1, r = rr, d = info.relativeDifficulty } end
    end
  end
  local oldEntry = Char().prof[prof]
  Char().prof[prof] = {
    maxRank = oldEntry and oldEntry.maxRank or nil,
    reagents = reagents, count = count, time = time(), learned = learned, recipes = recipes, crafts = crafts,
    rank = base and base.skillLevel or nil,   -- habilidad actual, para saber en que tramo de la guia estas
    skillLine = base and base.professionID or nil,
  }
end

local cachePending = false
local function ScheduleCache()
  if cachePending then return end
  cachePending = true
  C_Timer.After(0.6, function()
    cachePending = false
    pcall(CacheProfession)
    xpcall(UpdateTracker, geterrorhandler())
  end)
end

-- Profesiones del personaje y su habilidad, sin abrir ninguna ventana (como hacen Zygor y otros addons).
-- Las recetas y materiales solo se memorizan al abrir la ventana de cada profesion.
local skillSess = {}   -- por profesion: habilidad al empezar la sesion, hora, ultima subida
local function ReadSkills()
  if not (GetProfessions and GetProfessionInfo and GoldFinderDB) then return end
  local P = Char().prof
  local idx = { GetProfessions() }
  for i = 1, 6 do
    local index = idx[i]
    if index then
      local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
      if name and rank then
        local e = P[name]
        if not e then e = { reagents = {}, count = 0 }; P[name] = e end
        local old = e.rank
        e.rank = rank
        e.maxRank = maxRank
        local ss = skillSess[name]
        if not ss then
          skillSess[name] = { start = rank, t = GetTime() }
        elseif old and rank > old then
          ss.flash = GetTime()
        end
        if skillLine then e.skillLine = skillLine end
      end
    end
  end
end

-- SKILLUP FOREVER (opcional): si esta instalado y el ajuste activo, sus rutas de las profesiones que sigues
-- (casilla "Track") dicen que materiales hacen falta de verdad. Sustituyen a la reserva basada en guias para
-- esas profesiones. API publica: SkillUpForever.API.ShoppingList() (lista por profesion con cantidad "need").
local suCache = { t = -10, map = {}, tracked = {}, any = false }
local suLoad = GetTime()
local function SkillUpData()
  if not Cfg("useSkillUp") then return nil end
  local api = _G.SkillUpForever and _G.SkillUpForever.API
  if not (api and api.ShoppingList) then
    -- sin SkillUp (desactivado o desinstalado): su copia de este personaje ya no vale para los demas
    if GoldFinderDB and GetTime() - suLoad > 60 then
      local me = Char()
      if me.suNeed or me.suTracked then me.suNeed, me.suTracked = nil, nil end
    end
    return nil
  end
  local now = GetTime()
  if now - suCache.t > 3 then
    local ok, lists = pcall(api.ShoppingList)
    local map, tracked, any = {}, {}, false
    if ok and type(lists) == "table" then
      for _, l in ipairs(lists) do
        tracked[l.profession] = true
        any = true
        for _, it in ipairs(l.items or {}) do
          local e = map[it.itemID]
          if not e then e = { need = 0, profs = {}, target = l.target }; map[it.itemID] = e end
          e.need = e.need + (it.need or 0)
          e.profs[#e.profs + 1] = l.profession
          e.target = l.target
        end
      end
    end
    suCache = { t = now, map = map, tracked = tracked, any = any }
    -- copia por personaje: asi los demas personajes saben lo que este necesita para su ruta
    if any then
      local snap, trk = {}, {}
      for id2, e in pairs(map) do snap[id2] = { n = e.need, p = table.concat(e.profs, ", "), t = e.target } end
      for pn in pairs(tracked) do trk[pn] = true end
      local me = Char()
      me.suNeed, me.suTracked = snap, trk
    elseif now - suLoad > 60 then
      local me = Char()
      me.suNeed, me.suTracked = nil, nil
    end
  end
  return suCache
end

local function SkillUpNeed(id)
  local d = SkillUpData()
  local e = d and d.map[id]
  if e and e.need > 0 then return e end
  return nil
end

-- Profesion del personaje actual que SkillUp ya planifica: la reserva por guias no se aplica a ella
local function SuOwned(c, prof)
  if not Cfg("useSkillUp") then return false end
  if c == Char() then
    local d = SkillUpData()
    return (d and d.any and d.tracked[prof]) and true or false
  end
  return (c.suTracked and c.suTracked[prof]) and true or false
end

local function ReagentInfoFor(c, id)
  local best
  for prof, data in pairs(c.prof or {}) do
    local e = (not (c.off and c.off[prof]) and not SuOwned(c, prof)) and data.reagents and data.reagents[id] or nil
    if e then
      local need = (e.per or 1) * (Cfg("reserve") or 20)
      if not best or need > best.need then best = { need = need, recipe = e.recipe, prof = prof } end
    end
  end
  return best
end

local function ReagentInfo(id)
  return ReagentInfoFor(Char(), id)
end

-- RECETAS DEL JUEGO (GoldFinderRecipes): umbrales de color exactos de cada receta.
-- y = amarilla desde, (y+g)/2 = verde desde, g = gris desde. Probabilidad de subir un punto:
-- 100% mientras es naranja; despues baja linealmente hasta 0 al ponerse gris: (g - habilidad) / (g - y).
local RoutePlanner = GF.NewRoutePlanner(setmetatable({
  Cfg = function(...) return Cfg(...) end,
  Counts = function(...) return Counts(...) end,
  VendorPrice = function(...) return VendorPrice(...) end,
  AHApi = function(...) return AHApi(...) end,
  SuOwned = function(...) return SuOwned(...) end,
}, { __index = _G }))
local RecipeLookup, SkillUpChance, RecipeColor, BuyPrice, SellValue, PlanRoute, InvalidateRoutes, RouteFor, RouteNeedFor, StepMats, TrainerLearn, RouteStepEntry, GatherZones, PickZone, GatherStepEntry =
  RoutePlanner.RecipeLookup, RoutePlanner.SkillUpChance, RoutePlanner.RecipeColor, RoutePlanner.BuyPrice, RoutePlanner.SellValue, RoutePlanner.PlanRoute, RoutePlanner.InvalidateRoutes, RoutePlanner.RouteFor, RoutePlanner.RouteNeedFor, RoutePlanner.StepMats, RoutePlanner.TrainerLearn, RoutePlanner.RouteStepEntry, RoutePlanner.GatherZones, RoutePlanner.PickZone, RoutePlanner.GatherStepEntry
-- FIN DEL PLANIFICADOR DE RUTA

-- Material que le sirve a la profesion de OTRO de mis personajes (opcional, ver Ajustes).
-- Cuantas unidades lleva (bolsas + banco) un personaje, leido de BagBrother; nil si no hay datos de el
local function StockOf(first, id)
  local db = _G.BrotherBags
  if type(db) ~= "table" then return nil end
  first = first:lower()
  local function sameChar(name)
    local nl = name:lower()
    return nl == first or (not first:find(" ", 1, true) and (nl:match("^(%S+)") or nl) == first)
  end
  local n, found = 0, false
  for _, chars in pairs(db) do
    if type(chars) == "table" then
      for name, bags in pairs(chars) do
        if type(name) == "string" and type(bags) == "table" and sameChar(name) then
          found = true
          for _, bag in pairs(bags) do
            if type(bag) == "table" and type(bag.items) == "table" then
              for _, v in pairs(bag.items) do
                if type(v) == "string" then
                  local iid, cnt = v:match("^(%d+)[^;]*;?(%d*)")
                  if tonumber(iid) == id then n = n + (tonumber(cnt) or 1) end
                end
              end
            end
          end
        end
      end
    end
  end
  return found and n or nil
end

-- Lo que piden tus otros personajes. OtherNeed(id): el que mas pide ({ need, prof, upto, su, who }, para el texto
-- "para <alt>"). OtherNeed(id, true): la suma de todos para la reserva ({ need = suma, who = "A, B", n, list, first }).
-- Cada personaje cuenta una vez, con la misma regla que tu reserva: la mayor de SkillUp, ruta y materiales de
-- recetas (estiman el mismo consumo, no se suman). Las tres fuentes son totales (lo que pide, no lo que falta),
-- asi que a la mayor se le resta una sola vez lo que ese personaje ya lleva (StockOf, BagBrother; 0 sin datos).
local function OtherNeed(id, all)
  local mine = Char()
  local list, sum, best = {}, 0, nil
  for key, c in pairs(GoldFinderDB.chars or {}) do
    if c ~= mine and c.prof then
      local who = key:match("^([^-]+)") or key
      local z
      local sn = Cfg("useSkillUp") and c.suNeed and c.suNeed[id] or nil
      if sn then z = { need = sn.n, prof = sn.p, upto = sn.t, su = true } end
      for _, w in ipairs({ RouteNeedFor(c, id) or false, ReagentInfoFor(c, id) or false }) do
        if w and (not z or w.need > z.need) then z = w end
      end
      local short = z and (z.need - (StockOf(who, id) or 0)) or 0
      if short > 0 then
        local e = { need = short, prof = z.prof, upto = z.upto, su = z.su, who = who }
        list[#list + 1] = e
        sum = sum + e.need
        if not best or e.need > best.need then best = e end
      end
    end
  end
  if not best then return nil end
  if not all then return best end
  table.sort(list, function(x, y) return x.who < y.who end)
  local names = {}
  for i, e in ipairs(list) do names[i] = e.who end
  return { need = sum, who = table.concat(names, ", "), n = #list, list = list, first = best,
    su = best.su, prof = best.prof, upto = best.upto }
end

-- Siguiente paso calculado con tus propias recetas y los precios de la subasta: la receta mas barata
-- que aun te sube de nivel (naranja; si no hay ninguna, amarilla). Solo datos del propio juego.
local function GamePlan(prof, pd)
  if not pd.recipes or not next(pd.recipes) then return nil end
  local v1 = AHApi()
  local best
  for want = 0, 1 do
    for name, rc in pairs(pd.recipes) do
      if rc.d == want and #rc.r > 0 then
        local cost, unknown, craftable = 0, false, nil
        local mats = {}
        for _, m in ipairs(rc.r) do
          local id, qty = m[1], m[2]
          local bags, bank = Counts(id)
          local have = bags + bank
          local can = math.floor(have / qty)
          craftable = craftable and math.min(craftable, can) or can
          local price = v1 and v1.GetAuctionPriceByItemID(CALLER, id) or nil
          if price and price > 0 then cost = cost + price * qty else unknown = true end
          mats[#mats + 1] = { id = id, need = qty, have = have }
        end
        local cand = { name = name, cost = cost, unknown = unknown, craftable = craftable or 0, mats = mats, d = want }
        if not best or (best.unknown and not cand.unknown)
          or (best.unknown == cand.unknown and cand.cost < best.cost) then
          best = cand
        end
      end
    end
    if best then break end
  end
  return best
end

local function NormRecipe(n)
  n = n:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("s of ", " of "):gsub("s$", "")
  return n
end

-- Requisitos para entrenar cada rango (clave: tope de habilidad que da). Fuente: guias de WoW Forever.
local TRAIN_REQ = {
  [75] = { skill = 0, lvl = 0 },
  [150] = { skill = 50, lvl = 10 },
  [225] = { skill = 125, lvl = 20 },
  [300] = { skill = 200, lvl = 35 },
}

local function TrainReq(prof, max)
  local p = (prof or ""):lower()
  if max == 300 and p:find("fish", 1, true) then return { skill = 225, lvl = 35 } end   -- Artisan Pesca: Nat Pagle
  return TRAIN_REQ[max]
end

local RANK_NAMES = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }
local RANK_MAX = { Apprentice = 75, Journeyman = 150, Expert = 225, Artisan = 300 }

-- Instructores de cada rango de una profesion para tu faccion: primero el que anotaste al visitarlo
-- (GoldFinderDB.trainers, ver RecordTrainer) y, si no, el primero de GoldFinderTrainers (guias de Icy Veins).
-- Cada uno: { max, name, npc, zone, x, y, seen = true si viene de tu visita }. nil si no hay ninguno.
local function TrainList(prof)
  local faction = UnitFactionGroup("player") or "?"
  local fac = (faction == "Horde") and "H" or "A"
  local rec = GoldFinderDB and GoldFinderDB.trainers and GoldFinderDB.trainers[faction]
  local mine = rec and rec[prof]
  local p = (prof or ""):lower()
  local static
  for k, v in pairs(GoldFinderTrainers or {}) do
    if p:find(k, 1, true) then static = v; break end
  end
  local out = {}
  for _, max in ipairs({ 75, 150, 225, 300 }) do
    local d, entry = mine and mine[max], nil
    if d then
      entry = { npc = d.npc, zone = d.zone, x = d.x, y = d.y, seen = true }
    else
      local str = static and static[max] and static[max][fac]
      -- el de la zona donde estas si hay uno; si no, el primero de la lista
      local here = GetRealZoneText and GetRealZoneText()
      for part in (str or ""):gmatch("[^;]+") do
        local n, z, x, y = part:match("^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
        if n and (not entry or z == here) then
          entry = { npc = n, zone = z, x = x, y = y }
          if z == here then break end
        end
      end
    end
    if entry then
      entry.max, entry.name = max, RANK_NAMES[max] .. " " .. prof
      out[#out + 1] = entry
    end
  end
  return #out > 0 and out or nil
end
-- FIN DE INSTRUCTORES

-- Siguiente paso de cada profesion activa del personaje (para la ventana flotante opcional): el primer paso de
-- su ruta (o la zona de recoleccion del tramo), con los materiales de ese paso y cuantos tienes (bolsas + banco).
local stepFrom = {}   -- habilidad a la que empezo cada paso (para la barra de progreso del tramo)
local function NextStepList()
  local out = {}
  local me = Char()
  for prof, pd in pairs(me.prof) do
    if ProfOn(prof) and pd.rank then
      local plan = Cfg("gamePlan") and GamePlan(prof, pd) or nil
      if plan then
        out[#out + 1] = {
          prof = prof, rank = pd.rank, game = true, recipe = plan.name,
          color = (plan.d == 0) and "naranja" or "amarilla",
          cost = plan.cost, unknown = plan.unknown, craftable = plan.craftable,
          skillLine = pd.skillLine, mats = plan.mats,
        }
      else
        local e = GatherStepEntry(prof, pd)
        if not e and pd.crafts then
          e = RouteStepEntry(prof, pd, RouteFor(me, prof, pd.rank + (Cfg("routeSpan") or 25)))
          if e then
            local sf = stepFrom[prof]
            if sf and sf.what == e.what and sf.from <= e.from then
              e.from = sf.from
            else
              stepFrom[prof] = { what = e.what, from = e.from }
            end
          end
        end
        local train, trainState
        if pd.maxRank then
          for _, d in ipairs(TrainList(prof) or {}) do
            if d.max > pd.maxRank then
              local rq = TrainReq(prof, d.max)
              local ok = (not rq) or (pd.rank >= rq.skill and UnitLevel("player") >= rq.lvl)
              if pd.rank >= pd.maxRank then
                train, trainState = d, ok and "cap" or "capblocked"
              elseif ok then
                train, trainState = d, "ready"
              elseif pd.rank >= pd.maxRank - 5 then
                train, trainState = d, "blocked"
              end
              break
            end
          end
        end
        -- sin paso de ruta (tope alcanzado o ninguna receta te sube) pero con instructor: solo el aviso de entrenar
        if not e and train then
          e = { trainOnly = true, prof = prof, rank = pd.rank, from = pd.rank, upto = math.max(pd.maxRank, pd.rank),
            skillLine = pd.skillLine, mats = {} }
        end
        if e then
          e.train, e.trainState = train, trainState
          out[#out + 1] = e
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.prof < b.prof end)
  return out
end

-- DONDE CONSEGUIR LOS MATERIALES: el addon lo aprende solo. Al abrir un botin, si algo le sirve a
-- alguna profesion de tus personajes, anota la zona y la criatura (datos de toda la cuenta).
local function NeededByAny(id)
  for _, c in pairs(GoldFinderDB.chars or {}) do
    if c.prof and (RouteNeedFor(c, id) or ReagentInfoFor(c, id)) then return true end
  end
  return false
end

-- Cuero (comercio / cuero, clase 7 subclase 6): se anota siempre, para saber donde farmearlo (pestana Cuero).
local function IsLeather(id)
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
  return classID == 7 and subClassID == 6
end

-- Objeto de uso (bolsa de dormir, juguetes, abalorios con efecto): tiene un efecto "Usar:" y no es consumible
-- (clase 0) ni basura gris. Nunca se recomienda venderlo al vendedor.
local function IsUtilityItem(id)
  local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(id)
  if not classID or classID == 0 then return false end
  local getSpell = C_Item.GetItemSpell or GetItemSpell
  if not (getSpell and getSpell(id)) then return false end
  local q = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
  return q ~= nil and q >= 1
end
-- FIN DE OBJETOS DE USO

local function RecordSources()
  if not GoldFinderDB then return end
  local zone = GetRealZoneText()
  if not zone or zone == "" then return end
  local mob = (UnitExists("target") and UnitIsDead("target")) and UnitName("target") or nil
  for slot = 1, (GetNumLootItems() or 0) do
    local link = GetLootSlotLink(slot)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id and (NeededByAny(id) or IsLeather(id)) then
      local qty = tonumber(select(3, GetLootSlotInfo(slot))) or 1
      GoldFinderDB.sources = GoldFinderDB.sources or {}
      local t = GoldFinderDB.sources[id]
      if not t then t = {}; GoldFinderDB.sources[id] = t end
      local z = t[zone]
      if not z then z = { n = 0 }; t[zone] = z end
      z.n = z.n + qty
      if mob then z.mob = mob end
    end
  end
end

-- "Lo has conseguido en: Arathi Highlands (12, Highland Raptor); ..."
local function SourceText(id)
  local t = GoldFinderDB and GoldFinderDB.sources and GoldFinderDB.sources[id]
  if not t then return "" end
  local arr = {}
  for zone, z in pairs(t) do arr[#arr + 1] = { zone = zone, n = z.n, mob = z.mob } end
  table.sort(arr, function(a, b) return a.n > b.n end)
  local parts = {}
  for i = 1, math.min(#arr, 3) do
    local a = arr[i]
    parts[#parts + 1] = a.zone .. " (" .. a.n .. (a.mob and (", " .. a.mob) or "") .. ")"
  end
  return "\nLo has conseguido en: " .. table.concat(parts, "; ")
end

-- Donde farmear un material, con tus propios datos de botin (sustituye a la tabla de farmeo de Zygor): nil si
-- aun no lo has conseguido en ninguna zona.
local function FarmText(id)
  local s = SourceText(id)
  return s ~= "" and s:sub(2) or nil
end

-- Recetas (patrones, planos...) de una profesion tuya que aun no sabes: no se venden sin mirar.
-- Clase 9 = Receta; la subclase indica la profesion.
local RECIPE_PROF = {
  [1] = "leather", [2] = "tailor", [3] = "engineer", [4] = "blacksmith", [5] = "cook",
  [6] = "alchem", [7] = "first aid", [8] = "enchant", [9] = "fish", [10] = "jewel",
}
local RECIPE_PREFIX = { "Pattern: ", "Recipe: ", "Plans: ", "Schematic: ", "Formula: ", "Manual: ", "Design: " }

local function RecipeToLearn(id)
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
  if classID ~= 9 then return nil end
  local key = RECIPE_PROF[subClassID]
  if not key then return nil end
  local name = C_Item.GetItemInfo(id)
  if not name then return nil end
  for prof, data in pairs((GoldFinderDB and Char().prof) or {}) do
    if prof:lower():find(key, 1, true) and data.learned and ProfOn(prof) then
      local recipe = name
      for _, pre in ipairs(RECIPE_PREFIX) do
        if recipe:sub(1, #pre) == pre then recipe = recipe:sub(#pre + 1); break end
      end
      local target = NormRecipe(recipe)   -- misma comparacion que para tus otros personajes
      for k in pairs(data.learned) do
        if NormRecipe(k) == target then return nil end   -- ya la sabes
      end
      return format("receta de %s que aun no sabes: aprendela si tu nivel lo permite", prof)
    end
  end
  return nil
end

-- Recetas que le sirven a OTRO de tus personajes (opcional, ver Ajustes): si en un vendedor o en tus
-- bolsas hay una receta que un personaje de la cuenta aun no sabe, se avisa. El nivel que pide la
-- receta se lee de su tooltip ("Requires Cooking (175)").
local reqCache = {}
local function RecipeReq(id)
  local c = reqCache[id]
  if c ~= nil then return c or nil end
  if not scanTip then TooltipName(id) end
  if not scanTip then return nil end
  scanTip:SetOwner(UIParent, "ANCHOR_NONE")
  scanTip:ClearLines()
  if not pcall(scanTip.SetItemByID, scanTip, id) then return nil end
  for i = 2, scanTip:NumLines() do
    local fs = _G["GoldFinderScanTipTextLeft" .. i]
    local t = fs and fs:GetText()
    local n = t and t:match("^Requires [%a' ]+ %((%d+)%)")
    if n then
      reqCache[id] = tonumber(n)
      return reqCache[id]
    end
  end
  if scanTip:NumLines() > 1 then reqCache[id] = false end   -- cargado y sin requisito de habilidad
  return nil
end

local function RecipeForOthers(id, includeMine, all)
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
  if classID ~= 9 then return nil end
  local key = RECIPE_PROF[subClassID]
  if not key then return nil end
  local name = C_Item.GetItemInfo(id)
  if not name then return nil end
  local recipe = name
  for _, pre in ipairs(RECIPE_PREFIX) do
    if recipe:sub(1, #pre) == pre then recipe = recipe:sub(#pre + 1); break end
  end
  local target = NormRecipe(recipe)
  local mine = Char()
  local req = RecipeReq(id)
  local out = {}
  for ckey, c in pairs(GoldFinderDB.chars or {}) do
    if (c ~= mine or includeMine) and c.prof then
      for prof, data in pairs(c.prof) do
        if prof:lower():find(key, 1, true) and not (c.off and c.off[prof]) and data.learned and next(data.learned) then
          local known = false
          for k in pairs(data.learned) do
            if NormRecipe(k) == target then known = true; break end
          end
          if not known then
            local rank = data.rank or 0
            out[#out + 1] = {
              who = (c == mine) and "Tu" or (ckey:match("^([^-]+)") or ckey), prof = prof, rank = rank, req = req,
              ready = (not req) or rank >= req,
            }
          end
        elseif c ~= mine and prof:lower():find(key, 1, true) and not (c.off and c.off[prof]) and data.rank
            and ((not req) or data.rank >= req) then
          -- otro personaje con la profesion y el nivel, pero sin lista de recetas (nunca abrio su ventana con esta
          -- version): no se sabe si ya la tiene, se avisa igual para que lo compruebe
          out[#out + 1] = {
            who = ckey:match("^([^-]+)") or ckey, prof = prof, rank = data.rank, req = req, ready = true, unknown = true,
            note = format("%s (%s): abre su ventana de profesion una vez para confirmar si ya la sabe",
              ckey:match("^([^-]+)") or ckey, prof),
          }
        end
      end
    end
  end
  if all then return out end
  for _, ro in ipairs(out) do if not ro.unknown then return ro end end
  return out[1]
end

-- FIN DE RECETAS PARA APRENDER

---------------------------------------------------------------------------
-- DECISION: vender, subastar o guardar (un solo sitio para tooltip y bolsas)
-- Orden: 1 fijado por ti, 2 herramienta de profesion, 3 lo usa tu profesion, 4 vendedor paga mas que la
-- subasta, 5 precio bajo (esperar), 6 subasta si compensa, 7 vendedor.
-- Reserva: la tuya es la mayor de ruta, materiales de recetas y SkillUp (estiman el mismo consumo, no se suman);
-- la de tus otros personajes es la suma de lo que pide cada uno. Total = tuya + otros personajes.
---------------------------------------------------------------------------
local Decide, SellQty = GF.NewDecision({
  AHApi = function(...) return AHApi(...) end,
  VendorPrice = function(...) return VendorPrice(...) end,
  TSMValue = function(...) return TSMValue(...) end,
  Cfg = function(...) return Cfg(...) end,
  Char = function(...) return Char(...) end,
  Counts = function(...) return Counts(...) end,
  SkillUpNeed = function(...) return SkillUpNeed(...) end,
  RouteNeedFor = function(...) return RouteNeedFor(...) end,
  ReagentInfo = function(...) return ReagentInfo(...) end,
  RecipeToLearn = function(...) return RecipeToLearn(...) end,
  RecipeForOthers = function(...) return RecipeForOthers(...) end,
  OtherNeed = function(...) return OtherNeed(...) end,
  IsUtilityItem = function(...) return IsUtilityItem(...) end,
  RefPrice = function(...) return RefPrice(...) end,
  ToBanker = function(...) return ToBanker(...) end,
  QuestNeed = GF.QuestNeed,
  ItemInfoInstant = GF.ItemInfoInstant,
  ItemQuality = GF.ItemQuality,
})
-- FIN DE DECISION

---------------------------------------------------------------------------
-- TOOLTIP
---------------------------------------------------------------------------
-- Recetas: quien (tu u otro personaje) aun no la sabe, con el nivel que pide la receta
local function RecipeLines(tooltip, id)
  if not Cfg("crossChars") then return end
  local list = RecipeForOthers(id, true, true)
  if not list or #list == 0 then return end
  for _, ro in ipairs(list) do
    if ro.unknown then
      tooltip:AddLine("  " .. ro.note, 1, 0.82, 0)
    else
      tooltip:AddLine(format("  %s (%s %d%s) no la sabe: %s", ro.who, ro.prof, ro.rank,
        ro.req and (", pide " .. ro.req) or "", ro.ready and "puede aprenderla" or "aun le falta habilidad"),
        ro.ready and 0.35 or 1, ro.ready and 0.92 or 0.65, ro.ready and 0.55 or 0.25)
    end
  end
end

-- Lo que llevan tus otros personajes (bolsas y banco), leido de BagBrother (el addon de Bagnon): sirve para
-- avisar "te faltan X: Ashes tiene Y" antes de comprar algo que ya tienes en otro personaje.
local function OtherStock(id)
  local db = _G.BrotherBags
  if type(db) ~= "table" then return nil end
  local me = FullName():lower()
  local out = {}
  for _, chars in pairs(db) do
    if type(chars) == "table" then
      for name, bags in pairs(chars) do
        if type(name) == "string" and type(bags) == "table" and name:lower() ~= me then
          local n = 0
          for _, bag in pairs(bags) do
            if type(bag) == "table" and type(bag.items) == "table" then
              for _, v in pairs(bag.items) do
                if type(v) == "string" then
                  local iid, cnt = v:match("^(%d+)[^;]*;?(%d*)")
                  if tonumber(iid) == id then n = n + (tonumber(cnt) or 1) end
                end
              end
            end
          end
          if n > 0 then out[#out + 1] = { who = name, n = n } end
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.n > b.n end)
  return out
end

local function TipAdvice(tooltip, data)
  if not Cfg("tip") or not (data and data.id) then return end
  local id = data.id
  local bags, bank = Counts(id)
  local d = Decide(id, bags, bank, false)
  if d.verdict == "NONE" then
    if d.reason then tooltip:AddLine("GoldFinder: " .. d.reason, 0.6, 0.6, 0.6) end
    return
  end

  if d.verdict == "KEEP" then
    tooltip:AddLine("|cff6cb4ffGoldFinder: GUARDAR|r  " .. d.reason, 1, 1, 1)
    if bags + bank > 0 then
      tooltip:AddLine(format("  Tienes %d en bolsas y %d en el banco.", bags, bank), 0.7, 0.7, 0.7)
    end
    local qheld = d.quest and math.min(d.quest.n or 0, bags + bank) or 0
    if qheld > 0 then
      tooltip:AddLine(format("  %d reservados para mision(es): %s", qheld, table.concat(d.quest.quests or {}, ", ")),
        1, 0.82, 0, true)
    end
    if d.need and bags + bank < d.need then
      local others = OtherStock(id)
      if others and #others > 0 then
        local parts = {}
        for i, o in ipairs(others) do
          if i <= 3 then parts[#parts + 1] = format("%s %d", o.who, o.n) end
        end
        tooltip:AddLine(format("  Te faltan %d: otros personajes tienen %s. Pidelos por correo antes de comprar.",
          d.need - bags - bank, table.concat(parts, ", ")), 0.42, 0.71, 1, true)
      end
    end
    RecipeLines(tooltip, id)
    return
  end

  local color = d.verdict == "AH" and "|cff33ff99" or "|cffffa040"
  tooltip:AddLine(format("%sGoldFinder: %s|r  subasta %s (neto) | vendedor %s",
    color, d.verdict == "AH" and "SUBASTA" or "VENDEDOR",
    d.ahNet > 0 and Money(d.ahNet) or "sin datos", d.vendor > 0 and Money(d.vendor) or "-"), 1, 1, 1)
  -- solo se valora y se vende lo que sobra de la reserva (tus profesiones y las de tus otros personajes)
  local n = d.sellQty or bags
  local held = math.min(d.reserve or 0, bags + bank)
  -- objetos de mision: su propia linea; el resto de la reserva, con sus profesiones y otros personajes
  local qheld = d.quest and math.min(d.quest.n or 0, held) or 0
  if qheld > 0 then
    tooltip:AddLine(format("  %d reservados para mision(es): %s", qheld, table.concat(d.quest.quests or {}, ", ")),
      1, 0.82, 0, true)
  end
  if held - qheld > 0 then
    tooltip:AddLine(format("  %d reservados para %s: %s %d de tus %d en bolsas.", held - qheld,
      (d.quest and d.reserveOther or d.reserveFor) or "tus profesiones",
      d.verdict == "AH" and "se subastan" or "se venden", n, bags), 0.42, 0.71, 1, true)
  elseif qheld > 0 then
    tooltip:AddLine(format("  %s %d de tus %d en bolsas.", d.verdict == "AH" and "Se subastan" or "Se venden", n, bags),
      0.42, 0.71, 1, true)
  end
  if d.reason and d.verdict == "AH" then tooltip:AddLine("  " .. d.reason, 0.7, 0.7, 0.7, true) end
  if n > 0 and d.ahNet > 0 and d.vendor > 0 then
    local gain = (d.ahNet - d.vendor) * n
    tooltip:AddLine(format("  Tus %d u.: subasta %s | vendedor %s | diferencia %s%s",
      n, Money(d.ahNet * n), Money(d.vendor * n), gain >= 0 and "+" or "-", Money(math.abs(gain))),
      0.8, 0.8, 0.8)
    if d.verdict == "VENDOR" and d.ahNet > d.vendor then
      tooltip:AddLine("  La subasta gana poco: no compensa publicarlo.", 1, 0.8, 0.4)
    end
  end
  if d.verdict == "AH" then
    if d.toBanker then tooltip:AddLine("  Enviar a " .. BankerName() .. " para subastar.", 0.42, 0.71, 1) end
    tooltip:AddLine("  (si el objeto esta ligado no se puede subastar)", 0.6, 0.6, 0.6)
  end
  local o = Cfg("crossChars") and OtherNeed(id) or nil
  if o and o.su and bags + bank > 0 then
    tooltip:AddLine(format("  %s necesita %d mas para su ruta de %s: enviale hasta %d por correo.",
      o.who, o.need, o.prof, math.min(bags + bank, o.need)), 0.42, 0.71, 1, true)
  end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip == GameTooltip or tooltip == ItemRefTooltip then pcall(TipAdvice, tooltip, data) end
  end)
end

---------------------------------------------------------------------------
-- SESION: oro por hora del cuero que recoges, por zona
---------------------------------------------------------------------------
local function Sess()
  local c = Char()
  c.session = c.session or
    { start = time(), last = nil, secs = 0, total = 0, count = 0, items = {}, zones = {} }
  return c.session
end

-- Cuero registrado en esta sesion de juego que aun no esta en disco (WoW lo guarda al cerrar sesion).
-- Solo se muestra de forma informativa; nunca avisa en el chat.
local sessionBaseline = { count = 0, total = 0 }

local function MarkSessionBaseline()
  local s = Sess()
  sessionBaseline = { count = s.count, total = s.total }
end

local function UnsavedUnits()
  local s = Sess()
  return math.max(0, s.count - sessionBaseline.count)
end

local function UnitValue(id)
  local v1 = AHApi()
  local ah = v1 and v1.GetAuctionPriceByItemID(CALLER, id)
  local ahNet = (ah and ah > 0) and ah * (1 - AH_CUT) or 0
  return math.max(ahNet, VendorPrice(id) or 0)
end

local function RecordLoot(id, count)
  local s = Sess()
  local now = time()
  local zone = GetRealZoneText and GetRealZoneText() or "?"
  if not zone or zone == "" then zone = "?" end
  local dt = s.last and math.min(now - s.last, 300) or 0   -- huecos de mas de 5 min no cuentan
  s.last = now
  s.secs = s.secs + dt
  local value = UnitValue(id) * count
  s.total, s.count = s.total + value, s.count + count
  local it = s.items[id] or { count = 0, value = 0 }
  it.count, it.value = it.count + count, it.value + value
  s.items[id] = it
  local z = s.zones[zone] or { secs = 0, value = 0, count = 0 }
  z.secs, z.value, z.count = z.secs + dt, z.value + value, z.count + count
  s.zones[zone] = z
end

local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("CHAT_MSG_LOOT")
lootFrame:SetScript("OnEvent", function(_, _, text, ...)
  if not GoldFinderDB or not Cfg("track") then return end
  if select(11, ...) ~= UnitGUID("player") then return end   -- solo tu botin
  local msg = tostring(text)
  local id = tonumber(msg:match("item:(%d+)"))
  if not id then return end
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
  if not (classID == 7 and subClassID == 6) then return end   -- solo cuero y pieles
  pcall(RecordLoot, id, tonumber(msg:match("|h|r%s*x(%d+)")) or 1)
end)

---------------------------------------------------------------------------
-- ACCIONES con Auctionator (siempre confirmas tu)
---------------------------------------------------------------------------
local function StartFullScan()
  if not (Auctionator and Auctionator.State and Auctionator.Config) then
    Print("Auctionator no esta listo.")
    return
  end
  local ok, err = pcall(function()
    if Auctionator.Config.Get(Auctionator.Config.Options.REPLICATE_SCAN) then
      Auctionator.State.FullScanFrameRef:InitiateScan()
    else
      Auctionator.State.IncrementalScanFrameRef:InitiateScan()
    end
  end)
  if ok then Print("Escaneo pedido a Auctionator. Al terminar, la ventana se actualiza sola.")
  else Print("No pude iniciar el escaneo: " .. tostring(err)) end
end

local function ScanAgeText()
  local st = Auctionator and Auctionator.SavedState
  local t = st and math.max(st.TimeOfLastReplicateScan or 0, st.TimeOfLastBrowseScan or 0) or 0
  if t == 0 then return "Aun no hay un escaneo registrado." end
  return format("Ultimo escaneo: hace %d min.", floor((time() - t) / 60))
end

-- Prepara el objeto en la pestana Selling de Auctionator; publicas tu
local function SellItem(id)
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then Print("Abre la casa de subastas primero."); return end
  local loc
  for _, s in ipairs(GF.BagSlots()) do
    if s.id == id then
      loc = ItemLocation:CreateFromBagAndSlot(s.bag, s.slot)
      break
    end
  end
  if not loc or not loc:IsValid() or not C_AuctionHouse.IsSellItemValid(loc) then
    Print("No puedo preparar ese objeto (esta ligado o ya no esta en la bolsa).")
    return
  end
  local ok = pcall(function()
    AuctionHouseFrame.ItemSellFrame:SetItem(nil, nil, false)
    AuctionHouseFrame.CommoditiesSellFrame:SetItem(nil, nil, false)
    AuctionatorTabs_Selling:Click()
    local itemLink = C_Item.GetItemLink(loc)
    AuctionatorBagCacheFrame:CacheLinkInfo(itemLink, function()
      pcall(function()
        local info = Auctionator.Groups.Utilities.ToPostingItem(AuctionatorBagCacheFrame:GetByLinkInstant(itemLink, true))
        info.itemLink, info.location = itemLink, loc
        info.count = C_AuctionHouse.GetAvailablePostCount(loc)
        Auctionator.EventBus:RegisterSource(SellItem, "GoldFinderSell")
        Auctionator.EventBus:Fire(SellItem, Auctionator.Selling.Events.BagItemClicked, info)

        -- cantidad recomendada (Auctionator pone por defecto todo lo que tienes)
        local qty = SellQty(id)
        local function apply()
          local sf = AuctionatorSellingFrame and AuctionatorSellingFrame.SaleItemFrame
          if sf and sf.Quantity and qty > 0 then
            local limit = sf.GetPostLimit and sf:GetPostLimit() or qty
            sf.Quantity:SetNumber(math.min(qty, limit))
          end
        end
        apply()
        C_Timer.After(0.3, function() pcall(apply) end)
        if qty > 0 and qty < (info.count or qty) then
          Print(format("Preparado para publicar %d de tus %d: el resto queda reservado para tus profesiones.", qty, info.count))
        end
      end)
    end)
  end)
  if not ok then
    pcall(function() AuctionatorTabs_Selling:Click() end)
    Print("Abri la pestana Selling pero no pude seleccionar el objeto: haz alt+clic sobre el en tu bolsa.")
  end
end

---------------------------------------------------------------------------
-- DATOS PARA LA VENTANA
---------------------------------------------------------------------------
local function BagRows()
  local sum = { sell = 0, nAH = 0, nVendor = 0, nKeep = 0 }
  if not GF.BagApiReady() then return {}, sum end
  local items = {}
  for _, s in ipairs(GF.BagSlots()) do
    local e = items[s.id]
    if not e then e = { bags = 0, bound = s.bound }; items[s.id] = e end
    e.bags = e.bags + s.count
  end
  local rows = {}
  for id, e in pairs(items) do
    local _, bank = Counts(id)
    local d = Decide(id, e.bags, bank, e.bound)
    -- vender y subastar: solo lo que sobra de la reserva (Decide ya lo calcula igual que SellQty)
    local selling = d.verdict == "AH" or d.verdict == "VENDOR"
    d.id, d.count, d.bank, d.bound = id, e.bags, bank, e.bound
    d.value = d.unit * (selling and d.sellQty or e.bags)
    if d.verdict == "AH" and d.toBanker and not e.bound then
      sum.nBank = (sum.nBank or 0) + 1
      sum.bankValue = (sum.bankValue or 0) + d.value
    end
    if d.verdict == "AH" then sum.nAH, sum.sell = sum.nAH + 1, sum.sell + d.value
    elseif d.verdict == "VENDOR" then sum.nVendor, sum.sell = sum.nVendor + 1, sum.sell + d.value
    elseif d.verdict == "KEEP" then sum.nKeep = sum.nKeep + 1 end
    rows[#rows + 1] = d
  end
  local order = { AH = 1, VENDOR = 2, KEEP = 3, NONE = 4 }
  table.sort(rows, function(a, b)
    if order[a.verdict] ~= order[b.verdict] then return order[a.verdict] < order[b.verdict] end
    return a.value > b.value
  end)
  return rows, sum
end

local function SkinRank()
  for prof, d in pairs(Char().prof) do
    if prof:lower():find("skin") then return d.rank end
  end
  return nil
end

local function LeatherRows()
  local v1 = AHApi()
  if not (v1 and Auctionator.Database and Auctionator.Database.db) then return {} end
  local rows = {}
  for key, entry in pairs(Auctionator.Database.db) do
    if type(key) == "string" and key:match("^%d+$") and entry.m and entry.m > 0 then
      local id = tonumber(key)
      local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
      if classID == 7 and subClassID == 6 then
        local vendor = VendorPrice(id)
        local region = TSMValue("DBRegionSaleAvg", id)
        local ref = RefPrice(id)
        local netAH = entry.m * (1 - AH_CUT)
        -- el consejo sale de la misma decision que el tooltip y las bolsas (profesiones propias y de otros
        -- personajes, cantidad que tienes, precio bajo...)
        local bags, bank = Counts(id)
        local d = Decide(id, bags, bank, false)
        local advice
        if d.verdict == "KEEP" then
          if d.forOther then advice = "|cff6cb4ffGuarda: para " .. d.forOther .. "|r"
          elseif d.manual then advice = "|cff6cb4ffGuarda: fijado|r"
          elseif d.reason and d.reason:find("precio bajo", 1, true) then advice = "|cff6cb4ffGuarda: barato|r"
          else advice = "|cff6cb4ffGuarda: receta|r" end
        elseif d.verdict == "VENDOR" then advice = "|cffffa640Al vendedor|r"
        elseif d.verdict == "AH" then
          advice = (ref and entry.m >= ref * 1.15) and "|cff59eb8dSubasta ya|r" or "Subasta"
        else advice = "-" end
        rows[#rows + 1] = {
          id = id, price = entry.m, region = region, advice = advice,
          stack = math.max(netAH, vendor or 0) * 20, owned = bags + bank, farm = FarmText(id),
        }
      end
    end
  end
  -- primero lo que tienes, luego lo que tu Desuello alcanza, y despues el resto; en cada grupo por valor de pila
  local rank = SkinRank()
  local function group(r)
    if r.owned > 0 then return 1 end
    if r.farm and r.farm.req and rank and r.farm.req <= rank then return 2 end
    return 3
  end
  table.sort(rows, function(a, b)
    local ga, gb = group(a), group(b)
    if ga ~= gb then return ga < gb end
    return a.stack > b.stack
  end)
  return rows
end

---------------------------------------------------------------------------
-- VENTANA (pestana de la subasta y ventana propia con /gf)
---------------------------------------------------------------------------
local uiInstances, PAL, GREEN, ORANGE, BLUE, DIM, Flat, NewFrame, Text, Btn, Skin =
  GF.UI.instances, GF.UI.PAL, GF.UI.GREEN, GF.UI.ORANGE, GF.UI.BLUE, GF.UI.DIM,
  GF.UI.Flat, GF.UI.NewFrame, GF.UI.Text, GF.UI.Btn, GF.UI.Skin

-- Boton Subastar de la lista Bolsas: calcula precio y cantidad (como una operacion de TSM) y publica con UN clic.
-- Nunca publica sin clic: cada clic es una sola llamada a la API de la subasta. Se expone en Skin.Auction.
GF.InitAuction({
  Cfg = function(...) return Cfg(...) end,
  AHApi = function(...) return AHApi(...) end,
  TSMValue = function(...) return TSMValue(...) end,
  RefPrice = function(...) return RefPrice(...) end,
  SellQty = function(...) return SellQty(...) end,
  VendorPrice = function(...) return VendorPrice(...) end,
  Money = function(...) return Money(...) end,
  Print = function(...) return Print(...) end,
  BankerName = function(...) return BankerName(...) end,
})

local ROW_H, ACT_W = 30, 112
-- Las columnas se estrechan cuando hay poco ancho (por ejemplo dentro de la casa de subastas).
local function PlaceCols(owner, name, c1, c2, c3, hasIcon, w, act)
  act = act or ACT_W   -- espacio de los botones (poco si la lista no tiene botones)
  local narrow = (w or 900) < 720
  local w3, w2, w1 = narrow and 110 or 150, narrow and 110 or 150, narrow and 90 or 110
  c3:ClearAllPoints(); c3:SetPoint("RIGHT", owner, "RIGHT", -act, 0); c3:SetWidth(w3); c3:SetJustifyH("RIGHT")
  c2:ClearAllPoints(); c2:SetPoint("RIGHT", owner, "RIGHT", -(act + w3 + 8), 0); c2:SetWidth(w2); c2:SetJustifyH("RIGHT")
  c1:ClearAllPoints(); c1:SetPoint("RIGHT", owner, "RIGHT", -(act + w3 + w2 + 16), 0); c1:SetWidth(w1); c1:SetJustifyH("RIGHT")
  name:ClearAllPoints()
  name:SetPoint("LEFT", owner, "LEFT", hasIcon and 38 or 12, 0)
  name:SetPoint("RIGHT", owner, "RIGHT", -(act + w3 + w2 + w1 + 24), 0)
end

local scrollCount = 0
local function MakeList(parent)
  local v = CreateFrame("Frame", nil, parent)
  v:SetAllPoints(parent)
  local head = CreateFrame("Frame", nil, v)
  head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(24)
  local hb = Flat(head, "BACKGROUND", { 0, 0, 0, 0.30 }); hb:SetAllPoints()
  local hName, h1, h2, h3 = Text(head, 11, PAL.gold), Text(head, 11, PAL.gold), Text(head, 11, PAL.gold), Text(head, 11, PAL.gold)
  PlaceCols(head, hName, h1, h2, h3, true)

  scrollCount = scrollCount + 1
  local sf = CreateFrame("ScrollFrame", "GoldFinderScroll" .. scrollCount, v, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -26)
  sf:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", -26, 0)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(700, 10)
  sf:SetScrollChild(content)
  local rowFrames = {}
  local curW = 700
  local curAct = ACT_W
  local function relayout()
    PlaceCols(head, hName, h1, h2, h3, true, curW, curAct)
    for _, r in ipairs(rowFrames) do PlaceCols(r, r.name, r.c1, r.c2, r.c3, true, curW, curAct) end
  end
  sf:SetScript("OnSizeChanged", function(_, w)
    if w and w > 0 then content:SetWidth(w); curW = w; relayout() end
  end)

  local empty = Text(v, 14, PAL.dim, "CENTER")
  empty:SetPoint("CENTER", v, "CENTER", 0, 0)
  empty:SetWordWrap(true)
  empty:SetWidth(500)

  local function MakeRow(i)
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW_H)
    local zebra = Flat(row, "BACKGROUND", { 1, 1, 1, (i % 2 == 0) and 0.03 or 0 })
    zebra:SetAllPoints()
    -- resaltado de las listas de Blizzard (registro de misiones) al pasar el raton
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name, row.c1, row.c2, row.c3 = Text(row, 12), Text(row, 12), Text(row, 12), Text(row, 12)
    PlaceCols(row, row.name, row.c1, row.c2, row.c3, true, curW, curAct)
    row.act = {}
    for k = 1, 2 do
      local b = Btn(row, "", 50, 20)
      b:SetPoint("RIGHT", row, "RIGHT", -6 - (2 - k) * 54, 0)
      b:Hide()
      row.act[k] = b
    end
    row:SetScript("OnEnter", function(self)
      if self.data and self.data.id then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.data.id)
        if self.data.reason then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("GoldFinder: " .. self.data.reason, 0.42, 0.71, 1, true)
        end
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Mayus+clic en la fila: accion secundaria de la fila (p. ej. abrir el objeto en Auctionator)
    row:SetScript("OnClick", function(self)
      if self.data and self.data.shift and IsShiftKeyDown() then self.data.shift() end
    end)
    return row
  end

  function v.setHeaders(a, b, c, d) hName:SetText(a or ""); h1:SetText(b or ""); h2:SetText(c or ""); h3:SetText(d or "") end

  function v.setRows(data, emptyMsg)
    local n = math.min(#data, 200)
    for i = 1, n do
      local row = rowFrames[i]
      if not row then row = MakeRow(i); rowFrames[i] = row end
      local d = data[i]
      row.data = d
      if d.id then
        row.icon:SetTexture((C_Item.GetItemIconByID and C_Item.GetItemIconByID(d.id)) or 134400)
        row.icon:Show()
      else
        row.icon:Hide()
      end
      row.name:SetText(d.name or (d.id and ItemLink(d.id)) or "")
      row.c1:SetText(d.c1 or ""); row.c2:SetText(d.c2 or ""); row.c3:SetText(d.c3 or "")
      for k = 1, 2 do
        local a, b = d.actions and d.actions[k], row.act[k]
        if a then
          b.label:SetText(a[1])
          b:SetScript("OnClick", function() a[2]() end)
          -- opcional: a.tip(tooltip) al pasar el raton y a.disabled (boton apagado; el tooltip sigue saliendo)
          if b.gfEnter == nil then b.gfEnter, b.gfLeave = b:GetScript("OnEnter") or false, b:GetScript("OnLeave") or false end
          if a.tip then
            b:SetScript("OnEnter", function(self)
              GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
              pcall(a.tip, GameTooltip)
              GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
          else
            b:SetScript("OnEnter", b.gfEnter or nil)
            b:SetScript("OnLeave", b.gfLeave or nil)
          end
          if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
          if a.disabled then b:Disable() else b:Enable() end
          b:Show()
        else
          b:Hide()
        end
      end
      row:Show()
    end
    for i = n + 1, #rowFrames do rowFrames[i]:Hide() end
    -- sin botones en la lista: ese espacio se devuelve a las columnas
    local anyAct = false
    for i = 1, n do
      if data[i].actions and #data[i].actions > 0 then anyAct = true; break end
    end
    curAct = anyAct and ACT_W or 8
    relayout()
    content:SetHeight(math.max(n * ROW_H, 1))
    if n == 0 then empty:SetText(emptyMsg or ""); empty:Show() else empty:Hide() end
  end
  return v
end

local function Card(parent, title)
  -- recuadro con el borde de los tooltips; sin BackdropTemplate, el fondo plano de antes
  local f = NewFrame("Frame", nil, parent, "BackdropTemplate") or CreateFrame("Frame", nil, parent)
  f:SetSize(200, 96)
  local okB = f.SetBackdrop and pcall(f.SetBackdrop, f, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  if okB then
    f:SetBackdropColor(0, 0, 0, 0.45)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  else
    local bg = Flat(f, "BACKGROUND", PAL.card); bg:SetAllPoints()
  end
  f.title = Text(f, 11, PAL.gold); f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetText(title)
  f.value = Text(f, 20, PAL.gold); f.value:SetPoint("TOPLEFT", 14, -32)
  f.sub = Text(f, 11); f.sub:SetPoint("TOPLEFT", 14, -68)
  return f
end

local function MakeSummary(parent)
  local v = CreateFrame("Frame", nil, parent)
  v:SetAllPoints(parent)
  v.c1 = Card(v, "PARA VENDER")
  v.c2 = Card(v, "PARA GUARDAR")
  v.c3 = Card(v, "SESION DE CUERO")
  local function layout(w)
    local cw = math.max(150, math.floor(((w or 744) - 24) / 3))
    for i, c in ipairs({ v.c1, v.c2, v.c3 }) do
      c:SetWidth(cw)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", v, "TOPLEFT", (i - 1) * (cw + 12), 0)
    end
  end
  layout()
  v:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then layout(w) end end)
  local tt = Text(v, 13, PAL.gold); tt:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -122); tt:SetText("Que hacer ahora")
  v.tips = Text(v, 13, PAL.text)
  v.tips:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -148)
  v.tips:SetPoint("TOPRIGHT", v, "TOPRIGHT", 0, -148)
  v.tips:SetWordWrap(true)
  v.tips:SetJustifyV("TOP")
  v.tips:SetSpacing(6)
  return v
end

-- NIVEL DE ZONA: rangos aproximados de nivel de las zonas de Classic. Sirven para avisar si una zona
-- recomendada es peligrosa para tu personaje (o se te ha quedado pequena). Son orientativos.
local ZONE_LEVELS = {
  ["Durotar"] = { 1, 10 }, ["Mulgore"] = { 1, 10 }, ["Tirisfal Glades"] = { 1, 10 },
  ["Elwynn Forest"] = { 1, 10 }, ["Teldrassil"] = { 1, 10 }, ["Dun Morogh"] = { 1, 10 },
  ["Silverpine Forest"] = { 10, 20 }, ["The Barrens"] = { 10, 25 }, ["Westfall"] = { 10, 20 },
  ["Loch Modan"] = { 10, 20 }, ["Darkshore"] = { 10, 20 }, ["Redridge Mountains"] = { 15, 25 },
  ["Stonetalon Mountains"] = { 15, 27 }, ["Ashenvale"] = { 18, 30 }, ["Duskwood"] = { 18, 30 },
  ["Wetlands"] = { 20, 30 }, ["Hillsbrad Foothills"] = { 20, 30 }, ["Thousand Needles"] = { 25, 35 },
  ["Alterac Mountains"] = { 30, 40 }, ["Arathi Highlands"] = { 30, 40 }, ["Desolace"] = { 30, 40 },
  ["Stranglethorn Vale"] = { 30, 45 }, ["Badlands"] = { 35, 45 }, ["Swamp of Sorrows"] = { 35, 45 },
  ["Dustwallow Marsh"] = { 35, 45 }, ["Tanaris"] = { 40, 50 }, ["Feralas"] = { 40, 50 },
  ["The Hinterlands"] = { 40, 50 }, ["Searing Gorge"] = { 43, 50 }, ["Azshara"] = { 45, 55 },
  ["Blasted Lands"] = { 45, 55 }, ["Un'Goro Crater"] = { 48, 55 }, ["Felwood"] = { 48, 55 },
  ["Burning Steppes"] = { 50, 58 }, ["Western Plaguelands"] = { 51, 58 }, ["Eastern Plaguelands"] = { 53, 60 },
  ["Winterspring"] = { 55, 60 }, ["Silithus"] = { 55, 60 }, ["Moonglade"] = { 55, 60 },
}

-- Devuelve el rango de la zona y si es peligrosa ("hard"/"danger") o se queda baja ("low") para tu nivel
local function ZoneInfo(zone)
  local r = zone and ZONE_LEVELS[zone]
  if not r then return nil end
  local lvl = UnitLevel("player") or 1
  local state
  if lvl < r[1] - 3 then state = "danger"
  elseif lvl < r[1] then state = "hard"
  elseif lvl > r[2] + 10 then state = "low" end
  return r[1], r[2], state, lvl
end

local function ZoneTag(zone)
  local lo, hi, state, lvl = ZoneInfo(zone)
  if not lo then return "" end
  if state == "danger" then return format(" |cffff6666(nivel %d-%d: muy peligrosa para tu nivel %d)|r", lo, hi, lvl) end
  if state == "hard" then return format(" |cffffa640(nivel %d-%d: exigente para tu nivel %d)|r", lo, hi, lvl) end
  if state == "low" then return format(" |cff8a8a96(nivel %d-%d: te queda baja)|r", lo, hi) end
  return format(" |cff8a8a96(nivel %d-%d)|r", lo, hi)
end

-- Anade el nivel a cada zona que aparezca en un texto ("Silverpine Forest, The Barrens o Ashenvale")
local function AnnotateZones(text)
  local names = {}
  for name in pairs(ZONE_LEVELS) do names[#names + 1] = name end
  table.sort(names, function(a, b) return #a > #b end)
  for _, name in ipairs(names) do
    local i, j = text:find(name, 1, true)
    if i then text = text:sub(1, j) .. ZoneTag(name) .. text:sub(j + 1) end
  end
  return text
end

-- Texto del paso: fabricar (Cocina, Peleteria...) o recolectar (Pesca, Desuello...).
local function StepText(e)
  if e.game then
    local costTxt = e.cost > 0 and (", ~" .. ShortMoney(e.cost) .. (e.unknown and "+" or "") .. " c/u") or ""
    local canTxt = e.craftable > 0 and (", puedes hacer " .. e.craftable) or ""
    return format("fabrica %s (%s)%s%s", e.recipe, e.color, costTxt, canTxt)
  end
  if e.trainOnly then return "entrena el siguiente rango" end
  if e.gather then
    local p = e.prof:lower()
    local isSkin = p:find("skin", 1, true)
    local verb = p:find("fish", 1, true) and "pesca en" or (isSkin and "mata y desuella en"
      or (p:find("min", 1, true) and "mina en" or (p:find("herb", 1, true) and "recolecta hierbas en" or "recoge en")))
    local mob = (e.mob and isSkin) and (" (" .. e.mob .. ")") or ""
    local x, y = tonumber(e.x), tonumber(e.y)
    local where = (x and y) and format("%s (%.1f, %.1f)", e.zone, x, y) or tostring(e.zone)
    return verb .. " " .. where .. mob .. ZoneTag(e.zone) .. (e.note and (" (" .. e.note .. ")") or "")
  end
  return format("crea %d %s", e.qty, e.what)
end

-- VENTANA FLOTANTE del siguiente paso (opcional). Cada fila es pulsable:
--   clic          abre o cierra la ventana de esa profesion
--   clic derecho  busca en la subasta (Auctionator) los materiales que faltan
local function OpenProfession(e)
  if InCombatLockdown() then return end
  if not e.skillLine then
    Print("Abre una vez la ventana de " .. e.prof .. " para que GoldFinder aprenda a abrirla.")
    return
  end
  pcall(function()
    local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    if info and info.professionID == e.skillLine and ProfessionsFrame and ProfessionsFrame:IsShown() then
      C_TradeSkillUI.CloseTradeSkill()
    else
      C_TradeSkillUI.OpenTradeSkill(e.skillLine)
    end
  end)
end

local function SearchMaterials(e)
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then
    Print("Abre la casa de subastas para buscar los materiales.")
    return
  end
  local names = {}
  for _, m in ipairs(e.mats) do
    if m.have < m.need then
      local nm = C_Item.GetItemInfo(m.id)
      if nm then names[#names + 1] = nm end
    end
  end
  if #names == 0 then
    Print("Ya tienes los materiales de este paso (o sus nombres aun no estan cargados).")
    return
  end
  local v1 = AHApi()
  local ok, err = pcall(function() v1.MultiSearchExact(CALLER, names) end)
  if not ok then Print("No pude buscar en Auctionator: " .. tostring(err)) end
end

-- AYUDAS DE RUTA: textos y calculos que comparten la guia, las compras, el aviso de receta aprendida y Fabricar.
-- Quedan en Skin.Route (sin nuevos locales en el bloque principal).
GF.InitRouteHelpers(setmetatable({
  Skin = Skin, CALLER = CALLER, AH_CUT = AH_CUT,
  AHApi = function(...) return AHApi(...) end,
  BuyPrice = function(...) return BuyPrice(...) end,
  Cfg = function(...) return Cfg(...) end,
  Money = function(...) return Money(...) end,
  RecipeLookup = function(...) return RecipeLookup(...) end,
  SellQty = function(...) return SellQty(...) end,
  SellValue = function(...) return SellValue(...) end,
  VendorPrice = function(...) return VendorPrice(...) end,
}, { __index = _G }))

-- COSTE HASTA EL TOPE: materiales de tu ruta desde tu habilidad hasta el tope de rango (75, 150, 225...),
-- descontando lo que ya tienes (bolsas + banco). Es una estimacion. truncated: la ruta no llega al tope (to).
local function CapCost(prof, pd)
  if not pd.rank then return nil end
  local cap = pd.maxRank or 300
  local plan = RouteFor(Char(), prof, cap)
  if not plan then return nil end
  local r = { cap = cap, to = plan.to, truncated = plan.truncated, cost = 0, unknown = 0, n = 0, mats = {} }
  for _, m in ipairs(plan.mats) do
    if m.missing > 0 then
      r.n = r.n + 1
      if m.cost then r.cost = r.cost + m.cost else r.unknown = r.unknown + 1 end
      r.mats[#r.mats + 1] = { id = m.id, need = m.need, have = m.have }
    end
  end
  return r
end

local OpenGuide, RefreshGuide   -- guia completa de profesion (se define mas abajo)

-- DESTINO EN EL MAPA: nombre de zona (en ingles, como en las guias) -> mapa del juego
local mapIds
local function MapIdFor(zone)
  if not zone or not (C_Map and C_Map.GetMapInfo) then return nil end
  if not mapIds then
    mapIds = {}
    for id = 1, 2500 do
      local ok, info = pcall(C_Map.GetMapInfo, id)
      if ok and info and info.name and info.name ~= "" then
        local cur = mapIds[info.name]
        if not cur or (info.mapType == 3 and cur.t ~= 3) then mapIds[info.name] = { id = id, t = info.mapType } end
      end
    end
  end
  local m = mapIds[zone]
  return m and m.id or nil
end

-- A donde ir ahora: receta sin aprender, instructor si estas en el tope, o la zona de farmeo
local function Destination(e)
  if e.unknown and e.learn and e.learn.zone then return e.learn end
  if e.train and e.trainState and e.train.zone then return e.train end
  if e.gather and e.zone then return e end
  return nil
end

local function SetDestination(e)
  local d = Destination(e)
  if not d then return end
  local x, y = tonumber(d.x), tonumber(d.y)
  local id = MapIdFor(d.zone)
  if id and not (x and y) then
    -- zona conocida pero sin coordenadas (por ejemplo una mazmorra): se abre su mapa
    pcall(function() if OpenWorldMap then OpenWorldMap(id) end end)
    Print(format("Destino: %s (sin coordenadas exactas)%s", d.zone, d.npc and (" - " .. d.npc) or ""))
    return
  end
  if not (x and y and id) then
    Print("No pude ubicar en el mapa: " .. tostring(d.zone) .. ".")
    return
  end
  local title = d.npc or e.prof
  local ok = pcall(function()
    if TomTom and TomTom.AddWaypoint then
      TomTom:AddWaypoint(id, x / 100, y / 100, { title = title, persistent = false, minimap = true, world = true })
    elseif C_Map.SetUserWaypoint and UiMapPoint then
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(id, x / 100, y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    elseif OpenWorldMap then
      OpenWorldMap(id)
    end
  end)
  local lo, hi, state, lvl = ZoneInfo(d.zone)
  local warn = ""
  if state == "danger" then warn = format(" |cffff6666Aviso: zona de nivel %d-%d, tu nivel es %d.|r", lo, hi, lvl)
  elseif state == "hard" then warn = format(" |cffffa640Ojo: zona de nivel %d-%d, tu nivel es %d.|r", lo, hi, lvl) end
  Print(format("Destino: %s (%.1f, %.1f) - %s%s%s", d.zone, x, y, title,
    ok and "" or ". No pude marcarlo; busca esas coordenadas en el mapa.", warn))
end

local trackerRows = {}
local TRACK_W = 306
local function LearnText(e)
  local l = e.learn
  if not l or not (l.zone or l.npc or l.item) then return "aprendela antes de fabricarla" end
  local where
  local x, y = tonumber(l.x), tonumber(l.y)
  if l.zone and x and y then where = format("%s (%.1f, %.1f)", l.zone, x, y)
  elseif l.zone then where = l.zone end
  local at = where and (" en " .. where) or ""
  if l.item then
    local nm = C_Item.GetItemInfo(l.item)
    if not nm and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(l.item) end
    return format("compra %s y aprendela%s%s", nm or "la receta", at, l.npc and (" (" .. l.npc .. ")") or "")
  end
  if l.trainer then
    return "aprendela con el instructor de la profesion: " .. (l.npc or "instructor") .. at
      .. ((l.cost and l.cost > 0) and (" (" .. Money(l.cost) .. ")") or "")
  end
  return (l.npc and ("habla con " .. l.npc) or "entrenador") .. at
end

-- Instructores alternativos del mismo rango (GoldFinderTrainers): primero los de la zona donde estas
local trainerCache = {}
local function TrainerAlts(prof, max)
  local p = (prof or ""):lower()
  local rank
  for k, v in pairs(GoldFinderTrainers or {}) do
    if p:find(k, 1, true) then rank = v[max]; break end
  end
  if not rank then return nil end
  local fac = (UnitFactionGroup("player") == "Horde") and "H" or "A"
  local str = rank[fac]
  if not str then return nil end
  local ck = p .. max .. fac
  local list = trainerCache[ck]
  if not list then
    list = {}
    for entry in str:gmatch("[^;]+") do
      local n, z, x, y = entry:match("^(.-)|(.-)|(.-)|(.-)$")
      if n then list[#list + 1] = { npc = n, zone = z, x = x, y = y } end
    end
    trainerCache[ck] = list
  end
  return list
end

local function OtherTrainersText(prof, d)
  local alts = TrainerAlts(prof, d.max)
  if not alts then return "" end
  local here = GetRealZoneText()
  local picks = {}
  for _, a in ipairs(alts) do
    if a.zone == here and a.npc ~= d.npc and #picks < 3 then picks[#picks + 1] = a end
  end
  for _, a in ipairs(alts) do
    if a.zone ~= here and a.npc ~= d.npc and #picks < 3 then picks[#picks + 1] = a end
  end
  if #picks == 0 then return "" end
  local parts = {}
  for _, a in ipairs(picks) do
    local x, y = tonumber(a.x), tonumber(a.y)
    parts[#parts + 1] = format("%s (%s%s)", a.npc, a.zone, (x and y) and format(" %.1f, %.1f", x, y) or "")
  end
  return " Otros: " .. table.concat(parts, "; ") .. "."
end

local function TrainText(e)
  local d = e.train
  local where = d.zone or "?"
  local x, y = tonumber(d.x), tonumber(d.y)
  if d.zone and x and y then where = format("%s (%.1f, %.1f)", d.zone, x, y) end
  local rq = TrainReq(e.prof, d.max)
  local st = e.trainState
  local head
  if st == "cap" then head = "Tope de habilidad alcanzado"
  elseif st == "ready" then head = "Ya puedes entrenar el siguiente rango"
  else
    local miss = {}
    if rq and UnitLevel("player") < rq.lvl then miss[#miss + 1] = "nivel " .. rq.lvl end
    if rq and (e.rank or 0) < rq.skill then miss[#miss + 1] = "habilidad " .. rq.skill end
    head = "Cerca del tope, pero aun te falta " .. (#miss > 0 and table.concat(miss, " y ") or "cumplir los requisitos")
  end
  local who = d.npc and (" con " .. d.npc) or ""
  return format("%s: entrena %s%s en %s.%s", head, d.name, who, where, OtherTrainersText(e.prof, d))
end

-- ZONA ALTERNATIVA: si una zona es muy alta para tu nivel, sugiere las zonas del MISMO tramo (segun las guias de
-- GoldFinderRoutes) que si encajan ahora. Solo las del tramo actual: las de tramos anteriores no dan habilidad.
local function AltZoneText(prof, rank, badZone)
  local lo, hi, state, lvl = ZoneInfo(badZone)
  if not lo or (state ~= "danger" and state ~= "hard") then return nil end
  local p = (prof or ""):lower()
  local fits, easiest = {}, nil
  for k, routes in pairs(GoldFinderRoutes or {}) do
    if p:find(k, 1, true) then
      for _, rt in ipairs(routes) do
        for _, z in ipairs(rt.zones or {}) do
          if rank >= z.from and rank < z.to then
            for name, rng in pairs(ZONE_LEVELS) do
              if z.zone:find(name, 1, true) then
                local _, _, st = ZoneInfo(name)
                if st == nil then fits[#fits + 1] = name end
                if not easiest or rng[1] < ZONE_LEVELS[easiest][1] then easiest = name end
              end
            end
          end
        end
      end
    end
  end
  table.sort(fits)
  if #fits > 0 then
    local parts = {}
    for _, name in ipairs(fits) do parts[#parts + 1] = name .. ZoneTag(name) end
    return format("Para tu nivel %d, mientras tanto: %s (hasta el nivel %d).", lvl, table.concat(parts, " o "), lo)
  elseif easiest then
    return format("Ninguna zona de este tramo encaja con tu nivel %d: la mas asequible es %s%s. Sube de nivel antes.",
      lvl, easiest, ZoneTag(easiest))
  end
  return nil
end

-- ANTES DE IRTE: cuando te quedan 5 puntos o menos del tramo de recoleccion (Mineria, Pesca...), una lista
-- de lo que conviene hacer antes de cambiar de zona.
local function LeaveText(e)
  if not (e.gather and e.upto and e.rank and e.rank < e.upto and e.upto - e.rank <= 5) then return nil end
  local p = e.prof:lower()
  local todo = {}
  if e.train and e.trainState ~= "blocked" and e.trainState ~= "capblocked" then
    todo[#todo + 1] = "entrena " .. e.train.name .. (e.train.npc and (" con " .. e.train.npc) or "")
      .. (e.train.zone and (" (" .. e.train.zone .. ")") or "")
  end
  if p:find("min", 1, true) then
    if (C_Item.GetItemCount(2901) or 0) == 0 then todo[#todo + 1] = "compra un Mining Pick" end
    if e.rank < 105 then todo[#todo + 1] = "funde el mineral en una forja (aun da habilidad)" end
  end
  if p:find("fish", 1, true) then todo[#todo + 1] = "guarda el pescado que le sirva a Cocina" end
  todo[#todo + 1] = "revisa Bolsas: vende, deposita o envia al banquero lo que sobre"
  local out = "Antes de irte de " .. tostring(e.zone or "esta zona") .. ": " .. table.concat(todo, "; ") .. "."
  if e.nxt and e.nxt.zone then
    out = out .. " Siguiente: " .. e.nxt.zone .. ZoneTag(e.nxt.zone)
    local alt = AltZoneText(e.prof, e.rank, e.nxt.zone)
    if alt then out = out .. " " .. alt end
  end
  return out
end

local readyState = {}   -- por paso: tenia ya todos los materiales? (para avisar solo al conseguirlos)
local lastStep = {}   -- ultimo tramo mostrado por profesion (para avisar al completarlo)

-- "+5 esta sesion - 12 pts para 100 - ~8 min"
local function SessionLine(e)
  local ss = skillSess[e.prof]
  if not ss or not ss.start then return "" end
  local parts = {}
  local gain = e.rank - ss.start
  if gain > 0 then parts[#parts + 1] = "|cff59eb8d+" .. gain .. " esta sesion|r" end
  if e.upto and e.upto > e.rank then
    local left = e.upto - e.rank
    local el = GetTime() - ss.t
    if gain >= 2 and el > 60 then
      local mins = left / (gain / el) / 60
      parts[#parts + 1] = "|cffb3b3b3" .. (mins < 1 and "<1 min" or format("~%d min", math.ceil(mins))) .. "|r"
    end
  end
  return table.concat(parts, "  ")
end

local function TrackerRow(f, i)
  local r = trackerRows[i]
  if r then return r end
  r = CreateFrame("Button", nil, f)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:SetWidth(TRACK_W)
  local hl = Skin.Quest(r:CreateTexture(nil, "HIGHLIGHT"), 1, 0.82, 0.25, 0.6)
  hl:SetAllPoints()
  r.text = Text(r, 12, PAL.text)
  r.text:SetPoint("TOPLEFT", 0, 0)
  r.text:SetWidth(TRACK_W)
  r.text:SetWordWrap(true)
  r.text:SetJustifyV("TOP")
  r.text:SetSpacing(3)
  r.barBg = Flat(r, "BACKGROUND", { 1, 1, 1, 0.10 })
  r.barBg:SetHeight(4)
  r.barBg:SetPoint("BOTTOMLEFT")
  r.barBg:SetPoint("BOTTOMRIGHT")
  r.bar = Skin.Bar(Flat(r, "ARTWORK", { 1, 0.82, 0.25, 1 }))
  r.bar:SetHeight(4)
  r.bar:SetPoint("BOTTOMLEFT")
  r.flashTex = Flat(r, "BACKGROUND", { 0.35, 0.92, 0.55, 1 })
  r.flashTex:SetAllPoints()
  r.flashTex:SetAlpha(0)
  function r:Flash()
    self.ft = 1.5
    self:SetScript("OnUpdate", function(sf, dt)
      sf.ft = sf.ft - dt
      if sf.ft <= 0 then
        sf.flashTex:SetAlpha(0)
        sf:SetScript("OnUpdate", nil)
      else
        sf.flashTex:SetAlpha(0.35 * sf.ft / 1.5)
      end
    end)
  end
  r:SetScript("OnClick", function(self, btn)
    local e = self.entry
    if not e then return end
    if IsControlKeyDown() then OpenGuide(e.prof); return end
    if e.gather then
      if btn == "LeftButton" then SetDestination(e) end
      return
    end
    if btn == "RightButton" then SearchMaterials(e)
    elseif IsShiftKeyDown() and Destination(e) then SetDestination(e)
    else OpenProfession(e) end
  end)
  r:SetScript("OnEnter", function(self)
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.prof .. " " .. e.rank, 1, 0.82, 0.25)
    if e.game then
      GameTooltip:AddLine("Receta mas barata ahora que aun te sube, segun tus recetas y la subasta: " .. StepText(e) .. ".", 1, 1, 1, true)
    else
      GameTooltip:AddLine(format("Siguiente paso de tu ruta: %s hasta habilidad %d.", StepText(e), e.upto), 1, 1, 1, true)
    end
    if e.train then GameTooltip:AddLine(TrainText(e), 1, 0.65, 0.25, true) end
    if e.unknown then
      GameTooltip:AddLine("No sabes esta receta: " .. LearnText(e), 1, 0.4, 0.4, true)
    end
    if #e.mats > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(e.game and "Materiales por fabricacion (bolsas + banco):" or "Materiales de este tramo (bolsas + banco):", 0.7, 0.7, 0.7)
      for _, m in ipairs(e.mats) do
        local nm = C_Item.GetItemInfo(m.id) or ("item:" .. m.id)
        local done = m.have >= m.need
        GameTooltip:AddDoubleLine(nm, m.have .. " / " .. m.need,
          1, 1, 1, done and 0.35 or 1, done and 0.92 or 0.65, done and 0.55 or 0.25)
      end
    end
    local shown = false
    for _, m in ipairs(e.mats) do
      if m.have < m.need then
        local st = (SourceText(m.id):gsub("^\n", ""))
        if st ~= "" then
          if not shown then GameTooltip:AddLine(" "); shown = true end
          GameTooltip:AddLine((C_Item.GetItemInfo(m.id) or "") .. ": " .. st, 0.42, 0.71, 1, true)
        end
      end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Ctrl+clic: abrir la guia completa de la profesion", 0.7, 0.7, 0.7)
    if Destination(e) then
      GameTooltip:AddLine(e.gather and "Clic: marcar el destino en el mapa"
        or "Mayus+clic: marcar en el mapa donde aprender la receta o al instructor", 0.7, 0.7, 0.7)
    end
    if not e.gather then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Clic: abrir o cerrar la ventana de la profesion", 0.7, 0.7, 0.7)
      GameTooltip:AddLine("Clic derecho: buscar en la subasta lo que falta", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  trackerRows[i] = r
  return r
end

---------------------------------------------------------------------------
-- GUIA DE PROFESION: todos los pasos a la vista (hechos, actual y proximos), con materiales,
-- recetas por aprender e instructores. Se abre con /gf guia, el boton "G" o Ctrl+clic en la
-- ventana flotante. Clic en un paso: marca su destino; clic derecho: busca sus materiales.
---------------------------------------------------------------------------
local guideRows = {}
local GUIDE_W = 580
local guideProf

-- Profesiones con guia: las de la lista propia (GoldFinderGuides), las de fabricar cuyas recetas ya conoce el
-- addon y las de recoleccion con zonas
local function GuideKey(prof)
  local pd = Char().prof[prof]
  if not pd then return nil end
  for _, g in pairs(GoldFinderGuides or {}) do
    if (pd.skillLine and g.line == pd.skillLine) or g.name:lower() == prof:lower() then return prof:lower() end
  end
  if (pd.crafts and next(pd.crafts)) or GatherZones(prof) then return prof:lower() end
  return nil
end

local function WhereText(d)
  local x, y = tonumber(d.x), tonumber(d.y)
  if d.zone and x and y then return format("%s (%.1f, %.1f)", d.zone, x, y) end
  return d.zone or "?"
end

-- GUIA HIBRIDA: la lista propia (GoldFinderGuides, generada de las tablas del juego y de Icy Veins) con el
-- estado del personaje encima: tramos hechos, el actual con lo que falta, y la alternativa mas barata del
-- planificador con tus precios. Los instructores visitados corrigen la habilidad requerida y el precio.
local BuildGuide = GF.InitGuide({
  BuyPrice = function(...) return BuyPrice(...) end,
  Cfg = function(...) return Cfg(...) end,
  Char = function(...) return Char(...) end,
  Counts = function(...) return Counts(...) end,
  GatherZones = function(...) return GatherZones(...) end,
  GuideKey = function(...) return GuideKey(...) end,
  Money = function(...) return Money(...) end,
  PickZone = function(...) return PickZone(...) end,
  RouteFor = function(...) return RouteFor(...) end,
  ShortMoney = function(...) return ShortMoney(...) end,
  StepMats = function(...) return StepMats(...) end,
  TrainerLearn = function(...) return TrainerLearn(...) end,
  TrainList = function(...) return TrainList(...) end,
  TrainReq = function(...) return TrainReq(...) end,
  WhereText = function(...) return WhereText(...) end,
}).BuildGuide

local function GuideRow(content, i)
  local r = guideRows[i]
  if r then return r end
  r = CreateFrame("Button", nil, content)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r:SetWidth(GUIDE_W - 14)
  -- paso actual: resaltado de la lista de misiones en dorado
  r.bg = Skin.Quest(r:CreateTexture(nil, "BACKGROUND"), 1, 0.82, 0.25, 0.45)
  r.bg:SetAllPoints()
  r.curBar = Flat(r, "ARTWORK", { 1, 0.82, 0.25, 1 })
  r.curBar:SetPoint("TOPLEFT")
  r.curBar:SetPoint("BOTTOMLEFT")
  r.curBar:SetWidth(2)
  r.curBar:Hide()
  local hl = Skin.Quest(r:CreateTexture(nil, "HIGHLIGHT"))
  hl:SetAllPoints()
  -- paso pendiente: casilla vacia (la marca de hecho es la casilla con check)
  r.dot = r:CreateTexture(nil, "ARTWORK")
  r.dot:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
  r.dot:SetSize(22, 22)
  r.dot:SetPoint("TOPLEFT", 1, -2)
  r.check = r:CreateTexture(nil, "OVERLAY")
  r.check:SetTexture("Interface/Buttons/UI-CheckBox-Check")
  r.check:SetSize(22, 22)
  r.check:SetPoint("TOPLEFT", 1, -2)
  r.text = Text(r, 12, PAL.text)
  r.text:SetPoint("TOPLEFT", 28, -5)
  r.text:SetWidth(GUIDE_W - 14 - 36)
  r.text:SetWordWrap(true)
  r.text:SetJustifyV("TOP")
  r.text:SetSpacing(3)
  -- lineas secundarias del tramo (aprender, alternativa, materiales): letra menor y apagada
  r.sub = Text(r, 11, PAL.text)
  r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -3)
  r.sub:SetWidth(GUIDE_W - 14 - 36)
  r.sub:SetWordWrap(true)
  r.sub:SetJustifyV("TOP")
  r.sub:SetSpacing(2)
  r.barBg = Flat(r, "BORDER", { 1, 1, 1, 0.10 })
  r.barBg:SetHeight(4)
  r.barBg:SetPoint("BOTTOMLEFT", 28, 2)
  r.barBg:SetPoint("BOTTOMRIGHT", -6, 2)
  r.bar = Skin.Bar(Flat(r, "ARTWORK", { 1, 0.82, 0.25, 1 }))
  r.bar:SetHeight(4)
  r.bar:SetPoint("BOTTOMLEFT", 28, 2)
  r:SetScript("OnClick", function(self, btn)
    local it = self.item
    if not it or it.kind == "tip" then return end
    if it.kind == "section" then
      GoldFinderGuide.cmpOpen = not GoldFinderGuide.cmpOpen
      RefreshGuide()
      return
    end
    if btn == "RightButton" then
      if it.mats and #it.mats > 0 then SearchMaterials({ mats = it.mats }) end
    elseif it.e and Destination(it.e) then
      SetDestination(it.e)
    elseif it.learn and it.learn.zone then
      SetDestination({ prof = guideProf or "", unknown = true, learn = it.learn })
    elseif guideProf and Char().prof[guideProf] then
      OpenProfession({ prof = guideProf, skillLine = Char().prof[guideProf].skillLine })
    end
  end)
  r:SetScript("OnEnter", function(self)
    local it = self.item
    if not it then return end
    local dest = (it.e and Destination(it.e)) or (it.learn and it.learn.zone)
    local mats = it.mats and #it.mats > 0
    if not dest and not mats and not it.unknown then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if mats then
      GameTooltip:AddLine("Materiales (bolsas + banco)", 0.7, 0.7, 0.7)
      for _, m in ipairs(it.mats) do
        local nm = C_Item.GetItemInfo(m.id) or ("item:" .. m.id)
        local ok = m.have >= m.need
        GameTooltip:AddDoubleLine(nm, m.have .. " / " .. m.need, 1, 1, 1, ok and 0.35 or 1, ok and 0.92 or 0.65, ok and 0.55 or 0.25)
        if not ok then
          local st = (SourceText(m.id):gsub("^\n", ""))
          if st ~= "" then GameTooltip:AddLine("  " .. st, 0.42, 0.71, 1, true) end
        end
      end
      GameTooltip:AddLine(" ")
    end
    if it.unknown then
      GameTooltip:AddLine("No sabes esta receta: " .. LearnText({ learn = it.learn }), 1, 0.4, 0.4, true)
    end
    if dest then GameTooltip:AddLine("Clic: marcar el destino en el mapa", 0.7, 0.7, 0.7) end
    if mats then GameTooltip:AddLine("Clic derecho: buscar los materiales en la subasta", 0.7, 0.7, 0.7) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  guideRows[i] = r
  return r
end

-- FARMEO COMBINADO: criaturas/zonas donde ya conseguiste VARIOS de los materiales que te faltan
-- para los proximos pasos (de todas tus profesiones). Se apoya en lo que el addon aprende al abrir botines.
local function FarmCombos()
  local SS = GoldFinderDB.sources
  local out = {}
  if not SS then return out end
  local groups = {}
  for prof, pd in pairs(Char().prof) do
    if ProfOn(prof) and GuideKey(prof) then
      local taken = 0
      for _, it in ipairs(BuildGuide(prof, pd) or {}) do
        if it.kind == "craft" and not it.done and taken < 3 then
          taken = taken + 1
          for _, m in ipairs(it.mats or {}) do
            local src = m.have < m.need and SS[m.id] or nil
            if src then
              local nm = C_Item.GetItemInfo(m.id)
              if not nm then
                if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(m.id) end
                nm = "item:" .. m.id
              end
              for zone, z in pairs(src) do
                local k = zone .. "|" .. (z.mob or "")
                local g = groups[k]
                if not g then
                  g = { zone = zone, mob = z.mob, list = {}, seen = {}, score = 0 }
                  groups[k] = g
                end
                local tag = nm .. " (" .. (it.st.what or (prof .. " " .. it.st.upto)) .. ")"
                if not g.seen[tag] then
                  g.seen[tag] = true
                  g.list[#g.list + 1] = tag
                  g.score = g.score + (z.n or 1)
                end
              end
            end
          end
        end
      end
    end
  end
  for _, g in pairs(groups) do
    if #g.list >= 2 then out[#out + 1] = g end
  end
  table.sort(out, function(a, b)
    if #a.list ~= #b.list then return #a.list > #b.list end
    return a.score > b.score
  end)
  return out
end

-- RUTAS Y PLAN: compara tu ruta (el planificador, con tus recetas) con otras (GoldFinderRoutes) usando tus precios de
-- la subasta, y decide material por material si conviene COMPRAR, FARMEAR o esperar. Para farmear se usa tu ritmo de la
-- sesion (unidades por hora de ese objeto y oro por hora): se farmea si tu tiempo vale menos que comprarlo.
local function OwnRouteNeed(prof, cap)
  local plan = RouteFor(Char(), prof, cap)
  local need = {}
  for _, m in ipairs(plan and plan.mats or {}) do need[m.id] = m.need end
  return need
end

local function OtherRouteNeed(route, rank, cap)
  local need = {}
  for _, st in ipairs(route.steps) do
    local span = st.to - st.from
    local f
    if span <= 0 then f = (rank < st.from and cap >= st.to) and 1 or 0
    else f = (math.min(st.to, cap) - math.max(rank, st.from)) / span end
    if f > 0 then
      for _, m in ipairs(st.mats) do
        if not m[3] or rank >= m[3] then need[m[1]] = (need[m[1]] or 0) + m[2] * f end
      end
      for _, m in ipairs(st.makes or {}) do need[m[1]] = (need[m[1]] or 0) - m[2] * f end
    end
  end
  return need
end

-- Que te falta de cada material (descontando bolsas + banco) y que conviene hacer con cada uno
local function RoutePlan(need)
  local v1 = AHApi()
  local sess = Sess()
  local hrs = (sess.secs or 0) / 3600
  local gph = (hrs >= 1 / 6 and (sess.total or 0) > 0) and (sess.total / hrs) or nil
  local rows, cost, unknown = {}, 0, 0
  for id, q in pairs(need) do
    local bags, bank = Counts(id)
    local miss = math.ceil(q) - bags - bank
    if miss > 0 then
      -- el mismo precio de compra que el planificador (lo mas barato de subasta y vendedor)
      local price = BuyPrice(id)
      local buy = price and price * miss or nil
      if buy then cost = cost + buy else unknown = unknown + 1 end
      local it = sess.items and sess.items[id]
      local rate = (it and hrs >= 1 / 6 and it.count > 0) and (it.count / hrs) or nil
      local farmH = rate and (miss / rate) or nil
      local farmVal = (farmH and gph) and (farmH * gph) or nil
      local ref = RefPrice(id)
      local verdict
      if buy and farmVal then verdict = (farmVal < buy * 0.9) and "farm" or "buy"
      elseif buy then verdict = "buy"
      elseif farmH then verdict = "farm"
      else verdict = "none" end
      rows[#rows + 1] = {
        id = id, miss = miss, buy = buy, farmH = farmH, farmVal = farmVal, verdict = verdict,
        low = (price and ref and price <= ref * 0.85) or false,
        high = (price and ref and price >= ref * 1.15) or false,
      }
    end
  end
  table.sort(rows, function(a, b) return (a.buy or 0) > (b.buy or 0) end)
  return rows, cost, unknown
end

-- Lineas del plan: material por material, que conviene hacer (los 5 mas caros)
local function PlanText(rows)
  local lines, n = {}, 0
  for _, r in ipairs(rows) do
    if n >= 5 then break end
    n = n + 1
    local nm = C_Item.GetItemInfo(r.id)
    if not nm then
      if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r.id) end
      nm = "item:" .. r.id
    end
    local act
    if r.verdict == "buy" then
      act = "|cff59eb8dcomprar|r ~" .. Money(r.buy or 0)
        .. (r.low and " (precio bajo: buen momento)" or "")
        .. (r.farmH and format(" (farmear: ~%.1f h)", r.farmH) or "")
    elseif r.verdict == "farm" then
      act = format("|cffffa640farmear|r ~%.1f h", r.farmH)
        .. (r.buy and (" (comprar: " .. Money(r.buy) .. (r.high and ", precio alto" or "") .. ")") or "")
    else
      act = "sin precio ni datos de farmeo"
    end
    lines[#lines + 1] = format("   %s: faltan %d -> %s", nm, r.miss, act)
  end
  return lines
end

local function RouteSummary(prof, key, pd)
  local routes = GoldFinderRoutes and GoldFinderRoutes[key]
  if not routes or not pd.rank then return nil end
  local cap = pd.maxRank or 300
  if pd.rank >= cap then cap = math.min(300, cap + 75) end
  local out = {}

  -- zonas que sugieren otras guias para el tramo actual
  for _, r in ipairs(routes) do
    for _, z in ipairs(r.zones or {}) do
      if pd.rank < z.to then
        out[#out + 1] = format("|cff6bb5ff%s, tramo %d-%d:|r %s%s", r.name, z.from, z.to, AnnotateZones(z.zone),
          z.note and (" (" .. z.note .. ")") or "")
        break
      end
    end
  end

  local others = {}
  for _, r in ipairs(routes) do
    if r.steps and #r.steps > 0 then
      local rows, c, u = RoutePlan(OtherRouteNeed(r, pd.rank, cap))
      others[#others + 1] = { name = r.name, rows = rows, cost = c, unknown = u }
    end
  end
  local own = RouteFor(Char(), prof, cap)

  if not GatherZones(prof) then
    -- profesion de fabricacion: tu ruta (coste del plan con BuyPrice y lo que cuesta aprender) contra las otras guias
    if not own then
      local why = Skin.Route.NoRouteReason(pd)
      if why then out[#out + 1] = "|cff6bb5ffTu ruta:|r " .. why .. "." end
      for _, o in ipairs(others) do
        if #o.rows > 0 then
          out[#out + 1] = format("|cff6bb5ff%s hasta %d:|r comprar ~%s%s", o.name, cap, Money(o.cost),
            o.unknown > 0 and (" (+" .. o.unknown .. " materiales sin precio)") or "")
          for _, l in ipairs(PlanText(o.rows)) do out[#out + 1] = l end
        end
      end
    elseif #others > 0 then
      local mine = { name = "Tu ruta", rows = RoutePlan(OwnRouteNeed(prof, cap)), cost = own.cost, unknown = own.unknown,
        sell = own.sell, truncated = own.truncated, to = own.to }
      local lines, best = Skin.Route.RouteVerdict(mine, others, cap)
      for _, l in ipairs(lines) do out[#out + 1] = l end
      if best then
        for _, l in ipairs(PlanText(best.rows)) do out[#out + 1] = l end
        if #best.rows == 0 then out[#out + 1] = "   Ya tienes todos los materiales de esa ruta." end
      end
    end
  else
    -- profesion de recoleccion: la otra guia ofrece una alternativa comprando
    for _, o in ipairs(others) do
      if #o.rows > 0 then
        out[#out + 1] = format("|cff6bb5ffAlternativa %s en vez de recolectar:|r comprar ~%s%s", o.name, Money(o.cost),
          o.unknown > 0 and (" (+" .. o.unknown .. " materiales sin precio)") or "")
        for _, l in ipairs(PlanText(o.rows)) do out[#out + 1] = l end
      end
    end
  end
  if #out == 0 then return nil end
  return table.concat(out, "\n")
end

function RefreshGuide()
  local f = GoldFinderGuide
  if not f or not f:IsShown() then return end
  -- pestanas: una por profesion con guia
  local names = {}
  for prof in pairs(Char().prof) do
    if ProfOn(prof) and GuideKey(prof) then names[#names + 1] = prof end
  end
  table.sort(names)
  if not guideProf or not Char().prof[guideProf] or not GuideKey(guideProf) or not ProfOn(guideProf) then
    guideProf = names[1]
  end
  local tn = math.max(#names, 1)
  local tw = math.min(96, math.floor((GUIDE_W + 34 - 24 - (tn - 1) * 4) / tn))
  for i, name in ipairs(names) do
    local b = f.tabs[i]
    if not b then
      local function pick(self)
        if self.gfTab and PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
          pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end
        guideProf = self.profName
        f.needScroll = true
        RefreshGuide()
      end
      -- marco nativo: pestanas abajo como en la ventana de personaje; si no, botones arriba
      b = f.native and NewFrame("Button", "GoldFinderGuideTab" .. i, f, "PanelTabButtonTemplate")
      if b then
        b.gfTab = true
        b:SetID(i)
        b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
        b:SetScript("OnClick", pick)
      else
        b = Btn(f, "", tw, 20, nil, pick)
      end
      f.tabs[i] = b
    end
    b.profName = name
    b:ClearAllPoints()
    if b.gfTab then
      b:SetText(name)
      -- ancho segun el texto (sin tope); solo si no caben todas se limita el ancho de cada una
      local maxW = math.floor((GUIDE_W + 34 - 20 + 8 * (tn - 1)) / tn)
      if PanelTemplates_TabResize then
        pcall(PanelTemplates_TabResize, b, 16, nil, 70, (tn > 4) and maxW or nil)
      end
      if i == 1 then b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2)
      else b:SetPoint("LEFT", f.tabs[i - 1], "RIGHT", -8, 0) end
      local fn = (name == guideProf) and PanelTemplates_SelectTab or PanelTemplates_DeselectTab
      if fn then pcall(fn, b) end
    else
      b:SetSize(tw, 20)
      if f.native then
        b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12 + (i - 1) * (tw + 4), -2)
      else
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + (i - 1) * (tw + 4), -30)
      end
      b.label:SetWidth(tw - 4)
      b.label:SetText(name)
      if name == guideProf then b:LockHighlight() else b:UnlockHighlight() end
      b.base = (name == guideProf) and { 1, 0.82, 0.25, 0.30 } or { 1, 1, 1, 0.09 }
      b.bg:SetColorTexture(b.base[1], b.base[2], b.base[3], b.base[4])
    end
    b:Show()
  end
  for i = #names + 1, #f.tabs do f.tabs[i]:Hide() end

  local pd = guideProf and Char().prof[guideProf]
  local items = pd and BuildGuide(guideProf, pd) or nil
  if items then
    -- comparacion de rutas: seccion propia al final, plegada por defecto (clic en la cabecera la abre)
    local okR, summary = pcall(RouteSummary, guideProf, GuideKey(guideProf), pd)
    if okR and summary then
      items[#items + 1] = { kind = "section", open = f.cmpOpen }
      if f.cmpOpen then items[#items + 1] = { kind = "tip", text = summary } end
    end
  end
  if items then
    local combos = FarmCombos()
    if #combos > 0 then
      for idx, it in ipairs(items) do
        if it.current then
          local zoneNow = GetRealZoneText()
          for ci = 1, math.min(2, #combos) do
            local g = combos[ci]
            table.insert(items, idx + ci, {
              kind = "tip",
              text = format("|cff6bb5ffFarmeo combinado:|r %s (%s%s)%s\n%s", g.mob or "zona", g.zone, ZoneTag(g.zone),
                g.zone == zoneNow and "  |cff59eb8d(estas aqui)|r" or "", table.concat(g.list, ", ")),
            })
          end
          break
        end
      end
    end
  end
  if not items then
    f.title:SetText("Guia de profesion: no hay guia para tus profesiones")
    for _, r in ipairs(guideRows) do r:Hide() end
    f.content:SetHeight(1)
    return
  end
  f.title:SetText(format("%s  %d / %d", guideProf, pd.rank or 0, pd.maxRank or 0))
  f.gbar:SetWidth(math.max(1, (f.gbarW or (GUIDE_W + 34 - 24)) * math.min(1, (pd.rank or 0) / 300)))

  local y, curTop, missing = 0, 0, false
  for i, it in ipairs(items) do
    local r = GuideRow(f.content, i)
    r.item = it
    local grey = it.done
    local lines, sub = {}, nil
    if it.kind == "tip" then
      lines[1] = it.text
    elseif it.kind == "section" then
      lines[1] = format("|cffffd100%s Comparar rutas|r  |cff8a8a96(%s)|r", it.open and "[-]" or "[+]",
        it.open and "clic para plegar" or "tu ruta frente a Icy Veins con tus precios; clic para abrir")
    elseif it.band then
      local head, sl, miss = Skin.GuideBand(it)
      lines[1], sub = head, sl
      if miss then missing = true end
    elseif it.kind == "train" then
      local d = it.d
      local rq = TrainReq(guideProf, d.max)
      local ready = (not it.done) and rq and (pd.rank or 0) >= rq.skill and UnitLevel("player") >= rq.lvl
      lines[1] = (ready and "|cff59eb8dYa puedes: |r" or "")
        .. format("Entrena %s%s en %s", d.name, d.npc and (" con " .. d.npc) or "", WhereText(d))
        .. ((rq and rq.skill > 0) and format(" |cffb3b3b3(pide habilidad %d y nivel %d)|r", rq.skill, rq.lvl) or "")
    elseif it.kind == "gather" then
      lines[1] = (grey and "" or "|cffffd100") .. it.st.upto .. (grey and "  " or "|r  ") .. StepText(it.e)
    else
      lines[1] = (grey and "" or "|cffffd100") .. it.st.upto .. (grey and "  " or "|r  ")
        .. format("Crea %d %s", it.st.qty, it.st.what)
    end
    if not grey and not it.current and it.unknown and not it.band then
      lines[1] = lines[1] .. "  |cffff6666(receta pendiente)|r"
    end
    if it.current and it.mats and #it.mats > 0 and not it.band then
      local parts, ready = {}, true
      for _, m in ipairs(it.mats) do
        local nm = C_Item.GetItemInfo(m.id)
        if not nm then
          missing = true
          if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(m.id) end
          nm = "item:" .. m.id
        end
        if m.have < m.need then ready = false end
        parts[#parts + 1] = format("%s%s %d/%d|r", m.have >= m.need and "|cff59eb8d" or "|cffffa640", nm, m.have, m.need)
      end
      lines[#lines + 1] = (ready and "|cff59eb8dListo:|r " or "") .. table.concat(parts, "  ")
    end
    if it.current and it.unknown and not it.band then
      lines[#lines + 1] = "|cffff6666No sabes esta receta:|r " .. LearnText({ learn = it.learn })
    end
    if it.current and it.kind == "gather" then
      local alt = AltZoneText(guideProf, pd.rank or 0, it.st.zone)
      if alt then lines[#lines + 1] = "|cffffa640" .. alt .. "|r" end
      for _, ne in ipairs(NextStepList()) do
        if ne.prof == guideProf then
          local lt = LeaveText(ne)
          if lt then lines[#lines + 1] = "|cffb3b3b3" .. lt .. "|r" end
          break
        end
      end
    end
    -- cabecera del tramo mas fuerte (13-14) que las lineas secundarias (11, apagadas)
    r.text:SetFont(STANDARD_TEXT_FONT, it.current and 14 or (grey and 11 or (it.band and 13 or 12)), "")
    r.text:SetText(table.concat(lines, "\n"))
    if grey then r.text:SetTextColor(0.42, 0.44, 0.50)
    elseif it.kind == "train" then r.text:SetTextColor(1, 0.65, 0.25)
    else r.text:SetTextColor(0.92, 0.92, 0.92) end
    local h = (r.text:GetStringHeight() or 16) + (it.current and 14 or 8)
    if sub and #sub > 0 then
      r.sub:SetFont(STANDARD_TEXT_FONT, 11, "")
      r.sub:SetTextColor(0.72, 0.72, 0.76)
      r.sub:SetText(table.concat(sub, "\n"))
      r.sub:Show()
      h = h + (r.sub:GetStringHeight() or 12) + 3
    else
      r.sub:SetText("")
      r.sub:Hide()
    end
    r:SetHeight(h)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -y)
    if it.kind == "tip" or it.kind == "section" then r.check:Hide(); r.dot:Hide()
    elseif it.done then r.check:Show(); r.dot:Hide()
    else r.check:Hide(); r.dot:Show() end
    if it.current then
      r.bg:Show()
      r.curBar:Show()
      curTop = y
      if it.st then
        local span = it.st.upto - (it.from or 0)
        local frac = span > 0 and math.min(1, math.max(0, ((pd.rank or 0) - (it.from or 0)) / span)) or 0
        r.barBg:Show(); r.bar:Show()
        r.bar:SetWidth(math.max(1, (GUIDE_W - 14 - 34) * frac))
      else
        r.barBg:Hide(); r.bar:Hide()
      end
    else
      r.bg:Hide(); r.curBar:Hide(); r.barBg:Hide(); r.bar:Hide()
    end
    r:Show()
    y = y + h + 8
  end
  for i = #items + 1, #guideRows do guideRows[i]:Hide() end
  f.content:SetHeight(y + 8)
  -- se ajusta a los pasos, sin pasar del alto de la pantalla (la lista se desplaza)
  local maxH = math.max(300, math.min(640, ((UIParent and UIParent:GetHeight()) or 768) - 120))
  f:SetHeight(math.min(maxH, math.max(200, y + (f.padH or 78))))
  f.curTop = curTop
  if f.needScroll then
    f.needScroll = false
    C_Timer.After(0.05, function()
      local maxS = math.max(0, f.content:GetHeight() - f.sf:GetHeight())
      f.sf:SetVerticalScroll(math.min(maxS, math.max(0, (f.curTop or 0) - 30)))
    end)
  end
  if missing and not f.retry then
    f.retry = true
    C_Timer.After(1.5, function() f.retry = false; pcall(RefreshGuide) end)
  end
end

function OpenGuide(name)
  local f = GoldFinderGuide
  if not f then
    -- marco nativo (retrato con libro, titulo, X e Inset) y pestanas abajo; sin la plantilla, el marco plano
    f = NewFrame("Frame", "GoldFinderGuide", UIParent, "ButtonFrameTemplate")
    f = f or CreateFrame("Frame", "GoldFinderGuide", UIParent)
    f.native = f.Inset ~= nil
    f:SetSize(GUIDE_W + 34, 520)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, _, relPoint, x, y = self:GetPoint()
      GoldFinderDB.guidePos = { point, relPoint, x, y }
    end)
    -- top: donde va el texto de la profesion; gx: margen izquierdo (a la derecha del retrato si es nativo)
    local top, gx = -8, 12
    if f.native then
      top, gx = -30, 66
      if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end
      local icon = "Interface\\Icons\\INV_Misc_Book_09"
      if f.SetPortraitToAsset then
        pcall(f.SetPortraitToAsset, f, icon)
      else
        local p = (f.PortraitContainer and f.PortraitContainer.portrait) or f.portrait or _G["GoldFinderGuidePortrait"]
        if p and p.SetTexture then
          if SetPortraitToTexture then pcall(SetPortraitToTexture, p, icon) else p:SetTexture(icon) end
        end
      end
      if f.SetTitle then
        pcall(f.SetTitle, f, "GoldFinder Forever")
      else
        local t = (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText or _G["GoldFinderGuideTitleText"]
        if t then t:SetText("GoldFinder Forever") end
      end
    else
      local bg = Flat(f, "BACKGROUND", PAL.bg)
      bg:SetAllPoints()
      local bar = Flat(f, "ARTWORK", { 1, 0.82, 0.25, 1 })
      bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(3)
    end
    f.title = Text(f, 13, PAL.gold)
    f.title:SetPoint("TOPLEFT", gx, top)
    local gy = f.native and -50 or -53
    f.gbg = Flat(f, "BACKGROUND", { 1, 1, 1, 0.10 })
    f.gbg:SetHeight(4)
    f.gbg:SetPoint("TOPLEFT", f, "TOPLEFT", gx, gy)
    f.gbg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, gy)
    f.gbar = Skin.Bar(Flat(f, "ARTWORK", { 1, 0.82, 0.25, 1 }))
    f.gbar:SetHeight(4)
    f.gbar:SetPoint("TOPLEFT", f, "TOPLEFT", gx, gy)
    f.gbarW = GUIDE_W + 34 - gx - 12
    if not (f.native and (f.CloseButton or _G["GoldFinderGuideCloseButton"])) then
      local close = Skin.Close(f, function() f:Hide() end)
      close:SetPoint("TOPRIGHT", f.native and 2 or -2, f.native and 2 or -2)
      close:SetFrameLevel(f:GetFrameLevel() + 50)
    end
    f.tabs = {}
    local sf = CreateFrame("ScrollFrame", "GoldFinderGuideScroll", f, "UIPanelScrollFrameTemplate")
    if f.native then
      -- la lista va dentro del Inset (el recuadro hundido de las ventanas del juego)
      sf:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 6, -6)
      sf:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -26, 6)
      f.padH = 84
    else
      sf:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -58)
      sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)
    end
    f.content = CreateFrame("Frame", nil, sf)
    f.content:SetSize(GUIDE_W - 14, 100)
    sf:SetScrollChild(f.content)
    f.sf = sf
    local pos = GoldFinderDB.guidePos
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 0) end
    tinsert(UISpecialFrames, "GoldFinderGuide")   -- Esc la cierra
  end
  if name and name ~= "" then
    local q = name:lower()
    for prof in pairs(Char().prof) do
      if prof:lower():find(q, 1, true) and GuideKey(prof) then guideProf = prof; break end
    end
  end
  if f:IsShown() and (not name or name == "") then f:Hide(); return end
  f.needScroll = true
  f:Show()
  RefreshGuide()
end

---------------------------------------------------------------------------
-- EN PANTALLA COMO SKILLUP FOREVER: el siguiente paso como bloque del seguimiento de objetivos y, en la lista de
-- recetas de la ventana de profesiones, la probabilidad de subir y el coste o ganancia por punto de cada receta.
-- Seguimiento: si SkillUp Forever esta cargado, su ForeverCore publica una columna (ForeverCore.TrackerSection)
-- con secciones de la plantilla del juego fuera del seguimiento nativo; GoldFinder anade alli su propia seccion,
-- junto a "Profession reagents", sin tocar el seguimiento del juego. Sin ForeverCore, un marco propio con el estilo
-- del seguimiento justo debajo de ObjectiveTrackerFrame (solo se ancla a el; nunca se escribe en el ni se engancha).
-- Recetas: ScrollUtil.AddInitializedFrameCallback y EventRegistry; nada de Blizzard se reemplaza ni se llama nada
-- protegido. Si SkillUp ya escribe su texto en cada fila, GoldFinder lo pone en el tooltip de la fila.
-- Las APIs quedan en Skin.Objectives y Skin.RecipeNotes (sin nuevos locales en el bloque principal).
---------------------------------------------------------------------------
GF.InitObjectives({
  Cfg = function(...) return Cfg(...) end,
  Char = function(...) return Char(...) end,
  LearnText = function(...) return LearnText(...) end,
  OpenGuide = function(...) return OpenGuide(...) end,
  ProfOn = function(...) return ProfOn(...) end,
  RecipeLookup = function(...) return RecipeLookup(...) end,
  RouteFor = function(...) return RouteFor(...) end,
  ShortMoney = function(...) return ShortMoney(...) end,
  SkillUpChance = function(...) return SkillUpChance(...) end,
  UpdateTracker = function(...) return UpdateTracker(...) end,
})

function UpdateTracker(retry, tick)
  if RefreshGuide then xpcall(RefreshGuide, geterrorhandler()) end
  local entries = Cfg("nextSteps") and NextStepList() or {}
  -- lo que puedes hacer en la zona donde estas va arriba: farmeo de esa zona o materiales
  -- que ya conseguiste aqui (el addon los aprende solo al abrir botines)
  local zoneNow = GetRealZoneText()
  local SS = GoldFinderDB.sources
  for _, e in ipairs(entries) do
    e.score = 0
    if e.gather and e.zone == zoneNow then
      e.score = 2
    else
      for _, m in ipairs(e.mats or {}) do
        if m.have < m.need and SS and SS[m.id] and SS[m.id][zoneNow] then e.score = 1; break end
      end
    end
  end
  table.sort(entries, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.prof < b.prof
  end)
  -- firma barata de lo calculado: en el aviso periodico (tick, cada 4 s) sin cambios no se repinta nada oculto
  local function sv(x) return type(x) == "table" and "t" or tostring(x) end
  local sig = { sv(Cfg("trackerMode")), sv(GoldFinderDB.trackerCollapsed), sv(zoneNow) }
  for _, e in ipairs(entries) do
    sig[#sig + 1] = table.concat({ sv(e.prof), sv(e.rank), sv(e.from), sv(e.upto), sv(e.what or e.recipe or e.zone),
      sv(e.qty), sv(e.score), sv(e.unknown), e.train and "1" or "0", e.game and "1" or "0" }, "|")
    for _, m in ipairs(e.mats or {}) do sig[#sig + 1] = sv(m.id) .. ":" .. sv(m.have) .. "/" .. sv(m.need) end
  end
  sig = table.concat(sig, ";")
  local same = tick and Skin.trackerSig == sig and not (Skin.Objectives and Skin.Objectives.pending())
  Skin.trackerSig = sig
  -- bloque del seguimiento de objetivos (trackerMode "objetivos") y notas de la lista de recetas
  local OB, onObjectives, obWaiting = Skin.Objectives, false, false
  if same then
    onObjectives = OB and OB.active() or false
  else
    if OB then
      onObjectives = xpcall(function() obWaiting = OB.refresh(entries) end, geterrorhandler()) and OB.active()
    end
    if Skin.RecipeNotes then xpcall(Skin.RecipeNotes.refresh, geterrorhandler()) end
  end
  local f = GoldFinderTracker
  if #entries == 0 then
    if f then f:Hide() end
    return
  end
  -- la ventana flotante no se ve (el paso va al seguimiento de objetivos): sin cambios no se rehace
  if same and onObjectives then
    if f then f:Hide() end
    return
  end
  if not f then
    -- panel ligero como el seguimiento de misiones: borde de tooltip y fondo translucido
    f = Skin.Panel("GoldFinderTracker", UIParent, "tooltip")
    f:SetSize(TRACK_W + 24, 60)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, _, relPoint, x, y = self:GetPoint()
      GoldFinderDB.trackerPos = { point, relPoint, x, y }
    end)
    f.title = Text(f, 12, PAL.gold); f.title:SetPoint("TOPLEFT", 12, -9)
    f.title:SetText("GoldFinder Forever: siguiente paso")
    local close = Skin.Close(f, function()
      GoldFinderDB.nextSteps = false
      UpdateTracker()
      for _, u in ipairs(uiInstances) do pcall(u.refresh) end
    end, 22)
    close:SetPoint("TOPRIGHT", -1, -1)
    local fold = Skin.Icon(f, 14, GoldFinderDB.trackerCollapsed and Skin.PLUS or Skin.MINUS,
      GoldFinderDB.trackerCollapsed and "+" or "-", "Plegar o desplegar", function(self)
      GoldFinderDB.trackerCollapsed = (not GoldFinderDB.trackerCollapsed) or nil
      Skin.Fold(self, GoldFinderDB.trackerCollapsed)
      UpdateTracker()
    end)
    fold:SetPoint("RIGHT", close, "LEFT", -2, 0)
    local gbtn = Skin.Icon(f, 16, Skin.BOOK, "G", "Guia de profesion", function() OpenGuide() end)
    gbtn:SetPoint("RIGHT", fold, "LEFT", -4, 0)
    local pos = GoldFinderDB.trackerPos
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else f:SetPoint("LEFT", UIParent, "LEFT", 20, 120) end
  end

  local missing = obWaiting and true or false
  local y = -30
  for i, e in ipairs(entries) do
    local r = TrackerRow(f, i)
    r.entry = e
    local mats = {}
    for j, m in ipairs(e.mats) do
      if j <= 3 then
        local nm = C_Item.GetItemInfo(m.id)
        if not nm then
          missing = true
          if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(m.id) end
          nm = "item:" .. m.id
        end
        local col = m.have >= m.need and "|cff59eb8d" or "|cffffa640"
        mats[#mats + 1] = format("%s%s %d/%d|r", col, nm, m.have, m.need)
      end
    end
    local now = GetTime()
    if #e.mats > 0 then
      local ready = true
      for _, m in ipairs(e.mats) do
        if m.have < m.need then ready = false; break end
      end
      local key = e.prof .. "|" .. (e.upto or 0) .. "|" .. (e.what or e.recipe or "")
      if ready and readyState[key] == false and Cfg("readyAlert") and not e.unknown then
        Print(format("%s: ya tienes los materiales para %s.", e.prof, StepText(e)))
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE or 878)
        r:Flash()
      end
      readyState[key] = ready
    end
    local ss = skillSess[e.prof]
    local prevStep = lastStep[e.prof]
    -- La ruta se recalcula (precios, bolsas): el objetivo del paso puede subir sin haberlo cumplido. Solo cuenta
    -- como completado si tu habilidad llego al objetivo anterior.
    if ss and prevStep and e.upto and e.upto > prevStep and e.rank and e.rank >= prevStep then ss.done = now end
    lastStep[e.prof] = e.upto or prevStep
    local collapsed = GoldFinderDB.trackerCollapsed
    local txt
    if collapsed then
      txt = format("|cffffd100%s|r  %d%s", e.prof, e.rank, e.upto and (" > " .. e.upto) or "")
    elseif e.game then
      txt = format("|cffffd100%s %d|r  %s", e.prof, e.rank, StepText(e))
    else
      txt = format("|cffffd100%s|r  %d > %d: %s", e.prof, e.rank, e.upto, StepText(e))
    end
    if not collapsed then
      if e.train then txt = txt .. "\n|cffffa640" .. TrainText(e) .. "|r" end
      local leaveTxt = LeaveText(e)
      if leaveTxt then txt = txt .. "\n|cffb3b3b3" .. leaveTxt .. "|r" end
      if e.gather then
        local alt = AltZoneText(e.prof, e.rank, e.zone)
        if alt then txt = txt .. "\n|cffffa640" .. alt .. "|r" end
      end
      if e.unknown then
        txt = txt .. "\n|cffff6666No sabes esta receta:|r " .. LearnText(e)
        if e.learn and e.learn.item and not C_Item.GetItemInfo(e.learn.item) then missing = true end
      end
      if #mats > 0 then
        local ready = true
        for _, m in ipairs(e.mats) do
          if m.have < m.need then ready = false; break end
        end
        txt = txt .. "\n" .. (ready and "|cff59eb8dListo:|r " or "") .. table.concat(mats, "  ")
      end
      local here = {}
      for _, m in ipairs(e.mats) do
        local z = m.have < m.need and SS and SS[m.id] and SS[m.id][zoneNow]
        if z then
          local nm = C_Item.GetItemInfo(m.id) or ("item:" .. m.id)
          here[#here + 1] = nm .. (z.mob and (" (" .. z.mob .. ")") or "")
        end
      end
      if #here > 0 then txt = txt .. "\n|cff6bb5ffAqui: " .. table.concat(here, ", ") .. "|r" end
      local sl = SessionLine(e)
      if sl ~= "" then txt = txt .. "\n" .. sl end
    end
    if ss and ss.done and now - ss.done < 10 then
      txt = "|cff59eb8d¡Tramo completado!|r  " .. txt
      if ss.doneTimer ~= ss.done then
        ss.doneTimer = ss.done
        C_Timer.After(10.5, function() xpcall(UpdateTracker, geterrorhandler()) end)
      end
    end
    if e.score and e.score > 0 then txt = "|cff6bb5ff>|r " .. txt end
    r.text:SetText(txt)
    if ss and ss.flash and now - ss.flash < 1.5 and ss.flashShown ~= ss.flash then
      ss.flashShown = ss.flash
      r:Flash()
    end
    local h = (r.text:GetStringHeight() or 28) + 8
    r:SetHeight(h)
    local frac = 0
    if e.upto then
      local span = e.upto - (e.from or 0)
      frac = span > 0 and math.min(1, math.max(0, (e.rank - (e.from or 0)) / span)) or 0
    end
    r.bar:SetWidth(math.max(1, TRACK_W * frac))
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y)
    r:Show()
    y = y - h - 8
  end
  for i = #entries + 1, #trackerRows do trackerRows[i]:Hide() end
  f:SetHeight(-y + 4)
  -- con el bloque en el seguimiento de objetivos la ventana flotante no se muestra (sus avisos siguen igual)
  if onObjectives then f:Hide() else f:Show() end
  if missing and not retry then
    C_Timer.After(1.5, function() UpdateTracker(true) end)
  end
end

-- Abre GoldFinder en Opciones > AddOns (se define mas abajo, junto al registro). Devuelve false si no se pudo
-- (cliente sin la API Settings o en combate): entonces la pestana Ajustes muestra la pagina de abajo.
local OpenOptions

local settingsScrollCount = 0
local function MakeSettings(parent)
  local outer = CreateFrame("Frame", nil, parent)
  outer:SetAllPoints(parent)
  settingsScrollCount = settingsScrollCount + 1
  local sf = CreateFrame("ScrollFrame", "GoldFinderSettingsScroll" .. settingsScrollCount, outer, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", outer, "TOPLEFT", 0, 0)
  sf:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", -26, 0)
  local v = CreateFrame("Frame", nil, sf)
  v:SetSize(700, 1335)
  sf:SetScrollChild(v)
  sf:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then v:SetWidth(w) end end)
  local title = Text(v, 13, PAL.gold); title:SetPoint("TOPLEFT", v, "TOPLEFT", 0, 0); title:SetText("Opciones")
  local y = -32
  local checks = {
    { "tip", "Consejo vender / subastar / guardar en los tooltips" },
    { "track", "Registrar el cuero que recoges (pestana Sesion)" },
    { "nextSteps", "Ventana flotante con el siguiente paso de las guias de profesion" },
    { "crossChars", "Avisar de materiales que sirven a las profesiones de mis otros personajes" },
    { "questItems", "Proteger objetos de mision: no vender, subastar ni enviar lo que piden tus misiones activas" },
    { "gamePlan", "Siguiente paso segun mis recetas y los precios de la subasta (en vez de la guia)" },
    { "shopping", "Pestana Compras: materiales que me faltan para el paso actual, con precios" },
    { "readyAlert", "Avisar (chat y sonido) cuando reuna los materiales de un paso" },
    { "mailPanel", "Panel junto al correo con lo que conviene enviar al banquero (si no usas el correo de TSM)" },
    { "bankPanel", "Panel junto al banco con lo que conviene depositar (y lo que mejor llevas encima)" },
    { "vendorBox", "Cuadrito junto al vendedor con las recetas que te sirven (el tooltip siempre las indica)" },
    { "sellPanel", "Panel de venta junto al vendedor: lo que conviene venderle, cada objeto con su boton Vender" },
    { "useSkillUp", "Usar la ruta de SkillUp Forever (si lo tienes) para decidir que materiales guardar" },
    { "craftTab", "Pestana Fabricar: que compensa fabricar con tus materiales (valor del objeto fabricado)" },
    { "routeTab", "Pestana Ruta: planificador de ruta de profesion con tus recetas y los precios de la subasta" },
    { "profTabs", "Pestanas de GoldFinder en la ventana de profesiones" },
    { "recipeNotes", "Notas en la lista de recetas: probabilidad de subir y coste o ganancia por punto" },
    -- eleccion de dos valores como casilla: marcada = seguimiento de objetivos, sin marcar = ventana flotante
    { "trackerMode", "Siguiente paso en el seguimiento de objetivos (sin marcar: ventana flotante)",
      get = function() return Cfg("trackerMode") ~= "flotante" end,
      set = function(on) GoldFinderDB.trackerMode = on and "objetivos" or "flotante" end },
  }
  v.cbs = {}
  for _, c in ipairs(checks) do
    local cb = CreateFrame("CheckButton", nil, v, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", v, "TOPLEFT", 0, y)
    cb.get = c.get
    if c.get then cb:SetChecked(c.get() and true or false) else cb:SetChecked(Cfg(c[1]) and true or false) end
    cb:SetScript("OnClick", function(self)
      if c.set then c.set(self:GetChecked() and true or false)
      else GoldFinderDB[c[1]] = self:GetChecked() and true or false end
      if c[1] == "nextSteps" or c[1] == "trackerMode" then UpdateTracker() end
      if c[1] == "recipeNotes" and Skin.RecipeNotes then pcall(Skin.RecipeNotes.refresh) end
      if c[1] == "shopping" or c[1] == "craftTab" or c[1] == "routeTab" or c[1] == "profTabs" then
        if Skin.ProfTabs then pcall(Skin.ProfTabs.later) end
        for _, u in ipairs(uiInstances) do
          pcall(u.layoutNav)
          if (not Cfg("shopping") and u.current == "compras") or (not Cfg("craftTab") and u.current == "fabricar")
              or (not Cfg("routeTab") and u.current == "ruta") then
            pcall(u.open, "resumen")
          end
        end
      end
    end)
    local l = Text(v, 13); l:SetPoint("LEFT", cb, "RIGHT", 6, 0); l:SetText(c[2])
    v.cbs[c[1]] = cb
    y = y - 32
  end
  y = y - 8
  local eb = CreateFrame("EditBox", nil, v, "InputBoxTemplate")
  eb:SetSize(70, 22)
  eb:SetPoint("TOPLEFT", v, "TOPLEFT", 8, y)
  eb:SetAutoFocus(false)
  local function show() eb:SetText(tostring((Cfg("minGain") or 0) / 10000)) end
  local function save()
    local val = tonumber(eb:GetText())
    if val and val >= 0 then GoldFinderDB.minGain = val * 10000 end
    show()
  end
  eb:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
  eb:SetScript("OnEditFocusLost", save)
  local l = Text(v, 13); l:SetPoint("LEFT", eb, "RIGHT", 12, 0)
  l:SetText("Ganancia minima (oro) para recomendar subasta en vez de vendedor")
  y = y - 34
  local eb2 = CreateFrame("EditBox", nil, v, "InputBoxTemplate")
  eb2:SetSize(70, 22)
  eb2:SetPoint("TOPLEFT", v, "TOPLEFT", 8, y)
  eb2:SetAutoFocus(false)
  local function show2() eb2:SetText(tostring(Cfg("reserve") or 20)) end
  local function save2()
    local val = tonumber(eb2:GetText())
    if val and val >= 0 then GoldFinderDB.reserve = floor(val) end
    show2()
  end
  eb2:SetScript("OnEnterPressed", function(self) save2(); self:ClearFocus() end)
  eb2:SetScript("OnEditFocusLost", save2)
  local l2 = Text(v, 13); l2:SetPoint("LEFT", eb2, "RIGHT", 12, 0)
  l2:SetText("Fabricaciones a reservar de cada material (para subir tu profesion)")
  y = y - 34
  -- boton Subastar (mismas claves que en Opciones > AddOns)
  for _, o in ipairs({
    { "postMinPct", "Subastar: precio minimo (% del mercado; nunca menos que el vendedor)", 0, 100 },
    { "postMaxPct", "Subastar: precio maximo (% del mercado; por encima, precio normal)", 100, 500 },
    { "postUndercut", "Subastar: rebaja en cobre bajo la subasta mas barata", 0, 500 },
    { "postCapDays", "Subastar: tope de unidades (dias de ventas en la region, si TSM lo sabe)", 1, 14 },
    { "postDuration", "Subastar: duracion en horas (12 o 24)", 12, 24 },
  }) do
    local box = CreateFrame("EditBox", nil, v, "InputBoxTemplate")
    box:SetSize(70, 22)
    box:SetPoint("TOPLEFT", v, "TOPLEFT", 8, y)
    box:SetAutoFocus(false)
    local function showO() box:SetText(tostring(Cfg(o[1]))) end
    local function saveO()
      local val = tonumber(box:GetText())
      if val then
        val = math.min(math.max(floor(val + 0.5), o[3]), o[4])
        if o[1] == "postDuration" then val = val <= 12 and 12 or 24 end
        GoldFinderDB[o[1]] = val
      end
      showO()
    end
    box:SetScript("OnEnterPressed", function(self) saveO(); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", saveO)
    showO()
    v.postShows = v.postShows or {}
    v.postShows[#v.postShows + 1] = showO
    local lo = Text(v, 13); lo:SetPoint("LEFT", box, "RIGHT", 12, 0); lo:SetText(o[2])
    y = y - 34
  end
  local bh = Text(v, 13, PAL.gold)
  bh:SetPoint("TOPLEFT", v, "TOPLEFT", 0, y)
  bh:SetText("Personaje banquero (al que envias lo que hay que subastar)")
  local bankTop = y - 24
  v.bankChecks = {}

  -- Se elige entre los personajes con los que ya has entrado (el addon los identifica al iniciar sesion).
  local function layoutBankers()
    local names = {}
    for key in pairs(GoldFinderDB.chars or {}) do
      names[#names + 1] = ResolveFullName(key:match("^([^-]+)") or key)
    end
    table.sort(names)
    table.insert(names, 1, "")   -- "" = ninguno
    local cur = BankerName()
    for i, name in ipairs(names) do
      if i <= 9 then
        local cb = v.bankChecks[i]
        if not cb then
          cb = CreateFrame("CheckButton", nil, v, "UICheckButtonTemplate")
          cb:SetSize(24, 24)
          cb.label = Text(v, 12)
          cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
          cb:SetScript("OnClick", function(self)
            GoldFinderDB.banker = ResolveFullName(self.charName or "")
            for _, u in ipairs(uiInstances) do pcall(u.refresh) end
          end)
          v.bankChecks[i] = cb
        end
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", v, "TOPLEFT", col * 220, bankTop - row * 26)
        cb.charName = name
        cb.label:SetText(name == "" and "Ninguno" or name)
        cb:SetChecked((cur == nil and name == "")
          or (cur ~= nil and (name:lower() == cur:lower()
            or (not cur:find(" ", 1, true) and FirstName(name):lower() == cur:lower()))))
        cb:Show()
        cb.label:Show()
      end
    end
    for i = #names + 1, #v.bankChecks do
      v.bankChecks[i]:Hide()
      v.bankChecks[i].label:Hide()
    end
  end
  y = bankTop - 3 * 26 - 12
  local ph = Text(v, 13, PAL.gold)
  ph:SetPoint("TOPLEFT", v, "TOPLEFT", 0, y)
  ph:SetText("Profesiones que cuentan (materiales a guardar, patrones y siguiente paso)")
  local profTop = y - 24
  v.profChecks = {}
  v.info = Text(v, 12, PAL.dim)
  v.info:SetWordWrap(true)
  v.info:SetJustifyV("TOP")
  v.info:SetSpacing(4)

  local function layoutProfs()
    local names = {}
    for prof in pairs(Char().prof) do names[#names + 1] = prof end
    table.sort(names)
    for i, name in ipairs(names) do
      local cb = v.profChecks[i]
      if not cb then
        cb = CreateFrame("CheckButton", nil, v, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb.label = Text(v, 12)
        cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb:SetScript("OnClick", function(self)
          Char().off[self.profName] = (not self:GetChecked()) or nil
          UpdateTracker()
          for _, u in ipairs(uiInstances) do pcall(u.refresh) end
        end)
        v.profChecks[i] = cb
      end
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      cb:ClearAllPoints()
      cb:SetPoint("TOPLEFT", v, "TOPLEFT", col * 330, profTop - row * 26)
      cb.profName = name
      local d = Char().prof[name]
      cb.label:SetText(name .. (d.rank and (" (habilidad " .. d.rank .. ")") or ""))
      cb:SetChecked(not Char().off[name])
      cb:Show()
      cb.label:Show()
    end
    for i = #names + 1, #v.profChecks do
      v.profChecks[i]:Hide()
      v.profChecks[i].label:Hide()
    end
    local rows = math.ceil(#names / 2)
    v.info:ClearAllPoints()
    v.info:SetPoint("TOPLEFT", v, "TOPLEFT", 0, profTop - rows * 26 - 10)
    v.info:SetPoint("TOPRIGHT", v, "TOPRIGHT", 0, profTop - rows * 26 - 10)
  end

  v.refresh = function()
    for k, cb in pairs(v.cbs) do
      if cb.get then cb:SetChecked(cb.get() and true or false) else cb:SetChecked(Cfg(k) and true or false) end
    end
    show()
    show2()
    for _, fn in ipairs(v.postShows or {}) do fn() end
    layoutBankers()
    layoutProfs()
    v.info:SetText("GoldFinder lee tus profesiones y tu habilidad al entrar. Las recetas se memorizan al abrir la ventana de cada profesion.\nLos objetos que marques con Fijar tambien se guardan.")
  end
  outer.refresh = v.refresh
  return outer
end

-- Lista de objetos que conviene subastar, en el formato de importacion de grupos de TSM ("i:ID,i:ID").
-- GoldFinder decide QUE vender; TSM publica y envia por correo.
local function ShowTSMExport()
  local rows = BagRows()
  local ids = {}
  for _, r in ipairs(rows) do
    if r.verdict == "AH" and not r.bound then ids[#ids + 1] = "i:" .. r.id end
  end
  if #ids == 0 then
    Print("No hay objetos que convenga subastar ahora mismo.")
    return
  end
  local f = GoldFinderExport
  if not f then
    -- dialogo clasico (como el panel de venta); sin BackdropTemplate, el fondo plano de antes
    f = Skin.Panel("GoldFinderExport", UIParent, "dialog")
    f:SetSize(540, 150)
    f:SetPoint("CENTER", 0, 140)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.title = Skin.Head(f, "GoldFinder Forever: exportar a TSM")
    f.note = Text(f, 12, PAL.text)
    f.note:SetPoint("TOPLEFT", 20, -40)
    f.note:SetWidth(500)
    f.note:SetWordWrap(true)
    f.note:SetJustifyV("TOP")
    f.note:SetText("Copia el texto con Ctrl+C y pegalo en TSM: Grupos > Importar (crea o rellena un grupo). Luego TSM publica y envia por correo.")
    f.edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.edit:SetSize(496, 22)
    f.edit:SetPoint("TOPLEFT", 24, -86)
    f.edit:SetAutoFocus(false)
    f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
    f.count = Text(f, 12, PAL.dim)
    f.count:SetPoint("BOTTOMLEFT", 20, 18)
    local close = Skin.Close(f, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -4, -4)
    tinsert(UISpecialFrames, "GoldFinderExport")
  end
  f.edit:SetText(table.concat(ids, ","))
  f.count:SetText(#ids .. " objeto(s) que conviene subastar (sin los ligados)")
  f:Show()
  f.edit:SetFocus()
  f.edit:HighlightText()
end


-- Precios a los que el vendedor te vende cada objeto (se anotan al abrir un vendedor): sirven para costear materiales.
local function RecordVendorPrices()
  if not (GetMerchantNumItems and GoldFinderDB) then return end
  GoldFinderDB.vendorBuy = GoldFinderDB.vendorBuy or {}
  for i = 1, (GetMerchantNumItems() or 0) do
    local link = GetMerchantItemLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then
      local _, _, price, qty, _, _, _, extended = GF.MerchantItemInfo(i)
      if price and price > 0 and not extended then
        GoldFinderDB.vendorBuy[id] = price / math.max(1, qty or 1)
      end
    end
  end
end

-- opts (opcional): embedded = sin pestanas propias (las pone la ventana que lo aloja); only = vistas permitidas;
-- onNav = se llama en lugar de recolocar las pestanas; back = accion para volver a la pagina del juego.
-- auction = pestana de la casa de subastas: solo lo que se usa alli (Bolsas con la subasta primero, Compras, Cuero)
-- y Ajustes como boton de la cabecera.
local function CreateUI(parent, opts)
  -- VISTAS DE LA CASA DE SUBASTAS
  -- Compras sale en la subasta si su pestana esta activa o si faltan materiales para el paso actual
  -- (es donde se compran); el resto de vistas (Resumen, Fabricar, Ruta, Sesion) viven en otras ventanas.
  local function AHViewKeys(shoppingOn, missing)
    local keys = { "bolsas" }
    if shoppingOn or missing then keys[#keys + 1] = "compras" end
    keys[#keys + 1] = "cuero"
    return keys
  end
  -- filas de Bolsas con lo que se subasta aqui primero; luego subasta via banquero o ligado, vendedor, guardar.
  -- Orden estable: dentro de cada grupo se mantiene el orden de BagRows. No modifica la lista recibida.
  local function AHBagOrder(rows)
    local rank = { AH = 1, VENDOR = 3, KEEP = 4, NONE = 5 }
    local out, pos = {}, {}
    for i, r in ipairs(rows) do out[i] = r; pos[r] = i end
    local function rk(r)
      if r.verdict == "AH" and (r.toBanker or r.bound) then return 2 end
      return rank[r.verdict] or 6
    end
    table.sort(out, function(x, y)
      local rx, ry = rk(x), rk(y)
      if rx ~= ry then return rx < ry end
      return pos[x] < pos[y]
    end)
    return out
  end
  -- FIN DE VISTAS DE LA CASA DE SUBASTAS

  -- native: la ventana propia con marco de Blizzard (retrato, titulo e Inset del ButtonFrameTemplate).
  -- Si no, el contenido va incrustado (pestana de la subasta, que ya tiene su marco) con su propio Inset.
  local native = parent.gfNative
  local embedded = opts and opts.embedded
  local auction = opts and opts.auction
  local ui = CreateFrame("Frame", "GoldFinderUI" .. (#uiInstances + 1), parent)
  ui:SetAllPoints(parent)
  ui.back = opts and opts.back
  ui:SetFrameLevel(parent:GetFrameLevel() + 20)

  local header = CreateFrame("Frame", nil, ui)
  if native then
    -- franja entre la barra del titulo y el Inset, a la derecha del retrato
    header:SetPoint("TOPLEFT", ui, "TOPLEFT", 60, -24); header:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -8, -24)
    header:SetHeight(34)
  elseif parent.gfPadRight then
    -- ventana propia sin plantilla: titulo dibujado aqui
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(42)
    local title = Text(header, 18, PAL.gold); title:SetPoint("TOPLEFT", 6, -4); title:SetText("GoldFinder Forever")
  else
    -- dentro de la subasta el titulo ya lo pone el marco de la casa de subastas
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(30)
  end
  ui.status = Text(header, 11, PAL.text)
  if parent.gfPadRight then ui.status:SetPoint("TOPLEFT", 6, -26) else ui.status:SetPoint("LEFT", header, "LEFT", 8, 0) end
  ui.status:SetPoint("RIGHT", header, "RIGHT", -240, 0)
  local bScan = Btn(header, "Escanear", 90, 22, nil, function() StartFullScan() end)
  bScan:SetPoint("RIGHT", header, "RIGHT", -(parent.gfPadRight or 4), 0)

  local inset = native and parent.Inset
  if not inset then
    inset = NewFrame("Frame", nil, ui, "InsetFrameTemplate")
    if not inset then
      inset = CreateFrame("Frame", nil, ui)
      local ib = Flat(inset, "BACKGROUND", { 0, 0, 0, 0.35 }); ib:SetAllPoints()
    end
    if native then
      inset:SetPoint("TOPLEFT", ui, "TOPLEFT", 4, -60); inset:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -6, 6)
    else
      -- abajo queda sitio para las pestanas, que cuelgan del Inset
      inset:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2); inset:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", 0, embedded and 0 or 32)
    end
  end
  local bReset = Btn(header, "Reiniciar sesion", 110, 22, nil, function()
    Char().session = nil
    Sess()
    MarkSessionBaseline()
    ui.refresh()
  end)
  bReset:SetPoint("RIGHT", bScan, "LEFT", -8, 0)
  bReset:Hide()
  local bExport = Btn(header, "Exportar a TSM", 110, 22, nil, function() ShowTSMExport() end)
  bExport:SetPoint("RIGHT", bScan, "LEFT", -8, 0)
  bExport:Hide()
  if auction then
    -- en la subasta no hay pestana Ajustes: un boton abre la pagina de Opciones > AddOns
    local bOpts = Btn(header, "Ajustes", 80, 22, nil, function()
      local function nope() Print("Escribe /gf ajustes para abrir las opciones.") end
      if not (OpenOptions and OpenOptions(nope)) then nope() end
    end)
    bOpts:SetPoint("RIGHT", bScan, "LEFT", -8, 0)
    bExport:ClearAllPoints(); bExport:SetPoint("RIGHT", bOpts, "LEFT", -8, 0)
    ui.status:SetPoint("RIGHT", header, "RIGHT", -330, 0)
  end

  -- pestanas abajo, como en la ventana de personaje (PanelTabButtonTemplate). Sin la plantilla, botones.
  local navDefs = {
    { "resumen", "Resumen" }, { "bolsas", "Bolsas" }, { "compras", "Compras" }, { "fabricar", "Fabricar" }, { "ruta", "Ruta" }, { "cuero", "Cuero" },
    { "sesion", "Sesion" }, { "ajustes", "Ajustes" },
  }
  if embedded then navDefs = {} end
  ui.nav = {}
  ui.Tabs = {}
  for i, def in ipairs(navDefs) do
    local b = NewFrame("Button", ui:GetName() .. "Tab" .. i, ui, "PanelTabButtonTemplate")
    if b then
      b.gfTab = true
      b:SetID(i)
      b:SetText(def[2])
      -- margen de 12 y ancho minimo de 70: sin margen el texto queda pegado al borde de la pestana
      if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 12, nil, 70) end
      b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
    else
      b = Btn(ui, def[2], 90, 22)
    end
    b:SetScript("OnClick", function()
      if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
      -- Ajustes abre la pagina de Opciones > AddOns; si no se puede, queda la pagina propia de la ventana
      if def[1] == "ajustes" and OpenOptions and OpenOptions(function() ui.open("ajustes") end) then return end
      ui.open(def[1])
    end)
    ui.nav[def[1]] = b
    ui.Tabs[i] = b
  end

  -- subasta: vistas que tocan ahora (Compras tambien sin su pestana si faltan materiales del paso actual)
  local function ahAllowed(key)
    for _, k in ipairs(ui.ahKeys or {}) do if k == key then return true end end
    return false
  end
  function ui.ahUpdate()
    local shop = Cfg("shopping") and true or false
    local missing = false
    if not shop then
      pcall(function()
        for _, e in ipairs(NextStepList()) do
          if e.unknown and e.learn and e.learn.item then
            local bags, bank = Counts(e.learn.item)
            if (bags or 0) + (bank or 0) < 1 then missing = true end
          end
          for _, m in ipairs(e.mats or {}) do
            if (m.need or 0) > (m.have or 0) then missing = true end
          end
        end
      end)
    end
    ui.ahKeys = AHViewKeys(shop, missing)
  end
  if auction then ui.ahUpdate() end

  function ui.layoutNav()
    local prev
    if auction then ui.ahUpdate() end
    for _, def in ipairs(navDefs) do
      local b = ui.nav[def[1]]
      local hide
      if auction then
        hide = not ahAllowed(def[1])
      else
        hide = (def[1] == "compras" and not Cfg("shopping")) or (def[1] == "fabricar" and not Cfg("craftTab"))
          or (def[1] == "ruta" and not Cfg("routeTab"))
      end
      if hide then
        b:Hide()
      else
        b:ClearAllPoints()
        if prev then
          b:SetPoint("LEFT", prev, "RIGHT", b.gfTab and -8 or 4, 0)
        elseif native then
          b:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 11, 2)
        else
          b:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 6, 2)
        end
        b:Show()
        prev = b
      end
    end
  end
  ui.layoutNav()
  if embedded then ui.layoutNav = function() if opts.onNav then opts.onNav() end end end

  local area = CreateFrame("Frame", nil, ui)
  area:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
  area:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -6, 6)
  ui.summary = MakeSummary(area)
  ui.list = MakeList(area)
  local okS, settings = pcall(MakeSettings, area)
  ui.settings = okS and settings or nil

  -- FILTRO DE BOLSAS
  -- Fila visible en Bolsas: todo menos los objetos sin precio (ligados, de mision...); los que piden escanear la
  -- subasta se listan con su motivo. Solo filtra la lista: el vendedor y el correo siguen sin verlos (no son AH/VENDOR).
  local function BagListed(r)
    return r.verdict ~= "NONE" or r.reason == "sin datos de subasta: escanea"
  end
  -- FIN DE FILTRO DE BOLSAS
  local verdictText = {
    AH = GREEN .. "SUBASTA|r", VENDOR = ORANGE .. "VENDEDOR|r",
    KEEP = BLUE .. "GUARDAR|r", NONE = DIM .. "sin datos|r",
  }

  ui.loaders = {
    resumen = function()
      local s = ui.summary
      local _, sum = BagRows()
      s.c1.value:SetText(Money(sum.sell))
      s.c1.sub:SetText(sum.nAH .. " a subasta, " .. sum.nVendor .. " al vendedor")
      s.c2.value:SetText(sum.nKeep .. " objetos")
      s.c2.sub:SetText("para tu profesion o esperar")
      local sess = Sess()
      if sess.count > 0 and sess.secs >= 60 then
        s.c3.value:SetText(Money(sess.total / (sess.secs / 3600)) .. "/h")
        s.c3.sub:SetText(sess.count .. " u. en " .. floor(sess.secs / 60) .. " min")
      elseif sess.count > 0 then
        s.c3.value:SetText(Money(sess.total))
        s.c3.sub:SetText(sess.count .. " u. (poco tiempo aun para el oro/hora)")
      else
        s.c3.value:SetText("-")
        s.c3.sub:SetText("Desuella algo para empezar")
      end
      local tips = {}
      local known = {}
      for prof, d in pairs(Char().prof) do if d.learned then known[#known + 1] = prof:lower() end end
      local all = table.concat(known, " ")
      if not all:find("leather") then tips[#tips + 1] = "- Abre una vez tu ventana de Peleteria para memorizar sus materiales." end
      if not all:find("cook") then tips[#tips + 1] = "- Abre tambien tu ventana de Cocina: asi sabre que materiales guardar para subirla." end
      local st = Auctionator and Auctionator.SavedState
      local t = st and math.max(st.TimeOfLastReplicateScan or 0, st.TimeOfLastBrowseScan or 0) or 0
      if t == 0 then tips[#tips + 1] = "- Pulsa Escanear con la subasta abierta para tener precios."
      elseif time() - t > 1800 then tips[#tips + 1] = "- Tus precios tienen mas de 30 min: conviene escanear otra vez." end
      if (sum.nBank or 0) > 0 then
        tips[#tips + 1] = format("- %d objeto(s) para enviar a %s y subastar (valor aprox. %s).",
          sum.nBank, BankerName(), ShortMoney(sum.bankValue or 0))
      elseif sum.nAH > 0 then
        tips[#tips + 1] = "- Tienes " .. sum.nAH .. " objeto(s) que conviene subastar: pestana Bolsas."
      end
      if sum.nKeep > 0 then tips[#tips + 1] = "- " .. sum.nKeep .. " objeto(s) marcados GUARDAR: llevalos al banco." end
      local unsaved = UnsavedUnits()
      if unsaved >= 5 then tips[#tips + 1] = "- " .. unsaved .. " unidades de cuero de esta sesion aun no estan en disco (se guardan al cerrar sesion)." end
      if sess.count > 0 then tips[#tips + 1] = "- Mira la pestana Sesion: que zona te da mas oro por hora." end
      if #tips == 0 then tips[1] = "- Todo al dia." end
      s.tips:SetText(table.concat(tips, "\n"))
    end,

    bolsas = function()
      ui.list.setHeaders("Objeto", "Cant.", "Decision", "Valor")
      local allRows = BagRows()
      -- en la subasta lo que se puede subastar alli va arriba (en /gf queda el orden de siempre)
      if auction then allRows = AHBagOrder(allRows) end
      local rows, hidden = {}, 0
      for _, r in ipairs(allRows) do
        -- los objetos sin precio (ligados, de mision, piedra de hogar...) no se listan; los de "escanea" si
        if BagListed(r) then rows[#rows + 1] = r else hidden = hidden + 1 end
      end
      local out = {}
      for _, r in ipairs(rows) do
        local c2 = verdictText[r.verdict]
        local name = ItemLink(r.id)
        if r.bound then name = name .. "  " .. DIM .. "(ligado)|r" end
        if r.verdict == "KEEP" and r.count > 0 then
          name = name .. " " .. BLUE .. (r.forOther and ("> para " .. r.forOther) or "> banco") .. "|r"
        end
        if r.verdict == "AH" and r.toBanker and not r.bound then
          name = name .. " " .. BLUE .. "> " .. BankerName() .. "|r"
        end
        local acts, shift = {}, nil
        -- Subastar: publica con un clic al precio y cantidad calculados (tambien si hay banquero: estas en la
        -- subasta). Mayus+clic (en el boton o en la fila): prepararlo en la pestana Selling de Auctionator.
        if r.verdict == "AH" and not r.bound then
          local A = Skin.Auction
          local okP, pl = pcall(A.Plan, r.id)
          shift = function() SellItem(r.id) end
          acts[#acts + 1] = {
            "Subastar",
            function() if IsShiftKeyDown() then SellItem(r.id) else A.Post(r.id) end end,
            tip = function(tt) A.Tooltip(tt, r.id, r.toBanker) end,
            disabled = not (okP and pl and pl.post),
          }
        end
        if r.manual then
          acts[#acts + 1] = { "Soltar", function() Char().keep[r.id] = nil; ui.refresh() end }
        elseif r.verdict ~= "KEEP" and r.verdict ~= "NONE" then
          acts[#acts + 1] = { "Fijar", function() Char().keep[r.id] = true; ui.refresh() end }
        end
        -- unidades reservadas (tus profesiones y otros personajes): se muestran, y solo se vende o publica el resto
        local reserved
        if (r.verdict == "AH" or r.verdict == "VENDOR") and (r.sellQty or r.count) < r.count then
          reserved = format("%d reservados para %s: se %s %d.", r.count - r.sellQty, r.reserveFor or "tus profesiones",
            r.verdict == "AH" and "subastan" or "venden", r.sellQty)
          if r.reason then reserved = reserved .. " " .. r.reason end
        end
        out[#out + 1] = {
          id = r.id, name = name, shift = shift,
          reason = reserved or r.reason,
          c1 = "x" .. r.count .. (r.bank > 0 and (" +" .. r.bank .. "b") or ""),
          c2 = c2, c3 = r.verdict == "KEEP" and (DIM .. Money(r.value) .. "|r") or Money(r.value), actions = acts,
        }
      end
      if hidden > 0 then
        out[#out + 1] = { name = DIM .. hidden .. " ocultos (sin precio)|r" }
      end
      ui.list.setRows(out, "Tus bolsas estan vacias.")
    end,

    compras = function()
      ui.list.setHeaders("Material", "Faltan", "Precio c/u", "Coste")
      local byId, order = {}, {}
      local function add(id, need, have, use)
        local n = byId[id]
        if not n then
          n = { id = id, need = 0, have = have, uses = {} }
          byId[id] = n
          order[#order + 1] = n
        end
        n.need = n.need + need
        n.uses[#n.uses + 1] = use
      end
      for _, e in ipairs(NextStepList()) do
        if e.unknown and e.learn and e.learn.item then
          local bags, bank = Counts(e.learn.item)
          add(e.learn.item, 1, bags + bank, "aprender " .. e.what .. " (" .. LearnText(e) .. ")")
        end
        for _, m in ipairs(e.mats or {}) do
          add(m.id, m.need, m.have, e.prof .. (e.upto and (" " .. e.rank .. " > " .. e.upto) or ""))
        end
      end
      local v1 = AHApi()
      local out, total, unknown, allMats = {}, 0, false, {}
      for _, n in ipairs(order) do
        local miss = n.need - n.have
        if miss > 0 then
          local price = v1 and v1.GetAuctionPriceByItemID(CALLER, n.id) or nil
          if price and price <= 0 then price = nil end
          local cost = price and price * miss or nil
          if cost then total = total + cost else unknown = true end
          local mat = { id = n.id, need = n.need, have = n.have }
          allMats[#allMats + 1] = mat
          out[#out + 1] = {
            id = n.id, name = ItemLink(n.id),
            reason = "Para " .. table.concat(n.uses, ", ") .. format(" (tienes %d de %d)", n.have, n.need) .. SourceText(n.id),
            c1 = "x" .. miss,
            c2 = price and ShortMoney(price) or (DIM .. "sin precio|r"),
            c3 = cost and Money(cost) or (DIM .. "-|r"),
            actions = { { "Buscar", function() SearchMaterials({ mats = { mat } }) end } },
          }
        end
      end
      local final = {}
      if #out > 0 then
        final[1] = {
          name = "|cffffd100TOTAL a comprar (paso actual)|r", c1 = #out .. " mat.", c2 = "",
          c3 = Money(total) .. (unknown and "+" or ""),
          actions = { { "Buscar todo", function() SearchMaterials({ mats = allMats }) end } },
        }
        for _, r in ipairs(out) do final[#final + 1] = r end
      end
      -- hasta el tope de rango de cada profesion
      local capRows = {}
      for prof, pd in pairs(Char().prof) do
        if ProfOn(prof) then
          local c = CapCost(prof, pd)
          if c and (c.n > 0 or c.truncated) then
            local short = Skin.Route.CapReason(c)
            capRows[#capRows + 1] = {
              name = format("%s %d > %d", prof, pd.rank, c.truncated and c.to or c.cap),
              reason = (short and (short .. "\n") or "") .. format("%d materiales por comprar%s (estimacion segun tu ruta)",
                c.n, c.unknown > 0 and (", " .. c.unknown .. " sin precio") or ""),
              c1 = c.n .. " mat.", c2 = "",
              c3 = Money(c.cost) .. (c.unknown > 0 and "+" or ""),
              actions = { { "Buscar todo", function() SearchMaterials({ mats = c.mats }) end } },
            }
          end
        end
      end
      table.sort(capRows, function(a, b) return a.name < b.name end)
      if #capRows > 0 then
        final[#final + 1] = { name = "|cffffd100Hasta el tope de rango de cada profesion|r", c1 = "", c2 = "", c3 = "" }
        for _, r in ipairs(capRows) do final[#final + 1] = r end
      end
      ui.list.setRows(final, "No te falta ningun material para el paso actual de tus profesiones (abre la ventana de cada profesion una vez si esperabas ver algo).")
    end,

    fabricar = function()
      ui.list.setHeaders("Fabricar", "Puedes", "Vale c/u", "Ganancia c/u")
      local rows = {}
      for prof, pd in pairs(Char().prof) do
        if ProfOn(prof) and pd.crafts and (not ui.profFilter or ui.profFilter == prof) then
          for name, cr in pairs(pd.crafts) do
            local p = Skin.Route.CraftProfit(cr)
            if p.outVal > 0 then
              rows[#rows + 1] = {
                prof = prof, pd = pd, name = name, out = cr.o, q = p.q, n = p.n, outVal = p.outVal, d = cr.d,
                x = RecipeLookup(pd.skillLine, name), skill = pd.rank or 0, total = p.total, noPrice = p.noPrice,
                viaAH = p.viaAH, gain = p.gain, gainBuy = p.gainBuy,
              }
            end
          end
        end
      end
      table.sort(rows, function(a, b)
        if (a.n > 0) ~= (b.n > 0) then return a.n > 0 end
        if a.n > 0 then return a.total > b.total end
        return (a.gainBuy or -1e12) > (b.gainBuy or -1e12)
      end)
      local out = {}
      for i, r in ipairs(rows) do
        if i > 80 then break end
        -- sin materiales propios: la ganancia comprandolos; algun material sin precio: "sin precio"
        local g = r.n > 0 and r.gain or r.gainBuy
        local gtxt = (r.noPrice or not g) and (DIM .. "sin precio|r")
          or ((g >= 0 and GREEN .. "+" or "|cffff6666-") .. Money(math.abs(g)) .. "|r")
        local chance = r.x and SkillUpChance(r.x, r.skill) or nil
        local color = r.x and RecipeColor(r.x, r.skill) or r.d
        local lines = {
          format("%s%s|r: materiales sueltos valen %s%s", DIM, r.prof, Money(r.outVal - r.gain),
            r.gainBuy and (" | comprandolos ganarias " .. (r.gainBuy >= 0 and "+" or "-") .. Money(math.abs(r.gainBuy)))
              or " | algun material sin precio (escanea la subasta)"),
        }
        if chance and chance > 0 and r.gainBuy then
          local psu = r.gainBuy / chance
          lines[#lines + 1] = format("Probabilidad de subir habilidad: %d%% | por cada subida (comprando los materiales): %s%s",
            math.floor(chance * 100 + 0.5), psu >= 0 and "+" or "-", Money(math.abs(psu)))
        end
        if r.n > 0 then
          lines[#lines + 1] = format("Con lo que te sobra (sin lo reservado para tu ruta): %d fabricaciones = %s en total",
            r.n, (r.total >= 0 and "+" or "-") .. Money(math.abs(r.total)))
          lines[#lines + 1] = format("%sSolo %d unidades valen precio de subasta (/gf tope); el resto, lo que paga el vendedor.|r",
            DIM, Cfg("sellCap") or 5)
        end
        out[#out + 1] = {
          id = r.out,
          name = (C_Item.GetItemInfo(r.out) or ItemLink(r.out)) .. (r.q > 1 and (" x" .. r.q) or "")
            .. ((color == 0 and "  |cffff8040naranja|r") or (color == 1 and "  |cffffff00amarilla|r")
              or (color == 2 and "  |cff40c040verde|r") or (color == 3 and ("  " .. DIM .. "gris|r")) or "")
            .. (chance and format("  %d%%", math.floor(chance * 100 + 0.5)) or ""),
          reason = table.concat(lines, "\n"),
          c1 = r.n > 0 and ("x" .. r.n) or (DIM .. "-|r"),
          c2 = ShortMoney(r.outVal) .. (r.viaAH and "" or (" " .. DIM .. "(vendedor)|r")),
          c3 = gtxt,
          -- dentro de la ventana de profesiones, Abrir la cerraria: se vuelve a la lista de recetas del juego
          actions = { ui.back and { "Recetas", ui.back }
            or { "Abrir", function() OpenProfession({ prof = r.prof, skillLine = r.pd.skillLine }) end } },
        }
      end
      ui.list.setRows(out, "Abre la ventana de cada profesion una vez para que GoldFinder aprenda que fabrica cada receta, y escanea la subasta para tener precios.")
    end,

    ruta = function()
      ui.list.setHeaders("Ruta de profesion", "Cantidad", "Coste", "Venta")
      local out = {}
      local span = Cfg("routeSpan") or 25
      local names = {}
      for prof, pd in pairs(Char().prof) do
        if ProfOn(prof) and pd.crafts and pd.rank and pd.skillLine and (not ui.profFilter or ui.profFilter == prof) then
          names[#names + 1] = prof
        end
      end
      table.sort(names)
      for _, prof in ipairs(names) do
        local plan = RouteFor(Char(), prof, Char().prof[prof].rank + span)
        if plan then
          local net = plan.cost - plan.sell
          out[#out + 1] = {
            name = "|cffffd100" .. prof .. "|r  " .. plan.from .. " > " .. plan.to,
            reason = format("Compras %s | vendiendo lo fabricado recuperas %s | neto %s%s%s", Money(plan.cost), Money(plan.sell),
              net >= 0 and "" or "-", Money(math.abs(net)),
              plan.unknown > 0 and (" | " .. plan.unknown .. " materiales sin precio") or "")
              .. "\nCantidades esperadas, sin sobrantes: puede hacer falta alguna fabricacion mas."
              .. format("\nLo fabricado vale precio de subasta solo en sus primeras %d unidades; el resto, lo que paga el vendedor (/gf tope).", plan.cap),
            c1 = "", c2 = Money(plan.cost), c3 = Money(plan.sell),
          }
          for _, l in ipairs(plan.learns) do
            local t = l.t
            local where = t.zone and (" en " .. t.zone .. (t.x and (" (" .. t.x .. ", " .. t.y .. ")") or "")) or ""
            out[#out + 1] = {
              name = format("Aprender %s  |cffb3b3b3(desde %d)|r", t.n, l.at),
              reason = format("La ensena %s%s. Pide habilidad %d.", t.npc or "tu instructor", where, t.req or 0),
              c1 = "", c2 = t.cost and Money(t.cost) or (DIM .. "sin precio|r"), c3 = "",
            }
          end
          for _, st in ipairs(plan.steps) do
            local chance = SkillUpChance(st.c.x, st.from)
            local nm = (st.c.o and C_Item.GetItemInfo(st.c.o)) or st.c.name
            out[#out + 1] = {
              id = st.c.o,
              name = format("Fabricar %s  |cffb3b3b3(%d > %d)|r  %d%%", nm, st.from, st.to, math.floor(chance * 100 + 0.5)),
              reason = format("%s | por fabricacion: materiales %s, vale %s en subasta (%d de %d) y %s al vendedor (el resto)",
                st.c.name, Money(st.c.unitBuy), Money(st.c.outVal), st.ahUnits, st.n, Money(st.c.outVend)),
              c1 = "x" .. st.n, c2 = Money(st.n * st.c.unitBuy), c3 = Money(st.value),
            }
          end
          local shown = 0
          for _, m in ipairs(plan.mats) do
            if m.missing > 0 and shown < 12 then
              shown = shown + 1
              out[#out + 1] = {
                id = m.id, name = "Comprar " .. ItemLink(m.id),
                reason = format("Necesitas %d, tienes %d", m.need, m.have)
                  .. (m.price and (" | precio por unidad " .. Money(m.price) .. (m.est and " (estimado)" or "")) or ""),
                c1 = "x" .. m.missing,
                c2 = m.cost and (Money(m.cost) .. (m.est and "~" or "")) or (DIM .. "sin precio|r"),
                c3 = "",
                actions = { { "Buscar", function() SearchMaterials({ mats = { { id = m.id, need = m.need, have = m.have } } }) end } },
              }
            end
          end
        end
      end
      ui.list.setRows(out, "Abre la ventana de cada profesion una vez (para que GoldFinder aprenda tus recetas) y escanea la subasta para tener precios.")
    end,

    cuero = function()
      ui.list.setHeaders("Cuero / piel", "Subasta", "Pila de 20", "Consejo")
      local out = {}
      for _, r in ipairs(LeatherRows()) do
        local name = ItemLink(r.id)
        if r.owned > 0 then name = name .. "  " .. DIM .. "(tienes " .. r.owned .. ")|r" end
        local lines = {}
        lines[#lines + 1] = r.farm or "Aun no lo has desollado: GoldFinder anota donde lo consigues."
        if r.region then lines[#lines + 1] = "Precio medio en la region (TSM): " .. Money(r.region) end
        out[#out + 1] = {
          id = r.id, name = name,
          reason = #lines > 0 and table.concat(lines, "\n") or nil,
          c1 = ShortMoney(r.price), c2 = ShortMoney(r.stack), c3 = r.advice,
        }
      end
      ui.list.setRows(out, "No encontre cueros. Escanea la subasta primero.")
    end,

    sesion = function()
      ui.list.setHeaders("Zona / objeto", "Cant.", "Tiempo", "Valor")
      local s = Sess()
      if s.count == 0 then
        ui.list.setRows({}, "Aun no hay cuero registrado. Desuella algo y vuelve aqui.")
        return
      end
      local out = {}
      local function rate(value, secs)
        return secs >= 60 and (" " .. DIM .. "(" .. Money(value / (secs / 3600)) .. "/h)|r") or ""
      end
      out[#out + 1] = {
        name = "|cffffd100TOTAL|r", c1 = s.count .. " u.", c2 = floor(s.secs / 60) .. " min",
        c3 = Money(s.total) .. rate(s.total, s.secs),
      }
      local zs = {}
      for name, z in pairs(s.zones) do zs[#zs + 1] = { name = name, z = z } end
      table.sort(zs, function(a, b) return a.z.value > b.z.value end)
      for _, e in ipairs(zs) do
        out[#out + 1] = {
          name = "  " .. e.name, c1 = e.z.count .. " u.", c2 = floor(e.z.secs / 60) .. " min",
          c3 = Money(e.z.value) .. rate(e.z.value, e.z.secs),
        }
      end
      local its = {}
      for id, it in pairs(s.items) do its[#its + 1] = { id = id, it = it } end
      table.sort(its, function(a, b) return a.it.value > b.it.value end)
      for _, e in ipairs(its) do
        out[#out + 1] = { id = e.id, c1 = "x" .. e.it.count, c2 = "", c3 = Money(e.it.value) }
      end
      ui.list.setRows(out, "")
    end,

    ajustes = function() if ui.settings and ui.settings.refresh then ui.settings.refresh() end end,
  }

  ui.current = auction and "bolsas" or (opts and opts.only and opts.only[1]) or "resumen"
  function ui.open(key, retry)
    if auction then
      if not ahAllowed(key) then key = (ui.ahKeys and ui.ahKeys[1]) or "bolsas" end
    elseif (key == "compras" and not Cfg("shopping")) or (key == "fabricar" and not Cfg("craftTab"))
        or (key == "ruta" and not Cfg("routeTab")) then key = "resumen" end
    if opts and opts.only then
      local allowed = false
      for _, k in ipairs(opts.only) do if k == key then allowed = true end end
      if not allowed then key = opts.only[1] end
    end
    ui.current = key
    for k, b in pairs(ui.nav) do
      local on = (k == key)
      if b.gfTab then
        local fn = on and PanelTemplates_SelectTab or PanelTemplates_DeselectTab
        if fn then pcall(fn, b) end
      elseif on then b:LockHighlight() else b:UnlockHighlight() end
    end
    ui.summary:Hide(); ui.list:Hide()
    if ui.settings then ui.settings:Hide() end
    if key == "resumen" then ui.summary:Show()
    elseif key == "ajustes" then if ui.settings then ui.settings:Show() end
    else ui.list:Show() end
    if key == "sesion" then bReset:Show() else bReset:Hide() end
    if key == "bolsas" then bExport:Show() else bExport:Hide() end
    nameMissing = false
    local ok, err = pcall(ui.loaders[key])
    if not ok then Print("Error en la pantalla " .. key .. ": " .. tostring(err)) end
    -- si algun nombre aun no estaba cargado, se vuelve a dibujar una sola vez
    if nameMissing and (retry or 0) < 4 then
      C_Timer.After(1.5, function()
        if ui.current == key and ui:IsShown() then ui.open(key, (retry or 0) + 1) end
      end)
    end
  end

  function ui.refresh()
    local parts = { ScanAgeText(), TSM_API and "TSM activo" or "TSM no detectado" }
    ui.status:SetText(table.concat(parts, "   |   "))
    -- en la subasta, Compras aparece o desaparece segun lo que falte para el paso actual
    if auction then pcall(ui.layoutNav) end
    ui.open(ui.current)
  end

  ui:SetScript("OnShow", function() ui.refresh() end)
  uiInstances[#uiInstances + 1] = ui
  ui.refresh()
  return ui
end

local function ToggleWindow()
  if not GoldFinderWindow then
    -- marco nativo (retrato, titulo, boton de cerrar e Inset); sin la plantilla, el marco plano de antes
    local w = NewFrame("Frame", "GoldFinderWindow", UIParent, "ButtonFrameTemplate")
    local native = w ~= nil
    w = w or CreateFrame("Frame", "GoldFinderWindow", UIParent)
    w:SetSize(980, 580)
    w:SetPoint("CENTER")
    w:SetFrameStrata("HIGH")
    w:SetMovable(true)
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", w.StartMoving)
    w:SetScript("OnDragStop", w.StopMovingOrSizing)
    w:SetClampedToScreen(true)
    if native then
      w.gfNative = true
      -- sin la barra de botones de abajo: el Inset llega hasta el borde y las pestanas cuelgan debajo
      if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, w) end
      local icon = "Interface\\Icons\\INV_Misc_Coin_01"
      if w.SetPortraitToAsset then
        pcall(w.SetPortraitToAsset, w, icon)
      else
        local p = (w.PortraitContainer and w.PortraitContainer.portrait) or w.portrait or _G["GoldFinderWindowPortrait"]
        if p and p.SetTexture then
          if SetPortraitToTexture then pcall(SetPortraitToTexture, p, icon) else p:SetTexture(icon) end
        end
      end
      if w.SetTitle then
        pcall(w.SetTitle, w, "GoldFinder Forever")
      else
        local t = (w.TitleContainer and w.TitleContainer.TitleText) or w.TitleText or _G["GoldFinderWindowTitleText"]
        if t then t:SetText("GoldFinder Forever") end
      end
    else
      local edge = Flat(w, "BACKGROUND", { 1, 0.82, 0.25, 0.40 })
      edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
      local bg = Flat(w, "BORDER", PAL.bg); bg:SetAllPoints()
      w.gfPadRight = 30
    end
    local ok, err = pcall(CreateUI, w)
    if not ok then
      Print("No pude crear la ventana: " .. tostring(err))
      w:Hide()
      _G["GoldFinderWindow"] = nil   -- para reintentar limpio la proxima vez
      return
    end
    if not (native and (w.CloseButton or _G["GoldFinderWindowCloseButton"])) then
      local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
      close:SetPoint("TOPRIGHT", 2, 2)
      close:SetFrameLevel(w:GetFrameLevel() + 50)
    end
    table.insert(UISpecialFrames, "GoldFinderWindow")
    w:Show()
    return
  end
  if GoldFinderWindow:IsShown() then GoldFinderWindow:Hide() else GoldFinderWindow:Show() end
end

---------------------------------------------------------------------------
-- PESTANA en la casa de subastas (LibAHTab, la misma libreria que Auctionator y TSM)
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- VENTANA DE PROFESIONES: pestanas Ruta y Fabricar al pie de ProfessionsFrame (como las de SkillUp Forever).
-- Todo con hooksecurefunc y HookScript: no se reemplaza ningun manejador de Blizzard ni se llama nada protegido.
---------------------------------------------------------------------------
GF.InitProfTabs({
  Cfg = function(...) return Cfg(...) end,
  Char = function(...) return Char(...) end,
  CreateUI = function(...) return CreateUI(...) end,
  ProfOn = function(...) return ProfOn(...) end,
  RouteFor = function(...) return RouteFor(...) end,
})

GF.InitAuctionTab({
  CreateUI = function(...) return CreateUI(...) end,
  Print = function(...) return Print(...) end,
})

---------------------------------------------------------------------------
-- EVENTOS Y COMANDOS
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- ICONO DEL MINIMAPA: con LibDataBroker + LibDBIcon (los trae TSM) para que
-- se junte con los demas botones; si no estan, un boton propio arrastrable.
---------------------------------------------------------------------------
local minimapReady = false
local function SetupMinimap()
  if minimapReady or not GoldFinderDB then return end
  GoldFinderDB.minimap = GoldFinderDB.minimap or {}
  local ICON = "Interface\\Icons\\INV_Misc_Coin_01"

  local function tip(tt)
    tt:AddLine("GoldFinder Forever", 1, 0.82, 0.25)
    local _, sum = BagRows()
    tt:AddLine("Para vender: " .. Money(sum.sell), 1, 1, 1)
    tt:AddLine(sum.nKeep .. " objeto(s) para guardar", 0.4, 0.7, 1)
    local unsaved = UnsavedUnits()
    if unsaved > 0 then tt:AddLine(unsaved .. " u. de cuero aun no estan en disco (se guardan al salir)", 0.7, 0.7, 0.7) end    tt:AddLine("Clic: abrir o cerrar la ventana", 0.7, 0.7, 0.7)
  end

  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
  if LDB and DBI then
    local obj = LDB:GetDataObjectByName("GoldFinder") or LDB:NewDataObject("GoldFinder", {
      type = "launcher", text = "GoldFinder Forever", icon = ICON,
      OnClick = function() ToggleWindow() end,
      OnTooltipShow = function(tt) pcall(tip, tt) end,
    })
    if obj then
      pcall(DBI.Register, DBI, "GoldFinder", obj, GoldFinderDB.minimap)
      minimapReady = true
      return
    end
  end

  -- boton propio (respaldo)
  local b = CreateFrame("Button", "GoldFinderMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  local tex = b:CreateTexture(nil, "ARTWORK")
  tex:SetTexture(ICON); tex:SetSize(20, 20); tex:SetPoint("CENTER")
  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); ring:SetSize(53, 53); ring:SetPoint("TOPLEFT")
  local function place()
    local a = math.rad(GoldFinderDB.minimap.angle or 215)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
  end
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local x, y = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      GoldFinderDB.minimap.angle = math.deg(math.atan2(y / s - my, x / s - mx))
      place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnClick", function() ToggleWindow() end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    pcall(tip, GameTooltip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  if GoldFinderDB.minimap.hide then b:Hide() end
  place()
  minimapReady = true
end

local function ToggleMinimapIcon()
  GoldFinderDB.minimap = GoldFinderDB.minimap or {}
  GoldFinderDB.minimap.hide = not GoldFinderDB.minimap.hide
  local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
  if DBI and DBI.IsRegistered and DBI:IsRegistered("GoldFinder") then
    if GoldFinderDB.minimap.hide then DBI:Hide("GoldFinder") else DBI:Show("GoldFinder") end
  elseif GoldFinderMinimapButton then
    if GoldFinderDB.minimap.hide then GoldFinderMinimapButton:Hide() else GoldFinderMinimapButton:Show() end
  end
  Print("Icono del minimapa: " .. (GoldFinderDB.minimap.hide and "oculto" or "visible"))
end

---------------------------------------------------------------------------
-- CORREO: al abrir el buzon en un personaje que no es el banquero, un panel junto al correo
-- lista lo que conviene enviarle (cantidad a enviar = lo que sobra tras reservar para profesiones).
-- Boton "Enviar al banquero": un clic rellena destinatario y asunto, adjunta pilas enteras de lo que sobra de la
-- reserva (nunca unidades reservadas) y envia UN correo (max. 12 adjuntos); otro clic envia el siguiente.
---------------------------------------------------------------------------
local Mail = GF.InitMail({
  Cfg = function(...) return Cfg(...) end,
  BagRows = function(...) return BagRows(...) end,
  BankerName = function(...) return BankerName(...) end,
  ToBanker = function(...) return ToBanker(...) end,
  ShortMoney = function(...) return ShortMoney(...) end,
  Money = function(...) return Money(...) end,
  Print = function(...) return Print(...) end,
  ItemLink = function(...) return ItemLink(...) end,
})

---------------------------------------------------------------------------
-- BANCO: al abrirlo, un panel lista lo marcado GUARDAR que conviene DEPOSITAR. Lo que usas en el
-- paso actual de tus profesiones se deja fuera: mejor llevarlo encima para fabricar.
---------------------------------------------------------------------------
local BANK_LINES = 14

local function RefreshBank()
  local f = GoldFinderBank
  if not Cfg("bankPanel") then
    if f then f:Hide() end
    return
  end
  local now = {}
  for _, e in ipairs(NextStepList()) do
    for _, m in ipairs(e.mats or {}) do now[m.id] = true end
  end
  local rows = BagRows()
  local lines, n, carry = {}, 0, 0
  for _, r in ipairs(rows) do
    if r.verdict == "KEEP" and r.count > 0 then
      if now[r.id] then
        carry = carry + 1
      else
        n = n + 1
        if n <= BANK_LINES then
          local why = (r.reason or ""):sub(1, 44)
          lines[#lines + 1] = format("%s  |cffffffffx%d|r  |cffb3b3b3%s|r", ItemLink(r.id), r.count, why)
        end
      end
    end
  end
  if n == 0 then
    if f then f:Hide() end
    return
  end
  if not f then
    -- dialogo clasico (como el panel de venta): titulo "GoldFinder Forever" y debajo el subtitulo
    f = Skin.Panel("GoldFinderBank", BankFrame or UIParent, "dialog")
    f:SetWidth(380)
    f:SetFrameStrata("HIGH")
    f.head = Skin.Head(f, "GoldFinder Forever")
    f.title = Text(f, 12, PAL.text)
    f.title:SetPoint("TOPLEFT", 18, -36)
    f.body = Text(f, 12, PAL.text)
    f.body:SetPoint("TOPLEFT", 18, -56)
    f.body:SetWidth(344)
    f.body:SetSpacing(4)
    f.body:SetJustifyV("TOP")
    f.foot = Text(f, 12, PAL.dim)
    f.foot:SetPoint("BOTTOMLEFT", 18, 16)
    if BankFrame then f:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT", 2, -12)
    else f:SetPoint("LEFT", UIParent, "LEFT", 360, 60) end
  end
  if n > BANK_LINES then lines[#lines + 1] = "|cffb3b3b3... y " .. (n - BANK_LINES) .. " mas|r" end
  f.title:SetText("Conviene depositar en el banco")
  f.body:SetText(table.concat(lines, "\n"))
  f.foot:SetText(carry > 0 and (carry .. " objeto(s) mejor encima: los usas en el paso actual") or (n .. " objeto(s)"))
  f:SetHeight(56 + (f.body:GetStringHeight() or 0) + 36)
  f:Show()
end

local bankEvents = CreateFrame("Frame")
for _, ev in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
  "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "BAG_UPDATE_DELAYED" }) do
  pcall(bankEvents.RegisterEvent, bankEvents, ev)
end
local function IsBankType(t)
  return Enum and Enum.PlayerInteractionType and t == Enum.PlayerInteractionType.Banker
end
bankEvents:SetScript("OnEvent", function(_, event, arg1)
  if event == "BANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and IsBankType(arg1)) then
    C_Timer.After(0.3, function() pcall(RefreshBank) end)
  elseif event == "BANKFRAME_CLOSED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and IsBankType(arg1)) then
    if GoldFinderBank then GoldFinderBank:Hide() end
  elseif event == "BAG_UPDATE_DELAYED" then
    InvalidateRoutes()
    if GoldFinderBank and GoldFinderBank:IsShown() then pcall(RefreshBank) end
  end
end)

---------------------------------------------------------------------------
-- PANEL DE VENTA: al abrir un vendedor, junto a su ventana, la lista de lo que GoldFinder te recomienda
-- venderle (la misma decision que la pestana Bolsas), cada objeto con su boton Vender. Nada se vende sin clic.
---------------------------------------------------------------------------
local Vendor = GF.InitVendor({
  Cfg = function(...) return Cfg(...) end,
  BagRows = function(...) return BagRows(...) end,
  SellQty = function(...) return SellQty(...) end,
  Char = function(...) return Char(...) end,
  ShortMoney = function(...) return ShortMoney(...) end,
  Money = function(...) return Money(...) end,
  Print = function(...) return Print(...) end,
  RecipeForOthers = function(...) return RecipeForOthers(...) end,
  RecordVendorPrices = function(...) return RecordVendorPrices(...) end,
  InvalidateRoutes = function(...) return InvalidateRoutes(...) end,
})

-- RECETAS DEL INSTRUCTOR: las tablas del juego no dicen que habilidad pide cada receta ni quien la ensena, asi que
-- se anotan al abrir la ventana de un instructor de profesion: receta, habilidad requerida, precio, instructor y
-- donde esta. Se guardan por faccion y profesion en GoldFinderDB.trainerRecipes[faccion][profesion][receta].
-- Se muestran un momento todas las categorias (disponibles, no disponibles y aprendidas) y se restaura el filtro.
local RecordTrainer
do
  -- PROFESION DEL INSTRUCTOR
  -- Los rangos se anuncian con el sustantivo del oficio ("Journeyman Tailor"), pero las listas se leen por el
  -- nombre de la profesion ("Tailoring"): manda la linea de habilidad del juego y, si no la hay, esta tabla.
  local PROF_NOUN = {
    tailor = "Tailoring", leatherworker = "Leatherworking", blacksmith = "Blacksmithing", alchemist = "Alchemy",
    engineer = "Engineering", enchanter = "Enchanting", cook = "Cooking", herbalist = "Herbalism", miner = "Mining",
    skinner = "Skinning", fisherman = "Fishing", ["first aid"] = "First Aid",
  }
  -- pn: texto tras el rango; ...: lineas de habilidad candidatas en orden de preferencia (nil o "" se saltan)
  local function TrainerProf(pn, ...)
    for i = 1, select("#", ...) do
      local v = select(i, ...)
      if type(v) == "string" and v ~= "" then return v end
    end
    if type(pn) ~= "string" then return nil end
    local t = pn:gsub("^%s+", ""):gsub("%s+$", "")
    return PROF_NOUN[t:lower()] or t
  end
  -- FIN DE PROFESION DEL INSTRUCTOR

  local function Scan()
    local npc = UnitName("npc")
    local zone = GetRealZoneText and GetRealZoneText() or nil
    local x, y
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if pos then
      local px, py = pos:GetXY()
      x, y = format("%.1f", px * 100), format("%.1f", py * 100)
    end
    local faction = UnitFactionGroup("player") or "?"
    GoldFinderDB.trainerRecipes = GoldFinderDB.trainerRecipes or {}
    local byFaction = GoldFinderDB.trainerRecipes[faction] or {}
    GoldFinderDB.trainerRecipes[faction] = byFaction
    GoldFinderDB.trainers = GoldFinderDB.trainers or {}
    local ranksOf = GoldFinderDB.trainers[faction] or {}
    GoldFinderDB.trainers[faction] = ranksOf
    local n = GetNumTrainerServices() or 0
    -- profesion de la ventana: la que piden la mayoria de sus recetas
    local votes, windowSkill, best = {}, nil, 0
    for i = 1, n do
      local name, _, category = GetTrainerServiceInfo(i)
      local skill = GetTrainerServiceSkillReq(i)
      if name and category ~= "header" and type(skill) == "string" and skill ~= "" and name ~= skill then
        votes[skill] = (votes[skill] or 0) + 1
        if votes[skill] > best then windowSkill, best = skill, votes[skill] end
      end
    end
    local count = 0
    for i = 1, n do
      local name, sub, category = GetTrainerServiceInfo(i)
      local skill, req = GetTrainerServiceSkillReq(i)
      -- Rango de la profesion ("Leatherworking" + "Journeyman", o "Journeyman Tailor"): este instructor lo ensena.
      local rprof, rmax = nil, name and sub and RANK_MAX[sub]
      if rmax then
        rprof = name
      elseif name then
        local r, pn = name:match("^(%a+) (.+)$")
        if r and RANK_MAX[r] then rprof, rmax = pn, RANK_MAX[r] end
      end
      if rprof and category ~= "header" then
        local line = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i)
        rprof = TrainerProf(rprof, line, skill ~= name and skill or nil, windowSkill)
        local t = ranksOf[rprof] or {}
        ranksOf[rprof] = t
        t[rmax] = { npc = npc, zone = zone, x = x, y = y, seen = time() }
      elseif name and category ~= "header" and skill and req and name ~= skill then
        local t = byFaction[skill] or {}
        byFaction[skill] = t
        t[name:lower()] = {
          n = name, req = req, cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or nil,
          npc = npc, zone = zone, x = x, y = y, seen = time(),
        }
        count = count + 1
      end
    end
    return count
  end

  function RecordTrainer()
    if not (GoldFinderDB and GetNumTrainerServices and IsTradeskillTrainer and IsTradeskillTrainer()) then return end
    local filters, shown = { "available", "unavailable", "used" }, {}
    local canFilter = GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter
    -- en Forever el filtro pide true/false (con 1/0 da "Missing on/off parameter"); se prueba con booleano y,
    -- si el cliente lo rechaza, con numero. Protegido: un fallo aqui no deja los filtros a medias sin restaurar.
    local function SetFilter(k, on)
      if not pcall(SetTrainerServiceTypeFilter, k, on) then pcall(SetTrainerServiceTypeFilter, k, on and 1 or 0) end
    end
    if canFilter then
      for _, k in ipairs(filters) do
        local okGet, cur = pcall(GetTrainerServiceTypeFilter, k)
        shown[k] = okGet and cur and true or false
        if not shown[k] then SetFilter(k, true) end
      end
    end
    -- seccion protegida: los filtros del instructor se restauran siempre, aunque la lectura falle
    local ok, res = pcall(Scan)
    if canFilter then
      for _, k in ipairs(filters) do
        if not shown[k] then SetFilter(k, false) end
      end
    end
    if not ok then error(res, 0) end
    return res
  end
end

local trainerEvents = CreateFrame("Frame")
pcall(trainerEvents.RegisterEvent, trainerEvents, "TRAINER_SHOW")
trainerEvents:SetScript("OnEvent", function()
  C_Timer.After(0.2, function() xpcall(RecordTrainer, geterrorhandler()); InvalidateRoutes() end)
end)

---------------------------------------------------------------------------
-- OPCIONES en Opciones > AddOns > GoldFinder, con la API nativa Settings (casillas, secciones, Predeterminados
-- y busqueda del juego). Cada fila entra por Settings.RegisterInitializer, que la inserta desde el codigo seguro
-- de Blizzard: asi la busqueda de opciones no se contamina con el codigo del addon. Sin la API (u otro cliente)
-- no se registra nada y la pestana Ajustes de /gf sigue mostrando su pagina propia (MakeSettings).
---------------------------------------------------------------------------
local optionsCategory

local function RegisterOptions()
  local S = Settings
  if optionsCategory or type(S) ~= "table" or type(S.VarType) ~= "table" then return end
  for _, fn in ipairs({ "RegisterVerticalLayoutCategory", "RegisterAddOnCategory", "RegisterAddOnSetting",
      "RegisterProxySetting", "RegisterInitializer", "CreateCheckboxInitializer", "CreateSliderOptions",
      "CreateSliderInitializer" }) do
    if type(S[fn]) ~= "function" then return end
  end
  local BOOL, NUM = S.VarType.Boolean, S.VarType.Number
  local cat = S.RegisterVerticalLayoutCategory("GoldFinder Forever")

  local function refreshAll() for _, u in ipairs(uiInstances) do pcall(u.refresh) end end
  local function refreshShown() for _, u in ipairs(uiInstances) do if u:IsVisible() then pcall(u.refresh) end end end
  local function tracker() xpcall(UpdateTracker, geterrorhandler()) end

  -- los mismos efectos que tenia la pagina de Ajustes (y los comandos /gf ruta y /gf tope)
  local function applied(key)
    if key == "nextSteps" or key == "gamePlan" or key == "trackerMode" then tracker() end
    if key == "recipeNotes" and Skin.RecipeNotes then pcall(Skin.RecipeNotes.refresh) end
    if key == "shopping" or key == "craftTab" or key == "routeTab" or key == "profTabs" then
      if Skin.ProfTabs then pcall(Skin.ProfTabs.later) end
      for _, u in ipairs(uiInstances) do
        pcall(u.layoutNav)
        if (not Cfg("shopping") and u.current == "compras") or (not Cfg("craftTab") and u.current == "fabricar")
            or (not Cfg("routeTab") and u.current == "ruta") then
          pcall(u.open, "resumen")
        end
      end
    end
    if key == "sellPanel" or key == "vendorBox" then pcall(Vendor.RefreshSellPanel); pcall(Vendor.RefreshVendor) end
    if key == "routeSpan" or key == "sellCap" then
      InvalidateRoutes()
      tracker()
      refreshAll()
    else
      refreshShown()
    end
  end

  local function header(name, tip)
    local make = CreateSettingsListSectionHeaderInitializer
    if type(make) ~= "function" then return end
    if type(CreateSecureDelegate) == "function" then make = CreateSecureDelegate(make) end
    local init = make(name, tip)
    if type(init) == "table" then S.RegisterInitializer(cat, init) end
  end

  local function check(key, label, tip)
    local setting = S.RegisterAddOnSetting(cat, "GoldFinder_" .. key, key, GoldFinderDB, BOOL, label, DEFAULTS[key])
    setting:SetValueChangedCallback(function() applied(key) end)
    S.RegisterInitializer(cat, S.CreateCheckboxInitializer(setting, nil, tip))
  end

  local function slider(setting, lo, hi, step, fmt, tip)
    local o = S.CreateSliderOptions(lo, hi, step)
    local mixin = MinimalSliderWithSteppersMixin
    if fmt and o.SetLabelFormatter and mixin and mixin.Label then o:SetLabelFormatter(mixin.Label.Right, fmt) end
    S.RegisterInitializer(cat, S.CreateSliderInitializer(setting, o, tip))
    return o
  end

  -- numeros enteros guardados tal cual en GoldFinderDB (mismos nombres que usan Cfg y los comandos)
  local function number(key, label, lo, hi, step, tip)
    local setting = S.RegisterAddOnSetting(cat, "GoldFinder_" .. key, key, GoldFinderDB, NUM, label, DEFAULTS[key])
    setting:SetValueChangedCallback(function()
      local v = tonumber(GoldFinderDB[key])
      if v and v ~= floor(v) then GoldFinderDB[key] = floor(v + 0.5) end
      applied(key)
    end)
    slider(setting, lo, hi, step, function(v) return tostring(floor(v + 0.5)) end, tip)
  end

  header("Consejos y tooltips")
  check("tip", "Consejo en los tooltips", "Consejo vender / subastar / guardar en los tooltips de los objetos.")
  check("track", "Registrar el cuero que recoges", "Registrar el cuero que recoges (pestana Sesion).")
  check("crossChars", "Materiales de mis otros personajes",
    "Avisar de materiales que sirven a las profesiones de mis otros personajes.")
  check("questItems", "Proteger objetos de mision",
    "Nunca recomendar vender, subastar, enviar al banquero ni dar al vendedor lo que piden tus misiones activas (con QuestieDB, tambien la siguiente mision de la cadena).")
  check("useSkillUp", "Usar la ruta de SkillUp Forever",
    "Usar la ruta de SkillUp Forever (si lo tienes) para decidir que materiales guardar.")
  number("reserve", "Fabricaciones a reservar", 0, 200, 1,
    "Fabricaciones a reservar de cada material (para subir tu profesion).")

  header("Ventanas y paneles")
  check("nextSteps", "Ventana del siguiente paso", "Siguiente paso de las guias de profesion (en el seguimiento de objetivos o en una ventana flotante, segun la opcion de abajo).")
  -- donde va el siguiente paso: deslizador con pasos (el desplegable nativo falla en el cliente Forever)
  local MODES = { "objetivos", "flotante" }
  local mode = S.RegisterProxySetting(cat, "GoldFinder_trackerMode", NUM, "Donde se muestra el siguiente paso", 1,
    function() return Cfg("trackerMode") == "flotante" and 2 or 1 end,
    function(i)
      GoldFinderDB.trackerMode = MODES[floor((tonumber(i) or 1) + 0.5)] or "objetivos"
      applied("trackerMode")
    end)
  slider(mode, 1, 2, 1, function(i)
    return floor(i + 0.5) == 2 and "Ventana flotante" or "Seguimiento de objetivos"
  end, "Seguimiento de objetivos: un bloque GoldFinder Forever en el seguimiento de la derecha (junto al de SkillUp Forever si lo tienes). Ventana flotante: el panel movible de siempre.")
  check("gamePlan", "Siguiente paso segun la subasta",
    "Siguiente paso segun mis recetas y los precios de la subasta (en vez de la guia).")
  check("readyAlert", "Aviso al reunir los materiales", "Avisar (chat y sonido) cuando reuna los materiales de un paso.")
  check("shopping", "Pestana Compras", "Pestana Compras: materiales que me faltan para el paso actual, con precios.")
  check("mailPanel", "Panel junto al correo",
    "Panel junto al correo con lo que conviene enviar al banquero (si no usas el correo de TSM).")
  check("bankPanel", "Panel junto al banco", "Panel junto al banco con lo que conviene depositar (y lo que mejor llevas encima).")
  check("vendorBox", "Recetas junto al vendedor",
    "Cuadrito junto al vendedor con las recetas que te sirven (el tooltip siempre las indica).")
  check("sellPanel", "Panel de venta junto al vendedor",
    "Al abrir un vendedor, panel junto a su ventana con los objetos que conviene venderle, cada uno con su boton Vender. Nada se vende sin clic.")

  header("Profesiones y ruta",
    "GoldFinder lee tus profesiones y tu habilidad al entrar. Las recetas se memorizan al abrir la ventana de cada profesion.")
  check("craftTab", "Pestana Fabricar", "Pestana Fabricar: que compensa fabricar con tus materiales (valor del objeto fabricado).")
  check("routeTab", "Pestana Ruta",
    "Pestana Ruta: planificador de ruta de profesion con tus recetas y los precios de la subasta.")
  check("profTabs", "Pestanas de GoldFinder en la ventana de profesiones",
    "Pestanas Ruta y Fabricar al pie de la ventana de profesiones, con los datos de la profesion abierta (cada una solo si su pestana esta activa).")
  check("recipeNotes", "Notas en la lista de recetas",
    "Junto a cada receta de la ventana de profesiones: probabilidad de subir un punto y coste (-) o ganancia (+) por punto segun la ruta. Con SkillUp Forever mostrando su texto en la fila, van en el tooltip de la receta.")
  number("routeSpan", "Puntos que planifica la ruta", 5, 100, 1,
    "Puntos de habilidad que planifica la pestana Ruta, de 5 a 100 (lo mismo que /gf ruta N).")
  number("sellCap", "Unidades a precio de subasta", 0, 1000, 1,
    "Unidades de cada objeto fabricado que la pestana Ruta valora a precio de subasta; el resto, a precio del vendedor (lo mismo que /gf tope N).")
  -- profesiones de este personaje que cuentan (materiales a guardar, patrones y siguiente paso)
  -- Las que aprendas despues de entrar se anaden con SKILL_LINES_CHANGED (ver Skin.OptionsSync): la API Settings no
  -- deja quitar ni mover filas, asi que una profesion nueva aparece al final de la pagina hasta el proximo /reload.
  local profSeen = {}
  local function addProfs()
    local profs = {}
    for prof in pairs(Char().prof) do if not profSeen[prof] then profs[#profs + 1] = prof end end
    table.sort(profs)
    for _, prof in ipairs(profs) do
      profSeen[prof] = true
      local setting = S.RegisterProxySetting(cat, "GoldFinder_prof_" .. (prof:gsub("[^%w]", "_")), BOOL,
        "Cuenta: " .. prof, true,
        function() return not Char().off[prof] end,
        function(on)
          Char().off[prof] = (not on) or nil
          tracker()
          refreshAll()
        end)
      S.RegisterInitializer(cat, S.CreateCheckboxInitializer(setting, nil,
        "Profesiones que cuentan (materiales a guardar, patrones y siguiente paso). Solo para este personaje."))
    end
  end
  addProfs()

  header("Subasta y banquero")
  local gain = S.RegisterProxySetting(cat, "GoldFinder_minGain", NUM, "Ganancia minima de la subasta",
    floor(DEFAULTS.minGain / 100),
    function() return floor((tonumber(Cfg("minGain")) or 0) / 100 + 0.5) end,
    function(silver)
      GoldFinderDB.minGain = math.max(0, floor((tonumber(silver) or 0) + 0.5)) * 100
      refreshShown()
    end)
  slider(gain, 0, 5000, 5, function(silver) return Money(floor(silver + 0.5) * 100) end,
    "Ganancia minima (oro) para recomendar subasta en vez de vendedor.")
  -- boton Subastar de la lista Bolsas (como una operacion de TSM)
  number("postMinPct", "Subastar: precio minimo (% del mercado)", 0, 100, 5,
    "Por debajo de este % del valor de mercado no se publica: espera. Nunca baja de lo que paga el vendedor.")
  number("postMaxPct", "Subastar: precio maximo (% del mercado)", 100, 500, 10,
    "Si la subasta mas barata pasa de este % del valor de mercado, se publica al precio normal (el de mercado).")
  number("postUndercut", "Subastar: rebaja (cobre)", 0, 500, 1,
    "Cobre por debajo de la subasta mas barata.")
  number("postCapDays", "Subastar: tope (dias de ventas)", 1, 14, 1,
    "Como mucho se publican las unidades que se venden en la region en estos dias (si TSM lo sabe).")
  number("postDuration", "Subastar: duracion (horas)", 12, 24, 12, "Duracion de la subasta: 12 o 24 horas.")
  -- banquero: se elige entre los personajes con los que ya has entrado; un deslizador con pasos en vez de un
  -- desplegable, porque el desplegable nativo falla en el cliente Forever (lo mismo hace SkillUp Forever)
  -- La lista se rehace (misma tabla) al abrir el panel de opciones: recoge fichas nuevas y nombres ya completos.
  local names, seen, bankerOpts = {}, {}, nil
  local function addName(n)
    if n and n ~= "" and not seen[n:lower()] then seen[n:lower()] = true; names[#names + 1] = n end
  end
  local function buildNames()
    for i = #names, 1, -1 do names[i] = nil end
    for k in pairs(seen) do seen[k] = nil end
    for key in pairs(GoldFinderDB.chars or {}) do addName(ResolveFullName(key:match("^([^-]+)") or key)) end
    addName(BankerName())
    table.sort(names)
    table.insert(names, 1, "")   -- "" = ninguno
    if bankerOpts then bankerOpts.maxValue = math.max(2, #names) end
  end
  buildNames()
  local function bankerIndex()
    local cur = BankerName()
    if not cur then return 1 end
    for i, name in ipairs(names) do
      if name ~= "" and (name:lower() == cur:lower()
          or (not cur:find(" ", 1, true) and FirstName(name):lower() == cur:lower())) then
        return i
      end
    end
    return 1
  end
  local banker = S.RegisterProxySetting(cat, "GoldFinder_banker", NUM, "Personaje banquero", 1, bankerIndex,
    function(i)
      GoldFinderDB.banker = ResolveFullName(names[floor((tonumber(i) or 1) + 0.5)] or "") or ""
      refreshAll()
    end)
  bankerOpts = slider(banker, 1, math.max(2, #names), 1, function(i)
    local n = names[floor(i + 0.5)]
    return (n and n ~= "") and n or "(ninguno)"
  end, "Personaje banquero: al que envias lo que hay que subastar. Se elige entre los personajes con los que ya has entrado.")

  S.RegisterAddOnCategory(cat)
  optionsCategory = cat

  -- filas por personaje al dia: profesiones nuevas (fuera de combate) y lista de banqueros
  Skin.OptionsSync = function(onlyNames)
    if not onlyNames and not (InCombatLockdown and InCombatLockdown()) then addProfs() end
    buildNames()
  end
  if type(SettingsPanel) == "table" and SettingsPanel.HookScript then
    SettingsPanel:HookScript("OnShow", function() pcall(Skin.OptionsSync, true) end)
  end
end

-- fallback (opcional): se llama si un frame despues el panel de opciones no se ve (el abridor no hizo nada)
OpenOptions = function(fallback)
  if not optionsCategory then return false end
  if InCombatLockdown and InCombatLockdown() then
    Print("Las opciones del juego se abren fuera de combate.")
    return false
  end
  local id = optionsCategory.GetID and optionsCategory:GetID()
  -- el abridor del cliente, llamado de forma segura (como SkillUp Forever); si no esta, el de la API Settings
  local open = C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel
  local called = false
  if type(open) == "function" and type(securecallfunction) == "function" then
    called = pcall(securecallfunction, open, id)
  end
  if not called and Settings and type(Settings.OpenToCategory) == "function" then
    called = pcall(Settings.OpenToCategory, id)
  end
  if not called then return false end
  C_Timer.After(0, function()
    local sp = rawget(_G, "SettingsPanel")
    if not (type(sp) == "table" and sp.IsShown and sp:IsShown()) and fallback then
      xpcall(fallback, geterrorhandler())
    end
  end)
  return true
end

-- Cambia una opcion por la API Settings (asi la pagina de opciones y sus efectos quedan al dia) o, sin ella,
-- directamente en GoldFinderDB.
local function SetOption(key, value)
  if optionsCategory and Settings.SetValue and pcall(Settings.SetValue, "GoldFinder_" .. key, value)
      and GoldFinderDB[key] == value then
    return
  end
  GoldFinderDB[key] = value
  for _, u in ipairs(uiInstances) do pcall(u.refresh) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "BAG_UPDATE_DELAYED", "LOOT_OPENED", "ZONE_CHANGED_NEW_AREA", "NEW_RECIPE_LEARNED", "MAIL_SHOW" }) do
  pcall(f.RegisterEvent, f, ev)
end
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "GoldFinder" then
    GoldFinderDB = GoldFinderDB or {}
    GoldFinderDB.chars = GoldFinderDB.chars or {}
    -- datos de versiones anteriores (comunes a la cuenta): pasan a la ficha de su personaje al entrar
    if GoldFinderDB.prof or GoldFinderDB.keep or GoldFinderDB.session then
      GoldFinderDB.legacy = GoldFinderDB.legacy or
        { prof = GoldFinderDB.prof, keep = GoldFinderDB.keep, session = GoldFinderDB.session }
      GoldFinderDB.prof, GoldFinderDB.keep, GoldFinderDB.session = nil, nil, nil
    end
    -- limpieza de datos de versiones anteriores
    GoldFinderDB.log, GoldFinderDB.items, GoldFinderDB.lastScan = nil, nil, nil
  elseif event == "PLAYER_LOGIN" then
    pcall(MarkSessionBaseline)
    C_Timer.After(1, function() pcall(CleanPhantomChars) end)
    C_Timer.After(2, function()
      pcall(ReadSkills); xpcall(UpdateTracker, geterrorhandler())
      -- despues de leer las profesiones y ordenar las fichas: la pagina lista profesiones y personajes
      local okO, errO = pcall(RegisterOptions)
      if not okO then Print("No pude registrar las opciones en Opciones > AddOns: " .. tostring(errO)) end
    end)
    -- la API de SkillUp puede tardar en estar lista tras entrar: se lee varias veces durante el primer minuto
    for _, d in ipairs({ 8, 20, 40, 65 }) do
      C_Timer.After(d, function() suCache.t = -10; pcall(SkillUpData) end)
    end
    C_Timer.NewTicker(4, function()
      if GoldFinderDB and GoldFinderDB.nextSteps then
        pcall(ReadSkills)
        xpcall(function() UpdateTracker(nil, true) end, geterrorhandler())
      end
    end)
    local okMM, errMM = pcall(SetupMinimap)
    if not okMM then Print("No pude crear el icono del minimapa: " .. tostring(errMM)) end
    local v1 = AHApi()
    if v1 and v1.RegisterForDBUpdate then
      v1.RegisterForDBUpdate(CALLER, function()
        InvalidateRoutes()
        for _, u in ipairs(uiInstances) do pcall(u.refresh) end
        xpcall(UpdateTracker, geterrorhandler())
      end)
    end
  elseif event == "MAIL_SHOW" then
    C_Timer.After(0.2, function() pcall(Mail.Refresh) end)
  elseif event == "BAG_UPDATE_DELAYED" then
    InvalidateRoutes()
    pcall(ReadSkills)
    pcall(SkillUpData)
    xpcall(UpdateTracker, geterrorhandler())
    if GoldFinderMail and GoldFinderMail:IsShown() then pcall(Mail.Refresh) end
    -- la lista visible (ventana o pestana de la subasta) se rehace cuando cambian las bolsas: tras publicar,
    -- vender o recibir correo el objeto desaparece sin pulsar nada (una vez por rafaga de cambios)
    if not Skin.bagRefresh then
      Skin.bagRefresh = true
      C_Timer.After(0.3, function()
        Skin.bagRefresh = false
        for _, u in ipairs(uiInstances) do
          if u.IsVisible and u:IsVisible() and u.refresh then pcall(u.refresh) end
        end
      end)
    end
  elseif event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" then
    -- el juego a veces actualiza la habilidad un instante despues del aviso: se lee varias veces
    for _, d in ipairs({ 0, 0.5, 2 }) do
      C_Timer.After(d, function() pcall(ReadSkills); xpcall(UpdateTracker, geterrorhandler()) end)
    end
    -- profesion nueva u olvidada: sus filas de Opciones (despues de releer las profesiones)
    if event == "SKILL_LINES_CHANGED" then
      C_Timer.After(2.5, function() if Skin.OptionsSync then pcall(Skin.OptionsSync) end end)
    end
  elseif event == "LOOT_OPENED" then
    pcall(RecordSources)
  elseif event == "NEW_RECIPE_LEARNED" then
    -- recien aprendida en el entrenador: se apunta en su profesion (y en sus recetas, para la ruta) sin esperar a
    -- abrir la ventana de la profesion
    local ok, info = pcall(function() return C_TradeSkillUI.GetRecipeInfo(arg1) end)
    if ok and info and info.name then
      xpcall(function() Skin.Route.LearnRecipe(Char(), arg1, info.name, UnitFactionGroup("player") or "?") end,
        geterrorhandler())
    end
    InvalidateRoutes()
    ScheduleCache()
    xpcall(UpdateTracker, geterrorhandler())
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    xpcall(UpdateTracker, geterrorhandler())
  elseif event:find("^TRADE_SKILL") then
    ScheduleCache()
  end
end)

SLASH_GOLDFINDER1 = "/gf"
SlashCmdList["GOLDFINDER"] = function(msg)
  if not GoldFinderDB then return end
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    ToggleWindow()
  elseif cmd == "ruta" or cmd == "route" then
    local n = tonumber(rest)
    if n and n >= 5 and n <= 100 then
      SetOption("routeSpan", math.floor(n))
      Print("La ruta planifica " .. GoldFinderDB.routeSpan .. " puntos de habilidad.")
    else
      Print("Uso: /gf ruta 25 (puntos de habilidad que planifica la pestana Ruta, de 5 a 100)")
    end
  elseif cmd == "tope" or cmd == "cap" then
    local n = tonumber(rest)
    if n and n >= 0 and n <= 1000 then
      SetOption("sellCap", math.floor(n))
      Print("La ruta valora a precio de subasta las primeras " .. GoldFinderDB.sellCap .. " unidades de cada objeto fabricado; el resto, a precio del vendedor.")
    else
      Print("Uso: /gf tope 5 (unidades de cada objeto fabricado que la pestana Ruta valora a precio de subasta, de 0 a 1000)")
    end
  elseif cmd == "ajustes" or cmd == "config" or cmd == "opciones" then
    -- sin la pagina de Opciones (o en combate, o no se abrio): la pestana Ajustes de la ventana
    local function inWindow()
      if not (GoldFinderWindow and GoldFinderWindow:IsShown()) then ToggleWindow() end
      for _, u in ipairs(uiInstances) do
        if GoldFinderWindow and u:GetParent() == GoldFinderWindow then pcall(u.open, "ajustes") end
      end
    end
    if not OpenOptions(inWindow) then inWindow() end
  elseif cmd == "guia" or cmd == "guide" then
    OpenGuide(rest)
  elseif cmd == "icono" or cmd == "minimap" then
    ToggleMinimapIcon()
  elseif cmd == "session" or cmd == "sesion" then
    if rest:lower() == "reset" then
      Char().session = nil
      Sess()
      MarkSessionBaseline()
      Print("Sesion reiniciada.")
    else
      ToggleWindow()
    end
  else
    Print("Comandos: /gf (abre la ventana) | /gf ajustes (opciones en Opciones > AddOns) | /gf guia [profesion] (guia completa) | /gf ruta N (puntos que planifica la pestana Ruta, 5-100) | /gf tope N (unidades valoradas a precio de subasta en la Ruta) | /gf icono (muestra u oculta el icono del minimapa) | /gf session reset")
  end
end
