local _, ns = ...
local Style, Secret = ns.Style, ns.Secret

--[[ Cooldown Manager (module key "Tracker", formerly "Auras & Cooldowns"): the Phoenix take on what WeakAuras
    did, inside the 12.x rules. One module owns every cooldown and tracked-buff display:
      Viewers.lua    Blizzard's Cooldown Manager viewers (Essential, Utility, Tracked buffs, Tracked bars). They
                     receive the protected cooldown and aura data; Phoenix dresses their item frames and lays them
                     out on its own grid, anchored to the viewer (Edit Mode keeps the viewer) or to a Phoenix mover.
      Custom.lua     up to three Phoenix bars of spells, items and trinkets the viewers cannot show, fed duration
                     objects (C_Spell.GetSpellCooldownDuration) and boolean sinks only, so they work in combat.
      Reminders.lua  out-of-combat reminders: flask, food, augment rune, weapon oil, your raid buff, pet,
                     healthstone, and a mana warning on ready checks.
    Buffs & Debuffs (Modules/Auras) is separate: it shows every buff and debuff on you; this module shows only
    what you picked in the Cooldown Manager or listed on a custom bar. Countdown numbers belong to Cooldown Text
    (one owner): a viewer either hands its numbers to Cooldown Text or claims them with its own font. ]]

local function with(t, extra)
    if extra then for k, v in pairs(extra) do t[k] = v end end
    return t
end

local function grid(size, extra)
    return with({ enabled = true, size = size, perRow = 8, rows = 2, rowDelta = 0, spacing = 2, growth = "RIGHT",
        wrap = "DOWN", center = true, keepInPlace = false, overflow = "row" }, extra)
end

local function place(mode, y) return { mode = mode, point = "CENTER", x = 0, y = y, scale = 1 } end

local function visibility()
    return { mode = "always", mounted = false, vehicle = true, spec1 = true, spec2 = true, spec3 = true, spec4 = true }
end

-- One viewer's look and behaviour. Icon viewers and custom bars share every key; the bar viewer adds its bar keys.
local function viewer(timer, size, y, extra)
    return with({
        style = true, square = true, zoom = 0.08, hideDebuffBorder = false,
        border = Style.Border({ style = "solid" }),
        timer = Style.Text(timer, { outline = "OUTLINE", shadow = false }),
        count = Style.Text(12, { outline = "OUTLINE", shadow = false, anchor = "BOTTOMRIGHT", x = -1, y = 1 }),
        keybind = Style.Text(10, { outline = "OUTLINE", shadow = false, anchor = "TOPRIGHT", x = -1, y = -1 }),
        timerSource = "cooldowntext", desaturate = true, hideGCD = false, swipeAlpha = 0.7, rangeTint = true,
        keybinds = false, procGlow = "blizzard", procColor = false, readyGlow = "none", readyColor = false,
        readyTime = 1.5, layout = grid(size), position = place("editmode", y), visibility = visibility(),
    }, extra)
end

local function custom(n)
    return viewer(14, 36, -260 - n * 44, {
        enabled = n == 1, list = "", trinkets = n == 1, show = "always", charges = true, tooltips = true,
        position = place("mover", -260 - n * 44), readyGlow = "none",
    })
end

local M = ns:NewModule("Tracker", {
    label = "TRACKER", desc = "TRACKER_DESC", category = "combat", order = 15, icon = "tracker", reloadOnToggle = true,
    defaults = {
        viewers = {
            essential = viewer(16, 40, -150),
            utility = viewer(13, 30, -200),
            buffs = viewer(13, 34, -100, { layout = grid(34, { perRow = 12, rows = 1, keepInPlace = false }) }),
            bars = viewer(12, 30, -40, {
                texture = "", barColor = false, readyGlow = "none", gradient = "none",
                background = Style.Background({ alpha = 0.7 }),
                name = Style.Text(12, { shadow = true }),
                layout = { enabled = true, width = 220, height = 22, spacing = 2, wrap = "DOWN", iconSide = "LEFT",
                    reverse = false, keepInPlace = false },
            }),
            custom1 = custom(1), custom2 = custom(2), custom3 = custom(3),
        },
        fade = { enabled = false, alpha = 0.35 },
        reminders = {
            enabled = true, instancesOnly = true, flask = true, food = true, rune = false, oil = true, raidBuff = true,
            pet = true, healthstone = true, readyMana = true, manaPercent = 90, sound = "",
            size = 36, point = "TOP", x = 0, y = -180,
        },
    },
})

M.VIEWERS = {
    { key = "essential", frame = "EssentialCooldownViewer" },
    { key = "utility", frame = "UtilityCooldownViewer" },
    { key = "buffs", frame = "BuffIconCooldownViewer" },
    { key = "bars", frame = "BuffBarCooldownViewer", bars = true },
    { key = "custom1", custom = true }, { key = "custom2", custom = true }, { key = "custom3", custom = true },
}
M.KIND = {}
for _, def in ipairs(M.VIEWERS) do M.KIND[def.key] = def end

function M:Viewer(key) return self.db.viewers[key] or self.db.viewers.essential end
function M.IsCustom(key) return M.KIND[key] ~= nil and M.KIND[key].custom == true end
function M.IsBars(key) return key == "bars" end

---------------------------------------------------------------- pure helpers (smoke-tested)
local VERTICAL = { UP = true, DOWN = true }
local CROSS = { RIGHT = "DOWN", LEFT = "DOWN", UP = "RIGHT", DOWN = "RIGHT" }

-- The wrap direction must run across the icon direction; a parallel one falls back to down / right.
function M.WrapFor(growth, wrap)
    if VERTICAL[growth] == VERTICAL[wrap] then return CROSS[growth] or "DOWN" end
    return wrap
end

local function rowSizes(L, nRows)
    local sizes = {}
    for r = 1, nRows do sizes[r] = math.max(8, L.size + (r > 1 and (L.rowDelta or 0) or 0)) end
    return sizes
end

--[[ Positions of n icons on a grid: perRow icons along `growth`, then the next row along `wrap`; rows after the
    first can be bigger or smaller (rowDelta); short rows centre when `center` is on. `overflow` "row" lets rows
    run past `rows`; otherwise icons past perRow x rows are left over (returned as the 4th value).
    Returns { {x, y, size} … } from the grid's top-left (y grows downwards), width, height, leftover. ]]
function M.Grid(n, L)
    local per = math.max(1, math.floor(L.perRow or 1))
    local cap = L.overflow == "row" and n or math.min(n, per * math.max(1, math.floor(L.rows or 1)))
    local nRows = math.ceil(cap / per)
    local sizes, sp = rowSizes(L, nRows), L.spacing or 0
    local growth = L.growth or "RIGHT"
    local wrap = M.WrapFor(growth, L.wrap or "DOWN")
    local lens, widest, cross = {}, 0, {}
    local crossTotal = 0
    for r = 1, nRows do
        local count = math.min(per, cap - (r - 1) * per)
        lens[r] = count * sizes[r] + (count - 1) * sp
        widest = math.max(widest, lens[r])
        cross[r] = crossTotal
        crossTotal = crossTotal + sizes[r] + (r < nRows and sp or 0)
    end
    local out = {}
    for i = 1, cap do
        local r = math.ceil(i / per)
        local c, s = i - (r - 1) * per, sizes[r]
        local main = (c - 1) * (s + sp) + (L.center and (widest - lens[r]) / 2 or 0)
        if growth == "LEFT" or growth == "UP" then main = widest - main - s end
        local across = cross[r]
        if wrap == "UP" or wrap == "LEFT" then across = crossTotal - across - s end
        if VERTICAL[growth] then out[i] = { x = across, y = main, size = s }
        else out[i] = { x = main, y = across, size = s } end
    end
    local w, h = widest, crossTotal
    if VERTICAL[growth] then w, h = crossTotal, widest end
    return out, math.max(w, 1), math.max(h, 1), n - cap
end

-- Bars stacked along wrap (DOWN / UP): y offsets from the top, total height.
function M.Stack(n, L)
    local out, step = {}, L.height + L.spacing
    local total = math.max(1, n * step - L.spacing)
    for i = 1, n do
        local y = (i - 1) * step
        if L.wrap == "UP" then y = total - y - L.height end
        out[i] = y
    end
    return out, total
end

--[[ A custom bar's list: spell IDs, spell names, "item:ID", "trinket1" / "trinket2", separated by commas,
    semicolons or new lines. Returns { { kind = "spell" | "item" | "slot", id = … }, … }; unknown names stay
    as { kind = "name", name = … } for the caller to resolve in game. ]]
function M.ParseList(str)
    local out = {}
    for part in tostring(str or ""):gmatch("[^,;\n]+") do
        part = part:gsub("^%s+", ""):gsub("%s+$", "")
        local lower = part:lower()
        local item = lower:match("^item:(%d+)$")
        local slot = lower:match("^trinket([12])$")
        if item then out[#out + 1] = { kind = "item", id = tonumber(item) }
        elseif slot then out[#out + 1] = { kind = "slot", id = 12 + tonumber(slot) }
        elseif part:match("^%d+$") then out[#out + 1] = { kind = "spell", id = tonumber(part) }
        elseif part ~= "" then out[#out + 1] = { kind = "name", name = part } end
    end
    return out
end

-- Is a viewer shown for this specialization index (1-4)? An unknown spec shows everything.
function M.SpecAllowed(vis, spec)
    if type(spec) ~= "number" or spec < 1 or spec > 4 then return true end
    return vis["spec" .. spec] ~= false
end

--[[ Visibility rules as one pure decision: mode "always" | "combat" | "target" | "combatOrTarget" | "never",
    plus hide while mounted / in a vehicle and the spec filter. state = { combat, target, mounted, vehicle, spec }. ]]
function M.Visible(vis, state)
    if vis.mode == "never" then return false end
    if not M.SpecAllowed(vis, state.spec) then return false end
    if vis.mounted and state.mounted then return false end
    if vis.vehicle and state.vehicle then return false end
    if vis.mode == "combat" then return state.combat == true end
    if vis.mode == "target" then return state.target == true end
    if vis.mode == "combatOrTarget" then return state.combat == true or state.target == true end
    return true
end

local function plainTrue(v) return not Secret.IsSecret(v) and v and true or false end

function M:State()
    local api = C_SpecializationInfo
    local spec = api and api.GetSpecialization and api.GetSpecialization()
    return {
        combat = plainTrue(InCombatLockdown()) or plainTrue(UnitAffectingCombat("player")),
        target = plainTrue(UnitExists("target")),
        mounted = plainTrue(IsMounted()),
        vehicle = plainTrue(UnitInVehicle("player")) or plainTrue(C_ActionBar.HasVehicleActionBar()),
        spec = not Secret.IsSecret(spec) and spec or nil,
    }
end

-- Final opacity of a viewer: its visibility rules, then the out-of-combat fade.
function M:AlphaFor(key, state)
    state = state or self:State()
    if not self:IsEnabled() then return 1 end
    if not M.Visible(self:Viewer(key).visibility, state) then return 0 end
    if self.db.fade.enabled and not state.combat then return self.db.fade.alpha end
    return 1
end

-- Is Blizzard's Cooldown Manager running on this client and character (WoW Forever has it too; low levels may not)?
function M.ViewerAvailable()
    local api = C_CooldownViewer
    if not (api and api.IsCooldownViewerAvailable) then return false end
    local ok, yes = pcall(api.IsCooldownViewerAvailable)
    return ok and yes == true
end

---------------------------------------------------------------- lifecycle
local function onState()
    if M:IsEnabled() then M:ApplyVisibility() end
end

-- One handler per event and owner in ns.Events, so the four files share a small fan-out: M:On(event, fn).
local handlers = {}
local function fan(_, event, ...)
    for _, fn in ipairs(handlers[event] or {}) do ns.SafeCall(fn, M, event, ...) end
end
function M:On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        ns.Events:On(event, self, fan)
    end
    list[#list + 1] = fn
end

function M:OnEnable()
    wipe(handlers)
    self:EnableViewers() -- Viewers.lua
    self:EnableCustom()  -- Custom.lua
    self:EnableReminders() -- Reminders.lua
    for _, ev in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
        "PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_SPECIALIZATION_CHANGED" }) do
        self:On(ev, onState)
    end
    self:On("PLAYER_REGEN_DISABLED", function()
        if M.testShown then M:ShowTest(false) end
        onState()
    end)
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
    self:Refresh()
end

function M:OnDisable()
    self:ShowTest(false)
    self:DisableViewers()
    self:DisableCustom()
    self:DisableReminders()
end

function M:Refresh()
    self:RefreshViewers()
    self:RefreshCustom()
    self:RefreshReminders()
    self:ApplyVisibility()
    if self.testShown then self:DrawTest() end
end

function M:OnSettingChanged() self:Refresh() end

function M:ApplyVisibility()
    local state = self:State()
    self:ApplyViewerAlpha(state)
    self:ApplyCustomAlpha(state)
end

-- Test: sample icons and bars where every viewer, custom bar and the reminders sit (out of combat only).
function M:ShowTest(show)
    if show and InCombatLockdown() then return false end
    self.testShown = show and true or nil
    if show then self:DrawTest() else self:HideTest() end
    return true
end
