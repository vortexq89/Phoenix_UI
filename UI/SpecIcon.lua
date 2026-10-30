local _, ns = ...
local Skin, Theme, Media = ns.Skin, ns.Theme, ns.Media

--[[ Spec icon styles (docs/METER_ICONS_ILVL.md §2). The icon is always the game's own spec icon (drawn by the
    client, nothing redistributed); Phoenix adds its own masks, rings, frames and effects on top, all original
    (tools/media/gen_spec_icons.py, MIT). One shared look: General > spec icon style; a site may override it (the
    damage meter does). ns.SpecIcon:Apply(tex, style, classFile) styles a texture in place and can be called again
    with another style at any time (every setting is live). ]]
local SI = {}
ns.SpecIcon = SI

local T = "Interface\\AddOns\\Phoenix_UI\\Media\\Textures\\"
local tx = Media.textures

-- key, label (locale key), and how it is drawn
SI.styles = {
    { key = "blizzard", label = "SPECICON_BLIZZARD" },                                  -- the game's icon, untouched
    { key = "zoomed", label = "SPECICON_ZOOMED", zoom = 0.08 },                         -- edge trimmed, no frame
    { key = "bordered", label = "SPECICON_BORDERED", zoom = 0.08, border = "theme" },   -- 1 px theme border
    { key = "outlined", label = "SPECICON_OUTLINED", zoom = 0.08, border = "class", size = 2 },
    { key = "round", label = "SPECICON_ROUND", zoom = 0.06, mask = tx.MASK_CIRCLE },
    { key = "ringed", label = "SPECICON_RINGED", zoom = 0.06, mask = tx.MASK_CIRCLE, ring = tx.RING_CIRCLE, ringColor = "class" },
    { key = "hex", label = "SPECICON_HEX", zoom = 0.06, mask = T .. "MaskSpecHex", ring = T .. "RingSpecHex", ringColor = "class" },
    { key = "diamond", label = "SPECICON_DIAMOND", zoom = 0.02, mask = T .. "MaskDiamond", ring = T .. "RingDiamond", ringColor = "class" },
    { key = "shield", label = "SPECICON_SHIELD", zoom = 0.06, mask = T .. "MaskShield", ring = T .. "RingShield", ringColor = "class" },
    { key = "octagon", label = "SPECICON_OCTAGON", zoom = 0.06, mask = T .. "MaskOctagon", ring = T .. "RingOctagon", ringColor = "class" },
    { key = "squircle", label = "SPECICON_SQUIRCLE", zoom = 0.06, mask = T .. "MaskSquircle", ring = T .. "RingSquircle",
      ringColor = "class" },
    { key = "glossy", label = "SPECICON_GLOSSY", zoom = 0.08, border = "black", gloss = true, shade = true },
    { key = "ember", label = "SPECICON_EMBER", zoom = 0.1, frame = T .. "FrameEmber", shade = true },
    { key = "mono", label = "SPECICON_MONO", zoom = 0.08, border = "theme", desaturate = true },
    { key = "tinted", label = "SPECICON_TINTED", zoom = 0.08, border = "class", desaturate = true, tint = true },
}
SI.byKey = {}
for _, s in ipairs(SI.styles) do SI.byKey[s.key] = s end
SI.DEFAULT = "zoomed"

-- {value,label} list for a select row; withGlobal adds "Follow General" first.
function SI.Values(withGlobal)
    local out = {}
    if withGlobal then out[1] = { value = "global", label = "SPECICON_GLOBAL" } end
    for _, s in ipairs(SI.styles) do out[#out + 1] = { value = s.key, label = s.label } end
    return out
end

-- The shared style (General), or a site's own when it is not "global".
function SI.Resolve(style)
    if style and style ~= "global" and SI.byKey[style] then return style end
    local g = ns.modules.General
    local key = g and g.db and g.db.specIconStyle
    return SI.byKey[key] and key or SI.DEFAULT
end

local state = setmetatable({}, { __mode = "k" })

local function colorOf(which, class)
    if which == "class" then
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b, 1 end
        -- One rule for every ring and class border: the player's class colour, and a neutral border when the
        -- class is unknown (never the accent, so a missing class can't read as a highlight).
        return Theme:Color("border.strong")
    elseif which == "black" then
        return 0, 0, 0, 1
    elseif which == "border" then
        return Theme:Color("border.strong")
    end
    return Theme:Color("accent.primary")
end

local function layer(st, parent, key, drawLayer, sub)
    if not st[key] then
        st[key] = parent:CreateTexture(nil, drawLayer, nil, sub)
        st[key]:SetAllPoints(st.tex)
    end
    return st[key]
end

function SI:Apply(tex, style, class)
    local s = SI.byKey[SI.Resolve(style)]
    local parent = tex:GetParent()
    local st = state[tex]
    if not st then
        st = { tex = tex }
        state[tex] = st
        st.edge = CreateFrame("Frame", nil, parent)
        st.edge:SetAllPoints(tex)
    end
    local z = s.zoom or 0
    tex:SetTexCoord(z, 1 - z, z, 1 - z)
    tex:SetDesaturated(s.desaturate and true or false)
    if s.tint then tex:SetVertexColor(colorOf("class", class)) else tex:SetVertexColor(1, 1, 1, 1) end
    -- mask + ring
    if s.mask then
        if not st.mask then st.mask = parent:CreateMaskTexture(nil, "ARTWORK"); st.mask:SetAllPoints(tex) end
        st.mask:SetTexture(s.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if not st.masked then tex:AddMaskTexture(st.mask); st.masked = true end
    elseif st.masked then
        tex:RemoveMaskTexture(st.mask); st.masked = false
    end
    if s.ring then
        local ring = layer(st, parent, "ring", "OVERLAY", 6)
        ring:SetTexture(s.ring)
        ring:SetVertexColor(colorOf(s.ringColor, class))
        ring:Show()
    elseif st.ring then st.ring:Hide() end
    -- square border
    if s.border then
        Skin:Border(st.edge, "border.subtle", s.size or 1)
        if s.border == "theme" then Skin:SetBorderColor(st.edge, "border.subtle")
        else Skin:SetBorderColor(st.edge, colorOf(s.border, class)) end
        st.edge:Show()
    else
        st.edge:Hide()
    end
    -- effects: gloss highlight, inner shade, ember frame
    if s.gloss then
        local g = layer(st, parent, "gloss", "OVERLAY", 5)
        g:SetTexture(T .. "IconGloss"); g:SetVertexColor(1, 1, 1, 0.9); g:Show()
    elseif st.gloss then st.gloss:Hide() end
    if s.shade then
        local sh = layer(st, parent, "shade", "OVERLAY", 4)
        sh:SetTexture(T .. "IconShade"); sh:SetVertexColor(0, 0, 0, 0.85); sh:Show()
    elseif st.shade then st.shade:Hide() end
    if s.frame then
        local f = layer(st, parent, "frame", "OVERLAY", 7)
        f:SetTexture(s.frame); f:SetVertexColor(Theme:Color("accent.primary")); f:Show()
    elseif st.frame then st.frame:Hide() end
end

-- Show / hide every extra piece with the icon.
function SI:SetShown(tex, shown)
    local st = state[tex]
    if not st then return end
    if not shown then
        for _, k in ipairs({ "ring", "gloss", "shade", "frame" }) do if st[k] then st[k]:Hide() end end
        st.edge:Hide()
    end
end

-- Settings gallery: every style on a sample spec icon, the current one outlined; click one to pick it.
local SAMPLES = { { 135810, "MAGE" }, { 135873, "PRIEST" }, { 461112, "HUNTER" }, { 132341, "WARRIOR" }, { 237542, "DRUID" } }
function SI.Strip(row, getStyle, setStyle)
    local W = ns.Widgets
    getStyle = getStyle or function() return SI.Resolve("global") end
    setStyle = setStyle or function(v)
        ns.DB:Set(ns.modules.General, "specIconStyle", v)
        ns.modules.General:OnSettingChanged("specIconStyle")
    end
    local h = CreateFrame("Frame", nil, row)
    local size, gap, perRow = 24, 4, 8
    h:SetSize(W.CONTROL_WIDTH, 2 * size + gap + 4)
    h.cells = {}
    for i, s in ipairs(SI.styles) do
        local b = CreateFrame("Button", nil, h)
        b:SetSize(size, size)
        local col, line = (i - 1) % perRow, math.floor((i - 1) / perRow)
        b:SetPoint("TOPRIGHT", -(perRow - 1 - col) * (size + gap), -line * (size + gap))
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        local sample = SAMPLES[(i - 1) % #SAMPLES + 1]
        b.icon:SetTexture(sample[1])
        b.class, b.key = sample[2], s.key
        b.mark = CreateFrame("Frame", nil, b)
        b.mark:SetPoint("TOPLEFT", -3, 3); b.mark:SetPoint("BOTTOMRIGHT", 3, -3)
        b:SetScript("OnClick", function() setStyle(s.key); h:SetValue() end)
        b:SetScript("OnEnter", function(self) W.ShowTooltip(self, ns.L[s.label]) end)
        b:SetScript("OnLeave", function() W.HideTooltip() end)
        h.cells[i] = b
    end
    function h:SetValue()
        local cur = getStyle()
        for _, b in ipairs(self.cells) do
            SI:Apply(b.icon, b.key, b.class)
            if b.key == cur then Skin:Border(b.mark, "accent.primary", 2); b.mark:Show() else b.mark:Hide() end
        end
    end
    ns.Events:Listen("PUI_SPECICON_STYLE", h, function() h:SetValue() end)
    h:SetValue()
    return h
end
