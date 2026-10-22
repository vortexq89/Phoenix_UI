local _, ns = ...
local L, P = ns.L, ns.Previews

-- The party keystone list with a sample group, painted by MythicPlus.Keystones (the same code as the page).
local SAMPLE = {
    { sample = "PREVIEW_UNIT_PLAYER", class = "MAGE", level = 12, dungeon = L.PREVIEW_KEYS_DUNGEON1, rating = 2875 },
    { sample = "PREVIEW_PARTY_TANK", class = "WARRIOR", level = 14, dungeon = L.PREVIEW_KEYS_DUNGEON2, rating = 3120 },
    { sample = "PREVIEW_PARTY_HEALER", class = "PRIEST", level = 10, dungeon = L.PREVIEW_KEYS_DUNGEON3, rating = 2410 },
    { sample = "PREVIEW_PARTY_DPS1", class = "HUNTER", level = 0, rating = 1980 },
    { sample = "PREVIEW_PARTY_DPS2", class = "ROGUE" },
}

P:Register("keystones", {
    module = "MythicPlus",
    width = 450,
    height = 140,
    build = function(stage, m)
        local K = m.Keystones
        local list = K:NewList(stage)
        list:SetSize(420, list.height)
        list:SetPoint("CENTER")
        local rows = {}
        for i, s in ipairs(SAMPLE) do
            rows[i] = { name = L[s.sample], class = s.class, level = s.level, rating = s.rating,
                dungeon = s.dungeon }
        end
        return function() K:Paint(list, rows) end
    end,
})
