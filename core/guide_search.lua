-- core/guide_search.lua: "what do I use this material for". Given the steps of a profession guide and a piece of a material's
-- name, keeps the steps whose recipe uses it. Pure functions; the item names come from the caller.

local _, GF = ...

-- items: the guide steps (those with a recipe carry `spell`), spells: GoldFinderRecipes.spells ({ [spell] = { r = { {itemID, qty}, ... } } }),
-- nameOf(itemID) -> name or nil (not loaded yet), query: part of a name (any case). Returns nil when there is no query,
-- else a new list with a copy of every matching step plus `uses` = { { id, name, qty }, ... }; the originals are not touched.
function GF.GuideBandsUsing(items, spells, nameOf, query)
  local q = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if q == "" then return nil end
  local out = {}
  for _, it in ipairs(items or {}) do
    local spell = it.spell or (it.band and (it.band.spell or it.band.s))
    local rec = spell and spells and spells[spell]
    if type(rec) == "table" and type(rec.r) == "table" then
      local uses = {}
      for _, m in ipairs(rec.r) do
        local name = nameOf(m[1])
        if name and name:lower():find(q, 1, true) then uses[#uses + 1] = { id = m[1], name = name, qty = m[2] or 1 } end
      end
      if #uses > 0 then
        local copy = {}
        for k, v in pairs(it) do copy[k] = v end
        copy.uses = uses
        out[#out + 1] = copy
      end
    end
  end
  return out
end

-- "Uses: Heavy Leather x2, Fine Thread x1"
function GF.UsesText(uses, L)
  local parts = {}
  for i, u in ipairs(uses or {}) do parts[i] = string.format("%s x%d", u.name, u.qty) end
  return string.format(L["gsearch.uses"], table.concat(parts, ", "))
end
