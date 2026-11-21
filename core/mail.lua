-- core/mail.lua: the attachment plan of one mail for "Enviar al banquero". Pure: bag slots and the surplus
-- table come in, a plan comes out.

local _, GF = ...

-- Funcion pura. slots = { { bag, slot, id, count, locked, bound } } de las bolsas; surplus = { [id] = unidades
-- que sobran de la reserva }; maxAttach = adjuntos por correo (12). Solo pilas enteras: una pila entra si el total
-- enviado de ese objeto sigue <= su sobrante (las pilas grandes primero). Devuelve { attach (este correo),
-- skipped (con why), stacks, units, remaining (correos que quedan despues de este) }.
local OVER = "no se envia: quedaria por debajo de la reserva"
local function MailPlan(slots, surplus, maxAttach)
  maxAttach = maxAttach or 12
  local list = {}
  for _, s in ipairs(slots or {}) do
    if (surplus[s.id] or 0) > 0 and (s.count or 0) > 0 then list[#list + 1] = s end
  end
  table.sort(list, function(x, y)
    if x.id ~= y.id then return x.id < y.id end
    if x.count ~= y.count then return x.count > y.count end
    if x.bag ~= y.bag then return x.bag < y.bag end
    return x.slot < y.slot
  end)
  local p = { attach = {}, skipped = {}, stacks = 0, units = 0, remaining = 0 }
  local used, ok = {}, 0
  for _, s in ipairs(list) do
    local why
    if s.bound then why = "no se envia: ligado"
    elseif s.locked then why = "no se envia: bloqueado (espera un momento)"
    elseif (used[s.id] or 0) + s.count > surplus[s.id] then why = OVER end
    if why then
      p.skipped[#p.skipped + 1] = { bag = s.bag, slot = s.slot, id = s.id, count = s.count, why = why }
    else
      used[s.id] = (used[s.id] or 0) + s.count
      ok = ok + 1
      if #p.attach < maxAttach then
        p.attach[#p.attach + 1] = s
        p.stacks, p.units = p.stacks + 1, p.units + s.count
      end
    end
  end
  p.remaining = math.ceil((ok - #p.attach) / maxAttach)
  return p
end

GF.MailPlan = MailPlan
