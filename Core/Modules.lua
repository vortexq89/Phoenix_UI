local _, ns = ...

--[[ Module manager (ARCHITECTURE §4).
    ns:NewModule(key, def) -> module; def = { label, desc, category, order, icon, defaults, globalDefaults,
    requires, reloadOnToggle, locked, loadWhen, feature, descWithout }.
    A module whose `feature` this client lacks (ns:Supports, Core/Flavor.lua) is unavailable: never
    initialized or enabled and hidden from every menu, while its saved settings stay untouched for the other
    game. descWithout = { feature, desc } is the description on a client without that feature, so a card
    never promises what is not there. Lifecycle: OnInitialize, OnEnable, OnDisable,
    OnSettingChanged(path, value) (default: Refresh), OnProfileChanged (default: re-evaluate enabled). ]]
local Module = {}
Module.__index = Module

local CATEGORY_ORDER = { "system", "interface", "combat", "social", "utility" }
ns.categories = CATEGORY_ORDER

function ns:NewModule(key, def)
    assert(not ns.modules[key], "duplicate module " .. key)
    def = def or {}
    local m = setmetatable(def, Module)
    m.key = key
    m.defaults = m.defaults or {}
    if m.defaults.enabled == nil then m.defaults.enabled = true end
    m.category = m.category or "utility"
    m.order = m.order or 100
    m.icon = m.icon or key:lower()
    m.state = "disabled"
    if not ns:Supports(m.feature) then m.unavailable, m.hidden = true, true end
    if m.descWithout and not ns:Supports(m.descWithout.feature) then m.desc = m.descWithout.desc end
    ns.modules[key] = m
    ns.moduleList[#ns.moduleList + 1] = m
    return m
end

function ns:GetModule(key)
    return ns.modules[key]
end

-- Rows tagged with a feature this client lacks are dropped here, so search, presets and the renderer never
-- see them.
function ns:RegisterOptions(key, schema)
    ns.options[key] = ns:FilterSchema(schema)
end

local function sortModules()
    local rank = {}
    for i, c in ipairs(CATEGORY_ORDER) do rank[c] = i end
    table.sort(ns.moduleList, function(a, b)
        local ra, rb = rank[a.category] or 99, rank[b.category] or 99
        if ra ~= rb then return ra < rb end
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)
end

function Module:IsEnabled()
    return self.state == "enabled"
end

function Module:ShouldEnable()
    if not self.db or self.unavailable then return false end
    if not self.locked and not self.db.enabled then return false end
    if self.requires then
        for _, dep in ipairs(self.requires) do
            local d = ns.modules[dep]
            if not d or not d:ShouldEnable() then return false end
        end
    end
    if self.loadWhen and not self.loadWhen() then return false end
    return true
end

function Module:Enable()
    if self.state == "enabled" then return true end
    local ok = true
    if self.OnEnable then ok = ns.SafeCall(self.OnEnable, self) end
    self.state = ok and "enabled" or "errored"
    ns.Events:Fire("PUI_MODULE_STATE", self.key, self.state)
    return ok
end

function Module:Disable()
    if self.state ~= "enabled" and self.state ~= "errored" then return end
    if self.OnDisable then ns.SafeCall(self.OnDisable, self) end
    ns.Events:OffAll(self)
    self.state = "disabled"
    ns.Events:Fire("PUI_MODULE_STATE", self.key, self.state)
end

function Module:Refresh() end

function Module:OnSettingChanged()
    if self:IsEnabled() then self:Refresh() end
end

-- Runtime toggle from the config UI.
function ns:SetModuleEnabled(key, enabled)
    local m = ns.modules[key]
    if not m or m.locked then return end
    ns.DB:Set(m, "enabled", enabled and true or false)
    if m.reloadOnToggle then
        m.needsReload = true
        ns.Events:Fire("PUI_MODULE_STATE", key, m.state)
        return
    end
    ns.Combat:Run("module." .. key, function()
        if enabled and m:ShouldEnable() then m:Enable() else m:Disable() end
    end)
end

function ns:ReloadModules()
    for _, m in ipairs(ns.moduleList) do
        if m.OnProfileChanged then
            ns.SafeCall(m.OnProfileChanged, m)
        else
            local want = m:ShouldEnable()
            if want and m:IsEnabled() then
                ns.SafeCall(m.Refresh, m)
            elseif want then
                m:Enable()
            elseif m.reloadOnToggle and m:IsEnabled() then
                m.needsReload = true
            else
                m:Disable()
            end
        end
    end
end

function ns:InitializeModules()
    sortModules()
    for _, m in ipairs(ns.moduleList) do
        if m.OnInitialize and not m.unavailable then
            if not ns.SafeCall(m.OnInitialize, m) then m.state = "errored" end
        end
    end
end

function ns:EnableModules()
    for _, m in ipairs(ns.moduleList) do
        if m.state ~= "errored" and m:ShouldEnable() then m:Enable() end
    end
end
