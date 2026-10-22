local _, ns = ...
local Theme, Skin, Media = ns.Theme, ns.Skin, ns.Media
local M = ns.modules.UnitFrames

--[[ One unit frame's widgets (M:Build) and their layout from the saved settings (M:Layout). The real frames, the
    Test frames and the options preview are all built here, so what the preview shows is the frame itself:
    only the secure template differs (the preview and samples are plain Buttons).
    Every region is ours; nothing of Blizzard's is touched. Layout of a secure frame runs out of combat. ]]

local WHITE = Media.textures.WHITE
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local UF_ATLAS = { leader = "UI-HUD-UnitFrame-Player-Group-LeaderIcon", combat = "UI-HUD-UnitFrame-Player-CombatIcon",
    rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star" }
M.ATLAS = UF_ATLAS
M.RAID_ICONS = RAID_ICONS

local function statusBar(parent, layer)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetStatusBarTexture(WHITE)
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    if layer then b:SetFrameLevel(parent:GetFrameLevel() + layer) end
    return b
end

local function texture(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    t:SetTexture(WHITE)
    return t
end

---------------------------------------------------------------- aura icons
local function auraButton(container, index)
    local b = CreateFrame("Button", nil, container)
    b:SetSize(20, 20)
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetAllPoints()
    b.Dispel = b:CreateTexture(nil, "BACKGROUND")
    b.Dispel:SetTexture(WHITE)
    b.Dispel:SetPoint("TOPLEFT", -1, 1)
    b.Dispel:SetPoint("BOTTOMRIGHT", 1, -1)
    b.Dispel:Hide()
    b.Cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.Cooldown:SetAllPoints(b.Icon)
    b.Cooldown:SetDrawEdge(false)
    b.Cooldown:SetReverse(true)
    b.Over = CreateFrame("Frame", nil, b)
    b.Over:SetAllPoints()
    b.Over:SetFrameLevel(b.Cooldown:GetFrameLevel() + 2)
    b.Count = b.Over:CreateFontString(nil, "OVERLAY")
    b.index = index
    b:SetScript("OnEnter", function(self)
        if not (self.unit and self.auraInstanceID) or not M:Unit(container.key).auras.tooltips then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, self.unit, self.auraInstanceID)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:EnableMouse(false)
    b:Hide()
    return b
end

function M.AuraButton(container, i)
    container.buttons = container.buttons or {}
    local b = container.buttons[i]
    if not b then
        b = auraButton(container, i)
        container.buttons[i] = b
    end
    return b
end

---------------------------------------------------------------- build
--[[ opts: { secure = bool, name = global name|nil, token = unit token (secure frames), sample = table (plain data) }
    Returns the frame with its parts as fields (Health, Power, AltPower, Absorb …). ]]
function M:Build(parent, key, opts)
    opts = opts or {}
    local f
    if opts.secure then
        f = CreateFrame("Button", opts.name, parent, "SecureUnitButtonTemplate,PingableUnitFrameTemplate")
    else
        f = CreateFrame("Button", opts.name, parent)
    end
    f.unitKey, f.token, f.unit, f.sample = key, opts.token, opts.token, opts.sample
    f.secure = opts.secure and true or nil

    -- bars
    f.Health = statusBar(f, 1)
    f.Health.bg = texture(f.Health, "BACKGROUND")
    f.Health.bg:SetAllPoints()
    f.Health:SetClipsChildren(true)
    f.HealPred = statusBar(f.Health)
    f.HealPred:SetPoint("TOPLEFT", f.Health:GetStatusBarTexture(), "TOPRIGHT")
    f.HealPred:SetPoint("BOTTOMLEFT", f.Health:GetStatusBarTexture(), "BOTTOMRIGHT")
    f.Absorb = statusBar(f.Health)
    f.HealAbsorb = statusBar(f.Health)
    f.HealAbsorb:SetReverseFill(true)
    f.HealAbsorb:SetPoint("TOPRIGHT", f.Health:GetStatusBarTexture(), "TOPRIGHT")
    f.HealAbsorb:SetPoint("BOTTOMRIGHT", f.Health:GetStatusBarTexture(), "BOTTOMRIGHT")
    f.Shade = texture(f.Health, "OVERLAY", 1)
    f.Shade:SetAllPoints()
    f.Highlight = texture(f.Health, "OVERLAY", 2)
    f.Highlight:SetAllPoints()
    f.Highlight:SetBlendMode("ADD")
    f.Highlight:Hide()

    f.Power = statusBar(f, 1)
    f.Power.bg = texture(f.Power, "BACKGROUND")
    f.Power.bg:SetAllPoints()
    f.AltPower = statusBar(f, 1)
    f.AltPower.bg = texture(f.AltPower, "BACKGROUND")
    f.AltPower.bg:SetAllPoints()
    f.AltPower:Hide()

    -- portrait: a 2D texture (game portrait or class icon) or a 3D model, with its own border holder
    f.PortraitHolder = CreateFrame("Frame", nil, f)
    f.PortraitHolder:SetFrameLevel(f:GetFrameLevel() + 2)
    f.Portrait = f.PortraitHolder:CreateTexture(nil, "ARTWORK")
    f.Portrait:SetAllPoints()
    f.Model = CreateFrame("PlayerModel", nil, f.PortraitHolder)
    f.Model:SetAllPoints()
    f.Model:Hide()
    f.PortraitMask = f.PortraitHolder:CreateMaskTexture()
    f.PortraitMask:SetAllPoints(f.Portrait)
    f.PortraitMask:SetTexture(Media.textures.MASK_CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    -- texts sit above every bar
    f.TextLayer = CreateFrame("Frame", nil, f)
    f.TextLayer:SetAllPoints()
    f.TextLayer:SetFrameLevel(f:GetFrameLevel() + 6)
    f.NameText = f.TextLayer:CreateFontString(nil, "OVERLAY")
    f.HealthText = f.TextLayer:CreateFontString(nil, "OVERLAY")
    f.PowerText = f.TextLayer:CreateFontString(nil, "OVERLAY")
    f.InfoText = f.TextLayer:CreateFontString(nil, "OVERLAY")
    for _, fs in ipairs({ f.NameText, f.HealthText, f.PowerText, f.InfoText }) do
        fs:SetWordWrap(false)
        fs:SetNonSpaceWrap(false)
    end

    -- indicators
    local L = f.TextLayer
    f.Marker = L:CreateTexture(nil, "OVERLAY", nil, 2)
    f.Marker:SetTexture(RAID_ICONS)
    f.Marker:Hide()
    f.Leader = L:CreateTexture(nil, "OVERLAY")
    f.Leader:SetAtlas(UF_ATLAS.leader)
    f.Leader:Hide()
    f.Role = L:CreateTexture(nil, "OVERLAY")
    f.Role:Hide()
    f.Combat = L:CreateTexture(nil, "OVERLAY")
    f.Combat:SetAtlas(UF_ATLAS.combat)
    f.Combat:Hide()
    f.Resting = L:CreateFontString(nil, "OVERLAY")
    f.Resting:Hide()
    f.PvP = L:CreateTexture(nil, "OVERLAY")
    f.PvP:Hide()
    f.Elite = L:CreateTexture(nil, "OVERLAY")
    f.Elite:Hide()
    f.Ready = L:CreateTexture(nil, "OVERLAY", nil, 3)
    f.Ready:Hide()

    -- threat glow and the "this is my target" border live on their own frames around ours
    f.ThreatGlow = CreateFrame("Frame", nil, f)
    f.ThreatGlow:SetAllPoints()
    f.ThreatGlow:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
    f.ThreatGlow:Hide()
    f.TargetMark = CreateFrame("Frame", nil, f)
    f.TargetMark:SetPoint("TOPLEFT", -2, 2)
    f.TargetMark:SetPoint("BOTTOMRIGHT", 2, -2)
    f.TargetMark:SetFrameLevel(f:GetFrameLevel() + 7)
    f.TargetMark:Hide()

    -- auras
    f.Buffs = CreateFrame("Frame", nil, f)
    f.Buffs.key, f.Buffs.kind = key, "buffs"
    f.Debuffs = CreateFrame("Frame", nil, f)
    f.Debuffs.key, f.Debuffs.kind = key, "debuffs"

    -- S9 cast bars attach here (M:CastBarAnchor); until then Blizzard's own target/focus/boss cast bar does
    f.CastAnchor = CreateFrame("Frame", nil, f)
    f.CastAnchor:SetSize(1, 1)

    -- class resource (player) and arena extras; false (not nil) when the frame has none
    f.ClassPower, f.Trinket, f.Spec = false, false, false
    if key == "player" then
        f.ClassPower = CreateFrame("Frame", nil, f)
        f.ClassPower.pips = {}
        f.ClassPower.bar = statusBar(f.ClassPower)
        f.ClassPower.bar:SetAllPoints()
        f.ClassPower.bar.bg = texture(f.ClassPower.bar, "BACKGROUND")
        f.ClassPower.bar.bg:SetAllPoints()
        f.ClassPower.bar:Hide()
        f.ClassPower:Hide()
    end

    -- arena: PvP trinket and specialization
    if key == "arena" then
        f.Trinket = CreateFrame("Frame", nil, f)
        f.Trinket.Icon = f.Trinket:CreateTexture(nil, "ARTWORK")
        f.Trinket.Icon:SetAllPoints()
        f.Trinket.Cooldown = CreateFrame("Cooldown", nil, f.Trinket, "CooldownFrameTemplate")
        f.Trinket.Cooldown:SetAllPoints()
        f.Trinket:Hide()
        f.Spec = CreateFrame("Frame", nil, f)
        f.Spec.Icon = f.Spec:CreateTexture(nil, "ARTWORK")
        f.Spec.Icon:SetAllPoints()
        f.Spec:Hide()
    end

    f:SetScript("OnEnter", function(self) M:OnEnterFrame(self) end)
    f:SetScript("OnLeave", function(self) M:OnLeaveFrame(self) end)
    return f
end

---------------------------------------------------------------- layout
local function place(region, parent, rect)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", rect[1], -rect[2])
    region:SetSize(math.max(1, rect[3]), math.max(1, rect[4]))
end

local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT", TOPLEFT = "BOTTOMRIGHT",
    TOPRIGHT = "BOTTOMLEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT", CENTER = "CENTER" }

function M:BarTexture(key, which)
    local u = self:Unit(key)
    local name = (which == "power" and u.powerBar.texture ~= "" and u.powerBar.texture) or u.texture
    return name ~= "" and Media:Bar(name) or Theme:Bar()
end

local function indicator(region, parent, anchor, size, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", parent, anchor, x or 0, y or 0)
    if region.SetSize then region:SetSize(size, size) end
end

local function styleAuraButton(b, a)
    Skin:IconZoom(b.Icon, a.zoom)
    Skin:BorderSpec(b, a.border, "border.black")
    Skin:TextSpec(b.Count, a.count, "number", "text.primary")
    Skin:Place(b.Count, b.Over, a.count)
    b.Cooldown:SetDrawSwipe(a.swipe)
    local cd = b.Cooldown.GetCountdownFontString and b.Cooldown:GetCountdownFontString()
    if cd then
        Skin:TextSpec(cd, a.duration, "number", "text.primary")
        b.Cooldown:SetHideCountdownNumbers(not a.duration.show)
    end
    b:EnableMouse(a.tooltips)
end

M.StyleAuraButton = styleAuraButton

local function layoutAuraButtons(container, a, up, leftGrow)
    local slots = M.AuraSlots(a.max, a.size, a.perRow, a.spacing, leftGrow and "LEFT" or "RIGHT", up)
    local anchor = (up and "BOTTOM" or "TOP") .. (leftGrow and "RIGHT" or "LEFT")
    for i = 1, a.max do
        local b = M.AuraButton(container, i)
        b:SetSize(a.size, a.size)
        b:ClearAllPoints()
        b:SetPoint(anchor, container, anchor, slots[i][1], slots[i][2])
        styleAuraButton(b, a)
    end
    for i = a.max + 1, #(container.buttons or {}) do container.buttons[i]:Hide() end
end

-- the vertical room a row needs to clear: the class resource above, the hanging power bar and cast bar below
local function auraOffset(f, u, container, where, other, rows)
    local a = u.auras
    local stacked = other == where and container.kind == "debuffs" and (a.size + a.spacing) * rows or 0
    if where == "above" then
        local cp = f.ClassPower and M.db.classPower
        local lift = (cp and cp.show == "attached" and f.classPowerActive) and (cp.height + 2) or 0
        return lift + stacked
    end
    local castBelow = u.cast.attach == "below" and not M.SMALL[f.unitKey] and f.unitKey ~= "player"
    local hanging = (u.powerBar.show ~= "off" and u.powerBar.position == "below") and (u.powerBar.height + 2) or 0
    return hanging + (castBelow and (u.cast.height + u.cast.gap) or 0) + stacked
end

local function layoutAuras(f, u, container, where, other)
    local a = u.auras
    container:ClearAllPoints()
    if where == "off" then container:Hide(); return end
    container:Show()
    local gap = a.gap
    local rows = math.max(1, math.ceil(a.max / math.max(1, a.perRow)))
    local width = math.min(a.max, a.perRow) * (a.size + a.spacing) - a.spacing
    container:SetSize(math.max(1, width), rows * (a.size + a.spacing) - a.spacing)
    local leftGrow = a.growth == "LEFT"
    local edge = leftGrow and "RIGHT" or "LEFT"
    if where == "above" then
        container:SetPoint("BOTTOM" .. edge, f, "TOP" .. edge, 0, gap + auraOffset(f, u, container, where, other, rows))
    elseif where == "below" then
        container:SetPoint("TOP" .. edge, f, "BOTTOM" .. edge, 0, -(gap + auraOffset(f, u, container, where, other, rows)))
    elseif where == "left" then
        container:SetPoint("TOPRIGHT", f, "TOPLEFT", -gap, 0)
        leftGrow = true
    else -- right
        container:SetPoint("TOPLEFT", f, "TOPRIGHT", gap, 0)
        leftGrow = false
    end
    container.up = where == "above"
    container.leftGrow = leftGrow
    layoutAuraButtons(container, a, where == "above", leftGrow)
end

local function layoutHealth(self, f, u, g, key)
    place(f.Health, f, g.health)
    f.Health:SetStatusBarTexture(self:BarTexture(key))
    f.Health:SetOrientation(u.bar.vertical and "VERTICAL" or "HORIZONTAL")
    f.Health:SetReverseFill(u.bar.reverse and true or false)
    local bgMode = u.bar.bg
    f.Health.bg:SetShown(bgMode ~= "none")
    f.Health.bg:SetTexture(bgMode == "texture" and self:BarTexture(key) or WHITE)
    local shade = u.bar.gradient or 0
    f.Shade:SetShown(shade > 0)
    if shade > 0 then f.Shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, shade), CreateColor(1, 1, 1, shade * 0.35)) end
    f.Highlight:SetVertexColor(1, 1, 1, 0.12)
end

-- prediction and absorbs follow the health bar's own fill texture (no maths on health)
local function layoutPrediction(self, f, u, g, key)
    local hw, hh = g.health[3], g.health[4]
    local fillTex = self:BarTexture(key)
    f.HealPred:SetSize(hw, hh)
    f.HealPred:SetStatusBarTexture(fillTex)
    f.HealPred:SetStatusBarColor(self:Color("myHeal"))
    f.HealPred:SetAlpha(0.5)
    f.Absorb:ClearAllPoints()
    local ab = u.absorb
    if ab.position == "reverse" then
        f.Absorb:SetAllPoints(f.Health)
        f.Absorb:SetReverseFill(true)
    else
        f.Absorb:SetReverseFill(false)
        f.Absorb:SetPoint("TOPLEFT", f.HealPred:GetStatusBarTexture(), "TOPRIGHT")
        f.Absorb:SetPoint("BOTTOMLEFT", f.HealPred:GetStatusBarTexture(), "BOTTOMRIGHT")
        f.Absorb:SetWidth(hw)
    end
    f.Absorb:SetStatusBarTexture(ab.style == "striped" and Media:Bar("FineStripes") or fillTex)
    f.Absorb:SetStatusBarColor(self:Color("absorb"))
    f.Absorb:SetAlpha(ab.alpha)
    f.HealAbsorb:SetSize(hw, hh)
    f.HealAbsorb:SetStatusBarTexture(Media:Bar("Stripes"))
    f.HealAbsorb:SetStatusBarColor(self:Color("healAbsorb"))
    f.HealAbsorb:SetAlpha(0.7)
end

local NO_BORDER = { style = "none", shadow = "none" }

local function layoutPower(self, f, u, g, key)
    local pb = u.powerBar
    local inside = pb.position == "inside"
    f.Power:SetShown(g.power ~= nil)
    if g.power then
        place(f.Power, f, g.power)
        f.Power:SetStatusBarTexture(self:BarTexture(key, "power"))
        f.Power:SetFrameLevel(f:GetFrameLevel() + (inside and 1 or 3))
        Skin:BorderSpec(f.Power, inside and NO_BORDER or u.border, "border.black")
        Skin:Backdrop(f.Power, { alpha = inside and 0 or 0.9, color = false, style = "solid" }, "bg.sunken")
    end
    f.AltPower:ClearAllPoints()
    f.AltPower:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -((g.power and not inside) and (pb.height + 4) or 2))
    f.AltPower:SetSize(u.width, math.max(3, pb.height - 2))
    f.AltPower:SetStatusBarTexture(self:BarTexture(key, "power"))
    Skin:BorderSpec(f.AltPower, u.border, "border.black")
end

local function layoutPortrait(f, u, g)
    f.PortraitHolder:SetShown(g.portrait ~= nil)
    if not g.portrait then return end
    place(f.PortraitHolder, f, g.portrait)
    local overlay = u.portraitPos == "overlay"
    f.PortraitHolder:SetFrameLevel(f:GetFrameLevel() + (overlay and 2 or 1))
    f.PortraitHolder:SetAlpha(overlay and math.min(u.portraitAlpha, 0.6) or u.portraitAlpha)
    f.Model:SetShown(u.portrait == "model")
    f.Portrait:SetShown(u.portrait ~= "model")
    local round = u.portraitShape == "circle" and not overlay
    if round then f.Portrait:AddMaskTexture(f.PortraitMask) else f.Portrait:RemoveMaskTexture(f.PortraitMask) end
    Skin:BorderSpec(f.PortraitHolder, (overlay or round) and NO_BORDER or u.portraitBorder, "border.black")
end

local function layoutTexts(self, f, u, g)
    local function text(fs, spec, anchorTo)
        Skin:TextSpec(fs, spec, "unit", "text.primary")
        Skin:Place(fs, anchorTo, spec)
        fs:SetShown(spec.show ~= false)
    end
    text(f.NameText, u.name, f.Health)
    text(f.HealthText, u.health, f.Health)
    text(f.PowerText, u.power, g.power and f.Power or f.Health)
    text(f.InfoText, u.info, f.Health)
    -- the name never runs under the health text: it may use what the bar has left
    local share = (u.tags.health ~= "" and u.health.show ~= false) and 0.62 or 0.95
    f.NameText:SetWidth(math.max(20, g.health[3] * share))
    local d = self.db.percentDecimals
    f.compiled = { name = M.CompileTags(u.tags.name, d), health = M.CompileTags(u.tags.health, d),
        power = M.CompileTags(u.tags.power, d), info = M.CompileTags(u.tags.info, d) }
end

local function layoutIndicators(f, u)
    local ic = u.icons
    local s = ic.size
    local right = u.portraitPos == "right"
    indicator(f.Marker, f.Health, ic.markerAnchor, ic.markerSize, 0, 0)
    indicator(f.Leader, f, "TOPLEFT", s, 8, 0)
    indicator(f.Role, f, "TOPRIGHT", s, -8, 0)
    indicator(f.Combat, f.Health, "CENTER", s + 4, 0, 0)
    f.Resting:ClearAllPoints()
    f.Resting:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 2, 1)
    Skin:Text(f.Resting, "small", "accent.primary")
    indicator(f.PvP, f, right and "TOPRIGHT" or "TOPLEFT", s + 4, 0, 0)
    indicator(f.Elite, f, right and "BOTTOMRIGHT" or "BOTTOMLEFT", s + 2, 0, 0)
    indicator(f.Ready, f.Health, "CENTER", s + 6, 0, 0)
    Skin:BorderSpec(f.ThreatGlow, { style = "glow", size = 2, color = false }, "state.danger")
    Skin:BorderSpec(f.TargetMark, { style = "solid", size = 1, color = false, shadow = "none" }, "accent.primary")
end

local function layoutExtras(self, f, u, g, key)
    if f.ClassPower then
        if g.classPower then place(f.ClassPower, f, g.classPower) end
        f.ClassPower.bar:SetStatusBarTexture(self:BarTexture(key, "power"))
    end
    if not f.Trinket then return end
    local size = u.height
    f.Trinket:ClearAllPoints()
    f.Trinket:SetPoint("TOPLEFT", f, "TOPRIGHT", 3, 0)
    f.Trinket:SetSize(size, size)
    Skin:IconZoom(f.Trinket.Icon, 0.08)
    Skin:BorderSpec(f.Trinket, u.border, "border.black")
    f.Spec:ClearAllPoints()
    f.Spec:SetPoint("TOPLEFT", f.Trinket, "TOPRIGHT", 3, 0)
    f.Spec:SetSize(size * 0.6, size * 0.6)
    Skin:IconZoom(f.Spec.Icon, 0.08)
    Skin:BorderSpec(f.Spec, u.border, "border.black")
end

-- The frame's size, bars, texts and indicators from its settings. Secure frames: out of combat only.
function M:Layout(f)
    local key = f.unitKey
    local u = self:Unit(key)
    local cp = key == "player" and self.db.classPower or nil
    local g = M.Geometry(u, { classPower = cp and f.ClassPower and f.classPowerActive and cp or nil })
    f:SetSize(u.width, u.height)
    f:SetFrameStrata(u.strata)
    Skin:Backdrop(f, u.background, "bg.sunken")
    Skin:BorderSpec(f, u.border, "border.black")
    layoutHealth(self, f, u, g, key)
    layoutPrediction(self, f, u, g, key)
    layoutPower(self, f, u, g, key)
    layoutPortrait(f, u, g)
    layoutTexts(self, f, u, g)
    layoutIndicators(f, u)
    self:LayoutCastAnchor(f, u)
    layoutAuras(f, u, f.Buffs, u.auras.buffs, u.auras.debuffs)
    layoutAuras(f, u, f.Debuffs, u.auras.debuffs, u.auras.buffs)
    layoutExtras(self, f, u, g, key)
    f.layoutDone = true
end

-- Where S9's cast bar goes: under or over the frame, sized to it (none = no anchor in use).
function M:LayoutCastAnchor(f, u)
    local a = f.CastAnchor
    a:ClearAllPoints()
    local where = u.cast.attach
    if M.SMALL[f.unitKey] or f.unitKey == "player" or where == "none" then
        a:SetPoint("TOP", f, "BOTTOM", 0, -u.cast.gap)
        a:SetSize(u.width, u.cast.height)
        a.active = false
        return
    end
    local hanging = (u.powerBar.show ~= "off" and u.powerBar.position == "below") and (u.powerBar.height + 2) or 0
    if where == "above" then
        a:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, u.cast.gap)
    else
        a:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -(u.cast.gap + hanging))
    end
    a:SetSize(u.width, u.cast.height)
    a.active = true
end
M.OPPOSITE = OPPOSITE
