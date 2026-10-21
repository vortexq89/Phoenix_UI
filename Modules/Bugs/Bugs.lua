local ADDON, ns = ...
local L = ns.L
local W, Skin, Theme = ns.Widgets, ns.Skin, ns.Theme
local Errors = ns.Errors

--[[ Bugs: a BugGrabber + BugSack style error catcher. Capture lives in Core/Errors.lua (installed at load
    time, before any module); this module owns the SavedVariable binding, the notices (chat, sound,
    flashing indicator, data-bar count, compartment count) and the viewer (Viewer.lua).
    Public API: M:OpenViewer(), M:Counts() -> unique, total (this session). Message: PUI_BUG(report, isNew). ]]
local M = ns:NewModule("Bugs", {
    label = "BUGS", desc = "BUGS_DESC", category = "system", order = 20,
    defaults = {
        chat = true, sound = "none", flash = true, indicator = "errors",
        warnings = true, taint = true,
    },
    globalDefaults = { maxReports = 500 },
})

local LINK = "addon:" .. ADDON .. ":bugs"
local SOUND_GAP = 10 -- seconds between notification sounds
local SOUNDS = { chime = SOUNDKIT.TELL_MESSAGE, alert = SOUNDKIT.RAID_WARNING }
local indicator, lastSound, lastNotice = nil, 0, {}

function M:Counts()
    return Errors:CountSession()
end

function M:OpenViewer()
    self:GetViewer():Open() -- Viewer.lua
end

function M:OnSlash(rest)
    if rest == "options" or rest == "settings" then return ns.Config:Show(self.key) end
    if rest == "clear" then
        Errors:Clear("session")
        return self:Refresh()
    end
    self:OpenViewer()
end

---------------------------------------------------------------- minimap indicator
-- Three soft beats on a glow texture (also used by the data-bar segment).
local function pulse(region)
    ns.Anim:Tween(region, 1.4, 1, 0, function(v)
        region:SetAlpha(math.abs(math.sin(v * math.pi * 3)) * v)
    end, function() region:SetAlpha(0) end)
end
M.Pulse = pulse

local function buildIndicator()
    local b = CreateFrame("Button", nil, Minimap)
    b:SetSize(26, 26)
    b:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 2, 2)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = W.Icon(b, "bugs", 14, "state.danger")
    b.icon:SetPoint("CENTER")
    b.glow = W.Texture(b, "BACKGROUND", 1, ns.Media.textures.CIRCLE)
    b.glow:SetPoint("TOPLEFT", -6, 6); b.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    b.glow:SetAlpha(0)
    b.count = W:Badge(b, "0", "state.danger")
    b.count:SetPoint("CENTER", b, "TOPRIGHT", -2, -2)
    Skin:Register(b, function(self)
        Skin:Panel(self, "raised", { border = "border.strong", shadow = 6 })
        W.Color(self.glow, "state.danger", 0.35)
    end)
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ns.Config:Show(M.key) else M:OpenViewer() end
    end)
    b:SetScript("OnEnter", function(self)
        local unique, total = M:Counts()
        W.ShowTooltip(self, ns.Icons:Markup("bugs", 14, "state.danger") .. " " .. L.BUGS,
            L.BUGS_INDICATOR_TIP:format(unique, total))
    end)
    b:SetScript("OnLeave", W.HideTooltip)
    b:Hide()
    return b
end

local function updateIndicator()
    if not indicator then return end
    local unique = M:Counts()
    local mode = M.db.indicator
    indicator.count:Set(tostring(unique), unique > 0 and "state.danger" or "state.success")
    indicator.count:SetShown(unique > 0)
    ns.Icons:Tint(indicator.icon, unique > 0 and "state.danger" or "text.secondary")
    indicator:SetShown(M:IsEnabled() and (mode == "always" or (mode == "errors" and unique > 0)))
end

local function updateCompartment()
    local unique = M:Counts()
    ns.Config:SetCompartmentBadge(M:IsEnabled() and unique > 0
        and (ns.Icons:Markup("bugs", 12, "state.danger") .. " " .. Theme:Wrap(tostring(unique), "state.danger")) or nil)
end

---------------------------------------------------------------- notices
local function notice(r)
    local db = M.db
    if db.chat and not lastNotice[r.hash] then
        lastNotice[r.hash] = true
        local link = Theme:Wrap(("|H%s|h[%s]|h"):format(LINK, L.BUGS_OPEN), "accent.primary")
        local kind = r.kind == "taint" and L.BUGS_KIND_TAINT or r.kind == "warning" and L.BUGS_KIND_WARNING or L.BUGS_KIND_ERROR
        ns:Print(L.BUGS_NOTICE, kind, r.source, link)
    end
    if SOUNDS[db.sound] and GetTime() - lastSound > SOUND_GAP then
        lastSound = GetTime()
        PlaySound(SOUNDS[db.sound])
    end
    if db.flash and indicator and indicator:IsShown() then pulse(indicator.glow) end
end

local function onCapture(r, isNew)
    if not M:IsEnabled() then return end
    if isNew then notice(r) end
    updateIndicator()
    updateCompartment()
    ns.Events:Fire("PUI_BUG", r, isNew)
end

local function onLink(_, link)
    if link == LINK and M:IsEnabled() then M:OpenViewer() end
end

---------------------------------------------------------------- lifecycle
function M:OnInitialize()
    Errors.cap = self.global.maxReports
    Errors:Open(self.db.enabled)
    self:ApplyKinds()
end

function M:ApplyKinds()
    Errors:SetKinds({ error = true, warning = self.db.warnings, taint = self.db.taint })
end

function M:OnEnable()
    Errors:SetActive(true)
    Errors:SetListener(onCapture)
    indicator = indicator or buildIndicator()
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("BugIndicator", indicator, L.BUGS_INDICATOR) end
    EventRegistry:RegisterCallback("SetItemRef", onLink, self)
    self:Refresh()
end

function M:OnDisable()
    Errors:SetActive(false)
    Errors:SetListener(nil)
    EventRegistry:UnregisterCallback("SetItemRef", self)
    if indicator then indicator:Hide() end
    if self.viewerFrame then self.viewerFrame:Hide() end
    updateCompartment()
    ns.Events:Fire("PUI_BUG")
end

function M:Refresh()
    Errors.cap = self.global.maxReports
    self:ApplyKinds()
    updateIndicator()
    updateCompartment()
    ns.Events:Fire("PUI_BUG")
end
