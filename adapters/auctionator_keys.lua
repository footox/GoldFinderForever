-- adapters/auctionator_keys.lua: does an item link have an entry of its OWN in Auctionator's price database?
-- Auctionator answers a price asked by link with the generic entry (the cheapest variant of the item) when the link's variant has
-- no entry yet, so the price alone cannot tell the two apart. Auctionator names the keys of an item from the most specific to the
-- generic one (for equipment with variants: "gr:<id>:<suffix>", then "<id>"); one key means the item has no variants.
-- Everything is read inside pcall: Auctionator is optional and its internals are not ours.

local _, GF = ...

-- true: the price comes from the variant's own entry (or the item has no variants); false: only the generic entry exists;
-- nil: it cannot be told (Auctionator missing or different, item data not loaded yet).
function GF.VariantKnown(link)
  if type(link) ~= "string" then return nil end
  local A = _G.Auctionator
  local db = A and A.Database and A.Database.db
  local keyFor = A and A.Utilities and A.Utilities.DBKeyFromLink
  if type(db) ~= "table" or type(keyFor) ~= "function" then return nil end
  local keys
  local ok = pcall(keyFor, link, function(k) keys = k end)   -- the callback may come later (item data not loaded): then keys stays nil
  if not ok or type(keys) ~= "table" or #keys == 0 then return nil end
  if #keys == 1 then return true end
  return db[keys[1]] ~= nil
end
