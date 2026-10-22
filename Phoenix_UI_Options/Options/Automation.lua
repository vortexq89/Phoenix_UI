local _, ns = ...

ns:RegisterOptions("Automation", {
    { type = "header", label = "AUTO_VENDOR" },
    { type = "select", key = "repair", label = "AUTO_REPAIR", desc = "AUTO_REPAIR_DESC", values = {
        { value = "off", label = "OFF" },
        { value = "player", label = "AUTO_REPAIR_PLAYER" },
        { value = "guild", label = "AUTO_REPAIR_GUILD" },
    } },
    { type = "toggle", key = "sellJunk", label = "AUTO_SELL_JUNK", desc = "AUTO_SELL_JUNK_DESC", keywords = "grey gray vendor" },
    { type = "header", label = "AUTO_SOCIAL" },
    { type = "toggle", key = "acceptInvites", label = "AUTO_ACCEPT_INVITES", desc = "AUTO_ACCEPT_INVITES_DESC", keywords = "group party" },
    { type = "toggle", key = "declineDuels", label = "AUTO_DECLINE_DUELS", desc = "AUTO_DECLINE_DUELS_DESC" },
    { type = "toggle", key = "acceptResurrect", label = "AUTO_ACCEPT_RES", desc = "AUTO_ACCEPT_RES_DESC", keywords = "resurrection" },
    { type = "header", label = "AUTO_MISC" },
    { type = "toggle", key = "fillDelete", label = "AUTO_FILL_DELETE", desc = "AUTO_FILL_DELETE_DESC" },
    { type = "toggle", key = "autoRelease", label = "AUTO_RELEASE", desc = "AUTO_RELEASE_DESC", keywords = "battleground spirit" },
    { type = "toggle", key = "skipCinematics", label = "AUTO_SKIP_CINEMATICS", desc = "AUTO_SKIP_CINEMATICS_DESC",
      keywords = "movie cutscene" },
})
