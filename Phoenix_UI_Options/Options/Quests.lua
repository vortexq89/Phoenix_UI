local _, ns = ...
local Opt = ns.Opt

-- A setting owned by another module (the item bar lives in Action Bars), mirrored with a link to its page.
local function mirror(moduleKey, key, row)
    local other = ns.modules[moduleKey]
    local target
    for _, item in ipairs(ns.options[moduleKey] or {}) do if item.key == key then target = item end end
    return Opt.With({ type = "toggle", default = true,
        get = function() return ns.DB:Get(other, key) and true or false end, set = function(_, v) ns.DB:Set(other, key, v) end,
        disabled = function() return not other:IsEnabled() end, link = { key = moduleKey, item = target } }, row)
end

local function restyleOff(m) return not m.db.restyle end
local function arrowOff(m) return not m.db.arrow end
local function autoOff(m) return not m.db.autoTurnIn end

local COLLAPSE = {
    { value = "off", label = "OFF" }, { value = "instance", label = "QUESTS_COLLAPSE_INSTANCE" },
    { value = "combat", label = "QUESTS_COLLAPSE_COMBAT" }, { value = "both", label = "QUESTS_COLLAPSE_BOTH" },
}
local ARROWS = {
    { value = "phoenix", label = "QUESTS_ARROW_PHOENIX" }, { value = "blizzard", label = "QUESTS_ARROW_BLIZZARD" },
    { value = "minimal", label = "QUESTS_ARROW_MINIMAL" },
}
-- "Best for my character (Sim)" only where the Sim page exists.
local REWARDS = { { value = "off", label = "QUESTS_REWARD_OFF" }, { value = "vendor", label = "QUESTS_REWARD_VENDOR" } }
if ns:Supports("sim") then REWARDS[#REWARDS + 1] = { value = "sim", label = "QUESTS_REWARD_SIM" } end

local function dataMissing(m)
    if not (m.db.npcPins or m.db.turnins or m.db.tooltip) then return false end
    local _, err = m:Data()
    return err ~= nil
end

ns:RegisterOptions("Quests", {
    { type = "preview", kind = "quests" },
    { type = "description", text = "QUESTS_DATA_MISSING", hidden = function(m) return not dataMissing(m) end },
    ------------------------------------------------------------ Tracker
    { type = "tab", label = "QUESTS_TAB_TRACKER" },
    { type = "header", label = "QUESTS_TRACKER", icon = "tracker" },
    { type = "toggle", key = "restyle", label = "QUESTS_RESTYLE", desc = "QUESTS_RESTYLE_DESC", reload = true,
      keywords = "objective tracker quest list skin font" },
    { type = "range", key = "width", label = "QUESTS_WIDTH", desc = "QUESTS_WIDTH_DESC", min = 0, max = 500, step = 10,
      disabled = restyleOff, keywords = "size wide" },
    { type = "range", key = "maxHeight", label = "QUESTS_MAX_HEIGHT", desc = "QUESTS_MAX_HEIGHT_DESC", min = 0, max = 1200, step = 20,
      disabled = restyleOff, keywords = "size tall limit" },
    Opt.With(Opt.Text("header", "QUESTS_HEADER_FONT", { token = "accent.primary" }), { disabled = restyleOff }),
    Opt.With(Opt.Text("objective", "QUESTS_OBJECTIVE_FONT"), { disabled = restyleOff }),
    { type = "texture", key = "bar", label = "QUESTS_BAR", desc = "QUESTS_BAR_DESC", allowDefault = true, disabled = restyleOff },
    { type = "toggle", key = "difficulty", label = "QUESTS_DIFFICULTY", desc = "QUESTS_DIFFICULTY_DESC", disabled = restyleOff,
      keywords = "colour color level grey green yellow orange red" },
    { type = "toggle", key = "level", label = "QUESTS_LEVEL", desc = "QUESTS_LEVEL_DESC", disabled = restyleOff,
      keywords = "level tag elite dungeon raid daily" },
    { type = "select", key = "collapse", label = "QUESTS_COLLAPSE", desc = "QUESTS_COLLAPSE_DESC", values = COLLAPSE,
      keywords = "hide collapse instance dungeon raid combat fade" },
    { type = "toggle", key = "superTrack", label = "QUESTS_SUPERTRACK", desc = "QUESTS_SUPERTRACK_DESC",
      keywords = "focus click super track arrow" },
    { type = "header", label = "QUESTS_ITEMS", icon = "items" },
    mirror("ActionBars", "bars.items.enabled", { label = "QUESTS_ITEM_BAR", desc = "QUESTS_ITEM_BAR_DESC",
      keywords = "quest item button usable bar" }),
    mirror("ActionBars", "items.quest", { label = "QUESTS_ITEM_QUEST", desc = "QUESTS_ITEM_QUEST_DESC", combat = true }),
    ------------------------------------------------------------ Helper
    { type = "tab", label = "QUESTS_TAB_HELPER" },
    { type = "header", label = "QUESTS_ARROW", icon = "arrow-up" },
    { type = "toggle", key = "arrow", label = "QUESTS_ARROW_SHOW", desc = "QUESTS_ARROW_SHOW_DESC",
      keywords = "waypoint arrow tomtom direction navigation" },
    { type = "select", key = "arrowStyle", label = "QUESTS_ARROW_STYLE", values = ARROWS, disabled = arrowOff },
    { type = "range", key = "arrowSize", label = "QUESTS_ARROW_SIZE", min = 24, max = 96, step = 2, disabled = arrowOff },
    { type = "toggle", key = "distance", label = "QUESTS_DISTANCE", desc = "QUESTS_DISTANCE_DESC", disabled = arrowOff,
      keywords = "yards distance" },
    { type = "toggle", key = "eta", label = "QUESTS_ETA", desc = "QUESTS_ETA_DESC", disabled = arrowOff, keywords = "time arrival eta" },
    { type = "header", label = "QUESTS_PINS", icon = "maps" },
    { type = "toggle", key = "questLines", label = "QUESTS_QUESTLINES", desc = "QUESTS_QUESTLINES_DESC",
      keywords = "available quests map exclamation" },
    { type = "toggle", key = "npcPins", label = "QUESTS_NPC_PINS", desc = "QUESTS_NPC_PINS_DESC",
      keywords = "quest giver npc pin map questie" },
    { type = "toggle", key = "turnins", label = "QUESTS_TURNINS", desc = "QUESTS_TURNINS_DESC", feature = "questTurnins",
      keywords = "turn in hand in complete question mark" },
    { type = "toggle", key = "minimap", label = "QUESTS_MINIMAP", desc = "QUESTS_MINIMAP_DESC", keywords = "minimap pins radar" },
    { type = "range", key = "pinSize", label = "QUESTS_PIN_SIZE", min = 10, max = 32, step = 1 },
    { type = "toggle", key = "hideTrivial", label = "QUESTS_TRIVIAL", desc = "QUESTS_TRIVIAL_DESC",
      keywords = "low level grey trivial" },
    { type = "header", label = "QUESTS_NPCS", icon = "user" },
    { type = "toggle", key = "townsfolk", label = "QUESTS_TOWNSFOLK", desc = "QUESTS_TOWNSFOLK_DESC",
      keywords = "vendor trainer profession flight master townsfolk questie npc pins" },
    { type = "toggle", key = "rares", label = "QUESTS_RARES", desc = "QUESTS_RARES_DESC", keywords = "rare elite npc pins map" },
    { type = "toggle", key = "npcLocation", label = "QUESTS_NPC_LOCATION", desc = "QUESTS_NPC_LOCATION_DESC",
      keywords = "quest giver location where coordinates tooltip" },
    { type = "toggle", key = "mapSearch", label = "QUESTS_MAP_SEARCH", desc = "QUESTS_MAP_SEARCH_DESC",
      keywords = "world map search find npc name waypoint" },
    { type = "toggle", key = "waySlash", label = "QUESTS_WAY_SLASH", desc = "QUESTS_WAY_SLASH_DESC", reload = true,
      keywords = "/way tomtom waypoint coordinates command" },
    { type = "header", label = "QUESTS_EXPANSIONS", icon = "filter" },
    { type = "toggle", key = "slices.midnight", label = "QUESTS_SLICE_MIDNIGHT", feature = "questSliceRetail",
      keywords = "midnight quel'thalas expansion filter" },
    { type = "toggle", key = "slices.tww", label = "QUESTS_SLICE_TWW", feature = "questSliceRetail",
      keywords = "war within khaz algar expansion filter" },
    { type = "toggle", key = "slices.forever", label = "QUESTS_SLICE_FOREVER", feature = "questSliceForever",
      keywords = "azeroth eastern kingdoms kalimdor filter" },
    ------------------------------------------------------------ Automation
    { type = "tab", label = "QUESTS_TAB_AUTO" },
    { type = "header", label = "QUESTS_AUTO", icon = "automation" },
    { type = "toggle", key = "autoAccept", label = "QUESTS_AUTO_ACCEPT", desc = "QUESTS_AUTO_ACCEPT_DESC",
      keywords = "auto accept quest shift" },
    { type = "toggle", key = "autoTurnIn", label = "QUESTS_AUTO_TURNIN", desc = "QUESTS_AUTO_TURNIN_DESC",
      keywords = "auto turn in complete hand in shift" },
    { type = "select", key = "reward", label = "QUESTS_REWARD", desc = "QUESTS_REWARD_DESC", values = REWARDS, disabled = autoOff,
      keywords = "reward choice vendor gold sim upgrade" },
    { type = "toggle", key = "tooltip", label = "QUESTS_TOOLTIP", desc = "QUESTS_TOOLTIP_DESC",
      keywords = "tooltip progress objectives npc offers" },
    { type = "header", label = "QUESTS_COMMUNITY", icon = "friends" },
    { type = "toggle", key = "contribute", label = "QUESTS_CONTRIBUTE", desc = "QUESTS_CONTRIBUTE_DESC",
      keywords = "record collect npc positions local data opt in" },
    { type = "button", label = "QUESTS_COLLECT_CLEAR", desc = "QUESTS_COLLECT_CLEAR_DESC", button = "QUESTS_COLLECT_CLEAR_BUTTON",
      icon = "delete", disabled = function(m) return m:RecordedCount() == 0 end, func = function(m) m:ClearRecorded() end },
})
