local _, ns = ...

--[[ ns.WindowDrag — Layout's window dragging (specs/005 T002: the drag code lives in Layout now; Skins only owns
    the saved switch and spots, so nothing saved moved). Shift+drag a window moves it and remembers the spot (per
    profile); Ctrl+drag moves it for this session only. Windows go back to the spot whenever Blizzard's panel
    manager lays them out again.
    Safety: only out of combat for protected windows; nothing is re-parented or resized; positions are stored as
    an offset from UIParent's centre so they survive scale and resolution changes. ]]
local D = {}
ns.WindowDrag = D
local hooked, session = {}, {}
local cfg = { enabled = function() return false end, store = function() return {} end }

-- enabled() = the switch is on; store() = the saved spots table (by frame name)
function D:Configure(opts) cfg = opts end

local function canTouch(f)
    return not (InCombatLockdown() and f:IsProtected())
end

local function place(f)
    if not (cfg.enabled() and f:IsShown()) then return end
    local name = hooked[f]
    local p = name and (session[name] or cfg.store()[name])
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
    if keep then cfg.store()[name] = p end
end

local function hook(f, name)
    if hooked[f] or not f.HookScript then return end
    hooked[f] = name
    f:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not cfg.enabled() or not canTouch(self) then return end
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

function D:Hook(name)
    local f = _G[name]
    if f then hook(f, name) end
end

function D:Reset()
    wipe(cfg.store()); wipe(session)
    if not InCombatLockdown() and UpdateUIPanelPositions then UpdateUIPanelPositions() end
end

-- Blizzard re-lays panels out on show; put dragged ones back each time (one hook for every window)
function D:Watch()
    if self.panelHooked or not UpdateUIPanelPositions then return end
    self.panelHooked = true
    hooksecurefunc("UpdateUIPanelPositions", function()
        for f in pairs(hooked) do place(f) end
    end)
end

D.Test = { session = session, place = place, remember = remember, hook = hook }
