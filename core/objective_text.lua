-- core/objective_text.lua: the texts of the objective tracker block and of the recipe list notes. Pure: a step entry or a
-- skill-up chance comes in, lines of text come out.

local _, GF = ...

local DOT = " \194\183 "
local MAX_MATS = 5
local function ObjectiveHeader(e)
  if e.game then return string.format("%s %d: %s", e.prof, e.rank or 0, tostring(e.recipe)) end
  if e.trainOnly then return string.format("%s %d: entrena el siguiente rango", e.prof, e.rank or 0) end
  if e.gather then return string.format("%s %d > %d: %s", e.prof, e.rank or 0, e.upto or 0, tostring(e.zone)) end
  return string.format("%s %d > %d: %s x%d", e.prof, e.rank or 0, e.upto or 0, tostring(e.what), e.qty or 0)
end
-- Bloque del seguimiento para una entrada de NextStepList: { id, header, lines = { { key, kind, text } } }.
-- kind: learn (receta del instructor), train (rango del instructor), mat (material que falta), more, ready.
-- nameOf(id) da el nombre del objeto o nil (aun sin cargar: el segundo resultado avisa de que hay que esperar).
local function ObjectiveBlock(e, nameOf, learnText)
  local lines, waiting = {}, false
  if e.unknown then
    lines[#lines + 1] = { key = "learn", kind = "learn",
      text = "Aprende: " .. ((learnText and learnText(e)) or "aprendela antes de fabricarla") }
  end
  local t, st = e.train, e.trainState
  if t and (st == "ready" or st == "cap" or st == "capblocked") then
    local text = "Entrena " .. tostring(t.name) .. (t.npc and (" con " .. t.npc) or "")
      .. (t.zone and (" (" .. t.zone .. ")") or "")
    if st == "capblocked" then text = text .. " cuando cumplas los requisitos" end
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
      if not nm then waiting = true; nm = "objeto " .. tostring(m.id) end
      lines[#lines + 1] = { key = "m" .. tostring(m.id), kind = "mat", text = string.format("%d/%d %s", have, m.need, nm) }
    end
  end
  if not missing and #mats > 0 then
    lines[#lines + 1] = { key = "ready", kind = "ready", text = "Materiales listos" }
  end
  return { id = e.prof, header = ObjectiveHeader(e), lines = lines }, waiting
end
local function Pct(chance) return tostring(math.floor(chance * 100 + 0.5)) .. "%" end
-- Nota de la fila de una receta: "100% · -2s" (coste por punto) o "100% · +2s" (ganancia por punto).
local function RecipeNoteText(chance, eff, money)
  if not chance then return nil end
  local out = Pct(chance)
  if eff == nil then return out end
  if eff == false then return out .. DOT .. "sin precio" end
  if eff >= 0.5 then return out .. DOT .. "|cffff8080-" .. money(math.floor(eff + 0.5)) .. "|r" end
  if eff <= -0.5 then return out .. DOT .. "|cff80ff80+" .. money(math.floor(-eff + 0.5)) .. "|r" end
  return out .. DOT .. "0"
end
-- Las mismas cifras para el tooltip de la fila (cuando SkillUp ya escribe su texto en la fila).
local function RecipeNoteLines(chance, eff, money)
  if not chance then return {} end
  local lines = { "GoldFinder Forever: " .. Pct(chance) .. " de subir un punto" }
  if eff == false then
    lines[2] = "Coste por punto: sin precio (escanea la subasta)"
  elseif eff ~= nil then
    if eff <= -0.5 then lines[2] = "Ganancia por punto: " .. money(math.floor(-eff + 0.5))
    else lines[2] = "Coste por punto: " .. money(math.max(0, math.floor(eff + 0.5))) end
  end
  return lines
end

GF.ObjectiveBlock, GF.RecipeNoteText, GF.RecipeNoteLines = ObjectiveBlock, RecipeNoteText, RecipeNoteLines
