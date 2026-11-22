-- features/auction/materials.lua: the extra Materials window that appears next to the auction house when it opens and
-- goes away when it closes. It hosts the Materials view alone (the same list as the Materials tab of the GoldFinder
-- window) in a frame of its own, so the auction tab keeps its space. Movable; where you leave it is remembered.
-- Switched off by the option auctionMaterials, in which case Materials stays inside the GoldFinder tab.

local _, GF = ...

local W_DEFAULT, H_DEFAULT = 460, 520

-- d: CreateUI(parent, opts), Cfg(key), Print(line)
function GF.InitAuctionMaterials(d)
  local format = string.format
  local L = GF.L
  local win, ui
  local isOpen, hooked = false, false

  -- Default: to the right of the auction house, as tall as it is. A position you dragged it to wins.
  local function Place()
    local ah = rawget(_G, "AuctionHouseFrame")
    local h = ah and ah.GetHeight and ah:GetHeight()
    if type(h) ~= "number" or h < 100 then h = H_DEFAULT end
    win:SetSize(W_DEFAULT, h)
    win:ClearAllPoints()
    local pos = GoldFinderForeverDB and GoldFinderForeverDB.matsPos
    if type(pos) == "table" and type(pos[1]) == "string" and type(pos[2]) == "string"
        and type(pos[3]) == "number" and type(pos[4]) == "number" then
      win:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    elseif ah then
      win:SetPoint("TOPLEFT", ah, "TOPRIGHT", 6, 0)
    else
      win:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end
  end

  local function Build()
    local UI = GF.UI
    local w = CreateFrame("Frame", "GoldFinderMaterials", UIParent)
    w:SetFrameStrata("HIGH")
    w:SetClampedToScreen(true)
    w:SetMovable(true)
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", w.StartMoving)
    w:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, _, relPoint, x, y = self:GetPoint()
      if GoldFinderForeverDB and point then GoldFinderForeverDB.matsPos = { point, relPoint, x, y } end
    end)
    local edge = UI.Flat(w, "BACKGROUND", { 1, 0.82, 0.25, 0.40 })
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    local bg = UI.Flat(w, "BORDER", UI.PAL.bg)
    bg:SetAllPoints()
    w.gfPadRight = 30   -- room for the close button at the right of the header
    local ok, res = pcall(d.CreateUI, w, { embedded = true, only = { "cuero" } })
    if not ok then
      w:Hide()
      d.Print(format(L["auction.tab.fail"], tostring(res)))
      return nil
    end
    local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetFrameLevel(w:GetFrameLevel() + 50)
    win, ui = w, res
    return w
  end

  local function Show()
    if not isOpen or not d.Cfg("auctionMaterials") then return end
    if not win and not Build() then return end
    Place()
    win:Show()
    if ui and ui.refresh then pcall(ui.refresh) end   -- the prices may have changed since the last time
    local ah = rawget(_G, "AuctionHouseFrame")
    if not hooked and ah and ah.HookScript then
      hooked = true
      ah:HookScript("OnHide", function() if win then win:Hide() end end)   -- however the auction house closes
    end
  end

  local events = CreateFrame("Frame")
  events:RegisterEvent("AUCTION_HOUSE_SHOW")
  events:RegisterEvent("AUCTION_HOUSE_CLOSED")
  events:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_CLOSED" then
      isOpen = false
      if win then win:Hide() end
      return
    end
    isOpen = true
    -- a moment after the auction house opens, like the tab: its own frame must exist first
    C_Timer.After(0.5, function()
      local ok, err = pcall(Show)
      if not ok then d.Print(format(L["auction.tab.fail"], tostring(err))) end
    end)
  end)

  GF.AuctionMaterialsWindow = function() return win end
end
