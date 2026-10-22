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
-- { icon, seconds left, shade }: one expiring, a few in seconds, one in minutes, one below the decimals line
local CD = { { 3, 12, 0.55 }, { 6, 4, 0.18 }, { 1, 75, 0.9 }, { 9, 38, 0.7 }, { 11, 2.4, 0.08 } }

-- What Blizzard's countdown would print for `left` seconds with these settings.
local function countdown(db, left)
    if left >= 60 then return ("%dm"):format(math.floor(left / 60 + 0.5)) end
    if db.decimals > 0 and left < db.decimals then return ("%.1f"):format(left) end
    return tostring(math.floor(left + 0.5))
end

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
            local db = m.db
            local w = self:GetWidth()
            for i, b in ipairs(buttons) do
                local left = CD[i][2]
                b:ClearAllPoints()
                b:SetPoint("CENTER", self, "LEFT", w * (i - 0.5) / #buttons, 0)
                m.PaintCountdown(b.text, m:SizeFor(44))
                b.text:SetText(countdown(db, left))
                if db.byRemaining then
                    local which = (left < db.expiring and "expiring") or (left < 60 and "seconds") or "minutes"
                    b.text:SetTextColor(m:ColorOf(which))
                end
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
                    icons[i] = f
                end
                f:SetSize(size, size)
                m:StyleIcon(f)
                -- the third cast was interrupted (shown when marking is on)
                m.MarkIcon(f, db.markFailed and i == 3)
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
            if skin then
                Skin:Panel(frame, "base", { border = false })
                m:StyleWindow(frame)
            else
                Skin:Panel(frame, "base", { border = "border.black" })
            end
            for i, bar in ipairs(rows) do
                local r, g, b = ns.Util.ClassColor(METER[i][3])
                if skin then
                    m:StyleBar(bar, bar.name, bar.value)
                    bar.bg:SetTexture(Media.textures.WHITE)
                    bar.bg:SetVertexColor(ns.Theme:Color("bg.sunken"))
                else
                    -- the stock look: Blizzard's bar art and font, shown here as a plain fill
                    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                    bar:SetReverseFill(false)
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

-- Phoenix scroll areas: sample lines per area, in the area's font and crit style (CombatText:StyleLine).
local AREA_SAMPLE = {
    incoming = { { "-12 846", { 1, 0.3, 0.25 } }, { "+8 230", { 0.3, 1, 0.35 }, true }, { "COMBAT_TEXT_DODGE", { 1, 1, 1 } } },
    target = { { "31 044", { 1, 0.95, 0.85 }, true }, { "4 112 ×3", { 1, 0.95, 0.85 } } },
    notify = { { "+FCT_SAMPLE_AURA", { 1, 0.85, 0.4 } } },
}

local function sampleText(t)
    local word = t:gsub("^%+", "")
    if L[word] and word ~= t then return "+" .. L[word] end
    return _G[t] or L[t] or t
end

P:Register("combattext", {
    module = "CombatText",
    height = 150,
    build = function(stage, m)
        local texts = {}
        for i = 1, #FCT do texts[i] = P.Text(stage, "OVERLAY") end
        local areas = {}
        for _, key in ipairs({ "incoming", "target", "notify" }) do
            local box = CreateFrame("Frame", nil, stage)
            box.caption = P.Caption(box, L["FCT_AREA_" .. key:upper()])
            box.caption:SetPoint("BOTTOM", box, "TOP", 0, 2)
            box.lines = {}
            for i = 1, #AREA_SAMPLE[key] do box.lines[i] = P.Text(box, "OVERLAY") end
            areas[key] = box
        end
        return function(self)
            local scroll = m.db.scroll
            local scale = tonumber(GetCVar("WorldTextScale_v2")) or 1
            local mode = tonumber(GetCVar("floatingCombatTextFloatMode_v2")) or 1
            local w, h = self:GetWidth(), self:GetHeight()
            local font = (ns.Theme:Font("combat"))
            if m.db.damageFont ~= "" then font = Media:Font(m.db.damageFont) end
            for i, s in ipairs(FCT) do
                local fs = texts[i]
                local on = GetCVar(s[1]) == "1"
                fs:SetFont(font, math.floor(15 * s[4] * math.min(scale, 1.6) + 0.5), "OUTLINE")
                fs:SetTextColor(s[3][1], s[3][2], s[3][3])
                fs:SetText(s[2])
                fs:SetAlpha((on and 1 or 0.18) * (scroll.enabled and 0.35 or 1))
                fs:ClearAllPoints()
                local t = (i - 1) / (#FCT - 1)
                local y = (mode == 2) and (h * 0.32 - t * h * 0.64) or (-h * 0.32 + t * h * 0.64)
                local x = (mode == 3) and (math.sin(t * math.pi) * w * 0.18) or ((i % 2 == 0) and 40 or -40)
                fs:SetPoint("CENTER", self, "CENTER", x, y)
            end
            -- the three areas, laid out left / right / top like their default places
            local slots = { incoming = { -0.33, -10 }, target = { 0.33, -10 }, notify = { 0, 34 } }
            for key, box in pairs(areas) do
                local a = scroll.areas[key]
                box:SetShown(scroll.enabled and a.show)
                box:SetSize(w * 0.28, key == "notify" and 40 or 86)
                box:ClearAllPoints()
                box:SetPoint("CENTER", self, "CENTER", w * slots[key][1], slots[key][2])
                for i, fs in ipairs(box.lines) do
                    local sample = AREA_SAMPLE[key][i]
                    m:StyleLine(fs, sample[3])
                    local r, g, b = sample[2][1], sample[2][2], sample[2][3]
                    if sample[3] and scroll.crit == "flash" then r, g, b = ns.Theme:Color("accent.primary") end
                    fs:SetTextColor(r, g, b)
                    fs:SetText(sampleText(sample[1]))
                    fs:ClearAllPoints()
                    local step = (i - 1) * 24
                    if a.dir == "DOWN" then fs:SetPoint("TOP", box, "TOP", 0, -step) else fs:SetPoint("BOTTOM", box, "BOTTOM", 0, step) end
                end
            end
        end
    end,
})

---------------------------------------------------------------- PvP queue pop (S16)
-- A drawn copy of the ready dialog: Enter centred with "Leave Queue" gone under safe queue, and the countdown;
-- (S18) the arena Shadowsight timer under it, 52 seconds into a match.
P:Register("pvp", {
    module = "PvP",
    height = 156,
    build = function(stage, m)
        local d = CreateFrame("Frame", nil, stage)
        d:SetSize(260, 84)
        d:SetPoint("TOP", 0, -10)
        d.title = P.Text(d, "OVERLAY")
        d.title:SetPoint("TOP", 0, -10)
        local function fake(text)
            local b = CreateFrame("Frame", nil, d)
            b:SetSize(100, 22)
            b.text = P.Text(b, "OVERLAY")
            b.text:SetPoint("CENTER")
            b.text:SetText(text)
            return b
        end
        d.enter, d.leave = fake(ENTER_BATTLE), fake(LEAVE_QUEUE)
        local timer = P.Text(stage, "OVERLAY")
        timer:SetPoint("TOP", d, "BOTTOM", 0, -6)
        local sight = P.Text(stage, "OVERLAY")
        sight:SetPoint("TOP", timer, "BOTTOM", 0, -8)
        return function()
            local db = m.db
            Skin:Panel(d, "raised", { border = "border.default" })
            Skin:Text(d.title, "title", "text.primary", 12)
            d.title:SetText(L.PREVIEW_PVP_READY)
            for _, b in ipairs({ d.enter, d.leave }) do
                Skin:Panel(b, "sunken", { border = "border.subtle" })
                Skin:Text(b.text, "body", "text.primary", 11)
            end
            d.enter:ClearAllPoints(); d.leave:ClearAllPoints()
            if db.safeQueue then
                d.enter:SetPoint("BOTTOM", 0, 12)
                d.leave:Hide()
            else
                d.enter:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -4, 12)
                d.leave:SetPoint("BOTTOMLEFT", d, "BOTTOM", 4, 12)
                d.leave:Show()
            end
            m:StyleTimer(timer)
            timer:SetFormattedText(L.PVP_TIME_LEFT, 37)
            timer:SetShown(db.showTimer)
            local ss = db.shadowsight
            Skin:TextSpec(sight, ss.text, "number", "accent.primary")
            sight:SetText(m.ShadowsightText(52, ss.delay, ss.shown) or "")
            sight:SetShown(ss.enabled and ns:Supports("arena"))
        end
    end,
})
