-- core/shopping.lua: sends the missing materials to an Auctionator shopping list. The Auctionator API table comes in as
-- a parameter, so this stays testable offline. A list is replaced by name, so it uses its own name and never touches
-- the player's other lists.

local _, GF = ...

-- mats = { { id, need, have } } with one entry per item (need already summed over the steps, have counted once, so
-- shared materials are never counted twice). nameOf(id) -> item name or nil (not loaded yet).
-- Returns { terms = {search strings}, skipped = items whose name is not loaded, count = items with something missing }.
function GF.ShoppingTerms(api, caller, mats, nameOf)
  local out = { terms = {}, skipped = 0, count = 0 }
  for _, m in ipairs(mats or {}) do
    local miss = (tonumber(m.need) or 0) - (tonumber(m.have) or 0)
    if miss > 0 then
      local name = nameOf and nameOf(m.id)
      if not name then
        out.skipped = out.skipped + 1
      else
        local term = name
        if api and api.ConvertToSearchString then
          local ok, s = pcall(api.ConvertToSearchString, caller, { searchString = name, isExact = true, quantity = miss })
          if ok and type(s) == "string" and s ~= "" then term = s end
        end
        out.terms[#out.terms + 1] = term
        out.count = out.count + 1
      end
    end
  end
  return out
end

-- Creates (or replaces) the Auctionator list `listName`. Returns true, count, skipped; or false, reason where reason is
-- "noapi" (the Auctionator API has no shopping lists), "none" (nothing missing or no names loaded) or the error text.
function GF.ShoppingSync(api, caller, listName, mats, nameOf)
  if not (api and type(api.CreateShoppingList) == "function") then return false, "noapi" end
  local r = GF.ShoppingTerms(api, caller, mats, nameOf)
  if #r.terms == 0 then return false, "none", r.skipped end
  local ok, err = pcall(api.CreateShoppingList, caller, listName, r.terms)
  if not ok then return false, tostring(err) end
  return true, r.count, r.skipped
end
