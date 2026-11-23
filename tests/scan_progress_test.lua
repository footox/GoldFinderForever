-- Offline test for features/auction/scanprogress.lua (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\scan_progress_test.lua

local GF = {}
local core = assert(loadfile("core/scan.lua"))
setfenv(core, setmetatable({}, { __index = _G }))
core("GoldFinder", GF)

local registered, frameScript
Auctionator = {
  EventBus = { Register = function(_, listener) registered = listener end },
  FullScan = { Events = { ScanStart = "FS", ScanProgress = "FP", ScanComplete = "FC", ScanFailed = "FF" } },
}
function CreateFrame()
  return { RegisterEvent = function() end, SetScript = function(_, _, f) frameScript = f end }
end

local env = setmetatable({}, { __index = _G })
local fn = assert(loadfile("features/auction/scanprogress.lua"))
setfenv(fn, env)
fn("GoldFinder", GF)

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local last
check("starts", GF.ScanProgress.Start(function(st) last = st end) == true)
registered:ReceiveEvent("FP", 0.99)
check("progress shows the scan running at 99", last.on and GF.ScanPercent(last) == 99)
frameScript()
check("closing the auction house mid-scan clears the indicator", last.on == false and last.failed == nil)
check("State() agrees", GF.ScanProgress.State().on == false)
registered:ReceiveEvent("FP", 0.5)
check("a scan that continues after reopening shows again", last.on and GF.ScanPercent(last) == 50)
registered:ReceiveEvent("FC")
last = nil
frameScript()
check("closing with no scan running changes nothing", last == nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
