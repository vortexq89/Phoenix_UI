local _, ns = ...
local Opt = ns.Opt

-- A setting owned by another module (the window skin lives in Skins), mirrored with a link to its page.
local function mirror(moduleKey, key, row)
    local other = ns.modules[moduleKey]
    local target
    for _, item in ipairs(ns.options[moduleKey] or {}) do if item.key == key then target = item end end
    return Opt.With({ type = "toggle", default = true,
        get = function() return ns.DB:Get(other, key) and true or false end, set = function(_, v) ns.DB:Set(other, key, v) end,
        disabled = function() return not other:IsEnabled() end, link = { key = moduleKey, item = target } }, row)
end

local function panelOff(m) return not m.db.panel end
local function noDim(m) return m.db.nonMatch ~= "dim" end
local function list(m) return m.PRESETS end

local VOICE = {
    { value = "any", label = "LFG_ANY" },
    { value = "with", label = "LFG_VOICE_WITH" },
    { value = "without", label = "LFG_VOICE_WITHOUT" },
}
local BOSSES = {
    { value = "any", label = "LFG_ANY" },
    { value = "fresh", label = "LFG_BOSSES_FRESH" },
    { value = "progress", label = "LFG_BOSSES_PROGRESS" },
}
local NONMATCH = { { value = "dim", label = "LFG_NONMATCH_DIM" }, { value = "mark", label = "LFG_NONMATCH_MARK" } }
local KEYS = {
    { value = "off", label = "OFF" },
    { value = "SPACE", label = "LFG_KEY_SPACE" },
    { value = "ENTER", label = "LFG_KEY_ENTER" },
}
local function sorts(m) return m.SORT_LIST end

ns:RegisterOptions("GroupFinder", {
    { type = "preview", kind = "groupfinder" },
    ------------------------------------------------------------ Filters
    { type = "tab", label = "LFG_TAB_FILTERS" },
    { type = "header", label = "LFG_PANEL", icon = "filter" },
    { type = "toggle", key = "panel", label = "LFG_PANEL_SHOW", desc = "LFG_PANEL_SHOW_DESC",
      keywords = "premade group finder lfg filter panel pgf" },
    Opt.With(Opt.Background("panelBackground", "LFG_PANEL_BACKGROUND", "bg.base"), { disabled = panelOff }),
    Opt.With(Opt.Border("panelBorder", "LFG_PANEL_BORDER", "border.strong"), { disabled = panelOff }),
    { type = "select", key = "preset", label = "LFG_PRESET", desc = "LFG_PRESET_DESC", values = list,
      keywords = "preset dungeon raid push fresh progress rated" },
    { type = "header", label = "LFG_GAME_FILTERS", icon = "search" },
    { type = "description", text = "LFG_GAME_FILTERS_DESC" },
    { type = "toggle", key = "diffNormal", label = "LFG_NORMAL", keywords = "difficulty normal" },
    { type = "toggle", key = "diffHeroic", label = "LFG_HEROIC", keywords = "difficulty heroic" },
    { type = "toggle", key = "diffMythic", label = "LFG_MYTHIC", keywords = "difficulty mythic" },
    { type = "toggle", key = "diffMythicPlus", label = "LFG_MYTHICPLUS", keywords = "difficulty mythic plus keystone" },
    { type = "toggle", key = "needsMyRole", label = "LFG_NEEDS_MY_ROLE", desc = "LFG_NEEDS_MY_ROLE_DESC", keywords = "role tank healer" },
    { type = "toggle", key = "hasTank", label = "LFG_HAS_TANK" },
    { type = "toggle", key = "hasHealer", label = "LFG_HAS_HEALER" },
    { type = "range", key = "minRating", label = "LFG_MIN_RATING", desc = "LFG_MIN_RATING_DESC", min = 0, max = 4000, step = 50,
      keywords = "score rating minimum" },
    { type = "header", label = "LFG_PHOENIX_FILTERS", icon = "filter" },
    { type = "toggle", key = "freeTank", label = "LFG_FREE_TANK", keywords = "role needed tank" },
    { type = "toggle", key = "freeHealer", label = "LFG_FREE_HEALER", keywords = "role needed healer" },
    { type = "toggle", key = "freeDamage", label = "LFG_FREE_DAMAGE", keywords = "role needed dps damage" },
    { type = "range", key = "minScore", label = "LFG_MIN_SCORE", desc = "LFG_MIN_SCORE_DESC", min = 0, max = 4000, step = 50,
      keywords = "leader score rating raider" },
    { type = "range", key = "keyMin", label = "LFG_KEY_MIN", desc = "LFG_KEY_DESC", min = 0, max = 30, step = 1,
      keywords = "key level mythic plus" },
    { type = "range", key = "keyMax", label = "LFG_KEY_MAX", desc = "LFG_KEY_DESC", min = 0, max = 30, step = 1 },
    { type = "range", key = "minMembers", label = "LFG_MIN_MEMBERS", min = 0, max = 40, step = 1, keywords = "members size" },
    { type = "range", key = "maxMembers", label = "LFG_MAX_MEMBERS", min = 0, max = 40, step = 1 },
    { type = "range", key = "maxAge", label = "LFG_MAX_AGE", desc = "LFG_MAX_AGE_DESC", min = 0, max = 180, step = 5,
      keywords = "age minutes old new" },
    { type = "range", key = "minIlvl", label = "LFG_MIN_ILVL", desc = "LFG_MIN_ILVL_DESC", min = 0, max = 800, step = 5,
      keywords = "item level" },
    { type = "range", key = "minPvp", label = "LFG_MIN_PVP", min = 0, max = 3500, step = 50, keywords = "pvp rating arena rbg" },
    { type = "range", key = "maxPvp", label = "LFG_MAX_PVP", min = 0, max = 3500, step = 50 },
    { type = "toggle", key = "friends", label = "LFG_FRIENDS_ONLY", desc = "LFG_FRIENDS_ONLY_DESC", keywords = "friends guild" },
    { type = "select", key = "voice", label = "LFG_VOICE", values = VOICE, keywords = "voice chat discord" },
    { type = "select", key = "bosses", label = "LFG_BOSSES", desc = "LFG_BOSSES_DESC", values = BOSSES,
      keywords = "bosses defeated raid fresh" },
    { type = "toggle", key = "hasLust", label = "LFG_HAS_LUST", desc = "LFG_HAS_LUST_DESC", keywords = "bloodlust heroism time warp" },
    { type = "toggle", key = "hasBrez", label = "LFG_HAS_BREZ", desc = "LFG_HAS_BREZ_DESC", keywords = "battle res rebirth" },
    { type = "toggle", key = "hideDeclined", label = "LFG_HIDE_DECLINED", desc = "LFG_HIDE_DECLINED_DESC", keywords = "declined" },
    { type = "toggle", key = "noLeavers", label = "LFG_NO_LEAVERS", desc = "LFG_NO_LEAVERS_DESC", keywords = "leaver deserter" },
    { type = "input", key = "expression", label = "LFG_EXPRESSION", desc = "LFG_EXPRESSION_DESC",
      keywords = "advanced expression filter syntax tanks heals dps score" },
    { type = "header", label = "LFG_RESULTS", icon = "preview" },
    { type = "select", key = "nonMatch", label = "LFG_NONMATCH", desc = "LFG_NONMATCH_DESC", values = NONMATCH,
      keywords = "dim hide filtered" },
    { type = "range", key = "dimAlpha", label = "LFG_DIM_ALPHA", min = 0.1, max = 0.9, step = 0.05, percent = true, disabled = noDim },
    { type = "toggle", key = "highlight", label = "LFG_HIGHLIGHT", desc = "LFG_HIGHLIGHT_DESC", keywords = "highlight ember outline",
      cog = { { type = "color", key = "highlightColor", label = "LFG_HIGHLIGHT_COLOR", token = "accent.primary", reset = true } } },
    { type = "select", key = "sort", label = "LFG_SORT", desc = "LFG_SORT_HELP", values = sorts, keywords = "sort order" },
    { type = "toggle", key = "sortDesc", label = "LFG_SORT_DESC" },
    { type = "toggle", key = "matchList", label = "LFG_MATCH_LIST", desc = "LFG_MATCH_LIST_DESC", disabled = panelOff },
    { type = "toggle", key = "matchCount", label = "LFG_MATCH_COUNT", disabled = panelOff },
    ------------------------------------------------------------ Helpers
    { type = "tab", label = "LFG_TAB_HELPERS" },
    { type = "header", label = "LFG_SIGNUP", icon = "check" },
    { type = "toggle", key = "quickSignUp", label = "LFG_QUICK", desc = "LFG_QUICK_DESC", combat = true,
      keywords = "one click double click sign up apply quick" },
    { type = "toggle", key = "enterSignUp", label = "LFG_ENTER", desc = "LFG_ENTER_DESC", combat = true, keywords = "enter key sign up" },
    { type = "select", key = "roleCheckKey", label = "LFG_ROLECHECK", desc = "LFG_ROLECHECK_DESC", values = KEYS, combat = true,
      keywords = "role check accept key" },
    { type = "toggle", key = "teleport", label = "LFG_TELEPORT_OPT", desc = "LFG_TELEPORT_OPT_DESC",
      keywords = "teleport dungeon path hero mythic plus portal prompt" },
    { type = "header", label = "LFG_LIST", icon = "friends" },
    { type = "toggle", key = "entryScore", label = "LFG_ENTRY_SCORE", desc = "LFG_ENTRY_SCORE_DESC", keywords = "leader score best key" },
    { type = "toggle", key = "classBars", label = "LFG_CLASS_BARS", desc = "LFG_CLASS_BARS_DESC", keywords = "class colour icons roles" },
    { type = "toggle", key = "tooltip", label = "LFG_TOOLTIP", desc = "LFG_TOOLTIP_DESC", keywords = "tooltip score key rating" },
    { type = "toggle", key = "lockout", label = "LFG_LOCKOUT", desc = "LFG_LOCKOUT_DESC", keywords = "raid lockout saved id" },
    { type = "toggle", key = "skinEntries", label = "LFG_SKIN_ENTRIES", desc = "LFG_SKIN_ENTRIES_DESC", keywords = "ember style skin" },
    mirror("Skins", "groupFinder", { label = "LFG_SKIN_WINDOW", desc = "LFG_SKIN_WINDOW_DESC", keywords = "skin window group finder" }),
    { type = "header", label = "LFG_APPLICANTS", icon = "user" },
    { type = "toggle", key = "applicantBest", label = "LFG_APP_BEST", desc = "LFG_APP_BEST_DESC", keywords = "applicant best key leader" },
    { type = "toggle", key = "applicantSpec", label = "LFG_APP_SPEC", desc = "LFG_APP_SPEC_DESC", keywords = "applicant spec icon" },
    { type = "range", key = "applicantMinScore", label = "LFG_APP_SCORE", desc = "LFG_APP_SCORE_DESC", min = 0, max = 4000, step = 50,
      keywords = "applicant score highlight" },
})
