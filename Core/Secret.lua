local _, ns = ...

--[[ ns.Secret — Midnight secret-value helpers (Patch 12.0.0+, "Secret values" on warcraft.wiki.gg).
    Never do arithmetic/comparison/boolean tests on values these report as secret. ]]
local S = {}
ns.Secret = S

local issecretvalue, canaccessvalue = issecretvalue, canaccessvalue

function S.IsSecret(value)
    return issecretvalue(value)
end

function S.CanAccess(value)
    return canaccessvalue(value)
end

-- Returns value when it is a plain value, otherwise fallback. Use before any logic on API returns.
function S.Plain(value, fallback)
    if issecretvalue(value) then return fallback end
    return value
end

local restrictionTypes = Enum.AddOnRestrictionType
local active = {}

function S:IsRestricted(kind)
    if kind then return active[kind] == true end
    return next(active) ~= nil
end

local function refresh()
    for name, id in pairs(restrictionTypes) do
        active[name] = C_RestrictedActions.IsAddOnRestrictionActive(id) or nil
    end
end

local typeNames = {}
for name, id in pairs(restrictionTypes) do typeNames[id] = name end

ns.Events:On("ADDON_RESTRICTION_STATE_CHANGED", S, function(_, _, restrictionType, state)
    -- IsAddOnRestrictionActive always returns false during this event's dispatch (API doc),
    -- so track it from the payload: state is an Enum.AddOnRestrictionState.
    local name = typeNames[restrictionType]
    if name then
        active[name] = (state ~= Enum.AddOnRestrictionState.Inactive) or nil
        ns.Events:Fire("PUI_RESTRICTION_CHANGED", name, active[name] == true)
    end
end)
ns.Events:On("PLAYER_ENTERING_WORLD", S, refresh)
