local _, ns = ...

--[[ ns.Combat — combat-lockdown queue. Anything touching protected frames, CVars that the client
    rejects in combat, secure state drivers or Edit Mode goes through Run(). ]]
local C = {}
ns.Combat = C

local queue, order = {}, {}

function C:InLockdown()
    return InCombatLockdown()
end

-- Run fn now if allowed, otherwise once after combat. Same key = latest fn wins (de-duplicated).
function C:Run(key, fn, ...)
    if not InCombatLockdown() then
        return ns.SafeCall(fn, ...)
    end
    if not queue[key] then order[#order + 1] = key end
    queue[key] = { fn = fn, n = select("#", ...), ... }
    return false
end

-- Returns true when protected work may run now. Callers should queue with Run() when false.
function C:Guard()
    return not InCombatLockdown()
end

ns.Events:On("PLAYER_REGEN_ENABLED", C, function()
    local keys = order
    order = {}
    for i = 1, #keys do
        local job = queue[keys[i]]
        queue[keys[i]] = nil
        if job then ns.SafeCall(job.fn, unpack(job, 1, job.n)) end
    end
    ns.Events:Fire("PUI_COMBAT_END")
end)

-- get/set pair for a CVar exposed as an option (writes are deferred out of combat).
-- kind: "bool" (default) or "number".
function C.CVarAccessors(name, kind)
    local numeric = kind == "number"
    local function get()
        if numeric then return tonumber(C_CVar.GetCVar(name)) end
        return C_CVar.GetCVarBool(name)
    end
    local function set(_, value)
        local raw = numeric and tostring(value) or (value and "1" or "0")
        C:Run("cvar." .. name, C_CVar.SetCVar, name, raw)
    end
    return get, set
end
