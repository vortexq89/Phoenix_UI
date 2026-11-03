local _, ns = ...
local Style, Secret, Skin = ns.Style, ns.Secret, ns.Skin

--[[ CastBars v2 (plan v2 S9): Phoenix-owned cast bars with a Blizzard fallback.

    mode "phoenix"   Phoenix draws its own bars for the player, target, focus, pet, boss 1-5 and arena 1-5. Target,
                     focus, boss and arena bars sit on the Unit Frames cast bar anchors (S8) when those frames are
                     Phoenix's and the anchor is in use, otherwise they stand alone and move in Layout mode. The
                     player bar replaces Blizzard's (Edit Mode's) bar, which is parked: events off, hidden.
    mode "blizzard"  Blizzard keeps its bars; Phoenix only dresses them (Blizzard.lua, the 2.0 behaviour).

    Files: CastBars.lua (saved shape, colours, pure helpers shared with the preview and the smoke test), Bar.lua (one
    bar's widgets and layout; the preview builds the very same bar), Update.lua (cast events, secret-safe drawing,
    sample casts), Spawn.lua (bars per unit, anchoring, Blizzard parking, GCD and swing bars, Test casts, movers).

    Secret values (12.x): cast names, icons, times, the interrupt flag and spell IDs can be secret for other units.
    We never compare, add or test one. "Is something cast?" is read from the NeverSecret fields (isTradeskill,
    castBarID); progress is a duration object (UnitCastingDuration / UnitChannelDuration /
    UnitEmpoweredChannelDuration) given to StatusBar:SetTimerDuration; the timer text is a DurationTextBinding when
    the duration is secret; the interrupt flag only reaches Texture:SetVertexColorFromBoolean and
    Region:SetAlphaFromBoolean; the kick-ready tick is a StatusBar fed two secret remaining times. Numbers we must do
    sums with (latency zone, channel ticks, empower stages) are the player's own and pass `plain()` first. ]]

local KEYS = { "player", "target", "focus", "pet", "boss", "arena" }
local COUNT = { boss = 5, arena = 5 }
local TOKENS = {}
for _, key in ipairs(KEYS) do
    if COUNT[key] then
        TOKENS[key] = {}
        for i = 1, COUNT[key] do TOKENS[key][i] = key .. i end
    else
        TOKENS[key] = { key }
    end
end
-- bars that can sit on a Unit Frames cast bar anchor (the S8 hook-up point)
local ATTACHABLE = { target = true, focus = true, boss = true, arena = true }

local function bar(o)
    return {
        enabled = o.enabled ~= false, attach = o.attach or "free",
        width = o.w, height = o.h, point = o.point or "CENTER", x = o.x, y = o.y,
        strata = "MEDIUM", scale = 1, spacing = o.spacing or 46, growth = "DOWN",
        -- look (texture / border / background / text / time / colors are the 2.0 keys, Blizzard mode reads them too)
        texture = "", reverse = false, smooth = false, gradient = 0.25, classColor = false,
        colors = { cast = false, channel = false, locked = false, notReady = false, interrupted = false, success = false,
                   important = false },
        background = Style.Background({ alpha = 0.85 }),
        border = Style.Border({ style = "pixel" }),
        spark = true, sparkColor = false,
        icon = o.noIcon and "off" or "left", iconZoom = 0.08, iconDetached = false, iconSize = 28, iconGap = 4, shield = true,
        text = Style.Text(o.text or 11, { anchor = "LEFT", outline = "OUTLINE", shadow = false }),
        time = Style.Text(o.text or 11, { anchor = "RIGHT", outline = "OUTLINE", shadow = false }),
        target = Style.Text((o.text or 11) - 1, { anchor = "BOTTOMRIGHT", outline = "OUTLINE", shadow = false, y = -12,
                                                 show = o.spellTarget or false }),
        timeFormat = o.timeFormat or "remaining", decimals = 1, nameLength = 0,
        hold = 0.5, flash = true, important = o.important or false, targeted = o.targeted or false,
        importantFill = o.importantFill or false, kick = o.kick or false,
        importantAnnounce = false, -- important casts also on the Encounters warning banner (Update.lua)
    }
end

local DEFAULTS = {
    mode = "phoenix",
    bars = {
        player = bar({ w = 260, h = 22, point = "BOTTOM", x = 0, y = 230, text = 12 }),
        target = bar({ attach = "frame", w = 236, h = 18, x = 290, y = -246, kick = true, important = true, targeted = true,
                       spellTarget = true }),
        focus = bar({ attach = "frame", w = 180, h = 16, x = -470, y = -6, kick = true, important = true }),
        pet = bar({ w = 120, h = 12, x = -350, y = -262, noIcon = true, text = 9 }),
        boss = bar({ attach = "frame", w = 200, h = 16, point = "RIGHT", x = -260, y = 178, kick = true, important = true,
                     targeted = true }),
        arena = bar({ attach = "frame", w = 200, h = 16, point = "RIGHT", x = -260, y = 78, kick = true, important = true,
                      targeted = true }),
        -- casts aimed at you from enemy nameplates (OnMe.lua); not one of KEYS
        onme = bar({ enabled = false, w = 220, h = 16, point = "CENTER", x = 0, y = 170, spacing = 20, kick = true,
                     important = true }),
    },
    -- player extras
    latency = true, ticks = true, customTicks = "", empower = true,
    gcd = { enabled = false, height = 4, gap = 2, attach = "castbar", width = 260, point = "BOTTOM", x = 0, y = 214 },
    swing = { enabled = false, width = 260, height = 8, point = "BOTTOM", x = 0, y = 200, offhand = true, labels = false,
              rangeCue = false,
              text = Style.Text(9, { anchor = "RIGHT", outline = "OUTLINE", shadow = false }) },
    colors = { latency = false, tick = false, stage = false, kick = false, gcd = false, swing = false, glow = false },
    -- Blizzard mode (Blizzard.lua): the 2.0 skin of Blizzard's own bars
    style = true, icon = true, timer = true, classColor = false, iconZoom = 0.08,
}
local M = ns:NewModule("CastBars", {
    label = "CASTBARS", desc = "CASTBARS_DESC", category = "interface", order = 40, reloadOnToggle = true,
    defaults = DEFAULTS,
})
DEFAULTS.bars.onme.count = 4
M.KEYS, M.COUNT, M.TOKENS, M.ATTACHABLE, M.DEFAULTS = KEYS, COUNT, TOKENS, ATTACHABLE, DEFAULTS
-- The settings shape of one bar; other modules that draw bars with this engine (nameplates, S10) build theirs with it.
M.NewBarSettings = bar
--[[ Settings sources: key -> function(key) returning a bar's settings table. A module that draws its own bars with
    this engine registers its keys here (NamePlates: "plate.enemy", "plate.friendly"), so BuildBar / LayoutBar /
    ShowCast / the sample casts read its settings without a copy of the drawing code. ]]
M.SOURCES = {}

local function plain(v) return not Secret.IsSecret(v) end
M.plain = plain

function M:IsPhoenix() return self.db.mode == "phoenix" end
function M:Bar(key)
    local source = M.SOURCES[key]
    if source then return source(key) end
    return self.db.bars[key] or self.db.bars.player
end
-- The settings key of a unit token: boss3 -> boss
function M.KeyOf(token)
    if type(token) ~= "string" then return nil end
    local base = token:match("^(%a+)%d$")
    if base and COUNT[base] then return base end
    return TOKENS[token] and token or nil
end

-- True when Phoenix draws this unit's cast bar (Unit Frames then stops lending Blizzard's bar to its anchor).
function M:Owns(key)
    return self:IsEnabled() and self:IsPhoenix() and self:Bar(key).enabled and true or false
end

---------------------------------------------------------------- colours
local TOKEN = {
    cast = "accent.primary", channel = "state.info", locked = "text.muted", notReady = "state.warning",
    interrupted = "state.danger", success = "state.success",
    latency = "state.danger", tick = "text.primary", stage = "text.primary", kick = "state.success",
    gcd = "text.secondary", swing = "accent.primary", glow = "state.warning", important = "state.warning",
}
M.COLOR_TOKENS = TOKEN

-- A bar's colour for a state: cast | channel | locked | notReady | interrupted | success | important (r, g, b, a).
function M:StateColor(key, state)
    local b = self:Bar(key)
    if (state == "cast" or state == "channel") and b.classColor then
        local _, classFile = UnitClass("player")
        if key == "player" or key == "pet" then return ns.Util.ClassColor(classFile) end
    end
    return Skin:SpecColor(b.colors[state], TOKEN[state] or "accent.primary")
end

-- The module-wide colours (latency, tick, stage, kick, gcd, swing, glow).
function M:Color(which)
    return Skin:SpecColor(self.db.colors[which], TOKEN[which])
end

-- A ColorMixin for the *FromBoolean APIs.
function M:StateColorObject(key, state)
    return CreateColor(self:StateColor(key, state))
end

---------------------------------------------------------------- pure helpers (preview, test casts, smoke test)
-- The remaining/elapsed/total text a format gives for plain numbers (seconds).
local FORMATS = {
    remaining = function(f, r) return f:format(r) end,
    elapsed = function(f, _, e) return f:format(e) end,
    both = function(f, r, _, t) return (f .. " / " .. f):format(r, t) end,
    elapsedTotal = function(f, _, e, t) return (f .. " / " .. f):format(e, t) end,
    none = function() return "" end,
}
M.TIME_FORMATS = { "remaining", "elapsed", "both", "elapsedTotal", "none" }
function M.FormatTime(kind, decimals, remaining, total)
    decimals = math.max(0, math.min(2, tonumber(decimals) or 1))
    remaining = math.max(0, remaining or 0)
    total = math.max(remaining, total or remaining)
    local fn = FORMATS[kind] or FORMATS.remaining
    return fn("%." .. decimals .. "f", remaining, total - remaining, total)
end

-- "1234:5, 5678:3" -> { [1234] = 5, [5678] = 3 } (user channel tick counts; junk is skipped)
function M.ParseTicks(str)
    local out = {}
    if type(str) ~= "string" then return out end
    for id, n in str:gmatch("(%d+)%s*[:=]%s*(%d+)") do
        id, n = tonumber(id), tonumber(n)
        if id and n and n >= 1 and n <= 30 then out[id] = n end
    end
    return out
end

-- Built-in channel tick counts (base, before talents); the custom list overrides or extends them. Each game has
-- its own spell table (Forever: rank 1 IDs).
local TICKS = ns.flavor == "forever" and {
    [15407] = 3, [689] = 5, [1120] = 5, -- spellIDs(forever): Mind Flay, Drain Life, Drain Soul
    [5143] = 3, [10] = 8, [12051] = 4, -- spellIDs(forever): Arcane Missiles, Blizzard, Evocation
} or {
    [15407] = 6, [47540] = 3, [234153] = 5, -- spellIDs(retail): Mind Flay, Penance, Drain Life
    [5143] = 5, [257044] = 7, [356995] = 4, -- spellIDs(retail): Arcane Missiles, Rapid Fire, Disintegrate
    [113656] = 5, [117952] = 4, -- spellIDs(retail): Fists of Fury, Crackling Jade Lightning
    [115175] = 8, [755] = 5, -- spellIDs(retail): Soothing Mist, Health Funnel
}
M.TICKS = TICKS
local custom, customSource
function M:TickCount(spellID)
    if not plain(spellID) or type(spellID) ~= "number" then return nil end
    if customSource ~= self.db.customTicks then customSource = self.db.customTicks; custom = M.ParseTicks(customSource) end
    return custom[spellID] or TICKS[spellID]
end

-- x offsets (from the bar's start) of the n-1 lines between n channel ticks across width w.
function M.TickOffsets(n, w)
    local out = {}
    if not n or n < 2 then return out end
    for i = 1, n - 1 do out[i] = math.floor(w * i / n + 0.5) end
    return out
end

-- x offsets of empower stage marks from the stage percentages (each the share of the whole channel).
function M.StageOffsets(percentages, w)
    local out, sum = {}, 0
    if type(percentages) ~= "table" then return out end
    for i = 1, #percentages - 1 do
        local p = percentages[i]
        if not plain(p) or type(p) ~= "number" then return {} end
        sum = sum + p
        out[i] = math.floor(w * math.min(1, sum) + 0.5)
    end
    return out
end

-- The share of a cast the latency zone covers (0..1), from the world latency (ms) and the cast's length (s).
function M.LatencyShare(lagMs, total)
    if type(lagMs) ~= "number" or type(total) ~= "number" or total <= 0 then return 0 end
    return math.max(0, math.min(1, lagMs / 1000 / total))
end

-- A spell name cut to n characters (0 = whole). Only plain names are cut; a secret name passes through.
function M.CutName(name, n)
    if not n or n <= 0 or not plain(name) or type(name) ~= "string" then return name end
    local len = strlenutf8 and strlenutf8(name)
    if type(len) == "number" and len <= n then return name end
    local out, count = {}, 0
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > n then out[#out + 1] = "…"; break end
        out[#out + 1] = ch
    end
    return table.concat(out)
end

--[[ Where a bar's parts go inside its box (w x h, x right, y down): { bar = {x, y, w, h}, icon = {x, y, size}|nil }.
    The icon takes a square at one side ("left"/"right") of the box's height, or, detached, hangs outside the box
    at its own size. ]]
function M.Geometry(b, w, h)
    local g = { bar = { 0, 0, w, h } }
    if b.icon == "off" then return g end
    if b.iconDetached then
        local s = b.iconSize
        local gap = b.iconGap
        g.icon = { b.icon == "right" and (w + gap) or (-s - gap), (h - s) / 2, s }
        return g
    end
    local s = h
    if b.icon == "right" then
        g.icon = { w - s, 0, s }
        g.bar = { 0, 0, w - s - b.iconGap, h }
    else
        g.icon = { 0, 0, s }
        g.bar = { s + b.iconGap, 0, w - s - b.iconGap, h }
    end
    if g.bar[3] < 10 then g.bar[3] = 10 end
    return g
end

---------------------------------------------------------------- interrupts (kick-ready tick, "not ready" colour)
-- The player's own interrupts, first known wins (C_SpellBook.IsSpellKnown). Each game has its own spell table.
local INTERRUPTS = ns.flavor == "forever" and {
    1766, 6552, 72, 2139, -- spellIDs(forever): Kick, Pummel, Shield Bash, Counterspell
    8042, 15487, 19244, -- spellIDs(forever): Earth Shock, Silence, Spell Lock
} or {
    1766, 6552, 47528, 2139, -- spellIDs(retail): Kick, Pummel, Mind Freeze, Counterspell
    57994, 96231, 106839, 116705, -- spellIDs(retail): Wind Shear, Rebuke, Skull Bash, Spear Hand Strike
    187707, 147362, 183752, 351338, -- spellIDs(retail): Muzzle, Counter Shot, Disrupt, Quell
    78675, 15487, 119910, -- spellIDs(retail): Solar Beam, Silence, Spell Lock
}
M.INTERRUPTS = INTERRUPTS
local kickSpell
function M:KickSpell()
    if kickSpell ~= nil then return kickSpell or nil end
    kickSpell = false
    local known = C_SpellBook and C_SpellBook.IsSpellKnown
    if not known then return nil end
    for _, id in ipairs(INTERRUPTS) do
        local ok, yes = pcall(known, id)
        if ok and plain(yes) and yes then kickSpell = id; break end
    end
    return kickSpell or nil
end
function M:ResetKick() kickSpell = nil end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    if self:IsPhoenix() then
        self:EnablePhoenix()  -- Spawn.lua
    else
        self:EnableBlizzard() -- Blizzard.lua
    end
    ns.Events:Listen("PUI_THEME_CHANGED", self, function() M:Refresh() end)
    ns.Events:On("SPELLS_CHANGED", self, function() M:ResetKick() end)
    ns.Events:On("PLAYER_SPECIALIZATION_CHANGED", self, function() M:ResetKick() end)
end

function M:OnDisable()
    self:ShowTest(false)
end

function M:Refresh()
    if self:IsPhoenix() then self:RefreshPhoenix() else self:RefreshBlizzard() end
    if self.testShown then self:ShowTest(true) end
end

function M:OnSettingChanged() self:Refresh() end

-- Test casts: every enabled Phoenix bar loops a sample cast where it sits (plain data, any time).
function M:ShowTest(show)
    self.testShown = show and true or nil
    if not self:IsPhoenix() then return true end
    return self:ShowPhoenixTest(show) -- Spawn.lua
end
