local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local Config = ns.Config

--[[ About: identity, links, slash commands, credits and the maintained standalone addons that replace
    features removed in 2.0 (ARCHITECTURE §2, decision 1). ]]
local page = { key = "about", label = "ABOUT", desc = "ABOUT_DESC", icon = "about", locked = true, db = {} }

local LINKS = {
    { label = "LINK_CURSEFORGE", url = "https://www.curseforge.com/projects/1242528", icon = "web" },
    { label = "LINK_WAGO",       url = "https://addons.wago.io/addons/jK8XQjKy",       icon = "link" },
    { label = "LINK_GITHUB",     url = "https://github.com/vortexq89/Phoenix_UI",      icon = "github" },
}

-- Read-only URL box with the site's icon; the copy button selects the text for Ctrl+C.
local function linkBox(row, link)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(W.CONTROL_WIDTH + 116, 28)
    holder.icon = W.Icon(holder, link.icon, 16, "accent.primary")
    holder.icon:SetPoint("LEFT", 0, 0)
    local e = W:Input(holder, W.CONTROL_WIDTH + 52)
    e:SetPoint("LEFT", holder.icon, "RIGHT", 10, 0)
    e:SetValue(link.url)
    e:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    e:HookScript("OnTextChanged", function(self, user) if user then self:SetText(link.url); self:HighlightText() end end)
    local copy = W:IconButton(holder, "copy", 28, L.CHAT_COPY_URL, L.CHAT_COPY_DESC)
    copy:SetPoint("LEFT", e, "RIGHT", 6, 0)
    copy.onClick = function()
        e:SetFocus()
        e:HighlightText()
        Config:SetStatus(L.CHAT_COPY_DESC, "state.info")
    end
    return holder
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
    { type = "header", label = "SLASH_COMMANDS", icon = "terminal" },
    { type = "description", text = "SLASH_HELP_TEXT" },
    { type = "header", label = "RECOMMENDED", icon = "addon" },
    { type = "description", text = "RECOMMENDED_TEXT" },
    { type = "header", label = "CREDITS", icon = "heart" },
    { type = "description", text = "CREDITS_TEXT" },
}
for _, item in ipairs(tail) do schema[#schema + 1] = item end

Config:RegisterPage("about", function(parent)
    return Config.BuildSchemaPage(parent, page, schema)
end)
