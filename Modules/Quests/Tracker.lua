local _, ns = ...
local M = ns.modules.Quests
local Skin, Media, Theme = ns.Skin, ns.Media, ns.Theme

--[[ Objective tracker restyle. Blizzard_ObjectiveTracker stays Blizzard's: we restyle its font objects
    (ObjectiveTrackerHeaderFont for module headers, ObjectiveTrackerLineFont for objectives), dress quest
    titles and progress bars after each module's layout (a hooksecurefunc post-hook, so Blizzard's own code
    keeps its secure state), and change width, height and collapse only out of combat. ]]
local MODULES = {
    "CampaignQuestObjectiveTracker", "QuestObjectiveTracker", "WorldQuestObjectiveTracker", "BonusObjectiveTracker",
    "AchievementObjectiveTracker", "ScenarioObjectiveTracker", "ProfessionsRecipeTracker",
    "MonthlyActivitiesObjectiveTracker", "AdventureObjectiveTracker", "InitiativeTasksObjectiveTracker",
}
local QUEST_MODULES = { CampaignQuestObjectiveTracker = true, QuestObjectiveTracker = true }
local nameOf = setmetatable({}, { __mode = "k" }) -- module frame -> its global name (never written onto Blizzard frames)

local OUTLINES = { NONE = "", OUTLINE = "OUTLINE", THICK = "THICKOUTLINE", MONO = "MONOCHROME,OUTLINE" }

-- A Font object (not a FontString): only its face, size and outline; colour stays per line.
local function setFontObject(font, spec, role)
    if not (font and font.SetFont) then return end
    local path, size = Theme:Font(role, spec.size)
    if spec.font and spec.font ~= "" then path = Media:Font(spec.font) end
    font:SetFont(path, size, OUTLINES[spec.outline] or "")
    if spec.shadow then font:SetShadowOffset(1, -1) else font:SetShadowOffset(0, 0) end
end

-- Quest tag letters after the level: [42+] elite, [42G] group, [42D] dungeon, [42R] raid, [42!] daily.
local TAG_LETTER = {}
do
    local T = Enum and Enum.QuestTag
    if type(T) == "table" then
        for name, letter in pairs({ Group = "G", Dungeon = "D", Raid = "R", Heroic = "H", PvP = "P", Scenario = "S",
            Delve = "V", Legendary = "L" }) do
            if type(T[name]) == "number" then TAG_LETTER[T[name]] = letter end
        end
    end
end

function M.LevelTag(questID)
    local level = C_QuestLog.GetQuestDifficultyLevel(questID)
    if type(level) ~= "number" or level <= 0 then return nil, nil end
    local tag = ""
    local info = C_QuestLog.GetQuestTagInfo(questID)
    if type(info) == "table" then
        if info.isElite then tag = "+" end
        tag = tag .. (TAG_LETTER[info.tagID] or "")
    end
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    local entry = index and C_QuestLog.GetInfo(index)
    if entry and Enum.QuestFrequency and entry.frequency == Enum.QuestFrequency.Daily then tag = tag .. "!" end
    return ("[%d%s] "):format(level, tag), level
end

local function dressBlock(module, block)
    local db = M.db
    local header = block.HeaderText
    local questID = QUEST_MODULES[nameOf[module]] and type(block.id) == "number" and block.id or nil
    if header and header.GetText then
        Skin:TextSpec(header, db.header, "heading", nil)
        if questID then
            local text = header:GetText()
            local prefix, level = M.LevelTag(questID)
            if db.level and prefix and type(text) == "string" and text:sub(1, #prefix) ~= prefix then
                header:SetText(prefix .. text)
            end
            if db.difficulty and level and GetQuestDifficultyColor and not block.isHighlighted then
                local c = GetQuestDifficultyColor(level)
                if c then header:SetTextColor(c.r, c.g, c.b) end
            elseif type(db.header.color) == "table" then
                header:SetTextColor(Skin:SpecColor(db.header.color))
            end
        end
    end
    if block.ForEachUsedLine then
        block:ForEachUsedLine(function(line)
            if type(db.objective.color) == "table" and line.Text and not line.puiDone then
                line.Text:SetTextColor(Skin:SpecColor(db.objective.color))
            end
            local bar = line.progressBar and line.progressBar.Bar
            if bar and bar.SetStatusBarTexture then
                bar:SetStatusBarTexture(db.bar ~= "" and Media:Bar(db.bar) or Theme:Bar())
            end
        end)
    end
end

local function dressModule(module)
    if not (M:IsEnabled() and M.db.restyle) then return end
    if module.Header and module.Header.Text then Skin:TextSpec(module.Header.Text, M.db.header, "heading", "accent.primary") end
    if module.EnumerateActiveBlocks then
        module:EnumerateActiveBlocks(function(block) dressBlock(module, block) end)
    end
end

-- Quest title click: Blizzard opens the quest; we also make it the super-tracked quest (arrow target).
local function onHeaderClick(_, block, button)
    if not (M:IsEnabled() and M.db.superTrack) or button == "RightButton" or IsModifierKeyDown() then return end
    if type(block.id) == "number" then C_SuperTrack.SetSuperTrackedQuestID(block.id) end
end

local blizzardWidth -- the tracker's own width, restored when the width option goes back to 0
local function applySize()
    local f = ObjectiveTrackerFrame
    if not f or InCombatLockdown() then return end
    local db = M.db
    if db.restyle and db.width > 0 then
        blizzardWidth = blizzardWidth or f:GetWidth()
        f:SetWidth(db.width)
    elseif blizzardWidth then
        f:SetWidth(blizzardWidth)
        blizzardWidth = nil
    end
    if db.restyle and db.maxHeight > 0 and f:GetHeight() > db.maxHeight then f:SetHeight(db.maxHeight) end
end

-- Collapse in instances (out of combat), fade in combat (alpha only, so nothing secure moves).
function M:ApplyCollapse()
    local f = ObjectiveTrackerFrame
    if not (f and self:IsEnabled()) then return end
    local mode = self.db.collapse
    ns.Combat:Run("quests.collapse", function()
        local inInstance, kind = IsInInstance()
        local want = (mode == "instance" or mode == "both") and inInstance and kind ~= "none"
        if want and not f:IsCollapsed() then
            f:SetCollapsed(true)
            self.collapsedByUs = true
        elseif not want and self.collapsedByUs then
            if f:IsCollapsed() then f:SetCollapsed(false) end
            self.collapsedByUs = nil
        end
    end)
end

local function onCombat(_, event)
    local f = ObjectiveTrackerFrame
    if not f then return end
    local mode = M.db.collapse
    local fade = (mode == "combat" or mode == "both") and event == "PLAYER_REGEN_DISABLED"
    f:SetAlpha(fade and 0.15 or 1)
end

M.DressModule = function(module) return dressModule(module) end

local trackerHooked
function M:EnableTracker()
    if not ObjectiveTrackerFrame then return end
    if not trackerHooked then
        trackerHooked = true
        for _, name in ipairs(MODULES) do
            local module = _G[name]
            if type(module) == "table" and module.EndLayout then
                nameOf[module] = name
                hooksecurefunc(module, "EndLayout", dressModule)
                if QUEST_MODULES[name] and module.OnBlockHeaderClick then
                    hooksecurefunc(module, "OnBlockHeaderClick", onHeaderClick)
                end
            end
        end
        if ObjectiveTrackerFrame.UpdateHeight then hooksecurefunc(ObjectiveTrackerFrame, "UpdateHeight", applySize) end
    end
    ns.Events:On("PLAYER_REGEN_DISABLED", self, onCombat)
    ns.Events:On("PLAYER_REGEN_ENABLED", self, function(...) onCombat(...); applySize() end)
    ns.Events:On("PLAYER_ENTERING_WORLD", self, function() self:ApplyCollapse() end)
    self:RefreshTracker()
end

function M:RefreshTracker()
    if not (self:IsEnabled() and ObjectiveTrackerFrame) then return end
    if self.db.restyle then
        setFontObject(ObjectiveTrackerHeaderFont, self.db.header, "heading")
        setFontObject(ObjectiveTrackerLineFont, self.db.objective, "body")
        for _, name in ipairs(MODULES) do
            local module = _G[name]
            if type(module) == "table" and module.EnumerateActiveBlocks then dressModule(module) end
        end
    end
    ns.Combat:Run("quests.size", applySize)
    self:ApplyCollapse()
end
