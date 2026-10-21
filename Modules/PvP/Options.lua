local _, ns = ...

ns:RegisterOptions("PvP", {
    { type = "header", label = "PVP_QUEUE" },
    { type = "toggle", key = "safeQueue", label = "PVP_SAFE_QUEUE", desc = "PVP_SAFE_QUEUE_DESC", keywords = "leave queue timer" },
    { type = "header", label = "PVP_TARGETING" },
    { type = "toggle", key = "tabBinder", label = "PVP_TAB", desc = "PVP_TAB_DESC", combat = true, keywords = "keybind tab target" },
    { type = "header", label = "PVP_ARENA" },
    { type = "toggle", key = "surrender", label = "PVP_SURRENDER", desc = "PVP_SURRENDER_DESC", keywords = "gg forfeit" },
})
