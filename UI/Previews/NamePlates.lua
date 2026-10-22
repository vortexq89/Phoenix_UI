local _, ns = ...
local L, P = ns.L, ns.Previews

-- Three sample plates (hostile, neutral, friendly) drawn by NamePlates' own style methods.
local SAMPLES = {
    { sample = "PREVIEW_MOB_HOSTILE", value = 0.72, token = "state.danger", forces = "+4" },
    { sample = "PREVIEW_MOB_NEUTRAL", value = 1, token = "state.warning" },
    { sample = "PREVIEW_MOB_FRIENDLY", value = 0.46, token = "state.success" },
}
local PLATE_W, PLATE_H, SCALE = 150, 12, 1.25

P:Register("nameplate", {
    module = "NamePlates",
    height = 110,
    states = {
        { key = "low", label = "PREVIEW_STATE_LOW", icon = "warning" },
        { key = "target", label = "PREVIEW_STATE_TARGET", icon = "nameplates" },
    },
    build = function(stage, m)
        local plates = {}
        for i, sample in ipairs(SAMPLES) do
            local holder = CreateFrame("Frame", nil, stage)
            holder:SetSize(PLATE_W, 40)
            holder:SetScale(SCALE)
            local bar = P.Bar(holder, sample.value, PLATE_W, PLATE_H)
            bar:SetPoint("BOTTOM", 0, 4)
            local name = P.Text(holder)
            name:SetPoint("BOTTOM", bar, "TOP", 0, 4)
            local health = P.Text(bar)
            local forces = P.Text(bar)
            forces:SetPoint("LEFT", bar, "RIGHT", 4, 0)
            plates[i] = { holder = holder, bar = bar, name = name, health = health, forces = forces, sample = sample }
        end
        return function(self)
            local w = self:GetWidth() / SCALE
            local db = m.db
            local st = self.states
            for i, p in ipairs(plates) do
                -- "targeted": the hostile plate is selected, the rest dim like unselected plates
                p.holder:SetScale(st.target and i == 1 and SCALE * 1.12 or SCALE)
                p.holder:SetAlpha(st.target and i ~= 1 and 0.55 or 1)
                p.holder:ClearAllPoints()
                p.holder:SetPoint("CENTER", self, "LEFT", (w * (i - 0.5) / #plates), -4 / SCALE)
                -- with "Phoenix bar texture" off the real plates keep Blizzard's art; the sample shows a flat fill
                if not db.texture then p.bar:SetStatusBarTexture(ns.Media.textures.WHITE) end
                m:StyleBar(p.bar)
                p.bar:SetStatusBarColor(P.Token(p.sample.token))
                ns.Skin:TextSpec(p.name, db.name.styled and db.name or ns.Style.Text(10), "unit")
                p.name:SetTextColor(P.Token(p.sample.token))
                p.name:SetText(L[p.sample.sample])
                m:StyleHealthText(p.health, p.bar)
                local value = (st.low and i == 1) and 0.16 or p.sample.value
                p.bar:SetValue(value)
                p.health:SetText(("%d%%"):format(value * 100))
                p.health:SetShown(db.healthText)
                m:StyleForces(p.forces)
                p.forces:SetText(p.sample.forces or "")
                p.forces:SetShown(db.forces)
            end
        end
    end,
})
