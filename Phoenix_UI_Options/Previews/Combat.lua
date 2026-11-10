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

---------------------------------------------------------------- floating combat text
-- The real text is drawn by the game; this shows which kinds are on, in the game's colours, at its scale.
local FCT = {
    { "floatingCombatTextCombatDamage_v2", "12 846", { 1, 1, 1 }, 1.25 },
    { "floatingCombatTextCombatLogPeriodicSpells_v2", "3 104", { 1, 0.82, 0 }, 0.9 },
    { "floatingCombatTextCombatHealing_v2", "+5 230", { 0.25, 1, 0.3 }, 1 },
    { "floatingCombatTextPetMeleeDamage_v2", "1 418", { 0.85, 0.85, 0.85 }, 0.8 },
    { "enableFloatingCombatText", "-2 960", { 1, 0.25, 0.2 }, 1 },
}

-- Phoenix scrolling text: a scaled copy of the screen with every area at its real place and size; each plays
-- sample lines along its own animation path (CombatText.Path) in its events' colours and sizes, with spell icons
-- on the side the area says. The area picked in the scope bar can be dragged (P.Hot on the scaled screen, so a
-- drag moves its x / y one to one). Motion runs only while the preview is visible (its own OnUpdate, cleared on hide).
local AREA_KEYS = { "incoming", "heals", "target", "outheal", "power", "notify", "crits" }
local ICON_FIRE, ICON_HEAL, ICON_AURA = 135812, 135913, 136243 -- sample icon file IDs (a fire spell, a heal, an aura)
local AREA_SAMPLE = {
    incoming = { { "damage", "-12 846" }, { "spell", "-4 410", true }, { "avoid", "COMBAT_TEXT_DODGE" } },
    heals = { { "heal", "+8 230", true }, { "hot", "+1 904" } },
    target = { { "hit", "31 044", true, ICON_FIRE }, { "hit", "4 112 ×3", false, ICON_FIRE } },
    outheal = { { "theal", "+2 950", false, ICON_HEAL } },
    power = { { "p_mana", "+240 MANA" }, { "p_rage", "+12 RAGE" } },
    notify = { { "buff", "+FCT_SAMPLE_AURA", false, ICON_AURA } },
    crits = { { "hit", "58 120", true, ICON_FIRE } },
}

local function sampleText(t)
    local sign, word = t:match("^([%+%-]?)(.*)$")
    local num, power = word:match("^(%d+) (%u[%u_]+)$")
    if num and _G[power] then return sign .. num .. " " .. _G[power] end
    if sign ~= "" and L[word] then return sign .. L[word] end
    return _G[t] or rawget(L, t) or t
end

P:Register("combattext", {
    module = "CombatText",
    height = 280,
    build = function(stage, m)
        local texts = {}
        for i = 1, #FCT do texts[i] = P.Text(stage, "OVERLAY") end
        local screen = CreateFrame("Frame", nil, stage)
        screen:SetPoint("CENTER")
        local areas = {}
        for _, key in ipairs(AREA_KEYS) do
            local box = CreateFrame("Frame", nil, screen)
            box.key = key
            box.bg = box:CreateTexture(nil, "BACKGROUND")
            box.bg:SetAllPoints()
            box.bg:SetColorTexture(1, 1, 1, 0.04)
            box.caption = P.Caption(box, L["FCT_AREA_" .. key:upper()])
            box.caption:SetPoint("TOP", box, "BOTTOM", 0, -2)
            box.lines = {}
            for i = 1, #AREA_SAMPLE[key] do
                local fs = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                fs.icon = box:CreateTexture(nil, "OVERLAY")
                fs.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                box.lines[i] = fs
            end
            areas[key] = box
        end
        local clock, k = 0, 1
        local function animate()
            local scroll = m.db.scroll
            for key, box in pairs(areas) do
                local a = scroll.areas[key]
                local dur = math.max(0.5, a.duration or 2.4)
                for i, fs in ipairs(box.lines) do
                    local t = ((clock / dur) + (i - 1) / #box.lines) % 1
                    local x, y = m.Path(a.anim, t, a.height, a.width, i % 2 == 0 and 1 or -1, i - 1, 26)
                    local side = a.align == "LEFT" and "LEFT" or (a.align == "RIGHT" and "RIGHT" or "")
                    local inset = (side == "LEFT" and (a.iconSize + 6)) or (side == "RIGHT" and -(a.iconSize + 6)) or 0
                    local sc = fs:GetScale() or 1
                    fs:ClearAllPoints()
                    if a.dir == "DOWN" then fs:SetPoint("TOP" .. side, box, "TOP" .. side, (x + inset) / sc, -y / sc)
                    else fs:SetPoint("BOTTOM" .. side, box, "BOTTOM" .. side, (x + inset) / sc, y / sc) end
                    local alpha = t > 0.66 and math.max(0, 1 - (t - 0.66) / 0.34) or 1
                    fs:SetAlpha(alpha); fs.icon:SetAlpha(alpha)
                end
            end
        end
        -- the sample numbers move on a C_Timer ticker while the preview shows (no OnUpdate, specs/001 T015)
        local STEP = 1 / 30
        stage:HookScript("OnShow", function(self)
            if self.anim then self.anim:Cancel() end
            self.anim = C_Timer.NewTicker(STEP, function() clock = clock + STEP; animate() end)
        end)
        stage:HookScript("OnHide", function(self) if self.anim then self.anim:Cancel(); self.anim = nil end end)
        return function(self, scopeKey)
            local scroll = m.db.scroll
            local scale = tonumber((GetCVar("WorldTextScale_v2"))) or 1
            local mode = tonumber((GetCVar("floatingCombatTextFloatMode_v2"))) or 1
            local w, h = self:GetWidth(), self:GetHeight()
            local font = (ns.Theme:Font("combat"))
            if m.db.damageFont ~= "" then font = Media:Font(m.db.damageFont) end
            for i, s in ipairs(FCT) do
                local fs = texts[i]
                local on = GetCVar(s[1]) == "1"
                fs:SetFont(font, math.floor(15 * s[4] * math.min(scale, 1.6) + 0.5), "OUTLINE")
                fs:SetTextColor(s[3][1], s[3][2], s[3][3])
                fs:SetText(s[2])
                fs:SetAlpha((on and 1 or 0.18) * (scroll.enabled and 0.12 or 1))
                fs:ClearAllPoints()
                local t = (i - 1) / (#FCT - 1)
                local y = (mode == 2) and (h * 0.32 - t * h * 0.64) or (-h * 0.32 + t * h * 0.64)
                local x = (mode == 3) and (math.sin(t * math.pi) * w * 0.18) or ((i % 2 == 0) and 40 or -40)
                fs:SetPoint("CENTER", self, "CENTER", x, y)
            end
            -- the scaled screen: UIParent's size fitted into the stage
            local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
            k = math.min(w / sw, h / sh)
            screen:SetSize(sw, sh)
            screen:SetScale(math.max(0.05, k))
            screen.onHot, screen.attachHot = self.onHot, self.attachHot
            for key, box in pairs(areas) do
                local a = scroll.areas[key]
                box:SetShown(scroll.enabled and a.show)
                box:SetSize(a.width, a.height)
                box:ClearAllPoints()
                box:SetPoint("CENTER", screen, "CENTER", a.x, a.y)
                box.bg:SetColorTexture(1, 1, 1, key == scopeKey and 0.10 or 0.04)
                box.caption:SetScale(1 / math.max(0.05, k) * 0.9)
                for i, fs in ipairs(box.lines) do
                    local sample = AREA_SAMPLE[key][i]
                    local ev = scroll.events[sample[1]]
                    m:StyleLine(fs, sample[3], key, ev.scale)
                    -- readable at the preview's size: text and icon drawn larger than the scaled screen would
                    local boost = math.min(4, 0.45 / math.max(0.05, k))
                    fs:SetScale(boost)
                    local c = a.useColor and a.color or ev.color
                    local r, g, b = c.r, c.g, c.b
                    if sample[3] and scroll.crit == "flash" then r, g, b = ns.Theme:Color("accent.primary") end
                    fs:SetTextColor(r, g, b)
                    fs:SetText(sampleText(sample[2]))
                    local ic = fs.icon
                    if sample[4] and a.iconSide ~= "OFF" then
                        ic:SetTexture(sample[4])
                        ic:SetSize(a.iconSize * boost, a.iconSize * boost)
                        ic:ClearAllPoints()
                        if a.iconSide == "RIGHT" then ic:SetPoint("LEFT", fs, "RIGHT", 4, 0)
                        else ic:SetPoint("RIGHT", fs, "LEFT", -4, 0) end
                        ic:Show()
                    else
                        ic:Hide()
                    end
                end
                if key == scopeKey then
                    P.Hot(screen, box, "scroll.areas.@.width", L.FCT_UNLOCK)
                elseif box.puiHot then
                    box.puiHot:Hide()
                end
            end
            animate()
        end
    end,
})

---------------------------------------------------------------- PvP queue pop (S16)
-- A drawn copy of the ready dialog: Enter centred with "Leave Queue" gone under safe queue, and the countdown;
-- (S18) the arena Shadowsight timer under it, 52 seconds into a match.
