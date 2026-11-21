-- ui/widgets.lua: presentational building blocks shared by every window: flat textures, frames with the
-- default skin, text, buttons, and the Skin table with its panel/head/close/icon/bar helpers. No addon logic.

local _, GF = ...

local uiInstances = {}
local PAL = {
  bg = { 0.06, 0.07, 0.09, 0.97 }, panel = { 0.10, 0.11, 0.14, 1 }, card = { 0.13, 0.14, 0.18, 1 },
  gold = { 1, 0.82, 0.25 }, text = { 0.92, 0.93, 0.95 }, dim = { 0.60, 0.63, 0.70 },
}
local GREEN, ORANGE, BLUE, DIM = "|cff59eb8d", "|cffffa640", "|cff6cb4ff", "|cff9aa0a6"

local function Flat(parent, layer, c)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
  return t
end

-- Plantillas de Blizzard: si alguna no existe en este cliente, CreateFrame falla y se devuelve nil
-- para que quien llama use su plan B.
local function NewFrame(kind, name, parent, template)
  local ok, f = pcall(CreateFrame, kind, name, parent, template)
  if ok and f then return f end
  return nil
end

-- Fuentes del juego (las de las ventanas de Blizzard) segun el color y el tamano pedidos.
local function FontFor(size, color)
  local names
  if color == PAL.gold then
    names = size >= 18 and "GameFontNormalLarge" or (size <= 11 and "GameFontNormalSmall" or "GameFontNormal")
  elseif color == PAL.dim then
    names = size <= 11 and "GameFontDisableSmall" or "GameFontDisable"
  else
    names = size <= 11 and "GameFontHighlightSmall" or "GameFontHighlight"
  end
  return _G[names]
end

local function Text(parent, size, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  local font = FontFor(size or 12, color)
  if font then
    fs:SetFontObject(font)
  else
    fs:SetFont(STANDARD_TEXT_FONT, size or 12, "")
    local c = color or PAL.text
    fs:SetTextColor(c[1], c[2], c[3])
  end
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  return fs
end

-- Boton rojo clasico (UIPanelButtonTemplate). b.label es su texto y b.bg un tinte aditivo opcional
-- (b.base) para marcar un boton seleccionado. Sin la plantilla, el boton plano de antes.
local function Btn(parent, label, w, h, base, onClick)
  local tpl = NewFrame("Button", nil, parent, "UIPanelButtonTemplate")
  local b = tpl or CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  if tpl then
    if h <= 20 then
      local fn, fh, fd = _G["GameFontNormalSmall"], _G["GameFontHighlightSmall"], _G["GameFontDisableSmall"]
      if fn then b:SetNormalFontObject(fn) end
      if fh then b:SetHighlightFontObject(fh) end
      if fd then b:SetDisabledFontObject(fd) end
    end
    b:SetText(label)
    b.label = b.Text or b:GetFontString()
    if not b.label then
      b.label = Text(b, 12, PAL.gold, "CENTER")
      b.label:SetPoint("CENTER")
      b:SetFontString(b.label)
      b.label:SetText(label)
    end
    b.base = base or { 1, 1, 1, 0 }
    b.bg = b:CreateTexture(nil, "OVERLAY")
    b.bg:SetPoint("TOPLEFT", 3, -3); b.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    b.bg:SetColorTexture(b.base[1], b.base[2], b.base[3], b.base[4] or 1)
    b.bg:SetBlendMode("ADD")
  else
    b.base = base or { 1, 1, 1, 0.09 }
    b.bg = Flat(b, "BACKGROUND", b.base)
    b.bg:SetAllPoints()
    b.label = Text(b, 12, PAL.text, "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(label)
    b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 0.82, 0.25, 0.30) end)
    b:SetScript("OnLeave", function(self)
      self.bg:SetColorTexture(self.base[1], self.base[2], self.base[3], self.base[4] or 1)
    end)
  end
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- Marcos clasicos para las ventanas secundarias (guia, siguiente paso, correo, banco, vendedor, exportar).
-- Cada pieza tiene plan B: sin la plantilla o sin SetBackdrop queda el estilo plano de antes.
local Skin = {
  dialog = { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } },
  tooltip = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } },
  PLUS = { "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-PlusButton-Down",
    "Interface\\Buttons\\UI-PlusButton-Hilight" },
  MINUS = { "Interface\\Buttons\\UI-MinusButton-Up", "Interface\\Buttons\\UI-MinusButton-Down",
    "Interface\\Buttons\\UI-PlusButton-Hilight" },
  BOOK = { "Interface\\Icons\\INV_Misc_Book_09", nil, "Interface\\Buttons\\ButtonHilight-Square" },
}

-- Marco con borde de dialogo (style "dialog") o de tooltip ("tooltip"); sin BackdropTemplate, fondo plano.
function Skin.Panel(name, parent, style)
  local f = NewFrame("Frame", name, parent, "BackdropTemplate") or CreateFrame("Frame", name, parent)
  local ok = f.SetBackdrop and pcall(f.SetBackdrop, f, Skin[style] or Skin.dialog)
  if ok and style == "tooltip" then
    if f.SetBackdropColor then pcall(f.SetBackdropColor, f, 0, 0, 0, 0.75) end
    if f.SetBackdropBorderColor then pcall(f.SetBackdropBorderColor, f, 0.8, 0.8, 0.8, 1) end
  end
  if not ok then
    local bg = Flat(f, "BACKGROUND", PAL.bg); bg:SetAllPoints()
    local bar = Flat(f, "ARTWORK", { 1, 0.82, 0.25, 1 })
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(3)
  end
  f.gfSkinned = ok and true or false
  return f
end

-- Titulo centrado arriba, como en los dialogos del juego.
function Skin.Head(f, text)
  local h = Text(f, 13, PAL.gold, "CENTER")
  h:SetPoint("TOP", f, "TOP", 0, -16)
  h:SetText(text)
  return h
end

-- Boton de cerrar del juego (la X roja); sin la plantilla, el boton "x" de antes.
function Skin.Close(parent, onClick, size)
  local b = NewFrame("Button", nil, parent, "UIPanelCloseButton")
  if not b then return Btn(parent, "x", 18, 18, nil, onClick) end
  b:SetSize(size or 26, size or 26)
  b:SetScript("OnClick", onClick)
  return b
end

function Skin.SetIcon(b, tex)
  b:SetNormalTexture(tex[1])
  b:SetPushedTexture(tex[2] or tex[1])
  if not tex[2] then
    local p = b:GetPushedTexture()
    if p then p:SetVertexColor(0.6, 0.6, 0.6) end
  end
  if tex[3] then b:SetHighlightTexture(tex[3], "ADD") end
end

-- Boton pequeno con icono (y tooltip); si no se pueden poner las texturas, el boton con letra de antes.
function Skin.Icon(parent, size, tex, label, tip, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  if pcall(Skin.SetIcon, b, tex) then
    b.gfIcon = true
    b:SetScript("OnClick", onClick)
  else
    b:Hide()
    b = Btn(parent, label, 18, 18, nil, onClick)
  end
  if tip then
    b:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(tip, 1, 1, 1)
      GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return b
end

-- Boton de plegar: "+" si esta plegado, "-" si esta desplegado (icono o letra segun como se creo).
function Skin.Fold(b, collapsed)
  if b.gfIcon then pcall(Skin.SetIcon, b, collapsed and Skin.PLUS or Skin.MINUS)
  elseif b.label then b.label:SetText(collapsed and "+" or "-") end
end

-- Barra de progreso con la textura de las barras del juego (dorada).
function Skin.Bar(t)
  pcall(t.SetTexture, t, "Interface\\TargetingFrame\\UI-StatusBar")
  t:SetVertexColor(1, 0.82, 0.25, 1)
  return t
end

-- Resaltado de las listas de misiones (aditivo), con el color pedido.
function Skin.Quest(t, r, g, b, a)
  pcall(t.SetTexture, t, "Interface\\QuestFrame\\UI-QuestTitleHighlight")
  t:SetBlendMode("ADD")
  t:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
  return t
end

GF.UI = {
  instances = uiInstances, PAL = PAL, GREEN = GREEN, ORANGE = ORANGE, BLUE = BLUE, DIM = DIM,
  Flat = Flat, NewFrame = NewFrame, Text = Text, Btn = Btn, Skin = Skin,
}
