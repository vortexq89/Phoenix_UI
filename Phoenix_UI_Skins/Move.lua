local _, ns = ...
local M = ns.modules.Skins

--[[ Move Blizzard windows (option "moveWindows", off by default, applies live; its row is on the Layout page).
    The drag code is Layout's (Modules/Movers/Windows.lua, specs/005 T002); Skins keeps the switch and the saved
    spots (db.movedWindows) where they always were, and hooks its window list plus Layout's (M.WINDOWS). ]]
local D = ns.WindowDrag
D:Configure({
    enabled = function() return M.db and M.db.moveWindows end,
    store = function() M.db.movedWindows = M.db.movedWindows or {}; return M.db.movedWindows end,
})

function M:HookMovable(name) D:Hook(name) end

function M:ResetWindows() D:Reset() end

function M:SetupMoving()
    for _, entry in ipairs(self.WINDOWS) do
        -- load-on-demand windows are hooked when their addon loads (Skins' ADDON_LOADED handler)
        if not entry.dialog and not (entry.addon and not C_AddOns.IsAddOnLoaded(entry.addon)) then
            for _, name in ipairs(entry.frames) do self:HookMovable(name) end
        end
    end
    -- MoveAny's window list (Layout's M.WINDOWS): the ones already loaded; HookMovable skips missing frames
    local movers = ns:GetModule("Movers")
    for _, name in ipairs(movers and movers.WINDOWS or {}) do self:HookMovable(name) end
    D:Watch()
end

M.MoveTest = D.Test

-- live: turning the option off hands the windows back to Blizzard's layout at once
function M:Refresh()
    if self.RefreshMailAlts then self:RefreshMailAlts() end
    if self.SkinMicroMenu then self:SkinMicroMenu() end -- MicroMenu.lua, live
    if self.ApplyLive then self:ApplyLive() end -- Game Menu window look, live both ways
    if self.SkinGameMenu then self:SkinGameMenu() end -- GameMenu.lua, live
    if self.SkinWorldMap then self:SkinWorldMap() end -- WorldMap.lua, live
    if self.SkinCharacterSlots then self:SkinCharacterSlots() end -- Character.lua, live
    if self.SkinCharacterLists then self:SkinCharacterLists() end -- CharacterLists.lua, live
    if self.SkinPopups then self:SkinPopups() end -- Popups.lua, live
    if self.RunReskins then self:RunReskins() end -- dedicated window skins, live
    if not self.db.moveWindows and not InCombatLockdown() and UpdateUIPanelPositions then UpdateUIPanelPositions() end
end
