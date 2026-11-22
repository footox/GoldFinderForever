-- features/tracker/objectives.lua: the next route step on screen. A section of the objective tracker (ForeverCore column or
-- an own frame under ObjectiveTrackerFrame) and the skill-up chance and cost per point on each recipe row of the
-- professions window. Nothing of Blizzard is replaced and nothing protected is called. The texts come from
-- core/objective_text.lua; data and actions come from d. The APIs stay in Skin.Objectives and Skin.RecipeNotes.

local _, GF = ...

-- d: Cfg, Char, Counts, LearnText, OpenGuide, ProfOn, RecipeLookup, RouteFor, ShortMoney, SkillUpChance, UpdateTracker
function GF.InitObjectives(d)
  local UI = GF.UI
  local Skin = UI.Skin
  local Cfg, Char, LearnText, OpenGuide, ProfOn, RecipeLookup, RouteFor, ShortMoney, SkillUpChance, UpdateTracker =
    d.Cfg,
    d.Char,
    d.LearnText,
    d.OpenGuide,
    d.ProfOn,
    d.RecipeLookup,
    d.RouteFor,
    d.ShortMoney,
    d.SkillUpChance,
    d.UpdateTracker

  local function NameOf(id)
    local nm = C_Item.GetItemInfo(id)
    if not nm and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return nm
  end
  local function IconOf(id)
    return C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) or nil
  end
  -- llama a fn con sus argumentos y manda el error al manejador del juego (BugGrabber), sin cortar a los demas
  local function Safe(_, fn, ...)
    local n, args = select("#", ...), { ... }
    return xpcall(function() return fn(unpack(args, 1, n)) end, geterrorhandler())
  end

  -- SEGUIMIENTO DE OBJETIVOS
  local OB = { blocks = {} }
  Skin.Objectives = OB
  function OB.available() return type(ObjectiveTrackerFrame) == "table" end
  -- el siguiente paso va al seguimiento (y no a la ventana flotante)
  function OB.active() return Cfg("trackerMode") ~= "flotante" and OB.available() end

  local SectionMixin = {}
  function SectionMixin:LayoutContents()
    -- una seccion que ya no es la nuestra (ForeverCore la engancho tarde, con el marco propio ya dibujado) no pinta
    if OB.module ~= self or not OB.active() then return end
    local complete = OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR.Complete or nil
    for _, b in ipairs(OB.blocks) do
      local block = self:GetBlock(b.id)
      block:SetHeader(b.header)
      for _, l in ipairs(b.lines) do
        block:AddObjective(l.key, l.text, nil, nil, nil, l.kind == "ready" and complete or nil)
      end
      if not self:LayoutBlock(block) then return end
    end
  end

  local function TrackerMenu(target, menu)
    local prof = target and target.kind == "block" and target.id or nil
    menu:Title(prof or "GoldFinder Forever")
    menu:Open(GF.L["obj.openGuide"], function() OpenGuide(prof); return true end)
  end
  local function TrackerClick(target)
    OpenGuide(target and target.kind == "block" and target.id or nil)
    return true
  end

  -- la seccion en la columna de ForeverCore (SkillUp Forever); nil si no esta
  local function Section()
    if OB.tried then return OB.module end
    -- ForeverCore se publica al entrar al juego (o al salir de combate): se mira en cada pasada hasta tenerlo
    local fc = rawget(_G, "ForeverCore")
    local TS = type(fc) == "table" and fc.TrackerSection
    if not (type(TS) == "table" and type(TS.Create) == "function") then return nil end
    -- en combate no se crea (ForeverCore la dejaria aparcada y luego se veria a la vez que el marco propio):
    -- se vuelve a intentar al salir de combate
    if InCombatLockdown and InCombatLockdown() then
      if not OB.regen then
        OB.regen = CreateFrame("Frame")
        OB.regen:SetScript("OnEvent", function(f)
          f:UnregisterEvent("PLAYER_REGEN_ENABLED")
          xpcall(UpdateTracker, geterrorhandler())
        end)
      end
      OB.regen:RegisterEvent("PLAYER_REGEN_ENABLED")
      return nil
    end
    OB.tried = true
    local ok, module = pcall(TS.Create, "GoldFinderForeverObjectiveTracker", SectionMixin, {
      header = "GoldFinder Forever",
      contract = { menu = TrackerMenu, click = TrackerClick },
      safeCall = Safe,
      -- la columna no la acepto: se usa el marco propio
      onUnattached = function()
        OB.module = nil
        xpcall(UpdateTracker, geterrorhandler())
      end,
    })
    if ok and type(module) == "table" then OB.module = module end
    return OB.module
  end

  -- MARCO PROPIO con el estilo del seguimiento (sin ForeverCore): cabecera, entradas pulsables y lineas
  local function Font(name, fallback) return rawget(_G, name) and name or fallback end
  local function Fallback()
    local f = OB.frame
    if f then return f end
    f = CreateFrame("Frame", "GoldFinderObjectives", UIParent)
    f:SetSize(260, 30)
    f:SetFrameStrata("LOW")
    f.head = f:CreateFontString(nil, "OVERLAY", Font("ObjectiveTrackerHeaderFont", "GameFontNormal"))
    f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
    f.head:SetText("GoldFinder Forever")
    f.rule = f:CreateTexture(nil, "ARTWORK")
    local atlas = C_Texture and C_Texture.GetAtlasInfo
    if atlas and atlas("UI-QuestTracker-Primary-Objective-Header") then
      f.rule:SetAtlas("UI-QuestTracker-Primary-Objective-Header", true)
      f.rule:SetPoint("TOPLEFT", f, "TOPLEFT", -10, 4)
    else
      f.rule:SetColorTexture(1, 0.82, 0, 0.35)
      f.rule:SetHeight(1)
      f.rule:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -3)
      f.rule:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    end
    f.entries, f.lines = {}, {}
    OB.frame = f
    return f
  end
  local function Entry(f, i)
    local b = f.entries[i]
    if b then return b end
    b = CreateFrame("Button", nil, f)
    b:SetSize(240, 16)
    b.text = b:CreateFontString(nil, "OVERLAY", Font("ObjectiveTrackerLineFont", "GameFontNormalSmall"))
    b.text:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.text:SetWidth(240)
    b.text:SetJustifyH("LEFT")
    b:SetScript("OnClick", function(self) OpenGuide(self.prof) end)
    b:SetScript("OnEnter", function(self)
      self.text:SetTextColor(1, 1, 1)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText(self.prof or "GoldFinder Forever", 1, 0.82, 0)
      GameTooltip:AddLine(GF.L["obj.clickGuide"], 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
      local c = OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR.Header
      if c then self.text:SetTextColor(c.r, c.g, c.b) else self.text:SetTextColor(1, 0.82, 0) end
      GameTooltip:Hide()
    end)
    f.entries[i] = b
    return b
  end
  local function Line(f, i)
    local l = f.lines[i]
    if l then return l end
    l = f:CreateFontString(nil, "OVERLAY", Font("ObjectiveTrackerLineFont", "GameFontHighlightSmall"))
    l:SetWidth(230)
    l:SetJustifyH("LEFT")
    f.lines[i] = l
    return l
  end
  -- a la izquierda del seguimiento de objetivos, alineado arriba (como SkillUp): debajo se salia de la pantalla
  -- cuando la lista de misiones es larga
  local function Place(f)
    local T = ObjectiveTrackerFrame
    f:ClearAllPoints()
    if T and T.GetLeft and T:GetLeft() then
      f:SetPoint("TOPRIGHT", T, "TOPLEFT", -12, 0)
    else
      f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -260, -260)
    end
  end
  local function DrawFallback()
    local f = Fallback()
    if #OB.blocks == 0 then f:Hide(); return end
    Place(f)
    local hc = OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR.Header
    local nc = OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR.Normal
    local cc = OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR.Complete
    local y, nl = -28, 0
    for i, b in ipairs(OB.blocks) do
      local e = Entry(f, i)
      e.prof = b.id
      e.text:SetText(b.header)
      if hc then e.text:SetTextColor(hc.r, hc.g, hc.b) else e.text:SetTextColor(1, 0.82, 0) end
      local h = math.max(14, e.text:GetStringHeight() or 14)
      e:SetHeight(h)
      e:ClearAllPoints()
      e:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
      e:Show()
      y = y - h - 2
      for _, ln in ipairs(b.lines) do
        nl = nl + 1
        local l = Line(f, nl)
        l:SetText("- " .. ln.text)
        local c = ln.kind == "ready" and cc or nc
        if c then l:SetTextColor(c.r, c.g, c.b) else l:SetTextColor(0.8, 0.8, 0.8) end
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
        l:Show()
        y = y - math.max(12, l:GetStringHeight() or 12) - 2
      end
      y = y - 8
    end
    for i = #OB.blocks + 1, #f.entries do f.entries[i]:Hide() end
    for i = nl + 1, #f.lines do f.lines[i]:Hide() end
    f:SetHeight(-y)
    f:Show()
  end

  -- Lo llama UpdateTracker con las entradas de NextStepList ya ordenadas (sin sondeo propio). Devuelve true si
  -- falta algun nombre de objeto por cargar (UpdateTracker reintenta).
  function OB.refresh(entries)
    local blocks, waiting = {}, false
    if OB.active() then
      for _, e in ipairs(entries or {}) do
        local b, w = GF.ObjectiveBlock(e, NameOf, LearnText, IconOf, ShortMoney)
        blocks[#blocks + 1] = b
        waiting = waiting or w
      end
    end
    OB.blocks, OB.waiting = blocks, waiting
    local module = OB.available() and Section() or nil
    if module then
      if OB.frame then OB.frame:Hide() end
      -- la columna de ForeverCore rehace la seccion (fuera de combate); una lista vacia la oculta
      if module.MarkDirty then pcall(module.MarkDirty, module) end
    elseif OB.active() then
      DrawFallback()
    elseif OB.frame then
      OB.frame:Hide()
    end
    return waiting
  end
  -- true si en el aviso periodico hay que repintar aunque la firma no cambie: la pasada anterior esperaba nombres
  -- de objetos, o ForeverCore ya esta pero la seccion aun no se ha creado (se reintenta Section en cada pasada)
  function OB.pending()
    if OB.waiting then return true end
    if OB.tried or not OB.available() then return false end
    local fc = rawget(_G, "ForeverCore")
    return type(fc) == "table" and type(fc.TrackerSection) == "table" or false
  end

  -- NOTAS EN LA LISTA DE RECETAS
  local RN = { texts = setmetatable({}, { __mode = "k" }), hooked = setmetatable({}, { __mode = "k" }), owner = {},
    cache = {} }
  Skin.RecipeNotes = RN
  -- SkillUp Forever cargado y con su texto en las filas (su opcion showRowText, por defecto activa)
  local function SkillUpRowText()
    if not GF.IsAddOnLoaded("SkillUpForever") then return false end
    local db = rawget(_G, "SkillUpForeverDB")
    return not (type(db) == "table" and db.showRowText == false)
  end
  -- profesion abierta (la misma clave con la que CacheProfession la guarda); nil si es ajena o de hermandad
  local function OpenProf()
    local T = C_TradeSkillUI
    if not (T and T.GetBaseProfessionInfo) then return nil end
    if (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) or (T.IsTradeSkillGuild and T.IsTradeSkillGuild()) then return nil end
    local base = T.GetBaseProfessionInfo()
    return base and (base.professionName or base.parentProfessionName) or nil
  end
  -- probabilidad y coste por punto de una receta de la profesion abierta. Cache por profesion: se rehace si cambia
  -- la habilidad o el plan (InvalidateRoutes lo borra con las bolsas, la subasta y las recetas aprendidas).
  local function Note(info)
    if not (GoldFinderForeverDB and Cfg("recipeNotes") and info and info.name) or info.learned == false then return nil end
    local prof = OpenProf()
    local c = Char()
    local pd = prof and ProfOn(prof) and c.prof[prof] or nil
    if not (pd and pd.rank and pd.skillLine) then return nil end
    local plan = RouteFor(c, prof, pd.rank + (Cfg("routeSpan") or 25)) or false
    local pc = RN.cache[prof]
    if not (pc and pc.plan == plan and pc.rank == pd.rank) then
      pc = { plan = plan, rank = pd.rank, notes = {} }
      RN.cache[prof] = pc
    end
    local key = info.name:lower()
    local n = pc.notes[key]
    if n == nil then
      local x = RecipeLookup(pd.skillLine, info.name)
      -- eff false = algun material sin precio (la nota dice "sin precio")
      local eff
      if plan and plan.eff then eff = plan.eff[key] end
      n = x and { chance = SkillUpChance(x, pd.rank), eff = eff, recipe = x } or false
      pc.notes[key] = n
    end
    if not n then return nil end
    return n.chance, n.eff, n.recipe
  end
  -- how many of this recipe the bags can make right now (never cached: the bags change); nil when unknown
  local function CanMake(recipe)
    if not (recipe and d.Counts) then return nil end
    return GF.CraftableCount(recipe.r, function(id) return (d.Counts(id)) end)
  end
  local function Leave(self)
    if GameTooltip:GetOwner() == self and self.gfNoteTip then GameTooltip:Hide() end
    self.gfNoteTip = nil
  end
  function RN.decorate(row, elementData)
    local data = elementData and elementData.GetData and elementData:GetData()
    local info = data and data.recipeInfo
    local fs = RN.texts[row]
    local text
    if info and not SkillUpRowText() then
      local chance, eff, recipe = Note(info)
      text = GF.RecipeNoteText(chance, eff, ShortMoney, CanMake(recipe))
    end
    if not text then
      if fs then fs:Hide() end
      return
    end
    if not fs then
      fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetJustifyH("RIGHT")
      RN.texts[row] = fs
    end
    fs:ClearAllPoints()
    local lock = row.LockedIcon
    if lock and lock.IsShown and lock:IsShown() then
      fs:SetPoint("RIGHT", lock, "LEFT", -2, 0)
    else
      fs:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    end
    fs:SetText(text)
    fs:Show()
  end
  -- con SkillUp escribiendo en la fila: las cifras de GoldFinder van al tooltip de la fila (el de SkillUp o el
  -- del juego, si ya lo muestran; si no, uno propio). Se anaden un instante despues para ir tras su contenido.
  function RN.enter(_, row, data)
    if not (row and SkillUpRowText()) then return end
    local info = data and data.recipeInfo
    local chance, eff, recipe = Note(info)
    if not chance then return end
    local lines = GF.RecipeNoteLines(chance, eff, ShortMoney, CanMake(recipe))
    C_Timer.After(0, function()
      if not (row:IsVisible() and row:IsMouseOver()) then return end
      local tip = GameTooltip
      if tip:IsShown() and tip:GetOwner() == row then
        tip:AddLine(" ")
      else
        tip:SetOwner(row, "ANCHOR_RIGHT")
        tip:SetText(info.name, 1, 1, 1)
        row.gfNoteTip = true
      end
      for _, l in ipairs(lines) do tip:AddLine(l, 1, 0.82, 0) end
      tip:Show()
    end)
    if not RN.hooked[row] and row.HookScript then
      RN.hooked[row] = true
      row:HookScript("OnLeave", Leave)
    end
  end
  -- vuelve a escribir las filas visibles (ajuste cambiado, bolsas, subasta, habilidad): lo llama UpdateTracker
  function RN.refresh()
    local box = RN.box
    if not (box and box.ForEachFrame and ProfessionsFrame and ProfessionsFrame:IsShown()) then return end
    box:ForEachFrame(function(row, elementData) RN.decorate(row, elementData) end)
  end
  function RN.attach()
    if RN.attached then return end
    local page = type(ProfessionsFrame) == "table" and ProfessionsFrame.CraftingPage
    local list = type(page) == "table" and page.RecipeList
    local box = type(list) == "table" and list.ScrollBox
    if not (type(box) == "table" and ScrollUtil and ScrollUtil.AddInitializedFrameCallback) then return end
    RN.attached, RN.box = true, box
    ScrollUtil.AddInitializedFrameCallback(box, function(_, row, elementData)
      xpcall(function() RN.decorate(row, elementData) end, geterrorhandler())
    end, RN.owner)
    if type(EventRegistry) == "table" and EventRegistry.RegisterCallback then
      EventRegistry:RegisterCallback("Professions.RecipeListOnEnter", function(owner, row, data)
        xpcall(function() RN.enter(owner, row, data) end, geterrorhandler())
      end, RN.owner)
    end
    RN.refresh()
  end
  -- Blizzard_Professions se carga bajo demanda
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "TRADE_SKILL_SHOW" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(self)
    if RN.attached then self:UnregisterAllEvents(); return end
    if ProfessionsFrame then xpcall(RN.attach, geterrorhandler()) end
  end)
end
