local _, ns = ...
local Skin, Media, Theme = ns.Skin, ns.Media, ns.Theme
local M = ns.modules.NamePlates

--[[ One Phoenix plate: plain frames on top of a nameplate base (or on the preview stage / Test holder). Nothing here
    takes the mouse: clicks go to the base, which the game owns.

    p            holder, centred on the base; scaled by the context
    p.Health     StatusBar (+ .bg); p.Absorb rides the fill edge; p.Shade a gradient over the fill
    p.Execute    execute-colour overlay on the fill (alpha from a step curve); p.ExecuteMark the threshold line
    p.Hover      mouseover wash; p.Glow target border/glow frame; p.ArrowL / p.ArrowR target arrows
    p.FocusMark  focus stripe on the bar's left edge
    p.Name / p.HealthText / p.Level / p.Info   tag texts (Unit Frames tags)
    p.Marker / p.Quest / p.Elite               raid marker, quest and classification badges
    p.Cast       a CastBars engine bar (key "plate.<kind>")
    p.Debuffs / p.Buffs                        aura rows of Unit Frames aura buttons
    p.ClassPower the player's resource on the target plate (Unit Frames' class power drawing)
    p.Forces     Mythic+ forces ]]

local WHITE = Media.textures.WHITE
local UF = ns.modules.UnitFrames
local CB = ns.modules.CastBars

local function tex(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    t:SetTexture(WHITE)
    return t
end

local function container(parent, kind)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(1, 1)
    c.kind = kind
    c:EnableMouse(false)
    return c
end

function M:BuildPlate(parent, opts)
    opts = opts or {}
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(1, 1)
    p:EnableMouse(false)
    p.sample = opts.sample
    local h = CreateFrame("StatusBar", nil, p)
    h:SetMinMaxValues(0, 1)
    h:SetValue(1)
    h:SetClipsChildren(true)
    h.bg = tex(h, "BACKGROUND", -7)
    h.bg:SetAllPoints()
    p.Health = h
    p.Shade = tex(h, "ARTWORK", 2)
    p.Execute = tex(h, "ARTWORK", 3)
    p.Execute:SetAlpha(0)
    p.Absorb = CreateFrame("StatusBar", nil, h)
    p.Absorb:SetMinMaxValues(0, 1)
    p.Absorb:SetValue(0)
    p.ExecuteMark = tex(h, "OVERLAY", 3)
    p.Hover = tex(h, "OVERLAY", 4)
    p.Hover:SetAllPoints()
    p.Hover:SetBlendMode("ADD")
    p.Hover:Hide()
    p.FocusMark = tex(h, "OVERLAY", 5)
    p.FocusMark:Hide()
    local glow = CreateFrame("Frame", nil, p)
    glow:SetAllPoints(h)
    glow:SetFrameLevel(h:GetFrameLevel() + 3)
    glow:Hide()
    p.Glow = glow
    p.ArrowL = p:CreateTexture(nil, "OVERLAY")
    p.ArrowR = p:CreateTexture(nil, "OVERLAY")
    p.ArrowL:Hide(); p.ArrowR:Hide()
    -- texts on their own level so borders never cover them
    local texts = CreateFrame("Frame", nil, p)
    texts:SetAllPoints(h)
    texts:SetFrameLevel(h:GetFrameLevel() + 4)
    p.Texts = texts
    p.Name = texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.Name:SetWordWrap(false)
    p.HealthText = texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.Level = texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.Info = texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.Info:SetWordWrap(false)
    p.Forces = texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.Marker = texts:CreateTexture(nil, "OVERLAY")
    p.Marker:SetTexture(UF.RAID_ICONS)
    p.Marker:Hide()
    p.Quest = texts:CreateTexture(nil, "OVERLAY")
    p.Quest:Hide()
    p.Elite = texts:CreateTexture(nil, "OVERLAY")
    p.Elite:Hide()
    p.Cast = CB:BuildBar(p, "plate.enemy", { preview = opts.preview })
    p.Cast:EnableMouse(false)
    p.Cast:SetScript("OnUpdate", CB.OnBarUpdate)
    p.Cast:Hide()
    p.Debuffs = container(p, "debuffs")
    p.Buffs = container(p, "buffs")
    local cp = CreateFrame("Frame", nil, p)
    cp.pips = {}
    cp.bar = CreateFrame("StatusBar", nil, cp)
    cp.bar:SetAllPoints()
    cp.bar:SetStatusBarTexture(WHITE)
    cp.bar.bg = tex(cp.bar, "BACKGROUND")
    cp.bar.bg:SetAllPoints()
    cp:Hide()
    p.ClassPower = cp
    -- Unit Frames' class power code draws into p.ClassPower; it must not lay out a unit frame
    p.noLayout = true
    return p
end

---------------------------------------------------------------- layout
local function placeText(fs, parent, spec)
    Skin:Place(fs, parent, spec)
    fs:SetShown(spec.show ~= false)
end

local function layoutAuras(p, s, g)
    local a = s.auras
    for _, c in ipairs({ p.Debuffs, p.Buffs }) do c.key = p.unitKey end
    local d = { size = a.size, spacing = a.spacing, max = a.max, perRow = a.perRow, zoom = a.zoom, border = a.border,
                count = a.count, duration = a.duration, swipe = a.swipe, tooltips = false, dispel = a.dispel, desat = a.desat }
    p.debuffSpec = d
    local rows = math.max(1, math.ceil(a.max / math.max(1, a.perRow)))
    local width = math.min(a.max, a.perRow) * (a.size + a.spacing) - a.spacing
    p.Debuffs:ClearAllPoints()
    p.Debuffs:SetSize(math.max(1, width), rows * (a.size + a.spacing) - a.spacing)
    p.Debuffs:SetPoint("BOTTOM", p, "CENTER", 0, g.auras)
    local slots = UF.AuraSlots(a.max, a.size, a.perRow, a.spacing, "RIGHT", true)
    for i = 1, a.max do
        local b = UF.AuraButton(p.Debuffs, i)
        b:SetSize(a.size, a.size)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", p.Debuffs, "BOTTOMLEFT", slots[i][1], slots[i][2])
        UF.StyleAuraButton(b, d)
    end
    for i = a.max + 1, #(p.Debuffs.buttons or {}) do p.Debuffs.buttons[i]:Hide() end
    -- buffs: a short row left of the bar, growing left
    local bspec = { size = a.buffSize, spacing = a.spacing, max = a.buffMax, perRow = a.buffMax, zoom = a.zoom,
                    border = a.border, count = a.count, duration = a.duration, swipe = a.swipe, tooltips = false }
    p.buffSpec = bspec
    p.Buffs:ClearAllPoints()
    p.Buffs:SetSize(math.max(1, a.buffMax * (a.buffSize + a.spacing) - a.spacing), a.buffSize)
    p.Buffs:SetPoint("RIGHT", p.Health, "LEFT", -(a.spacing + 2 + (s.icons.markerPos == "LEFT" and s.icons.markerSize + 4 or 0)), 0)
    local bslots = UF.AuraSlots(a.buffMax, a.buffSize, a.buffMax, a.spacing, "LEFT", false)
    for i = 1, a.buffMax do
        local b = UF.AuraButton(p.Buffs, i)
        b:SetSize(a.buffSize, a.buffSize)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", p.Buffs, "TOPRIGHT", bslots[i][1], bslots[i][2])
        UF.StyleAuraButton(b, bspec)
    end
    for i = a.buffMax + 1, #(p.Buffs.buttons or {}) do p.Buffs.buttons[i]:Hide() end
end

local function layoutTarget(p, s)
    local size = math.max(8, s.height + 4)
    ns.Icons:Apply(p.ArrowL, "arrow-right", size)
    ns.Icons:Apply(p.ArrowR, "arrow-left", size)
    p.ArrowL:ClearAllPoints()
    p.ArrowL:SetPoint("RIGHT", p.Health, "LEFT", -2, 0)
    p.ArrowR:ClearAllPoints()
    p.ArrowR:SetPoint("LEFT", p.Health, "RIGHT", 2, 0)
    local r, g, b = M:Color("target")
    p.ArrowL:SetVertexColor(r, g, b); p.ArrowR:SetVertexColor(r, g, b)
    local effect = M.db.target.effect
    local spec = { style = effect == "border" and "solid" or "glow", size = effect == "border" and 1 or 2,
                   color = { r = r, g = g, b = b, a = 1 } }
    Skin:BorderSpec(p.Glow, spec, "accent.primary")
    p.FocusMark:ClearAllPoints()
    p.FocusMark:SetPoint("TOPLEFT", p.Health, "TOPLEFT")
    p.FocusMark:SetPoint("BOTTOMLEFT", p.Health, "BOTTOMLEFT")
    p.FocusMark:SetWidth(3)
    p.FocusMark:SetVertexColor(M:Color("focus"))
    local hr, hg, hb = M:Color("hover")
    p.Hover:SetVertexColor(hr, hg, hb, M.db.hover.alpha)
end

local function layoutBar(p, s, kind)
    local h = p.Health
    h:ClearAllPoints()
    h:SetPoint("CENTER", p, "CENTER", 0, 0)
    h:SetSize(s.width, s.height)
    local texture = M:BarTexture(kind)
    h:SetStatusBarTexture(texture)
    h:SetReverseFill(s.reverse and true or false)
    h.bg:SetTexture(texture)
    Skin:Backdrop(h, s.background, "bg.sunken")
    Skin:BorderSpec(h, s.border, "border.black")
    local fill = h:GetStatusBarTexture()
    p.Shade:ClearAllPoints()
    p.Shade:SetAllPoints(fill)
    p.Shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, s.gradient or 0), CreateColor(0, 0, 0, 0))
    p.Shade:SetShown((s.gradient or 0) > 0)
    p.Execute:ClearAllPoints()
    p.Execute:SetAllPoints(fill)
    p.Execute:SetVertexColor(M:Color("execute"))
    -- absorbs grow from the fill edge; the bar clips what spills over
    local edge = s.reverse and "LEFT" or "RIGHT"
    local away = s.reverse and "RIGHT" or "LEFT"
    p.Absorb:ClearAllPoints()
    p.Absorb:SetPoint("TOP" .. away, fill, "TOP" .. edge)
    p.Absorb:SetPoint("BOTTOM" .. away, fill, "BOTTOM" .. edge)
    p.Absorb:SetWidth(s.width)
    p.Absorb:SetReverseFill(s.reverse and true or false)
    p.Absorb:SetStatusBarTexture(Media:Bar("FineStripes"))
    p.Absorb:SetStatusBarColor(Theme:Color("text.primary"))
    p.Absorb:SetAlpha(0.55)
    -- execute threshold mark
    local ex = M.db.execute
    local x = M.ExecuteOffset(ex.threshold, s.width)
    p.ExecuteMark:ClearAllPoints()
    if s.reverse then p.ExecuteMark:SetPoint("TOPRIGHT", h, "TOPRIGHT", -x, 0)
    else p.ExecuteMark:SetPoint("TOPLEFT", h, "TOPLEFT", x, 0) end
    p.ExecuteMark:SetSize(1, s.height)
    p.ExecuteMark:SetVertexColor(1, 1, 1, 0.8)
    p.ExecuteMark:SetShown(ex.enabled and ex.marker and x > 0 and x < s.width)
end

-- Size, look and placement for a plate kind (out of the data path: on add, kind change and refresh).
function M:LayoutPlate(p, kind)
    local s = self:Style(kind)
    p.kind, p.unitKey = kind, "plate." .. kind
    local nameOnly = self:NameOnly(kind)
    p.nameOnly = nameOnly
    local c = self:Context()
    p:SetScale(c and c.scale > 0 and c.scale or 1)
    local g = M.Geometry(s, nameOnly)
    p.geometry = g
    layoutBar(p, s, kind)
    p.Health:SetShown(not nameOnly)
    p.Glow:SetFrameLevel(p.Health:GetFrameLevel() + 3)
    -- texts: on the bar, or alone when the plate is a name only
    local anchor = nameOnly and p or p.Health
    Skin:TextSpec(p.Name, s.name, "unit", s.nameColor == "white" and "text.primary" or nil)
    if nameOnly then
        p.Name:ClearAllPoints()
        p.Name:SetPoint("CENTER", p, "CENTER", s.name.x or 0, 0)
        p.Name:SetJustifyH("CENTER")
        p.Name:SetShown(true)
    else
        placeText(p.Name, anchor, s.name)
    end
    Skin:TextSpec(p.HealthText, s.health, "number", "text.primary")
    placeText(p.HealthText, p.Health, s.health)
    p.HealthText:SetShown(not nameOnly and s.health.show ~= false)
    Skin:TextSpec(p.Level, s.level, "number", "text.primary")
    placeText(p.Level, p.Health, s.level)
    p.Level:SetShown(not nameOnly and s.level.show ~= false)
    Skin:TextSpec(p.Info, s.info, "unit", "text.secondary")
    if nameOnly then
        p.Info:ClearAllPoints()
        p.Info:SetPoint("TOP", p.Name, "BOTTOM", 0, -1)
    else
        placeText(p.Info, p.Health, s.info)
    end
    p.Info:SetShown(s.infoTag ~= "" and s.info.show ~= false)
    p.Name:SetWidth(math.max(40, s.width + 20))
    -- compiled tags (Unit Frames' tag engine)
    p.compiled = { name = UF.CompileTags(s.nameTag, 0), health = UF.CompileTags(s.healthTag, 0),
                   level = UF.CompileTags(s.levelTag, 0), info = UF.CompileTags(s.infoTag, 0) }
    -- indicators
    local ic = s.icons
    p.Marker:ClearAllPoints()
    p.Marker:SetSize(ic.markerSize, ic.markerSize)
    p.Marker:SetPoint(g.marker[1], p, "CENTER", g.marker[2], g.marker[3])
    p.Elite:ClearAllPoints()
    p.Elite:SetPoint("LEFT", p.Health, "RIGHT", 2, 0)
    p.Quest:ClearAllPoints()
    p.Quest:SetSize(ic.size + 2, ic.size + 2)
    p.Quest:SetPoint("RIGHT", p.Name, "LEFT", 0, 0)
    p.Quest:SetAtlas("QuestNormal")
    self:StyleForces(p.Forces)
    p.Forces:ClearAllPoints()
    p.Forces:SetPoint("LEFT", p.Health, "RIGHT", ic.elite and (ic.size + 4) or 4, 0)
    layoutTarget(p, s)
    -- cast bar (the S9 engine, settings from this kind)
    local cast = p.Cast
    cast.key = "plate." .. kind
    cast:ClearAllPoints()
    cast:SetPoint("TOP", p.Health, "BOTTOM", 0, g.cast)
    CB:LayoutBar(cast, s.width, s.cast.height)
    if not s.cast.enabled or nameOnly then CB:StopSample(cast); cast.active = nil; cast:Hide() end
    -- class resource under the cast bar
    local cp = p.ClassPower
    cp:ClearAllPoints()
    cp:SetSize(s.width, 4)
    cp:SetPoint("TOP", p.Health, "BOTTOM", 0, g.cast - (s.cast.enabled and s.cast.height + 2 or 0))
    layoutAuras(p, s, g)
    p.layoutDone = true
end
