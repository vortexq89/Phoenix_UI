local _, ns = ...

--[[ ns.DB — sole owner of SavedVariables (docs/ARCHITECTURE.md §5).
    PhoenixUIDB = { schema, profiles = { [name] = { modules = { [key] = {...} } } },
                    profileKeys = { [char] = name }, specProfiles = { [char] = { enabled, [specIndex] = name } },
                    global = { modules = { [key] = {...} }, layouts = {}, ui = {} } }
    Defaults are merged in on load and stripped at logout, so only user changes are saved. ]]
local DB = {}
ns.DB = DB
local U = ns.Util

local DEFAULT_PROFILE = "Default"

local function bindModules(self)
    local profile = self.profile
    profile.modules = profile.modules or {}
    local global = self.sv.global
    global.modules = global.modules or {}
    for _, m in ipairs(ns.moduleList) do
        local key = m.key
        profile.modules[key] = U.MergeDefaults(type(profile.modules[key]) == "table" and profile.modules[key] or {}, m.defaults)
        m.db = profile.modules[key]
        if m.globalDefaults then
            global.modules[key] = U.MergeDefaults(type(global.modules[key]) == "table" and global.modules[key] or {}, m.globalDefaults)
            m.global = global.modules[key]
        end
    end
end

local function stripModules(self)
    if not self.profile then return end
    for _, m in ipairs(ns.moduleList) do
        U.StripDefaults(self.profile.modules[m.key], m.defaults)
        if m.globalDefaults then U.StripDefaults(self.sv.global.modules[m.key], m.globalDefaults) end
    end
end

function DB:Init()
    -- fresh: no Phoenix settings at all before this login (first install); the style picker offers itself once
    self.fresh = type(PhoenixUIDB) ~= "table" or next(PhoenixUIDB) == nil
    if type(PhoenixUIDB) ~= "table" then PhoenixUIDB = {} end
    local sv = PhoenixUIDB
    sv.profiles = type(sv.profiles) == "table" and sv.profiles or {}
    sv.profileKeys = type(sv.profileKeys) == "table" and sv.profileKeys or {}
    sv.specProfiles = type(sv.specProfiles) == "table" and sv.specProfiles or {}
    sv.global = type(sv.global) == "table" and sv.global or {}
    sv.global.layouts = type(sv.global.layouts) == "table" and sv.global.layouts or {}
    sv.global.ui = type(sv.global.ui) == "table" and sv.global.ui or {}
    sv.schema = tonumber(sv.schema) or 0
    self.sv = sv
    self.charKey = U.PlayerKey()

    ns.Migrations:Run(sv)

    local name = sv.profileKeys[self.charKey]
    if type(name) ~= "string" or type(sv.profiles[name]) ~= "table" then name = DEFAULT_PROFILE end
    self:Load(name)
    ns.Events:On("PLAYER_LOGOUT", self, function() stripModules(self) end)
end

function DB:Load(name)
    self.sv.profiles[name] = type(self.sv.profiles[name]) == "table" and self.sv.profiles[name] or {}
    self.profile, self.profileName = self.sv.profiles[name], name
    self.sv.profileKeys[self.charKey] = name
    bindModules(self)
end

function DB:GetProfileName() return self.profileName end

function DB:GetProfiles()
    local list = {}
    for name in pairs(self.sv.profiles) do list[#list + 1] = name end
    table.sort(list)
    return list
end

-- Switch the character to another (possibly new) profile and let every module react.
function DB:SetProfile(name)
    if name == self.profileName then return end
    ns.Combat:Run("db.profile", function()
        stripModules(self)
        self:Load(name)
        ns:ReloadModules()
        ns.Events:Fire("PUI_PROFILE_CHANGED", name)
    end)
end

function DB:NewProfile(name, copyFrom)
    if type(name) ~= "string" or name == "" or self.sv.profiles[name] then return false end
    local src = copyFrom and self.sv.profiles[copyFrom]
    if src then
        if copyFrom == self.profileName then stripModules(self) end
        self.sv.profiles[name] = U.DeepCopy(src)
        if copyFrom == self.profileName then bindModules(self) end
    else
        self.sv.profiles[name] = {}
    end
    return true
end

function DB:DeleteProfile(name)
    if name == self.profileName or not self.sv.profiles[name] then return false end
    self.sv.profiles[name] = nil
    for char, p in pairs(self.sv.profileKeys) do
        if p == name then self.sv.profileKeys[char] = nil end
    end
    return true
end

function DB:RenameProfile(old, new)
    if type(new) ~= "string" or new == "" or self.sv.profiles[new] or not self.sv.profiles[old] then return false end
    self.sv.profiles[new], self.sv.profiles[old] = self.sv.profiles[old], nil
    for char, p in pairs(self.sv.profileKeys) do
        if p == old then self.sv.profileKeys[char] = new end
    end
    if self.profileName == old then self.profileName = new end
    ns.Events:Fire("PUI_PROFILE_CHANGED", self.profileName)
    return true
end

function DB:ResetProfile()
    ns.Combat:Run("db.reset", function()
        wipe(self.profile)
        bindModules(self)
        ns:ReloadModules()
        ns.Events:Fire("PUI_PROFILE_CHANGED", self.profileName)
    end)
end

-- Returns a stripped deep copy of the active profile (for export).
function DB:SnapshotProfile()
    stripModules(self)
    local copy = U.DeepCopy(self.profile)
    bindModules(self)
    return copy
end

-- Replaces the given modules' settings in the active profile ({ [key] = savedTable }) and reloads them.
function DB:ReplaceModules(map)
    ns.Combat:Run("db.merge", function()
        stripModules(self)
        for key, values in pairs(map) do self.profile.modules[key] = U.DeepCopy(values) end
        bindModules(self)
        ns:ReloadModules()
        ns.Events:Fire("PUI_PROFILE_CHANGED", self.profileName)
    end)
end

-- Characters that have used Phoenix on this account and the profile each loads ({ { key, profile }, ... }).
function DB:GetCharacters()
    local list = {}
    for char, name in pairs(self.sv.profileKeys) do list[#list + 1] = { key = char, profile = name } end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

-- Which profile a character loads next login (this character switches now).
function DB:SetCharacterProfile(char, name)
    if type(name) ~= "string" or type(self.sv.profiles[name]) ~= "table" then return false end
    if char == self.charKey then self:SetProfile(name) else self.sv.profileKeys[char] = name end
    return true
end

function DB:ImportProfile(name, data)
    self.sv.profiles[name] = data
    self:SetProfile(name)
end

-- The single write path for settings. Fires live updates.
function DB:Set(module, path, value)
    assert(not issecretvalue(value), "Phoenix_UI: secret values cannot be saved")
    U.SetPath(module.db, path, value)
    if module.OnSettingChanged then ns.SafeCall(module.OnSettingChanged, module, path, value) end
    ns.Events:Fire("PUI_SETTING_CHANGED", module.key, path, value)
end

function DB:Get(module, path)
    return U.GetPath(module.db, path)
end

-- Per-specialisation automatic profiles.
function DB:GetSpecProfiles()
    local t = self.sv.specProfiles[self.charKey]
    if type(t) ~= "table" then t = { enabled = false }; self.sv.specProfiles[self.charKey] = t end
    return t
end

ns.Events:On("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", DB, function()
    local t = DB:GetSpecProfiles()
    if not t.enabled then return end
    local spec = C_SpecializationInfo.GetSpecialization()
    local name = spec and t[spec]
    if type(name) == "string" and DB.sv.profiles[name] then DB:SetProfile(name) end
end)
