local _, ns = ...
local Skin, Media, Theme, Secret = ns.Skin, ns.Media, ns.Theme, ns.Secret
local M = ns.modules.Tracker

--[[ Blizzard's Cooldown Manager viewers (EssentialCooldownViewer, UtilityCooldownViewer, BuffIconCooldownViewer,
    BuffBarCooldownViewer; Blizzard_CooldownViewer, loaded on retail and WoW Forever).
    Look      every item frame is dressed once when the viewer acquires it (OnAcquireItemFrame post-hook): square
              or round icon, zoom, border, Phoenix fonts for stacks, charges, keybinds and bar texts.
    Layout    a post-hook on the viewer's Layout (GridLayoutFrame) re-anchors the item frames on Phoenix's grid
              (M.Grid / M.Stack) around a Phoenix anchor frame: on the viewer itself (Edit Mode keeps moving
              the viewer) or on a Phoenix mover. The viewer, an Edit Mode system, is never moved or resized;
              item frames are plain frames, so this is allowed in combat too.
    Behaviour post-hooks on the item's own refresh methods: desaturation off, GCD swipe hidden, swipe opacity,
              range/usable tint off; proc glows through ActionButtonSpellAlertManager hooks (Phoenix glow styles);
              a ready glow when the cooldown frame finishes a real cooldown.
    No cooldown, aura or duration value is read except the item's own isOnGCD / isOnActualCooldown flags, and
    those only when they are plain (Secret.IsSecret); Blizzard keeps feeding the protected data into its widgets.
    Countdown numbers: Cooldown Text styles them (timerSource "cooldowntext"), or the viewer claims them from
    Cooldown Text and paints its own font ("own"). ]]

local keyOf = {}     -- viewer frame -> key
local viewers = {}   -- key -> viewer frame
local anchors = {}   -- key -> Phoenix anchor frame (the grid's top-left lives here)
local itemKey = setmetatable({}, { __mode = "k" }) -- item frame -> key
local parts = setmetatable({}, { __mode = "k" })   -- item frame -> { border, keybind }
local extras = setmetatable({}, { __mode = "k" })  -- item frame -> { masks = {}, overlays = {} }
local hookedItem = setmetatable({}, { __mode = "k" })
local readyTimers = setmetatable({}, { __mode = "k" })
M.anchors, M.viewerFrames = anchors, viewers

---------------------------------------------------------------- style (shared with the options preview)
function M:BarTexture(key)
    local v = self:Viewer(key)
    return v.texture and v.texture ~= "" and Media:Bar(v.texture) or Theme:Bar()
end

function M:BarColor(key)
    local c = self:Viewer(key).barColor
    if type(c) == "table" then return c.r, c.g, c.b end
    return Theme:Color("accent.primary")
end

-- icon: the Texture; holder: frame around it for the border; timer/count/keybind: FontStrings (may be nil).
function M:StyleIcon(key, icon, holder, timer, count, keybind)
    local v = self:Viewer(key)
    Skin:IconZoom(icon, v.square and v.zoom or 0)
    Skin:BorderSpec(holder, v.square and v.border or { style = "none" }, "border.black")
    if timer then Skin:TextSpec(timer, v.timer, "number", "text.primary") end
    if count then Skin:TextSpec(count, v.count, "number", "text.primary") end
    if keybind then
        Skin:TextSpec(keybind, v.keybind, "number", "text.secondary")
        Skin:Place(keybind, holder, v.keybind)
    end
end

function M:StyleBar(key, bar, name, duration)
    local v = self:Viewer(key)
    bar:SetStatusBarTexture(self:BarTexture(key))
    bar:SetStatusBarColor(self:BarColor(key))
    if bar.SetReverseFill then bar:SetReverseFill(v.layout.reverse and true or false) end
    Skin:Backdrop(bar, v.background or { alpha = 0 }, "bg.sunken")
    if name then Skin:TextSpec(name, v.name or v.timer, "unit", "text.primary") end
    if duration then Skin:TextSpec(duration, v.timer, "number", "text.primary") end
end

function M:GlowColor(key, which)
    local v = self:Viewer(key)
    local r, g, b = Skin:SpecColor(v[which], which == "readyColor" and "state.success" or "accent.glow")
    return r, g, b, 1
end

---------------------------------------------------------------- countdown numbers: Cooldown Text or our own
local function countdown(key, cd)
    if not (cd and cd.GetCountdownFontString) then return end
    local v, ct = M:Viewer(key), ns.modules.CooldownText
    local own = v.timerSource == "own"
    if ct and ct.Claim then ct:Claim(cd, own) end
    if own then
        local fs = cd:GetCountdownFontString()
        if fs then Skin:TextSpec(fs, v.timer, "number", "text.primary") end
    end
end

---------------------------------------------------------------- Blizzard item frames
-- The round mask and the ring overlay Blizzard draws on every icon (unnamed regions).
local function artOf(frame, iconHost)
    local e = extras[frame]
    if e then return e end
    e = { masks = {}, overlays = {} }
    local icon = iconHost.Icon
    for i = 1, (icon.GetNumMaskTextures and icon:GetNumMaskTextures() or 0) do
        e.masks[#e.masks + 1] = icon:GetMaskTexture(i)
    end
    for _, region in ipairs({ iconHost:GetRegions() }) do
        if region ~= icon and region:IsObjectType("Texture") and region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
            e.overlays[#e.overlays + 1] = region
        end
    end
    extras[frame] = e
    return e
end

local function setRound(icon, e, round)
    for _, mask in ipairs(e.masks) do
        if round then
            if not e.removed then break end
            icon:AddMaskTexture(mask)
        else
            icon:RemoveMaskTexture(mask)
        end
    end
    e.removed = not round
    for _, o in ipairs(e.overlays) do o:SetAlpha(round and 1 or 0) end
end

local function partsOf(frame, iconHost, icon)
    local p = parts[frame]
    if p then return p end
    local holder = CreateFrame("Frame", nil, iconHost)
    holder:SetAllPoints(icon)
    holder:SetFrameLevel(iconHost:GetFrameLevel() + 2)
    p = { border = holder, keybind = holder:CreateFontString(nil, "OVERLAY") }
    parts[frame] = p
    return p
end

-- Keybind text: the action slots holding the item's spell (C_ActionBar.FindSpellActionButtons) and the keys bound
-- to the buttons showing those slots (M.SlotKeys, rebuilt on UPDATE_BINDINGS / ACTIONBAR_SLOT_CHANGED).
local slotKeys = {}
local BUTTONS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }

function M.RebuildSlotKeys()
    wipe(slotKeys)
    local ab = ns.modules.ActionBars
    for _, prefix in ipairs(BUTTONS) do
        for i = 1, 12 do
            local b = _G[prefix .. i]
            local slot = b and b.action
            if type(slot) == "number" and not Secret.IsSecret(slot) and not slotKeys[slot] then
                local cmd = b.commandName
                local key = ab and ab.BindingKey and ab.BindingKey(b) or (type(cmd) == "string" and GetBindingKey(cmd))
                if key then slotKeys[slot] = ab and ab.ShortKey and ab.ShortKey(key) or key end
            end
        end
    end
end

function M.KeyForSpell(spellID)
    if type(spellID) ~= "number" or Secret.IsSecret(spellID) or not (C_ActionBar and C_ActionBar.FindSpellActionButtons) then
        return nil
    end
    local ok, slots = pcall(C_ActionBar.FindSpellActionButtons, spellID)
    if not ok or type(slots) ~= "table" then return nil end
    for _, slot in ipairs(slots) do
        if not Secret.IsSecret(slot) and slotKeys[slot] then return slotKeys[slot] end
    end
end

local function spellOf(frame)
    if not frame.GetSpellID then return nil end
    local ok, id = pcall(frame.GetSpellID, frame)
    if ok and type(id) == "number" and not Secret.IsSecret(id) then return id end
end

local function updateKeybind(key, frame)
    local p = parts[frame]
    if not p then return end
    local v = M:Viewer(key)
    local text = v.keybinds and v.style and M.KeyForSpell(spellOf(frame)) or nil
    p.keybind:SetText(text or "")
    p.keybind:SetShown(text ~= nil)
end

local function styleItem(key, frame)
    local v = M:Viewer(key)
    if not v.style or frame:IsForbidden() then return end
    local iconHost = M.IsBars(key) and frame.Icon or frame
    local icon = iconHost and iconHost.Icon
    if not (icon and icon.SetTexCoord) then return end
    setRound(icon, artOf(frame, iconHost), not v.square)
    local p = partsOf(frame, iconHost, icon)
    local count = (frame.ChargeCount and frame.ChargeCount.Current) or (frame.Applications and frame.Applications.Applications)
        or (M.IsBars(key) and frame.Icon and frame.Icon.Applications)
    M:StyleIcon(key, icon, p.border, nil, count, p.keybind)
    countdown(key, frame.Cooldown)
    if frame.DebuffBorder then frame.DebuffBorder:SetAlpha(v.hideDebuffBorder and 0 or 1) end
    if M.IsBars(key) and frame.Bar then
        M:StyleBar(key, frame.Bar, frame.Bar.Name, frame.Bar.Duration)
        if frame.Bar.BarBG then frame.Bar.BarBG:SetAlpha(0) end
    end
    updateKeybind(key, frame)
end
M.StyleItem = styleItem

---------------------------------------------------------------- behaviour hooks on each item frame
local function afterDesat(frame)
    local key = itemKey[frame]
    if not key or not M:IsEnabled() then return end
    local icon = frame.Icon
    if not M:Viewer(key).desaturate and icon and icon.SetDesaturated then icon:SetDesaturated(false) end
end

local function afterCooldown(frame)
    local key = itemKey[frame]
    if not key or not M:IsEnabled() then return end
    local v, cd = M:Viewer(key), frame.Cooldown
    if not cd then return end
    if v.style then cd:SetSwipeColor(0, 0, 0, v.swipeAlpha) end
    local gcd = frame.isOnGCD
    if v.hideGCD and not Secret.IsSecret(gcd) and gcd == true then
        cd:SetDrawSwipe(false)
        cd:SetDrawEdge(false)
    end
    local real = frame.isOnActualCooldown
    if not Secret.IsSecret(real) then frame.phoenixReal = real and true or nil end
end

local function afterColor(frame)
    local key = itemKey[frame]
    if not key or not M:IsEnabled() or M:Viewer(key).rangeTint then return end
    local icon = frame.Icon
    if icon and icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
    if frame.OutOfRange then frame.OutOfRange:SetAlpha(0) end
end

local function hideReady(frame)
    readyTimers[frame] = nil
    ns.Glow:Hide(frame, "ready")
end

-- The cooldown frame finished: glow for readyTime seconds when the item was on a real (not global) cooldown.
local function onDone(frame)
    local key = itemKey[frame]
    if not key or not M:IsEnabled() then return end
    local v = M:Viewer(key)
    if v.readyGlow == "none" or not frame.phoenixReal then return end
    frame.phoenixReal = nil
    local r, g, b, a = M:GlowColor(key, "readyColor")
    ns.Glow:Show(frame, v.readyGlow, r, g, b, a, "ready")
    local t = readyTimers[frame]
    if t then t:Cancel() end
    readyTimers[frame] = C_Timer.NewTimer(v.readyTime, function() hideReady(frame) end)
end

local function hookMethod(frame, name, fn)
    if type(frame[name]) == "function" then hooksecurefunc(frame, name, fn) end
end

local function hookItem(frame)
    if hookedItem[frame] then return end
    hookedItem[frame] = true
    hookMethod(frame, "RefreshIconDesaturation", afterDesat)
    hookMethod(frame, "RefreshSpellCooldownInfo", afterCooldown)
    hookMethod(frame, "RefreshIconColor", afterColor)
    local cd = frame.Cooldown
    if cd and cd.HookScript then cd:HookScript("OnCooldownDone", function() onDone(frame) end) end
    -- shown/hidden buffs move the others unless they keep their place
    frame:HookScript("OnShow", function() if itemKey[frame] then M:QueueLayout(itemKey[frame]) end end)
    frame:HookScript("OnHide", function() if itemKey[frame] then M:QueueLayout(itemKey[frame]) end end)
end

-- Proc glows: Blizzard's spell alert (style "blizzard"), a Phoenix glow instead, or none.
local function onAlert(_, frame)
    local key = frame and itemKey[frame]
    if not key or not M:IsEnabled() then return end
    local style = M:Viewer(key).procGlow
    local manager = ActionButtonSpellAlertManager
    local has = manager and manager.HasAlert and manager:HasAlert(frame)
    local alert = frame.SpellActivationAlert
    if alert then alert:SetAlpha(style == "blizzard" and 1 or 0) end
    if has and style ~= "blizzard" and style ~= "none" then
        local r, g, b, a = M:GlowColor(key, "procColor")
        ns.Glow:Show(frame, style, r, g, b, a, "proc")
    else
        ns.Glow:Hide(frame, "proc")
    end
end

---------------------------------------------------------------- layout on Phoenix's grid
local function sorted(viewer, key)
    local list, v = {}, M:Viewer(key)
    local pool = viewer.itemFramePool
    if not pool then return list end
    for frame in pool:EnumerateActive() do
        local shown = frame:IsShown()
        if v.layout.keepInPlace or Secret.IsSecret(shown) or shown then list[#list + 1] = frame end
    end
    table.sort(list, function(a, b) return (tonumber(a.layoutIndex) or 0) < (tonumber(b.layoutIndex) or 0) end)
    return list
end

local EDGE = { DOWN = "TOP", UP = "BOTTOM", RIGHT = "LEFT", LEFT = "RIGHT" }

-- Where the anchor sits: on the Blizzard viewer (Edit Mode moves it) or at the saved mover position.
function M:PlaceAnchor(key, w, h)
    local a = anchors[key]
    if not a then
        a = CreateFrame("Frame", "PhoenixUI_CDM_" .. key, UIParent)
        a:SetSize(1, 1)
        anchors[key] = a
    end
    local v = self:Viewer(key)
    a:SetSize(math.max(1, w or a:GetWidth()), math.max(1, h or a:GetHeight()))
    a:ClearAllPoints()
    local viewer = viewers[key]
    if v.position.mode == "editmode" and viewer then
        local edge = EDGE[M.WrapFor(v.layout.growth or "RIGHT", v.layout.wrap or "DOWN")] or "TOP"
        a:SetPoint(edge, viewer, edge, 0, 0)
    else
        a:SetPoint(v.position.point, UIParent, v.position.point, v.position.x, v.position.y)
    end
    return a
end

local function scaled(L, k)
    local out = {}
    for name, val in pairs(L) do out[name] = val end
    out.size, out.spacing = math.floor(L.size * k + 0.5), math.floor(L.spacing * k + 0.5)
    return out
end

local function placeIcons(key, list, extra)
    local v = M:Viewer(key)
    local k = v.position.mode == "mover" and (v.position.scale or 1) or 1
    local L = scaled(v.layout, k)
    local all = list
    if extra and #extra > 0 then
        all = {}
        for _, f in ipairs(extra) do all[#all + 1] = f end
        for _, f in ipairs(list) do all[#all + 1] = f end
    end
    local pos, w, h = M.Grid(#all, L)
    local a = M:PlaceAnchor(key, w, h)
    local left = {}
    for i, frame in ipairs(all) do
        local p = pos[i]
        if p then
            frame:SetScale(1)
            frame:SetSize(p.size, p.size)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", a, "TOPLEFT", p.x, -p.y)
            frame:SetAlpha(1)
        else
            left[#left + 1] = frame
        end
    end
    return left
end

local function placeBars(key, list)
    local v = M:Viewer(key)
    local L = v.layout
    local k = v.position.mode == "mover" and (v.position.scale or 1) or 1
    local w, h = math.floor(L.width * k + 0.5), math.floor(L.height * k + 0.5)
    local ys, total = M.Stack(#list, { height = h, spacing = L.spacing, wrap = L.wrap })
    local a = M:PlaceAnchor(key, w, total)
    for i, frame in ipairs(list) do
        frame:SetScale(1)
        frame:SetSize(w, h)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -ys[i])
        local icon, bar = frame.Icon, frame.Bar
        if icon and bar then
            icon:SetSize(h, h)
            icon:ClearAllPoints()
            bar:ClearAllPoints()
            bar:SetHeight(h)
            icon:SetAlpha(L.iconSide == "OFF" and 0 or 1)
            if L.iconSide == "RIGHT" then
                icon:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
                bar:SetPoint("LEFT", frame, "LEFT", 0, 0)
                bar:SetPoint("RIGHT", icon, "LEFT", -2, 0)
            elseif L.iconSide == "OFF" then
                icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
                bar:SetPoint("LEFT", frame, "LEFT", 0, 0)
                bar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            else
                icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
                bar:SetPoint("LEFT", icon, "RIGHT", 2, 0)
                bar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            end
        end
    end
end

local function phoenixLayout(key)
    local v = M:Viewer(key)
    return M:IsEnabled() and v.style and v.layout.enabled
end

-- Lays out one viewer (and, for Essential with overflow "utility", the Utility viewer after it).
function M:LayoutViewer(key)
    local viewer = viewers[key]
    if not viewer or not phoenixLayout(key) then return end
    local list = sorted(viewer, key)
    if M.IsBars(key) then placeBars(key, list); return end
    local extra
    if key == "utility" and phoenixLayout("essential") and self:Viewer("essential").layout.overflow == "utility" then
        extra = self.essentialOverflow
    end
    local left = placeIcons(key, list, extra)
    if key == "essential" then
        local overflow = self:Viewer("essential").layout.overflow
        self.essentialOverflow = overflow == "utility" and left or nil
        for _, frame in ipairs(left) do
            if overflow ~= "utility" or not viewers.utility then frame:SetAlpha(0) end
        end
        if overflow == "utility" and viewers.utility then self:LayoutViewer("utility") end
    else
        for _, frame in ipairs(left) do frame:SetAlpha(0) end
    end
end

-- Show / hide events arrive one item at a time: lay a viewer out once on the next frame.
local queued, driver = {}, CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self)
    self:Hide()
    for key in pairs(queued) do
        queued[key] = nil
        ns.SafeCall(M.LayoutViewer, M, key)
    end
end)
function M:QueueLayout(key) queued[key] = true; driver:Show() end

---------------------------------------------------------------- viewers
local function onAcquire(viewerFrame, frame)
    local key = keyOf[viewerFrame]
    if not key or not M:IsEnabled() then return end
    itemKey[frame] = key
    ns.SafeCall(hookItem, frame)
    ns.SafeCall(styleItem, key, frame)
end

local function eachItem(key, fn)
    local f = viewers[key]
    if not (f and f.itemFramePool) then return end
    for frame in f.itemFramePool:EnumerateActive() do
        itemKey[frame] = key
        fn(key, frame)
    end
end

local function styleViewer(key)
    eachItem(key, function(k, frame)
        ns.SafeCall(hookItem, frame)
        ns.SafeCall(styleItem, k, frame)
    end)
end

local hooked, alertsHooked = {}, false
local function hookViewers()
    for _, def in ipairs(M.VIEWERS) do
        local f = def.frame and _G[def.frame]
        if f and not hooked[f] and f.OnAcquireItemFrame then
            hooked[f] = true
            keyOf[f], viewers[def.key] = def.key, f
            hooksecurefunc(f, "OnAcquireItemFrame", onAcquire)
            if type(f.Layout) == "function" then
                hooksecurefunc(f, "Layout", function() if M:IsEnabled() then M:QueueLayout(def.key) end end)
            end
        end
    end
    if not alertsHooked and ActionButtonSpellAlertManager then
        alertsHooked = true
        hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", onAlert)
        hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", onAlert)
    end
end

-- Viewer opacity: visibility rules and the out-of-combat fade (custom bars do the same on their own anchors).
function M:ApplyViewerAlpha(state)
    for key, f in pairs(viewers) do f:SetAlpha(self:AlphaFor(key, state)) end
end

---------------------------------------------------------------- movers (viewers placed by Phoenix)
local function store(key)
    return {
        active = function() return M:IsEnabled() and M:Viewer(key).position.mode == "mover" end,
        get = function() local p = M:Viewer(key).position; return { point = p.point, x = p.x, y = p.y, scale = p.scale } end,
        set = function(val)
            local p = M:Viewer(key).position
            p.point, p.x, p.y = val.point or p.point, val.x or p.x, val.y or p.y
            if val.scale then p.scale = val.scale end
        end,
        apply = function() M:Refresh() end,
        reset = function()
            local p, d = M:Viewer(key).position, M.defaults.viewers[key].position
            p.point, p.x, p.y, p.scale = d.point, d.x, d.y, d.scale
            M:Refresh()
        end,
    }
end
M.MoverStore = store

M.MOVER_LABELS = { essential = "TRACKER_ESSENTIAL", utility = "TRACKER_UTILITY", buffs = "TRACKER_BUFFS",
    bars = "TRACKER_BARS", custom1 = "TRACKER_CUSTOM1", custom2 = "TRACKER_CUSTOM2", custom3 = "TRACKER_CUSTOM3" }

function M:RegisterMovers()
    local movers = ns:GetModule("Movers")
    if not movers or self.moversDone then return end
    self.moversDone = true
    for _, def in ipairs(M.VIEWERS) do
        local a = anchors[def.key] or self:PlaceAnchor(def.key)
        movers:Register("cdm." .. def.key, a, ns.L[M.MOVER_LABELS[def.key]], store(def.key))
    end
end

---------------------------------------------------------------- Blizzard's own settings
-- Blizzard's own spell picker for the viewers (the "Advanced Cooldown Settings" window).
function M:OpenCooldownManager()
    if InCombatLockdown() then return end
    if not CooldownViewerSettings and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_CooldownViewer") end
    if CooldownViewerSettings and CooldownViewerSettings.TogglePanel then CooldownViewerSettings:TogglePanel() end
end

-- The game's master switch (CVar cooldownViewerEnabled) is Quality of Life's row; the options page mirrors it.

---------------------------------------------------------------- lifecycle
function M:EnableViewers()
    hookViewers()
    self:On("ADDON_LOADED", function(_, _, name)
        if name == "Blizzard_CooldownViewer" then
            hookViewers()
            self:Refresh()
        end
    end)
    local function rebind()
        M.RebuildSlotKeys()
        for key in pairs(viewers) do eachItem(key, updateKeybind) end
    end
    self:On("UPDATE_BINDINGS", rebind)
    self:On("ACTIONBAR_SLOT_CHANGED", rebind)
    self:On("PLAYER_LOGIN", rebind)
    M.RebuildSlotKeys()
    self:RegisterMovers()
end

function M:DisableViewers()
    for _, f in pairs(viewers) do f:SetAlpha(1) end
    local ct = ns.modules.CooldownText
    for frame in pairs(itemKey) do
        if ct and ct.Claim and frame.Cooldown then ct:Claim(frame.Cooldown, false) end
        ns.Glow:Hide(frame, "proc")
        ns.Glow:Hide(frame, "ready")
    end
end

function M:RefreshViewers()
    for key in pairs(viewers) do
        styleViewer(key)
        self:QueueLayout(key)
    end
    for _, def in ipairs(M.VIEWERS) do
        if not def.custom and not viewers[def.key] then self:PlaceAnchor(def.key) end
    end
end
