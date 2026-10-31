local _, ns = ...

local cvar = ns.Combat.CVarAccessors
local function noFlight(m) return not m.db.flight.enabled end
local function noFeed(m) return not m.db.feed.enabled end
local FEED_QUALITY = {
    { value = 0, label = "QUALITY_FEED_Q0" }, { value = 1, label = "QUALITY_FEED_Q1" }, { value = 2, label = "QUALITY_FEED_Q2" },
    { value = 3, label = "QUALITY_FEED_Q3" }, { value = 4, label = "QUALITY_FEED_Q4" },
}

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
    { type = "toggle", key = "hideBossEmotes", label = "QUALITY_BOSS_EMOTES", desc = "QUALITY_BOSS_EMOTES_DESC",
      keywords = "boss emote whisper bossblock quiet raid warning" },
    { type = "select", key = "hideWhere", label = "QUALITY_HIDE_WHERE", desc = "QUALITY_HIDE_WHERE_DESC",
      keywords = "bossblock quiet instance dungeon raid only where", values = {
        { value = "always", label = "QUALITY_HIDE_ALWAYS" }, { value = "instances", label = "QUALITY_HIDE_INSTANCES" },
        { value = "raids", label = "QUALITY_HIDE_RAIDS" } } },
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

    { type = "tab", label = "QUALITY_TAB_FEED" },
    { type = "header", label = "QUALITY_FEED", icon = "items" },
    { type = "toggle", key = "feed.enabled", label = "QUALITY_FEED_SHOW", desc = "QUALITY_FEED_DESC", gate = true,
      keywords = "loot feed received items gold money currency toast list" },
    { type = "toggle", key = "feed.items", label = "QUALITY_FEED_ITEMS", disabled = noFeed },
    { type = "select", key = "feed.minQuality", label = "QUALITY_FEED_MIN", desc = "QUALITY_FEED_MIN_DESC", values = FEED_QUALITY,
      disabled = function(m) return noFeed(m) or not m.db.feed.items end },
    { type = "toggle", key = "feed.money", label = "QUALITY_FEED_MONEY", desc = "QUALITY_FEED_MONEY_DESC", disabled = noFeed },
    { type = "toggle", key = "feed.currency", label = "QUALITY_FEED_CURRENCY", disabled = noFeed },
    { type = "header", label = "QUALITY_FEED_LAYOUT", icon = "layout" },
    { type = "range", key = "feed.duration", label = "QUALITY_FEED_DURATION", min = 2, max = 20, step = 1, disabled = noFeed },
    { type = "range", key = "feed.rows", label = "QUALITY_FEED_ROWS", min = 1, max = 10, step = 1, disabled = noFeed },
    { type = "range", key = "feed.width", label = "UF_WIDTH", min = 180, max = 400, step = 2, disabled = noFeed },
    { type = "select", key = "feed.grow", label = "QUALITY_FEED_GROW", values = {
        { value = "up", label = "GROW_UP" }, { value = "down", label = "GROW_DOWN" } }, disabled = noFeed },

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
