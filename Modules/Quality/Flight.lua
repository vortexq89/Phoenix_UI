local _, ns = ...
local L, Skin, Theme, W, U = ns.L, ns.Skin, ns.Theme, ns.Widgets, ns.Util
local M = ns.modules.Quality

--[[ Flight timer (EllesmereUI Forever Essentials reference; both flavours). A Phoenix bar while you ride a
    flight path: the destination, a progress fill in the accent colour and the time left, plus a Land button
    (TaxiRequestEarlyLanding, from your click). The game gives no flight duration, so Phoenix learns it:
    every flight that lands on its own stores its time per route (account-wide, from node ID to node ID).
    A route not flown yet is estimated from its hops' world length (C_TaxiMap node positions through
    C_Map.GetWorldPosFromMapPos) and a speed learned from your own landed flights, shown with a "~".
    The flight map's node tooltips show the same time. No route data is shipped. A reload mid-flight
    resumes the bar from the flight saved at take-off (dropped when stale or once you have landed). ]]

local OWNER = {}
local DEFAULT_SPEED = 32     -- yards per second until a landed flight teaches the real one
local SPEED_SAMPLES = 20     -- learned speed: running mean over at most this many flights
local MIN_FLIGHT = 5         -- shorter "flights" (a cancelled take-off) are not learned
local STALE = 1800           -- a saved flight older than this is never resumed
local W_DEFAULT, H = 260, 22
local bar, ticker, flight

---------------------------------------------------------------- pure helpers (tests)
function M.FlightKey(from, to)
    if type(from) ~= "number" or type(to) ~= "number" then return nil end
    return from .. ">" .. to
end

-- Seconds for a route: the learned time (exact) or yards / learned speed (estimate); nil when neither.
function M.FlightEstimate(store, key, yards)
    local known = key and store.times[key]
    if type(known) == "number" and known > 0 then return known, true end
    if type(yards) ~= "number" or yards <= 0 then return nil, false end
    local speed = tonumber(store.speed) or DEFAULT_SPEED
    if speed <= 0 then speed = DEFAULT_SPEED end
    return yards / speed, false
end

-- Store a landed flight: its time for the route and one more speed sample (when the length is known).
function M.FlightLearn(store, key, seconds, yards)
    if not key or type(seconds) ~= "number" or seconds < MIN_FLIGHT then return false end
    store.times[key] = math.floor(seconds + 0.5)
    if type(yards) == "number" and yards > 0 then
        local n = math.min(tonumber(store.samples) or 0, SPEED_SAMPLES - 1)
        local speed = tonumber(store.speed) or DEFAULT_SPEED
        store.speed = (speed * n + yards / seconds) / (n + 1)
        store.samples = n + 1
    end
    return true
end

-- Remaining-time text: "1:23" for a learned route, "~1:23" for an estimate, elapsed "+0:42" when unknown.
function M.FlightTimeText(total, exact, elapsed)
    if not total then return "+" .. U.FormatClock(elapsed or 0) end
    local left = math.max(0, total - (elapsed or 0))
    return (exact and "" or "~") .. U.FormatClock(left)
end

local function store()
    local g = M.global
    g.flight = type(g.flight) == "table" and g.flight or {}
    g.flight.times = type(g.flight.times) == "table" and g.flight.times or {}
    return g.flight
end

---------------------------------------------------------------- the open flight map
local function worldXY(mapID, pos)
    if not (pos and C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
    local _, world = C_Map.GetWorldPosFromMapPos(mapID, pos)
    if not world then return nil end
    return world:GetXY()
end

-- The route to a node slot of the open taxi map: { from, to, name, yards } (yards nil when not measurable).
function M:FlightRoute(slot)
    local mapID = GetTaxiMapID and GetTaxiMapID()
    local nodes = mapID and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and C_TaxiMap.GetAllTaxiNodes(mapID) or {}
    local bySlot, here = {}, nil
    for _, n in ipairs(nodes) do
        bySlot[n.slotIndex] = n
        if n.state == Enum.FlightPathState.Current then here = n end
    end
    local dest = bySlot[slot]
    local r = { from = here and here.nodeID, to = dest and dest.nodeID, name = dest and dest.name or TaxiNodeName(slot) }
    local yards = 0
    for hop = 1, tonumber((GetNumRoutes(slot))) or 0 do
        local a, b = bySlot[TaxiGetNodeSlot(slot, hop, true)], bySlot[TaxiGetNodeSlot(slot, hop, false)]
        local ax, ay = worldXY(mapID, a and a.position)
        local bx, by = worldXY(mapID, b and b.position)
        if not (ax and bx) then yards = nil break end
        yards = yards + math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    end
    r.yards = yards and yards > 0 and yards or nil
    r.key = M.FlightKey(r.from, r.to)
    return r
end

-- Tooltip line for a reachable node: "Flight time 1:23" (learned) or "~1:23" (estimated).
local function tipTime(slot)
    if not (M:IsEnabled() and M.db.flight.enabled and M.db.flight.mapTimes) then return end
    local route = M:FlightRoute(slot)
    local total, exact = M.FlightEstimate(store(), route.key, route.yards)
    if not total then return end
    local r, g, b = Theme:Color("accent.primary")
    GameTooltip:AddLine(L.QUALITY_FLIGHT_TIP:format(M.FlightTimeText(total, exact, 0)), r, g, b)
    GameTooltip:Show()
end

---------------------------------------------------------------- the bar
local function build()
    bar = CreateFrame("Frame", "PhoenixUI_FlightTimer", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar.fill = CreateFrame("StatusBar", nil, bar)
    bar.fill:SetPoint("TOPLEFT", 2, -2)
    bar.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    bar.fill:SetMinMaxValues(0, 1)
    bar.icon = W.Icon(bar.fill, "maps", 14, "text.primary", "OVERLAY")
    bar.icon:SetPoint("LEFT", 5, 0)
    bar.time = W.Text(bar.fill, "small", "text.primary", "RIGHT")
    bar.time:SetPoint("RIGHT", -6, 0)
    bar.name = W.Text(bar.fill, "small", "text.primary", "LEFT")
    bar.name:SetPoint("LEFT", bar.icon, "RIGHT", 5, 0)
    bar.name:SetPoint("RIGHT", bar.time, "LEFT", -6, 0)
    bar.name:SetWordWrap(false)
    bar.land = W:Button(bar, L.QUALITY_FLIGHT_LAND, "secondary", nil, 54)
    bar.land:SetHeight(H)
    bar.land:SetPoint("LEFT", bar, "RIGHT", 4, 0)
    bar.land.onClick = function(self)
        if UnitOnTaxi("player") then
            if flight then flight.early = true end
            TaxiRequestEarlyLanding()
            self:Disable()
        end
    end
    Skin:Register(bar, function(self)
        Skin:Panel(self, "base", { border = "border.subtle" })
        self.fill:SetStatusBarTexture(Theme:Bar())
        self.fill:SetStatusBarColor(Theme:Color("accent.primary"))
    end)
    local movers = ns:GetModule("Movers")
    if movers then
        movers:Register("quality.flight", bar, L.QUALITY_FLIGHT, {
            active = function() return M:IsEnabled() and M.db.flight.enabled end,
            get = function() local f = M.db.flight; return { point = f.point, x = f.x, y = f.y } end,
            set = function(v) local f = M.db.flight; f.point, f.x, f.y = v.point or f.point, v.x or f.x, v.y or f.y end,
            apply = function() M:ApplyFlight() end,
            preview = function() M:ApplyFlight() end,
            reset = function()
                local d, f = M.defaults.flight, M.db.flight
                f.point, f.x, f.y = d.point, d.x, d.y
                M:ApplyFlight()
            end,
        })
    end
end

local function paint()
    if not bar then return end
    local f = flight
    local elapsed = f and (GetTime() - f.start) or 0
    local total, exact
    if f then total, exact = M.FlightEstimate(store(), f.key, f.yards) end
    bar.name:SetText(f and f.name or store().last or L.QUALITY_FLIGHT_SAMPLE)
    bar.time:SetText(f and M.FlightTimeText(total, exact, elapsed) or M.FlightTimeText(83, true, 0))
    bar.fill:SetValue(f and total and math.min(1, elapsed / total) or (f and 0 or 0.4))
end

local function stopTicker() if ticker then ticker:Cancel(); ticker = nil end end
local landed
-- Every half second: the time and fill, or the landing when the taxi ended without a control event.
local function tick()
    if flight and not UnitOnTaxi("player") then landed() else paint() end
end

function M:ApplyFlight()
    local d = self.db.flight
    local movers = ns:GetModule("Movers")
    local preview = movers and movers:IsUnlocked()
    local want = self:IsEnabled() and d.enabled and (flight or preview)
    if not want then stopTicker(); if bar then bar:Hide() end return end
    if not bar then build() end
    bar:SetSize(math.max(120, tonumber(d.width) or W_DEFAULT), H)
    bar:ClearAllPoints()
    bar:SetPoint(d.point, UIParent, d.point, d.x, d.y)
    bar.land:SetShown(flight and d.land and true or false)
    bar.land:Enable()
    paint()
    bar:Show()
    if flight and not ticker then ticker = C_Timer.NewTicker(0.5, function() ns.SafeCall(tick) end) end
    if not flight then stopTicker() end
end

---------------------------------------------------------------- take-off and landing
local pending -- the route picked on the flight map, waiting for the taxi to start

local function begin(route, start)
    flight = { key = route.key, yards = route.yards, name = route.name, start = start or GetTime() }
    local g = store()
    g.last = route.name
    g.current = { key = route.key, yards = route.yards, name = route.name, at = GetServerTime(), start = flight.start }
    M:ApplyFlight()
end

function landed()
    if not flight then return end
    local seconds = GetTime() - flight.start
    if not flight.early and not flight.resumed then M.FlightLearn(store(), flight.key, seconds, flight.yards) end
    flight = nil
    store().current = nil
    M:ApplyFlight()
end

local function onControl()
    if not (M:IsEnabled() and M.db.flight.enabled) then return end
    -- the taxi starts a moment after control is lost; ask once more shortly after
    C_Timer.After(0.3, function()
        if UnitOnTaxi("player") then
            if pending and not flight then begin(pending) end
            pending = nil
        elseif flight then
            landed()
        end
    end)
end

-- TakeTaxiNode post-hook: remember the picked route until the taxi is under way.
function M.FlightPicked(slot)
    if not (M:IsEnabled() and M.db.flight.enabled) then return end
    local ok, route = pcall(M.FlightRoute, M, slot)
    pending = ok and route or nil
    -- fallback when no control event comes: the taxi is under way a moment after the pick
    C_Timer.After(1.5, function()
        if pending and not flight and UnitOnTaxi("player") then begin(pending); pending = nil end
    end)
end
M.FlightControl = onControl
function M:FlightActive() return flight end
M.FlightBar = function() return bar end

-- After a reload mid-flight: the saved flight comes back if it is fresh and you are still on the taxi.
function M.FlightResume()
    local g = store()
    local c = g.current
    if not (c and UnitOnTaxi("player")) then g.current = nil return end
    local age = GetServerTime() - (tonumber(c.at) or 0)
    if age < 0 or age > STALE then g.current = nil return end
    flight = { key = c.key, yards = c.yards, name = c.name, start = GetTime() - age, resumed = true }
    M:ApplyFlight()
end

function M:SetupFlight()
    if self.flightHooked then return end
    self.flightHooked = true
    if not bar then build(); bar:Hide() end -- registered with Layout mode from the start
    hooksecurefunc("TakeTaxiNode", M.FlightPicked)
    hooksecurefunc("TaxiRequestEarlyLanding", function() if flight then flight.early = true end end)
    if type(TaxiNodeOnButtonEnter) == "function" then
        hooksecurefunc("TaxiNodeOnButtonEnter", function(button)
            if button and button.GetID and TaxiNodeGetType(button:GetID()) == "REACHABLE" then ns.SafeCall(tipTime, button:GetID()) end
        end)
    end
    local function hookMap()
        if M.flightMapHooked or type(FlightMap_FlightPointPinMixin) ~= "table" then return end
        M.flightMapHooked = true
        hooksecurefunc(FlightMap_FlightPointPinMixin, "OnMouseEnter", function(pin)
            local data = pin.taxiNodeData
            if data and data.state == Enum.FlightPathState.Reachable then ns.SafeCall(tipTime, data.slotIndex) end
        end)
    end
    hookMap()
    ns.Events:On("ADDON_LOADED", OWNER, function(_, _, name) if name == "Blizzard_FlightMap" then hookMap() end end)
    ns.Events:On("PLAYER_CONTROL_LOST", OWNER, onControl)
    ns.Events:On("PLAYER_CONTROL_GAINED", OWNER, onControl)
    ns.Events:On("PLAYER_ENTERING_WORLD", OWNER, function() ns.SafeCall(M.FlightResume) end)
end

-- Forget every learned route time and the learned speed (Quality page button).
function M:ForgetFlights()
    local g = store()
    g.times, g.speed, g.samples = {}, nil, nil
end

function M:FlightLastName() return store().last end
function M:FlightCount()
    local n = 0
    for _ in pairs(store().times) do n = n + 1 end
    return n
end
