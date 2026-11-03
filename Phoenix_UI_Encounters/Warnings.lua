local _, ns = ...
local L, Skin, Media, Secret = ns.L, ns.Skin, ns.Media, ns.Secret
local M = ns:GetModule("Encounters")
local LEM = LibStub("LibEditMode")

--[[ Encounter warnings: Blizzard's boss alerts (ENCOUNTER_WARNING) as a Phoenix banner. The text, caster,
    target and icon are secret during an encounter: they are joined with string.format (allowed on secrets)
    and handed to SetText / SetTexture untouched. Severity and duration are plain, so the banner sizes,
    colours, orders, times out and picks the sound by severity. The game's minimum-severity setting
    (encounterWarningsLevel) is honoured; "only when it targets me" cannot be, because the target is secret.
    Review 28 (BigWigs parity): how many lines the banner keeps, and a red flash on the screen edges for a
    critical warning (BigWigs "Flash"; plain severity decides it, nothing secret is read). ]]
local W = {}
M.Warnings = W

local FADE, GAP = 0.5, 4
M.WARN_SCALE = { high = 1.2, medium = 1, low = 0.82 }
M.WARN_TOKEN = { high = "state.danger", medium = "state.warning", low = "text.primary" }

local banner
local lines = {}   -- lines[1] is the newest
local editing = false

---------------------------------------------------------------- lines (shared with the options preview)
function M:CreateWarningLine(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    Skin:IconZoom(f.icon, 0.08)
    f.iconEdge = CreateFrame("Frame", nil, f)
    f.iconEdge:SetAllPoints(f.icon)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetJustifyH("CENTER")
    f.text:SetWordWrap(false)
    return f
end

-- Font, colour and icon placement for a line of `level` ("high" / "medium" / "low").
function M:StyleWarningLine(f, level)
    local db = self.db.warnings
    local spec = db.text
    local size = math.floor(spec.size * (self.WARN_SCALE[level] or 1) + 0.5)
    Skin:TextSpec(f.text, { font = spec.font, size = size, outline = spec.outline, shadow = spec.shadow,
        color = spec.color }, "heading", self.WARN_TOKEN[level] or "text.primary")
    if type(spec.color) ~= "table" then f.text:SetTextColor(ns.Theme:Color(self.WARN_TOKEN[level] or "text.primary")) end
    local iconSize = size + 6
    f.icon:SetSize(iconSize, iconSize)
    f.icon:SetShown(db.icon)
    f.iconEdge:SetShown(db.icon)
    Skin:BorderSpec(f.iconEdge, { style = "solid", size = 1 }, "border.black")
    f:SetHeight(iconSize)
    f.text:ClearAllPoints()
    f.text:SetPoint("CENTER", db.icon and (iconSize / 2 + 3) or 0, 0)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("RIGHT", f.text, "LEFT", -6, 0)
end

---------------------------------------------------------------- sounds
-- choice: "blizzard" (the game's sound for this severity), "none", or a Phoenix / LibSharedMedia sound.
function M:PlayWarningSound(severity)
    local level = self.SEVERITY[severity]
    local choice = level and self.db.warnings.sounds[level]
    if not choice or choice == "none" then return end
    if not C_CVar.GetCVarBool("Sound_EnableEncounterWarningsSounds") then return end
    if choice == "blizzard" then
        C_EncounterWarnings.PlaySound(severity)
    else
        Media:PlaySound(choice, "Master")
    end
end

---------------------------------------------------------------- banner
local function layout()
    for i, f in ipairs(lines) do
        f:ClearAllPoints()
        if i == 1 then
            f:SetPoint("TOP", banner, "TOP", 0, 0)
        else
            f:SetPoint("TOP", lines[i - 1], "BOTTOM", 0, -GAP)
        end
        f:SetWidth(banner:GetWidth())
    end
end

local pool = {}
local function acquire()
    local f = table.remove(pool) or M:CreateWarningLine(banner)
    f:SetAlpha(1)
    f.gate = nil -- a line gated by a secret (AnnounceCast) keeps the alpha the game gave it
    f:Show()
    return f
end

local function release(i)
    local f = table.remove(lines, i)
    f:Hide()
    pool[#pool + 1] = f
end

local function onUpdate()
    local now = GetTime()
    for i = #lines, 1, -1 do
        local f = lines[i]
        local left = f.expires - now
        if left <= 0 then
            release(i)
        elseif not f.gate then
            f:SetAlpha(left < FADE and left / FADE or 1)
        end
    end
    if #lines == 0 then
        if not editing then banner:Hide() end
    else
        layout()
    end
end

-- Shows one warning. text may be secret; level and duration are plain.
-- Screen-edge flash: four gradients on a full-screen frame, faded in and out by one animation.
local flash
local function edge(f, a, b, horizontal)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(Media.textures.WHITE)
    t:SetPoint(a); t:SetPoint(b)
    if horizontal then t:SetWidth(120) else t:SetHeight(120) end
    return t
end
function M:FlashScreen()
    if not flash then
        flash = CreateFrame("Frame", nil, UIParent)
        flash:SetAllPoints(UIParent)
        flash:SetFrameStrata("FULLSCREEN_DIALOG")
        flash:EnableMouse(false)
        flash:SetAlpha(0)
        flash.edges = {
            { edge(flash, "TOPLEFT", "BOTTOMLEFT", true), "HORIZONTAL", true },
            { edge(flash, "TOPRIGHT", "BOTTOMRIGHT", true), "HORIZONTAL", false },
            { edge(flash, "TOPLEFT", "TOPRIGHT", false), "VERTICAL", false },
            { edge(flash, "BOTTOMLEFT", "BOTTOMRIGHT", false), "VERTICAL", true },
        }
        local g = flash:CreateAnimationGroup()
        local up = g:CreateAnimation("Alpha"); up:SetFromAlpha(0); up:SetToAlpha(1); up:SetDuration(0.15); up:SetOrder(1)
        local down = g:CreateAnimation("Alpha"); down:SetFromAlpha(1); down:SetToAlpha(0); down:SetDuration(0.55); down:SetOrder(2)
        g:SetScript("OnFinished", function() flash:SetAlpha(0); flash:Hide() end)
        flash.anim = g
    end
    local r, g, b = ns.Theme:Color("state.danger")
    for _, e in ipairs(flash.edges) do
        -- strong at the screen edge, clear towards the middle
        local solid, clear = CreateColor(r, g, b, 0.7), CreateColor(r, g, b, 0)
        if e[3] then e[1]:SetGradient(e[2], solid, clear) else e[1]:SetGradient(e[2], clear, solid) end
    end
    flash:Show()
    flash.anim:Stop()
    flash.anim:Play()
end

local function push(level, text, icon, duration)
    local most = math.max(1, math.min(5, tonumber(M.db.warnings.lines) or 3))
    while #lines >= most do release(#lines) end
    local f = acquire()
    M:StyleWarningLine(f, level)
    f.text:SetText(text)
    f.icon:SetTexture(icon)
    f.expires = GetTime() + duration
    table.insert(lines, 1, f)
    layout()
    banner:Show()
end

local DEFAULT_DURATION = 4 -- seconds, when a warning carries none

-- The warning's format string takes the caster and the target name; all three may be secret.
local function formatted(info)
    local ok, text = pcall(string.format, info.text, info.casterName, info.targetName)
    if ok then return text end
    return info.text
end

local function onWarning(_, _, info)
    if not (M:Draws("warnings") and type(info) == "table") then return end
    local severity = info.severity
    if Secret.IsSecret(severity) then return end
    local level = M.SEVERITY[severity] or "medium"
    if severity < (tonumber((C_CVar.GetCVar("encounterWarningsLevel"))) or 0) then return end
    local duration = (not Secret.IsSecret(info.duration) and type(info.duration) == "number" and info.duration > 0)
        and info.duration or DEFAULT_DURATION
    push(level, formatted(info), info.iconFileID, duration)
    M:PlayWarningSound(severity)
    if level == "high" and M.db.warnings.flash then M:FlashScreen() end
end

--[[ Important-cast announcements (CastBars > Important casts > Announce, the LittleWigs trash warnings done the
    Midnight way): one banner line "caster: spell" when the game marks a cast important. `important` may be
    secret: then the line's alpha comes from it (SetAlphaFromBoolean) and no sound plays, as a sound cannot hang
    on a secret; a plain true plays the medium warning sound. Returns true when a line was pushed. ]]
function M:AnnounceCast(caster, spell, icon, important)
    if not (banner and M:Draws("warnings")) or important == nil then return false end
    local secret = Secret.IsSecret(important)
    if not secret and not important then return false end
    local ok, text = pcall(string.format, L.ENC_CAST_ANNOUNCE, caster, spell)
    push("medium", ok and text or spell, icon, 3)
    local f = lines[1]
    if secret then
        f.gate = true
        f:SetAlphaFromBoolean(important, 1, 0)
    else
        M:PlayWarningSound(1)
    end
    return true
end

local function clear()
    for i = #lines, 1, -1 do release(i) end
    if banner and not editing then banner:Hide() end
end

-- The game's own sample warnings, one per severity, a moment apart.
function W:Test()
    if not (banner and M:Draws("warnings")) then return end
    for i, severity in ipairs({ 2, 1, 0 }) do
        C_Timer.After((i - 1) * 0.7, function()
            local ok, info = pcall(C_EncounterWarnings.GetEditModeWarningInfo, severity)
            if ok and type(info) == "table" then
                push(M.SEVERITY[severity], formatted(info), info.iconFileID, DEFAULT_DURATION + 2)
                M:PlayWarningSound(severity)
                if severity == 2 and M.db.warnings.flash then M:FlashScreen() end
            end
        end)
    end
end

---------------------------------------------------------------- lifecycle
function W:Enable()
    if not banner then
        banner = CreateFrame("Frame", "PhoenixEncounterWarnings", UIParent)
        banner:SetFrameStrata("HIGH")
        banner:SetClampedToScreen(true)
        banner:SetSize(640, 3 * 34) -- the box Edit Mode / Layout mode shows; lines stack down from its top
        banner:Hide()
        banner:SetScript("OnUpdate", onUpdate)
        ns.EditMode:Register(banner, { key = "EncounterWarnings", name = ns.title .. " – " .. L.ENC_WARNINGS,
            default = { point = "TOP", x = 0, y = -190 },
            active = function() return M:Draws("warnings") end,
            -- Layout mode: one sample line per severity while unlocked
            preview = function(unlocked)
                if not unlocked then clear(); return end
                for _, level in ipairs({ "low", "medium", "high" }) do push(level, L.ENC_WARNINGS, M.PULL_ICON, 3600) end
            end })
        LEM:RegisterCallback("enter", function() editing = true; if M:Draws("warnings") then banner:Show() end end)
        LEM:RegisterCallback("exit", function() editing = false end)
    end
    ns.Events:On("ENCOUNTER_WARNING", W, onWarning)
    ns.Events:On("CLEAR_BOSS_EMOTES", W, clear)
end

function W:Disable()
    ns.Events:OffAll(W)
    if banner then clear(); banner:Hide() end
end

-- Lines restyle as they appear; the ones on screen keep their look until they fade.
function W:Refresh() end

function W:Count() return #lines end
