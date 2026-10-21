local _, ns = ...

--[[ ns.Events — the only game-event dispatcher in Phoenix_UI.
    On(event, owner, fn)              fn(owner, event, ...)
    OnUnit(event, owner, fn, u1, u2)  unit-filtered (RegisterUnitEvent), one frame per owner and unit pair
    Off(event, owner) / OffAll(owner)
    Listen(msg, owner, fn) / Fire(msg, ...)   internal PUI_* messages: fn(owner, msg, ...) ]]
local E = {}
ns.Events = E

local frame = CreateFrame("Frame")
local handlers = {}      -- event -> { [owner] = fn }
local unitFrames = {}    -- owner -> { [unitKey] = frame }, frame.handlers[event] = fn
local listeners = {}     -- message -> { [owner] = fn }
local safecall = ns.SafeCall

-- Midnight: registering the combat log errors for addons (Patch 12.0.0 API changes).
local function assertAllowed(event)
    assert(not event:find("^COMBAT_LOG_EVENT"), "Phoenix_UI: combat-log events are forbidden in 12.x")
end

local function dispatch(map, name, ...)
    local list = map[name]
    if not list then return end
    for owner, fn in pairs(list) do
        safecall(fn, owner, name, ...)
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    dispatch(handlers, event, ...)
end)

local function onUnitEvent(self, event, ...)
    local fn = self.handlers[event]
    if fn then safecall(fn, self.owner, event, ...) end
end

function E:On(event, owner, fn)
    assertAllowed(event)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        frame:RegisterEvent(event)
    end
    list[owner] = fn
end

function E:OnUnit(event, owner, fn, unit1, unit2)
    assertAllowed(event)
    local frames = unitFrames[owner]
    if not frames then
        frames = {}
        unitFrames[owner] = frames
    end
    local key = unit2 and (unit1 .. "|" .. unit2) or unit1
    local f = frames[key]
    if not f then
        f = CreateFrame("Frame")
        f.owner, f.handlers = owner, {}
        f:SetScript("OnEvent", onUnitEvent)
        frames[key] = f
    end
    f.handlers[event] = fn
    if unit2 then f:RegisterUnitEvent(event, unit1, unit2) else f:RegisterUnitEvent(event, unit1) end
end

function E:Off(event, owner)
    local list = handlers[event]
    if list and list[owner] then
        list[owner] = nil
        if next(list) == nil then
            handlers[event] = nil
            frame:UnregisterEvent(event)
        end
    end
    for _, f in pairs(unitFrames[owner] or {}) do
        if f.handlers[event] then
            f.handlers[event] = nil
            f:UnregisterEvent(event)
        end
    end
end

function E:OffAll(owner)
    for event, list in pairs(handlers) do
        if list[owner] then self:Off(event, owner) end
    end
    for _, f in pairs(unitFrames[owner] or {}) do
        f:UnregisterAllEvents()
        wipe(f.handlers)
    end
    for _, list in pairs(listeners) do list[owner] = nil end
end

function E:Listen(message, owner, fn)
    listeners[message] = listeners[message] or {}
    listeners[message][owner] = fn
end

function E:Fire(message, ...)
    dispatch(listeners, message, ...)
end
