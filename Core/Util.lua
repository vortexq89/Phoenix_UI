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
-- Deep equality for saved values (numbers compared with a small tolerance so slider rounding is not a change).
function U.Equal(a, b)
    if a == b then return true end
    local ta, tb = type(a), type(b)
    if ta == "number" and tb == "number" then return math.abs(a - b) < 1e-4 end
    if ta ~= "table" or tb ~= "table" then return false end
    for k, v in pairs(a) do if not U.Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

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

-- A class colour: General's override when one is set, else the game's.
function U.ClassColor(classFile)
    local over = classFile and ns.Theme and ns.Theme.settings.classColors
    over = type(over) == "table" and over[classFile]
    if type(over) == "table" then return over.r or 1, over.g or 1, over.b or 1 end
    local c = classFile and C_ClassColor.GetClassColor(classFile)
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- text in a class colour (|cffRRGGBB…|r)
function U.WrapClass(classFile, text)
    return "|cff" .. U.Hex(U.ClassColor(classFile)) .. tostring(text) .. "|r"
end

-- The player's position on the current map as 0..1 fractions, or nil (no map, instance, or secret values).
function U.PlayerMapXY()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    if ns.Secret.IsSecret(x) or ns.Secret.IsSecret(y) or not (x and y) or (x == 0 and y == 0) then return nil end
    return x, y
end

function U.PlayerKey()
    return UnitName("player") .. " - " .. GetRealmName()
end

