local _, ns = ...
local L = ns.L
local Theme, Skin, Media = ns.Theme, ns.Skin, ns.Media

--[[ AFK screen: a calm full-screen overlay with your character, the time away and the Phoenix mark.
    Purely cosmetic: it never hides UIParent and closes itself on combat.
    S16: model, guild and hint toggles, dim strength, an optional stats line (equipped item level; Mythic+
    rating and Great Vault slots where the client has them, ns.Weekly), "not in instances" and the timer
    font. ]]
local M = ns:NewModule("AFK", {
    label = "AFK", desc = "AFK_DESC", category = "social", order = 40,
    defaults = {
        enabled = true, spin = true, showModel = true, showGuild = true, showHint = true, stats = true,
        notInInstances = true, dim = 0.45, timer = ns.Style.Text(30, { font = "", outline = "NONE", shadow = true }),
    },
})

local screen

local function paint(self)
    self.dim:SetVertexColor(0, 0, 0, M.db.dim)
    self.vignette:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0))
    Skin:Panel(self.bar, "base", { border = false })
    Skin:SetPanelColor(self.bar, "bg.sunken")
    self.line:SetGradient("HORIZONTAL", Theme:ColorObj("accent.primary"), CreateColor(0, 0, 0, 0))
    Skin:Text(self.name, "title", "text.primary", 24)
    Skin:Text(self.info, "body", "text.secondary", 14)
    Skin:TextSpec(self.timer, M.db.timer, "number", "accent.primary")
    Skin:Text(self.hint, "small", "text.muted", 12)
    Skin:Text(self.stats, "body", "text.secondary", 14)
end

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
    f.logo:SetSize(320, 80)
    ns.Icons:Brand(f.logo, "logo", 320)
    f.logo:SetPoint("LEFT", 50, 4)
    f.name = f.bar:CreateFontString(nil, "OVERLAY")
    f.name:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 30, -12)
    f.info = f.bar:CreateFontString(nil, "OVERLAY")
    f.info:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -6)
    f.timer = f.bar:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("TOPLEFT", f.info, "BOTTOMLEFT", 0, -10)
    f.hint = f.bar:CreateFontString(nil, "OVERLAY")
    f.hint:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT", 50, -28)
    f.stats = f.bar:CreateFontString(nil, "OVERLAY")
    f.stats:SetPoint("RIGHT", f.bar, "RIGHT", -60, 0)

    Skin:Register(f, paint)

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

-- "Item level 642 · Mythic+ 2840 · Vault 3/9" from plain numbers (nil parts are left out).
function M.StatsText(ilvl, rating, vaultDone, vaultTotal)
    local parts = {}
    if ilvl and ilvl > 0 then parts[#parts + 1] = L.AFK_STAT_ILVL:format(ilvl) end
    if rating and rating > 0 then parts[#parts + 1] = L.AFK_STAT_RATING:format(rating) end
    if vaultTotal and vaultTotal > 0 then parts[#parts + 1] = L.AFK_STAT_VAULT:format(vaultDone or 0, vaultTotal) end
    return table.concat(parts, "  ·  ")
end

local function currentStats()
    local _, equipped = GetAverageItemLevel()
    local rating, done, total
    if ns:Supports("mythicplus") then rating = ns.Weekly:Season().rating end
    if ns:Supports("vault") then
        done, total = 0, 0
        for _, track in ipairs(ns.Weekly.TRACKS) do
            local t = ns.Weekly:Track(track)
            done, total = done + t.done, total + #t.slots
        end
    end
    return M.StatsText(equipped and math.floor(equipped) or nil, rating, done, total)
end

function M:Apply()
    if not screen then return end
    local db = self.db
    screen.model:SetShown(db.showModel)
    screen.hint:SetShown(db.showHint)
    screen.stats:SetShown(db.stats)
    paint(screen)
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
    local guildText = self.db.showGuild and guild and ("  ·  <" .. guild .. ">") or ""
    screen.info:SetText(("%s %d %s%s"):format(LEVEL, UnitLevel("player"), className, guildText))
    screen.stats:SetText(self.db.stats and currentStats() or "")
    screen.hint:SetText(L.AFK_HINT)
    screen.since = GetTime()
    screen.model:SetUnit("player")
    screen.model:SetPortraitZoom(0)
    screen.model:SetCamDistanceScale(1.1)
    screen.model:SetAnimation(0)
    self:Apply()
    ns.Anim:FadeIn(screen, 0.4)
end

function M:Hide()
    if screen and screen:IsShown() then ns.Anim:FadeOut(screen, 0.25) end
end

function M:OnEnable()
    ns.Events:On("PLAYER_FLAGS_CHANGED", self, function(_, _, unit)
        if unit ~= "player" then return end
        if UnitIsAFK("player") and not (self.db.notInInstances and IsInInstance()) then self:Show() else self:Hide() end
    end)
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function() if screen then screen:Hide() end end)
end

function M:Refresh()
    self:Apply()
end

function M:OnDisable()
    if screen then screen:Hide() end
end
