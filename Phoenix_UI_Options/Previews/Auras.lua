local _, ns = ...
local P = ns.Previews

-- Buffs and debuffs with durations and stacks, styled by Auras.
local AURAS = {
    { icon = 10, duration = "58m" }, { icon = 9, duration = "14m" }, { icon = 4, duration = "2m" },
    { icon = 6, duration = "28s", count = "2" }, { icon = 12, duration = "" },
    { icon = 8, duration = "11s", debuff = true }, { icon = 5, duration = "4s", count = "5", debuff = true },
}
local SIZE, GAP, SCALE = 32, 8, 1.2

P:Register("auras", {
    module = "Auras",
    height = 100,
    build = function(stage, m)
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
        return function()
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
    end,
})
