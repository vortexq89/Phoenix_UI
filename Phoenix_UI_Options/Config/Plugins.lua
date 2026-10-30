local _, ns = ...
local L = ns.L
local W = ns.Widgets
local Config = ns.Config

--[[ Plugin manager (docs/PLUGIN_SPLIT.md §4): every optional system is its own Phoenix_UI_<Key> addon folder,
    loaded only when it is on. One row per plugin, grouped by category: state chip (Loaded / Off / Not installed /
    Needs reload), memory once loaded, and its switch. Header: counts, Enable all, Minimal. ]]
local P = ns.Plugins
local page = { key = "plugins", label = "PLUGINS", desc = "PLUGINS_DESC", icon = "addon", locked = true, db = {} }
local MINIMAL = { ActionBars = true, UnitFrames = true, CastBars = true, GroupFrames = true }

local function chip(state)
    if state == "loaded" then return L.PLUGIN_LOADED, "state.success" end
    if state == "missing" then return L.PLUGIN_MISSING, "state.danger" end
    if state == "reload" then return L.PLUGIN_RELOAD, "state.warning" end
    return L.PLUGIN_OFF, "text.muted"
end
local CATS = {
    system = { label = "PLUGINS_CAT_SYSTEM", icon = "cat-phoenix" },
    interface = { label = "PLUGINS_CAT_INTERFACE", icon = "addon" },
    combat = { label = "PLUGINS_CAT_COMBAT", icon = "cat-combat" },
    social = { label = "PLUGINS_CAT_SOCIAL", icon = "addon" },
    utility = { label = "PLUGINS_CAT_UTILITY", icon = "cat-utility" },
}

local function setOn(p, on)
    local m = ns.modules[p.key]
    if m and not m.locked and (m.db.enabled ~= false) ~= on then ns:SetModuleEnabled(p.key, on) end
end

local function pluginRow(row, p)
    local h = CreateFrame("Frame", nil, row)
    h:SetSize(W.CONTROL_WIDTH, 28)
    h.toggle = W:Toggle(h)
    h.toggle:SetPoint("RIGHT")
    h.toggle.onChange = function(_, v) setOn(p, v); C_Timer.After(0, function() h:SetValue() end) end
    h.badge = W:Badge(h, "", "text.muted")
    h.badge:SetPoint("RIGHT", h.toggle, "LEFT", -10, 0)
    h.mem = W.Text(h, "small", "text.muted", "RIGHT")
    h.mem:SetPoint("RIGHT", h.badge, "LEFT", -8, 0)
    function h:SetValue()
        self.badge:Set(chip(P:State(p)))
        local kb = P:Memory(p)
        self.mem:SetText(type(kb) == "number" and ("%.0f KB"):format(kb) or "")
        local m = ns.modules[p.key]
        self.toggle:SetValue(m and m.db and m.db.enabled ~= false)
        W.SetEnabledState(self.toggle, not p.missing)
    end
    ns.Events:Listen("PUI_MODULE_STATE", h, function() h:SetValue() end)
    h:SetValue()
    return h
end

local function counts()
    local loaded, total = 0, 0
    for _, p in ipairs(P.list) do
        if ns:Supports(p.feature) then
            total = total + 1
            if p.loaded then loaded = loaded + 1 end
        end
    end
    return L.PLUGINS_COUNT:format(loaded, total)
end

local function schema()
    if UpdateAddOnMemoryUsage and not InCombatLockdown() then UpdateAddOnMemoryUsage() end
    local s = {
        { type = "header", label = "PLUGINS", icon = "addon" },
        { type = "description", text = "PLUGINS_INTRO" },
        { type = "description", text = counts },
        { type = "button", label = "PLUGINS_ALL", desc = "PLUGINS_ALL_DESC", button = "PLUGINS_ALL_BUTTON", icon = "check",
          combat = true, func = function() for _, p in ipairs(P.list) do setOn(p, true) end end },
        { type = "button", label = "PLUGINS_MINIMAL", desc = "PLUGINS_MINIMAL_DESC", button = "PLUGINS_MINIMAL_BUTTON",
          icon = "reset", combat = true, func = function() for _, p in ipairs(P.list) do setOn(p, MINIMAL[p.key] or false) end end },
    }
    for _, cat in ipairs(ns.categories) do
        local first = true
        for _, p in ipairs(P.list) do
            if p.category == cat and ns:Supports(p.feature) then
                if first then s[#s + 1] = { type = "header", label = CATS[cat].label, icon = CATS[cat].icon }; first = false end
                s[#s + 1] = { type = "custom", label = p.label, desc = p.desc, build = function(row) return pluginRow(row, p) end }
            end
        end
    end
    return s
end

Config:RegisterPage("plugins", function(parent)
    return Config.BuildSchemaPage(parent, page, schema())
end, { label = page.label, icon = page.icon, object = page, schema = schema })

-- A plugin that is not loaded has no option schema of its own here: its page says how to load it.
local placeholderSchema = {
    { type = "header", label = "PLUGIN_NOT_LOADED", icon = "addon" },
    { type = "description", text = "PLUGIN_NOT_LOADED_TEXT" },
    { type = "button", label = "PLUGINS", desc = "PLUGINS_DESC", button = "PLUGINS_OPEN", icon = "addon",
      func = function() Config:Show("plugins") end },
}
Config.placeholderSchema = placeholderSchema
