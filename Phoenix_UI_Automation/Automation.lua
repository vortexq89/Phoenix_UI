local _, ns = ...
local L = ns.L
local Secret = ns.Secret

--[[ Automation: optional one-click chores. Every action is a plain, unprotected API call made in
    response to its own event; nothing runs in combat that Blizzard restricts.
    S16: faster auto loot (LOOT_READY loots every slot when the game's auto loot applies), bind-on-pickup
    confirm while solo, single gossip option pick (only when the NPC offers no quests, which the Quests page
    automates; Shift pauses), pet battle duel and guild invite decline, and a low health sound played when
    Blizzard's own low health flash shows (we only hook its OnShow). Role checks live on Group Finder. ]]
local M = ns:NewModule("Automation", {
    label = "AUTOMATION", desc = "AUTOMATION_DESC", category = "utility", order = 20,
    defaults = {
        repair = "player", sellJunk = true, fillDelete = true,
        bulkBuy = true, rareAlert = true, alreadyKnown = true, undercut = false, declineDuels = false, acceptInvites = false,
        acceptResurrect = false, autoRelease = false, skipCinematics = false,
        fastLoot = false, confirmBoP = false, gossip = false, declinePetDuels = false, declineGuild = false,
        lowHealth = false, lowHealthSound = "AlertOnYou",
        mountFlyer = "", mountGround = "", mountSwimmer = "", -- PUI Mount rules (Macros.lua)
        petSummon = false, petMode = "favorite", -- auto summon pet (PetSummon.lua)
        fishing = true, fishingQuiet = true, -- fishing helper (Fishing.lua)
        junkWindow = true, -- junk window at vendors (Junk.lua)
        autoLog = false, autoLogMplus = true, autoLogRaid = true, autoLogDungeon = false, -- AutoLog.lua
        lootCouncil = false, lootCouncilOpen = true, lootCouncilRaidOnly = true, -- LootCouncil.lua
    },
    -- per character: the last companion pet and whether you put it away (PetSummon.lua)
    globalDefaults = { pets = {} },
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

---------------------------------------------------------------- S16
-- Auto loot applies when the CVar is on and the modifier is up, or the CVar is off and the modifier held.
function M.WantsAutoLoot(cvarOn, modifierDown)
    return (cvarOn and not modifierDown) or (not cvarOn and modifierDown) or false
end

local lootAt = 0
local function onLootReady()
    local db = M.db
    if not db.fastLoot or GetTime() - lootAt < 0.3 then return end
    if not M.WantsAutoLoot(GetCVarBool("autoLootDefault"), IsModifiedClick("AUTOLOOTTOGGLE")) then return end
    lootAt = GetTime()
    for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
end

local function onBindConfirm(_, _, slot)
    if M.db.confirmBoP and not IsInGroup() and type(slot) == "number" then
        ConfirmLootSlot(slot)
        StaticPopup_Hide("LOOT_BIND")
    end
end

-- One plain gossip option and no quests: pick it. Quests are left to the Quests page's automation.
function M.SingleGossip(options, available, active)
    if #(available or {}) > 0 or #(active or {}) > 0 then return nil end
    if #(options or {}) ~= 1 then return nil end
    local o = options[1]
    return type(o.gossipOptionID) == "number" and o.gossipOptionID or nil
end

local function onGossip()
    if not M.db.gossip or IsShiftKeyDown() then return end
    local id = M.SingleGossip(C_GossipInfo.GetOptions(), C_GossipInfo.GetAvailableQuests(), C_GossipInfo.GetActiveQuests())
    if id then C_GossipInfo.SelectOption(id) end
end

local healthAt = 0
local function onLowHealth()
    if not (M:IsEnabled() and M.db.lowHealth) or GetUIPanel("fullscreen") or GetTime() - healthAt < 8 then return end
    healthAt = GetTime()
    ns.Media:PlaySound(M.db.lowHealthSound)
end

local function enableS16(self)
    ns.Events:On("LOOT_READY", self, onLootReady)
    ns.Events:On("LOOT_BIND_CONFIRM", self, onBindConfirm)
    ns.Events:On("GOSSIP_SHOW", self, onGossip)
    ns.Events:On("PET_BATTLE_PVP_DUEL_REQUESTED", self, function()
        if self.db.declinePetDuels and C_PetBattles then
            C_PetBattles.CancelPVPDuel()
            StaticPopup_Hide("PET_BATTLE_PVP_DUEL_REQUESTED")
        end
    end)
    ns.Events:On("GUILD_INVITE_REQUEST", self, function()
        if self.db.declineGuild then
            DeclineGuild() -- the invite frame closes on GUILD_INVITE_CANCEL
        end
    end)
end

local hooked
function M:OnEnable()
    self:SetupBulkBuy() -- BulkBuy.lua
    self:SetupRareAlert() -- RareAlert.lua
    self:SetupAlreadyKnown() -- AlreadyKnown.lua
    self:SetupUndercut() -- Undercut.lua
    self:SetupPetSummon() -- PetSummon.lua
    self:SetupFishing() -- Fishing.lua
    self:SetupJunk() -- Junk.lua
    self:EnableAutoLog() -- AutoLog.lua
    self:EnableLootCouncil() -- LootCouncil.lua
    if not hooked then
        hooked = true
        hooksecurefunc("StaticPopup_Show", onPopup)
        if LowHealthFrame then LowHealthFrame:HookScript("OnShow", onLowHealth) end
    end
    enableS16(self)
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
