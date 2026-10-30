local _, ns = ...
local Opt = ns.Opt

-- Bars tab rows only act when Phoenix owns the bars; the Blizzard mode keeps Edit Mode's bars.
local function blizzard(m) return m.db.mode ~= "phoenix" end
local function unstyled(m) return not m.db.style end
local function notBar1(_, bar) return bar ~= "bar1" end
local function noGrid(_, bar) return bar == "pet" or bar == "stance" or bar == "items" end
local function noBars(m) return blizzard(m) end

local lockGet, lockSet = ns.Combat.CVarAccessors("lockActionBars")

local MODE = { { value = "phoenix", label = "AB_MODE_PHOENIX" }, { value = "blizzard", label = "AB_MODE_BLIZZARD" } }
local ORDER = { { value = "normal", label = "AB_ORDER_NORMAL" }, { value = "reversed", label = "AB_ORDER_REVERSED" } }
local SHAPE = {
    { value = "square", label = "AB_SHAPE_SQUARE" }, { value = "rounded", label = "AB_SHAPE_ROUNDED" },
    { value = "circle", label = "AB_SHAPE_CIRCLE" }, { value = "hexagon", label = "AB_SHAPE_HEXAGON" },
}
local TARGET = { { value = "icon", label = "AB_TARGET_ICON" }, { value = "hotkey", label = "AB_TARGET_HOTKEY" },
    { value = "both", label = "AB_TARGET_BOTH" } }
local STATE = { { value = "blizzard", label = "AB_STYLE_BLIZZARD" }, { value = "accent", label = "AB_STYLE_ACCENT" },
    { value = "none", label = "AB_STYLE_NONE" } }
local GLOW = {
    { value = "blizzard", label = "AB_STYLE_BLIZZARD" }, { value = "pixel", label = "AB_GLOW_PIXEL" },
    { value = "autocast", label = "AB_GLOW_AUTOCAST" }, { value = "button", label = "AB_GLOW_BUTTON" },
    { value = "none", label = "AB_STYLE_NONE" },
}
local TIPS = { { value = "never", label = "AB_TIPS_NEVER" }, { value = "combat", label = "AB_TIPS_COMBAT" },
    { value = "always", label = "AB_TIPS_ALWAYS" } }
local MENU = { { value = "bar", label = "AB_MENU_BAR" }, { value = "mouseover", label = "AB_MENU_MOUSEOVER" },
    { value = "hidden", label = "AB_MENU_HIDDEN" } }
local PAGES = { { value = 0, label = "OFF" }, { value = 2, label = "AB_PAGE_2" }, { value = 3, label = "AB_PAGE_3" },
    { value = 4, label = "AB_PAGE_4" }, { value = 5, label = "AB_PAGE_5" }, { value = 6, label = "AB_PAGE_6" } }

local BARS = {}
for _, key in ipairs({ "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet", "stance", "items" }) do
    BARS[#BARS + 1] = { value = key, label = ({ pet = "AB_PET", stance = "AB_STANCE", items = "AB_ITEMS" })[key]
        or ("AB_BAR" .. key:sub(4)) }
end

local function openLayout()
    local movers = ns:GetModule("Movers")
    if not movers or not movers:IsEnabled() then
        ns.Config:SetStatus(ns.L.AB_LAYOUT_NEEDS_MOVERS, "state.warning", "warning")
        return
    end
    ns.Config.frame:Hide()
    movers:SetUnlocked(true)
end

local function bars(row) return Opt.With(row, { disabled = noBars }) end

ns:RegisterOptions("ActionBars", {
    { type = "scope", key = "bars", label = "AB_BAR", values = BARS },
    { type = "preview", kind = "actionbar" },
    ------------------------------------------------------------ bars
    { type = "tab", label = "AB_TAB_BARS" },
    { type = "header", label = "AB_MODE", icon = "actionbars" },
    { type = "select", key = "mode", label = "AB_MODE", desc = "AB_MODE_DESC", values = MODE, reload = true,
      keywords = "bartender dominos own bars edit mode" },
    { type = "button", label = "AB_LAYOUT_MODE", desc = "AB_LAYOUT_MODE_DESC", button = "AB_LAYOUT_MODE_BUTTON", icon = "movers",
      combat = true, disabled = noBars, func = openLayout, keywords = "move drag unlock position" },
    { type = "header", label = "AB_LAYOUT", icon = "layout" },
    bars({ type = "toggle", gate = true, key = "bars.@.enabled", label = "AB_ENABLE", desc = "AB_ENABLE_DESC", combat = true }),
    bars({ type = "range", key = "bars.@.buttons", label = "AB_BUTTONS", min = 1, max = 12, step = 1, combat = true }),
    bars({ type = "range", key = "bars.@.rows", label = "AB_ROWS", desc = "AB_ROWS_DESC", min = 1, max = 12, step = 1, combat = true }),
    bars({ type = "range", key = "bars.@.width", label = "AB_WIDTH", min = 16, max = 120, step = 1, combat = true,
      keywords = "button size" }),
    bars({ type = "range", key = "bars.@.height", label = "AB_HEIGHT", min = 16, max = 120, step = 1, combat = true,
      disabled = function(m, bar) return noBars(m) or m.db.bars[bar].square end }),
    bars({ type = "toggle", key = "bars.@.square", label = "AB_SQUARE_SIZE", desc = "AB_SQUARE_SIZE_DESC", combat = true }),
    bars({ type = "range", key = "bars.@.spacingX", label = "AB_SPACING_X", min = -10, max = 30, step = 1, combat = true }),
    bars({ type = "range", key = "bars.@.spacingY", label = "AB_SPACING_Y", min = -10, max = 30, step = 1, combat = true }),
    bars({ type = "select", key = "bars.@.grow", label = "AB_GROW", values = Opt.GROWTH, combat = true }),
    bars({ type = "select", key = "bars.@.wrap", label = "AB_WRAP", desc = "AB_WRAP_DESC", values = Opt.GROWTH, combat = true }),
    bars({ type = "select", key = "bars.@.order", label = "AB_ORDER", values = ORDER, combat = true }),
    bars({ type = "toggle", key = "bars.@.showEmpty", label = "AB_SHOW_EMPTY", desc = "AB_SHOW_EMPTY_DESC", hidden = noGrid,
      combat = true, keywords = "grid empty slots" }),
    bars({ type = "toggle", key = "bars.@.clickThrough", label = "AB_CLICK_THROUGH", desc = "AB_CLICK_THROUGH_DESC", combat = true }),
    { type = "header", label = "AB_POSITION", icon = "movers" },
    bars({ type = "select", key = "bars.@.point", label = "AB_ANCHOR", values = Opt.ANCHOR, combat = true }),
    bars({ type = "range", key = "bars.@.x", relative = true, label = "OFFSET_X", min = -2000, max = 2000, step = 1, combat = true }),
    bars({ type = "range", key = "bars.@.y", relative = true, label = "OFFSET_Y", min = -1200, max = 1200, step = 1, combat = true }),
    bars({ type = "select", key = "bars.@.strata", label = "FRAME_STRATA", values = Opt.STRATA, combat = true }),
    bars({ type = "range", key = "bars.@.scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, percent = true, combat = true }),
    { type = "header", label = "AB_BACKDROP", icon = "theme" },
    bars({ type = "toggle", gate = true, key = "bars.@.backdrop.show", label = "AB_BACKDROP_SHOW", combat = true }),
    bars(Opt.Background("bars.@.backdrop")),
    bars({ type = "range", key = "bars.@.backdrop.padding", label = "AB_PADDING", min = 0, max = 20, step = 1, combat = true }),
    bars(Opt.Border("bars.@.border", "AB_BAR_BORDER")),
    { type = "header", label = "AB_VISIBILITY", icon = "opacity" },
    bars({ type = "toggle", key = "bars.@.vis.combat", label = "AB_VIS_COMBAT", combat = true }),
    bars({ type = "toggle", key = "bars.@.vis.ooc", label = "AB_VIS_OOC", combat = true }),
    bars({ type = "toggle", key = "bars.@.vis.fade", label = "AB_VIS_FADE", desc = "AB_VIS_FADE_DESC",
      cog = { { type = "range", key = "bars.@.vis.oocAlpha", label = "AB_VIS_OOC_ALPHA", min = 0, max = 1, step = 0.05,
                percent = true },
              { type = "toggle", key = "bars.@.vis.keepActive", label = "UF_OOC_KEEP", desc = "AB_VIS_KEEP_DESC" } } }),
    bars({ type = "toggle", key = "bars.@.vis.mouseover", label = "AB_VIS_MOUSEOVER", desc = "AB_VIS_MOUSEOVER_DESC" }),
    bars({ type = "toggle", key = "bars.@.vis.linked", label = "AB_VIS_LINKED", desc = "AB_VIS_LINKED_DESC" }),
    bars({ type = "toggle", key = "bars.@.vis.drag", label = "AB_VIS_DRAG" }),
    bars({ type = "toggle", key = "bars.@.vis.spellbook", label = "AB_VIS_SPELLBOOK" }),
    bars({ type = "toggle", key = "bars.@.vis.hideVehicle", label = "AB_VIS_VEHICLE", desc = "AB_VIS_VEHICLE_DESC", combat = true }),
    bars({ type = "input", key = "bars.@.vis.macro", label = "AB_VIS_MACRO", desc = "AB_VIS_MACRO_DESC", combat = true,
      keywords = "state driver macro conditions" }),
    bars({ type = "range", key = "bars.@.vis.alpha", label = "AB_VIS_ALPHA", min = 0, max = 1, step = 0.05, percent = true }),
    { type = "header", label = "AB_PAGING", icon = "actionbars", hidden = notBar1 },
    bars({ type = "toggle", key = "paging.forms", label = "AB_PAGE_FORMS", desc = "AB_PAGE_FORMS_DESC", hidden = notBar1,
      combat = true }),
    bars({ type = "toggle", key = "paging.sky", label = "AB_PAGE_SKY", hidden = notBar1, combat = true, feature = "skyriding" }),
    bars({ type = "toggle", key = "paging.possess", label = "AB_PAGE_POSSESS", desc = "AB_PAGE_POSSESS_DESC", hidden = notBar1,
      combat = true }),
    bars({ type = "select", key = "paging.shift", label = "AB_PAGE_SHIFT", values = PAGES, hidden = notBar1, combat = true }),
    bars({ type = "select", key = "paging.ctrl", label = "AB_PAGE_CTRL", values = PAGES, hidden = notBar1, combat = true }),
    bars({ type = "select", key = "paging.alt", label = "AB_PAGE_ALT", values = PAGES, hidden = notBar1, combat = true }),
    bars({ type = "toggle", key = "paging.arrows", label = "AB_PAGE_ARROWS", desc = "AB_PAGE_ARROWS_DESC", hidden = notBar1,
      combat = true }),
    ------------------------------------------------------------ buttons
    { type = "tab", label = "AB_TAB_BUTTONS" },
    { type = "header", label = "AB_SHAPE", icon = "actionbars" },
    { type = "toggle", gate = true, key = "style", label = "AB_STYLE_ON", desc = "AB_STYLE_ON_DESC", reload = true },
    { type = "select", key = "shape", label = "AB_SHAPE", desc = "AB_SHAPE_DESC", values = SHAPE, keywords = "round circle hex mask" },
    { type = "range", key = "iconZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 },
    Opt.Border("border", "AB_BORDER"),
    { type = "toggle", key = "desatCooldown", label = "AB_DESAT", desc = "AB_DESAT_DESC" },
    { type = "range", key = "cooldownAlpha", label = "AB_CD_ALPHA", min = 0, max = 1, step = 0.05, percent = true },
    { type = "range", key = "emptyAlpha", label = "AB_EMPTY_ALPHA", min = 0, max = 1, step = 0.05, percent = true },
    { type = "toggle", key = "equippedBorder", label = "AB_EQUIPPED", desc = "AB_EQUIPPED_DESC" },
    { type = "toggle", key = "qualityBorder", label = "AB_QUALITY", desc = "AB_QUALITY_DESC" },
    { type = "header", label = "AB_FEEDBACK", icon = "preview" },
    { type = "toggle", key = "rangeTint", label = "AB_RANGE", desc = "AB_RANGE_DESC", keywords = "out of range red",
      cog = { { type = "color", key = "rangeColor", label = "AB_RANGE_COLOR", token = "state.danger", reset = true } } },
    { type = "toggle", key = "feedback.power", label = "AB_POWER", desc = "AB_POWER_DESC", keywords = "mana energy rage",
      cog = { { type = "color", key = "feedback.powerColor", label = "AB_POWER_COLOR", token = "state.info", reset = true } } },
    { type = "toggle", key = "feedback.unusable", label = "AB_UNUSABLE", desc = "AB_UNUSABLE_DESC",
      cog = { { type = "color", key = "feedback.unusableColor", label = "AB_UNUSABLE_COLOR", token = "text.muted", reset = true } } },
    { type = "select", key = "feedback.target", label = "AB_TARGET", values = TARGET },
    { type = "select", key = "feedback.pushed", label = "AB_PUSHED", values = STATE },
    { type = "select", key = "feedback.highlight", label = "AB_HIGHLIGHT", values = STATE },
    { type = "select", key = "feedback.checked", label = "AB_CHECKED", values = STATE },
    { type = "select", key = "feedback.proc", label = "AB_PROC", desc = "AB_PROC_DESC", values = GLOW, keywords = "glow proc overlay",
      cog = { { type = "color", key = "feedback.procColor", label = "AB_PROC_COLOR", token = "accent.glow", reset = true } } },
    { type = "select", key = "feedback.assist", label = "AB_ASSIST", desc = "AB_ASSIST_DESC", values = GLOW,
      keywords = "one button assisted highlight rotation" },
    { type = "toggle", key = "feedback.hideCast", label = "AB_HIDE_CAST", desc = "AB_HIDE_CAST_DESC" },
    { type = "range", key = "feedback.swipeAlpha", label = "AB_SWIPE", min = 0, max = 1, step = 0.05, percent = true },
    { type = "toggle", key = "feedback.bling", label = "AB_BLING", desc = "AB_BLING_DESC" },
    { type = "toggle", key = "feedback.gcd", label = "AB_GCD", desc = "AB_GCD_DESC" },
    { type = "select", key = "feedback.hideTooltips", label = "AB_TIPS", values = TIPS, keywords = "tooltip hide" },
    { type = "toggle", label = "AB_LOCK", desc = "AB_LOCK_DESC", get = lockGet, set = lockSet, combat = true,
      keywords = "lock drag pick up" },
    ------------------------------------------------------------ text
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "AB_HOTKEYS_HEADER", icon = "fonts" },
    { type = "button", label = "AB_KEYBIND_MODE", desc = "AB_KEYBIND_MODE_DESC", button = "AB_KEYBIND_MODE_BUTTON", icon = "keyboard",
      combat = true, keywords = "quick keybind bind keys hotkeys hover press key mode",
      func = function(m)
          local ok, why = m:OpenQuickKeybind()
          if not ok then ns.Config:SetStatus(ns.L[why], "state.warning", "warning") end
      end },
    { type = "toggle", key = "hotkeys", label = "AB_HOTKEYS", desc = "AB_HOTKEYS_DESC", keywords = "keybind" },
    { type = "toggle", key = "shortHotkeys", label = "AB_SHORT_KEYS", desc = "AB_SHORT_KEYS_DESC" },
    Opt.Text("hotkey", "AB_HOTKEY_FONT", { place = true, max = 40, row = { disabled = function(m) return not m.db.hotkeys end } }),
    { type = "header", label = "AB_MACRO_HEADER", icon = "fonts" },
    { type = "toggle", key = "macroText", label = "AB_MACRO", desc = "AB_MACRO_DESC" },
    Opt.Text("macro", "AB_MACRO_FONT", { place = true, max = 40, row = { disabled = function(m) return not m.db.macroText end } }),
    { type = "header", label = "AB_COUNT_HEADER", icon = "fonts" },
    Opt.Text("count", "AB_COUNT_FONT", { place = true, max = 40 }),
    { type = "header", label = "AB_CD_HEADER", icon = "cooldowntext" },
    { type = "button", label = "CD_NUMBERS", desc = "AB_CD_LINK_DESC", button = "AUTO_OPEN_PAGE", icon = "link",
      keywords = "countdown omnicc timer", func = function() ns.Config:Show("CooldownText") end },
    { type = "range", key = "cooldown.size", label = "AB_CD_SIZE", desc = "AB_CD_SIZE_DESC", min = 0, max = 30, step = 1 },
    { type = "toggle", key = "cooldown.charges", label = "AB_CD_CHARGES", desc = "AB_CD_CHARGES_DESC" },
    ------------------------------------------------------------ extra bars
    { type = "tab", label = "AB_TAB_EXTRA" },
    { type = "header", label = "AB_EXTRA", icon = "actionbars" },
    { type = "toggle", key = "extra.skin", label = "AB_EXTRA_SKIN", desc = "AB_EXTRA_SKIN_DESC", disabled = unstyled },
    { type = "range", key = "extra.scale", label = "AB_EXTRA_SCALE", min = 0.5, max = 2, step = 0.05, percent = true, combat = true },
    { type = "toggle", key = "extra.hideArt", label = "AB_EXTRA_ART", desc = "AB_EXTRA_ART_DESC" },
    { type = "toggle", key = "vehicle.enabled", label = "AB_VEHICLE", desc = "AB_VEHICLE_DESC", disabled = noBars,
      cog = { { type = "range", key = "vehicle.size", label = "AB_VEHICLE_SIZE", min = 20, max = 64, step = 1 } } },
    { type = "select", key = "micro", label = "AB_MICRO", values = MENU },
    { type = "select", key = "bags", label = "AB_BAGS", values = MENU },
    { type = "toggle", key = "uprank", label = "AB_UPRANK", desc = "AB_UPRANK_DESC", feature = "uprank",
      keywords = "rank spell upgrade new rank replace" },
    { type = "header", label = "AB_ITEMS", icon = "items" },
    { type = "description", text = "AB_ITEMS_NOTE" },
    { type = "toggle", key = "items.quest", label = "AB_ITEMS_QUEST", desc = "AB_ITEMS_QUEST_DESC", disabled = noBars, combat = true },
    { type = "input", key = "items.list", label = "AB_ITEMS_LIST", desc = "AB_ITEMS_LIST_DESC", disabled = noBars, combat = true,
      keywords = "item id consumables potions" },
    { type = "input", key = "items.hotkey", label = "AB_ITEMS_HOTKEY", desc = "AB_ITEMS_HOTKEY_DESC", disabled = noBars, combat = true,
      keywords = "quest item key bind hotkey" },
    { type = "header", label = "AB_RING", icon = "grid" },
    { type = "toggle", key = "ring.enabled", label = "AB_RING", desc = "AB_RING_DESC", combat = true,
      keywords = "ring radial wheel quickdraw palette",
      cog = { { type = "range", key = "ring.size", label = "UF_SIZE", min = 24, max = 72, step = 1 },
              { type = "range", key = "ring.radius", label = "AB_RING_RADIUS", min = 40, max = 240, step = 1 } } },
    { type = "input", key = "ring.key", label = "AB_RING_KEY", desc = "AB_RING_KEY_DESC", combat = true,
      disabled = function(m) return not m.db.ring.enabled end },
    { type = "input", key = "ring.list", label = "AB_RING_LIST", desc = "AB_RING_LIST_DESC", combat = true,
      disabled = function(m) return not m.db.ring.enabled end },
})
