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
local MODE_VALUES = {}
for _, g in ipairs(ns.modules.DamageMeter.MODES) do
    for _, md in ipairs(g) do MODE_VALUES[#MODE_VALUES + 1] = { value = md.id, label = md.label } end
end
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

local rows = {
    { type = "preview", kind = "damagemeter" },
    { type = "header", label = "DM_ENGINE", icon = "damagemeter" },
    { type = "select", key = "engine", label = "DM_ENGINE", desc = "DM_ENGINE_DESC", values = {
        { value = "phoenix", label = "DM_ENGINE_PHOENIX" }, { value = "blizzard", label = "DM_ENGINE_BLIZZARD" },
    }, keywords = "dps meter details skada recount" },
    { type = "header", label = "DM_WINDOWS", icon = "skins" },
    meter({ type = "range", key = "meter.windows", label = "DM_WINDOW_COUNT", desc = "DM_WINDOW_COUNT_DESC", min = 1, max = 3, step = 1 }),
    meter({ type = "range", key = "meter.width", label = "UF_WIDTH", min = 160, max = 520, step = 1 }),
    meter({ type = "range", key = "meter.rows", label = "DM_ROWS", min = 3, max = 25, step = 1 }),
    meter({ type = "range", key = "meter.rowHeight", label = "DM_ROW_HEIGHT", min = 12, max = 32, step = 1 }),
    meter({ type = "range", key = "meter.spacing", label = "DM_ROW_SPACING", min = 0, max = 8, step = 1 }),
    { type = "header", label = "DM_ROWS_LOOK", icon = "damagemeter" },
    meter({ type = "toggle", key = "meter.classColor", label = "DM_CLASS_COLOR", desc = "DM_CLASS_COLOR_DESC" }),
    meter({ type = "toggle", key = "meter.specIcon", label = "DM_SPEC_ICON" }),
    meter({ type = "toggle", key = "meter.rank", label = "DM_RANK" }),
    meter({ type = "select", key = "meter.valueFormat", label = "DM_VALUE_FORMAT", desc = "DM_VALUE_FORMAT_DESC", values = {
        { value = "both", label = "DM_FMT_BOTH" }, { value = "total", label = "DM_FMT_TOTAL" }, { value = "rate", label = "DM_FMT_RATE" },
    } }),
    meter({ type = "toggle", key = "meter.clock", label = "DM_CLOCK", desc = "DM_CLOCK_DESC" }),
    { type = "header", label = "DM_BEHAVIOUR", icon = "general" },
    meter({ type = "select", key = "meter.visibility", label = "DM_VISIBILITY", values = {
        { value = "always", label = "DM_VIS_ALWAYS" }, { value = "combat", label = "DM_VIS_COMBAT" },
        { value = "group", label = "DM_VIS_GROUP" },
    } }),
    meter({ type = "range", key = "meter.idleAlpha", label = "DM_IDLE_ALPHA", desc = "DM_IDLE_ALPHA_DESC",
      min = 0.1, max = 1, step = 0.05 }),
    meter({ type = "range", key = "meter.rate", label = "DM_RATE", desc = "DM_RATE_DESC",
      min = 0.1, max = 2, step = 0.1 }),
    meter({ type = "button", label = "DM_RESET_ALL", desc = "DM_RESET_ALL_DESC", button = "DM_RESET",
      func = function(m) m:ResetData() end }),
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
    skinned({ type = "texture", key = "bar.texture", label = "DM_BAR_TEXTURE", desc = "DM_BAR_TEXTURE_DESC", allowDefault = true,
      keywords = "bar texture statusbar" }),
    skinned({ type = "toggle", key = "bar.reverse", label = "CB_REVERSE", desc = "DM_REVERSE_DESC",
      keywords = "fill direction right left" }),
    skinned({ type = "range", key = "bar.shade", label = "UF_SHADE", desc = "UF_SHADE_DESC", min = 0, max = 0.8, step = 0.05,
      keywords = "gradient shade depth" }),
    skinned(Opt.Text("name", "DM_NAME_FONT", { min = 8, max = 24 })),
    skinned(Opt.Text("value", "DM_VALUE_FONT", { min = 8, max = 24 })),
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
