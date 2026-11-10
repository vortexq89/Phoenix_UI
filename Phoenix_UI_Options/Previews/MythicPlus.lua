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


-- The run timer, drawn by MythicPlus:StyleTimer and its renderer on a sample run.
P:Register("mplustimer", {
    module = "MythicPlus",
    width = 460,
    height = 260,
    build = function(stage, m)
        local f, redraw = m:BuildTimerPreview(stage)
        local keys = m.Keystones:NewList(stage)
        keys:SetSize(170, keys.height)
        local rows = {}
        for i, s in ipairs(SAMPLE) do
            rows[i] = { name = L[s.sample], class = s.class, level = s.level, rating = s.rating, dungeon = s.dungeon }
        end
        return function(self)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -8)
            redraw()
            P.Hot(self, f, "width", L.MPLUS_TIMER_WIDTH)
            keys:ClearAllPoints()
            keys:SetPoint("TOPLEFT", f, "TOPRIGHT", 14, -4)
            keys:SetShown(m.db.partyKeys and m.db.keysWindow)
            if keys:IsShown() then m.Keystones:Paint(keys, rows) end
        end
    end,
})
