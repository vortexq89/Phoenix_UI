local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- One pooled Phoenix plate (PUI_V2 5.5, plan 5.3 / 13.4 / 15.6, mockup 02).
-- Health, name, subtitle, health text, M+ forces text, the shared cast bar
-- (PUI.CastBar, own-kick state included), three aura lanes on PUI.Auras
-- (your debuffs, important or purgeable buffs, crowd control), target and
-- focus highlights with arrows, raid marker, elite/rare and quest icons,
-- execute marker and recolour, and the class resource on the target plate.
-- Values that may be secret go straight to widgets (SetValue, SetText,
-- SetAlphaFromBoolean, SetSpriteSheetCell); Lua compares only plain values.
local _, ns = ...
local Bars, Theme, Media, Secret = PUI.Bars, PUI.Theme, PUI.Media, PUI.Secret
local OWNER = "Nameplates"

local P = { pool = {}, built = 0 }
ns.Plate = P

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
P.plain = plain

local function fontString(parent, justify, size)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(Media:FontObject(size or "number"))
  fs:SetJustifyH(justify)
  fs:SetWordWrap(false)
  return fs
end

local function icon(parent, size, layer)
  local t = parent:CreateTexture(nil, layer or "OVERLAY")
  t:SetSize(size, size)
  t:Hide()
  return t
end

-- Plain four-edge outline coloured by the plate's own settings (not a Theme
-- token, so a user colour is never repainted over).
local function edges(frame, px)
  local list = {}
  local function edge(p1, p2, w, h)
    local t = frame:CreateTexture(nil, "OVERLAY")
    t:SetPoint(p1); t:SetPoint(p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
    list[#list + 1] = t
  end
  edge("TOPLEFT", "TOPRIGHT", nil, px); edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, px)
  edge("TOPLEFT", "BOTTOMLEFT", px, nil); edge("TOPRIGHT", "BOTTOMRIGHT", px, nil)
  return list
end
local function paintEdges(list, c, a)
  for i = 1, #list do list[i]:SetColorTexture(c.r, c.g, c.b, a or 1) end
end

-- Looks (every part is also its own setting; the look only picks chrome).
P.STYLES = { "ember", "slate", "minimal" }
P.STYLE_LABELS = { ember = "Ember (soft border, dark backdrop)", slate = "Slate (crisp black border)",
  minimal = "Minimal (no border)" }
local LOOK = {
  ember = { border = { r = 0.165, g = 0.173, b = 0.2 }, alpha = 1 },
  slate = { border = { r = 0, g = 0, b = 0 }, alpha = 1 },
  minimal = { border = { r = 0, g = 0, b = 0 }, alpha = 0 },
}

-- Builds one plate frame (unprotected; created in or out of combat).
function P.Build()
  local f = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
  f:Hide()
  P.built = P.built + 1
  -- Every per-plate field exists from the start (no lookups fall through to
  -- frame methods); cast bar and aura lanes are attached on first use.
  f.castBar, f.lanes, f.unit, f.rule, f.isTarget, f.casting = false, false, false, false, false, false
  f.nameOnly, f.friendlyBars, f.colorWhy = false, false, false
  f.health = Bars:Create(f, OWNER)
  f.border = PUI:CreateFrame("Frame", nil, f.health, nil, OWNER)
  f.border:SetPoint("TOPLEFT", -1, 1)
  f.border:SetPoint("BOTTOMRIGHT", 1, -1)
  f.border.edges = edges(f.border, 1)
  f.execute = f.health:CreateTexture(nil, "OVERLAY")
  f.execute:SetWidth(1)
  f.execute:SetColorTexture(1, 1, 1, 0.85)
  f.execute:Hide()
  f.name = fontString(f, "CENTER", "body")
  f.sub = fontString(f, "CENTER", "small")
  f.sub:SetPoint("TOP", f.name, "BOTTOM", 0, -1)
  f.sub:SetTextColor(0.72, 0.71, 0.69)
  f.sub:Hide()
  f.hp = fontString(f.health, "RIGHT")
  f.hp:SetPoint("RIGHT", f.health, "RIGHT", -3, 0)
  f.forces = fontString(f, "LEFT", "small")
  f.forces:SetPoint("LEFT", f.health, "RIGHT", 4, 0)
  f.forces:SetTextColor(0.96, 0.77, 0.42)
  f.forces:Hide()
  -- Target highlight and arrows are frames, so a possibly secret
  -- "is target" boolean can drive their alpha.
  f.glow = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
  f.glow:SetPoint("TOPLEFT", f.health, "TOPLEFT", -2, 2)
  f.glow:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", 2, -2)
  f.glow.edges = edges(f.glow, 2)
  f.glow:SetAlpha(0)
  f.arrows = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
  f.arrows:SetAllPoints(f.health)
  f.arrowL = f.arrows:CreateTexture(nil, "OVERLAY")
  f.arrowL:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  f.arrowL:SetSize(16, 16)
  f.arrowL:SetPoint("RIGHT", f.health, "LEFT", -2, 0)
  f.arrowR = f.arrows:CreateTexture(nil, "OVERLAY")
  f.arrowR:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
  f.arrowR:SetSize(16, 16)
  f.arrowR:SetPoint("LEFT", f.health, "RIGHT", 2, 0)
  f.arrows:SetAlpha(0)
  f.focus = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
  f.focus:SetPoint("TOPLEFT", f.health, "TOPLEFT", -1, 1)
  f.focus:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", 1, -1)
  f.focus.edges = edges(f.focus, 1)
  f.focus.letter = fontString(f.focus, "RIGHT", "small")
  f.focus.letter:SetPoint("BOTTOMRIGHT", f.health, "TOPLEFT", -1, 1)
  f.focus.letter:SetText("F")
  f.focus:SetAlpha(0)
  f.marker = icon(f, 18)
  f.marker:SetPoint("BOTTOM", f.name, "TOP", 0, 2)
  f.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  f.classif = icon(f, 14)
  f.classif:SetPoint("RIGHT", f.health, "LEFT", -2, 0)
  f.classif:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
  f.quest = icon(f, 14)
  f.quest:SetPoint("LEFT", f.name, "RIGHT", 2, 0)
  f.quest:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
  -- Important-cast glow over the cast bar (alpha from a possibly secret flag).
  f.important = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
  f.important.edges = edges(f.important, 2)
  f.important:SetAlpha(0)
  -- Class resource pips (target plate only).
  f.res = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
  f.res:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
  f.res:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -2)
  f.res.pips = {}
  f.res:Hide()
  return f
end

-- Cast bar and aura lanes are created on first use with a real unit token.
function P.Attach(f, unit)
  if not f.castBar then
    f.castBar = PUI.CastBar:Create(OWNER, f, unit)
  else
    f.castBar:SetUnit(unit)
    f.castBar:Enable()
  end
  if not f.lanes then
    f.lanes = {}
    for _, lane in ipairs(P.LANES) do f.lanes[lane] = PUI.Auras:Create(OWNER, f, unit) end
  else
    for _, h in pairs(f.lanes) do h:SetUnit(unit) end
  end
end

function P.Acquire()
  local f = table.remove(P.pool)
  return f or P.Build()
end

function P.Release(f)
  f:Hide()
  f:ClearAllPoints()
  f:SetParent(UIParent)
  f:SetAlpha(1)
  f:SetScale(1)
  f.unit, f.rule, f.isTarget, f.casting = false, false, false, false
  if f.castBar then f.castBar:Disable() end
  if f.lanes then
    for _, h in pairs(f.lanes) do
      h:Configure(P.OffGroups(h)) -- cap 0: the engine stops parsing this lane
      if h.container then h.container:Hide() end
    end
  end
  PUI.Glow:Stop(f.health)
  f.important:SetAlpha(0)
  f.res:Hide()
  P.pool[#P.pool + 1] = f
end

-- Aura lanes ----------------------------------------------------------------
P.LANES = { "debuffs", "buffs", "cc" }
P.LANE_FILTERS = {
  debuffs = { plate = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY", mine = "HARMFUL|PLAYER", all = "HARMFUL" },
  buffs = { important = "HELPFUL|IMPORTANT", purgeable = "HELPFUL|DISPELLABLE", all = "HELPFUL" },
  cc = { cc = "HARMFUL|CROWD_CONTROL", all = "HARMFUL|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY" },
}
P.LANE_FILTER_LABELS = {
  plate = "Your debuffs the game marks for nameplates", mine = "All of your debuffs", all = "Everything",
  important = "Important buffs (big cooldowns, enrage)", purgeable = "Buffs you can purge or soothe",
  cc = "Crowd control on the unit",
}
P.LANE_FILTER_CHOICES = { debuffs = { "plate", "mine", "all" }, buffs = { "important", "purgeable", "all" }, cc = { "cc", "all" } }

function P.OffGroups(h)
  local out = {}
  for _, key in ipairs(h:Groups()) do out[#out + 1] = { key = key, filter = h.groups[key].filter, enabled = false } end
  return out
end

local LANE_POS = {
  debuffs = function(c, f) c:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, 16) end,
  buffs = function(c, f) c:SetPoint("BOTTOMLEFT", f.health, "TOPRIGHT", 4, 2) end,
  cc = function(c, f) c:SetPoint("LEFT", f.health, "RIGHT", 22, 0) end,
}

function P.ConfigureAuras(f, s)
  if not f.lanes then return end
  local hide = f.nameOnly
  for _, lane in ipairs(P.LANES) do
    local h, a = f.lanes[lane], s.auras[lane]
    local filter = P.LANE_FILTERS[lane][a.filter] or P.LANE_FILTERS[lane][P.LANE_FILTER_CHOICES[lane][1]]
    h:SetLayout({ anchor = lane == "cc" and "LEFT" or "BOTTOMLEFT", growX = "RIGHT", growY = "UP", padding = 2,
      lineSize = a.max, size = a.size })
    h:Configure({ { key = lane, filter = filter, max = a.max, sort = lane == "debuffs" and "expiration" or "default",
      enabled = a.enabled and not hide } })
    local c = h.container
    if c then
      c:ClearAllPoints()
      LANE_POS[lane](c, f)
      c:SetShown(a.enabled and not hide)
    end
  end
end

-- Geometry -------------------------------------------------------------------
local function dims(f, s)
  local d = (f.nameOnly or f.friendlyBars) and s.friendly or s.enemy
  return d.width, d.height
end
P.Dims = dims

function P.Layout(f, s)
  local w, h = dims(f, s)
  f:SetSize(w, h)
  f.health:ClearAllPoints()
  f.health:SetPoint("CENTER", f, "CENTER")
  f.health:SetSize(w, h)
  local look = P.LOOK[s.style] or P.LOOK.ember
  paintEdges(f.border.edges, look.border, 1)
  f.border:SetAlpha(f.nameOnly and 0 or look.alpha)
  f.name:ClearAllPoints()
  local inside = not f.nameOnly and s.enemy.namePos == "inside"
  if f.nameOnly then
    f.name:SetPoint("CENTER", f, "CENTER", 0, 0)
  elseif inside then
    f.name:SetPoint("LEFT", f.health, "LEFT", 3, 0)
    f.name:SetPoint("RIGHT", f.hp, "LEFT", -2, 0)
  else
    f.name:SetPoint("BOTTOM", f.health, "TOP", 0, 2)
  end
  f.name:SetJustifyH(inside and "LEFT" or "CENTER")
  f.name:SetFont(Media:Font(s.font), f.nameOnly and s.friendly.nameSize or s.nameSize, "OUTLINE")
  if f.castBar then
    local c = s.cast
    f.castBar:ApplyStyle({ width = w, height = c.height, icon = c.icon, spellName = c.name, timer = c.timer, shield = c.shield,
      kick = c.kick, fadeOut = c.fade, colors = { cast = c.colorCast, channel = c.colorChannel, empower = c.colorChannel,
      locked = c.colorLocked, failed = c.colorFailed, done = c.colorCast } })
    local cf = f.castBar.frame
    cf:ClearAllPoints()
    cf:SetPoint("TOP", f.health, "BOTTOM", 0, -((s.resource.enabled and f.isTarget) and (s.resource.height + 4) or 3))
    f.important:ClearAllPoints()
    f.important:SetPoint("TOPLEFT", cf, "TOPLEFT", -2, 2)
    f.important:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 2, -2)
    paintEdges(f.important.edges, c.importantColor, 1)
    if c.enabled and not f.nameOnly and f.unit then f.castBar:Enable() else f.castBar:Disable() end
  end
  f.res:SetHeight(s.resource.height)
  local ex = s.icons.execute
  if ex > 0 and s.icons.executeLine and not f.nameOnly then
    f.execute:ClearAllPoints()
    f.execute:SetPoint("TOP", f.health, "TOPLEFT", w * ex / 100, 0)
    f.execute:SetPoint("BOTTOM", f.health, "BOTTOMLEFT", w * ex / 100, 0)
    f.execute:Show()
  else
    f.execute:Hide()
  end
  f.marker:SetSize(s.icons.markerSize, s.icons.markerSize)
  local t = s.target
  paintEdges(f.glow.edges, t.color, t.highlight == "glow" and 0.6 or 1)
  f.arrowL:SetVertexColor(t.color.r, t.color.g, t.color.b)
  f.arrowR:SetVertexColor(t.color.r, t.color.g, t.color.b)
  paintEdges(f.focus.edges, t.focusColor, 1)
  f.focus.letter:SetTextColor(t.focusColor.r, t.focusColor.g, t.focusColor.b)
  f.focus.letter:SetShown(t.focusLetter)
  P.ConfigureAuras(f, s)
end
P.LOOK = LOOK

-- Colours -------------------------------------------------------------------
-- Threat status 0-3 (UnitThreatSituation). Role style: tanks want 3, others 0.
-- Classic style: only "you have aggro" (and "about to") is coloured.
P.THREAT = {
  tank = { [0] = "danger", [1] = "warn", [2] = "warn", [3] = "safe" },
  other = { [0] = "safe", [1] = "warn", [2] = "warn", [3] = "danger" },
  classic = { [2] = "warn", [3] = "danger" },
}

-- Another tank in the group holds aggro on this unit (plain values only).
function P.OffTankHolds(unit)
  local prefix, n = "party", (GetNumGroupMembers() or 0) - 1
  if IsInRaid() then prefix, n = "raid", GetNumGroupMembers() or 0 end
  for i = 1, n do
    local u = prefix .. i
    local me = UnitIsUnit(u, "player")
    if plain(me) and not me then
      local role = UnitGroupRolesAssigned(u)
      if plain(role) and role == "TANK" then
        local st = UnitThreatSituation(u, unit)
        if plain(st) and st >= 2 then return true end
      end
    end
  end
  return false
end

-- ThreatKey(unit, role, s) -> "safe" | "warn" | "danger" | "offTank" | nil
function P.ThreatKey(unit, role, s)
  local status = UnitThreatSituation("player", unit)
  if not plain(status) then return nil end
  local c = s.colors
  if role == "TANK" and c.offTank and status < 2 and P.OffTankHolds(unit) then return "offTank" end
  local map = c.threatStyle == "classic" and P.THREAT.classic or P.THREAT[role == "TANK" and "tank" or "other"]
  return map[status]
end

local function rgb(t) return t.r, t.g, t.b end

-- Plain base colour for the unit and why (shown in the preview), or nil when
-- the engine colour (class or selection colour) should be used.
function P.BaseColor(f, s)
  local unit, c = f.unit, s.colors
  local tapped = UnitIsTapDenied(unit)
  if plain(tapped) and tapped then return c.tapped, "tapped" end
  local rule = f.rule
  if rule and s.rules.priority == "rules" then return rule.color, "rule" end
  if c.threat then
    local inCombat = UnitAffectingCombat(unit)
    if plain(inCombat) and inCombat then
      local k = P.ThreatKey(unit, ns.role, s)
      if k then return c[k], "threat." .. k end
    end
  end
  if rule then return rule.color, "rule" end
  if c.quest then
    local q = C_QuestLog.UnitIsRelatedToActiveQuest(unit)
    if plain(q) and q then return c.questColor, "quest" end
  end
  local isPlayer = UnitIsPlayer(unit)
  if c.mode == "class" and plain(isPlayer) and isPlayer then return nil, "class" end
  local reaction = UnitReaction(unit, "player")
  if plain(reaction) then
    if reaction <= 3 then return c.hostile, "hostile" elseif reaction == 4 then return c.neutral, "neutral" end
    return c.friendly, "friendly"
  end
  return nil, "engine"
end

-- Execute recolour: one step colour curve per (base, threshold, colour),
-- evaluated by the engine against the possibly secret health percent.
local curves = {}
function P.ExecuteCurve(base, s)
  local ex, ec = s.icons.execute, s.icons.executeColor
  local id = ("%.3f,%.3f,%.3f/%d/%.3f,%.3f,%.3f"):format(base.r, base.g, base.b, ex, ec.r, ec.g, ec.b)
  local cv = curves[id]
  if cv then return cv end
  cv = C_CurveUtil.CreateColorCurve()
  cv:SetType(Enum.LuaCurveType.Step)
  cv:AddPoint(0, CreateColor(ec.r, ec.g, ec.b, 1))
  cv:AddPoint(ex / 100, CreateColor(base.r, base.g, base.b, 1))
  curves[id] = cv
  return cv
end

function P.UpdateColor(f, s)
  if f.nameOnly then return P.ColorName(f, s) end
  local base, why = P.BaseColor(f, s)
  f.colorWhy = why
  local bar = f.health
  if not base then
    if why == "class" and Bars.ClassColor(bar, f.unit) then return end
    return Bars.Color(bar, UnitSelectionColor(f.unit))
  end
  if s.icons.executeRecolor and s.icons.execute > 0 then
    local col = UnitHealthPercent(f.unit, true, P.ExecuteCurve(base, s))
    if col then return bar:SetStatusBarColor(col:GetRGB()) end
  end
  Bars.Color(bar, rgb(base))
end

function P.ColorName(f, s)
  local unit = f.unit
  if f.rule then return f.name:SetTextColor(rgb(f.rule.color)) end
  local isPlayer = UnitIsPlayer(unit)
  if s.friendly.classNames and isPlayer ~= nil and (Secret.IsSecret(isPlayer) or isPlayer) then
    local _, token = UnitClass(unit)
    local color = token ~= nil and C_ClassColor.GetClassColor(token)
    if color then return f.name:SetTextColor(color:GetRGB()) end
  end
  if plain(isPlayer) and not isPlayer then return f.name:SetTextColor(rgb(s.colors.friendly)) end
  f.name:SetTextColor(1, 1, 1)
end

-- Channels -------------------------------------------------------------------
function P.UpdateHealth(f, s)
  local unit = f.unit
  if f.nameOnly then f.hp:Hide() return end
  Bars:SetValues(f.health, UnitHealthMax(unit), UnitHealth(unit), false)
  local mode = s.enemy.healthText
  if mode == "percent" then
    f.hp:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
  elseif mode == "value" then
    f.hp:SetText(AbbreviateNumbers(UnitHealth(unit)))
  elseif mode == "both" then
    f.hp:SetFormattedText("%s | %.0f%%", AbbreviateNumbers(UnitHealth(unit)), UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
  end
  f.hp:SetShown(mode ~= "none")
  if s.icons.executeRecolor and s.icons.execute > 0 then P.UpdateColor(f, s) end
end

function P.UpdateName(f, s)
  local show = f.nameOnly or s.enemy.name
  if show and not f.nameOnly and s.enemy.hideNameCasting and f.casting then show = false end
  f.name:SetText(UnitName(f.unit))
  f.name:SetShown(show == true)
  local sub
  if f.nameOnly and s.friendly.guild then
    local isPlayer = UnitIsPlayer(f.unit)
    if plain(isPlayer) and isPlayer then sub = GetGuildInfo(f.unit) end
  end
  if sub ~= nil then f.sub:SetFormattedText("<%s>", sub); f.sub:Show() else f.sub:Hide() end
end

-- Cast-side extras the shared bar does not own: important-cast glow and
-- "hide name while casting". The bar itself is PUI.CastBar.
function P.UpdateCastExtras(f, s)
  local unit = f.unit
  local casting = UnitCastingDuration(unit) ~= nil or UnitChannelDuration(unit) ~= nil -- duration objects are never secret
  f.casting = casting
  local spellID
  if s.cast.enabled and s.cast.important and casting and not f.nameOnly then
    spellID = select(9, UnitCastingInfo(unit))
    if spellID == nil then spellID = select(8, UnitChannelInfo(unit)) end
  end
  if spellID ~= nil then f.important:SetAlphaFromBoolean(C_Spell.IsSpellImportant(spellID), 1, 0) else f.important:SetAlpha(0) end
  if s.enemy.hideNameCasting then P.UpdateName(f, s) end
end

local function applyScale(f, s)
  f:SetScale((f.isTarget and s.target.scale or 1) * (f.rule and f.rule.scale or 1))
end

function P.UpdateTarget(f, s)
  local unit, t = f.unit, s.target
  local isTarget = UnitIsUnit("target", unit)
  local bars = not f.nameOnly
  if t.highlight ~= "none" and bars then f.glow:SetAlphaFromBoolean(isTarget, 1, 0) else f.glow:SetAlpha(0) end
  if t.arrows and bars then f.arrows:SetAlphaFromBoolean(isTarget, 1, 0) else f.arrows:SetAlpha(0) end
  local has = UnitExists("target")
  if t.nonTargetAlpha < 1 and plain(has) and has then f:SetAlphaFromBoolean(isTarget, 1, t.nonTargetAlpha) else f:SetAlpha(1) end
  local was = f.isTarget
  f.isTarget = plain(isTarget) and isTarget == true
  applyScale(f, s)
  if t.focus and bars then f.focus:SetAlphaFromBoolean(UnitIsUnit("focus", unit), 1, 0) else f.focus:SetAlpha(0) end
  if was ~= f.isTarget and s.resource.enabled then P.Layout(f, s) end
  P.UpdateResource(f, s)
end

function P.UpdateFocus(f, s)
  if s.target.focus and not f.nameOnly then f.focus:SetAlphaFromBoolean(UnitIsUnit("focus", f.unit), 1, 0) else f.focus:SetAlpha(0) end
end

function P.UpdateIcons(f, s)
  local unit, ic = f.unit, s.icons
  local idx
  if ic.raidMarker then idx = GetRaidTargetIndex(unit) end
  if idx == nil then f.marker:Hide() else f.marker:SetSpriteSheetCell(idx, 4, 4); f.marker:Show() end
  local c = ic.classification and not f.nameOnly and UnitClassification(unit)
  if c and plain(c) and (c == "elite" or c == "rareelite" or c == "rare" or c == "worldboss") then
    f.classif:SetVertexColor(c == "rare" and 0.7 or 1, c == "rare" and 0.7 or 0.85, c == "rare" and 1 or 0.2)
    f.classif:Show()
  else
    f.classif:Hide()
  end
  local q = ic.quest and C_QuestLog.UnitIsRelatedToActiveQuest(unit)
  f.quest:SetShown(q and plain(q) and q == true or false)
  P.UpdateForces(f, s)
end

-- M+ enemy forces text (data from PUI.Season, the Ascent data provider).
function P.UpdateForces(f, s)
  if not s.icons.forces or f.nameOnly then f.forces:Hide() return end
  local text = PUI.Season:UnitForces(f.unit)
  if text == nil then f.forces:Hide() return end
  f.forces:SetFormattedText("+%s", text)
  f.forces:Show()
end

-- Class resource on the target plate (Resource Bars owns the resolver).
local function resolver()
  local RB = PUI.ResourceBars
  return RB and RB.ClassResource and RB.ClassResource.Resolve
end

function P.UpdateResource(f, s)
  local res = f.res
  local resolve = resolver()
  if not (s.resource.enabled and f.isTarget and not f.nameOnly and resolve) then res:Hide() return end
  local kind, ptype, max = resolve()
  if kind ~= "points" or type(max) ~= "number" or max < 1 then res:Hide() return end
  local w = dims(f, s)
  local gap = 2
  local pw = (w - gap * (max - 1)) / max
  local value = UnitPower("player", ptype)
  for i = 1, math.max(max, #res.pips) do
    local p = res.pips[i]
    if i <= max then
      if not p then
        p = Bars:Create(res, OWNER)
        res.pips[i] = p
      end
      Bars.Color(p, rgb(s.resource.color))
      p:ClearAllPoints()
      p:SetPoint("TOPLEFT", res, "TOPLEFT", (i - 1) * (pw + gap), 0)
      p:SetSize(pw, s.resource.height)
      p:SetMinMaxValues(i - 1, i)
      p:SetValue(value) -- the engine clamps; Lua never compares the amount
      p:Show()
    elseif p then
      p:Hide()
    end
  end
  res:Show()
end

-- Friendly name-only or health-bar mode, per content type and unit kind.
function P.ApplyMode(f, s)
  local friend = UnitIsFriend("player", f.unit)
  local isFriend = plain(friend) and friend == true
  local bars = false
  if isFriend then
    local isPlayer = UnitIsPlayer(f.unit)
    local row = (plain(isPlayer) and isPlayer) and "players" or "npcs"
    bars = (s.friendly.bars[row] or {})[s.content] == true
  end
  f.nameOnly, f.friendlyBars = isFriend and not bars, isFriend and bars
  f.health:SetShown(not f.nameOnly)
  f.rule = ns.Rules.Match(f.unit) or false
end

function P.UpdateAll(f, s)
  P.ApplyMode(f, s)
  P.Layout(f, s)
  P.UpdateColor(f, s)
  if not f.nameOnly then f.name:SetTextColor(1, 1, 1) end
  P.UpdateHealth(f, s)
  P.UpdateName(f, s)
  if f.castBar and s.cast.enabled and not f.nameOnly then f.castBar:Refresh() end
  P.UpdateCastExtras(f, s)
  P.UpdateTarget(f, s)
  P.UpdateIcons(f, s)
  if f.rule and f.rule.glow and not f.nameOnly then PUI.Glow:Start(f.health, "pulse", f.rule.color) else PUI.Glow:Stop(f.health) end
end

-- Preview samples (options page): fixed values, never a unit read.
P.SAMPLES = {
  { name = "Void Acolyte", pct = 0.72, color = "hostile", target = true },
  { name = "Shade Lord", pct = 0.31, color = "warn", quest = true, focus = true },
  { name = "Healer Bot", nameOnly = true, sub = "Phoenix Guild" },
  { name = "Searing Totem", pct = 0.18, color = "neutral", execute = true },
}
function P.PaintSample(f, s, i)
  local d = P.SAMPLES[i]
  f.nameOnly, f.friendlyBars, f.rule, f.unit, f.isTarget = d.nameOnly == true, false, false, false, d.target == true
  f.health:SetShown(not f.nameOnly)
  P.Layout(f, s)
  f.name:SetText(d.name)
  f.name:SetShown(f.nameOnly or s.enemy.name)
  if f.nameOnly then
    f.name:SetTextColor(0.25, 0.78, 0.92)
    f.sub:SetShown(s.friendly.guild and d.sub ~= nil)
    if d.sub then f.sub:SetFormattedText("<%s>", d.sub) end
    f.hp:Hide()
  else
    f.sub:Hide()
    f.name:SetTextColor(1, 1, 1)
    f.health:SetMinMaxValues(0, 1)
    f.health:SetValue(d.pct)
    local c = s.colors[d.color] or s.colors.hostile
    if d.execute and s.icons.executeRecolor and s.icons.execute > 0 and d.pct * 100 < s.icons.execute then c = s.icons.executeColor end
    Bars.Color(f.health, rgb(c))
    f.hp:SetFormattedText("%.0f%%", d.pct * 100)
    f.hp:SetShown(s.enemy.healthText ~= "none")
  end
  f.glow:SetAlpha((d.target and s.target.highlight ~= "none") and 1 or 0)
  f.arrows:SetAlpha((d.target and s.target.arrows) and 1 or 0)
  f.focus:SetAlpha((d.focus and s.target.focus) and 1 or 0)
  f.quest:SetShown(d.quest == true and s.icons.quest)
  f.important:SetAlpha(0)
  f.forces:SetShown(i == 1 and s.icons.forces)
  if i == 1 then f.forces:SetText("+0.84%") end
  f:SetAlpha((not d.target and not f.nameOnly and s.target.nonTargetAlpha < 1) and s.target.nonTargetAlpha or 1)
  f.res:Hide()
end
