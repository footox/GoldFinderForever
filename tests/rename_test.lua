-- Offline checks of the 2.3.0 rename wiring (Lua 5.1): the .toc, the variable names, the addon name that comes from
-- the loader and the slash registration. Run from the addon folder:
--   "C:\Program Files (x86)\Lua\5.1\lua.exe" tests\rename_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local function read(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a"); f:close()
  return (s:gsub("\r\n", "\n"))
end

local toc = read("GoldFinderForever.toc")
check("toc exists under the new name", toc ~= nil)
check("old toc name is gone", read("GoldFinder.toc") == nil)
toc = toc or ""

local sv = toc:match("## SavedVariables:%s*([^\n]+)") or ""
check("toc declares the new variable", sv:find("GoldFinderForeverDB", 1, true) ~= nil)
-- declaring a variable that another addon may also own would make our saved file overwrite theirs
check("toc does NOT declare the old variable", sv:find("GoldFinderDB", 1, true) == nil)
check("toc declares exactly one variable", not sv:find(","))
check("toc keeps the project id", toc:find("## X-Curse-Project-ID: 1820519", 1, true) ~= nil)
check("toc keeps the visible title", toc:find("## Title: GoldFinder Forever", 1, true) ~= nil)

-- every file listed in the toc exists; slash.lua is loaded before the main file
local order, seen = {}, {}
for line in toc:gmatch("[^\n]+") do
  if not line:find("^#") and line:find("%.lua$") then
    order[#order + 1] = line
    local f = io.open(line, "rb")
    check("toc file exists: " .. line, f ~= nil)
    if f then f:close() end
    seen[line] = #order
  end
end
check("core/slash.lua is listed", seen["core/slash.lua"] ~= nil)
check("core/slash.lua loads before GoldFinder.lua", seen["core/slash.lua"] and seen["GoldFinder.lua"]
  and seen["core/slash.lua"] < seen["GoldFinder.lua"])

-- the main file: addon name from the loader, new variable everywhere, old one only inside the migration call
local main = read("GoldFinder.lua") or ""
check("addon name comes from the loader", main:find("local ADDON, GF = ...", 1, true) ~= nil)
check("ADDON_LOADED compares with the loader name", main:find('arg1 == ADDON', 1, true) ~= nil)
check("no ADDON_LOADED test against a hard-coded folder name", main:find('arg1 == "GoldFinder"', 1, true) == nil)

check("the old variable no longer appears in the main file", not main:find("GoldFinderDB", 1, true))
check("nothing migrates: the data variable starts empty", main:find("GoldFinderForeverDB = GoldFinderForeverDB or {}", 1, true) ~= nil)

-- no other lua file touches the old variable
local others = 0
for _, p in ipairs({ "core/config.lua", "core/decision.lua", "core/routeplanner.lua", "features/auction/sidepanel.lua",
  "features/guide/hybrid.lua", "features/professions/tabs.lua", "features/route/helpers.lua", "features/route/plan.lua",
  "features/tracker/objectives.lua" }) do
  local s = read(p) or ""
  if s:find("GoldFinderDB", 1, true) then others = others + 1 end
end
check("no feature or core file reads the old variable", others == 0)

-- slash and broker names
check("slash key is its own", main:find('SlashCmdList["GOLDFINDERFOREVER"]', 1, true) ~= nil)
check("/gff is the primary command", main:find('SLASH_GOLDFINDERFOREVER1 = "/gff"', 1, true) ~= nil)
check("/gf is registered only when free", main:find('GF.CommandTaken(SlashCmdList, _G, "GOLDFINDERFOREVER", "/gf")', 1, true) ~= nil)
check("the old slash key is not registered", main:find('SlashCmdList["GOLDFINDER"]', 1, true) == nil)
check("minimap broker object has its own name", main:find('NewDataObject("GoldFinderForever"', 1, true) ~= nil
  and main:find('NewDataObject("GoldFinder"', 1, true) == nil)
check("option registry names have the new prefix", main:find('"GoldFinder_"', 1, true) == nil)

-- build script
local build = read("tools/build_zip.py") or ""
check("zip folder and file names follow the new name", build:find('"GoldFinderForever/" + f', 1, true) ~= nil
  and build:find("GoldFinderForever-%s.zip", 1, true) ~= nil)

-- the texts the player reads
local en, es, readme = read("locales/enUS.lua") or "", read("locales/esES.lua") or "", read("README.md") or ""
check("no leftover migration texts", not en:find("migrate.", 1, true) and not es:find("migrate.", 1, true))
check("player-facing texts do not tell to type /gf", not en:find("/gf[^f]") and not es:find("/gf[^f]") and not readme:find("/gf[^f]"))

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
