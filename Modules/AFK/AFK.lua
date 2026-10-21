local _, ns = ...
local L = ns.L
local Theme, Skin, Media = ns.Theme, ns.Skin, ns.Media

--[[ AFK screen: a calm full-screen overlay with your character, the time away and the Phoenix mark.
    Purely cosmetic: it never hides UIParent and closes itself on combat. ]]
local M = ns:NewModule("AFK", {
    label = "AFK", desc = "AFK_DESC", category = "social", order = 40,
    defaults = { enabled = true, spin = true },
})

local screen

local function build()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetAllPoints(UIParent)
    f:EnableMouse(true)
    f:Hide()

    f.dim = f:CreateTexture(nil, "BACKGROUND")
    f.dim:SetAllPoints()
    f.dim:SetTexture(Media.textures.WHITE)
    f.vignette = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.vignette:SetPoint("BOTTOMLEFT"); f.vignette:SetPoint("BOTTOMRIGHT")
    f.vignette:SetHeight(360)
    f.vignette:SetTexture(Media.textures.WHITE)

    f.model = CreateFrame("PlayerModel", nil, f)
    f.model:SetPoint("BOTTOMRIGHT", -80, 40)
    f.model:SetSize(560, 760)

    f.bar = CreateFrame("Frame", nil, f)
    f.bar:SetPoint("BOTTOMLEFT", 0, 70); f.bar:SetPoint("BOTTOMRIGHT", 0, 70)
    f.bar:SetHeight(140)
    f.line = f.bar:CreateTexture(nil, "ARTWORK")
    f.line:SetTexture(Media.textures.WHITE)
    f.line:SetPoint("TOPLEFT"); f.line:SetPoint("TOPRIGHT")
    f.line:SetHeight(2)

    f.logo = f.bar:CreateTexture(nil, "ARTWORK")
    f.logo:SetTexture(Media.textures.LOGO)
    f.logo:SetSize(320, 80)
    f.logo:SetPoint("LEFT", 50, 4)
    f.name = f.bar:CreateFontString(nil, "OVERLAY")
    f.name:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 30, -12)
    f.info = f.bar:CreateFontString(nil, "OVERLAY")
    f.info:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -6)
    f.timer = f.bar:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("TOPLEFT", f.info, "BOTTOMLEFT", 0, -10)
    f.hint = f.bar:CreateFontString(nil, "OVERLAY")
    f.hint:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT", 50, -28)

    Skin:Register(f, function(self)
        self.dim:SetVertexColor(0, 0, 0, 0.45)
        self.vignette:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0))
        Skin:Panel(self.bar, "base", { border = false })
        Skin:SetPanelColor(self.bar, "bg.sunken")
        self.line:SetGradient("HORIZONTAL", Theme:ColorObj("accent.primary"), CreateColor(0, 0, 0, 0))
        Skin:Text(self.name, "title", "text.primary", 24)
        Skin:Text(self.info, "body", "text.secondary", 14)
        Skin:Text(self.timer, "number", "accent.primary", 30)
        Skin:Text(self.hint, "small", "text.muted", 12)
    end)

    local elapsed, angle = 0, 0
    f:SetScript("OnUpdate", function(self, dt)
        if M.db.spin and not Theme.settings.reduceMotion then
            angle = (angle + dt * 0.25) % (math.pi * 2)
            self.model:SetFacing(angle)
        end
        elapsed = elapsed + dt
        if elapsed < 0.25 then return end
        elapsed = 0
        self.timer:SetText(ns.Util.FormatClock(GetTime() - self.since))
    end)
    return f
end

function M:Show()
    if InCombatLockdown() then return end
    screen = screen or build()
    local name = UnitName("player")
    local className, classFile = UnitClass("player")
    local r, g, b = ns.Util.ClassColor(classFile)
    screen.name:SetText(name)
    screen.name:SetTextColor(r, g, b)
    local guild = GetGuildInfo("player")
    screen.info:SetText(("%s %d %s%s"):format(LEVEL, UnitLevel("player"), className, guild and ("  ·  <" .. guild .. ">") or ""))
    screen.hint:SetText(L.AFK_HINT)
    screen.since = GetTime()
    screen.model:SetUnit("player")
    screen.model:SetPortraitZoom(0)
    screen.model:SetCamDistanceScale(1.1)
    screen.model:SetAnimation(0)
    ns.Anim:FadeIn(screen, 0.4)
end

function M:Hide()
    if screen and screen:IsShown() then ns.Anim:FadeOut(screen, 0.25) end
end

function M:OnEnable()
    ns.Events:On("PLAYER_FLAGS_CHANGED", self, function(_, _, unit)
        if unit ~= "player" then return end
        if UnitIsAFK("player") then self:Show() else self:Hide() end
    end)
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function() if screen then screen:Hide() end end)
end

function M:OnDisable()
    if screen then screen:Hide() end
end
