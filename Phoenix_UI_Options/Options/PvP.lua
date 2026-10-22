local _, ns = ...
local Opt = ns.Opt

ns:RegisterOptions("PvP", {
    { type = "preview", kind = "pvp" },
    { type = "header", label = "PVP_QUEUE", icon = "bell" },
    { type = "toggle", key = "safeQueue", label = "PVP_SAFE_QUEUE", desc = "PVP_SAFE_QUEUE_DESC", keywords = "leave queue" },
    { type = "toggle", key = "showTimer", label = "PVP_TIMER", desc = "PVP_TIMER_DESC", keywords = "queue timer countdown" },
    Opt.With(Opt.Text("timer", "PVP_TIMER_FONT", { min = 10, max = 24, token = "accent.primary" }),
        { disabled = function(m) return not m.db.showTimer end }),
    { type = "sound", key = "queueSound", label = "PVP_QUEUE_SOUND", desc = "PVP_QUEUE_SOUND_DESC", keywords = "queue pop alert" },
    { type = "header", label = "PVP_TARGETING", icon = "keyboard" },
    { type = "toggle", key = "tabBinder", label = "PVP_TAB", desc = "PVP_TAB_DESC", combat = true, keywords = "keybind tab target" },
    { type = "header", label = "PVP_ARENA", icon = "pvp" },
    { type = "toggle", key = "surrender", label = "PVP_SURRENDER", desc = "PVP_SURRENDER_DESC", keywords = "gg forfeit" },
    { type = "button", label = "PVP_ARENA_LINK", desc = "PVP_ARENA_LINK_DESC", button = "AUTO_OPEN_PAGE", icon = "link",
      keywords = "arena frames enemy spec trinket", func = function() ns.Config:Show("UnitFrames") end },
    { type = "header", label = "PVP_BATTLEGROUNDS", icon = "maps" },
    { type = "button", label = "PVP_OBJECTIVES_LINK", desc = "PVP_OBJECTIVES_LINK_DESC", button = "AUTO_OPEN_PAGE", icon = "link",
      keywords = "score objectives widgets move", func = function() ns.Config:Show("Movers") end },
    { type = "button", label = "PVP_RELEASE_LINK", desc = "PVP_RELEASE_LINK_DESC", button = "AUTO_OPEN_PAGE", icon = "link",
      keywords = "release spirit battleground", func = function() ns.Config:Show("Automation") end },
})
