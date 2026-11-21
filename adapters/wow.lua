-- adapters/wow.lua: the only place that talks to the game for chat output and coin formatting.

local _, GF = ...

function GF.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100GoldFinder Forever:|r " .. tostring(msg))
end

-- Same lookup order as before, evaluated per call: modern C_CurrencyInfo first, legacy global second.
function GF.CoinText(c)
  local fn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
  if fn then return fn(c) end
end

-- Runs fn(...) and returns its results, or nil when it raised: one failing call never breaks the caller.
function GF.Safe(fn, ...)
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  return unpack(r, 2)
end

-- Is the addon loaded? Modern namespace first, legacy global second.
function GF.IsAddOnLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
  if IsAddOnLoaded then return IsAddOnLoaded(name) end
  return false
end

-- Spell icon, or nil.
function GF.SpellTexture(id)
  if C_Spell and C_Spell.GetSpellTexture then
    local t = C_Spell.GetSpellTexture(id)
    if t then return t end
  end
  if GetSpellTexture then return GetSpellTexture(id) end
end

-- One merchant entry as name, texture, price, qty, numAvailable, isUsable, extended (GetMerchantItemInfo order).
function GF.MerchantItemInfo(i)
  if GetMerchantItemInfo then return GetMerchantItemInfo(i) end
  local CM = C_MerchantFrame
  if CM and CM.GetItemInfo then
    local t = CM.GetItemInfo(i)
    if type(t) == "table" then
      return t.name, t.texture, t.price, t.stackCount, t.numAvailable, t.isUsable, t.hasExtendedCost
    end
  end
end

-- itemID, type, subType, equipLoc, icon, classID, subClassID without needing the item cached; nothing if unavailable.
function GF.ItemInfoInstant(id)
  local fn = C_Item and C_Item.GetItemInfoInstant
  if not fn then return nil end
  return fn(id)
end

-- Item quality: the direct API when it exists, else from the full item info (nil while not cached).
function GF.ItemQuality(id)
  if not C_Item then return nil end
  local q = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
  if q == nil and C_Item.GetItemInfo then q = select(3, C_Item.GetItemInfo(id)) end
  return q
end
