-- Offline tests for adapters/auctionator_keys.lua (Lua 5.1): does a link have an entry of its own in Auctionator's database?
-- Run from the addon folder:  lua tests/variant_known_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local function fresh(A)
  local GF = {}
  local env = setmetatable({ Auctionator = A }, { __index = _G })
  env._G = env
  local fn = assert(loadfile("adapters/auctionator_keys.lua"))
  setfenv(fn, env)
  fn("GoldFinder", GF)
  return GF
end

local LINK = "|cff1eff00|Hitem:1111::::::::30:::::::::|h[Staff of the Eagle]|h|r"
local function auctionator(keys, db, mode)
  return {
    Database = { db = db },
    Utilities = { DBKeyFromLink = function(link, cb)
      if mode == "error" then error("boom") end
      if mode == "later" then return end            -- the callback would be called after the item data loads
      cb(keys)
    end },
  }
end

check("the variant's own entry exists: true", fresh(auctionator({ "gr:1111:Eagle", "1111" }, { ["gr:1111:Eagle"] = { m = 15000 }, ["1111"] = { m = 4400 } })).VariantKnown(LINK) == true)
check("only the generic entry exists: false", fresh(auctionator({ "gr:1111:Eagle", "1111" }, { ["1111"] = { m = 4400 } })).VariantKnown(LINK) == false)
check("neither entry exists: false (the link price cannot come from the variant)", fresh(auctionator({ "gr:1111:Eagle", "1111" }, {})).VariantKnown(LINK) == false)
check("an item with a single key has no variants: true", fresh(auctionator({ "1111" }, { ["1111"] = { m = 4400 } })).VariantKnown(LINK) == true)
check("a single key with no entry is still no variants: true", fresh(auctionator({ "1111" }, {})).VariantKnown(LINK) == true)
check("only the FIRST key counts (the generic one is not proof)", fresh(auctionator({ "g:1111:60", "1111" }, { ["1111"] = { m = 1 } })).VariantKnown(LINK) == false)
check("the item-level key works the same way", fresh(auctionator({ "g:1111:60", "1111" }, { ["g:1111:60"] = { m = 1 } })).VariantKnown(LINK) == true)

check("the callback never comes (item data not loaded): nil", fresh(auctionator({ "gr:1111:Eagle", "1111" }, {}, "later")).VariantKnown(LINK) == nil)
check("Auctionator's key function throws: nil, never an error", fresh(auctionator({}, {}, "error")).VariantKnown(LINK) == nil)
check("an empty key list: nil", fresh(auctionator({}, {})).VariantKnown(LINK) == nil)
check("keys that are not a table: nil", fresh(auctionator("x", {})).VariantKnown(LINK) == nil)

check("no Auctionator: nil", fresh(nil).VariantKnown(LINK) == nil)
check("Auctionator without a database: nil", fresh({ Utilities = { DBKeyFromLink = function() end } }).VariantKnown(LINK) == nil)
check("Auctionator without the key function: nil", fresh({ Database = { db = {} }, Utilities = {} }).VariantKnown(LINK) == nil)
check("a database that is not a table: nil", fresh({ Database = { db = "x" }, Utilities = { DBKeyFromLink = function() end } }).VariantKnown(LINK) == nil)
check("a link that is not a string: nil", fresh(auctionator({ "1" }, {})).VariantKnown(nil) == nil and fresh(auctionator({ "1" }, {})).VariantKnown(42) == nil)

-- wiring
local function read(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n")) end
check("the file is in the toc", read("GoldFinderForever.toc"):find("adapters/auctionator_keys.lua", 1, true) ~= nil)
check("the decision gets it", read("GoldFinder.lua"):find("VariantKnown = GF.VariantKnown,", 1, true) ~= nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
