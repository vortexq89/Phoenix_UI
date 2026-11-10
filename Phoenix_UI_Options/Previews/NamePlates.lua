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
            holder:SetScale(ns.Previews.ClampScale(SCALE))
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
                p.holder:SetScale(ns.Previews.ClampScale(st.target and i == 1 and SCALE * 1.12 or SCALE))
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
        local plate
        -- One plate, the kind picked in the scope bar, centred at its real size with every part on it (cast bar
        -- filling, auras with stacks and timers, marker, class resource): what that plate looks like in the world.
        -- Each part is a hot spot that jumps to its settings.
        return function(view, kind)
            local phoenix = m.db.mode == "phoenix" and m.BuildPlate ~= nil
            holder:SetShown(not phoenix)
            if plate then plate:SetShown(phoenix) end
            if not phoenix then drawOld(view); return end
            if not plate then
                plate = m:BuildPlate(stage, { preview = true, sample = true })
                plate:EnableMouse(false)
            end
            local st = view.states
            local samples = m.Samples()
            local s = kind == "friendly" and samples[3] or samples[1]
            -- an enemy plate wears your real target (or focus) when there is one
            local real = kind ~= "friendly" and (P.RealUnit("target") or P.RealUnit("focus"))
            if real then
                s.name = real.name or s.name
                if real.level then s.level = real.level end
            end
            -- the cast is one of your own spells, named as the game names it ("bolt" is the first real icon)
            if P.real and s.cast then s.cast.name = P.real[1].name end
            s.frozen = ns.Anim:ReduceMotion() and true or false
            s.target = st.target and true or false
            s.hover = false
            if not st.marker then s.marker = nil end
            s.quest = st.quest and true or false
            s.absorb = st.absorb and math.floor((s.hpMax or 1) * 0.15) or 0
            if st.low then s.hp = math.floor((s.hpMax or 1) * 0.14) end
            plate:ClearAllPoints()
            plate:SetPoint("CENTER", stage, "CENTER", 0, 0)
            plate:Show()
            m:DrawSample(plate, s)
            P.Hot(stage, plate.Health, "styles.@.width", L.UF_WIDTH)
            P.Hot(stage, plate.Cast, "styles.@.cast.height", L.NP_CASTBAR)
            P.Hot(stage, plate.Name, "styles.@.nameTag", L.UF_TAG_NAME)
            P.Hot(stage, plate.HealthText, "styles.@.healthTag", L.UF_TAG_HEALTH)
            P.Hot(stage, plate.Marker, "styles.@.icons.marker", L.PREVIEW_STATE_MARKER)
            P.Hot(stage, plate.ClassPower, "target.classPower", L.UF_TAB_RESOURCES)
            local first = plate.Debuffs.buttons and plate.Debuffs.buttons[1]
            if first then P.Hot(stage, first, "styles.@.auras.size", L.NP_AURAS) end
        end
    end,
})
