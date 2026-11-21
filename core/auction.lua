-- core/auction.lua: price and quantity of the one-click "Subastar" button. Pure: market data comes in, a plan comes out.

local _, GF = ...

-- Funcion pura. input: lowest (la subasta mas barata ahora), market (valor de mercado), vendor (lo que paga el
-- vendedor), available (unidades sin reservar), soldPerDay (ventas al dia en la region, opcional) y los ajustes
-- minPct, maxPct, undercut, capDays; cut = comision de la subasta; money = formato del dinero para los textos;
-- variant = equipo con variantes (no se publica con un clic). Sin market tampoco se publica con un clic, ni
-- sin lowest: sin precio de Auctionator el veredicto viene solo de TSM y hay que escanear antes (Mayus+clic vale).
-- Devuelve { post, unit, qty, reason, min, normal, max, cap }.
local function AuctionPlan(input)
  local money = input.money or tostring
  local cut = input.cut or 0.05
  local lowest = (input.lowest and input.lowest > 0) and input.lowest or nil
  local market = (input.market and input.market > 0) and input.market or nil
  local vendor = input.vendor or 0
  local p = { post = false, unit = 0, qty = 0 }
  -- equipo con variantes (sufijos "de la ..." o nivel de objeto): el precio por id no vale para la variante
  if input.variant then p.reason = "precio por variante: usa Auctionator (Mayus+clic)"; return p end
  if not (market or lowest) then p.reason = "sin precio: escanea"; return p end
  -- sin valor de mercado (TSM o historial de varios dias) la subasta mas barata sola no es fiable
  if not market then p.reason = "sin precio de referencia: usa Auctionator (Mayus+clic)"; return p end
  local ref = market
  -- minimo: % del mercado, y nunca menos de lo que paga el vendedor despues de la comision
  local vendorFloor = vendor > 0 and math.ceil(vendor * 1.05 / (1 - cut)) or 0
  p.min = math.max(math.floor(ref * (input.minPct or 60) / 100), vendorFloor, 1)
  p.max = math.max(math.floor(ref * (input.maxPct or 200) / 100), p.min)
  p.normal = math.min(math.max(math.floor(ref), p.min), p.max)
  local why
  if lowest and lowest < p.min then
    p.reason = "debajo del minimo: espera (la mas barata esta a " .. money(lowest) .. ", minimo " .. money(p.min) .. ")"
    return p
  elseif not lowest then
    p.reason = "escanea la casa de subastas antes de publicar"
    return p
  elseif lowest > p.max then
    p.unit, why = p.normal, "la mas barata (" .. money(lowest) .. ") pasa del maximo: precio normal"
  else
    local under = math.max(math.floor(input.undercut or 1), 0)
    p.unit = math.max(lowest - under, p.min)
    why = (p.unit == lowest) and ("igual a la mas barata (" .. money(lowest) .. ")")
      or (money(lowest - p.unit) .. " por debajo de la mas barata (" .. money(lowest) .. ")")
  end
  local avail = math.floor(input.available or 0)
  if avail <= 0 then p.reason = "todo reservado para tus profesiones"; return p end
  p.qty = avail
  local spd = tonumber(input.soldPerDay)
  if spd and spd > 0 then
    local cap = math.max(1, math.ceil(spd * (input.capDays or 2)))
    if avail > cap then
      p.qty, p.cap = cap, cap
      why = why .. string.format("; tope de %d por publicacion (en la region se venden ~%.1f al dia)", cap, spd)
    end
  end
  p.post, p.reason = true, why
  return p
end

GF.AuctionPlan = AuctionPlan
