local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Action buttons (plan 5.4, mockup 05): SecureActionButtonTemplate buttons
-- with original visuals. The secure "action" attribute is the single source of
-- truth; OnAttributeChanged (an insecure observer) refreshes visuals when the
-- paging snippet moves a button to another slot. Engine values that may be
-- secret (usable, mana, in range, counts, cooldown durations, loss of
-- control) only reach widgets: SetVertexColor from EvaluateColorFromBoolean,
-- SetAlphaFromBoolean, SetText and SetCooldownFromDurationObject. Nothing here
-- compares or does arithmetic on them (G1).
local _, ns = ...
local Theme, Media, Secret = PUI.Theme, PUI.Media, PUI.Secret
local OWNER = "ActionBars"

local Btn = { all = {}, bySlot = {}, glowing = {}, assisted = {} }
ns.Buttons = Btn

-- Look settings shared by every Phoenix button (and the options preview).
local S = {
  tooltips = true, hotkeys = true, keyAbbrev = true, hotkeySize = 11, hotkeyColor = { r = 0.92, g = 0.92, b = 0.95, a = 1 },
  macroText = true, macroSize = 10, countSize = 12, showEmpty = false, lock = true,
  cdText = true, cdTextSize = 14, cdEdge = true, swipeAlpha = 0.8, dimOnCooldown = false, dimAlpha = 0.45,
  lossOfControl = true, rangeMode = "overlay",
  rangeColor = { r = 0.9, g = 0.2, b = 0.2, a = 0.5 }, unusableColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 },
  manaColor = { r = 0.35, g = 0.45, b = 1, a = 1 }, neverDim = {},
  zoom = 0.08, border = 1, borderColor = { r = 0, g = 0, b = 0, a = 1 },
  procGlow = "pulse", procColor = { r = 1, g = 0.78, b = 0.25, a = 1 },
  assist = false, assistColor = { r = 0.3, g = 0.85, b = 1, a = 1 },
}
ns.settings = S
Btn.S = S

local WHITE = CreateColor(1, 1, 1, 1)
local function color(c) return CreateColor(c.r, c.g, c.b, c.a or 1) end

-- Keybind text abbreviations (original table): modifiers become one letter,
-- mouse and numpad names are shortened so the text fits small buttons.
local ABBREV = {
  { "ALT%-", "A" }, { "CTRL%-", "C" }, { "SHIFT%-", "S" }, { "META%-", "M" },
  { "MOUSEWHEELUP", "WU" }, { "MOUSEWHEELDOWN", "WD" }, { "MIDDLEMOUSE", "M3" }, { "BUTTON(%d+)", "M%1" },
  { "NUMPADPLUS", "N+" }, { "NUMPADMINUS", "N-" }, { "NUMPADMULTIPLY", "N*" }, { "NUMPADDIVIDE", "N/" },
  { "NUMPADDECIMAL", "N." }, { "NUMPAD", "N" }, { "SPACEBAR", "Sp" }, { "SPACE", "Sp" }, { "BACKSPACE", "Bs" },
  { "CAPSLOCK", "Caps" }, { "INSERT", "Ins" }, { "DELETE", "Del" }, { "HOME", "Hm" }, { "PAGEUP", "PU" },
  { "PAGEDOWN", "PD" }, { "ENTER", "Ent" }, { "TAB", "Tab" }, { "ESCAPE", "Esc" },
}
function Btn.Abbrev(key)
  if type(key) ~= "string" or key == "" then return "" end
  local out = key:upper()
  for _, r in ipairs(ABBREV) do out = out:gsub(r[1], r[2]) end
  return out
end

function Btn.KeyText(key)
  if not key or not S.hotkeys then return "" end
  if S.keyAbbrev then return Btn.Abbrev(key) end
  return GetBindingText(key, true) or key
end

local function text(b, justify, point, x, y, role)
  local fs = b:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(Media:FontObject(role or "small"))
  fs:SetJustifyH(justify)
  fs:SetPoint(point, b, point, x, y)
  fs:SetWordWrap(false)
  return fs
end

local function setFontSize(fs, size)
  local path, _, flags = fs:GetFont()
  if path then fs:SetFont(path, size, flags) end
end

local function slotOf(b) return b:GetAttribute("action") end

local function index(b, slot)
  local old = b.slot
  if old == (slot or false) then return end
  if old and Btn.bySlot[old] then
    Btn.bySlot[old][b] = nil
    if next(Btn.bySlot[old]) == nil then
      Btn.bySlot[old] = nil
      C_ActionBar.EnableActionRangeCheck(old, false)
    end
  end
  b.slot = slot or false
  if slot then
    Btn.bySlot[slot] = Btn.bySlot[slot] or {}
    Btn.bySlot[slot][b] = true
    C_ActionBar.EnableActionRangeCheck(slot, true)
  end
end

local function onAttributeChanged(b, name, value)
  if name == "action" then
    index(b, value)
    Btn.Update(b)
  end
end

local function onEnter(b)
  if b.onHover then b.onHover(b, true) end
  if not b.slot or not S.tooltips then return end
  GameTooltip_SetDefaultAnchor(GameTooltip, b)
  GameTooltip:SetAction(b.slot)
  GameTooltip:Show()
end
local function onLeave(b)
  if b.onHover then b.onHover(b, false) end
  GameTooltip:Hide()
end
Btn.OnEnter, Btn.OnLeave = onEnter, onLeave

local function onDragStart(b)
  if InCombatLockdown() or not b.slot or (S.lock and not IsModifiedClick("PICKUPACTION")) then return end
  PickupAction(b.slot)
  Btn.Update(b)
end

local function onReceiveDrag(b)
  if InCombatLockdown() or not b.slot then return end
  PlaceAction(b.slot)
  Btn.Update(b)
end

-- Visual skeleton shared by action, stance, pet and item buttons.
function Btn.Skin(b)
  -- Plain fields start as false (never read through to the frame's methods).
  b.slot, b.live, b.bindKey, b.extraKey, b.glowOn, b.assistOn, b.entry, b.autocast = false, false, false, false, false, false, false, false
  b.onHover = b.onHover or false
  b.bg = Theme:Backdrop(b, "surface.1")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  PUI.Look.Shape(b.icon, b) -- icon shape mask (Theme > Icon shape), live
  b.dim = b:CreateTexture(nil, "ARTWORK", nil, 2) -- "dim while on cooldown" veil
  b.dim:SetAllPoints(b.icon)
  b.dim:SetColorTexture(0, 0, 0, 1)
  b.dim:SetAlpha(0)
  b.range = b:CreateTexture(nil, "OVERLAY")
  b.range:SetAllPoints(b.icon)
  b.range:SetAlpha(0)
  b.current = b:CreateTexture(nil, "OVERLAY")
  b.current:SetAllPoints(b.icon)
  Theme:Paint(b.current, "accent", 0.25)
  b.current:SetAlpha(0)
  b.edges = {}
  for i = 1, 4 do b.edges[i] = b:CreateTexture(nil, "OVERLAY", nil, 1) end
  b.cooldown = PUI:CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate", OWNER)
  b.cooldown:SetAllPoints(b.icon)
  b.charge = PUI:CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate", OWNER)
  b.charge:SetAllPoints(b.icon)
  b.charge:SetDrawSwipe(false)
  b.loc = PUI:CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate", OWNER) -- loss of control (red swipe)
  b.loc:SetAllPoints(b.icon)
  b.loc:SetSwipeColor(0.85, 0.1, 0.1, 0.65)
  b.loc:SetHideCountdownNumbers(true)
  b.count = text(b, "RIGHT", "BOTTOMRIGHT", -2, 2, "number")
  b.hotkey = text(b, "RIGHT", "TOPRIGHT", -2, -2, "small")
  b.macro = text(b, "CENTER", "BOTTOM", 0, 2, "small")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(b.icon)
  Theme:Paint(hl, "text.primary", 0.15)
  Btn.ApplyLook(b)
end

-- Applies the shared look (zoom, border, fonts, cooldown text) to one button.
function Btn.ApplyLook(b)
  local z, px = S.zoom, S.border
  b.icon:ClearAllPoints()
  b.icon:SetPoint("TOPLEFT", px, -px)
  b.icon:SetPoint("BOTTOMRIGHT", -px, px)
  b.icon:SetTexCoord(z, 1 - z, z, 1 - z)
  local c = S.borderColor
  local e, w = b.edges, math.max(px, 0.01)
  e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(w)
  e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(w)
  e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(w)
  e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(w)
  for i = 1, 4 do e[i]:SetColorTexture(c.r, c.g, c.b, c.a or 1); e[i]:SetShown(px > 0) end
  local r = S.rangeColor
  b.range:SetColorTexture(r.r, r.g, r.b, S.rangeMode == "overlay" and (r.a or 0.5) or 0)
  b.cooldown:SetHideCountdownNumbers(not S.cdText)
  b.cooldown:SetDrawEdge(S.cdEdge)
  b.cooldown:SetSwipeColor(0, 0, 0, S.swipeAlpha)
  local cdText = b.cooldown.GetCountdownFontString and b.cooldown:GetCountdownFontString()
  if cdText then setFontSize(cdText, S.cdTextSize) end
  setFontSize(b.hotkey, S.hotkeySize)
  local hc = S.hotkeyColor
  b.hotkey:SetTextColor(hc.r, hc.g, hc.b, hc.a or 1)
  setFontSize(b.macro, S.macroSize)
  setFontSize(b.count, S.countSize)
end

-- Creates one secure action button (out of combat). name is global for keybind clicks.
function Btn.Create(header, name, id)
  local b = PUI:CreateFrame("Button", name, header, "SecureActionButtonTemplate", OWNER)
  b.onHover = false
  b:SetID(id)
  b:SetAttribute("type", "action")
  b:SetAttribute("checkselfcast", true)
  b:SetAttribute("checkfocuscast", true)
  b:RegisterForClicks("AnyUp", "AnyDown") -- the template honours ActionButtonUseKeyDown
  b:RegisterForDrag("LeftButton", "RightButton")
  Btn.Skin(b)
  b:SetScript("OnAttributeChanged", onAttributeChanged)
  b:SetScript("OnEnter", onEnter)
  b:SetScript("OnLeave", onLeave)
  b:SetScript("OnDragStart", onDragStart)
  b:SetScript("OnReceiveDrag", onReceiveDrag)
  Btn.all[#Btn.all + 1] = b
  return b
end

-- Visual refreshers ---------------------------------------------------------------
-- "Never dim" list (plan 13.5 parity): spells usable on a condition (e.g.
-- Swiftmend) keep full colour. The action's spell id is plain data.
function Btn.NeverDim(slot)
  if #S.neverDim == 0 then return false end
  local kind, id = GetActionInfo(slot)
  if Secret.IsSecret(kind) or Secret.IsSecret(id) or kind ~= "spell" then return false end
  for _, v in ipairs(S.neverDim) do if tonumber(v) == id then return true end end
  return false
end

function Btn.UpdateUsable(b)
  local slot = b.slot
  if not slot then return end
  if Btn.NeverDim(slot) then b.icon:SetVertexColor(1, 1, 1, 1) return end
  local usable, noMana = C_ActionBar.IsUsableAction(slot)
  -- usable -> white; else not enough mana -> mana colour; else unusable colour.
  local otherwise = C_CurveUtil.EvaluateColorFromBoolean(noMana, color(S.manaColor), color(S.unusableColor))
  local c = C_CurveUtil.EvaluateColorFromBoolean(usable, WHITE, otherwise)
  b.icon:SetVertexColor(c:GetRGBA())
end

function Btn.UpdateRange(b, inRange)
  if S.rangeMode == "off" or type(inRange) == "nil" then
    b.range:SetAlpha(0)
    if S.rangeMode == "tint" then Btn.UpdateUsable(b) end
    return
  end
  if S.rangeMode == "tint" then
    local c = C_CurveUtil.EvaluateColorFromBoolean(inRange, WHITE, color(S.rangeColor))
    b.icon:SetVertexColor(c:GetRGBA())
    return
  end
  b.range:SetAlphaFromBoolean(inRange, 0, 1)
end

function Btn.UpdateCooldown(b)
  local slot = b.slot
  if not slot then return end
  local d = C_ActionBar.GetActionCooldownDuration(slot)
  b.cooldown:SetCooldownFromDurationObject(d, true)
  b.charge:SetCooldownFromDurationObject(C_ActionBar.GetActionChargeDuration(slot), true)
  if S.lossOfControl then
    b.loc:SetCooldownFromDurationObject(C_ActionBar.GetActionLossOfControlCooldownDuration(slot), true)
  else
    b.loc:Clear()
  end
  if S.dimOnCooldown and type(d) ~= "nil" then
    b.dim:SetAlphaFromBoolean(d:IsZero(), 0, S.dimAlpha)
  else
    b.dim:SetAlpha(0)
  end
end

function Btn.UpdateCount(b)
  if not b.slot then return end
  b.count:SetText(C_ActionBar.GetActionDisplayCount(b.slot, 9999, "*"))
end

function Btn.UpdateState(b)
  if not b.slot then return end
  b.current:SetAlphaFromBoolean(C_ActionBar.IsCurrentAction(b.slot), 1, 0)
end

function Btn.UpdateHotkey(b)
  b.hotkey:SetText(Btn.KeyText(b.extraKey or b.bindKey))
end

-- Proc and assisted-combat glows on PUI.Glow (C-side animation, G2).
function Btn.PaintGlow(b)
  if b.glowOn and S.procGlow ~= "none" then
    PUI.Glow:Start(b, S.procGlow, S.procColor)
  elseif b.assistOn and S.assist then
    PUI.Glow:Start(b, "solid", S.assistColor)
  else
    PUI.Glow:Stop(b)
  end
end

function Btn.SetGlow(b, on)
  b.glowOn = on and true or false
  Btn.PaintGlow(b)
end

function Btn.Update(b)
  local slot = b.slot
  local has = slot and C_ActionBar.HasAction(slot)
  if not has then
    b.icon:SetTexture(nil)
    b.icon:Hide()
    b.count:SetText("")
    b.macro:SetText("")
    b.cooldown:Clear()
    b.charge:Clear()
    b.loc:Clear()
    b.dim:SetAlpha(0)
    b.range:SetAlpha(0)
    b.current:SetAlpha(0)
    b.glowOn, b.assistOn = false, false
    Btn.PaintGlow(b)
    b.bg:SetAlpha(S.showEmpty and 1 or 0)
    for _, e in ipairs(b.edges) do e:SetShown(S.showEmpty and S.border > 0) end
  else
    b.icon:SetTexture(C_ActionBar.GetActionTexture(slot))
    b.icon:Show()
    b.bg:SetAlpha(1)
    for _, e in ipairs(b.edges) do e:SetShown(S.border > 0) end
    if S.macroText then b.macro:SetText(C_ActionBar.GetActionText(slot)) else b.macro:SetText("") end
    Btn.UpdateUsable(b)
    Btn.UpdateCooldown(b)
    Btn.UpdateCount(b)
    Btn.UpdateState(b)
    b.glowOn = Btn.glowing[slot] == true
    b.assistOn = Btn.assisted[slot] == true
    Btn.PaintGlow(b)
  end
  Btn.UpdateHotkey(b)
end

-- Bulk helpers used by the module's events (only buttons that are shown).
function Btn.Each(fn)
  for i = 1, #Btn.all do
    local b = Btn.all[i]
    if b.live then fn(b) end
  end
end

function Btn.ForSlot(slot, fn, ...)
  local set = Btn.bySlot[slot]
  if not set then return end
  for b in pairs(set) do if b.live then fn(b, ...) end end
end

-- Proc glow from spell-activation events: the engine maps spell -> slots.
function Btn.Glow(spellID, on)
  if Secret.IsSecret(spellID) then return end
  local slots = C_ActionBar.FindSpellActionButtons(spellID)
  if not slots then return end
  for _, slot in ipairs(slots) do
    Btn.glowing[slot] = on or nil
    Btn.ForSlot(slot, Btn.SetGlow, on)
  end
end

-- Assisted combat (Blizzard's rotation helper): highlight the slots holding
-- the suggested spell. Polled through one Ticker entry only while on.
local function setAssist(b, on) b.assistOn = on; Btn.PaintGlow(b) end
function Btn.Assist()
  local spell = S.assist and C_AssistedCombat.GetNextCastSpell(true) or nil
  if Secret.IsSecret(spell) then spell = nil end
  if spell == Btn.assistSpell then return end
  Btn.assistSpell = spell
  local old = Btn.assisted
  Btn.assisted = {}
  for _, slot in ipairs(spell and C_ActionBar.FindSpellActionButtons(spell) or {}) do Btn.assisted[slot] = true end
  for slot in pairs(old) do Btn.ForSlot(slot, setAssist, false) end
  for slot in pairs(Btn.assisted) do Btn.ForSlot(slot, setAssist, true) end
end

Btn.slotOf = slotOf
Btn.index = index
