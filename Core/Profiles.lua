local _, ns = ...

--[[ ns.Profiles — export/import strings: "!PUI1!" .. Base64(Deflate(CBOR(payload))) via C_EncodingUtil.
    No addon-comms sharing (comms are blocked during Midnight lockdown). ]]
local P = {}
ns.Profiles = P
local PREFIX = "!PUI1!"
local E = C_EncodingUtil

function P:Export()
    local payload = {
        v = 1, schema = ns.DB.sv.schema, addon = ns.version,
        name = ns.DB:GetProfileName(), profile = ns.DB:SnapshotProfile(),
    }
    return PREFIX .. E.EncodeBase64(E.CompressString(E.SerializeCBOR(payload)))
end

-- Returns payload or nil, errorKey. Parsing untrusted text: every stage is checked.
function P:Decode(text)
    if type(text) ~= "string" then return nil, "IMPORT_ERR_EMPTY" end
    text = text:gsub("%s", "")
    if text == "" then return nil, "IMPORT_ERR_EMPTY" end
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, "IMPORT_ERR_PREFIX" end
    local ok, raw = pcall(E.DecodeBase64, text:sub(#PREFIX + 1))
    if not ok or not raw then return nil, "IMPORT_ERR_CORRUPT" end
    local ok2, inflated = pcall(E.DecompressString, raw)
    if not ok2 or not inflated then return nil, "IMPORT_ERR_CORRUPT" end
    local ok3, payload = pcall(E.DeserializeCBOR, inflated)
    if not ok3 or type(payload) ~= "table" or type(payload.profile) ~= "table" then return nil, "IMPORT_ERR_CORRUPT" end
    if type(payload.schema) ~= "number" or payload.schema > ns.C.SCHEMA then return nil, "IMPORT_ERR_NEWER" end
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
