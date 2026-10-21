local _, ns = ...

ns:RegisterOptions("ItemLevel", {
    { type = "header", label = "ITEMLEVEL_WHERE" },
    { type = "toggle", key = "character", label = "ITEMLEVEL_CHARACTER", desc = "ITEMLEVEL_CHARACTER_DESC", keywords = "ilvl gear" },
    { type = "toggle", key = "bags", label = "ITEMLEVEL_BAGS", desc = "ITEMLEVEL_BAGS_DESC", keywords = "ilvl inventory" },
    { type = "header", label = "ITEMLEVEL_STYLE" },
    { type = "toggle", key = "qualityColor", label = "ITEMLEVEL_QUALITY", desc = "ITEMLEVEL_QUALITY_DESC" },
    { type = "range", key = "size", label = "FONT_SIZE", min = 8, max = 18, step = 1 },
})
