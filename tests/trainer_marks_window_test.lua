-- Offline tests for features/trainer/marks.lua (Lua 5.1): the panel next to a profession trainer. A fake client opens and
-- closes the trainer window. Run from the addon folder:  lua tests/trainer_marks_window_test.lua

local failures = 0
local function check(name, cond)
  if cond then print("PASS " .. name) else print("FAIL " .. name); failures = failures + 1 end
end

local function newFrame(name)
  local f = { name = name, shown = false, points = {}, scripts = {}, events = {}, text = nil, wrap = nil, size = nil, width = nil }
  local known = {}
  function known.Show(self) self.shown = true end
  function known.Hide(self) self.shown = false end
  function known.ClearAllPoints(self) self.points = {} end
  function known.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
  function known.SetHeight(self, h) self.height = h end
  function known.SetWidth(self, w) self.width = w end
  function known.SetText(self, t) self.text = t end
  function known.SetWordWrap(self, v) self.wrap = v end
  function known.GetStringHeight(self) return self.text and (select(2, self.text:gsub("\n", "")) + 1) * 14 or 0 end
  function known.RegisterEvent(self, e) self.events[e] = true end
  function known.SetScript(self, n, fn) self.scripts[n] = fn end
  -- only methods (capitalised, like WoW's) are no-ops; a missing plain field is nil, not a function
  return setmetatable(f, { __index = function(_, k)
    if known[k] then return known[k] end
    if type(k) == "string" and k:find("^%u") then return function() end end
    return nil
  end })
end

local function session(opts)
  opts = opts or {}
  local S = { frames = {}, queue = {}, calls = 0, panels = 0 }
  local env = {
    UIParent = newFrame("UIParent"),
    C_Timer = { After = function(_, fn) S.queue[#S.queue + 1] = fn end },
    CreateFrame = function() local f = newFrame(); S.frames[#S.frames + 1] = f; return f end,
    pcall = pcall, type = type, tostring = tostring, string = string, table = table, math = math, rawget = rawget, ipairs = ipairs, pairs = pairs,
  }
  env._G = env
  if opts.trainerFrame then env.ClassTrainerFrame = newFrame("ClassTrainerFrame") end
  local GF = {
    L = setmetatable({ ["tm.title"] = "TITLE", ["tm.fail"] = "FAIL %s" }, { __index = function(_, k) return k end }),
    UI = {
      PAL = { gold = {}, text = {} },
      Skin = { Panel = function(name) S.panels = S.panels + 1; local p = newFrame(name); S.panel = p; return p end },
      Text = function() local t = newFrame("Text"); S.texts = S.texts or {}; S.texts[#S.texts + 1] = t; return t end,
    },
    TrainerPanelLines = function(sections) S.lastSections = sections; return { "line one", "line two" } end,
  }
  local fn = assert(loadfile("features/trainer/marks.lua"))
  setfenv(fn, env)
  fn("GoldFinderForever", GF)
  local sections = opts.sections
  if sections == nil then sections = { { prof = "Leatherworking" } } end
  GF.InitTrainerMarks({
    Sections = function() S.calls = S.calls + 1; if opts.fail then error("boom") end; return sections end,
    Cfg = function(k) if k == "trainerMarks" then return opts.cfg ~= false end end,
    Money = function(c) return c end,
    Print = function(line) S.prints = S.prints or {}; S.prints[#S.prints + 1] = line end,
  })
  S.env, S.GF = env, GF
  S.events = S.frames[1]
  function S.fire(e) S.events.scripts.OnEvent(S.events, e) end
  function S.flush() local q = S.queue; S.queue = {}; for _, f in ipairs(q) do f() end end
  return S
end

local S = session({ trainerFrame = true })
check("it listens to the trainer opening and closing", S.events.events.TRAINER_SHOW and S.events.events.TRAINER_CLOSED)
check("nothing is built before a trainer opens", S.panels == 0)
S.fire("TRAINER_SHOW")
check("it waits for the trainer to be recorded first", #S.queue == 1 and S.panels == 0)
S.flush()
check("the panel is built once, shown and called GoldFinderTrainerMarks", S.panels == 1 and S.panel.shown and S.panel.name == "GoldFinderTrainerMarks")
check("it is anchored to the right of the trainer window", S.panel.points[1][1] == "TOPLEFT" and S.panel.points[1][2] == S.env.ClassTrainerFrame
  and S.panel.points[1][3] == "TOPRIGHT")
local paragraph
for _, t in ipairs(S.texts) do if t.wrap ~= nil then paragraph = t end end
check("the paragraph wraps (Text() makes single lines by default)", paragraph and paragraph.wrap == true)
check("the body is the lines of the pure function, one per line", paragraph.text == "line one\nline two")
check("the title is the locale text", S.texts[1].text == "TITLE")
check("it asks for the sections of the open trainer", S.calls == 1 and S.lastSections[1].prof == "Leatherworking")
check("the panel is tall enough for its text", S.panel.height >= 60)

S.fire("TRAINER_CLOSED")
check("closing the trainer hides it", S.panel.shown == false)
S.fire("TRAINER_SHOW"); S.flush()
check("opening again reuses the panel and asks again", S.panels == 1 and S.panel.shown and S.calls == 2)

S.fire("TRAINER_SHOW"); S.fire("TRAINER_CLOSED"); S.flush()
check("closed before the timer fired: it does not appear", S.panel.shown == false)

-- no trainer window frame: it goes beside the middle of the screen
local Sn = session()
Sn.fire("TRAINER_SHOW"); Sn.flush()
check("without the trainer frame it sits at the side of the screen", Sn.panel.points[1][1] == "CENTER" and Sn.panel.points[1][2] == Sn.env.UIParent)

-- nothing to say: no panel
local Se = session({ sections = {} })
Se.fire("TRAINER_SHOW"); Se.flush()
check("no section (not a profession of yours, or nothing recorded): no panel", Se.panels == 0)
local Sx = session({ sections = "bad" })
Sx.fire("TRAINER_SHOW"); Sx.flush()
check("a bad answer does not build or raise", Sx.panels == 0)

-- option off
local So = session({ cfg = false })
So.fire("TRAINER_SHOW"); So.flush()
check("option off: nothing is asked and nothing is built", So.panels == 0 and So.calls == 0)

-- a failing data provider does not raise out of the event
local Sf = session({ fail = true })
Sf.fire("TRAINER_SHOW")
local ok = pcall(Sf.flush)
check("an error while reading the trainer never escapes", ok and Sf.panels == 0)
check("and it is shown to the player, not swallowed", Sf.prints and #Sf.prints == 1 and Sf.prints[1]:find("boom", 1, true) ~= nil)
local Sg = session({ fail = false })
Sg.fire("TRAINER_SHOW"); Sg.flush()
check("a normal run prints nothing", Sg.prints == nil)

if failures > 0 then print(failures .. " FAILED"); os.exit(1) end
print("ALL PASS")
