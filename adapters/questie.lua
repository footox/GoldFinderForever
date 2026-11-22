-- adapters/questie.lua: reads QuestieDB (optional, through its public ItemDB and NpcDB tables) to say where a recipe
-- item can be bought or looted. Everything is pcall-guarded and nil-safe: without QuestieDB nothing changes.

local _, GF = ...

local function Api()
  local I, N = rawget(_G, "ItemDB"), rawget(_G, "NpcDB")
  if not (type(I) == "table" and type(N) == "table" and type(I.vendors) == "function" and type(I.npcDrops) == "function"
    and type(N.name) == "function") then return nil end
  local function safe(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
  end
  return {
    vendors = function(id) return safe(I.vendors, id) end,
    drops = function(id) return safe(I.npcDrops, id) end,
    npc = function(id)
      local name = safe(N.name, id)
      if not name then return nil end
      local zid = type(N.zoneID) == "function" and safe(N.zoneID, id) or nil
      local spawns = type(N.spawns) == "function" and safe(N.spawns, id) or nil
      local x, y
      if type(spawns) == "table" then
        local list = (zid and spawns[zid]) or select(2, next(spawns))
        local first = type(list) == "table" and list[1]
        if type(first) == "table" then x, y = first[1], first[2] end
        -- Questie marks creatures inside an instance with -1: that is "no position on the map", not a coordinate
        if (tonumber(x) or 0) < 0 or (tonumber(y) or 0) < 0 then x, y = nil, nil end
      end
      local zone
      if zid and C_Map and C_Map.GetAreaInfo then zone = safe(C_Map.GetAreaInfo, zid) end
      return { name = name, zone = zone, x = x, y = y,
        level = type(N.minLevel) == "function" and safe(N.minLevel, id) or nil,
        friendly = type(N.friendlyToFaction) == "function" and safe(N.friendlyToFaction, id) or nil }
    end,
  }
end

local cache = {}

-- Forget every cached answer (the data addon calls this when it records or receives a point).
function GF.ClearRecipeSourceCache()
  for k in pairs(cache) do cache[k] = nil end
end

-- learn = { item = recipeItemId, ... }: if QuestieDB (or the data addon, GoldFinderForeverData) knows where to get that item and the entry has no place yet, the
-- same table gets zone, npc, x, y (a vendor) or zone, npc, level, drop = true (a loot source), plus others = more places.
function GF.WithRecipeSource(learn)
  if type(learn) ~= "table" or not learn.item or learn.zone or learn.npc then return learn end
  local src = cache[learn.item]
  if src == nil then
    local questie = Api()
    local data = GF.DataSourceApi and GF.DataSourceApi() or nil
    local api = GF.MergeSourceApis(questie, data)
    if not api then return learn end   -- neither source is ready (or installed): try again next time, cache nothing
    if data and GF.WatchDataAddon then GF.WatchDataAddon() end
    local ok, res = pcall(GF.PickRecipeSource, api, learn.item, UnitFactionGroup and UnitFactionGroup("player") or nil)
    src = (ok and res) or false
    -- a genuine "no source" is cached; a transient error is not; without QuestieDB nothing is cached because it may
    -- still be loading and would change the answer
    if ok and questie then cache[learn.item] = src end
  end
  if src then
    learn.zone, learn.npc, learn.x, learn.y = src.zone, src.name, src.x, src.y
    learn.drop, learn.level, learn.others = (src.kind == "drop") or nil, src.level, src.others
  end
  return learn
end
