-- core/objective_text.lua: the texts of the objective tracker block and of the recipe list notes. Pure: a step entry or a
-- skill-up chance comes in, lines of text come out.

local _, GF = ...

local L = GF.L

local DOT = " \194\183 "
local MAX_MATS = 5
local function ObjectiveHeader(e)
  if e.game then return string.format("%s %d: %s", e.prof, e.rank or 0, tostring(e.recipe)) end
  if e.trainOnly then return string.format(L["obj.trainNext"], e.prof, e.rank or 0) end
  if e.gather then return string.format("%s %d > %d: %s", e.prof, e.rank or 0, e.upto or 0, tostring(e.zone)) end
  return string.format("%s %d > %d: %s x%d", e.prof, e.rank or 0, e.upto or 0, tostring(e.what), e.qty or 0)
end
-- Bloque del seguimiento para una entrada de NextStepList: { id, header, lines = { { key, kind, text } } }.
-- kind: learn (receta del instructor), train (rango del instructor), mat (material que falta, con su icono si iconOf
-- lo da), more, ready, info (coste de lo que falta, probabilidad de subir), note (la guia propone otra receta).
-- nameOf(id) da el nombre del objeto o nil (aun sin cargar: el segundo resultado avisa de que hay que esperar).
local function ObjectiveBlock(e, nameOf, learnText, iconOf, money)
  local lines, waiting = {}, false
  if e.unknown then
    lines[#lines + 1] = { key = "learn", kind = "learn",
      text = string.format(L["obj.learn"], (learnText and learnText(e)) or L["obj.learnFirst"]) }
  end
  local t, st = e.train, e.trainState
  if t and (st == "ready" or st == "cap" or st == "capblocked") then
    local text = string.format(L["obj.train"], tostring(t.name)) .. (t.npc and string.format(L["obj.with"], t.npc) or "")
      .. (t.zone and (" (" .. t.zone .. ")") or "")
    if st == "capblocked" then text = text .. L["obj.capblocked"] end
    lines[#lines + 1] = { key = "train", kind = "train", text = text }
  end
  local mats = e.mats or {}
  local shown, missing = 0, false
  for _, m in ipairs(mats) do
    local have = m.have or 0
    if have < (m.need or 0) then
      missing = true
      if shown == MAX_MATS then
        lines[#lines + 1] = { key = "more", kind = "more", text = "..." }
        break
      end
      shown = shown + 1
      local nm = nameOf and nameOf(m.id)
      if not nm then waiting = true; nm = string.format(L["obj.item"], m.id) end
      local icon = iconOf and iconOf(m.id)
      local text = string.format("%d/%d %s", have, m.need, nm)
      if icon then text = string.format("|T%s:14|t %s", tostring(icon), text) end
      lines[#lines + 1] = { key = "m" .. tostring(m.id), kind = "mat", text = text }
    end
  end
  if not missing and #mats > 0 then
    lines[#lines + 1] = { key = "ready", kind = "ready", text = L["obj.ready"] }
  end
  -- datos utiles del paso: cuanto cuesta lo que falta y que probabilidad tiene cada fabricacion de subirte
  if missing and e.missingCost and e.missingCost > 0 and money then
    lines[#lines + 1] = { key = "cost", kind = "info", text = string.format(L["obj.missingCost"], money(e.missingCost)) }
  end
  if e.chance and e.chance < 0.995 and e.chance > 0 then
    lines[#lines + 1] = { key = "chance", kind = "info", text = string.format(L["obj.chance"], math.floor(e.chance * 100 + 0.5)) }
  end
  -- el paso sale del planificador (lo mas barato para ti); si la guia pone otra receta, se dice con palabras simples
  if e.guide then
    lines[#lines + 1] = { key = "guide", kind = "note", text = string.format(L["obj.cheaperThanGuide"], e.guide) }
  end
  return { id = e.prof, header = ObjectiveHeader(e), lines = lines }, waiting
end
local function Pct(chance) return tostring(math.floor(chance * 100 + 0.5)) .. "%" end
-- Cuantas veces se puede fabricar una receta con lo que hay: el minimo de floor(tengo / necesito) entre sus reactivos.
-- reagents = { { itemId, qty }, ... } (el campo r de GoldFinderRecipes); count(itemId) -> unidades. nil si no hay datos
-- (sin reactivos o sin funcion de recuento): no se sabe, no se dice 0. Una entrada rota se ignora; un material que falta da 0.
local function CraftableCount(reagents, count)
  if type(reagents) ~= "table" or type(count) ~= "function" then return nil end
  local best
  for _, m in ipairs(reagents) do
    local id, qty = type(m) == "table" and m[1], type(m) == "table" and m[2]
    if type(id) == "number" and type(qty) == "number" and qty > 0 then
      local ok, have = pcall(count, id)
      have = (ok and type(have) == "number" and have > 0) and have or 0
      local can = math.floor(have / qty)
      best = best and math.min(best, can) or can
    end
  end
  return best
end
-- Nota de la fila de una receta: "100% · -2s" (coste por punto) o "100% · +2s" (ganancia por punto), y al final
-- "(4)" con las que puedes fabricar ahora (solo si hay alguna).
local function RecipeNoteText(chance, eff, money, can)
  if not chance then return nil end
  local out = Pct(chance)
  if eff == nil then
    -- solo la probabilidad
  elseif eff == false then out = out .. DOT .. L["note.noprice"]
  elseif eff >= 0.5 then out = out .. DOT .. "|cffff8080-" .. money(math.floor(eff + 0.5)) .. "|r"
  elseif eff <= -0.5 then out = out .. DOT .. "|cff80ff80+" .. money(math.floor(-eff + 0.5)) .. "|r"
  else out = out .. DOT .. "0" end
  if type(can) == "number" and can > 0 then out = out .. " (" .. can .. ")" end
  return out
end
-- Las mismas cifras para el tooltip de la fila (cuando SkillUp ya escribe su texto en la fila).
local function RecipeNoteLines(chance, eff, money, can)
  if not chance then return {} end
  local lines = { string.format(L["note.chance"], Pct(chance)) }
  if eff == false then
    lines[2] = L["note.nopriceTip"]
  elseif eff ~= nil then
    if eff <= -0.5 then lines[2] = string.format(L["note.gain"], money(math.floor(-eff + 0.5)))
    else lines[2] = string.format(L["note.cost"], money(math.max(0, math.floor(eff + 0.5)))) end
  end
  if type(can) == "number" and can > 0 then lines[#lines + 1] = string.format(L["note.canMake"], can) end
  return lines
end

GF.ObjectiveBlock, GF.RecipeNoteText, GF.RecipeNoteLines = ObjectiveBlock, RecipeNoteText, RecipeNoteLines
GF.CraftableCount = CraftableCount
