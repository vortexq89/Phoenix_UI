local _, ns = ...
local L, P, Skin, Theme = ns.L, ns.Previews, ns.Skin, ns.Theme

-- A sample of the unit picked in the scope bar: portrait, name, health and power, styled by UnitFrames.
local SAMPLES = {
    player = { sample = "PREVIEW_UNIT_PLAYER", class = "MAGE", health = 0.86, power = 0.64, hp = "55.2K", level = "90",
               portrait = "Interface\\Icons\\ClassIcon_Mage" },
    target = { sample = "PREVIEW_MOB_HOSTILE", token = "state.danger", health = 0.58, power = 0.3, hp = "1.24M", level = "92",
               portrait = "Interface\\Icons\\Spell_Fire_SelfDestruct" },
    focus  = { sample = "PREVIEW_MOB_NEUTRAL", token = "state.warning", health = 1, power = 1, hp = "410K", level = "90",
               portrait = "Interface\\Icons\\Spell_Fire_FlameBolt" },
    boss   = { sample = "PREVIEW_MOB_BOSS", token = "state.danger", health = 0.72, power = 0.5, hp = "48.6M", level = "??",
               portrait = "Interface\\Icons\\Achievement_Boss_Ragnaros" },
    pet    = { sample = "PREVIEW_UNIT_PET", token = "state.success", health = 0.74, power = 0.9, hp = "21.7K", level = "90",
               portrait = "Interface\\Icons\\Spell_Frost_SummonWaterElemental_2" },
}
local SCALE = 1.35
local AURAS = { { 3, "" }, { 7, "2" }, { 11, "" }, { 5, "4" } }
local HAS_AURAS = { target = true, focus = true, boss = true }

P:Register("unitframe", {
    module = "UnitFrames",
    width = 360,
    height = 120,
    states = {
        { key = "low", label = "PREVIEW_STATE_LOW", icon = "warning" },
        { key = "range", label = "PREVIEW_STATE_RANGE", icon = "opacity" },
    },
    build = function(stage, m)
        local f = CreateFrame("Frame", nil, stage)
        f:SetSize(236, 62)
        f:SetScale(SCALE)
        f:SetPoint("CENTER", 0, 5)
        f.portrait = f:CreateTexture(nil, "ARTWORK")
        f.portrait:SetSize(54, 54)
        f.portrait:SetPoint("LEFT", 4, 0)
        f.portraitFrame = CreateFrame("Frame", nil, f)
        f.portraitFrame:SetAllPoints(f.portrait)
        f.health = P.Bar(f, 1, 168, 20)
        f.health:SetPoint("TOPLEFT", f.portrait, "TOPRIGHT", 6, -14)
        f.power = P.Bar(f, 1, 168, 10)
        f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
        f.name = P.Text(f)
        f.name:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 2, 3)
        f.level = P.Text(f)
        f.level:SetPoint("BOTTOMRIGHT", f.health, "TOPRIGHT", -2, 3)
        f.hpText = P.Text(f.health)
        f.hpText:SetPoint("CENTER")
        f.ppText = P.Text(f.power)
        f.ppText:SetPoint("CENTER")
        -- the aura row Blizzard shows under target, focus and boss frames
        f.auras = {}
        for i, def in ipairs(AURAS) do
            local a = P.Icon(f, 17, def[1])
            a:SetPoint("TOPLEFT", f.power, "BOTTOMLEFT", (i - 1) * 19, -4)
            a.count = P.Text(a)
            a.count:SetPoint("BOTTOMRIGHT", 1, 0)
            a.def = def
            f.auras[i] = a
        end
        return function(view, unit)
            local key = SAMPLES[unit] and unit or "player"
            local st = view.states
            local s = SAMPLES[key]
            local db = m.db
            local mode = m:Unit(key).portrait
            if mode == "class" and s.class then
                f.portrait:SetAtlas(GetClassAtlas(s.class))
                f.portrait:SetTexCoord(0, 1, 0, 1)
            else
                f.portrait:SetTexture(s.portrait)
                Skin:IconZoom(f.portrait, 0.08)
            end
            f.portrait:SetShown(mode ~= "hide")
            f.portraitFrame:SetShown(mode ~= "hide")
            Skin:Border(f.portraitFrame, "border.black")
            if not db.texture then
                f.health:SetStatusBarTexture(ns.Media.textures.WHITE)
                f.power:SetStatusBarTexture(ns.Media.textures.WHITE)
            end
            m:StyleHealthBar(f.health, key)
            m:StylePowerBar(f.power, key)
            local health = st.low and 0.18 or s.health
            f.health:SetValue(health)
            -- out of range: the faded look of the real frames (Blizzard's own range alpha)
            f:SetAlpha(st.range and (db.range and db.range.alpha or 0.45) or 1)
            f.power:SetValue(s.power)
            if s.class and db.classColor then
                f.health:SetStatusBarColor(ns.Util.ClassColor(s.class))
            else
                f.health:SetStatusBarColor(Theme:Color(s.token or "state.success"))
            end
            if db.powerColor then f.power:SetStatusBarColor(Theme:Color("state.info")) else
                f.power:SetStatusBarColor(Theme:Color("accent.primary"))
            end
            local texts = { name = f.name, health = { f.hpText }, power = { f.ppText } }
            if db.fonts then
                m:StyleTexts(texts, key)
            else
                Skin:Text(f.name, "unit"); Skin:Text(f.hpText, "unit", nil, 11); Skin:Text(f.ppText, "unit", nil, 10)
            end
            Skin:Text(f.level, "unit", "state.warning", 11)
            f.name:SetText(L[s.sample])
            f.level:SetText(s.level)
            f.hpText:SetText(st.low and ("%d%%"):format(health * 100) or s.hp)
            f.ppText:SetText(("%d%%"):format(s.power * 100))
            for _, a in ipairs(f.auras) do
                a:SetShown(HAS_AURAS[key] or false)
                if db.auras.style then
                    m:StyleAuraIcon(a, a.tex, a.count)
                else
                    Skin:IconFrame(a, a.tex, { style = "none" }, 0)
                    Skin:Text(a.count, "number", nil, 10)
                end
                a.count:SetText(a.def[2])
            end
        end
    end,
})
