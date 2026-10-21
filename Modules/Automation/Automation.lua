local _, ns = ...
local L = ns.L
local Secret = ns.Secret

--[[ Automation: optional one-click chores. Every action is a plain, unprotected API call made in
    response to its own event; nothing runs in combat that Blizzard restricts. ]]
local M = ns:NewModule("Automation", {
    label = "AUTOMATION", desc = "AUTOMATION_DESC", category = "utility", order = 20,
    defaults = {
        repair = "player", sellJunk = true, fillDelete = true, declineDuels = false, acceptInvites = false,
        acceptResurrect = false, autoRelease = false, skipCinematics = false,
    },
})

-- GetGuildBankWithdrawMoney returns -1 when the withdrawal limit is unlimited (guild master).
local function guildCanPay(cost)
    if not (IsInGuild() and CanGuildBankRepair()) then return false end
    local limit = GetGuildBankWithdrawMoney()
    return limit < 0 or limit >= cost
end

local function onMerchant(self)
    local db = self.db
    if db.sellJunk and C_MerchantFrame.GetNumJunkItems() > 0 then
        C_MerchantFrame.SellAllJunkItems()
        ns:Print(L.AUTO_SOLD_JUNK)
    end
    if db.repair ~= "off" and CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost > 0 then
            local guild = db.repair == "guild" and guildCanPay(cost)
            if guild or GetMoney() >= cost then
                RepairAllItems(guild)
                ns:Print(guild and L.AUTO_REPAIRED_GUILD or L.AUTO_REPAIRED, C_CurrencyInfo.GetCoinTextureString(cost))
            end
        end
    end
end

-- Only accept from people we know. The GUID may be secret while restrictions are active: then do nothing.
local function isKnown(guid)
    if not guid or Secret.IsSecret(guid) then return false end
    return C_FriendList.IsFriend(guid) or IsGuildMember(guid) or C_BattleNet.GetAccountInfoByGUID(guid) ~= nil
end

local DELETE_POPUPS = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
local function onPopup(which)
    if not (M:IsEnabled() and M.db.fillDelete and DELETE_POPUPS[which]) then return end
    local dialog = StaticPopup_FindVisible(which)
    local box = dialog and dialog:GetEditBox()
    if box then box:SetText(DELETE_ITEM_CONFIRM_STRING) end
end

local hooked
function M:OnEnable()
    if not hooked then
        hooked = true
        hooksecurefunc("StaticPopup_Show", onPopup)
    end
    ns.Events:On("MERCHANT_SHOW", self, onMerchant)
    ns.Events:On("DUEL_REQUESTED", self, function()
        if self.db.declineDuels then
            CancelDuel()
            StaticPopup_Hide("DUEL_REQUESTED")
        end
    end)
    ns.Events:On("PARTY_INVITE_REQUEST", self, function(_, _, _, _, _, _, _, _, inviterGUID)
        if self.db.acceptInvites and isKnown(inviterGUID) then
            AcceptGroup()
            StaticPopup_Hide("PARTY_INVITE")
        end
    end)
    ns.Events:On("RESURRECT_REQUEST", self, function()
        if self.db.acceptResurrect and not InCombatLockdown() then AcceptResurrect() end
    end)
    ns.Events:On("PLAYER_DEAD", self, function()
        if not self.db.autoRelease or not C_PvP.IsBattleground() then return end
        local options = C_DeathInfo.GetSelfResurrectOptions()
        if not options or #options == 0 then RepopMe() end
    end)
    ns.Events:On("CINEMATIC_START", self, function()
        if not self.db.skipCinematics or IsShiftKeyDown() then return end
        C_Timer.After(0.1, function()
            if CinematicFrame.isRealCinematic then StopCinematic() elseif CanCancelScene() then CancelScene() end
        end)
    end)
    ns.Events:On("PLAY_MOVIE", self, function()
        if self.db.skipCinematics and not IsShiftKeyDown() and MovieFrame:IsShown() then MovieFrame:StopMovie() end
    end)
end
