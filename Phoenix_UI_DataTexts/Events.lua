local _, ns = ...
local M = ns.modules.DataTexts

--[[ Event tracker (EllesmereUI WindTools "Event Tracker" reference, original code; both clients). The "Events"
    segment counts the world events running on your continent right now plus today's holidays; its tooltip lists
    each event with its zone and time left, soonest first, and a click opens the world map on that event's zone.
    Nothing is scheduled from shipped data: events are the game's own event POIs (C_AreaPoiInfo.GetEventsForMap on
    each zone of the continent, deduplicated), time left is C_AreaPoiInfo.GetAreaPOISecondsLeft, holidays are the
    calendar's own HOLIDAY day events. The scan runs on AREA_POIS_UPDATED, zone changes and a 60 s ticker that only
    lives while the segment is on; the bar's 1 s redraw only reads the cached list. ]]

local RESCAN = 60
local EVENTS = { "AREA_POIS_UPDATED", "CALENDAR_UPDATE_EVENT_LIST", "ZONE_CHANGED_NEW_AREA" }
local cache = { events = {}, holidays = {}, at = 0 }
local ticker, asked
local owner = {} -- our own event owner: the bar already listens to zone changes as the module

-- Walks up from a map to its continent (nil when the map sits above or outside one).
function M.ContinentOf(mapID)
    local guard = 0
    while mapID and guard < 10 do
        local info = C_Map.GetMapInfo(mapID)
        if not info then return nil end
        if info.mapType == Enum.UIMapType.Continent then return mapID end
        if info.mapType == Enum.UIMapType.World or info.mapType == Enum.UIMapType.Cosmic then return nil end
        mapID, guard = info.parentMapID, guard + 1
    end
    return nil
end

-- Event POIs on the continent and each of its zones: { id, name, zone, mapID, left (seconds or nil) }, soonest first.
function M:ScanEvents(continent)
    local out, seen = {}, {}
    if not continent then return out end
    local maps = { { mapID = continent } }
    for _, child in ipairs(C_Map.GetMapChildrenInfo(continent, Enum.UIMapType.Zone) or {}) do maps[#maps + 1] = child end
    for _, m in ipairs(maps) do
        for _, id in ipairs(C_AreaPoiInfo.GetEventsForMap(m.mapID) or {}) do
            local poi = not seen[id] and C_AreaPoiInfo.GetAreaPOIInfo(m.mapID, id)
            if type(poi) == "table" and type(poi.name) == "string" and poi.name ~= "" then
                seen[id] = true
                local left = tonumber((C_AreaPoiInfo.GetAreaPOISecondsLeft(id)))
                local zone = C_Map.GetMapInfo(m.mapID)
                out[#out + 1] = { id = id, name = poi.name, mapID = m.mapID, zone = zone and zone.name or "",
                    left = left and left > 0 and left or nil }
            end
        end
    end
    table.sort(out, function(a, b)
        if (a.left ~= nil) ~= (b.left ~= nil) then return a.left ~= nil end
        if a.left and b.left and a.left ~= b.left then return a.left < b.left end
        return a.name < b.name
    end)
    return out
end

-- Month offset of today from the month the calendar is showing (the calendar's day calls are relative to it).
function M.TodayOffset(shown, now)
    if type(shown) ~= "table" or type(now) ~= "table" then return nil end
    local sy, sm, ny, nm = tonumber(shown.year), tonumber(shown.month), tonumber(now.year), tonumber(now.month)
    if not (sy and sm and ny and nm) then return nil end
    return (ny - sy) * 12 + (nm - sm)
end

-- Today's holiday titles from the calendar (empty until the calendar has its data).
function M:Holidays()
    local out = {}
    local now = C_DateAndTime.GetCurrentCalendarTime()
    local offset = M.TodayOffset(C_Calendar.GetMonthInfo(0), now)
    local day = now and tonumber(now.monthDay)
    if not (offset and day) then return out end
    for i = 1, tonumber((C_Calendar.GetNumDayEvents(offset, day))) or 0 do
        local e = C_Calendar.GetDayEvent(offset, day, i)
        if type(e) == "table" and e.calendarType == "HOLIDAY" and type(e.title) == "string" and e.title ~= "" then
            out[#out + 1] = e.title
        end
    end
    return out
end

function M:RescanEvents()
    cache.events = self:ScanEvents(M.ContinentOf(C_Map.GetBestMapForUnit("player")))
    cache.holidays = self.db.eventsHolidays and self:Holidays() or {}
    cache.at = GetTime()
end

-- The cached lists with time left counted down since the scan.
function M:EventList()
    local gone = GetTime() - cache.at
    local list = {}
    for _, e in ipairs(cache.events) do
        local left = e.left and e.left - gone
        if not left or left > 0 then
            list[#list + 1] = { id = e.id, name = e.name, zone = e.zone, mapID = e.mapID, left = left }
        end
    end
    return list, cache.holidays
end

-- "1h 05m" / "12m" / "45s".
function M.EventTimeText(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    if sec >= 3600 then return ("%dh %02dm"):format(math.floor(sec / 3600), math.floor(sec / 60) % 60) end
    if sec >= 60 then return ("%dm"):format(math.floor(sec / 60)) end
    return ("%ds"):format(sec)
end

local function rescan()
    if not M:IsEnabled() or not M.db.events then return end
    M:RescanEvents()
    M:Update()
end

-- Starts or stops the scan (events, ticker) with the segment.
function M:SyncEvents()
    local want = self:IsEnabled() and self.db.events
    if want and not ticker then
        ticker = C_Timer.NewTicker(RESCAN, rescan)
        for _, event in ipairs(EVENTS) do ns.Events:On(event, owner, rescan) end
        -- the calendar only has holiday data once it was asked for it (the game's calendar does the same on open)
        if self.db.eventsHolidays and not asked and not InCombatLockdown() then asked = true; C_Calendar.OpenCalendar() end
        self:RescanEvents()
    elseif not want and ticker then
        ticker:Cancel(); ticker = nil
        for _, event in ipairs(EVENTS) do ns.Events:Off(event, owner) end
        cache.events, cache.holidays = {}, {}
    end
    return ticker ~= nil
end

-- The world map on the soonest event's zone (or the continent's map when nothing runs).
function M:OpenEventMap()
    local first = (self:EventList())[1]
    local mapID = first and first.mapID or M.ContinentOf(C_Map.GetBestMapForUnit("player"))
    if mapID then OpenWorldMap(mapID) else ToggleWorldMap() end
end
