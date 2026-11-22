-- Offline tests for the R3 data fixes (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\r3_test.lua [path to GoldFinder.lua]
-- Loads the character records ("local function FullName" .. "-- Profesiones que el jugador ha dejado fuera"),
-- the recipe checks ("-- Recetas (patrones, planos...)" .. "-- DECISION: vender") and the trainer recorder
-- ("-- RECETAS DEL INSTRUCTOR" .. "local trainerEvents"), with stubbed WoW APIs.

local src = assert(io.open((arg and arg[1]) or "GoldFinder.lua")):read("*a")
local GFL = {}
for _, p in ipairs({ "core/locale.lua", "locales/enUS.lua" }) do assert(loadfile(p))("GoldFinder", GFL) end
local function block(from, to, tail)
  local a = assert(src:find(from, 1, true), "start marker " .. from)
  local b = assert(src:find(to, a, true), "end marker " .. to)
  return src:sub(a, b - 1) .. (tail or "")
end
local function load(chunk, env)
  local f = assert(loadstring(chunk))
  setfenv(f, setmetatable(env, { __index = _G }))
  return f()
end

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

---------------------------------------------------------------------------
-- 1 and 5: character records
---------------------------------------------------------------------------
local charsChunk = block("local function FullName()", "-- Profesiones que el jugador ha dejado fuera",
  "\nreturn Char, CleanPhantomChars")
local function charsEnv(first, surname, db)
  return load(charsChunk, {
    GoldFinderForeverDB = db, LEGACY_OWNER = "Twistice",
    UnitName = function() return first, surname end,
  })
end

for _, phantom in ipairs({ "Ashes-?", "Ashes-" }) do
  local db = { chars = {
    [phantom] = { prof = { Cooking = { rank = 50 } }, keep = { [5] = true }, session = { phantom = true } },
    ["Ashes-forever"] = { prof = { Tailoring = { rank = 120 } }, keep = { [7] = true }, session = { real = true } },
  } }
  local Char, Clean = charsEnv("Ashes", "Soulbinder", db)
  Char()
  Clean()
  local c = db.chars["Ashes Soulbinder"]
  check("1 " .. phantom .. ": full-name record exists", c ~= nil)
  check("1 " .. phantom .. ": no leftovers", count(db.chars) == 1)
  check("1 " .. phantom .. ": professions merged", c and c.prof.Cooking and c.prof.Tailoring and true)
  check("1 " .. phantom .. ": pins merged", c and c.keep[5] and c.keep[7] and true)
  check("1 " .. phantom .. ": realm record wins scalar fields", c and c.session and c.session.real == true)
end

do
  local db = { chars = {
    ["Ashes Soulbinder"] = { prof = { Tailoring = { rank = 120 } }, keep = {} },
    ["Ashes-?"] = { prof = { Cooking = { rank = 50 } }, keep = { [9] = true } },
  } }
  local _, Clean = charsEnv("Ashes", "Soulbinder", db)
  Clean()
  local c = db.chars["Ashes Soulbinder"]
  check("1 phantom left over after rename merges into full record", count(db.chars) == 1 and c.prof.Cooking
    and c.keep[9] and true)
end

do
  local legacy = { prof = { Mining = { rank = 10 } }, keep = {} }
  local db = { chars = {}, legacy = legacy }
  local Char = charsEnv("Twisticer", "Other", db)
  Char()
  check("5 legacy not merged into a longer first name", db.legacy == legacy
    and not db.chars["Twisticer Other"].prof.Mining)
  Char = charsEnv("Twistice", "Real", db)
  Char()
  check("5 legacy merged on exact first name", db.legacy == nil and db.chars["Twistice Real"].prof.Mining ~= nil)
end

---------------------------------------------------------------------------
-- R3 corrections: merge per profession, namesakes, generic fields, deferred surname, idempotence
---------------------------------------------------------------------------
-- stable serializer (sorted keys) to compare records byte by byte
local function ser(v)
  if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = "[" .. ser(k) .. "]=" .. ser(v[k]) end
  return "{" .. table.concat(out, ",") .. "}"
end

do
  local db = { chars = {
    ["Ashes-forever"] = { prof = { Tailoring = { rank = 75, maxRank = 75, skillLine = 197,
      learned = { ["Linen Boots"] = true }, crafts = { ["Linen Boots"] = { q = 1 } }, reagents = { [2320] = { per = 1 } } } },
      keep = {} },
    ["Ashes-?"] = { prof = { Tailoring = { rank = 120, maxRank = 150,
      learned = { ["Bolt of Silk Cloth"] = true, ["Linen Boots"] = false }, crafts = { ["Bolt of Silk Cloth"] = { q = 2 } },
      reagents = { [4306] = { per = 4 } } } }, keep = {} },
  } }
  local Char = charsEnv("Ashes", "Soulbinder", db)
  local t = Char().prof.Tailoring
  check("C1 same profession keeps both learned lists", t.learned["Linen Boots"] == true
    and t.learned["Bolt of Silk Cloth"] == true)
  check("C1 same profession keeps both crafts and reagents", t.crafts["Linen Boots"] and t.crafts["Bolt of Silk Cloth"]
    and t.reagents[2320] and t.reagents[4306] and true)
  check("C1 same profession keeps max rank and maxRank", t.rank == 120 and t.maxRank == 150)
  check("C1 skillLine kept", t.skillLine == 197)
end

do
  local soul = { prof = { Tailoring = { rank = 75 } }, keep = { [1] = true } }
  local oldR = { prof = { Mining = { rank = 30 } }, keep = { [2] = true } }
  local oldP = { prof = { Cooking = { rank = 5 } }, keep = { [3] = true } }
  local db = { chars = { ["Ashes Soulbinder"] = soul, ["Ashes-forever"] = oldR, ["Ashes-?"] = oldP } }
  local Char, Clean = charsEnv("Ashes", "Breakhand", db)
  local c = Char()
  Clean()
  check("C2 namesake: old keys not claimed", db.chars["Ashes-forever"] == oldR and db.chars["Ashes-?"] == oldP
    and not c.prof.Mining and not c.prof.Cooking)
  check("C2 namesake: nothing deleted, other record untouched", db.chars["Ashes Soulbinder"] == soul
    and soul.prof.Tailoring.rank == 75 and not soul.prof.Mining and not soul.prof.Cooking and count(db.chars) == 4)
end

do
  local db = { chars = {
    ["Ashes Soulbinder"] = { prof = {}, keep = {} }, ["Ashes Breakhand"] = { prof = {}, keep = {} },
    ["Ashes-?"] = { prof = { Cooking = { rank = 5 } }, keep = {} },
    ["Twistice Penguin"] = { prof = {}, keep = {} }, ["Twistice-"] = { prof = { Fishing = { rank = 9 } }, keep = {} },
  } }
  local _, Clean = charsEnv("Twistice", "Penguin", db)
  Clean()
  check("C3 single-candidate phantom merges", db.chars["Twistice-"] == nil
    and db.chars["Twistice Penguin"].prof.Fishing ~= nil)
  check("C3 ambiguous phantom stays", db.chars["Ashes-?"] ~= nil and not db.chars["Ashes Soulbinder"].prof.Cooking
    and not db.chars["Ashes Breakhand"].prof.Cooking)
end

do
  local resolveChunk = block("local function FullName()", "-- Profesiones que el jugador ha dejado fuera",
    "\nreturn ResolveFullName")
  local db = { chars = { ["Ashes Soulbinder"] = {}, ["Ashes Breakhand"] = {}, ["Twistice Penguin"] = {} },
    banker = "Ashes" }
  local R = load(resolveChunk, { GoldFinderForeverDB = db, LEGACY_OWNER = "Twistice", UnitName = function() return "X" end })
  check("C4 ambiguous first name returned unchanged", R("Ashes") == "Ashes")
  check("C4 unique first name resolved", R("Twistice") == "Twistice Penguin")
  local _, Clean = charsEnv("Twistice", "Penguin", db)
  Clean()
  check("C4 ambiguous banker not resolved", db.banker == "Ashes")
end

do
  local db = { chars = {
    ["Ashes-forever"] = { prof = {}, keep = {}, session = { real = true }, suNeed = { [1] = 2 },
      suTracked = { Tailoring = true }, flag = 1, extra = { a = 1 } },
    ["Ashes-?"] = { prof = {}, keep = {}, session = { phantom = true }, suTracked = { Cooking = true },
      flag = 2, extra = { a = 9, b = 2 }, other = "x" },
  } }
  local c = charsEnv("Ashes", "Soulbinder", db)()
  check("C5 generic scalar copied only when missing", c.flag == 1 and c.other == "x")
  check("C5 generic table unioned, dst wins", c.extra.a == 1 and c.extra.b == 2)
  check("C5 session kept whole", c.session.real == true and c.session.phantom == nil)
  check("C5 suNeed and suTracked stay together", c.suNeed[1] == 2 and c.suTracked.Tailoring
    and not c.suTracked.Cooking)
  local db2 = { chars = {
    ["Ashes-forever"] = { prof = {}, keep = {}, suTracked = { Cooking = true } },
    ["Ashes-?"] = { prof = {}, keep = {}, suNeed = { [5] = 1 }, suTracked = { Tailoring = true } },
  } }
  local c2 = charsEnv("Ashes", "Soulbinder", db2)()
  check("C5 suTracked copied with suNeed when dst lacks suNeed", c2.suNeed and c2.suNeed[5] == 1
    and c2.suTracked.Tailoring and not c2.suTracked.Cooking)
end

do
  local db = { chars = {
    ["Twistice Penguin"] = { prof = { Cooking = { rank = 179 } }, keep = {} },
    ["Twistice-forever"] = { prof = { Mining = { rank = 40 } }, keep = { [8] = true } },
  } }
  local c = charsEnv("Twistice", "Penguin", db)()
  check("C6 leftover realm key merged when unambiguous", db.chars["Twistice-forever"] == nil and c.prof.Mining
    and c.keep[8] and c.prof.Cooking.rank == 179 and true)
  local db2 = { chars = {
    ["Ashes Soulbinder"] = { prof = {}, keep = {} }, ["Ashes Breakhand"] = { prof = {}, keep = {} },
    ["Ashes-forever"] = { prof = { Mining = { rank = 40 } }, keep = {} },
  } }
  charsEnv("Ashes", "Soulbinder", db2)()
  check("C6 leftover realm key kept when ambiguous", db2.chars["Ashes-forever"] ~= nil
    and not db2.chars["Ashes Soulbinder"].prof.Mining)
end

do
  local surname
  local db = { chars = { ["Ashes-forever"] = { prof = { Mining = { rank = 40 } }, keep = {} } } }
  local Char = load(charsChunk, { GoldFinderForeverDB = db, LEGACY_OWNER = "Twistice",
    UnitName = function() return "Ashes", surname end })
  local t = Char()
  t.prof.Tailoring = { rank = 3 }
  check("C7 no bare first-name record without surname", db.chars["Ashes"] == nil
    and db.chars["Ashes-forever"] ~= nil and count(db.chars) == 1)
  surname = "Soulbinder"
  local c = Char()
  check("C7 deferred migration once the surname is known", db.chars["Ashes"] == nil
    and db.chars["Ashes-forever"] == nil and c == db.chars["Ashes Soulbinder"] and c.prof.Mining
    and c.prof.Tailoring and true)
end

do
  local function realShape()
    local function p(rank, sl) return { rank = rank, maxRank = 75, skillLine = sl, count = 1, time = 1,
      learned = { R = true }, crafts = { R = { q = 1 } }, reagents = { [1] = { per = 1 } }, recipes = { R = { d = 1 } } } end
    return { banker = "Ashes Soulbinder", chars = {
      ["Twistice Penguin"] = { prof = { Cooking = p(179, 185) }, keep = { [3385] = true }, off = { ["First Aid"] = true },
        session = { items = {} }, suNeed = { [4232] = {} }, suTracked = { Cooking = true } },
      ["Ashes Soulbinder"] = { prof = { Tailoring = p(75, 197) }, keep = {}, off = {}, session = { items = {} } },
      ["Ashes Breakhand"] = { prof = { Mining = p(36, 186) }, keep = {}, off = {}, session = { items = {} } },
    } }
  end
  local okAll = true
  for _, who in ipairs({ { "Twistice", "Penguin" }, { "Ashes", "Soulbinder" }, { "Ashes", "Breakhand" } }) do
    local db = realShape()
    local before = ser(db)
    local Char, Clean = charsEnv(who[1], who[2], db)
    for _ = 1, 3 do Char(); Clean() end
    if ser(db) ~= before then okAll = false; print("  changed for " .. who[1] .. " " .. who[2]) end
  end
  check("C8 idempotent on the real 3-character shape", okAll)
end

---------------------------------------------------------------------------
-- 3 and 4: recipe checks (own and other characters)
---------------------------------------------------------------------------
local recipeChunk = block("local function NormRecipe", "-- Requisitos para entrenar cada rango")
  .. block("-- Recetas (patrones, planos...)", "-- DECISION: vender", "\nreturn RecipeToLearn, RecipeForOthers")
local items = {
  [100] = { name = "Pattern: Bolt of Silk Cloth", req = 125 },
}
local curItem
local function recipeEnv(db, me)
  return load(recipeChunk, {
    L = GFL.L,
    GoldFinderForeverDB = db, format = string.format,
    Char = function() return db.chars[me] end,
    ProfOn = function() return true end,
    C_Item = {
      GetItemInfoInstant = function(id) if items[id] then return id, nil, nil, nil, nil, 9, 2 end end,
      GetItemInfo = function(id) return items[id] and items[id].name end,
    },
    TooltipName = function() end,
    UIParent = {},
    scanTip = {
      SetOwner = function() end, ClearLines = function() end,
      SetItemByID = function(_, id) curItem = id end, NumLines = function() return 2 end,
    },
    _G = { GoldFinderScanTipTextLeft2 = { GetText = function()
      return items[curItem] and items[curItem].req and ("Requires Tailoring (" .. items[curItem].req .. ")") or ""
    end } },
  })
end

do
  local db = { chars = { ["Me Self"] = { prof = { Tailoring = { rank = 130,
    learned = { ["bolts of silk cloth"] = true } } } } } }
  local RecipeToLearn = recipeEnv(db, "Me Self")
  check("3 own check uses normalized names (already known)", RecipeToLearn(100) == nil)
  db.chars["Me Self"].prof.Tailoring.learned = { ["Other Thing"] = true }
  check("3 own check still flags an unknown recipe", RecipeToLearn(100) ~= nil)
end

do
  local db = { chars = {
    ["Me Self"] = { prof = {} },
    ["Bob Smith"] = { prof = { Tailoring = { rank = 150, learned = {} } } },
    ["Low Guy"] = { prof = { Tailoring = { rank = 100 } } },
    ["Ann Known"] = { prof = { Tailoring = { rank = 160, learned = { ["Bolt of Silk Cloth"] = true } } } },
  } }
  local _, RecipeForOthers = recipeEnv(db, "Me Self")
  local list = RecipeForOthers(100, true, true)
  local bob, low, ann
  for _, ro in ipairs(list or {}) do
    if ro.who == "Bob Smith" then bob = ro elseif ro.who == "Low Guy" then low = ro elseif ro.who == "Ann Known" then
      ann = ro end
  end
  check("4 alt without recipe list gets a hint", bob ~= nil and bob.unknown == true)
  check("4 hint text", bob and bob.note ==
    "Bob Smith (Tailoring): open their profession window once to confirm whether they already know it")
  check("4 alt below the requirement gets no hint", low == nil)
  check("4 alt that knows it gets no hint", ann == nil)
  db.chars["Cy New"] = { prof = { Tailoring = { rank = 140, learned = { ["Something"] = true } } } }
  local one = RecipeForOthers(100)
  check("4 single answer prefers a confirmed alt", one and one.who == "Cy New" and not one.unknown)
end

---------------------------------------------------------------------------
-- 2: trainer rank services stored by profession name; filters always restored
---------------------------------------------------------------------------
local trainerChunk = block("-- RECETAS DEL INSTRUCTOR", "local trainerEvents = CreateFrame", "\nreturn RecordTrainer")
local function trainerEnv(db, services, opts)
  opts = opts or {}
  local filter = { available = true, unavailable = true, used = false }
  local env = {
    GoldFinderForeverDB = db, format = string.format, time = function() return 1 end,
    RANK_MAX = { Apprentice = 75, Journeyman = 150, Expert = 225, Artisan = 300 },
    GetNumTrainerServices = function() return #services end,
    IsTradeskillTrainer = function() return true end,
    GetTrainerServiceInfo = function(i) local s = services[i]; return s.name, s.sub, s.cat or "available" end,
    GetTrainerServiceSkillReq = function(i) return services[i].skill, services[i].req end,
    GetTrainerServiceCost = function(i)
      if opts.costError then error("boom") end
      return 100
    end,
    GetTrainerServiceTypeFilter = function(k) return filter[k] end,
    SetTrainerServiceTypeFilter = function(k, v) filter[k] = (v == 1) end,
    UnitName = function() return "Trainer Npc" end,
    GetRealZoneText = function() return "Zone" end,
    UnitFactionGroup = function() return "Horde" end,
  }
  return load(trainerChunk, env), filter
end

do
  local db = {}
  local RecordTrainer = trainerEnv(db, {
    { name = "Journeyman Tailor", sub = "" },
    { name = "Bolt of Silk Cloth", skill = "Tailoring", req = 125 },
  })
  RecordTrainer()
  local h = db.trainers and db.trainers.Horde
  check("2 rank stored under the window's profession", h and h.Tailoring and h.Tailoring[150] ~= nil)
  check("2 no entry under the noun", not (h and h.Tailor))
end

do
  local db = {}
  local RecordTrainer = trainerEnv(db, { { name = "Expert Leatherworker", sub = "" } })
  RecordTrainer()
  local h = db.trainers and db.trainers.Horde
  check("2 noun fallback without recipes", h and h.Leatherworking and h.Leatherworking[225] ~= nil)
end

do
  local db = {}
  local RecordTrainer, filter = trainerEnv(db, { { name = "Bolt of Silk Cloth", skill = "Tailoring", req = 125 } },
    { costError = true })
  local ok = pcall(RecordTrainer)
  check("2 error is still reported", not ok)
  check("2 filters restored after an error", filter.used == false)
end

do
  local a = src:find("-- PROFESION DEL INSTRUCTOR", 1, true)
  local TrainerProf = a and load(block("-- PROFESION DEL INSTRUCTOR", "-- FIN DE PROFESION DEL INSTRUCTOR",
    "\nreturn TrainerProf"), {})
  check("2 helper present", TrainerProf ~= nil)
  if TrainerProf then
    local map = { Tailor = "Tailoring", Leatherworker = "Leatherworking", Blacksmith = "Blacksmithing",
      Alchemist = "Alchemy", Engineer = "Engineering", Enchanter = "Enchanting", Cook = "Cooking",
      Herbalist = "Herbalism", Miner = "Mining", Skinner = "Skinning", Fisherman = "Fishing",
      ["First Aid"] = "First Aid", Leatherworking = "Leatherworking" }
    local okAll = true
    for k, v in pairs(map) do if TrainerProf(k) ~= v then okAll = false; print("  map " .. k) end end
    check("2 noun map", okAll)
    check("2 skill line wins over the noun", TrainerProf("Tailor", nil, "", "Tailoring") == "Tailoring")
  end
end

print(failures == 0 and "ALL PASS" or (failures .. " FAILED"))
if failures > 0 then os.exit(1) end
