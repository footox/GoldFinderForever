-- features/trainer/marks.lua: the small panel next to a profession trainer's window that says which of the recipes it
-- teaches your guide still needs, so you do not pay for the useless ones. It reads what the addon already records of
-- the trainer; it never touches Blizzard's rows. Switched off by the option trainerMarks.

local _, GF = ...

local W = 290

-- d: Sections() -> { { prof, recs, wanted, known }, ... } for the trainer that is open, Cfg(key), Money(copper)
function GF.InitTrainerMarks(d)
  local L = GF.L
  local panel, title, body
  local isOpen = false

  local function Place()
    local tf = rawget(_G, "ClassTrainerFrame")
    panel:ClearAllPoints()
    if tf then
      panel:SetPoint("TOPLEFT", tf, "TOPRIGHT", 6, 0)
    else
      panel:SetPoint("CENTER", UIParent, "CENTER", 330, 0)
    end
  end

  local function Build()
    local UI = GF.UI
    local p = UI.Skin.Panel("GoldFinderTrainerMarks", UIParent, "dialog")
    p:SetFrameStrata("HIGH")
    p:SetClampedToScreen(true)
    p:SetWidth(W)
    title = UI.Text(p, 13, UI.PAL.gold, "LEFT")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -12)
    title:SetWidth(W - 28)
    body = UI.Text(p, 12, UI.PAL.text, "LEFT")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    body:SetWidth(W - 28)
    body:SetWordWrap(true)   -- Text() makes single-line strings; this is a paragraph
    if body.SetJustifyV then body:SetJustifyV("TOP") end
    panel = p
  end

  local function Refresh()
    if not isOpen or not d.Cfg("trainerMarks") then
      if panel then panel:Hide() end
      return
    end
    local sections = d.Sections()
    if type(sections) ~= "table" or #sections == 0 then
      if panel then panel:Hide() end
      return
    end
    if not panel then Build() end
    title:SetText(L["tm.title"])
    body:SetText(table.concat(GF.TrainerPanelLines(sections, L, d.Money), "\n"))
    Place()
    panel:SetHeight(math.max(60, 12 + (title:GetStringHeight() or 14) + 8 + (body:GetStringHeight() or 0) + 14))
    panel:Show()
  end

  local events = CreateFrame("Frame")
  events:RegisterEvent("TRAINER_SHOW")
  events:RegisterEvent("TRAINER_CLOSED")
  events:SetScript("OnEvent", function(_, event)
    if event == "TRAINER_CLOSED" then
      isOpen = false
      if panel then panel:Hide() end
      return
    end
    isOpen = true
    -- after the trainer has been recorded (the addon does that 0.2 s after the window opens)
    C_Timer.After(0.8, function() pcall(Refresh) end)
  end)
end
