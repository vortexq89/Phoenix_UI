local _, ns = ...
local Opt = ns.Opt

--[[ Buffs & Debuffs (plan v2 S9). The scope picks the group (Buffs / Debuffs) for the layout rows; look, text,
    weapon enchant and private aura rows are shared. Blizzard mode keeps the 2.0 skin rows only. ]]
local function blizzard(m) return m.db.mode ~= "phoenix" end
local function phoenix(m) return m.db.mode == "phoenix" end
local function flat(m) return not m.db.style end
local function off(m, key) return blizzard(m) or not m.db.headers[key or "buffs"].enabled end
local function noTypes(m) return blizzard(m) or not m.db.typeBorder end
local function noTime(m) return blizzard(m) or not m.db.colorByTime end
local function notBuffs(_, key) return (key or "buffs") ~= "buffs" end
local function noEnchant(m) return blizzard(m) or m.db.enchants ~= "separate" end
local function flatOff(m) return blizzard(m) and flat(m) end
local function noPrivate(m) return blizzard(m) or not m.db.private.enabled end

local MODE = { { value = "phoenix", label = "AURAS_MODE_PHOENIX" }, { value = "blizzard", label = "AURAS_MODE_BLIZZARD" } }
local HEADERS = { { value = "buffs", label = "AURAS_BUFFS" }, { value = "debuffs", label = "AURAS_DEBUFFS" } }
local GROW = { { value = "LEFT", label = "GROW_LEFT" }, { value = "RIGHT", label = "GROW_RIGHT" } }
local WRAP = { { value = "DOWN", label = "GROW_DOWN" }, { value = "UP", label = "GROW_UP" } }
local SORT = { { value = "TIME", label = "AURAS_SORT_TIME" }, { value = "NAME", label = "AURAS_SORT_NAME" },
    { value = "INDEX", label = "AURAS_SORT_INDEX" } }
local DIRECTION = { { value = "+", label = "AURAS_DIR_ASC" }, { value = "-", label = "AURAS_DIR_DESC" } }
local OWN = { { value = 1, label = "AURAS_OWN_FIRST" }, { value = 0, label = "AURAS_OWN_MIXED" } }
local ENCHANTS = { { value = "buffs", label = "AURAS_ENCHANTS_BUFFS" }, { value = "separate", label = "AURAS_ENCHANTS_SEPARATE" },
    { value = "hide", label = "AURAS_ENCHANTS_HIDE" } }
local SHAPE = { { value = "square", label = "AB_SHAPE_SQUARE" }, { value = "wide", label = "AURAS_SHAPE_WIDE" } }
local FORMAT = { { value = "short", label = "AURAS_FMT_SHORT" }, { value = "clock", label = "AURAS_FMT_CLOCK" },
    { value = "seconds", label = "AURAS_FMT_SECONDS" } }
local TOOLTIP = { { value = "always", label = "UF_TIP_ALWAYS" }, { value = "ooc", label = "UF_TIP_OOC" } }

local function toggleTest(m)
    if not m:IsEnabled() then return end
    if not m:ShowTest(not m.testShown) then ns.Config:SetStatus(ns.L.UF_TEST_COMBAT, "state.warning", "warning") end
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

local function px(row, extra)
    local d = row.disabled
    row.disabled = d and function(m, u) return blizzard(m) or d(m, u) end or blizzard
    return Opt.With(row, extra)
end
local function hx(row) -- per-header layout rows: off while that header is off
    local d = row.disabled
    row.disabled = d and function(m, u) return off(m, u) or d(m, u) end or off
    return row
end

ns:RegisterOptions("Auras", {
    { type = "scope", key = "headers", label = "AURAS_HEADER", values = HEADERS },
    { type = "preview", kind = "auras" },
    ------------------------------------------------------------ layout
    { type = "tab", label = "AURAS_TAB_LAYOUT" },
    { type = "header", label = "AURAS_MODE", icon = "auras" },
    { type = "select", key = "mode", label = "AURAS_MODE", desc = "AURAS_MODE_DESC", values = MODE, reload = true,
      keywords = "buffs debuffs secure header blizzard edit mode" },
    { type = "button", label = "AURAS_TEST", desc = "AURAS_TEST_DESC", button = "AURAS_TEST_BUTTON", icon = "test",
      func = toggleTest, keywords = "test fake aura sample" },
    { type = "button", label = "UF_LAYOUT_MODE", desc = "AURAS_LAYOUT_DESC", button = "AB_LAYOUT_MODE_BUTTON", icon = "movers",
      combat = true, func = openLayout, disabled = blizzard, keywords = "move drag unlock position" },
    { type = "header", label = "AURAS_GRID", icon = "grid", wide = true },
    { type = "toggle", gate = true, key = "headers.@.enabled", label = "AURAS_ENABLE", desc = "AURAS_ENABLE_DESC", reload = true,
      disabled = blizzard },
    hx({ type = "range", key = "headers.@.size", label = "ICON_SIZE", min = 16, max = 64, step = 1, combat = true }),
    hx({ type = "range", key = "headers.@.perRow", label = "AURAS_PER_ROW", min = 1, max = 40, step = 1, combat = true }),
    hx({ type = "range", key = "headers.@.rows", label = "AURAS_ROWS", min = 1, max = 10, step = 1, combat = true }),
    hx({ type = "range", key = "headers.@.hSpacing", label = "AURAS_HSPACING", min = 0, max = 20, step = 1, combat = true }),
    hx({ type = "range", key = "headers.@.vSpacing", label = "AURAS_VSPACING", min = 0, max = 40, step = 1, combat = true }),
    hx({ type = "select", key = "headers.@.growth", label = "AURAS_GROWTH", values = GROW, combat = true }),
    hx({ type = "select", key = "headers.@.wrap", label = "AURAS_WRAP", values = WRAP, combat = true }),
    hx({ type = "range", key = "headers.@.scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, combat = true }),
    { type = "header", label = "AURAS_SORTING", icon = "items" },
    hx({ type = "select", key = "headers.@.sort", label = "AURAS_SORT", desc = "AURAS_SORT_DESC", values = SORT, combat = true,
      keywords = "sort order time name" }),
    hx({ type = "select", key = "headers.@.direction", label = "AURAS_DIRECTION", values = DIRECTION, combat = true }),
    hx({ type = "select", key = "headers.@.separateOwn", label = "AURAS_OWN", desc = "AURAS_OWN_DESC", values = OWN,
      combat = true }),
    { type = "header", label = "UF_POSITION", icon = "movers" },
    hx({ type = "select", key = "headers.@.point", label = "UF_POINT", values = Opt.ANCHOR, combat = true }),
    hx({ type = "range", key = "headers.@.x", label = "OFFSET_X", min = -1200, max = 1200, step = 1, combat = true }),
    hx({ type = "range", key = "headers.@.y", label = "OFFSET_Y", min = -800, max = 800, step = 1, combat = true }),
    ------------------------------------------------------------ look
    { type = "tab", label = "AURAS_TAB_LOOK" },
    { type = "header", label = "AURAS_STYLE", icon = "theme" },
    { type = "toggle", key = "style", label = "AURAS_SKIN", desc = "AURAS_SKIN_DESC", reload = true, hidden = phoenix,
      keywords = "buffs debuffs" },
    { type = "range", key = "iconZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01,
      disabled = flatOff },
    px({ type = "select", key = "shape", label = "AURAS_SHAPE", desc = "AURAS_SHAPE_DESC", values = SHAPE, combat = true }),
    Opt.With(Opt.Border("border"), { disabled = flatOff }),
    px({ type = "toggle", key = "typeBorder", label = "AURAS_TYPE_BORDER", desc = "AURAS_TYPE_BORDER_DESC",
      keywords = "debuff type magic curse poison disease colour" }),
    px({ type = "toggle", key = "buffTypes", label = "AURAS_BUFF_TYPES", desc = "AURAS_BUFF_TYPES_DESC", disabled = noTypes }),
    px({ type = "toggle", key = "swipe", label = "AURAS_SWIPE", desc = "AURAS_SWIPE_DESC",
      cog = { { type = "toggle", key = "reverseSwipe", label = "AURAS_REVERSE_SWIPE" } } }),
    px({ type = "toggle", key = "desaturate", label = "AURAS_DESATURATE", desc = "AURAS_DESATURATE_DESC" }),
    ------------------------------------------------------------ text
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "AURAS_TEXT", icon = "fonts" },
    Opt.Text("duration", "AURAS_DURATION_FONT", { max = 18, place = true, row = { disabled = flatOff } }),
    Opt.Text("count", "AURAS_COUNT_FONT", { max = 20, place = true, row = { disabled = flatOff } }),
    { type = "header", label = "AURAS_TIMER", icon = "clock" },
    px({ type = "select", key = "durationFormat", label = "AURAS_FORMAT", desc = "AURAS_FORMAT_DESC", values = FORMAT,
      keywords = "duration time format minutes seconds" }),
    px({ type = "range", key = "precise", label = "AURAS_PRECISE", desc = "AURAS_PRECISE_DESC", min = 0, max = 30, step = 1 }),
    px({ type = "toggle", key = "colorByTime", label = "AURAS_COLOR_TIME", desc = "AURAS_COLOR_TIME_DESC" }),
    px({ type = "colors", keys = { "colors.expiring", "colors.soon", "colors.normal" },
      tokens = { "state.danger", "state.warning", "text.primary" }, label = "AURAS_TIME_COLORS",
      labels = { "AURAS_COLOR_EXPIRING", "AURAS_COLOR_SOON", "AURAS_COLOR_NORMAL" }, disabled = noTime }),
    ------------------------------------------------------------ behaviour
    { type = "tab", label = "AURAS_TAB_MORE" },
    { type = "header", label = "AURAS_BEHAVIOUR", icon = "general" },
    px({ type = "toggle", key = "cancel", label = "AURAS_CANCEL", desc = "AURAS_CANCEL_DESC", reload = true,
      keywords = "right click cancel remove buff" }),
    px({ type = "select", key = "tooltips", label = "UF_TOOLTIP", values = TOOLTIP }),
    { type = "header", label = "AURAS_ENCHANTS", icon = "items", hidden = notBuffs },
    px({ type = "select", key = "enchants", label = "AURAS_ENCHANTS_MODE", desc = "AURAS_ENCHANTS_DESC", values = ENCHANTS,
      combat = true, hidden = notBuffs, keywords = "weapon enchant oil poison imbue" }),
    px({ type = "range", key = "enchant.size", label = "ICON_SIZE", min = 16, max = 64, step = 1, combat = true,
      hidden = notBuffs, disabled = noEnchant }),
    px({ type = "range", key = "enchant.spacing", label = "ICON_SPACING", min = 0, max = 20, step = 1, combat = true,
      hidden = notBuffs, disabled = noEnchant }),
    px({ type = "select", key = "enchant.growth", label = "AURAS_GROWTH", values = GROW, combat = true,
      hidden = notBuffs, disabled = noEnchant }),
    { type = "header", label = "AURAS_PRIVATE", icon = "encounters", hidden = function(m, k) return notBuffs(m, k) end },
    px({ type = "toggle", key = "private.enabled", label = "AURAS_PRIVATE_ENABLE", desc = "AURAS_PRIVATE_DESC", hidden = notBuffs,
      keywords = "private aura boss mechanic raid" }),
    px({ type = "range", key = "private.count", label = "AURAS_PRIVATE_COUNT", min = 1, max = 6, step = 1, hidden = notBuffs,
      disabled = noPrivate }),
    px({ type = "range", key = "private.size", label = "ICON_SIZE", min = 16, max = 80, step = 1, hidden = notBuffs,
      disabled = noPrivate }),
    px({ type = "range", key = "private.spacing", label = "ICON_SPACING", min = 0, max = 20, step = 1, hidden = notBuffs,
      disabled = noPrivate }),
    px({ type = "select", key = "private.growth", label = "AURAS_GROWTH", values = GROW, hidden = notBuffs, disabled = noPrivate }),
    px({ type = "toggle", key = "private.countdown", label = "AURAS_PRIVATE_SWIPE", hidden = notBuffs, disabled = noPrivate,
      cog = { { type = "toggle", key = "private.numbers", label = "AURAS_PRIVATE_NUMBERS" } } }),
    { type = "description", text = "AURAS_LAYOUT_NOTE", hidden = blizzard },
    { type = "description", text = "AURAS_NOTE", hidden = phoenix },
})
