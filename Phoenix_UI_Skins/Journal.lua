local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Adventure Guide, skins plan window 14: instance cards, boss list, loot list and search results as Phoenix
    rows, the encounter page on a sunken card, the suggested-content cards raised (the first in the accent).
    Dungeon art, boss portraits and loot icons are the game's own.
    Live both ways with its Skins switch, repainted on theme change (kit rows / cards). ]]

local function on() return M:IsEnabled() and M.db.journal and true or false end

M.JOURNAL_LISTS = { { "instanceSelect", "ScrollBox" }, { "encounter", "info", "BossesScrollBox" },
    { "encounter", "info", "LootContainer", "ScrollBox" }, { "searchResults", "ScrollBox" } }

function M:SkinJournal()
    local ej = _G.EncounterJournal
    if not ej then return end
    local isOn = on()
    for _, path in ipairs(self.JOURNAL_LISTS) do
        M.KitScrollBox(M.FramePath(ej, path), on, function(row, o) M.KitRow(row, o, { alpha = 0.4 }) end)
    end
    M.KitCard(M.FramePath(ej, { "encounter", "info" }), isOn, "sunken", false)
    M.KitCard(rawget(ej, "searchBox"), isOn, "sunken", false)
    local suggest = _G.EncounterJournalSuggestFrame
    if suggest then
        for i = 1, 3 do M.KitCard(rawget(suggest, "Suggestion" .. i), isOn, "raised", i == 1) end
    end
end

local journalHooked
function M:SetupJournal()
    self:SkinJournal()
    local root = _G.EncounterJournal
    if journalHooked or not root then return end
    journalHooked = true
    root:HookScript("OnShow", function() M:SkinJournal() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupJournal"
M.RESKINS[#M.RESKINS + 1] = "SkinJournal"
