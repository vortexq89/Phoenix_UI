local _, ns = ...
local M = ns.modules.Skins

--[[ Move Blizzard windows (Skins option "moveWindows", off by default, applies live).
    Shift+drag a window moves it and remembers the spot (per profile); Ctrl+drag moves it for this session
    only. Windows go back to the spot whenever Blizzard's panel manager lays them out again.
    Safety: only out of combat for protected windows; nothing is re-parented or resized; positions are
    stored as an offset from UIParent's centre so they survive scale and resolution changes. ]]
local hooked, session = {}, {}

local function store()
    M.db.movedWindows = M.db.movedWindows or {}
    return M.db.movedWindows
end

local function canTouch(f)
    return not (InCombatLockdown() and f:IsProtected())
end

local function place(f)
    if not (M.db.moveWindows and f:IsShown()) then return end
    local name = hooked[f]
    local p = name and (session[name] or store()[name])
    if not p or not canTouch(f) then return end
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", p.x, p.y)
end

local function remember(f, keep)
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and ux) then return end
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local p = { x = math.floor(cx * s - ux + 0.5), y = math.floor(cy * s - uy + 0.5) }
    local name = hooked[f]
    session[name] = p
    if keep then store()[name] = p end
end

local function hook(f, name)
    if hooked[f] or not f.HookScript then return end
    hooked[f] = name
    f:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not M.db.moveWindows or not canTouch(self) then return end
        local shift, ctrl = IsShiftKeyDown(), IsControlKeyDown()
        if not (shift or ctrl) then return end
        self.puiMoveKeep = shift
        self:SetMovable(true)
        self:SetClampedToScreen(true)
        self:StartMoving()
        self.puiMoving = true
    end)
    f:HookScript("OnMouseUp", function(self)
        if not self.puiMoving then return end
        self.puiMoving = nil
        self:StopMovingOrSizing()
        if self.SetUserPlaced then self:SetUserPlaced(false) end
        remember(self, self.puiMoveKeep)
    end)
    f:HookScript("OnShow", place)
end

function M:HookMovable(name)
    local f = _G[name]
    if f then hook(f, name) end
end

function M:ResetWindows()
    wipe(store()); wipe(session)
    if not InCombatLockdown() and UpdateUIPanelPositions then UpdateUIPanelPositions() end
end

function M:SetupMoving()
    for _, entry in ipairs(self.WINDOWS) do
        -- load-on-demand windows are hooked when their addon loads (Skins' ADDON_LOADED handler)
        if not entry.dialog and not (entry.addon and not C_AddOns.IsAddOnLoaded(entry.addon)) then
            for _, name in ipairs(entry.frames) do self:HookMovable(name) end
        end
    end
    if not self.panelHooked and UpdateUIPanelPositions then
        self.panelHooked = true
        hooksecurefunc("UpdateUIPanelPositions", function()
            for f in pairs(hooked) do place(f) end
        end)
    end
end

M.MoveTest = { session = session, place = place, remember = remember, hook = hook }

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
    if not self.db.moveWindows and not InCombatLockdown() and UpdateUIPanelPositions then UpdateUIPanelPositions() end
end
