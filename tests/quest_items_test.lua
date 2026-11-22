-- Offline tests for the quest item protection (Lua 5.1): the need table built from the quest log and QuestieDB
-- (item objectives with ids, source items, next quest of the chain), reading the quest log with the classic and
-- modern APIs, and the reserve integration in Decide / SellQty. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\quest_items_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function has(list, s) for _, v in ipairs(list or {}) do if v == s then return true end end return false end

---------------------------------------------------------------------------
-- 1. need table (pure builder) and quest log reader
---------------------------------------------------------------------------
local function loadCore(path, GF, env)
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable(env or {}, { __index = _G }))
  fn("GoldFinder", GF)
end
local GF = {}
loadCore("core/quest_need.lua", GF)
local L = {}   -- stubbed quest log state
local qenv = {
  C_QuestLog = L,
  CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end,
  C_Timer = { After = function() end },
}
loadCore("adapters/quests.lua", GF, qenv)
local BuildQuestNeed, ReadQuestLog, ALL = GF.BuildQuestNeed, GF.ReadQuestLog, GF.QUEST_ALL

local names = { [2589] = "Linen Cloth", [769] = "Chunk of Boar Meat", [5000] = "Coarse Gorilla Hair",
  [5001] = "Sealed Letter", [5002] = "Strange Rune", [5003] = "Pristine Hide" }
local quests = {
  [10] = { name = "Bring Cloth", obj = { [3] = { { 2589, nil, 0 } } }, next = 11 },
  [11] = { name = "More Cloth", obj = { [3] = { { 5003, nil, 0 } } }, src = { 5002 } },
  [20] = { name = "Boar Stew", obj = { [3] = { { 769, nil, 0 }, { 5000, nil, 0 } } }, src = { 5001 } },
}
local api = {
  objectives = function(q) return quests[q] and quests[q].obj end,
  sourceItems = function(q) return quests[q] and quests[q].src end,
  nextQuest = function(q) return quests[q] and quests[q].next end,
  questName = function(q) return quests[q] and quests[q].name end,
  itemName = function(id) return names[id] end,
  idByName = function(n) for id, x in pairs(names) do if x == n then return id end end end,
}
local entries = {
  { id = 10, title = "Bring Cloth", items = { { name = "Linen Cloth", required = 10 } } },
  { id = 20, title = "Boar Stew", items = { { name = "Chunk of Boar Meat", required = 4 },
    { name = "Coarse Gorilla Hair", required = 2 } } },
}
local need = BuildQuestNeed(entries, api)
check("objective with QuestieDB id: required total (not remaining)", need[2589] and need[2589].n == 10)
check("objective titles", need[2589] and has(need[2589].quests, "Bring Cloth"))
check("two item objectives matched by name", need[769] and need[769].n == 4 and need[5000] and need[5000].n == 2)
check("source item of active quest reserved (all)", need[5001] and need[5001].n == ALL
  and has(need[5001].quests, "Boar Stew"))
check("next quest of the chain: item objective reserved", need[5003] and need[5003].n == ALL
  and has(need[5003].quests, "siguiente de la cadena: More Cloth") and need[5003].chain == true)
check("next quest of the chain: source item reserved", need[5002] and has(need[5002].quests,
  "siguiente de la cadena: More Cloth"))
check("active objective is not marked as chain", need[2589].chain ~= true)

-- two quests asking for the same item add up; the same quest is counted once
local both = BuildQuestNeed({
  { id = 10, title = "Bring Cloth", items = { { name = "Linen Cloth", required = 10 } } },
  { id = 30, title = "Cloth Again", items = { { name = "Linen Cloth", required = 5 } } },
}, api)
check("two quests: counts add up", both[2589] and both[2589].n == 15 and #both[2589].quests == 2)
-- next quest already in the log: not counted as chain
local inlog = BuildQuestNeed({
  { id = 10, title = "Bring Cloth", items = { { name = "Linen Cloth", required = 10 } } },
  { id = 11, title = "More Cloth", items = {} },
}, api)
check("next quest already active: labelled as the quest, not chain", inlog[5003]
  and has(inlog[5003].quests, "More Cloth") and inlog[5003].chain ~= true)

-- without QuestieDB: names of items in bags only
local plain = BuildQuestNeed(entries, { idByName = api.idByName })
check("no QuestieDB: mapped by bag names", plain[2589] and plain[2589].n == 10 and plain[769].n == 4)
check("no QuestieDB: no chain, no source items", plain[5003] == nil and plain[5001] == nil)
check("no data at all: empty table", next(BuildQuestNeed(entries, {})) == nil)
-- QuestieDB id whose name does not match the log (other locale): one objective each pairs directly
local loc = BuildQuestNeed({ { id = 10, title = "Traer tela", items = { { name = "Paño de lino", required = 10 } } } },
  { objectives = api.objectives, itemName = api.itemName })
check("single objective pairs by position when names differ", loc[2589] and loc[2589].n == 10)
-- an unmatched QuestieDB item objective is kept whole (safe side)
local un = BuildQuestNeed({ { id = 20, title = "Boar Stew", items = {} } }, { objectives = api.objectives })
check("unmatched QuestieDB objective: all units", un[769] and un[769].n == ALL)
-- broken QuestieDB accessors never break the table
local bad = BuildQuestNeed(entries, { objectives = function() error("boom") end, idByName = api.idByName,
  nextQuest = function() error("x") end, sourceItems = function() return "nope" end })
check("erroring QuestieDB accessors: log objectives still counted", bad[2589] and bad[2589].n == 10)

-- quest log reader: modern API (C_QuestLog.GetInfo + GetQuestObjectives)
L.GetNumQuestLogEntries = function() return 3, 2 end
L.GetInfo = function(i)
  return ({ { title = "Elwynn", isHeader = true }, { title = "Bring Cloth", questID = 10 },
    { title = "Kill Wolves", questID = 40 } })[i]
end
L.GetQuestObjectives = function(q)
  if q == 10 then return { { text = "Linen Cloth: 3/10", type = "item", numFulfilled = 3, numRequired = 10 } } end
  return { { text = "Wolf slain: 1/8", type = "monster", numRequired = 8 } }
end
local log = ReadQuestLog()
check("modern log: headers skipped, one entry per quest", #log == 2 and log[1].id == 10 and log[1].title == "Bring Cloth")
check("modern log: item objective with required total", log[1].items[1] and log[1].items[1].name == "Linen Cloth"
  and log[1].items[1].required == 10)
check("modern log: monster objectives ignored", #log[2].items == 0)

-- classic API (GetQuestLogTitle + GetQuestLogLeaderBoard)
for k in pairs(L) do L[k] = nil end
qenv.C_QuestLog = nil
qenv.GetNumQuestLogEntries = function() return 2, 1 end
qenv.GetQuestLogTitle = function(i)
  if i == 1 then return "Westfall", nil, nil, true end
  return "Boar Stew", 12, nil, false, nil, nil, nil, 20
end
qenv.GetNumQuestLeaderBoards = function() return 2 end
qenv.GetQuestLogLeaderBoard = function(j)
  if j == 1 then return "Chunk of Boar Meat: 1/4", "item", false end
  return "Coarse Gorilla Hair: 2/2", "item", true
end
log = ReadQuestLog()
check("classic log: one quest", #log == 1 and log[1].id == 20 and log[1].title == "Boar Stew")
check("classic log: parsed item objectives", #log[1].items == 2 and log[1].items[1].name == "Chunk of Boar Meat"
  and log[1].items[1].required == 4 and log[1].items[2].required == 2)
qenv.GetNumQuestLogEntries = nil
check("no quest API: empty log", #ReadQuestLog() == 0)

---------------------------------------------------------------------------
-- 2. reserve integration (Decide / SellQty)
---------------------------------------------------------------------------
loadCore("core/config.lua", GF)
loadCore("core/locale.lua", GF)
loadCore("locales/enUS.lua", GF)
loadCore("core/decision.lua", GF, { GoldFinderDB = {} })
local S
local function reset()
  S = { ah = {}, vendor = {}, bags = {}, bank = {}, su = {}, route = {}, reagent = {}, quest = {},
        cfg = { minGain = 2000, crossChars = false, questItems = true }, keep = {} }
end
reset()
local deps = {
  AHApi = function() return { GetAuctionPriceByItemID = function(_, id) return S.ah[id] end } end,
  VendorPrice = function(id) return S.vendor[id] end,
  TSMValue = function() return nil end,
  Cfg = function(k) return S.cfg[k] end,
  Char = function() return { keep = S.keep } end,
  Counts = function(id) return S.bags[id] or 0, S.bank[id] or 0 end,
  SkillUpNeed = function(id) return S.su[id] end,
  RouteNeedFor = function(_, id) return S.route[id] end,
  ReagentInfo = function(id) return S.reagent[id] end,
  QuestNeed = function(id) return S.quest[id] end,
  RecipeToLearn = function() return nil end,
  RecipeForOthers = function() return nil end,
  OtherNeed = function() return nil end,
  IsUtilityItem = function() return false end,
  RefPrice = function() return nil end,
  ToBanker = function() return nil end,
  ItemInfoInstant = function(id) return id end,
  ItemQuality = function() return 1 end,
}
local Decide, SellQty = GF.NewDecision(deps)

local function cloth()
  reset()
  S.ah[2589] = 100000; S.vendor[2589] = 10
  S.quest[2589] = { n = 10, quests = { "Bring Cloth" } }
end
cloth()
local d = Decide(2589, 10, 0, false)
check("held = quest need: KEEP for the quest", d.verdict == "KEEP" and d.reason
  and d.reason:find("for the quest Bring Cloth", 1, true) ~= nil)
check("KEEP reserve counts the quest", d.reserve == 10)
cloth()
d = Decide(2589, 13, 0, false)
check("surplus over the quest need: AH with 3", d.verdict == "AH" and d.sellQty == 3)
check("decision carries the quest reserve", d.quest and d.quest.n == 10 and has(d.quest.quests, "Bring Cloth"))
cloth(); S.bags[2589] = 13
check("SellQty respects the quest need", SellQty(2589) == 3)
cloth(); S.bags[2589] = 5; S.bank[2589] = 6
check("SellQty: bank counts toward the quest reserve", SellQty(2589) == 1)
-- quest need is added to the profession reserve (turn-in consumes in addition to crafting)
cloth(); S.route[2589] = { need = 6, prof = "Tailoring", upto = 75 }; S.reagent[2589] = { need = 4, prof = "Tailoring",
  recipe = "Linen Bag" }
d = Decide(2589, 17, 0, false)
check("own = max(route, reagents) + quest: 16 reserved", d.reserve == 16 and d.sellQty == 1)
check("label names profession and quest", d.reserveFor and d.reserveFor:find("Tailoring", 1, true) ~= nil)
d = Decide(2589, 16, 0, false)
check("16 held with route 6 + quest 10: KEEP", d.verdict == "KEEP")
d = Decide(2589, 5, 0, false)
check("route alone covers holdings: profession reason kept", d.verdict == "KEEP" and d.reason:find("Tailoring", 1, true))
-- chain only
reset(); S.ah[5003] = 100000; S.vendor[5003] = 10
S.quest[5003] = { n = ALL, quests = { "siguiente de la cadena: More Cloth" }, chain = true, chainTitles = { "More Cloth" } }
d = Decide(5003, 4, 0, false)
check("chain item: KEEP for the chain", d.verdict == "KEEP" and d.reason:find("for the chain: More Cloth", 1, true))
S.bags[5003] = 4
check("chain item: nothing to sell", SellQty(5003) == 0)
-- setting off
cloth(); S.cfg.questItems = false
d = Decide(2589, 10, 0, false)
check("questItems off: no quest reserve", d.verdict == "AH" and d.sellQty == 10)
-- previous behaviour without quests
reset(); S.ah[300] = 100000; S.vendor[300] = 10
d = Decide(300, 4, 0, false)
check("previous behaviour: no quest need, AH all", d.verdict == "AH" and d.sellQty == 4 and d.quest == nil)

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
