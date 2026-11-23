-- Offline tests for the addon icon (Lua 5.1): the penguin icon is a valid game texture, the toc and the main window use it, and the
-- package ships it. Run from the addon folder:  lua tests/icon_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end
local function read(p)
  local f = io.open(p, "rb"); if not f then return nil end
  local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n"))
end
local function readRaw(p)
  local f = io.open(p, "rb"); if not f then return nil end
  local s = f:read("*a"); f:close(); return s
end

-- a TGA header: byte 3 = image type (2 = uncompressed true colour), width/height little endian, bits per pixel
local function tga(path)
  local s = readRaw(path)
  if not s or #s < 18 then return nil end
  local function u16(i) return s:byte(i) + s:byte(i + 1) * 256 end
  return { type = s:byte(3), w = u16(13), h = u16(15), bpp = s:byte(17), size = #s }
end
local function isPowerOfTwo(n) return n > 0 and math.floor(math.log(n) / math.log(2) + 0.0000001) == math.log(n) / math.log(2) end

for _, n in ipairs({ 64, 128 }) do
  local h = tga("art/icon_penguin_" .. n .. ".tga")
  check("icon_penguin_" .. n .. ".tga exists", h ~= nil)
  check("it is uncompressed true colour", h and h.type == 2)
  check("it is " .. n .. "x" .. n, h and h.w == n and h.h == n)
  check("it is 32 bits (colour and transparency)", h and h.bpp == 32)
  check("its size matches the header (18 bytes + pixels)", h and h.size >= 18 + n * n * 4 and h.size <= 18 + n * n * 4 + 600)
  check("sizes are powers of two, as the game needs", h and isPowerOfTwo(h.w) and isPowerOfTwo(h.h))
end

local toc = read("GoldFinderForever.toc")
local iconLine = toc:match("## IconTexture: ([^\n]+)")
check("the toc names an icon", iconLine ~= nil)
check("it points inside this addon, to the art folder", iconLine and iconLine:find("Interface\\AddOns\\GoldFinderForever\\art\\", 1, true) == 1)
local rel = iconLine and iconLine:gsub("^Interface\\AddOns\\GoldFinderForever\\", ""):gsub("\\", "/")
check("the file the toc names exists", rel and readRaw(rel) ~= nil)
check("it is the 64x64 one", rel and rel:find("icon_penguin_64.tga", 1, true) ~= nil)

local main = read("GoldFinder.lua")
check("the main window uses the penguin icon", main:find('local icon = "Interface\\\\AddOns\\\\GoldFinderForever\\\\art\\\\icon_penguin_128.tga"', 1, true) ~= nil)
check("the minimap button uses the penguin icon", main:find([[local ICON = "Interface\\AddOns\\GoldFinderForever\\art\\icon_penguin_64.tga"]], 1, true) ~= nil)
check("the generic coin icon is gone", not main:find("INV_Misc_Coin_01", 1, true))

local pkg = read(".pkgmeta") or ""
check("the package does not ignore the art folder", not pkg:find("%- art") and not pkg:find("art/", 1, true))
check("the package still ignores the screenshots folder (media)", pkg:find("- media", 1, true) ~= nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
