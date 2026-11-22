-- core/hidden.lua: the per-character "Ocultar" filter of the Bolsas list. Pure: rows come in with the set of hidden
-- item ids, the rows to list come out. It only filters the list; decisions, the vendor panel and the mail panel
-- do not change.

local _, GF = ...

-- rows = { { id, ... } }; hide = { [id] = true }; show = true to list the hidden items too (marked userHidden).
-- Returns the visible rows (the same tables, userHidden set on hidden ones) and how many are hidden.
function GF.FilterHidden(rows, hide, show)
  hide = hide or {}
  local out, n = {}, 0
  for _, r in ipairs(rows or {}) do
    if hide[r.id] then
      n = n + 1
      if show then r.userHidden = true; out[#out + 1] = r end
    else
      r.userHidden = nil
      out[#out + 1] = r
    end
  end
  return out, n
end
