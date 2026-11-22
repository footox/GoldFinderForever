-- Offline tests for features/auction/materials.lua (Lua 5.1): the extra Materials window that opens with the auction
-- house. A fake client opens and closes the auction house, drags the window and makes its creation fail.
-- Run from the addon folder:  lua tests/auction_materials_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

-- a frame that remembers what the module did to it; every method it does not know is a no-op
local function newFrame(kind, name)
  local f = { kind = kind, name = name, shown = false, points = {}, scripts = {}, events = {}, hooks = {}, size = nil }
  local known = {}
  function known.Show(self) self.shown = true end
  function known.Hide(self) self.shown = false end
  function known.IsShown(self) return self.shown end
  function known.ClearAllPoints(self) self.points = {} end
  function known.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
  function known.SetSize(self, w, h) self.size = { w, h } end
  function known.GetFrameLevel() return 1 end
  function known.GetHeight(self) return self.height end
  function known.RegisterEvent(self, e) self.events[e] = true end
  function known.SetScript(self, n, fn) self.scripts[n] = fn end
  function known.HookScript(self, n, fn) self.hooks[n] = fn end
  function known.GetPoint(self) return self.dragPoint, nil, self.dragRel, self.dragX, self.dragY end
  return setmetatable(f, { __index = function(_, k) return known[k] or function() end end })
end

-- one fake game session; returns what the test needs to drive it
local function session(opts)
  opts = opts or {}
  local S = { frames = {}, prints = {}, createCalls = {}, queue = {}, refreshes = 0 }
  local ui = { refresh = function() S.refreshes = S.refreshes + 1 end }
  local env = {
    UIParent = newFrame("Frame", "UIParent"),
    GoldFinderForeverDB = opts.db or {},
    C_Timer = { After = function(_, fn) S.queue[#S.queue + 1] = fn end },
    CreateFrame = function(kind, name)
      local f = newFrame(kind, name)
      S.frames[#S.frames + 1] = f
      return f
    end,
    pcall = pcall, type = type, tostring = tostring, string = string, rawget = rawget, ipairs = ipairs, pairs = pairs,
  }
  env._G = env
  if opts.ah ~= false then
    env.AuctionHouseFrame = newFrame("Frame", "AuctionHouseFrame")
    env.AuctionHouseFrame.height = opts.ahHeight or 600
  end
  local GF = { L = setmetatable({ ["auction.tab.fail"] = "FAIL: %s" }, { __index = function(_, k) return k end }),
    UI = { Flat = function() return newFrame("Texture") end, PAL = { bg = { 0, 0, 0, 1 } } } }
  local fn = assert(loadfile("features/auction/materials.lua"))
  setfenv(fn, env)
  fn("GoldFinderForever", GF)
  local cfgOn = opts.cfg ~= false
  GF.InitAuctionMaterials({
    CreateUI = function(parent, o)
      S.createCalls[#S.createCalls + 1] = { parent = parent, opts = o }
      if opts.failCreate then error("boom") end
      return ui
    end,
    Cfg = function(k) if k == "auctionMaterials" then return cfgOn end end,
    Print = function(line) S.prints[#S.prints + 1] = line end,
  })
  S.GF, S.env = GF, env
  S.events = S.frames[1]   -- the first frame the module creates is its event frame
  function S.fire(event) S.events.scripts.OnEvent(S.events, event) end
  function S.flush() local q = S.queue; S.queue = {}; for _, f in ipairs(q) do f() end end
  function S.win() return GF.AuctionMaterialsWindow() end
  return S
end

-- 1. it listens to the auction house opening and closing
local S = session()
check("it registers both events", S.events.events.AUCTION_HOUSE_SHOW and S.events.events.AUCTION_HOUSE_CLOSED)
check("nothing is built before the auction house opens", #S.createCalls == 0 and S.win() == nil)

-- 2. opening it builds the window once, on the Materials view alone
S.fire("AUCTION_HOUSE_SHOW")
check("the window waits half a second like the tab", #S.createCalls == 0 and #S.queue == 1)
S.flush()
check("it hosts the Materials view alone, embedded", #S.createCalls == 1 and S.createCalls[1].opts.embedded == true
  and S.createCalls[1].opts.only[1] == "cuero" and #S.createCalls[1].opts.only == 1)
check("the window exists, is called GoldFinderMaterials and is shown", S.win() and S.win().name == "GoldFinderMaterials" and S.win().shown)
check("it is placed to the right of the auction house, as tall as it is",
  S.win().points[1][1] == "TOPLEFT" and S.win().points[1][2] == S.env.AuctionHouseFrame and S.win().points[1][3] == "TOPRIGHT"
  and S.win().size[1] == 460 and S.win().size[2] == 600)
check("the list is refreshed when it appears", S.refreshes == 1)
check("it leaves room for the close button", S.win().gfPadRight == 30)
check("it hides with the auction house frame, however that closes", type(S.env.AuctionHouseFrame.hooks.OnHide) == "function")

-- 3. closing hides it, opening again reuses it
S.fire("AUCTION_HOUSE_CLOSED")
check("closing the auction house hides it", S.win().shown == false)
S.fire("AUCTION_HOUSE_SHOW"); S.flush()
check("opening again does not build a second window", #S.createCalls == 1 and S.win().shown == true)
check("and refreshes the list again", S.refreshes == 2)
S.env.AuctionHouseFrame.hooks.OnHide()
check("the auction house frame hiding hides it too", S.win().shown == false)

-- 4. a quick close before the half second is over leaves it hidden
S.fire("AUCTION_HOUSE_SHOW")
S.fire("AUCTION_HOUSE_CLOSED")
S.flush()
check("closed before the timer fired: it does not appear", S.win().shown == false)

-- 5. the option switches it off
local Soff = session({ cfg = false })
Soff.fire("AUCTION_HOUSE_SHOW"); Soff.flush()
check("option off: nothing is built and nothing shown", #Soff.createCalls == 0 and Soff.win() == nil)

-- 6. dragging remembers the position and the next time it comes back there
local Sd = session()
Sd.fire("AUCTION_HOUSE_SHOW"); Sd.flush()
local w = Sd.win()
w.dragPoint, w.dragRel, w.dragX, w.dragY = "TOPLEFT", "BOTTOMLEFT", 120, 480
w.scripts.OnDragStop(w)
local saved = Sd.env.GoldFinderForeverDB.matsPos
check("the drop position is saved", saved and saved[1] == "TOPLEFT" and saved[2] == "BOTTOMLEFT" and saved[3] == 120 and saved[4] == 480)
Sd.fire("AUCTION_HOUSE_CLOSED"); Sd.fire("AUCTION_HOUSE_SHOW"); Sd.flush()
local p = Sd.win().points[1]
check("the saved position wins over the default", p[1] == "TOPLEFT" and p[2] == Sd.env.UIParent and p[3] == "BOTTOMLEFT" and p[4] == 120 and p[5] == 480)

-- 7. a damaged saved position is ignored
for _, bad in ipairs({ "x", { "TOPLEFT" }, { "TOPLEFT", "TOPLEFT", "a", 5 }, { 1, 2, 3, 4 }, 42 }) do
  local Sb = session({ db = { matsPos = bad } })
  Sb.fire("AUCTION_HOUSE_SHOW"); Sb.flush()
  local q = Sb.win().points[1]
  check("a damaged saved position falls back to the default", q[1] == "TOPLEFT" and q[2] == Sb.env.AuctionHouseFrame)
end

-- 8. no auction house frame, or a strange height
local Sn = session({ ah = false })
Sn.fire("AUCTION_HOUSE_SHOW"); Sn.flush()
check("without the auction house frame it centres on the screen with the default height",
  Sn.win().points[1][1] == "CENTER" and Sn.win().size[2] == 520)
local Sh = session({ ahHeight = 20 })
Sh.fire("AUCTION_HOUSE_SHOW"); Sh.flush()
check("a tiny height is not used", Sh.win().size[2] == 520)

-- 9. a failing creation does not raise, tells the player and tries again next time
local Sf = session({ failCreate = true })
Sf.fire("AUCTION_HOUSE_SHOW"); Sf.flush()
check("a creation error is printed and nothing is left shown", #Sf.prints == 1 and Sf.prints[1]:find("boom", 1, true) ~= nil and Sf.win() == nil)
Sf.fire("AUCTION_HOUSE_SHOW"); Sf.flush()
check("it tries again the next time", #Sf.createCalls == 2)

-- 10. wiring in the main file, the tab, the options and the texts
local function read(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return (s:gsub("\13", "")) end
local toc, main, en, es = read("GoldFinderForever.toc"), read("GoldFinder.lua"), read("locales/enUS.lua"), read("locales/esES.lua")
check("the toc loads the feature after the auction tab and before the main file", toc:find("features/auction/materials.lua", 1, true)
  and toc:find("features/auction/tab.lua", 1, true) < toc:find("features/auction/materials.lua", 1, true)
  and toc:find("features/auction/materials.lua", 1, true) < toc:find("GoldFinder.lua", 1, true))
check("the main file starts it with CreateUI, Cfg and Print", main:find("GF.InitAuctionMaterials({", 1, true) ~= nil)
check("the tab drops its Materials view only when the window is on", main:find('if not Cfg("auctionMaterials") then keys[#keys + 1] = "cuero" end', 1, true) ~= nil)
check("both option pages list it", main:find('{ "auctionMaterials", L["set.auctionMaterials"] }', 1, true) ~= nil
  and main:find('check("auctionMaterials"', 1, true) ~= nil)
check("the option is on by default", read("core/config.lua"):find("auctionMaterials = true", 1, true) ~= nil)
for _, k in ipairs({ "set.auctionMaterials", "opt.auctionMaterials.l", "opt.auctionMaterials.t" }) do
  check("both languages have " .. k, en:find('["' .. k .. '"]', 1, true) ~= nil and es:find('["' .. k .. '"]', 1, true) ~= nil)
end

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
