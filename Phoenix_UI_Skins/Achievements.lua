local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Achievements, skins plan window 15: category rail, achievement rows (points in the accent), stats and
    comparison lists as Phoenix rows, summary bars in the theme texture, the summary on a sunken card.
    Achievement icons and shields are the game's own; tracking and linking stay Blizzard's clicks.
    Live both ways with its Skins switch, repainted on theme change (kit rows / cards). ]]

local function on() return M:IsEnabled() and M.db.achievements and true or false end

M.ACHIEVEMENT_LISTS = { "AchievementFrameCategories", "AchievementFrameAchievements", "AchievementFrameStats",
    "AchievementFrameComparison" }

-- Points badge on an achievement row: the points number in the accent (the shield art stays the game's).
function M.AchievementRow(row, isOn)
    M.KitRow(row, isOn, { alpha = 0.45 })
    local shield = type(row) == "table" and rawget(row, "Shield")
    local pts = type(shield) == "table" and rawget(shield, "Points")
    if type(pts) == "table" and pts.SetTextColor then
        if isOn then ns.Skin:Text(pts, "number", "accent.primary") else ns.Skin:Restore(pts) end
    end
end

function M:SkinAchievements()
    if not _G.AchievementFrame then return end
    local isOn = on()
    for _, name in ipairs(self.ACHIEVEMENT_LISTS) do
        local f = _G[name]
        if f then M.KitScrollBox(M.FramePath(f, { "ScrollBox" }), on, M.AchievementRow) end
    end
    for _, name in ipairs({ "AchievementFrameSummaryCategoriesStatusBar", "AchievementFrameComparisonSummaryPlayerStatusBar" }) do
        local bar = _G[name]
        if type(bar) == "table" and bar.SetStatusBarTexture then
            if isOn then ns.Skin:StatusBar(bar, { border = "border.subtle" }) else ns.Skin:Restore(bar) end
        end
    end
    M.KitCard(_G.AchievementFrameSummary, isOn, "sunken", false)
end

local achievementsHooked
function M:SetupAchievements()
    self:SkinAchievements()
    local root = _G.AchievementFrame
    if achievementsHooked or not root then return end
    achievementsHooked = true
    root:HookScript("OnShow", function() M:SkinAchievements() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupAchievements"
M.RESKINS[#M.RESKINS + 1] = "SkinAchievements"
