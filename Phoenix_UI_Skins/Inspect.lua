local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Inspect, skins plan window 27 (window chrome: shared skin): the inspected player's gear slots like the
    character sheet (square 1 px slots, the border in each item's quality colour; icons untouched).
    Live with Skins > Inspect. ]]

function M:SkinInspect()
    local f = _G.InspectFrame
    if not f then return end
    local unit = rawget(f, "unit") or "target"
    for _, slot in ipairs(self.PAPERDOLL_SLOTS) do M.StyleSlot(_G["Inspect" .. slot .. "Slot"], "inspect", unit) end
end

local inspectHooked
function M:SetupInspect()
    self:SkinInspect()
    local root = _G.InspectFrame
    if inspectHooked or not root then return end
    inspectHooked = true
    root:HookScript("OnShow", function() M:SkinInspect() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupInspect"
M.RESKINS[#M.RESKINS + 1] = "SkinInspect"
