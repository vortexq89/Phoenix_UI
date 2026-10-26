local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Oracle palette window. Built on first open. Plain results run on Enter or
-- click. A secure result is handed to the single action button: its
-- attributes are set (out of combat) and the button is laid over the chosen
-- row and bound to Enter, so the next Enter or a click on the row runs it
-- through Blizzard's secure path.
local _, ns = ...
local OR, Theme, Media, CQ = ns.OR, PUI.Theme, PUI.Media, PUI.CombatQueue
local Palette = { rows = {}, results = {}, selected = 1 }
ns.Palette = Palette
local ROWS = 15

local action
local function actionButton()
  if action then return action end
  action = PUI:CreateFrame("Button", "PhoenixUI_OracleAction", UIParent, "SecureActionButtonTemplate", OR.OWNER or "Oracle")
  action:RegisterForClicks("AnyUp", "AnyDown")
  action:SetFrameStrata("DIALOG")
  action:HookScript("PostClick", function() Palette.Close() end)
  action:Hide()
  return action
end
Palette.ActionButton = actionButton

PUI.Layout:RegisterElement("oracle.palette", { label = "Oracle search", owner = "Oracle", size = { 460, 60 + ROWS * 22 },
  keys = "oracle", default = { point = "TOP", x = 0, y = -140 } })

local function build()
  if Palette.frame then return Palette.frame end
  local f = PUI:CreateFrame("Frame", "PhoenixUI_Oracle", UIParent, nil, "Oracle")
  f:SetSize(460, 60 + ROWS * 22)
  PUI.Layout:Place(f, "oracle.palette")
  f:SetFrameStrata("DIALOG")
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.8)
  local box = PUI:CreateFrame("EditBox", nil, f, nil, "Oracle")
  box:SetPoint("TOPLEFT", 12, -10)
  box:SetPoint("TOPRIGHT", -12, -10)
  box:SetHeight(26)
  box:SetFontObject(Media:FontObject("header"))
  box:SetAutoFocus(false)
  box:SetScript("OnTextChanged", function(self) Palette.Refresh(self:GetText()) end)
  box:SetScript("OnEscapePressed", function() Palette.Close() end)
  box:SetScript("OnEnterPressed", function() Palette.Choose(Palette.selected) end)
  box:SetScript("OnArrowPressed", function(_, key) Palette.Move(key == "UP" and -1 or (key == "DOWN" and 1 or 0)) end)
  box:SetAltArrowKeyMode(false)
  Theme:Backdrop(box, "surface.2")
  f.box = box
  f.hint = f:CreateFontString(nil, "OVERLAY")
  f.hint:SetFontObject(Media:FontObject("small"))
  f.hint:SetPoint("BOTTOMLEFT", 12, 8)
  for i = 1, ROWS do
    local r = PUI:CreateFrame("Button", nil, f, nil, "Oracle")
    r:SetPoint("TOPLEFT", 12, -42 - (i - 1) * 22)
    r:SetPoint("TOPRIGHT", -12, -42 - (i - 1) * 22)
    r:SetHeight(20)
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetFontObject(Media:FontObject("body"))
    r.text:SetPoint("LEFT", 6, 0)
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.49, 0.04, 0.25)
    r:SetScript("OnClick", function() Palette.Choose(i) end)
    r:Hide()
    Palette.rows[i] = r
  end
  f:Hide()
  Palette.frame = f
  return f
end

function Palette.Refresh(query)
  local results, inCombat = OR.Search(query)
  Palette.results = results
  Palette.selected = 1
  Palette.Disarm()
  for i, r in ipairs(Palette.rows) do
    local res = results[i]
    if res then r.text:SetText(res.text); r:Show() else r:Hide() end
  end
  Palette.frame.hint:SetText(inCombat and "In combat: panels, macros and mounts are hidden until combat ends." or "Enter runs; Up/Down to move; Esc closes.")
  Palette.Highlight()
end

function Palette.Highlight()
  for i, r in ipairs(Palette.rows) do r.hl:SetShown(i == Palette.selected) end
end

function Palette.Move(d)
  local n = #Palette.results
  if n == 0 then return end
  Palette.selected = ((Palette.selected - 1 + d) % n) + 1
  Palette.Disarm()
  Palette.Highlight()
end

-- Arm the secure button for a result (out of combat only).
function Palette.Arm(i, res)
  if InCombatLockdown() then return false end
  local b = actionButton()
  for k in pairs({ type = 1, clickbutton = 1, macro = 1 }) do b:SetAttribute(k, nil) end
  for k, v in pairs(res.secure) do b:SetAttribute(k, v) end
  b:ClearAllPoints()
  b:SetAllPoints(Palette.rows[i])
  b:Show()
  SetOverrideBindingClick(Palette.frame, true, "ENTER", "PhoenixUI_OracleAction")
  Palette.armed = i
  return true
end

function Palette.Disarm()
  if not Palette.armed then return end
  Palette.armed = nil
  CQ.Defer("oracle.disarm", function()
    if action then action:Hide() end
    if Palette.frame then ClearOverrideBindings(Palette.frame) end
  end)
end

function Palette.Choose(i)
  local res = Palette.results[i]
  if not res then return end
  OR.Remember(res.text)
  if res.secure then
    Palette.selected = i
    Palette.Highlight()
    if Palette.Arm(i, res) then
      Palette.frame.box:ClearFocus()
      Palette.frame.hint:SetText("Press Enter again (or click) to run: " .. res.text)
    else
      Palette.frame.hint:SetText("Not available in combat.")
    end
    return
  end
  Palette.Close()
  securecallfunction(res.run)
end

function Palette.Open()
  local f = build()
  f:Show()
  f.box:SetText("")
  f.box:SetFocus()
  Palette.Refresh("")
end

function Palette.Close()
  Palette.Disarm()
  if Palette.frame then Palette.frame.box:ClearFocus(); Palette.frame:Hide() end
end

function Palette.Toggle()
  if Palette.frame and Palette.frame:IsShown() then Palette.Close() else Palette.Open() end
end
