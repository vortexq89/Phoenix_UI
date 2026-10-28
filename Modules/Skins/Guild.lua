local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Guild & communities, skins plan window 13 (window chrome and tabs: shared skin): the community rail as
    Phoenix rows with the open community outlined in the accent, the chat area on a sunken card like the Phoenix
    chat, the roster and the guild news / perks lists as rows. Avatars, class colours and every click stay the
    game's. Live with Skins > Guild & communities. ]]

local function on() return M:IsEnabled() and M.db.communities and true or false end

M.GUILD_LISTS = { { "CommunitiesList", "ScrollBox" }, { "MemberList", "ScrollBox" },
    { "GuildBenefitsFrame", "Perks", "ScrollBox" }, { "GuildBenefitsFrame", "Rewards", "ScrollBox" },
    { "GuildDetailsFrame", "News", "ScrollBox" }, { "ApplicantList", "ScrollBox" } }

function M:SkinGuild()
    local cf = _G.CommunitiesFrame
    if not cf then return end
    local isOn = on()
    for _, path in ipairs(self.GUILD_LISTS) do
        M.KitScrollBox(M.FramePath(cf, path), on, function(row, o) M.KitRow(row, o, { alpha = 0.4 }) end)
    end
    M.KitCard(cf.Chat, isOn, "sunken", false)
    M.KitCard(cf.ChatEditBox, isOn, "sunken", true)
end

local guildHooked
function M:SetupGuild()
    self:SkinGuild()
    local cf = _G.CommunitiesFrame
    if guildHooked or not cf then return end
    guildHooked = true
    cf:HookScript("OnShow", function() M:SkinGuild() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupGuild"
M.RESKINS[#M.RESKINS + 1] = "SkinGuild"
