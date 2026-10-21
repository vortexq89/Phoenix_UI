local _, ns = ...
local Theme, Skin, Media = ns.Theme, ns.Skin, ns.Media

--[[ DamageMeter: Phoenix skin for Blizzard's built-in damage meter (Blizzard_DamageMeter, 12.x),
    plus an optional one-click style for Details! when that addon is loaded (no dependency).
    Meter values are secret in combat: entries are restyled only, never read. ]]
local M = ns:NewModule("DamageMeter", {
    label = "DAMAGEMETER", desc = "DAMAGEMETER_DESC", category = "combat", order = 30, reloadOnToggle = true,
    defaults = { skin = true },
})

local windows = setmetatable({}, { __mode = "k" })
local entries = setmetatable({}, { __mode = "k" })

-- Entries are recycled by the scroll box, and InitEntry runs on every data refresh, so each entry is
-- styled once and kept themed through Skin:Register. Text keeps a 12 pt base: Blizzard applies the
-- meter's text scale on top with FontString:SetTextScale.
local function styleEntry(entry)
    if entries[entry] or not (M:IsEnabled() and M.db.skin) or not entry.StatusBar then return end
    entries[entry] = true
    local bar = entry.StatusBar
    for _, region in ipairs(bar.BackgroundRegions or {}) do Skin:HideRegion(region) end
    if entry.Icon and entry.Icon.Icon then Skin:Icon(entry.Icon.Icon) end
    Skin:Register(bar, function(self)
        Skin:StatusBar(self)
        if self.Name then Skin:Text(self.Name, "unit", "text.primary", 12) end
        if self.Value then Skin:Text(self.Value, "number", "text.primary", 12) end
    end)
end

local function styleWindow(window)
    if windows[window] or not (M:IsEnabled() and M.db.skin) then return end
    windows[window] = true
    Skin:HideRegion(window.Header)
    local container = window.MinimizeContainer
    if container then Skin:HideRegion(container.Background) end
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT")
    header:SetHeight(28)
    header:SetFrameLevel(window:GetFrameLevel())
    header.line = header:CreateTexture(nil, "ARTWORK")
    header.line:SetTexture(Media.textures.WHITE)
    header.line:SetPoint("BOTTOMLEFT"); header.line:SetPoint("BOTTOMRIGHT")
    header.line:SetHeight(1)
    Skin:Register(window, function(self)
        Skin:Panel(self, "base", { border = "border.subtle", shadow = 10 })
        Skin:Panel(header, "raised", { border = false, sheen = 14 })
        Skin:Gradient(header.line, "HORIZONTAL", "accent.primary", "accent.primary", 1, 0)
        if self.SessionTimer then Skin:Text(self.SessionTimer, "number", "text.secondary", 12) end
    end)
    hooksecurefunc(window, "InitEntry", function(_, entry) styleEntry(entry) end)
    local player = container and container.LocalPlayerEntry
    if player then styleEntry(player) end
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
    if not DamageMeter then return end
    hooksecurefunc(DamageMeter, "SetupSessionWindow", function() DamageMeter:ForEachSessionWindow(styleWindow) end)
    DamageMeter:ForEachSessionWindow(styleWindow)
end

