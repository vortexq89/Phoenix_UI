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

-- Skins plan window 5: an accent tick (primary -> secondary) beside each module header; our own texture on
-- the header, hidden again when the restyle is switched off.
local ticks = setmetatable({}, { __mode = "k" })
local function headerTick(module, on)
    local h = module.Header
    if not (h and h.Text and h.CreateTexture) then return end
    local t = ticks[h]
    if not on then if t then t:Hide() end; return end
    if not t then
        t = h:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetTexture(Media.textures.WHITE)
        t:SetSize(2, 12)
        t:SetPoint("RIGHT", h.Text, "LEFT", -4, 0)
        ticks[h] = t
    end
    Skin:Gradient(t, "VERTICAL", "accent.secondary", "accent.primary")
    t:Show()
end
M.HeaderTick = headerTick

-- t146: the headers kept Blizzard's gold header art ("All Objectives" ornament, the secondary header bars),
-- so the restyled tracker still read as Blizzard's. Restyled, that art goes and a 1 px accent line sits under
-- each header instead (EllesmereUI's tracker does the same); switched off, Blizzard's art comes back.
local rules = setmetatable({}, { __mode = "k" })
local function headerArt(h, on)
    if not (h and h.CreateTexture) then return end
    if h.Background then
        if on then Skin:HideRegion(h.Background) else Skin:Restore(h.Background) end
    end
    local t = rules[h]
    if not on then if t then t:Hide() end; return end
    if not t then
        t = h:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetTexture(Media.textures.WHITE)
        t:SetPoint("BOTTOMLEFT", 0, 1)
        t:SetPoint("BOTTOMRIGHT", 0, 1)
        rules[h] = t
    end
    t:SetHeight(PixelUtil.ConvertPixelsToUIForRegion(1, t)) -- one physical pixel
    t:SetVertexColor(Theme:Color("accent.primary"))
    t:SetAlpha(0.45)
    t:Show()
end
M.HeaderArt = headerArt

local function dressModule(module)
    local on = M:IsEnabled() and M.db.restyle
    headerTick(module, on)
    headerArt(module.Header, on)
    if ObjectiveTrackerFrame then headerArt(ObjectiveTrackerFrame.Header, on) end
    if not on then return end
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
local blizzardHeight -- likewise its height, restored when nothing caps it any more

-- t146: Phoenix's right-edge bars (bar4 / bar5, vertical, centred) sat on top of a long quest list. The room
-- from the tracker's top down to the highest shown Phoenix bar it overlaps sideways, in tracker units, or nil.
-- Blizzard's tracker stops adding blocks when it runs out of height, so a shorter tracker just lists less.
function M.RoomAboveBars(f)
    local AB = ns:Loaded("ActionBars")
    if not (AB and AB.GetHeader and AB:IsEnabled() and AB:IsPhoenix()) then return end
    local fs, l, r, top = f:GetEffectiveScale(), f:GetLeft(), f:GetRight(), f:GetTop()
    if not (l and r and top) then return end
    l, r, top = l * fs, r * fs, top * fs
    local room
    for key in pairs(AB.db and AB.db.bars or {}) do
        local h = AB.GetHeader(key)
        if h and h:IsVisible() then
            local hs, hl, hr, ht = h:GetEffectiveScale(), h:GetLeft(), h:GetRight(), h:GetTop()
            if hl and hr and ht then
                hl, hr, ht = hl * hs, hr * hs, ht * hs
                if hl < r and hr > l and ht < top then
                    local gap = (top - ht) / fs - 8
                    if gap >= 120 and (not room or gap < room) then room = gap end
                end
            end
        end
    end
    return room
end

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
    local cap = db.restyle and db.maxHeight > 0 and db.maxHeight or nil
    local room = db.restyle and db.avoidBars ~= false and M.RoomAboveBars(f)
    if room and (not cap or room < cap) then cap = room end
    if cap and f:GetHeight() > cap then
        blizzardHeight = blizzardHeight or f:GetHeight()
        f:SetHeight(cap)
    elseif not cap and blizzardHeight then
        f:SetHeight(blizzardHeight)
        blizzardHeight = nil
    end
end
M.ApplySize = applySize

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
    ns.Events:Listen("PUI_THEME_CHANGED", self, function() self:RefreshTracker() end) -- header ticks follow the accent
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
    else
        for _, name in ipairs(MODULES) do
            local module = _G[name]
            if type(module) == "table" then headerTick(module, false) end
        end
    end
    ns.Combat:Run("quests.size", applySize)
    self:ApplyCollapse()
end
