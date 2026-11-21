-- core/locale.lua: one lookup for every user-facing string. GF.L[key] returns the text of the active language, falls back
-- to English (enUS, the base) and, if the key does not exist anywhere, returns the key itself and records it in
-- GF.MissingKeys so a typo is visible. Locale tables live in locales/*.lua and register themselves in GF.locales.
-- Internal tokens (verdicts, SavedVariables keys) never go through here.

local _, GF = ...

GF.locales = GF.locales or {}
GF.MissingKeys = GF.MissingKeys or {}

local active = "enUS"

GF.L = setmetatable({}, {
  __index = function(_, key)
    local t, base = GF.locales[active], GF.locales.enUS
    local v = t and t[key]
    if v == nil then v = base and base[key] end
    if v == nil then
      GF.MissingKeys[key] = true
      return tostring(key)
    end
    return v
  end,
})

-- The language to use: the user's setting ("auto", "enUS" or "esES") or, for "auto", the client's. Spanish clients
-- (esES, esMX) get Spanish; every other client gets English.
function GF.ResolveLocale(setting, clientLocale)
  if setting == "enUS" or setting == "esES" then return setting end
  if clientLocale == "esES" or clientLocale == "esMX" then return "esES" end
  return "enUS"
end

-- Selects the active language ("esES" or, for anything else, "enUS"). The locale tables may load after this file, so the
-- name is only checked when a key is read.
function GF.SetLocale(name)
  active = (name == "esES") and "esES" or "enUS"
  return active
end

function GF.ActiveLocale() return active end

-- Until the saved setting is read (ADDON_LOADED), follow the client.
if type(GetLocale) == "function" then GF.SetLocale(GF.ResolveLocale("auto", GetLocale())) end
