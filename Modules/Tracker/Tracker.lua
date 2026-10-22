local _, ns = ...
local Skin, Style, Media, Theme, Secret = ns.Skin, ns.Style, ns.Media, ns.Theme, ns.Secret

--[[ Tracker ("Auras & Cooldowns"): the Phoenix take on what WeakAuras did, inside the 12.x rules.
    Blizzard's Cooldown Manager viewers already receive the protected cooldown and aura data; we only dress
    their item frames (square or round icons, zoom, border, Phoenix fonts for timers, stacks and bar texts,
    bar texture and colour) and fade the viewers out of combat. No cooldown, aura or duration value is read:
    Blizzard keeps feeding them into the Cooldown and StatusBar widgets, which accept secret values.
    The countdown voice for pulls and start timers lives in Encounters (one owner per timer). ]]
local function viewer(timer, extra)
    local v = {
        style = true, square = true, zoom = 0.08, hideDebuffBorder = false,
        border = Style.Border({ style = "solid" }),
        timer = Style.Text(timer, { outline = "OUTLINE", shadow = false }),
        count = Style.Text(12, { outline = "OUTLINE", shadow = false }),
    }
    if extra then for k, val in pairs(extra) do v[k] = val end end
    return v
end

local M = ns:NewModule("Tracker", {
    label = "TRACKER", desc = "TRACKER_DESC", category = "combat", order = 15, icon = "tracker", reloadOnToggle = true,
    defaults = {
        viewers = {
            essential = viewer(16),
            utility = viewer(13),
            buffs = viewer(13),
            bars = viewer(12, {
                texture = "", barColor = false,
                background = Style.Background({ alpha = 0.7 }),
                name = Style.Text(12, { shadow = true }),
            }),
        },
        fade = { enabled = false, alpha = 0.35 },
    },
})

M.VIEWERS = {
    { key = "essential", frame = "EssentialCooldownViewer" },
    { key = "utility", frame = "UtilityCooldownViewer" },
    { key = "buffs", frame = "BuffIconCooldownViewer" },
    { key = "bars", frame = "BuffBarCooldownViewer" },
}
local keyOf = {} -- viewer frame -> key
local holders = setmetatable({}, { __mode = "k" }) -- item frame -> border frame
local extras = setmetatable({}, { __mode = "k" })  -- item frame -> { masks = {}, overlays = {} }

---------------------------------------------------------------- style (shared with the options preview)
function M:Viewer(key) return self.db.viewers[key] or self.db.viewers.essential end

function M:BarTexture(key)
    local v = self:Viewer(key)
    return v.texture and v.texture ~= "" and Media:Bar(v.texture) or Theme:Bar()
end

function M:BarColor(key)
    local c = self:Viewer(key).barColor
    if type(c) == "table" then return c.r, c.g, c.b end
    return Theme:Color("accent.primary")
end

-- icon: the Texture; holder: frame around it for the border; timer/count: FontStrings (may be nil).
function M:StyleIcon(key, icon, holder, timer, count)
    local v = self:Viewer(key)
    Skin:IconZoom(icon, v.square and v.zoom or 0)
    Skin:BorderSpec(holder, v.square and v.border or { style = "none" }, "border.black")
    if timer then Skin:TextSpec(timer, v.timer, "number", "text.primary") end
    if count then Skin:TextSpec(count, v.count, "number", "text.primary") end
end

function M:StyleBar(key, bar, name, duration)
    local v = self:Viewer(key)
    bar:SetStatusBarTexture(self:BarTexture(key))
    bar:SetStatusBarColor(self:BarColor(key))
    Skin:Backdrop(bar, v.background or { alpha = 0 }, "bg.sunken")
    if name then Skin:TextSpec(name, v.name or v.timer, "unit", "text.primary") end
    if duration then Skin:TextSpec(duration, v.timer, "number", "text.primary") end
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

local function styleItem(key, frame)
    local v = M:Viewer(key)
    if not v.style or frame:IsForbidden() then return end
    local iconHost = (key == "bars") and frame.Icon or frame
    local icon = iconHost and iconHost.Icon
    if not (icon and icon.SetTexCoord) then return end
    setRound(icon, artOf(frame, iconHost), not v.square)
    local holder = holders[frame]
    if not holder then
        holder = CreateFrame("Frame", nil, iconHost)
        holder:SetAllPoints(icon)
        holder:SetFrameLevel(iconHost:GetFrameLevel() + 2)
        holders[frame] = holder
    end
    local cd = frame.Cooldown
    local timer = cd and cd.GetCountdownFontString and cd:GetCountdownFontString()
    local count = (frame.ChargeCount and frame.ChargeCount.Current) or (frame.Applications and frame.Applications.Applications)
        or (key == "bars" and frame.Icon and frame.Icon.Applications)
    M:StyleIcon(key, icon, holder, timer, count)
    if frame.DebuffBorder then frame.DebuffBorder:SetAlpha(v.hideDebuffBorder and 0 or 1) end
    if key == "bars" and frame.Bar then
        M:StyleBar(key, frame.Bar, frame.Bar.Name, frame.Bar.Duration)
        if frame.Bar.BarBG then frame.Bar.BarBG:SetAlpha(0) end
    end
end

local function onAcquire(viewerFrame, frame)
    local key = keyOf[viewerFrame]
    if key and M:IsEnabled() then ns.SafeCall(styleItem, key, frame) end
end

local function styleViewer(viewerFrame)
    local key = keyOf[viewerFrame]
    if not (key and viewerFrame.itemFramePool) then return end
    for frame in viewerFrame.itemFramePool:EnumerateActive() do ns.SafeCall(styleItem, key, frame) end
end

local hooked = {}
local function hookViewers()
    for _, def in ipairs(M.VIEWERS) do
        local f = _G[def.frame]
        if f and not hooked[f] and f.OnAcquireItemFrame then
            hooked[f] = true
            keyOf[f] = def.key
            hooksecurefunc(f, "OnAcquireItemFrame", onAcquire)
        end
    end
end

---------------------------------------------------------------- fade out of combat
function M:ApplyFade()
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local alpha = (self:IsEnabled() and self.db.fade.enabled and not inCombat) and self.db.fade.alpha or 1
    if Secret.IsSecret(inCombat) then alpha = 1 end
    for f in pairs(keyOf) do f:SetAlpha(alpha) end
end

-- Blizzard's own spell picker for the viewers (the "Advanced Cooldown Settings" window).
function M:OpenCooldownManager()
    if InCombatLockdown() then return end
    if not CooldownViewerSettings and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_CooldownViewer") end
    if CooldownViewerSettings and CooldownViewerSettings.TogglePanel then CooldownViewerSettings:TogglePanel() end
end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    hookViewers()
    if not next(keyOf) then
        ns.Events:On("ADDON_LOADED", self, function(_, _, name)
            if name == "Blizzard_CooldownViewer" then
                hookViewers()
                self:Refresh()
            end
        end)
    end
    ns.Events:On("PLAYER_REGEN_DISABLED", self, self.ApplyFade)
    ns.Events:On("PLAYER_REGEN_ENABLED", self, self.ApplyFade)
    ns.Events:On("PLAYER_ENTERING_WORLD", self, self.ApplyFade)
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
    self:Refresh()
end

function M:OnDisable()
    for f in pairs(keyOf) do f:SetAlpha(1) end
end

function M:Refresh()
    for f in pairs(keyOf) do styleViewer(f) end
    self:ApplyFade()
end
