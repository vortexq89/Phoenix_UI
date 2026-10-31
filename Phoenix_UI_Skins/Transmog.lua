local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Transmog and dressing room, skins plan window 17: the transmog window in the Phoenix window look, the outfit
    bar on an accent card, slot buttons on sunken cells, Apply primary; the dressing room's link button.
    Appearance icons and the model are the game's own; applying stays Blizzard's click.
    Live both ways with its Skins switch, repainted on theme change (kit rows / cards). ]]

local function on() return M:IsEnabled() and M.db.transmog and true or false end

-- 12.x transmog window and the dressing room: slot buttons on sunken cells, the outfit bar and cost footer
-- on Phoenix cards, Apply as the primary button.
M.TRANSMOG_SLOTS = { "HEADSLOT", "SHOULDERSLOT", "BACKSLOT", "CHESTSLOT", "SHIRTSLOT", "TABARDSLOT", "WRISTSLOT",
    "HANDSSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT", "MAINHANDSLOT", "SECONDARYHANDSLOT" }

function M:SkinTransmog()
    local isOn = on()
    local tf = _G.TransmogFrame
    if tf then
        if isOn then M.SkinWindow(tf, false) else M.UnskinWindow(tf) end
        M.KitCard(M.FramePath(tf, { "OutfitCollection" }), isOn, "raised", true)
        M.SkinPopupButton(rawget(tf, "ApplyButton"), "primary", isOn)
        for _, slot in ipairs(self.TRANSMOG_SLOTS) do
            local b = rawget(tf, slot) or _G["TransmogFrame" .. slot]
            M.KitCard(b, isOn, "sunken", false)
        end
    end
    local du = _G.DressUpFrame
    if du then M.SkinPopupButton(rawget(du, "LinkButton"), "secondary", isOn) end
end

local transmogHooked
function M:SetupTransmog()
    self:SkinTransmog()
    local root = _G.TransmogFrame
    if transmogHooked or not root then return end
    transmogHooked = true
    root:HookScript("OnShow", function() M:SkinTransmog() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupTransmog"
M.RESKINS[#M.RESKINS + 1] = "SkinTransmog"
