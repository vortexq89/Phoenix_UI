local _, ns = ...

ns:RegisterOptions("Minimap", {
    { type = "header", label = "MINIMAP_SHAPE" },
    { type = "toggle", key = "square", label = "MINIMAP_SQUARE", desc = "MINIMAP_SQUARE_DESC", reload = true },
    { type = "toggle", key = "zoneText", label = "MINIMAP_ZONE_TEXT", desc = "MINIMAP_ZONE_TEXT_DESC", reload = true },
    { type = "header", label = "MINIMAP_INFO" },
    { type = "toggle", key = "coords", label = "MINIMAP_COORDS", desc = "MINIMAP_COORDS_DESC", keywords = "coordinates position" },
})
