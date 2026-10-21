local _, ns = ...
local Skin = ns.Skin

--[[ Skins: Phoenix panels behind a few Blizzard dialogs. Art is hidden with alpha only, our textures
    are added beside it; nothing is re-parented, re-anchored or written onto the Blizzard frame. ]]
local M = ns:NewModule("Skins", {
    label = "SKINS", desc = "SKINS_DESC", category = "interface", order = 5, reloadOnToggle = true,
    defaults = { gameMenu = true, popups = true, readyCheck = true },
})

local ART = { "Border", "NineSlice", "BG", "Bg", "Background" }
local HEADER_ART = { "LeftBG", "RightBG", "CenterBG" }

local function window(frame, shadow)
    if not frame or Skin:IsSkinned(frame) then return end
    for _, key in ipairs(ART) do Skin:HideRegion(frame[key]) end
    local header = frame.Header
    if header then
        for _, key in ipairs(HEADER_ART) do Skin:HideRegion(header[key]) end
    end
    Skin:Register(frame, function(self)
        Skin:Panel(self, "base", { border = "border.strong", shadow = shadow or 14, sheen = 30 })
        if header and header.Text then Skin:Text(header.Text, "heading", "accent.primary", 13) end
    end)
end

function M:OnEnable()
    if self.db.gameMenu then window(GameMenuFrame) end
    if self.db.readyCheck then window(ReadyCheckListenerFrame, 10) end
    if self.db.popups then
        for i = 1, 4 do window(_G["StaticPopup" .. i], 10) end
    end
end
