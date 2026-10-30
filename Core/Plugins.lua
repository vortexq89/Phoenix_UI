local _, ns = ...

--[[ Plugin loader (docs/PLUGIN_SPLIT.md). Each optional system ships as its own load-on-demand addon folder,
    Phoenix_UI_<Key>, and is loaded only when the active profile has it on. A plugin that is not loaded is a
    placeholder module: it shows in the plugin manager, the sidebar and Home with its toggle, keeps its saved
    settings, and never runs. Turning it on loads the folder and enables it live (systems that take over Blizzard
    frames at login, reloadOnToggle, ask for a reload instead). WoW cannot unload addon code, so turning a loaded
    plugin off disables it live and the code stays resident until the next /reload.
    Plugin files share Phoenix_UI's private namespace through PhoenixUI_Bridge, set only while LoadAddOn runs. ]]
local Plugins = { list = {}, byKey = {} }
ns.Plugins = Plugins

-- key, label, desc, category, order, icon, feature, reloadOnToggle, needs (plugins whose code must load first)
local function add(key, label, category, order, extra)
    local p = extra or {}
    p.key, p.label, p.desc, p.category, p.order = key, label, label .. "_DESC", category, order
    p.addon = "Phoenix_UI_" .. key
    Plugins.list[#Plugins.list + 1] = p
    Plugins.byKey[key] = p
end
local R = true
add("Skins", "SKINS", "interface", 5, { reloadOnToggle = R })
add("ActionBars", "ACTIONBARS", "interface", 10, { reloadOnToggle = R })
add("UnitFrames", "UNITFRAMES", "interface", 20, { reloadOnToggle = R, needs = { "CastBars" } })
add("GroupFrames", "GROUPFRAMES", "interface", 30, { reloadOnToggle = R, needs = { "UnitFrames" } })
add("CastBars", "CASTBARS", "interface", 40, { reloadOnToggle = R, needs = { "UnitFrames" } })
add("Auras", "AURAS", "interface", 50, { reloadOnToggle = R })
add("NamePlates", "NAMEPLATES", "interface", 55, { reloadOnToggle = R, needs = { "UnitFrames", "CastBars" } })
add("Tooltip", "TOOLTIP", "interface", 60, { reloadOnToggle = R })
add("ItemLevel", "ITEMLEVEL", "interface", 70)
add("Bags", "BAGS", "interface", 72, { reloadOnToggle = R, icon = "items" })
add("Sim", "SIM", "utility", 74, { icon = "sim", feature = "sim" })
add("Minimap", "MINIMAP", "interface", 80, { reloadOnToggle = R })
add("DataTexts", "DATATEXTS", "interface", 90)
add("CooldownText", "COOLDOWNTEXT", "combat", 10)
add("Tracker", "TRACKER", "combat", 15, { reloadOnToggle = R, icon = "tracker" })
add("Encounters", "ENCOUNTERS", "combat", 12, { icon = "encounters" })
add("DamageMeter", "DAMAGEMETER", "combat", 30)
add("SpellHistory", "SPELLHISTORY", "combat", 40)
add("PvP", "PVP", "combat", 50, { reloadOnToggle = R })
add("Chat", "CHAT", "social", 10)
add("AFK", "AFK", "social", 40)
add("Automation", "AUTOMATION", "utility", 20)
add("Quests", "QUESTS", "utility", 25, { reloadOnToggle = R, icon = "maps" })
add("GroupFinder", "GROUPFINDER", "utility", 26, { reloadOnToggle = R, icon = "search", feature = "lfgList" })
add("MythicPlus", "MYTHICPLUS", "utility", 30, { feature = "mythicplus" })

-- The module if its code is loaded (nil for a placeholder or an unknown key): use this for cross-system calls.
function ns:Loaded(key)
    local m = ns.modules[key]
    if m and not m.placeholder then return m end
end

function Plugins:Get(key) return self.byKey[key] end

-- On in the active profile (a missing value is the module default: on).
function Plugins:Wanted(p)
    if not ns:Supports(p.feature) then return false end
    local mods = ns.DB.profile and ns.DB.profile.modules
    local db = mods and mods[p.key]
    return not (type(db) == "table" and db.enabled == false)
end

-- "loaded" | "off" | "missing" | "reload" (on, but only takes effect after a reload)
function Plugins:State(p)
    if p.loaded then
        local m = ns.modules[p.key]
        if m and m.needsReload then return "reload" end
        return m and m.db and m.db.enabled == false and "off" or "loaded"
    end
    if p.missing then return "missing" end
    return self:Wanted(p) and "reload" or "off"
end

local function loadOne(key, seen)
    if seen[key] then return end
    seen[key] = true
    local p = Plugins.byKey[key]
    if not p or p.loaded then return end
    for _, dep in ipairs(p.needs or {}) do
        loadOne(dep, seen)
        local d = Plugins.byKey[dep]
        -- a required plugin that did not load: skip this one too (it would hit nil paths at runtime)
        if d and not d.loaded then
            p.missing, p.reason, p.loadedNow, p.loaded = true, "needs " .. dep, false, false
            return
        end
    end
    p.missing, p.reason = nil, nil -- a retry after the user re-enabled the folder starts clean (L7)
    local ok, loaded, why = pcall(C_AddOns.LoadAddOn, p.addon)
    local m = ns.modules[key]
    p.loaded = ok and loaded and m and not m.placeholder or false
    if not p.loaded then
        p.missing = true
        p.reason = ok and why or tostring(loaded)
    end
    p.loadedNow = p.loaded
end

-- Loads the given plugin keys (and what they need). Returns the keys whose module code arrived.
function Plugins:Load(keys)
    local seen, arrived = {}, {}
    PhoenixUI_Bridge = ns
    for _, key in ipairs(keys) do loadOne(key, seen) end
    PhoenixUI_Bridge = nil
    for _, p in ipairs(self.list) do
        if p.loadedNow then p.loadedNow = nil; arrived[#arrived + 1] = p.key end
    end
    return arrived
end

-- Placeholder for a plugin that is not loaded, so menus, profiles and toggles keep working.
local function placeholder(p)
    if ns.modules[p.key] then return end
    local m = ns:NewModule(p.key, { label = p.label, desc = p.desc, category = p.category, order = p.order,
        icon = p.icon, feature = p.feature, reloadOnToggle = p.reloadOnToggle })
    m.placeholder = true
    ns.DB:BindModule(m)
end

-- ADDON_LOADED, after DB:Init and before modules initialize.
function Plugins:Boot()
    local want = {}
    for _, p in ipairs(self.list) do
        if ns:Loaded(p.key) then p.loaded = true -- still built into Phoenix_UI
        elseif self:Wanted(p) then want[#want + 1] = p.key end
    end
    self:Load(want)
    for _, p in ipairs(self.list) do placeholder(p) end
end

-- Loads a placeholder now and brings it up as if it had been there at login. Out of combat only.
function Plugins:Activate(key)
    local arrived = self:Load({ key })
    for _, k in ipairs(arrived) do
        local m = ns.modules[k]
        ns.DB:BindModule(m)
        if m.OnInitialize and not m.unavailable and not ns.SafeCall(m.OnInitialize, m) then m.state = "errored" end
    end
    ns:SortModules()
    for _, k in ipairs(arrived) do
        local m = ns.modules[k]
        if IsLoggedIn() and m.state ~= "errored" and m:ShouldEnable() then m:Enable() end
    end
    return ns:Loaded(key) ~= nil
end

-- Profile switch: load what the new profile turns on (live where the system allows it).
function Plugins:LoadWanted()
    for _, p in ipairs(self.list) do
        local m = ns.modules[p.key]
        if m and m.placeholder and self:Wanted(p) then
            if p.reloadOnToggle then m.needsReload = true else self:Activate(p.key) end
        end
    end
end

-- Memory of a loaded plugin folder in KB (nil when unknown).
function Plugins:Memory(p)
    if not (p.loaded and UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then return nil end
    return GetAddOnMemoryUsage(p.addon)
end
