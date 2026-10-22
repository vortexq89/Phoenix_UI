local _, ns = ...

-- Item level numbers in bags belong to the ItemLevel module; this row mirrors its switch and links there.
local function ilvlRow()
    local il = ns.modules.ItemLevel
    local target
    for _, item in ipairs(ns.options.ItemLevel or {}) do if item.key == "bags" then target = item end end
    return { type = "toggle", label = "BAGS_ILVL", desc = "BAGS_ILVL_DESC", default = true, keywords = "item level ilvl",
        get = function() return il.db.bags end, set = function(_, v) ns.DB:Set(il, "bags", v) end,
        disabled = function() return not il:IsEnabled() end, link = { key = "ItemLevel", item = target } }
end

ns:RegisterOptions("Bags", {
    { type = "preview", kind = "bags" },
    { type = "header", label = "BAGS_LOOK", icon = "items" },
    { type = "toggle", key = "skin", label = "BAGS_SKIN", desc = "BAGS_SKIN_DESC", reload = true, keywords = "inventory backpack theme" },
    { type = "toggle", key = "quality", label = "BAGS_QUALITY", desc = "BAGS_QUALITY_DESC", keywords = "rarity border color",
      disabled = function(m) return not m.db.skin end },
    { type = "range", key = "countSize", label = "BAGS_COUNT", desc = "BAGS_COUNT_DESC", min = 8, max = 18, step = 1,
      disabled = function(m) return not m.db.skin end },
    { type = "header", label = "BAGS_INFO", icon = "itemlevel" },
    { type = "toggle", key = "upgrade", label = "BAGS_UPGRADE", desc = "BAGS_UPGRADE_DESC", icon = "arrow-up",
      keywords = "better gear arrow green" },
    { type = "toggle", key = "simArrow", label = "BAGS_SIM_ARROW", desc = "BAGS_SIM_ARROW_DESC", icon = "sim",
      keywords = "simulationcraft simc dps upgrade", disabled = function(m) return not m.db.upgrade end },
    ilvlRow(),
})
