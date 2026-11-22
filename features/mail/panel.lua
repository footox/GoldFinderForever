-- features/mail/panel.lua: the mailbox panel and the "Enviar al banquero" button. Container: data comes from d, the
-- plan from GF.MailPlan, drawing from GF.UI. Each click attaches whole stacks and sends one mail.

local _, GF = ...

-- d: Cfg, BagRows, BankerName, ToBanker, ShortMoney, Money, Print, ItemLink
function GF.InitMail(d)
  local UI = GF.UI
  local Text, Btn, PAL, Skin = UI.Text, UI.Btn, UI.PAL, UI.Skin
  local Cfg, BagRows, BankerName, ToBanker, ShortMoney, Money, Print, ItemLink =
    d.Cfg, d.BagRows, d.BankerName, d.ToBanker, d.ShortMoney, d.Money, d.Print, d.ItemLink
  local format = string.format
  local L = GF.L
  local MAIL_LINES = 14
  local ROW_H = 22
  local RefreshMail


  local pending      -- correo enviado que espera MAIL_SEND_SUCCESS / MAIL_FAILED
  local excluded = {}   -- objetos que el jugador desmarco: no van en este correo (se olvida al cerrar el buzon)

  -- sobrante por objeto: las mismas filas que lista el panel (veredicto AH, para el banquero, sin ligar)
  local function Surplus()
    local surplus, rows = {}, {}
    for _, r in ipairs(BagRows()) do
      if r.verdict == "AH" and r.toBanker and not r.bound and (r.sellQty or 0) > 0 then
        surplus[r.id] = r.sellQty
        rows[#rows + 1] = r
      end
    end
    return surplus, rows
  end

  -- plan del correo con solo lo marcado; rows son todas las filas (marcadas o no) y sel el resumen de lo marcado
  local function Plan()
    local _, rows = Surplus()
    local sel = GF.MailSelect(rows, excluded)
    return GF.MailPlan(GF.BagSlots(), sel.surplus, tonumber(ATTACHMENTS_MAX_SEND) or 12), rows, sel
  end

  local function MailOpen() return MailFrame and MailFrame:IsShown() end
  local function SendOpen() return MailOpen() and SendMailFrame and SendMailFrame:IsShown() end

  -- adjuntos que ya tiene el correo (si el jugador puso algo, no se mezcla con lo nuestro)
  local function Attached()
    if not GetSendMailItem then return 0 end
    local n = 0
    for i = 1, (tonumber(ATTACHMENTS_MAX_SEND) or 12) do
      local ok, name = pcall(GetSendMailItem, i)
      if ok and name then n = n + 1 end
    end
    return n
  end

  local function Fail(msg)
    if ClearCursor then pcall(ClearCursor) end
    Print(format(L["mail.fail"], msg))
  end

  -- coge la pila con el cursor y la suelta en la casilla i del correo (como los addons de correo)
  local function AttachOne(s, i)
    local CC = C_Container
    local info = CC.GetContainerItemInfo(s.bag, s.slot)
    if not info or info.itemID ~= s.id or (info.stackCount or 1) ~= s.count or info.isLocked then
      return false, format(L["mail.err.bagChanged"], ItemLink(s.id))
    end
    if CursorHasItem and CursorHasItem() then return false, L["mail.err.cursor"] end
    if not pcall(CC.PickupContainerItem, s.bag, s.slot) then return false, format(L["mail.err.pickup"], ItemLink(s.id)) end
    if not (CursorHasItem and CursorHasItem()) then return false, format(L["mail.err.pickup"], ItemLink(s.id)) end
    if not pcall(ClickSendMailItemButton, i) then return false, format(L["mail.err.attach"], ItemLink(s.id)) end
    if CursorHasItem() then return false, format(L["mail.err.attach"], ItemLink(s.id)) end
    return true
  end

  local function SendToBanker()
    local banker = BankerName()
    if not banker or not ToBanker() then return Print(L["mail.nobanker"]) end
    -- en Forever el correo necesita "Nombre Apellido": con solo el nombre de pila podria llegar a otro personaje
    if not banker:find(" ", 1, true) then
      return Print(format(L["mail.nosurname"], banker))
    end
    if pending then return Print(L["mail.wait"]) end
    if not MailOpen() then return Print(L["mail.openbox"]) end
    if not (C_Container and C_Container.PickupContainerItem and C_Container.GetContainerItemInfo
      and ClickSendMailItemButton and GetSendMailItem and SendMail and CursorHasItem) then
      return Print(L["mail.unsupported"])
    end
    -- pestana Enviar: el mismo clic que hace el jugador en la interfaz por defecto
    if not SendOpen() and MailFrameTab2 and MailFrameTab2.Click then pcall(MailFrameTab2.Click, MailFrameTab2) end
    if not SendOpen() then return Print(L["mail.nosendtab"]) end
    if Attached() > 0 then return Print(L["mail.hasattach"]) end
    if (GetSendMailMoney and (GetSendMailMoney() or 0) > 0) or (GetSendMailCOD and (GetSendMailCOD() or 0) > 0) then
      return Print(L["mail.hasmoney"])
    end
    local p = Plan()
    if #p.attach == 0 then return Print(format(L["mail.nothing"], banker)) end
    if SendMailNameEditBox then SendMailNameEditBox:SetText(banker) end
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(L["mail.subject"]) end
    for i, s in ipairs(p.attach) do
      if not SendOpen() then return Fail(L["mail.err.closed"]) end
      local ok, why = AttachOne(s, i)
      if not ok then return Fail(format(L["mail.err.review"], why)) end
    end
    -- el cliente puede tardar un instante en mostrar los adjuntos: se comprueba otra vez antes de enviar
    pending = { banker = banker, n = p.stacks, remaining = p.remaining, sending = false }
    C_Timer.After(0.3, function()
      if not pending or pending.sending then return end
      if not SendOpen() or Attached() ~= #p.attach then
        pending = nil
        return Fail(L["mail.err.missing"])
      end
      -- cuerpo propio: un borrador que tuviera escrito el jugador no se envia
      local mine = pending
      mine.sending = true
      local ok, err = pcall(SendMail, banker, L["mail.subject"], L["mail.body"])
      if not ok then
        pending = nil
        Fail(tostring(err))
        return
      end
      -- si el servidor no responde (sin MAIL_SEND_SUCCESS ni MAIL_FAILED), el boton no se queda bloqueado
      C_Timer.After(10, function()
        if pending == mine then
          pending = nil
          Print(L["mail.noresponse"])
          pcall(RefreshMail)
        end
      end)
    end)
  end

  local function Tip(btn)
    local p = btn.plan
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["mail.button"], 1, 0.82, 0)
    GameTooltip:AddLine(format(L["mail.tip.to"], BankerName() or "?"), 1, 1, 1)
    if p then
      GameTooltip:AddLine(format(L["mail.tip.this"], p.stacks, p.units), 1, 1, 1)
      local postage = SendOpen() and Attached() > 0 and GetSendMailPrice and GetSendMailPrice()
      if postage then GameTooltip:AddLine(format(L["mail.tip.postage"], Money(postage)), 1, 1, 1)
      else GameTooltip:AddLine(format(L["mail.tip.postageApprox"], Money(30 * math.max(p.stacks, 1))), 1, 1, 1) end
      if p.remaining > 0 then GameTooltip:AddLine(format(L["mail.tip.after"], p.remaining), 0.7, 0.7, 0.7) end
      for i, s in ipairs(p.skipped) do
        if i > 8 then GameTooltip:AddLine(format(L["mail.more"], #p.skipped - 8), 0.7, 0.7, 0.7); break end
        GameTooltip:AddLine(format("%s x%d: %s", ItemLink(s.id), s.count, L["mail.skip." .. tostring(s.why)]), 1, 0.5, 0.3, true)
      end
    end
    GameTooltip:AddLine(L["mail.tip.rule"], 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "MAIL_SEND_SUCCESS", "MAIL_FAILED", "MAIL_CLOSED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, event, arg1)
    -- solo el envio que hizo GoldFinder (ya llamo a SendMail): otro correo enviado a mano no cuenta
    if event == "MAIL_SEND_SUCCESS" and pending and pending.sending then
      Print(format(L["mail.sent"], pending.banker, pending.n, pending.remaining))
      pending = nil
      C_Timer.After(0.5, function() pcall(RefreshMail) end)
    elseif event == "MAIL_FAILED" and pending then
      local who = pending.banker
      pending = nil
      Print(type(arg1) == "string" and format(L["mail.failedWith"], who, arg1) or format(L["mail.failedGeneric"], who))
      pcall(RefreshMail)
    elseif event == "MAIL_CLOSED" then
      pending = nil
      excluded = {}
    end
  end)

  -- una fila: casilla (marcada = va en el correo) + objeto, cantidad y valor
  local function NewRow(f, i)
    local row = {}
    row.cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    row.cb:SetSize(22, 22)
    row.cb:SetPoint("TOPLEFT", 12, -(52 + (i - 1) * ROW_H))
    row.cb:SetScript("OnClick", function(self)
      if self:GetChecked() then excluded[row.id] = nil else excluded[row.id] = true end
      pcall(RefreshMail)
    end)
    row.cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L["mail.check.tip"], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    row.cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.text = Text(f, 12, PAL.text)
    row.text:SetPoint("LEFT", row.cb, "RIGHT", 2, 0)
    row.text:SetWidth(250)
    row.text:SetJustifyH("LEFT")
    return row
  end

  function RefreshMail()
    local banker = BankerName()
    local f = GoldFinderMail
    if not Cfg("mailPanel") or not banker or not ToBanker() then
      if f then f:Hide() end
      return
    end
    local plan, rows, sel = Plan()
    local n = #rows
    if n == 0 then
      if f then f:Hide() end
      return
    end
    if not f then
      -- dialogo clasico (como el panel de venta): titulo "GoldFinder Forever" y debajo el subtitulo
      f = Skin.Panel("GoldFinderMail", MailFrame or UIParent, "dialog")
      f:SetWidth(310)
      f:SetFrameStrata("HIGH")
      f.head = Skin.Head(f, "GoldFinder Forever")
      f.title = Text(f, 12, PAL.text)
      f.title:SetPoint("TOPLEFT", 18, -36)
      f.rows = {}
      f.more = Text(f, 12, PAL.dim)
      f.foot = Text(f, 12, PAL.dim)
      f.foot:SetPoint("BOTTOMLEFT", 18, 44)
      f.send = Btn(f, L["mail.button"], 150, 22, nil, function() SendToBanker() end)
      f.send:SetPoint("BOTTOMLEFT", 16, 14)
      if f.send.SetMotionScriptsWhileDisabled then f.send:SetMotionScriptsWhileDisabled(true) end
      f.send:SetScript("OnEnter", Tip)
      f.send:SetScript("OnLeave", function() GameTooltip:Hide() end)
      f.mails = Text(f, 12, PAL.dim)
      f.mails:SetPoint("LEFT", f.send, "RIGHT", 8, 0)
      if MailFrame then f:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 2, -12)
      else f:SetPoint("LEFT", UIParent, "LEFT", 360, 60) end
    end
    f.title:SetText(format(L["mail.panel.title"], banker))
    local shown = math.min(n, MAIL_LINES)
    for i = 1, shown do
      local r = rows[i]
      local row = f.rows[i]
      if not row then row = NewRow(f, i); f.rows[i] = row end
      row.id = r.id
      row.cb:SetChecked(not excluded[r.id])
      row.text:SetText(format("%s  |cffffffffx%d|r  |cffb3b3b3%s|r", ItemLink(r.id), r.sellQty, ShortMoney(r.unit * r.sellQty)))
      row.text:SetAlpha(excluded[r.id] and 0.4 or 1)
      row.cb:Show()
      row.text:Show()
    end
    for i = shown + 1, #f.rows do f.rows[i].cb:Hide(); f.rows[i].text:Hide() end
    if n > MAIL_LINES then
      f.more:SetText(format(L["mail.more"], n - MAIL_LINES))
      f.more:ClearAllPoints()
      f.more:SetPoint("TOPLEFT", 18, -(58 + shown * ROW_H))
      f.more:Show()
    else
      f.more:Hide()
    end
    f.foot:SetText(format(L["mail.panel.foot"], sel.n, ShortMoney(sel.total)))
    f.send.plan = plan
    local mails = #plan.attach > 0 and (1 + plan.remaining) or 0
    if mails > 0 and MailOpen() then f.send:Enable() else f.send:Disable() end
    f.mails:SetText(mails > 0 and format(L["mail.panel.mails"], mails) or L["mail.panel.none"])
    f:SetHeight(56 + shown * ROW_H + (n > MAIL_LINES and 16 or 0) + 66)
    f:Show()
  end

  return { Refresh = RefreshMail }
end
