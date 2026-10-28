local _, ns = ...
local L = ns.L
local W, Secret = ns.Widgets, ns.Secret
local M = ns:GetModule("Automation")

--[[ Rare alert: when a rare (a kill vignette) appears on the minimap, a small toast names it with a sound.
    "Target" is a secure macro button (/target <name>), set up only out of combat; "Waypoint" puts the game's own
    map pin on it and tracks it. Each vignette alerts once. Off with Automation > Rare alert. ]]
local seen = {}

-- Is this vignette a rare to alert on? Kill vignettes only (not treasures, events or ones already looted).
function M.IsRareVignette(info)
    if type(info) ~= "table" or Secret.IsSecret(info.name) or Secret.IsSecret(info.atlasName) then return false end
    if info.isDead or info.onWorldMap == false and info.onMinimap == false then return false end
    local atlas = type(info.atlasName) == "string" and info.atlasName:lower() or ""
    return atlas:find("vignettekill", 1, true) ~= nil and type(info.name) == "string" and info.name ~= ""
end

local toast
local function build()
    local t = W:Popup(L.AUTO_RARE, 300, 104, "boss")
    t:ClearAllPoints()
    t:SetPoint("TOP", 0, -140)
    t.name = W.Text(t, "body", "text.primary")
    t.name:SetPoint("TOPLEFT", 16, -42); t.name:SetPoint("RIGHT", -16, 0)
    t.target = CreateFrame("Button", "PhoenixUI_RareTarget", t, "SecureActionButtonTemplate")
    t.target:SetSize(120, 26)
    t.target:SetPoint("BOTTOMLEFT", 16, 12)
    t.target:RegisterForClicks("AnyUp", "AnyDown")
    t.target:SetAttribute("type", "macro")
    t.targetLabel = W:Button(t.target, L.AUTO_RARE_TARGET, "primary", "user", 120)
    t.targetLabel:SetAllPoints()
    t.targetLabel:EnableMouse(false)
    -- the toast holds a secure button: never hide it in combat (that would be blocked); close after combat instead
    t.close.onClick = function() ns.Combat:Run("rare.close", function() t:Hide() end) end
    t.way = W:Button(t, L.AUTO_RARE_WAYPOINT, "secondary", "maps", 130)
    t.way:SetPoint("BOTTOMRIGHT", -16, 12)
    return t
end

function M:ShowRare(guid, info)
    toast = toast or build()
    toast.name:SetText(info.name)
    if not InCombatLockdown() then
        toast.target:SetAttribute("macrotext", "/cleartarget\n/targetexact " .. info.name)
        toast.target:Show()
    end
    toast.way.onClick = function()
        local map = C_Map.GetBestMapForUnit("player")
        local pos = map and C_VignetteInfo.GetVignettePosition(guid, map)
        if pos and C_Map.CanSetUserWaypointOnMap(map) then
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromVector2D(map, pos))
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end
    if not InCombatLockdown() then toast:Show() end
    PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    ns:Print(L.AUTO_RARE_SEEN:format(info.name))
    return toast
end

local function onVignette(_, _, guid, onMinimap)
    if not (M:IsEnabled() and M.db.rareAlert) or not guid or Secret.IsSecret(guid) or seen[guid] then return end
    if onMinimap == false or IsInInstance() then return end
    local info = C_VignetteInfo.GetVignetteInfo(guid)
    if not M.IsRareVignette(info) then return end
    seen[guid] = true
    M:ShowRare(guid, info)
end

function M:SetupRareAlert()
    if self.rareHooked then return end
    self.rareHooked = true
    ns.Events:On("VIGNETTE_MINIMAP_UPDATED", self, onVignette)
end
