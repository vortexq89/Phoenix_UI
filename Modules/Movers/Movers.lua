local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin

--[[ Movers: MoveAny-style positioning for the frames Edit Mode cannot reach (ARCHITECTURE §16).
    * Only a curated list of Blizzard frames, each verified against 12.1.5 FrameXML to be outside Edit Mode
      and the UIParent managed-frame layout, plus Phoenix's own frames (M:Register).
    * A runtime guard refuses anything Edit Mode manages (frame.system, isManagedFrame, or listed in
      EditModeManagerFrame.registeredSystemFrames). Those fields are only read, never written.
    * We never call StartMoving/SetMovable on a Blizzard frame: the user drags a Phoenix overlay and the
      target only receives ClearAllPoints/SetPoint/SetScale/SetAlpha. Protected targets are touched
      out of combat only (ns.Combat:Run); unlock mode itself closes when combat starts.
    * Positions are per profile: db.frames[key] = { point, x, y (UIParent units), scale, alpha }.
      The original anchors are kept in memory so "reset" restores Blizzard's own layout. ]]
local M = ns:NewModule("Movers", {
    label = "MOVERS", desc = "MOVERS_DESC", category = "interface", order = 95,
    defaults = { grid = true, gridSize = 32, snap = true, frames = {} },
})

local OVERLAY_MIN_W, OVERLAY_MIN_H = 160, 36
local SCALE_MIN, SCALE_MAX, ALPHA_MIN = 0.5, 2, 0.2

-- noAlpha: Blizzard animates the frame's alpha itself (fading text, banners, toasts), so a stored alpha
-- would be overwritten. noScale: the visible children are not parented to the frame (alert pool lives on
-- UIParent), so scaling the anchor does nothing. hook: a method that re-anchors the frame.
M.BLIZZARD = {
    { key = "ZoneText", frame = "ZoneTextFrame", label = "MOVERS_ZONE_TEXT", noAlpha = true },
    { key = "SubZoneText", frame = "SubZoneTextFrame", label = "MOVERS_SUBZONE_TEXT", noAlpha = true },
    { key = "Errors", frame = "UIErrorsFrame", label = "MOVERS_ERRORS" },
    { key = "Alerts", frame = "AlertFrame", label = "MOVERS_ALERTS", noAlpha = true, noScale = true },
    { key = "TopWidgets", frame = "UIWidgetTopCenterContainerFrame", label = "MOVERS_TOP_WIDGETS" },
    { key = "BossBanner", frame = "BossBanner", label = "MOVERS_BOSS_BANNER", noAlpha = true },
    { key = "EventToasts", frame = "EventToastManagerFrame", label = "MOVERS_EVENT_TOASTS", noAlpha = true, hook = "UpdateAnchor" },
    { key = "ReadyCheck", frame = "ReadyCheckFrame", label = "MOVERS_READY_CHECK", noAlpha = true },
}

local entries, byKey = {}, {}
for _, e in ipairs(M.BLIZZARD) do entries[#entries + 1] = e; byKey[e.key] = e end

local unlocked, selected = false, nil
local toolbar, grid

---------------------------------------------------------------- targets
local function resolve(e)
    if e.target then return e.target end
    local f = e.frame and _G[e.frame]
    if type(f) == "table" and f.GetObjectType then e.target = f end
    return e.target
end

-- Anything Edit Mode or the managed-frame layout owns is off limits (reading these fields is taint-free).
function M.IsManaged(f)
    if f.system ~= nil or f.isManagedFrame then return true end
    local list = EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames
    if type(list) == "table" then
        for _, s in ipairs(list) do if s == f then return true end end
    end
    return false
end

local function usable(e)
    local f = resolve(e)
    if not f or f:IsForbidden() then return nil end
    if not e.owned and M.IsManaged(f) then
        if not e.refused then e.refused = true; ns:Debug("Movers: %s is managed by Edit Mode, skipped", e.key) end
        return nil
    end
    return f
end

local function uiScale(f) return f:GetEffectiveScale() / UIParent:GetEffectiveScale() end

local function blocked(f) return InCombatLockdown() and f:IsProtected() end

-- Keep Blizzard's own anchors the first time we touch a frame.
local function remember(e, f)
    if e.orig then return end
    local points = {}
    for i = 1, f:GetNumPoints() do points[i] = { f:GetPoint(i) } end
    e.orig = { points = points, scale = f:GetScale(), alpha = f:GetAlpha() }
end

local function saved(e) return M.db.frames[e.key] end

local function apply(e)
    local f = usable(e)
    if not f then return end
    if blocked(f) then return ns.Combat:Run("movers." .. e.key, apply, e) end
    local s = saved(e)
    if not s then return end
    remember(e, f)
    e.applying = true
    if not e.noScale and s.scale then f:SetScale(s.scale) end
    if not e.noAlpha and s.alpha then f:SetAlpha(s.alpha) end
    if s.point then
        local k = uiScale(f) -- offsets are in the frame's own units
        f:ClearAllPoints()
        f:SetPoint(s.point, UIParent, s.point, s.x / k, s.y / k)
    end
    e.applying = false
end

local function restore(e)
    local f = resolve(e)
    if not f or not e.orig then return end
    if blocked(f) then return ns.Combat:Run("movers." .. e.key, restore, e) end
    f:SetScale(e.orig.scale)
    if not e.noAlpha then f:SetAlpha(e.orig.alpha) end
    f:ClearAllPoints()
    for _, p in ipairs(e.orig.points) do f:SetPoint(unpack(p)) end
    e.orig = nil
end

local function hookTarget(e)
    local f = resolve(e)
    if e.hooked or not f or not e.hook or type(f[e.hook]) ~= "function" then return end
    e.hooked = true
    hooksecurefunc(f, e.hook, function()
        if M:IsEnabled() and not e.applying and saved(e) then apply(e) end
    end)
end

function M:ApplyAll()
    for _, e in ipairs(entries) do
        hookTarget(e)
        if saved(e) then apply(e) else restore(e) end
    end
end

-- Phoenix frames (bug indicator …) join the list at runtime.
function M:Register(key, frame, label)
    if byKey[key] then byKey[key].target = frame; return end
    local e = { key = key, target = frame, text = label, owned = true }
    entries[#entries + 1], byKey[key] = e, e
    if self:IsEnabled() and saved(e) then apply(e) end
end

function M:GetEntries() return entries end
function M:GetEntry(key) return byKey[key] end
function M:IsUnlocked() return unlocked end
function M:LabelOf(e) return e.text or L[e.label] end

---------------------------------------------------------------- geometry (UIParent units)
local function centerOf(f)
    local x, y = f:GetCenter()
    if not x or not y then return nil end
    local s = uiScale(f)
    return x * s, y * s, f:GetWidth() * s, f:GetHeight() * s
end

-- Offset of one axis for a frame of `size` centred at c on a screen of `total`: by thirds the nearest edge
-- ("LEFT"/"BOTTOM" = low, "RIGHT"/"TOP" = high) or the middle; the frame's matching edge is anchored.
local function axis(c, size, total, low, high)
    if c < total / 3 then return low, c - size / 2 end
    if c > total * 2 / 3 then return high, c + size / 2 - total end
    return "", c - total / 2
end

-- Save the target so its centre lands on (cx, cy).
local function commit(e, cx, cy, scale, alpha)
    local f = resolve(e)
    local s = saved(e) or {}
    scale = scale or s.scale or f:GetScale()
    local ratio = scale / f:GetScale()
    local _, _, w, h = centerOf(f)
    local hx, x = axis(cx, (w or 0) * ratio, UIParent:GetWidth(), "LEFT", "RIGHT")
    local vy, y = axis(cy, (h or 0) * ratio, UIParent:GetHeight(), "BOTTOM", "TOP")
    local point = vy .. hx
    s.point, s.x, s.y = point ~= "" and point or "CENTER", math.floor(x + 0.5), math.floor(y + 0.5)
    if not e.noScale then s.scale = scale end
    if alpha and not e.noAlpha then s.alpha = alpha end
    M.db.frames[e.key] = s
    apply(e)
end

local function snapped(v, origin)
    local g = M.db.gridSize
    if not M.db.snap or g <= 0 then return v end
    return origin + math.floor((v - origin) / g + 0.5) * g
end

---------------------------------------------------------------- overlays
local overlays = {}

local function paintOverlay(o)
    local sel = selected == o.entry
    Skin:Panel(o, "raised", { border = sel and "accent.primary" or "border.strong" })
    W.Color(o.fill, "accent.primary", sel and 0.22 or 0.1)
    Skin:Text(o.label, "body", sel and "text.primary" or "text.secondary")
end

local function syncOverlay(o)
    local f = resolve(o.entry)
    local cx, cy, w, h = centerOf(f)
    if not cx then o:Hide(); return end
    o:ClearAllPoints()
    o:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    o:SetSize(math.max(OVERLAY_MIN_W, w), math.max(OVERLAY_MIN_H, h))
    local s = saved(o.entry)
    o.state:SetText(s and s.point and ("%s  %d, %d"):format(s.point, s.x, s.y) or L.MOVERS_DEFAULT_POS)
end

local function selectEntry(e)
    selected = e
    for _, o in pairs(overlays) do paintOverlay(o) end
    if toolbar then toolbar:Update() end
end

local function nudge(e, dx, dy)
    local f = resolve(e)
    if not f or blocked(f) then return end
    local cx, cy = centerOf(f)
    if not cx then return end
    commit(e, cx + dx, cy + dy)
    if overlays[e.key] then syncOverlay(overlays[e.key]) end
    if toolbar then toolbar:Update() end
end
M.Nudge = nudge

local function setScale(e, v)
    local f = resolve(e)
    if e.noScale or not f or blocked(f) then return end
    local cx, cy = centerOf(f)
    if not cx then return end
    commit(e, cx, cy, math.max(SCALE_MIN, math.min(SCALE_MAX, v)))
    if overlays[e.key] then syncOverlay(overlays[e.key]) end
    if toolbar then toolbar:Update() end
end

local function setAlpha(e, v)
    local f = resolve(e)
    if e.noAlpha or not f or blocked(f) then return end
    local cx, cy = centerOf(f)
    if not cx then return end
    commit(e, cx, cy, nil, math.max(ALPHA_MIN, math.min(1, v)))
    if toolbar then toolbar:Update() end
end
M.SetFrameScale, M.SetFrameAlpha = setScale, setAlpha

function M:ResetFrame(key)
    local e = byKey[key]
    if not e then return end
    self.db.frames[key] = nil
    restore(e)
    if overlays[key] then syncOverlay(overlays[key]) end
    if toolbar then toolbar:Update() end
    ns.Events:Fire("PUI_MOVERS")
end

function M:ResetAll()
    for _, e in ipairs(entries) do self.db.frames[e.key] = nil; restore(e) end
    for _, o in pairs(overlays) do syncOverlay(o) end
    if toolbar then toolbar:Update() end
    ns.Events:Fire("PUI_MOVERS")
end

local ARROWS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }

local function overlayFor(e)
    local o = overlays[e.key]
    if o then return o end
    o = CreateFrame("Button", nil, UIParent)
    o.entry = e
    o:SetFrameStrata("DIALOG")
    o:SetFrameLevel(60)
    o:SetClampedToScreen(true)
    o:SetMovable(true)
    o:EnableMouse(true)
    o:EnableMouseWheel(true)
    o:RegisterForDrag("LeftButton")
    o:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    o.fill = W.Texture(o, "BACKGROUND", 1)
    o.fill:SetPoint("TOPLEFT", 1, -1); o.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    o.label = W.Text(o, "body", "text.primary", "CENTER")
    o.label:SetPoint("CENTER", 0, 6)
    o.label:SetText(M:LabelOf(e))
    o.state = W.Text(o, "small", "text.muted", "CENTER")
    o.state:SetPoint("TOP", o.label, "BOTTOM", 0, -2)
    Skin:Register(o, paintOverlay)
    o:SetScript("OnDragStart", function(self)
        if blocked(resolve(e)) then return end
        selectEntry(e)
        self.dragging = true
        self:StartMoving()
    end)
    o:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dragging = false
        local cx, cy = self:GetCenter()
        commit(e, snapped(cx, UIParent:GetWidth() / 2), snapped(cy, UIParent:GetHeight() / 2))
        syncOverlay(self)
        if toolbar then toolbar:Update() end
        ns.Events:Fire("PUI_MOVERS")
    end)
    o:SetScript("OnClick", function(_, button)
        if button == "RightButton" then M:ResetFrame(e.key) else selectEntry(e) end
    end)
    o:SetScript("OnMouseWheel", function(_, delta)
        selectEntry(e)
        local s, f = saved(e) or {}, resolve(e)
        if IsShiftKeyDown() then setAlpha(e, (s.alpha or f:GetAlpha()) + delta * 0.05)
        else setScale(e, (s.scale or f:GetScale()) + delta * 0.05) end
    end)
    -- Arrow keys nudge the hovered overlay (keyboard is captured only while the cursor is on it).
    o:SetScript("OnEnter", function(self)
        if not InCombatLockdown() then self:EnableKeyboard(true) end
        W.ShowTooltip(self, M:LabelOf(e), L.MOVERS_OVERLAY_TIP)
    end)
    o:SetScript("OnLeave", function(self)
        if not InCombatLockdown() then self:EnableKeyboard(false) end
        W.HideTooltip()
    end)
    o:SetScript("OnKeyDown", function(_, key)
        local dir = ARROWS[key]
        if dir then
            local step = IsShiftKeyDown() and 10 or 1
            selectEntry(e)
            nudge(e, dir[1] * step, dir[2] * step)
        elseif key == "ESCAPE" then
            M:SetUnlocked(false)
        end
    end)
    overlays[e.key] = o
    return o
end

---------------------------------------------------------------- grid
local function buildGrid()
    local g = CreateFrame("Frame", nil, UIParent)
    g:SetAllPoints(UIParent)
    g:SetFrameStrata("DIALOG")
    g:SetFrameLevel(1)
    g:EnableMouse(false)
    g.lines = {}
    function g:Layout()
        for _, t in ipairs(self.lines) do t:Hide() end
        local size = M.db.gridSize
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        local n = 0
        local function line(vertical, offset, center)
            n = n + 1
            local t = self.lines[n] or W.Texture(self, "BACKGROUND", 0)
            self.lines[n] = t
            t:ClearAllPoints()
            if vertical then
                t:SetPoint("TOP", self, "TOP", offset, 0); t:SetPoint("BOTTOM", self, "BOTTOM", offset, 0); t:SetWidth(1)
            else
                t:SetPoint("LEFT", self, "LEFT", 0, offset); t:SetPoint("RIGHT", self, "RIGHT", 0, offset); t:SetHeight(1)
            end
            W.Color(t, center and "accent.primary" or "border.strong", center and 0.7 or 0.35)
            t:Show()
        end
        for i = 0, math.floor(w / 2 / size) do
            line(true, i * size, i == 0)
            if i > 0 then line(true, -i * size) end
        end
        for i = 0, math.floor(h / 2 / size) do
            line(false, i * size, i == 0)
            if i > 0 then line(false, -i * size) end
        end
    end
    Skin:Register(g, function(self) self:Layout() end)
    g:Hide()
    return g
end

---------------------------------------------------------------- unlock mode
function M:SetUnlocked(on)
    if on and InCombatLockdown() then
        ns:Print(L.MOVERS_COMBAT)
        return
    end
    if on and not self:IsEnabled() then return end
    unlocked = on and true or false
    if unlocked then
        grid = grid or buildGrid()
        if self.db.grid then grid:Layout(); grid:Show() else grid:Hide() end
        for _, e in ipairs(entries) do
            if usable(e) then
                local o = overlayFor(e)
                o:Show()
                syncOverlay(o)
            end
        end
        toolbar = toolbar or self:BuildToolbar() -- Toolbar.lua
        toolbar:Show()
        selectEntry(selected or entries[1])
    else
        if grid then grid:Hide() end
        for _, o in pairs(overlays) do
            o:EnableKeyboard(false)
            o:Hide()
        end
        if toolbar then toolbar:Hide() end
    end
    ns.Events:Fire("PUI_MOVERS")
end

function M:GetSelected() return selected end
function M:Select(e) selectEntry(e) end
M.Usable = usable
function M:ShowGrid(on)
    ns.DB:Set(self, "grid", on and true or false)
end

function M:OnSlash()
    self:SetUnlocked(not unlocked)
end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    self:ApplyAll()
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function()
        if unlocked then
            self:SetUnlocked(false)
            ns:Print(L.MOVERS_COMBAT_LOCKED)
        end
    end)
    ns.Events:On("ADDON_LOADED", self, function() self:ApplyAll() end) -- frames from load-on-demand addons
    ns.Events:On("UI_SCALE_CHANGED", self, function() if grid and grid:IsShown() then grid:Layout() end end)
    ns.Events:On("DISPLAY_SIZE_CHANGED", self, function() if grid and grid:IsShown() then grid:Layout() end end)
    EventRegistry:RegisterCallback("EditMode.Enter", function() if unlocked then self:SetUnlocked(false) end end, self)
end

function M:OnDisable()
    self:SetUnlocked(false)
    EventRegistry:UnregisterCallback("EditMode.Enter", self)
    for _, e in ipairs(entries) do restore(e) end
end

function M:Refresh()
    self:ApplyAll()
    if unlocked then
        if self.db.grid then grid:Layout(); grid:Show() else grid:Hide() end
        for _, o in pairs(overlays) do syncOverlay(o) end
        if toolbar then toolbar:Update() end
    end
end

function M:OnProfileChanged()
    if self:ShouldEnable() then
        if self:IsEnabled() then self:Refresh() else self:Enable() end
    else
        self:Disable()
    end
end
