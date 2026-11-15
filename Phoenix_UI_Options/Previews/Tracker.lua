local _, ns = ...
local L, P, Skin, Media = ns.L, ns.Previews, ns.Skin, ns.Media

-- The viewer or custom bar picked in the scope bar with sample cooldowns, buffs or bars, laid out by the same grid
-- code as the real items (Tracker M.Grid: size, per row, rows, row size step, spacing, growth, wrap, centre) and
-- styled the same way (icon crop, ring or square, border, timer, stacks, keybinds, desaturation, proc and ready glows).
-- Each sample: icon, timer text ("" = ready), stacks or charges, proc.
local SAMPLES = {
    essential = { { 1, "", "", true }, { 2, "8" }, { 3, "" }, { 6, "24", "2" }, { 5, "" }, { 7, "1:12" }, { 4, "" },
        { 9, "" }, { 10, "3" }, { 11, "" } },
    utility = { { 9, "" }, { 10, "41" }, { 11, "" }, { 12, "2:30" }, { 8, "" }, { 4, "" }, { 2, "" }, { 7, "12" } },
    buffs = { { 10, "12", "3" }, { 9, "6" }, { 4, "18" }, { 6, "3", "5" }, { 2, "9" } },
    custom = { { 11, "", "", true }, { 12, "1:40" }, { 4, "" }, { 8, "15", "2" } },
}
local MAX_ICONS = 10
local BARS = {
    { icon = 10, name = L.PREVIEW_TRACKER_BUFF_1, value = 0.82, time = "14.2" },
    { icon = 6, name = L.PREVIEW_TRACKER_BUFF_2, value = 0.46, time = "6.8", count = "3" },
    { icon = 9, name = L.PREVIEW_TRACKER_BUFF_3, value = 0.2, time = "2.1" },
}
local BAR_W, BAR_H = 260, 22

local function makeIcon(parent, size, index)
    local a = P.Icon(parent, size, index)
    a.mask = a:CreateMaskTexture()
    a.mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
    a.mask:SetAllPoints(a.tex)
    a.ring = a:CreateTexture(nil, "OVERLAY")
    a.ring:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
    a.ring:SetPoint("TOPLEFT", -size * 0.18, size * 0.16)
    a.ring:SetPoint("BOTTOMRIGHT", size * 0.18, -size * 0.16)
    a.swipe = a:CreateTexture(nil, "ARTWORK", nil, 2)
    a.swipe:SetTexture(Media.textures.WHITE)
    a.swipe:SetVertexColor(0, 0, 0, 0.6)
    a.swipe:SetPoint("TOPLEFT"); a.swipe:SetPoint("TOPRIGHT")
    a.edge = CreateFrame("Frame", nil, a)
    a.edge:SetAllPoints()
    a.edge:SetFrameLevel(a:GetFrameLevel() + 2)
    a.timer = P.Text(a.edge)
    a.timer:SetPoint("CENTER")
    a.count = P.Text(a.edge)
    a.count:SetPoint("BOTTOMRIGHT", -2, 2)
    a.keybind = P.Text(a.edge)
    a.keybind:SetPoint("TOPRIGHT", -2, -2)
    return a
end

local function round(a, on)
    if on and not a.masked then a.tex:AddMaskTexture(a.mask) elseif not on and a.masked then a.tex:RemoveMaskTexture(a.mask) end
    a.masked = on
    a.ring:SetShown(on)
end

local function sampleFor(key)
    return SAMPLES[key] or SAMPLES.custom
end

local function drawBars(m, key, bars)
    local v = m:Viewer(key)
    local L_ = v.layout
    local ys = m.Stack(#BARS, { height = BAR_H, spacing = math.max(L_.spacing, 2) + 4, wrap = L_.wrap })
    for i, it in ipairs(bars.items) do
        local a = it.icon
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", 0, -ys[i])
        a:SetShown(L_.iconSide ~= "OFF")
        a:ClearAllPoints()
        it.bar:ClearAllPoints()
        if L_.iconSide == "RIGHT" then
            a:SetPoint("RIGHT")
            it.bar:SetPoint("RIGHT", a, "LEFT", -4, 0)
        else
            a:SetPoint("LEFT")
            local off = L_.iconSide == "OFF"
            it.bar:SetPoint("LEFT", off and it or a, off and "LEFT" or "RIGHT", off and 0 or 4, 0)
        end
        it.bar:SetReverseFill(L_.reverse and true or false)
        round(a, not (v.style and v.square))
        a.swipe:Hide()
        if v.style then
            m:StyleIcon(key, a.tex, a.edge, nil, a.count)
            m:StyleBar(key, it.bar, it.name, it.time)
        else
            Skin:IconZoom(a.tex, 0); Skin:BorderSpec(a.edge, { style = "none" })
            it.bar:SetStatusBarTexture(Media.textures.WHITE); it.bar:SetStatusBarColor(1, 0.5, 0.25)
            Skin:Text(it.name, "number", nil, 12); Skin:Text(it.time, "number", nil, 12)
        end
        a.count:SetText(it.def.count or "")
        it.name:SetText(it.def.name)
        it.time:SetText(it.def.time)
    end
end

local function glow(m, key, a, which, on, style)
    if on and style ~= "none" then
        local r, g, b = m:GlowColor(key, which == "proc" and "procColor" or "readyColor")
        ns.Glow:Show(a, style == "blizzard" and "button" or style, r, g, b, 1, which)
    else
        ns.Glow:Hide(a, which)
    end
end

local function drawIcons(stage, m, key, row)
    local v = m:Viewer(key)
    local list = sampleFor(key)
    local L_ = {}
    for k, val in pairs(v.layout) do L_[k] = val end
    local n = math.min(#list, MAX_ICONS)
    local pos, w, h = m.Grid(n, L_)
    -- fit the grid into the stage (the dock may be narrow); the real one is drawn at full size
    local room = math.max(200, (stage:GetWidth() or 0) > 0 and stage:GetWidth() - 24 or 560)
    local k = math.min(1, room / w, 96 / h)
    row:SetSize(w * k, h * k)
    for i, a in ipairs(row.items) do
        local p, d = pos[i], list[i]
        a:SetShown(p ~= nil and d ~= nil)
        if p and d then
            local size = p.size * k
            a:SetSize(size, size)
            a.ring:SetPoint("TOPLEFT", -size * 0.18, size * 0.16)
            a.ring:SetPoint("BOTTOMRIGHT", size * 0.18, -size * 0.16)
            a:ClearAllPoints()
            a:SetPoint("TOPLEFT", row, "TOPLEFT", p.x * k, -p.y * k)
            a.tex:SetTexture(P.SAMPLE.icons[(d[1] - 1) % #P.SAMPLE.icons + 1])
            round(a, not (v.style and v.square))
            if v.style then
                m:StyleIcon(key, a.tex, a.edge, a.timer, a.count, a.keybind)
            else
                Skin:IconZoom(a.tex, 0); Skin:BorderSpec(a.edge, { style = "none" })
                Skin:Text(a.timer, "number", nil, 16, "OUTLINE"); Skin:Text(a.count, "number", nil, 12, "OUTLINE")
            end
            local onCD = d[2] ~= ""
            a.swipe:SetShown(onCD)
            a.swipe:SetVertexColor(0, 0, 0, v.swipeAlpha or 0.6)
            a.swipe:SetHeight(p.size * k * (0.25 + (i % 3) * 0.22))
            a.tex:SetDesaturated(v.desaturate and onCD or false)
            a.timer:SetText(d[2])
            a.count:SetText(d[3] or "")
            a.keybind:SetText(v.keybinds and key ~= "buffs" and ("S" .. i) or "")
            glow(m, key, a, "proc", d[4], v.procGlow)
            glow(m, key, a, "ready", i == 3 and not onCD, v.readyGlow)
        end
    end
end

P:Register("tracker", {
    module = "Tracker",
    height = 128,
    build = function(stage, m)
        local rows = {}
        for key in pairs(SAMPLES) do
            local row = CreateFrame("Frame", nil, stage)
            row:SetPoint("CENTER", 0, 4)
            row.items = {}
            for i = 1, MAX_ICONS do row.items[i] = makeIcon(row, 36, i) end
            rows[key] = row
        end
        local bars = CreateFrame("Frame", nil, stage)
        bars:SetSize(BAR_W + BAR_H + 4, #BARS * (BAR_H + 6))
        bars:SetPoint("CENTER", 0, 2)
        bars.items = {}
        for i, def in ipairs(BARS) do
            local it = CreateFrame("Frame", nil, bars)
            it:SetSize(BAR_W + BAR_H + 4, BAR_H)
            it.icon = makeIcon(it, BAR_H, def.icon)
            it.bar = P.Bar(it, def.value, BAR_W, BAR_H - 4)
            it.name = P.Text(it.bar)
            it.name:SetPoint("LEFT", 6, 0)
            it.time = P.Text(it.bar)
            it.time:SetPoint("RIGHT", -6, 0)
            it.def = def
            bars.items[i] = it
        end
        return function(_, unit)
            local key = m.KIND[unit] and unit or "essential"
            local rowKey = SAMPLES[key] and key or "custom"
            for k, row in pairs(rows) do row:SetShown(k == rowKey and key ~= "bars") end
            bars:SetShown(key == "bars")
            if key == "bars" then return drawBars(m, key, bars) end
            drawIcons(stage, m, key, rows[rowKey])
        end
    end,
})
