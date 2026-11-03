local _, ns = ...
local L, P = ns.L, ns.Previews
local Skin, Media, Theme = ns.Skin, ns.Media, ns.Theme

--[[ Quests preview: a sample objective tracker (two quests, level tags, difficulty colours, a progress bar),
    a map tile with giver / daily / turn-in pins at the chosen size (plus vendor, trainer, flight master and
    rare pins, the NPC search box and the giver's location line), and the waypoint arrow with its distance and
    ETA. Fixed sample data; every element follows the page's saved settings. ]]
local QUESTS = {
    { title = "PREVIEW_QUEST_1", level = 82, tag = "", color = { 1, 0.82, 0 },
      lines = { { text = "PREVIEW_QUEST_1A" }, { text = "PREVIEW_QUEST_1B" } }, bar = 0.6 },
    { title = "PREVIEW_QUEST_2", level = 80, tag = "+G", color = { 0.25, 0.75, 0.25 }, lines = { { text = "PREVIEW_QUEST_2A" } } },
}
local PINS = { { "QuestNormal", 0.3, 0.35 }, { "QuestDaily", 0.66, 0.28 }, { "QuestTurnin", 0.52, 0.7 }, { "QuestNormal", 0.2, 0.74 } }
-- townsfolk / rare pins (NPCs.lua glyphs and colours): kind, x, y
local NPC_PINS = { { "vendor", 0.44, 0.22 }, { "trainer", 0.8, 0.5 }, { "flight", 0.14, 0.5 }, { "rare", 0.78, 0.82 } }

P:Register("quests", {
    module = "Quests",
    height = 200,
    width = 600,
    build = function(stage, m)
        -- tracker
        local tracker = CreateFrame("Frame", nil, stage)
        tracker:SetPoint("TOPLEFT", 16, -14)
        tracker:SetSize(250, 170)
        tracker.header = P.Text(tracker)
        tracker.header:SetPoint("TOPLEFT", 0, 0)
        tracker.rule = tracker:CreateTexture(nil, "ARTWORK")
        tracker.rule:SetTexture(Media.textures.WHITE)
        tracker.rule:SetHeight(1)
        tracker.rule:SetPoint("TOPLEFT", 0, -20)
        tracker.rule:SetPoint("TOPRIGHT", 0, -20)
        tracker.rows = {}
        for _, q in ipairs(QUESTS) do
            local t = P.Text(tracker)
            local row = { title = t, q = q, lines = {} }
            for _ in ipairs(q.lines) do row.lines[#row.lines + 1] = P.Text(tracker) end
            if q.bar then row.bar = P.Bar(tracker, q.bar, 170, 12) end
            tracker.rows[#tracker.rows + 1] = row
        end
        -- map tile
        local map = CreateFrame("Frame", nil, stage)
        map:SetSize(150, 150)
        map:SetPoint("TOPLEFT", tracker, "TOPRIGHT", 20, 0)
        map.ground = map:CreateTexture(nil, "BACKGROUND")
        map.ground:SetAllPoints()
        map.ground:SetTexture(Media.textures.WHITE)
        map.ground:SetVertexColor(0.2, 0.24, 0.16, 1)
        map.lake = map:CreateTexture(nil, "BORDER")
        map.lake:SetTexture(Media.textures.CIRCLE)
        map.lake:SetVertexColor(0.15, 0.28, 0.4, 0.9)
        map.lake:SetSize(60, 44)
        map.lake:SetPoint("CENTER", 30, -10)
        map.pins = {}
        for i, p in ipairs(PINS) do
            local t = map:CreateTexture(nil, "OVERLAY")
            t:SetAtlas(p[1])
            map.pins[i] = t
        end
        map.npcs = {}
        for i, p in ipairs(NPC_PINS) do
            map.npcs[i] = ns.Icons:Create(map, m.NPC_ICONS[p[1]], 16, m.NPC_TOKENS[p[1]], "OVERLAY")
        end
        -- the world map's NPC search box
        map.search = CreateFrame("Frame", nil, map)
        map.search:SetPoint("TOPLEFT", 6, -6)
        map.search:SetPoint("TOPRIGHT", -6, -6)
        map.search:SetHeight(18)
        map.search.text = P.Caption(map.search, L.QUESTS_SEARCH_NPC)
        map.search.text:SetPoint("LEFT", 6, 0)
        map.caption = P.Caption(stage, L.QUESTS_PINS)
        map.caption:SetPoint("TOP", map, "BOTTOM", 0, -6)
        -- arrow
        local arrow = CreateFrame("Frame", nil, stage)
        arrow:SetSize(130, 150)
        arrow:SetPoint("TOPLEFT", map, "TOPRIGHT", 20, 0)
        arrow.glyphs = {}
        arrow.title = P.Text(arrow)
        arrow.text = P.Text(arrow)
        arrow.off = P.Caption(arrow, L.OFF)
        arrow.off:SetPoint("CENTER")
        local function drawTracker(db)
            local styled = db.restyle
            local header, objective = db.header, db.objective
            if styled then
                Skin:TextSpec(tracker.header, header, "heading", "accent.primary")
            else
                Skin:Text(tracker.header, "heading", "accent.primary", 14)
            end
            tracker.header:SetText(L.QUESTS_PREVIEW_HEADER)
            tracker.rule:SetVertexColor(Theme:Color("accent.primary"))
            tracker.rule:SetAlpha(0.4)
            local y = -28
            for _, row in ipairs(tracker.rows) do
                local q = row.q
                if styled then Skin:TextSpec(row.title, header, "heading", nil) else Skin:Text(row.title, "body", nil, 12) end
                local prefix = (styled and db.level) and ("[%d%s] "):format(q.level, q.tag) or ""
                row.title:SetText(prefix .. L[q.title])
                if styled and db.difficulty then
                    row.title:SetTextColor(q.color[1], q.color[2], q.color[3])
                elseif styled and type(header.color) == "table" then
                    row.title:SetTextColor(Skin:SpecColor(header.color))
                else
                    row.title:SetTextColor(1, 0.82, 0)
                end
                row.title:ClearAllPoints()
                row.title:SetPoint("TOPLEFT", 8, y)
                y = y - (styled and header.size or 12) - 6
                for i, fs in ipairs(row.lines) do
                    if styled then
                        Skin:TextSpec(fs, objective, "body", "text.secondary")
                    else
                        Skin:Text(fs, "body", "text.secondary", 12)
                    end
                    fs:SetText("- " .. L[q.lines[i].text])
                    fs:ClearAllPoints()
                    fs:SetPoint("TOPLEFT", 20, y)
                    y = y - (styled and objective.size or 12) - 4
                end
                if row.bar then
                    row.bar:SetStatusBarTexture((styled and db.bar ~= "") and Media:Bar(db.bar) or Theme:Bar())
                    row.bar:SetStatusBarColor(Theme:Color("accent.primary"))
                    row.bar:ClearAllPoints()
                    row.bar:SetPoint("TOPLEFT", 20, y - 2)
                    y = y - 20
                end
                y = y - 6
            end
        end
        local function drawMap(db)
            local shown = db.questLines or db.npcPins
            local size = db.pinSize
            for i, t in ipairs(map.pins) do
                local p = PINS[i]
                t:SetSize(size, size)
                t:ClearAllPoints()
                t:SetPoint("CENTER", map, "TOPLEFT", p[2] * 150, -p[3] * 150)
                t:SetShown((p[1] == "QuestTurnin" and db.turnins) or (p[1] ~= "QuestTurnin" and shown))
            end
            for i, t in ipairs(map.npcs) do
                local p = NPC_PINS[i]
                t:SetSize(size, size)
                t:ClearAllPoints()
                t:SetPoint("CENTER", map, "TOPLEFT", p[2] * 150, -p[3] * 150)
                t:SetShown((p[1] == "rare" and db.rares) or (p[1] ~= "rare" and db.townsfolk))
            end
            Skin:Panel(map.search, "sunken")
            map.search:SetShown(db.mapSearch)
            -- the giver's spot under the caption, as quest tooltips show it
            map.caption:SetText(db.npcLocation and L.QUESTS_NPC_AT:format(L.PREVIEW_QUEST_ZONE, 45.4, 70.3) or L.QUESTS_PINS)
            Skin:BorderSpec(map, { style = "theme", size = 1, color = false, shadow = "auto" }, "border.black")
        end
        local function drawArrow(db)
            local style = m.ARROW_STYLES[db.arrowStyle] or m.ARROW_STYLES.phoenix
            for _, g in pairs(arrow.glyphs) do g:Hide() end
            local g = arrow.glyphs[db.arrowStyle]
            if not g then
                if style.atlas then
                    g = arrow:CreateTexture(nil, "ARTWORK")
                    g:SetAtlas(style.atlas)
                else
                    g = ns.Icons:Create(arrow, style.icon, 44, "accent.primary", "ARTWORK")
                end
                g:SetPoint("CENTER", 0, 24)
                arrow.glyphs[db.arrowStyle] = g
            end
            g:SetSize(db.arrowSize, db.arrowSize)
            g:SetRotation(math.rad(-30) + (style.rotate or 0))
            g:SetShown(db.arrow)
            arrow.off:SetShown(not db.arrow)
            Skin:Text(arrow.title, "heading", "accent.primary", 12, "OUTLINE")
            Skin:Text(arrow.text, "number", "text.primary", 12, "OUTLINE")
            arrow.title:ClearAllPoints()
            arrow.title:SetPoint("TOP", arrow, "CENTER", 0, 24 - db.arrowSize / 2 - 4)
            arrow.text:ClearAllPoints()
            arrow.text:SetPoint("TOP", arrow.title, "BOTTOM", 0, -2)
            arrow.title:SetText(L[QUESTS[1].title])
            local parts = {}
            if db.distance then parts[#parts + 1] = L.QUESTS_ARROW_YARDS:format(214) end
            if db.eta then parts[#parts + 1] = "0:31" end
            arrow.text:SetText(table.concat(parts, "  "))
            arrow.title:SetShown(db.arrow)
            arrow.text:SetShown(db.arrow)
        end
        return function()
            drawTracker(m.db)
            drawMap(m.db)
            drawArrow(m.db)
        end
    end,
})
