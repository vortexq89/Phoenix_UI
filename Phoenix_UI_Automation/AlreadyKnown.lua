local _, ns = ...
local M = ns:GetModule("Automation")

--[[ Already known: at a merchant, recipes, mounts, pets and toys you already know get a green tint on their icon.
    The game's own tooltip data says it (the ITEM_SPELL_KNOWN line); nothing is guessed. Off with
    Automation > Already known at merchants. ]]
local KNOWN_R, KNOWN_G, KNOWN_B = 0.25, 1, 0.35

-- Does a tooltip data table carry the "Already known" line?
function M.TooltipSaysKnown(data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    local known = _G.ITEM_SPELL_KNOWN
    if type(known) ~= "string" then return false end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and not ns.Secret.IsSecret(text) and text == known then return true end
    end
    return false
end

local function isKnown(index)
    if not (C_TooltipInfo and C_TooltipInfo.GetMerchantItem) then return false end
    local ok, data = pcall(C_TooltipInfo.GetMerchantItem, index)
    return ok and M.TooltipSaysKnown(data)
end

local function paint()
    if not (M:IsEnabled() and M.db.alreadyKnown) or not MerchantFrame or MerchantFrame.selectedTab ~= 1 then return end
    local per = _G.MERCHANT_ITEMS_PER_PAGE or 10
    local page = MerchantFrame.page or 1
    for i = 1, per do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        local index = (page - 1) * per + i
        if button and button:IsShown() and isKnown(index) then
            local icon = button.icon or (button.GetName and _G[(button:GetName() or "") .. "IconTexture"])
            if icon and icon.SetVertexColor then icon:SetVertexColor(KNOWN_R, KNOWN_G, KNOWN_B) end
            local frame = _G["MerchantItem" .. i]
            if frame and frame.Name then frame.Name:SetTextColor(KNOWN_R, KNOWN_G, KNOWN_B) end
        end
    end
end
M.PaintKnown = paint

function M:SetupAlreadyKnown()
    if self.knownHooked or type(MerchantFrame_UpdateMerchantInfo) ~= "function" then return end
    self.knownHooked = true
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", paint)
end
