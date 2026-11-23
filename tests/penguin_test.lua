-- Offline tests for core/penguin.lua (Lua 5.1): the penguin winks. Run from the addon folder:  lua tests/penguin_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function read(p)
  local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n"))
end
local function loadCore(path, GF)
  local fn = assert(loadfile(path)); fn("GoldFinder", GF)
end

local GF = {}
loadCore("core/locale.lua", GF)
loadCore("locales/enUS.lua", GF)
loadCore("locales/esES.lua", GF)
loadCore("core/penguin.lua", GF)

local function count(tbl, group) local n = 0 while tbl[group .. "." .. (n + 1)] do n = n + 1 end return n end
local en, es = GF.locales.enUS, GF.locales.esES

for _, g in ipairs({ "penguin.hello", "penguin.cmd", "penguin.scan" }) do
  check(g .. ": there are phrases", count(en, g) >= 3)
  check(g .. ": Spanish has as many as English", count(es, g) == count(en, g))
  local allText = true
  for i = 1, count(en, g) do
    local a, b = en[g .. "." .. i], es[g .. "." .. i]
    if type(a) ~= "string" or a == "" or type(b) ~= "string" or b == "" then allText = false end
  end
  check(g .. ": every phrase has text in both languages", allText)
end

-- the scan phrases replace the plain message, so each one must still say what happened
local scanOk = true
for i = 1, count(en, "penguin.scan") do
  local a, b = en["penguin.scan." .. i]:lower(), es["penguin.scan." .. i]:lower()
  if not (a:find("scan requested", 1, true) and a:find("window updates", 1, true)) then scanOk = false end
  if not (b:find("escaneo pedido", 1, true) and b:find("ventana se actualiza", 1, true)) then scanOk = false end
end
check("every scan phrase still says the scan was requested and that the window updates", scanOk)

-- no accents or special characters in the Spanish file's new phrases
local esSrc = read("locales/esES.lua")
local a0 = esSrc:find('["penguin.hello.1"]', 1, true)
local a1 = esSrc:find('["penguin.scan.4"]', 1, true)
check("Spanish phrases have no accents (the file's convention)", a0 and a1 and not esSrc:sub(a0, a1 + 200):find("[\128-\255]"))

-- picking
GF.SetLocale("enUS")
check("it picks the phrase the generator asks for", GF.PenguinPhrase("penguin.cmd", function() return 3 end) == en["penguin.cmd.3"])
check("the generator is asked for a number between 1 and the count", (function()
  local asked
  GF.PenguinPhrase("penguin.cmd", function(n) asked = n; return 1 end)
  return asked == count(en, "penguin.cmd")
end)())
check("a bad number falls back to the first phrase", GF.PenguinPhrase("penguin.hello", function() return 99 end) == en["penguin.hello.1"]
  and GF.PenguinPhrase("penguin.hello", function() return 0 end) == en["penguin.hello.1"])
check("an unknown group gives nothing, without recording a missing key", GF.PenguinPhrase("penguin.nothing") == nil and GF.MissingKeys["penguin.nothing.1"] == nil)
GF.SetLocale("esES")
check("the active language is used", GF.PenguinPhrase("penguin.cmd", function() return 3 end) == es["penguin.cmd.3"])
GF.SetLocale("enUS")
check("with no generator it still returns a phrase", type(GF.PenguinPhrase("penguin.scan")) == "string")

-- when the greeting at login is due
check("the greeting comes one login in four", GF.PenguinLoginDue(true, false, function() return 1 end) == true
  and GF.PenguinLoginDue(true, false, function() return 2 end) == false and GF.PenguinLoginDue(true, false, function() return 4 end) == false)
check("the generator is asked for 1 to 4", (function() local asked; GF.PenguinLoginDue(true, false, function(n) asked = n; return 1 end); return asked == 4 end)())
check("never when the option is off", GF.PenguinLoginDue(false, false, function() return 1 end) == false and GF.PenguinLoginDue(nil, false, function() return 1 end) == false)
check("never on the first run, where the welcome window is shown", GF.PenguinLoginDue(true, true, function() return 1 end) == false)

-- wiring
local main = read("GoldFinder.lua")
check("the file is in the toc", read("GoldFinderForever.toc"):find("core/penguin.lua", 1, true) ~= nil)
check("the option exists and is on by default", read("core/config.lua"):find("penguin = true", 1, true) ~= nil)
check("the option is on the settings page and in the options panel", main:find('{ "penguin", L["set.penguin"] }', 1, true) ~= nil
  and main:find('check("penguin", L["opt.penguin.l"], L["opt.penguin.t"])', 1, true) ~= nil)
check("the scan line is the penguin one only when the option is on, else the plain message",
  main:find('Print((Cfg("penguin") and GF.PenguinPhrase("penguin.scan")) or L["scan.requested"])', 1, true) ~= nil)
check("the greeting at login respects the option and the first run", main:find('GF.PenguinLoginDue(Cfg("penguin"), firstRun)', 1, true) ~= nil
  and main:find("local firstRun = GF.WelcomeDue(GoldFinderForeverDB)", 1, true) ~= nil)
check("/gff penguin answers whatever the option says", main:find('cmd == "penguin" or cmd == "pingu" or cmd == "pinguino"', 1, true) ~= nil
  and main:find('Print(GF.PenguinPhrase("penguin.cmd") or "Noot noot!")', 1, true) ~= nil)
check("the easter egg is not in the help text", not read("locales/enUS.lua"):match('%["cmd.help"%] = "[^\n]*penguin') and not read("locales/esES.lua"):match('%["cmd.help"%] = "[^\n]*pinguino'))
for _, k in ipairs({ "set.penguin", "opt.penguin.l", "opt.penguin.t" }) do
  check("both languages have " .. k, en[k] ~= nil and es[k] ~= nil)
end

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
