local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Gossip and quest dialogs, skins plan window 27 (cards: shared dialog skin): gossip options and the quest
    greeting list as Phoenix rows with an accent bullet, Accept / Complete / Continue as primary buttons and
    Decline / Goodbye as secondary. Quest text, rewards and NPC portraits are the game's own; choosing an
    option stays Blizzard's click. Live with Skins > Gossip. ]]

local function on() return M:IsEnabled() and M.db.gossip and true or false end

local bullets = setmetatable({}, { __mode = "k" })
function M.GossipBullet(row, isOn)
    if type(row) ~= "table" or not row.CreateTexture then return end
    local b = bullets[row]
    if not isOn then if b then b:Hide() end; return end
    if not b then
        b = row:CreateTexture(nil, "OVERLAY", nil, 5)
        b:SetTexture(ns.Media.textures.CIRCLE)
        b:SetSize(5, 5)
        b:SetPoint("LEFT", 2, 0)
        bullets[row] = b
    end
    ns.Widgets.Color(b, "accent.primary", 1)
    b:Show()
end

M.QUEST_BUTTONS = { QuestFrameAcceptButton = "primary", QuestFrameCompleteButton = "primary",
    QuestFrameCompleteQuestButton = "primary", QuestFrameDeclineButton = "secondary", QuestFrameGoodbyeButton = "secondary",
    QuestFrameGreetingGoodbyeButton = "secondary" }

function M:SkinGossip()
    local isOn = on()
    local gf = _G.GossipFrame
    if gf then
        M.KitScrollBox(M.FramePath(gf, { "GreetingPanel", "ScrollBox" }), on, function(row, o)
            M.KitRow(row, o, { alpha = 0.3 }); M.GossipBullet(row, o)
        end)
        M.SkinPopupButton(M.FramePath(gf, { "GreetingPanel", "GoodbyeButton" }), "secondary", isOn)
    end
    for name, variant in pairs(self.QUEST_BUTTONS) do M.SkinPopupButton(_G[name], variant, isOn) end
end

local gossipHooked
function M:SetupGossip()
    self:SkinGossip()
    local root = _G.GossipFrame
    if gossipHooked or not root then return end
    gossipHooked = true
    root:HookScript("OnShow", function() M:SkinGossip() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupGossip"
M.RESKINS[#M.RESKINS + 1] = "SkinGossip"
