local _, ns = ...
local L, W = ns.L, ns.Widgets
local Opt = ns.Opt

-- A setting owned by another module, mirrored here with a link to its page (no second copy of the setting).
local function mirror(moduleKey, key, row)
    local other = ns.modules[moduleKey]
    local target
    for _, item in ipairs(ns.options[moduleKey] or {}) do if item.key == key then target = item end end
    return Opt.With({ type = "toggle", default = true,
        get = function() return other.db[key] and true or false end, set = function(_, v) ns.DB:Set(other, key, v) end,
        disabled = function() return not other:IsEnabled() end, link = { key = moduleKey, item = target } }, row)
end

local function openLayout()
    local movers = ns:GetModule("Movers")
    if not movers or not movers:IsEnabled() then
        ns.Config:SetStatus(L.AB_LAYOUT_NEEDS_MOVERS, "state.warning", "warning")
        return
    end
    ns.Config.frame:Hide()
    movers:SetUnlocked(true)
end

local function phoenixOff(m) return not m:UsesWindow() end
local function categoriesOff(m) return m.db.view ~= "categories" end
local function skinOff(m) return not m.db.skin end

local VIEWS = {
    { value = "blizzard", label = "BAGS_VIEW_BLIZZARD" }, { value = "combined", label = "BAGS_VIEW_COMBINED" },
    { value = "categories", label = "BAGS_VIEW_CATEGORIES" },
}
local CAT_SORT = {
    { value = "bag", label = "BAGS_SORT_BAG" }, { value = "quality", label = "BAGS_SORT_QUALITY" },
    { value = "ilvl", label = "BAGS_SORT_ILVL" }, { value = "name", label = "BAGS_SORT_NAME" },
}
local NEW_GLOW = {
    { value = "phoenix", label = "BAGS_NEW_PHOENIX" }, { value = "blizzard", label = "BAGS_NEW_BLIZZARD" },
    { value = "off", label = "OFF" },
}

-- Category chips: drag to reorder, right-click to merge a category into "Other" (dimmed) or bring it back.
local function categoryRow(row, m)
    local h = W:OrderChips(row, {
        order = function() return m:CategoryOrder() end,
        label = function(key) return m.CAT_LABEL[key] end,
        dimmed = function(key) return m:CategoryHidden(key) end,
        tip = function() return L.BAGS_CATEGORIES_TIP end,
        onReorder = function(list) ns.DB:Set(m, "categories", table.concat(list, ",")) end,
        onRightClick = function(key)
            if key == "other" then return end
            local out, found = {}, false
            for k in tostring(m.db.hiddenCats or ""):gmatch("[^,%s]+") do
                if k == key then found = true else out[#out + 1] = k end
            end
            if not found then out[#out + 1] = key end
            ns.DB:Set(m, "hiddenCats", table.concat(out, ","))
        end,
    })
    ns.Events:Listen("PUI_SETTING_CHANGED", h, function(_, _, key) if key == "Bags" then h:Layout() end end)
    return h
end

ns:RegisterOptions("Bags", {
    { type = "preview", kind = "bags" },
    { type = "tab", label = "TRACKER_TAB_LAYOUT" },
    { type = "header", label = "BAGS_LAYOUT", icon = "items" },
    { type = "select", key = "view", label = "BAGS_VIEW", desc = "BAGS_VIEW_DESC", values = VIEWS, reload = true,
      keywords = "combined categories one bag window baganator" },
    { type = "range", key = "columns", label = "BAGS_COLUMNS", min = 6, max = 24, step = 1, disabled = phoenixOff },
    { type = "range", key = "slotSize", label = "BAGS_SLOT_SIZE", min = 24, max = 56, step = 1, disabled = phoenixOff },
    { type = "range", key = "spacing", label = "BAGS_SPACING", min = 0, max = 8, step = 1, disabled = phoenixOff },
    { type = "range", key = "scale", label = "SCALE", min = 0.5, max = 1.5, step = 0.05, percent = true, disabled = phoenixOff },
    { type = "toggle", key = "reagents", label = "BAGS_REAGENTS", desc = "BAGS_REAGENTS_DESC", keywords = "reagent bag crafting",
      disabled = function(m) return m.db.view ~= "combined" end },
    { type = "custom", key = "categories", label = "BAGS_CATEGORIES", desc = "BAGS_CATEGORIES_DESC", fullWidth = true, height = 60,
      resettable = true, keywords = "sections groups order drag", build = categoryRow, disabled = categoriesOff },
    { type = "select", key = "catSort", label = "BAGS_CAT_SORT", desc = "BAGS_CAT_SORT_DESC", values = CAT_SORT,
      disabled = categoriesOff },
    { type = "toggle", key = "emptySlots", label = "BAGS_EMPTY", desc = "BAGS_EMPTY_DESC", disabled = categoriesOff },
    { type = "header", label = "BAGS_WINDOW", icon = "layout" },
    { type = "toggle", key = "skin", label = "BAGS_SKIN", desc = "BAGS_SKIN_DESC", keywords = "inventory backpack theme" },
    Opt.With(Opt.Background("backdrop", "BAGS_BACKGROUND", "bg.base"), { disabled = skinOff }),
    Opt.With(Opt.Border("border", "BAGS_BORDER", "border.strong"), { disabled = skinOff }),
    Opt.With(Opt.Text("title", "BAGS_TITLE_FONT", { token = "accent.primary" }), { disabled = skinOff }),
    { type = "toggle", key = "search", label = "BAGS_SEARCH", desc = "BAGS_SEARCH_DESC", icon = "search", disabled = phoenixOff },
    { type = "toggle", key = "sortButton", label = "BAGS_SORT_BUTTON", desc = "BAGS_SORT_BUTTON_DESC", disabled = phoenixOff },
    { type = "toggle", label = "BAGS_SORT_REVERSE", desc = "BAGS_SORT_REVERSE_DESC", default = false, keywords = "clean up direction",
      get = function() return C_Container.GetSortBagsRightToLeft and C_Container.GetSortBagsRightToLeft() or false end,
      set = function(_, v) if C_Container.SetSortBagsRightToLeft then C_Container.SetSortBagsRightToLeft(v) end end },
    { type = "toggle", key = "footer", label = "BAGS_FOOTER", desc = "BAGS_FOOTER_DESC", keywords = "gold money", disabled = phoenixOff },
    { type = "toggle", key = "currencies", label = "BAGS_CURRENCIES", desc = "BAGS_CURRENCIES_DESC", disabled = phoenixOff },
    { type = "toggle", key = "freeCount", label = "BAGS_FREE_COUNT", disabled = phoenixOff },
    { type = "toggle", key = "bagBar", label = "BAGS_BAG_BAR", desc = "BAGS_BAG_BAR_DESC", disabled = phoenixOff,
      keywords = "bag bar equipped bags containers highlight" },
    { type = "button", label = "UF_LAYOUT_MODE", desc = "BAGS_MOVE_DESC", button = "AB_LAYOUT_MODE_BUTTON", icon = "movers",
      combat = true, func = openLayout, disabled = phoenixOff, keywords = "move drag unlock position" },
    { type = "tab", label = "TAB_APPEARANCE" },
    { type = "header", label = "BAGS_SLOTS", icon = "border" },
    { type = "toggle", key = "quality", label = "BAGS_QUALITY", desc = "BAGS_QUALITY_DESC", keywords = "rarity border color",
      disabled = skinOff },
    Opt.With(Opt.Border("slotBorder", "BAGS_SLOT_BORDER", "border.black"), { disabled = skinOff }),
    Opt.With(Opt.Text("count", "BAGS_COUNT", { max = 18, place = true }), { desc = "BAGS_COUNT_DESC", disabled = skinOff }),
    { type = "toggle", key = "junk", label = "BAGS_JUNK", desc = "BAGS_JUNK_DESC", icon = "gold", keywords = "grey gray coin" },
    { type = "toggle", key = "junkDim", label = "BAGS_JUNK_DIM", desc = "BAGS_JUNK_DIM_DESC" },
    { type = "select", key = "newGlow", label = "BAGS_NEW", desc = "BAGS_NEW_DESC", values = NEW_GLOW, keywords = "new item glow" },
    { type = "toggle", key = "bind", label = "BAGS_BIND", desc = "BAGS_BIND_DESC", keywords = "boe warbound bind on equip" },
    { type = "toggle", key = "cooldowns", label = "BAGS_COOLDOWNS", desc = "BAGS_COOLDOWNS_DESC", disabled = phoenixOff },
    { type = "header", label = "BAGS_INFO", icon = "itemlevel" },
    { type = "toggle", key = "upgrade", label = "BAGS_UPGRADE", desc = "BAGS_UPGRADE_DESC", icon = "arrow-up",
      keywords = "better gear arrow green" },
    { type = "toggle", key = "simArrow", label = "BAGS_SIM_ARROW", desc = "BAGS_SIM_ARROW_DESC", icon = "sim", feature = "sim",
      keywords = "simulationcraft simc dps upgrade", disabled = function(m) return not m.db.upgrade end },
    mirror("ItemLevel", "bags", { label = "BAGS_ILVL", desc = "BAGS_ILVL_DESC", keywords = "item level ilvl" }),
    { type = "tab", label = "TAB_BEHAVIOUR" },
    { type = "header", label = "BAGS_BEHAVIOUR", icon = "automation" },
    { type = "toggle", key = "bankSkin", label = "BAGS_BANK", desc = "BAGS_BANK_DESC",
      keywords = "bank warband account reagent tabs" },
    { type = "toggle", key = "openAuction", label = "BAGS_OPEN_AUCTION", desc = "BAGS_OPEN_AUCTION_DESC" },
    { type = "toggle", key = "openTrade", label = "BAGS_OPEN_TRADE", desc = "BAGS_OPEN_TRADE_DESC" },
    { type = "toggle", key = "process", label = "BAGS_PROCESS_OPT", desc = "BAGS_PROCESS_OPT_DESC", feature = "bagProcess",
      keywords = "disenchant mill milling prospect prospecting lockpick process quick actions" },
    mirror("Automation", "sellJunk", { label = "BAGS_SELL_JUNK", desc = "BAGS_SELL_JUNK_DESC", keywords = "vendor grey auto sell" }),
})
