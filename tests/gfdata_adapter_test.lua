-- Offline tests for adapters/gfdata.lua and GF.MergeSourceApis (Lua 5.1): the data addon as a recipe source.
-- Run from the addon folder:  lua tests/gfdata_adapter_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local function run(path, G, GF)
  local fn = assert(loadfile(path))
  G = G or {}
  G._G = G   -- rawget(_G, "GoldFinderForeverData") inside the chunk must see the fake globals
  setfenv(fn, setmetatable(G, { __index = _G }))
  fn("GoldFinderForever", GF)
end

-- MergeSourceApis ------------------------------------------------------------------------------------------------------
local GF = {}
run("core/recipe_source.lua", {}, GF)
local A = { vendors = function(id) return id == 1 and { 30, 10 } or nil end, drops = function() return { 5 } end,
  npc = function(id) return id == 10 and { name = "FromA", level = 20 } or nil end }
local B = { vendors = function(id) return id == 1 and { 20, 10 } or nil end, drops = function() return { 5, 6 } end,
  npc = function(id) return (id == 10 or id == 20) and { name = "FromB" } or nil end }
local M = GF.MergeSourceApis(A, B)
local v = M.vendors(1)
check("merge: vendors are the sorted union without duplicates", #v == 3 and v[1] == 10 and v[2] == 20 and v[3] == 30)
local d = M.drops(1)
check("merge: drops are the union", #d == 2 and d[1] == 5 and d[2] == 6)
check("merge: the first source answers for a creature both know", M.npc(10).name == "FromA")
check("merge: the second source answers when the first does not know it", M.npc(20).name == "FromB")
check("merge: nobody knows it", M.npc(99) == nil)
check("merge: one nil gives the other", GF.MergeSourceApis(nil, B) == B and GF.MergeSourceApis(A, nil) == A)
check("merge: both nil gives nil", GF.MergeSourceApis(nil, nil) == nil)
local bad = { vendors = function() error("boom") end, drops = function() return "x" end, npc = function() error("boom") end }
local MB = GF.MergeSourceApis(A, bad)
check("merge: a raising source counts as empty", #MB.vendors(1) == 2 and #MB.drops(1) == 1 and MB.npc(10).name == "FromA")

-- DataSourceApi --------------------------------------------------------------------------------------------------------
local points = {
  { type = "RECIPE_SOLD", npcId = 3366, itemId = 18731, zone = 1454, x = 0.6304, y = 0.4547, name = "Tamar", confirmations = 3 },
  { type = "RECIPE_SOLD", npcId = 3366, itemId = 18731, zone = 1454, x = 0.7, y = 0.7, name = "Tamar", confirmations = 1 },
  { type = "RECIPE_SOLD", npcId = 4000, itemId = 18731, zone = 1411, x = 0.5, y = 0.25, name = "Other", confirmations = 2 },
  { type = "RECIPE_DROP", npcId = 7000, itemId = 18731, zone = 1428, x = 0.1, y = 0.2, name = "Mob", confirmations = 1 },
  { type = "VENDOR", npcId = 5, name = "NotARecipe" },
  { type = "RECIPE_SOLD", itemId = 18731 },
  "garbage", 42,
}
local calls = 0
local G = {
  GoldFinderForeverData = { FindItem = function(id) calls = calls + 1; return id == 18731 and points or {} end },
  C_Map = { GetMapInfo = function(id) return ({ [1454] = { name = "Orgrimmar" }, [1411] = { name = "Durotar" } })[id] end },
}
local GF2 = {}
run("adapters/gfdata.lua", G, GF2)
local api = GF2.DataSourceApi()
check("data api exists when the addon is there", type(api) == "table")
local sold = api.vendors(18731)
check("vendors: creature ids of RECIPE_SOLD points, once each", #sold == 2 and sold[1] == 3366 and sold[2] == 4000)
local drops = api.drops(18731)
check("drops: creature ids of RECIPE_DROP points", #drops == 1 and drops[1] == 7000)
check("an unknown item has no sources", #api.vendors(99) == 0 and #api.drops(99) == 0)
local n = api.npc(3366)
check("npc: name and zone name", n and n.name == "Tamar" and n.zone == "Orgrimmar")
check("npc: the best-confirmed sighting wins, scaled to 0-100 with one decimal", n and n.x == 63.0 and n.y == 45.5)
check("npc: no level and no faction (usable by both)", n and n.level == nil and n.friendly == nil)
check("npc: a second map", api.npc(4000).zone == "Durotar" and api.npc(4000).x == 50.0 and api.npc(4000).y == 25.0)
check("npc: unknown creature", api.npc(123) == nil)
check("npc: asked before any item lookup", GF2.DataSourceApi().npc(3366) == nil)

-- the picker accepts this api as is
local GF3 = {}
run("core/recipe_source.lua", {}, GF3)
local pick = GF3.PickRecipeSource(api, 18731, "Horde")
check("PickRecipeSource: lowest creature id vendor wins, zone and place come from the data",
  pick and pick.kind == "vendor" and pick.name == "Tamar" and pick.zone == "Orgrimmar" and pick.x == 63.0 and pick.others == 2)

-- missing or broken data addon
local GF4 = {}
run("adapters/gfdata.lua", {}, GF4)
check("no data addon: no api", GF4.DataSourceApi() == nil)
local GF5 = {}
run("adapters/gfdata.lua", { GoldFinderForeverData = { Command = function() end } }, GF5)
check("an addon without FindItem: no api", GF5.DataSourceApi() == nil)
local GF6 = {}
run("adapters/gfdata.lua", { GoldFinderForeverData = { FindItem = function() error("boom") end } }, GF6)
local a6 = GF6.DataSourceApi()
check("FindItem that raises: empty answers, nothing raised", a6 and #a6.vendors(1) == 0 and #a6.drops(1) == 0)
local GF7 = {}
run("adapters/gfdata.lua", { GoldFinderForeverData = { FindItem = function() return "not a list" end } }, GF7)
check("FindItem that returns a non-list: empty answers", #GF7.DataSourceApi().vendors(1) == 0)
local GF8 = {}
run("adapters/gfdata.lua", { GoldFinderForeverData = { FindItem = function() return { { type = "RECIPE_SOLD", npcId = 1, name = "N", zone = 1454, x = "bad", y = {} } } end },
  C_Map = { GetMapInfo = function() error("boom") end } }, GF8)
local a8 = GF8.DataSourceApi()
a8.vendors(1)
local n8 = a8.npc(1)
check("bad coordinates and a failing C_Map: the creature is still named, without a place", n8 and n8.name == "N" and n8.x == nil and n8.y == nil and n8.zone == nil)

-- WatchDataAddon --------------------------------------------------------------------------------------------------------
local cleared, cb = 0, nil
local GF9 = { ClearRecipeSourceCache = function() cleared = cleared + 1 end }
local subs = 0
run("adapters/gfdata.lua", { GoldFinderForeverData = { FindItem = function() return {} end,
  Subscribe = function(fn) subs = subs + 1; cb = fn; return subs end } }, GF9)
GF9.WatchDataAddon(); GF9.WatchDataAddon()
check("watch: subscribes only once", subs == 1)
cb("added", {})
check("watch: a recorded point clears the cache", cleared == 1)
local GF10 = {}
run("adapters/gfdata.lua", { GoldFinderForeverData = { FindItem = function() return {} end, Subscribe = function() return nil end } }, GF10)
GF10.WatchDataAddon()
check("watch: a refused subscription does not raise and is retried later", true)
local GF11 = {}
run("adapters/gfdata.lua", {}, GF11)
GF11.WatchDataAddon()
check("watch: no addon, nothing happens", true)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
