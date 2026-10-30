local _, ns = ...
local Media = ns.Media
local M = ns.modules.GroupFrames
local UF = ns.modules.UnitFrames

--[[ Indicators (t169): up to six placeable aura indicators per layout profile, on top of the fixed HoT corners /
    debuff row. Each one picks what it tracks (a filter string, never aura data: 12.x keeps spell IDs secret in
    combat), where it sits on a 3x3 grid of the health bar plus a nudge, how it grows, how many it shows and how it
    looks: the aura's icon, or a flat square in a fixed colour or in the debuff's dispel colour (the colour comes
    from the game's dispel curve and only ever reaches SetVertexColor). The same code draws the live buttons, the
    Test frames and the options preview. ]]

M.INDICATOR_KINDS = {
    hots = { filter = "HELPFUL|PLAYER|RAID_IN_COMBAT", kind = "buffs", sample = "buffs" },
    raidbuffs = { filter = "HELPFUL|RAID", kind = "buffs", sample = "buffs" },
    externals = { filter = "HELPFUL|EXTERNAL_DEFENSIVE", kind = "buffs", sample = "defensive" },
    defensives = { filter = "HELPFUL|BIG_DEFENSIVE", kind = "buffs", sample = "defensive" },
    dispellable = { filter = "HARMFUL|RAID_PLAYER_DISPELLABLE", kind = "debuffs", sample = "debuffs" },
    mydispels = { filter = "HARMFUL|RAID", kind = "debuffs", sample = "debuffs" },
    cc = { filter = "HARMFUL|CROWD_CONTROL", kind = "debuffs", sample = "debuffs" },
    debuffs = { filter = "HARMFUL", kind = "debuffs", sample = "debuffs" },
}
M.INDICATOR_POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local STEP = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

-- inner edge offset so a corner indicator sits 1 px inside the bar
local function inset(point)
    return (point:find("LEFT") and 1 or point:find("RIGHT") and -1 or 0), (point:find("TOP") and -1 or point:find("BOTTOM") and 1 or 0)
end
M.IndicatorInset = inset

-- pure: where button i of an indicator goes (point, x, y) relative to its container
function M.IndicatorOffset(ind, i)
    local dx, dy = inset(ind.point)
    local s = STEP[ind.grow] or STEP.LEFT
    local d = (i - 1) * (ind.size + (ind.spacing or 1))
    return ind.point, dx + (ind.x or 0) + s[1] * d, dy + (ind.y or 0) + s[2] * d
end

local function list(p)
    p.indicators = p.indicators or M.DefaultIndicators()
    return p.indicators
end

function M:LayoutIndicators(b, p)
    local a = p.auras
    b.Indicators = b.Indicators or {}
    for i, ind in ipairs(list(p)) do
        local c = b.Indicators[i]
        if not c then
            c = CreateFrame("Frame", nil, b)
            c.key, c.kind = b.unitKey, "buffs"
            c:SetAllPoints(b.Health)
            c:SetFrameLevel(b:GetFrameLevel() + 6)
            b.Indicators[i] = c
        end
        local def = M.INDICATOR_KINDS[ind.kind]
        c.ind, c.def = ind, def
        local n = def and math.max(1, math.min(8, ind.max or 1)) or 0
        c:SetShown(n > 0)
        for k = 1, n do
            local btn = UF.AuraButton(c, k)
            btn:SetSize(ind.size, ind.size)
            btn:ClearAllPoints()
            local pt, x, y = M.IndicatorOffset(ind, k)
            btn:SetPoint(pt, c, pt, x, y)
            UF.StyleAuraButton(btn, a)
            M.IndicatorArt(btn, i, ind)
        end
        for k = n + 1, #(c.buttons or {}) do c.buttons[k]:Hide() end
        c.max = n
    end
end

-- v8.1 slot frames (THEME_API §7.04, GroupFrames.indicator1..6) around icon indicators; squares and dispel
-- colour keep the plain look (their colour is the message, and a custom colour is the colour-blind fallback)
function M.IndicatorArt(btn, i, ind)
    local Art = ns.Art
    if not (Art and Art.DressSlot) then return end
    if ind.style == "icon" or ind.style == nil then
        Art:DressSlot(btn, "GroupFrames.indicator" .. math.min(6, i), { slot = "frame", out = 2, scale = 0.75, level = 2 })
    else
        Art:Undress(btn, "frame")
    end
end

-- the look of one shown button: icon, a fixed-colour square or a dispel-colour square
local function paint(btn, ind)
    btn.Dispel:ClearAllPoints()
    if ind.style == "dispel" then
        btn.Icon:SetAlpha(0)
        btn.Dispel:SetAllPoints(btn)
    else
        btn.Dispel:SetPoint("TOPLEFT", -1, 1)
        btn.Dispel:SetPoint("BOTTOMRIGHT", 1, -1)
        if ind.style == "square" then
            -- the greyscale aura_tint chip on the phoenix-wings look, else a flat square; tinted by the chosen colour
            btn.artTint = ns.Art and ns.Art.PaintSlot and ns.Art:PaintSlot(btn.Icon, "GroupFrames.indicator.tint")
            if not btn.artTint then btn.Icon:SetTexture(Media.textures.WHITE) end
            local c = ind.color
            btn.Icon:SetVertexColor(c.r, c.g, c.b, c.a or 1)
            btn.Dispel:Hide()
        else
            if btn.artTint then btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); btn.artTint = nil end
            btn.Icon:SetVertexColor(1, 1, 1, 1)
        end
        btn.Icon:SetAlpha(1)
    end
end

function M:FillIndicators(b, p)
    if not b.Indicators then return end
    local a = p.auras
    local look = setmetatable({ dispel = true }, { __index = a })
    local s = b.sample or {}
    for _, c in ipairs(b.Indicators) do
        local ind, def = c.ind, c.def
        if def and c:IsShown() then
            local samples = s[def.sample]
            if def.sample == "defensive" then samples = s.defensive and { s.defensive } or nil end
            local style = ind.style == "dispel" and look or a
            local shown = M.FillAuras(c, b, def.filter, ind.style == "dispel" and "debuffs" or def.kind, style, samples)
            for k = 1, shown do paint(c.buttons[k], ind) end
        end
    end
end
