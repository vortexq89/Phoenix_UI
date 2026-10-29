local _, ns = ...

--[[ ns.Profiles — share strings: "!PUI2!" .. Base64(Deflate(CBOR(payload))) via C_EncodingUtil.
    v2 payloads carry a header (title, author, client flavor, addon version, date, module list) and a checksum
    of the settings, so a damaged paste is refused instead of half-applied; "!PUI1!" strings still import.
    Every string has a short code (PX-XXXX-XXXX, a fingerprint of the settings) that names it on the Phoenix
    website's Profiles page and lets two people check they hold the same design.
    No addon-comms sharing (comms are blocked during Midnight lockdown). ]]
local P = {}
ns.Profiles = P
local PREFIX, PREFIX1 = "!PUI2!", "!PUI1!"
local E = C_EncodingUtil
P.VERSION = 2

-- Canonical text of a value (keys sorted), the input of the checksum and the short code.
local function canon(v, out)
    local t = type(v)
    if t == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        out[#out + 1] = "{"
        for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "="; canon(v[k], out); out[#out + 1] = ";" end
        out[#out + 1] = "}"
    else
        out[#out + 1] = t:sub(1, 1) .. tostring(v)
    end
    return out
end

-- FNV-1a, 32 bit, in plain Lua 5.1 arithmetic (no bit library needed).
local function fnv(text, seed)
    local h = seed or 2166136261
    for i = 1, #text do
        local x, b, r, bit = h, text:byte(i), 0, 1
        for _ = 1, 8 do                                  -- h = h XOR byte
            local xa, ba = x % 2, b % 2
            if xa ~= ba then r = r + bit end
            x, b, bit = (x - xa) / 2, (b - ba) / 2, bit * 2
        end
        h = r + x * 256
        h = ((h % 256) * 16777216 + h * 403) % 4294967296 -- h * 16777619 mod 2^32 without losing bits
    end
    return h
end

function P.Checksum(profile) return fnv(table.concat(canon(profile, {}))) end

local B32 = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ" -- no 0/O/1/I: read aloud or typed without mistakes
local function base32(n, len)
    local s = ""
    for _ = 1, len do
        local d = n % 32
        s = B32:sub(d + 1, d + 1) .. s
        n = (n - d) / 32
    end
    return s
end

-- PX-XXXX-XXXX: 40 bits of two hashes of the settings.
function P.ShortCode(profile)
    local text = table.concat(canon(profile, {}))
    local a, b = fnv(text), fnv(text, 2654435769)
    local code = base32(a % 1048576, 4) .. base32(b % 1048576, 4)
    return "PX-" .. code:sub(1, 4) .. "-" .. code:sub(5, 8)
end

-- keys: optional set { [moduleKey] = true } to share only those modules (payload.partial marks such a string).
-- meta: optional { title, author }. Returns the string and its short code.
function P:Export(keys, meta)
    local profile = ns.DB:SnapshotProfile()
    if keys then
        local only = { modules = {} }
        for key in pairs(keys) do
            if type(profile.modules) == "table" and profile.modules[key] ~= nil then only.modules[key] = profile.modules[key] end
        end
        profile = only
    end
    local mods = {}
    for key in pairs(type(profile.modules) == "table" and profile.modules or {}) do mods[#mods + 1] = key end
    table.sort(mods)
    meta = type(meta) == "table" and meta or {}
    local payload = {
        v = P.VERSION, schema = ns.DB.sv.schema, addon = ns.version, partial = keys and true or nil,
        name = ns.DB:GetProfileName(), profile = profile,
        title = meta.title ~= "" and meta.title or nil, author = meta.author ~= "" and meta.author or nil,
        flavor = ns.flavor, created = time and time() or nil, modules = mods, sum = P.Checksum(profile),
    }
    return PREFIX .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(payload))), P.ShortCode(profile)
end

-- Returns payload or nil, errorKey. Parsing untrusted text: every stage is checked.
function P:Decode(text)
    if type(text) ~= "string" then return nil, "IMPORT_ERR_EMPTY" end
    text = text:gsub("%s", "")
    if text == "" then return nil, "IMPORT_ERR_EMPTY" end
    local head = text:sub(1, #PREFIX)
    if head ~= PREFIX and head ~= PREFIX1 then return nil, "IMPORT_ERR_PREFIX" end
    local ok, raw = pcall(E.DecodeBase64, text:sub(#PREFIX + 1))
    if not ok or not raw then return nil, "IMPORT_ERR_CORRUPT" end
    local ok2, inflated = pcall(E.DecompressString, raw)
    if not ok2 or not inflated then return nil, "IMPORT_ERR_CORRUPT" end
    local ok3, payload = pcall(E.DeserializeCBOR, inflated)
    if not ok3 or type(payload) ~= "table" or type(payload.profile) ~= "table" then return nil, "IMPORT_ERR_CORRUPT" end
    if type(payload.schema) ~= "number" or payload.schema > ns.C.SCHEMA then return nil, "IMPORT_ERR_NEWER" end
    if head == PREFIX and payload.sum ~= nil and payload.sum ~= P.Checksum(payload.profile) then return nil, "IMPORT_ERR_CORRUPT" end
    payload.code = P.ShortCode(payload.profile)
    return payload
end

-- Human-readable summary for the import preview: which modules the string changes.
function P:Summarize(payload)
    local list = {}
    local mods = type(payload.profile.modules) == "table" and payload.profile.modules or {}
    for key, values in pairs(mods) do
        local m = ns.modules[key]
        if m and type(values) == "table" then
            local n = 0
            for _ in pairs(values) do n = n + 1 end
            list[#list + 1] = { key = key, label = ns.L[m.label] or key, count = n }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

-- Never overwrites: a taken name becomes "Name (2)", "Name (3)" …
local function freeName(base)
    local profiles, name, n = ns.DB.sv.profiles, base, 1
    while profiles[name] do
        n = n + 1
        name = ("%s (%d)"):format(base, n)
    end
    return name
end

function P:Import(payload, name)
    name = (type(name) == "string" and name ~= "") and name or (type(payload.name) == "string" and payload.name) or "Imported"
    name = freeName(name)
    local profile = { modules = {} }
    for key, values in pairs(type(payload.profile.modules) == "table" and payload.profile.modules or {}) do
        if ns.modules[key] and type(values) == "table" then profile.modules[key] = values end
    end
    ns.Migrations:UpgradeProfile(profile, payload.schema)
    ns.DB:ImportProfile(name, profile)
    return name
end

-- Leaf settings that differ between two saved (default-stripped) module tables.
local function countDiff(a, b)
    if type(a) ~= "table" and type(b) ~= "table" then return a == b and 0 or 1 end
    local n = 0
    if type(a) ~= "table" then n, a = (a ~= nil and 1 or 0), {} end
    if type(b) ~= "table" then n, b = n + (b ~= nil and 1 or 0), {} end
    for k, v in pairs(a) do n = n + countDiff(v, b[k]) end
    for k, v in pairs(b) do if a[k] == nil then n = n + countDiff(nil, v) end end
    return n
end

--[[ What importing would change against the active profile, module by module:
    { { key, label, changes = n }, ... } for every module in the string, sorted by label; changes = 0 means the
    string matches what you have. Used by the import preview and to merge chosen modules. ]]
function P:Diff(payload)
    local mine = ns.DB:SnapshotProfile().modules or {}
    local list = {}
    for key, values in pairs(type(payload.profile.modules) == "table" and payload.profile.modules or {}) do
        local m = ns.modules[key]
        if m and type(values) == "table" then
            list[#list + 1] = { key = key, label = ns.L[m.label] or key, changes = countDiff(values, mine[key] or {}) }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

-- Setting-level changes of one module: { { path = "a.b", mine = v, theirs = v }, ... } sorted by path, at most limit.
function P:Changes(payload, key, limit)
    local theirs = type(payload.profile.modules) == "table" and payload.profile.modules[key]
    local mine = (ns.DB:SnapshotProfile().modules or {})[key] or {}
    local out = {}
    local function walk(a, b, path)
        if type(a) == "table" or type(b) == "table" then
            local seen = {}
            local bt = type(b) == "table" and b or {}
            for k, v in pairs(type(a) == "table" and a or {}) do seen[k] = true; walk(v, bt[k], path .. "." .. tostring(k)) end
            for k, v in pairs(type(b) == "table" and b or {}) do if not seen[k] then walk(nil, v, path .. "." .. tostring(k)) end end
        elseif a ~= b and a ~= nil then
            out[#out + 1] = { path = path:sub(2), theirs = a, mine = b }
        end
    end
    walk(theirs, mine, "")
    table.sort(out, function(x, y) return x.path < y.path end)
    local total = #out
    if limit then for i = #out, limit + 1, -1 do out[i] = nil end end
    return out, total
end

-- Deep overlay: the string's values win, everything it does not mention stays as you have it.
local function overlay(into, from)
    for k, v in pairs(from) do
        if type(v) == "table" and type(into[k]) == "table" then overlay(into[k], v) else into[k] = ns.Util.DeepCopy(v) end
    end
    return into
end

--[[ Applies an import string to the active profile. keys: set of modules (nil = all of them). mode:
    "replace" (default) the chosen modules become exactly the string's; "merge" only the settings the string
    sets are written, the rest of each module stays yours. Returns how many modules changed. ]]
function P:Apply(payload, keys, mode)
    if mode ~= "merge" then return self:Merge(payload, keys) end
    local mine = ns.DB:SnapshotProfile().modules or {}
    local map = {}
    for key, values in pairs(type(payload.profile.modules) == "table" and payload.profile.modules or {}) do
        if ns.modules[key] and type(values) == "table" and (not keys or keys[key]) then
            local up = { modules = { [key] = ns.Util.DeepCopy(values) } }
            ns.Migrations:UpgradeProfile(up, payload.schema)
            map[key] = overlay(ns.Util.DeepCopy(mine[key] or {}), up.modules[key])
        end
    end
    local n = 0
    for _ in pairs(map) do n = n + 1 end
    if n > 0 then ns.DB:ReplaceModules(map) end
    return n
end

-- Writes the chosen modules of an import string into the active profile (keys: set, or nil for all of them).
function P:Merge(payload, keys)
    local profile = { modules = {} }
    for key, values in pairs(type(payload.profile.modules) == "table" and payload.profile.modules or {}) do
        if ns.modules[key] and type(values) == "table" and (not keys or keys[key]) then profile.modules[key] = values end
    end
    ns.Migrations:UpgradeProfile(profile, payload.schema)
    local n = 0
    for _ in pairs(profile.modules) do n = n + 1 end
    if n > 0 then ns.DB:ReplaceModules(profile.modules) end
    return n
end
