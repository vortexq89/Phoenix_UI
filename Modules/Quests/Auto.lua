local _, ns = ...
local M = ns.modules.Quests
local L = ns.L

--[[ Quest automation: accept offered quests and hand in finished ones as the quest dialogs open. Hold
    Shift while talking to an NPC to do it yourself. Never pays gold (quests that ask for money are left to
    you), never picks a reward unless "Choose reward" is set: by vendor value, or by your latest Sim result
    (retail; falls back to vendor value for items you have not simmed). Plain quest-dialog API calls made
    in response to their own events. ]]
M.REWARDS = { "off", "vendor", "sim" }

local function paused() return IsShiftKeyDown() end

local function trivialOK(info)
    return not (M.db.hideTrivial and info and info.isTrivial)
end

-- Gossip window: hand in the first finished quest, else take the first available one.
local function onGossip()
    local db = M.db
    if paused() then return end
    if db.autoTurnIn then
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if q.isComplete and type(q.questID) == "number" then
                C_GossipInfo.SelectActiveQuest(q.questID)
                return
            end
        end
    end
    if db.autoAccept then
        for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            if type(q.questID) == "number" and trivialOK(q) then
                C_GossipInfo.SelectAvailableQuest(q.questID)
                return
            end
        end
    end
end

-- Old-style quest greeting (several quests, no gossip).
local function onGreeting()
    local db = M.db
    if paused() then return end
    if db.autoTurnIn then
        for i = 1, tonumber((GetNumActiveQuests())) or 0 do
            local _, isComplete = GetActiveTitle(i)
            if isComplete then SelectActiveQuest(i) return end
        end
    end
    if db.autoAccept then
        for i = 1, tonumber((GetNumAvailableQuests())) or 0 do
            local isTrivial = GetAvailableQuestInfo(i)
            if not (db.hideTrivial and isTrivial) then SelectAvailableQuest(i) return end
        end
    end
end

local function onDetail()
    if not M.db.autoAccept or paused() then return end
    if QuestGetAutoAccept() then AcknowledgeAutoAcceptQuest() else AcceptQuest() end
end

local function onProgress()
    if not M.db.autoTurnIn or paused() then return end
    if IsQuestCompletable() and GetQuestMoneyToGet() == 0 then CompleteQuest() end
end

-- Index of the reward to take, or nil to leave the choice to you.
function M:PickReward()
    local n = tonumber((GetNumQuestChoices())) or 0
    if n <= 1 then return n end
    local mode = self.db.reward
    if mode == "off" then return nil end
    local Sim = ns.modules.Sim
    if mode == "sim" and ns:Supports("sim") and Sim and Sim.active then
        local best, bestPct
        for i = 1, n do
            local r = Sim:ItemResult(GetQuestItemLink("choice", i))
            if r and (not bestPct or r.pct > bestPct) then best, bestPct = i, r.pct end
        end
        if best and bestPct > 0 then return best end
    end
    return M.BestVendorReward(n)
end

-- The choice worth the most at a vendor (price x count), or nil while any of them is not cached yet.
function M.BestVendorReward(n)
    local best, bestValue = nil, -1
    for i = 1, n do
        local link = GetQuestItemLink("choice", i)
        local _, _, count = GetQuestItemInfo("choice", i)
        local price = link and select(11, C_Item.GetItemInfo(link))
        if type(price) ~= "number" then return nil end -- item not cached yet: let the player choose
        local value = price * (type(count) == "number" and count or 1)
        if value > bestValue then best, bestValue = i, value end
    end
    return best
end

---------------------------------------------------------------- reward value marker
-- A small coin on the quest reward worth the most at a vendor (shown whenever there is a choice; works without
-- auto turn-in). The reward buttons and their item icons stay Blizzard's; the coin is our own texture on top.
local mark
local function rewardButton(i)
    local rf = QuestInfoRewardsFrame
    local list = rf and rf.RewardButtons
    return list and list[i] or _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
end

function M:HideRewardMark() if mark then mark:Hide() end end

function M:MarkReward()
    self:HideRewardMark()
    if not self.db.rewardMark then return end
    local n = tonumber((GetNumQuestChoices())) or 0
    if n < 2 then return end
    local best = M.BestVendorReward(n)
    local b = best and rewardButton(best)
    if not b then return end
    if not mark then
        mark = CreateFrame("Frame")
        mark:SetSize(18, 18)
        mark.tex = mark:CreateTexture(nil, "OVERLAY")
        mark.tex:SetAllPoints()
        local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-junkcoin")
        if atlas then mark.tex:SetAtlas("bags-junkcoin") else
            mark.tex:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon") end
    end
    mark:SetParent(b)
    mark:SetFrameLevel(b:GetFrameLevel() + 5)
    mark:ClearAllPoints()
    mark:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4)
    mark:Show()
    return b
end

local function onComplete()
    M:MarkReward()
    if not M.db.autoTurnIn or paused() then return end
    local pick = M:PickReward()
    if pick == nil then return end
    if (tonumber((GetNumQuestChoices())) or 0) > 1 then
        ns:Print(L.QUESTS_PICKED:format(GetQuestItemLink("choice", pick) or "?"))
    end
    GetQuestReward(pick)
end

function M:EnableAuto()
    ns.Events:On("GOSSIP_SHOW", self, onGossip)
    ns.Events:On("QUEST_GREETING", self, onGreeting)
    ns.Events:On("QUEST_DETAIL", self, onDetail)
    ns.Events:On("QUEST_PROGRESS", self, onProgress)
    ns.Events:On("QUEST_COMPLETE", self, onComplete)
    ns.Events:On("QUEST_FINISHED", self, function() M:HideRewardMark() end)
    ns.Events:On("GET_ITEM_INFO_RECEIVED", self, function()
        if mark and QuestFrame and QuestFrame:IsShown() then M:MarkReward() end
    end)
end
