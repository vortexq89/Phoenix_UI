local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Review gaps (2026-10-27), Core pieces:
--  * PUI.Toast: one small themed notice at the top of the screen. Used by the
--    CombatQueue (workaround W14): when a change has to wait for combat to
--    end, you see "Waits until combat ends" instead of nothing happening.
--  * Cursor ring: a ring (and optional dot) that follows the cursor, drawn
--    from PUI.Mouse (one poll through the Ticker, only while the ring is on).
--  * Celebrations (opt-in): a banner with rising embers for an achievement,
--    a timed Mythic+ key or a level up. Reduced motion: the banner only.
--  * Edit Mode layout in the profile (workaround W13): Blizzard-owned frames
--    move only in Edit Mode, so Phoenix keeps a copy of your active Edit Mode
--    layout (C_EditMode.ConvertLayoutInfoToString) in the Phoenix profile and
--    can put it back as a layout named "Phoenix" (SaveLayouts and
--    SetActiveLayout, official API, out of combat only). /pui editmode.
--  * Frame provider API: PUI.API.GetUnitFrame(unit) / GetUnitFrames(unit)
--    return the Phoenix frames showing a unit (unit frames, raid and party,
--    nameplates), so other addons can anchor to them; RegisterFrameProvider
--    lets a plugin add its own frames.
local Schema, Theme, Media, Ticker, CQ, Kernel, Secret = PUI.Schema, PUI.Theme, PUI.Media, PUI.Ticker, PUI.CombatQueue, PUI.Kernel, PUI.Secret
local MEDIA = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\"
local Gaps = {}
PUI.Gaps = Gaps
local s = { toast = true, toastSeconds = 3,
  ring = false, ringSize = 48, ringStyle = "ring", ringColor = "accent", ringCombat = false, ringDot = false,
  editModeAutoSave = false, editModeActivate = true,
  celebrate = false, celebrateAchievements = true, celebrateKeys = true, celebrateLevels = true, celebrateSound = true }
Gaps.s = s

-- Toast ---------------------------------------------------------------------------------------------------
local Toast = {}
PUI.Toast = Toast
function Toast:Build()
  if self.frame then return self.frame end
  local f = PUI:CreateFrame("Frame", "PhoenixUIToast", UIParent, nil, "Core")
  f:SetSize(300, 30); f:SetPoint("TOP", UIParent, "TOP", 0, -120); f:SetFrameStrata("DIALOG"); f:Hide()
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.06, 0.06, 0.08, 0.92)
  f.bar = f:CreateTexture(nil, "ARTWORK"); f.bar:SetPoint("TOPLEFT"); f.bar:SetPoint("BOTTOMLEFT"); f.bar:SetWidth(3)
  f.text = f:CreateFontString(nil, "OVERLAY"); f.text:SetFontObject(Media:FontObject("small")); f.text:SetPoint("CENTER", 2, 0)
  f.anim = f:CreateAnimationGroup()
  f.hold = f.anim:CreateAnimation("Alpha"); f.hold:SetFromAlpha(1); f.hold:SetToAlpha(1)
  f.fade = f.anim:CreateAnimation("Alpha"); f.fade:SetFromAlpha(1); f.fade:SetToAlpha(0); f.fade:SetDuration(0.4)
  f.anim:SetScript("OnFinished", function() f:Hide() end)
  self.frame = f
  return f
end
-- Show(text[, token[, always]]) -> frame (nil when combat notices are off and always is not set)
function Toast:Show(text, token, always)
  if not (s.toast or always) then return nil end
  local f = self:Build()
  f.bar:SetColorTexture(Theme:Color(token or "accent"))
  f.text:SetText(text)
  f:SetWidth(math.max(200, (f.text:GetStringWidth() or 0) + 40))
  f.hold:SetDuration(s.toastSeconds); f.fade:SetStartDelay(s.toastSeconds)
  f:SetAlpha(1); f:Show()
  f.anim:Stop(); f.anim:Play()
  self.last = text
  return f
end
-- W14: CombatQueue tells you when something you did waits. Only work you
-- started says so: a setting change (its label is used) or a labelled action
-- (LABEL); Phoenix's own housekeeping queues silently. One notice per item per fight.
local LABEL = { ["gf.cancelOldest"] = "Cancel oldest application", ["ascent.slot"] = "Slotting your keystone",
  ["profiles.switch"] = "Profile switch", ["setup.wizard"] = "Setup", ["uf.test"] = "Unit frame test mode" }
Gaps.QUEUE_LABEL = LABEL
Gaps.told = {}
local set = Schema.Set
function Schema:Set(k, v, ...)
  local prev = Gaps.changing
  Gaps.changing = k
  local a, b = set(self, k, v, ...)
  Gaps.changing = prev
  return a, b
end
function Gaps.QueueLabel(key)
  if LABEL[key] then return LABEL[key] end
  local def = Gaps.changing and Schema:Def(Gaps.changing)
  return def and def.label or nil
end
local defer = CQ.Defer
function CQ.Defer(key, fn)
  local ran = defer(key, fn)
  if not ran and key ~= "core.toldReset" then
    local label = Gaps.QueueLabel(key)
    if label and not Gaps.told[label] then
      Gaps.told[label] = true
      Toast:Show(label .. ": waits until combat ends", "warn")
      defer("core.toldReset", function() wipe(Gaps.told) end)
    end
  end
  return ran
end

-- Cursor ring ---------------------------------------------------------------------------------------------
local Ring = {}
Gaps.Ring = Ring
Ring.STYLES = { ring = "Cursor\\ring", thin = "Cursor\\ringthin" }
function Ring.Color()
  if s.ringColor == "class" then
    local _, class = UnitClass("player")
    if type(class) == "string" and not Secret.IsSecret(class) and PUI.Look then return PUI.Look.ClassRGB(class) end
  end
  return Theme:Color("accent")
end
function Ring.Build()
  if Ring.frame then return Ring.frame end
  local f = PUI:CreateFrame("Frame", nil, UIParent, nil, "Core")
  f:SetFrameStrata("TOOLTIP"); f:EnableMouse(false)
  f.ring = f:CreateTexture(nil, "OVERLAY"); f.ring:SetAllPoints()
  f.dot = f:CreateTexture(nil, "OVERLAY"); f.dot:SetPoint("CENTER"); f.dot:SetTexture(MEDIA .. "Cursor\\dot")
  Ring.frame = f
  return f
end
function Ring.Paint()
  local f = Ring.Build()
  f:SetSize(s.ringSize, s.ringSize)
  f.ring:SetTexture(MEDIA .. (Ring.STYLES[s.ringStyle] or Ring.STYLES.ring))
  f.dot:SetSize(s.ringSize / 4, s.ringSize / 4); f.dot:SetShown(s.ringDot)
  local r, g, b = Ring.Color()
  f.ring:SetVertexColor(r, g, b); f.dot:SetVertexColor(r, g, b)
end
local function fighting()
  local c = UnitAffectingCombat("player")
  return not Secret.IsSecret(c) and c == true
end
function Ring.Wanted() return s.ring and (not s.ringCombat or fighting()) end
local function follow(x, y)
  -- combat-only: the poll that moves the ring also notices combat ending
  if s.ringCombat and not fighting() then return Ring.Update() end
  local f = Ring.frame; f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end
function Ring.Update()
  if Ring.Wanted() then
    Ring.Paint(); Ring.frame:Show()
    PUI.Mouse:Subscribe("cursor.ring", follow)
  else
    PUI.Mouse:Unsubscribe("cursor.ring")
    if Ring.frame then Ring.frame:Hide() end
  end
end
Ring.events = PUI:CreateFrame("Frame", nil, UIParent, nil, "Core")
Ring.events:SetScript("OnEvent", function() Ring.Update() end)
function Ring.Track()
  Ring.events:UnregisterAllEvents()
  -- combat-only ring: PLAYER_REGEN_DISABLED shows it; the cursor poll hides it when combat ends
  if s.ring and s.ringCombat then Ring.events:RegisterEvent("PLAYER_REGEN_DISABLED") end
  Ring.Update()
end

-- Celebrations --------------------------------------------------------------------------------------------
local Cel = { embers = {} }
Gaps.Celebrate = Cel
function Cel.Build()
  if Cel.frame then return Cel.frame end
  local f = PUI:CreateFrame("Frame", "PhoenixUICelebration", UIParent, nil, "Core")
  f:SetSize(420, 70); f:SetPoint("TOP", UIParent, "TOP", 0, -180); f:SetFrameStrata("HIGH"); f:Hide()
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.04, 0.04, 0.85)
  f.line = f:CreateTexture(nil, "ARTWORK"); f.line:SetPoint("BOTTOMLEFT"); f.line:SetPoint("BOTTOMRIGHT"); f.line:SetHeight(2)
  f.title = f:CreateFontString(nil, "OVERLAY"); f.title:SetFontObject(Media:FontObject("header")); f.title:SetPoint("TOP", 0, -12)
  f.sub = f:CreateFontString(nil, "OVERLAY"); f.sub:SetFontObject(Media:FontObject("small")); f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
  f.anim = f:CreateAnimationGroup()
  local hold = f.anim:CreateAnimation("Alpha"); hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(3.5)
  local fade = f.anim:CreateAnimation("Alpha"); fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetDuration(0.8); fade:SetStartDelay(3.5)
  f.anim:SetScript("OnFinished", function() f:Hide() end)
  for i = 1, 14 do
    local e = f:CreateTexture(nil, "OVERLAY")
    e:SetTexture(MEDIA .. "Celebrate\\" .. (i % 3 == 0 and "spark" or "ember"))
    e:SetBlendMode("ADD")
    local size = 8 + (i * 7) % 12
    e:SetSize(size, size)
    e:SetPoint("BOTTOM", f, "BOTTOM", -180 + (i - 1) * 27, 0)
    local g = e:CreateAnimationGroup()
    local rise = g:CreateAnimation("Translation"); rise:SetOffset(((i * 13) % 21) - 10, 60 + (i * 17) % 50); rise:SetDuration(1.6 + (i % 4) * 0.3)
    local out = g:CreateAnimation("Alpha"); out:SetFromAlpha(1); out:SetToAlpha(0); out:SetDuration(rise:GetDuration())
    g:SetScript("OnFinished", function() e:Hide() end)
    Cel.embers[i] = { tex = e, anim = g }
  end
  Cel.frame = f
  return f
end
function Cel.Reduced() return PUI.Look and PUI.Look.s.reducedMotion == true end
-- Show(title, sub) -> frame; always works when called (the setting gates the events)
function Cel.Show(title, sub)
  local f = Cel.Build()
  local r, g, b = Theme:Color("accent")
  f.title:SetText(title); f.title:SetTextColor(r, g, b)
  f.sub:SetText(sub or ""); f.sub:SetTextColor(0.9, 0.9, 0.9)
  f.line:SetColorTexture(r, g, b)
  f:SetAlpha(1); f:Show(); f.anim:Stop(); f.anim:Play()
  for _, e in ipairs(Cel.embers) do
    e.anim:Stop()
    if Cel.Reduced() then e.tex:Hide() else e.tex:SetVertexColor(r, g, b); e.tex:Show(); e.anim:Play() end
  end
  if s.celebrateSound then PlaySound(SOUNDKIT and SOUNDKIT.UI_70_CHALLENGE_MODE_KEYSTONE_UPGRADE or 33339, "Master") end
  Cel.last = title
  return f
end
function Cel.OnEvent(_, event, a)
  if not s.celebrate then return end
  if event == "ACHIEVEMENT_EARNED" and s.celebrateAchievements then
    local _, name = GetAchievementInfo(a)
    if type(name) == "string" and not Secret.IsSecret(name) then Cel.Show("Achievement", name) end
  elseif event == "CHALLENGE_MODE_COMPLETED" and s.celebrateKeys then
    local info = C_ChallengeMode.GetChallengeCompletionInfo()
    if type(info) == "table" and info.onTime == true then Cel.Show("Key timed", "+" .. tostring(info.level or "")) end
  elseif event == "PLAYER_LEVEL_UP" and s.celebrateLevels then
    Cel.Show("Level " .. tostring(a), "Well played")
  end
end
Cel.events = PUI:CreateFrame("Frame", nil, UIParent, nil, "Core")
Cel.events:SetScript("OnEvent", Cel.OnEvent)
function Cel.Track()
  local e = Cel.events
  e:UnregisterAllEvents()
  if not s.celebrate then return end
  e:RegisterEvent("ACHIEVEMENT_EARNED"); e:RegisterEvent("CHALLENGE_MODE_COMPLETED"); e:RegisterEvent("PLAYER_LEVEL_UP")
end

-- Edit Mode layout -----------------------------------------------------------------------------------------
local EM = { NAME = "Phoenix" }
Gaps.EditMode = EM
local function presets() local m = Enum.EditModePresetLayoutsMeta; return (m and m.NumValues) or 2 end
-- Active() -> layoutInfo of the active saved layout (nil for a preset layout)
function EM.Active()
  local all = C_EditMode.GetLayouts()
  if type(all) ~= "table" or type(all.layouts) ~= "table" or type(all.activeLayout) ~= "number" then return nil end
  return all.layouts[all.activeLayout - presets()], all
end
-- Save() -> true when the active layout was copied into the profile
function EM.Save()
  local info = EM.Active()
  if not info then return false, "the active Edit Mode layout is one of Blizzard's presets: copy it to a new layout first" end
  local str = C_EditMode.ConvertLayoutInfoToString(info)
  if type(str) ~= "string" or str == "" then return false, "the game did not export the layout" end
  Schema:Set("studio.editModeLayout", { name = info.layoutName, data = str, saved = time() })
  return true
end
-- Restore() -> queued/applied; adds or replaces the "Phoenix" layout and (setting) makes it active
function EM.Restore()
  local stored = Schema:Get("studio.editModeLayout")
  if type(stored) ~= "table" or type(stored.data) ~= "string" then return false, "no Edit Mode layout in this profile yet" end
  CQ.Defer("studio.editMode", function()
    local info = C_EditMode.ConvertStringToLayoutInfo(stored.data)
    local all = C_EditMode.GetLayouts()
    if type(info) ~= "table" or type(all) ~= "table" or type(all.layouts) ~= "table" then return end
    info.layoutName = EM.NAME
    info.layoutType = (Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account) or info.layoutType
    local at
    for i, l in ipairs(all.layouts) do if l.layoutName == EM.NAME then at = i end end
    if at then all.layouts[at] = info else all.layouts[#all.layouts + 1] = info; at = #all.layouts end
    if s.editModeActivate then all.activeLayout = at + presets() end
    C_EditMode.SaveLayouts(all)
    if s.editModeActivate then C_EditMode.SetActiveLayout(at + presets()) end
    EM.restored = at
  end)
  return true
end
LABEL["studio.editMode"] = "Edit Mode layout"
EM.events = PUI:CreateFrame("Frame", nil, UIParent, nil, "Core")
EM.events:SetScript("OnEvent", function() if s.editModeAutoSave then EM.Save() end end)
function EM.Track()
  EM.events:UnregisterAllEvents()
  if s.editModeAutoSave then EM.events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED") end
end
PUI.Slash:Register("editmode", function(rest)
  local ok, why
  if rest == "restore" then ok, why = EM.Restore() else ok, why = EM.Save() end
  PUI.Slash.Print(ok and ("Edit Mode layout " .. (rest == "restore" and "restored as \"Phoenix\"" or "saved in this profile")) or ("Edit Mode: " .. tostring(why)))
end, "save your Edit Mode layout in the profile, or restore it (/pui editmode restore)")

-- Frame provider API --------------------------------------------------------------------------------------
local API = PUI.API
local providers, order = {}, {}
Gaps.providers = providers
local function same(a, b)
  if a == b then return true end
  local r = UnitIsUnit(a, b)
  return not Secret.IsSecret(r) and r == true
end
-- RegisterFrameProvider(id, fn(unit) -> frame, frame, ...)
function API.RegisterFrameProvider(id, fn)
  assert(type(id) == "string" and type(fn) == "function", "RegisterFrameProvider(id, fn)")
  if not providers[id] then order[#order + 1] = id end
  providers[id] = fn
  return true
end
API.RegisterFrameProvider("unitframes", function(unit)
  local UF = PUI.UnitFrames
  if not (UF and UF.active and UF.units) then return end
  local out = {}
  for token, o in pairs(UF.units) do if o.button and o.button:IsShown() and same(token, unit) then out[#out + 1] = o.button end end
  return unpack(out)
end)
API.RegisterFrameProvider("raidframes", function(unit)
  local RF = PUI.RaidFrames
  if not (RF and RF.active and RF.buttons) then return end
  local out = {}
  for _, o in ipairs(RF.buttons) do if o.unit and o.button:IsShown() and same(o.unit, unit) then out[#out + 1] = o.button end end
  return unpack(out)
end)
API.RegisterFrameProvider("nameplates", function(unit)
  local NP = PUI.Nameplates
  if not (NP and NP.active and NP.plates) then return end
  local out = {}
  for _, f in pairs(NP.plates) do if f.unit and f:IsShown() and same(f.unit, unit) then out[#out + 1] = f end end
  return unpack(out)
end)
-- GetUnitFrames(unit) -> list of frames, in provider order (unit frames, raid, nameplates, plugins)
function API.GetUnitFrames(unit)
  local out = {}
  if type(unit) ~= "string" or not UnitExists(unit) then return out end
  for _, id in ipairs(order) do
    local list = { securecallfunction(providers[id], unit) }
    for _, f in ipairs(list) do out[#out + 1] = f end
  end
  return out
end
function API.GetUnitFrame(unit) return API.GetUnitFrames(unit)[1] end

-- Settings ------------------------------------------------------------------------------------------------
local function key(k, owner, field, def, after)
  def.owner = owner
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[field] = v; if after then after(v) end end
  Schema:Register(k, def)
  s[field] = Schema:Get(k)
end
local ring = function() Ring.Track() end
local cel = function() Cel.Track() end
key("core.combatToast", "Core", "toast", { type = "toggle", default = true, mode = "simple", label = "Say when a change waits for combat",
  tooltip = "Some changes cannot happen in combat. A short notice at the top of the screen says so, and the change happens when combat ends." })
key("core.combatToastSeconds", "Core", "toastSeconds", { type = "range", default = 3, min = 1, max = 8, step = 0.5, label = "Notice time",
  tooltip = "How long the notice stays." })
key("cursor.ring", "Cursor", "ring", { type = "toggle", default = false, mode = "simple", label = "Cursor ring",
  tooltip = "A ring around your mouse cursor, so you never lose it in a busy fight.", searchTags = { "mouse", "cursor" } }, ring)
key("cursor.size", "Cursor", "ringSize", { type = "range", default = 48, min = 24, max = 128, step = 4, mode = "simple", label = "Ring size",
  tooltip = "Width of the cursor ring." }, ring)
key("cursor.style", "Cursor", "ringStyle", { type = "select", default = "ring", choices = { "ring", "thin" }, label = "Ring style",
  tooltip = "Thick or thin ring." }, ring)
key("cursor.color", "Cursor", "ringColor", { type = "select", default = "accent", choices = { "accent", "class" }, label = "Ring colour",
  tooltip = "Theme accent or your class colour." }, ring)
key("cursor.combatOnly", "Cursor", "ringCombat", { type = "toggle", default = false, label = "Only in combat",
  tooltip = "Show the ring only while you are in combat." }, ring)
key("cursor.dot", "Cursor", "ringDot", { type = "toggle", default = false, label = "Centre dot",
  tooltip = "A small dot in the middle of the ring." }, ring)
key("celebrate.enabled", "Celebrations", "celebrate", { type = "toggle", default = false, mode = "simple", label = "Celebrations",
  tooltip = "A banner with rising embers when you earn an achievement, time a key or level up. Reduced motion (Glows page) keeps only the banner." }, cel)
key("celebrate.achievements", "Celebrations", "celebrateAchievements", { type = "toggle", default = true, label = "For achievements",
  tooltip = "Celebrate achievements you earn." })
key("celebrate.keys", "Celebrations", "celebrateKeys", { type = "toggle", default = true, label = "For timed keys",
  tooltip = "Celebrate Mythic+ keys completed in time." })
key("celebrate.levels", "Celebrations", "celebrateLevels", { type = "toggle", default = true, label = "For level ups",
  tooltip = "Celebrate each new level." })
key("celebrate.sound", "Celebrations", "celebrateSound", { type = "toggle", default = true, mode = "simple", label = "Celebration sound",
  tooltip = "Play a short sound with the banner." })
key("studio.editModeAutoSave", "Studio", "editModeAutoSave", { type = "toggle", default = false, mode = "simple", label = "Keep my Edit Mode layout in the profile",
  tooltip = "Each time you save in Edit Mode, Phoenix keeps a copy of the active layout in this profile; /pui editmode restore puts it back as a layout named Phoenix.",
  searchTags = { "edit mode", "layout" } }, function() EM.Track() end)
key("studio.editModeActivate", "Studio", "editModeActivate", { type = "toggle", default = true, label = "Switch to the restored Edit Mode layout",
  tooltip = "After a restore, make the Phoenix Edit Mode layout the active one." })
Schema:Register("studio.editModeLayout", { type = "layout", default = {}, owner = "Studio", mode = "advanced", label = "Saved Edit Mode layout",
  tooltip = "The Edit Mode layout kept in this profile (/pui editmode).", apply = function() end })
Kernel:On("LOOK_CHANGED", function() if Ring.frame and Ring.frame:IsShown() then Ring.Paint() end end)
Ring.Track(); Cel.Track(); EM.Track()
