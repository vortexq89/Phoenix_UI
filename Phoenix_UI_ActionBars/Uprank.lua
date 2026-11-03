local _, ns = ...
local L = ns.L
local M = ns.modules.ActionBars

--[[ Auto uprank (WoW Forever: spells have ranks). When you learn a new rank of a spell, every action slot that
    holds an older rank of it gets the new one: the slot is picked up and placed again with the new rank, out of
    combat only (a learn in combat waits for PLAYER_REGEN_ENABLED), and only while the cursor is empty so nothing
    you are dragging is lost. One chat line says how many slots changed. Works with Phoenix and Blizzard bars
    alike (the action slots are the same). ]]

local OWNER = {}
local MAX_SLOT = 180
local queue = {}

-- The slots holding another spell of the same name as `newID`: { slot, … }.
function M.UprankSlots(newID, nameOf, actionOf, maxSlot)
    local name = nameOf(newID)
    local out = {}
    if type(name) ~= "string" or name == "" then return out end
    for slot = 1, maxSlot or MAX_SLOT do
        local kind, id = actionOf(slot)
        if kind == "spell" and type(id) == "number" and id ~= newID and nameOf(id) == name then out[#out + 1] = slot end
    end
    return out
end

local function spellName(id) return C_Spell.GetSpellName(id) end

function M:Uprank(newID)
    if not (self:IsEnabled() and self.db.uprank and ns:Supports("uprank")) or type(newID) ~= "number" then return 0 end
    if InCombatLockdown() or GetCursorInfo() then queue[newID] = true; return 0 end
    local slots = M.UprankSlots(newID, spellName, GetActionInfo)
    for _, slot in ipairs(slots) do
        C_Spell.PickupSpell(newID)
        PlaceAction(slot)
        ClearCursor()
    end
    if #slots > 0 then ns:Print(L.AB_UPRANKED:format(C_Spell.GetSpellLink(newID) or spellName(newID) or "?", #slots)) end
    return #slots
end

function M:SetupUprank()
    if self.uprankHooked or not ns:Supports("uprank") then return end
    self.uprankHooked = true
    ns.Events:On("LEARNED_SPELL_IN_SKILL_LINE", OWNER, function(_, _, spellID) M:Uprank(spellID) end)
    ns.Events:On("PLAYER_REGEN_ENABLED", OWNER, function()
        local ids = queue
        queue = {}
        for id in pairs(ids) do M:Uprank(id) end
    end)
end
