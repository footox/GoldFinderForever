-- core/trainer_marks.lua: what a profession trainer teaches that the player's guide still needs. Pure: the recorded
-- recipes of the trainer, the names the guide wants and the names the player already knows come in; the lists and the
-- panel text come out. The panel itself is features/trainer/marks.lua.

local _, GF = ...

-- Names (lower case) of the recipes the guide still has ahead: the craft items it builds that are not done yet.
-- items = the list GF BuildGuide returns (kind "craft", done, st.what).
function GF.WantedRecipes(items)
  local out = {}
  for _, it in ipairs(type(items) == "table" and items or {}) do
    if type(it) == "table" and it.kind == "craft" and not it.done and type(it.st) == "table" and type(it.st.what) == "string" then
      out[it.st.what:lower()] = true
    end
  end
  return out
end

-- recs = { { n = name, req = skill needed, cost = copper }, ... } (what this trainer teaches, as recorded);
-- wanted / known = { [lower case name] = true }. Returns
--   used      the recipes the guide still needs, by required skill then name: { { name, req, cost } }
--   usedCost  what they cost together (only the ones with a price)
--   unpriced  how many of them have no recorded price
--   others    recipes taught here that the guide does not use and the player does not know
--   knownN    recipes taught here that the player already knows
function GF.TrainerMarks(recs, wanted, known)
  local m = { used = {}, usedCost = 0, unpriced = 0, others = 0, knownN = 0 }
  wanted, known = type(wanted) == "table" and wanted or {}, type(known) == "table" and known or {}
  for _, r in ipairs(type(recs) == "table" and recs or {}) do
    if type(r) == "table" and type(r.n) == "string" and r.n ~= "" then
      local key = r.n:lower()
      if known[key] then
        m.knownN = m.knownN + 1
      elseif wanted[key] then
        local cost = (type(r.cost) == "number" and r.cost >= 0) and r.cost or nil
        m.used[#m.used + 1] = { name = r.n, req = type(r.req) == "number" and r.req or nil, cost = cost }
        if cost then m.usedCost = m.usedCost + cost else m.unpriced = m.unpriced + 1 end
      else
        m.others = m.others + 1
      end
    end
  end
  table.sort(m.used, function(a, b)
    if (a.req or 1e9) ~= (b.req or 1e9) then return (a.req or 1e9) < (b.req or 1e9) end
    return a.name < b.name
  end)
  return m
end

-- The text of the panel: one block per profession the trainer teaches. sections = { { prof, recs, wanted, known } };
-- L = the locale table; money(copper) -> text. Game names are escaped so they can never start a colour code.
function GF.TrainerPanelLines(sections, L, money)
  local out = {}
  local function plain(s) return (tostring(s):gsub("|", "||")) end
  for _, s in ipairs(type(sections) == "table" and sections or {}) do
    local m = GF.TrainerMarks(s.recs, s.wanted, s.known)
    out[#out + 1] = "|cffffd24d" .. plain(s.prof) .. "|r"
    if #m.used == 0 then
      out[#out + 1] = L["tm.none"]
    else
      for _, u in ipairs(m.used) do
        local cost = u.cost and money(u.cost) or ("|cff9aa0a6" .. L["tm.noPrice"] .. "|r")
        if u.req then
          out[#out + 1] = string.format(L["tm.item"], plain(u.name), u.req, cost)
        else
          out[#out + 1] = string.format(L["tm.itemNoReq"], plain(u.name), cost)
        end
      end
      if m.usedCost > 0 then out[#out + 1] = string.format(L["tm.total"], money(m.usedCost)) end
    end
    if m.others > 0 then out[#out + 1] = "|cff9aa0a6" .. string.format(L["tm.others"], m.others) .. "|r" end
    if m.knownN > 0 then out[#out + 1] = "|cff9aa0a6" .. string.format(L["tm.known"], m.knownN) .. "|r" end
  end
  return out
end
