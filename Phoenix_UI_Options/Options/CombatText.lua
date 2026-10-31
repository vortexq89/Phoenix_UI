local _, ns = ...
local CVar = ns.Combat.CVarAccessors

-- item = { label, desc, keywords? } for a boolean FCT CVar
local function toggle(cvar, item)
    item.type, item.combat = "toggle", true
    item.get, item.set = CVar(cvar)
    return item
end

local Opt = ns.Opt
local scaleGet, scaleSet = CVar("WorldTextScale_v2", "number")
local function noScroll(m) return not m.db.scroll.enabled end
local function scroll(row) return Opt.With(row, { disabled = row.disabled or noScroll }) end
-- the seven fixed areas, then the user's own (named in the area's "name"); a function so new areas appear
local function AREAS(m)
    local out = {}
    for _, key in ipairs(m.AreaKeys()) do
        local a = m.db.scroll.areas[key]
        local label = m.IsCustomArea(key) and ((a.name ~= "" and a.name) or key) or ("FCT_AREA_" .. key:upper())
        out[#out + 1] = { value = key, label = label }
    end
    return out
end
local function CRIT_AREA(m)
    local out = { { value = "same", label = "FCT_CRIT_SAME" } }
    for _, a in ipairs(AREAS(m)) do out[#out + 1] = a end
    return out
end
local function rebuild() if ns.Config.RebuildPage then ns.Config:RebuildPage("CombatText") end end
local newName = ""
-- Triggers tab: one trigger is edited at a time (picked in the first row); every row reads and writes that one.
local editing = 1
local function trig(m) local l = m.db.scroll.triggers; return l and l[editing] end
local function noTrig(m) return trig(m) == nil end
local function tfield(field)
    return function(m) local t = trig(m); return t and t[field] end,
        function(m, v) local t = trig(m); if t then t[field] = v end end
end
local function TRIGGERS(m)
    local out = {}
    for i, t in ipairs(m.db.scroll.triggers or {}) do
        out[i] = { value = i, label = i .. ". " .. ((t.spell ~= "" and t.spell) or "…") }
    end
    return out
end
local WHEN = { { value = "buff", label = "FCT_EV_BUFF" }, { value = "debuff", label = "FCT_EV_DEBUFF" },
    { value = "fade", label = "FCT_EV_FADE" }, { value = "reactive", label = "FCT_EV_REACTIVE" } }
local function trow(row, field)
    row.get, row.set = tfield(field)
    row.hidden = noTrig
    return row
end
local ANIM = { { value = "straight", label = "FCT_ANIM_STRAIGHT" }, { value = "parabola", label = "FCT_ANIM_PARABOLA" },
    { value = "angled", label = "FCT_ANIM_ANGLED" }, { value = "static", label = "FCT_ANIM_STATIC" },
    { value = "horizontal", label = "FCT_ANIM_HORIZONTAL" }, { value = "pow", label = "FCT_ANIM_POW" } }
local ICON = { { value = "LEFT", label = "ANCHOR_LEFT" }, { value = "RIGHT", label = "ANCHOR_RIGHT" }, { value = "OFF", label = "OFF" } }
-- the areas are Phoenix movers: unlocking shows every area's box (with its scroll path) next to the other frames
local function unlock()
    local movers = ns:GetModule("Movers")
    if not movers then return end
    ns.Config.frame:Hide()
    movers:SetUnlocked(true)
end
local ALIGN = { { value = "LEFT", label = "ANCHOR_LEFT" }, { value = "CENTER", label = "ANCHOR_CENTER" },
    { value = "RIGHT", label = "ANCHOR_RIGHT" } }
-- one switch per event type, its colour, size, area and sound behind the cog
local function event(key, t)
    local base = "scroll.events." .. key
    return Opt.With({ type = "toggle", key = base .. ".show", label = t.label, desc = t.desc,
        keywords = t.keywords, cog = {
            { type = "color", key = base .. ".color", label = "FCT_EV_COLOR" },
            { type = "range", key = base .. ".scale", label = "FCT_EV_SCALE", min = 0.5, max = 2, step = 0.05, percent = true },
            { type = "select", key = base .. ".area", label = "FCT_EV_AREA", values = AREAS },
            { type = "sound", key = base .. ".sound", label = "FCT_EV_SOUND" },
        } }, { disabled = noScroll })
end
local DIRS = { { value = "UP", label = "GROW_UP" }, { value = "DOWN", label = "GROW_DOWN" } }
local CRIT = { { value = "sticky", label = "FCT_CRIT_STICKY" },
    { value = "grow", label = "FCT_CRIT_GROW" }, { value = "flash", label = "FCT_CRIT_FLASH" },
    { value = "none", label = "FCT_CRIT_NONE" } }
local modeGet, modeSet = CVar("floatingCombatTextFloatMode_v2", "number")

local schema = {
    { type = "scope", key = "scroll.areas", label = "FCT_AREA", values = AREAS },
    { type = "preview", kind = "combattext" },
    { type = "tab", label = "FCT_TAB_BLIZZARD" },
    { type = "description", text = "FCT_INTRO" },
    { type = "font", key = "damageFont", label = "FCT_DAMAGE_FONT", desc = "FCT_DAMAGE_FONT_DESC", allowDefault = true, reload = true,
      keywords = "damage font numbers floating relog" },
    { type = "header", label = "FCT_OUTGOING", icon = "arrow-up" },
    toggle("floatingCombatTextCombatDamage_v2", { label = "FCT_DAMAGE", desc = "FCT_DAMAGE_DESC", keywords = "numbers sct msbt" }),
    toggle("floatingCombatTextCombatLogPeriodicSpells_v2", { label = "FCT_PERIODIC", desc = "FCT_PERIODIC_DESC", keywords = "dot" }),
    toggle("floatingCombatTextPetMeleeDamage_v2", { label = "FCT_PET", desc = "FCT_PET_DESC" }),
    toggle("floatingCombatTextCombatHealing_v2", { label = "FCT_HEALING", desc = "FCT_HEALING_DESC" }),
    { type = "range", label = "FCT_SCALE", desc = "FCT_SCALE_DESC", min = 0.5, max = 2.5, step = 0.1,
      get = scaleGet, set = scaleSet, combat = true },
    { type = "header", label = "FCT_INCOMING", icon = "arrow-down" },
    toggle("enableFloatingCombatText", { label = "FCT_SELF", desc = "FCT_SELF_DESC", keywords = "msbt incoming" }),
    { type = "select", label = "FCT_MODE", desc = "FCT_MODE_DESC", get = modeGet, set = modeSet, combat = true, values = {
        { value = 1, label = "FCT_MODE_UP" }, { value = 2, label = "FCT_MODE_DOWN" }, { value = 3, label = "FCT_MODE_ARC" },
    } },
    toggle("floatingCombatTextDodgeParryMiss_v2", { label = "FCT_AVOIDANCE", desc = "FCT_AVOIDANCE_DESC" }),
    toggle("floatingCombatTextDamageReduction_v2", { label = "FCT_RESISTANCES", desc = "FCT_RESISTANCES_DESC" }),
    toggle("floatingCombatTextCombatState_v2", { label = "FCT_COMBAT_STATE", desc = "FCT_COMBAT_STATE_DESC" }),
    toggle("floatingCombatTextReactives_v2", { label = "FCT_REACTIVES", desc = "FCT_REACTIVES_DESC" }),
    toggle("floatingCombatTextLowManaHealth_v2", { label = "FCT_LOW", desc = "FCT_LOW_DESC" }),
    toggle("floatingCombatTextAuras_v2", { label = "FCT_AURAS", desc = "FCT_AURAS_DESC" }),
    toggle("floatingCombatTextEnergyGains_v2", { label = "FCT_ENERGY", desc = "FCT_ENERGY_DESC" }),
    toggle("floatingCombatTextHonorGains_v2", { label = "FCT_HONOR", desc = "FCT_HONOR_DESC" }),
    toggle("floatingCombatTextRepChanges_v2", { label = "FCT_REP", desc = "FCT_REP_DESC" }),
    ------------------------------------------------------------ Phoenix scroll areas
    { type = "tab", label = "FCT_TAB_SCROLL" },
    { type = "header", label = "FCT_SCROLL", icon = "combattext" },
    { type = "toggle", gate = true, key = "scroll.enabled", label = "FCT_SCROLL_ENABLE", desc = "FCT_SCROLL_ENABLE_DESC",
      keywords = "scrolling combat text sct msbt parrot areas" },
    { type = "description", text = "FCT_SCROLL_TEXT" },
    scroll({ type = "toggle", key = "scroll.hideBlizzard", label = "FCT_HIDE_BLIZZARD", desc = "FCT_HIDE_BLIZZARD_DESC",
      keywords = "double duplicate blizzard text" }),
    scroll({ type = "input", key = "scroll.subs", label = "FCT_SUBS", desc = "FCT_SUBS_DESC",
      keywords = "substitutions rename abbreviate shorten msbt" }),
    scroll({ type = "button", label = "FCT_SCROLL_TEST", desc = "FCT_SCROLL_TEST_DESC", button = "CB_TEST_BUTTON", icon = "test",
      func = function(m) ns.Config.frame:Hide(); m:TestScroll() end, keywords = "test sample" }),
    scroll({ type = "select", key = "scroll.font.font", label = "FCT_COMBAT_FONT", desc = "FCT_COMBAT_FONT_DESC",
      keywords = "msbt font face combat numbers", values = {
        { value = "PhoenixFontBold", label = "Phoenix Font Bold" }, { value = "BebasNeueRegular", label = "Bebas Neue" },
        { value = "OswaldSemiBold", label = "Oswald" }, { value = "RussoOneRegular", label = "Russo One" },
        { value = "BlackOpsRegular", label = "Black Ops One" }, { value = "GrenzeBlack", label = "Grenze Black" } } }),
    scroll(Opt.Text("scroll.font", "FCT_SCROLL_FONT", { min = 10, max = 40 })),
    scroll({ type = "toggle", key = "scroll.merge", label = "FCT_MERGE", desc = "FCT_MERGE_DESC", keywords = "merge spam combine hits" }),
    scroll({ type = "range", key = "scroll.mergeWindow", label = "FCT_MERGE_WINDOW", desc = "FCT_MERGE_WINDOW_DESC", min = 0.1, max = 2,
      step = 0.05, disabled = function(m) return noScroll(m) or not m.db.scroll.merge end }),
    scroll({ type = "range", key = "scroll.throttle", label = "FCT_THROTTLE", desc = "FCT_THROTTLE_DESC", min = 0, max = 30, step = 1,
      keywords = "throttle spam limit lines per second" }),
    scroll({ type = "toggle", key = "scroll.onlyCombat", label = "FCT_ONLY_COMBAT", desc = "FCT_ONLY_COMBAT_DESC" }),
    ------------------------------------------------------------ areas
    { type = "tab", label = "FCT_TAB_AREAS" },
    { type = "header", label = "FCT_AREA_HEADER", icon = "layout" },
    scroll({ type = "button", label = "FCT_UNLOCK", desc = "FCT_UNLOCK_DESC", button = "FCT_UNLOCK_BUTTON", icon = "movers",
      combat = true, func = unlock, keywords = "move drag unlock areas position" }),
    scroll({ type = "toggle", key = "scroll.areas.@.show", label = "FCT_AREA_SHOW", desc = "FCT_AREA_SHOW_DESC" }),
    { type = "input", label = "FCT_AREA_NEW", desc = "FCT_AREA_NEW_DESC", keywords = "custom scroll area add new",
      get = function() return newName end, set = function(_, v) newName = v or "" end },
    { type = "button", label = "FCT_AREA_ADD", desc = "FCT_AREA_ADD_DESC", button = "FCT_AREA_ADD", icon = "add",
      func = function(m) m:AddArea(newName); newName = ""; rebuild() end },
    scroll({ type = "input", key = "scroll.areas.@.name", label = "FCT_AREA_NAME", desc = "FCT_AREA_NAME_DESC",
      hidden = function(m, unit) return not m.IsCustomArea(unit) end }),
    { type = "button", label = "FCT_AREA_REMOVE", desc = "FCT_AREA_REMOVE_DESC", button = "DELETE", icon = "delete",
      hidden = function(m, unit) return not m.IsCustomArea(unit) end,
      func = function(m, page) if m:RemoveArea(page and page.scope and page.scope.unit) then rebuild() end end },
    scroll({ type = "select", key = "scroll.areas.@.anim", label = "FCT_ANIM", desc = "FCT_ANIM_DESC", values = ANIM,
      keywords = "animation parabola curve angled static straight msbt xct" }),
    scroll({ type = "select", key = "scroll.areas.@.dir", label = "FCT_AREA_DIR", values = DIRS, keywords = "direction up down" }),
    scroll({ type = "select", key = "scroll.areas.@.align", label = "FCT_ALIGN", values = ALIGN }),
    scroll({ type = "range", key = "scroll.areas.@.duration", label = "FCT_DURATION", min = 0.6, max = 6, step = 0.1 }),
    scroll({ type = "range", key = "scroll.areas.@.scale", label = "FCT_AREA_SCALE", min = 0.5, max = 2, step = 0.05, percent = true }),
    scroll({ type = "toggle", key = "scroll.areas.@.useColor", label = "FCT_AREA_COLOR", desc = "FCT_AREA_COLOR_DESC",
      cog = { { type = "color", key = "scroll.areas.@.color", label = "FCT_EV_COLOR" } } }),
    { type = "header", label = "FCT_ICON", icon = "auras" },
    scroll({ type = "select", key = "scroll.areas.@.iconSide", label = "FCT_ICON", desc = "FCT_ICON_DESC", values = ICON,
      keywords = "spell icon msbt" }),
    scroll({ type = "range", key = "scroll.areas.@.iconSize", label = "FCT_ICON_SIZE", min = 10, max = 48, step = 1 }),
    scroll({ type = "toggle", key = "scroll.castIcons", label = "FCT_CAST_ICONS", desc = "FCT_CAST_ICONS_DESC" }),
    scroll({ type = "toggle", key = "scroll.glyphIcons", label = "FCT_GLYPH_ICONS", desc = "FCT_GLYPH_ICONS_DESC" }),
    { type = "header", label = "UF_POSITION", icon = "movers" },
    scroll({ type = "range", key = "scroll.areas.@.x", label = "OFFSET_X", min = -800, max = 800, step = 10 }),
    scroll({ type = "range", key = "scroll.areas.@.y", label = "OFFSET_Y", min = -500, max = 500, step = 10 }),
    scroll({ type = "range", key = "scroll.areas.@.width", label = "FCT_AREA_WIDTH", min = 100, max = 600, step = 10 }),
    scroll({ type = "range", key = "scroll.areas.@.height", label = "FCT_AREA_HEIGHT", min = 60, max = 500, step = 10 }),
    ------------------------------------------------------------ events
    { type = "tab", label = "FCT_TAB_EVENTS" },
    { type = "header", label = "FCT_INCOMING", icon = "arrow-down" },
    event("damage", { label = "FCT_EV_DAMAGE", desc = "FCT_EV_DAMAGE_DESC", keywords = "melee hits taken" }),
    event("spell", { label = "FCT_EV_SPELL", desc = "FCT_EV_SPELL_DESC", keywords = "spell damage taken" }),
    event("shield", { label = "FCT_EV_SHIELD", desc = "FCT_EV_SHIELD_DESC", keywords = "damage shield thorns" }),
    event("heal", { label = "FCT_EV_HEAL", desc = "FCT_EV_HEAL_DESC", keywords = "heals received" }),
    event("hot", { label = "FCT_EV_HOT", desc = "FCT_EV_HOT_DESC", keywords = "heal over time periodic" }),
    event("avoid", { label = "FCT_EV_AVOID", desc = "FCT_EV_AVOID_DESC", keywords = "miss dodge parry block absorb" }),
    { type = "header", label = "FCT_EV_TARGET", icon = "arrow-up" },
    event("hit", { label = "FCT_EV_HIT", desc = "FCT_EV_HIT_DESC", keywords = "outgoing damage target" }),
    event("theal", { label = "FCT_EV_THEAL", desc = "FCT_EV_THEAL_DESC", keywords = "target heals" }),
    { type = "header", label = "FCT_AREA_NOTIFY", icon = "warning" },
    event("buff", { label = "FCT_EV_BUFF", desc = "FCT_EV_BUFF_DESC", keywords = "aura gained buff" }),
    event("debuff", { label = "FCT_EV_DEBUFF", desc = "FCT_EV_DEBUFF_DESC", keywords = "debuff gained" }),
    event("fade", { label = "FCT_EV_FADE", desc = "FCT_EV_FADE_DESC", keywords = "aura faded" }),
    event("reactive", { label = "FCT_EV_REACTIVE", desc = "FCT_EV_REACTIVE_DESC", keywords = "proc reactive spell" }),
    event("honor", { label = "FCT_EV_HONOR", desc = "FCT_EV_HONOR_DESC", keywords = "honour pvp" }),
    event("rep", { label = "FCT_EV_REP", desc = "FCT_EV_REP_DESC", keywords = "reputation faction" }),
    event("money", { label = "FCT_EV_MONEY", desc = "FCT_EV_MONEY_DESC", keywords = "gold money looted coins" }),
    event("xp", { label = "FCT_EV_XP", desc = "FCT_EV_XP_DESC", keywords = "experience xp level" }),
    { type = "header", label = "FCT_AREA_POWER", icon = "speed" },
    ------------------------------------------------------------ crits
    { type = "tab", label = "FCT_TAB_TRIGGERS" },
    { type = "header", label = "FCT_TRIGGERS", icon = "bell" },
    { type = "description", text = "FCT_TRIGGERS_TEXT" },
    { type = "button", label = "FCT_TRIGGER_ADD", desc = "FCT_TRIGGER_ADD_DESC", button = "FCT_TRIGGER_ADD", icon = "add",
      keywords = "trigger alert custom message msbt",
      func = function(m) editing = m:AddTrigger(); rebuild() end },
    { type = "select", label = "FCT_TRIGGER", desc = "FCT_TRIGGER_DESC", values = TRIGGERS, hidden = noTrig,
      get = function() return editing end, set = function(_, v) editing = v; rebuild() end },
    trow({ type = "toggle", label = "FCT_TRIGGER_ON" }, "on"),
    trow({ type = "select", label = "FCT_TRIGGER_WHEN", values = WHEN }, "when"),
    trow({ type = "input", label = "FCT_TRIGGER_SPELL", desc = "FCT_TRIGGER_SPELL_DESC" }, "spell"),
    trow({ type = "input", label = "FCT_TRIGGER_TEXT", desc = "FCT_TRIGGER_TEXT_DESC" }, "text"),
    trow({ type = "select", label = "FCT_EV_AREA", values = AREAS }, "area"),
    trow({ type = "color", label = "FCT_EV_COLOR" }, "color"),
    trow({ type = "sound", label = "FCT_EV_SOUND" }, "sound"),
    { type = "button", label = "FCT_TRIGGER_REMOVE", desc = "FCT_TRIGGER_REMOVE_DESC", button = "DELETE", icon = "delete",
      hidden = noTrig, func = function(m) if m:RemoveTrigger(editing) then editing = math.max(1, editing - 1); rebuild() end end },
    { type = "tab", label = "FCT_TAB_CRITS" },
    { type = "header", label = "FCT_CRIT", icon = "warning" },
    scroll({ type = "select", key = "scroll.crit", label = "FCT_CRIT", desc = "FCT_CRIT_DESC", values = CRIT, keywords = "critical crit" }),
    scroll({ type = "range", key = "scroll.critScale", label = "FCT_CRIT_SCALE", min = 1, max = 3, step = 0.05, percent = true,
      disabled = function(m) return noScroll(m) or m.db.scroll.crit ~= "grow" end }),
    scroll({ type = "select", key = "scroll.critArea", label = "FCT_CRIT_AREA", desc = "FCT_CRIT_AREA_DESC", values = CRIT_AREA }),
    scroll({ type = "sound", key = "scroll.critSound", label = "FCT_CRIT_SOUND", desc = "FCT_CRIT_SOUND_DESC" }),
}

-- one row per power type, named by the game's own power strings, after the Power header
for i, item in ipairs(schema) do
    if item.type == "header" and item.label == "FCT_AREA_POWER" then
        local at = i + 1
        for _, token in ipairs(ns.modules.CombatText.POWERS) do
            table.insert(schema, at, event("p_" .. token:lower(), { label = type(_G[token]) == "string" and _G[token] or token,
                desc = "FCT_EV_POWER_DESC", keywords = "power gain energize " .. token:lower() }))
            at = at + 1
        end
        break
    end
end
ns:RegisterOptions("CombatText", schema)
