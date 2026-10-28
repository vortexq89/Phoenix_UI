local _, ns = ...
local Opt = ns.Opt

--[[ Cast Bars (plan v2 S9). Most rows act on Phoenix's own bars ("Bars drawn by: Phoenix"); the 2.0 Blizzard skin's
    rows show in Blizzard mode only. Rows that only make sense for some bars hide for the others (attach for the
    unit-frame bars, stacking for boss/arena, latency/ticks/GCD for the player, kick tick for enemies). ]]
local function blizzard(m) return m.db.mode ~= "phoenix" end
local function phoenix(m) return m.db.mode == "phoenix" end
local function bar(m, unit) return m.db.bars[unit or "player"] end
local function off(m, unit) return blizzard(m) or not bar(m, unit).enabled end
local function attached(m, unit)
    local b = bar(m, unit)
    return b.attach == "frame" and ns.modules.CastBars.ATTACHABLE[unit or "player"] ~= nil
end
local function placed(m, unit) return off(m, unit) or attached(m, unit) end
local function notAttachable(_, unit) return not ns.modules.CastBars.ATTACHABLE[unit or "player"] end
local function notGroup(_, unit) return unit ~= "boss" and unit ~= "arena" end
local function notPlayer(_, unit) return (unit or "player") ~= "player" end
local function isPlayer(_, unit) return (unit or "player") == "player" end
local function notMine(_, unit) local u = unit or "player"; return u ~= "player" and u ~= "pet" end
local function noIcon(m, unit) return off(m, unit) or bar(m, unit).icon == "off" end
local function playerOff(m) return blizzard(m) or not m.db.bars.player.enabled end
local function unstyled(m) return not m.db.style end

local ATTACH = { { value = "frame", label = "CB_ATTACH_FRAME" }, { value = "free", label = "CB_ATTACH_FREE" } }
local MODE = { { value = "phoenix", label = "CB_MODE_PHOENIX" }, { value = "blizzard", label = "CB_MODE_BLIZZARD" } }
local ICON = { { value = "left", label = "ANCHOR_LEFT" }, { value = "right", label = "ANCHOR_RIGHT" }, { value = "off", label = "OFF" } }
local GROWTH = { { value = "DOWN", label = "GROW_DOWN" }, { value = "UP", label = "GROW_UP" },
    { value = "RIGHT", label = "GROW_RIGHT" }, { value = "LEFT", label = "GROW_LEFT" } }
local TIME = { { value = "remaining", label = "CB_TIME_REMAINING" }, { value = "elapsed", label = "CB_TIME_ELAPSED" },
    { value = "both", label = "CB_TIME_BOTH" }, { value = "elapsedTotal", label = "CB_TIME_ELAPSED_TOTAL" },
    { value = "none", label = "CB_TIME_NONE" } }

local BARS = {}
for _, key in ipairs({ "player", "target", "focus", "pet", "boss", "arena" }) do
    BARS[#BARS + 1] = { value = key, label = "UF_" .. key:upper() }
end

local function toggleTest(m)
    if not m:IsEnabled() then return end
    if not m:ShowTest(not m.testShown) then ns.Config:SetStatus(ns.L.UF_TEST_COMBAT, "state.warning", "warning") end
end

local function openLayout()
    local movers = ns:GetModule("Movers")
    if not movers or not movers:IsEnabled() then
        ns.Config:SetStatus(ns.L.AB_LAYOUT_NEEDS_MOVERS, "state.warning", "warning")
        return
    end
    ns.Config.frame:Hide()
    movers:SetUnlocked(true)
end

-- Phoenix-mode rows: greyed out while Blizzard draws the bars (and while this bar is off).
local function px(row, extra)
    local d = row.disabled
    row.disabled = d and function(m, u) return off(m, u) or d(m, u) end or off
    return Opt.With(row, extra)
end
local LEGACY = { player = true, target = true, focus = true }
local function bz(row, perBar)
    return Opt.With(row, { hidden = perBar and function(m, u) return phoenix(m) or not LEGACY[u or "player"] end or phoenix })
end

local GCD_ATTACH = { { value = "castbar", label = "CB_GCD_ON_CASTBAR" }, { value = "free", label = "CB_GCD_FREE" } }

ns:RegisterOptions("CastBars", {
    { type = "scope", key = "bars", label = "CB_BAR", values = BARS },
    { type = "preview", kind = "castbar" },
    ------------------------------------------------------------ bars
    { type = "tab", label = "CB_TAB_BARS" },
    { type = "header", label = "CB_MODE", icon = "castbars" },
    { type = "select", key = "mode", label = "CB_MODE", desc = "CB_MODE_DESC", values = MODE, reload = true,
      keywords = "own cast bar blizzard edit mode replace fallback" },
    { type = "button", label = "CB_TEST", desc = "CB_TEST_DESC", button = "CB_TEST_BUTTON", icon = "test", func = toggleTest,
      keywords = "test fake cast sample" },
    { type = "button", label = "UF_LAYOUT_MODE", desc = "CB_LAYOUT_DESC", button = "AB_LAYOUT_MODE_BUTTON", icon = "movers",
      combat = true, func = openLayout, disabled = blizzard, keywords = "move drag unlock position" },
    { type = "header", label = "CB_SIZE", icon = "layout", wide = true },
    { type = "toggle", gate = true, key = "bars.@.enabled", label = "CB_ENABLE", desc = "CB_ENABLE_DESC", reload = true,
      disabled = blizzard },
    px({ type = "select", key = "bars.@.attach", label = "CB_ATTACH", desc = "CB_ATTACH_DESC", values = ATTACH,
      hidden = notAttachable, keywords = "attach unit frame anchor detach" }),
    px({ type = "range", key = "bars.@.width", label = "UF_WIDTH", min = 60, max = 600, step = 1, disabled = attached }),
    px({ type = "range", key = "bars.@.height", label = "UF_HEIGHT", min = 4, max = 60, step = 1, disabled = attached }),
    px({ type = "range", key = "bars.@.scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, disabled = attached }),
    px({ type = "select", key = "bars.@.strata", label = "FRAME_STRATA", values = Opt.STRATA, disabled = attached }),
    px({ type = "range", key = "bars.@.spacing", label = "UF_SPACING", min = 0, max = 120, step = 1, hidden = notGroup,
      disabled = attached }),
    px({ type = "select", key = "bars.@.growth", label = "UF_GROWTH", values = GROWTH, hidden = notGroup, disabled = attached }),
    { type = "header", label = "CB_POSITION", icon = "movers" },
    { type = "select", key = "bars.@.point", single = true, label = "UF_POINT", values = Opt.ANCHOR, disabled = placed },
    { type = "range", key = "bars.@.x", single = true, label = "OFFSET_X", min = -1200, max = 1200, step = 1, disabled = placed },
    { type = "range", key = "bars.@.y", single = true, label = "OFFSET_Y", min = -800, max = 800, step = 1, disabled = placed },
    { type = "description", text = "CB_ATTACH_NOTE", hidden = notAttachable },
    ------------------------------------------------------------ look
    { type = "tab", label = "CB_TAB_LOOK" },
    { type = "header", label = "CB_FILL", icon = "border" },
    { type = "texture", key = "bars.@.texture", label = "BAR_TEXTURE", allowDefault = true,
      disabled = function(m, u) return blizzard(m) and not m.db.style or (phoenix(m) and off(m, u)) end,
      keywords = "statusbar texture" },
    px({ type = "toggle", key = "bars.@.reverse", label = "CB_REVERSE", desc = "CB_REVERSE_DESC", keywords = "fill direction" }),
    px({ type = "toggle", key = "bars.@.smooth", label = "UF_SMOOTH", desc = "CB_SMOOTH_DESC" }),
    px({ type = "range", key = "bars.@.gradient", label = "UF_SHADE", desc = "UF_SHADE_DESC", min = 0, max = 0.8, step = 0.05,
      percent = true }),
    px({ type = "toggle", key = "bars.@.classColor", label = "CB_CLASSCOLOR", desc = "CB_CLASSCOLOR_DESC2", hidden = notMine }),
    { type = "colors", keys = { "bars.@.colors.cast", "bars.@.colors.channel", "bars.@.colors.locked" },
      tokens = { "accent.primary", "state.info", "text.muted" }, label = "CB_FILL_COLORS", desc = "CB_FILL_COLORS_DESC2",
      labels = { "CB_COLOR_CAST", "CB_COLOR_CHANNEL", "CB_COLOR_LOCKED" },
      disabled = function(m, u) return blizzard(m) and not m.db.style or (phoenix(m) and off(m, u)) end,
      keywords = "colour cast channel interrupt uninterruptible shield" },
    px({ type = "colors", keys = { "bars.@.colors.notReady", "bars.@.colors.interrupted", "bars.@.colors.success" },
      tokens = { "state.warning", "state.danger", "state.success" }, label = "CB_STATE_COLORS", desc = "CB_STATE_COLORS_DESC",
      labels = { "CB_COLOR_NOT_READY", "CB_COLOR_INTERRUPTED", "CB_COLOR_SUCCESS" } }),
    Opt.With(Opt.Background("bars.@.background"), { disabled = function(m, u) return phoenix(m) and off(m, u) end }),
    Opt.With(Opt.Border("bars.@.border"), { disabled = function(m, u) return phoenix(m) and off(m, u) end }),
    px({ type = "toggle", key = "bars.@.spark", label = "CB_SPARK", desc = "CB_SPARK_DESC",
      cog = { { type = "color", key = "bars.@.sparkColor", label = "CB_SPARK_COLOR", token = "text.primary", reset = true } } }),
    { type = "header", label = "CB_ICON_HEADER", icon = "auras" },
    px({ type = "select", key = "bars.@.icon", label = "CB_ICON_POS", desc = "CB_ICON_POS_DESC", values = ICON,
      keywords = "spell icon left right",
      cog = { { type = "range", key = "bars.@.iconZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 },
              { type = "range", key = "bars.@.iconGap", label = "CB_ICON_GAP", min = 0, max = 20, step = 1 } } }),
    px({ type = "toggle", key = "bars.@.iconDetached", label = "CB_ICON_DETACHED", desc = "CB_ICON_DETACHED_DESC", disabled = noIcon,
      cog = { { type = "range", key = "bars.@.iconSize", label = "ICON_SIZE", min = 10, max = 80, step = 1 } } }),
    px({ type = "toggle", key = "bars.@.shield", label = "CB_SHIELD", desc = "CB_SHIELD_DESC", disabled = noIcon,
      keywords = "uninterruptible lock shield" }),
    ------------------------------------------------------------ text
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "CB_TEXT", icon = "fonts" },
    px(Opt.Text("bars.@.text", "CB_SPELL_FONT", { place = true, show = true })),
    px(Opt.Text("bars.@.time", "CB_TIME_FONT", { place = true, show = true })),
    px(Opt.Text("bars.@.target", "CB_TARGET_FONT", { place = true, show = true,
      row = { desc = "CB_TARGET_DESC", hidden = isPlayer, keywords = "spell target name" } })),
    { type = "header", label = "CB_TIMER", icon = "speed" },
    px({ type = "select", key = "bars.@.timeFormat", label = "CB_TIME_FORMAT", values = TIME, keywords = "remaining elapsed total" }),
    px({ type = "range", key = "bars.@.decimals", label = "UF_DECIMALS", min = 0, max = 2, step = 1 }),
    px({ type = "range", key = "bars.@.nameLength", label = "CB_NAME_LENGTH", desc = "CB_NAME_LENGTH_DESC", min = 0, max = 40, step = 1 }),
    ------------------------------------------------------------ behaviour
    { type = "tab", label = "CB_TAB_EXTRAS" },
    { type = "header", label = "CB_END", icon = "error" },
    px({ type = "range", key = "bars.@.hold", label = "CB_HOLD", desc = "CB_HOLD_DESC", min = 0, max = 3, step = 0.1 }),
    px({ type = "toggle", key = "bars.@.flash", label = "CB_FLASH", desc = "CB_FLASH_DESC", keywords = "interrupted flash success" }),
    { type = "header", label = "CB_ENEMY", icon = "pvp", hidden = notMine },
    px({ type = "toggle", key = "bars.@.kick", label = "CB_KICK", desc = "CB_KICK_DESC", hidden = notMine,
      keywords = "interrupt kick ready tick cooldown",
      cog = { { type = "color", key = "colors.kick", label = "CB_KICK_COLOR", token = "state.success", reset = true } } }),
    px({ type = "toggle", key = "bars.@.important", label = "CB_IMPORTANT", desc = "CB_IMPORTANT_DESC", hidden = notMine,
      keywords = "important dangerous highlight" }),
    px({ type = "toggle", key = "bars.@.importantFill", label = "CB_IMPORTANT_FILL", desc = "CB_IMPORTANT_FILL_DESC", hidden = notMine,
      keywords = "important dangerous cast colour",
      cog = { { type = "color", key = "bars.@.colors.important", label = "TEXT_COLOR", token = "state.warning", reset = true } } }),
    px({ type = "toggle", key = "bars.@.targeted", label = "CB_TARGETED", desc = "CB_TARGETED_DESC", hidden = notMine,
      keywords = "targeted at me spell target highlight" }),
    { type = "header", label = "CB_PLAYER", icon = "user", hidden = notPlayer },
    { type = "toggle", key = "latency", label = "CB_LATENCY", desc = "CB_LATENCY_DESC", keywords = "lag safe zone", hidden = notPlayer,
      disabled = function(m) return phoenix(m) and playerOff(m) end,
      cog = { { type = "color", key = "colors.latency", label = "CB_LATENCY_COLOR", token = "state.danger", reset = true } } },
    { type = "toggle", key = "ticks", label = "CB_TICKS", desc = "CB_TICKS_DESC", hidden = notPlayer, disabled = playerOff,
      keywords = "channel ticks mind flay drain",
      cog = { { type = "color", key = "colors.tick", label = "CB_TICK_COLOR", token = "text.primary", reset = true } } },
    { type = "input", key = "customTicks", label = "CB_CUSTOM_TICKS", desc = "CB_CUSTOM_TICKS_DESC", hidden = notPlayer,
      disabled = playerOff },
    { type = "toggle", key = "empower", label = "CB_EMPOWER", desc = "CB_EMPOWER_DESC", hidden = notPlayer, disabled = playerOff,
      keywords = "empower evoker stages charge",
      cog = { { type = "color", key = "colors.stage", label = "CB_STAGE_COLOR", token = "text.primary", reset = true } } },
    { type = "toggle", key = "gcd.enabled", label = "CB_GCD", desc = "CB_GCD_DESC", hidden = notPlayer, disabled = playerOff,
      feature = "gcdBar", keywords = "global cooldown gcd",
      cog = { { type = "range", key = "gcd.height", label = "UF_HEIGHT", min = 1, max = 12, step = 1 },
              { type = "range", key = "gcd.gap", label = "UF_CAST_GAP", min = 0, max = 10, step = 1 },
              { type = "select", key = "gcd.attach", label = "CB_GCD_ATTACH", desc = "CB_GCD_ATTACH_DESC", values = GCD_ATTACH },
              { type = "range", key = "gcd.width", label = "UF_WIDTH", min = 40, max = 600, step = 1 },
              { type = "color", key = "colors.gcd", label = "CB_GCD_COLOR", token = "text.secondary", reset = true } } },
    { type = "toggle", key = "swing.enabled", label = "CB_SWING", desc = "CB_SWING_DESC", hidden = notPlayer, disabled = blizzard,
      feature = "swingTimer", keywords = "swing timer auto attack melee",
      cog = { { type = "range", key = "swing.width", label = "UF_WIDTH", min = 60, max = 600, step = 1 },
              { type = "range", key = "swing.height", label = "UF_HEIGHT", min = 2, max = 30, step = 1 },
              { type = "toggle", key = "swing.offhand", label = "CB_SWING_OFFHAND" },
              { type = "toggle", key = "swing.labels", label = "CB_SWING_LABELS", desc = "CB_SWING_LABELS_DESC" },
              { type = "toggle", key = "swing.rangeCue", label = "CB_SWING_RANGE", desc = "CB_SWING_RANGE_DESC" },
              { type = "color", key = "colors.swing", label = "CB_SWING_COLOR", token = "accent.primary", reset = true } } },
    Opt.With(Opt.Text("swing.text", "CB_SWING_FONT", { place = true, show = true }),
      { hidden = notPlayer, disabled = blizzard, feature = "swingTimer" }),
    { type = "description", text = "CB_SECRET_NOTE", hidden = blizzard },
    ------------------------------------------------------------ Blizzard mode (the 2.0 skin)
    bz({ type = "header", label = "CB_BLIZZARD_SKIN", icon = "skins" }),
    bz({ type = "toggle", gate = true, key = "style", label = "CB_SKIN", desc = "CB_SKIN_DESC", reload = true }),
    bz(Opt.Text("bars.@.text", "CB_SPELL_FONT", { row = { disabled = unstyled } }), true),
    bz(Opt.Text("bars.@.time", "CB_TIME_FONT", { row = { disabled = unstyled } }), true),
    bz({ type = "toggle", key = "classColor", label = "CB_CLASSCOLOR", desc = "CB_CLASSCOLOR_DESC", disabled = unstyled }),
    bz({ type = "toggle", key = "icon", label = "CB_ICON", desc = "CB_ICON_DESC",
      cog = { { type = "range", key = "iconZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } }),
    bz({ type = "toggle", key = "timer", label = "CB_TIMER", desc = "CB_TIMER_DESC", keywords = "cast time remaining" }),
    { type = "description", text = "CB_BLIZZARD_NOTE", hidden = phoenix },
})
