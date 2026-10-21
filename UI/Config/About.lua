local _, ns = ...
local L = ns.L
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media
local Config = ns.Config

--[[ About: identity, links, slash commands, credits and the maintained standalone addons that replace
    features removed in 2.0 (ARCHITECTURE §2, decision 1). ]]
local page = { key = "about", label = "ABOUT", desc = "ABOUT_DESC", icon = Media:Icon("about"), locked = true, db = {} }

local LINKS = {
    { label = "LINK_CURSEFORGE", url = "https://www.curseforge.com/projects/1242528" },
    { label = "LINK_WAGO",       url = "https://addons.wago.io/addons/jK8XQjKy" },
    { label = "LINK_GITHUB",     url = "https://github.com/vortexq89/Phoenix_UI" },
}

local function linkBox(row, url)
    local e = W:Input(row, W.CONTROL_WIDTH + 80)
    e:SetValue(url)
    e:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    e:HookScript("OnTextChanged", function(self, user) if user then self:SetText(url); self:HighlightText() end end)
    return e
end

local function hero(row)
    local h = CreateFrame("Frame", nil, row)
    h.logo = W.Texture(h, "ARTWORK", 0, Media.textures.LOGO)
    h.logo:SetSize(320, 80)
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
    { type = "header", label = "LINKS" },
}
for _, link in ipairs(LINKS) do
    schema[#schema + 1] = { type = "custom", label = link.label, build = function(row) return linkBox(row, link.url) end }
end
local tail = {
    { type = "header", label = "SLASH_COMMANDS" },
    { type = "description", text = "SLASH_HELP_TEXT" },
    { type = "header", label = "RECOMMENDED" },
    { type = "description", text = "RECOMMENDED_TEXT" },
    { type = "header", label = "CREDITS" },
    { type = "description", text = "CREDITS_TEXT" },
}
for _, item in ipairs(tail) do schema[#schema + 1] = item end

Config:RegisterPage("about", function(parent)
    return Config.BuildSchemaPage(parent, page, schema)
end)
