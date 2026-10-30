local _, ns = ...
local Opt = ns.Opt

--[[ Nameplates (plan v2 S10). The scope bar picks the plate kind (enemy / friendly) for the per-kind rows
    ("styles.@…"); colours, target effects, execute, click area and contexts are shared. Rows of the Game tab write
    client CVars (account-wide, not part of the profile). The 2.0 Blizzard restyle's rows show in Blizzard mode only. ]]
local function blizzard(m) return m.db.mode ~= "phoenix" end
local function phoenix(m) return m.db.mode == "phoenix" end
local function enemyOnly(_, u) return (u or "enemy") ~= "enemy" end
local function friendlyOnly(_, u) return (u or "enemy") ~= "friendly" end
local function style(m, u) return m.db.styles[u or "enemy"] end
local function castOff(m, u) return blizzard(m) or not style(m, u).cast.enabled end
local function noClick(m) return blizzard(m) or not m.db.click.enabled end
local function noThreat(m) return not m.db.threat.enabled end
local function noExecute(m) return blizzard(m) or not m.db.execute.enabled end
local function noContexts(m) return blizzard(m) or not m.db.contexts.enabled end
local function noHealthText(m) return not m.db.healthText end
local function nameUnstyled(m) return not m.db.name.styled end
local function noCast(m) return not m.db.castbar.style end
local function noAuras(m) return not m.db.auras.style end

local MODE = { { value = "phoenix", label = "NP_MODE_PHOENIX" }, { value = "blizzard", label = "NP_MODE_BLIZZARD" } }
local KINDS = { { value = "enemy", label = "NP_ENEMY" }, { value = "friendly", label = "NP_FRIENDLY" } }
local COLOR = { { value = "reaction", label = "UF_COLOR_REACTION" }, { value = "class", label = "UF_COLOR_CLASS" },
    { value = "health", label = "UF_COLOR_HEALTH" }, { value = "fixed", label = "UF_COLOR_FIXED" } }
local NAME_COLOR = { { value = "reaction", label = "UF_COLOR_REACTION" }, { value = "class", label = "UF_COLOR_CLASS" },
    { value = "white", label = "UF_COLOR_WHITE" } }
local ROLE = { { value = "auto", label = "NP_ROLE_AUTO" }, { value = "tank", label = "NP_ROLE_TANK" },
    { value = "dps", label = "NP_ROLE_DPS" } }
local EFFECT = { { value = "glow", label = "BORDER_GLOW" }, { value = "border", label = "BORDER_SOLID" },
    { value = "arrows", label = "NP_EFFECT_ARROWS" }, { value = "none", label = "OFF" } }
local DEBUFFS = { { value = "mine", label = "UF_FILTER_MINE" }, { value = "important", label = "NP_FILTER_IMPORTANT" },
    { value = "all", label = "UF_FILTER_ALL" }, { value = "off", label = "OFF" } }
local BUFFS = { { value = "purgeable", label = "NP_FILTER_PURGEABLE" }, { value = "important", label = "NP_FILTER_IMPORTANT" },
    { value = "all", label = "UF_FILTER_ALL" }, { value = "off", label = "OFF" } }
local MARKER = { { value = "LEFT", label = "ANCHOR_LEFT" }, { value = "TOP", label = "ANCHOR_TOP" },
    { value = "RIGHT", label = "ANCHOR_RIGHT" } }
local ICON = { { value = "left", label = "ANCHOR_LEFT" }, { value = "right", label = "ANCHOR_RIGHT" }, { value = "off", label = "OFF" } }
local TIME = { { value = "remaining", label = "CB_TIME_REMAINING" }, { value = "elapsed", label = "CB_TIME_ELAPSED" },
    { value = "both", label = "CB_TIME_BOTH" }, { value = "none", label = "CB_TIME_NONE" } }
local FRIENDLY = { { value = "show", label = "NP_CTX_SHOW" }, { value = "name", label = "NP_CTX_NAME" },
    { value = "hide", label = "NP_CTX_HIDE" } }

local function toggleTest(m)
    if not m:IsEnabled() then return end
    m:ShowTest(not m.testShown)
end

-- Phoenix-mode rows: greyed out while Blizzard draws the plates.
local function px(row, extra)
    local d = row.disabled
    row.disabled = d and function(m, u) return blizzard(m) or d(m, u) end or blizzard
    return Opt.With(row, extra)
end
local function cx(row) return px(row, { disabled = castOff }) end
local function bz(row) return Opt.With(row, { hidden = phoenix }) end

-- client CVar rows (written out of combat)
local function cvar(name, kind, row)
    local get, set = ns.Combat.CVarAccessors(name, kind)
    return Opt.With({ type = kind == "number" and "range" or "toggle", get = get, set = set, combat = true }, row)
end
local function stacking(index, row)
    local function idx()
        local t = Enum.NamePlateStackType
        return t and t[index] or (index == "Enemy" and 1 or 2)
    end
    local m = ns.modules.NamePlates
    return Opt.With({ type = "toggle", combat = true,
        get = function() return m.GetStacking(idx()) end, set = function(_, v) m.SetStacking(idx(), v) end,
        hidden = function() return not m.StackingAvailable() end, keywords = "stack stacking overlap spread" }, row)
end

local ICONS = { world = "maps", instance = "encounters", pvp = "pvp" }
local CTX = { labels = { world = "NP_CTX_WORLD", instance = "NP_CTX_INSTANCE", pvp = "NP_CTX_PVP" } }
local function context(key)
    local p = "contexts." .. key
    return {
        { type = "header", label = CTX.labels[key], icon = ICONS[key] },
        px({ type = "range", key = p .. ".scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, disabled = noContexts }),
        px({ type = "select", key = p .. ".friendly", label = "NP_CTX_FRIENDLY", desc = "NP_CTX_FRIENDLY_DESC", values = FRIENDLY,
          disabled = noContexts }),
        px({ type = "toggle", key = p .. ".hideOOC", label = "NP_CTX_HIDE_OOC", desc = "NP_CTX_HIDE_OOC_DESC", disabled = noContexts }),
        px({ type = "toggle", key = p .. ".minions", label = "NP_CTX_MINIONS", desc = "NP_CTX_MINIONS_DESC", disabled = noContexts }),
    }
end

local schema = {
    { type = "scope", key = "styles", label = "NP_KIND", values = KINDS },
    { type = "preview", kind = "nameplate" },
    ------------------------------------------------------------ plates
    { type = "tab", label = "NP_TAB_PLATES" },
    { type = "header", label = "NP_MODE", icon = "nameplates" },
    { type = "select", key = "mode", label = "NP_MODE", desc = "NP_MODE_DESC", values = MODE, reload = true,
      keywords = "own nameplate blizzard replace fallback" },
    { type = "button", label = "NP_TEST", desc = "NP_TEST_DESC", button = "NP_TEST_BUTTON", icon = "test", func = toggleTest,
      disabled = blizzard, keywords = "test fake sample plates" },
    bz({ type = "header", label = "NP_BLIZZARD_SKIN", icon = "skins" }),
    bz({ type = "toggle", key = "texture", label = "NP_TEXTURE", desc = "NP_TEXTURE_DESC", reload = true }),
    bz(Opt.Border("border")),
    bz(Opt.Background("background")),
    { type = "header", label = "UF_LOOK", icon = "textures" },
    { type = "texture", key = "bar", label = "BAR_TEXTURE", desc = "NP_BAR_TEXTURE_DESC", allowDefault = true,
      disabled = function(m) return blizzard(m) and not m.db.texture end, keywords = "statusbar texture" },
    { type = "header", label = "NP_SIZE", icon = "layout" },
    px({ type = "range", key = "styles.@.width", label = "UF_WIDTH", min = 40, max = 300, step = 1 }),
    px({ type = "range", key = "styles.@.height", label = "UF_HEIGHT", min = 2, max = 40, step = 1 }),
    px({ type = "toggle", key = "styles.@.nameOnly", label = "NP_NAME_ONLY", desc = "NP_NAME_ONLY_DESC", hidden = friendlyOnly,
      keywords = "friendly name only no bar" }),
    { type = "header", label = "NP_CLICK", icon = "movers" },
    px({ type = "toggle", gate = true, key = "click.enabled", label = "NP_CLICK_ENABLE", desc = "NP_CLICK_ENABLE_DESC",
      keywords = "clickable area hit box size" }),
    px({ type = "range", key = "click.enemyW", label = "NP_CLICK_ENEMY_W", min = 20, max = 300, step = 1, disabled = noClick }),
    px({ type = "range", key = "click.enemyH", label = "NP_CLICK_ENEMY_H", min = 4, max = 80, step = 1, disabled = noClick }),
    px({ type = "range", key = "click.friendlyW", label = "NP_CLICK_FRIENDLY_W", min = 20, max = 300, step = 1, disabled = noClick }),
    px({ type = "range", key = "click.friendlyH", label = "NP_CLICK_FRIENDLY_H", min = 4, max = 80, step = 1, disabled = noClick }),
    px({ type = "toggle", key = "click.friendlyThrough", label = "NP_CLICK_THROUGH", desc = "NP_CLICK_THROUGH_DESC",
      disabled = noClick, keywords = "click through friendly" }),
    { type = "description", text = "NP_CLICK_NOTE" },
    ------------------------------------------------------------ health
    { type = "tab", label = "UF_TAB_HEALTH" },
    { type = "header", label = "UF_HEALTH_BAR", icon = "border" },
    px({ type = "texture", key = "styles.@.texture", label = "NP_KIND_TEXTURE", desc = "NP_KIND_TEXTURE_DESC", allowDefault = true }),
    px({ type = "toggle", key = "styles.@.reverse", label = "CB_REVERSE", desc = "NP_REVERSE_DESC", keywords = "fill direction" }),
    px({ type = "toggle", key = "styles.@.smooth", label = "UF_SMOOTH", desc = "UF_SMOOTH_DESC" }),
    px({ type = "range", key = "styles.@.gradient", label = "UF_SHADE", desc = "UF_SHADE_DESC", min = 0, max = 0.8, step = 0.05,
      percent = true }),
    px({ type = "select", key = "styles.@.color", label = "UF_HEALTH_COLOR", desc = "NP_COLOR_DESC", values = COLOR,
      cog = { { type = "color", key = "styles.@.fixed", label = "UF_FIXED_COLOR", token = "accent.primary", reset = true } } }),
    px({ type = "toggle", key = "styles.@.classColor", label = "NP_CLASS_PLAYERS", desc = "NP_CLASS_PLAYERS_DESC",
      keywords = "class colour players pvp" }),
    px({ type = "toggle", key = "styles.@.absorb", label = "UF_ABSORB", desc = "NP_ABSORB_DESC", keywords = "absorb shield" }),
    px(Opt.Background("styles.@.background")),
    px(Opt.Border("styles.@.border")),
    { type = "header", label = "NP_REACTION", icon = "palette" },
    px({ type = "colors", keys = { "colors.hostile", "colors.neutral", "colors.friendly", "colors.tapped" },
      tokens = { "state.danger", "state.warning", "state.success", "text.muted" }, label = "NP_REACTION_COLORS",
      desc = "NP_REACTION_COLORS_DESC", labels = { "NP_HOSTILE", "NP_NEUTRAL", "NP_FRIENDLY", "UF_TAPPED" },
      keywords = "reaction hostile neutral friendly tapped colour" }),
    { type = "header", label = "NP_THREAT", icon = "warning" },
    { type = "toggle", gate = true, key = "threat.enabled", label = "NP_THREAT_COLORS", desc = "NP_THREAT_COLORS_DESC",
      keywords = "threat aggro tank colour" },
    { type = "select", key = "threatRole", label = "NP_ROLE", desc = "NP_ROLE_DESC", values = ROLE, disabled = noThreat,
      keywords = "tank dps role threat" },
    { type = "colors", keys = { "threat.safe", "threat.warning", "threat.aggro" },
      tokens = { "state.success", "state.warning", "state.danger" },
      labels = { "NP_THREAT_SAFE", "NP_THREAT_WARNING", "NP_THREAT_AGGRO" }, label = "NP_THREAT_PICK", desc = "NP_THREAT_PICK_DESC",
      disabled = noThreat },
    px({ type = "color", key = "colors.offTank", label = "NP_OFFTANK", desc = "NP_OFFTANK_DESC", token = "state.info", reset = true,
      disabled = noThreat, keywords = "off tank co tank threat" }),
    { type = "header", label = "NP_QUEST", icon = "tracker" },
    px({ type = "toggle", key = "quest.color", label = "NP_QUEST_COLOR", desc = "NP_QUEST_COLOR_DESC", keywords = "quest mob objective",
      cog = { { type = "color", key = "colors.quest", label = "TEXT_COLOR", token = "accent.secondary", reset = true } } }),
    px({ type = "toggle", key = "quest.icon", label = "NP_QUEST_ICON", desc = "NP_QUEST_ICON_DESC" }),
    { type = "header", label = "NP_EXECUTE", icon = "deaths" },
    px({ type = "toggle", gate = true, key = "execute.enabled", label = "NP_EXECUTE_ENABLE", desc = "NP_EXECUTE_ENABLE_DESC",
      keywords = "execute range low health kill",
      cog = { { type = "color", key = "colors.execute", label = "TEXT_COLOR", token = "state.danger", reset = true } } }),
    px({ type = "range", key = "execute.threshold", label = "NP_EXECUTE_AT", min = 5, max = 50, step = 1, disabled = noExecute }),
    px({ type = "toggle", key = "execute.marker", label = "NP_EXECUTE_MARK", desc = "NP_EXECUTE_MARK_DESC", disabled = noExecute }),
    ------------------------------------------------------------ target, focus, mouseover
    { type = "tab", label = "NP_TAB_TARGET" },
    { type = "header", label = "NP_HIGHLIGHT", icon = "preview" },
    px({ type = "select", key = "target.effect", label = "NP_TARGET_EFFECT", desc = "NP_TARGET_EFFECT_DESC", values = EFFECT,
      keywords = "target glow border arrows",
      cog = { { type = "color", key = "colors.target", label = "TEXT_COLOR", token = "accent.primary", reset = true } } }),
    px({ type = "toggle", key = "target.arrows", label = "NP_TARGET_ARROWS", desc = "NP_TARGET_ARROWS_DESC" }),
    { type = "toggle", key = "highlight.target", label = "NP_TARGET_COLOR", desc = "NP_TARGET_COLOR_DESC", keywords = "target colour",
      cog = { { type = "color", key = "highlight.targetColor", label = "TEXT_COLOR", token = "accent.primary", reset = true } } },
    { type = "toggle", key = "highlight.focus", label = "NP_FOCUS_COLOR", desc = "NP_FOCUS_COLOR_DESC", keywords = "focus colour",
      cog = { { type = "color", key = "highlight.focusColor", label = "TEXT_COLOR", token = "state.info", reset = true } } },
    px({ type = "toggle", key = "focus.marker", label = "NP_FOCUS_MARK", desc = "NP_FOCUS_MARK_DESC",
      cog = { { type = "color", key = "colors.focus", label = "TEXT_COLOR", token = "state.info", reset = true } } }),
    px({ type = "toggle", key = "hover.highlight", label = "NP_HOVER", desc = "NP_HOVER_DESC", keywords = "mouseover hover highlight",
      cog = { { type = "range", key = "hover.alpha", label = "NP_HOVER_ALPHA", min = 0.05, max = 0.8, step = 0.05, percent = true },
              { type = "color", key = "colors.hover", label = "TEXT_COLOR", token = "text.primary", reset = true } } }),
    px({ type = "toggle", key = "target.classPower", label = "NP_CLASS_POWER", desc = "NP_CLASS_POWER_DESC",
      keywords = "combo points holy power class resource target" }),
    { type = "header", label = "NP_SELECTION", icon = "opacity" },
    cvar("nameplateSelectedScale", "number", { label = "NP_CV_TARGET_SCALE", desc = "NP_CV_TARGET_SCALE_DESC",
      min = 1, max = 1.6, step = 0.05 }),
    cvar("nameplateNotSelectedAlpha", "number", { label = "NP_CV_OTHER_ALPHA", desc = "NP_CV_OTHER_ALPHA_DESC",
      min = 0.1, max = 1, step = 0.05, percent = true }),
    cvar("nameplateOccludedAlphaMult", "number", { label = "NP_CV_OCCLUDED", desc = "NP_CV_OCCLUDED_DESC",
      min = 0, max = 1, step = 0.05, percent = true }),
    ------------------------------------------------------------ cast bar (the S9 engine)
    { type = "tab", label = "NP_CASTBAR" },
    { type = "header", label = "NP_CASTBAR", icon = "castbars" },
    px({ type = "toggle", gate = true, key = "styles.@.cast.enabled", label = "CB_ENABLE", desc = "NP_CAST_ENABLE_DESC" }),
    cx({ type = "range", key = "styles.@.cast.height", label = "UF_CAST_HEIGHT", min = 4, max = 30, step = 1 }),
    cx({ type = "range", key = "styles.@.cast.gap", label = "UF_CAST_GAP", min = 0, max = 20, step = 1 }),
    cx({ type = "texture", key = "styles.@.cast.texture", label = "BAR_TEXTURE", allowDefault = true }),
    cx({ type = "toggle", key = "styles.@.cast.reverse", label = "CB_REVERSE", desc = "CB_REVERSE_DESC" }),
    cx({ type = "toggle", key = "styles.@.cast.smooth", label = "UF_SMOOTH", desc = "CB_SMOOTH_DESC" }),
    cx({ type = "range", key = "styles.@.cast.gradient", label = "UF_SHADE", desc = "UF_SHADE_DESC", min = 0, max = 0.8, step = 0.05,
      percent = true }),
    cx({ type = "colors", keys = { "styles.@.cast.colors.cast", "styles.@.cast.colors.channel", "styles.@.cast.colors.locked" },
      tokens = { "accent.primary", "state.info", "text.muted" }, label = "CB_FILL_COLORS", desc = "CB_FILL_COLORS_DESC2",
      labels = { "CB_COLOR_CAST", "CB_COLOR_CHANNEL", "CB_COLOR_LOCKED" }, keywords = "interruptible uninterruptible colour" }),
    cx({ type = "colors", keys = { "styles.@.cast.colors.notReady", "styles.@.cast.colors.interrupted", "styles.@.cast.colors.success" },
      tokens = { "state.warning", "state.danger", "state.success" }, label = "CB_STATE_COLORS", desc = "CB_STATE_COLORS_DESC",
      labels = { "CB_COLOR_NOT_READY", "CB_COLOR_INTERRUPTED", "CB_COLOR_SUCCESS" } }),
    cx({ type = "toggle", key = "styles.@.cast.importantFill", label = "CB_IMPORTANT_FILL", desc = "CB_IMPORTANT_FILL_DESC",
      keywords = "important dangerous cast colour",
      cog = { { type = "color", key = "styles.@.cast.colors.important", label = "TEXT_COLOR", token = "state.warning",
                reset = true } } }),
    cx({ type = "toggle", key = "styles.@.cast.important", label = "CB_IMPORTANT", desc = "CB_IMPORTANT_DESC" }),
    cx({ type = "toggle", key = "styles.@.cast.kick", label = "CB_KICK", desc = "CB_KICK_DESC", keywords = "interrupt kick ready" }),
    cx({ type = "select", key = "styles.@.cast.icon", label = "CB_ICON_POS", desc = "CB_ICON_POS_DESC", values = ICON,
      cog = { { type = "range", key = "styles.@.cast.iconZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } }),
    cx({ type = "toggle", key = "styles.@.cast.shield", label = "CB_SHIELD", desc = "CB_SHIELD_DESC" }),
    cx(Opt.Text("styles.@.cast.text", "CB_SPELL_FONT", { place = true, show = true, max = 20 })),
    cx(Opt.Text("styles.@.cast.time", "CB_TIME_FONT", { place = true, show = true, max = 20 })),
    cx(Opt.Text("styles.@.cast.target", "CB_TARGET_FONT", { place = true, show = true, max = 20,
      row = { desc = "CB_TARGET_DESC", keywords = "spell target name" } })),
    cx({ type = "select", key = "styles.@.cast.timeFormat", label = "CB_TIME_FORMAT", values = TIME }),
    cx({ type = "range", key = "styles.@.cast.nameLength", label = "CB_NAME_LENGTH", desc = "CB_NAME_LENGTH_DESC", min = 0, max = 40,
      step = 1 }),
    cx({ type = "range", key = "styles.@.cast.hold", label = "CB_HOLD", desc = "CB_HOLD_DESC", min = 0, max = 2, step = 0.1 }),
    cx({ type = "toggle", key = "styles.@.cast.flash", label = "CB_FLASH", desc = "CB_FLASH_DESC" }),
    bz({ type = "header", label = "NP_CASTBAR", icon = "castbars" }),
    bz({ type = "toggle", gate = true, key = "castbar.style", label = "NP_CASTBAR_STYLE", desc = "NP_CASTBAR_STYLE_DESC" }),
    bz({ type = "texture", key = "castbar.texture", label = "BAR_TEXTURE", allowDefault = true, disabled = noCast }),
    bz({ type = "color", key = "castbar.color", label = "NP_CASTBAR_COLOR", desc = "NP_CASTBAR_COLOR_DESC", token = "accent.primary",
      reset = true, disabled = noCast }),
    bz(Opt.Text("castbar.text", "NP_CASTBAR_FONT", { max = 18, row = { disabled = noCast } })),
    ------------------------------------------------------------ text
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "UF_TAGS", icon = "fonts", hidden = blizzard },
    px({ type = "input", key = "styles.@.nameTag", label = "UF_TAG_NAME", desc = "UF_TAGS_DESC" }),
    px(Opt.Text("styles.@.name", "UF_NAME_FONT", { place = true, max = 24 })),
    px({ type = "select", key = "styles.@.nameColor", label = "UF_NAME_COLOR", values = NAME_COLOR }),
    px({ type = "range", key = "styles.@.nameLength", label = "UF_NAME_LENGTH", desc = "UF_NAME_LENGTH_DESC",
      min = 0, max = 40, step = 1 }),
    px({ type = "input", key = "styles.@.healthTag", label = "UF_TAG_HEALTH", desc = "UF_TAGS_DESC" }),
    px(Opt.Text("styles.@.health", "UF_HEALTH_FONT", { place = true, show = true, max = 24 })),
    px({ type = "input", key = "styles.@.levelTag", label = "NP_TAG_LEVEL", desc = "NP_TAG_LEVEL_DESC" }),
    px(Opt.Text("styles.@.level", "NP_LEVEL_FONT", { place = true, show = true, max = 24 })),
    px({ type = "input", key = "styles.@.infoTag", label = "UF_TAG_INFO", desc = "NP_TAG_INFO_DESC" }),
    px(Opt.Text("styles.@.info", "UF_INFO_FONT", { place = true, show = true, max = 24 })),
    { type = "description", text = "UF_TAGS_HELP", hidden = blizzard },
    { type = "header", label = "NP_FORCES", icon = "forces", feature = "mythicplus" },
    { type = "toggle", key = "forces", label = "NP_FORCES", desc = "NP_FORCES_DESC", feature = "mythicplus",
      keywords = "mythic plus enemy forces count percent trash" },
    Opt.Text("forcesText", "NP_FORCES_FONT", { max = 20, token = "accent.secondary",
      row = { disabled = function(m) return not m.db.forces end, feature = "mythicplus" } }),
    -- the 2.0 Blizzard restyle's texts
    bz({ type = "header", label = "NP_TEXT", icon = "fonts" }),
    bz({ type = "toggle", key = "healthText", label = "NP_HEALTH_TEXT", desc = "NP_HEALTH_TEXT_DESC", keywords = "percent hp" }),
    bz(Opt.Text("health", "NP_HEALTH_FONT", { place = true, max = 20, row = { disabled = noHealthText } })),
    bz({ type = "toggle", key = "name.styled", label = "NP_NAME_STYLED", desc = "NP_NAME_STYLED_DESC" }),
    bz(Opt.Text("name", "NP_NAME_FONT", { max = 20, row = { disabled = nameUnstyled } })),
    bz(Opt.Text("auras.count", "NP_AURA_COUNT_FONT", { max = 18, row = { disabled = noAuras } })),
    bz(Opt.Text("auras.timer", "NP_AURA_TIMER_FONT", { max = 18, row = { disabled = noAuras } })),
    ------------------------------------------------------------ indicators
    { type = "tab", label = "UF_TAB_INDICATORS" },
    { type = "header", label = "UF_ICONS", icon = "boss" },
    px({ type = "toggle", key = "styles.@.icons.marker", label = "UF_ICON_MARKER", desc = "NP_MARKER_DESC",
      keywords = "raid marker skull cross",
      cog = { { type = "range", key = "styles.@.icons.markerSize", label = "ICON_SIZE", min = 8, max = 40, step = 1 },
              { type = "select", key = "styles.@.icons.markerPos", label = "TEXT_POSITION", values = MARKER } } }),
    px({ type = "toggle", key = "styles.@.icons.quest", label = "NP_QUEST_ICON", desc = "NP_QUEST_ICON_DESC" }),
    px({ type = "toggle", key = "styles.@.icons.elite", label = "UF_ICON_ELITE", desc = "UF_ICON_ELITE_DESC",
      keywords = "elite rare boss star" }),
    px({ type = "range", key = "styles.@.icons.size", label = "UF_ICON_SIZE", min = 8, max = 32, step = 1 }),
    ------------------------------------------------------------ auras
    { type = "tab", label = "NP_AURAS" },
    { type = "header", label = "UF_DEBUFFS", icon = "auras" },
    px({ type = "select", key = "styles.@.auras.debuffs", label = "UF_DEBUFF_FILTER", desc = "NP_DEBUFFS_DESC", values = DEBUFFS,
      keywords = "debuff dots mine important filter" }),
    px({ type = "toggle", key = "styles.@.auras.cc", label = "NP_CC", desc = "NP_CC_DESC", keywords = "crowd control stun cc" }),
    px({ type = "range", key = "styles.@.auras.size", label = "ICON_SIZE", min = 10, max = 48, step = 1 }),
    px({ type = "range", key = "styles.@.auras.spacing", label = "ICON_SPACING", min = 0, max = 10, step = 1 }),
    px({ type = "range", key = "styles.@.auras.max", label = "UF_AURA_MAX", min = 1, max = 12, step = 1 }),
    px({ type = "range", key = "styles.@.auras.perRow", label = "UF_AURA_PER_ROW", min = 1, max = 12, step = 1 }),
    px({ type = "range", key = "styles.@.auras.gap", label = "UF_AURA_GAP", min = 0, max = 30, step = 1 }),
    { type = "header", label = "UF_BUFFS", icon = "auras", hidden = enemyOnly },
    px({ type = "select", key = "styles.@.auras.buffs", label = "UF_BUFF_FILTER", desc = "NP_BUFFS_DESC", values = BUFFS,
      hidden = enemyOnly, keywords = "enemy buffs purge dispel steal" }),
    px({ type = "range", key = "styles.@.auras.buffSize", label = "ICON_SIZE", min = 10, max = 48, step = 1, hidden = enemyOnly }),
    px({ type = "range", key = "styles.@.auras.buffMax", label = "UF_AURA_MAX", min = 1, max = 8, step = 1, hidden = enemyOnly }),
    { type = "header", label = "UF_LOOK", icon = "border" },
    px({ type = "range", key = "styles.@.auras.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 }),
    px({ type = "toggle", key = "styles.@.auras.swipe", label = "UF_SWIPE" }),
    px({ type = "toggle", key = "styles.@.auras.dispel", label = "UF_DISPEL", desc = "UF_DISPEL_DESC" }),
    px({ type = "toggle", key = "styles.@.auras.desat", label = "UF_DESAT", desc = "UF_DESAT_DESC" }),
    px(Opt.Border("styles.@.auras.border", "UF_AURA_BORDER")),
    px(Opt.Text("styles.@.auras.count", "UF_AURA_COUNT_FONT", { place = true, max = 18 })),
    px(Opt.Text("styles.@.auras.duration", "UF_AURA_DURATION_FONT", { place = true, show = true, max = 18 })),
    { type = "description", text = "NP_AURA_NOTE", hidden = blizzard },
    -- the 2.0 Blizzard restyle's aura dressing (its bar skin sits on Plates, its cast bar on Cast bar)
    bz({ type = "header", label = "NP_AURAS", icon = "auras" }),
    bz({ type = "toggle", gate = true, key = "auras.style", label = "NP_AURAS_STYLE", desc = "NP_AURAS_STYLE_DESC",
      cog = { { type = "range", key = "auras.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } }),
    bz(Opt.With(Opt.Border("auras.border"), { disabled = noAuras })),
    ------------------------------------------------------------ contexts
    { type = "tab", label = "NP_TAB_CONTEXTS" },
    { type = "header", label = "NP_CONTEXTS", icon = "maps" },
    px({ type = "toggle", gate = true, key = "contexts.enabled", label = "NP_CONTEXTS_ENABLE", desc = "NP_CONTEXTS_ENABLE_DESC",
      keywords = "instance dungeon raid pvp arena battleground world zone" }),
}
for _, key in ipairs({ "world", "instance", "pvp" }) do
    for _, row in ipairs(context(key)) do schema[#schema + 1] = row end
end
local game = {
    ------------------------------------------------------------ client CVars
    { type = "tab", label = "TAB_GAME" },
    { type = "header", label = "NP_STACKING", icon = "grid" },
    stacking("Enemy", { label = "NP_STACK_ENEMY", desc = "NP_STACK_ENEMY_DESC" }),
    stacking("Friendly", { label = "NP_STACK_FRIENDLY", desc = "NP_STACK_FRIENDLY_DESC" }),
    cvar("nameplateOverlapV", "number", { label = "NP_CV_OVERLAP_V", desc = "NP_CV_OVERLAP_V_DESC", min = 0.3, max = 3, step = 0.05 }),
    cvar("nameplateOverlapH", "number", { label = "NP_CV_OVERLAP_H", desc = "NP_CV_OVERLAP_H_DESC", min = 0.3, max = 3, step = 0.05 }),
    cvar("nameplateMaxDistance", "number", { label = "NP_CV_DISTANCE", desc = "NP_CV_DISTANCE_DESC", min = 10, max = 60, step = 1 }),
    -- screen clamp (back in 12.1.5); hidden on clients that lack the CVar
    cvar("nameplateTopInset", "number", { label = "NP_CV_TOP_INSET", desc = "NP_CV_TOP_INSET_DESC", min = 0, max = 0.5,
        step = 0.01, percent = true, hidden = function() return C_CVar.GetCVar("nameplateTopInset") == nil end }),
    cvar("nameplateBottomInset", "number", { label = "NP_CV_BOTTOM_INSET", desc = "NP_CV_BOTTOM_INSET_DESC", min = 0, max = 0.5,
        step = 0.01, percent = true, hidden = function() return C_CVar.GetCVar("nameplateBottomInset") == nil end }),
    { type = "header", label = "BLIZZARD_FEATURES", icon = "general" },
}
local show = {
    cvar("nameplateShowAll", "bool", { label = "NP_SHOW_ALL", desc = "NP_SHOW_ALL_DESC" }),
    cvar("nameplateShowEnemies", "bool", { label = "NP_SHOW_ENEMIES", desc = "NP_SHOW_ENEMIES_DESC" }),
    cvar("nameplateShowFriendlyPlayers", "bool", { label = "NP_CV_FRIENDLYPLAYERS", desc = "NP_CV_FRIENDLYPLAYERS_DESC" }),
    cvar("nameplateShowFriendlyNpcs", "bool", { label = "NP_CV_FRIENDLYNPCS", desc = "NP_CV_FRIENDLYNPCS_DESC" }),
    cvar("nameplateShowEnemyPets", "bool", { label = "NP_CV_ENEMYPETS", desc = "NP_CV_ENEMYPETS_DESC" }),
    cvar("nameplateShowEnemyTotems", "bool", { label = "NP_CV_ENEMYTOTEMS", desc = "NP_CV_ENEMYTOTEMS_DESC" }),
    cvar("nameplateShowEnemyMinions", "bool", { label = "NP_CV_ENEMYMINIONS", desc = "NP_CV_ENEMYMINIONS_DESC" }),
    cvar("nameplateShowEnemyGuardians", "bool", { label = "NP_CV_ENEMYGUARDIANS", desc = "NP_CV_ENEMYGUARDIANS_DESC" }),
    cvar("nameplateShowEnemyMinus", "bool", { label = "NP_CV_ENEMYMINUS", desc = "NP_CV_ENEMYMINUS_DESC" }),
}
for _, row in ipairs(show) do game[#game + 1] = row end
for _, row in ipairs(game) do schema[#schema + 1] = row end
schema[#schema + 1] = { type = "description", text = "NP_SECRET_NOTE", hidden = blizzard }

ns:RegisterOptions("NamePlates", schema)
