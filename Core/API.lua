local _, ns = ...

--[[ Public plugin API (docs/PLUGIN_API.md). The ONE global Phoenix exposes for other addons: `PhoenixUI`.
    Stable contract, versioned by API_MAJOR (breaking change) and API_MINOR (additions). Everything a plugin needs
    goes through these functions; the internal namespace is not part of the contract.
    Plugins are ordinary Phoenix modules: they get saved settings in the active profile, live on/off from the
    module list, a settings page in the v4 Flow layout, Layout-mode movers and the theme. ]]

local API_MAJOR, API_MINOR = 1, 2 -- 1.1: art kit theme API; 1.2: v8.1 slots (DressArt, ArtEnabled), GetState, On returns ok
local api = {}

api.API_MAJOR, api.API_MINOR = API_MAJOR, API_MINOR

function api:GetVersion() return ns.version, API_MAJOR, API_MINOR end

-- True when this Phoenix provides at least major.minor of the API (same major only).
function api:Supports(major, minor)
    return major == API_MAJOR and (minor or 0) <= API_MINOR
end

-- keys Phoenix keeps for its own plugins (current and planned)
local RESERVED = { Raid = true, Cooldowns = true, Reminders = true, Toast = true, Quickdraw = true, Macros = true,
    MythicPlus = true, Movers = true, General = true, Profiles = true }

local function check(cond, msg) if not cond then error("PhoenixUI: " .. msg, 3) end end

-- Register a plugin. key: unique "Vendor_Name" string. def: { label, desc, category ("system" | "interface" |
-- "combat" | "social" | "utility"), order, icon, defaults, OnInitialize, OnEnable, OnDisable, Refresh,
-- apiMajor }. Labels may be plain text (missing locale keys show as written). Returns the module object:
-- module.db is the plugin's saved table once the profile is loaded (module:IsEnabled(), module:Refresh()).
function api:RegisterPlugin(key, def)
    check(type(key) == "string" and key:match("^[%w_]+$"), "plugin key must be letters, digits and _")
    check(type(def) == "table", "plugin definition must be a table")
    check(def.apiMajor == nil or def.apiMajor == API_MAJOR, ("plugin %s needs API %s, this Phoenix has %d"):format(key,
        tostring(def.apiMajor), API_MAJOR))
    check(not ns.modules[key], "plugin key already used: " .. key)
    -- third-party keys are namespaced ("Vendor_Name"), so a later Phoenix plugin key can never be taken over
    check(key:find("_", 2, true) and not key:find("^Phoenix") and not (ns.Plugins and ns.Plugins.byKey[key])
        and not RESERVED[key], "plugin key must be Vendor_Name and not a Phoenix key: " .. key)
    def.thirdParty = true
    def.label, def.desc = def.label or key, def.desc or ""
    def.icon = def.icon or "general"
    local m = ns:NewModule(key, def)
    -- Registered after Phoenix loaded its profile: bind, initialize and (after login) enable now.
    if ns.DB:BindModule(m) then
        if m.OnInitialize and not ns.SafeCall(m.OnInitialize, m) then m.state = "errored" end
        if IsLoggedIn() and m.state ~= "errored" and m:ShouldEnable() then m:Enable() end
    end
    return m
end

function api:GetPlugin(key)
    local m = ns.modules[key]
    return m and m.thirdParty and m or nil
end

-- A plugin's lifecycle state ("disabled" | "enabled" | "errored" ...) and, for a built-in plugin, why it did not load.
-- Watch PUI_MODULE_STATE (Listen) to see it change.
function api:GetState(key)
    local m = ns.modules[key]
    if not m then return nil end
    local p = ns.Plugins and ns.Plugins.byKey[key]
    return m.state, p and p.reason or m.lastError
end

-- Settings page rows (same schema as Phoenix's own pages: header, toggle, range, select, color, texture, input,
-- button, description; `key` is a dotted path into module.db). Every change calls module:Refresh() live.
function api:RegisterSettings(key, rows)
    check(ns.modules[key], "register the plugin before its settings: " .. tostring(key))
    check(type(rows) == "table", "settings rows must be a table")
    ns:RegisterOptions(key, rows)
end

-- Layout-mode mover. store = { get = fn -> { point, x, y }, set = fn(v), apply = fn(), reset = fn() } (all optional;
-- without a store Phoenix saves the position itself).
function api:RegisterMover(key, frame, label, store)
    local movers = ns:GetModule("Movers")
    check(frame and frame.GetObjectType, "mover needs a frame")
    if movers then movers:Register(key, frame, label, store) return true end
    return false
end

---------------------------------------------------------------- theme and fonts
-- Colour of a theme token ("accent.primary", "text.primary", "text.secondary", "bg.base", "bg.raised",
-- "bg.sunken", "border.subtle", "state.success", "state.danger"): r, g, b, a.
function api:Color(token) return ns.Theme:Color(token) end
-- Font file, size, flags of a role ("title", "heading", "body", "desc", "number", "small", "unit", "combat").
function api:Font(role)
    local r = ns.Theme.fontRoles[role] or ns.Theme.fontRoles.body
    return ns.Media:Font(r.font), r.size, r.flags
end
function api:BarTexture() return ns.Theme:Bar() end
-- Themed font string / panel; both re-theme themselves on theme changes.
function api:CreateText(parent, role, token, justify) return ns.Widgets.Text(parent, role, token, justify) end
function api:StylePanel(frame, style) -- style: "base" | "raised" | "sunken"
    ns.Skin:Register(frame, function(f) ns.Skin:Panel(f, style or "base", { border = "border.subtle" }) end)
end
-- Run fn(frame) now and on every theme or font change.
function api:OnTheme(frame, fn) ns.Skin:Register(frame, fn) end

---------------------------------------------------------------- art kit (1.1, THEME_API §7.0 / 7.00 / 7.01)
-- Swap Phoenix's baked art through tokens: "background.image" / ".fit" / ".anchor" / ".tint" / ".alpha",
-- "logo.*", "panel.alpha.<card|rail|header|preview|footer|meter>" (0.5-1: text keeps 4.5:1), "atlas.ui" or
-- "atlas.ui.<piece>" ({ file, coords = { l, r, t, b }, inset }), "atlas.icons" or "atlas.icons.<key>",
-- "icon.status.<enabled|disabled|warning|error|info>", "texture.meterBG", "meter.barTintScale". Effect tokens
-- (effects.*, ash.*, wings.*) and wrong types are dropped. Returns a handle: h:Set(path, v), h:Clear(path), h:Remove().
function api:OverrideArt(owner, tokens, priority)
    check(type(owner) == "string" and type(tokens) == "table", "OverrideArt(owner, tokens [, priority])")
    return ns.Art:Override(owner, tokens, priority)
end
function api:ArtToken(path) return ns.Art:Token(path) end
-- Your own module icon (rail, Home, status rows): entry = { file = texture path, coords = { l, r, t, b } }.
function api:RegisterIcon(key, entry) return ns.Art:RegisterIcon(key, entry) end
function api:SetModuleIcon(moduleKey, iconKey) ns.Art:SetModuleIcon(moduleKey, iconKey) end
-- Paint a texture with an atlas piece ("card", "btn_pri_normal" …) or an icon ("status_enabled", "mod_chat" …).
function api:PaintArt(tex, piece) return ns.Art:Paint(tex, piece) end
function api:PaintIcon(tex, key) return ns.Art:Icon(tex, key) end
-- v8.1 (THEME_API §7.04): dress a frame with a module slot ("Toast.frame", "Cooldowns.icon" ...); opts as UI/ArtKit.lua
function api:DressArt(frame, slot, opts) return ns.Art.DressSlot and ns.Art:DressSlot(frame, slot, opts) end
-- true while the phoenix-wings look draws game-frame art
function api:ArtEnabled() return ns.Art.GameArt ~= nil and ns.Art.GameArt() end

---------------------------------------------------------------- events
-- Game events and Phoenix messages ("PUI_THEME_CHANGED", "PUI_PROFILE_CHANGED", "PUI_MODULE_STATE",
-- "PUI_SETTING_CHANGED", "PUI_COMBAT_END"). owner: any table, used to unregister.
function api:On(event, owner, fn) return ns.Events:On(event, owner, fn) end
function api:Off(event, owner) ns.Events:Off(event, owner) end
function api:Listen(message, owner, fn) ns.Events:Listen(message, owner, fn) end
-- Run fn now, or as soon as combat ends (protected changes).
function api:AfterCombat(key, fn, ...) ns.Combat:Run(key, fn, ...) end
-- Secret values (12.x): true when v must only be passed to display widgets.
function api:IsSecret(v) return ns.Secret.IsSecret ~= nil and ns.Secret.IsSecret(v) or false end

function api:OpenSettings(key) if ns.Config and ns.Config.Show then ns.Config:Show(key) end end

-- Read-only from the outside: plugins cannot replace the API's functions.
PhoenixUI = setmetatable({}, {
    __index = api,
    __newindex = function() error("PhoenixUI is read-only", 2) end,
    __metatable = false,
})
ns.API = api
