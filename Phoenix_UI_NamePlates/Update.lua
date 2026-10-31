local _, ns = ...
local L, Skin, Theme = ns.L, ns.Skin, ns.Theme
local M = ns.modules.NamePlates
local UF = ns.modules.UnitFrames
local CB = ns.modules.CastBars
local plain = M.plain

--[[ Phoenix plates: live data, sample data and events. Every update reads its facts from a source: Unit Frames'
    Live (the game, secret-safe) or Sample (plain tables for the preview and Test plates), so the preview draws
    with the same code as the real plates. ]]

local INTERP = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut

local active = {}      -- unit token -> plate (ours)
M.active = active
local owners = {}      -- unit token -> event owner (one per token, registered once)
local hovered          -- our plate under the mouse

local function yes(v) return plain(v) and v and true or false end
local function sourceOf(p) return p.sample and UF.Sample or UF.Live end

---------------------------------------------------------------- facts (sample or live)
local function isTarget(p)
    if p.sample then return p.sample.target and true or false end
    return M:IsPlateOf(p.unit, "target")
end
local function isFocus(p)
    if p.sample then return p.sample.focus and true or false end
    return M:IsPlateOf(p.unit, "focus")
end
local function isQuest(p)
    if p.sample then return p.sample.quest and true or false end
    local api = C_QuestLog
    if api and api.UnitIsRelatedToActiveQuest then
        local ok, related = pcall(api.UnitIsRelatedToActiveQuest, p.unit)
        if ok and plain(related) then return related and true or false end
    end
    return false
end

-- the kind of plate a unit gets: enemy when we can attack it (plain answer), friendly otherwise
function M.KindOf(unit)
    local can = UnitCanAttack("player", unit)
    if plain(can) then return can and "enemy" or "friendly" end
    return "enemy"
end

---------------------------------------------------------------- execute (step alpha curve, no health compare)
local executeCurve, executeAt
local function executeAlphaCurve(threshold)
    if executeAt == threshold then return executeCurve or nil end
    executeAt, executeCurve = threshold, false
    if C_CurveUtil and C_CurveUtil.CreateCurve and Enum.LuaCurveType then
        local ok, c = pcall(function()
            local curve = C_CurveUtil.CreateCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            curve:AddPoint(0, 1)
            curve:AddPoint(math.max(0.001, threshold / 100), 0)
            return curve
        end)
        if ok and c then executeCurve = c end
    end
    return executeCurve or nil
end

local function updateExecute(p, src)
    local ex = M.db.execute
    if not ex.enabled or p.nameOnly or p.kind ~= "enemy" then p.Execute:SetAlpha(0); return end
    if p.sample then
        p.Execute:SetAlpha(src:HealthFraction(p) * 100 < ex.threshold and 1 or 0)
        return
    end
    local curve = executeAlphaCurve(ex.threshold)
    if not curve then p.Execute:SetAlpha(0); return end
    local ok, a = pcall(UnitHealthPercent, p.unit, true, curve)
    p.Execute:SetAlpha(ok and a or 0)
end

---------------------------------------------------------------- health and colour
-- -> r, g, b, or nil + "curve" / "selection" (secret colours drawn by a sink)
local function baseColor(p, src, s)
    if src:Tapped(p) then return M:Color("tapped") end
    if s.classColor then
        local file = src:ClassFile(p)
        if file then return ns.Util.ClassColor(file) end
    end
    if s.color == "fixed" then return Skin:SpecColor(s.fixed, "accent.primary") end
    if s.color == "health" then
        local f = src:HealthFraction(p)
        if f then return UF:CurveColor(f) end
        return nil, "curve"
    end
    if s.color == "class" and p.kind == "friendly" then
        local r, g, b = M:ReactionColor(src:Reaction(p))
        if r then return r, g, b end
    end
    local r, g, b = M:ReactionColor(src:Reaction(p))
    if r then return r, g, b end
    if p.sample then return M:Color("hostile") end
    return nil, "selection"
end

function M:HealthColor(p, src)
    local s = self:Style(p.kind)
    if src:Tapped(p) then return self:Color("tapped") end
    local sample = p.sample and { target = p.sample.target, focus = p.sample.focus, threat = p.sample.threat,
                                  tank = p.sample.tank, offTank = p.sample.offTank }
    if p.kind == "enemy" and not src:IsPlayer(p) or (sample and (sample.target or sample.focus)) then
        local r, g, b = self:PlateColor(p.unit, sample)
        if r then return r, g, b end
    end
    if self.db.quest.color and isQuest(p) then return self:Color("quest") end
    return baseColor(p, src, s)
end

-- the empty part of a bar: the theme's sunken surface (follows theme / skin changes), never a fixed grey
local function emptyBg(bar)
    local r, g, b = ns.Theme:Color("bg.sunken")
    bar.bg:SetVertexColor(r, g, b, 0.5)
end

local function paintHealth(p, src)
    local bar = p.Health
    local r, g, b = M:HealthColor(p, src)
    if r == nil and g == "curve" then
        local color = src:HealthColorFromCurve(p)
        if color then bar:SetStatusBarColor(color:GetRGB()) else bar:SetStatusBarColor(UF:Color("high")) end
        emptyBg(bar)
    elseif r == nil then
        local ok = pcall(function() bar:SetStatusBarColor(UnitSelectionColor(p.unit)) end)
        if not ok then bar:SetStatusBarColor(M:Color("hostile")) end
        emptyBg(bar)
    else
        bar:SetStatusBarColor(r, g, b)
        bar.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.5)
    end
    p.color = r and { r, g, b } or nil
end
M.PaintHealth = paintHealth

function M:UpdateHealth(p, src)
    src = src or sourceOf(p)
    local s = self:Style(p.kind)
    local bar = p.Health
    local max = src:HealthMax(p)
    bar:SetMinMaxValues(0, max)
    if s.smooth and INTERP and not p.sample then bar:SetValue(src:Health(p), INTERP) else bar:SetValue(src:Health(p)) end
    paintHealth(p, src)
    p.Absorb:SetShown(s.absorb and not p.nameOnly)
    if s.absorb then
        p.Absorb:SetMinMaxValues(0, max)
        p.Absorb:SetValue(src:Absorbs(p))
    end
    updateExecute(p, src)
    if p.compiled then UF.ApplyTags(p.HealthText, p.compiled.health, p, src) end
end

---------------------------------------------------------------- texts
local function nameColor(p, src, s)
    local mode = s.nameColor
    if mode == "class" then
        local file = src:ClassFile(p)
        if file then return ns.Util.ClassColor(file) end
        local r, g, b = M:ReactionColor(src:Reaction(p))
        if r then return r, g, b end
    elseif mode == "reaction" then
        local r, g, b = M:ReactionColor(src:Reaction(p))
        if r then return r, g, b end
    end
    return Skin:SpecColor(s.name.color, "text.primary")
end

local function levelColor(p, src)
    local lvl = src:Level(p)
    if plain(lvl) and type(lvl) == "number" and GetCreatureDifficultyColor then
        local c = GetCreatureDifficultyColor(lvl)
        if c and c.r then return c.r, c.g, c.b end
    end
    return Theme:Color("text.primary")
end

function M:UpdateTexts(p, src)
    src = src or sourceOf(p)
    local s = self:Style(p.kind)
    local c = p.compiled
    if not c then return end
    UF.ApplyTags(p.Name, c.name, p, src)
    if s.nameColor ~= "white" then p.Name:SetTextColor(nameColor(p, src, s)) end
    UF.ApplyTags(p.HealthText, c.health, p, src)
    UF.ApplyTags(p.Level, c.level, p, src)
    if type(s.level.color) ~= "table" then p.Level:SetTextColor(levelColor(p, src)) end
    UF.ApplyTags(p.Info, c.info, p, src)
end

---------------------------------------------------------------- indicators and highlights
function M:UpdateIndicators(p, src)
    src = src or sourceOf(p)
    local ic = self:Style(p.kind).icons
    if ic.marker then UF.ShowMarker(p.Marker, src:RaidMarker(p)) else p.Marker:Hide() end
    if ic.elite and not p.nameOnly then UF.ShowClassification(p.Elite, src:RawClassification(p), ic.size)
    else p.Elite:Hide() end
    p.Quest:SetShown(ic.quest and self.db.quest.icon and isQuest(p) or false)
    if p.sample then
        p.Forces:SetText(self.db.forces and ns:Supports("mythicplus") and p.sample.forces or "")
    elseif p.kind == "enemy" then
        self:ShowForces(p.Forces, p.unit)
    else
        p.Forces:SetText("")
    end
end

function M:UpdateHighlight(p)
    local target, focus = isTarget(p), isFocus(p)
    local hover = p.sample and p.sample.hover or (hovered == p)
    local t = self.db.target
    local glow = target and t.effect ~= "none" and t.effect ~= "arrows" and not p.nameOnly
    p.Glow:SetShown(glow and true or false)
    local arrows = target and (t.effect == "arrows" or t.arrows) and not p.nameOnly
    p.ArrowL:SetShown(arrows and true or false)
    p.ArrowR:SetShown(arrows and true or false)
    p.FocusMark:SetShown(focus and self.db.focus.marker and not p.nameOnly or false)
    p.Hover:SetShown(hover and self.db.hover.highlight and not target and not p.nameOnly or false)
    p.isTarget = target
    self:UpdateClassPower(p, target)
end

function M:UpdateClassPower(p, target)
    local want = self.db.target.classPower and target and p.kind == "enemy" and not p.nameOnly
    if not want then p.ClassPower:Hide(); p.classPowerActive = false; return end
    ns.SafeCall(UF.UpdateClassPower, UF, p)
end

---------------------------------------------------------------- auras (filter strings; data only reaches sinks)
local function auraList(unit, filter, max)
    if not (filter and C_UnitAuras and C_UnitAuras.GetUnitAuras) then return {} end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter, max)
    return ok and type(list) == "table" and list or {}
end

-- Shows list entries from button `from + 1` on, skipping auras already shown (plain IDs); returns the last index used.
local function fill(container, list, from, max, kind, spec, unit, seen)
    local shown = from
    for _, aura in ipairs(list) do
        if shown >= max then break end
        local id = aura.auraInstanceID
        local key = plain(id) and id or nil
        if not (key and seen[key]) then
            if key then seen[key] = true end
            shown = shown + 1
            ns.SafeCall(UF.ShowAura, UF.AuraButton(container, shown), unit, aura, kind, spec)
        end
    end
    return shown
end

local function sampleRow(container, list, max, kind, spec)
    local shown = 0
    for i, s in ipairs(list or {}) do
        if i > max then break end
        UF.ShowSampleAura(UF.AuraButton(container, i), s, kind, spec, i)
        shown = i
    end
    return shown
end

-- Debuffs: crowd control first (when on), then the chosen filter; enemy buffs: the chosen filter.
function M:UpdateAuras(p)
    local a = self:Style(p.kind).auras
    local dshown, bshown = 0, 0
    local buffs = p.kind == "enemy" and a.buffs ~= "off"
    if p.debuffSpec and not p.nameOnly then
        if p.sample then
            if a.debuffs ~= "off" then dshown = sampleRow(p.Debuffs, p.sample.debuffs, a.max, "debuffs", p.debuffSpec) end
            if buffs then bshown = sampleRow(p.Buffs, p.sample.buffs, a.buffMax, "buffs", p.buffSpec) end
        else
            local seen, unit = {}, p.unit
            if a.cc then dshown = fill(p.Debuffs, auraList(unit, M.CC_FILTER, a.max), 0, a.max, "debuffs", p.debuffSpec, unit, seen) end
            local filter = M.DEBUFF_FILTERS[a.debuffs]
            if filter and dshown < a.max then
                dshown = fill(p.Debuffs, auraList(unit, filter, a.max), dshown, a.max, "debuffs", p.debuffSpec, unit, seen)
            end
            local bfilter = buffs and M.BUFF_FILTERS[a.buffs] or nil
            if bfilter then bshown = fill(p.Buffs, auraList(unit, bfilter, a.buffMax), 0, a.buffMax, "buffs", p.buffSpec, unit, {}) end
        end
    end
    for i = dshown + 1, #(p.Debuffs.buttons or {}) do p.Debuffs.buttons[i]:Hide() end
    for i = bshown + 1, #(p.Buffs.buttons or {}) do p.Buffs.buttons[i]:Hide() end
end

---------------------------------------------------------------- the cast bar (CastBars engine)
function M:UpdateCast(p)
    local s = self:Style(p.kind)
    local f = p.Cast
    if not s.cast.enabled or p.nameOnly then CB:StopSample(f); f.active = nil; f:Hide(); return end
    if p.sample then
        if p.sample.cast then
            local c = {}
            for k, v in pairs(p.sample.cast) do c[k] = v end
            c.frozen = p.sample.frozen
            c.loop = not p.sample.frozen
            CB:StartSample(f, c)
            f:SetAlpha(1)
        else
            CB:StopSample(f)
        end
        return
    end
    f.unit = p.unit
    f.hideAt, f.active = nil, nil
    CB:ShowCast(f)
end

---------------------------------------------------------------- visibility (contexts: hide enemies out of combat)
-- Minor enemies (the game's "minus" classification: packs of weak trash) get a simpler plate: smaller and dimmer,
-- so the mobs that matter stand out (Tust idea, our own code). A secret classification is treated as normal.
function M.IsMinor(unit)
    local db = M.db and M.db.minor
    if not (db and db.enabled and unit and UnitClassification) then return false end
    local ok, c = pcall(UnitClassification, unit)
    return ok and plain(c) and c == "minus" or false
end

function M:UpdateVisibility(p)
    if p.sample then p:SetAlpha(1); return end
    local c = self:Context()
    local hide = c and c.hideOOC and p.kind == "enemy" and not InCombatLockdown()
    local base = c and c.scale > 0 and c.scale or 1
    local minor = p.kind == "enemy" and M.IsMinor(p.unit)
    p:SetScale(minor and base * self.db.minor.scale or base)
    p:SetAlpha(hide and 0 or (minor and self.db.minor.alpha or 1))
end

---------------------------------------------------------------- everything
function M:UpdatePlate(p)
    if not p.layoutDone then self:LayoutPlate(p, p.kind or "enemy") end
    local src = sourceOf(p)
    ns.SafeCall(self.UpdateHealth, self, p, src)
    ns.SafeCall(self.UpdateTexts, self, p, src)
    ns.SafeCall(self.UpdateIndicators, self, p, src)
    ns.SafeCall(self.UpdateHighlight, self, p)
    ns.SafeCall(self.UpdateAuras, self, p)
    ns.SafeCall(self.UpdateCast, self, p)
    ns.SafeCall(self.UpdateVisibility, self, p)
end

---------------------------------------------------------------- live plates
local function blizzardFrame(base)
    local uf = base and base.UnitFrame
    if uf and not uf:IsForbidden() then return uf end
    return nil
end

local function release(unit)
    local p = active[unit]
    if not p then return end
    active[unit] = nil
    CB:StopSample(p.Cast)
    p.Cast.active, p.Cast.unit = nil, nil
    p.Cast:Hide()
    if hovered == p then hovered = nil end
    p.unit = nil
    p:Hide()
    local uf = blizzardFrame(p.base)
    if uf then uf:SetAlpha(1) end
end

local UNIT_EVENTS = {
    UNIT_HEALTH = function(p) M:UpdateHealth(p) end,
    UNIT_MAXHEALTH = function(p) M:UpdateHealth(p) end,
    UNIT_ABSORB_AMOUNT_CHANGED = function(p) M:UpdateHealth(p) end,
    UNIT_AURA = function(p) M:UpdateAuras(p) end,
    UNIT_THREAT_SITUATION_UPDATE = function(p) paintHealth(p, UF.Live) end,
    UNIT_THREAT_LIST_UPDATE = function(p) paintHealth(p, UF.Live) end,
    UNIT_NAME_UPDATE = function(p) M:UpdateTexts(p) end,
    UNIT_LEVEL = function(p) M:UpdateTexts(p) end,
    UNIT_CLASSIFICATION_CHANGED = function(p) M:UpdateIndicators(p) end,
    UNIT_FACTION = function(p)
        local kind = M.KindOf(p.unit)
        if kind ~= p.kind then M:LayoutPlate(p, kind) end
        M:UpdatePlate(p)
    end,
}

local function watch(unit)
    if owners[unit] then return end
    local owner = { unit = unit }
    owners[unit] = owner
    local function handler(_, event, u, ...)
        local p = active[unit]
        if not p or u ~= unit then return end
        local fn = UNIT_EVENTS[event]
        if fn then fn(p) else CB:OnCastEvent(p.Cast, event, u, ...) end
    end
    for ev in pairs(UNIT_EVENTS) do ns.Events:OnUnit(ev, owner, handler, unit) end
    for _, ev in ipairs(CB.CAST_EVENTS) do ns.Events:OnUnit(ev, owner, handler, unit) end
end

-- Phoenix plates by Blizzard base plate (a side table: nothing is written onto Blizzard's frames)
local byBase = setmetatable({}, { __mode = "k" })
M.byBase = byBase
local function plateFor(base)
    local p = byBase[base]
    if not p then
        p = M:BuildPlate(base)
        p:SetPoint("CENTER", base, "CENTER", 0, 0)
        p.base = base
        byBase[base] = p
    end
    return p
end

local function onAdded(_, _, unit)
    if not plain(unit) or type(unit) ~= "string" then return end
    local base = M.PlateOf(unit)
    if not base then return end
    -- plates that only show widgets (objects, some quest NPCs) stay Blizzard's
    if yes(UnitNameplateShowsWidgetsOnly(unit)) then return end
    local p = plateFor(base)
    if p.unit and p.unit ~= unit then release(p.unit) end
    p.unit = unit
    active[unit] = p
    local kind = M.KindOf(unit)
    if kind ~= p.kind or not p.layoutDone then M:LayoutPlate(p, kind) else M.DressArt(p) end
    local uf = blizzardFrame(base)
    if uf then uf:SetAlpha(0) end
    watch(unit)
    p:Show()
    M:UpdatePlate(p)
end

local function onRemoved(_, _, unit)
    if not plain(unit) then return end
    release(unit)
end

local function eachPlate(fn) for _, p in pairs(active) do ns.SafeCall(fn, p) end end
M.EachPlate = eachPlate

local function highlightAll() eachPlate(function(p) M:UpdateHighlight(p); paintHealth(p, UF.Live) end) end

-- mouseover: found by plate, cleared when the mouse leaves the unit (polled lightly while one is hovered)
local poll = CreateFrame("Frame")
poll:Hide()
poll.t = 0
poll:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    if self.t < 0.1 then return end
    self.t = 0
    if not yes(UnitExists("mouseover")) then
        local was = hovered
        hovered = nil
        self:Hide()
        if was then M:UpdateHighlight(was) end
    end
end)

local function onMouseover()
    local was = hovered
    hovered = nil
    local base = M.PlateOf("mouseover")
    local p = base and byBase[base]
    if p and p.unit then hovered = p end
    if was and was ~= hovered then M:UpdateHighlight(was) end
    if hovered then M:UpdateHighlight(hovered); poll:Show() end
end

local function onPower(_, _, unit)
    if unit ~= "player" then return end
    eachPlate(function(p) if p.isTarget then M:UpdateClassPower(p, true) end end)
end

local spawned
function M:EnablePhoenix()
    if spawned then return end
    spawned = true
    local E = ns.Events
    E:On("NAME_PLATE_UNIT_ADDED", self, onAdded)
    E:On("NAME_PLATE_UNIT_REMOVED", self, onRemoved)
    E:On("PLAYER_TARGET_CHANGED", self, highlightAll)
    E:On("PLAYER_FOCUS_CHANGED", self, highlightAll)
    E:On("UPDATE_MOUSEOVER_UNIT", self, onMouseover)
    E:On("RAID_TARGET_UPDATE", self, function() eachPlate(function(p) M:UpdateIndicators(p) end) end)
    E:On("QUEST_LOG_UPDATE", self, function() eachPlate(function(p) M:UpdateIndicators(p); paintHealth(p, UF.Live) end) end)
    E:On("PLAYER_REGEN_DISABLED", self, function() eachPlate(function(p) M:UpdateVisibility(p) end) end)
    E:On("PLAYER_REGEN_ENABLED", self, function() eachPlate(function(p) M:UpdateVisibility(p) end) end)
    E:On("PLAYER_SPECIALIZATION_CHANGED", self, function() eachPlate(function(p) paintHealth(p, UF.Live) end) end)
    local function zone()
        M:UpdateContext()
        M:RefreshPhoenix()
    end
    E:On("PLAYER_ENTERING_WORLD", self, zone)
    E:On("ZONE_CHANGED_NEW_AREA", self, zone)
    for _, ev in ipairs({ "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_POINT_CHARGE" }) do
        E:OnUnit(ev, self, onPower, "player")
    end
    E:On("RUNE_POWER_UPDATE", self, function() onPower(nil, nil, "player") end)
    self:HookSize()
    M.ApplySize()
    self:UpdateContext()
    -- plates that already exist (a /reload with plates on screen)
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, list = pcall(C_NamePlate.GetNamePlates, false)
        if ok and type(list) == "table" then
            for _, base in ipairs(list) do
                local unit = base.namePlateUnitToken
                if unit and plain(unit) then onAdded(nil, nil, unit) end
            end
        end
    end
end

function M:RefreshPhoenix()
    if not spawned then return end
    for unit, p in pairs(active) do
        local kind = M.KindOf(unit)
        self:LayoutPlate(p, kind)
        self:UpdatePlate(p)
    end
    if self.testPlates then for _, p in ipairs(self.testPlates) do self:LayoutPlate(p, p.kind); self:UpdatePlate(p) end end
end

---------------------------------------------------------------- samples (preview, Test plates)
--[[ Sample plates: Unit Frames' Sample source fields (name, level, classification, class, reaction, hp, hpMax,
    absorb, marker) plus target, focus, hover, threat, tank, quest, forces, cast (a CastBars sample cast),
    debuffs / buffs ({ icon, count, duration, elapsed, dispel }) and classPowerKind / classPower / classPowerMax. ]]
function M.Samples()
    local icons = UF.SAMPLE_ICONS or {}
    local me = UnitName("player") or "Phoenix"
    local _, class = UnitClass("player")
    return {
        { kind = "enemy", name = L.PREVIEW_MOB_HOSTILE, level = 92, classification = "elite", reaction = 2,
          hp = 1460000, hpMax = 2000000, absorb = 240000, target = true, threat = 3, tank = true, marker = 8,
          forces = "+4", quest = false,
          cast = { kind = "cast", name = L.PREVIEW_SPELL_CAST, icon = icons.bolt, total = 2.5, elapsed = 1.4, kick = 0.6,
                   important = true, target = me },
          debuffs = { { icon = icons.pain, duration = 18, elapsed = 6 }, { icon = icons.flame, count = 3, duration = 12, elapsed = 4 },
                      { icon = icons.bomb, duration = 8, elapsed = 2 } },
          buffs = { { icon = icons.shield, duration = 10, elapsed = 3 } },
          classPowerKind = "ComboPoints", classPower = 3, classPowerMax = 5 },
        { kind = "enemy", name = L.PREVIEW_MOB_NEUTRAL, level = 90, classification = "rare", reaction = 4,
          hp = 260000, hpMax = 1500000, threat = 1, quest = true, focus = true, marker = 2,
          cast = { kind = "channel", name = L.PREVIEW_SPELL_CHANNEL, icon = icons.storm, total = 3, elapsed = 1, locked = true },
          debuffs = { { icon = icons.pain, duration = 18, elapsed = 12 } } },
        { kind = "friendly", name = me, level = 90, class = class, reaction = 5, hp = 400000, hpMax = 520000, hover = true,
          guild = "Phoenix" },
        { kind = "friendly", name = L.PREVIEW_MOB_FRIENDLY, level = 90, reaction = 5, hp = 300000, hpMax = 300000,
          title = L.PREVIEW_NPC_TITLE },
    }
end

function M:DrawSample(p, sample)
    p.sample = sample
    p.unit = nil
    if p.kind ~= sample.kind or not p.layoutDone then self:LayoutPlate(p, sample.kind) end
    self:UpdatePlate(p)
end

---------------------------------------------------------------- Test plates
function M:ShowPhoenixTest(show)
    if not show then
        if self.testHolder then
            for _, p in ipairs(self.testPlates or {}) do CB:StopSample(p.Cast); p:Hide() end
            self.testHolder:Hide()
        end
        return true
    end
    if not self.testHolder then
        local holder = CreateFrame("Frame", "PhoenixUI_NamePlateTest", UIParent)
        holder:SetSize(600, 120)
        holder:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
        holder:SetFrameStrata("MEDIUM")
        holder:EnableMouse(false)
        self.testHolder = holder
        self.testPlates = {}
        local n = #M.Samples()
        for i = 1, n do
            local p = self:BuildPlate(holder, { sample = true })
            p:SetPoint("CENTER", holder, "CENTER", (i - (n + 1) / 2) * 200, 0)
            self.testPlates[i] = p
        end
    end
    self.testHolder:Show()
    for i, sample in ipairs(M.Samples()) do
        local p = self.testPlates[i]
        p:Show()
        self:DrawSample(p, sample)
    end
    return true
end
