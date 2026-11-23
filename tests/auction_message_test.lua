-- Offline tests for the "auction gains little" message (Lua 5.1): GF.UnitsForAuction follows the same rule as Decide, and the tooltip
-- says how little, what the minimum is and how many units would make it worth posting.
-- Run from the addon folder:  lua tests/auction_message_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function read(p)
  local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n"))
end
local function loadCore(path, GF, env)
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable(env or {}, { __index = _G }))
  fn("GoldFinder", GF)
end

local GF = {}
loadCore("core/config.lua", GF)
loadCore("core/locale.lua", GF)
loadCore("locales/enUS.lua", GF)
do local f = io.open("core/crates.lua", "rb"); if f then f:close(); loadCore("core/crates.lua", GF) end end
loadCore("core/decision.lua", GF, { GoldFinderForeverDB = {} })

-- the rule Decide applies, written out again here to compare against
local function worth(ahNet, vendor, qty, minGain)
  return ahNet > vendor * 1.10 and (ahNet - vendor) * qty >= minGain
end

-- the real cases: jarabe (net 492, vendor 95), carne misteriosa (net 190, vendor 87), manual (net 4177, vendor 1500); min 2000
check("the water-breathing potion needs 6 units", GF.UnitsForAuction(492, 95, 2000) == 6)
check("the mysterious meat needs 20 units", GF.UnitsForAuction(190, 87, 2000) == 20)
check("the manual needs 1 unit (it already compensates)", GF.UnitsForAuction(4177, 1500, 2000) == 1)

-- it follows the rule: with the units it says, the auction is worth it; with one fewer it is not
local agree, tried = true, 0
for _, ah in ipairs({ 120, 190, 333, 492, 1000, 2500, 4177, 15000 }) do
  for _, v in ipairs({ 10, 87, 95, 300, 1500, 4000 }) do
    for _, mg in ipairs({ 0, 500, 2000, 10000 }) do
      local n = GF.UnitsForAuction(ah, v, mg)
      tried = tried + 1
      if ah > v * 1.10 then
        if not n or not worth(ah, v, n, mg) then agree = false end
        if n and n > 1 and worth(ah, v, n - 1, mg) then agree = false end
      else
        if n ~= nil then agree = false end
      end
    end
  end
end
check("for " .. tried .. " price pairs it agrees with the rule: enough with n, not enough with n-1", agree)

-- no quantity can do it
check("a margin under 10% never compensates: nil", GF.UnitsForAuction(100, 95, 2000) == nil and GF.UnitsForAuction(104, 95, 2000) == nil)
check("exactly 10% is not enough either (the rule is strictly greater)", GF.UnitsForAuction(110, 100, 0) == nil)
check("auction below the vendor: nil", GF.UnitsForAuction(50, 95, 2000) == nil)
check("no price: nil, never an error", GF.UnitsForAuction(nil, 95, 2000) == nil and GF.UnitsForAuction(0, 95, 2000) == nil and GF.UnitsForAuction(100, nil, 2000) == nil)
check("a minimum of nothing: one unit is enough", GF.UnitsForAuction(492, 95, nil) == 1 and GF.UnitsForAuction(492, 95, 0) == 1)
check("it never says zero units", GF.UnitsForAuction(5000, 10, 1) >= 1)

-- the tooltip
local main = read("GoldFinder.lua")
check("the tooltip asks how many units are needed", main:find('GF.UnitsForAuction(d.ahNet, d.vendor, minGain)', 1, true) ~= nil)
check("the detailed line is shown only when more units than you have would be needed", main:find("elseif need > n then", 1, true) ~= nil)
check("under 10% it says the margin is the problem", main:find('tooltip:AddLine(L["tip.littleMargin"], 1, 0.8, 0.4)', 1, true) ~= nil)
check("otherwise it says the gain, the quantity and the minimum", main:find('format(L["tip.littleGainDetail"], Money(gain), n, Money(minGain))', 1, true) ~= nil)
check("and how many units would do, only when it is a reasonable number", main:find('if need <= 1000 then tooltip:AddLine(format(L["tip.littleGainNeed"], need)', 1, true) ~= nil)
check("the old generic line stays as a last fallback", main:find('tooltip:AddLine(L["tip.littleGain"], 1, 0.8, 0.4)', 1, true) ~= nil)
local en, es = GF.locales.enUS, GF.locales.esES or (function() loadCore("locales/esES.lua", GF); return GF.locales.esES end)()
for _, k in ipairs({ "tip.littleMargin", "tip.littleGainDetail", "tip.littleGainNeed" }) do
  check("both languages have " .. k, en[k] ~= nil and es[k] ~= nil)
end
check("the detail line has three placeholders in order (gain, units, minimum)", select(2, en["tip.littleGainDetail"]:gsub("%%[sd]", "")) == 3
  and select(2, es["tip.littleGainDetail"]:gsub("%%[sd]", "")) == 3)
check("the 'units needed' line has one number", select(2, en["tip.littleGainNeed"]:gsub("%%d", "")) == 1 and select(2, es["tip.littleGainNeed"]:gsub("%%d", "")) == 1)
check("they format without error", pcall(string.format, en["tip.littleGainDetail"], "7s", 2, "20s") and pcall(string.format, es["tip.littleGainNeed"], 6))

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
