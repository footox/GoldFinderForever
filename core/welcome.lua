-- core/welcome.lua: what the one-time welcome window lists. Pure: the option lookup and the texts come in, the lines
-- come out. The window itself is features/welcome/window.lua.

local _, GF = ...

-- id = text key prefix (welcome.<id>.n and welcome.<id>.d); opt = the option that switches the feature, nil when the
-- feature has no switch.
GF.WELCOME_ITEMS = {
  { id = "tip", opt = "tip" },
  { id = "sell", opt = "sellPanel" },
  { id = "auction" },
  { id = "mail", opt = "mailPanel" },
  { id = "shopping", opt = "shopping" },
  { id = "prof", opt = "routeTab" },
  { id = "tracker", opt = "nextSteps" },
  { id = "alts", opt = "crossChars" },
}

-- true when the window has not been shown yet. No data table (not loaded yet) never shows it.
function GF.WelcomeDue(db)
  return type(db) == "table" and db.welcomeSeen ~= true
end

-- One entry per feature: name, desc and on (true, false, or nil when the feature has no switch).
function GF.WelcomeLines(cfg, L)
  local out = {}
  for _, it in ipairs(GF.WELCOME_ITEMS) do
    local on
    if it.opt then on = cfg(it.opt) and true or false end
    out[#out + 1] = { id = it.id, name = L["welcome." .. it.id .. ".n"], desc = L["welcome." .. it.id .. ".d"], on = on }
  end
  return out
end
