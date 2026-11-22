-- Offline tests for core/materials.lua (Lua 5.1): the categories of the Materials tab and the one it opens on.
-- Run from the addon folder:  lua tests/materials_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local GF = {}
assert(loadfile("core/materials.lua"))("GoldFinderForever", GF)
local CATS = GF.MATERIAL_CATEGORIES

-- the categories
check("four categories in a fixed order", #CATS == 4 and CATS[1].id == "leather" and CATS[2].id == "cloth"
  and CATS[3].id == "ore" and CATS[4].id == "herb")
check("lookup by id", GF.MaterialCategory("ore") == CATS[3] and GF.MaterialCategory("nope") == nil and GF.MaterialCategory(nil) == nil)

-- which items belong
check("leather is trade goods class 7, subclass 6", GF.MaterialMatches(CATS[1], 7, 6))
check("cloth is 7/5, ore 7/7, herbs 7/9", GF.MaterialMatches(CATS[2], 7, 5) and GF.MaterialMatches(CATS[3], 7, 7) and GF.MaterialMatches(CATS[4], 7, 9))
check("an item of another category does not match", not GF.MaterialMatches(CATS[1], 7, 5) and not GF.MaterialMatches(CATS[4], 7, 6))
check("another class does not match", not GF.MaterialMatches(CATS[1], 2, 6) and not GF.MaterialMatches(CATS[1], nil, nil))
check("no category does not match and does not raise", not GF.MaterialMatches(nil, 7, 6))
local seen, unique = {}, true
for _, c in ipairs(CATS) do local k = c.class .. ":" .. c.sub; if seen[k] then unique = false end; seen[k] = true end
check("no two categories share the same item subclass", unique)

-- the default for a character
local function prof(name, rank) return { [name] = { rank = rank } } end
local function merge(...) local out = {} for _, t in ipairs({ ... }) do for k, v in pairs(t) do out[k] = v end end return out end
check("a skinner opens on leather", GF.DefaultMaterialCategory(prof("Skinning", 100)).id == "leather")
check("a leatherworker opens on leather", GF.DefaultMaterialCategory(prof("Leatherworking", 50)).id == "leather")
check("a tailor opens on cloth", GF.DefaultMaterialCategory(prof("Tailoring", 20)).id == "cloth")
for _, p in ipairs({ "Mining", "Blacksmithing", "Engineering", "Jewelcrafting" }) do
  check(p .. " opens on ore", GF.DefaultMaterialCategory(prof(p, 10)).id == "ore")
end
check("an herbalist opens on herbs", GF.DefaultMaterialCategory(prof("Herbalism", 1)).id == "herb")
check("an alchemist opens on herbs", GF.DefaultMaterialCategory(prof("Alchemy", 1)).id == "herb")
check("the profession with the highest skill decides",
  GF.DefaultMaterialCategory(merge(prof("Skinning", 100), prof("Tailoring", 150), prof("Herbalism", 10))).id == "cloth")
check("a tie goes to the first category in the list",
  GF.DefaultMaterialCategory(merge(prof("Tailoring", 100), prof("Skinning", 100))).id == "leather")
check("two professions of the same category", GF.DefaultMaterialCategory(merge(prof("Mining", 80), prof("Blacksmithing", 90))).id == "ore")
check("professions with no material (cooking, fishing, first aid) fall back to leather",
  GF.DefaultMaterialCategory(merge(prof("Cooking", 150), prof("Fishing", 100), prof("First Aid", 200))).id == "leather")
check("a lowercase or longer profession name still matches", GF.DefaultMaterialCategory(prof("herbalism (journeyman)", 10)).id == "herb")
check("no professions, nil, a string or broken entries fall back to leather",
  GF.DefaultMaterialCategory({}).id == "leather" and GF.DefaultMaterialCategory(nil).id == "leather"
  and GF.DefaultMaterialCategory("x").id == "leather"
  and GF.DefaultMaterialCategory({ Mining = "bad", [5] = { rank = 3 }, Tailoring = {} }).id == "leather")

-- the choice made by hand
check("a valid choice wins over the professions", GF.CurrentMaterialCategory({ matCat = "herb", prof = prof("Skinning", 300) }).id == "herb")
check("an unknown choice is ignored", GF.CurrentMaterialCategory({ matCat = "gems", prof = prof("Tailoring", 5) }).id == "cloth")
check("no choice follows the professions", GF.CurrentMaterialCategory({ prof = prof("Mining", 5) }).id == "ore")
check("a character record without professions", GF.CurrentMaterialCategory({}).id == "leather" and GF.CurrentMaterialCategory(nil).id == "leather")

-- the selector
check("next goes forward and wraps", GF.NextMaterialCategory("leather", 1) == "cloth" and GF.NextMaterialCategory("herb", 1) == "leather")
check("previous goes back and wraps", GF.NextMaterialCategory("cloth", -1) == "leather" and GF.NextMaterialCategory("leather", -1) == "herb")
check("an unknown id starts from the first", GF.NextMaterialCategory("x", 1) == "cloth" and GF.NextMaterialCategory(nil, -1) == "herb")
local id, n = "leather", 0
repeat id = GF.NextMaterialCategory(id, 1); n = n + 1 until id == "leather" or n > 10
check("four steps come back to the start", n == 4)

-- wiring
local function read(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return (s:gsub("\13", "")) end
local toc, main, en, es = read("GoldFinderForever.toc"), read("GoldFinder.lua"), read("locales/enUS.lua"), read("locales/esES.lua")
check("the toc loads the module before the main file", toc:find("core/materials.lua", 1, true) ~= nil
  and toc:find("core/materials.lua", 1, true) < toc:find("GoldFinder.lua", 1, true))
check("the view uses the category helpers", main:find("GF.CurrentMaterialCategory(Char())", 1, true) ~= nil
  and main:find("GF.NextMaterialCategory(cat.id, step)", 1, true) ~= nil and main:find("GF.MaterialMatches(cat, classID, subClassID)", 1, true) ~= nil)
-- the selector is in the header: a list row with buttons made every row reserve the action column and squeezed the names
local a0 = main:find("    cuero = function()", 1, true)
local a1 = a0 and main:find("    end,", a0, true)
local loader = (a0 and a1) and main:sub(a0, a1) or ""
check("the Materials rows carry no buttons (no action column is reserved)", loader ~= "" and loader:find("actions", 1, true) == nil)
check("the loader shows the header controls and writes the category name", loader:find("ui.catControls", 1, true) ~= nil
  and loader:find("ui.catLabel:SetText", 1, true) ~= nil)
check("every view hides the header controls first", main:find("for _, c in ipairs(ui.catControls) do c:Hide() end", 1, true) ~= nil)
check("the header has the two step buttons and a label", main:find("ui.catStep(1)", 1, true) ~= nil and main:find("ui.catStep(-1)", 1, true) ~= nil
  and main:find("local catLabel = Text(header", 1, true) ~= nil)
check("the controls sit left of the Settings button when there is one", main:find("local catAnchor = ui.bOpts or bScan", 1, true) ~= nil)
check("the short category names fit the label", read("locales/enUS.lua"):find('["mat.ore"] = "Ore"', 1, true) ~= nil)
check("the tab is labelled Materials", main:find('L["tab.materials"]', 1, true) ~= nil and main:find('L["tab.leather"]', 1, true) == nil)
check("the choice is saved per character, not as an option", main:find("Char().matCat =", 1, true) ~= nil)
for _, k in ipairs({ "tab.materials", "mat.leather", "mat.cloth", "mat.ore", "mat.herb", "mat.leather.h", "mat.cloth.h", "mat.ore.h",
  "mat.herb.h", "mat.leather.l", "mat.cloth.l", "mat.ore.l", "mat.herb.l", "win.matEmpty" }) do
  check("both languages have " .. k, en:find('["' .. k .. '"]', 1, true) ~= nil and es:find('["' .. k .. '"]', 1, true) ~= nil)
end
check("the old leather-only texts are gone", en:find('"tab.leather"', 1, true) == nil and en:find('"win.hLeather"', 1, true) == nil
  and en:find('"win.leatherEmpty"', 1, true) == nil)

-- the columns of a list: PlaceCols is run for real (extracted from the main file) against fake regions
local a2 = main:find("local ROW_H, ACT_W = 30, 112", 1, true)
local b2 = a2 and main:find("local scrollCount = 0", a2, true)
local cols = (a2 and b2) and assert(loadstring(main:sub(a2, b2 - 1) .. "\nreturn PlaceCols")) or nil
check("PlaceCols can be extracted from the main file", cols ~= nil)
if cols then
  setfenv(cols, setmetatable({}, { __index = _G }))
  local PlaceCols = cols()
  local function region()
    local r = { points = {} }
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:SetWidth(w) self.width = w end
    function r:SetJustifyH() end
    return r
  end
  local function place(w, act, c1w)
    local owner, name, c1, c2, c3 = region(), region(), region(), region(), region()
    PlaceCols(owner, name, c1, c2, c3, true, w, act, c1w)
    return name, c1, c2, c3
  end
  local name, c1, c2, c3 = place(560, 8)
  check("narrow list: the default widths of the three number columns", c3.width == 96 and c2.width == 78 and c1.width == 46)
  local name2, d1, d2, d3 = place(560, 8, 80)
  check("a view can ask for a wider first number column", d1.width == 80 and d2.width == 78 and d3.width == 96)
  check("the name column gives up exactly that room", name2.points[2][4] == -(8 + 96 + 78 + 80 + 24) and name.points[2][4] == -(8 + 96 + 78 + 46 + 24))
  check("the wider column moves left as much as it grew", d1.points[1][4] == -(8 + 96 + 78 + 16))
  local _, e1 = place(900, 8)
  check("a wide list keeps its own wide default", e1.width == 110)
  local _, f1 = place(900, 8, 80)
  check("the request also applies to a wide list", f1.width == 80)
  local _, g1, g2, g3 = place(nil, nil, nil)
  check("no width and no reserve still lays out", g1.width == 110 and g2.width == 150 and g3.width == 150)
end

-- setHeaders starts every view from the default width; the Materials view asks for more after it
local sh = main:find("function v.setHeaders(a, b, c, d)", 1, true)
local shEnd = sh and main:find("function v.setC1Width(px)", sh, true)
local shBody = (sh and shEnd) and main:sub(sh, shEnd) or ""
check("setHeaders drops a width asked by the previous view", shBody:find("if curC1 then curC1 = nil; relayout() end", 1, true) ~= nil)
check("a list view can ask for a column width", main:find("function v.setC1Width(px)", 1, true) ~= nil
  and main:find("PlaceCols(head, hName, h1, h2, h3, true, curW, curAct, curC1)", 1, true) ~= nil
  and main:find("PlaceCols(row, row.name, row.c1, row.c2, row.c3, true, curW, curAct, curC1)", 1, true) ~= nil)
local l0 = main:find("    cuero = function()", 1, true)
local l1 = l0 and main:find("    end,", l0, true)
local ld = (l0 and l1) and main:sub(l0, l1) or ""
check("Materials asks for the wider price column right after its headers", ld:find("setHeaders", 1, true) and ld:find("ui.list.setC1Width(80)", 1, true)
  and ld:find("setHeaders", 1, true) < ld:find("setC1Width", 1, true))

-- item names: redraw when the game says one arrived
check("the item-info event is registered with the others", main:find('"MAIL_SHOW", "PLAYER_LOGOUT", "GET_ITEM_INFO_RECEIVED" })', 1, true) ~= nil)
local e0 = main:find('elseif event == "GET_ITEM_INFO_RECEIVED" then', 1, true)
local e1b = e0 and main:find('elseif event == "PLAYER_LOGOUT" then', e0, true)
local eh = (e0 and e1b) and main:sub(e0, e1b) or ""
check("the handler ignores a load that failed", eh:find("arg2 ~= false", 1, true) ~= nil)
check("it redraws only windows waiting for THIS item and still open", eh:find("u.missingIds and u.missingIds[arg1] and u:IsShown()", 1, true) ~= nil
  and eh:find("w.missingIds and w.missingIds[arg1] and w:IsShown()", 1, true) ~= nil)
check("an item can cause at most three redraws", eh:find("(nameTries[arg1] or 0) < 3", 1, true) ~= nil
  and eh:find("nameTries[arg1] = (nameTries[arg1] or 0) + 1", 1, true) ~= nil)
check("the handler is debounced to one redraw per half second", eh:find("not namesPending", 1, true) ~= nil
  and eh:find("namesPending = true", 1, true) ~= nil and eh:find("C_Timer.After(0.5", 1, true) ~= nil and eh:find("namesPending = false", 1, true) ~= nil)
check("a failing redraw does not stop the others", eh:find("pcall(w.refresh)", 1, true) ~= nil)
check("the event handler reads the second argument", main:find('f:SetScript("OnEvent", function(_, event, arg1, arg2)', 1, true) ~= nil)
check("ItemLink records which ids are missing", main:find("missingNow[id] = true", 1, true) ~= nil
  and main:find("    missingNow = {}", 1, true) ~= nil and main:find("ui.namesMissing, ui.missingIds = nameMissing, missingNow", 1, true) ~= nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
