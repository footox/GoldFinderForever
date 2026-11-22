-- Offline tests for core/locale.lua and the locale tables (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\locale_test.lua
-- Checks the lookup and fallback, the language choice, and (over the real locale files) that Spanish never has a key
-- English lacks, that placeholders match, and that every key used in the source exists.

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local function load(path, GF, env)
  local f = assert(loadfile(path))
  setfenv(f, setmetatable(env or {}, { __index = _G }))
  f("GoldFinder", GF)
end

-- lookup and fallback, with small fake tables
local GF = {}
load("core/locale.lua", GF)
GF.locales.enUS = { hello = "Hello", only_en = "Only English", fmt = "%d of %s" }
GF.locales.esES = { hello = "Hola", fmt = "%d de %s" }
check("starts in English without a client", GF.ActiveLocale() == "enUS" and GF.L.hello == "Hello")
GF.SetLocale("esES")
check("Spanish when selected", GF.L.hello == "Hola" and GF.L.fmt == "%d de %s")
check("missing Spanish key falls back to English", GF.L.only_en == "Only English")
check("unknown key returns the key and is recorded", GF.L.nope == "nope" and GF.MissingKeys.nope == true)
GF.SetLocale("fr")
check("unknown language leaves English", GF.ActiveLocale() == "enUS")

-- the language choice
check("auto: Spanish client", GF.ResolveLocale("auto", "esES") == "esES" and GF.ResolveLocale("auto", "esMX") == "esES")
check("auto: any other client is English", GF.ResolveLocale("auto", "enUS") == "enUS"
  and GF.ResolveLocale("auto", "deDE") == "enUS" and GF.ResolveLocale(nil, nil) == "enUS")
check("setting wins over the client", GF.ResolveLocale("enUS", "esES") == "enUS" and GF.ResolveLocale("esES", "enUS") == "esES")
check("garbage setting behaves as auto", GF.ResolveLocale("klingon", "esMX") == "esES")

-- follows the client at load time
local GF3 = {}
load("core/locale.lua", GF3, { GetLocale = function() return "esMX" end })
check("a Spanish client starts in Spanish", GF3.ActiveLocale() == "esES")

-- the real tables
local R = {}
load("core/locale.lua", R)
load("locales/enUS.lua", R)
load("locales/esES.lua", R)
local en, es = R.locales.enUS, R.locales.esES
local function placeholders(s)
  local t = {}
  for p in s:gmatch("%%[%d%.%-]*[sdfx]") do t[#t + 1] = p end
  table.sort(t)
  return table.concat(t, ",")
end
local extra, mismatch = {}, {}
for k, v in pairs(es) do
  if en[k] == nil then extra[#extra + 1] = k
  elseif placeholders(v) ~= placeholders(en[k]) then mismatch[#mismatch + 1] = k end
end
check("Spanish has no key English lacks" .. (#extra > 0 and (": " .. table.concat(extra, ", ")) or ""), #extra == 0)
check("placeholders match between languages" .. (#mismatch > 0 and (": " .. table.concat(mismatch, ", ")) or ""),
  #mismatch == 0)
local empty = {}
for k, v in pairs(en) do if type(v) ~= "string" or v == "" then empty[#empty + 1] = k end end
check("no empty English text", #empty == 0)

-- every L.key / L["key"] used in the source exists in English
local files = { "GoldFinder.lua" }
for _, dir in ipairs({ "core", "adapters", "ui", "features/vendor", "features/mail", "features/auction",
  "features/professions", "features/guide", "features/route", "features/tracker" }) do
  local p = io.popen('dir /b "' .. dir:gsub("/", "\\") .. '\*.lua" 2>nul')
  if p then
    for name in p:lines() do files[#files + 1] = dir .. "/" .. name end
    p:close()
  end
end
local unknown = {}
for _, path in ipairs(files) do
  local fh = io.open(path)
  if fh then
    local src = fh:read("*a")
    fh:close()
    for key in src:gmatch('L%[%s*"([^"]+)"%s*%]') do
      if en[key] == nil then unknown[#unknown + 1] = path .. ": " .. key end
    end
  end
end
check("every key used in the source exists in English" .. (#unknown > 0 and ("\n  " .. table.concat(unknown, "\n  ")) or ""),
  #unknown == 0)

-- keys built at run time (prefix .. code) must exist for every code the core can return
local dynamic = { "mail.skip.reserve", "mail.skip.bound", "mail.skip.locked" }
local missingDyn = {}
for _, k in ipairs(dynamic) do if en[k] == nil or es[k] == nil then missingDyn[#missingDyn + 1] = k end end
check("run-time keys exist in both languages" .. (#missingDyn > 0 and (": " .. table.concat(missingDyn, ", ")) or ""),
  #missingDyn == 0)

if failures > 0 then os.exit(1) end
print("locale tests ok")
