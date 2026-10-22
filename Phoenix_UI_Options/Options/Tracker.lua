local _, ns = ...
local Opt = ns.Opt

local function unstyled(m, key) return not m:Viewer(key).style end
local function round(m, key) return unstyled(m, key) or not m:Viewer(key).square end
local function notBars(_, key) return key ~= "bars" end

ns:RegisterOptions("Tracker", {
    { type = "scope", key = "viewers", label = "TRACKER_VIEWER", values = {
        { value = "essential", label = "TRACKER_ESSENTIAL" }, { value = "utility", label = "TRACKER_UTILITY" },
        { value = "buffs", label = "TRACKER_BUFFS" }, { value = "bars", label = "TRACKER_BARS" },
    } },
    { type = "preview", kind = "tracker" },
    { type = "tab", label = "TAB_APPEARANCE" },
    { type = "header", label = "TRACKER_ICONS", icon = "tracker" },
    { type = "toggle", gate = true, key = "viewers.@.style", label = "TRACKER_SKIN", desc = "TRACKER_SKIN_DESC", reload = true,
      keywords = "cooldown manager weakauras skin" },
    { type = "toggle", key = "viewers.@.square", label = "TRACKER_SQUARE", desc = "TRACKER_SQUARE_DESC", disabled = unstyled,
      cog = { { type = "range", key = "viewers.@.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } },
    Opt.With(Opt.Border("viewers.@.border"), { disabled = round }),
    { type = "toggle", key = "viewers.@.hideDebuffBorder", label = "TRACKER_DEBUFF_BORDER", desc = "TRACKER_DEBUFF_BORDER_DESC",
      disabled = unstyled },
    { type = "header", label = "TRACKER_BAR", icon = "textures", hidden = notBars },
    { type = "texture", key = "viewers.@.texture", label = "BAR_TEXTURE", allowDefault = true, hidden = notBars, disabled = unstyled },
    { type = "color", key = "viewers.@.barColor", label = "TRACKER_BAR_COLOR", token = "accent.primary", reset = true,
      hidden = notBars, disabled = unstyled },
    Opt.With(Opt.Background("viewers.@.background"), { hidden = notBars, disabled = unstyled }),
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "TRACKER_TEXT", icon = "fonts", wide = true },
    Opt.Text("viewers.@.timer", "TRACKER_TIMER_FONT", { max = 28, row = { disabled = unstyled } }),
    Opt.Text("viewers.@.count", "TRACKER_COUNT_FONT", { max = 24, row = { disabled = unstyled } }),
    Opt.Text("viewers.@.name", "TRACKER_NAME_FONT", { max = 20, row = { disabled = unstyled, hidden = notBars } }),
    { type = "tab", label = "TAB_BEHAVIOUR" },
    { type = "header", label = "TRACKER_FADE", icon = "opacity" },
    { type = "toggle", key = "fade.enabled", label = "TRACKER_FADE_OOC", desc = "TRACKER_FADE_OOC_DESC",
      keywords = "hide out of combat opacity alpha",
      cog = { { type = "range", key = "fade.alpha", label = "TRACKER_FADE_ALPHA", min = 0, max = 1, step = 0.05, percent = true } } },
    { type = "button", label = "TRACKER_OPEN_CDM", desc = "TRACKER_OPEN_CDM_DESC", button = "BUGS_OPEN", icon = "tracker",
      keywords = "cooldown manager spells auras choose", func = function(m) m:OpenCooldownManager() end },
    { type = "description", text = "TRACKER_NOTE" },
})
