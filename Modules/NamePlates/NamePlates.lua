local _, ns = ...
local Style, Secret, Skin, Theme, Media = ns.Style, ns.Secret, ns.Skin, ns.Theme, ns.Media

--[[ NamePlates v2 (plan v2 S10): Phoenix-drawn nameplates with a Blizzard fallback.

    mode "phoenix"   Phoenix draws every (non-forbidden) plate itself: health bar with absorbs, tag texts (name,
                     health, level, guild), the S9 cast bar engine (CastBars draws the plate cast bar from these
                     settings), aura rows with secret-safe filter strings, raid marker, quest / elite / rare badges,
                     target / focus / mouseover effects, execute range, threat colours by role, class resource on the
                     target plate and Mythic+ forces. Blizzard's own plate (its UnitFrame) is only faded out.
    mode "blizzard"  Blizzard draws its plates; Phoenix dresses them (Blizzard.lua, the 2.0 behaviour).

    Files: NamePlates.lua (saved shape, colours, pure helpers, CVars, size and click area, contexts), Plate.lua (one
    plate's widgets and layout; the preview and the Test plates build the very same plate), Update.lua (live data,
    sample data, events), Blizzard.lua (the 2.0 restyle).

    12.x rules kept here: forbidden plates are never asked for (GetNamePlateForUnit(unit, false) and the FORBIDDEN_*
    events are not handled). "Which plate is the target / focus / mouseover" is answered by comparing plate frames
    (C_NamePlate.GetNamePlateForUnit("target")), never by UnitIsUnit on a secret answer. Health, absorbs, threat,
    reaction, level, names and aura data may be secret: they only reach sinks (SetValue, SetFormattedText, curve
    evaluation, SetAlpha with a curve result, SetSpriteSheetCell, SetStatusBarColor from UnitSelectionColor), and
    anything we branch on passes plain() first with a neutral fallback. The execute colour is an overlay whose alpha
    comes from a step curve (UnitHealthPercent(unit, true, curve)), so no health number is compared.
    Plate size (C_NamePlate.SetNamePlateSize) and hit-test insets (C_NamePlateManager.SetNamePlateHitTestInsets) are
    restricted: they run out of combat (ns.Combat:Run) and after Blizzard's own size pass (UpdateNamePlateSize). ]]

local CB = ns.modules.CastBars

local function castSettings(o)
    local b = CB.NewBarSettings({ w = o.w, h = 10, text = 9, kick = true, important = true, targeted = false,
                                   importantFill = true })
    b.enabled = o.cast ~= false
    b.gap = 2
    b.hold = 0.3
    b.text = Style.Text(9, { anchor = "LEFT", outline = "OUTLINE", shadow = false })
    b.time = Style.Text(9, { anchor = "RIGHT", outline = "OUTLINE", shadow = false })
    b.target = Style.Text(8, { anchor = "BOTTOM", outline = "OUTLINE", shadow = false, y = -10, show = o.spellTarget or false })
    return b
end

local function auraSettings(o)
    return {
        debuffs = o.debuffs or "mine", buffs = o.buffs or "off", cc = o.cc ~= false,
        size = o.size or 20, spacing = 2, max = o.max or 6, perRow = o.max or 6, gap = 4, buffSize = 18, buffMax = 3,
        zoom = 0.08, swipe = true, dispel = true, desat = false, tooltips = false,
        border = Style.Border({ style = "pixel" }),
        count = Style.Text(9, { anchor = "BOTTOMRIGHT", x = 2, y = -1, outline = "OUTLINE", shadow = false }),
        duration = Style.Text(9, { anchor = "CENTER", outline = "OUTLINE", shadow = false }),
    }
end

-- One plate kind's look (enemy / friendly).
local function style(o)
    return {
        width = o.w, height = o.h, nameOnly = o.nameOnly or false,
        texture = "", reverse = false, smooth = true, gradient = 0.25,
        color = o.color or "reaction", classColor = true, fixed = false, absorb = o.absorb ~= false,
        background = Style.Background({ alpha = 0.75 }),
        border = Style.Border({ style = "pixel" }),
        nameTag = o.nameTag or "[name]", healthTag = o.healthTag or "[health:percent]",
        levelTag = "[level][classification]", infoTag = o.infoTag or "",
        nameLength = 0, nameColor = o.nameColor or "reaction",
        name = Style.Text(o.nameSize or 10, { anchor = "TOP", y = 13, outline = "OUTLINE", shadow = false }),
        health = Style.Text(9, { anchor = "RIGHT", outline = "OUTLINE", shadow = false, show = o.healthText ~= false }),
        level = Style.Text(9, { anchor = "LEFT", outline = "OUTLINE", shadow = false, show = o.level or false }),
        info = Style.Text(8, { anchor = "BOTTOM", y = -10, outline = "OUTLINE", shadow = false, color = { r = 0.8, g = 0.8, b = 0.8 } }),
        cast = castSettings(o),
        auras = auraSettings(o),
        icons = { marker = true, markerSize = 18, markerPos = "LEFT", quest = o.quest ~= false, elite = o.elite ~= false,
                  size = 14 },
    }
end

local function context(o)
    return { scale = 1, friendly = o.friendly or "show", hideOOC = false, minions = o.minions ~= false }
end

local DEFAULTS = {
    mode = "phoenix",
    styles = {
        enemy = style({ w = 140, h = 12, cast = true, spellTarget = true, debuffs = "mine", buffs = "purgeable" }),
        friendly = style({ w = 110, h = 8, nameOnly = true, cast = false, debuffs = "off", buffs = "off", cc = false,
                           healthText = false, quest = false, elite = false, color = "class", nameColor = "class",
                           infoTag = "[guild:title]" }),
    },
    -- colours shared by both kinds (reaction, tapped, quest, execute, target and focus effects)
    colors = { hostile = false, neutral = false, friendly = false, tapped = false, quest = false, execute = false,
               target = false, focus = false, hover = false, offTank = false },
    quest = { color = false, icon = true },
    execute = { enabled = false, threshold = 20, marker = true },
    target = { effect = "glow", arrows = false, classPower = false },
    focus = { marker = true },
    hover = { highlight = true, alpha = 0.25 },
    threatRole = "auto",                      -- auto | tank | dps
    click = { enabled = false, enemyW = 140, enemyH = 30, friendlyW = 110, friendlyH = 24, friendlyThrough = false },
    contexts = { enabled = false, world = context({}), instance = context({ friendly = "name", minions = false }),
                 pvp = context({ friendly = "show" }) },
    -- the 2.0 keys (Blizzard mode, Blizzard.lua); bar / border / background / forces are read by Phoenix plates too
    texture = true, healthText = true, forces = true,
    bar = "",                                       -- "" = the theme's bar texture
    border = Style.Border(),
    background = Style.Background({ alpha = 0.75 }),
    health = Style.Text(10, { outline = "OUTLINE", shadow = false }),
    name = Style.Text(10, { styled = true }),
    forcesText = Style.Text(10, { outline = "OUTLINE", shadow = false }),
    highlight = { target = false, targetColor = false, focus = false, focusColor = false },
    threat = { enabled = false, aggro = false, warning = false, safe = false },
    castbar = { style = true, texture = "", color = false, text = Style.Text(9, { outline = "OUTLINE", shadow = false }) },
    auras = { style = true, zoom = 0.08, border = Style.Border({ style = "solid" }),
        count = Style.Text(9, { outline = "OUTLINE", shadow = false }),
        timer = Style.Text(9, { outline = "OUTLINE", shadow = false }) },
}

local M = ns:NewModule("NamePlates", {
    label = "NAMEPLATES", desc = "NAMEPLATES_DESC", category = "interface", order = 55, reloadOnToggle = true,
    descWithout = { feature = "mythicplus", desc = "NAMEPLATES_DESC_PLAIN" },
    defaults = DEFAULTS,
})
M.DEFAULTS = DEFAULTS
M.KINDS = { "enemy", "friendly" }
M.CONTEXTS = { "world", "instance", "pvp" }

local function plain(v) return not Secret.IsSecret(v) end
M.plain = plain

function M:IsPhoenix() return self.db.mode == "phoenix" end
function M:Style(kind) return self.db.styles[kind] or self.db.styles.enemy end

-- the cast bar engine and the unit-frame tags / aura buttons read plate settings through their source registries
for _, kind in ipairs(M.KINDS) do
    CB.SOURCES["plate." .. kind] = function() return M:Style(kind).cast end
    local UF = ns.modules.UnitFrames
    if UF and UF.UNIT_SOURCES then UF.UNIT_SOURCES["plate." .. kind] = function() return M:Style(kind) end end
end

---------------------------------------------------------------- contexts
-- "instance" (dungeon, raid, scenario), "pvp" (battleground, arena) or "world".
function M.ContextOf(instanceType)
    if instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then return "instance" end
    if instanceType == "pvp" or instanceType == "arena" then return "pvp" end
    return "world"
end

function M:CurrentContext()
    local _, kind = IsInInstance()
    return M.ContextOf(plain(kind) and kind or nil)
end

-- The settings of the zone we are in (nil while contexts are off).
function M:Context()
    if not self.db.contexts.enabled then return nil end
    return self.db.contexts[self.context or "world"]
end

-- Whether friendly plates draw as names only right now (the context wins over the friendly style).
function M:NameOnly(kind)
    if kind ~= "friendly" then return false end
    local c = self:Context()
    if c and c.friendly ~= "show" then return c.friendly == "name" or c.friendly == "hide" end
    return self:Style("friendly").nameOnly
end

---------------------------------------------------------------- colours
local TOKEN = {
    hostile = "state.danger", neutral = "state.warning", friendly = "state.success", tapped = "text.muted",
    quest = "accent.secondary", execute = "state.danger", target = "accent.primary", focus = "state.info",
    hover = "text.primary", offTank = "state.info",
}
M.COLOR_TOKENS = TOKEN
function M:Color(which) return Skin:SpecColor(self.db.colors[which], TOKEN[which]) end

-- Plain colour of a (plain) reaction: 1-3 hostile, 4 neutral, 5+ friendly. nil when unknown or secret.
function M:ReactionColor(reaction)
    if not plain(reaction) or type(reaction) ~= "number" then return nil end
    if reaction <= 3 then return self:Color("hostile") end
    if reaction == 4 then return self:Color("neutral") end
    return self:Color("friendly")
end

function M:IsTank(sample)
    if sample then return sample.tank and true or false end
    if self.db.threatRole == "tank" then return true end
    if self.db.threatRole == "dps" then return false end
    local api = C_SpecializationInfo
    local spec = api and api.GetSpecialization and api.GetSpecialization()
    if not plain(spec) or type(spec) ~= "number" then return false end
    local role = GetSpecializationRole and GetSpecializationRole(spec)
    return plain(role) and role == "TANK"
end

--[[ The threat colour for a plain threat status (0 none … 3 securely tanking) and the player's role, or nil to keep
    the plate's own colour. Tanks: 3 safe, 1-2 losing it, 0 danger (offTank: another tank holds it). Others:
    2-3 danger, 1 warning, 0 nothing. ]]
function M:ThreatColor(status, tank, offTank)
    local t = self.db.threat
    if not (t.enabled and plain(status) and type(status) == "number") then return nil end
    if tank then
        if status == 3 then return Skin:SpecColor(t.safe, "state.success") end
        if status == 0 then
            if offTank then return self:Color("offTank") end
            return Skin:SpecColor(t.aggro, "state.danger")
        end
        return Skin:SpecColor(t.warning, "state.warning")
    end
    if status >= 2 then return Skin:SpecColor(t.aggro, "state.danger") end
    if status == 1 then return Skin:SpecColor(t.warning, "state.warning") end
    return nil
end

local function plateOf(unit)
    local api = C_NamePlate
    if not (api and api.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(api.GetNamePlateForUnit, unit, false)
    if ok and plate and not plate:IsForbidden() then return plate end
    return nil
end
M.PlateOf = plateOf

-- Is this unit's plate the target's / focus's plate (frames compared, no unit compare)?
function M:IsPlateOf(unit, which)
    local mine = unit and plateOf(unit)
    return mine ~= nil and mine == plateOf(which)
end

--[[ The highlight / threat colour Phoenix wants for a plate, or nil to keep its own (shared with Blizzard mode
    and the preview). sample = { target, focus, threat, tank, offTank } for previews and tests. ]]
function M:PlateColor(unit, sample)
    local db, hl = self.db, self.db.highlight
    local target, focus, status, offTank
    if sample then
        target, focus, status, offTank = sample.target, sample.focus, sample.threat, sample.offTank
    else
        target = hl.target and self:IsPlateOf(unit, "target")
        focus = hl.focus and self:IsPlateOf(unit, "focus")
        if db.threat.enabled and not target and not focus then
            status = UnitThreatSituation("player", unit)
            if not plain(status) then status = nil end
        end
    end
    if hl.target and target then return Skin:SpecColor(hl.targetColor, "accent.primary") end
    if hl.focus and focus then return Skin:SpecColor(hl.focusColor, "state.info") end
    if not (db.threat.enabled and status) then return nil end
    local tank = self:IsTank(sample)
    if tank and status == 0 and not sample then offTank = self:OffTankHolds(unit) end
    return self:ThreatColor(status, tank, offTank)
end

-- True when another tank of the group has aggro on the unit (plain answers only).
function M:OffTankHolds(unit)
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if not plain(n) or type(n) ~= "number" or n == 0 then return false end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, math.min(n, 40) do
        local token = prefix .. i
        local role = UnitGroupRolesAssigned(token)
        if plain(role) and role == "TANK" then
            local me = UnitIsUnit(token, "player")
            if plain(me) and not me then
                local s = UnitThreatSituation(token, unit)
                if plain(s) and type(s) == "number" and s >= 2 then return true end
            end
        end
    end
    return false
end

---------------------------------------------------------------- pure helpers (plates, preview, smoke test)
function M:BarTexture(kind)
    local s = kind and self:Style(kind)
    local name = (s and s.texture ~= "" and s.texture) or self.db.bar
    return name ~= "" and Media:Bar(name) or Theme:Bar()
end

--[[ Where a plate's parts go around its health bar (w x h): the debuff row above the name, buffs to the left, the
    marker on its side, the cast bar under the bar. -> { cast = y, auras = y, marker = {point, x, y} } ]]
function M.Geometry(s, nameOnly)
    local g = {}
    local nameRoom = (s.name.show ~= false) and (s.name.size + 4) or 0
    g.cast = -(s.cast.gap or 2)
    g.auras = (nameOnly and (s.name.size + 4) or (s.height + nameRoom)) / 2 + s.auras.gap
    if nameOnly then g.auras = s.name.size / 2 + s.auras.gap + 2 end
    local m = s.icons
    local half = (nameOnly and 0 or s.width / 2) + 4 + m.markerSize / 2
    if m.markerPos == "RIGHT" then g.marker = { "CENTER", half, 0 }
    elseif m.markerPos == "TOP" then g.marker = { "BOTTOM", 0, g.auras + s.auras.size + 2 }
    else g.marker = { "CENTER", -half, 0 } end
    return g
end

-- The x offset (from the bar's start) of the execute threshold mark.
function M.ExecuteOffset(threshold, width)
    local t = math.max(0, math.min(100, tonumber(threshold) or 0))
    return math.floor(width * t / 100 + 0.5)
end

-- Aura filter strings for a row's choice (C_UnitAuras / AuraUtil filter words, no aura data read).
M.DEBUFF_FILTERS = {
    mine = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY", important = "HARMFUL|IMPORTANT",
    all = "HARMFUL|INCLUDE_NAME_PLATE_ONLY", off = nil,
}
M.BUFF_FILTERS = { purgeable = "HELPFUL|RAID_PLAYER_DISPELLABLE", important = "HELPFUL|IMPORTANT", all = "HELPFUL", off = nil }
M.CC_FILTER = "HARMFUL|CROWD_CONTROL"

-- "+4" for a mob worth 4 enemy forces, empty for mobs worth nothing or outside Mythic+. The count is secret while
-- unit identity is restricted; it only flows through C_StringUtil.TruncateWhenZero / WrapString into SetText.
function M:ShowForces(fs, unit)
    fs:SetText("")
    if not (self.db.forces and ns:Supports("mythicplus") and C_ChallengeMode.IsChallengeModeActive()) then return end
    local count = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
    if Secret.IsSecret(count) or count then
        fs:SetText(C_StringUtil.WrapString(C_StringUtil.TruncateWhenZero(count), "+"))
    end
end

function M:StyleForces(fs)
    Skin:TextSpec(fs, self.db.forcesText, "number", "accent.secondary")
end

---------------------------------------------------------------- CVars (client-wide, not per profile)
local STACK = "nameplateStackingTypes"
function M.StackingAvailable() return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(STACK) ~= nil end
function M.GetStacking(index)
    if not M.StackingAvailable() or not GetCVarBitfield then return false end
    return GetCVarBitfield(STACK, index) and true or false
end
function M.SetStacking(index, on)
    if not (M.StackingAvailable() and SetCVarBitfield) then return end
    ns.Combat:Run("np.stack." .. index, SetCVarBitfield, STACK, index, on and true or false)
end

---------------------------------------------------------------- size and click area (restricted: out of combat)
local function applySize()
    local c = M.db.click
    if not (M:IsEnabled() and M:IsPhoenix() and c.enabled) then return end
    local w, h = math.max(c.enemyW, c.friendlyW), math.max(c.enemyH, c.friendlyH)
    if C_NamePlate and C_NamePlate.SetNamePlateSize then pcall(C_NamePlate.SetNamePlateSize, w, h) end
    local mgr, types = C_NamePlateManager, Enum.NamePlateType
    if not (mgr and mgr.SetNamePlateHitTestInsets and types) then return end
    local function insets(kind, iw, ih, through)
        if through then iw, ih = 0, 0 end
        local x, y = math.max(0, (w - iw) / 2), math.max(0, (h - ih) / 2)
        pcall(mgr.SetNamePlateHitTestInsets, kind, x, x, y, y)
    end
    insets(types.Enemy, c.enemyW, c.enemyH, false)
    insets(types.Friendly, c.friendlyW, c.friendlyH, c.friendlyThrough)
end
M.ApplySize = function() ns.Combat:Run("np.size", applySize) end

local sizeHooked
function M:HookSize()
    if sizeHooked or not (NamePlateDriverFrame and NamePlateDriverFrame.UpdateNamePlateSize) then return end
    sizeHooked = true
    hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateSize", function() M.ApplySize() end)
end

---------------------------------------------------------------- contexts (out of combat CVars)
local function applyContext()
    if not (M:IsEnabled() and M:IsPhoenix()) then return end
    local c = M:Context()
    if not c then return end
    C_CVar.SetCVar("nameplateShowFriendlyPlayers", c.friendly == "hide" and "0" or "1")
    C_CVar.SetCVar("nameplateShowEnemyMinions", c.minions and "1" or "0")
end

function M:UpdateContext()
    self.context = self:CurrentContext()
    if self.db.contexts.enabled then ns.Combat:Run("np.context", applyContext) end
end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    self.context = self:CurrentContext()
    if self:IsPhoenix() then
        self:EnablePhoenix()  -- Update.lua
    else
        self:EnableBlizzard() -- Blizzard.lua
    end
    ns.Events:Listen("PUI_THEME_CHANGED", self, function() M:Refresh() end)
end

function M:OnDisable() self:ShowTest(false) end

function M:Refresh()
    if self:IsPhoenix() then self:RefreshPhoenix() else self:RefreshBlizzard() end
    if self.testShown then self:ShowTest(true) end
end

function M:OnSettingChanged(path)
    if type(path) == "string" and path:find("^click") then M.ApplySize() end
    if type(path) == "string" and path:find("^contexts") then self:UpdateContext() end
    self:Refresh()
end

-- Test plates: three sample plates mid-screen (plain data, any time).
function M:ShowTest(show)
    self.testShown = show and true or nil
    if not self:IsPhoenix() then return true end
    return self:ShowPhoenixTest(show) -- Update.lua
end
