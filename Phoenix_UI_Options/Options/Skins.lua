local _, ns = ...

ns:RegisterOptions("Skins", {
    { type = "preview", kind = "skins" },
    { type = "header", label = "SKINS_WINDOWS", icon = "skins" },
    { type = "toggle", key = "gameMenu", label = "SKINS_GAMEMENU", desc = "SKINS_GAMEMENU_DESC", reload = true, keywords = "escape menu" },
    { type = "toggle", key = "popups", label = "SKINS_POPUPS", desc = "SKINS_POPUPS_DESC", reload = true, keywords = "dialog" },
    { type = "toggle", key = "readyCheck", label = "SKINS_READYCHECK", desc = "SKINS_READYCHECK_DESC", reload = true },
    { type = "description", text = "SKINS_NOTE" },
})
