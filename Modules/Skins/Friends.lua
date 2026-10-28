local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Friends / Who / Quick Join, skins plan window 12 (window chrome and tabs: shared skin): friends, who and
    quick-join lists as Phoenix rows (the selected one outlined in the accent; names keep the game's class
    colours, status and game icons stay the game's), and the add-friend / send-message buttons in Phoenix style.
    Live with Skins > Friends. ]]

local function on() return M:IsEnabled() and M.db.friends and true or false end

M.FRIEND_LISTS = { { "FriendsListFrame", "ScrollBox" }, { "WhoFrame", "ScrollBox" }, { "QuickJoinFrame", "ScrollBox" },
    { "RecruitAFriendFrame", "RecruitList", "ScrollBox" } }

function M:SkinFriends()
    local isOn = on()
    for _, path in ipairs(self.FRIEND_LISTS) do
        M.KitScrollBox(M.FramePath(_G, path), on, function(row, o) M.KitRow(row, o, { alpha = 0.4 }) end)
    end
    M.SkinPopupButton(_G.FriendsFrameAddFriendButton, "primary", isOn)
    M.SkinPopupButton(_G.FriendsFrameSendMessageButton, "secondary", isOn)
    M.SkinPopupButton(_G.WhoFrameWhoButton, "primary", isOn)
end

local friendsHooked
function M:SetupFriends()
    self:SkinFriends()
    local ff = _G.FriendsFrame
    if friendsHooked or not ff then return end
    friendsHooked = true
    ff:HookScript("OnShow", function() M:SkinFriends() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupFriends"
M.RESKINS[#M.RESKINS + 1] = "SkinFriends"
