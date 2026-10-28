local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Group Finder / PvE / PvP, skins plan window 7 (window chrome and tabs: the shared window skin): premade
    search results and applicants as Phoenix rows (selected outlined in the accent), the dungeon and raid
    lists as rows, PvP's queue buttons and the dungeon-ready dialog as Phoenix buttons (Enter primary, Leave
    secondary) on a Phoenix dialog card. Queue / sign-up / enter clicks stay Blizzard's own. Live both ways
    with Skins > Group Finder. ]]

local function on() return M:IsEnabled() and M.db.groupFinder and true or false end
M.GroupFinderOn = on

local function lists()
    local out = {}
    local lfg = _G.LFGListFrame
    if lfg then
        out[#out + 1] = M.FramePath(lfg, { "SearchPanel", "ScrollBox" })
        out[#out + 1] = M.FramePath(lfg, { "ApplicationViewer", "ScrollBox" })
        out[#out + 1] = M.FramePath(lfg, { "CategorySelection", "ScrollBox" })
    end
    local lfd = _G.LFDQueueFrame
    if lfd then out[#out + 1] = M.FramePath(lfd, { "Specific", "ScrollBox" }) end
    return out
end

function M:SkinGroupFinder()
    local isOn = on()
    for _, box in pairs(lists()) do M.KitScrollBox(box, on, function(row, o) M.KitRow(row, o) end) end
    local ready = _G.LFGDungeonReadyDialog
    if ready then
        if isOn then M.SkinWindow(ready, true) else M.UnskinWindow(ready) end
        M.SkinPopupButton(ready.enterButton or _G.LFGDungeonReadyDialogEnterDungeonButton, "primary", isOn)
        M.SkinPopupButton(ready.leaveButton or _G.LFGDungeonReadyDialogLeaveQueueButton, "secondary", isOn)
    end
    M.SkinPopupButton(_G.LFDQueueFrameFindGroupButton, "primary", isOn)
    M.SkinPopupButton(_G.RaidFinderFrameFindRaidButton, "primary", isOn)
    local pvp = _G.HonorFrame
    if pvp then M.SkinPopupButton(pvp.QueueButton, "primary", isOn) end
    local conq = _G.ConquestFrame
    if conq then M.SkinPopupButton(conq.JoinButton, "primary", isOn) end
end

local gfHooked, readyHooked
function M:SetupGroupFinder()
    self:SkinGroupFinder()
    if not readyHooked then
        readyHooked = true
        ns.Events:On("LFG_PROPOSAL_SHOW", self, function() M:SkinGroupFinder() end)
    end
    if gfHooked or not _G.PVEFrame then return end
    gfHooked = true
    _G.PVEFrame:HookScript("OnShow", function() M:SkinGroupFinder() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupGroupFinder"
M.RESKINS[#M.RESKINS + 1] = "SkinGroupFinder"
