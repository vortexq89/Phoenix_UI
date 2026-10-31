local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local Config = ns.Config

--[[ About: identity, links, tools (every slash shortcut as a control), credits and the maintained standalone addons that replace
    features removed in 2.0 (ARCHITECTURE §2, decision 1). ]]
local page = { key = "about", label = "ABOUT", desc = "ABOUT_DESC", icon = "about", locked = true, db = {} }

local LINKS = {
    { label = "LINK_CURSEFORGE", url = "https://www.curseforge.com/projects/1242528", icon = "web" },
    { label = "LINK_WAGO",       url = "https://addons.wago.io/addons/jK8XQjKy",       icon = "link" },
    { label = "LINK_GITHUB",     url = "https://github.com/vortexq89/Phoenix_UI",      icon = "github" },
}

local function linkBox(row, link)
    return W:CopyField(row, link.url, link.icon)
end

local function hero(row)
    local h = CreateFrame("Frame", nil, row)
    h.logo = W.Texture(h, "ARTWORK", 0)
    h.logo:SetSize(320, 80)
    ns.Icons:Brand(h.logo, "logo", 320)
    h.logo:SetPoint("TOPLEFT", -6, 6)
    h.line = W.Text(h, "body", "text.secondary")
    h.line:SetPoint("TOPLEFT", 8, -78)
    h.badge = W:Badge(h, "v" .. ns.version, "accent.primary")
    h.badge:SetPoint("LEFT", h.line, "RIGHT", 10, 0)
    Skin:Register(h, function(self)
        Skin:Text(self.line, "body", "text.secondary")
        self.line:SetText(L.ABOUT_BYLINE:format(ns.Theme:Wrap("VortexQ8", "accent.text")))
    end)
    return h
end

local schema = {
    { type = "custom", label = "", fullWidth = true, height = 150, build = hero },
    { type = "description", text = "ABOUT_TEXT" },
    { type = "header", label = "LINKS", icon = "link" },
}
for _, link in ipairs(LINKS) do
    schema[#schema + 1] = { type = "custom", label = link.label, build = function(row) return linkBox(row, link) end }
end
local tail = {
    -- every slash shortcut has its control here or on its own page (standing rule: nothing needs a typed command)
    { type = "header", label = "ABOUT_TOOLS", icon = "terminal" },
    { type = "button", label = "ABOUT_EDIT_MODE", button = "ABOUT_OPEN", icon = "editmode", func = function() ns.EditMode:Open() end },
    { type = "button", label = "ABOUT_SETUP", desc = "ABOUT_SETUP_DESC", button = "ABOUT_OPEN", icon = "presets",
      func = function() Config:RunSetupWizard() end },
    { type = "button", label = "ABOUT_WHATS_NEW", button = "ABOUT_OPEN", icon = "bell", func = function() ns.ShowWhatsNew() end },
    { type = "button", label = "WHATS_NEW_ALL", desc = "WHATS_NEW_ALL_DESC", button = "ABOUT_OPEN", icon = "bell",
      func = function() ns.ShowChangelog() end },
    { type = "toggle", label = "WHATS_NEW_AUTO", desc = "WHATS_NEW_AUTO_DESC",
      get = function() return not ns.DB.sv.global.whatsNewOff end,
      set = function(_, v) ns.DB.sv.global.whatsNewOff = not v or nil end },
    { type = "button", label = "ABOUT_GAME_SETTINGS", desc = "ABOUT_GAME_SETTINGS_DESC", button = "ABOUT_OPEN", icon = "addon",
      func = function() Config:OpenBlizzardSettings() end },
    { type = "button", label = "ABOUT_DIAG", desc = "ABOUT_DIAG_DESC", button = "ABOUT_RUN", icon = "test",
      func = function() ns.Diag:Run(false) end },
    { type = "button", label = "ABOUT_RESET_WINDOW", button = "RESET", icon = "reset",
      func = function() Config:ResetPosition(); ns:Print(L.SLASH_RESET_DONE) end },
    { type = "toggle", label = "ABOUT_DEBUG", desc = "ABOUT_DEBUG_DESC",
      get = function() return ns.debug and true or false end, set = function(_, v) ns.SetDebug(v) end },
    { type = "header", label = "ABOUT_DEV", icon = "terminal" },
    { type = "toggle", label = "ABOUT_DEV_ON", desc = "ABOUT_DEV_ON_DESC",
      get = function() return ns.DevDiag and ns.DevDiag:IsEnabled() and true or false end,
      set = function(_, v) ns.DevDiag:Slash(v and "on" or "off") end },
    { type = "button", label = "ABOUT_DEV_AUDIT", button = "ABOUT_RUN", icon = "test", func = function() ns.DevDiag:Slash("audit") end },
    { type = "button", label = "ABOUT_DEV_PAGES", button = "ABOUT_RUN", icon = "test", func = function() ns.DevDiag:Slash("pages") end },
    { type = "button", label = "ABOUT_DEV_CLEAR", button = "RESET", icon = "delete", func = function() ns.DevDiag:Slash("clear") end },
    { type = "header", label = "RECOMMENDED", icon = "addon" },
    { type = "description", text = "RECOMMENDED_TEXT" },
    { type = "header", label = "CREDITS", icon = "heart" },
    { type = "description", text = "CREDITS_TEXT" },
}
for _, item in ipairs(tail) do schema[#schema + 1] = item end

Config:RegisterPage("about", function(parent)
    return Config.BuildSchemaPage(parent, page, schema)
end, { label = page.label, icon = page.icon, object = page, schema = schema })
