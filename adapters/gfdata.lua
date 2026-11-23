-- adapters/gfdata.lua: reads the optional data addon (GoldFinderForeverData) through its public API and presents what its
-- players recorded as a recipe source API ({ vendors, drops, npc }, see core/recipe_source.lua). Everything is
-- pcall-guarded and nil-safe: without the addon nothing changes.

local _, GF = ...

local function round1(v)
  v = tonumber(v)
  if not v then return nil end
  return math.floor(v * 1000 + 0.5) / 10   -- 0..1 map fraction -> 0..100 with one decimal, like the guide prints it
end

local function zoneName(uiMapId)
  if not (C_Map and C_Map.GetMapInfo and uiMapId) then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, uiMapId)
  if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
  return nil
end

-- The API for one lookup, or nil when the data addon is not there. Points are asked per item and remembered per
-- creature so npc(id) can answer without the item (PickRecipeSource asks for the creature by id only).
function GF.DataSourceApi()
  local D = rawget(_G, "GoldFinderForeverData")
  if not (type(D) == "table" and type(D.FindItem) == "function") then return nil end
  local known = {}
  local function ids(itemId, kind)
    local ok, points = pcall(D.FindItem, itemId)
    local out, seen = {}, {}
    if not (ok and type(points) == "table") then return out end
    for _, p in ipairs(points) do   -- already sorted by confirmations: the first sighting of a creature wins
      if type(p) == "table" and p.type == kind and type(p.npcId) == "number" and not seen[p.npcId] then
        seen[p.npcId] = true
        out[#out + 1] = p.npcId
        known[p.npcId] = known[p.npcId] or p
      end
    end
    return out
  end
  return {
    vendors = function(itemId) return ids(itemId, "RECIPE_SOLD") end,
    drops = function(itemId) return ids(itemId, "RECIPE_DROP") end,
    npc = function(id)
      local p = known[id]
      if not (p and type(p.name) == "string" and p.name ~= "") then return nil end
      -- the data records neither level nor faction: nil means "usable by both" and "level unknown"
      return { name = p.name, zone = zoneName(p.zone), x = round1(p.x), y = round1(p.y) }
    end,
  }
end

-- Newly recorded or shared points can change an answer: ask the data addon to tell us, once, and drop the cached
-- answers when it does.
local watched = false
function GF.WatchDataAddon()
  if watched then return end
  local D = rawget(_G, "GoldFinderForeverData")
  if not (type(D) == "table" and type(D.Subscribe) == "function") then return end
  local ok, token = pcall(D.Subscribe, function()
    if GF.ClearRecipeSourceCache then GF.ClearRecipeSourceCache() end
  end)
  if ok and token ~= nil then watched = true end
end
