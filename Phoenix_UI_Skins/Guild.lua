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
    for i, path in ipairs(self.GUILD_LISTS) do
        local rail = i == 1
        M.KitScrollBox(M.FramePath(cf, path), on, function(row, o)
            M.KitRow(row, o, { alpha = 0.4 })
            if rail then M.AvatarRing(row, o) end
        end)
    end
    M.KitCard(cf.Chat, isOn, "sunken", false)
    M.KitCard(cf.ChatEditBox, isOn, "sunken", true)
end

-- Community rail avatars: a round accent ring around each community's own icon (the icon is untouched).
local avatarRings = setmetatable({}, { __mode = "k" })
function M.AvatarRing(row, isOn)
    local icon = type(row) == "table" and (rawget(row, "Icon") or rawget(row, "CircleMask") and rawget(row, "Icon"))
    if type(icon) ~= "table" or not icon.GetObjectType then return end
    local ring = avatarRings[row]
    if not isOn then if ring then ring:Hide() end; return end
    if not ring then
        ring = row:CreateTexture(nil, "OVERLAY", nil, 6)
        ring:SetTexture(ns.Media.textures.RING_CIRCLE)
        ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2); ring:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
        avatarRings[row] = ring
    end
    local sel = M.RowSelected(row)
    ns.Widgets.Color(ring, sel and "accent.primary" or "border.subtle", 1)
    ring:Show()
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
