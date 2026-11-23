-- core/materials.lua: the categories of the Materials tab (leather, cloth, ore, herbs) and which one it opens on.
-- Pure: item class numbers and profession names come in, a category comes out.

local _, GF = ...

-- class/sub = the item class and subclass of the trade goods in this category (Trade Goods is class 7; cloth 5,
-- leather 6, metal and stone 7, herbs 9). profs = lower-case fragments of the profession names (as saved in the
-- character record, in English) whose players mostly deal in this material.
GF.MATERIAL_CATEGORIES = {
  { id = "leather", class = 7, sub = 6, profs = { "skinning", "leatherworking" } },
  { id = "cloth", class = 7, sub = 5, profs = { "tailoring" } },
  { id = "ore", class = 7, sub = 7, profs = { "mining", "blacksmithing", "engineering", "jewelcrafting" } },
  { id = "herb", class = 7, sub = 9, profs = { "herbalism", "alchemy" } },
}

local byId = {}
for i, c in ipairs(GF.MATERIAL_CATEGORIES) do byId[c.id] = { index = i, cat = c } end

-- The category table for an id, or nil.
function GF.MaterialCategory(id)
  local e = byId[id]
  return e and e.cat or nil
end

-- true when an item (class and subclass, as GetItemInfoInstant gives them) belongs to the category.
function GF.MaterialMatches(cat, classID, subClassID)
  return type(cat) == "table" and classID == cat.class and subClassID == cat.sub
end

-- The category a character opens on: the one of the profession with the highest skill among the ones that map to a
-- category; on a tie the order of GF.MATERIAL_CATEGORIES decides; with none of them, leather (what the tab always
-- showed). profs = the character's saved professions { [name] = { rank = n, ... } }.
function GF.DefaultMaterialCategory(profs)
  local best, bestRank
  if type(profs) == "table" then
    for i, c in ipairs(GF.MATERIAL_CATEGORIES) do
      for name, data in pairs(profs) do
        local rank = type(data) == "table" and tonumber(data.rank) or nil
        local lower = type(name) == "string" and name:lower() or ""
        if rank then
          for _, frag in ipairs(c.profs) do
            if lower:find(frag, 1, true) and (not bestRank or rank > bestRank) then best, bestRank = c, rank end
          end
        end
      end
    end
  end
  return best or GF.MATERIAL_CATEGORIES[1]
end

-- The category to show for a character record: the one chosen by hand if it is still valid, else the default.
function GF.CurrentMaterialCategory(char)
  local chosen = type(char) == "table" and byId[char.matCat]
  if chosen then return chosen.cat end
  return GF.DefaultMaterialCategory(type(char) == "table" and char.prof or nil)
end

-- The id of the next (step = 1) or previous (step = -1) category, wrapping around; an unknown id starts from the first.
function GF.NextMaterialCategory(id, step)
  local n = #GF.MATERIAL_CATEGORIES
  local e = byId[id]
  local i = e and e.index or 1
  i = ((i - 1 + (step == -1 and -1 or 1)) % n) + 1
  return GF.MATERIAL_CATEGORIES[i].id
end
