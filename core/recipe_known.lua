-- core/recipe_known.lua: which of the player's OWN characters already know a recipe. Pure functions; no game calls and no
-- messages to anyone: it only reads what GoldFinder saved from each character's own profession window.

local _, GF = ...

-- chars: the saved characters ({ ["Name-Realm"] = { prof = { Skinning = { learned = { ["Recipe"] = true } } }, off = {} } }),
-- mine: the table of the current character, profKey: lowercase profession fragment, target: the normalised recipe name,
-- norm: the normaliser the caller uses for recipe names. Returns { { name, mine, prof }, ... } sorted: you first, then A-Z.
function GF.RecipeKnownBy(chars, mine, profKey, target, norm)
  local out = {}
  for ckey, c in pairs(chars or {}) do
    if type(c) == "table" and type(c.prof) == "table" then
      for prof, data in pairs(c.prof) do
        if type(data) == "table" and prof:lower():find(profKey, 1, true) and not (c.off and c.off[prof])
            and type(data.learned) == "table" then
          for known in pairs(data.learned) do
            if norm(known) == target then
              out[#out + 1] = { name = tostring(ckey):match("^([^-]+)") or tostring(ckey), mine = (c == mine), prof = prof }
              break
            end
          end
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.mine ~= b.mine then return a.mine end
    return a.name < b.name
  end)
  return out
end

-- "Already known by: you, Ashes". nil when nobody does.
function GF.KnownByText(list, L)
  if type(list) ~= "table" or #list == 0 then return nil end
  local names = {}
  for i, k in ipairs(list) do names[i] = k.mine and L["tip.recipeYou"] or k.name end
  return string.format(L["tip.recipeKnownBy"], table.concat(names, ", "))
end
