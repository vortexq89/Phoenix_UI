local _, ns = ...

--[[ Quality of life: small, independent tweaks of Blizzard behaviour. ]]
local M = ns:NewModule("Quality", {
    label = "QUALITY", desc = "QUALITY_DESC", category = "utility", order = 10,
    defaults = { hideTalkingHead = false, filterErrors = false, achievementScreenshot = false },
})

local function talkingHeadHook()
    if M:IsEnabled() and M.db.hideTalkingHead then TalkingHeadFrame:CloseImmediately() end
end

local hooked
function M:OnEnable()
    if not hooked then
        hooksecurefunc(TalkingHeadFrame, "PlayCurrent", talkingHeadHook)
        hooked = true
    end
    -- Error spam (not ready / out of range ...) is muted only while in combat.
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function()
        if self.db.filterErrors then UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE") end
    end)
    ns.Events:On("PLAYER_REGEN_ENABLED", self, function() UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE") end)
    ns.Events:On("ACHIEVEMENT_EARNED", self, function()
        if self.db.achievementScreenshot then C_Timer.After(1, Screenshot) end
    end)
end

function M:OnDisable()
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
end
