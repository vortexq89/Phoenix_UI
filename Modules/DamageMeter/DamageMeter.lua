local _, ns = ...
local Theme, Skin, Media, Style = ns.Theme, ns.Skin, ns.Media, ns.Style

--[[ DamageMeter: Phoenix skin for Blizzard's built-in damage meter (Blizzard_DamageMeter, 12.x),
    plus an optional one-click style for Details! when that addon is loaded (no dependency).
    Meter values are secret in combat: entries are restyled only, never read.
    What the skin owns (S16): bar texture, fill direction, shade, the window's backdrop and border, and the
    name / value fonts. What Edit Mode owns and only links to: bar height and spacing, class colours, the
    number format, spec icons, visibility (always / in combat / in group) and extra windows. Calling the
    meter's own setters from addon code would taint the frames that later handle secret values, so those
    stay Blizzard's (DamageMeter.lua, EditModeSettingDisplayInfo.lua). ]]
local M = ns:NewModule("DamageMeter", {
    label = "DAMAGEMETER", desc = "DAMAGEMETER_DESC", category = "combat", order = 30,
    defaults = {
        skin = true,
        -- "phoenix": Phoenix's own meter windows (Meter.lua, docs/DAMAGE_METER.md); "blizzard": Blizzard's window, skinned
        engine = "phoenix",
        meter = {
            windows = 1, width = 280, rows = 8, rowHeight = 18, spacing = 2,
            classColor = true, specIcon = true, rank = true, valueFormat = "both", clock = true,
            visibility = "always", idleAlpha = 1, rate = 0.3,
            win1 = { type = 0, segment = 0, overall = false, point = "BOTTOMRIGHT", x = -16, y = 220 },
            win2 = { type = 2, segment = 0, overall = false, point = "BOTTOMRIGHT", x = -306, y = 220 },
            win3 = { type = 7, segment = 0, overall = false, point = "BOTTOMRIGHT", x = -16, y = 420 },
        },
        bar = { texture = "", reverse = false, shade = 0.2 },
        bg = Style.Background({ show = true, alpha = 0.92, color = false, style = "solid" }),
        border = Style.Border({ style = "solid", color = false }),
        name = Style.Text(12),
        value = Style.Text(12),
        -- threat meter (Threat.lua, WoW Forever)
        threat = { enabled = true, combatOnly = true, rows = 5, width = 200, point = "RIGHT", x = -260, y = -120 },
    },
})

local windows = setmetatable({}, { __mode = "k" })
local entries = setmetatable({}, { __mode = "k" })
local shades = setmetatable({}, { __mode = "k" })

function M:BarTexture()
    local key = self.db.bar.texture
    return key ~= "" and Media:Bar(key) or Theme:Bar()
end

-- Shared by the real entries and the options preview, so both draw the same bar.
function M:StyleBar(bar, name, value)
    local db = self.db
    Skin:StatusBar(bar, { texture = self:BarTexture() })
    bar:SetReverseFill(db.bar.reverse and true or false)
    local shade = shades[bar]
    if not shade then
        shade = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        shade:SetTexture(Media.textures.WHITE)
        shade:SetAllPoints(bar:GetStatusBarTexture())
        shades[bar] = shade
    end
    local s = db.bar.shade or 0
    shade:SetShown(s > 0)
    if s > 0 then shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, s), CreateColor(1, 1, 1, s * 0.35)) end
    -- 12 pt base: Blizzard applies the meter's text scale on top with FontString:SetTextScale
    if name then Skin:TextSpec(name, db.name, "unit", "text.primary") end
    if value then Skin:TextSpec(value, db.value, "number", "text.primary") end
end

function M:StyleWindow(window)
    local db = self.db
    if db.bg.show then
        Skin:Backdrop(window, db.bg, "bg.base")
    else
        Skin:Backdrop(window, { alpha = 0 })
    end
    Skin:BorderSpec(window, db.border, "border.subtle")
end

-- Entries are recycled by the scroll box, and InitEntry runs on every data refresh, so each entry is
-- styled once and kept themed through Skin:Register (re-run on theme and setting changes).
local function paintBar(bar) M:StyleBar(bar, bar.Name, bar.Value) end

local styleEntry
function styleEntry(entry)
    if entries[entry] or not (M:IsEnabled() and M.db.skin) or not entry.StatusBar then return end
    entries[entry] = true
    local bar = entry.StatusBar
    for _, region in ipairs(bar.BackgroundRegions or {}) do Skin:HideRegion(region) end
    if entry.Icon and entry.Icon.Icon then Skin:Icon(entry.Icon.Icon) end
    Skin:Register(bar, paintBar)
end

local function paintWindow(window)
    local header = windows[window]
    M:StyleWindow(window)
    Skin:Panel(header, "raised", { border = false, sheen = 14 })
    Skin:Gradient(header.line, "HORIZONTAL", "accent.primary", "accent.primary", 1, 0)
    if window.SessionTimer then Skin:TextSpec(window.SessionTimer, M.db.value, "number", "text.secondary") end
end

local hooked = setmetatable({}, { __mode = "k" })
local function styleWindow(window)
    if not (M:IsEnabled() and M.db.skin) then return end
    local header = windows[window]
    if header and header:IsShown() then return end
    Skin:HideRegion(window.Header)
    local container = window.MinimizeContainer
    if container then Skin:HideRegion(container.Background) end
    if not header then
        header = CreateFrame("Frame", nil, window)
        header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT")
        header:SetHeight(28)
        header:SetFrameLevel(window:GetFrameLevel())
        header.line = header:CreateTexture(nil, "ARTWORK")
        header.line:SetTexture(Media.textures.WHITE)
        header.line:SetPoint("BOTTOMLEFT"); header.line:SetPoint("BOTTOMRIGHT")
        header.line:SetHeight(1)
        windows[window] = header
    end
    header:Show()
    Skin:Register(window, paintWindow)
    if not hooked[window] then
        hooked[window] = true
        hooksecurefunc(window, "InitEntry", function(_, entry) styleEntry(entry) end)
    end
    local player = container and container.LocalPlayerEntry
    if player then styleEntry(player) end
end

-- Live switch off: Blizzard's own art, fonts and bar back on every window and entry (on again redoes them).
local function unstyleEntry(entry)
    entries[entry] = nil
    local bar = entry.StatusBar
    if not bar then return end
    for _, region in ipairs(bar.BackgroundRegions or {}) do Skin:Restore(region) end
    if entry.Icon and entry.Icon.Icon then Skin:Restore(entry.Icon.Icon) end
    if shades[bar] then shades[bar]:Hide() end
    bar:SetReverseFill(false)
    if bar.Name then Skin:Restore(bar.Name) end
    if bar.Value then Skin:Restore(bar.Value) end
    Skin:Restore(bar)
end

function M:Unskin()
    for entry in pairs(entries) do ns.SafeCall(unstyleEntry, entry) end
    for window, header in pairs(windows) do
        header:Hide()
        Skin:Restore(window.Header)
        local container = window.MinimizeContainer
        if container then Skin:Restore(container.Background) end
        if window.SessionTimer then Skin:Restore(window.SessionTimer) end
        Skin:Restore(window)
    end
end

---------------------------------------------------------------- Details! (optional)
local DETAILS = "Details"
function M:DetailsLoaded()
    return C_AddOns.IsAddOnLoaded(DETAILS) and _G[DETAILS] ~= nil
end

-- One-shot: rewrites the user's Details! window settings through its public API (API UI.txt).
function M:ApplyDetails()
    if not self:DetailsLoaded() then return false end
    local D = _G[DETAILS]
    local r, g, b = Theme:Color("bg.base")
    local accent = { Theme:Color("accent.primary") }
    local count = 0
    for i = 1, 10 do
        local instance = D:GetInstance(i)
        if instance and instance.baseframe then
            local ok = pcall(function()
                instance:SetBarSettings(20, "Phoenix Satin", true, nil, "Phoenix Flat", false, { 0.06, 0.07, 0.09, 0.6 })
                instance:SetBarTextSettings(11, "Phoenix Condensed SemiBold", nil, false, false, true, true)
                instance:InstanceColor(r, g, b, 0.92, false, true)
                instance:AttributeMenu(true, nil, nil, "Phoenix Condensed Bold", 11, accent)
            end)
            if ok then count = count + 1 end
        end
    end
    return count > 0, count
end

function M:OnEnable()
    self:SetupThreat() -- Threat.lua (Forever)
    ns.SafeCall(self.SetupMeter, self) -- Meter.lua
    if not DamageMeter then return end
    if self.blizzardHooked then return self:Refresh() end
    self.blizzardHooked = true
    hooksecurefunc(DamageMeter, "SetupSessionWindow", function() DamageMeter:ForEachSessionWindow(styleWindow) end)
    DamageMeter:ForEachSessionWindow(styleWindow)
end

-- Settings changes restyle every skinned window and entry (Skin:Register keeps the painters).
function M:OnDisable()
    self:Unskin()
    if self.StopMeter then ns.SafeCall(self.StopMeter, self) end
    if self.ThreatWindow and self:ThreatWindow() then self:ThreatWindow():Hide() end
end

function M:Refresh()
    if self.UpdateThreat then ns.SafeCall(self.UpdateThreat, self) end
    if self.RefreshMeter then ns.SafeCall(self.ApplyEngine, self); ns.SafeCall(self.RefreshMeter, self) end
    if not self.db.skin then return self:Unskin() end
    if DamageMeter and DamageMeter.ForEachSessionWindow then DamageMeter:ForEachSessionWindow(styleWindow) end
    for window in pairs(windows) do ns.SafeCall(paintWindow, window) end
    for entry in pairs(entries) do if entry.StatusBar then ns.SafeCall(paintBar, entry.StatusBar) end end
end
