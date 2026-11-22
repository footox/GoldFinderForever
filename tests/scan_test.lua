-- Offline tests for GF.ScanNext and GF.ScanPercent (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\scan_test.lua

local GF = {}
local fn = assert(loadfile("core/scan.lua"))
setfenv(fn, setmetatable({}, { __index = _G }))
fn("GoldFinder", GF)

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local s = GF.ScanNext(nil, "start")
check("start: scanning at 0", s.on == true and s.pct == 0)
s = GF.ScanNext(s, "progress", 0.42)
check("progress: keeps the fraction", s.on and math.abs(s.pct - 0.42) < 1e-9 and GF.ScanPercent(s) == 42)
s = GF.ScanNext(s, "progress", 1.7)
check("progress above 1 is clamped, and shows 99 while running", s.pct == 1 and GF.ScanPercent(s) == 99)
s = GF.ScanNext(s, "progress", -3)
check("progress below 0 is clamped", s.pct == 0)
s = GF.ScanNext(s, "progress", "x")
check("progress with a non-number keeps the previous value", s.pct == 0)
s = GF.ScanNext({ on = true, pct = 0.5 }, "complete")
check("complete: stopped at 100", s.on == false and s.pct == 1 and GF.ScanPercent(s) == 100)
s = GF.ScanNext({ on = true, pct = 0.5 }, "failed")
check("failed: stopped and flagged", s.on == false and s.failed == true and GF.ScanPercent(s) == 0)
s = GF.ScanNext(nil, "progress", 0.3)
check("progress without a start still shows the scan", s.on and GF.ScanPercent(s) == 30)
check("unknown event leaves the state alone", GF.ScanNext({ on = true, pct = 0.2 }, "nope").pct == 0.2)
check("nil state gives 0", GF.ScanPercent(nil) == 0)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
