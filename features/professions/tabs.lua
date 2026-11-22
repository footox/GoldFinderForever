-- features/professions/tabs.lua: the Ruta and Fabricar tabs at the foot of the professions window. Everything goes
-- through hooksecurefunc and HookScript: no Blizzard handler is replaced and nothing protected is called.

local _, GF = ...

-- d: Cfg, Char, CreateUI, ProfOn, RouteFor
function GF.InitProfTabs(d)
  local UI = GF.UI
  local Flat, NewFrame, Btn, Skin = UI.Flat, UI.NewFrame, UI.Btn, UI.Skin
  local Cfg, Char, CreateUI, ProfOn, RouteFor =
    d.Cfg, d.Char, d.CreateUI, d.ProfOn, d.RouteFor

  local P = { tabs = {}, hooked = {}, order = { "ruta", "fabricar" }, labels = { ruta = "tab.route", fabricar = "tab.craft" } }
  Skin.ProfTabs = P   -- los ajustes (profTabs, craftTab, routeTab) recolocan las pestanas con P.later

  -- profesion abierta en la ventana, con la misma clave con la que CacheProfession la guarda
  function P.prof()
    local T = C_TradeSkillUI
    if not (T and T.GetBaseProfessionInfo) then return nil end
    if (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) or (T.IsTradeSkillGuild and T.IsTradeSkillGuild()) then return nil end
    local base = T.GetBaseProfessionInfo()
    return base and (base.professionName or base.parentProfessionName) or nil
  end

  function P.keys()
    if not (GoldFinderForeverDB and Cfg("profTabs")) then return {} end
    local prof = P.prof()
    local c = Char()
    local pd = prof and ProfOn(prof) and c.prof[prof] or nil
    local hasRoute = pd and pd.rank and Cfg("routeTab")
      and RouteFor(c, prof, pd.rank + (Cfg("routeSpan") or 25)) ~= nil
    return GF.ProfTabKeys(pd, Cfg("craftTab"), Cfg("routeTab"), hasRoute)
  end

  -- ultima pestana visible al pie de la ventana que no es nuestra (las de Blizzard o las de SkillUp)
  function P.lastTab(win)
    local bottom, best, bestRight = win:GetBottom(), nil, nil
    if not bottom then return nil end
    local function scan(holder)
      for _, c in ipairs({ holder:GetChildren() }) do
        if not c.gfProfTab and c:IsShown() and c:IsObjectType("Button") and c.Text and (c.LeftActive or c.Left) then
          local top, right = c:GetTop(), c:GetRight()
          if top and right and math.abs(top - bottom) < 14 and (not bestRight or right > bestRight) then
            best, bestRight = c, right
          end
        end
      end
    end
    scan(win)
    if type(win.TabSystem) == "table" and win.TabSystem.GetChildren then scan(win.TabSystem) end
    return best
  end

  function P.hide()
    P.current = nil
    if P.page then P.page:Hide() end
  end

  -- la pagina del juego vuelve (pestana del juego, otra pagina o la ventana se abre de nuevo)
  function P.native()
    P.hide()
    P.later()
  end

  -- cualquier pagina o pestana lateral del juego devuelve la ventana a Blizzard
  function P.hookNative(win)
    local function hook(fr, script)
      if type(fr) == "table" and fr.HookScript and not P.hooked[fr] then
        P.hooked[fr] = true
        fr:HookScript(script, P.native)
      end
    end
    if type(win.Pages) == "table" then for _, page in ipairs(win.Pages) do hook(page, "OnShow") end end
    for _, n in ipairs({ "CraftingPage", "BookPage", "SpecPage", "OrdersPage" }) do hook(win[n], "OnShow") end
    hook(win.ProfessionsOverviewTab, "OnMouseUp")
    if type(win.rightProfessionTabs) == "table" then
      for _, t in ipairs(win.rightProfessionTabs) do hook(t, "OnMouseUp") end
    end
  end

  function P.sync()
    local win = ProfessionsFrame
    if not (P.installed and type(win) == "table") then return end
    P.hookNative(win)
    local on = {}
    if win:IsShown() then for _, k in ipairs(P.keys()) do on[k] = true end end
    if P.current and not on[P.current] then P.hide() end
    local prev = P.lastTab(win)
    for _, k in ipairs(P.order) do
      local b = P.tabs[k]
      if b then
        b:SetShown(on[k] == true)
        if on[k] then
          b:ClearAllPoints()
          if not (prev and pcall(b.SetPoint, b, "LEFT", prev, "RIGHT", 3, 0)) then
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 11, 4)
          end
          prev = b
        end
        if b.gfPanel then
          local fn = (k == P.current) and PanelTemplates_SelectTab or PanelTemplates_DeselectTab
          if fn then pcall(fn, b) end
        elseif k == P.current then b:LockHighlight() else b:UnlockHighlight() end
      end
    end
  end

  -- una recolocacion en el siguiente frame, por muchas veces que se pida en este
  function P.later()
    if P.queued then return end
    P.queued = true
    C_Timer.After(0, function()
      P.queued = false
      xpcall(P.sync, geterrorhandler())
    end)
  end

  -- tras los eventos de la ventana (CacheProfession ya guardo las recetas): pestanas y, si cambio la profesion, datos
  function P.update()
    P.sync()
    if P.current and P.ui and P.page:IsShown() then
      local prof = P.prof()
      if prof ~= P.ui.profFilter then
        P.ui.profFilter = prof
        P.ui.refresh()
      end
    end
  end

  function P.soon()
    if P.waiting then return end
    P.waiting = true
    C_Timer.After(0.8, function()
      P.waiting = false
      xpcall(P.update, geterrorhandler())
    end)
  end

  function P.build(win)
    if P.ui then return end
    -- debajo del retrato y la barra del titulo; por encima de la pagina de recetas, que queda tapada
    local page = CreateFrame("Frame", "GoldFinderProfessionPage", win)
    page:SetPoint("TOPLEFT", win, "TOPLEFT", 4, -58)
    page:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 4)
    -- capa superior a la de la ventana: con solo subir el nivel, la lista de recetas (y skins como EllesmereUI)
    -- quedaba por encima y la pagina no se veia aunque estuviera mostrada
    local above = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG", DIALOG = "FULLSCREEN" }
    page:SetFrameStrata(above[win:GetFrameStrata()] or "HIGH")
    page:SetFrameLevel(math.min(win:GetFrameLevel() + 40, 9000))
    page:SetToplevel(true)
    page:EnableMouse(true)
    local bg = Flat(page, "BACKGROUND", { 0.05, 0.05, 0.05, 0.97 }); bg:SetAllPoints()
    page:Hide()
    P.page = page
    P.ui = CreateUI(page, { embedded = true, only = P.order, onNav = P.later,
      back = function() P.hide(); P.sync() end })
  end

  function P.select(key)
    local win = ProfessionsFrame
    if not (type(win) == "table" and win:IsShown()) then return end
    -- solo pestanas que tocan ahora (ajuste apagado o profesion sin recetas: no se abre)
    local allowed = false
    for _, k in ipairs(P.keys()) do if k == key then allowed = true; break end end
    if not allowed then P.sync(); return end
    -- si hay una pagina de SkillUp (ForeverCore) elegida, se devuelve la ventana al juego antes de tapar
    pcall(function()
      local FT = type(ForeverCore) == "table" and ForeverCore.ProfessionTabs
      if type(FT) == "table" and FT.Selected and FT.ShowNative and FT.Selected() then FT.ShowNative() end
    end)
    P.build(win)
    P.current = key
    P.ui.profFilter = P.prof()
    P.ui.current = key
    if P.page:IsShown() then P.ui.refresh() else P.page:Show() end
    P.sync()
  end

  -- otra pestana de la ventana (SkillUp) elegida: nuestra pagina se va. Las nuestras se ignoran.
  function P.other(tab, selected)
    if type(tab) ~= "table" or tab.gfProfTab or not tab.GetParent then return end
    local win = ProfessionsFrame
    if not win or tab:GetParent() ~= win then return end
    if selected and P.current then P.hide() end
    P.later()
  end

  function P.install()
    local win = ProfessionsFrame
    if P.installed or type(win) ~= "table" or not win.HookScript then return end
    P.installed = true
    for _, k in ipairs(P.order) do
      local b = NewFrame("Button", "GoldFinderProfTab_" .. k, win, "PanelTabButtonTemplate")
      if b then
        b.gfPanel = true
        b:SetText(GF.L[P.labels[k]])
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 0) end
      else
        b = Btn(win, GF.L[P.labels[k]], 90, 22)
      end
      b.gfProfTab = true
      b:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
        P.select(k)
      end)
      b:Hide()
      P.tabs[k] = b
    end
    win:HookScript("OnShow", P.later)
    win:HookScript("OnHide", P.hide)
    if type(hooksecurefunc) == "function" then
      if type(PanelTemplates_SelectTab) == "function" then
        hooksecurefunc("PanelTemplates_SelectTab", function(tab) P.other(tab, true) end)
      end
      if type(PanelTemplates_DeselectTab) == "function" then
        hooksecurefunc("PanelTemplates_DeselectTab", function(tab) P.other(tab, false) end)
      end
    end
    if type(EventRegistry) == "table" and EventRegistry.RegisterCallback then
      pcall(EventRegistry.RegisterCallback, EventRegistry, "ProfessionsFrame.TabSet", P.native, P)
      pcall(EventRegistry.RegisterCallback, EventRegistry, "Professions.ProfessionSelected", P.soon, P)
    end
    P.sync()
  end

  -- Blizzard_Professions se carga bajo demanda: se instala en cuanto existe la ventana
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event)
    if not P.installed and ProfessionsFrame then xpcall(P.install, geterrorhandler()) end
    if P.installed and event:find("^TRADE_SKILL") then P.soon() end
  end)
end
