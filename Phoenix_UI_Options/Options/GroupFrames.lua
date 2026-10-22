local _, ns = ...
local Opt = ns.Opt

--[[ Group Frames (plan v2 S11). The scope bar picks the layout profile (party / raid 10-20 / large raid 25-40) for
    the "profiles.@…" rows; main tank / assist and pet frames, the test size and the Blizzard raid manager are
    shared. Colours (dead, offline, absorbs …) and number formats are Unit Frames' own. Rows that size, place,
    sort or filter the secure headers change out of combat. The 2.0 Blizzard skin's rows show in Blizzard mode only. ]]
local function blizzard(m) return m.db.mode ~= "phoenix" end
local function phoenix(m) return m.db.mode == "phoenix" end
local function notParty(_, u) return (u or "party") ~= "party" end
local function party(_, u) return (u or "party") == "party" end
local function noFonts(m) return blizzard(m) and not m.db.fonts end
local function prof(m, u) return m.db.profiles[u or "party"] end
local function perHidden(m, u) return party(m, u) or prof(m, u).sortBy == "group" end
local function roleHidden(m, u) return prof(m, u).sortBy ~= "role" end
local function noTanks(m) return blizzard(m) or not m.db.tanks.enabled end
local function noPets(m) return blizzard(m) or not m.db.pets.enabled end
local function dispelOff(m, u) return prof(m, u).dispel.mode == "off" end
local function buffsOff(m, u) return prof(m, u).groupAuras.buffs.mode == "off" end
local function debuffsOff(m, u) return prof(m, u).groupAuras.debuffs.mode == "off" end
local function defOff(m, u) return not prof(m, u).groupAuras.defensive.enabled end
local function privOff(m, u) return not prof(m, u).groupAuras.private.enabled end

local PROFILES = { { value = "party", label = "GF_PROFILE_PARTY" }, { value = "raid", label = "GF_PROFILE_RAID" },
    { value = "large", label = "GF_PROFILE_LARGE" } }
local MODE = { { value = "phoenix", label = "GF_MODE_PHOENIX" }, { value = "blizzard", label = "GF_MODE_BLIZZARD" } }
local GROWTH = { { value = "DOWN", label = "GROW_DOWN" }, { value = "UP", label = "GROW_UP" },
    { value = "RIGHT", label = "GROW_RIGHT" }, { value = "LEFT", label = "GROW_LEFT" } }
local SORT = { { value = "group", label = "GF_SORT_GROUP" }, { value = "role", label = "GF_SORT_ROLE" },
    { value = "class", label = "GF_SORT_CLASS" }, { value = "name", label = "GF_SORT_NAME" },
    { value = "index", label = "GF_SORT_INDEX" } }
local DIR = { { value = "ASC", label = "GF_SORT_ASC" }, { value = "DESC", label = "GF_SORT_DESC" } }
local ROLE_ORDER = { { value = "TANK,HEALER,DAMAGER", label = "GF_ROLES_THD" },
    { value = "HEALER,TANK,DAMAGER", label = "GF_ROLES_HTD" }, { value = "TANK,DAMAGER,HEALER", label = "GF_ROLES_TDH" },
    { value = "DAMAGER,HEALER,TANK", label = "GF_ROLES_DHT" } }
local TEST = { { value = 5, label = "GF_TEST_5" }, { value = 20, label = "GF_TEST_20" }, { value = 40, label = "GF_TEST_40" } }
local HEALTH_COLOR = { { value = "class", label = "UF_COLOR_CLASS" }, { value = "health", label = "UF_COLOR_HEALTH" },
    { value = "fixed", label = "UF_COLOR_FIXED" }, { value = "theme", label = "UF_COLOR_THEME" } }
local POWER_COLOR = { { value = "type", label = "UF_COLOR_POWER" }, { value = "class", label = "UF_COLOR_CLASS" },
    { value = "fixed", label = "UF_COLOR_FIXED" } }
local NAME_COLOR = { { value = "white", label = "UF_COLOR_WHITE" }, { value = "class", label = "UF_COLOR_CLASS" } }
local BG = { { value = "dark", label = "UF_BG_DARK" }, { value = "texture", label = "UF_BG_TEXTURE" },
    { value = "none", label = "UF_BG_NONE" } }
local ABSORB_STYLE = { { value = "striped", label = "UF_ABSORB_STRIPED" }, { value = "solid", label = "UF_ABSORB_SOLID" } }
local ABSORB_POS = { { value = "attached", label = "UF_ABSORB_ATTACHED" }, { value = "reverse", label = "UF_ABSORB_REVERSE" } }
local POWER_SHOW = { { value = "always", label = "UF_POWER_ALWAYS" }, { value = "mana", label = "UF_POWER_MANA" },
    { value = "off", label = "OFF" } }
local POWER_POS = { { value = "inside", label = "UF_POWER_INSIDE" }, { value = "below", label = "UF_POWER_BELOW" } }
local TOOLTIP = { { value = "always", label = "UF_TIP_ALWAYS" }, { value = "ooc", label = "UF_TIP_OOC" },
    { value = "never", label = "UF_TIP_NEVER" } }
local MARKER_ANCHOR = { { value = "TOP", label = "ANCHOR_TOP" }, { value = "CENTER", label = "ANCHOR_CENTER" },
    { value = "LEFT", label = "ANCHOR_LEFT" }, { value = "RIGHT", label = "ANCHOR_RIGHT" } }
local DISPEL = { { value = "border", label = "GF_DISPEL_BORDER" }, { value = "overlay", label = "GF_DISPEL_OVERLAY" },
    { value = "gradient", label = "GF_DISPEL_GRADIENT" }, { value = "off", label = "OFF" } }
local BUFF_MODE = { { value = "corners", label = "GF_BUFFS_CORNERS" }, { value = "row", label = "GF_BUFFS_ROW" },
    { value = "off", label = "OFF" } }
local DEBUFF_MODE = { { value = "row", label = "GF_BUFFS_ROW" }, { value = "center", label = "GF_DEBUFFS_CENTER" },
    { value = "off", label = "OFF" } }
local BUFF_FILTER = { { value = "mine", label = "GF_FILTER_HOTS" }, { value = "raid", label = "GF_FILTER_RAID_BUFFS" },
    { value = "all", label = "UF_FILTER_ALL" } }
local DEBUFF_FILTER = { { value = "all", label = "UF_FILTER_ALL" }, { value = "raid", label = "GF_FILTER_MY_DISPELS" },
    { value = "dispellable", label = "GF_FILTER_DISPELLABLE" }, { value = "cc", label = "GF_FILTER_CC" } }

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

-- Phoenix-mode rows: greyed out while Blizzard draws the frames.
local function px(row, extra)
    local d = row.disabled
    row.disabled = d and function(m, u) return blizzard(m) or d(m, u) end or blizzard
    return Opt.With(row, extra)
end
local function bz(row) return Opt.With(row, { hidden = phoenix }) end
local function text(path, label, extra)
    return px(Opt.Text(path, label, { place = true, show = true, max = 24, row = extra }))
end
local P = "profiles.@."

ns:RegisterOptions("GroupFrames", {
    { type = "scope", key = "profiles", label = "GF_PROFILE", values = PROFILES },
    { type = "preview", kind = "groupframe" },
    ------------------------------------------------------------ layout
    { type = "tab", label = "GF_TAB_LAYOUT" },
    { type = "header", label = "GF_MODE", icon = "groupframes" },
    { type = "select", key = "mode", label = "GF_MODE", desc = "GF_MODE_DESC", values = MODE, reload = true,
      keywords = "own raid party frames blizzard compact fallback replace" },
    px({ type = "button", label = "GF_TEST", desc = "GF_TEST_DESC", button = "GF_TEST_BUTTON", icon = "test", func = toggleTest,
      keywords = "test fake raid party 5 20 40" }),
    px({ type = "select", key = "testSize", label = "GF_TEST_SIZE", values = TEST }),
    px({ type = "button", label = "UF_LAYOUT_MODE", desc = "GF_LAYOUT_MODE_DESC", button = "AB_LAYOUT_MODE_BUTTON", icon = "movers",
      combat = true, func = openLayout, keywords = "move drag unlock position" }),
    ------------------------------------------------------------ Blizzard mode (the 2.0 skin)
    bz({ type = "header", label = "GF_STYLE", icon = "theme" }),
    bz({ type = "toggle", key = "texture", label = "GF_TEXTURE", desc = "GF_TEXTURE_DESC", keywords = "raid party" }),
    bz({ type = "texture", key = "bar", label = "BAR_TEXTURE", allowDefault = true,
      disabled = function(m) return not m.db.texture end, keywords = "statusbar texture raid party" }),
    bz(Opt.Border("border")),
    bz(Opt.Background("background")),
    bz({ type = "header", label = "GF_TEXT", icon = "fonts" }),
    bz({ type = "toggle", key = "fonts", label = "GF_FONTS", desc = "GF_FONTS_DESC" }),
    bz(Opt.Text("name", "GF_NAME_FONT", { min = 8, max = 18, row = { disabled = noFonts } })),
    bz(Opt.Text("status", "GF_STATUS_FONT", { min = 8, max = 18, row = { disabled = noFonts } })),
    { type = "header", label = "UF_SIZE", icon = "layout", wide = true },
    px({ type = "range", key = P .. "width", label = "UF_WIDTH", min = 40, max = 300, step = 1, combat = true }),
    px({ type = "range", key = P .. "height", label = "UF_HEIGHT", min = 16, max = 150, step = 1, combat = true }),
    px({ type = "range", key = P .. "scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, combat = true }),
    px({ type = "select", key = P .. "strata", label = "FRAME_STRATA", values = Opt.STRATA, combat = true }),
    { type = "header", label = "GF_GROWTH", icon = "grid" },
    px({ type = "select", key = P .. "growth", label = "GF_UNIT_GROWTH", values = GROWTH, combat = true }),
    px({ type = "range", key = P .. "spacing", label = "GF_SPACING", min = 0, max = 30, step = 1, combat = true }),
    px({ type = "select", key = P .. "groupGrowth", label = "GF_GROUP_GROWTH", desc = "GF_GROUP_GROWTH_DESC", values = GROWTH,
      combat = true }),
    px({ type = "range", key = P .. "groupSpacing", label = "GF_GROUP_SPACING", min = 0, max = 40, step = 1, combat = true }),
    px({ type = "range", key = P .. "perColumn", label = "GF_PER_COLUMN", desc = "GF_PER_COLUMN_DESC", min = 1, max = 40, step = 1,
      combat = true, hidden = perHidden }),
    { type = "header", label = "GF_SORTING", icon = "filter" },
    px({ type = "select", key = P .. "sortBy", label = "GF_SORT_BY", values = SORT, combat = true,
      keywords = "sort group role class name order" }),
    px({ type = "select", key = P .. "sortDir", label = "GF_SORT_DIR", values = DIR, combat = true }),
    px({ type = "select", key = P .. "roleOrder", label = "GF_ROLE_ORDER", values = ROLE_ORDER, combat = true,
      hidden = roleHidden, keywords = "tank healer damage first" }),
    px({ type = "toggle", key = P .. "showPlayer", label = "GF_SHOW_PLAYER", desc = "GF_SHOW_PLAYER_DESC", combat = true,
      hidden = notParty }),
    px({ type = "toggle", key = P .. "showSolo", label = "GF_SHOW_SOLO", desc = "GF_SHOW_SOLO_DESC", combat = true,
      hidden = notParty }),
    px({ type = "range", key = P .. "groups", label = "GF_GROUPS", desc = "GF_GROUPS_DESC", min = 1, max = 8, step = 1,
      combat = true, hidden = party }),
    px({ type = "toggle", key = P .. "mythicGroups", label = "GF_MYTHIC_GROUPS", desc = "GF_MYTHIC_GROUPS_DESC", combat = true,
      hidden = party, feature = "mythicRaid", keywords = "mythic 20 groups 5 6 7 8 hide" }),
    { type = "header", label = "UF_POSITION", icon = "movers" },
    px({ type = "select", key = P .. "point", label = "UF_POINT", values = Opt.ANCHOR, combat = true }),
    px({ type = "range", key = P .. "x", label = "OFFSET_X", min = -1600, max = 1600, step = 1, combat = true }),
    px({ type = "range", key = P .. "y", label = "OFFSET_Y", min = -1000, max = 1000, step = 1, combat = true }),
    { type = "header", label = "GF_TANKS", icon = "user" },
    px({ type = "toggle", gate = true, key = "tanks.enabled", label = "GF_TANKS_ENABLE", desc = "GF_TANKS_DESC", combat = true,
      keywords = "main tank main assist mt ma" }),
    px({ type = "toggle", key = "tanks.assist", label = "GF_TANKS_ASSIST", combat = true, disabled = noTanks }),
    px({ type = "range", key = "tanks.width", label = "UF_WIDTH", min = 40, max = 300, step = 1, combat = true, disabled = noTanks }),
    px({ type = "range", key = "tanks.height", label = "UF_HEIGHT", min = 16, max = 150, step = 1, combat = true, disabled = noTanks }),
    px({ type = "range", key = "tanks.spacing", label = "GF_SPACING", min = 0, max = 30, step = 1, combat = true, disabled = noTanks }),
    px({ type = "select", key = "tanks.growth", label = "GF_UNIT_GROWTH", values = GROWTH, combat = true, disabled = noTanks }),
    px({ type = "range", key = "tanks.scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, combat = true, disabled = noTanks }),
    { type = "header", label = "GF_PETS", icon = "friends" },
    px({ type = "toggle", gate = true, key = "pets.enabled", label = "GF_PETS_ENABLE", desc = "GF_PETS_DESC", combat = true,
      keywords = "pet pets minion" }),
    px({ type = "range", key = "pets.width", label = "UF_WIDTH", min = 30, max = 300, step = 1, combat = true, disabled = noPets }),
    px({ type = "range", key = "pets.height", label = "UF_HEIGHT", min = 10, max = 100, step = 1, combat = true, disabled = noPets }),
    px({ type = "range", key = "pets.spacing", label = "GF_SPACING", min = 0, max = 30, step = 1, combat = true, disabled = noPets }),
    px({ type = "select", key = "pets.growth", label = "GF_UNIT_GROWTH", values = GROWTH, combat = true, disabled = noPets }),
    px({ type = "range", key = "pets.scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, combat = true, disabled = noPets }),
    { type = "header", label = "GF_BLIZZARD", icon = "hide" },
    px({ type = "toggle", key = "hideManager", label = "GF_HIDE_MANAGER", desc = "GF_HIDE_MANAGER_DESC", reload = true,
      keywords = "raid manager ready check markers side panel" }),
    ------------------------------------------------------------ health
    { type = "tab", label = "UF_TAB_HEALTH" },
    { type = "header", label = "UF_LOOK", icon = "border" },
    { type = "texture", key = P .. "texture", label = "BAR_TEXTURE", allowDefault = true, hidden = blizzard,
      keywords = "statusbar texture" },
    px(Opt.Border(P .. "border", "UF_BORDER")),
    px(Opt.Background(P .. "background")),
    px({ type = "toggle", key = P .. "highlight", label = "UF_HIGHLIGHT", desc = "UF_HIGHLIGHT_DESC" }),
    px({ type = "toggle", key = P .. "targetBorder", label = "UF_TARGET_BORDER", desc = "UF_TARGET_BORDER_DESC" }),
    px({ type = "select", key = P .. "tooltip", label = "UF_TOOLTIP", values = TOOLTIP }),
    { type = "header", label = "UF_HEALTH_BAR", icon = "heart" },
    px({ type = "select", key = P .. "bar.color", label = "UF_HEALTH_COLOR", desc = "UF_HEALTH_COLOR_DESC", values = HEALTH_COLOR,
      keywords = "class colour gradient",
      cog = { { type = "color", key = P .. "bar.fixed", label = "UF_FIXED_COLOR", token = "accent.primary", reset = true,
                classToken = true } } }),
    px({ type = "toggle", key = P .. "bar.dark", label = "UF_DARK", desc = "UF_DARK_DESC", keywords = "dark mode inverted" }),
    px({ type = "range", key = P .. "bar.gradient", label = "UF_SHADE", desc = "UF_SHADE_DESC", min = 0, max = 0.6, step = 0.05,
      percent = true }),
    px({ type = "toggle", key = P .. "bar.smooth", label = "UF_SMOOTH", desc = "UF_SMOOTH_DESC" }),
    px({ type = "toggle", key = P .. "bar.reverse", label = "UF_REVERSE", desc = "UF_REVERSE_DESC" }),
    px({ type = "toggle", key = P .. "bar.vertical", label = "UF_VERTICAL", keywords = "vertical fill direction" }),
    px({ type = "select", key = P .. "bar.bg", label = "UF_BG", values = BG,
      cog = { { type = "range", key = P .. "bar.bgAlpha", label = "BACKGROUND_OPACITY", min = 0, max = 1, step = 0.05,
                percent = true },
              { type = "color", key = P .. "bar.bgColor", label = "BACKGROUND_COLOR", token = "bg.sunken", reset = true } } }),
    { type = "header", label = "UF_ABSORBS", icon = "lock" },
    px({ type = "toggle", key = P .. "absorb.show", label = "UF_ABSORB", desc = "UF_ABSORB_DESC", keywords = "shield absorb",
      cog = { { type = "select", key = P .. "absorb.style", label = "UF_ABSORB_STYLE", values = ABSORB_STYLE },
              { type = "range", key = P .. "absorb.alpha", label = "UF_ABSORB_ALPHA", min = 0.1, max = 1, step = 0.05,
                percent = true },
              { type = "select", key = P .. "absorb.position", label = "UF_ABSORB_POSITION", values = ABSORB_POS } } }),
    px({ type = "toggle", key = P .. "absorb.healAbsorb", label = "UF_HEAL_ABSORB", desc = "UF_HEAL_ABSORB_DESC" }),
    px({ type = "toggle", key = P .. "absorb.prediction", label = "UF_PREDICTION", desc = "UF_PREDICTION_DESC",
      keywords = "incoming heals" }),
    { type = "header", label = "UF_FADING", icon = "opacity" },
    px({ type = "toggle", key = P .. "rangeFade", label = "UF_RANGE_FADE", desc = "GF_RANGE_DESC", keywords = "out of range alpha",
      cog = { { type = "range", key = P .. "rangeAlpha", label = "UF_RANGE_ALPHA", min = 0.1, max = 0.9, step = 0.05,
                percent = true } } }),
    { type = "description", text = "GF_COLORS_NOTE", hidden = blizzard },
    ------------------------------------------------------------ power
    { type = "tab", label = "UF_TAB_POWER" },
    { type = "header", label = "UF_POWER_BAR", icon = "speed" },
    px({ type = "select", key = P .. "powerBar.show", label = "UF_POWER_SHOW", values = POWER_SHOW }),
    px({ type = "range", key = P .. "powerBar.height", label = "UF_POWER_HEIGHT", min = 1, max = 20, step = 1 }),
    px({ type = "select", key = P .. "powerBar.position", label = "UF_POWER_POSITION", values = POWER_POS }),
    px({ type = "range", key = P .. "powerBar.gap", label = "UF_POWER_GAP", min = 0, max = 8, step = 1 }),
    px({ type = "texture", key = P .. "powerBar.texture", label = "UF_POWER_TEXTURE", allowDefault = true }),
    px({ type = "select", key = P .. "powerBar.color", label = "UF_POWER_COLOR", values = POWER_COLOR,
      cog = { { type = "color", key = P .. "powerBar.fixed", label = "UF_FIXED_COLOR", token = "accent.primary", reset = true,
                classToken = true } } }),
    px({ type = "toggle", key = P .. "powerBar.smooth", label = "UF_SMOOTH", desc = "UF_SMOOTH_DESC" }),
    { type = "header", label = "GF_POWER_ROLES", icon = "spec" },
    px({ type = "toggle", key = P .. "powerRoles.TANK", label = "GF_POWER_TANK" }),
    px({ type = "toggle", key = P .. "powerRoles.HEALER", label = "GF_POWER_HEALER" }),
    px({ type = "toggle", key = P .. "powerRoles.DAMAGER", label = "GF_POWER_DAMAGER" }),
    ------------------------------------------------------------ text
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "UF_TAGS", icon = "fonts" },
    px({ type = "input", key = P .. "tags.name", label = "UF_TAG_NAME", desc = "UF_TAGS_DESC", keywords = "tags text format" }),
    px({ type = "input", key = P .. "tags.health", label = "UF_TAG_HEALTH", desc = "UF_TAGS_DESC" }),
    px({ type = "input", key = P .. "tags.power", label = "UF_TAG_POWER", desc = "UF_TAGS_DESC" }),
    px({ type = "input", key = P .. "tags.info", label = "UF_TAG_INFO", desc = "UF_TAGS_DESC" }),
    { type = "description", text = "UF_TAGS_HELP", hidden = blizzard },
    { type = "header", label = "UF_TEXT", icon = "fonts" },
    text(P .. "name", "UF_NAME_FONT"),
    text(P .. "health", "UF_HEALTH_FONT"),
    text(P .. "power", "UF_POWER_FONT"),
    text(P .. "info", "UF_INFO_FONT"),
    { type = "header", label = "UF_NAME", icon = "user" },
    px({ type = "range", key = P .. "nameLength", label = "UF_NAME_LENGTH", desc = "UF_NAME_LENGTH_DESC", min = 2, max = 30, step = 1 }),
    px({ type = "select", key = P .. "nameColor", label = "UF_NAME_COLOR", values = NAME_COLOR }),
    ------------------------------------------------------------ indicators
    { type = "tab", label = "UF_TAB_INDICATORS" },
    { type = "header", label = "UF_ICONS", icon = "check" },
    px({ type = "toggle", key = P .. "icons.marker", label = "UF_ICON_MARKER", keywords = "raid target skull",
      cog = { { type = "range", key = P .. "icons.markerSize", label = "ICON_SIZE", min = 8, max = 40, step = 1 },
              { type = "select", key = P .. "icons.markerAnchor", label = "TEXT_POSITION", values = MARKER_ANCHOR } } }),
    px({ type = "toggle", key = P .. "icons.leader", label = "UF_ICON_LEADER" }),
    px({ type = "toggle", key = P .. "icons.role", label = "UF_ICON_ROLE", keywords = "tank healer damage" }),
    px({ type = "toggle", key = P .. "roleCombat", label = "GF_ROLE_COMBAT", desc = "GF_ROLE_COMBAT_DESC" }),
    px({ type = "toggle", key = P .. "icons.threat", label = "GF_AGGRO", desc = "GF_AGGRO_DESC", keywords = "aggro threat" }),
    px({ type = "toggle", key = P .. "icons.ready", label = "UF_ICON_READY", desc = "UF_ICON_READY_DESC",
      keywords = "ready check summon resurrection" }),
    px({ type = "toggle", key = P .. "icons.phase", label = "GF_PHASE", desc = "GF_PHASE_DESC", keywords = "phase shard other group" }),
    px({ type = "range", key = P .. "icons.size", label = "UF_ICON_SIZE", min = 8, max = 32, step = 1 }),
    { type = "header", label = "GF_DISPEL", icon = "auras" },
    px({ type = "select", key = P .. "dispel.mode", label = "GF_DISPEL_MODE", desc = "GF_DISPEL_MODE_DESC", values = DISPEL,
      keywords = "dispel highlight magic curse poison disease" }),
    px({ type = "toggle", key = P .. "dispel.mine", label = "GF_DISPEL_MINE", desc = "GF_DISPEL_MINE_DESC", disabled = dispelOff }),
    { type = "button", label = "GEN_DISPEL_COLORS", desc = "GF_DISPEL_COLORS_DESC", button = "AUTO_OPEN_PAGE", icon = "link",
      keywords = "dispel colour color magic curse poison disease", func = function() ns.Config:Show("General") end },
    px({ type = "range", key = P .. "dispel.size", label = "BORDER_SIZE", min = 1, max = 6, step = 1, disabled = dispelOff }),
    px({ type = "range", key = P .. "dispel.alpha", label = "GF_DISPEL_ALPHA", min = 0.1, max = 1, step = 0.05, percent = true,
      disabled = dispelOff }),
    ------------------------------------------------------------ auras
    { type = "tab", label = "UF_AURAS" },
    { type = "header", label = "GF_BUFFS", icon = "auras" },
    px({ type = "select", key = P .. "groupAuras.buffs.mode", label = "GF_BUFFS_MODE", values = BUFF_MODE,
      keywords = "hot heal over time corner" }),
    px({ type = "select", key = P .. "groupAuras.buffs.filter", label = "UF_BUFF_FILTER", desc = "GF_BUFF_FILTER_DESC",
      values = BUFF_FILTER, disabled = buffsOff }),
    px({ type = "range", key = P .. "groupAuras.buffs.size", label = "ICON_SIZE", min = 6, max = 40, step = 1, disabled = buffsOff }),
    px({ type = "range", key = P .. "groupAuras.buffs.max", label = "UF_AURA_MAX", min = 1, max = 8, step = 1, disabled = buffsOff }),
    { type = "header", label = "GF_DEBUFFS", icon = "warning" },
    px({ type = "select", key = P .. "groupAuras.debuffs.mode", label = "GF_DEBUFFS_MODE", values = DEBUFF_MODE }),
    px({ type = "select", key = P .. "groupAuras.debuffs.filter", label = "UF_DEBUFF_FILTER", desc = "GF_DEBUFF_FILTER_DESC",
      values = DEBUFF_FILTER, disabled = debuffsOff }),
    px({ type = "range", key = P .. "groupAuras.debuffs.size", label = "ICON_SIZE", min = 6, max = 48, step = 1,
      disabled = debuffsOff }),
    px({ type = "range", key = P .. "groupAuras.debuffs.max", label = "UF_AURA_MAX", min = 1, max = 8, step = 1,
      disabled = debuffsOff }),
    { type = "header", label = "GF_DEFENSIVE", icon = "lock" },
    px({ type = "toggle", key = P .. "groupAuras.defensive.enabled", label = "GF_DEFENSIVE_SHOW", desc = "GF_DEFENSIVE_DESC",
      keywords = "big defensive external cooldown" }),
    px({ type = "range", key = P .. "groupAuras.defensive.size", label = "ICON_SIZE", min = 8, max = 48, step = 1,
      disabled = defOff }),
    { type = "header", label = "GF_PRIVATE", icon = "hide" },
    px({ type = "toggle", key = P .. "groupAuras.private.enabled", label = "GF_PRIVATE_SHOW", desc = "GF_PRIVATE_DESC",
      keywords = "private aura boss mechanic" }),
    px({ type = "range", key = P .. "groupAuras.private.size", label = "ICON_SIZE", min = 8, max = 48, step = 1, disabled = privOff }),
    px({ type = "range", key = P .. "groupAuras.private.max", label = "UF_AURA_MAX", min = 1, max = 4, step = 1, disabled = privOff }),
    px({ type = "toggle", key = P .. "groupAuras.private.countdown", label = "GF_PRIVATE_SWIPE", disabled = privOff }),
    px({ type = "toggle", key = P .. "groupAuras.private.numbers", label = "GF_PRIVATE_NUMBERS", disabled = privOff }),
    { type = "header", label = "GF_AURA_LOOK", icon = "palette" },
    px({ type = "range", key = P .. "auras.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 }),
    px({ type = "toggle", key = P .. "auras.swipe", label = "UF_SWIPE" }),
    px({ type = "toggle", key = P .. "auras.dispel", label = "UF_DISPEL", desc = "UF_DISPEL_DESC" }),
    px({ type = "toggle", key = P .. "auras.tooltips", label = "UF_AURA_TIPS", desc = "UF_AURA_TIPS_DESC" }),
    px(Opt.Border(P .. "auras.border", "UF_AURA_BORDER")),
    px(Opt.Text(P .. "auras.duration", "UF_AURA_DURATION_FONT", { place = true, show = true, max = 20 })),
    px(Opt.Text(P .. "auras.count", "UF_AURA_COUNT_FONT", { place = true, max = 20 })),
    { type = "description", text = "GF_NOTE", hidden = phoenix },
})
