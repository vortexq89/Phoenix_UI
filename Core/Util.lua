local _, ns = ...

local U = {}
ns.Util = U

function U.DeepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = U.DeepCopy(v) end
    return out
end

-- Fill missing keys of dst from defaults (recursively). Never overwrites valid user values; a value
-- whose type differs from its default (corrupt/old/imported data) is replaced by the default.
function U.MergeDefaults(dst, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            U.MergeDefaults(dst[k], v)
        elseif dst[k] == nil or type(dst[k]) ~= type(v) then
            dst[k] = v
        end
    end
    return dst
end

-- Remove every value that equals its default so SavedVariables only hold user changes.
function U.StripDefaults(dst, defaults)
    if type(dst) ~= "table" or type(defaults) ~= "table" then return end
    for k, v in pairs(defaults) do
        local cur = dst[k]
        if type(v) == "table" and type(cur) == "table" then
            U.StripDefaults(cur, v)
            if next(cur) == nil then dst[k] = nil end
        elseif cur == v then
            dst[k] = nil
        end
    end
end

-- "a.b.c" path helpers for option schemas.
function U.GetPath(tbl, path)
    for key in path:gmatch("[^%.]+") do
        if type(tbl) ~= "table" then return nil end
        tbl = tbl[tonumber(key) or key]
    end
    return tbl
end

function U.SetPath(tbl, path, value)
    local keys = {}
    for key in path:gmatch("[^%.]+") do keys[#keys + 1] = tonumber(key) or key end
    for i = 1, #keys - 1 do
        local k = keys[i]
        if type(tbl[k]) ~= "table" then tbl[k] = {} end
        tbl = tbl[k]
    end
    tbl[keys[#keys]] = value
end

function U.Round(v, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor(v * m + 0.5) / m
end

function U.Hex(r, g, b)
    return ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function U.HexToRGB(hex)
    hex = hex:gsub("#", "")
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- Non-secret durations only (our own timers, M+ clock). Never call with combat values.
function U.FormatClock(seconds)
    seconds = math.max(0, seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor(seconds / 60) % 60
    local s = math.floor(seconds % 60)
    if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
    return ("%d:%02d"):format(m, s)
end

function U.ClassColor(classFile)
    local c = classFile and C_ClassColor.GetClassColor(classFile)
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

function U.PlayerKey()
    return UnitName("player") .. " - " .. GetRealmName()
end

-- Debounce: run fn once, delay seconds after the last call.
function U.Debounce(delay, fn)
    local timer
    return function(...)
        local args = { n = select("#", ...), ... }
        if timer then timer:Cancel() end
        timer = C_Timer.NewTimer(delay, function()
            timer = nil
            fn(unpack(args, 1, args.n))
        end)
    end
end

function U.Contains(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end
