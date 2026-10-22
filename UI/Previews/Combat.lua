local _, ns = ...
local L, P = ns.L, ns.Previews
local Skin, Media = ns.Skin, ns.Media

--[[ Previews for the smaller combat modules: cooldown numbers, the spell history strip, the damage meter and
    floating combat text. Fixed sample data, styled by each module's own settings. ]]

-- One action-button sized icon with a partial cooldown shade.
local function button(parent, size, index)
    local b = P.Icon(parent, size, index)
    Skin:Icon(b.tex)
    Skin:Border(b, "border.black")
    b.shade = b:CreateTexture(nil, "OVERLAY")
    b.shade:SetTexture(Media.textures.WHITE)
    b.shade:SetVertexColor(0, 0, 0, 0.62)
    b.shade:SetPoint("BOTTOMLEFT"); b.shade:SetPoint("BOTTOMRIGHT")
    return b
end

---------------------------------------------------------------- cooldown numbers
local CD = { { 3, "12", 0.55 }, { 6, "4", 0.18 }, { 1, "1m", 0.9 }, { 9, "38", 0.7 }, { 11, "2", 0.08 } }

P:Register("cooldowntext", {
    module = "CooldownText",
    height = 96,
    build = function(stage, m)
        local buttons = {}
        for i, s in ipairs(CD) do
            local b = button(stage, 44, s[1])
            b.shade:SetHeight(44 * s[3])
            b.text = P.Text(b, "OVERLAY")
            b.text:SetPoint("CENTER", 0, 0)
            buttons[i] = b
        end
        return function(self)
            local w = self:GetWidth()
            for i, b in ipairs(buttons) do
                b:ClearAllPoints()
                b:SetPoint("CENTER", self, "LEFT", w * (i - 0.5) / #buttons, 0)
                m.PaintCountdown(b.text)
                b.text:SetText(CD[i][2])
            end
        end
    end,
})

---------------------------------------------------------------- spell history
P:Register("spellhistory", {
    module = "SpellHistory",
    height = 120,
    build = function(stage, m)
        local strip = CreateFrame("Frame", nil, stage)
        local icons = {}
        return function(self)
            local db = m.db
            local horiz = db.grow == "RIGHT" or db.grow == "LEFT"
            local sign = (db.grow == "RIGHT" or db.grow == "UP") and 1 or -1
            -- vertical strips are shown smaller so they fit the stage
            local size = horiz and db.size or math.min(db.size, math.floor((self:GetHeight() - 16) / db.count) - db.spacing)
            local span = db.count * size + (db.count - 1) * db.spacing
            if horiz then strip:SetSize(span, size) else strip:SetSize(size, span) end
            strip:ClearAllPoints()
            strip:SetPoint("CENTER")
            for i = 1, db.count do
                local f = icons[i]
                if not f then
                    f = P.Icon(strip, size, i + 2)
                    Skin:Icon(f.tex)
                    Skin:Border(f, "border.black")
                    Skin:Shadow(f, 4, nil, 0.45)
                    icons[i] = f
                end
                f:SetSize(size, size)
                f:ClearAllPoints()
                local offset = (i - 1) * (size + db.spacing) * sign
                local anchor = sign > 0 and (horiz and "LEFT" or "BOTTOM") or (horiz and "RIGHT" or "TOP")
                f:SetPoint(anchor, strip, anchor, horiz and offset or 0, horiz and 0 or offset)
                -- the newest cast is first; older ones fade the way they will in play
                f:SetAlpha(db.fade > 0 and (1 - (i - 1) / (db.count + 2)) or 1)
                f:Show()
            end
            for i = db.count + 1, #icons do icons[i]:Hide() end
        end
    end,
})

---------------------------------------------------------------- damage meter
local METER = {
    { "PREVIEW_PARTY_DPS1", 1, "MAGE", "2.41M" }, { "PREVIEW_UNIT_PLAYER", 0.86, "PALADIN", "2.07M" },
    { "PREVIEW_PARTY_DPS2", 0.74, "HUNTER", "1.78M" }, { "PREVIEW_PARTY_TANK", 0.41, "WARRIOR", "988K" },
    { "PREVIEW_PARTY_HEALER", 0.12, "PRIEST", "290K" },
}

P:Register("damagemeter", {
    module = "DamageMeter",
    height = 132,
    build = function(stage, m)
        local frame = CreateFrame("Frame", nil, stage)
        frame:SetSize(300, 5 * 20 + 8)
        frame:SetPoint("CENTER")
        local rows = {}
        for i, s in ipairs(METER) do
            local bar = P.Bar(frame, s[2], 284, 18)
            bar:SetPoint("TOPLEFT", 8, -4 - (i - 1) * 20)
            bar.bg = bar:CreateTexture(nil, "BACKGROUND")
            bar.bg:SetAllPoints()
            bar.name = P.Text(bar)
            bar.name:SetPoint("LEFT", 6, 0)
            bar.value = P.Text(bar)
            bar.value:SetPoint("RIGHT", -6, 0)
            rows[i] = bar
        end
        return function()
            local skin = m.db.skin
            Skin:Panel(frame, "base", { border = skin and "border.subtle" or "border.black" })
            for i, bar in ipairs(rows) do
                local r, g, b = ns.Util.ClassColor(METER[i][3])
                if skin then
                    Skin:StatusBar(bar)
                    bar.bg:SetTexture(Media.textures.WHITE)
                    bar.bg:SetVertexColor(ns.Theme:Color("bg.sunken"))
                    Skin:Text(bar.name, "unit", "text.primary", 12)
                    Skin:Text(bar.value, "number", "text.primary", 12)
                else
                    -- the stock look: Blizzard's bar art and font, shown here as a plain fill
                    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                    bar.bg:SetTexture(Media.textures.WHITE)
                    bar.bg:SetVertexColor(0, 0, 0, 0.5)
                    bar.name:SetFontObject(GameFontHighlightSmall)
                    bar.value:SetFontObject(GameFontHighlightSmall)
                end
                bar:SetStatusBarColor(r, g, b)
                bar.name:SetText(i .. ". " .. L[METER[i][1]])
                bar.value:SetText(METER[i][4])
            end
        end
    end,
})

---------------------------------------------------------------- floating combat text
-- The real text is drawn by the game; this shows which kinds are on, in the game's colours, at its scale.
local FCT = {
    { "floatingCombatTextCombatDamage_v2", "12 846", { 1, 1, 1 }, 1.25 },
    { "floatingCombatTextCombatLogPeriodicSpells_v2", "3 104", { 1, 0.82, 0 }, 0.9 },
    { "floatingCombatTextCombatHealing_v2", "+5 230", { 0.25, 1, 0.3 }, 1 },
    { "floatingCombatTextPetMeleeDamage_v2", "1 418", { 0.85, 0.85, 0.85 }, 0.8 },
    { "enableFloatingCombatText", "-2 960", { 1, 0.25, 0.2 }, 1 },
}

P:Register("combattext", {
    module = "CombatText",
    height = 120,
    build = function(stage)
        local texts = {}
        for i = 1, #FCT do texts[i] = P.Text(stage, "OVERLAY") end
        return function(self)
            local scale = tonumber(GetCVar("WorldTextScale_v2")) or 1
            local mode = tonumber(GetCVar("floatingCombatTextFloatMode_v2")) or 1
            local w, h = self:GetWidth(), self:GetHeight()
            local font = (ns.Theme:Font("combat"))
            for i, s in ipairs(FCT) do
                local fs = texts[i]
                local on = GetCVar(s[1]) == "1"
                fs:SetFont(font, math.floor(15 * s[4] * math.min(scale, 1.6) + 0.5), "OUTLINE")
                fs:SetTextColor(s[3][1], s[3][2], s[3][3])
                fs:SetText(s[2])
                fs:SetAlpha(on and 1 or 0.18)
                fs:ClearAllPoints()
                local t = (i - 1) / (#FCT - 1)
                local y = (mode == 2) and (h * 0.32 - t * h * 0.64) or (-h * 0.32 + t * h * 0.64)
                local x = (mode == 3) and (math.sin(t * math.pi) * w * 0.18) or ((i % 2 == 0) and 40 or -40)
                fs:SetPoint("CENTER", self, "CENTER", x, y)
            end
        end
    end,
})
