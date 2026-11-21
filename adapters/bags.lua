-- adapters/bags.lua: every bag read goes through here. Returns one flat list of occupied slots, empty when the
-- container API is missing, and a failing read skips that slot instead of raising.

local _, GF = ...

function GF.BagApiReady()
  local CC = C_Container
  return (CC and CC.GetContainerNumSlots and CC.GetContainerItemInfo) and true or false
end

-- { bag, slot, id, count, locked, bound } for every occupied slot of the backpack and the bag slots.
function GF.BagSlots()
  local slots = {}
  if not GF.BagApiReady() then return slots end
  local CC = C_Container
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (CC.GetContainerNumSlots(bag) or 0) do
      local ok, info = pcall(CC.GetContainerItemInfo, bag, slot)
      if ok and info and info.itemID then
        slots[#slots + 1] = { bag = bag, slot = slot, id = info.itemID, count = info.stackCount or 1,
          locked = info.isLocked, bound = info.isBound }
      end
    end
  end
  return slots
end
