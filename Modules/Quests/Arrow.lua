local _, ns = ...
local M = ns.modules.Quests
local L, Secret, Skin = ns.L, ns.Secret, ns.Skin

--[[ Waypoint arrow: points from the player to the target — a pin you clicked, else your map pin (user
    waypoint), else the super-tracked quest's next waypoint. Distance in yards and an ETA from your recent
    closing speed. Clicking a pin also sets the game's own map pin (C_Map.SetUserWaypoint) so Blizzard's
    in-world marker agrees. Hidden in instances, where the game hides positions. Movable with Layout mode. ]]
M.ARROW_STYLES = {
    phoenix = { icon = "arrow-up" },
    blizzard = { atlas = "Navigation-Tracked-Arrow" },
    minimal = { icon = "chevron-right", rotate = -math.pi / 2 },
}

local arrow
local target -- { mapID, x, y, title }

function M:SetTarget(mapID, x, y, title)
    target = { mapID = mapID, x = x, y = y, title = title }
    if C_Map.CanSetUserWaypointOnMap(mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    self:RefreshArrow()
end

function M:ClearTarget()
    target = nil
    self:RefreshArrow()
end

-- The current destination: mapID, x, y, title (nil when there is none).
function M:Destination()
    if target then return target.mapID, target.x, target.y, target.title end
    if C_Map.HasUserWaypoint() then
        local p = C_Map.GetUserWaypoint()
        if p and p.position then
            local x, y = p.position:GetXY()
            return p.uiMapID, x, y, L.QUESTS_ARROW_PIN
        end
    end
    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    if type(questID) == "number" and questID > 0 then
        local mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
        if not mapID then
            mapID = C_Map.GetBestMapForUnit("player")
            for _, q in ipairs(mapID and C_QuestLog.GetQuestsOnMap(mapID) or {}) do
                if q.questID == questID then x, y = q.x, q.y end
            end
        end
        if mapID and x and y then return mapID, x, y, M:QuestName(questID) end
    end
end

-- Yards and bearing (radians, counter-clockwise from north) from the player to a map point.
function M.Bearing(px, py, tx, ty)
    local north, west = tx - px, ty - py
    return math.sqrt(north * north + west * west), math.atan2(west, north)
end

local function worldXY(mapID, x, y)
    local cont, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if not pos then return nil end
    local wx, wy = pos:GetXY()
    if Secret.IsSecret(wx) or Secret.IsSecret(wy) then return nil end
    return cont, wx, wy
end

function M.FormatETA(seconds)
    if not seconds or seconds <= 0 or seconds > 5999 then return nil end
    return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
end

local function update(self, elapsed)
    self.acc = (self.acc or 0) + elapsed
    if self.acc < 0.05 then return end
    local dt = self.acc
    self.acc = 0
    local mapID, x, y, title = M:Destination()
    local here = C_Map.GetBestMapForUnit("player")
    local pxm, pym = ns.Util.PlayerMapXY()
    local cont, tx, ty, pcont, px, py
    if mapID then cont, tx, ty = worldXY(mapID, x, y) end
    if here and pxm then pcont, px, py = worldXY(here, pxm, pym) end
    if not (cont and pcont and cont == pcont) then
        self.dir:Hide()
        self.text:SetText(title and L.QUESTS_ARROW_FAR or "")
        self.title:SetText(title or "")
        return
    end
    local dist, bearing = M.Bearing(px, py, tx, ty)
    if target and dist < 8 then M:ClearTarget() return end
    local facing = GetPlayerFacing()
    if type(facing) == "number" and not Secret.IsSecret(facing) then
        local style = M.ARROW_STYLES[M.db.arrowStyle] or M.ARROW_STYLES.phoenix
        self.dir:SetRotation(bearing - facing + (style.rotate or 0))
        self.dir:Show()
    else
        self.dir:Hide()
    end
    -- closing speed, smoothed, for the ETA
    if self.lastDist then
        local v = (self.lastDist - dist) / dt
        self.speed = (self.speed or 0) * 0.9 + v * 0.1
    end
    self.lastDist = dist
    local parts = {}
    if M.db.distance then parts[#parts + 1] = L.QUESTS_ARROW_YARDS:format(dist) end
    local eta = M.db.eta and self.speed and self.speed > 0.5 and M.FormatETA(dist / self.speed)
    if eta then parts[#parts + 1] = eta end
    self.text:SetText(table.concat(parts, "  "))
    self.title:SetText(title or "")
end

local function build()
    arrow = CreateFrame("Button", nil, UIParent)
    arrow:SetPoint("TOP", UIParent, "TOP", 0, -140)
    arrow:SetMovable(true)
    arrow:SetClampedToScreen(true)
    arrow:RegisterForClicks("RightButtonUp")
    arrow:SetScript("OnClick", function() M:ClearTarget(); C_Map.ClearUserWaypoint() end)
    arrow.title = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrow.title:SetPoint("TOP", arrow, "BOTTOM", 0, -2)
    arrow.text = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrow.text:SetPoint("TOP", arrow.title, "BOTTOM", 0, -2)
    arrow:SetScript("OnUpdate", update)
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("quests.arrow", arrow, L.QUESTS_ARROW) end
end

local function styleArrow()
    local db = M.db
    local style = M.ARROW_STYLES[db.arrowStyle] or M.ARROW_STYLES.phoenix
    arrow:SetSize(db.arrowSize, db.arrowSize)
    if arrow.dir then arrow.dir:Hide() end
    arrow.dirs = arrow.dirs or {}
    local dir = arrow.dirs[db.arrowStyle]
    if not dir then
        if style.atlas then
            dir = arrow:CreateTexture(nil, "ARTWORK")
            dir:SetAtlas(style.atlas)
        else
            dir = ns.Icons:Create(arrow, style.icon, db.arrowSize, "accent.primary", "ARTWORK")
        end
        dir:SetPoint("CENTER")
        arrow.dirs[db.arrowStyle] = dir
    end
    dir:SetSize(db.arrowSize, db.arrowSize)
    arrow.dir = dir
    Skin:Text(arrow.title, "heading", "accent.primary", 12, "OUTLINE")
    Skin:Text(arrow.text, "number", "text.primary", 12, "OUTLINE")
end

function M:EnableArrow()
    ns.Events:On("SUPER_TRACKING_CHANGED", self, function() self:RefreshArrow() end)
    ns.Events:On("USER_WAYPOINT_UPDATED", self, function() self:RefreshArrow() end)
    self:RefreshArrow()
end

function M:DisableArrow()
    if arrow then arrow:Hide() end
end

function M:RefreshArrow()
    if not (self:IsEnabled() and self.db.arrow) then
        if arrow then arrow:Hide() end
        return
    end
    if not arrow then build() end
    styleArrow()
    arrow.lastDist, arrow.speed = nil, nil
    local inInstance = IsInInstance()
    arrow:SetShown(self:Destination() ~= nil and not inInstance)
end
