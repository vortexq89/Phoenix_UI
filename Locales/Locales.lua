local _, ns = ...

-- Locale table. Missing keys fall back to enUS, then to the key itself (never errors, never nil).
local base = {}
ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = base[key]
        if v == nil then return key end
        return v
    end,
})

-- Register strings. enUS fills the base table; other locales override only when they match the client.
function ns.RegisterLocale(locale, strings)
    if locale == "enUS" then
        for k, v in pairs(strings) do base[k] = v end
    elseif locale == GetLocale() then
        for k, v in pairs(strings) do rawset(ns.L, k, v) end
    end
end
