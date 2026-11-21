-- adapters/quests.lua: reads the quest log (modern and classic clients) and QuestieDB, and keeps a cached need
-- table that is dropped when the log or the bags change.

local _, GF = ...

-- Registro de misiones: { { id, title, items = { { name, required } } } } (solo objetivos de objeto).
-- Cliente moderno (C_QuestLog.GetInfo) o clasico (GetQuestLogTitle); objetivos con GetQuestObjectives o
-- GetQuestLogLeaderBoard ("Nombre: 3/10").
local function ReadQuestLog()
  local out = {}
  local CQ = C_QuestLog
  local modern = CQ and CQ.GetNumQuestLogEntries and CQ.GetInfo
  local n = 0
  if modern then n = CQ.GetNumQuestLogEntries() or 0
  elseif GetNumQuestLogEntries then n = GetNumQuestLogEntries() or 0 end
  for i = 1, n do
    local title, isHeader, qid
    if modern then
      local info = CQ.GetInfo(i)
      if info then title, isHeader, qid = info.title, info.isHeader, info.questID end
    elseif GetQuestLogTitle then
      local t, _, _, h, _, _, _, q = GetQuestLogTitle(i)
      title, isHeader, qid = t, h, q
    end
    if title and not isHeader then
      local e = { id = tonumber(qid), title = title, items = {} }
      local objs = qid and CQ and CQ.GetQuestObjectives and CQ.GetQuestObjectives(qid)
      if type(objs) == "table" then
        for _, o in ipairs(objs) do
          if o.type == "item" and o.text then
            local name, _, req = o.text:match("^%s*(.-):%s*(%d+)%s*/%s*(%d+)")
            e.items[#e.items + 1] = { name = name or o.text, required = tonumber(o.numRequired) or tonumber(req) }
          end
        end
      elseif GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        for j = 1, (GetNumQuestLeaderBoards(i) or 0) do
          local text, kind = GetQuestLogLeaderBoard(j, i)
          if kind == "item" and text then
            local name, _, req = text:match("^%s*(.-):%s*(%d+)%s*/%s*(%d+)")
            e.items[#e.items + 1] = { name = name or text, required = tonumber(req) }
          end
        end
      end
      out[#out + 1] = e
    end
  end
  return out
end

-- QuestieDB (opcional) y nombres de lo que llevas en las bolsas, para pasar de nombre a id
local function QuestApi()
  local api = {}
  local Q, I = rawget(_G, "QuestDB"), rawget(_G, "ItemDB")
  if type(Q) == "table" then
    api.objectives, api.sourceItems = Q.objectives, Q.requiredSourceItems
    api.nextQuest, api.questName = Q.nextQuestInChain, Q.name
  end
  api.itemName = function(id)
    local n = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)
    if not n and type(I) == "table" and type(I.name) == "function" then n = I.name(id) end
    return n
  end
  local byName
  api.idByName = function(name)
    if not byName then
      byName = {}
      for _, s in ipairs(GF.BagSlots()) do
        local n = C_Item.GetItemInfo(s.id)
        if n then byName[n:lower()] = s.id end
      end
    end
    return type(name) == "string" and byName[name:lower()] or nil
  end
  return api
end

local questCache, questPending
local function QuestNeed(id)
  if not questCache then
    local ok, res = pcall(function() return GF.BuildQuestNeed(ReadQuestLog(), QuestApi()) end)
    questCache = ok and res or {}
  end
  return questCache[id]
end
local questEvents = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED",
    "BAG_UPDATE_DELAYED" }) do
  pcall(questEvents.RegisterEvent, questEvents, e)
end
questEvents:SetScript("OnEvent", function()
  if questPending then return end
  questPending = true
  C_Timer.After(0.5, function() questPending = nil; questCache = nil end)
end)

GF.ReadQuestLog = ReadQuestLog
GF.QuestApi = QuestApi
GF.QuestNeed = QuestNeed
