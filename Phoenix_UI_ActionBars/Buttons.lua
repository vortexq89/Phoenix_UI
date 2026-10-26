local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Action buttons (PUI_V2 5.6): SecureActionButtonTemplate buttons with
-- original visuals. The secure "action" attribute is the single source of
-- truth; OnAttributeChanged (an insecure observer) refreshes visuals when the
-- paging snippet moves a button to another slot. Engine values that may be
-- secret (usable, in range, counts, cooldown durations) only reach widgets:
-- SetVertexColor from EvaluateColorFromBoolean, SetAlphaFromBoolean,
-- SetText and SetCooldownFromDurationObject.
local _, ns = ...
local Theme, Media, Secret = PUI.Theme, PUI.Media, PUI.Secret
local OWNER = "ActionBars"

local Btn = { all = {}, bySlot = {}, glowing = {} }
ns.Buttons = Btn

local WHITE = CreateColor(1, 1, 1, 1)
local DIM = CreateColor(0.4, 0.4, 0.4, 1)

local function text(b, justify, point, x, y, role)
  local fs = b:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(Media:FontObject(role or "small"))
  fs:SetJustifyH(justify)
  fs:SetPoint(point, b, point, x, y)
  fs:SetWordWrap(false)
  return fs
end

local function slotOf(b) return b:GetAttribute("action") end

local function index(b, slot)
  local old = b.slot
  if old == slot then return end
  if old and Btn.bySlot[old] then
    Btn.bySlot[old][b] = nil
    if next(Btn.bySlot[old]) == nil then
      Btn.bySlot[old] = nil
      C_ActionBar.EnableActionRangeCheck(old, false)
    end
  end
  b.slot = slot
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
  if not b.slot or not ns.settings.tooltips then return end
  GameTooltip_SetDefaultAnchor(GameTooltip, b)
  GameTooltip:SetAction(b.slot)
  GameTooltip:Show()
end
local function onLeave() GameTooltip:Hide() end

local function onDragStart(b)
  if InCombatLockdown() or not b.slot or (ns.settings.lock and not IsModifiedClick("PICKUPACTION")) then return end
  PickupAction(b.slot)
  Btn.Update(b)
end

local function onReceiveDrag(b)
  if InCombatLockdown() or not b.slot then return end
  PlaceAction(b.slot)
  Btn.Update(b)
end

-- Creates one secure button (out of combat). name is global for keybind clicks.
function Btn.Create(header, name, id)
  local b = PUI:CreateFrame("Button", name, header, "SecureActionButtonTemplate", OWNER)
  b:SetID(id)
  b:SetAttribute("type", "action")
  b:SetAttribute("checkselfcast", true)
  b:SetAttribute("checkfocuscast", true)
  b:RegisterForClicks("AnyUp", "AnyDown") -- the template honours ActionButtonUseKeyDown
  b:RegisterForDrag("LeftButton", "RightButton")
  b.bg = Theme:Backdrop(b, "surface.1")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.range = b:CreateTexture(nil, "OVERLAY")
  b.range:SetAllPoints(b.icon)
  Theme:Paint(b.range, "danger", 0.45)
  b.range:SetAlpha(0)
  b.current = b:CreateTexture(nil, "OVERLAY")
  b.current:SetAllPoints(b.icon)
  Theme:Paint(b.current, "accent", 0.25)
  b.current:SetAlpha(0)
  b.glow = Theme:Outline(b, "spark", 1)
  for _, e in ipairs(b.glow) do e:Hide() end
  b.outline = Theme:Outline(b, "line")
  b.cooldown = PUI:CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate", OWNER)
  b.cooldown:SetAllPoints(b.icon)
  b.charge = PUI:CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate", OWNER)
  b.charge:SetAllPoints(b.icon)
  b.charge:SetDrawSwipe(false)
  b.count = text(b, "RIGHT", "BOTTOMRIGHT", -2, 2, "number")
  b.hotkey = text(b, "RIGHT", "TOPRIGHT", -2, -2, "small")
  b.macro = text(b, "CENTER", "BOTTOM", 0, 2, "small")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(b.icon)
  Theme:Paint(hl, "text.primary", 0.15)
  b:SetScript("OnAttributeChanged", onAttributeChanged)
  b:SetScript("OnEnter", onEnter)
  b:SetScript("OnLeave", onLeave)
  b:SetScript("OnDragStart", onDragStart)
  b:SetScript("OnReceiveDrag", onReceiveDrag)
  Btn.all[#Btn.all + 1] = b
  return b
end

-- Visual refreshers ---------------------------------------------------------------
function Btn.UpdateUsable(b)
  local slot = b.slot
  if not slot then return end
  local usable = C_ActionBar.IsUsableAction(slot)
  local color = C_CurveUtil.EvaluateColorFromBoolean(usable, WHITE, DIM)
  b.icon:SetVertexColor(color:GetRGBA())
end

function Btn.UpdateRange(b, inRange)
  if type(inRange) == "nil" then b.range:SetAlpha(0) return end
  b.range:SetAlphaFromBoolean(inRange, 0, 1)
end

function Btn.UpdateCooldown(b)
  local slot = b.slot
  if not slot then return end
  b.cooldown:SetCooldownFromDurationObject(C_ActionBar.GetActionCooldownDuration(slot), true)
  b.charge:SetCooldownFromDurationObject(C_ActionBar.GetActionChargeDuration(slot), true)
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
  local key = b.bindKey
  b.hotkey:SetText(key and ns.settings.hotkeys and GetBindingText(key, true) or "")
end

function Btn.SetGlow(b, on)
  for _, e in ipairs(b.glow) do e:SetShown(on) end
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
    b.range:SetAlpha(0)
    b.current:SetAlpha(0)
    Btn.SetGlow(b, false)
    b.bg:SetAlpha(ns.settings.showEmpty and 1 or 0)
    for _, e in ipairs(b.outline) do e:SetShown(ns.settings.showEmpty) end
  else
    b.icon:SetTexture(C_ActionBar.GetActionTexture(slot))
    b.icon:Show()
    b.bg:SetAlpha(1)
    for _, e in ipairs(b.outline) do e:Show() end
    if ns.settings.macroText then b.macro:SetText(C_ActionBar.GetActionText(slot)) else b.macro:SetText("") end
    Btn.UpdateUsable(b)
    Btn.UpdateCooldown(b)
    Btn.UpdateCount(b)
    Btn.UpdateState(b)
    Btn.SetGlow(b, Btn.glowing[slot] == true)
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

Btn.slotOf = slotOf
Btn.index = index
