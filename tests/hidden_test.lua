-- Offline tests for GF.FilterHidden (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\hidden_test.lua

local GF = {}
local f = assert(loadfile("core/hidden.lua"))
setfenv(f, setmetatable({}, { __index = _G }))
f("GoldFinder", GF)

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function rows() return { { id = 1 }, { id = 2 }, { id = 3 } } end

local out, n = GF.FilterHidden(rows(), {}, false)
check("nothing hidden: all rows, count 0", #out == 3 and n == 0)
out, n = GF.FilterHidden(rows(), { [2] = true }, false)
check("hidden item is dropped and counted", #out == 2 and n == 1 and out[1].id == 1 and out[2].id == 3)
out, n = GF.FilterHidden(rows(), { [2] = true }, true)
check("show: hidden item stays, marked userHidden", #out == 3 and n == 1 and out[2].userHidden == true and not out[1].userHidden)
out, n = GF.FilterHidden(rows(), { [1] = true, [2] = true, [3] = true }, false)
check("all hidden: empty list, count 3", #out == 0 and n == 3)
out, n = GF.FilterHidden(nil, nil, false)
check("nil input: empty", #out == 0 and n == 0)
local shared = { { id = 5, userHidden = true } }
out = GF.FilterHidden(shared, {}, false)
check("a previously hidden mark is cleared when no longer hidden", out[1].userHidden == nil)

if failures > 0 then os.exit(1) end
print("ALL PASS")
