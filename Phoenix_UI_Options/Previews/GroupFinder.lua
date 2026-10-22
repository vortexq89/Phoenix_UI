local _, ns = ...
local L, P = ns.L, ns.Previews
local Skin, Media, Theme, Util = ns.Skin, ns.Media, ns.Theme, ns.Util

--[[ Group Finder preview: four sample groups run through the page's real filter (M:Match), drawn the way the
    list decorates them (dimmed when filtered, Ember outline on matches, leader score, best key, class strip),
    beside a small filter panel with the match count, the expression state and the sort. Fixed sample data. ]]
local GROUPS = {
    { id = 1, title = "PREVIEW_LFG_1", text = "PREVIEW_LFG_A1", members = 3, max = 5, score = 2850, bestkey = 14, timed = true,
      mythicplus = true, dungeon = true, tankfree = 0, healfree = 1, dpsfree = 1, age = 4, friends = 0, guild = 1, voice = true,
      lust = true, brez = false, leavers = 0, bosses = 0, pvp = 0, ilvl = 700, myrole = true,
      classes = { { class = "WARRIOR" }, { class = "MAGE" }, { class = "ROGUE" } } },
    { id = 2, title = "PREVIEW_LFG_2", text = "PREVIEW_LFG_A1", members = 4, max = 5, score = 1650, bestkey = 8, timed = false,
      mythicplus = true, dungeon = true, tankfree = 0, healfree = 0, dpsfree = 1, age = 41, friends = 0, guild = 0, voice = false,
      lust = false, brez = true, leavers = 1, bosses = 0, pvp = 0, ilvl = 680, myrole = false,
      classes = { { class = "PALADIN" }, { class = "PRIEST" }, { class = "DRUID" }, { class = "HUNTER" } } },
    { id = 3, title = "PREVIEW_LFG_3", text = "PREVIEW_LFG_A2", members = 2, max = 5, score = 3200, bestkey = 17, timed = true,
      mythicplus = true, dungeon = true, tankfree = 1, healfree = 1, dpsfree = 1, age = 1, friends = 1, guild = 0, voice = true,
      lust = true, brez = true, leavers = 0, bosses = 0, pvp = 0, ilvl = 715, myrole = true,
      classes = { { class = "SHAMAN" }, { class = "DEATHKNIGHT" } } },
    { id = 4, title = "PREVIEW_LFG_4", text = "PREVIEW_LFG_A3", members = 14, max = 30, score = 0, raid = true, heroic = true,
      tankfree = 0, healfree = 2, dpsfree = 8, age = 22, friends = 0, guild = 0, voice = true, lust = true, brez = true,
      leavers = 0, bosses = 3, pvp = 0, ilvl = 690, myrole = true, classes = {} },
}
for _, g in ipairs(GROUPS) do
    g.slots = g.max - g.members
    g.tanks, g.heals, g.dps = 1, 1, g.members - 2
    g.mythic, g.normal, g.pvpactivity, g.rated, g.declined, g.saved = false, false, false, false, false, false
    g.heroic, g.raid, g.dungeon = g.heroic or false, g.raid or false, g.dungeon or false
end

P:Register("groupfinder", {
    module = "GroupFinder",
    height = 236,
    width = 620,
    build = function(stage, m)
        local rows = {}
        for i, g in ipairs(GROUPS) do
            local row = CreateFrame("Frame", nil, stage)
            row:SetSize(330, 46)
            row:SetPoint("TOPLEFT", 14, -12 - (i - 1) * 52)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetTexture(Media.textures.WHITE)
            row.edge = CreateFrame("Frame", nil, row)
            row.edge:SetAllPoints()
            row.name = P.Text(row)
            row.name:SetPoint("TOPLEFT", 10, -7)
            row.activity = P.Text(row)
            row.activity:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
            row.score = P.Text(row)
            row.score:SetPoint("RIGHT", -88, -6)
            row.key = P.Text(row)
            row.key:SetPoint("BOTTOMRIGHT", row.score, "TOPRIGHT", 0, 2)
            row.roles = P.Text(row)
            row.roles:SetPoint("RIGHT", -10, 2)
            row.bars = {}
            for j = 1, 5 do
                local t = row:CreateTexture(nil, "OVERLAY")
                t:SetTexture(Media.textures.WHITE)
                t:SetSize(14, 3)
                t:SetPoint("BOTTOMRIGHT", -10 - (5 - j) * 16, 5)
                row.bars[j] = t
            end
            row.g = g
            rows[i] = row
        end
        local panel = CreateFrame("Frame", nil, stage)
        panel:SetSize(230, 204)
        panel:SetPoint("TOPLEFT", rows[1], "TOPRIGHT", 24, 0)
        panel.title = P.Text(panel)
        panel.title:SetPoint("TOPLEFT", 10, -10)
        panel.count = P.Text(panel)
        panel.count:SetPoint("TOPRIGHT", -10, -11)
        panel.lines = {}
        for i = 1, 6 do
            local fs = P.Text(panel)
            fs:SetPoint("TOPLEFT", 10, -36 - (i - 1) * 18)
            fs:SetWidth(210)
            fs:SetJustifyH("LEFT")
            panel.lines[i] = fs
        end
        panel.caption = P.Caption(stage, L.LFG_PANEL_TITLE)
        panel.caption:SetPoint("TOP", panel, "BOTTOM", 0, -6)

        local function drawRows(db, active)
            local n = 0
            for _, row in ipairs(rows) do
                local g = row.g
                local ok = m:Match(g)
                if ok then n = n + 1 end
                row:SetAlpha((not ok and db.nonMatch == "dim") and db.dimAlpha or 1)
                row.bg:SetVertexColor(Theme:Color("bg.raised"))
                if db.highlight and ok and active then
                    Skin:BorderSpec(row.edge, { style = "ember", size = 1, color = db.highlightColor, shadow = "none" }, "accent.primary")
                    row.edge:Show()
                elseif db.skinEntries then
                    Skin:BorderSpec(row.edge, { style = "theme", size = 1, color = false, shadow = "none" }, "border.subtle")
                    row.edge:Show()
                else
                    row.edge:Hide()
                end
                Skin:Text(row.name, "body", "text.primary", 12)
                Skin:Text(row.activity, "small", "text.muted", 10)
                Skin:Text(row.score, "number", nil, 11, "OUTLINE")
                Skin:Text(row.key, "small", nil, 10, "OUTLINE")
                Skin:Text(row.roles, "small", "text.secondary", 10)
                row.name:SetText(L[g.title])
                row.activity:SetText(L[g.text])
                row.score:SetText((db.entryScore and g.score > 0) and g.score or "")
                row.score:SetTextColor(Theme:Color(g.score >= 2500 and "accent.primary" or "text.primary"))
                row.key:SetText((db.entryScore and g.bestkey) and L.LFG_BEST_KEY:format(g.bestkey) or "")
                row.key:SetTextColor(Theme:Color(g.timed and "state.success" or "text.muted"))
                row.roles:SetText(("%d/%d"):format(g.members, g.max))
                for j, t in ipairs(row.bars) do
                    local c = db.classBars and g.max == 5 and g.classes[j]
                    if c then t:SetVertexColor(Util.ClassColor(c.class)); t:Show() else t:Hide() end
                end
            end
            return n
        end
        local function drawPanel(db, n)
            panel:SetShown(db.panel)
            panel.caption:SetShown(db.panel)
            Skin:Backdrop(panel, db.panelBackground, "bg.base")
            Skin:BorderSpec(panel, db.panelBorder, "border.strong")
            Skin:Text(panel.title, "heading", "accent.primary", 12)
            Skin:Text(panel.count, "number", "text.secondary", 11)
            panel.title:SetText(L.LFG_PANEL_TITLE)
            panel.count:SetText(db.matchCount and L.LFG_COUNT:format(n, #GROUPS) or "")
            local text = {}
            local preset
            for _, p in ipairs(m.PRESETS) do if p.value == db.preset then preset = p end end
            text[1] = L.LFG_PRESET .. ": " .. L[preset and preset.label or "LFG_PRESET_NONE"]
            text[2] = L.LFG_MIN_SCORE .. ": " .. db.minScore
            text[3] = L.LFG_MAX_AGE .. ": " .. (db.maxAge > 0 and db.maxAge or L.LFG_ANY)
            local err = m.filterError and m:ErrorText()
            text[4] = L.LFG_EXPRESSION .. ": " .. (db.expression ~= "" and db.expression or "—")
            text[5] = err or ""
            local sortLabel = db.sort
            for _, item in ipairs(m.SORT_LIST) do if item.value == db.sort then sortLabel = L[item.label] end end
            text[6] = L.LFG_SORT .. ": " .. sortLabel .. (db.sortDesc and (" · " .. L.LFG_SORT_DESC) or "")
            for i, fs in ipairs(panel.lines) do
                Skin:Text(fs, "small", (i == 5) and "state.danger" or "text.secondary", 10)
                fs:SetText(text[i])
            end
        end
        return function()
            local db = m.db
            m:BuildFilter()
            local active = m.expressionFn ~= nil or m:HasFilters()
            drawPanel(db, drawRows(db, active))
        end
    end,
})
