local _, ns = ...
local Skin = ns.Skin
local M = ns:GetModule("Skins")

--[[ World map and quest log, skins plan window 5 (the tracker's header ticks live in Quests/Tracker.lua):
    the map's border frame gets the Phoenix window look (backdrop, border, accent title, close glyph) through
    the shared window skin, the quest log beside it a sunken Phoenix panel, and the quest log's side tabs
    (quests / events / legend) a 1 px outline that turns accent on the open one. The map canvas, pins and quest
    rows are not touched (no secure parts are involved), and nothing is moved or resized. Live both ways
    through the Skins > World map switch, repainted on theme change. ]]

local SIDE_TABS = { "QuestsTab", "EventsTab", "MapLegendTab" }
local outlines = setmetatable({}, { __mode = "k" })
local logPanel

-- Is a quest-log side tab the open one? (its selected art shown; plain boolean read, no secret values)
function M.SideTabSelected(tab)
    local sel = tab and tab.SelectedTexture
    return sel and sel.IsShown and sel:IsShown() and true or false
end

local function paintSideTabs(on)
    local qm = _G.QuestMapFrame
    if not qm then return end
    for _, key in ipairs(SIDE_TABS) do
        local tab = qm[key]
        if tab then
            local o = outlines[tab]
            if on and not o then
                o = CreateFrame("Frame", nil, tab)
                o:SetAllPoints()
                Skin:Border(o, "border.subtle")
                outlines[tab] = o
                tab:HookScript("OnClick", function() M:SkinWorldMap() end)
            end
            if o then
                o:SetShown(on and true or false)
                if on then Skin:SetBorderColor(o, M.SideTabSelected(tab) and "accent.primary" or "border.subtle") end
            end
        end
    end
end

function M:SkinWorldMap()
    local map = _G.WorldMapFrame
    if not map then return end
    local on = self:IsEnabled() and self.db.worldMap and true or false
    local border = map.BorderFrame
    if border then
        if on then M.SkinWindow(border, false) else M.UnskinWindow(border) end
    end
    local qm = _G.QuestMapFrame
    if qm then
        if on and not logPanel then
            logPanel = CreateFrame("Frame", nil, qm)
            logPanel:SetAllPoints()
            logPanel:SetFrameLevel(math.max(0, qm:GetFrameLevel() - 1))
            Skin:Register(logPanel, function(self) Skin:Panel(self, "sunken", { border = "border.subtle" }) end)
        end
        if logPanel then logPanel:SetShown(on) end
        if qm.Background then
            if on then Skin:HideRegion(qm.Background) else Skin:Restore(qm.Background) end
        end
    end
    paintSideTabs(on)
    self:SkinQuestCards()
end

---------------------------------------------------------------- quest log cards
--[[ Quest log headers as cards: campaign headers get a raised Phoenix card with an accent bar on the left,
    zone / side headers a sunken card; their text in the accent. Cards are frames of ours under Blizzard's
    header buttons (post-hook of QuestLogQuests_Update); quest rows and clicks stay Blizzard's. ]]
M.QUEST_POOLS = { campaign = "campaignHeaderFramePool", campaignMinimal = "campaignHeaderMinimalFramePool",
    header = "headerFramePool", covenant = "covenantCallingsHeaderFramePool" }
local cards = setmetatable({}, { __mode = "k" })

function M.QuestCardStyle(kind)
    if kind == "campaign" or kind == "campaignMinimal" then return "raised", true end
    return "sunken", false
end

function M.StyleQuestCard(header, kind, on)
    if not header then return end
    local c = cards[header]
    if not on then if c then c:Hide() end; return end
    if not c then
        c = CreateFrame("Frame", nil, header)
        c:SetPoint("TOPLEFT", 1, -1); c:SetPoint("BOTTOMRIGHT", -1, 1)
        c:SetFrameLevel(math.max(0, header:GetFrameLevel() - 1))
        c.bar = c:CreateTexture(nil, "ARTWORK", nil, 2)
        c.bar:SetTexture(ns.Media.textures.WHITE)
        c.bar:SetPoint("TOPLEFT", 1, -1); c.bar:SetPoint("BOTTOMLEFT", 1, 1); c.bar:SetWidth(3)
        cards[header] = c
    end
    local style, accentBar = M.QuestCardStyle(kind)
    Skin:Panel(c, style, { border = accentBar and "accent.primary" or "border.subtle" })
    Skin:Gradient(c.bar, "VERTICAL", "accent.secondary", "accent.primary")
    c.bar:SetShown(accentBar)
    local fs = header.Text or header.ButtonText or (header.GetFontString and header:GetFontString())
    if fs and fs.SetTextColor then Skin:Text(fs, "heading", "accent.primary") end
    c:Show()
end

function M:SkinQuestCards()
    local sf = _G.QuestScrollFrame
    if not sf then return end
    local on = self:IsEnabled() and self.db.worldMap and true or false
    for kind, key in pairs(self.QUEST_POOLS) do
        local pool = sf[key]
        if pool and pool.EnumerateActive then
            for header in pool:EnumerateActive() do M.StyleQuestCard(header, kind, on) end
        end
    end
    if not on then for _, c in pairs(cards) do c:Hide() end end
end

local mapHooked
function M:SetupWorldMap()
    self:SkinWorldMap()
    local map = _G.WorldMapFrame
    if mapHooked or not map then return end
    mapHooked = true
    map:HookScript("OnShow", function() M:SkinWorldMap() end)
    if _G.QuestLogQuests_Update then hooksecurefunc("QuestLogQuests_Update", function() M:SkinQuestCards() end) end
    ns.Events:Listen("PUI_THEME_CHANGED", SIDE_TABS, function() if map:IsShown() then M:SkinWorldMap() end end)
end
