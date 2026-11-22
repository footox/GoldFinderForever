-- core/auction.lua: price and quantity of the one-click "Subastar" button. Pure: market data comes in, a plan comes out.

local _, GF = ...

local L, format = GF.L, string.format

-- Funcion pura. input: lowest (la subasta mas barata ahora), market (valor de mercado), vendor (lo que paga el
-- vendedor), available (unidades sin reservar), soldPerDay (ventas al dia en la region, opcional) y los ajustes
-- minPct, maxPct, undercut, capDays; cut = comision de la subasta; money = formato del dinero para los textos;
-- variant = equipo con variantes (no se publica con un clic). Sin market tampoco se publica con un clic, ni
-- sin lowest: sin precio de Auctionator el veredicto viene solo de TSM y hay que escanear antes (Mayus+clic vale).
-- Devuelve { post, unit, qty, reason, code, min, normal, max, cap }; code ("variant", "noprice", "noref", "belowMin",
  -- "scan", "reserved") no depende del idioma.
local function AuctionPlan(input)
  local money = input.money or tostring
  local cut = input.cut or 0.05
  local lowest = (input.lowest and input.lowest > 0) and input.lowest or nil
  local market = (input.market and input.market > 0) and input.market or nil
  local vendor = input.vendor or 0
  local p = { post = false, unit = 0, qty = 0 }
  -- equipo con variantes (sufijos "de la ..." o nivel de objeto): el precio por id no vale para la variante
  if input.variant then p.code, p.reason = "variant", L["auction.reason.variant"]; return p end
  if not (market or lowest) then p.code, p.reason = "noprice", L["auction.reason.noprice"]; return p end
  -- sin valor de mercado (TSM o historial de varios dias) la subasta mas barata sola no es fiable
  if not market then p.code, p.reason = "noref", L["auction.reason.noref"]; return p end
  local ref = market
  -- minimo: % del mercado, y nunca menos de lo que paga el vendedor despues de la comision
  local vendorFloor = vendor > 0 and math.ceil(vendor * 1.05 / (1 - cut)) or 0
  p.min = math.max(math.floor(ref * (input.minPct or 60) / 100), vendorFloor, 1)
  p.max = math.max(math.floor(ref * (input.maxPct or 200) / 100), p.min)
  p.normal = math.min(math.max(math.floor(ref), p.min), p.max)
  local why
  if lowest and lowest < p.min then
    p.code, p.reason = "belowMin", format(L["auction.reason.belowMin"], money(lowest), money(p.min))
    return p
  elseif not lowest then
    p.code, p.reason = "scan", L["auction.reason.scanFirst"]
    return p
  elseif lowest > p.max then
    p.unit, why = p.normal, format(L["auction.why.overMax"], money(lowest))
  else
    local under = math.max(math.floor(input.undercut or 1), 0)
    p.unit = math.max(lowest - under, p.min)
    why = (p.unit == lowest) and format(L["auction.why.equal"], money(lowest))
      or format(L["auction.why.under"], money(lowest - p.unit), money(lowest))
  end
  local avail = math.floor(input.available or 0)
  if avail <= 0 then p.code, p.reason = "reserved", L["auction.reason.allReserved"]; return p end
  p.qty = avail
  local spd = tonumber(input.soldPerDay)
  if spd and spd > 0 then
    local cap = math.max(1, math.ceil(spd * (input.capDays or 2)))
    if avail > cap then
      p.qty, p.cap = cap, cap
      why = why .. format(L["auction.why.cap"], cap, spd)
    end
  end
  p.post, p.reason = true, why
  return p
end

GF.AuctionPlan = AuctionPlan

-- Funcion pura: dado cuanto hace del ultimo escaneo (minutos, nil si no hay) y el maximo aceptado (minutos; 0 o
-- menos lo desactiva), dice si hay que revisar el precio en vivo antes de publicar.
function GF.AuctionNeedsLive(ageMin, maxMin)
  maxMin = tonumber(maxMin) or 0
  if maxMin <= 0 then return false end
  return ageMin == nil or ageMin > maxMin
end

-- Funcion pura: de las primeras subastas de la consulta ({ { price, mine } }) el precio mas bajo que no es tuyo; si
-- todas son tuyas, el mas bajo de todas. nil si no hay ninguna con precio.
function GF.AuctionPickLowest(rows)
  local best, bestAny
  for _, r in ipairs(rows or {}) do
    local p = tonumber(r.price)
    if p and p > 0 then
      if not bestAny or p < bestAny then bestAny = p end
      if not r.mine and (not best or p < best) then best = p end
    end
  end
  return best or bestAny
end

-- Funcion pura: cambio del precio en vivo frente al guardado, en %; nil si falta alguno.
function GF.AuctionDrift(stored, live)
  stored, live = tonumber(stored), tonumber(live)
  if not (stored and live and stored > 0) then return nil end
  return (live - stored) / stored * 100
end

-- Funcion pura: valor de un campo numerico de opciones de subasta. text puede ser texto; se redondea y se limita a
-- [lo, hi]; con isDuration solo vale 12 o 24. nil si no es un numero.
function GF.AuctionClampOption(text, lo, hi, isDuration)
  local v = tonumber(text)
  if not v then return nil end
  v = math.min(math.max(math.floor(v + 0.5), lo), hi)
  if isDuration then v = (v <= 12) and 12 or 24 end
  return v
end
