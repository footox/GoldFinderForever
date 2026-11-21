-- Offline tests for TrainList (Lua 5.1): rank trainers come from trainers recorded in game first and from
-- GoldFinderTrainers otherwise, never from GoldFinderData (Zygor). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\trainers_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")
local a = assert(src:find("-- Requisitos para entrenar cada rango", 1, true), "start marker")
local b = assert(src:find("-- FIN DE INSTRUCTORES", 1, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn TrainList"

local faction = "Horde"
local env = setmetatable({
  UnitFactionGroup = function() return faction end,
  GoldFinderData = { train = { leatherworking = { H = { { max = 75, name = "Zygor", npc = "Zygor NPC" } } } } },
  GoldFinderTrainers = { leatherworking = {
    [75] = { A = "Alli One|Stormwind City|1.0|2.0", H = "Horde One|Orgrimmar|3.0|4.0;Horde Two|Undercity|5.0|6.0" },
    [225] = { A = "Alli Expert|Darnassus|7.0|8.0", H = "Una|Thunder Bluff|41.4|42.6" },
  } },
  GoldFinderDB = {},
}, { __index = _G })

local function load()
  local f = assert(loadstring(chunk))
  setfenv(f, env)
  return f()
end

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

-- 1. Without recorded trainers, the first GoldFinderTrainers entry of each rank, for the player's faction.
local TrainList = load()
local l = TrainList("Leatherworking")
check("static: two ranks", l and #l == 2)
check("static: apprentice from GoldFinderTrainers", l[1].max == 75 and l[1].npc == "Horde One" and l[1].zone == "Orgrimmar"
  and l[1].x == "3.0" and l[1].y == "4.0" and l[1].name == "Apprentice Leatherworking")
check("static: expert", l[2].max == 225 and l[2].npc == "Una" and l[2].name == "Expert Leatherworking")
check("never reads Zygor data", l[1].npc ~= "Zygor NPC")

-- 2. A trainer recorded in game wins over the static list for that rank.
env.GoldFinderDB = { trainers = { Horde = { Leatherworking = {
  [150] = { npc = "Arthur Moore", zone = "Undercity", x = "70.2", y = "57.4" },
  [75] = { npc = "Dan Golthas", zone = "Undercity", x = "70.9", y = "58.4" } } } } }
l = TrainList("Leatherworking")
check("recorded: three ranks in order", #l == 3 and l[1].max == 75 and l[2].max == 150 and l[3].max == 225)
check("recorded: apprentice is the visited trainer", l[1].npc == "Dan Golthas" and l[1].seen == true)
check("recorded: journeyman only known from the visit", l[2].npc == "Arthur Moore" and l[2].name == "Journeyman Leatherworking")

-- 3. A profession missing from GoldFinderTrainers works from recorded data alone, and is nil with none.
env.GoldFinderDB.trainers.Horde.Cooking = { [225] = { npc = "Cook", zone = "Orgrimmar", x = "1", y = "2" } }
l = TrainList("Cooking")
check("recorded only: cooking expert", l and #l == 1 and l[1].npc == "Cook" and l[1].name == "Expert Cooking")
check("no data: nil", TrainList("Alchemy") == nil)

-- 4. The other faction's data is ignored.
faction = "Alliance"
l = TrainList("Leatherworking")
check("faction: alliance static list", #l == 2 and l[1].npc == "Alli One")

os.exit(failures == 0 and 0 or 1)
