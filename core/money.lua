-- core/money.lua: copper formatting. Pure: the game's coin-texture formatter is injected as GF.CoinText.

local _, GF = ...

function GF.Money(c)
  c = math.floor(c or 0)
  local text = GF.CoinText and GF.CoinText(c)
  if text then return text end
  return string.format("%dg %ds %dc", math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end

-- Compact money for narrow columns: no copper from 1 gold and no silver from 100 gold.
function GF.ShortMoney(c)
  c = math.floor(c or 0)
  if c >= 1000000 then c = math.floor(c / 10000) * 10000
  elseif c >= 10000 then c = math.floor(c / 100) * 100 end
  return GF.Money(c)
end
