-- Offline tests for VendorSellRows (Lua 5.1): the merchant panel lists only the bag items the decision sends to
-- the vendor, with a vendor price, sorted by value, and with the right total. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\sell_panel_test.lua

local src = assert(io.open("GoldFinder.lua")):read("*a")
local a = assert(src:find("-- VENTA AL VENDEDOR: filas del panel", 1, true), "start marker")
local b = assert(src:find("-- FIN DE VENTA AL VENDEDOR", 1, true), "end marker")
local chunk = src:sub(a, b - 1) .. "\nreturn VendorSellRows"
local f = assert(loadstring(chunk))
setfenv(f, setmetatable({}, { __index = _G }))
local VendorSellRows = f()

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local rows = {
  { id = 1, verdict = "VENDOR", vendor = 100, count = 3 },               -- 300
  { id = 2, verdict = "KEEP", vendor = 500, count = 10, manual = true }, -- pinned
  { id = 3, verdict = "AH", vendor = 50, count = 4 },                    -- auction
  { id = 4, verdict = "VENDOR", vendor = 2000, count = 1 },              -- 2000
  { id = 5, verdict = "VENDOR", vendor = 0, count = 7 },                 -- no vendor price
  { id = 6, verdict = "NONE", vendor = 0, count = 1, bound = true },     -- soulbound, no price
  { id = 7, verdict = "VENDOR", vendor = 40, count = 20, quest = true }, -- quest item
  { id = 8, verdict = "VENDOR", vendor = 25, count = 40 },               -- 1000
}

local list, total = VendorSellRows(rows)
local ids = {}
for i, r in ipairs(list) do ids[i] = r.id end
check("only vendor items with a vendor price", #list == 3)
check("keep and auction items excluded", table.concat(ids, ",") ~= "" and not table.concat(ids, ","):find("[23]"))
check("no price, bound and quest items excluded", not table.concat(ids, ","):find("[567]"))
check("sorted by value descending", table.concat(ids, ",") == "4,8,1")
check("value is count x vendor price", list[1].value == 2000 and list[2].value == 1000 and list[3].value == 300)
check("total is the sum of count x price", total == 3300)

-- Reserved units (qty function) lower the count and the value; nothing left to sell drops the row.
local list2, total2 = VendorSellRows(rows, function(id) if id == 8 then return 10 elseif id == 1 then return 0 end end)
check("reserve lowers the quantity", #list2 == 2 and list2[2].id == 8 and list2[2].qty == 10 and list2[2].value == 250)
check("total with reserve", total2 == 2250)

local empty, t0 = VendorSellRows({})
check("empty list", #empty == 0 and t0 == 0)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
