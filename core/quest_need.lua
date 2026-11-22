-- core/quest_need.lua: which items your active quests need. Pure: the quest log entries and the QuestieDB
-- accessors arrive as arguments, so it runs (and is tested) without the game.

local _, GF = ...

-- NECESIDAD DE MISIONES
-- Objetos que piden tus misiones activas: nunca se recomienda venderlos, subastarlos, enviarlos ni darselos al
-- vendedor. Del registro de misiones salen los objetivos de objeto (se guarda el total pedido, no lo que falta:
-- al entregar la mision se consumen). Con QuestieDB: los ids de esos objetos, los objetos que pide la mision
-- (requiredSourceItems) y los de la siguiente mision de la cadena (nextQuestInChain, un paso).
-- need[itemID] = { n = unidades, quests = { textos }, titles = { misiones }, chainTitles = { cadena }, chain }
local QUEST_ALL = 100000   -- cantidad desconocida (QuestieDB no la guarda): se reserva todo lo que tengas

local function BuildQuestNeed(entries, api)
  api = api or {}
  local need, active = {}, {}
  for _, e in ipairs(entries or {}) do if e.id then active[e.id] = true end end
  local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil   -- siempre un valor (tonumber() sin argumento falla)
  end
  local function list(t)
    local out = {}
    if type(t) == "table" then
      for _, v in ipairs(t) do
        local id = tonumber(type(v) == "table" and v[1] or v)
        if id and id > 0 then out[#out + 1] = id end
      end
    end
    return out
  end
  local function itemObjectives(qid)
    local o = call(api.objectives, qid)
    return list(type(o) == "table" and o[3] or nil)
  end
  local added
  local function add(id, n, title, chain)
    if not id or added[id] then return end
    added[id] = true
    local x = need[id]
    if not x then x = { n = 0, quests = {}, titles = {}, chainTitles = {}, chain = true }; need[id] = x end
    x.n = math.min(QUEST_ALL, x.n + (n or QUEST_ALL))
    if chain then
      x.chainTitles[#x.chainTitles + 1] = title
      x.quests[#x.quests + 1] = string.format(GF.L["quest.chainNext"], title)
    else
      x.chain = false
      x.titles[#x.titles + 1] = title
      x.quests[#x.quests + 1] = title
    end
  end
  local function lower(s) return type(s) == "string" and s:lower() or nil end
  for _, e in ipairs(entries or {}) do
    added = {}
    local title = e.title or ("#" .. tostring(e.id))
    local items = e.items or {}
    local ids = e.id and itemObjectives(e.id) or {}
    local used = {}
    for _, it in ipairs(items) do
      local found
      for _, id in ipairs(ids) do
        if not used[id] and lower(call(api.itemName, id)) == lower(it.name) then found = id; break end
      end
      if not found and #ids == 1 and #items == 1 then found = ids[1] end
      if not found then found = tonumber(call(api.idByName, it.name)) end
      if found then used[found] = true; add(found, tonumber(it.required) or QUEST_ALL, title) end
    end
    -- objetivos de QuestieDB sin pareja en el registro: se guarda todo (lado seguro)
    for _, id in ipairs(ids) do if not used[id] then add(id, nil, title) end end
    if e.id then
      for _, id in ipairs(list(call(api.sourceItems, e.id))) do add(id, nil, title) end
      local nq = tonumber(call(api.nextQuest, e.id))
      if nq and nq > 0 and not active[nq] then
        added = {}
        local nt = call(api.questName, nq) or ("#" .. nq)
        for _, id in ipairs(itemObjectives(nq)) do add(id, nil, nt, true) end
        for _, id in ipairs(list(call(api.sourceItems, nq))) do add(id, nil, nt, true) end
      end
    end
  end
  return need
end

GF.BuildQuestNeed = BuildQuestNeed
GF.QUEST_ALL = QUEST_ALL
