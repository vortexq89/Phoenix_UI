local _, ns = ...
local L = ns.L
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media
local Config = ns.Config

--[[ Integration points with Blizzard UI: a themed landing page in Options → AddOns and an
    Addon Compartment entry. Both just open the standalone window. ]]
local function openFromSettings()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    Config:Show()
end

local function buildLanding()
    local f = CreateFrame("Frame")
    f.bg = W.Texture(f, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", 0, -4); f.bg:SetPoint("BOTTOMRIGHT", -4, 4)
    f.emblem = W.Texture(f, "BORDER", 0, Media.textures.EMBLEM)
    f.emblem:SetSize(300, 300)
    f.emblem:SetPoint("BOTTOMRIGHT", 40, -40)
    f.logo = W.Texture(f, "ARTWORK", 0, Media.textures.LOGO)
    f.logo:SetSize(384, 96)
    f.logo:SetPoint("TOPLEFT", 16, -24)
    f.text = W.Text(f, "body", "text.secondary")
    f.text:SetWordWrap(true)
    f.text:SetPoint("TOPLEFT", 36, -130)
    f.text:SetWidth(420)
    f.text:SetText(L.SETTINGS_LANDING)
    f.open = W:Button(f, L.OPEN_CONFIG, "primary", "phoenix", 200)
    f.open:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -20)
    f.open.onClick = openFromSettings
    f.hint = W.Text(f, "small", "text.muted")
    f.hint:SetPoint("TOPLEFT", f.open, "BOTTOMLEFT", 0, -12)
    f.hint:SetText(L.SETTINGS_LANDING_HINT)
    Skin:Register(f, function(self)
        W.Color(self.bg, "bg.base")
        W.Color(self.emblem, "accent.primary", 0.08)
        Skin:Text(self.text, "body", "text.secondary", 13)
        Skin:Text(self.hint, "small", "text.muted")
    end)
    return f
end

function Config:RegisterBlizzard()
    local category = Settings.RegisterCanvasLayoutCategory(buildLanding(), ns.title)
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category

    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
        AddonCompartmentFrame:RegisterAddon({
            text = ns.title,
            icon = Media.textures.EMBLEM,
            notCheckable = true,
            func = function() Config:Toggle() end,
            funcOnEnter = function(button)
                W.ShowTooltip(button, ns.title, L.COMPARTMENT_TIP)
            end,
            funcOnLeave = function() W.HideTooltip() end,
        })
    end
end

function Config:OpenBlizzardSettings()
    if self.settingsCategory then Settings.OpenToCategory(self.settingsCategory:GetID()) end
end
