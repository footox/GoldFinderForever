-- Offline tests for GF.NoteText and GF.ZoneText (Lua 5.1). Run from the addon folder:
--   "C:\Program Files (x86)/Lua/5.1/lua.exe" tests\notes_test.lua
-- The data files keep their notes in Spanish; an English UI shows them through locales/notes_enUS.lua. The coverage test
-- fails when a note in the data has no English entry (add one, or add it to NAMES_ONLY if it is only item names).

local GF = {}
for _, path in ipairs({ "core/locale.lua", "locales/notes_enUS.lua" }) do
  local fn = assert(loadfile(path))
  setfenv(fn, setmetatable({}, { __index = _G }))
  fn("GoldFinder", GF)
end

local failures = 0
local function check(name, cond, detail)
  if cond then print("PASS " .. name) else print("FAIL " .. name .. (detail and (" -- " .. tostring(detail)) or "")); failures = failures + 1 end
end

GF.SetLocale("enUS")
check("english: a known note is translated", GF.NoteText("cobre") == "copper")
check("english: an unknown note is shown as written", GF.NoteText("algo nuevo") == "algo nuevo")
check("english: nil stays nil", GF.NoteText(nil) == nil)
check("english: ' o ' in a zone list becomes ' or '", GF.ZoneText("Durotar, Mulgore o Tirisfal Glades") == "Durotar, Mulgore or Tirisfal Glades")
check("english: a zone name with an o inside is not touched", GF.ZoneText("Orgrimmar") == "Orgrimmar" and GF.ZoneText("Thousand Needles") == "Thousand Needles")
GF.SetLocale("esES")
check("spanish: the note is shown as stored", GF.NoteText("cobre") == "cobre")
check("spanish: the zone list is shown as stored", GF.ZoneText("Durotar, Mulgore o Tirisfal Glades") == "Durotar, Mulgore o Tirisfal Glades")

-- coverage: every note in the data files is translated or is only item names
local NAMES_ONLY = {
  ["Dreamfoil 270; Mountain Silversage 280; Plaguebloom 285"] = true,
  ["Firebloom 205; Purple Lotus 210"] = true,
  ["Goldthorn, Fadeleaf; Khadgar's Whisker 185"] = true,
  ["Mageroyal, Briarthorn; Stranglekelp 85; Bruiseweed 100"] = true,
  ["Small Thorium"] = true,
  ["Sungrass; Ghost Mushroom 245; Golden Sansam 260"] = true,
  ["Wild Steelbloom; Kingsblood 125; Liferoot 150"] = true,
}
local function loadData(path)
  local env = setmetatable({}, { __index = _G })
  local fn = assert(loadfile(path))
  setfenv(fn, env)
  fn("GoldFinder", {})
  return env
end
local Guides = loadData("GoldFinderGuides.lua").GoldFinderGuides
local Routes = loadData("GoldFinderRoutes.lua").GoldFinderRoutes
local notes, n = {}, 0
for _, g in pairs(Guides) do
  for _, z in ipairs(g.zones or {}) do if z[4] and z[4] ~= "" then notes[z[4]] = true end end
end
for _, list in pairs(Routes) do
  if type(list) == "table" then
    for _, rt in ipairs(list) do
      for _, z in ipairs(rt.zones or {}) do if z.note and z.note ~= "" then notes[z.note] = true end end
    end
  end
end
local missing = {}
for note in pairs(notes) do
  n = n + 1
  if not GF.NotesEN[note] and not NAMES_ONLY[note] then missing[#missing + 1] = note end
end
table.sort(missing)
check("coverage: every note has an English text or is names only (" .. n .. " notes)", #missing == 0, table.concat(missing, " | "))

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
