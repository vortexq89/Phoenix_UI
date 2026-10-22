local _, ns = ...
local L, Opt = ns.L, ns.Opt
local CVar = ns.Combat.CVarAccessors
local M = ns.modules.Encounters

local function notBars(m) return m.db.timeline.display ~= "phoenix" end
local function notBanner(m) return m.db.warnings.display ~= "phoenix" end
local function noVoice(m) return not m.db.countdown.enabled end
local function noEmphasis(m) return notBars(m) or not m.db.timeline.emphasize end

local masterGet, masterSet = CVar("combatWarningsEnabled")

-- Blizzard settings shown as rows (the game applies them to its own timeline and banner).
-- row = { label, desc, … } plus the CVar's get/set.
local function cvarToggle(cvar, row)
    row.type, row.combat = "toggle", true
    row.get, row.set = CVar(cvar)
    return row
end

-- One toggle per role / spell-support icon set the timeline can draw (Enum.EncounterTimelineIconSet).
local function iconSet(set, row)
    row.type, row.combat = "toggle", true
    row.get = function(m) return m:IconSetShown(set) end
    row.set = function(m, v) m:SetIconSetShown(set, v) end
    return row
end

local function sounds()
    local out = { { value = "blizzard", label = "ENC_SOUND_GAME" }, { value = "none", label = "NONE" } }
    for _, s in ipairs(ns.Media:List("sound")) do out[#out + 1] = { value = s.value, label = s.label } end
    return out
end

local function voices()
    local out = {}
    for _, v in ipairs(ns.Media.voices) do out[#out + 1] = { value = v.key, label = v.name } end
    return out
end

local function status()
    local mod = M and M:BossMod()
    if mod then return L.ENC_BOSSMOD_NOTE:format(mod) end
    if M and not M:HasFeature("timeline") then return L.ENC_NOTE_TIMERS end
    return L.ENC_NOTE
end

local ICON_SETS = Enum.EncounterTimelineIconSet

-- The test button; what it shows depends on whether this client has the game's timeline (M:Test).
-- t = { desc, status (shown while it runs), feature }
local function testRow(t)
    return { type = "button", label = "ENC_TEST", desc = t.desc, feature = t.feature, button = "ENC_TEST_BUTTON",
        icon = "test", variant = "primary", keywords = "test preview sample boss", func = function(m)
            if m:Test() then ns.Config:SetStatus(L[t.status], "state.success", "test") end
        end }
end

ns:RegisterOptions("Encounters", {
    { type = "preview", kind = "encounters" },
    { type = "header", label = "ENC_START", icon = "encounters" },
    { type = "toggle", label = "ENC_MASTER", desc = "ENC_MASTER_DESC", get = masterGet, set = masterSet, combat = true,
      feature = "encounterAlerts", keywords = "boss warnings timeline combat warnings blizzard" },
    testRow({ desc = "ENC_TEST_DESC", status = "ENC_TEST_RUNNING", feature = "encounterTimeline" }),
    -- no game timeline (WoW Forever): the test is a pull bar
    testRow({ desc = "ENC_TEST_TIMERS_DESC", status = "ENC_TEST_PULL_RUNNING", feature = "!encounterTimeline" }),
    { type = "description", text = status },

    { type = "tab", label = "ENC_TAB_TIMELINE", feature = "encounterTimeline" },
    { type = "header", label = "ENC_TIMELINE", icon = "encounters" },
    { type = "select", key = "timeline.display", label = "ENC_TIMELINE_DISPLAY", desc = "ENC_TIMELINE_DISPLAY_DESC",
      keywords = "boss timers bars timeline bigwigs dbm", values = {
        { value = "phoenix", label = "ENC_DISPLAY_PHOENIX" }, { value = "blizzard", label = "ENC_DISPLAY_BLIZZARD" } } },
    cvarToggle("encounterTimelineHideLongCountdowns", { label = "ENC_HIDE_LONG", desc = "ENC_HIDE_LONG_DESC" }),
    cvarToggle("encounterTimelineHideQueuedCountdowns", { label = "ENC_HIDE_QUEUED", desc = "ENC_HIDE_QUEUED_DESC" }),
    cvarToggle("encounterTimelineHideForOtherRoles", { label = "ENC_HIDE_ROLES", desc = "ENC_HIDE_ROLES_DESC" }),
    cvarToggle("encounterTimelineShowSequenceCount", { label = "ENC_SEQUENCE", desc = "ENC_SEQUENCE_DESC" }),
    cvarToggle("encounterTimelineIconographyEnabled", { label = "ENC_ICONOGRAPHY", desc = "ENC_ICONOGRAPHY_DESC", cog = {
        iconSet(ICON_SETS.TankAlert, { label = "ENC_ICONS_TANK" }), iconSet(ICON_SETS.HealerAlert, { label = "ENC_ICONS_HEALER" }),
        iconSet(ICON_SETS.DamageAlert, { label = "ENC_ICONS_DAMAGE" }), iconSet(ICON_SETS.Dispel, { label = "ENC_ICONS_DISPEL" }),
        iconSet(ICON_SETS.Enrage, { label = "ENC_ICONS_ENRAGE" }), iconSet(ICON_SETS.Deadly, { label = "ENC_ICONS_DEADLY" }),
    } }),
    { type = "header", label = "ENC_BARS", icon = "textures" },
    { type = "range", key = "timeline.width", label = "ENC_WIDTH", min = 120, max = 500, step = 2, disabled = notBars },
    { type = "range", key = "timeline.height", label = "ENC_HEIGHT", min = 12, max = 40, step = 1, disabled = notBars },
    { type = "range", key = "timeline.spacing", label = "ENC_SPACING", min = 0, max = 12, step = 1, disabled = notBars },
    { type = "range", key = "timeline.max", label = "ENC_MAX_BARS", min = 3, max = 15, step = 1, disabled = notBars },
    { type = "range", key = "timeline.horizon", label = "ENC_HORIZON", desc = "ENC_HORIZON_DESC", min = 0, max = 120,
      step = 5, disabled = notBars },
    { type = "select", key = "timeline.grow", label = "ENC_GROW", disabled = notBars, values = {
        { value = "UP", label = "ENC_GROW_UP", icon = "arrow-up" }, { value = "DOWN", label = "ENC_GROW_DOWN", icon = "arrow-down" } } },
    { type = "toggle", key = "timeline.icon", label = "ENC_SHOW_ICON", disabled = notBars },
    { type = "texture", key = "timeline.texture", label = "BAR_TEXTURE", allowDefault = true, disabled = notBars },
    { type = "color", key = "timeline.color", label = "ENC_BAR_COLOR", token = "accent.primary", reset = true, disabled = notBars },
    { type = "toggle", key = "timeline.emphasize", label = "ENC_EMPHASIZE", desc = "ENC_EMPHASIZE_DESC", disabled = notBars,
      cog = {
        { type = "range", key = "timeline.emphasizeAt", label = "ENC_EMPHASIZE_AT", min = 2, max = 15, step = 1, disabled = noEmphasis },
        { type = "color", key = "timeline.emphasizeColor", label = "ENC_EMPHASIZE_COLOR", token = "state.danger", reset = true,
          disabled = noEmphasis },
      } },
    Opt.With(Opt.Background("timeline.background"), { disabled = notBars }),
    Opt.With(Opt.Border("timeline.border"), { disabled = notBars }),
    Opt.Text("timeline.name", "ENC_NAME_FONT", { max = 24, row = { disabled = notBars } }),
    Opt.Text("timeline.time", "ENC_TIME_FONT", { max = 24, row = { disabled = notBars } }),

    { type = "tab", label = "ENC_TAB_WARNINGS", feature = "encounterWarnings" },
    { type = "header", label = "ENC_WARNINGS", icon = "warning" },
    { type = "select", key = "warnings.display", label = "ENC_WARN_DISPLAY", desc = "ENC_WARN_DISPLAY_DESC",
      keywords = "boss alerts raid warning banner text", values = {
        { value = "phoenix", label = "ENC_DISPLAY_PHOENIX" }, { value = "blizzard", label = "ENC_DISPLAY_BLIZZARD" },
        { value = "hidden", label = "ENC_DISPLAY_HIDDEN" } } },
    { type = "select", label = "ENC_WARN_LEVEL", desc = "ENC_WARN_LEVEL_DESC", combat = true,
      get = function() return tonumber(C_CVar.GetCVar("encounterWarningsLevel")) or 0 end,
      set = function(_, v) ns.Combat:Run("cvar.encounterWarningsLevel", C_CVar.SetCVar, "encounterWarningsLevel", tostring(v)) end,
      values = { { value = 0, label = "ENC_SEV_LOW" }, { value = 1, label = "ENC_SEV_MEDIUM" }, { value = 2, label = "ENC_SEV_HIGH" } } },
    cvarToggle("encounterWarningsHideIfNotTargetingPlayer", { label = "ENC_WARN_TARGETED", desc = "ENC_WARN_TARGETED_DESC",
      disabled = function(m) return m.db.warnings.display ~= "blizzard" end }),
    { type = "header", label = "ENC_BANNER", icon = "fonts" },
    { type = "toggle", key = "warnings.icon", label = "ENC_SHOW_ICON", disabled = notBanner },
    Opt.Text("warnings.text", "ENC_WARN_FONT", { max = 40, row = { disabled = notBanner } }),

    { type = "tab", label = "ENC_TAB_TIMERS" },
    { type = "header", label = "ENC_PULL", icon = "encounters" },
    { type = "range", key = "pull.seconds", label = "ENC_PULL_SECONDS", min = 3, max = 30, step = 1 },
    { type = "button", label = "ENC_PULL_START", desc = "ENC_PULL_START_DESC", button = "ENC_PULL_BUTTON", icon = "encounters",
      keywords = "pull timer countdown", func = function(m) m:Pull() end },
    { type = "button", label = "ENC_PULL_CANCEL", desc = "ENC_PULL_CANCEL_DESC", button = "ENC_CANCEL", icon = "close",
      func = function(m) m:Pull(0) end },
    { type = "header", label = "ENC_BREAK", icon = "break" },
    { type = "range", key = "breaks.minutes", label = "ENC_BREAK_MINUTES", min = 1, max = 30, step = 1 },
    { type = "toggle", key = "breaks.sync", label = "ENC_BREAK_SYNC", desc = "ENC_BREAK_SYNC_DESC",
      keywords = "dbm bigwigs share group" },
    { type = "button", label = "ENC_BREAK_START", desc = "ENC_BREAK_START_DESC", button = "ENC_BREAK_BUTTON", icon = "break",
      keywords = "break timer", func = function(m) m:Break() end },
    { type = "button", label = "ENC_BREAK_END", desc = "ENC_BREAK_END_DESC", button = "ENC_CANCEL", icon = "close",
      func = function(m) m:Break(0) end },

    { type = "tab", label = "ENC_TAB_SOUNDS" },
    { type = "header", label = "ENC_COUNTDOWN", icon = "sound" },
    { type = "toggle", gate = true, key = "countdown.enabled", label = "ENC_VOICE", desc = "ENC_VOICE_DESC",
      keywords = "pull timer countdown voice sound" },
    { type = "select", key = "countdown.voice", label = "ENC_VOICE_PICK", values = voices, disabled = noVoice },
    { type = "range", key = "countdown.from", label = "ENC_VOICE_FROM", min = 3, max = 10, step = 1, disabled = noVoice },
    { type = "toggle", key = "countdown.pull", label = "ENC_VOICE_PULL", desc = "ENC_VOICE_PULL_DESC", disabled = noVoice },
    { type = "toggle", key = "countdown.timers", label = "ENC_VOICE_TIMERS", desc = "ENC_VOICE_TIMERS_DESC", disabled = noVoice },
    { type = "button", label = "ENC_VOICE_TEST", desc = "ENC_VOICE_TEST_DESC", button = "MEDIA_PLAY", icon = "sound",
      func = function(m) m:TestCountdown() end },
    { type = "header", label = "ENC_WARN_SOUNDS", icon = "bell", feature = "encounterWarnings" },
    { type = "select", key = "warnings.sounds.high", label = "ENC_SEV_HIGH", values = sounds, disabled = notBanner,
      feature = "encounterWarnings" },
    { type = "select", key = "warnings.sounds.medium", label = "ENC_SEV_MEDIUM", values = sounds, disabled = notBanner,
      feature = "encounterWarnings" },
    { type = "select", key = "warnings.sounds.low", label = "ENC_SEV_LOW", values = sounds, disabled = notBanner,
      feature = "encounterWarnings" },
    { type = "button", label = "ENC_SOUND_TEST", desc = "ENC_SOUND_TEST_DESC", button = "MEDIA_PLAY", icon = "sound",
      feature = "encounterWarnings", func = function(m) m:PlayWarningSound(2) end },

    { type = "tab", label = "ENC_TAB_BIGWIGS" },
    { type = "header", label = "ENC_BIGWIGS", icon = "addon" },
    { type = "toggle", key = "bigwigs", label = "ENC_BW_STYLE", desc = "ENC_BW_STYLE_DESC", keywords = "bigwigs littlewigs bars style" },
    { type = "description", text = function() return M and M.BigWigs and M.BigWigs:StatusText() or L.ENC_BW_ABSENT end },
})
