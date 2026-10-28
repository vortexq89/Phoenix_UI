local _, ns = ...

--[[ ns.Combat — combat-lockdown queue. Anything touching protected frames, CVars that the client
    rejects in combat, secure state drivers or Edit Mode goes through Run(). ]]
local C = {}
ns.Combat = C

local queue, order = {}, {}

-- Run fn now if allowed, otherwise once after combat. Same key = latest fn wins (de-duplicated).
function C:Run(key, fn, ...)
    if not InCombatLockdown() then
        return ns.SafeCall(fn, ...)
    end
    if not queue[key] then order[#order + 1] = key end
    queue[key] = { fn = fn, n = select("#", ...), ... }
    return false
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

-- Keys still waiting for combat to end (developer diagnostics: leftovers out of combat are a bug).
function C:Pending()
    local out = {}
    for _, k in ipairs(order) do if queue[k] then out[#out + 1] = tostring(k) end end
    return out
end

-- get/set pair for a CVar exposed as an option (writes are deferred out of combat).
-- kind: "bool" (default), "number" or "string" (the raw value, for CVars that hold a choice).
function C.CVarAccessors(name, kind)
    local numeric, text = kind == "number", kind == "string"
    local function get()
        if numeric then return tonumber((C_CVar.GetCVar(name))) end
        if text then return C_CVar.GetCVar(name) end
        return C_CVar.GetCVarBool(name)
    end
    local function set(_, value)
        local raw = (numeric or text) and tostring(value) or (value and "1" or "0")
        C:Run("cvar." .. name, C_CVar.SetCVar, name, raw)
    end
    return get, set
end
