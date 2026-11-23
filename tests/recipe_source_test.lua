-- Offline tests for GF.PickRecipeSource and GF.WithRecipeSource (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\recipe_source_test.lua
-- The pure picker gets a stub source API; the adapter gets fake QuestieDB globals (ItemDB, NpcDB, C_Map).

local function run(path, G, GF)
  local fn = assert(loadfile(path))
  G = G or {}
  G._G = G   -- rawget(_G, "ItemDB") inside the chunk must see the fake globals
  setfenv(fn, setmetatable(G, { __index = _G }))
  fn("GoldFinder", GF)
end

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

-- 1. Pure picker
local GF = {}
run("core/recipe_source.lua", {}, GF)
local NPCS = {
  [10] = { name = "Horde Vendor", zone = "Orgrimmar", x = 50, y = 60, level = 30, friendly = "H" },
  [11] = { name = "Alliance Vendor", zone = "Stormwind City", x = 10, y = 20, level = 30, friendly = "A" },
  [12] = { name = "Neutral Vendor", zone = "Booty Bay", x = 40, y = 70, level = 40, friendly = "AH" },
  [20] = { name = "Strong Mob", zone = "Tanaris", level = 50 },
  [21] = { name = "Weak Mob", zone = "Feralas", level = 41 },
}
local function api(vendors, drops)
  return { vendors = function() return vendors end, drops = function() return drops end, npc = function(id) return NPCS[id] end }
end

local r = GF.PickRecipeSource(api({ 11, 10 }, { 20 }), 1, "Horde")
check("vendor of the player's faction wins over a drop", r and r.kind == "vendor" and r.name == "Horde Vendor" and r.zone == "Orgrimmar")
r = GF.PickRecipeSource(api({ 10, 11 }, nil), 1, "Alliance")
check("alliance player gets the alliance vendor", r and r.name == "Alliance Vendor")
r = GF.PickRecipeSource(api({ 10 }, { 21 }), 1, "Alliance")
check("no vendor for the faction: falls back to a drop", r and r.kind == "drop" and r.name == "Weak Mob")
r = GF.PickRecipeSource(api(nil, { 20, 21 }), 1, "Horde")
check("several drops: the lowest-level creature", r and r.name == "Weak Mob" and r.level == 41 and r.others == 1)
r = GF.PickRecipeSource(api({ 12, 10 }, { 20 }), 1, "Horde")
check("several places are counted in others (lowest vendor id first)", r and r.name == "Horde Vendor" and r.others == 2)
r = GF.PickRecipeSource(api({}, {}), 1, "Horde")
check("nothing known: nil", r == nil)
r = GF.PickRecipeSource(api({ 999 }, nil), 1, "Horde")
check("unknown npc ids are ignored", r == nil)
check("nil api or item: nil", GF.PickRecipeSource(nil, 1, "Horde") == nil and GF.PickRecipeSource(api({}, {}), nil, "Horde") == nil)

-- 2. Adapter with fake QuestieDB
local GF2 = {}
local G = {
  UnitFactionGroup = function() return "Horde" end,
  C_Map = { GetAreaInfo = function(id) return ({ [1637] = "Orgrimmar" })[id] end },
  ItemDB = { vendors = function(id) return id == 5 and { 77 } or nil end, npcDrops = function() return nil end },
  NpcDB = {
    name = function(id) return id == 77 and "Test Vendor" or nil end,
    zoneID = function() return 1637 end,
    spawns = function() return { [1637] = { { 52.5, 61.2 } } } end,
    minLevel = function() return 35 end,
    friendlyToFaction = function() return "H" end,
  },
}
run("core/recipe_source.lua", G, GF2)
run("adapters/questie.lua", G, GF2)
local l = GF2.WithRecipeSource({ item = 5 })
check("adapter fills zone, npc and coordinates for a vendor", l.zone == "Orgrimmar" and l.npc == "Test Vendor" and l.x == 52.5 and l.y == 61.2 and not l.drop)
-- the same vendor, but inside an instance: Questie reports the position as -1, -1
local GF4 = {}
local G4 = {
  UnitFactionGroup = function() return "Horde" end,
  C_Map = { GetAreaInfo = function() return "Orgrimmar" end },
  ItemDB = { vendors = function() return { 77 } end, npcDrops = function() return nil end },
  NpcDB = { name = function() return "Test Vendor" end, zoneID = function() return 1637 end,
    spawns = function() return { [1637] = { { -1, -1 } } } end, minLevel = function() return 35 end,
    friendlyToFaction = function() return "H" end },
}
run("core/recipe_source.lua", G4, GF4)
run("adapters/questie.lua", G4, GF4)
l = GF4.WithRecipeSource({ item = 5 })
check("instance creatures: the -1,-1 position is dropped, the zone stays", l.zone == "Orgrimmar" and l.x == nil and l.y == nil and l.npc == "Test Vendor")
l = GF2.WithRecipeSource({ item = 6 })
check("item without sources: unchanged", l.zone == nil and l.npc == nil)
l = GF2.WithRecipeSource({ item = 5, zone = "Somewhere" })
check("an entry that already has a place is left alone", l.zone == "Somewhere" and l.npc == nil)
local GF3 = {}
run("core/recipe_source.lua", {}, GF3)
run("adapters/questie.lua", {}, GF3)
l = GF3.WithRecipeSource({ item = 5 })
check("without QuestieDB nothing changes and nothing errors", l.zone == nil and l.npc == nil)

-- 3. The guide line
do
  local LL = { ["guide.srcVendor"] = "Sold by %s%s%s", ["guide.srcDrop"] = "Dropped by %s%s%s%s", ["guide.srcIn"] = " in %s",
    ["learn.level"] = " (level %d)", ["learn.more"] = " (+%d more places)" }
  local where = function(l) return l.zone .. " (" .. l.x .. ", " .. l.y .. ")" end
  check("line: vendor with its place", GF.RecipeSourceLine({ npc = "Bob", zone = "Orgrimmar", x = 5, y = 6 }, LL, where) == "Sold by Bob in Orgrimmar (5, 6)")
  check("line: drop with level, place and more", GF.RecipeSourceLine({ npc = "Mob", drop = true, level = 41, zone = "Feralas", x = 1, y = 2, others = 2 }, LL, where)
    == "Dropped by Mob (level 41) in Feralas (1, 2) (+2 more places)")
  check("line: no zone known leaves the place out", GF.RecipeSourceLine({ npc = "Bob" }, LL, where) == "Sold by Bob")
  check("line: no npc or no entry gives nil", GF.RecipeSourceLine({}, LL, where) == nil and GF.RecipeSourceLine(nil, LL, where) == nil)
end

-- 3. WithRecipeSource with the data addon (and without QuestieDB)
do
  local DATA = { { type = "RECIPE_SOLD", npcId = 3366, itemId = 777, zone = 1454, x = 0.6304, y = 0.4547, name = "Tamar", confirmations = 1 } }
  local clearCb
  local G3 = {
    UnitFactionGroup = function() return "Horde" end,
    C_Map = { GetMapInfo = function() return { name = "Orgrimmar" } end },
    GoldFinderForeverData = { FindItem = function(id)
        local out = {}
        for _, p in ipairs(DATA) do if p.itemId == id then out[#out + 1] = p end end
        return out
      end,
      Subscribe = function(fn) clearCb = fn; return 1 end },
  }
  local GF3 = {}
  run("core/recipe_source.lua", G3, GF3)
  run("adapters/questie.lua", G3, GF3)
  run("adapters/gfdata.lua", G3, GF3)
  local l = GF3.WithRecipeSource({ item = 777 })
  check("data only: the entry gets npc, zone and place", l.npc == "Tamar" and l.zone == "Orgrimmar" and l.x == 63.0 and l.y == 45.5)
  check("data only: the data addon is watched for changes", clearCb ~= nil)
  local none = GF3.WithRecipeSource({ item = 888 })
  check("data only: an item nobody recorded stays without a place", none.npc == nil and none.zone == nil)
  DATA[#DATA + 1] = { type = "RECIPE_SOLD", npcId = 3367, itemId = 888, zone = 1454, x = 0.5, y = 0.5, name = "New", confirmations = 1 }
  local later = GF3.WithRecipeSource({ item = 888 })
  check("data only: nothing is cached without QuestieDB, so a new point shows at once", later.npc == "New")
  check("an entry that already has a place is left alone", GF3.WithRecipeSource({ item = 777, zone = "X", npc = "Y" }).npc == "Y")
end

-- the faction of a vendor: one whose faction is known beats one whose faction is not (the data addon records none)
do
  local npcs = {
    [3] = { name = "Data Vendor", zone = "Somewhere", x = 1, y = 2 },
    [10] = { name = "Horde Vendor", zone = "Orgrimmar", x = 50, y = 60, level = 30, friendly = "H" },
    [11] = { name = "Alliance Vendor", zone = "Stormwind City", x = 10, y = 20, level = 30, friendly = "A" },
  }
  local function mix(ids) return { vendors = function() return ids end, drops = function() return nil end, npc = function(id) return npcs[id] end } end
  local r1 = GF.PickRecipeSource(mix({ 3, 10 }), 1, "Horde")
  check("a vendor with a known faction beats one with none, even with a higher id", r1 and r1.name == "Horde Vendor")
  check("the one with no faction is still counted among the other places", r1 and r1.others == 1)
  local r2 = GF.PickRecipeSource(mix({ 3 }), 1, "Horde")
  check("with only a vendor of unknown faction, it is used", r2 and r2.name == "Data Vendor")
  local r3 = GF.PickRecipeSource(mix({ 3, 11 }), 1, "Horde")
  check("a vendor of the other faction is never used, and the unknown one fills the gap", r3 and r3.name == "Data Vendor")
  local r4 = GF.PickRecipeSource(mix({ 11, 10 }), 1, "Horde")
  check("among vendors of known faction the lowest id still wins", r4 and r4.name == "Horde Vendor")
end

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
