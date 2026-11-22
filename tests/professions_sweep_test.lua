-- Offline sweep over every profession the addon ships data for (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\professions_sweep_test.lua
-- It uses the REAL data files (GoldFinderGuides, GoldFinderRecipes): the guide bands must be well formed and point to
-- real recipes, GuideMerge must work at many skill levels, gathering guides must cover 1-300, and the route planner
-- must produce a route for every crafting profession when every recipe is known. It does not replace playing them.

local function loadData(path)
  local env = setmetatable({}, { __index = _G })
  local fn = assert(loadfile(path))
  setfenv(fn, env)
  fn("GoldFinder", {})
  return env
end
local Guides = loadData("GoldFinderGuides.lua").GoldFinderGuides
local Recipes = loadData("GoldFinderRecipes.lua").GoldFinderRecipes

local GF = {}
for _, path in ipairs({ "core/config.lua", "core/guide.lua", "core/routeplanner.lua" }) do
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable({}, { __index = _G }))
  fn("GoldFinder", GF)
end

local failures = 0
local function check(name, cond, detail)
  if cond then print("PASS " .. name)
  else print("FAIL " .. name .. (detail and (" -- " .. tostring(detail)) or "")); failures = failures + 1 end
end

local keys = {}
for k in pairs(Guides) do keys[#keys + 1] = k end
table.sort(keys)
check("the guide list is not empty", #keys >= 11, #keys)

local RANKS = { 1, 35, 75, 100, 150, 200, 250, 299 }

for _, key in ipairs(keys) do
  local g = Guides[key]
  local label = g.name or key
  if g.bands then
    -- crafting profession: bands are contiguous and every band points at a real recipe of this skill line
    local ok, gaps, badRecipe, badSpan = true, nil, nil, nil
    local prev
    for i, b in ipairs(g.bands) do
      if not (b.f and b.t and b.f < b.t) then badSpan = badSpan or i end
      if prev and b.f ~= prev.t then gaps = gaps or string.format("band %d starts %s after %s", i, tostring(b.f), tostring(prev.t)) end
      local rec = b.s and Recipes.spells[b.s]
      if not (rec and rec.s == g.line) then badRecipe = badRecipe or string.format("band %d (%s) spell %s", i, tostring(b.n), tostring(b.s)) end
      prev = b
    end
    check(label .. ": bands have f < t", not badSpan, badSpan)
    check(label .. ": bands are contiguous", not gaps, gaps)
    check(label .. ": every band points at a recipe of this skill line", not badRecipe, badRecipe)
    check(label .. ": the guide reaches skill 300", g.bands[#g.bands].t >= 300, g.bands[#g.bands].t)

    -- GuideMerge at several skill levels: one row per band, exactly one current (or all done at the cap)
    for _, rank in ipairs(RANKS) do
      local okM, rows = pcall(GF.GuideMerge, g.bands, {
        rank = rank, known = {}, trainer = {}, plan = nil,
        recipe = function(id) return Recipes.spells[id] end,
        have = function() return 0 end, price = function() return 100 end,
      })
      local cur = 0
      for _, r in ipairs(okM and rows or {}) do if r.current then cur = cur + 1 end end
      check(label .. ": guide merges at skill " .. rank, okM and #rows == #g.bands and cur == 1,
        okM and ("rows=" .. #rows .. " current=" .. cur) or rows)
    end
  elseif g.zones then
    -- gathering profession: every skill level falls in exactly one zone band
    local bad
    for _, rank in ipairs(RANKS) do
      local hits = 0
      for _, z in ipairs(g.zones) do if z[1] <= rank and rank < z[2] then hits = hits + 1 end end
      if hits ~= 1 then bad = bad or ("skill " .. rank .. " matches " .. hits .. " zone bands") end
    end
    check(label .. ": zones cover every sampled skill level once", not bad, bad)
    check(label .. ": every zone band has a place name", (function()
      for _, z in ipairs(g.zones) do if type(z[3]) ~= "string" or z[3] == "" then return false end end
      return true
    end)())
  else
    check(label .. ": has bands or zones", false)
  end
end

-- Route planner with every recipe known and a flat price list: a route must exist at several levels.
local faction = "Horde"
local env = setmetatable({
  CALLER = "GoldFinder", AH_CUT = 0.05,
  AHApi = function() return { GetAuctionPriceByItemID = function() return 100 end } end,
  VendorPrice = function() return nil end,
  Counts = function() return 0, 0 end,
  Cfg = function(k) return ({ sellCap = 5 })[k] end,
  C_Item = { GetItemInfo = function() return nil end },
  UnitFactionGroup = function() return faction end,
  GoldFinderDB = {}, GoldFinderRecipes = Recipes,
}, { __index = _G })
local PlanRoute = GF.NewRoutePlanner(env).PlanRoute

for _, key in ipairs(keys) do
  local g = Guides[key]
  if g.bands then
    local pd = { rank = 1, maxRank = 300, skillLine = g.line, crafts = {}, learned = {} }
    local n = 0
    for _, x in pairs(Recipes.spells) do
      if x.s == g.line then
        pd.crafts[x.n] = { r = x.r, o = x.o, q = x.q }
        pd.learned[x.n] = true
        n = n + 1
      end
    end
    check((g.name or key) .. ": recipe data exists for the planner", n > 0, n)
    for _, rank in ipairs({ 1, 60, 120, 180, 240 }) do
      pd.rank = rank
      local okP, plan = pcall(PlanRoute, g.name, pd, rank + 25)
      check((g.name or key) .. ": planner builds a route at skill " .. rank,
        okP and plan and #plan.steps > 0 and type(plan.cost) == "number",
        okP and (plan and ("steps=" .. #plan.steps) or "no plan") or plan)
    end
  end
end

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
