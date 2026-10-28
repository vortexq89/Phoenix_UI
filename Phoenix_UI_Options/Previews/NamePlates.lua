local _, ns = ...
local L, P = ns.L, ns.Previews

--[[ Phoenix mode: three plates built by NamePlates itself (M:BuildPlate / LayoutPlate / DrawSample, the code that
    draws the real plates) fed plain sample units - an elite enemy casting an important spell, a rare quest mob
    and a friendly player - so the cast bar, auras, badges and highlights all show. Nothing reads a unit.
    States (eye toggles): low health (execute), target, raid markers, quest mobs, absorbs.
    Blizzard mode: the 2.0 restyle drawn on plain bars. ]]

-- Three sample plates (hostile, neutral, friendly) drawn by NamePlates' own style methods.
local SAMPLES = {
    { sample = "PREVIEW_MOB_HOSTILE", value = 0.72, token = "state.danger", forces = "+4", threat = 3, cast = 0.6,
      auras = { { 3, "8" }, { 7, "14", "2" }, { 11, "" } } },
    { sample = "PREVIEW_MOB_NEUTRAL", value = 1, token = "state.warning", threat = 1, focus = true },
    { sample = "PREVIEW_MOB_FRIENDLY", value = 0.46, token = "state.success" },
}
local PLATE_W, PLATE_H, SCALE, AURA = 150, 12, 1.25, 16

local function legacy(stage, m)
    do
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
            local cast
            if sample.cast then
                cast = P.Bar(holder, sample.cast, PLATE_W, 8)
                cast:SetPoint("TOP", bar, "BOTTOM", 0, -2)
                cast.text = P.Text(cast)
                cast.text:SetPoint("CENTER", 0, -1)
                holder:SetHeight(50)
            end
            local auras
            if sample.auras then
                auras = {}
                for k, def in ipairs(sample.auras) do
                    local a = P.Icon(holder, AURA, def[1])
                    a:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", (k - 1) * (AURA + 2), 20)
                    a.timer = P.Text(a)
                    a.timer:SetPoint("CENTER", 0, 0)
                    a.count = P.Text(a)
                    a.count:SetPoint("BOTTOMRIGHT", 1, 0)
                    a.def = def
                    auras[k] = a
                end
                holder:SetHeight(holder:GetHeight() + AURA)
            end
            plates[i] = { holder = holder, bar = bar, name = name, health = health, forces = forces, sample = sample, cast = cast,
                auras = auras }
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
                p.holder:SetPoint("CENTER", self, "LEFT", (w * (i - 0.5) / #plates), (p.cast and -9 or -4) / SCALE)
                -- with "Phoenix bar texture" off the real plates keep Blizzard's art; the sample shows a flat fill
                if not db.texture then p.bar:SetStatusBarTexture(ns.Media.textures.WHITE) end
                m:StyleBar(p.bar)
                local s = p.sample
                local r, g, b = m:PlateColor(nil, { target = st.target and i == 1, focus = s.focus, threat = s.threat })
                if r then p.bar:SetStatusBarColor(r, g, b) else p.bar:SetStatusBarColor(P.Token(s.token)) end
                if p.cast then
                    p.cast:SetShown(db.castbar.style)
                    m:StyleCastBar(p.cast, p.cast.text)
                    if type(db.castbar.color) ~= "table" then p.cast:SetStatusBarColor(P.Token("accent.primary")) end
                    p.cast.text:SetText(L.PREVIEW_CAST_SPELL)
                end
                ns.Skin:TextSpec(p.name, db.name.styled and db.name or ns.Style.Text(10), "unit")
                p.name:SetTextColor(P.Token(p.sample.token))
                p.name:SetText(L[p.sample.sample])
                m:StyleHealthText(p.health, p.bar)
                local value = (st.low and i == 1) and 0.16 or p.sample.value
                p.bar:SetValue(value)
                p.health:SetText(("%d%%"):format(value * 100))
                p.health:SetShown(db.healthText)
                for _, a in ipairs(p.auras or {}) do
                    if db.auras.style then
                        m:StyleAuraIcon(a, a.tex, a.count, a.timer)
                    else
                        ns.Skin:IconFrame(a, a.tex, { style = "none" }, 0.08)
                    end
                    a.timer:SetText(a.def[2]); a.count:SetText(a.def[3] or "")
                end
                m:StyleForces(p.forces)
                p.forces:SetText(p.sample.forces or "")
                p.forces:SetShown(db.forces)
            end
        end
    end
end

P:Register("nameplate", {
    module = "NamePlates",
    width = 600,
    height = 150,
    states = {
        { key = "low", label = "PREVIEW_STATE_LOW", icon = "deaths" },
        { key = "target", label = "PREVIEW_STATE_TARGET", icon = "nameplates" },
        { key = "marker", label = "PREVIEW_STATE_MARKER", icon = "boss" },
        { key = "quest", label = "PREVIEW_STATE_QUEST", icon = "tracker" },
        { key = "absorb", label = "PREVIEW_STATE_ABSORB", icon = "auras" },
    },
    build = function(stage, m)
        local holder = CreateFrame("Frame", nil, stage)
        holder:SetAllPoints()
        local drawOld = legacy(holder, m)
        local plates
        return function(view)
            local phoenix = m.db.mode == "phoenix" and m.BuildPlate ~= nil
            holder:SetShown(not phoenix)
            for _, p in ipairs(plates or {}) do p:SetShown(phoenix) end
            if not phoenix then drawOld(view); return end
            if not plates then
                plates = {}
                for i = 1, 4 do
                    local p = m:BuildPlate(stage, { preview = true, sample = true })
                    p:EnableMouse(false)
                    plates[i] = p
                end
            end
            local st = view.states
            local samples = m.Samples()
            -- the first plate wears your real target (or the nearest real unit you have) when there is one
            local real = P.RealUnit("target") or P.RealUnit("focus")
            if real and samples[1] then
                samples[1].name = real.name or samples[1].name
                if real.level then samples[1].level = real.level end
            end
            local w = view:GetWidth()
            for i, p in ipairs(plates) do
                local s = samples[i]
                s.frozen = true
                s.target = st.target and i == 1 or false
                s.hover = i == 3
                if not st.marker then s.marker = nil end
                s.quest = st.quest and i == 2 or false
                if st.absorb then s.absorb = math.floor((s.hpMax or 1) * 0.15) else s.absorb = 0 end
                if st.low and i == 1 then s.hp = math.floor((s.hpMax or 1) * 0.14) end
                p:ClearAllPoints()
                p:SetPoint("CENTER", stage, "LEFT", w * (i - 0.5) / #plates, 4)
                p:Show()
                m:DrawSample(p, s)
                P.Hot(stage, p, "styles.@.width", L.UF_WIDTH)
            end
        end
    end,
})
