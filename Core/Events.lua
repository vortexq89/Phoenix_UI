local _, ns = ...

--[[ ns.Events — the only game-event dispatcher in Phoenix_UI.
    On(event, owner, fn)           fn(owner, event, ...)
    OnUnit(event, owner, fn, u1, u2) unit-filtered (RegisterUnitEvent)
    Off(event, owner) / OffAll(owner)
    Listen(msg, owner, fn) / Fire(msg, ...)   internal PUI_* messages: fn(owner, msg, ...)
]]
local E = {}
ns.Events = E

local frame = CreateFrame("Frame")
local handlers = {}      -- event -> { [owner] = fn }
local unitFrames = {}    -- owner -> { [event] = frame }
local listeners = {}     -- message -> { [owner] = fn }
local safecall = ns.SafeCall

local function isForbidden(event)
    -- Midnight: registering the combat log errors for addons (Patch 12.0.0 API changes).
    return event:find("^COMBAT_LOG_EVENT") ~= nil
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

function E:On(event, owner, fn)
    assert(not isForbidden(event), "Phoenix_UI: combat-log events are forbidden in 12.x")
    assert(type(fn) == "function", "handler must be a function")
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        frame:RegisterEvent(event)
    end
    list[owner] = fn
end

function E:Off(event, owner)
    local list = handlers[event]
    if list then
        list[owner] = nil
        if next(list) == nil then
            handlers[event] = nil
            frame:UnregisterEvent(event)
        end
    end
    local uf = unitFrames[owner] and unitFrames[owner][event]
    if uf then uf:UnregisterEvent(event) end
end

function E:OnUnit(event, owner, fn, unit1, unit2)
    assert(not isForbidden(event), "Phoenix_UI: combat-log events are forbidden in 12.x")
    unitFrames[owner] = unitFrames[owner] or {}
    local f = unitFrames[owner][event]
    if not f then
        f = CreateFrame("Frame")
        unitFrames[owner][event] = f
    end
    f:SetScript("OnEvent", function(_, ev, ...) safecall(fn, owner, ev, ...) end)
    if unit2 then f:RegisterUnitEvent(event, unit1, unit2) else f:RegisterUnitEvent(event, unit1) end
end

function E:OffAll(owner)
    for event, list in pairs(handlers) do
        if list[owner] then self:Off(event, owner) end
    end
    if unitFrames[owner] then
        for _, f in pairs(unitFrames[owner]) do f:UnregisterAllEvents() end
    end
    for _, list in pairs(listeners) do list[owner] = nil end
end

function E:Listen(message, owner, fn)
    listeners[message] = listeners[message] or {}
    listeners[message][owner] = fn
end

function E:Unlisten(message, owner)
    if listeners[message] then listeners[message][owner] = nil end
end

function E:Fire(message, ...)
    dispatch(listeners, message, ...)
end
