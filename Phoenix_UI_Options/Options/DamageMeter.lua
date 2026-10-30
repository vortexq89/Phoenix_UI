local _, ns = ...
local L, Opt = ns.L, ns.Opt

local dmGet, dmSet = ns.Combat.CVarAccessors("damageMeterEnabled")
local function unskinned(m) return not m.db.skin end
local function noThreat(m) return not m.db.threat.enabled end
local function noBg(m) return unskinned(m) or not m.db.bg.show end
local function skinned(row) return Opt.With(row, { disabled = row.disabled or unskinned }) end

-- Bar height and spacing, class colours, number format, spec icons, visibility and extra windows are the
-- meter's Edit Mode settings: one button opens them (the skin never calls the meter's own setters).
local function openEditMode() ns.Config.frame:Hide(); ns.EditMode:Open() end

local function blizzard(m) return m.db.engine ~= "phoenix" end
local function notPhoenix(m) return m.db.engine ~= "phoenix" end
local function meter(row) return Opt.With(row, { disabled = row.disabled or notPhoenix }) end
-- The meter's modes come from the plugin's code, which may load after this file (Phoenix > Plugins).
local MODE_VALUES = {}
local function fillModes()
    local dm = ns:Loaded("DamageMeter")
    if #MODE_VALUES > 0 or not (dm and dm.MODES) then return end
    for _, g in ipairs(dm.MODES) do
        for _, md in ipairs(g) do MODE_VALUES[#MODE_VALUES + 1] = { value = md.id, label = md.label } end
    end
end
fillModes()
ns.Events:Listen("PUI_MODULE_STATE", MODE_VALUES, fillModes)
local function windowRows(i, head)
    local base = "meter.win" .. i
    local function off(m) return notPhoenix(m) or m.db.meter.windows < i end
    return {
        head,
        { type = "select", key = base .. ".type", label = "DM_WIN_MODE", desc = "DM_WIN_MODE_DESC", values = MODE_VALUES,
          disabled = off, keywords = "damage healing dps hps interrupts dispels deaths taken" },
        { type = "toggle", key = base .. ".overall", label = "DM_WIN_OVERALL", desc = "DM_WIN_OVERALL_DESC", disabled = off },
    }
end

local function customOff(m) return notPhoenix(m) or m.db.meter.barColor ~= "custom" end
local rows = {
    { type = "preview", kind = "damagemeter" },
    { type = "header", label = "DM_ENGINE", icon = "damagemeter" },
    { type = "select", key = "engine", label = "DM_ENGINE", desc = "DM_ENGINE_DESC", values = {
        { value = "phoenix", label = "DM_ENGINE_PHOENIX" }, { value = "blizzard", label = "DM_ENGINE_BLIZZARD" },
    }, keywords = "dps meter details skada recount" },
    meter({ type = "select", key = "meter.preset", label = "DM_PRESET", desc = "DM_PRESET_DESC", values = {
        { value = "solo", label = "DM_PRESET_SOLO" }, { value = "dps", label = "DM_PRESET_DPS" },
        { value = "healer", label = "DM_PRESET_HEALER" }, { value = "tank", label = "DM_PRESET_TANK" },
        { value = "raid", label = "DM_PRESET_RAID" }, { value = "mplus", label = "DM_PRESET_MPLUS" },
    } }),
    meter({ type = "button", label = "DM_PRESET_APPLY", desc = "DM_PRESET_APPLY_DESC", button = "APPLY",
      func = function(m) m:ApplyPreset(m.db.meter.preset) end }),
    { type = "header", label = "DM_WINDOWS", icon = "skins" },
    meter({ type = "range", key = "meter.windows", label = "DM_WINDOW_COUNT", desc = "DM_WINDOW_COUNT_DESC", min = 1, max = 3, step = 1 }),
    meter({ type = "range", key = "meter.width", label = "UF_WIDTH", min = 160, max = 520, step = 1 }),
    meter({ type = "range", key = "meter.rows", label = "DM_ROWS", min = 3, max = 25, step = 1 }),
    meter({ type = "range", key = "meter.rowHeight", label = "DM_ROW_HEIGHT", min = 12, max = 32, step = 1 }),
    meter({ type = "range", key = "meter.spacing", label = "DM_ROW_SPACING", min = 0, max = 8, step = 1 }),
    meter({ type = "range", key = "meter.headerHeight", label = "DM_HEADER_HEIGHT", min = 18, max = 32, step = 1 }),
    meter({ type = "toggle", key = "meter.hideReset", label = "DM_HIDE_RESET" }),
    meter({ type = "toggle", key = "meter.lock", label = "DM_LOCK", desc = "DM_LOCK_DESC" }),
    meter({ type = "select", key = "meter.headerColor", label = "DM_HEADER_COLOR", desc = "DM_HEADER_COLOR_DESC", values = {
        { value = "theme", label = "DM_COLOR_ACCENT" }, { value = "class", label = "DM_COLOR_CLASS" },
        { value = "custom", label = "DM_COLOR_CUSTOM" }, { value = "none", label = "DM_HEADER_NONE" },
    } }),
    meter({ type = "color", key = "meter.headerCustom", label = "DM_HEADER_CUSTOM",
      disabled = function(m) return m.db.meter.headerColor ~= "custom" end }),
    meter({ type = "range", key = "meter.headerAlpha", label = "DM_HEADER_ALPHA", desc = "DM_HEADER_ALPHA_DESC",
      min = 0, max = 1, step = 0.05, percent = true, disabled = function(m) return m.db.meter.headerColor == "none" end }),
    { type = "header", label = "DM_ROWS_LOOK", icon = "damagemeter" },
    { type = "texture", key = "bar.texture", label = "DM_BAR_TEXTURE", desc = "DM_BAR_TEXTURE_DESC", allowDefault = true,
      keywords = "bar texture statusbar" },
    meter({ type = "select", key = "meter.barColor", label = "DM_BAR_COLOR", values = {
        { value = "class", label = "DM_COLOR_CLASS" }, { value = "accent", label = "DM_COLOR_ACCENT" },
        { value = "custom", label = "DM_COLOR_CUSTOM" },
    } }),
    meter({ type = "color", key = "meter.customColor", label = "DM_CUSTOM_COLOR", disabled = customOff }),
    meter({ type = "range", key = "meter.barAlpha", label = "DM_BAR_ALPHA", min = 0.2, max = 1, step = 0.05 }),
    meter({ type = "range", key = "meter.trackAlpha", label = "DM_TRACK_ALPHA", min = 0, max = 1, step = 0.05 }),
    meter({ type = "toggle", key = "meter.sheen", label = "DM_SHEEN" }),
    Opt.Text("name", "DM_NAME_FONT", { min = 8, max = 24 }),
    Opt.Text("value", "DM_VALUE_FONT", { min = 8, max = 24 }),
    meter({ type = "toggle", key = "meter.nameClassColor", label = "DM_NAME_CLASS" }),
    meter({ type = "toggle", key = "meter.valueClassColor", label = "DM_VALUE_CLASS" }),
    meter({ type = "toggle", key = "meter.specIcon", label = "DM_SPEC_ICON" }),
    meter({ type = "select", key = "meter.iconStyle", label = "SPECICON_STYLE", desc = "DM_ICON_STYLE_DESC",
      values = ns.SpecIcon.Values(true), disabled = function(m) return not m.db.meter.specIcon end }),
    meter({ type = "custom", label = "SPECICON_SAMPLES", build = function(row)
        local dm = ns.modules.DamageMeter
        return ns.SpecIcon.Strip(row, function() return ns.SpecIcon.Resolve(dm.db.meter.iconStyle) end,
            function(v) ns.DB:Set(dm, "meter.iconStyle", v); dm:Refresh() end)
    end }),
    meter({ type = "select", key = "meter.iconBorder", label = "DM_ICON_BORDER", values = {
        { value = "none", label = "DM_BORDER_NONE" }, { value = "theme", label = "DM_BORDER_THEME" },
        { value = "class", label = "DM_COLOR_CLASS" },
    }, disabled = function(m) return not m.db.meter.specIcon end }),
    meter({ type = "select", key = "meter.ilvl", label = "DM_ILVL", desc = "DM_ILVL_DESC", values = {
        { value = "off", label = "DM_ILVL_OFF" }, { value = "name", label = "DM_ILVL_NAME" },
        { value = "tooltip", label = "DM_ILVL_TOOLTIP" },
    } }),
    meter({ type = "range", key = "meter.nameX", label = "DM_NAME_X", min = -20, max = 40, step = 1 }),
    meter({ type = "range", key = "meter.nameY", label = "DM_NAME_Y", min = -10, max = 10, step = 1 }),
    meter({ type = "range", key = "meter.valueX", label = "DM_VALUE_X", min = -40, max = 20, step = 1 }),
    meter({ type = "range", key = "meter.valueY", label = "DM_VALUE_Y", min = -10, max = 10, step = 1 }),
    meter({ type = "toggle", key = "meter.rank", label = "DM_RANK" }),
    meter({ type = "select", key = "meter.valueFormat", label = "DM_VALUE_FORMAT", desc = "DM_VALUE_FORMAT_DESC", values = {
        { value = "both", label = "DM_FMT_BOTH" }, { value = "pipe", label = "DM_FMT_PIPE" },
        { value = "total", label = "DM_FMT_TOTAL" }, { value = "rate", label = "DM_FMT_RATE" },
    } }),
    meter({ type = "toggle", key = "meter.clock", label = "DM_CLOCK", desc = "DM_CLOCK_DESC" }),
    { type = "header", label = "DM_BIGTIMER", icon = "encounters" },
    meter({ type = "toggle", key = "meter.bigTimer.enabled", label = "DM_BIGTIMER_ON", desc = "DM_BIGTIMER_DESC" }),
    meter({ type = "toggle", key = "meter.bigTimer.combatOnly", label = "DM_BIGTIMER_COMBAT",
      disabled = function(m) return not m.db.meter.bigTimer.enabled end }),
    meter({ type = "toggle", key = "meter.bigTimer.label", label = "DM_BIGTIMER_SHOW_LABEL",
      disabled = function(m) return not m.db.meter.bigTimer.enabled end }),
    meter(Opt.Text("bigTimerText", "DM_BIGTIMER_FONT", { min = 16, max = 64 })),
    { type = "header", label = "DM_BEHAVIOUR", icon = "general" },
    meter({ type = "select", key = "meter.visibility", label = "DM_VISIBILITY", values = {
        { value = "always", label = "DM_VIS_ALWAYS" }, { value = "combat", label = "DM_VIS_COMBAT" },
        { value = "group", label = "DM_VIS_GROUP" },
    } }),
    meter({ type = "select", key = "meter.filter", label = "DM_FILTER", desc = "DM_FILTER_DESC", values = {
        { value = "all", label = "DM_FILTER_ALL" }, { value = "TANK", label = "DM_FILTER_TANK" },
        { value = "HEALER", label = "DM_FILTER_HEALER" }, { value = "DAMAGER", label = "DM_FILTER_DAMAGER" },
    } }),
    meter({ type = "toggle", key = "meter.pinSelf", label = "DM_PIN_SELF", desc = "DM_PIN_SELF_DESC" }),
    meter({ type = "toggle", key = "meter.tooltip", label = "DM_TOOLTIP", desc = "DM_TOOLTIP_DESC" }),
    meter({ type = "range", key = "meter.idleAlpha", label = "DM_IDLE_ALPHA", desc = "DM_IDLE_ALPHA_DESC",
      min = 0.1, max = 1, step = 0.05 }),
    meter({ type = "range", key = "meter.rate", label = "DM_RATE", desc = "DM_RATE_DESC",
      min = 0.1, max = 2, step = 0.1 }),
    meter({ type = "button", label = "DM_RESET_ALL", desc = "DM_RESET_ALL_DESC", button = "DM_RESET",
      func = function(m) m:ResetData() end }),
    { type = "header", label = "DM_REPORT", icon = "chat" },
    meter({ type = "select", key = "meter.reportChannel", label = "DM_REPORT_CHANNEL", values = function(m) return m.CHANNELS end }),
    meter({ type = "button", label = "DM_REPORT_NOW", desc = "DM_REPORT_NOW_DESC", button = "DM_REPORT",
      func = function(m) local w = m.meterWindows[1]; if w then m:Report(w, m.db.meter.reportChannel) end end }),
    meter({ type = "range", key = "meter.reportLines", label = "DM_REPORT_LINES", min = 1, max = 25, step = 1 }),
    meter({ type = "description", text = "DM_REPORT_TEXT" }),
    { type = "header", label = "DM_KEYS", icon = "editmode" },
    meter({ type = "input", key = "meter.toggleKey", label = "DM_KEY_TOGGLE", desc = "DM_KEY_DESC", combat = true,
      keywords = "keybind hotkey shortcut" }),
    meter({ type = "input", key = "meter.resetKey", label = "DM_KEY_RESET", desc = "DM_KEY_DESC", combat = true,
      keywords = "keybind hotkey shortcut" }),
}
local heads = {
    { type = "header", label = "DM_WIN_1", icon = "damagemeter" },
    { type = "header", label = "DM_WIN_2", icon = "damagemeter" },
    { type = "header", label = "DM_WIN_3", icon = "damagemeter" },
}
for i = 1, 3 do for _, r in ipairs(windowRows(i, heads[i])) do rows[#rows + 1] = r end end
for _, r in ipairs({
    { type = "header", label = "BLIZZARD_FEATURES", icon = "general" },
    { type = "toggle", label = "DM_ENABLE", desc = "DM_ENABLE_DESC", get = dmGet, set = dmSet, combat = true, keywords = "dps meter",
      disabled = function(m) return not blizzard(m) end },
    { type = "header", label = "DM_STYLE", icon = "theme" },
    { type = "toggle", key = "skin", label = "DM_SKIN", desc = "DM_SKIN_DESC" },
    { type = "header", label = "DM_BARS", icon = "damagemeter" },
    skinned({ type = "toggle", key = "bar.reverse", label = "CB_REVERSE", desc = "DM_REVERSE_DESC",
      keywords = "fill direction right left" }),
    skinned({ type = "range", key = "bar.shade", label = "UF_SHADE", desc = "UF_SHADE_DESC", min = 0, max = 0.8, step = 0.05,
      keywords = "gradient shade depth" }),
    { type = "header", label = "DM_WINDOW", icon = "skins" },
    skinned({ type = "toggle", gate = true, key = "bg.show", label = "DM_BG", desc = "DM_BG_DESC", keywords = "background window" }),
    Opt.With(Opt.Background("bg", "DM_BG_OPACITY", "bg.base"), { disabled = noBg }),
    skinned(Opt.Border("border", "DM_BORDER", "border.subtle")),
    { type = "header", label = "DM_THREAT", icon = "damagemeter", feature = "threatMeter" },
    { type = "toggle", key = "threat.enabled", label = "DM_THREAT_SHOW", desc = "DM_THREAT_DESC", feature = "threatMeter",
      keywords = "threat aggro tank pull meter" },
    { type = "toggle", key = "threat.combatOnly", label = "DM_THREAT_COMBAT", feature = "threatMeter", disabled = noThreat },
    { type = "range", key = "threat.rows", label = "DM_THREAT_ROWS", min = 1, max = 10, step = 1, feature = "threatMeter",
      disabled = noThreat },
    { type = "range", key = "threat.width", label = "UF_WIDTH", min = 120, max = 400, step = 1, feature = "threatMeter",
      disabled = noThreat },
    { type = "header", label = "DM_EDIT_MODE", icon = "editmode" },
    { type = "description", text = "DM_EDIT_MODE_TEXT" },
    { type = "button", label = "DM_EDIT_MODE_OPEN", desc = "DM_EDIT_MODE_OPEN_DESC", button = "OPEN_EDIT_MODE", icon = "editmode",
      combat = true, func = openEditMode,
      keywords = "bar height spacing class colours number format spec icons visibility combat group second window" },
    { type = "header", label = "DM_DETAILS", icon = "damagemeter" },
    { type = "description", text = "DM_DETAILS_TEXT" },
    { type = "button", label = "DM_DETAILS_APPLY", desc = "DM_DETAILS_APPLY_DESC", button = "APPLY", variant = "primary",
      disabled = function(m) return not m:DetailsLoaded() end,
      func = function(m)
          local ok, count = m:ApplyDetails()
          ns.Config:SetStatus(ok and L.DM_DETAILS_DONE:format(count) or L.DM_DETAILS_MISSING, ok and "state.success" or "state.danger")
      end },
}) do rows[#rows + 1] = r end

ns:RegisterOptions("DamageMeter", rows)
