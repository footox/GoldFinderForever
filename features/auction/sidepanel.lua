-- features/auction/sidepanel.lua: the collapsible right-hand panel of the GoldFinder tab inside the auction house.
-- It holds the navigation between the auction views (Bags, Shopping, Leather) and the posting options, so the list
-- keeps the whole width. Container: the window (ui), its header and inset come from the caller; options are read from
-- and written to GoldFinderForeverDB the same way the settings page does, with the same limits.

local _, GF = ...

local UI = GF.UI
local Text, Btn, Flat, PAL = UI.Text, UI.Btn, UI.Flat, UI.PAL
local L = GF.L

local W_OPEN, W_SHUT = 196, 26

-- key, label, min, max (the same keys and limits as the settings page and Options > AddOns)
local OPTIONS = {
  { "postRefreshMin", "side.refresh", 0, 120 },
  { "postUndercut", "side.undercut", 0, 500 },
  { "postCapDays", "side.cap", 1, 14 },
  { "postDuration", "side.duration", 12, 24 },
}
local VIEWS = { { "bolsas", "tab.bags" }, { "compras", "tab.shopping" }, { "cuero", "tab.leather" } }

GF.SidePanel = {}

-- ui: the window; header: its top strip; inset: the framed area to shrink; cfg(key) reads an option.
function GF.SidePanel.Attach(ui, header, inset, cfg)
  local shut = (GoldFinderForeverDB and GoldFinderForeverDB.sideShut) and true or false
  local panel = CreateFrame("Frame", nil, ui)
  panel:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
  panel:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", 0, 0)
  local bg = Flat(panel, "BACKGROUND", { 0.10, 0.08, 0.06, 0.55 })
  bg:SetAllPoints()
  local edge = Flat(panel, "BORDER", { 0.29, 0.23, 0.13, 1 })
  edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)

  local title = Text(panel, 12, PAL.gold)
  title:SetPoint("TOPLEFT", 10, -10)
  title:SetText(L["side.title"])
  local toggle = Btn(panel, "", 20, 20)
  toggle:SetPoint("TOPRIGHT", -3, -6)

  local content = CreateFrame("Frame", nil, panel)
  content:SetPoint("TOPLEFT", 0, -34)
  content:SetPoint("BOTTOMRIGHT", 0, 0)

  -- views
  local vh = Text(content, 11, PAL.dim)
  vh:SetPoint("TOPLEFT", 10, -2)
  vh:SetText(L["side.views"])
  local navBtns = {}
  for i, v in ipairs(VIEWS) do
    local b = Btn(content, L[v[2]], W_OPEN - 20, 22, nil, function() ui.open(v[1]) end)
    b.gfKey = v[1]
    navBtns[i] = b
  end

  -- posting options
  local ph = Text(content, 11, PAL.dim)
  ph:SetText(L["side.posting"])
  local boxes = {}
  for i, o in ipairs(OPTIONS) do
    local lab = Text(content, 11, PAL.text)
    lab:SetText(L[o[2]])
    local box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    box:SetSize(46, 20)
    box:SetAutoFocus(false)
    local function show() box:SetText(tostring(cfg(o[1]))) end
    local function save()
      local val = GF.AuctionClampOption(box:GetText(), o[3], o[4], o[1] == "postDuration")
      if val then GoldFinderForeverDB[o[1]] = val end
      show()
    end
    box:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", save)
    boxes[i] = { lab = lab, box = box, show = show }
  end
  local hint = Text(content, 10, PAL.dim)
  hint:SetWidth(W_OPEN - 20)
  hint:SetJustifyH("LEFT")
  hint:SetText(L["side.hint"])

  local api = {}

  local function layout()
    local y = -22
    local shown = {}
    for _, b in ipairs(navBtns) do
      local ok = false
      for _, k in ipairs(ui.ahKeys or {}) do if k == b.gfKey then ok = true end end
      b:ClearAllPoints()
      if ok then
        b:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
        b:Show()
        y = y - 26
        shown[#shown + 1] = b
      else
        b:Hide()
      end
    end
    ph:ClearAllPoints()
    ph:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y - 12)
    y = y - 34
    for _, e in ipairs(boxes) do
      e.lab:ClearAllPoints(); e.lab:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y - 4)
      e.box:ClearAllPoints(); e.box:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, y)
      y = y - 26
    end
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y - 8)
  end

  local function apply()
    local w = shut and W_SHUT or W_OPEN
    panel:SetWidth(w)
    -- the list keeps the rest of the width (the inset ends where the panel starts; no bottom strip is needed because
    -- the navigation lives here and the bottom tabs are hidden)
    inset:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -w, 0)
    content:SetShown(not shut)
    title:SetShown(not shut)
    toggle.label:SetText(shut and "<" or ">")
  end

  toggle:SetScript("OnClick", function()
    shut = not shut
    if GoldFinderForeverDB then GoldFinderForeverDB.sideShut = shut or nil end
    apply()
    pcall(ui.refresh)   -- the list width changed: lay the columns out again
  end)
  toggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(shut and L["side.expand"] or L["side.collapse"], 1, 1, 1)
    GameTooltip:Show()
  end)
  toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- called whenever the window opens a view or refreshes: which views exist now, which one is current, option values
  function api.update()
    layout()
    for _, b in ipairs(navBtns) do
      local on = b.gfKey == ui.current
      if on then b:LockHighlight() else b:UnlockHighlight() end
      -- la vista actual se distingue por el texto dorado (los botones rojos se ven iguales con o sin resaltado)
      if on then b.label:SetTextColor(1, 0.82, 0.25) else b.label:SetTextColor(0.75, 0.7, 0.62) end
    end
    for _, e in ipairs(boxes) do e.show() end
  end

  apply()
  api.update()
  return api
end
