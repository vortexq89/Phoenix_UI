local _, ns = ...
local Style = ns.Style

--[[ ActionBars v2 (plan v2 S7): Phoenix-owned action bars with a Blizzard fallback.

    mode "phoenix"   Blizzard's own action buttons (ActionButton1-12, MultiBar*Button1-12, PetActionButton1-10,
                     StanceButton1-10) are re-parented into Phoenix bar headers (SecureHandlerStateTemplate,
                     Bars.lua). Phoenix owns their layout, paging, visibility and fading; keybinds, macros and
                     Blizzard's own button code keep working because the buttons stay Blizzard's. Blizzard's bar
                     frames are parked in a hidden frame. Every protected change runs out of combat (ns.Combat:Run).
    mode "blizzard"  Edit Mode keeps the bars; Phoenix only dresses the buttons (the 2.0 behaviour).

    Buttons.lua dresses buttons in both modes (art, shape, feedback tints, proc and assist glows, cooldown
    swipe, texts). Extras.lua owns the extra action / zone ability skin, the vehicle exit button, the micro menu
    and bag bar modes and the extra item bar. Layout, state-driver strings and fading are pure functions here so
    the options preview and the smoke test use exactly what the game uses. Switching mode needs a reload: buttons
    that were re-parented are only handed back by a fresh UI. ]]

-- One bar's saved shape. Positions are UIParent offsets from `point` (Layout mode writes them too).
local function bar(point, x, y, extra)
    local b = {
        enabled = true, buttons = 12, rows = 1, width = 40, height = 40, square = true,
        spacingX = 2, spacingY = 2, grow = "RIGHT", wrap = "DOWN", order = "normal",
        showEmpty = false, clickThrough = false,
        point = point, x = x, y = y, strata = "MEDIUM", scale = 1,
        backdrop = { show = false, alpha = 0.5, color = false, style = "solid", padding = 3 },
        border = Style.Border({ style = "none" }),
        vis = { combat = true, ooc = true, fade = false, oocAlpha = 0.4, mouseover = false, hideVehicle = true,
                macro = "", drag = true, spellbook = true, linked = false, alpha = 1 },
    }
    for k, v in pairs(extra or {}) do b[k] = v end
    return b
end

local function vertical(extra)
    local t = { grow = "DOWN", wrap = "LEFT" }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end

local DEFAULTS = {
    mode = "phoenix",
    bars = {
        bar1 = bar("BOTTOM", 0, 26),
        bar2 = bar("BOTTOM", 0, 70),
        bar3 = bar("BOTTOM", 0, 114),
        bar4 = bar("RIGHT", -6, 0, vertical()),
        bar5 = bar("RIGHT", -50, 0, vertical()),
        -- off by default; when switched on they open on the left edge and right of bar 5, clear of everything
        bar6 = bar("LEFT", 6, 0, vertical({ enabled = false, wrap = "RIGHT" })),
        bar7 = bar("LEFT", 50, 0, vertical({ enabled = false, wrap = "RIGHT" })),
        bar8 = bar("RIGHT", -94, 0, vertical({ enabled = false })),
        pet = bar("BOTTOM", 0, 158, { buttons = 10, width = 32, height = 32 }),
        -- above the pet bar: clear of the player and target frames on a 768 px high UI (pixel-perfect scale)
        stance = bar("BOTTOM", 0, 194, { buttons = 10, width = 32, height = 32 }),
        items = bar("CENTER", 0, -220, { enabled = false, width = 36, height = 36 }),
    },
    -- bar 1 only: what switches its page
    paging = { forms = true, sky = true, possess = true, shift = 0, ctrl = 0, alt = 0, arrows = false },
    -- buttons (every bar)
    style = true, shape = "square", iconZoom = 0.08,
    border = Style.Border({ style = "shadow" }),
    desatCooldown = false, cooldownAlpha = 1, emptyAlpha = 0.4, equippedBorder = true, qualityBorder = false,
    -- feedback
    rangeTint = true, rangeColor = false,
    feedback = {
        power = true, powerColor = false, unusable = true, unusableColor = false, target = "icon",
        pushed = "accent", highlight = "accent", checked = "accent",
        proc = "blizzard", procColor = false, assist = "blizzard", hideCast = false,
        swipeAlpha = 0.8, bling = false, gcd = true, hideTooltips = "never",
    },
    -- text
    hotkeys = true, shortHotkeys = true, macroText = false,
    hotkey = Style.Text(12, { outline = "OUTLINE", shadow = false, anchor = "TOPRIGHT", x = -1, y = -3 }),
    count = Style.Text(13, { outline = "OUTLINE", shadow = false, anchor = "BOTTOMRIGHT", x = -1, y = 3 }),
    macro = Style.Text(10, { outline = "OUTLINE", shadow = false, anchor = "BOTTOM", y = 3 }),
    cooldown = { size = 0, charges = false },
    -- extra bars
    extra = { skin = true, scale = 1, hideArt = false },
    vehicle = { enabled = true, size = 36 },
    micro = "bar", bags = "bar",
    ring = { enabled = false, key = "", list = "", size = 40, radius = 90 }, -- quick ring (Ring.lua)
    items = { quest = true, list = "", hotkey = "" }, -- hotkey: uses the first item (e.g. "SHIFT-E")
}

local M = ns:NewModule("ActionBars", {
    label = "ACTIONBARS", desc = "ACTIONBARS_DESC", category = "interface", order = 10, reloadOnToggle = true,
    defaults = DEFAULTS,
})

-- The bars Phoenix can own. page: the fixed action page of a multi bar (Blizzard_ActionBar
-- MultiActionBars.xml `actionpage`); bar 1 pages through its state driver instead.
M.BARS = {
    { key = "bar1", label = "AB_BAR1", blizzard = "MainActionBar", prefix = "ActionButton", count = 12 },
    { key = "bar2", label = "AB_BAR2", blizzard = "MultiBarBottomLeft", prefix = "MultiBarBottomLeftButton", count = 12, page = 6 },
    { key = "bar3", label = "AB_BAR3", blizzard = "MultiBarBottomRight", prefix = "MultiBarBottomRightButton", count = 12, page = 5 },
    { key = "bar4", label = "AB_BAR4", blizzard = "MultiBarRight", prefix = "MultiBarRightButton", count = 12, page = 3 },
    { key = "bar5", label = "AB_BAR5", blizzard = "MultiBarLeft", prefix = "MultiBarLeftButton", count = 12, page = 4 },
    { key = "bar6", label = "AB_BAR6", blizzard = "MultiBar5", prefix = "MultiBar5Button", count = 12, page = 13 },
    { key = "bar7", label = "AB_BAR7", blizzard = "MultiBar6", prefix = "MultiBar6Button", count = 12, page = 14 },
    { key = "bar8", label = "AB_BAR8", blizzard = "MultiBar7", prefix = "MultiBar7Button", count = 12, page = 15 },
    { key = "pet", label = "AB_PET", blizzard = "PetActionBar", prefix = "PetActionButton", count = 10, kind = "pet" },
    { key = "stance", label = "AB_STANCE", blizzard = "StanceBar", prefix = "StanceButton", count = 10, kind = "stance" },
    { key = "items", label = "AB_ITEMS", count = 12, kind = "items" },
}
M.BAR_BY_KEY = {}
for _, def in ipairs(M.BARS) do M.BAR_BY_KEY[def.key] = def end
M.DEFAULTS = DEFAULTS

function M:IsPhoenix() return self.db.mode == "phoenix" end
function M:Bar(key) return self.db.bars[key] end

---------------------------------------------------------------- layout (pure; shared with the preview)
local HORIZONTAL = { RIGHT = true, LEFT = true }

-- The wrap direction must cross the grow direction; anything else falls back to Blizzard's usual choice.
local function wrapOf(b)
    if HORIZONTAL[b.grow] then return (b.wrap == "UP" or b.wrap == "DOWN") and b.wrap or "DOWN" end
    return (b.wrap == "LEFT" or b.wrap == "RIGHT") and b.wrap or "RIGHT"
end

--[[ Button offsets for n buttons of bar spec b, from the bar's TOPLEFT (x right, y down, before padding):
    returns { { x, y }, ... }, width, height, buttonWidth, buttonHeight. `rows` is the number of lines: buttons
    fill a line along `grow`, lines stack along `wrap`; "reversed" fills from the last slot. ]]
function M.Layout(b, n)
    n = math.max(0, math.min(n or b.buttons, b.buttons))
    local w = b.width
    local h = b.square and b.width or b.height
    local sx, sy = b.spacingX, b.spacingY
    local lines = math.max(1, math.min(b.rows, math.max(n, 1)))
    local per = math.max(1, math.ceil(n / lines))
    lines = math.max(1, math.ceil(n / per))
    local horizontal = HORIZONTAL[b.grow] ~= nil
    local wrap = wrapOf(b)
    local cols, rowsN = per, lines
    if not horizontal then cols, rowsN = lines, per end
    local W = cols * w + (cols - 1) * sx
    local H = rowsN * h + (rowsN - 1) * sy
    local out = {}
    for i = 1, n do
        local idx = (b.order == "reversed") and (n - i) or (i - 1)
        local along, line = idx % per, math.floor(idx / per)
        local col, row
        if horizontal then
            col = (b.grow == "RIGHT") and along or (cols - 1 - along)
            row = (wrap == "DOWN") and line or (rowsN - 1 - line)
        else
            row = (b.grow == "DOWN") and along or (rowsN - 1 - along)
            col = (wrap == "RIGHT") and line or (cols - 1 - line)
        end
        out[i] = { col * (w + sx), row * (h + sy) }
    end
    return out, math.max(W, 0), math.max(H, 0), w, h
end

---------------------------------------------------------------- state drivers (pure)
--[[ Visibility macro for a bar (RegisterStateDriver "visibility"). Pet battles always hide the bars (Blizzard
    hides its own there); vehicles hide them unless the bar opts out; a custom macro replaces the combat rules. ]]
function M.VisibilityDriver(b, kind)
    local vis = b.vis
    local parts = { "[petbattle] hide" }
    -- Blizzard's own override bar (vehicles, possession, some quests) takes over while it is up
    if vis.hideVehicle then parts[#parts + 1] = "[vehicleui] hide"; parts[#parts + 1] = "[overridebar] hide" end
    if kind == "pet" then parts[#parts + 1] = "[nopet] hide" end
    local custom = vis.macro and vis.macro:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if custom ~= "" then
        parts[#parts + 1] = custom
    elseif vis.combat and vis.ooc then
        parts[#parts + 1] = "show"
    elseif vis.combat then
        parts[#parts + 1] = "[combat] show"; parts[#parts + 1] = "hide"
    elseif vis.ooc then
        parts[#parts + 1] = "[combat] hide"; parts[#parts + 1] = "show"
    else
        parts[#parts + 1] = "hide"
    end
    return table.concat(parts, "; ")
end

--[[ Page macro for bar 1. Every state names how the restricted snippet (Bars.lua PAGE_SNIPPET) finds the page,
    in Blizzard's own order (ActionBarController_UpdateAll): vehicle, override, possess, temporary shapeshift,
    then the player's choices (modifier pages, manual pages), then skyriding and form bonus bars, then page 1.
    Manual pages come before bonus bars so a druid on page 2 stays on page 2 in cat form, as in Blizzard's UI.
    States are unique per condition so changing form always re-runs the snippet. ]]
function M.PageDriver(p, sky)
    local parts = {}
    if p.possess then
        parts[#parts + 1] = "[vehicleui] vehicle"
        parts[#parts + 1] = "[overridebar] override"
        parts[#parts + 1] = "[possessbar] possess"
        parts[#parts + 1] = "[shapeshift] temp"
    end
    for _, mod in ipairs({ "shift", "ctrl", "alt" }) do
        local page = tonumber(p[mod]) or 0
        if page >= 1 and page <= 6 then parts[#parts + 1] = ("[mod:%s] %d"):format(mod, page) end
    end
    for page = 2, 6 do parts[#parts + 1] = ("[bar:%d] p%d"):format(page, page) end
    if p.sky and sky ~= false then parts[#parts + 1] = "[bonusbar:5] b5" end
    if p.forms then
        for i = 1, 4 do parts[#parts + 1] = ("[bonusbar:%d] b%d"):format(i, i) end
    end
    parts[#parts + 1] = "p1"
    return table.concat(parts, "; ")
end

--[[ Alpha a bar should have. s = { combat, hover, reveal }: reveal (dragging a spell, spellbook open) and hover
    show the bar fully; mouseover bars are invisible otherwise; faded bars dim out of combat. ]]
function M.TargetAlpha(vis, s)
    local a = vis.alpha
    if s.reveal or s.hover then return a end
    -- linked bars are one mouseover group: hidden until any bar of the group is hovered (with fade on they
    -- fade instead of hiding)
    if vis.mouseover or (vis.linked and not vis.fade) then return 0 end
    if vis.fade and not s.combat then return a * vis.oocAlpha end
    return a
end

---------------------------------------------------------------- short key labels (pure)
-- "SHIFT-BUTTON4" -> "S-M4". Works on the binding key, not the localised text, so it is the same in every locale.
local KEY_SHORT = {
    BUTTON1 = "LM", BUTTON2 = "RM", BUTTON3 = "M3", MOUSEWHEELUP = "WU", MOUSEWHEELDOWN = "WD",
    SPACE = "Sp", BACKSPACE = "Bs", ESCAPE = "Esc", ENTER = "Ent", TAB = "Tab", CAPSLOCK = "Cap",
    INSERT = "Ins", DELETE = "Del", HOME = "Hm", END = "End", PAGEUP = "PU", PAGEDOWN = "PD",
    UP = "Up", DOWN = "Dn", LEFT = "Lt", RIGHT = "Rt", NUMLOCK = "NL", PRINTSCREEN = "Prt",
    NUMPADPLUS = "N+", NUMPADMINUS = "N-", NUMPADMULTIPLY = "N*", NUMPADDIVIDE = "N/", NUMPADDECIMAL = "N.",
}
local MOD_SHORT = { SHIFT = "S", CTRL = "C", ALT = "A", META = "M" }

function M.ShortKey(key)
    if type(key) ~= "string" or key == "" then return nil end
    local mods, base = {}, key
    while true do
        local mod, rest = base:match("^(%u+)%-(.+)$")
        if not mod or not MOD_SHORT[mod] then break end
        mods[#mods + 1] = MOD_SHORT[mod]
        base = rest
    end
    local short = KEY_SHORT[base]
    if not short then
        local n = base:match("^BUTTON(%d+)$")
        local pad = base:match("^NUMPAD(%d)$")
        if n then short = "M" .. n elseif pad then short = "N" .. pad else short = base end
    end
    mods[#mods + 1] = short
    return table.concat(mods, "-")
end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    self:EnableButtons()                 -- Buttons.lua (both modes)
    if self:IsPhoenix() then self:EnableBars() end -- Bars.lua
    self:EnableExtras()                  -- Extras.lua
    self:RefreshRing()                   -- Ring.lua
end

function M:OnSettingChanged(path)
    local root, element = path:match("^([^.]+)%.?([^.]*)")
    if root == "bars" and element ~= "" and path == "bars." .. element .. ".point" then self:KeepSpot(element) end
    if root == "bars" and element ~= "" then
        self:RefreshBar(element)
        if element == "items" then self:RefreshItems() end
    elseif root == "paging" then
        self:RefreshPaging()
    elseif root == "extra" or root == "vehicle" or root == "micro" or root == "bags" then
        self:RefreshExtras()
    elseif root == "items" then
        self:RefreshItems()
    elseif root == "ring" then
        self:RefreshRing()
    else
        self:RefreshButtons()
    end
end

-- A new anchor keeps the bar where it is on screen: its offsets are re-derived from where it is now (so an
-- anchor change on several selected bars at once moves none of them).
function M.AnchorOffsets(point, l, r, t, b, sw, sh)
    local function axis(lo, hi, size, wantLo, wantHi)
        if wantLo then return lo, 0 elseif wantHi then return hi, size end
        return (lo + hi) / 2, size / 2
    end
    local px, ux = axis(l, r, sw, point:find("LEFT"), point:find("RIGHT"))
    local py, uy = axis(b, t, sh, point:find("BOTTOM"), point:find("TOP"))
    return math.floor(px - ux + 0.5), math.floor(py - uy + 0.5)
end

function M:KeepSpot(key)
    local h = self.GetHeader and self.GetHeader(key)
    local b = self.db.bars[key]
    if not (h and b and h:IsShown()) then return end
    local l, r, t, bt = h:GetLeft(), h:GetRight(), h:GetTop(), h:GetBottom()
    if not (tonumber(l) and tonumber(r) and tonumber(t) and tonumber(bt)) then return end
    local k = (h:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    b.x, b.y = M.AnchorOffsets(b.point, l * k, r * k, t * k, bt * k, UIParent:GetWidth(), UIParent:GetHeight())
end

function M:Refresh()
    self:RefreshButtons()
    if self:IsPhoenix() then
        for _, def in ipairs(M.BARS) do self:RefreshBar(def.key) end
        self:RefreshPaging()
    end
    self:RefreshExtras()
    self:RefreshItems()
end
