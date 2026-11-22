-- features/welcome/window.lua: the one-time welcome window. It lists what the addon does and which features are on,
-- so a new player knows they exist. Text only; nothing is changed from here. The lines come from core/welcome.lua.

local _, GF = ...

-- Shows (or refreshes) the window and marks it as seen, so it never opens by itself again.
function GF.ShowWelcome()
  local UI, L = GF.UI, GF.L
  if not (UI and UI.Skin and UI.Text and UI.Btn) then return end
  local Text, Btn, PAL, Skin = UI.Text, UI.Btn, UI.PAL, UI.Skin
  local W = 480

  local f = GoldFinderWelcome
  if not f then
    f = Skin.Panel("GoldFinderWelcome", UIParent, "dialog")
    f:SetSize(W, 320)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f.head = Skin.Head(f, "")
    local close = Skin.Close(f, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.intro = Text(f, 12, PAL.text, "LEFT")
    f.intro:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -46)
    f.intro:SetWidth(W - 40)
    f.body = Text(f, 12, PAL.text, "LEFT")
    f.body:SetPoint("TOPLEFT", f.intro, "BOTTOMLEFT", 0, -12)
    f.body:SetWidth(W - 40)
    f.foot = Text(f, 11, PAL.dim, "LEFT")
    f.foot:SetPoint("TOPLEFT", f.body, "BOTTOMLEFT", 0, -12)
    f.foot:SetWidth(W - 40)
    f.ok = Btn(f, "", 110, 24, nil, function() f:Hide() end)
    f.ok:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    -- Text() makes single-line strings (no wrap); these three are paragraphs
    for _, fs in ipairs({ f.intro, f.body, f.foot }) do fs:SetWordWrap(true) end
    if f.body.SetJustifyV then f.body:SetJustifyV("TOP") end
  end

  f.head:SetText(L["welcome.title"])
  f.intro:SetText(L["welcome.intro"])
  local parts = {}
  for _, l in ipairs(GF.WelcomeLines(GF.Cfg, L)) do
    local state = ""
    if l.on == true then
      state = "  " .. UI.GREEN .. L["welcome.on"] .. "|r"
    elseif l.on == false then
      state = "  " .. UI.ORANGE .. L["welcome.off"] .. "|r"
    end
    parts[#parts + 1] = "|cffffd24d" .. l.name .. "|r: " .. l.desc .. state
  end
  f.body:SetText(table.concat(parts, "\n\n"))
  f.foot:SetText(L["welcome.foot"])
  if f.ok.SetText then f.ok:SetText(L["welcome.ok"]) end

  local h = 46 + (f.intro:GetStringHeight() or 0) + 12 + (f.body:GetStringHeight() or 0) + 12
    + (f.foot:GetStringHeight() or 0) + 14 + 24 + 16
  f:SetHeight(math.max(h, 240))
  f:Show()
  if GoldFinderForeverDB then GoldFinderForeverDB.welcomeSeen = true end
end
