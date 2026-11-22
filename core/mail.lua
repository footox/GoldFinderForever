-- core/mail.lua: the attachment plan of one mail for "Enviar al banquero". Pure: bag slots and the surplus
-- table come in, a plan comes out.

local _, GF = ...

-- Funcion pura. slots = { { bag, slot, id, count, locked, bound } } de las bolsas; surplus = { [id] = unidades
-- que sobran de la reserva }; maxAttach = adjuntos por correo (12). Solo pilas enteras: una pila entra si el total
-- enviado de ese objeto sigue <= su sobrante (las pilas grandes primero). Devuelve { attach (este correo),
-- skipped (with why: "bound", "locked" or "reserve"), stacks, units, remaining (correos que quedan despues de este) }.
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
    if s.bound then why = "bound"
    elseif s.locked then why = "locked"
    elseif (used[s.id] or 0) + s.count > surplus[s.id] then why = "reserve" end
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

-- Funcion pura. rows = filas que lista el panel ({ id, sellQty, unit }); excluded = { [id] = true } de lo que el
-- jugador desmarco. Devuelve { surplus (solo lo marcado, para MailPlan), n (objetos marcados), total (valor marcado) }.
local function MailSelect(rows, excluded)
  excluded = excluded or {}
  local sel = { surplus = {}, n = 0, total = 0 }
  for _, r in ipairs(rows or {}) do
    if not excluded[r.id] and (r.sellQty or 0) > 0 then
      sel.surplus[r.id] = r.sellQty
      sel.n = sel.n + 1
      sel.total = sel.total + (r.unit or 0) * r.sellQty
    end
  end
  return sel
end

GF.MailPlan = MailPlan
GF.MailSelect = MailSelect
