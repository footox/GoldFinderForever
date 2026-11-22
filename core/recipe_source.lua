-- core/recipe_source.lua: where to get a recipe item (pattern, plans, formula...). Pure: a source API and an item id come
-- in, the best place to get it comes out. The API is built by adapters/questie.lua from QuestieDB (optional).

local _, GF = ...

-- api = { vendors(itemId) -> npcIds|nil, drops(itemId) -> npcIds|nil,
--         npc(npcId) -> { name, zone, x, y, level, friendly ("A"|"H"|"AH"|nil) } | nil }
-- faction = "Horde" or "Alliance". Vendors the faction cannot use are skipped. A vendor beats a drop; among several
-- vendors the lowest id wins (stable), among drops the lowest-level creature wins.
-- Returns { kind = "vendor"|"drop", name, zone, x, y, level, others = how many more places exist } or nil.
function GF.PickRecipeSource(api, itemId, faction)
  if not (api and itemId) then return nil end
  local letter = (faction == "Horde") and "H" or "A"
  local function sorted(ids)
    local out = {}
    for _, id in ipairs(ids or {}) do out[#out + 1] = id end
    table.sort(out)
    return out
  end
  local function pick(ids, isVendor)
    local best, n = nil, 0
    for _, id in ipairs(sorted(ids)) do
      local npc = api.npc(id)
      local usable = npc and npc.name and ((not isVendor) or (not npc.friendly) or npc.friendly:find(letter, 1, true))
      if usable then
        n = n + 1
        if not best or ((not isVendor) and (npc.level or 999) < (best.level or 999)) then best = npc end
      end
    end
    return best, n
  end
  local v, nv = pick(api.vendors(itemId), true)
  local d, nd = pick(api.drops(itemId), false)
  local chosen, kind = v, "vendor"
  if not v then chosen, kind = d, "drop" end
  if not chosen then return nil end
  return { kind = kind, name = chosen.name, zone = chosen.zone, x = chosen.x, y = chosen.y, level = chosen.level,
    others = (nv + nd) - 1 }
end

-- The one-line text for where a recipe item can be had, from an entry filled by GF.WithRecipeSource
-- ({ npc, zone, x, y, level, drop, others }). L = the locale table; where(l) -> "Zone (x, y)". nil when there is no place.
function GF.RecipeSourceLine(l, L, where)
  if type(l) ~= "table" or not l.npc then return nil end
  local place = l.zone and string.format(L["guide.srcIn"], where(l)) or ""
  local more = (l.others and l.others > 0) and string.format(L["learn.more"], l.others) or ""
  if l.drop then
    local lvl = l.level and string.format(L["learn.level"], l.level) or ""
    return string.format(L["guide.srcDrop"], l.npc, lvl, place, more)
  end
  return string.format(L["guide.srcVendor"], l.npc, place, more)
end
