local _, ns = ...

local cvar = ns.Combat.CVarAccessors
local function noFlight(m) return not m.db.flight.enabled end

-- Curated account CVars that exist on both clients and are safe to flip at any time out of combat.
-- item = { label, desc, keywords, min/max/step for ranges }
local function cvarRow(name, kind, item)
    item.get, item.set = cvar(name, kind)
    item.type, item.combat = kind == "number" and "range" or "toggle", true
    item.keywords = (item.keywords or "") .. " cvar " .. name
    return item
end

ns:RegisterOptions("Quality", {
    { type = "preview", kind = "quality" },
    { type = "tab", label = "QUALITY_TAB_INTERFACE" },
    { type = "header", label = "QUALITY_INTERFACE", icon = "quality" },
    { type = "toggle", key = "hideTalkingHead", label = "HIDE_TALKING_HEAD", desc = "HIDE_TALKING_HEAD_DESC" },
    { type = "toggle", key = "hideZoneText", label = "QUALITY_ZONE_TEXT", desc = "QUALITY_ZONE_TEXT_DESC",
      keywords = "zone name subzone banner" },
    { type = "toggle", key = "hideBossBanner", label = "QUALITY_BOSS_BANNER", desc = "QUALITY_BOSS_BANNER_DESC",
      keywords = "boss kill banner loot" },
    { type = "toggle", key = "filterErrors", label = "FILTER_ERRORS", desc = "FILTER_ERRORS_DESC", keywords = "red text spam" },
    { type = "toggle", key = "achievementScreenshot", label = "ACHIEVEMENT_SCREENSHOT", desc = "ACHIEVEMENT_SCREENSHOT_DESC" },
    { type = "toggle", key = "knownTint", label = "QUALITY_KNOWN", desc = "QUALITY_KNOWN_DESC",
      keywords = "merchant vendor recipe known learned green" },
    { type = "header", label = "QUALITY_COMBAT", icon = "cat-combat" },
    { type = "toggle", key = "combatAlert", label = "QUALITY_COMBAT_ALERT", desc = "QUALITY_COMBAT_ALERT_DESC", gate = true,
      keywords = "enter leave combat banner alert" },
    { type = "sound", key = "combatSound", label = "QUALITY_COMBAT_SOUND", desc = "QUALITY_COMBAT_SOUND_DESC" },
    { type = "button", label = "QUALITY_COMBAT_TEST", desc = "QUALITY_COMBAT_TEST_DESC", button = "CB_TEST_BUTTON", icon = "test",
      func = function(m) m.ShowCombatBanner(true) end },
    { type = "header", label = "QUALITY_MARKERS", icon = "groupframes" },
    { type = "toggle", key = "markers", label = "QUALITY_MARKERS_ENABLE", desc = "QUALITY_MARKERS_DESC", combat = true,
      keywords = "raid markers world markers target icons skull" },
    { type = "button", label = "QUALITY_MARKERS_MOVE", desc = "QUALITY_MARKERS_MOVE_DESC", button = "OPEN_EDIT_MODE", icon = "editmode",
      func = function() ns.EditMode:Open() end },
    { type = "header", label = "QUALITY_CURSOR", icon = "snap" },
    { type = "toggle", key = "cursorRing", label = "QUALITY_RING", desc = "QUALITY_RING_DESC", gate = true,
      keywords = "cursor mouse ring circle highlight" },
    { type = "range", key = "ringSize", label = "QUALITY_RING_SIZE", min = 24, max = 128, step = 2 },
    { type = "toggle", key = "ringCombatOnly", label = "QUALITY_RING_COMBAT", desc = "QUALITY_RING_COMBAT_DESC" },

    { type = "tab", label = "QUALITY_TAB_TRAVEL" },
    { type = "header", label = "QUALITY_FLIGHT", icon = "maps" },
    { type = "toggle", key = "flight.enabled", label = "QUALITY_FLIGHT_SHOW", desc = "QUALITY_FLIGHT_DESC", gate = true,
      keywords = "flight path taxi timer gryphon wyvern travel eta" },
    { type = "toggle", key = "flight.mapTimes", label = "QUALITY_FLIGHT_MAP", desc = "QUALITY_FLIGHT_MAP_DESC", disabled = noFlight,
      keywords = "flight map tooltip time" },
    { type = "toggle", key = "flight.land", label = "QUALITY_FLIGHT_LAND_SHOW", desc = "QUALITY_FLIGHT_LAND_DESC", disabled = noFlight,
      keywords = "land early dismount taxi" },
    { type = "range", key = "flight.width", label = "UF_WIDTH", min = 160, max = 480, step = 2, disabled = noFlight },
    { type = "description", text = function()
        local m = ns.modules.Quality
        return m and m.FlightCount and ns.L.QUALITY_FLIGHT_LEARNED:format(m:FlightCount()) or ""
    end },
    { type = "button", label = "QUALITY_FLIGHT_FORGET", desc = "QUALITY_FLIGHT_FORGET_DESC", button = "QUALITY_FLIGHT_FORGET_BUTTON",
      icon = "delete", func = function(m) m:ForgetFlights() end },

    { type = "tab", label = "QUALITY_TAB_GAME" },
    { type = "header", label = "QUALITY_CAMERA", icon = "preview" },
    cvarRow("cameraDistanceMaxZoomFactor", "number", { label = "QUALITY_CAMERA_MAX", desc = "QUALITY_CAMERA_MAX_DESC",
      min = 1, max = 2.6, step = 0.1,
      keywords = "camera zoom distance" }),
    cvarRow("cameraYawMoveSpeed", "number", { label = "QUALITY_CAMERA_YAW", desc = "QUALITY_CAMERA_YAW_DESC",
      min = 60, max = 360, step = 10,
      keywords = "camera turn speed" }),
    { type = "header", label = "QUALITY_CVARS", icon = "general" },
    cvarRow("SpellQueueWindow", "number", { label = "QUALITY_SPELL_QUEUE", desc = "QUALITY_SPELL_QUEUE_DESC", min = 0, max = 400, step = 10,
      keywords = "spell queue latency" }),
    cvarRow("autoDismountFlying", nil, { label = "QUALITY_DISMOUNT", desc = "QUALITY_DISMOUNT_DESC", keywords = "dismount flying cast" }),
    cvarRow("alwaysCompareItems", nil, { label = "QUALITY_COMPARE", desc = "QUALITY_COMPARE_DESC", keywords = "compare tooltip" }),
    cvarRow("autoClearAFK", nil, { label = "QUALITY_CLEAR_AFK", desc = "QUALITY_CLEAR_AFK_DESC", keywords = "afk away" }),
    cvarRow("Sound_EnableErrorSpeech", nil, { label = "QUALITY_ERROR_SPEECH", desc = "QUALITY_ERROR_SPEECH_DESC",
      keywords = "voice error speech" }),
    cvarRow("ffxGlow", nil, { label = "QUALITY_FFX_GLOW", desc = "QUALITY_FFX_GLOW_DESC", keywords = "glow bloom" }),
    cvarRow("ffxDeath", nil, { label = "QUALITY_FFX_DEATH", desc = "QUALITY_FFX_DEATH_DESC", keywords = "death grey" }),
    cvarRow("screenshotQuality", "number", { label = "QUALITY_SCREENSHOT", desc = "QUALITY_SCREENSHOT_DESC", min = 1, max = 10, step = 1,
      keywords = "screenshot quality" }),
    { type = "header", label = "BLIZZARD_FEATURES", icon = "general" },
    { type = "button", label = "COOLDOWN_MANAGER", desc = "QUALITY_CDM_LINK_DESC", button = "AUTO_OPEN_PAGE", icon = "link",
      keywords = "cooldown viewer tracker", func = function() ns.Config:Show("Tracker") end },
})
