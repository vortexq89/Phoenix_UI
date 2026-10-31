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
      The original anchors are kept in memory so "reset" restores Blizzard's own layout.
    * S16: snapping to other frames' edges, an arrow-key switch, live coordinates, an unlock key (an override
      binding to our own button, set out of combat) and one scale for Blizzard's UI panel windows (M.WINDOWS,
      none of them Edit Mode systems; scaled on show, protected ones out of combat only). ]]
local M = ns:NewModule("Movers", {
    label = "MOVERS", desc = "MOVERS_DESC", category = "interface", order = 95,
    defaults = { showHidden = false, grid = true, gridSize = 32, snap = true, frames = {}, snapFrames = true, arrows = true, coords = true,
        unlockKey = "", windowScale = 1, any = {} },
})

local OVERLAY_MIN_W, OVERLAY_MIN_H = 48, 20 -- the box matches the frame; tiny frames still get a grabbable box
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

-- UI panel windows "Scale Blizzard windows" applies to (several load on demand; scaled when shown).
M.WINDOWS = { "CharacterFrame", "PVEFrame", "FriendsFrame", "MerchantFrame", "MailFrame", "GossipFrame", "QuestFrame",
    "BankFrame", "PlayerSpellsFrame", "CollectionsJournal", "EncounterJournal", "AchievementFrame", "ProfessionsFrame",
    "AuctionHouseFrame", "WeeklyRewardsFrame", "CommunitiesFrame", "PlayerChoiceFrame" }

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
    if e.store and e.store.active and not e.store.active() then return nil end
    -- only frames that are on screen get a box (a switched-off module, an empty party frame when solo, a
    -- Blizzard message frame with nothing to say). Test frames (/pui test) make the group and boss frames show.
    if not f:IsVisible() and not M.db.showHidden then return nil end
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

-- A store lets a module keep the position in its own settings (action bars write bars.<key>.point/x/y…) and
-- place the frame itself: { get() -> {point,x,y,scale,alpha}|nil, set(s), apply(), reset(), active(),
-- preview(unlocked) (optional: show or drop a sample when Layout mode opens or closes) }.
local function saved(e)
    if e.store then return e.store.get() end
    return M.db.frames[e.key]
end

local function apply(e)
    if e.store then return e.store.apply() end
    local f = usable(e)
    if not f then return end
    if blocked(f) then return ns.Combat:Run("movers." .. e.key, apply, e) end
    local s = saved(e)
    if not s then return end
    remember(e, f)
    e.applying = true
    if not e.noScale and s.scale then f:SetScale(ns.Util.SafeScale(s.scale)) end
    if not e.noAlpha and s.alpha then f:SetAlpha(s.alpha) end
    if s.point then
        local k = uiScale(f) -- offsets are in the frame's own units
        f:ClearAllPoints()
        f:SetPoint(s.point, UIParent, s.point, s.x / k, s.y / k)
    end
    e.applying = false
end

local function restore(e)
    if e.store then return e.store.reset() end
    local f = resolve(e)
    if not f or not e.orig then return end
    if blocked(f) then return ns.Combat:Run("movers." .. e.key, restore, e) end
    f:SetScale(ns.Util.SafeScale(e.orig.scale))
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
        if e.store then -- the owning module places its own frames
        elseif saved(e) then apply(e) else restore(e) end
    end
end

-- Phoenix frames (bug indicator, action bars …) join the list at runtime. `store` is optional (see saved()).
function M:Register(key, frame, label, store)
    if byKey[key] then byKey[key].target = frame; byKey[key].store = store or byKey[key].store; return end
    local e = { key = key, target = frame, text = label, owned = true, store = store }
    entries[#entries + 1], byKey[key] = e, e
    if self:IsEnabled() and saved(e) and not store then apply(e) end
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

-- The {point, x, y} that puts the target's centre on (cx, cy); `s` (optional) is filled in.
local function placement(e, cx, cy, scale, s)
    local f = resolve(e)
    s = s or {}
    scale = scale or s.scale or f:GetScale()
    local ratio = scale / f:GetScale()
    local _, _, w, h = centerOf(f)
    local hx, x = axis(cx, (w or 0) * ratio, UIParent:GetWidth(), "LEFT", "RIGHT")
    local vy, y = axis(cy, (h or 0) * ratio, UIParent:GetHeight(), "BOTTOM", "TOP")
    local point = vy .. hx
    s.point, s.x, s.y = point ~= "" and point or "CENTER", math.floor(x + 0.5), math.floor(y + 0.5)
    return s, scale
end

-- Save the target so its centre lands on (cx, cy).
local function commit(e, cx, cy, scale, alpha)
    local s
    s, scale = placement(e, cx, cy, scale, saved(e))
    if not e.noScale then s.scale = scale end
    if alpha and not e.noAlpha then s.alpha = alpha end
    if e.store then e.store.set(s) else M.db.frames[e.key] = s end
    apply(e)
end

local function snapped(v, origin)
    local g = M.db.gridSize
    if not M.db.snap or g <= 0 then return v end
    return origin + math.floor((v - origin) / g + 0.5) * g
end

-- Edge snapping: pull the dragged box's centre so one of its edges (or its centre line) meets another
-- shown frame's edge when within SNAP px. Returns the adjusted centre.
local SNAP = 10
function M.SnapToEdges(cx, cy, w, h, others)
    local bestX, bestY = SNAP + 1, SNAP + 1
    local nx, ny = cx, cy
    for _, o in ipairs(others) do
        local ox, oy, ow, oh = o[1], o[2], o[3], o[4]
        for _, mine in ipairs({ -w / 2, 0, w / 2 }) do
            for _, theirs in ipairs({ -ow / 2, 0, ow / 2 }) do
                local d = (ox + theirs) - (cx + mine)
                if math.abs(d) < math.abs(bestX) then bestX, nx = d, cx + d end
            end
        end
        for _, mine in ipairs({ -h / 2, 0, h / 2 }) do
            for _, theirs in ipairs({ -oh / 2, 0, oh / 2 }) do
                local d = (oy + theirs) - (cy + mine)
                if math.abs(d) < math.abs(bestY) then bestY, ny = d, cy + d end
            end
        end
    end
    return nx, ny
end

---------------------------------------------------------------- overlays
local overlays = {}

local function paintOverlay(o)
    local sel = selected == o.entry
    Skin:Panel(o, "raised", { border = sel and "accent.primary" or "border.strong" })
    W.Color(o.fill, "accent.primary", sel and 0.22 or 0.1)
    Skin:Text(o.label, o.role or "body", sel and "text.primary" or "text.secondary")
end

local function syncOverlay(o)
    local f = resolve(o.entry)
    local cx, cy, w, h = centerOf(f)
    if not cx then o:Hide(); return end
    o:ClearAllPoints()
    o:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    w, h = math.max(OVERLAY_MIN_W, w), math.max(OVERLAY_MIN_H, h)
    o:SetSize(w, h)
    -- the name always fits inside its box: smaller type on small boxes, elided when still too long;
    -- the coordinates line only where there is room for two lines
    local roomy = h >= 34
    o.role = (w < 120 or h < 26) and "small" or "body"
    Skin:Text(o.label, o.role, selected == o.entry and "text.primary" or "text.secondary")
    o.label:SetWidth(w - 8)
    o.label:ClearAllPoints()
    o.label:SetPoint("CENTER", 0, (roomy and M.db.coords) and 6 or 0)
    o.state:SetWidth(w - 8)
    o:SetFrameLevel(60 + math.max(0, 20 - math.floor(w * h / 20000))) -- smaller boxes on top, so each stays clickable
    local s = saved(o.entry)
    o.state:SetShown(M.db.coords and roomy)
    o.state:SetText(s and s.point and ("%s  %d, %d"):format(s.point, s.x, s.y) or L.MOVERS_DEFAULT_POS)
    -- a registered frame may draw extra guides inside its box (combat text areas draw their scroll path)
    local st = o.entry.store
    if st and st.decorate then ns.SafeCall(st.decorate, o, w, h) end
end

-- Puts a registered frame's box back over the frame (another module moved the frame itself, e.g. the other
-- bars of an action bar multi-selection following the dragged one).
function M:SyncOverlay(key)
    local o = overlays[key]
    if o then syncOverlay(o) end
end

-- Every other shown overlay's box, for edge snapping.
local function otherBoxes(self)
    local out = {}
    for _, other in pairs(overlays) do
        if other ~= self and other:IsShown() then
            local x, y = other:GetCenter()
            if x then out[#out + 1] = { x, y, other:GetWidth(), other:GetHeight() } end
        end
    end
    return out
end

-- Centre (UIParent units) of the overlay at the end of a drag: grid snap, then edge snap.
local function dropPoint(self)
    local cx, cy = self:GetCenter()
    cx, cy = snapped(cx, UIParent:GetWidth() / 2), snapped(cy, UIParent:GetHeight() / 2)
    if M.db.snapFrames then cx, cy = M.SnapToEdges(cx, cy, self:GetWidth(), self:GetHeight(), otherBoxes(self)) end
    return cx, cy
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

-- Exact placement from the popup: the saved {point, x, y} (UIParent units), or for a frame never moved the
-- numbers of where it is now (nothing is saved until a value is changed).
function M.PositionOf(e)
    local s = saved(e)
    if s and s.point then return s end
    local f = resolve(e)
    if not f or blocked(f) then return nil end
    local cx, cy = centerOf(f)
    if not cx then return nil end
    return (placement(e, cx, cy))
end
function M.SetPosition(e, point, x, y)
    local f = resolve(e)
    if not f or blocked(f) then return end
    local s = M.PositionOf(e)
    if not s then return end
    s = saved(e) or s
    if not e.noScale and not s.scale then s.scale = f:GetScale() end
    s.point, s.x, s.y = point or s.point, math.floor((x or s.x) + 0.5), math.floor((y or s.y) + 0.5)
    if e.store then e.store.set(s) else M.db.frames[e.key] = s end
    apply(e)
    if overlays[e.key] then syncOverlay(overlays[e.key]) end
    if toolbar then toolbar:Update() end
end

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
    if not e.store then self.db.frames[key] = nil end
    restore(e)
    if overlays[key] then syncOverlay(overlays[key]) end
    if toolbar then toolbar:Update() end
    ns.Events:Fire("PUI_MOVERS")
end

---------------------------------------------------------------- any frame (MoveAny level, t194)
-- Add any named frame to Layout mode, by typing its name or by clicking it on screen. It then moves, scales and
-- fades like the built-in entries (per profile, db.frames["any:<name>"]). Frames Edit Mode manages, forbidden
-- frames and the screen roots are refused; protected ones are placed out of combat only (apply / blocked).
local ROOTS = { UIParent = true, WorldFrame = true }
local function anyKey(name) return "any:" .. name end
M.AnyKey = anyKey

function M.FrameByName(name)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" or ROOTS[name] then return nil, "MOVERS_ANY_BAD" end
    local f = _G[name]
    if type(f) ~= "table" or type(f.GetObjectType) ~= "function" or not f.SetPoint then return nil, "MOVERS_ANY_BAD" end
    if f:IsForbidden() then return nil, "MOVERS_ANY_BAD" end
    if M.IsManaged(f) then return nil, "MOVERS_ANY_MANAGED" end
    return f, name
end

local function registerAny(name)
    local key = anyKey(name)
    if byKey[key] then return byKey[key] end
    local e = { key = key, frame = name, text = name, any = true }
    entries[#entries + 1], byKey[key] = e, e
    return e
end

function M:AddAnyFrame(name)
    local f, clean = M.FrameByName(name)
    if not f then return nil, clean end
    local list = self.db.any
    for _, n in ipairs(list) do if n == clean then return clean end end
    list[#list + 1] = clean
    registerAny(clean)
    ns.Events:Fire("PUI_MOVERS")
    return clean
end

function M:RemoveAnyFrame(name)
    local list, key = self.db.any, anyKey(name or "")
    local found
    for i = #list, 1, -1 do if list[i] == name then table.remove(list, i); found = true end end
    if not found then return false end
    self:ResetFrame(key)
    for i = #entries, 1, -1 do if entries[i].key == key then table.remove(entries, i) end end
    byKey[key] = nil
    if overlays[key] then overlays[key]:Hide(); overlays[key] = nil end
    ns.Events:Fire("PUI_MOVERS")
    return true
end

function M:RegisterAnyFrames()
    for _, n in ipairs(self.db.any or {}) do registerAny(n) end
end

-- The named frame under a screen point's mouse focus: the first ancestor with a global name that is usable.
function M.NamedAncestor(f)
    while f and f.GetName do
        local n = f:GetName()
        if n and not ROOTS[n] and _G[n] == f and M.FrameByName(n) then return n end
        f = f.GetParent and f:GetParent()
    end
end

-- Click-to-pick: a full-screen catcher takes the next click, steps aside, and reads what was under the mouse.
local catcher
function M:PickFrame(done)
    if InCombatLockdown() then return false end
    if not catcher then
        catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("TOOLTIP")
        catcher.tint = catcher:CreateTexture(nil, "BACKGROUND")
        catcher.tint:SetAllPoints(); catcher.tint:SetColorTexture(1, 0.5, 0.1, 0.08)
        catcher.text = catcher:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        catcher.text:SetPoint("TOP", 0, -120)
        catcher:RegisterForClicks("AnyUp")
    end
    catcher.text:SetText(L.MOVERS_ANY_PICKING)
    catcher:SetScript("OnClick", function(self, button)
        self:Hide()
        if button ~= "LeftButton" then return done(nil) end
        C_Timer.After(0, function()
            local foci = GetMouseFoci and GetMouseFoci() or {}
            local name
            for _, f in ipairs(foci or {}) do name = name or M.NamedAncestor(f) end
            done(name)
        end)
    end)
    catcher:Show()
    return true
end

function M:ResetAll()
    for _, e in ipairs(entries) do
        if not e.store then self.db.frames[e.key] = nil end
        restore(e)
    end
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
    -- the cog opens this frame's own settings right on the box (Popup.lua)
    o.cog = W:IconButton(o, "cog", 18, L.MOVERS_SETTINGS)
    o.cog:SetPoint("TOPRIGHT", -2, -2)
    o.cog.onClick = function() selectEntry(e); M:OpenPopup(e, o) end
    Skin:Register(o, paintOverlay)
    o:SetScript("OnDragStart", function(self)
        if blocked(resolve(e)) then return end
        selectEntry(e)
        self.dragging = true
        self:StartMoving()
        -- live coordinates while dragging
        if M.db.coords then
            self:SetScript("OnUpdate", function(me)
                local x, y = me:GetCenter()
                if x then me.state:SetFormattedText("%d, %d", x - UIParent:GetWidth() / 2, y - UIParent:GetHeight() / 2) end
            end)
        end
    end)
    o:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        self.dragging = false
        commit(e, dropPoint(self))
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
        if M.db.arrows and not InCombatLockdown() then self:EnableKeyboard(true) end
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
function M.EditModeActive()
    local em = _G.EditModeManagerFrame
    return em ~= nil and em.IsShown ~= nil and em:IsShown() == true
end

function M:SetUnlocked(on)
    if on and InCombatLockdown() then
        ns:Print(L.MOVERS_COMBAT)
        return
    end
    if on and not self:IsEnabled() then return end
    -- Blizzard Edit Mode draws its own grid and labels over the same frames (defect #19): one mode at a time
    if on and M.EditModeActive() then
        ns:Print(L.MOVERS_EDITMODE)
        return
    end
    unlocked = on and true or false
    -- frames that only show now and then (flight timer, threat meter) put up a sample first, so they get a box
    for _, e in ipairs(entries) do
        if e.store and e.store.preview then ns.SafeCall(e.store.preview, unlocked) end
    end
    if unlocked then
        grid = grid or buildGrid()
        if self.db.grid then grid:Layout(); grid:Show() else grid:Hide() end
        for _, o in pairs(overlays) do o:Hide() end
        for _, e in ipairs(entries) do
            if usable(e) then
                local o = overlayFor(e)
                o:Show()
                syncOverlay(o)
            end
        end
        toolbar = toolbar or self:BuildToolbar() -- Toolbar.lua
        toolbar:Show()
        if not (selected and usable(selected)) then
            selected = nil
            for _, e in ipairs(entries) do if usable(e) then selected = e; break end end
        end
        selectEntry(selected)
    else
        if grid then grid:Hide() end
        for _, o in pairs(overlays) do
            o:EnableKeyboard(false)
            o:Hide()
        end
        if toolbar then toolbar:Hide() end
        if M.ClosePopup then M:ClosePopup() end
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

---------------------------------------------------------------- Blizzard windows scale
local scaledHooks = {}
local function scaleWindow(f)
    if not (M:IsEnabled() and type(f) == "table" and f.SetScale) or f:IsForbidden() or M.IsManaged(f) then return end
    local want = ns.Util.SafeScale(M.db.windowScale)
    if blocked(f) then return ns.Combat:Run("movers.window", scaleWindow, f) end
    if want == 1 and not scaledHooks[f] then return end
    f:SetScale(want)
end

function M:ApplyWindowScale()
    for _, name in ipairs(M.WINDOWS) do
        local f = rawget(_G, name) -- load-on-demand windows may not exist yet
        if type(f) == "table" and f.HookScript then
            if not scaledHooks[f] and (self.db.windowScale or 1) ~= 1 then
                scaledHooks[f] = true
                f:HookScript("OnShow", scaleWindow)
            end
            if scaledHooks[f] and f:IsShown() then scaleWindow(f) end
        end
    end
end

---------------------------------------------------------------- unlock key
-- An override binding (ours, owned by a hidden frame) clicks our own toggle button: no Blizzard binding changes.
local keyOwner = CreateFrame("Frame")
local toggleButton = CreateFrame("Button", "PhoenixUI_MoversToggle", UIParent)
toggleButton:Hide()
toggleButton:SetScript("OnClick", function() if not InCombatLockdown() then M:SetUnlocked(not unlocked) end end)

-- "ctrl-shift-m" -> "CTRL-SHIFT-M"; empty or malformed keys bind nothing.
function M.NormalizeKey(text)
    local key = tostring(text or ""):upper():gsub("%s+", "")
    if key == "" or key:find("[^%w%-]") then return nil end
    return key
end

function M:ApplyUnlockKey(off)
    ns.Combat:Run("movers.key", function()
        ClearOverrideBindings(keyOwner)
        local key = not off and M:IsEnabled() and M.NormalizeKey(M.db.unlockKey)
        if key then SetOverrideBindingClick(keyOwner, true, key, toggleButton:GetName(), "LeftButton") end
    end)
end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    self:RegisterAnyFrames()
    self:ApplyAll()
    self:ApplyWindowScale()
    self:ApplyUnlockKey()
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function()
        if unlocked then
            self:SetUnlocked(false)
            ns:Print(L.MOVERS_COMBAT_LOCKED)
        end
    end)
    ns.Events:On("ADDON_LOADED", self, function() self:ApplyAll(); self:ApplyWindowScale() end) -- load-on-demand frames
    ns.Events:On("UI_SCALE_CHANGED", self, function() if grid and grid:IsShown() then grid:Layout() end end)
    ns.Events:On("DISPLAY_SIZE_CHANGED", self, function() if grid and grid:IsShown() then grid:Layout() end end)
    EventRegistry:RegisterCallback("EditMode.Enter", function() if unlocked then self:SetUnlocked(false) end end, self)
end

function M:OnDisable()
    self:SetUnlocked(false)
    self:ApplyUnlockKey(true)
    EventRegistry:UnregisterCallback("EditMode.Enter", self)
    for _, e in ipairs(entries) do if not e.store then restore(e) end end
end

function M:Refresh()
    self:ApplyAll()
    self:ApplyWindowScale()
    self:ApplyUnlockKey()
    if unlocked then
        if self.db.grid then grid:Layout(); grid:Show() else grid:Hide() end
        for _, o in pairs(overlays) do syncOverlay(o) end
        if toolbar then toolbar:Update() end
    end
end

function M:OnProfileChanged()
    self:RegisterAnyFrames()
    if self:ShouldEnable() then
        if self:IsEnabled() then self:Refresh() else self:Enable() end
    else
        self:Disable()
    end
end
