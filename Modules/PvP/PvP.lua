local _, ns = ...
local L = ns.L
local Skin = ns.Skin

--[[ PvP: safer queue pops (no accidental "Leave Queue", visible timer), TAB targets enemy players
    inside arenas/battlegrounds, and /gg to surrender an arena. Arena dampening display was removed:
    it relied on combat-log/aura data that 12.x restricts. ]]
local M = ns:NewModule("PvP", {
    label = "PVP", desc = "PVP_DESC", category = "combat", order = 50, reloadOnToggle = true,
    defaults = { safeQueue = true, tabBinder = false, surrender = true },
})

---------------------------------------------------------------- safe queue
local timer
local function ensureTimer()
    if timer then return timer end
    timer = CreateFrame("Frame", nil, PVPReadyDialog)
    timer:SetSize(120, 18)
    timer:SetPoint("TOP", PVPReadyDialog, "BOTTOM", 0, -4)
    timer.text = timer:CreateFontString(nil, "OVERLAY")
    timer.text:SetPoint("CENTER", 9, 0)
    timer.icon = ns.Icons:Create(timer, "clock", 14, "accent.primary", "OVERLAY")
    timer.icon:SetPoint("RIGHT", timer.text, "LEFT", -5, 0)
    Skin:Text(timer.text, "number", "accent.primary", 14, "OUTLINE")
    timer:SetScript("OnUpdate", function(self, elapsed)
        self.acc = (self.acc or 0) + elapsed
        if self.acc < 0.2 then return end
        self.acc = 0
        local index = PVPReadyDialog.activeIndex
        local left = index and GetBattlefieldPortExpiration(index)
        if left and left > 0 then self.text:SetFormattedText(L.PVP_TIME_LEFT, left) else self.text:SetText("") end
    end)
    return timer
end

-- Runs after PVPReadyDialog_Display has laid out the buttons, so the Enter button is re-centred the
-- same way Blizzard does it for queues that never offer "Leave Queue".
local function onDisplay(dialog)
    if not (M:IsEnabled() and M.db.safeQueue) then return end
    dialog.leaveButton:Hide()
    dialog.enterButton:ClearAllPoints()
    dialog.enterButton:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 25)
    ensureTimer():Show()
end

---------------------------------------------------------------- TAB binder
local TAB = "TAB"
local SAFE = { TARGETNEARESTENEMY = true, TARGETNEARESTENEMYPLAYER = true }

local function applyTab()
    if not M.db.tabBinder then return end
    local current = GetBindingAction(TAB)
    if current ~= "" and not SAFE[current] then return end -- never overwrite a custom bind
    local _, instanceType = IsInInstance()
    local want = (instanceType == "arena" or instanceType == "pvp") and "TARGETNEARESTENEMYPLAYER" or "TARGETNEARESTENEMY"
    if current ~= want then
        SetBinding(TAB, want)
        SaveBindings(GetCurrentBindingSet())
    end
end

---------------------------------------------------------------- surrender
local function surrender()
    if not M.db.surrender then return end
    if IsActiveBattlefieldArena() and C_PvP.CanSurrenderArena() then
        ConfirmSurrenderArena()
    else
        ns:Print(L.PVP_CANT_SURRENDER)
    end
end

-- reloadOnToggle: OnEnable runs at most once per session.
function M:OnEnable()
    hooksecurefunc("PVPReadyDialog_Display", onDisplay)
    RegisterNewSlashCommand(surrender, "gg", "pvpgg")
    local function deferTab() ns.Combat:Run("pvp.tab", applyTab) end
    ns.Events:On("PLAYER_ENTERING_WORLD", self, deferTab)
    ns.Events:On("ZONE_CHANGED_NEW_AREA", self, deferTab)
end

function M:Refresh()
    ns.Combat:Run("pvp.tab", applyTab)
end
