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
    local best, unknown, n = nil, nil, 0
    for _, id in ipairs(sorted(ids)) do
      local npc = api.npc(id)
      local usable = npc and npc.name and ((not isVendor) or (not npc.friendly) or npc.friendly:find(letter, 1, true))
      if usable then
        n = n + 1
        if isVendor then
          -- a vendor with no faction on record (the data addon records none) can belong to the other side:
          -- the lowest id among the vendors whose faction is known wins, and an unknown one only fills a gap
          if npc.friendly then
            if not best then best = npc end
          elseif not unknown then
            unknown = npc
          end
        elseif not best or (npc.level or 999) < (best.level or 999) then
          best = npc
        end
      end
    end
    return best or unknown, n
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

-- Two source APIs (same shape as above) become one: vendors and drops are the sorted union of both lists, and npc(id)
-- asks a first and b only when a does not know the creature (a is the one with levels and factions). Either may be nil;
-- both nil gives nil. A source that raises is treated as having nothing.
function GF.MergeSourceApis(a, b)
  if not a then return b end
  if not b then return a end
  local function list(fn, id)
    local ok, out = pcall(fn, id)
    return (ok and type(out) == "table") and out or {}
  end
  local function union(fn)
    return function(id)
      local seen, out = {}, {}
      for _, src in ipairs({ a, b }) do
        for _, n in ipairs(list(src[fn], id)) do
          if not seen[n] then seen[n] = true; out[#out + 1] = n end
        end
      end
      table.sort(out)
      return out
    end
  end
  return {
    vendors = union("vendors"),
    drops = union("drops"),
    npc = function(id)
      for _, src in ipairs({ a, b }) do
        local ok, npc = pcall(src.npc, id)
        if ok and npc then return npc end
      end
      return nil
    end,
  }
end
