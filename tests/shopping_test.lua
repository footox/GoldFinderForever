-- Offline tests for GF.ShoppingTerms and GF.ShoppingSync (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\shopping_test.lua

local GF = {}
local fn = assert(loadfile("core/shopping.lua"))
setfenv(fn, setmetatable({}, { __index = _G }))
fn("GoldFinder", GF)

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local NAMES = { [1] = "Light Leather", [2] = "Salt", [3] = "Tiger Meat" }
local function nameOf(id) return NAMES[id] end
local created
local api = {
  ConvertToSearchString = function(caller, t) return string.format('"%s";q=%d;exact=%s', t.searchString, t.quantity, tostring(t.isExact)) end,
  CreateShoppingList = function(caller, name, terms) created = { caller = caller, name = name, terms = terms } end,
}

-- 1. Only what is missing, with exact name and quantity
local r = GF.ShoppingTerms(api, "GoldFinder", {
  { id = 1, need = 10, have = 4 }, { id = 2, need = 3, have = 3 }, { id = 3, need = 6, have = 0 } }, nameOf)
check("terms: only the missing items", #r.terms == 2 and r.count == 2)
check("terms: exact name and missing quantity", r.terms[1] == '"Light Leather";q=6;exact=true' and r.terms[2] == '"Tiger Meat";q=6;exact=true')

-- 2. Unloaded names are skipped and counted
r = GF.ShoppingTerms(api, "GoldFinder", { { id = 99, need = 5, have = 0 }, { id = 1, need = 2, have = 0 } }, nameOf)
check("terms: unloaded name skipped and counted", #r.terms == 1 and r.skipped == 1)

-- 3. Without ConvertToSearchString the plain name is used; a failing converter falls back too
r = GF.ShoppingTerms({}, "GoldFinder", { { id = 1, need = 2, have = 0 } }, nameOf)
check("terms: no converter, plain name", r.terms[1] == "Light Leather")
r = GF.ShoppingTerms({ ConvertToSearchString = function() error("boom") end }, "GoldFinder", { { id = 1, need = 2, have = 0 } }, nameOf)
check("terms: converter error falls back to the plain name", r.terms[1] == "Light Leather")

-- 4. Sync creates the list under our own name
local ok, n, skipped = GF.ShoppingSync(api, "GoldFinder", "GoldFinder", { { id = 1, need = 10, have = 4 }, { id = 99, need = 1, have = 0 } }, nameOf)
check("sync: list created with the given name and the terms", ok and n == 1 and skipped == 1
  and created.name == "GoldFinder" and created.caller == "GoldFinder" and #created.terms == 1)

-- 5. Failure modes
ok, n = GF.ShoppingSync({}, "GoldFinder", "GoldFinder", { { id = 1, need = 2, have = 0 } }, nameOf)
check("sync: no shopping list API gives noapi", ok == false and n == "noapi")
ok, n = GF.ShoppingSync(nil, "GoldFinder", "GoldFinder", {}, nameOf)
check("sync: nil api gives noapi", ok == false and n == "noapi")
created = nil
ok, n = GF.ShoppingSync(api, "GoldFinder", "GoldFinder", { { id = 2, need = 3, have = 3 } }, nameOf)
check("sync: nothing missing gives none and creates nothing", ok == false and n == "none" and created == nil)
ok, n = GF.ShoppingSync({ CreateShoppingList = function() error("auctionator failed") end }, "GoldFinder", "GoldFinder",
  { { id = 1, need = 2, have = 0 } }, nameOf)
check("sync: an API error is returned, not raised", ok == false and tostring(n):find("auctionator failed", 1, true) ~= nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
