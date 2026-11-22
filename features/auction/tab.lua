-- features/auction/tab.lua: the GoldFinder tab inside the auction house (LibAHTab, the same library Auctionator and TSM
-- use). It builds the panel once and hosts the window with the auction views only.

local _, GF = ...

-- d: CreateUI, Print
function GF.InitAuctionTab(d)
  local format, floor = string.format, math.floor
  local L = GF.L
  local TAB_ID = "GoldFinderTab"
  local panelBuilt = false

  local function BuildTab()
    if panelBuilt or not AuctionHouseFrame or not AuctionHouseFrame.Tabs then return end
    local LibAHTab = LibStub and LibStub("LibAHTab-1-0", true)
    if not LibAHTab then return end
    if LibAHTab:DoesIDExist(TAB_ID) then panelBuilt = true return end
    local panel = CreateFrame("Frame", nil, AuctionHouseFrame)
    panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 14, -64)
    panel:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -14, 36)
    -- solo lo que se usa en la subasta: Bolsas (subasta primero), Compras y Cuero; Ajustes en la cabecera
    d.CreateUI(panel, { auction = true })
    LibAHTab:CreateTab(TAB_ID, panel, "GoldFinder", "GoldFinder Forever")   -- texto de la pestana (corto) y titulo
    panelBuilt = true

    -- el boton de la pestana puede salir estirado: se limita a un ancho normal
    local btn = LibAHTab:GetButton(TAB_ID)
    if btn then
      local reported = false
      local function fixWidth()
        local w = btn:GetWidth()
        if w and w > 200 then
          if not reported then
            reported = true
            d.Print(format(L["auction.tab.width"], floor(w)))
          end
          btn:SetWidth(110)
        end
      end
      fixWidth()
      C_Timer.After(0.2, fixWidth)
      btn:HookScript("OnShow", fixWidth)
      btn:HookScript("OnClick", function() C_Timer.After(0, fixWidth) end)
    end
  end

  local tabEvents = CreateFrame("Frame")
  tabEvents:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
  tabEvents:RegisterEvent("AUCTION_HOUSE_SHOW")
  tabEvents:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
      local ok, err = pcall(BuildTab)
      if not ok then d.Print(format(L["auction.tab.fail"], tostring(err))) end
    end)
  end)
end
