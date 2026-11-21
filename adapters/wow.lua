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
