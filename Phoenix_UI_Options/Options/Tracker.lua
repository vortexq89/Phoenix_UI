local _, ns = ...
local Opt = ns.Opt

local function unstyled(m, key) return not m:Viewer(key).style end
local function round(m, key) return unstyled(m, key) or not m:Viewer(key).square end
local function notBars(_, key) return key ~= "bars" end
local function noVoice(m) return not m.db.countdown.enabled end

local function voices()
    local out = {}
    for _, v in ipairs(ns.Media.voices) do out[#out + 1] = { value = v.key, label = v.name } end
    return out
end

ns:RegisterOptions("Tracker", {
    { type = "scope", key = "viewers", label = "TRACKER_VIEWER", values = {
        { value = "essential", label = "TRACKER_ESSENTIAL" }, { value = "utility", label = "TRACKER_UTILITY" },
        { value = "buffs", label = "TRACKER_BUFFS" }, { value = "bars", label = "TRACKER_BARS" },
    } },
    { type = "preview", kind = "tracker" },
    { type = "tab", label = "TAB_APPEARANCE" },
    { type = "header", label = "TRACKER_ICONS" },
    { type = "toggle", key = "viewers.@.style", label = "TRACKER_SKIN", desc = "TRACKER_SKIN_DESC", reload = true,
      keywords = "cooldown manager weakauras skin" },
    { type = "toggle", key = "viewers.@.square", label = "TRACKER_SQUARE", desc = "TRACKER_SQUARE_DESC", disabled = unstyled,
      cog = { { type = "range", key = "viewers.@.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } },
    Opt.With(Opt.Border("viewers.@.border"), { disabled = round }),
    { type = "toggle", key = "viewers.@.hideDebuffBorder", label = "TRACKER_DEBUFF_BORDER", desc = "TRACKER_DEBUFF_BORDER_DESC",
      disabled = unstyled },
    { type = "header", label = "TRACKER_BAR", hidden = notBars },
    { type = "texture", key = "viewers.@.texture", label = "BAR_TEXTURE", allowDefault = true, hidden = notBars, disabled = unstyled },
    { type = "color", key = "viewers.@.barColor", label = "TRACKER_BAR_COLOR", token = "accent.primary", reset = true,
      hidden = notBars, disabled = unstyled },
    Opt.With(Opt.Background("viewers.@.background"), { hidden = notBars, disabled = unstyled }),
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "TRACKER_TEXT", wide = true },
    Opt.Text("viewers.@.timer", "TRACKER_TIMER_FONT", { max = 28, row = { disabled = unstyled } }),
    Opt.Text("viewers.@.count", "TRACKER_COUNT_FONT", { max = 24, row = { disabled = unstyled } }),
    Opt.Text("viewers.@.name", "TRACKER_NAME_FONT", { max = 20, row = { disabled = unstyled, hidden = notBars } }),
    { type = "tab", label = "TAB_BEHAVIOUR" },
    { type = "header", label = "TRACKER_FADE" },
    { type = "toggle", key = "fade.enabled", label = "TRACKER_FADE_OOC", desc = "TRACKER_FADE_OOC_DESC",
      keywords = "hide out of combat opacity alpha",
      cog = { { type = "range", key = "fade.alpha", label = "TRACKER_FADE_ALPHA", min = 0, max = 1, step = 0.05, percent = true } } },
    { type = "header", label = "TRACKER_COUNTDOWN" },
    { type = "toggle", key = "countdown.enabled", label = "TRACKER_VOICE", desc = "TRACKER_VOICE_DESC",
      keywords = "pull timer countdown voice sound" },
    { type = "select", key = "countdown.voice", label = "TRACKER_VOICE_PICK", values = voices, disabled = noVoice },
    { type = "range", key = "countdown.from", label = "TRACKER_VOICE_FROM", min = 3, max = 10, step = 1, disabled = noVoice },
    { type = "toggle", key = "countdown.pull", label = "TRACKER_VOICE_PULL", desc = "TRACKER_VOICE_PULL_DESC", disabled = noVoice },
    { type = "toggle", key = "countdown.timers", label = "TRACKER_VOICE_TIMERS", desc = "TRACKER_VOICE_TIMERS_DESC",
      disabled = noVoice },
    { type = "button", label = "TRACKER_VOICE_TEST", desc = "TRACKER_VOICE_TEST_DESC", button = "MEDIA_PLAY", icon = "sound",
      func = function(m) m:TestCountdown() end },
    { type = "button", label = "TRACKER_OPEN_CDM", desc = "TRACKER_OPEN_CDM_DESC", button = "BUGS_OPEN", icon = "tracker",
      keywords = "cooldown manager spells auras choose", func = function(m) m:OpenCooldownManager() end },
    { type = "description", text = "TRACKER_NOTE" },
})
