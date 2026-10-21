local _, ns = ...

--[[ General: the theme and typography shared by the config window and every skinned frame.
    Locked (always on). Its db.theme table *is* ns.Theme.settings. ]]
local M = ns:NewModule("General", {
    label = "GENERAL", desc = "GENERAL_DESC", category = "system", order = 1, icon = ns.Media:Icon("home"), locked = true,
    defaults = {
        theme = {
            preset = "ember", custom = { r = 1, g = 0.42, b = 0.1 }, fontScale = 1,
            uiFont = "", unitFont = "", barTexture = "Satin", reduceMotion = false,
        },
    },
})

function M:OnInitialize()
    ns.Theme:Apply(self.db.theme)
end

function M:Refresh()
    ns.Theme:Apply(self.db.theme)
end
