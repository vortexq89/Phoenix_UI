local _, ns = ...
local L, W = ns.L, ns.Widgets

local Opt = ns.Opt

-- Segment chips for one panel (W:OrderChips): drag to reorder, right-click to move a segment to the other panel.
-- Dimmed chips are segments that are switched off.
local LABEL = { fps = "DT_FPS", latency = "DT_LATENCY", speed = "DT_SPEED", durability = "DT_DURABILITY", gold = "DT_GOLD",
    clock = "DT_CLOCK", bugs = "DT_BUGS", bags = "DT_BAGS", itemlevel = "DT_ITEMLEVEL", friends = "DT_FRIENDS",
    guild = "DT_GUILD", mail = "DT_MAIL", spec = "DT_SPEC", keystone = "DT_KEYSTONE", coords = "DT_COORDS",
    volume = "DT_VOLUME", currency = "DT_CURRENCY" }

-- The currency picker: every currency in your currency list, plus "none".
local function currencyValues(m)
    local out = { { value = 0, label = "NONE" } }
    for _, c in ipairs(m.CurrencyChoices()) do out[#out + 1] = { value = c.id, label = c.name } end
    -- a picked currency that is not in the list right now (collapsed header, other character) stays selectable
    for i = 1, m.CURRENCY_SLOTS do
        local id = m.db["currency" .. i]
        local known = id == 0
        for _, v in ipairs(out) do if v.value == id then known = true end end
        if not known then out[#out + 1] = { value = id, label = "#" .. tostring(id) } end
    end
    return out
end
local function noCurrency(m) return not m.db.currency end

local function panelRow(panel)
    return function(row, m)
        local function list()
            local out = {}
            for _, key in ipairs(panel == 1 and m:Order1() or m:Order2()) do
                if not m.FEATURE[key] or ns:Supports(m.FEATURE[key]) then out[#out + 1] = key end
            end
            return out
        end
        local h = W:OrderChips(row, {
            order = list,
            label = function(key) return L[LABEL[key]] end,
            icon = function(key) return m.ICON[key] or key end,
            dimmed = function(key) return not m.db[key] end,
            tip = function() return m.db.panel2 and L.DT_ORDER_TIP2 or L.DT_ORDER_TIP end,
            onReorder = function(keys)
                if panel == 2 then ns.DB:Set(m, "order2", table.concat(keys, ",")); return end
                -- panel 1's saved order also keeps panel 2's segments (they are skipped there)
                local full, on1 = {}, {}
                for _, k in ipairs(keys) do on1[k] = true; full[#full + 1] = k end
                for _, k in ipairs(m:Order()) do if not on1[k] then full[#full + 1] = k end end
                ns.DB:Set(m, "order", table.concat(full, ","))
            end,
            onRightClick = function(key)
                if not m.db.panel2 then return end
                m:MoveToPanel(key, panel == 1 and 2 or 1)
            end,
        })
        ns.Events:Listen("PUI_SETTING_CHANGED", h, function(_, _, key) if key == "DataTexts" then h:Layout() end end)
        return h
    end
end

local JUSTIFY = { { value = "LEFT", label = "ANCHOR_LEFT" }, { value = "CENTER", label = "ANCHOR_CENTER" },
    { value = "RIGHT", label = "ANCHOR_RIGHT" } }
local BAR_TEXT = { { value = "mouseover", label = "DT_BAR_MOUSEOVER" }, { value = "percent", label = "DT_BAR_PERCENT" },
    { value = "current", label = "DT_BAR_CURRENT" }, { value = "remaining", label = "DT_BAR_REMAINING_LABEL" },
    { value = "none", label = "OFF" } }
local function noBar(m) return not m.db.xpBar end

ns:RegisterOptions("DataTexts", {
    { type = "preview", kind = "datatexts" },
    { type = "tab", label = "TRACKER_TAB_LAYOUT" },
    { type = "header", label = "DT_SEGMENTS", icon = "datatexts" },
    { type = "toggle", key = "fps", label = "DT_FPS", keywords = "framerate" },
    { type = "toggle", key = "latency", label = "DT_LATENCY", keywords = "ping ms" },
    { type = "toggle", key = "speed", label = "DT_SPEED", keywords = "movement" },
    { type = "toggle", key = "durability", label = "DT_DURABILITY", keywords = "repair armor" },
    { type = "range", key = "durabilityWarn", label = "DT_DURABILITY_WARN", desc = "DT_DURABILITY_WARN_DESC", min = 5, max = 50,
      step = 5, disabled = function(m) return not m.db.durability end },
    { type = "toggle", key = "gold", label = "DT_GOLD", keywords = "money" },
    { type = "toggle", key = "goldCopper", label = "DT_GOLD_COPPER", desc = "DT_GOLD_COPPER_DESC", keywords = "silver copper coins",
      disabled = function(m) return not m.db.gold end },
    { type = "toggle", key = "goldAccount", label = "DT_GOLD_ACCOUNT", desc = "DT_GOLD_ACCOUNT_DESC",
      keywords = "warband bank alts characters total", disabled = function(m) return not m.db.gold end },
    { type = "toggle", key = "clock", label = "DT_CLOCK", keywords = "time" },
    { type = "toggle", key = "clock24", label = "DT_CLOCK24", disabled = function(m) return not m.db.clock end },
    { type = "toggle", key = "clockRealm", label = "DT_CLOCK_REALM", desc = "DT_CLOCK_REALM_DESC", keywords = "server time",
      disabled = function(m) return not m.db.clock end },
    { type = "toggle", key = "bugs", label = "DT_BUGS", desc = "DT_BUGS_DESC", keywords = "errors lua",
      disabled = function() local b = ns:GetModule("Bugs"); return not (b and b:IsEnabled()) end },
    { type = "toggle", key = "bags", label = "DT_BAGS", desc = "DT_BAGS_DESC", keywords = "free slots inventory space" },
    { type = "toggle", key = "itemlevel", label = "DT_ITEMLEVEL", desc = "DT_ITEMLEVEL_DESC", keywords = "ilvl gear average" },
    { type = "toggle", key = "friends", label = "DT_FRIENDS", desc = "DT_FRIENDS_DESC", keywords = "battle.net online" },
    { type = "toggle", key = "guild", label = "DT_GUILD", desc = "DT_GUILD_DESC", keywords = "members online" },
    { type = "toggle", key = "mail", label = "DT_MAIL", desc = "DT_MAIL_DESC", keywords = "mailbox letter" },
    { type = "toggle", key = "spec", label = "DT_SPEC", desc = "DT_SPEC_DESC", keywords = "specialization loot talents" },
    { type = "toggle", key = "keystone", label = "DT_KEYSTONE", desc = "DT_KEYSTONE_DESC", feature = "mythicplus",
      keywords = "mythic plus key dungeon rating" },
    { type = "toggle", key = "coords", label = "DT_COORDS", desc = "DT_COORDS_DESC", keywords = "coordinates position map" },
    { type = "toggle", key = "volume", label = "DT_VOLUME", desc = "DT_VOLUME_DESC", keywords = "sound master audio" },
    { type = "toggle", key = "currency", label = "DT_CURRENCY", desc = "DT_CURRENCY_DESC",
      keywords = "currency currencies crests valorstones tokens picker" },
    { type = "select", key = "currency1", label = "DT_CURRENCY_1", values = currencyValues, disabled = noCurrency },
    { type = "select", key = "currency2", label = "DT_CURRENCY_2", values = currencyValues, disabled = noCurrency },
    { type = "select", key = "currency3", label = "DT_CURRENCY_3", values = currencyValues, disabled = noCurrency },
    { type = "header", label = "DT_PANELS", icon = "layout" },
    { type = "custom", key = "order", label = "DT_ORDER", desc = "DT_ORDER_DESC", fullWidth = true, height = 112, resettable = true,
      keywords = "drag reorder arrange sort", build = panelRow(1) },
    { type = "toggle", key = "panel2", label = "DT_PANEL2", desc = "DT_PANEL2_DESC", keywords = "second bar panel" },
    { type = "custom", key = "order2", label = "DT_ORDER2", desc = "DT_ORDER2_DESC", fullWidth = true, height = 60, resettable = true,
      keywords = "second panel segments", build = panelRow(2), disabled = function(m) return not m.db.panel2 end },
    { type = "range", key = "width", label = "DT_WIDTH", desc = "DT_WIDTH_DESC", min = 0, max = 1600, step = 10 },
    { type = "select", key = "justify", label = "DT_JUSTIFY", values = JUSTIFY, disabled = function(m) return m.db.width == 0 end },
    { type = "toggle", key = "mouseover", label = "DT_MOUSEOVER", desc = "DT_MOUSEOVER_DESC", keywords = "fade hide hover" },
    { type = "toggle", key = "tooltips", label = "DT_TOOLTIPS", desc = "DT_TOOLTIPS_DESC", icon = "tooltip" },
    { type = "toggle", key = "combatTips", label = "DT_COMBAT_TIPS", desc = "DT_COMBAT_TIPS_DESC", keywords = "hide tooltips combat" },
    { type = "tab", label = "TAB_APPEARANCE" },
    { type = "header", label = "DT_STYLE", icon = "theme" },
    { type = "toggle", key = "background", label = "DT_BACKGROUND", desc = "DT_BACKGROUND_DESC",
      cog = Opt.Flat(Opt.Background("backdrop", nil, "bg.base"), Opt.Border("border", nil, "border.subtle")) },
    { type = "range", key = "scale", label = "SCALE", min = 0.6, max = 2, step = 0.05, percent = true },
    { type = "range", key = "height", label = "DT_HEIGHT", min = 18, max = 40, step = 1 },
    { type = "range", key = "spacing", label = "DT_SPACING", min = 4, max = 40, step = 1 },
    { type = "select", key = "strata", label = "FRAME_STRATA", values = Opt.STRATA, keywords = "layer above below" },
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "DT_TEXT", icon = "fonts" },
    Opt.Text("value", "DT_VALUE_FONT", { max = 20 }),
    Opt.Text("unitText", "DT_UNIT_FONT", { max = 18, token = "text.muted" }),
    { type = "toggle", key = "colorValues", label = "DT_COLOR_VALUES", desc = "DT_COLOR_VALUES_DESC" },
    { type = "toggle", key = "icons", label = "DT_ICONS" },
    { type = "tab", label = "DT_XP_BAR" },
    { type = "header", label = "DT_XP_BAR", icon = "arrow-up" },
    { type = "toggle", key = "xpBar", label = "DT_XP_BAR_SHOW", desc = "DT_XP_BAR_DESC", keywords = "experience reputation rep xp" },
    { type = "toggle", key = "xpRep", label = "DT_XP_REP", desc = "DT_XP_REP_DESC", disabled = noBar },
    { type = "toggle", key = "rested", label = "DT_RESTED", desc = "DT_RESTED_DESC", disabled = noBar },
    { type = "toggle", key = "barHonor", label = "DT_BAR_HONOR", desc = "DT_BAR_HONOR_DESC", disabled = noBar,
      keywords = "honor pvp level bar" },
    { type = "texture", key = "barTexture", label = "BAR_TEXTURE", allowDefault = true, disabled = noBar },
    { type = "toggle", key = "barReverse", label = "DT_BAR_REVERSE", desc = "DT_BAR_REVERSE_DESC", disabled = noBar,
      keywords = "fill direction right to left reverse" },
    { type = "toggle", key = "barSmooth", label = "DT_BAR_SMOOTH", desc = "DT_BAR_SMOOTH_DESC", disabled = noBar,
      keywords = "smooth animate fill" },
    { type = "select", key = "barGradient", label = "DT_BAR_GRADIENT", values = Opt.GRADIENT, disabled = noBar,
      keywords = "gradient shade shading" },
    { type = "range", key = "barWidth", label = "DT_BAR_WIDTH", min = 100, max = 1600, step = 10, disabled = noBar },
    { type = "range", key = "barHeight", label = "DT_BAR_HEIGHT", min = 4, max = 30, step = 1, disabled = noBar },
    { type = "select", key = "barTextMode", label = "DT_BAR_TEXT", values = BAR_TEXT, disabled = noBar },
    Opt.With(Opt.Text("barText", "DT_BAR_FONT", { max = 18, place = true }), { disabled = noBar }),
    { type = "button", label = "DT_MOVE", desc = "DT_MOVE_DESC", button = "OPEN_EDIT_MODE", icon = "editmode",
      func = function() ns.Config.frame:Hide(); ns.EditMode:Open() end },
})
