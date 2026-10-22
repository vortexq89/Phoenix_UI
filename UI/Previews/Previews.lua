local _, ns = ...
local W, Skin, Theme, Media = ns.Widgets, ns.Skin, ns.Theme, ns.Media

--[[ ns.Previews — live mock-ups at the top of module option pages.
    A preview is built from plain Frames, Textures, FontStrings and StatusBars (no secure templates, no
    Blizzard frames, no unit queries) filled with fixed sample data, so it is safe in combat and never
    touches a secret value. It is styled by the module's own style methods, the same code that dresses
    the real frames, and redrawn on every PUI_SETTING_CHANGED of its module, on theme changes and when
    the page's unit selector moves.

    ns.Previews:Register(kind, { height = px, states = { {key, label, icon} }?,
        build = function(stage, m) -> redraw(stage, unit) }) ]]
local P = { kinds = {} }
ns.Previews = P

function P:Register(kind, def) self.kinds[kind] = def end

-- def.states = { { key, label, icon }, ... }: sample states the page can switch on (low health, casting …).
-- The draw function reads them from stage.states[key].
function P:States(kind)
    local def = self.kinds[kind]
    return def and def.states and #def.states > 0 and def.states or nil
end

-- Sample data shared by the previews (spell and item icons are stock game art).
P.SAMPLE = {
    icons = {
        "Interface\\Icons\\Spell_Fire_Fireball02", "Interface\\Icons\\Spell_Fire_FlameBolt",
        "Interface\\Icons\\Spell_Fire_SelfDestruct", "Interface\\Icons\\Spell_Holy_MagicalSentry",
        "Interface\\Icons\\Spell_Frost_IceStorm", "Interface\\Icons\\Ability_Mage_LivingBomb",
        "Interface\\Icons\\Spell_Nature_Lightning", "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
        "Interface\\Icons\\Ability_Warrior_BattleShout", "Interface\\Icons\\Spell_Holy_PowerWordShield",
        "Interface\\Icons\\INV_Misc_PocketWatch_01", "Interface\\Icons\\Spell_Arcane_TeleportDalaran",
    },
}

---------------------------------------------------------------- building blocks
-- A status bar for previews: fixed value, our texture, a background region.
function P.Bar(parent, value, w, h)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetMinMaxValues(0, 1)
    b:SetValue(value or 1)
    b:SetSize(w or 160, h or 14)
    b:SetStatusBarTexture(Media.textures.WHITE)
    return b
end

function P.Text(parent, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetWordWrap(false)
    return fs
end

function P.Icon(parent, size, index)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size or 32, size or 32)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexture(P.SAMPLE.icons[((index or 1) - 1) % #P.SAMPLE.icons + 1])
    return f
end

-- Small caption under a sample ("Target", "Focus", …).
function P.Caption(parent, text)
    local fs = W.Text(parent, "small", "text.muted", "CENTER")
    fs:SetText(text:upper())
    return fs
end

---------------------------------------------------------------- stage
function P:Create(kind, parent, m, page)
    local def = self.kinds[kind]
    local stage = CreateFrame("Frame", nil, parent)
    stage:SetHeight(def and def.height or 120)
    stage:SetClipsChildren(true)
    stage.states = {}
    stage.floor = W.Texture(stage, "BACKGROUND", 1, Media.textures.FADE_V)
    stage.floor:SetPoint("BOTTOMLEFT"); stage.floor:SetPoint("BOTTOMRIGHT")
    stage.floor:SetHeight(60)
    stage.floor:SetTexCoord(0, 1, 1, 0)
    Skin:Register(stage, function(self)
        Skin:Panel(self, "sunken", { border = "border.subtle" })
        W.Color(self.floor, "accent.primary", 0.06)
    end)
    local draw = def and def.build(stage, m)
    function stage:Redraw()
        if draw then ns.SafeCall(draw, self, page.scope and page.scope.unit) end
    end
    local function onChange(_, _, moduleKey)
        if stage:IsVisible() and (moduleKey == m.key or moduleKey == "General") then stage:Redraw() end
    end
    ns.Events:Listen("PUI_SETTING_CHANGED", stage, onChange)
    ns.Events:Listen("PUI_THEME_CHANGED", stage, function() if stage:IsVisible() then stage:Redraw() end end)
    stage:SetScript("OnShow", stage.Redraw)
    stage:Redraw()
    return stage
end

-- The colour a sample bar would get from the theme (healthy friendly unit, hostile mob, …).
function P.Token(token) return Theme:Color(token) end
