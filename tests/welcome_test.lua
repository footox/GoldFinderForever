-- Offline tests for core/welcome.lua (Lua 5.1): when the welcome window is due and which lines it lists.
-- Run from the addon folder:  lua tests/welcome_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local GF = {}
assert(loadfile("core/welcome.lua"))("GoldFinderForever", GF)

check("due: first run", GF.WelcomeDue({}))
check("due: seen flag false", GF.WelcomeDue({ welcomeSeen = false }))
check("not due: already seen", not GF.WelcomeDue({ welcomeSeen = true }))
check("not due: data not loaded", not GF.WelcomeDue(nil))
check("not due: data is not a table", not GF.WelcomeDue("x"))

local L = setmetatable({}, { __index = function(_, k) return "<" .. k .. ">" end })
local cfgOn = { tip = true, sellPanel = true, mailPanel = false, shopping = true, routeTab = true, nextSteps = true, crossChars = true }
local lines = GF.WelcomeLines(function(k) return cfgOn[k] end, L)
check("one line per feature", #lines == #GF.WELCOME_ITEMS and #lines == 8)
local by = {}
for _, l in ipairs(lines) do by[l.id] = l end
check("text keys are welcome.<id>.n and .d", by.tip.name == "<welcome.tip.n>" and by.tip.desc == "<welcome.tip.d>")
check("an option that is on shows on", by.shopping.on == true and by.tracker.on == true)
check("an option that is off shows off", by.mail.on == false)
check("a feature without a switch has no state", by.auction.on == nil)
check("an unset option counts as off", GF.WelcomeLines(function() return nil end, L)[1].on == false)
local ids = {}
for _, it in ipairs(GF.WELCOME_ITEMS) do check("unique id " .. it.id, not ids[it.id]); ids[it.id] = true end

-- wiring: the files load, in an order that works, and the window is triggered once after login
local function read(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return (s:gsub("\13", "")) end
local toc, main = read("GoldFinderForever.toc"), read("GoldFinder.lua")
local function pos(name) return toc:find(name, 1, true) end
check("toc lists core/welcome.lua", pos("core/welcome.lua") ~= nil)
check("toc lists the window", pos("features/welcome/window.lua") ~= nil)
check("window loads after the widgets and before the main file", pos("ui/widgets.lua") < pos("features/welcome/window.lua")
  and pos("features/welcome/window.lua") < pos("GoldFinder.lua"))
check("login opens it only when due", main:find("GF.WelcomeDue(GoldFinderForeverDB)", 1, true) ~= nil)
check("command opens it again", main:find('cmd == "welcome"', 1, true) ~= nil and main:find('cmd == "bienvenida"', 1, true) ~= nil)
local win = read("features/welcome/window.lua")
check("the paragraphs wrap (Text() defaults to one line)", win:find("fs:SetWordWrap(true)", 1, true) ~= nil
  and win:find("{ f.intro, f.body, f.foot }", 1, true) ~= nil)
check("the window marks itself as seen", win:find("welcomeSeen = true", 1, true) ~= nil)
local en, es = read("locales/enUS.lua"), read("locales/esES.lua")
for _, it in ipairs(GF.WELCOME_ITEMS) do
  for _, k in ipairs({ ".n", ".d" }) do
    local key = '["welcome.' .. it.id .. k .. '"]'
    check("both languages have " .. key, en:find(key, 1, true) ~= nil and es:find(key, 1, true) ~= nil)
  end
end

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
