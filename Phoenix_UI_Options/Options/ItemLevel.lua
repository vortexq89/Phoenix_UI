local _, ns = ...
local Opt = ns.Opt

-- The badge's font, outline, shadow, colour and place share one cog (the size row stays the old db.size).
local function textRow()
    local row = Opt.Text("text", "ITEMLEVEL_FONT", { place = true })
    local cog = {}
    for _, sub in ipairs(row.cog) do
        if sub.key ~= "text.size" then cog[#cog + 1] = sub end
    end
    row.cog = cog
    return row
end

ns:RegisterOptions("ItemLevel", {
    { type = "preview", kind = "itemlevel" },
    { type = "header", label = "ITEMLEVEL_WHERE", icon = "itemlevel" },
    { type = "toggle", key = "character", label = "ITEMLEVEL_CHARACTER", desc = "ITEMLEVEL_CHARACTER_DESC", keywords = "ilvl gear" },
    { type = "toggle", key = "inspect", label = "ITEMLEVEL_INSPECT", desc = "ITEMLEVEL_INSPECT_DESC",
      keywords = "ilvl inspect other player" },
    { type = "toggle", key = "bags", label = "ITEMLEVEL_BAGS", desc = "ITEMLEVEL_BAGS_DESC", keywords = "ilvl inventory bank" },
    { type = "toggle", key = "flyout", label = "ITEMLEVEL_FLYOUT", desc = "ITEMLEVEL_FLYOUT_DESC", keywords = "ilvl equipment flyout alt" },
    { type = "toggle", key = "loot", label = "ITEMLEVEL_LOOT", desc = "ITEMLEVEL_LOOT_DESC", keywords = "ilvl loot roll need greed" },
    { type = "toggle", key = "merchant", label = "ITEMLEVEL_MERCHANT", desc = "ITEMLEVEL_MERCHANT_DESC", keywords = "ilvl vendor buy" },
    { type = "button", label = "ITEMLEVEL_UPGRADES", desc = "ITEMLEVEL_UPGRADES_DESC", button = "ITEMLEVEL_UPGRADES_BUTTON",
      icon = "itemlevel", keywords = "upgrade crest track hero myth planner",
      func = function(m) m:ShowUpgrades() end },
    { type = "range", key = "crestCost", label = "ITEMLEVEL_CREST_COST", desc = "ITEMLEVEL_CREST_COST_DESC", min = 0, max = 90, step = 5,
      keywords = "upgrade crest cost calculator" },
    { type = "range", key = "stepIlvl", label = "ITEMLEVEL_STEP_ILVL", desc = "ITEMLEVEL_STEP_ILVL_DESC", min = 1, max = 13, step = 1,
      keywords = "upgrade item level step calculator" },
    { type = "header", label = "ITEMLEVEL_STYLE", icon = "fonts" },
    { type = "toggle", key = "qualityColor", label = "ITEMLEVEL_QUALITY", desc = "ITEMLEVEL_QUALITY_DESC" },
    { type = "range", key = "size", label = "FONT_SIZE", min = 8, max = 18, step = 1 },
    textRow(),
    { type = "header", label = "ITEMLEVEL_DETAILS", icon = "items" },
    { type = "toggle", key = "track", label = "ITEMLEVEL_TRACK", desc = "ITEMLEVEL_TRACK_DESC",
      keywords = "upgrade track hero myth champion crest" },
    { type = "toggle", key = "enchant", label = "ITEMLEVEL_ENCHANT", desc = "ITEMLEVEL_ENCHANT_DESC", keywords = "enchant text slot" },
    { type = "toggle", key = "gems", label = "ITEMLEVEL_GEMS", desc = "ITEMLEVEL_GEMS_DESC",
      keywords = "gem socket empty missing warning" },
    { type = "toggle", key = "statsPanel", label = "ITEMLEVEL_STATS", desc = "ITEMLEVEL_STATS_DESC", reload = true,
      keywords = "character sheet stats panel attributes enhancements crit haste" },
    { type = "toggle", key = "statDR", label = "ITEMLEVEL_STAT_DR", desc = "ITEMLEVEL_STAT_DR_DESC",
      keywords = "diminishing returns dr stats crit haste mastery versatility rating tooltip" },
    { type = "range", key = "decimals", label = "ITEMLEVEL_DECIMALS", desc = "ITEMLEVEL_DECIMALS_DESC", min = 0, max = 2, step = 1,
      keywords = "average item level decimals character sheet" },
})
