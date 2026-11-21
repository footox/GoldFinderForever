-- core/vendor.lua: which bag items the merchant panel offers to sell. Pure: rows come from the decision, the
-- reservation lookup is passed in.

local _, GF = ...

-- rows: filas de BagRows (verdict, vendor, count, quest). qtyFn(id) opcional: unidades que se pueden vender
-- (sin lo reservado). Devuelve las filas a vender (qty, value) de mas a menos valor y el total.
local function VendorSellRows(rows, qtyFn)
  local list, total = {}, 0
  for _, r in ipairs(rows or {}) do
    local price = r.vendor or 0
    if r.verdict == "VENDOR" and price > 0 and not r.quest and (r.count or 0) > 0 then
      local qty = r.count
      if qtyFn then qty = math.min(qty, qtyFn(r.id) or qty) end
      if qty > 0 then
        local e = { id = r.id, qty = qty, count = r.count, vendor = price, value = qty * price }
        list[#list + 1] = e
        total = total + e.value
      end
    end
  end
  table.sort(list, function(x, y)
    if x.value ~= y.value then return x.value > y.value end
    return x.id < y.id
  end)
  return list, total
end

GF.VendorSellRows = VendorSellRows
