local _, ns = ...
local Skin, Media, Theme = ns.Skin, ns.Media, ns.Theme
local M = ns.modules.CastBars

--[[ One cast bar: a box holding the status bar, its icon (inside or detached), texts and overlays.

    f            the box (plain Frame): sized and placed by Spawn.lua, or by the preview
    f.Bar        StatusBar; its fill texture carries the state colour (SetVertexColorFromBoolean for secrets)
    f.Shade      a dark gradient over the fill ("gradient"), so a secret colour still gets shading
    f.Spark      a bright line at the fill edge (anchored to the fill texture: no maths on the value)
    f.Icon       icon frame (tex + border); f.Shield a lock over it while the cast cannot be interrupted
    f.Name / f.Time / f.Target   spell name, timer, spell target
    f.Latency    player latency zone; f.Ticks channel tick lines; f.Stages empower stage marks
    f.Kick       kick-ready tick: a clear StatusBar spanning the part of the bar still to fill, min/max = cast
                 time left, value = interrupt cooldown left; the tick rides its fill edge (two secret numbers in,
                 no comparison)
    f.Glow       important cast / cast at me highlight (alpha from booleans)
    f.State      full-bar overlay for the interrupted / succeeded flash ]]

local WHITE = Media.textures.WHITE

local function tex(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    t:SetTexture(WHITE)
    return t
end

function M:BuildBar(parent, key, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", opts.name, parent)
    f.key = key
    f:SetSize(200, 18)
    local b = CreateFrame("StatusBar", nil, f)
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    f.Bar = b
    f.Shade = tex(b, "ARTWORK", 2)
    f.Shade:SetVertexColor(1, 1, 1, 1)
    f.Spark = tex(b, "OVERLAY", 3)
    f.Spark:SetBlendMode("ADD")
    f.Latency = tex(b, "ARTWORK", 1)
    f.Latency:Hide()
    f.Ticks, f.Stages = {}, {}
    f.State = tex(b, "OVERLAY", 1)
    f.State:SetAllPoints(b)
    f.State:Hide()
    -- texts sit on their own layer frame so the border never covers them
    local texts = CreateFrame("Frame", nil, f)
    texts:SetAllPoints(b)
    texts:SetFrameLevel(b:GetFrameLevel() + 3)
    f.Texts = texts
    f.Name = texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Name:SetWordWrap(false)
    f.Time = texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Target = texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    -- icon
    local icon = CreateFrame("Frame", nil, f)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()
    f.Icon = icon
    f.Shield = icon:CreateTexture(nil, "OVERLAY")
    f.Shield:SetPoint("CENTER", icon, "BOTTOMRIGHT", -2, 2)
    -- kick-ready tick
    local kick = CreateFrame("StatusBar", nil, b)
    kick:SetStatusBarTexture(WHITE)
    kick:GetStatusBarTexture():SetAlpha(0)
    kick:SetMinMaxValues(0, 1)
    kick:SetFrameLevel(b:GetFrameLevel() + 1)
    kick.ready = CreateFrame("Frame", nil, kick)   -- alpha: interrupt off cooldown -> hidden
    kick.ready:SetAllPoints()
    kick.tick = tex(kick.ready, "OVERLAY", 4)
    kick.tick:SetWidth(2)
    kick:Hide()
    f.Kick = kick
    -- highlight for important casts / casts at me
    local glow = CreateFrame("Frame", nil, f)
    glow:SetAllPoints(b)
    glow:SetFrameLevel(b:GetFrameLevel() + 2)
    glow.important = CreateFrame("Frame", nil, glow)
    glow.important:SetAllPoints()
    glow.targeted = CreateFrame("Frame", nil, glow)
    glow.targeted:SetAllPoints()
    glow:Hide()
    f.Glow = glow
    f.preview = opts.preview
    return f
end

---------------------------------------------------------------- layout
local function placeText(fs, parent, spec)
    Skin:Place(fs, parent, spec)
    fs:SetShown(spec.show ~= false)
end

local function sparkColor(b)
    if type(b.sparkColor) == "table" then return Skin:SpecColor(b.sparkColor) end
    return 1, 1, 1, 0.9
end

local function layoutIcon(f, b, g)
    local icon = f.Icon
    if not g.icon then icon:Hide(); return end
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", g.icon[1], -g.icon[2])
    icon:SetSize(g.icon[3], g.icon[3])
    Skin:IconZoom(icon.tex, b.iconZoom)
    Skin:BorderSpec(icon, b.border, "border.black")
    ns.Icons:Apply(f.Shield, "lock", math.max(10, math.floor(g.icon[3] * 0.5)))
    f.Shield:SetVertexColor(Theme:Color("text.primary"))
    icon:Show()
end

-- Size, look and text placement of a bar for its settings (out of the data path; called on spawn and refresh).
function M:LayoutBar(f, w, h)
    local b = self:Bar(f.key)
    f:SetSize(w, h)
    f.w, f.h = w, h
    local g = M.Geometry(b, w, h)
    local bar = f.Bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", g.bar[1], -g.bar[2])
    bar:SetSize(g.bar[3], g.bar[4])
    f.barW, f.barH = g.bar[3], g.bar[4]
    bar:SetStatusBarTexture(b.texture ~= "" and Media:Bar(b.texture) or Theme:Bar())
    bar:SetReverseFill(b.reverse and true or false)
    Skin:Backdrop(bar, b.background, "bg.sunken")
    Skin:BorderSpec(bar, b.border, "border.black")
    local fill = bar:GetStatusBarTexture()
    -- shade and spark follow the fill texture's edges
    f.Shade:ClearAllPoints()
    f.Shade:SetAllPoints(fill)
    f.Shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, b.gradient or 0), CreateColor(0, 0, 0, 0))
    f.Shade:SetShown((b.gradient or 0) > 0)
    f.Spark:ClearAllPoints()
    local edge = b.reverse and "LEFT" or "RIGHT"
    f.Spark:SetPoint("TOP", fill, "TOP" .. edge, 0, 0)
    f.Spark:SetPoint("BOTTOM", fill, "BOTTOM" .. edge, 0, 0)
    f.Spark:SetWidth(2)
    f.Spark:SetVertexColor(sparkColor(b))
    f.sparkOn = b.spark
    layoutIcon(f, b, g)
    -- texts
    Skin:TextSpec(f.Name, b.text, "body", "text.primary")
    Skin:TextSpec(f.Time, b.time, "number", "text.primary")
    Skin:TextSpec(f.Target, b.target, "body", "text.secondary")
    placeText(f.Name, f.Texts, b.text)
    placeText(f.Time, f.Texts, b.time)
    placeText(f.Target, f.Texts, b.target)
    f.Name:SetWidth(math.max(20, g.bar[3] * ((b.time.show ~= false and b.timeFormat ~= "none") and 0.7 or 0.95)))
    f.Time:SetShown(b.time.show ~= false and b.timeFormat ~= "none")
    -- overlays
    f.Latency:SetVertexColor(self:Color("latency"))
    f.Latency:SetAlpha(0.5)
    f.Kick.tick:SetVertexColor(self:Color("kick"))
    f.Kick.tick:SetHeight(g.bar[4])
    Skin:BorderSpec(f.Glow.important, { style = "glow", size = 2, color = false }, "state.warning")
    Skin:BorderSpec(f.Glow.targeted, { style = "pixel", size = 1, color = false }, "state.danger")
    for _, t in ipairs(f.Ticks) do t:Hide() end
    for _, t in ipairs(f.Stages) do t:Hide() end
    f.layoutDone = true
end

-- n thin marks at x offsets (from the bar's start, honouring reverse fill) in a pool.
function M:Marks(f, pool, offsets, token, alpha)
    local b = self:Bar(f.key)
    local r, g, bl = self:Color(token)
    for i, x in ipairs(offsets) do
        local t = pool[i]
        if not t then t = tex(f.Bar, "OVERLAY", 2); pool[i] = t end
        t:ClearAllPoints()
        if b.reverse then t:SetPoint("TOPRIGHT", f.Bar, "TOPRIGHT", -x, 0) else t:SetPoint("TOPLEFT", f.Bar, "TOPLEFT", x, 0) end
        t:SetSize(1, f.barH or f.Bar:GetHeight())
        t:SetVertexColor(r, g, bl, alpha or 0.7)
        t:Show()
    end
    for i = #offsets + 1, #pool do pool[i]:Hide() end
end

-- The latency zone: a share of the bar at the end a cast finishes on (the start for channels).
function M:ShowLatency(f, share, channel)
    local t = f.Latency
    if not share or share <= 0 then t:Hide(); return end
    local b = self:Bar(f.key)
    local atEnd = not channel
    if b.reverse then atEnd = not atEnd end
    t:ClearAllPoints()
    t:SetPoint("TOP", f.Bar, "TOP")
    t:SetPoint("BOTTOM", f.Bar, "BOTTOM")
    t:SetPoint(atEnd and "RIGHT" or "LEFT", f.Bar, atEnd and "RIGHT" or "LEFT")
    t:SetWidth(math.max(1, (f.barW or f.Bar:GetWidth()) * share))
    t:Show()
end

--[[ The kick tick's span: for a cast the part of the bar still to fill (fill edge -> bar end), for a channel the
    part still filled (bar start -> fill edge, filling back towards the start). ]]
function M:LayoutKick(f, channel)
    local k, b = f.Kick, self:Bar(f.key)
    local fill = f.Bar:GetStatusBarTexture()
    local startSide, endSide = "LEFT", "RIGHT"
    if b.reverse then startSide, endSide = "RIGHT", "LEFT" end
    k:ClearAllPoints()
    if channel then
        k:SetPoint("TOP" .. startSide, f.Bar, "TOP" .. startSide)
        k:SetPoint("BOTTOM" .. endSide, fill, "BOTTOM" .. endSide)
    else
        k:SetPoint("TOP" .. startSide, fill, "TOP" .. endSide)
        k:SetPoint("BOTTOM" .. endSide, f.Bar, "BOTTOM" .. endSide)
    end
    -- the tick rides the clear fill's far edge
    local reverse = (channel and not b.reverse) or (not channel and b.reverse)
    k:SetReverseFill(reverse)
    local edge = reverse and "LEFT" or "RIGHT"
    k.tick:ClearAllPoints()
    k.tick:SetPoint("TOP", k:GetStatusBarTexture(), "TOP" .. edge)
    k.tick:SetPoint("BOTTOM", k:GetStatusBarTexture(), "BOTTOM" .. edge)
end
