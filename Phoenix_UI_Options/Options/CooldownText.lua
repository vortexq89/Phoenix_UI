local _, ns = ...
local Opt = ns.Opt

local cdGet, cdSet = ns.Combat.CVarAccessors("countdownForCooldowns")
local function plain(m) return not m.db.byRemaining end

ns:RegisterOptions("CooldownText", {
    { type = "preview", kind = "cooldowntext" },
    { type = "header", label = "CD_COUNTDOWN", icon = "cooldowntext" },
    { type = "toggle", label = "CD_NUMBERS", desc = "CD_NUMBERS_DESC", get = cdGet, set = cdSet, combat = true,
      keywords = "countdown omnicc timer" },
    { type = "font", key = "font", label = "CD_FONT", allowDefault = true, keywords = "font countdown" },
    { type = "range", key = "size", label = "FONT_SIZE", min = 6, max = 40, step = 1 },
    { type = "select", key = "outline", label = "FONT_OUTLINE", values = Opt.OUTLINE },
    { type = "toggle", key = "shadow", label = "FONT_SHADOW" },
    { type = "color", key = "color", label = "CD_COLOR", disabled = function(m) return m.db.byRemaining end },
    { type = "toggle", key = "scale", label = "CD_SCALE", desc = "CD_SCALE_DESC", keywords = "icon size scale" },
    { type = "header", label = "CD_TIMING", icon = "clock" },
    { type = "range", key = "decimals", label = "CD_DECIMALS", desc = "CD_DECIMALS_DESC", min = 0, max = 10, step = 0.5 },
    { type = "range", key = "minDuration", label = "CD_MIN", desc = "CD_MIN_DESC", min = 0, max = 10, step = 0.5 },
    { type = "toggle", key = "hideAuras", label = "CD_HIDE_AURAS", desc = "CD_HIDE_AURAS_DESC", keywords = "buff debuff aura" },
    { type = "header", label = "CD_REMAINING", icon = "palette" },
    { type = "toggle", gate = true, key = "byRemaining", label = "CD_BY_REMAINING", desc = "CD_BY_REMAINING_DESC",
      keywords = "colour color red expiring" },
    { type = "colors", keys = { "colors.expiring", "colors.seconds", "colors.minutes" },
      tokens = { "state.danger", "state.warning", "text.primary" }, label = "CD_REMAINING_COLORS",
      labels = { "CD_EXPIRING", "CD_SECONDS", "CD_MINUTES" }, disabled = plain },
    { type = "range", key = "expiring", label = "CD_EXPIRING_AT", desc = "CD_EXPIRING_AT_DESC", min = 0, max = 10, step = 0.5,
      disabled = plain },
})
