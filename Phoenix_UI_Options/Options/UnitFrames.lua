local _, ns = ...
local Opt = ns.Opt

--[[ Unit Frames (plan v2 S8). Most rows act on Phoenix's own frames ("Frames owned by: Phoenix"); the rows of the
    2.0 Blizzard skin show in Blizzard mode only. Rows that only make sense for some frames hide for the others
    (stacking for boss/arena, class resource for the player, cast bar anchor for target/focus/boss/arena). ]]
local function blizzard(m) return m.db.mode ~= "phoenix" end
local function phoenix(m) return m.db.mode == "phoenix" end
local function notGroup(_, unit) return unit ~= "boss" and unit ~= "arena" and unit ~= "arenapet" end
local function notPlayer(_, unit) return unit ~= "player" end
local function notArena(_, unit) return unit ~= "arena" end
local function notArenaPet(_, unit) return unit ~= "arenapet" end
local function notArenaAny(_, unit) return unit ~= "arena" and unit ~= "arenapet" end
local function drOff(m) return not m.db.units.arena.dr.show end
local function resOff(m) return not m.db.resources.enabled end
local function totemsOff(m) return m.db.totems.style ~= "phoenix" end
local function imbuesOff(m) return not m.db.imbues.show end
local function stripOff(m, unit) return not m.db.units[unit or "player"].strip.show end
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
local CP_SHAPE = { { value = "bar", label = "UF_CP_SHAPE_BAR" }, { value = "square", label = "AB_SHAPE_SQUARE" },
    { value = "round", label = "AB_SHAPE_CIRCLE" } }
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

local POWER_DIR = { { value = "RIGHT", label = "GROW_RIGHT" }, { value = "LEFT", label = "GROW_LEFT" },
    { value = "CENTER", label = "ANCHOR_CENTER" } }
local POWER_GRADIENT = { { value = "none", label = "GRADIENT_NONE" }, { value = "horizontal", label = "GRADIENT_HORIZONTAL" },
    { value = "vertical", label = "GRADIENT_VERTICAL" } }
local CP_ORIENT = { { value = "HORIZONTAL", label = "UF_CP_HORIZONTAL" }, { value = "VERTICAL", label = "UF_CP_VERTICAL" } }
local ARENA_LAYOUT = {
    { value = "phoenix", label = "UF_ARENA_LAYOUT_PHOENIX" }, { value = "mirrored", label = "UF_ARENA_LAYOUT_MIRRORED" },
    { value = "compact", label = "UF_ARENA_LAYOUT_COMPACT" }, { value = "tall", label = "UF_ARENA_LAYOUT_TALL" },
    { value = "wide", label = "UF_ARENA_LAYOUT_WIDE" }, { value = "slim", label = "UF_ARENA_LAYOUT_SLIM" },
    { value = "portrait", label = "UF_ARENA_LAYOUT_PORTRAIT" }, { value = "gladiator", label = "UF_ARENA_LAYOUT_GLADIATOR" },
    { value = "cropped", label = "UF_ARENA_LAYOUT_CROPPED" },
}
local CLICK = { { value = "target", label = "UF_CLICK_TARGET" }, { value = "focus", label = "UF_CLICK_FOCUS" },
    { value = "togglemenu", label = "UF_CLICK_MENU" }, { value = "spell", label = "UF_CLICK_SPELL" },
    { value = "macro", label = "UF_CLICK_MACRO" }, { value = "none", label = "UF_CLICK_NONE" } }
local QUICK_KEY = { { value = "none", label = "OFF" }, { value = "shift", label = "UF_KEY_SHIFT" },
    { value = "ctrl", label = "UF_KEY_CTRL" }, { value = "alt", label = "UF_KEY_ALT" } }
local MARKER = {
    { value = 0, label = "UF_MARKER_NONE" }, { value = 1, label = "UF_MARKER_1" }, { value = 2, label = "UF_MARKER_2" },
    { value = 3, label = "UF_MARKER_3" }, { value = 4, label = "UF_MARKER_4" }, { value = 5, label = "UF_MARKER_5" },
    { value = 6, label = "UF_MARKER_6" }, { value = 7, label = "UF_MARKER_7" }, { value = 8, label = "UF_MARKER_8" },
}
local TOTEM_STYLE = { { value = "blizzard", label = "UF_TOTEMS_BLIZZARD" }, { value = "phoenix", label = "UF_TOTEMS_PHOENIX" },
    { value = "off", label = "OFF" } }
local PREVIEW_CLASS = {
    { value = "", label = "UF_RES_PREVIEW_MINE" }, { value = "WARRIOR", label = "UF_CLASS_WARRIOR" },
    { value = "PALADIN", label = "UF_CLASS_PALADIN" }, { value = "HUNTER", label = "UF_CLASS_HUNTER" },
    { value = "ROGUE", label = "UF_CLASS_ROGUE" }, { value = "PRIEST", label = "UF_CLASS_PRIEST" },
    { value = "DEATHKNIGHT", label = "UF_CLASS_DEATHKNIGHT" }, { value = "SHAMAN", label = "UF_CLASS_SHAMAN" },
    { value = "MAGE", label = "UF_CLASS_MAGE" }, { value = "WARLOCK", label = "UF_CLASS_WARLOCK" },
    { value = "MONK", label = "UF_CLASS_MONK" }, { value = "DRUID", label = "UF_CLASS_DRUID" },
    { value = "DEMONHUNTER", label = "UF_CLASS_DEMONHUNTER" }, { value = "EVOKER", label = "UF_CLASS_EVOKER" },
}

local UNITS = {}
for _, key in ipairs({ "player", "target", "targettarget", "focus", "focustarget", "pet", "boss", "arena", "arenapet" }) do
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
    px({ type = "select", key = "units.@.layout", label = "UF_ARENA_LAYOUT", desc = "UF_ARENA_LAYOUT_DESC", values = ARENA_LAYOUT,
      combat = true, hidden = notArena, feature = "arena", keywords = "sarena layout preset gladius style" }),
    px({ type = "toggle", key = "units.@.mirrored", label = "UF_MIRRORED", desc = "UF_MIRRORED_DESC", combat = true,
      hidden = notArena, feature = "arena", keywords = "mirror flip left right" }),
    px({ type = "range", key = "units.@.testCount", label = "UF_TEST_COUNT", desc = "UF_TEST_COUNT_DESC", min = 2, max = 5, step = 1,
      combat = true, hidden = notArena, feature = "arena", keywords = "2v2 3v3 5v5 test" }),
    px({ type = "toggle", key = "units.@.attach", label = "UF_PET_ATTACH", desc = "UF_PET_ATTACH_DESC", combat = true,
      hidden = notArenaPet, feature = "arena", keywords = "arena pet beside" }),
    { type = "header", label = "UF_POSITION", icon = "movers" },
    px({ type = "select", key = "units.@.point", single = true, label = "UF_POINT", values = Opt.ANCHOR, combat = true }),
    px({ type = "range", key = "units.@.x", single = true, label = "OFFSET_X", min = -1200, max = 1200, step = 1, combat = true }),
    px({ type = "range", key = "units.@.y", single = true, label = "OFFSET_Y", min = -800, max = 800, step = 1, combat = true }),
    { type = "header", label = "UF_LOOK", icon = "border" },
    { type = "texture", key = "units.@.texture", label = "BAR_TEXTURE", allowDefault = true,
      disabled = function(m) return blizzard(m) and not m.db.texture end, keywords = "statusbar texture" },
    Opt.Border("units.@.border", "UF_BORDER"),
    Opt.Background("units.@.background"),
    px({ type = "texture", key = "units.@.bgTexture", label = "UF_BG_TEXTURE", desc = "UF_BG_TEXTURE_DESC", allowDefault = true,
      keywords = "frame background texture" }),
    px({ type = "toggle", key = "units.@.highlight", label = "UF_HIGHLIGHT", desc = "UF_HIGHLIGHT_DESC" }),
    px({ type = "toggle", key = "units.@.targetBorder", label = "UF_TARGET_BORDER", desc = "UF_TARGET_BORDER_DESC",
      hidden = function(_, u) return u == "target" end }),
    px({ type = "select", key = "units.@.tooltip", label = "UF_TOOLTIP", values = TOOLTIP }),
    -- Phoenix frames are SecureUnitButtons: Blizzard's own click bindings (and Clique) already act on them
    { type = "button", label = "UF_CLICK_CAST", desc = "UF_CLICK_CAST_DESC", button = "UF_CLICK_CAST_BUTTON", icon = "link",
      keywords = "click casting click cast bindings mouseover heal clique",
      func = function() if ToggleClickBindingFrame then ToggleClickBindingFrame() end end },
    px({ type = "toggle", key = "units.@.strip.show", label = "UF_STRIP", desc = "UF_STRIP_DESC", combat = true,
      keywords = "text strip info bar under frame",
      cog = { { type = "range", key = "units.@.strip.height", label = "UF_STRIP_HEIGHT", min = 8, max = 30, step = 1 },
              { type = "range", key = "units.@.strip.gap", label = "UF_STRIP_GAP", min = 0, max = 10, step = 1 },
              { type = "input", key = "units.@.strip.tag", label = "UF_STRIP_TAG", desc = "UF_TAGS_DESC" } } }),
    px(Opt.Text("units.@.strip.text", "UF_STRIP_FONT", { place = true, max = 20, row = { disabled = stripOff } })),
    { type = "header", label = "UF_FOCUS_QUICK", icon = "keyboard" },
    px({ type = "select", key = "quickFocus.key", label = "UF_QUICK_FOCUS", desc = "UF_QUICK_FOCUS_DESC", values = QUICK_KEY,
      combat = true, keywords = "quick focus shift click set focus" }),
    px({ type = "select", key = "quickFocus.marker", label = "UF_QUICK_MARKER", desc = "UF_QUICK_MARKER_DESC", values = MARKER,
      combat = true, disabled = function(m) return m.db.quickFocus.key == "none" end, keywords = "raid marker focus" }),
    px({ type = "input", key = "nicknames", label = "UF_NICKNAMES", desc = "UF_NICKNAMES_DESC", keywords = "nickname rename alias" }),
    { type = "header", label = "UF_FADING", icon = "opacity" },
    px({ type = "toggle", key = "units.@.rangeFade", label = "UF_RANGE_FADE", desc = "UF_RANGE_FADE_DESC2",
      hidden = function(_, u) return u == "player" end, keywords = "out of range alpha fade",
      cog = { { type = "range", key = "units.@.rangeAlpha", label = "UF_RANGE_ALPHA", min = 0.1, max = 0.9, step = 0.05,
                percent = true },
              { type = "input", key = "units.@.rangeSpell", label = "UF_RANGE_SPELL", desc = "UF_RANGE_SPELL_DESC" } } }),
    px({ type = "range", key = "units.@.stealthAlpha", label = "UF_STEALTH_ALPHA", desc = "UF_STEALTH_ALPHA_DESC", min = 0.1, max = 1,
      step = 0.05, percent = true, hidden = notArena, feature = "arena", keywords = "stealth unseen fade" }),
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
    px({ type = "range", key = "units.@.bar.share", label = "UF_HEALTH_SHARE", desc = "UF_HEALTH_SHARE_DESC", min = 0.4, max = 1,
      step = 0.05, percent = true, combat = true, keywords = "health power ratio split height" }),
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
    px({ type = "range", key = "units.@.absorb.overheal", label = "UF_OVERHEAL", desc = "UF_OVERHEAL_DESC", min = 0, max = 0.5,
      step = 0.05, percent = true, keywords = "overheal overflow incoming heals past full",
      disabled = function(m, u) return not m.db.units[u or "player"].absorb.prediction end }),
    { type = "header", label = "UF_COLORS", icon = "palette" },
    px({ type = "colors", keys = { "colors.high", "colors.mid", "colors.low" },
      tokens = { "state.success", "state.warning", "state.danger" }, label = "UF_GRADIENT", desc = "UF_GRADIENT_DESC",
      labels = { "UF_GRADIENT_HIGH", "UF_GRADIENT_MID", "UF_GRADIENT_LOW" } }),
    px({ type = "colors", keys = { "colors.tapped", "colors.dead", "colors.offline" },
      tokens = { "text.muted", "text.disabled", "text.disabled" }, label = "UF_STATE_COLORS",
      labels = { "UF_TAPPED", "UF_DEAD", "UF_OFFLINE" } }),
    px({ type = "colors", keys = { "colors.absorb", "colors.healAbsorb", "colors.myHeal", "colors.otherHeal" },
      tokens = { "text.primary", "state.danger", "state.success", "state.info" }, label = "UF_PREDICT_COLORS",
      labels = { "UF_ABSORB", "UF_HEAL_ABSORB", "UF_PREDICT_MINE", "UF_PREDICT_OTHER" } }),
    px({ type = "colors", keys = { "colors.cc", "colors.defensive", "colors.important", "colors.focus" },
      tokens = { "state.danger", "state.success", "state.warning", "state.info" }, label = "UF_ARENA_COLORS",
      desc = "UF_ARENA_COLORS_DESC", labels = { "UF_COLOR_CC", "UF_COLOR_DEFENSIVE", "UF_COLOR_IMPORTANT", "UF_COLOR_FOCUS" },
      feature = "arena" }),
    px({ type = "color", key = "colors.fixed", label = "UF_THEME_COLOR", desc = "UF_THEME_COLOR_DESC", token = "bg.raised",
      reset = true, classToken = true }),
    ------------------------------------------------------------ power
    { type = "tab", label = "UF_TAB_POWER" },
    { type = "header", label = "UF_POWER_BAR", icon = "speed" },
    px({ type = "select", key = "units.@.powerBar.show", label = "UF_POWER_SHOW", values = POWER_SHOW, combat = true }),
    px({ type = "range", key = "units.@.powerBar.height", label = "UF_POWER_HEIGHT", min = 2, max = 30, step = 1, combat = true }),
    px({ type = "select", key = "units.@.powerBar.position", label = "UF_POWER_POSITION", values = POWER_POS, combat = true }),
    px({ type = "range", key = "units.@.powerBar.gap", label = "UF_POWER_GAP", min = 0, max = 8, step = 1, combat = true }),
    px({ type = "range", key = "units.@.powerBar.width", label = "UF_POWER_WIDTH", desc = "UF_POWER_WIDTH_DESC", min = 0, max = 400,
      step = 1, combat = true, keywords = "power bar width detached narrow" }),
    px({ type = "select", key = "units.@.powerBar.direction", label = "UF_POWER_DIRECTION", desc = "UF_POWER_DIRECTION_DESC",
      values = POWER_DIR, keywords = "fill direction reverse centre" }),
    px({ type = "select", key = "units.@.powerBar.gradient", label = "UF_POWER_GRADIENT", values = POWER_GRADIENT }),
    px({ type = "texture", key = "units.@.powerBar.texture", label = "UF_POWER_TEXTURE", allowDefault = true }),
    px({ type = "select", key = "units.@.powerBar.color", label = "UF_POWER_COLOR", values = POWER_COLOR,
      cog = { { type = "color", key = "units.@.powerBar.fixed", label = "UF_FIXED_COLOR", token = "accent.primary", reset = true,
                classToken = true } } }),
    px({ type = "toggle", key = "units.@.powerBar.smooth", label = "UF_SMOOTH", desc = "UF_SMOOTH_DESC" }),
    px({ type = "toggle", key = "units.@.powerBar.alt", label = "UF_ALT_POWER", desc = "UF_ALT_POWER_DESC",
      keywords = "alternate power encounter bar" }),
    px({ type = "toggle", key = "units.@.powerBar.cost", label = "UF_COST", desc = "UF_COST_DESC", hidden = notPlayer,
      keywords = "spell cost prediction mana cost power" }),
    { type = "header", label = "UF_CLASS_POWER", icon = "spec" },
    { type = "select", key = "classPower.show", label = "UF_CP_SHOW", desc = "UF_CP_SHOW_DESC", values = CP_SHOW,
      hidden = notPlayer, disabled = noClassPower, combat = true,
      keywords = "combo points holy power chi soul shards runes essence arcane charges stagger" },
    { type = "range", key = "classPower.height", label = "UF_CP_HEIGHT", min = 2, max = 24, step = 1, hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end, combat = true },
    { type = "select", key = "classPower.shape", label = "UF_CP_SHAPE", values = CP_SHAPE, hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end, keywords = "pip shape round square circle" },
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
    { type = "select", key = "classPower.orientation", label = "UF_CP_ORIENT", values = CP_ORIENT, hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end, keywords = "vertical class power" },
    { type = "toggle", key = "classPower.separators", label = "UF_CP_SEPARATORS", desc = "UF_CP_SEPARATORS_DESC",
      hidden = notPlayer, disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end },
    { type = "range", key = "classPower.threshold", label = "UF_CP_THRESHOLD", desc = "UF_CP_THRESHOLD_DESC", min = 0, max = 10,
      step = 1, hidden = notPlayer, disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end,
      cog = { { type = "color", key = "colors.threshold", label = "UF_CP_THRESHOLD_COLOR", token = "state.warning", reset = true } } },
    { type = "toggle", key = "classPower.fade", label = "UF_CP_FADE", desc = "UF_CP_FADE_DESC", hidden = notPlayer,
      disabled = function(m, u) return noClassPower(m, u) or cpOff(m) end, keywords = "fade out of combat empty" },
    Opt.With(Opt.Text("classPower.text", "UF_CP_TEXT", { place = true, show = true, max = 20 }),
      { hidden = notPlayer, disabled = noClassPower }),
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
    { type = "description", text = "UF_TAGS_HELP2", hidden = blizzard },
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
    px({ type = "range", key = "units.@.portraitSize", label = "UF_PORTRAIT_SIZE", desc = "UF_PORTRAIT_SIZE_DESC", min = 0.5,
      max = 2, step = 0.05, percent = true, combat = true,
      disabled = function(m, u) local x = m.db.units[u or "player"]; return x.portrait == "hide" or x.portraitPos == "overlay" end }),
    px({ type = "range", key = "units.@.portraitZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 }),
    px({ type = "range", key = "units.@.portraitAlpha", label = "UF_PORTRAIT_ALPHA", min = 0.1, max = 1, step = 0.05, percent = true }),
    px(Opt.Border("units.@.portraitBorder", "UF_PORTRAIT_BORDER")),
    px({ type = "toggle", key = "units.@.portraitRing", label = "UF_PORTRAIT_RING", desc = "UF_PORTRAIT_RING_DESC",
      keywords = "portrait ring circle class colour" }),
    px({ type = "toggle", key = "units.@.portraitArt", label = "UF_PORTRAIT_ART", desc = "UF_PORTRAIT_ART_DESC",
      hidden = function(_, u) return u == "player" end, keywords = "elite rare dragon wings boss art" }),
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
    px({ type = "toggle", key = "units.@.racial", label = "UF_RACIAL", desc = "UF_RACIAL_DESC", hidden = notArena, feature = "arena",
      keywords = "racial every man for himself will of the forsaken" }),
    px({ type = "toggle", key = "units.@.classIcon", label = "UF_CLASS_ICON", desc = "UF_CLASS_ICON_DESC", hidden = notArena,
      feature = "arena", keywords = "class icon",
      cog = { { type = "range", key = "units.@.iconZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } }),
    px({ type = "toggle", key = "units.@.classIconAuras", label = "UF_CLASS_ICON_AURAS", desc = "UF_CLASS_ICON_AURAS_DESC",
      hidden = notArena, feature = "arena", keywords = "crowd control defensive immunity on class icon",
      disabled = function(m) return not m.db.units.arena.classIcon end,
      cog = { { type = "toggle", key = "units.@.auraGlow", label = "UF_AURA_GLOW" } } }),
    { type = "header", label = "UF_DR", icon = "spec", hidden = notArena, feature = "arena" },
    px({ type = "toggle", key = "units.@.dr.show", label = "UF_DR_SHOW", desc = "UF_DR_SHOW_DESC", hidden = notArena,
      feature = "arena", keywords = "diminishing returns dr tracker stun fear incap" }),
    px({ type = "range", key = "units.@.dr.size", label = "ICON_SIZE", min = 14, max = 48, step = 1, hidden = notArena,
      feature = "arena", disabled = drOff }),
    px({ type = "range", key = "units.@.dr.spacing", label = "ICON_SPACING", min = 0, max = 10, step = 1, hidden = notArena,
      feature = "arena", disabled = drOff }),
    px({ type = "range", key = "units.@.dr.gap", label = "UF_DR_GAP", min = 0, max = 30, step = 1, hidden = notArena,
      feature = "arena", disabled = drOff }),
    px({ type = "range", key = "units.@.dr.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01, hidden = notArena,
      feature = "arena", disabled = drOff }),
    px({ type = "toggle", key = "units.@.dr.immune", label = "UF_DR_IMMUNE", desc = "UF_DR_IMMUNE_DESC", hidden = notArena,
      feature = "arena", disabled = drOff }),
    px({ type = "toggle", key = "units.@.dr.mineOnly", label = "UF_DR_MINE", desc = "UF_DR_MINE_DESC", hidden = notArena,
      feature = "arena", disabled = drOff }),
    px(Opt.With(Opt.Border("units.@.dr.border", "UF_DR_BORDER"), { hidden = notArena, feature = "arena", disabled = drOff })),
    px(Opt.Text("units.@.dr.text", "UF_DR_FONT", { place = true, max = 20,
      row = { hidden = notArena, feature = "arena", disabled = drOff } })),
    { type = "header", label = "UF_WIDGETS", icon = "check", hidden = notArena, feature = "arena" },
    px({ type = "toggle", key = "units.@.widgets.healer", label = "UF_WIDGET_HEALER", desc = "UF_WIDGET_HEALER_DESC",
      hidden = notArena, feature = "arena" }),
    px({ type = "toggle", key = "units.@.widgets.focus", label = "UF_WIDGET_FOCUS", desc = "UF_WIDGET_FOCUS_DESC",
      hidden = notArena, feature = "arena" }),
    px({ type = "toggle", key = "units.@.widgets.targets", label = "UF_WIDGET_TARGETS", desc = "UF_WIDGET_TARGETS_DESC",
      hidden = notArena, feature = "arena", keywords = "targeted by party pips" }),
    { type = "header", label = "UF_CLICKS", icon = "keyboard", hidden = notArenaAny, feature = "arena" },
    px({ type = "select", key = "units.@.click.left", label = "UF_CLICK_LEFT", values = CLICK, combat = true, hidden = notArena,
      feature = "arena", keywords = "click action left right middle",
      cog = { { type = "input", key = "units.@.click.leftText", label = "UF_CLICK_TEXT", desc = "UF_CLICK_TEXT_DESC" } } }),
    px({ type = "select", key = "units.@.click.right", label = "UF_CLICK_RIGHT", values = CLICK, combat = true, hidden = notArena,
      feature = "arena",
      cog = { { type = "input", key = "units.@.click.rightText", label = "UF_CLICK_TEXT", desc = "UF_CLICK_TEXT_DESC" } } }),
    px({ type = "select", key = "units.@.click.middle", label = "UF_CLICK_MIDDLE", values = CLICK, combat = true, hidden = notArena,
      feature = "arena",
      cog = { { type = "input", key = "units.@.click.middleText", label = "UF_CLICK_TEXT", desc = "UF_CLICK_TEXT_DESC" } } }),
    { type = "description", text = "UF_ARENA_NOTE3" },
    ------------------------------------------------------------ resources (detached player bars, totems)
    { type = "tab", label = "UF_TAB_RESOURCES" },
    { type = "header", label = "UF_RESOURCES", icon = "speed" },
    px({ type = "toggle", gate = true, key = "resources.enabled", label = "UF_RES_ENABLE", desc = "UF_RES_ENABLE_DESC", combat = true,
      keywords = "personal resource display detached bars weakaura health power" }),
    px({ type = "select", key = "resources.previewClass", label = "UF_RES_PREVIEW", desc = "UF_RES_PREVIEW_DESC",
      values = PREVIEW_CLASS, disabled = resOff }),
    px({ type = "range", key = "resources.width", label = "UF_WIDTH", min = 80, max = 500, step = 1, combat = true, disabled = resOff }),
    px({ type = "range", key = "resources.spacing", label = "UF_RES_SPACING", min = 0, max = 10, step = 1, combat = true,
      disabled = resOff }),
    px({ type = "range", key = "resources.scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, combat = true, disabled = resOff }),
    px({ type = "select", key = "resources.strata", label = "FRAME_STRATA", values = Opt.STRATA, combat = true, disabled = resOff }),
    px({ type = "select", key = "resources.point", label = "UF_POINT", values = Opt.ANCHOR, combat = true, disabled = resOff }),
    px({ type = "range", key = "resources.x", label = "OFFSET_X", min = -1200, max = 1200, step = 1, combat = true, disabled = resOff }),
    px({ type = "range", key = "resources.y", label = "OFFSET_Y", min = -800, max = 800, step = 1, combat = true, disabled = resOff }),
    px({ type = "texture", key = "resources.texture", label = "BAR_TEXTURE", allowDefault = true, disabled = resOff }),
    px(Opt.With(Opt.Border("resources.border", "UF_BORDER"), { disabled = resOff })),
    px(Opt.With(Opt.Background("resources.background"), { disabled = resOff })),
    px({ type = "toggle", key = "resources.collapse", label = "UF_RES_COLLAPSE", desc = "UF_RES_COLLAPSE_DESC", disabled = resOff }),
    px({ type = "toggle", key = "resources.combatOnly", label = "UF_RES_COMBAT", desc = "UF_RES_COMBAT_DESC", disabled = resOff,
      cog = { { type = "range", key = "resources.oocAlpha", label = "UF_OOC_ALPHA", min = 0, max = 1, step = 0.05, percent = true } } }),
    { type = "header", label = "UF_RES_ROWS", icon = "layout" },
    px({ type = "toggle", key = "resources.health.show", label = "UF_RES_HEALTH", disabled = resOff,
      cog = { { type = "range", key = "resources.health.height", label = "UF_HEIGHT", min = 4, max = 40, step = 1 },
              { type = "input", key = "resources.health.tag", label = "UF_TAG_HEALTH", desc = "UF_TAGS_DESC" } } }),
    px(Opt.Text("resources.health.text", "UF_HEALTH_FONT", { place = true, max = 24, row = { disabled = resOff } })),
    px({ type = "toggle", key = "resources.power.show", label = "UF_RES_POWER", disabled = resOff,
      cog = { { type = "range", key = "resources.power.height", label = "UF_HEIGHT", min = 2, max = 30, step = 1 },
              { type = "input", key = "resources.power.tag", label = "UF_TAG_POWER", desc = "UF_TAGS_DESC" },
              { type = "toggle", key = "resources.power.mana", label = "UF_RES_MANA", desc = "UF_RES_MANA_DESC" } } }),
    px(Opt.Text("resources.power.text", "UF_POWER_FONT", { place = true, max = 24, row = { disabled = resOff } })),
    px({ type = "toggle", key = "resources.class.show", label = "UF_RES_CLASS", desc = "UF_RES_CLASS_DESC", disabled = resOff,
      cog = { { type = "range", key = "resources.class.height", label = "UF_HEIGHT", min = 2, max = 24, step = 1 } } }),
    px({ type = "toggle", key = "resources.spec.show", label = "UF_RES_SPEC", desc = "UF_RES_SPEC_DESC", disabled = resOff,
      feature = "specBars", keywords = "ironfur ignore pain soul fragments ebon might sweeping strikes",
      cog = { { type = "range", key = "resources.spec.height", label = "UF_HEIGHT", min = 2, max = 24, step = 1 } } }),
    { type = "header", label = "UF_TOTEMS", icon = "grid" },
    px({ type = "select", key = "totems.style", label = "UF_TOTEMS_STYLE", desc = "UF_TOTEMS_STYLE_DESC", values = TOTEM_STYLE,
      combat = true, keywords = "totem bar guardians destroy right click" }),
    px({ type = "range", key = "totems.size", label = "ICON_SIZE", min = 16, max = 64, step = 1, combat = true, disabled = totemsOff }),
    px({ type = "range", key = "totems.spacing", label = "ICON_SPACING", min = 0, max = 16, step = 1, combat = true,
      disabled = totemsOff }),
    px({ type = "select", key = "totems.growth", label = "ICON_GROWTH", values = Opt.GROWTH, combat = true, disabled = totemsOff }),
    px({ type = "range", key = "totems.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01, disabled = totemsOff }),
    px({ type = "select", key = "totems.point", label = "UF_POINT", values = Opt.ANCHOR, combat = true, disabled = totemsOff }),
    px({ type = "range", key = "totems.x", label = "OFFSET_X", min = -1200, max = 1200, step = 1, combat = true, disabled = totemsOff }),
    px({ type = "range", key = "totems.y", label = "OFFSET_Y", min = -800, max = 800, step = 1, combat = true, disabled = totemsOff }),
    px(Opt.With(Opt.Border("totems.border", "UF_BORDER"), { disabled = totemsOff })),
    px(Opt.Text("totems.duration", "UF_TOTEMS_FONT", { place = true, max = 24, row = { disabled = totemsOff } })),
    { type = "header", label = "UF_IMBUES", icon = "grid" },
    px({ type = "toggle", key = "imbues.show", label = "UF_IMBUES_SHOW", desc = "UF_IMBUES_DESC",
      keywords = "weapon enchant poison oil sharpening stone windfury flametongue" }),
    px({ type = "range", key = "imbues.size", label = "ICON_SIZE", min = 16, max = 64, step = 1, disabled = imbuesOff }),
    px({ type = "range", key = "imbues.spacing", label = "ICON_SPACING", min = 0, max = 16, step = 1, disabled = imbuesOff }),
    px({ type = "range", key = "imbues.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01, disabled = imbuesOff }),
    px({ type = "select", key = "imbues.point", label = "UF_POINT", values = Opt.ANCHOR, disabled = imbuesOff }),
    px({ type = "range", key = "imbues.x", label = "OFFSET_X", min = -1200, max = 1200, step = 1, disabled = imbuesOff }),
    px({ type = "range", key = "imbues.y", label = "OFFSET_Y", min = -800, max = 800, step = 1, disabled = imbuesOff }),
    px(Opt.Text("imbues.text", "UF_IMBUES_FONT", { max = 24, row = { disabled = imbuesOff } })),
    { type = "description", text = "UF_RES_NOTE" },
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
