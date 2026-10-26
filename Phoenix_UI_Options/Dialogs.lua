local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Dialog windows behind PUI.Dialogs (plan 1.26/1.27). One reusable window:
-- glass panel, accent bar, title, wrapped body, optional read-only copy box,
-- and a right-aligned button row (primary on the right). Escape cancels,
-- Enter accepts (G10). Every show resets text, buttons and timers (G37). The
-- keep/revert countdown is an owned Ticker entry (G2, G33).
local Options, Kit, Theme = PUI.Options, PUI.Options.Kit, PUI.Theme
local D = {}
Options.Dialogs = D

local W = 440
local win

local function build()
  local f = PUI:CreateFrame("Frame", "PhoenixUIDialog", UIParent, nil, "Options")
  f:SetSize(W, 180)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  Kit.Window(f)
  local bar = Kit.AccentBar(f, 3, 22)
  bar:SetPoint("TOPLEFT", 20, -22)
  f.title = Kit.Text(f, "title", "text.primary")
  f.title:SetPoint("LEFT", bar, "RIGHT", 10, 0)
  f.title:SetPoint("RIGHT", f, "RIGHT", -20, 0)
  f.body = Kit.Text(f, "text", "text.secondary")
  f.body:SetPoint("TOPLEFT", 20, -60)
  f.body:SetPoint("RIGHT", f, "RIGHT", -20, 0)
  f.body:SetJustifyV("TOP")
  f.body:SetWordWrap(true)
  f.body:SetSpacing(3)
  -- copy box (hidden unless Copy)
  local box = CreateFrame("EditBox", nil, f)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetFontObject(Kit.FontObject("mono"))
  box:SetTextInsets(10, 10, 8, 8)
  local boxBg = box:CreateTexture(nil, "BACKGROUND")
  boxBg:SetAllPoints()
  Theme:Paint(boxBg, "bg0", 0.9)
  box:SetScript("OnEscapePressed", function() D:Cancel() end)
  -- read-only: typing restores the original text, so a stray key never loses it
  box:SetScript("OnTextChanged", function(self, user) if user and D.copyText then self:SetText(D.copyText); self:HighlightText() end end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.box = box
  f.hint = Kit.Text(f, "small", "muted")
  f.buttons = {
    Kit.Button(f, "", 120, function() D:Accept() end, "primary"),
    Kit.Button(f, "", 110, function() D:Cancel() end, "secondary"),
  }
  f.buttons[1]:SetPoint("BOTTOMRIGHT", -20, 18)
  f.buttons[2]:SetPoint("RIGHT", f.buttons[1], "LEFT", -10, 0)
  -- Escape closes through UISpecialFrames (the OnHide below treats it as Cancel);
  -- Enter accepts out of combat (keyboard propagation is restricted in combat).
  tinsert(UISpecialFrames, "PhoenixUIDialog")
  f:SetScript("OnHide", function() if D.current then D:Cancel(true) end end)
  f:EnableKeyboard(true)
  f:SetPropagateKeyboardInput(true)
  f:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then return end
    local mine = key == "ENTER" and not D.copyText
    self:SetPropagateKeyboardInput(not mine)
    if mine then D:Accept() end
  end)
  f:Hide()
  return f
end

-- Reset everything a previous dialog may have set (G37).
local function reset(spec)
  win = win or build()
  PUI.Ticker:Unregister("dialogs.countdown")
  D.current = spec
  D.copyText = nil
  win.box:Hide()
  win.box:SetText("")
  win.hint:Hide()
  win.hint:SetText("")
  win.body:SetText(spec.text or "")
  win.title:SetText(spec.title or "")
  win.buttons[1]:SetLabel(spec.accept or "OK")
  Theme:Paint(win.buttons[1].bg, spec.danger and "err" or "accent", 1, "vertex")
  win.buttons[2]:SetLabel(spec.cancel or "Cancel")
  win.buttons[2]:SetShown(spec.cancel ~= false)
  return win
end

local function fit(extra)
  local h = 60 + math.max(18, win.body:GetStringHeight() or 18) + (extra or 0) + 70
  win:SetHeight(math.floor(h + 0.5))
end

local function finish(which, fromHide)
  local f = win
  if not (f and D.current) then return end
  local spec = D.current
  PUI.Ticker:Unregister("dialogs.countdown")
  D.current = nil
  if not fromHide then f:Hide() end
  local fn = spec and spec[which]
  if fn then securecallfunction(fn) end
end

function D:Accept() finish("onAccept") end
-- Cancel, Escape and closing all count as "not accepted"; KeepOrRevert reverts (G10).
function D:Cancel(fromHide) finish("onCancel", fromHide) end
function D:Close() finish("onCancel") end
function D:IsShown() return win ~= nil and D.current ~= nil end
function D:Current() return win and D.current end

function D:Confirm(spec)
  if self:IsShown() then self:Cancel() end
  reset(spec)
  fit()
  win:Show()
  return win
end

function D:KeepOrRevert(spec)
  if self:IsShown() then self:Cancel() end
  local left = spec.seconds
  local s = { title = spec.title, accept = spec.keep or "Keep these settings", cancel = spec.revert or "Revert",
    onAccept = spec.onKeep, onCancel = spec.onRevert }
  local base = spec.text or "Your screen changed. Keep these settings?"
  s.text = string.format("%s\nReverting in %d seconds.", base, left)
  reset(s)
  fit()
  win:Show()
  PUI.Ticker:Register("dialogs.countdown", 1, function()
    left = left - 1
    if left <= 0 then return D:Cancel() end
    win.body:SetText(string.format("%s\nReverting in %d seconds.", base, left))
  end, "Options")
  return win
end

function D:Copy(title, text, hint)
  if self:IsShown() then self:Cancel() end
  reset({ title = title, accept = "Done", cancel = false })
  D.copyText = text
  win.body:SetText("")
  win.box:SetPoint("TOPLEFT", 20, -58)
  win.box:SetPoint("RIGHT", win, "RIGHT", -20, 0)
  win.box:SetHeight(150)
  win.box:SetText(text)
  win.box:Show()
  win.hint:SetText(hint or "The text is selected. Press Ctrl+C to copy it, then Escape to close.")
  win.hint:SetPoint("TOPLEFT", win.box, "BOTTOMLEFT", 2, -8)
  win.hint:Show()
  win:SetHeight(58 + 150 + 30 + 70)
  win:Show()
  win.box:SetFocus()
  win.box:HighlightText()
  return win
end
