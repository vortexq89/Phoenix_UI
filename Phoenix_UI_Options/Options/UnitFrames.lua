local _, ns = ...
local Opt = ns.Opt

--[[ Unit Frames (plan v2 S8). Most rows act on Phoenix's own frames ("Frames owned by: Phoenix"); the rows of the
    2.0 Blizzard skin show in Blizzard mode only. Rows that only make sense for some frames hide for the others
    (stacking for boss/arena, class resource for the player, cast bar anchor for target/focus/boss/arena). ]]
local function blizzard(m) return m.db.mode ~= "phoenix" end
local function phoenix(m) return m.db.mode == "phoenix" end
local function notGroup(_, unit) return unit ~= "boss" and unit ~= "arena" end
local function notPlayer(_, unit) return unit ~= "player" end
local function notArena(_, unit) return unit ~= "arena" end
local function noCast(m, unit) return blizzard(m) or unit == "player" or ns.modules.UnitFrames.SMALL[unit] ~= nil end
local function castHidden(_, u) return u == "player" or ns.modules.UnitFrames.SMALL[u] ~= nil end
local function noClassPower(m, unit) return blizzard(m) or unit ~= "player" end
local function cpOff(m) return m.db.classPower.show == "off" end
local function noFonts(m) return blizzard(m) and not m.db.fonts end
local function legacyAuras(m) return not m.db.auras.style end
local function auraOff(m, unit) local a = m.db.units[unit or "player"].auras; return a.buffs == "off" and a.debuffs == "off" end

local MODE = { { value = "phoenix", label = "UF_MODE_PHOENIX" },
    { value = "blizzard", label = "UF_MODE_BLIZZARD" } }
local PORTRAIT = { { value = "game", label = "UF_PORTRAIT_GAME" }, { value = "model", label = "UF_PORTRAIT_MODEL" },
    { value = "class", label = "UF_PORTRAIT_CLASS" }, { value = "hide", label = "UF_PORTRAIT_HIDE" } }
local LEGACY_PORTRAIT = { { value = "game", label = "UF_PORTRAIT_GAME" }, { value = "class", label = "UF_PORTRAIT_CLASS" },
    { value = "hide", label = "UF_PORTRAIT_HIDE" } }
local PORTRAIT_POS = { { value = "left", label = "ANCHOR_LEFT" }, { value = "right", label = "ANCHOR_RIGHT" },
    { value = "overlay", label = "UF_PORTRAIT_OVERLAY" } }
local SHAPE = { { value = "square", label = "AB_SHAPE_SQUARE" }, { value = "circle", label = "AB_SHAPE_CIRCLE" } }
local HEALTH_COLOR = { { value = "class", label = "UF_COLOR_CLASS" }, { value = "reaction", label = "UF_COLOR_REACTION" },
    { value = "health", label = "UF_COLOR_HEALTH" }, { value = "fixed", label = "UF_COLOR_FIXED" },
    { value = "theme", label = "UF_COLOR_THEME" } }
local POWER_COLOR = { { value = "type", label = "UF_COLOR_POWER" }, { value = "class", label = "UF_COLOR_CLASS" },
    { value = "fixed", label = "UF_COLOR_FIXED" } }
local NAME_COLOR = { { value = "white", label = "UF_COLOR_WHITE" }, { value = "class", label = "UF_COLOR_CLASS" },
    { value = "reaction", label = "UF_COLOR_REACTION" } }
local BG = { { value = "dark", label = "UF_BG_DARK" }, { value = "texture", label = "UF_BG_TEXTURE" },
    { value = "none", label = "UF_BG_NONE" } }
local ABSORB_STYLE = { { value = "striped", label = "UF_ABSORB_STRIPED" }, { value = "solid", label = "UF_ABSORB_SOLID" } }
local ABSORB_POS = { { value = "attached", label = "UF_ABSORB_ATTACHED" },
    { value = "reverse", label = "UF_ABSORB_REVERSE" } }
local POWER_SHOW = { { value = "always", label = "UF_POWER_ALWAYS" }, { value = "mana", label = "UF_POWER_MANA" },
    { value = "off", label = "OFF" } }
local POWER_POS = { { value = "inside", label = "UF_POWER_INSIDE" }, { value = "below", label = "UF_POWER_BELOW" } }
local CP_SHOW = { { value = "attached", label = "UF_CP_ATTACHED" }, { value = "detached", label = "UF_CP_DETACHED" },
    { value = "off", label = "OFF" } }
local CP_COLOR = { { value = "power", label = "UF_COLOR_POWER" }, { value = "class", label = "UF_COLOR_CLASS" },
    { value = "theme", label = "UF_COLOR_THEME" } }
local AURA_POS = { { value = "above", label = "UF_AURA_ABOVE" }, { value = "below", label = "UF_AURA_BELOW" },
    { value = "left", label = "ANCHOR_LEFT" }, { value = "right", label = "ANCHOR_RIGHT" },
    { value = "off", label = "OFF" } }
local AURA_FILTER = { { value = "all", label = "UF_FILTER_ALL" }, { value = "player", label = "UF_FILTER_MINE" },
    { value = "raid", label = "UF_FILTER_RAID" } }
local AURA_GROW = { { value = "RIGHT", label = "GROW_RIGHT" }, { value = "LEFT", label = "GROW_LEFT" } }
local GROWTH = { { value = "DOWN", label = "GROW_DOWN" }, { value = "UP", label = "GROW_UP" },
    { value = "RIGHT", label = "GROW_RIGHT" }, { value = "LEFT", label = "GROW_LEFT" } }
local TOOLTIP = { { value = "always", label = "UF_TIP_ALWAYS" }, { value = "ooc", label = "UF_TIP_OOC" },
    { value = "never", label = "UF_TIP_NEVER" } }
local NUMBERS = { { value = "short", label = "UF_NUM_SHORT" }, { value = "full", label = "UF_NUM_FULL" },
    { value = "asian", label = "UF_NUM_ASIAN" } }
local CAST = { { value = "below", label = "UF_AURA_BELOW" }, { value = "above", label = "UF_AURA_ABOVE" },
    { value = "none", label = "UF_CAST_NONE" } }
local MARKER_ANCHOR = { { value = "TOP", label = "ANCHOR_TOP" }, { value = "CENTER", label = "ANCHOR_CENTER" },
    { value = "LEFT", label = "ANCHOR_LEFT" }, { value = "RIGHT", label = "ANCHOR_RIGHT" } }

local UNITS = {}
for _, key in ipairs({ "player", "target", "targettarget", "focus", "focustarget", "pet", "boss", "arena" }) do
    UNITS[#UNITS + 1] = { value = key, label = "UF_" .. key:upper() }
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

-- Phoenix-mode rows: greyed out while Blizzard owns the frames.
local function px(row, extra)
    local d = row.disabled
    row.disabled = d and function(m, u) return blizzard(m) or d(m, u) end or blizzard
    return Opt.With(row, extra)
end
-- Blizzard-mode rows (the 2.0 skin): only shown in Blizzard mode.
local function bz(row) return Opt.With(row, { hidden = phoenix }) end
local function text(path, label, extra)
    return Opt.Text(path, label, { place = true, show = true, row = Opt.With({ disabled = noFonts }, extra) })
end

ns:RegisterOptions("UnitFrames", {
    { type = "scope", key = "units", label = "UF_FRAME", values = UNITS },
    { type = "preview", kind = "unitframe" },
    ------------------------------------------------------------ frames
    { type = "tab", label = "UF_TAB_FRAMES" },
    { type = "header", label = "UF_MODE", icon = "unitframes" },
    { type = "select", key = "mode", label = "UF_MODE", desc = "UF_MODE_DESC", values = MODE, reload = true,
      keywords = "own frames blizzard edit mode fallback replace" },
    { type = "button", label = "UF_TEST", desc = "UF_TEST_DESC", button = "UF_TEST_BUTTON", icon = "test", func = toggleTest,
      keywords = "test mode fake frames boss arena" },
    px({ type = "button", label = "UF_LAYOUT_MODE", desc = "UF_LAYOUT_MODE_DESC", button = "AB_LAYOUT_MODE_BUTTON", icon = "movers",
      combat = true, func = openLayout, keywords = "move drag unlock position" }),
    { type = "header", label = "UF_SIZE", icon = "layout", wide = true },
    px({ type = "toggle", gate = true, key = "units.@.enabled", label = "UF_ENABLE", desc = "UF_ENABLE_DESC", combat = true }),
    px({ type = "range", key = "units.@.width", label = "UF_WIDTH", min = 60, max = 400, step = 1, combat = true }),
    px({ type = "range", key = "units.@.height", label = "UF_HEIGHT", min = 14, max = 120, step = 1, combat = true }),
    px({ type = "range", key = "units.@.scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, combat = true }),
    px({ type = "select", key = "units.@.strata", label = "FRAME_STRATA", values = Opt.STRATA, combat = true }),
    px({ type = "range", key = "units.@.spacing", label = "UF_SPACING", desc = "UF_SPACING_DESC", min = 0, max = 120, step = 1,
      combat = true, hidden = notGroup }),
    px({ type = "select", key = "units.@.growth", label = "UF_GROWTH", values = GROWTH, combat = true, hidden = notGroup }),
    { type = "header", label = "UF_POSITION", icon = "movers" },
    px({ type = "select", key = "units.@.point", label = "UF_POINT", values = Opt.ANCHOR, combat = true }),
    px({ type = "range", key = "units.@.x", label = "OFFSET_X", min = -1200, max = 1200, step = 1, combat = true }),
    px({ type = "range", key = "units.@.y", label = "OFFSET_Y", min = -800, max = 800, step = 1, combat = true }),
    { type = "header", label = "UF_LOOK", icon = "border" },
    { type = "texture", key = "units.@.texture", label = "BAR_TEXTURE", allowDefault = true,
      disabled = function(m) return blizzard(m) and not m.db.texture end, keywords = "statusbar texture" },
    Opt.Border("units.@.border", "UF_BORDER"),
    Opt.Background("units.@.background"),
    px({ type = "toggle", key = "units.@.highlight", label = "UF_HIGHLIGHT", desc = "UF_HIGHLIGHT_DESC" }),
    px({ type = "toggle", key = "units.@.targetBorder", label = "UF_TARGET_BORDER", desc = "UF_TARGET_BORDER_DESC",
      hidden = function(_, u) return u == "target" end }),
    px({ type = "select", key = "units.@.tooltip", label = "UF_TOOLTIP", values = TOOLTIP }),
    { type = "header", label = "UF_FADING", icon = "opacity" },
    px({ type = "toggle", key = "units.@.rangeFade", label = "UF_RANGE_FADE", desc = "UF_RANGE_FADE_DESC2",
      hidden = function(_, u) return u == "player" end, keywords = "out of range alpha fade",
      cog = { { type = "range", key = "units.@.rangeAlpha", label = "UF_RANGE_ALPHA", min = 0.1, max = 0.9, step = 0.05,
                percent = true } } }),
    px({ type = "toggle", key = "units.@.oocFade", label = "UF_OOC_FADE", desc = "UF_OOC_FADE_DESC",
      cog = { { type = "range", key = "units.@.oocAlpha", label = "UF_OOC_ALPHA", min = 0, max = 1, step = 0.05, percent = true } } }),
    ------------------------------------------------------------ health
    { type = "tab", label = "UF_TAB_HEALTH" },
    { type = "header", label = "UF_HEALTH_BAR", icon = "heart" },
    px({ type = "select", key = "units.@.bar.color", label = "UF_HEALTH_COLOR", desc = "UF_HEALTH_COLOR_DESC", values = HEALTH_COLOR,
      keywords = "class colour reaction gradient",
      cog = { { type = "color", key = "units.@.bar.fixed", label = "UF_FIXED_COLOR", token = "accent.primary", reset = true,
                classToken = true } } }),
    px({ type = "toggle", key = "units.@.bar.dark", label = "UF_DARK", desc = "UF_DARK_DESC", keywords = "dark mode inverted" }),
    px({ type = "range", key = "units.@.bar.gradient", label = "UF_SHADE", desc = "UF_SHADE_DESC", min = 0, max = 0.6, step = 0.05,
      percent = true }),
    px({ type = "toggle", key = "units.@.bar.smooth", label = "UF_SMOOTH", desc = "UF_SMOOTH_DESC" }),
    px({ type = "toggle", key = "units.@.bar.reverse", label = "UF_REVERSE", desc = "UF_REVERSE_DESC" }),
    px({ type = "toggle", key = "units.@.bar.vertical", label = "UF_VERTICAL" }),
    px({ type = "select", key = "units.@.bar.bg", label = "UF_BG", values = BG,
      cog = { { type = "range", key = "units.@.bar.bgAlpha", label = "BACKGROUND_OPACITY", min = 0, max = 1, step = 0.05,
                percent = true },
              { type = "color", key = "units.@.bar.bgColor", label = "BACKGROUND_COLOR", token = "bg.sunken", reset = true } } }),
    { type = "header", label = "UF_ABSORBS", icon = "lock" },
    px({ type = "toggle", key = "units.@.absorb.show", label = "UF_ABSORB", desc = "UF_ABSORB_DESC", keywords = "shield absorb overshield",
      cog = { { type = "select", key = "units.@.absorb.style", label = "UF_ABSORB_STYLE", values = ABSORB_STYLE },
              { type = "range", key = "units.@.absorb.alpha", label = "UF_ABSORB_ALPHA", min = 0.1, max = 1, step = 0.05,
                percent = true },
              { type = "select", key = "units.@.absorb.position", label = "UF_ABSORB_POSITION", values = ABSORB_POS } } }),
    px({ type = "toggle", key = "units.@.absorb.healAbsorb", label = "UF_HEAL_ABSORB", desc = "UF_HEAL_ABSORB_DESC" }),
    px({ type = "toggle", key = "units.@.absorb.prediction", label = "UF_PREDICTION", desc = "UF_PREDICTION_DESC",
      keywords = "incoming heals" }),
    { type = "header", label = "UF_COLORS", icon = "palette" },
    px({ type = "colors", keys = { "colors.high", "colors.mid", "colors.low" },
      tokens = { "state.success", "state.warning", "state.danger" }, label = "UF_GRADIENT", desc = "UF_GRADIENT_DESC",
      labels = { "UF_GRADIENT_HIGH", "UF_GRADIENT_MID", "UF_GRADIENT_LOW" } }),
    px({ type = "colors", keys = { "colors.tapped", "colors.dead", "colors.offline" },
      tokens = { "text.muted", "text.disabled", "text.disabled" }, label = "UF_STATE_COLORS",
      labels = { "UF_TAPPED", "UF_DEAD", "UF_OFFLINE" } }),
    px({ type = "colors", keys = { "colors.absorb", "colors.healAbsorb", "colors.myHeal" },
      tokens = { "text.primary", "state.danger", "state.success" }, label = "UF_PREDICT_COLORS",
      labels = { "UF_ABSORB", "UF_HEAL_ABSORB", "UF_PREDICTION" } }),
    px({ type = "color", key = "colors.fixed", label = "UF_THEME_COLOR", desc = "UF_THEME_COLOR_DESC", token = "bg.raised",
      reset = true, classToken = true }),
    ------------------------------------------------------------ power
    { type = "tab", label = "UF_TAB_POWER" },
    { type = "header", label = "UF_POWER_BAR", icon = "speed" },
    px({ type = "select", key = "units.@.powerBar.show", label = "UF_POWER_SHOW", values = POWER_SHOW, combat = true }),
    px({ type = "range", key = "units.@.powerBar.height", label = "UF_POWER_HEIGHT", min = 2, max = 30, step = 1, combat = true }),
    px({ type = "select", key = "units.@.powerBar.position", label = "UF_POWER_POSITION", values = POWER_POS, combat = true }),
    px({ type = "range", key = "units.@.powerBar.gap", label = "UF_POWER_GAP", min = 0, max = 8, step = 1, combat = true }),
    px({ type = "texture", key = "units.@.powerBar.texture", label = "UF_POWER_TEXTURE", allowDefault = true }),
    px({ type = "select", key = "units.@.powerBar.color", label = "UF_POWER_COLOR", values = POWER_COLOR,
      cog = { { type = "color", key = "units.@.powerBar.fixed", label = "UF_FIXED_COLOR", token = "accent.primary", reset = true,
                classToken = true } } }),
    px({ type = "toggle", key = "units.@.powerBar.smooth", label = "UF_SMOOTH", desc = "UF_SMOOTH_DESC" }),
    px({ type = "toggle", key = "units.@.powerBar.alt", label = "UF_ALT_POWER", desc = "UF_ALT_POWER_DESC",
      keywords = "alternate power encounter bar" }),
    { type = "header", label = "UF_CLASS_POWER", icon = "spec" },
    { type = "select", key = "classPower.show", label = "UF_CP_SHOW", desc = "UF_CP_SHOW_DESC", values = CP_SHOW,
      hidden = notPlayer, disabled = noClassPower, combat = true,
      keywords = "combo points holy power chi soul shards runes essence arcane charges stagger" },
    { type = "range", key = "classPower.height", label = "UF_CP_HEIGHT", min = 2, max = 24, step = 1, hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end, combat = true },
    { type = "range", key = "classPower.spacing", label = "UF_CP_SPACING", min = 0, max = 10, step = 1, hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end },
    { type = "select", key = "classPower.color", label = "UF_CP_COLOR", values = CP_COLOR, hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end },
    { type = "range", key = "classPower.emptyAlpha", label = "UF_CP_EMPTY", min = 0, max = 1, step = 0.05, percent = true,
      hidden = notPlayer, disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end },
    { type = "toggle", key = "classPower.runesSorted", label = "UF_CP_RUNES", desc = "UF_CP_RUNES_DESC", hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end },
    { type = "toggle", key = "classPower.stagger", label = "UF_CP_STAGGER", desc = "UF_CP_STAGGER_DESC", hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end },
    { type = "toggle", key = "classPower.hideFull", label = "UF_CP_HIDE_FULL", desc = "UF_CP_HIDE_FULL_DESC", hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end },
    Opt.With(Opt.Border("classPower.border", "UF_CP_BORDER"), { hidden = notPlayer, disabled = noClassPower }),
    { type = "color", key = "colors.charged", label = "UF_CHARGED", desc = "UF_CHARGED_DESC", token = "accent.primary", reset = true,
      hidden = notPlayer, disabled = noClassPower },
    ------------------------------------------------------------ text
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "UF_TAGS", icon = "fonts" },
    px({ type = "input", key = "units.@.tags.name", label = "UF_TAG_NAME", desc = "UF_TAGS_DESC", keywords = "tags oUF text format" }),
    px({ type = "input", key = "units.@.tags.health", label = "UF_TAG_HEALTH", desc = "UF_TAGS_DESC" }),
    px({ type = "input", key = "units.@.tags.power", label = "UF_TAG_POWER", desc = "UF_TAGS_DESC" }),
    px({ type = "input", key = "units.@.tags.info", label = "UF_TAG_INFO", desc = "UF_TAGS_DESC" }),
    { type = "description", text = "UF_TAGS_HELP", hidden = blizzard },
    { type = "header", label = "UF_TEXT", icon = "fonts" },
    bz({ type = "toggle", key = "fonts", label = "UF_FONTS", desc = "UF_FONTS_DESC", reload = true }),
    text("units.@.name", "UF_NAME_FONT"),
    text("units.@.health", "UF_HEALTH_FONT"),
    text("units.@.power", "UF_POWER_FONT"),
    text("units.@.info", "UF_INFO_FONT", { hidden = blizzard }),
    { type = "header", label = "UF_NAME", icon = "user" },
    px({ type = "range", key = "units.@.nameLength", label = "UF_NAME_LENGTH", desc = "UF_NAME_LENGTH_DESC", min = 4, max = 40, step = 1 }),
    px({ type = "select", key = "units.@.nameColor", label = "UF_NAME_COLOR", values = NAME_COLOR }),
    px({ type = "toggle", key = "units.@.hideFull", label = "UF_HIDE_FULL", desc = "UF_HIDE_FULL_DESC" }),
    { type = "header", label = "UF_NUMBERS", icon = "grid" },
    px({ type = "select", key = "numbers", label = "UF_NUMBERS_STYLE", desc = "UF_NUMBERS_STYLE_DESC", values = NUMBERS }),
    px({ type = "range", key = "decimals", label = "UF_DECIMALS", min = 0, max = 2, step = 1 }),
    px({ type = "range", key = "percentDecimals", label = "UF_PERCENT_DECIMALS", min = 0, max = 2, step = 1 }),
    ------------------------------------------------------------ portrait & auras
    { type = "tab", label = "UF_TAB_PORTRAIT" },
    { type = "header", label = "UF_PORTRAIT", icon = "user" },
    px({ type = "select", key = "units.@.portrait", label = "UF_PORTRAIT", desc = "UF_PORTRAIT_DESC2", values = PORTRAIT,
      keywords = "portrait class icon face 3d model" }),
    bz({ type = "select", key = "units.@.portrait", label = "UF_PORTRAIT", desc = "UF_PORTRAIT_DESC", values = LEGACY_PORTRAIT }),
    px({ type = "select", key = "units.@.portraitPos", label = "UF_PORTRAIT_POS", values = PORTRAIT_POS, combat = true }),
    px({ type = "select", key = "units.@.portraitShape", label = "UF_PORTRAIT_SHAPE", values = SHAPE }),
    px({ type = "range", key = "units.@.portraitZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 }),
    px({ type = "range", key = "units.@.portraitAlpha", label = "UF_PORTRAIT_ALPHA", min = 0.1, max = 1, step = 0.05, percent = true }),
    px(Opt.Border("units.@.portraitBorder", "UF_PORTRAIT_BORDER")),
    { type = "header", label = "UF_AURAS", icon = "auras" },
    px({ type = "select", key = "units.@.auras.buffs", label = "UF_BUFFS", values = AURA_POS, combat = true }),
    px({ type = "select", key = "units.@.auras.debuffs", label = "UF_DEBUFFS", values = AURA_POS, combat = true }),
    px({ type = "select", key = "units.@.auras.buffFilter", label = "UF_BUFF_FILTER", values = AURA_FILTER, disabled = auraOff }),
    px({ type = "select", key = "units.@.auras.debuffFilter", label = "UF_DEBUFF_FILTER", values = AURA_FILTER, disabled = auraOff }),
    px({ type = "range", key = "units.@.auras.size", label = "ICON_SIZE", min = 10, max = 48, step = 1, disabled = auraOff,
      combat = true }),
    px({ type = "range", key = "units.@.auras.max", label = "UF_AURA_MAX", min = 1, max = 32, step = 1, disabled = auraOff,
      combat = true }),
    px({ type = "range", key = "units.@.auras.perRow", label = "UF_AURA_PER_ROW", min = 1, max = 16, step = 1, disabled = auraOff,
      combat = true }),
    px({ type = "range", key = "units.@.auras.spacing", label = "ICON_SPACING", min = 0, max = 10, step = 1, disabled = auraOff,
      combat = true }),
    px({ type = "range", key = "units.@.auras.gap", label = "UF_AURA_GAP", min = 0, max = 20, step = 1, disabled = auraOff,
      combat = true }),
    px({ type = "select", key = "units.@.auras.growth", label = "ICON_GROWTH", values = AURA_GROW, disabled = auraOff, combat = true }),
    px({ type = "toggle", key = "units.@.auras.dispel", label = "UF_DISPEL", desc = "UF_DISPEL_DESC", disabled = auraOff }),
    px({ type = "toggle", key = "units.@.auras.desat", label = "UF_DESAT", desc = "UF_DESAT_DESC", disabled = auraOff }),
    px({ type = "range", key = "units.@.auras.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01, disabled = auraOff }),
    px({ type = "toggle", key = "units.@.auras.swipe", label = "UF_SWIPE", disabled = auraOff }),
    px({ type = "toggle", key = "units.@.auras.tooltips", label = "UF_AURA_TIPS", desc = "UF_AURA_TIPS_DESC", disabled = auraOff }),
    px(Opt.Border("units.@.auras.border", "UF_AURA_BORDER")),
    px(Opt.Text("units.@.auras.duration", "UF_AURA_DURATION_FONT", { place = true, show = true, max = 20 })),
    px(Opt.Text("units.@.auras.count", "UF_AURA_COUNT_FONT", { place = true, max = 20 })),
    ------------------------------------------------------------ indicators
    { type = "tab", label = "UF_TAB_INDICATORS" },
    { type = "header", label = "UF_ICONS", icon = "check" },
    { type = "toggle", key = "units.@.icons.marker", label = "UF_ICON_MARKER", keywords = "raid target skull",
      cog = { px({ type = "range", key = "units.@.icons.markerSize", label = "ICON_SIZE", min = 8, max = 40, step = 1 }),
              px({ type = "select", key = "units.@.icons.markerAnchor", label = "TEXT_POSITION", values = MARKER_ANCHOR }) } },
    { type = "toggle", key = "units.@.icons.leader", label = "UF_ICON_LEADER" },
    { type = "toggle", key = "units.@.icons.pvp", label = "UF_ICON_PVP" },
    px({ type = "toggle", key = "units.@.icons.role", label = "UF_ICON_ROLE", keywords = "tank healer damage" }),
    px({ type = "toggle", key = "units.@.icons.combat", label = "UF_ICON_COMBAT" }),
    px({ type = "toggle", key = "units.@.icons.resting", label = "UF_ICON_RESTING", hidden = notPlayer }),
    px({ type = "toggle", key = "units.@.icons.elite", label = "UF_ICON_ELITE", desc = "UF_ICON_ELITE_DESC" }),
    px({ type = "toggle", key = "units.@.icons.threat", label = "UF_ICON_THREAT", desc = "UF_ICON_THREAT_DESC", keywords = "aggro" }),
    px({ type = "toggle", key = "units.@.icons.ready", label = "UF_ICON_READY", desc = "UF_ICON_READY_DESC",
      keywords = "ready check summon resurrection" }),
    px({ type = "range", key = "units.@.icons.size", label = "UF_ICON_SIZE", min = 8, max = 32, step = 1 }),
    { type = "header", label = "UF_CAST", icon = "castbars" },
    { type = "select", key = "units.@.cast.attach", label = "UF_CAST_ATTACH", desc = "UF_CAST_ATTACH_DESC", values = CAST,
      disabled = noCast, hidden = castHidden,
      combat = true, keywords = "cast bar castbar anchor" },
    { type = "range", key = "units.@.cast.height", label = "UF_CAST_HEIGHT", min = 6, max = 40, step = 1, disabled = noCast,
      hidden = castHidden, combat = true },
    { type = "range", key = "units.@.cast.gap", label = "UF_CAST_GAP", min = 0, max = 20, step = 1, disabled = noCast,
      hidden = castHidden, combat = true },
    { type = "header", label = "UF_ARENA", icon = "pvp" },
    px({ type = "toggle", key = "units.@.trinket", label = "UF_TRINKET", desc = "UF_TRINKET_DESC", hidden = notArena }),
    px({ type = "toggle", key = "units.@.spec", label = "UF_SPEC", desc = "UF_SPEC_DESC", hidden = notArena }),
    { type = "description", text = "UF_ARENA_NOTE2" },
    ------------------------------------------------------------ Blizzard mode (the 2.0 skin)
    { type = "header", label = "UF_BLIZZARD_SKIN", icon = "skins" },
    bz({ type = "toggle", key = "texture", label = "UF_TEXTURE", desc = "UF_TEXTURE_DESC", reload = true }),
    bz({ type = "toggle", key = "classColor", label = "UF_CLASSCOLOR", desc = "UF_CLASSCOLOR_DESC", keywords = "class colour health" }),
    bz({ type = "toggle", key = "powerColor", label = "UF_POWERCOLOR", desc = "UF_POWERCOLOR_DESC" }),
    bz({ type = "toggle", key = "range.enabled", label = "UF_RANGE_FADE", desc = "UF_RANGE_FADE_DESC",
      cog = { { type = "range", key = "range.alpha", label = "UF_RANGE_ALPHA", min = 0.1, max = 0.9, step = 0.05, percent = true } } }),
    bz({ type = "header", label = "UF_AURAS", icon = "auras" }),
    bz({ type = "toggle", gate = true, key = "auras.style", label = "UF_AURAS_STYLE", desc = "UF_AURAS_STYLE_DESC", reload = true,
      cog = { { type = "range", key = "auras.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } }),
    bz(Opt.With(Opt.Border("auras.border"), { disabled = legacyAuras })),
    bz(Opt.Text("auras.count", "UF_AURA_COUNT_FONT", { max = 20, row = { disabled = legacyAuras } })),
    { type = "description", text = "UF_EDITMODE_NOTE", hidden = phoenix },
    { type = "description", text = "UF_BLIZZARD_NOTE", hidden = blizzard },
})
