-- Offline tests for the Scan button (Lua 5.1): with the auction house closed it says so instead of failing, and the summary window has no
-- hard-coded Spanish. Run from the addon folder:  lua tests/scan_frame_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function read(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n")) end
local function loadCore(path, GF)
  local fn = assert(loadfile(path)); fn("GoldFinder", GF)
end

local GF = {}
loadCore("core/locale.lua", GF)
loadCore("locales/enUS.lua", GF)
loadCore("locales/esES.lua", GF)
loadCore("core/penguin.lua", GF)
loadCore("core/scan.lua", GF)

-- the pure part: which frame
local function frame(ok) return ok == false and {} or { InitiateScan = function() end } end
local incremental, full = frame(), frame()
local state = { IncrementalScanFrameRef = incremental, FullScanFrameRef = full }
check("replicate on: the full-scan frame", GF.ScanFrameFor(state, true) == full)
check("replicate off: the incremental frame", GF.ScanFrameFor(state, false) == incremental)
check("the auction house is closed (no incremental frame): nil", GF.ScanFrameFor({ FullScanFrameRef = full }, false) == nil)
check("the auction house is closed (no full frame): nil", GF.ScanFrameFor({ IncrementalScanFrameRef = incremental }, true) == nil)
check("it never falls back to the other frame", GF.ScanFrameFor({ IncrementalScanFrameRef = incremental }, true) == nil and GF.ScanFrameFor({ FullScanFrameRef = full }, false) == nil)
check("a frame without InitiateScan is not usable: nil", GF.ScanFrameFor({ IncrementalScanFrameRef = {} }, false) == nil)
check("no state, or a state that is not a table: nil", GF.ScanFrameFor(nil, false) == nil and GF.ScanFrameFor("x", true) == nil)

-- the button, run against a fake Auctionator: the real function is taken from the main file
local src = read("GoldFinder.lua")
local a = assert(src:find("local function StartFullScan()", 1, true), "start marker")
local b = assert(src:find("-- minutos desde el ultimo escaneo de Auctionator", a, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn StartFullScan"

local function session(auctionator, penguin)
  local S = { printed = {}, errors = 0 }
  local env = setmetatable({
    Auctionator = auctionator, GF = GF, L = GF.L, format = string.format, pcall = pcall, tostring = tostring,
    Print = function(line) S.printed[#S.printed + 1] = line end,
    Cfg = function(k) if k == "penguin" then return penguin end end,
  }, { __index = _G })
  setfenv(assert(loadstring(chunk)), env)
  S.run = setfenv(assert(loadstring(chunk)), env)()
  return S
end
local function auct(replicate, frames)
  return { State = frames, Config = { Options = { REPLICATE_SCAN = "R" }, Get = function(k) return replicate end } }
end

local called = 0
local good = { InitiateScan = function() called = called + 1 end }
local S1 = session(auct(false, { IncrementalScanFrameRef = good }), false)
S1.run()
check("with the auction house open the scan starts", called == 1)
check("and it says so (plain message)", #S1.printed == 1 and S1.printed[1] == GF.L["scan.requested"])

called = 0
local S2 = session(auct(false, {}), false)
local ok = pcall(S2.run)
check("with the auction house closed nothing is called and nothing fails", ok and called == 0)
check("it tells the player to open the auction house", #S2.printed == 1 and S2.printed[1] == GF.L["scan.openAH"])
check("and does not show a Lua error", not S2.printed[1]:find("attempt", 1, true) and not S2.printed[1]:find("nil value", 1, true))

local S3 = session(auct(true, { IncrementalScanFrameRef = good }), false)
S3.run()
check("replicate on and only the incremental frame exists: asks to open the auction house (no wrong frame called)", S3.printed[1] == GF.L["scan.openAH"])

local bad = { InitiateScan = function() error("boom") end }
local S4 = session(auct(false, { IncrementalScanFrameRef = bad }), false)
check("a scan that fails is reported, not thrown", pcall(S4.run) and S4.printed[1]:find("boom", 1, true) ~= nil)

local S5 = session({}, false)
S5.run()
check("Auctionator not ready at all: its own message", S5.printed[1] == GF.L["scan.notReady"])

local S6 = session(auct(false, { IncrementalScanFrameRef = good }), true)
S6.run()
check("with the penguin winks on, the scan line is a penguin one", S6.printed[1] ~= GF.L["scan.requested"] and S6.printed[1]:lower():find("scan requested", 1, true) ~= nil)

-- no hard-coded Spanish in the summary any more
for _, lit in ipairs({ '"PARA VENDER"', '"PARA GUARDAR"', '"SESION DE CUERO"', '"Que hacer ahora"' }) do
  check("GoldFinder.lua no longer has " .. lit, not src:find(lit, 1, true))
end
for _, k in ipairs({ "win.sumSellTitle", "win.sumKeepTitle", "win.sumSessionTitle", "win.sumNowTitle", "scan.openAH" }) do
  check("both languages have " .. k, GF.locales.enUS[k] ~= nil and GF.locales.esES[k] ~= nil)
end
check("the English titles are English", GF.locales.enUS["win.sumSellTitle"] == "TO SELL" and GF.locales.enUS["win.sumKeepTitle"] == "TO KEEP")
check("the Spanish titles keep the old text", GF.locales.esES["win.sumSellTitle"] == "PARA VENDER" and GF.locales.esES["win.sumNowTitle"] == "Que hacer ahora")
check("the summary uses the keys", src:find('Card(v, L["win.sumSellTitle"])', 1, true) ~= nil and src:find('tt:SetText(L["win.sumNowTitle"])', 1, true) ~= nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
