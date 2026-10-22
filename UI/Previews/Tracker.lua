local _, ns = ...
local L, P, Skin, Media = ns.L, ns.Previews, ns.Skin, ns.Media

-- The viewer picked in the scope bar with sample cooldowns, buffs or bars, styled by Tracker the same way
-- the real Cooldown Manager items are (icon crop, ring or square, border, timer, stacks, bar texts).
local ICONS = {
    essential = { size = 40, n = 7, items = { { 1, "" }, { 2, "8" }, { 3, "" }, { 6, "24", "2" }, { 5, "" }, { 7, "1:12" }, { 4, "" } } },
    utility = { size = 32, n = 6, items = { { 9, "" }, { 10, "41" }, { 11, "" }, { 12, "2:30" }, { 8, "" }, { 4, "" } } },
    buffs = { size = 34, n = 5, items = { { 10, "12", "3" }, { 9, "6" }, { 4, "18" }, { 6, "3", "5" }, { 2, "9" } } },
}
local BARS = {
    { icon = 10, name = L.PREVIEW_TRACKER_BUFF_1, value = 0.82, time = "14.2" },
    { icon = 6, name = L.PREVIEW_TRACKER_BUFF_2, value = 0.46, time = "6.8", count = "3" },
    { icon = 9, name = L.PREVIEW_TRACKER_BUFF_3, value = 0.2, time = "2.1" },
}
local GAP, BAR_W, BAR_H = 6, 260, 22

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
    return a
end

local function round(a, on)
    if on and not a.masked then a.tex:AddMaskTexture(a.mask) elseif not on and a.masked then a.tex:RemoveMaskTexture(a.mask) end
    a.masked = on
    a.ring:SetShown(on)
end

P:Register("tracker", {
    module = "Tracker",
    height = 118,
    build = function(stage, m)
        local rows = {}
        for key, def in pairs(ICONS) do
            local row = CreateFrame("Frame", nil, stage)
            row:SetSize(def.n * (def.size + GAP) - GAP, def.size)
            row:SetPoint("CENTER", 0, 4)
            row.items = {}
            for i, it in ipairs(def.items) do
                local a = makeIcon(row, def.size, it[1])
                a:SetPoint("LEFT", (i - 1) * (def.size + GAP), 0)
                a.def = it
                row.items[i] = a
            end
            rows[key] = row
        end
        local bars = CreateFrame("Frame", nil, stage)
        bars:SetSize(BAR_W + BAR_H + 4, #BARS * (BAR_H + 6))
        bars:SetPoint("CENTER", 0, 2)
        bars.items = {}
        for i, def in ipairs(BARS) do
            local it = CreateFrame("Frame", nil, bars)
            it:SetSize(BAR_W + BAR_H + 4, BAR_H)
            it:SetPoint("TOPLEFT", 0, -(i - 1) * (BAR_H + 6))
            it.icon = makeIcon(it, BAR_H, def.icon)
            it.icon:SetPoint("LEFT")
            it.bar = P.Bar(it, def.value, BAR_W, BAR_H - 4)
            it.bar:SetPoint("LEFT", it.icon, "RIGHT", 4, 0)
            it.name = P.Text(it.bar)
            it.name:SetPoint("LEFT", 6, 0)
            it.time = P.Text(it.bar)
            it.time:SetPoint("RIGHT", -6, 0)
            it.def = def
            bars.items[i] = it
        end
        return function(_, unit)
            local key = (unit == "bars" or ICONS[unit]) and unit or "essential"
            local v = m:Viewer(key)
            for k, row in pairs(rows) do row:SetShown(k == key) end
            bars:SetShown(key == "bars")
            if key == "bars" then
                for _, it in ipairs(bars.items) do
                    local a = it.icon
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
                return
            end
            local size = ICONS[key].size
            for i, a in ipairs(rows[key].items) do
                round(a, not (v.style and v.square))
                if v.style then
                    m:StyleIcon(key, a.tex, a.edge, a.timer, a.count)
                else
                    Skin:IconZoom(a.tex, 0); Skin:BorderSpec(a.edge, { style = "none" })
                    Skin:Text(a.timer, "number", nil, 16, "OUTLINE"); Skin:Text(a.count, "number", nil, 12, "OUTLINE")
                end
                local t = a.def[2]
                a.swipe:SetShown(t ~= "")
                a.swipe:SetHeight(size * (0.25 + (i % 3) * 0.22))
                a.timer:SetText(t)
                a.count:SetText(a.def[3] or "")
            end
        end
    end,
})
