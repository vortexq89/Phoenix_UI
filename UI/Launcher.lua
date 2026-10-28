local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin

--[[ The settings window lives in a separate load-on-demand addon, Phoenix_UI_Options, so its pages, previews
    and option schemas cost nothing until you open it. This file stays in Phoenix_UI: it owns ns.Config's
    front door (Toggle / Show / ResetPosition load the window first, then the real methods take over the same
    table), the landing page in Options → AddOns, the Addon Compartment entry and the first-install picker.
    Phoenix_UI_Options reaches this addon's namespace through a global that exists only while it loads. ]]
local OPTIONS = "Phoenix_UI_Options"
local Config = ns.Config or {}
ns.Config = Config
local Launcher = {}
ns.Launcher = Launcher

-- Version strings of Phoenix_UI and Phoenix_UI_Options (nil when the options folder is missing).
function Launcher:Versions()
    return C_AddOns.GetAddOnMetadata("Phoenix_UI", "Version"), C_AddOns.GetAddOnMetadata(OPTIONS, "Version")
end

-- Loads the settings addon once; true when the real window code is in place.
function Launcher:Load()
    if Config.loaded then return true end
    if self.failed then return false end
    local reason
    PhoenixUI_Bridge = ns
    local ok, loaded, why = pcall(C_AddOns.LoadAddOn, OPTIONS)
    PhoenixUI_Bridge = nil
    if ok and loaded and Config.loaded then
        -- Updating only one of the two folders leaves the window out of step with the addon: say so once.
        local mine, theirs = Launcher:Versions()
        if theirs and mine ~= theirs then ns:Print(L.OPTIONS_VERSION_MISMATCH, theirs, mine) end
        return true
    end
    reason = (ok and (why and _G["ADDON_" .. why] or why)) or loaded
    self.failed = true
    ns:Print(L.OPTIONS_MISSING, tostring(reason or OPTIONS))
    return false
end

-- Front-door methods; Phoenix_UI_Options' Window.lua replaces them on the same table.
for _, name in ipairs({ "Toggle", "Show", "ResetPosition", "ShowStylePicker", "ShowModulePicker", "ShowSetupFinish",
    "RunSetupWizard" }) do
    local front
    front = function(self, ...)
        if not Launcher:Load() or Config[name] == front then return end
        return Config[name](self, ...)
    end
    Config[name] = front
end

---------------------------------------------------------------- Blizzard integration
local function openFromSettings()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    Config:Show()
end

local function buildLanding()
    local f = CreateFrame("Frame")
    f.bg = W.Texture(f, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", 0, -4); f.bg:SetPoint("BOTTOMRIGHT", -4, 4)
    f.emblem = W.Texture(f, "BORDER", 0)
    f.emblem:SetSize(300, 300)
    ns.Icons:Brand(f.emblem, "emblem", 300)
    f.emblem:SetPoint("BOTTOMRIGHT", 40, -40)
    f.logo = W.Texture(f, "ARTWORK", 0)
    f.logo:SetSize(384, 96)
    ns.Icons:Brand(f.logo, "logo", 384)
    f.logo:SetPoint("TOPLEFT", 16, -24)
    f.text = W.Text(f, "body", "text.secondary")
    f.text:SetWordWrap(true)
    f.text:SetPoint("TOPLEFT", 36, -130)
    f.text:SetWidth(420)
    f.text:SetText(L.SETTINGS_LANDING)
    f.open = W:Button(f, L.OPEN_CONFIG, "primary", "cat-phoenix", 200)
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
        -- Our own table: the compartment reads .text each time it builds its menu (SetCompartmentBadge).
        self.compartment = {
            text = ns.title,
            icon = ns.Icons.EMBLEM_SMALL,
            notCheckable = true,
            func = function(_, input)
                local bugs = ns:GetModule("Bugs")
                if input and input.buttonName == "RightButton" and bugs and bugs:IsEnabled() then
                    bugs:OpenViewer()
                else
                    Config:Toggle()
                end
            end,
            funcOnEnter = function(button)
                W.ShowTooltip(button, ns.Icons:Markup("cat-phoenix", 14, "accent.primary") .. " " .. ns.title, L.COMPARTMENT_TIP)
            end,
            funcOnLeave = function() W.HideTooltip() end,
        }
        AddonCompartmentFrame:RegisterAddon(self.compartment)
        self:SetCompartmentBadge(self.compartmentBadge)
    end
end

-- Extra text after the title in the compartment menu (the Bugs module's error count); nil clears it.
function Config:SetCompartmentBadge(text)
    self.compartmentBadge = text
    if self.compartment then self.compartment.text = text and (ns.title .. "  " .. text) or ns.title end
end

function Config:OpenBlizzardSettings()
    if self.settingsCategory then Settings.OpenToCategory(self.settingsCategory:GetID()) end
end

---------------------------------------------------------------- first install: the style picker
ns.Events:On("PLAYER_LOGIN", Launcher, function()
    local ui = ns.DB.sv.global.ui
    if not ns.DB.fresh or ui.stylePicked then return end
    C_Timer.After(4, function()
        if not InCombatLockdown() then
            ns.SafeCall(Config.ShowStylePicker, Config)
            ns.SafeCall(Config.ShowSetupFinish, Config) -- the wizard's last step, when a module reload cut it off
        end
    end)
end)
