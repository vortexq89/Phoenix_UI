local _, ns = ...
local Style, Secret = ns.Style, ns.Secret

--[[ UnitFrames v2 (plan v2 S8): Phoenix-owned unit frames with a Blizzard fallback.

    mode "phoenix"   Phoenix builds its own secure unit buttons (SecureUnitButtonTemplate) for the player, target,
                     target of target, focus, focus target, pet, boss 1-5 and (opt-in) arena 1-5, and parks
                     Blizzard's frames in a hidden frame. Left click targets, right click opens the unit menu,
                     Blizzard click bindings and Clique work (ClickCastFrames). Unit Watch shows a frame only while
                     its unit exists; every protected change runs out of combat (ns.Combat:Run).
    mode "blizzard"  Blizzard keeps its frames; Phoenix only dresses them (Blizzard.lua, the 2.0 behaviour).

    Files: UnitFrames.lua (saved shape, tags, colours and geometry: pure functions shared with the preview and
    the smoke test), Build.lua (one frame's widgets and layout; the preview builds the very same frame without the
    secure template), Update.lua (every element's update, fed either by the game or by plain sample data),
    Spawn.lua (secure buttons, Blizzard parking, events, Test frames, Layout-mode movers), Blizzard.lua.

    Secret values (12.x): health, power, absorbs, auras and many unit facts can be secret in combat. They only ever
    reach sinks that accept them (StatusBar:SetValue/SetMinMaxValues, FontString:SetFormattedText,
    Texture:SetSpriteSheetCell, Region:SetAlphaFromBoolean, Cooldown:SetCooldownFromDurationObject), through
    APIs built for them (UnitHealthPercent with a curve, AbbreviateNumbers, C_UnitAuras.Get*). We never compare,
    add or test one; a value we must branch on goes through `plain()` first and falls back when it is secret.
    Switching mode needs a reload: parked Blizzard frames are only handed back by a fresh UI. ]]

local UNITS = { "player", "target", "targettarget", "focus", "focustarget", "pet", "boss", "arena", "arenapet" }
local GROUP = { boss = 5, arena = 5, arenapet = 5 }
local TOKENS = {}
for _, key in ipairs(UNITS) do
    if GROUP[key] then
        TOKENS[key] = {}
        for i = 1, GROUP[key] do TOKENS[key][i] = key .. i end
    else
        TOKENS[key] = { key }
    end
end
-- the frames Blizzard mode dresses (Blizzard.lua); the others only exist as Phoenix frames
local LEGACY = { player = true, target = true, focus = true, pet = true, boss = true }
-- small frames: no castbar anchor, no class power
local SMALL = { targettarget = true, focustarget = true, pet = true, arenapet = true }

local function unit(o)
    local ns_ = o.text or 12
    return {
        enabled = o.enabled ~= false,
        width = o.w, height = o.h, point = o.point or "CENTER", x = o.x, y = o.y,
        strata = "LOW", scale = 1, spacing = 34, growth = "DOWN",
        -- look (texture / border / background are the 2.0 keys, still read by Blizzard mode)
        texture = "", bgTexture = "",
        border = Style.Border({ style = "pixel", color = false }),
        background = Style.Background({ alpha = 0.8 }),
        highlight = true, targetBorder = o.targetBorder or false,
        rangeFade = o.range or false, rangeAlpha = 0.5, rangeSpell = "",
        oocFade = false, oocAlpha = 0.35, oocKeep = true,
        tooltip = "always",
        bar = {
            color = o.color or "class", fixed = false, dark = false, gradient = 0.2, smooth = true,
            reverse = false, vertical = false, bg = "dark", bgAlpha = 0.8, bgColor = false, share = 1,
        },
        absorb = { show = true, style = "striped", alpha = 0.6, position = "attached", healAbsorb = true, prediction = true,
                   overheal = 0 },
        powerBar = {
            show = o.power or "always", height = o.ph or 7, position = "inside", texture = "", smooth = true,
            color = "type", fixed = false, gap = 1, alt = o.alt ~= false, cost = o.cost or false,
            width = 0, direction = "RIGHT", gradient = "none",
        },
        tags = { name = o.nameTag or "[name]", health = o.healthTag or "[health:percent]",
                 power = o.powerTag or "", info = o.infoTag or "" },
        nameLength = o.nameLength or 18, nameColor = o.nameColor or "white", hideFull = false,
        name = Style.Text(ns_, { anchor = "LEFT", outline = "OUTLINE", shadow = false }),
        health = Style.Text(ns_ - 1, { anchor = "RIGHT", outline = "OUTLINE", shadow = false }),
        power = Style.Text(ns_ - 3, { anchor = "RIGHT", outline = "OUTLINE", shadow = false }),
        info = Style.Text(ns_ - 2, { anchor = "TOPLEFT", outline = "OUTLINE", shadow = false, y = 10, show = o.infoTag ~= nil }),
        portrait = o.portrait or "hide",                -- game (2D) | model (3D) | class | hide
        portraitPos = o.portraitPos or "left", portraitShape = "square", portraitZoom = 0.08, portraitAlpha = 1,
        portraitSize = 1, portraitRing = false, portraitArt = false,
        portraitBorder = Style.Border({ style = "pixel" }),
        -- a strip of text under the frame (its own tag string)
        strip = { show = false, height = 14, tag = "[level] [class]", gap = 1,
                  text = Style.Text(ns_ - 2, { anchor = "CENTER", outline = "OUTLINE", shadow = false }) },
        icons = {
            leader = o.leader ~= false, marker = true, pvp = false, markerSize = 16, markerAnchor = "TOP",
            role = o.role or false, combat = o.combat or false, resting = o.resting or false,
            elite = o.elite or false, threat = o.threat or false, ready = o.ready ~= false, size = 14,
        },
        auras = {
            buffs = o.buffs or "off", debuffs = o.debuffs or "off", size = o.auraSize or 20, perRow = 8, max = o.auraMax or 8,
            spacing = 2, growth = "RIGHT", gap = 3, buffFilter = "all", debuffFilter = "all",
            dispel = true, desat = true, zoom = 0.08, swipe = true, tooltips = true,
            border = Style.Border({ style = "pixel" }),
            duration = Style.Text(9, { outline = "OUTLINE", shadow = false, anchor = "CENTER" }),
            count = Style.Text(10, { outline = "OUTLINE", shadow = false, anchor = "BOTTOMRIGHT", x = 1, y = 1 }),
        },
        cast = { attach = o.cast or "none", height = 14, gap = 4 },
        trinket = o.trinket or false, spec = o.spec or false,
    }
end

--[[ Arena extras (S18, sArena parity), only on the arena key: the class icon with its CC / defensive / important
    aura, the trinket and racial, the game's DR tray (restyled), widgets, click actions and the stealth fade. ]]
local function arenaExtras(u)
    u.strip.tag = "[spec]"
    u.layout = "phoenix"
    u.mirrored = false
    u.testCount = 3
    u.stealthAlpha = 0.45
    u.classIcon = true
    u.classIconAuras = true
    u.auraGlow = true
    u.iconZoom = 0.08
    u.racial = true
    u.dr = { show = true, size = 24, spacing = 2, gap = 4, zoom = 0.08, immune = true, mineOnly = false,
             border = Style.Border({ style = "pixel" }),
             text = Style.Text(10, { anchor = "CENTER", outline = "OUTLINE", shadow = false }) }
    u.widgets = { healer = true, focus = true, targets = true }
    u.click = { left = "target", right = "togglemenu", middle = "focus", leftText = "", rightText = "", middleText = "" }
    return u
end

-- Visual defaults: no unit-frame or plate text under 10-11 px (blurry at UI scale < 0.7); small frames 24 px tall.
local DEFAULTS = {
    mode = "phoenix",
    units = {
        player = unit({ w = 236, h = 46, x = -290, y = -190, portrait = "game", text = 13, combat = true, resting = true, cost = true,
                        role = true, infoTag = "[level]", healthTag = "[health:current-percent]", powerTag = "[power:current]" }),
        target = unit({ w = 236, h = 46, x = 290, y = -190, portrait = "game", portraitPos = "right", text = 13, range = true,
                        elite = true, threat = true, cast = "below", buffs = "above", debuffs = "below",
                        infoTag = "[level] [classification]",
                        healthTag = "[health:current-percent]", powerTag = "[power:percent]" }),
        targettarget = unit({ w = 120, h = 24, x = 474, y = -190, text = 11, power = "off", range = true, leader = false,
                              healthTag = "", nameLength = 12 }),
        focus = unit({ w = 180, h = 36, x = -470, y = 40, text = 12, range = true, portrait = "game", cast = "below", debuffs = "below",
                       auraSize = 18, auraMax = 6 }),
        focustarget = unit({ w = 110, h = 24, x = -320, y = 40, text = 11, power = "off", range = true, leader = false,
                             healthTag = "", nameLength = 12 }),
        pet = unit({ w = 120, h = 24, x = -350, y = -232, text = 11, portrait = "game", power = "always", ph = 4, range = true,
                     leader = false,
                     healthTag = "", nameLength = 12, color = "reaction" }),
        boss = unit({ point = "RIGHT", w = 200, h = 40, x = -260, y = 200, text = 12, portrait = "game", portraitPos = "right",
                      color = "reaction", cast = "below",
                      debuffs = "left", auraSize = 22, auraMax = 4, range = true, healthTag = "[health:percent]" }),
        arena = arenaExtras(unit({ enabled = false, point = "RIGHT", w = 200, h = 40, x = -260, y = 100, text = 12, cast = "below",
                       range = true, trinket = true, spec = true, debuffs = "left", auraSize = 22, auraMax = 4,
                       healthTag = "[health:percent]", targetBorder = true })),
        arenapet = unit({ enabled = false, point = "RIGHT", w = 90, h = 18, x = -520, y = 100, text = 11, power = "off",
                          range = true, leader = false, healthTag = "", nameLength = 10, color = "reaction" }),
    },
    -- nicknames: "Name=Nick, Other=Nick2" (plain names only)
    nicknames = "",
    -- modifier-click focus on every Phoenix unit frame, with an optional raid marker
    quickFocus = { key = "none", marker = 0 },
    --[[ Detached player resource bars (S18): health, power (with a druid's mana while shapeshifted), the class
        resource and the spec bar stacked in one movable block; missing ones collapse. ]]
    resources = {
        enabled = false, point = "CENTER", x = 0, y = -170, width = 220, spacing = 2, strata = "MEDIUM", scale = 1,
        texture = "", border = Style.Border({ style = "pixel" }), background = Style.Background({ alpha = 0.8 }),
        order = "default", smooth = true,
        health = { show = true, height = 12, tag = "[health:percent]", color = "class", fixed = { r = 0.2, g = 0.8, b = 0.3 },
                   text = Style.Text(10, { anchor = "CENTER", outline = "OUTLINE", shadow = false }) },
        power = { show = true, height = 8, tag = "[power:current]", mana = true, color = "type",
                  fixed = { r = 0.3, g = 0.5, b = 1 }, ticks = "", tickColor = { r = 1, g = 1, b = 1, a = 0.8 },
                  text = Style.Text(9, { anchor = "CENTER", outline = "OUTLINE", shadow = false }) },
        class = { show = true, height = 8 },
        spec = { show = true, height = 6 },
        collapse = true, combatOnly = false, oocAlpha = 1, previewClass = "",
    },
    -- the player's totems as buttons: right click destroys one (a secure button)
    totems = { style = "blizzard", size = 28, spacing = 4, growth = "RIGHT", point = "CENTER", x = 0, y = -214, zoom = 0.08,
               border = Style.Border({ style = "pixel" }),
               duration = Style.Text(10, { anchor = "BOTTOM", outline = "OUTLINE", shadow = false, y = -2 }) },
    -- weapon imbues (poisons, oils, stones, shaman weapon spells): the weapon's icon with the time left
    imbues = { show = true, size = 28, spacing = 4, zoom = 0.08, point = "CENTER", x = 120, y = -214,
               text = Style.Text(11, { outline = "OUTLINE", shadow = false }) },
    -- colours (every frame)
    colors = {
        low = false, mid = false, high = false, tapped = false, dead = false, offline = false,
        absorb = false, healAbsorb = false, myHeal = false, otherHeal = false, fixed = false, charged = false,
        threshold = false, cc = false, defensive = false, important = false, focus = false,
    },
    numbers = "short", decimals = 1, percentDecimals = 0,
    -- class resource (player only): combo points, holy power, chi, soul shards, arcane charges, essence, runes …
    classPower = {
        show = "attached", height = 6, spacing = 2, color = "power", emptyAlpha = 0.25, runesSorted = true,
        stagger = true, hideFull = false, shape = "bar", border = Style.Border({ style = "pixel" }),
        orientation = "HORIZONTAL", separators = false, threshold = 0, fade = false,
        text = Style.Text(10, { anchor = "CENTER", outline = "OUTLINE", shadow = false, show = false }),
    },
    -- Blizzard mode (Blizzard.lua): the 2.0 skin of Blizzard's own frames
    texture = true, classColor = true, powerColor = true, fonts = true,
    range = { enabled = false, alpha = 0.45 },
    auras = { style = true, zoom = 0.08, border = Style.Border({ style = "none" }),
        count = Style.Text(10, { outline = "OUTLINE", shadow = false }) },
}
-- arena pets sit beside their arena frame (off: their own stack and mover)
DEFAULTS.units.arenapet.attach = true

local M = ns:NewModule("UnitFrames", {
    label = "UNITFRAMES", desc = "UNITFRAMES_DESC", category = "interface", order = 20, reloadOnToggle = true,
    defaults = DEFAULTS,
})
M.UNITS, M.TOKENS, M.GROUP, M.LEGACY, M.SMALL, M.DEFAULTS = UNITS, TOKENS, GROUP, LEGACY, SMALL, DEFAULTS
-- other modules shape their own frames' settings like a unit's (Group Frames profiles)
M.NewUnitSettings = unit

local function plain(v) return not Secret.IsSecret(v) end
M.plain = plain

function M:IsPhoenix() return self.db.mode == "phoenix" end
--[[ Unit settings sources: key -> function(key) returning a settings table shaped like a unit's (at least nameLength
    and auras.tooltips). Modules that draw with this module's tags and aura buttons register their keys here
    (NamePlates: "plate.enemy", "plate.friendly"; Group Frames: "group.party", "group.raid", "group.large",
    "group.tanks", "group.pets"). ]]
M.UNIT_SOURCES = {}
function M:Unit(key)
    local source = M.UNIT_SOURCES[key]
    if source then return source(key) end
    return self.db.units[key] or self.db.units.player
end
-- the settings key of a unit token: boss3 -> boss, targettarget -> targettarget
function M.KeyOf(token)
    if type(token) ~= "string" then return nil end
    local base = token:match("^(%a+)%d$")
    if base and GROUP[base] then return base end
    return TOKENS[token] and token or nil
end

---------------------------------------------------------------- numbers
-- Breakpoints for AbbreviateNumbers (it accepts secret numbers): 1.2k with one decimal, 1k with none.
local abbrev = {}
function M.AbbrevOptions(decimals)
    decimals = math.max(0, math.min(2, decimals or 1))
    if abbrev[decimals] then return abbrev[decimals] end
    local f = 10 ^ decimals
    local data = {}
    for _, step in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
        local n, letter = step[1], step[2]
        data[#data + 1] = { breakpoint = n * 10, abbreviation = letter, significandDivisor = n, fractionDivisor = 1,
            abbreviationIsGlobal = false }
        data[#data + 1] = { breakpoint = n, abbreviation = letter, significandDivisor = n / f, fractionDivisor = f,
            abbreviationIsGlobal = false }
    end
    abbrev[decimals] = { breakpointData = data }
    return abbrev[decimals]
end

local ASIAN = { koKR = true, zhCN = true, zhTW = true }
-- A number for display: "short" (12.3K), "full" (12,345) or "asian" (万/億). Never compared or added.
function M:Number(n)
    local mode = self.db.numbers
    if mode == "full" then return BreakUpLargeNumbers(n) end
    if mode == "asian" then
        return AbbreviateNumbers(n, { locale = ASIAN[GetLocale()] and GetLocale() or "zhCN" })
    end
    return AbbreviateNumbers(n, M.AbbrevOptions(self.db.decimals))
end

---------------------------------------------------------------- tags
--[[ A tag string ("[name]  [health:percent]") compiles once into a format string and a list of value getters;
    the text is then fs:SetFormattedText(fmt, values…). Format strings accept secret values, so a secret health
    or power number flows straight through without being read. Literal text keeps its place; "%" is escaped.
    Getters receive (frame, source) where source is the frame's data source (Update.lua). ]]
local TAGS = {}
M.TAGS = TAGS
-- fmt uses "%s" for text and "%P" for a percentage (becomes "%.Nf%%" with the chosen decimals)
local function tag(name, fmt, ...) TAGS[name] = { fmt = fmt, fns = { ... } } end
local function num(kind) return function(f, s) return s:HealthText(f, kind) end end
local function pnum(kind) return function(f, s) return s:PowerText(f, kind) end end
local function hpct(f, s) return s:HealthPercent(f) end
local function ppct(f, s) return s:PowerPercent(f) end

tag("name", "%s", function(f, s) return s:Name(f) end)
tag("name:short", "%s", function(f, s) return s:Name(f, 8) end)
tag("level", "%s", function(f, s) return s:Level(f) end)
tag("classification", "%s", function(f, s) return s:Classification(f) end)
tag("class", "%s", function(f, s) return s:ClassName(f) end)
tag("status", "%s", function(f, s) return s:Status(f) end)
tag("group", "%s", function(f, s) return s:Group(f) end)
tag("afk", "%s", function(f, s) return s:Away(f) end)
tag("guild", "%s", function(f, s) return s:Guild(f) end)
-- an NPC's title (<Innkeeper>, <Flight Master>) and "guild for players, title for NPCs" (S17)
tag("npctitle", "%s", function(f, s) return s:Title(f) end)
tag("guild:title", "%s", function(f, s) return s:GuildOrTitle(f) end)
tag("health:current", "%s", num("current"))
tag("health:max", "%s", num("max"))
tag("health:percent", "%P", hpct)
tag("health:current-max", "%s / %s", num("current"), num("max"))
tag("health:current-percent", "%s | %P", num("current"), hpct)
tag("health:deficit", "-%s", num("deficit"))
tag("absorbs", "%s", function(f, s) return s:AbsorbText(f) end)
tag("power:current", "%s", pnum("current"))
tag("power:max", "%s", pnum("max"))
tag("power:percent", "%P", ppct)
tag("power:current-max", "%s / %s", pnum("current"), pnum("max"))
tag("altpower", "%s", function(f, s) return s:AltPowerText(f) end)
-- S18: the player's threat on the unit, the level in its difficulty colour, an arena enemy's spec, the unit's target
tag("threat", "%P", function(f, s) return s:ThreatPercent(f) end)
tag("level:color", "%s", function(f, s) return s:LevelColored(f) end)
tag("spec", "%s", function(f, s) return s:SpecName(f) end)
tag("target", "%s", function(f, s) return s:TargetName(f) end)
-- list for the options help, in a stable order
M.TAG_LIST = { "name", "name:short", "level", "classification", "class", "status", "group", "afk", "guild", "guild:title", "npctitle",
    "health:current", "health:max", "health:percent", "health:current-max", "health:current-percent", "health:deficit", "absorbs",
    "power:current", "power:max", "power:percent", "power:current-max", "altpower", "threat", "level:color", "spec",
    "target" }
M.MAX_TAG_VALUES = 8

local compiled = {}
--[[ -> { fmt = "…", getters = { fn, … }, empty = bool, percent = bool }. Unknown tags stay as literal text; values
    beyond MAX_TAG_VALUES are dropped. `decimals` sets the percentage precision. ]]
function M.CompileTags(str, decimals)
    str = type(str) == "string" and str or ""
    decimals = math.max(0, math.min(2, tonumber(decimals) or 0))
    local key = decimals .. "\1" .. str
    local c = compiled[key]
    if c then return c end
    local pct = "%%." .. decimals .. "f%%%%"
    local parts, getters = {}, {}
    local pos = 1
    while pos <= #str do
        local a, b, name = str:find("%[([%w:%-]+)%]", pos)
        local literal = str:sub(pos, (a or (#str + 1)) - 1)
        if literal ~= "" then parts[#parts + 1] = (literal:gsub("%%", "%%%%")) end
        if not a then break end
        local t = TAGS[name]
        if t and #getters + #t.fns <= M.MAX_TAG_VALUES then
            parts[#parts + 1] = (t.fmt:gsub("%%P", pct))
            for _, fn in ipairs(t.fns) do getters[#getters + 1] = fn end
        else
            parts[#parts + 1] = (("[" .. name .. "]"):gsub("%%", "%%%%"))
        end
        pos = b + 1
    end
    local fmt = table.concat(parts)
    c = { fmt = fmt, getters = getters, empty = fmt == "" }
    compiled[key] = c
    return c
end

-- Fills fs from a compiled tag string; the values are handed over unread.
function M.ApplyTags(fs, c, f, s)
    if c.empty then fs:SetText(""); return end
    local g = c.getters
    if #g == 0 then fs:SetText((c.fmt:gsub("%%%%", "%%"))); return end
    local v = {}
    for i = 1, M.MAX_TAG_VALUES do v[i] = g[i] and g[i](f, s) or "" end
    fs:SetFormattedText(c.fmt, v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8])
end

---------------------------------------------------------------- colours
local TOKEN = {
    low = "state.danger", mid = "state.warning", high = "state.success", tapped = "text.muted", dead = "text.disabled",
    offline = "text.disabled", absorb = "text.primary", healAbsorb = "state.danger", myHeal = "state.success",
    otherHeal = "state.info", fixed = "bg.raised", charged = "accent.primary", threshold = "state.warning",
    cc = "state.danger", defensive = "state.success", important = "state.warning", focus = "state.info",
}
M.COLOR_TOKENS = TOKEN
function M:Color(which)
    return ns.Skin:SpecColor(self.db.colors[which], TOKEN[which])
end

-- Plain colour of a unit's reaction (hostile red … friendly green). nil when it cannot be read.
function M.ReactionColor(reaction)
    if not plain(reaction) or type(reaction) ~= "number" then return nil end
    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if c then return c.r, c.g, c.b end
    return nil
end

function M.PowerColor(token, kind)
    if plain(token) and token then
        local r, g, b = ns.Util.PowerColor(token)
        if r then return r, g, b end
    end
    if plain(kind) and kind and PowerBarColor then
        local c = PowerBarColor[kind]
        if c and c.r then return c.r, c.g, c.b end
    end
    return 0.31, 0.45, 0.85
end

-- A health colour curve (low -> mid -> high) evaluated by UnitHealthPercent(unit, true, curve), so the
-- colour follows secret health without our code reading it. Rebuilt when a colour setting changes.
local healthCurve
function M:HealthCurve()
    if healthCurve ~= nil then return healthCurve or nil end
    healthCurve = false
    if C_CurveUtil and C_CurveUtil.CreateColorCurve then
        local ok, c = pcall(function()
            local curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Linear)
            curve:AddPoint(0, CreateColor(self:Color("low")))
            curve:AddPoint(0.5, CreateColor(self:Color("mid")))
            curve:AddPoint(1, CreateColor(self:Color("high")))
            return curve
        end)
        if ok and c then healthCurve = c end
    end
    return healthCurve or nil
end

-- The plain colour the health curve would give at fraction p (preview, sample frames, tests).
function M:CurveColor(p)
    p = math.max(0, math.min(1, p or 1))
    local a, b, t
    if p < 0.5 then a, b, t = { self:Color("low") }, { self:Color("mid") }, p / 0.5
    else a, b, t = { self:Color("mid") }, { self:Color("high") }, (p - 0.5) / 0.5 end
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- An alpha curve: 0 at full health, 1 below it ("hide when full" health text).
local fullCurve
function M.FullCurve()
    if fullCurve ~= nil then return fullCurve or nil end
    fullCurve = false
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local ok, c = pcall(function()
            local curve = C_CurveUtil.CreateCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            curve:AddPoint(0, 1)
            curve:AddPoint(0.9999, 0)
            return curve
        end)
        if ok and c then fullCurve = c end
    end
    return fullCurve or nil
end

function M:ResetCurves() healthCurve = nil end

---------------------------------------------------------------- geometry (pure)
--[[ Where a frame's parts go, in frame units from its TOPLEFT (x right, y down):
    returns { health = {x, y, w, h}, power = {…}|nil, portrait = {…}|nil, classPower = {…}|nil }.
    The portrait takes a square at one side ("left"/"right") or fills the health bar ("overlay"); the power bar
    sits inside the frame at the bottom ("inside"), hangs under it ("below") or is hidden. ]]
-- An inside power bar's height when the health bar takes a share (40-100 %) of the frame; else its own height.
function M.SharedPowerHeight(u, H, ph)
    local share = u.bar and tonumber(u.bar.share) or 1
    if share >= 1 then return ph end
    return math.max(1, math.min(H - 6, math.floor(H * (1 - math.max(0.4, share)) + 0.5) - (u.powerBar.gap or 1)))
end

function M.Geometry(u, opts)
    opts = opts or {}
    local W, H = u.width, u.height
    local pb = u.powerBar
    local showPower = pb.show ~= "off" and not opts.noPower
    local ph = showPower and math.max(1, math.min(pb.height, H - 6)) or 0
    local g = {}
    local x0, w = 0, W
    if u.portrait ~= "hide" and u.portraitPos ~= "overlay" then
        -- portraitSize scales the square against the frame height (centred on it), never past half the width
        local size = math.max(8, math.min(math.floor(H * (u.portraitSize or 1) + 0.5), math.floor(W / 2)))
        local py = math.floor((H - size) / 2 + 0.5)
        if u.portraitPos == "right" then
            g.portrait = { W - size, py, size, size }
        else
            g.portrait = { 0, py, size, size }
            x0 = size + 1
        end
        w = W - size - 1
    end
    if showPower and pb.position == "inside" then ph = M.SharedPowerHeight(u, H, ph) end
    if showPower and pb.position == "inside" then
        local gap = pb.gap or 1
        g.health = { x0, 0, w, H - ph - gap }
        g.power = { x0, H - ph, w, ph }
    else
        g.health = { x0, 0, w, H }
        if showPower then
            -- a detached width (0 = the frame's, inset 4 px a side) centres the bar under the health bar
            local pw = (pb.width or 0) > 0 and math.min(pb.width, 400) or (w - 8)
            g.power = { x0 + math.floor((w - pw) / 2 + 0.5), H + (pb.gap or 1), pw, ph }
        end
    end
    if u.portrait ~= "hide" and u.portraitPos == "overlay" then g.portrait = { g.health[1], 0, g.health[3], g.health[4] } end
    if opts.classPower then
        local cp = opts.classPower
        if cp.show == "attached" then
            g.classPower = { x0, -(cp.height + 2), w, cp.height }
        elseif cp.show == "detached" then
            g.classPower = { x0, H + ((g.power and pb.position ~= "inside") and (ph + 6) or 4), w, cp.height }
        end
    end
    return g
end

-- How far below the frame its hanging parts reach (power bar below, text strip): cast bars and auras clear it.
function M.Hanging(u)
    local h = (u.powerBar.show ~= "off" and u.powerBar.position == "below") and (u.powerBar.height + 2) or 0
    if u.strip and u.strip.show then h = h + u.strip.height + (u.strip.gap or 1) end
    return h
end

--[[ "Name=Nick, Other = Nick two" -> { Name = "Nick", Other = "Nick two" } (whitespace trimmed, bad pairs skipped). ]]
local nickCache = { src = nil, map = {} }
function M.ParseNicknames(str)
    if type(str) ~= "string" then return {} end
    if nickCache.src == str then return nickCache.map end
    local map = {}
    for pair in str:gmatch("[^,;\n]+") do
        local name, nick = pair:match("^%s*(.-)%s*=%s*(.-)%s*$")
        if name and name ~= "" and nick and nick ~= "" then map[name] = nick end
    end
    nickCache.src, nickCache.map = str, map
    return map
end

--[[ Arena layout presets (S18): each sets the arena frame's shape; the icons and DR follow `mirrored`. ]]
M.ARENA_LAYOUTS = {
    phoenix = { width = 200, height = 40, ph = 7, portrait = "hide", mirrored = false, zoom = 0.08, spacing = 34 },
    mirrored = { width = 200, height = 40, ph = 7, portrait = "hide", mirrored = true, zoom = 0.08, spacing = 34 },
    compact = { width = 160, height = 28, ph = 4, portrait = "hide", mirrored = false, zoom = 0.08, spacing = 24 },
    tall = { width = 190, height = 56, ph = 10, portrait = "hide", mirrored = false, zoom = 0.08, spacing = 40 },
    wide = { width = 260, height = 36, ph = 6, portrait = "hide", mirrored = false, zoom = 0.08, spacing = 30 },
    slim = { width = 220, height = 22, ph = 0, portrait = "hide", mirrored = false, zoom = 0.08, spacing = 22 },
    portrait = { width = 210, height = 44, ph = 7, portrait = "class", mirrored = false, zoom = 0.08, spacing = 34 },
    gladiator = { width = 200, height = 48, ph = 10, portrait = "game", mirrored = true, zoom = 0.08, spacing = 36 },
    cropped = { width = 180, height = 34, ph = 5, portrait = "hide", mirrored = false, zoom = 0.2, spacing = 28 },
}
M.ARENA_LAYOUT_ORDER = { "phoenix", "mirrored", "compact", "tall", "wide", "slim", "portrait", "gladiator", "cropped" }

-- Writes a preset into the arena settings (size, power height, portrait, mirroring, icon crop).
function M.ApplyArenaLayout(u, name)
    local p = M.ARENA_LAYOUTS[name]
    if not (u and p) then return false end
    u.layout = name
    u.width, u.height, u.spacing = p.width, p.height, p.spacing
    u.powerBar.show = p.ph > 0 and "always" or "off"
    if p.ph > 0 then u.powerBar.height = p.ph end
    u.portrait = p.portrait
    u.portraitPos = p.mirrored and "right" or "left"
    u.mirrored = p.mirrored
    u.iconZoom = p.zoom
    if u.dr then u.dr.zoom = p.zoom; u.dr.size = math.max(16, math.min(36, p.height - 8)) end
    return true
end

-- Slots of n pips across width w with spacing s: { {x, w}, … } (pixel-rounded, the last one takes the rest).
function M.Pips(n, w, s)
    local out = {}
    if n < 1 then return out end
    local each = math.floor((w - (n - 1) * s) / n)
    local x = 0
    for i = 1, n do
        local width = (i == n) and (w - x) or each
        out[i] = { x, width }
        x = x + each + s
    end
    return out
end

-- Aura slot offsets for n icons of size `size`, `perRow` per line, growing along `growth` ("RIGHT"/"LEFT"), lines
-- stacking away from the frame (up when the row sits above, down otherwise).
function M.AuraSlots(n, size, perRow, spacing, growth, up)
    local out = {}
    perRow = math.max(1, perRow)
    for i = 1, n do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        local x = col * (size + spacing)
        if growth == "LEFT" then x = -x end
        local y = row * (size + spacing)
        out[i] = { x, up and y or -y }
    end
    return out
end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    ns.Events:Listen("PUI_SPECICON_STYLE", self, function() self:Refresh() end) -- arena spec icons (UI/SpecIcon.lua)
    if self:IsPhoenix() then
        self:EnablePhoenix()  -- Spawn.lua
    else
        self:EnableBlizzard() -- Blizzard.lua
    end
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function() M:ShowTest(false) end)
end

function M:OnDisable()
    self:ShowTest(false)
    if not self:IsPhoenix() then self:DisableBlizzard() end
end

function M:Refresh()
    self:ResetCurves()
    if self:IsPhoenix() then self:RefreshPhoenix() else self:RefreshBlizzard() end
    if self.testShown then self:ShowTest(true) end
end

function M:OnSettingChanged(path, value)
    if type(path) == "string" and path:find("^colors") then self:ResetCurves() end
    -- an arena layout preset writes its size, power, portrait and icon crop
    if path == "units.arena.layout" then M.ApplyArenaLayout(self.db.units.arena, value or self.db.units.arena.layout) end
    self:Refresh()
end

-- Test frames: Phoenix frames filled with sample data where the real ones sit (out of combat only).
function M:ShowTest(show)
    if show and InCombatLockdown() then return false end
    self.testShown = show and true or nil
    if self:IsPhoenix() then
        return self:ShowPhoenixTest(show)
    end
    return self:ShowBlizzardTest(show)
end
