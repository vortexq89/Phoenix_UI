local _, ns = ...
local L = ns.L
local Theme, Skin, W, U = ns.Theme, ns.Skin, ns.Widgets, ns.Util
local M = ns:GetModule("MythicPlus")

--[[ Mythic+ timer overlay: key and affixes, run clock against the +1/+2/+3 limits, deaths and the
    time they cost, boss splits and enemy forces. Every source is plain, non-secret run data
    (ChallengeModeInfoDocumentation, ScenarioInfoDocumentation, GetWorldElapsedTime), the same
    calls Blizzard_ScenarioObjectiveTracker uses; nothing here reads combat data. The frame is a
    Phoenix Edit Mode frame and shows a sample run while Edit Mode is open so it can be placed. ]]
local WIDTH, PAD, ROW, BAR_H, FORCES_H = 256, 12, 20, 6, 4
local CHEST = { { tier = 3, fraction = 0.6 }, { tier = 2, fraction = 0.8 }, { tier = 1, fraction = 1 } }
local TICK = 0.25

local T                   -- the overlay frame
local run                 -- live state, see sync()
local sample              -- Edit Mode preview state

---------------------------------------------------------------- run state
local function challengeTimer(...)
    for i = 1, select("#", ...) do
        local id = select(i, ...)
        local _, elapsed, kind = GetWorldElapsedTime(id)
        if kind == Enum.WorldElapsedTimerTypes.ChallengeMode then return id, elapsed end
    end
end

-- Enemy forces: quantity is the 0-100 percentage Blizzard's bar shows; quantityString carries the
-- raw count ("123%"), which gives a finer percentage when it parses.
local function forcesOf(info)
    local raw = tonumber(info.quantityString and info.quantityString:match("^(%d+)"))
    local pct = info.quantity
    if raw and info.totalQuantity > 0 then pct = raw / info.totalQuantity * 100 end
    return { pct = math.min(100, pct), raw = raw, total = info.totalQuantity, done = info.completed }
end

local function readCriteria(state)
    local _, _, numCriteria = C_Scenario.GetStepInfo()
    state.bosses, state.forces = {}, nil
    local splits = M.global.run.splits
    for i = 1, numCriteria or 0 do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info then
            if info.isWeightedProgress then
                state.forces = forcesOf(info)
                if info.completed and not splits.forces then splits.forces = state.elapsed end
                state.forces.at = splits.forces
            else
                local key = tostring(info.criteriaID)
                if info.completed and not splits[key] then splits[key] = state.elapsed end
                state.bosses[#state.bosses + 1] = { name = info.description, done = info.completed, at = splits[key] }
            end
        end
    end
end

local function sync()
    local timerID, elapsed = challengeTimer(GetWorldElapsedTimers())
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    -- A finished run stays on screen (frozen at the completion time) until the group leaves the dungeon.
    if run and run.finished and run.mapID == mapID then return end
    if not (timerID and mapID) then
        run = nil
        return
    end
    local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
    local level, affixIDs = C_ChallengeMode.GetActiveKeystoneInfo()
    local stored = M.global.run
    if stored.mapID ~= mapID or stored.level ~= level or (stored.elapsed or 0) > elapsed then
        M.global.run = { mapID = mapID, level = level, splits = {} }
    end
    M.global.run.elapsed = elapsed
    local affixes = {}
    for _, id in ipairs(affixIDs or {}) do
        local affixName = C_ChallengeMode.GetAffixInfo(id)
        if affixName then affixes[#affixes + 1] = affixName end
    end
    local deaths, timeLost = C_ChallengeMode.GetDeathCount()
    run = {
        mapID = mapID, name = name, level = level, limit = limit, affixes = affixes,
        timerID = timerID, elapsed = elapsed, syncedAt = GetTime(),
        deaths = deaths or 0, timeLost = timeLost or 0,
    }
    readCriteria(run)
end

local function elapsedOf(state)
    if state.finished then return state.elapsed end
    return state.elapsed + (GetTime() - state.syncedAt)
end

local function bestKey(state) return state.mapID .. ":" .. state.level end

local function finish()
    local info = C_ChallengeMode.GetChallengeCompletionInfo()
    if not (run and info and info.time and info.time > 0) then return end
    run.finished, run.elapsed, run.onTime = true, info.time / 1000, info.onTime
    if info.practiceRun then return end
    local best = M.global.best
    local key = bestKey(run)
    if info.onTime and (not best[key] or run.elapsed < best[key]) then best[key] = run.elapsed end
end

---------------------------------------------------------------- frame
local function line(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW)
    r.icon = W.Icon(r, "boss", 14, "text.muted")
    r.icon:SetPoint("LEFT")
    r.label = W.Text(r, "body", "text.primary")
    r.label:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.value = W.Text(r, "number", "text.secondary", "RIGHT")
    r.value:SetPoint("RIGHT")
    r.label:SetPoint("RIGHT", r.value, "LEFT", -8, 0)
    Skin:Register(r, function(self)
        Skin:Text(self.label, "body")
        Skin:Text(self.value, "number")
    end)
    return r
end

local function build()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(WIDTH, 120)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)

    f.level = W.Text(f, "number", "accent.primary")
    f.level:SetPoint("TOPLEFT", PAD, -PAD)
    f.name = W.Text(f, "title", "text.primary")
    f.name:SetPoint("LEFT", f.level, "RIGHT", 8, 0)
    f.deaths = W.Text(f, "number", "text.secondary", "RIGHT")
    f.deaths:SetPoint("TOPRIGHT", -PAD, -PAD)
    f.skull = W.Icon(f, "deaths", 14, "state.danger")
    f.skull:SetPoint("RIGHT", f.deaths, "LEFT", -4, 0)
    f.name:SetPoint("RIGHT", f.skull, "LEFT", -8, 0)
    f.affixes = W.Text(f, "small", "text.muted")
    f.affixes:SetPoint("TOPLEFT", f.level, "BOTTOMLEFT", 0, -4)
    f.affixes:SetPoint("RIGHT", -PAD, 0)

    f.clock = W.Text(f, "combat", "text.primary")
    f.clock:SetPoint("TOPLEFT", f.affixes, "BOTTOMLEFT", 0, -8)
    f.limit = W.Text(f, "number", "text.muted")
    f.limit:SetPoint("BOTTOMLEFT", f.clock, "BOTTOMRIGHT", 6, 2)
    f.pb = W.Text(f, "small", "text.muted", "RIGHT")
    f.pb:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f.pb:SetPoint("BOTTOM", f.clock, "BOTTOM", 0, 2)

    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetHeight(BAR_H)
    f.bar:SetPoint("TOPLEFT", f.clock, "BOTTOMLEFT", 0, -8)
    f.bar:SetPoint("RIGHT", -PAD, 0)
    f.bar:SetMinMaxValues(0, 1)
    f.ticks = {}
    for i = 1, 2 do
        local t = W.Texture(f.bar, "OVERLAY")
        t:SetWidth(1)
        t:SetPoint("TOP"); t:SetPoint("BOTTOM")
        f.ticks[i] = t
    end

    f.chests = {}
    for i, c in ipairs(CHEST) do
        local fs = W.Text(f, "small", "text.secondary", i == 1 and "LEFT" or (i == 3 and "RIGHT" or "CENTER"))
        fs:SetWidth((WIDTH - 2 * PAD) / 3)
        fs:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", (i - 1) * (WIDTH - 2 * PAD) / 3, -6)
        fs.tier = c.tier
        f.chests[i] = fs
    end

    f.forces = line(f)
    ns.Icons:Apply(f.forces.icon, "forces", 14)
    f.forcesBar = CreateFrame("StatusBar", nil, f.forces)
    f.forcesBar:SetHeight(FORCES_H)
    f.forcesBar:SetPoint("TOPLEFT", f.forces, "BOTTOMLEFT", 22, 0)
    f.forcesBar:SetPoint("TOPRIGHT", f.forces, "BOTTOMRIGHT")
    f.forcesBar:SetMinMaxValues(0, 100)
    f.bosses = {}

    Skin:Register(f, function(self)
        Skin:Panel(self, "base", { border = "border.subtle", shadow = 10, sheen = 24 })
        Skin:Text(self.level, "number", "accent.primary", 16)
        Skin:Text(self.name, "title", "text.primary", 14)
        Skin:Text(self.deaths, "number", "text.secondary", 12)
        Skin:Text(self.affixes, "small", "text.muted")
        Skin:Text(self.clock, "combat", "text.primary", 28)
        Skin:Text(self.limit, "number", "text.muted", 14)
        Skin:Text(self.pb, "small", "text.muted")
        Skin:StatusBar(self.bar, { border = true })
        Skin:StatusBar(self.forcesBar, { border = true })
        self.forcesBar:SetStatusBarColor(Theme:Color("accent.secondary"))
        for _, t in ipairs(self.ticks) do W.Color(t, "text.primary", 0.7) end
    end)

    f:Hide()
    return f
end

local function bossLine(i)
    local r = T.bosses[i]
    if not r then
        r = line(T)
        T.bosses[i] = r
    end
    return r
end

---------------------------------------------------------------- render
local function chestToken(remaining, isCurrent)
    if remaining <= 0 then return "text.muted" end
    return isCurrent and "accent.primary" or "text.secondary"
end

local function renderHeader(state)
    T.level:SetFormattedText("+%d", state.level or 0)
    T.name:SetText(state.name or "")
    local showDeaths = M.db.timerDeaths and (state.deaths or 0) > 0
    T.deaths:SetShown(showDeaths)
    T.skull:SetShown(showDeaths)
    if showDeaths then T.deaths:SetFormattedText(L.MPLUS_DEATHS_VALUE, state.deaths, state.timeLost) end
    T.affixes:SetText(table.concat(state.affixes or {}, "  ·  "))
end

local function renderClock(state, elapsed, limit)
    T.clock:SetText(U.FormatClock(elapsed))
    T.limit:SetText("/ " .. U.FormatClock(limit))
    local over = elapsed > limit
    T.clock:SetTextColor(Theme:Color(over and "state.danger" or (state.finished and "state.success" or "text.primary")))

    local best = state.best or M.global.best[bestKey(state)]
    T.pb:SetShown(M.db.timerBest and best ~= nil)
    if best then T.pb:SetFormattedText(L.MPLUS_BEST, U.FormatClock(best)) end

    T.bar:SetValue(math.min(1, elapsed / limit))
    T.bar:SetStatusBarColor(Theme:Color(over and "state.danger" or "accent.primary"))
    local width = WIDTH - 2 * PAD -- the bar spans the frame's inner width
    for i = 1, 2 do
        T.ticks[i]:ClearAllPoints()
        T.ticks[i]:SetPoint("TOP"); T.ticks[i]:SetPoint("BOTTOM")
        T.ticks[i]:SetPoint("LEFT", T.bar, "LEFT", width * CHEST[i].fraction, 0)
    end

    local current
    for i, c in ipairs(CHEST) do
        local remaining = limit * c.fraction - elapsed
        if not current and remaining > 0 then current = i end
        local fs = T.chests[i]
        fs:SetFormattedText("+%d  %s", c.tier, remaining > 0 and U.FormatClock(remaining) or "—")
        fs:SetTextColor(Theme:Color(chestToken(remaining, current == i)))
    end
end

-- Each body row returns the new anchor, the gap below it and the height it added.
local function renderForces(forces, anchor, y)
    local show = M.db.timerForces and forces ~= nil
    T.forces:SetShown(show)
    if not show then return anchor, y, 0 end
    T.forces:ClearAllPoints()
    T.forces:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
    T.forces:SetPoint("RIGHT", T, "RIGHT", -PAD, 0)
    T.forces.label:SetText(L.MPLUS_FORCES)
    if forces.done and forces.at then
        T.forces.value:SetFormattedText("100%%  %s", U.FormatClock(forces.at))
    else
        T.forces.value:SetFormattedText("%.2f%%", forces.pct)
    end
    T.forces.value:SetTextColor(Theme:Color(forces.done and "state.success" or "text.primary"))
    T.forcesBar:SetValue(forces.pct)
    return T.forces, -(FORCES_H + 6), -y + ROW + FORCES_H
end

local function renderBoss(i, boss, anchor, y)
    local r = bossLine(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
    r:SetPoint("RIGHT", T, "RIGHT", -PAD, 0)
    r.label:SetText(boss.name)
    r.label:SetTextColor(Theme:Color(boss.done and "text.secondary" or "text.primary"))
    r.value:SetText(boss.at and U.FormatClock(boss.at) or (boss.done and L.MPLUS_DONE or ""))
    r.value:SetTextColor(Theme:Color(boss.done and "state.success" or "text.secondary"))
    ns.Icons:Tint(r.icon, boss.done and "state.success" or "text.muted")
    r:Show()
    return r, 0, -y + ROW
end

local function render(state)
    local elapsed, limit = elapsedOf(state), state.limit or 1
    renderHeader(state)
    renderClock(state, elapsed, limit)

    -- Height from the known row metrics: rect queries are not resolved until the next layout pass.
    local height = PAD + T.level:GetStringHeight() + 4 + T.affixes:GetStringHeight() + 8 + T.clock:GetStringHeight()
        + 8 + BAR_H + 6 + T.chests[1]:GetStringHeight()
    local anchor, y, added = renderForces(state.forces, T.chests[1], -10)
    height = height + added

    local shown = 0
    if M.db.timerBosses then
        for i, boss in ipairs(state.bosses or {}) do
            anchor, y, added = renderBoss(i, boss, anchor, y)
            height, shown = height + added, i
        end
    end
    for i = shown + 1, #T.bosses do T.bosses[i]:Hide() end
    T:SetHeight(math.floor(height + PAD + 0.5))
end

local function sampleRun()
    if sample then
        sample.syncedAt = GetTime()
        return sample
    end
    sample = {
        name = L.MPLUS_SAMPLE_DUNGEON, level = 12, limit = 1980, elapsed = 1104, syncedAt = GetTime(),
        affixes = { L.MPLUS_SAMPLE_AFFIX1, L.MPLUS_SAMPLE_AFFIX2 }, deaths = 3, timeLost = 15, best = 1712,
        forces = { pct = 72.4 },
        bosses = {
            { name = L.MPLUS_SAMPLE_BOSS1, done = true, at = 402 },
            { name = L.MPLUS_SAMPLE_BOSS2, done = true, at = 931 },
            { name = L.MPLUS_SAMPLE_BOSS3, done = false },
        },
    }
    return sample
end

---------------------------------------------------------------- driver
local editing = false
local acc = 0

local function current()
    if editing then return sampleRun() end
    return run
end

local function update()
    local state = current()
    if not (state and M:IsEnabled() and M.db.timer) then
        if T then T:Hide() end
        return
    end
    T = T or M:BuildTimer()
    T:Show()
    render(state)
end

function M:BuildTimer()
    if T then return T end
    T = build()
    T:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < TICK then return end
        acc = 0
        local state = current()
        if state and not state.finished then render(state) end
    end)
    ns.EditMode:Register(T, { key = "MythicPlusTimer", name = ns.title .. " – " .. L.MPLUS_TIMER,
        default = { point = "RIGHT", x = -40, y = 120 } })
    return T
end

local function refresh() sync(); update() end

-- Own event owner: the module object already handles CHALLENGE_MODE_COMPLETED for the key report, and
-- the bus keeps one handler per (event, owner).
local events = {}

function M:EnableTimer()
    self:BuildTimer() -- registered with Edit Mode up front so it can be placed before the first key
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_START", "CHALLENGE_MODE_RESET",
        "WORLD_STATE_TIMER_START", "WORLD_STATE_TIMER_STOP", "SCENARIO_CRITERIA_UPDATE",
        "CHALLENGE_MODE_DEATH_COUNT_UPDATED" }) do
        ns.Events:On(event, events, refresh)
    end
    ns.Events:On("CHALLENGE_MODE_COMPLETED", events, function() sync(); finish(); update() end)
    refresh()
end

function M:DisableTimer()
    ns.Events:OffAll(events)
    if T then T:Hide() end
end

function M:RefreshTimer()
    update()
end

-- Registered once at load: LibEditMode callbacks cannot be removed. update() checks IsEnabled.
local LEM = LibStub("LibEditMode")
LEM:RegisterCallback("enter", function() editing = true; update() end)
LEM:RegisterCallback("exit", function() editing = false; update() end)
