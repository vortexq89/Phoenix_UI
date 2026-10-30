local _, ns = ...
local L = ns.L
local M = ns:GetModule("Quests")

--[[ Quest progress feedback (Questie reference: objective sounds and progress announce). The quest log's objectives
    are compared with the last look after each QUEST_LOG_UPDATE (batched, one look per 0.3 s): a sound when an
    objective is done and another when a quest is ready to turn in, and, if you ask for it, the step in party chat
    ("[PUI] Quest: 5/8 Boars slain"). Party chat is only used in a home party outside instances and never during a
    chat lockdown. The first look after login and newly accepted quests are only remembered, never announced. ]]

local OBJECTIVE_SOUND, COMPLETE_SOUND = SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01, SOUNDKIT.IG_QUEST_LIST_COMPLETE
local seen, primed, queued = {}, false, false

-- One quest's state: { complete, objectives = { { done, n, text } } }.
local function stateOf(questID)
    local objs = C_QuestLog.GetQuestObjectives(questID) or {}
    local st = { complete = C_QuestLog.IsComplete(questID) and true or false, objectives = {} }
    for i, o in ipairs(objs) do
        st.objectives[i] = { done = o.finished and true or false, n = tonumber(o.numFulfilled) or 0, text = o.text }
    end
    return st
end

-- Pure: what changed between two states. Returns a list of { kind = "step" | "done" | "complete", text }.
function M.QuestChanges(old, new)
    local out = {}
    if not (old and new) then return out end
    for i, o in ipairs(new.objectives) do
        local p = old.objectives[i]
        if p and o.done and not p.done then
            out[#out + 1] = { kind = "done", text = o.text }
        elseif p and o.n > p.n then
            out[#out + 1] = { kind = "step", text = o.text }
        end
    end
    if new.complete and not old.complete then out[#out + 1] = { kind = "complete" } end
    return out
end

local function canAnnounce()
    if M.db.progressAnnounce ~= "party" then return false end
    if not IsInGroup() or IsInRaid() or IsInInstance() then return false end
    return not (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
end

local function report(questID, changes)
    local title = C_QuestLog.GetTitleForQuestID(questID) or ""
    local sound
    for _, c in ipairs(changes) do
        if c.kind == "complete" then sound = COMPLETE_SOUND elseif c.kind == "done" then sound = sound or OBJECTIVE_SOUND end
        if canAnnounce() and type(c.text) == "string" and c.text ~= "" then
            C_ChatInfo.SendChatMessage(L.QUESTS_PROGRESS_LINE:format(title, c.text), "PARTY")
        elseif canAnnounce() and c.kind == "complete" then
            C_ChatInfo.SendChatMessage(L.QUESTS_PROGRESS_LINE:format(title, L.QUESTS_PROGRESS_COMPLETE), "PARTY")
        end
    end
    if sound and M.db.progressSound then PlaySound(sound, "Master") end
end

local function look()
    queued = false
    if not (M:IsEnabled() and (M.db.progressSound or M.db.progressAnnounce ~= "off")) then return end
    local now = {}
    for i = 1, tonumber(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            local st = stateOf(info.questID)
            now[info.questID] = st
            if primed and seen[info.questID] then
                local changes = M.QuestChanges(seen[info.questID], st)
                if #changes > 0 then report(info.questID, changes) end
            end
        end
    end
    seen, primed = now, true
end
M.LookQuestProgress = look

function M:SetupProgress()
    if self.progressHooked then return end
    self.progressHooked = true
    local owner = {}
    ns.Events:On("QUEST_LOG_UPDATE", owner, function()
        if queued then return end
        queued = true
        C_Timer.After(0.3, look)
    end)
end
