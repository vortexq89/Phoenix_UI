local _, ns = ...
local M = ns.modules.CastBars
local plain = M.plain

--[[ Cast drawing. A bar shows one unit's cast from its START event (or a re-read when the unit changes) until its
    STOP/INTERRUPTED/CHANNEL_STOP/EMPOWER_STOP, then holds the end state for `hold` seconds and fades.

    The cast is read with UnitCastingInfo / UnitChannelInfo. "Is there a cast" is the NeverSecret isTradeskill
    field (nil when nothing is cast); castBarID (NeverSecret) matches the end events to the cast on show. Everything
    else (name, icon, times, notInterruptible, spellID) may be secret and only reaches sinks:
      progress     StatusBar:SetTimerDuration(duration object)       name/icon   SetText / SetTexture
      colour       Texture:SetVertexColorFromBoolean(notInterruptible, locked, normal)
      shield/glow  Region:SetAlphaFromBoolean(flag)                  timer text  DurationTextBinding (secret) or
      kick tick    StatusBar:SetMinMaxValues/SetValue(secret times)              our formatter (plain)
    Sample casts (preview, Test casts) are plain tables drawn the same way without the game. ]]

local Enum_ = Enum or {}
local TIMER = Enum_.StatusBarTimerDirection or {}
local INTERP = Enum_.StatusBarInterpolation or {}
local TEXT_PROP = Enum_.DurationTextBindingProperty or {}
local THROTTLE = 0.05

---------------------------------------------------------------- reading the game
-- -> kind ("cast" | "channel" | "empower"), text, icon, notInterruptible, spellID, castBarID, numStages, startMs, endMs
local function readCast(unit)
    local ok, _, text, icon, startMs, endMs, trade, _, notInt, spellID, castBarID = pcall(UnitCastingInfo, unit)
    if ok and trade ~= nil then return "cast", text, icon, notInt, spellID, castBarID, nil, startMs, endMs end
    local ok2, _, ctext, cicon, cstart, cend, ctrade, cnotInt, cspell, empowered, stages, cbar = pcall(UnitChannelInfo, unit)
    if ok2 and ctrade ~= nil then
        local isEmpower = plain(empowered) and empowered and true or false
        return isEmpower and "empower" or "channel", ctext, cicon, cnotInt, cspell, cbar, stages, cstart, cend
    end
    return nil
end
M.ReadCast = readCast

local function durationOf(kind, unit)
    local fn
    if kind == "cast" then fn = UnitCastingDuration
    elseif kind == "empower" then fn = UnitEmpoweredChannelDuration
    else fn = UnitChannelDuration end
    if not fn then return nil end
    local ok, d
    if kind == "empower" then ok, d = pcall(fn, unit, true) else ok, d = pcall(fn, unit) end
    return ok and d or nil
end

-- a plain boolean from a nilable flag, or the flag itself when secret (for the *FromBoolean APIs)
local function flag(v)
    if plain(v) then return v and true or false end
    return v
end

local function isSecretDuration(d)
    if not d or not d.HasSecretValues then return true end
    local ok, s = pcall(d.HasSecretValues, d)
    return not ok or s ~= false
end

---------------------------------------------------------------- timer text
local formatters = {}
-- A NumericRuleFormatter showing seconds with `decimals` places (DurationTextBinding needs one for secret times).
local function formatter(decimals)
    if formatters[decimals] ~= nil then return formatters[decimals] or nil end
    formatters[decimals] = false
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
    local ok, fmt = pcall(function()
        local f = C_StringUtil.CreateNumericRuleFormatter()
        f:SetBreakpoints({ { threshold = 0, format = "%." .. decimals .. "f" } })
        return f
    end)
    if ok and fmt then formatters[decimals] = fmt end
    return formatters[decimals] or nil
end

local BOTH = { both = true, elapsedTotal = true }
-- Binds the timer text to a secret duration: the game formats it, our code never sees the number.
local function bindTime(f, d, b)
    if not (C_DurationUtil and C_DurationUtil.CreateDurationTextBinding) then return false end
    local fmt = formatter(math.max(0, math.min(2, b.decimals or 1)))
    if not fmt then return false end
    local ok = pcall(function()
        local bind = f.binding or C_DurationUtil.CreateDurationTextBinding()
        f.binding = bind
        bind:SetFontString(f.Time)
        local first = (b.timeFormat == "elapsed" or b.timeFormat == "elapsedTotal") and TEXT_PROP.ElapsedDuration
            or TEXT_PROP.RemainingDuration
        if BOTH[b.timeFormat] then
            bind:SetTextFormat("{} / {}", { { property = first, formatter = fmt },
                { property = TEXT_PROP.TotalDuration, formatter = fmt } })
        else
            bind:SetTextFormat("{}", { { property = first, formatter = fmt } })
        end
        bind:SetDuration(d)
        bind:SetUpdateInterval(THROTTLE)
        bind:SetEnabled(true)
    end)
    return ok
end

local function unbindTime(f)
    if f.binding then pcall(f.binding.SetEnabled, f.binding, false) end
end

-- Timer text for plain numbers (also the sample path).
local function plainTime(f, b, remaining, total)
    if b.timeFormat == "none" or b.time.show == false then f.Time:SetText(""); return end
    f.Time:SetText(M.FormatTime(b.timeFormat, b.decimals, remaining, total))
end

---------------------------------------------------------------- colours
local function fill(f) return f.Bar:GetStatusBarTexture() end

local function setColor(f, r, g, b, a) fill(f):SetVertexColor(r, g, b, a or 1) end

-- Normal colour of the shown cast, before the interrupt flag.
local function baseState(f) return f.kind == "channel" and "channel" or "cast" end

-- Colours the fill for the interrupt flag (and, for enemies, whether our interrupt is ready).
local function paint(f, ready)
    local key = f.key
    local base = M:StateColorObject(key, baseState(f))
    if ready ~= nil and f.kickOn then
        if plain(ready) then
            if not ready then base = M:StateColorObject(key, "notReady") end
        elseif C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean then
            local ok, c = pcall(C_CurveUtil.EvaluateColorFromBoolean, ready, base, M:StateColorObject(key, "notReady"))
            if ok and c then base = c end
        end
    end
    -- important casts (C_Spell.IsSpellImportant, may be secret) take their own fill colour
    if f.importantOn and f.isImportant ~= nil then
        local imp = M:StateColorObject(key, "important")
        if plain(f.isImportant) then
            if f.isImportant then base = imp end
        elseif C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean then
            local ok, c = pcall(C_CurveUtil.EvaluateColorFromBoolean, f.isImportant, imp, base)
            if ok and c then base = c end
        end
    end
    local ni = f.notInterruptible
    if ns.Art and ns.Art.CastLock then ns.Art:CastLock(f.Bar, ni) end
    if plain(ni) then
        if ni then setColor(f, M:StateColor(key, "locked")) else setColor(f, base:GetRGBA()) end
        f.Shield:SetShown(ni and f.showShield or false)
        f.Shield:SetAlpha(1)
        return
    end
    local tex = fill(f)
    if tex.SetVertexColorFromBoolean then
        tex:SetVertexColorFromBoolean(ni, M:StateColorObject(key, "locked"), base)
    else
        setColor(f, base:GetRGBA())
    end
    f.Shield:SetShown(f.showShield)
    if f.Shield.SetAlphaFromBoolean then f.Shield:SetAlphaFromBoolean(ni, 1, 0) end
end
M.Paint = paint

---------------------------------------------------------------- kick-ready tick
local function kickUpdate(f)
    local id = M:KickSpell()
    local k = f.Kick
    if not (id and f.duration and C_Spell and C_Spell.GetSpellCooldownDuration) then k:Hide(); return end
    local ok, icd = pcall(C_Spell.GetSpellCooldownDuration, id, true)
    if not ok or not icd then k:Hide(); return end
    local ok2 = pcall(function()
        k:SetMinMaxValues(0, f.duration:GetRemainingDuration())
        k:SetValue(icd:GetRemainingDuration())
        local ready = icd:IsZero()
        k.ready:SetAlphaFromBoolean(ready, 0, 1)
        k:SetAlphaFromBoolean(f.notInterruptible, 0, 1)
        paint(f, ready)
    end)
    k:SetShown(ok2)
end

---------------------------------------------------------------- extras (player data is plain)
local function showTicks(f, spellID)
    if f.key == "player" and f.kind == "channel" and M.db.ticks then
        M:Marks(f, f.Ticks, M.TickOffsets(M:TickCount(spellID), f.barW or 100), "tick", 0.6)
    else
        M:Marks(f, f.Ticks, {}, "tick")
    end
    if f.kind == "empower" and M.db.empower and UnitEmpoweredStagePercentages then
        local ok, pct = pcall(UnitEmpoweredStagePercentages, f.unit, true)
        M:Marks(f, f.Stages, ok and M.StageOffsets(pct, f.barW or 100) or {}, "stage", 0.9)
    else
        M:Marks(f, f.Stages, {}, "stage")
    end
end

local function showLatency(f, d)
    if f.key ~= "player" or not M.db.latency or f.kind == "empower" then f.Latency:Hide(); return end
    if isSecretDuration(d) then f.Latency:Hide(); return end
    local _, _, _, world = GetNetStats()
    M:ShowLatency(f, M.LatencyShare(plain(world) and world or 0, d:GetTotalDuration()), f.kind == "channel")
end

local function showTarget(f, b)
    if not (b.target.show and f.unit and UnitSpellTargetName) then f.Target:SetText(""); return end
    local okS, should = pcall(UnitShouldDisplaySpellTargetName, f.unit)
    if okS and plain(should) and not should then f.Target:SetText(""); return end
    local ok, name = pcall(UnitSpellTargetName, f.unit)
    f.Target:SetText(ok and name or "")
    local okC, class = pcall(UnitSpellTargetClass, f.unit)
    if okC and plain(class) and type(class) == "string" then
        f.Target:SetTextColor(ns.Util.ClassColor(class))
    end
end

local function showGlow(f, b, spellID)
    local g = f.Glow
    local want = f.key ~= "player" and (b.important or b.targeted)
    g:SetShown(want and true or false)
    if not want then return end
    g.important:SetShown(b.important)
    g.targeted:SetShown(b.targeted)
    if b.important and C_Spell and C_Spell.IsSpellImportant then
        local ok, yes = pcall(C_Spell.IsSpellImportant, spellID)
        if ok then g.important:SetAlphaFromBoolean(flag(yes), 1, 0) else g.important:Hide() end
    end
    if b.targeted and PlayerIsSpellTarget then
        local ok, yes = pcall(PlayerIsSpellTarget, f.unit)
        if ok then g.targeted:SetAlphaFromBoolean(flag(yes), 1, 0) else g.targeted:Hide() end
    end
end

---------------------------------------------------------------- show / end
local function resetLook(f)
    f.State:Hide()
    fill(f):SetAlpha(1)
    f.Spark:SetShown(f.sparkOn)
    f.hideAt, f.fadeFrom = nil, nil
    f:SetAlpha(1)
end

local function startTimer(f, d, kind, b)
    local bar = f.Bar
    f.plainStart, f.plainTotal = nil, nil
    if d and bar.SetTimerDuration then
        local dir = kind == "channel" and TIMER.RemainingTime or TIMER.ElapsedTime
        local interp = b.smooth and INTERP.ExponentialEaseOut or INTERP.Immediate
        if pcall(bar.SetTimerDuration, bar, d, interp, dir) then return true end
    end
    return false
end

-- (Re)draws the unit's current cast; hides the bar when nothing is cast (unless it is holding an end state).
function M:ShowCast(f, keepHold)
    local unit = f.unit
    if not unit or f.sample then return end
    local kind, text, icon, notInt, spellID, castBarID, _, startMs, endMs = readCast(unit)
    if not kind then
        if not keepHold or not f.hideAt then f.active = nil; unbindTime(f); f:Hide() end
        return
    end
    local b = self:Bar(f.key)
    f.kind, f.active, f.castBarID, f.spellID = kind, true, castBarID, spellID
    f.notInterruptible = flag(notInt)
    resetLook(f)
    local d = durationOf(kind, unit)
    f.duration = d
    if not startTimer(f, d, kind, b) and plain(startMs) and plain(endMs) and startMs and endMs then
        f.plainStart, f.plainTotal = startMs / 1000, (endMs - startMs) / 1000
        f.Bar:SetMinMaxValues(0, math.max(0.001, f.plainTotal))
    end
    f.Name:SetText(M.CutName(text, b.nameLength))
    f.Icon.tex:SetTexture(icon)
    f.showShield = b.shield and b.icon ~= "off"
    f.kickOn = b.kick and f.key ~= "player" and M:KickSpell() ~= nil
    f.importantOn, f.isImportant = b.importantFill and f.key ~= "player", nil
    if f.importantOn and C_Spell and C_Spell.IsSpellImportant then
        local ok, yes = pcall(C_Spell.IsSpellImportant, spellID)
        if ok then f.isImportant = flag(yes) end
    end
    paint(f)
    f.secretTime = isSecretDuration(d)
    unbindTime(f)
    if f.secretTime and d and b.timeFormat ~= "none" and b.time.show ~= false then
        if not bindTime(f, d, b) then f.Time:SetText("") end
    end
    showTicks(f, spellID)
    showLatency(f, d)
    showTarget(f, b)
    showGlow(f, b, spellID)
    if f.kickOn then self:LayoutKick(f, kind == "channel"); kickUpdate(f) else f.Kick:Hide() end
    f:Show()
end

-- Ends the shown cast: "interrupted" and "success" flash the bar in their colour; the bar then holds and fades.
function M:EndCast(f, how)
    if f.sample then return end
    local b = self:Bar(f.key)
    f.active = nil
    unbindTime(f)
    f.Kick:Hide()
    f.Glow:Hide()
    f.Latency:Hide()
    if (how == "interrupted" or how == "failed") and b.flash then
        f.State:SetVertexColor(self:StateColor(f.key, "interrupted"))
        f.State:Show()
        fill(f):SetAlpha(0)
        f.Spark:Hide()
        f.Name:SetText(how == "failed" and FAILED or INTERRUPTED)
        f.Time:SetText("")
    elseif how == "success" and b.flash then
        f.State:SetVertexColor(self:StateColor(f.key, "success"))
        f.State:Show()
        fill(f):SetAlpha(0)
        f.Spark:Hide()
    end
    if (b.hold or 0) <= 0 then f:Hide(); return end
    f.hideAt = GetTime() + b.hold
end

---------------------------------------------------------------- events
-- an "interrupted by" GUID that is really there (plain, non-empty)
local function cut(v) return plain(v) and type(v) == "string" and v ~= "" end

local function matches(f, castBarID)
    if not f.active then return false end
    if castBarID == nil or f.castBarID == nil then return true end
    return castBarID == f.castBarID
end

local HANDLERS = {
    UNIT_SPELLCAST_START = function(f) M:ShowCast(f) end,
    UNIT_SPELLCAST_CHANNEL_START = function(f) M:ShowCast(f) end,
    UNIT_SPELLCAST_EMPOWER_START = function(f) M:ShowCast(f) end,
    UNIT_SPELLCAST_DELAYED = function(f) M:ShowCast(f, true) end,
    UNIT_SPELLCAST_CHANNEL_UPDATE = function(f) M:ShowCast(f, true) end,
    UNIT_SPELLCAST_EMPOWER_UPDATE = function(f) M:ShowCast(f, true) end,
    UNIT_SPELLCAST_INTERRUPTIBLE = function(f) if f.active then f.notInterruptible = false; paint(f) end end,
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function(f) if f.active then f.notInterruptible = true; paint(f) end end,
    UNIT_SPELLCAST_SUCCEEDED = function(f, _, _, _, castBarID)
        if matches(f, castBarID) and f.kind == "cast" then f.succeeded = true end
    end,
    UNIT_SPELLCAST_STOP = function(f, _, _, _, castBarID)
        if matches(f, castBarID) and f.kind == "cast" then
            local ok = f.succeeded
            f.succeeded = nil
            M:EndCast(f, ok and "success" or "stop")
        end
    end,
    UNIT_SPELLCAST_FAILED = function(f, _, _, _, castBarID)
        if f.active and f.kind == "cast" and castBarID ~= nil and castBarID == f.castBarID then M:EndCast(f, "failed") end
    end,
    UNIT_SPELLCAST_INTERRUPTED = function(f, _, _, _, _, castBarID)
        if matches(f, castBarID) then M:EndCast(f, "interrupted") end
    end,
    UNIT_SPELLCAST_CHANNEL_STOP = function(f, _, _, _, interruptedBy, castBarID)
        if matches(f, castBarID) and f.kind ~= "cast" then
            M:EndCast(f, cut(interruptedBy) and "interrupted" or "stop")
        end
    end,
    UNIT_SPELLCAST_EMPOWER_STOP = function(f, _, _, _, complete, interruptedBy, castBarID)
        if matches(f, castBarID) then
            local done = plain(complete) and complete
            M:EndCast(f, cut(interruptedBy) and "interrupted" or (done and "success" or "stop"))
        end
    end,
}
M.CAST_EVENTS = {}
for ev in pairs(HANDLERS) do M.CAST_EVENTS[#M.CAST_EVENTS + 1] = ev end
table.sort(M.CAST_EVENTS)

function M:OnCastEvent(f, event, ...)
    local fn = HANDLERS[event]
    if fn and not f.sample then fn(f, ...) end
end

---------------------------------------------------------------- per-frame driver
local function fade(f, now)
    if not f.hideAt then return end
    if now < f.hideAt then return end
    local left = 1 - (now - f.hideAt) / 0.3
    if left <= 0 then
        f.hideAt = nil
        f:SetAlpha(1)
        f:Hide()
        if f.sample and f.sample.loop then M:StartSample(f, f.sample) end
        return
    end
    f:SetAlpha(left)
end

local function plainProgress(f, now)
    local total = f.plainTotal
    local elapsed = math.max(0, math.min(total, now - f.plainStart))
    local remaining = total - elapsed
    f.Bar:SetValue(f.kind == "channel" and remaining or elapsed)
    return remaining, total, elapsed >= total
end

local function onUpdate(f, elapsed)
    local now = GetTime()
    fade(f, now)
    if not f.active then return end
    local b = M:Bar(f.key)
    local remaining, total, done
    if f.plainStart then remaining, total, done = plainProgress(f, now) end
    f.tick = (f.tick or 0) + elapsed
    if f.tick < THROTTLE then return end
    f.tick = 0
    if not remaining and f.duration and not f.secretTime then
        local ok, r, t = pcall(function() return f.duration:GetRemainingDuration(), f.duration:GetTotalDuration() end)
        if ok then remaining, total = r, t end
    end
    if remaining then plainTime(f, b, remaining, total) end
    if f.sample then M:SampleTick(f, remaining, total, done) elseif f.kickOn then kickUpdate(f) end
end
M.OnBarUpdate = onUpdate

---------------------------------------------------------------- sample casts (preview, Test casts)
--[[ s = { kind, name, icon, total, elapsed, locked, kick (share of the time left when our interrupt is ready),
    ticks, stages = { share, … }, latency (share), target, important, ending = "interrupted"|"success",
    loop = bool, frozen = bool } ]]
-- the marks, latency zone, target text and glows a sample asks for
local function sampleExtras(self, f, s, b)
    if f.key == "player" and f.kind == "channel" and self.db.ticks then
        self:Marks(f, f.Ticks, M.TickOffsets(s.ticks or 0, f.barW or 100), "tick", 0.6)
    else
        self:Marks(f, f.Ticks, {}, "tick")
    end
    local stages = (f.kind == "empower" and self.db.empower) and s.stages or nil
    self:Marks(f, f.Stages, stages and M.StageOffsets(stages, f.barW or 100) or {}, "stage", 0.9)
    local lag = f.key == "player" and self.db.latency and f.kind ~= "empower" and s.latency or nil
    self:ShowLatency(f, lag, f.kind == "channel")
    f.Target:SetText(b.target.show and s.target or "")
    f.Target:SetTextColor(ns.Theme:Color("text.secondary"))
    local g = f.Glow
    g:SetShown(f.key ~= "player" and (b.important or b.targeted) and true or false)
    g.important:SetShown(b.important and s.important or false)
    g.targeted:SetShown(b.targeted and s.targeted or false)
end

function M:StartSample(f, s)
    local b = self:Bar(f.key)
    f.sample = s
    f.kind, f.active = s.kind or "cast", true
    f.notInterruptible = s.locked and true or false
    resetLook(f)
    unbindTime(f)
    f.duration, f.secretTime = nil, false
    f.plainTotal = s.total or 2.5
    f.plainStart = GetTime() - (s.elapsed or 0)
    f.Bar:SetMinMaxValues(0, f.plainTotal)
    f.Name:SetText(M.CutName(s.name or "", b.nameLength))
    f.Icon.tex:SetTexture(s.icon)
    f.showShield = b.shield and b.icon ~= "off"
    f.kickOn = b.kick and f.key ~= "player" and s.kick ~= nil
    f.importantOn = b.importantFill and f.key ~= "player"
    f.isImportant = s.important and true or false
    paint(f, s.kick == nil or s.kick <= 0)
    sampleExtras(self, f, s, b)
    if f.kickOn then self:LayoutKick(f, f.kind == "channel") end
    f:Show()
    onUpdate(f, THROTTLE)
end

-- the sample's per-tick work: kick tick, ending flash, looping
function M:SampleTick(f, remaining, total, done)
    local s = f.sample
    if f.kickOn and remaining then
        local k = f.Kick
        local kickLeft = math.max(0, (s.kick or 0) * (s.total or 2.5) - (total - remaining))
        k:SetMinMaxValues(0, math.max(0.001, remaining))
        k:SetValue(math.min(remaining, kickLeft))
        k.ready:SetAlpha(kickLeft > 0 and 1 or 0)
        k:SetAlpha(f.notInterruptible and 0 or 1)
        k:Show()
        paint(f, kickLeft <= 0)
    end
    if s.frozen then f.active = false; return end
    if done then
        local how = s.ending or "success"
        f.sample = nil
        self:EndCast(f, how)
        f.sample = s
        f.hideAt = GetTime() + math.max(0.4, self:Bar(f.key).hold or 0.5)
    end
end

function M:StopSample(f)
    if not f.sample then return end
    f.sample, f.active, f.hideAt = nil, nil, nil
    f.Kick:Hide()
    f:SetAlpha(1)
    f:Hide()
end
