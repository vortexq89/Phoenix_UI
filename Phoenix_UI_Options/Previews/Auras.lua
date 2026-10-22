local _, ns = ...
local P = ns.Previews

--[[ Phoenix mode: the header picked in the scope bar drawn with Auras' own button code (M:Dress / Style /
    ShowSample, used by the real headers and the Test auras) at its grid settings - growth, wrap, rows, spacing,
    shape, type borders, timers coloured by time left. Nothing reads a unit. Blizzard mode: the 2.0 skin on plain
    icons (buffs and debuffs in one row). State: expiring (every timer under the precise threshold). ]]
local AURAS = {
    { icon = 10, duration = "58m" }, { icon = 9, duration = "14m" }, { icon = 4, duration = "2m" },
    { icon = 6, duration = "28s", count = "2" }, { icon = 12, duration = "" },
    { icon = 8, duration = "11s", debuff = true }, { icon = 5, duration = "4s", count = "5", debuff = true },
}
local SIZE, GAP, SCALE = 32, 8, 1.2
local MAX_W, MAX_H = 380, 120

local function legacy(stage, m)
    local row = CreateFrame("Frame", nil, stage)
    row:SetSize(#AURAS * (SIZE + GAP), SIZE + 16)
    row:SetScale(SCALE)
    row:SetPoint("CENTER", 0, 4)
    local items = {}
    for i, def in ipairs(AURAS) do
        local a = P.Icon(row, SIZE, def.icon)
        a:SetPoint("TOPLEFT", (i - 1) * (SIZE + GAP) + (def.debuff and 12 or 0), 0)
        a.edge = CreateFrame("Frame", nil, a)
        a.edge:SetAllPoints()
        a.duration = P.Text(row)
        a.duration:SetPoint("TOP", a, "BOTTOM", 0, -3)
        a.count = P.Text(a)
        a.count:SetPoint("BOTTOMRIGHT", -1, 2)
        a.def = def
        items[i] = a
    end
    return row, function()
        for _, a in ipairs(items) do
            if m.db.style then
                m:StyleAura(a.tex, a.edge, a.duration, a.count)
            else
                a.tex:SetTexCoord(0, 1, 0, 1)
                ns.Skin:BorderSpec(a.edge, { style = "none" })
                ns.Skin:Text(a.duration, "number", nil, 11); ns.Skin:Text(a.count, "number", nil, 12)
            end
            if a.def.debuff then ns.Skin:SetBorderColor(a.edge, "state.danger") end
            a.duration:SetText(a.def.duration)
            a.count:SetText(a.def.count or "")
        end
    end
end

P:Register("auras", {
    module = "Auras",
    height = 140,
    states = { { key = "expiring", label = "PREVIEW_STATE_EXPIRING", icon = "clock" } },
    build = function(stage, m)
        local old, drawOld = legacy(stage, m)
        local grid = CreateFrame("Frame", nil, stage)
        local pool = {}
        return function(view, scope)
            local phoenix = m.db.mode == "phoenix" and m.Dress ~= nil
            old:SetShown(not phoenix)
            grid:SetShown(phoenix)
            if not phoenix then drawOld(); return end
            local key = (scope == "debuffs") and "debuffs" or "buffs"
            local h = m:Header(key)
            local list = m.SAMPLES[key]
            -- show up to two rows of the samples, repeated, at the header's own grid
            local perRow = math.max(1, math.min(h.perRow, 8))
            local vh = { size = h.size, perRow = perRow, rows = math.min(h.rows, 2), hSpacing = h.hSpacing,
                vSpacing = h.vSpacing, growth = h.growth, wrap = h.wrap }
            local n = math.min(perRow * vh.rows, #list * 2)
            local w, ht = m.HolderSize(vh)
            local scale = math.min(1.25, MAX_W / math.max(1, w), MAX_H / math.max(1, ht))
            grid:SetScale(scale)
            grid:SetSize(w, ht)
            grid:ClearAllPoints()
            grid:SetPoint("CENTER", stage, "CENTER", 0, 0)
            local point = m.Layout(vh)
            for _, b in ipairs(pool) do b:Hide() end
            for i, off in ipairs(m.Slots(vh, n)) do
                local b = pool[i]
                if not b then
                    b = m:Dress(CreateFrame("Button", nil, grid), key)
                    b:EnableMouse(false)
                    pool[i] = b
                end
                b.kind = key
                m:Style(b)
                b:SetSize(h.size, m.Height(h))
                b:ClearAllPoints()
                b:SetPoint(point, grid, point, off[1], off[2])
                local s = list[(i - 1) % #list + 1]
                if view.states.expiring and s.total then
                    local copy = {}
                    for k, v in pairs(s) do copy[k] = v end
                    copy.left = math.min(s.left, math.max(1, m.db.precise - 1) + (i % 3) * 0.7)
                    s = copy
                end
                m:ShowSample(b, s, key)
                b:Show()
            end
        end
    end,
})
