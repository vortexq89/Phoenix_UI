local _, ns = ...
local L = ns.L
local Theme, Skin, W, U = ns.Theme, ns.Skin, ns.Widgets, ns.Util
local M = ns:GetModule("MythicPlus")

--[[ Mythic+ timer overlay: key and affixes, run clock against the +1/+2/+3 limits, deaths and the
    time they cost, boss splits and enemy forces. Every source is plain, non-secret run data
    (ChallengeModeInfoDocumentation, ScenarioInfoDocumentation, GetWorldElapsedTime), the same
    calls Blizzard_ScenarioObjectiveTracker uses; nothing here reads combat data. The frame is a
    Phoenix Edit Mode frame and shows a sample run while Edit Mode is open so it can be placed.
    S16: width, bar texture / fill / smoothing / shade, chest colours, clock and objective fonts, affix icons
    with tooltips and a per-player death log (party deaths seen through UnitIsDeadOrGhost on UNIT_HEALTH,
    skipped when that is secret). The options preview draws this same frame (M:BuildTimerPreview). ]]
local PAD, ROW, BAR_H, FORCES_H, AFFIX = 12, 20, 6, 4, 18
local CHEST = { { tier = 3, fraction = 0.6 }, { tier = 2, fraction = 0.8 }, { tier = 1, fraction = 1 } }
local INTERP = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
-- sample affix art for the Edit Mode / preview run (stock icons)
local SAMPLE_AFFIX_ICONS = { "Interface\\Icons\\Spell_Fire_SelfDestruct", "Interface\\Icons\\Spell_Shadow_ShadowWordPain" }
local TICK = 0.25

local Secret = ns.Secret
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
                state.forces.at, state.forces.key = splits.forces, "forces"
            else
                local key = tostring(info.criteriaID)
                if info.completed and not splits[key] then splits[key] = state.elapsed end
                state.bosses[#state.bosses + 1] = { name = info.description, done = info.completed, at = splits[key], key = key }
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
    local affixes, icons = {}, {}
    for _, id in ipairs(affixIDs or {}) do
        local affixName, desc, fileID = C_ChallengeMode.GetAffixInfo(id)
        if affixName then
            affixes[#affixes + 1] = affixName
            icons[#icons + 1] = { name = affixName, desc = desc, icon = fileID }
        end
    end
    local deaths, timeLost = C_ChallengeMode.GetDeathCount()
    run = {
        mapID = mapID, name = name, level = level, limit = limit, affixes = affixes, affixIcons = icons,
        deathsBy = M.global.run.deathsBy,
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
    if info.onTime and (not best[key] or run.elapsed < best[key]) then
        best[key] = run.elapsed
        -- the splits of the fastest timed run are what later runs are compared against
        local copy = {}
        for k, v in pairs(M.global.run.splits or {}) do copy[k] = v end
        M.global.bestSplits[key] = copy
    end
end

---------------------------------------------------------------- pull preview (roadmap S2)
-- Enemy forces of every hostile nameplate in combat, summed. GetUnitCriteriaProgressValues can be
-- secret: one secret value (or a secret combat flag) and the whole sum is dropped, silently.
local plateUnits = {}

local function pullCount()
    local sum = 0
    for unit in pairs(plateUnits) do
        local fighting = UnitAffectingCombat(unit)
        local hostile = UnitCanAttack("player", unit)
        if Secret.IsSecret(fighting) or Secret.IsSecret(hostile) then return nil end
        if fighting and hostile then
            local count = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
            if Secret.IsSecret(count) then return nil end
            if type(count) == "number" then sum = sum + count end
        end
    end
    return sum
end

-- Percentage the current pull adds, or nil when it cannot (or need not) be shown.
local function pullPercent(forces)
    if not (M.db.timerPull and forces and not forces.done and forces.total and forces.total > 0) then return nil end
    if not InCombatLockdown() then return nil end
    local sum = pullCount()
    if not sum or sum <= 0 then return nil end
    return sum / forces.total * 100
end
M.PullCount = pullCount -- exposed for the smoke harness

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
    return r
end

-- Objective rows: the "lines" font spec (colour stays the row's state colour).
local function styleLine(r)
    local spec = M.db.lines
    Skin:TextSpec(r.label, spec, "body")
    Skin:TextSpec(r.value, spec, "number")
end

local function affixButton(f, i)
    local b = f.affixIcons[i]
    if b then return b end
    b = CreateFrame("Frame", nil, f)
    b:SetSize(AFFIX, AFFIX)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    Skin:Icon(b.tex)
    Skin:Border(b, "border.black")
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self) if self.info then W.ShowTooltip(self, self.info.name, self.info.desc) end end)
    b:SetScript("OnLeave", function() W.HideTooltip() end)
    f.affixIcons[i] = b
    if ns.Art and ns.Art.DressSlot then ns.Art:DressSlot(b, "MythicPlus.affix") end
    return b
end

local function build(parent)
    local f = CreateFrame("Frame", nil, parent or UIParent)
    f:SetSize(M.db.width, 120)
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
    f.affixIcons = {}
    f.deathLog = W.Text(f, "small", "text.secondary")
    f.deathLog:SetPoint("RIGHT", -PAD, 0)
    f.deathLog:SetWordWrap(true)

    f.clock = W.Text(f, "combat", "text.primary")
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
    f.shade = f.bar:CreateTexture(nil, "ARTWORK", nil, 2)
    f.shade:SetTexture(ns.Media.textures.WHITE)
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

    Skin:Register(f, function(self) M:StyleTimer(self) end)
    f:Hide()
    return f
end

-- The look: width, fonts, bar texture / fill / shade, chest columns. Re-run on theme and setting changes.
function M:StyleTimer(f)
    local db = self.db
    local width = db.width
    f:SetWidth(width)
    Skin:Panel(f, "base", { border = "border.subtle", shadow = 10, sheen = 24 })
    Skin:Text(f.level, "number", "accent.primary", 16)
    Skin:Text(f.name, "title", "text.primary", 14)
    Skin:Text(f.deaths, "number", "text.secondary", 12)
    Skin:Text(f.affixes, "small", "text.muted")
    Skin:Text(f.deathLog, "small", "text.secondary")
    Skin:TextSpec(f.clock, db.clock, "combat")
    Skin:TextSpec(f.limit, { font = db.clock.font, size = 14, outline = db.clock.outline, shadow = db.clock.shadow }, "number")
    Skin:Text(f.pb, "small", "text.muted")
    local texture = db.bar.texture ~= "" and ns.Media:Bar(db.bar.texture) or nil
    for _, bar in ipairs({ f.bar, f.forcesBar }) do
        Skin:StatusBar(bar, { border = true, texture = texture })
        bar:SetReverseFill(db.bar.reverse and true or false)
    end
    f.shade:SetAllPoints(f.bar:GetStatusBarTexture())
    local shade = db.bar.shade or 0
    f.shade:SetShown(shade > 0)
    if shade > 0 then f.shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, shade), CreateColor(1, 1, 1, shade * 0.35)) end
    f.forcesBar:SetStatusBarColor(Theme:Color("accent.secondary"))
    for _, t in ipairs(f.ticks) do W.Color(t, "text.primary", 0.7) end
    local inner = width - 2 * PAD
    for i, fs in ipairs(f.chests) do
        fs:SetWidth(inner / 3)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", (i - 1) * inner / 3, -6)
        Skin:Text(fs, "small")
    end
    styleLine(f.forces)
    for _, r in ipairs(f.bosses) do styleLine(r) end
    M.TimerArt(f)
end

-- v9 art (THEME_API §7.04 MythicPlus.*): the bar frame, chest marks, the skull, affix frames and the forces track.
-- With the flat look every piece is hidden again and the skull goes back to its icon.
function M.TimerArt(f)
    local A = ns.Art
    if not (A and A.DressSlot) then return end
    A:DressSlot(f.bar, "MythicPlus.bar")
    if not A:PaintSlot(f.skull, "MythicPlus.deaths", 0.4) then ns.Icons:Apply(f.skull, "deaths", 14) end
    f.chestArt = f.chestArt or {}
    for i, fs in ipairs(f.chests) do
        local t = f.chestArt[i] or f:CreateTexture(nil, "ARTWORK")
        f.chestArt[i] = t
        t:ClearAllPoints()
        t:SetPoint("TOP", fs, "BOTTOM", 0, -2)
        local ok = A:PaintSlot(t, "MythicPlus.chest" .. i, 0.6)
        t:SetShown(ok and M.db.timerChests and true or false)
    end
    f.forcesTrack = f.forcesTrack or f.forcesBar:CreateTexture(nil, "BACKGROUND", nil, -6)
    f.forcesTrack:SetPoint("TOPLEFT", -2, 2)
    f.forcesTrack:SetPoint("BOTTOMRIGHT", 2, -2)
    f.forcesTrack:SetShown(A:PaintSlot(f.forcesTrack, "MythicPlus.forces", 0.5) and true or false)
    for _, b in ipairs(f.affixIcons) do A:DressSlot(b, "MythicPlus.affix") end
end

local function bossLine(f, i)
    local r = f.bosses[i]
    if not r then
        r = line(f)
        styleLine(r)
        f.bosses[i] = r
    end
    return r
end

---------------------------------------------------------------- render
local function chestToken(remaining, isCurrent)
    if remaining <= 0 then return "text.muted" end
    return isCurrent and "accent.primary" or "text.secondary"
end

-- "Name ×2 · Name" from the run's death log
local function deathLogText(by)
    local list = {}
    for name, n in pairs(by or {}) do list[#list + 1] = { name = name, n = n } end
    table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
    local parts = {}
    for _, d in ipairs(list) do parts[#parts + 1] = d.n > 1 and ("%s ×%d"):format(d.name, d.n) or d.name end
    return table.concat(parts, "  ·  ")
end

-- Affix line: icons (with tooltips) or names. Returns the height it takes.
local function renderAffixes(f, state)
    local icons = M.db.timerAffixIcons and state.affixIcons or nil
    local useIcons = icons and #icons > 0
    f.affixes:SetShown(not useIcons)
    for i, b in ipairs(f.affixIcons) do b:SetShown(useIcons and i <= #icons) end
    if not useIcons then
        f.affixes:SetText(table.concat(state.affixes or {}, "  ·  "))
        return f.affixes:GetStringHeight(), f.affixes
    end
    for i, info in ipairs(icons) do
        local b = affixButton(f, i)
        b.info = info
        b.tex:SetTexture(info.icon)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f.level, "BOTTOMLEFT", (i - 1) * (AFFIX + 4), -4)
        b:Show()
    end
    return AFFIX, f.affixIcons[1]
end

local function renderHeader(f, state)
    f.level:SetFormattedText("+%d", state.level or 0)
    f.name:SetText(state.name or "")
    local showDeaths = M.db.timerDeaths and (state.deaths or 0) > 0
    f.deaths:SetShown(showDeaths)
    f.skull:SetShown(showDeaths)
    if showDeaths then f.deaths:SetFormattedText(L.MPLUS_DEATHS_VALUE, state.deaths, state.timeLost) end
    local h, anchor = renderAffixes(f, state)
    local log = M.db.timerDeathLog and showDeaths and deathLogText(state.deathsBy) or ""
    f.deathLog:SetShown(log ~= "")
    f.deathLog:ClearAllPoints()
    f.deathLog:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    f.deathLog:SetPoint("RIGHT", -PAD, 0)
    f.deathLog:SetText(log)
    local below = log ~= "" and f.deathLog or anchor
    f.clock:ClearAllPoints()
    if M.db.clockAlign == "CENTER" then
        local inner = M.db.width - 2 * PAD
        local w = (tonumber(f.clock:GetStringWidth()) or 0) + (tonumber(f.limit:GetStringWidth()) or 0) + 6
        f.clock:SetPoint("TOPLEFT", below, "BOTTOMLEFT", math.max(0, (inner - w) / 2), -8)
    else
        f.clock:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
    end
    return h + (log ~= "" and (4 + f.deathLog:GetStringHeight()) or 0)
end

-- The bar colour for where the run stands: +3 / +2 / in time / over.
local function barColor(elapsed, limit)
    if elapsed > limit then return M:ColorOf("over", "state.danger") end
    if elapsed <= limit * CHEST[1].fraction then return M:ColorOf("plus3", "accent.primary") end
    if elapsed <= limit * CHEST[2].fraction then return M:ColorOf("plus2", "accent.secondary") end
    return M:ColorOf("onTime", "state.warning")
end

local function renderClock(f, state, elapsed, limit)
    f.clock:SetText(U.FormatClock(elapsed))
    f.limit:SetText("/ " .. U.FormatClock(limit))
    local over = elapsed > limit
    if type(M.db.clock.color) == "table" and not over then
        f.clock:SetTextColor(Skin:SpecColor(M.db.clock.color))
    else
        f.clock:SetTextColor(Theme:Color(over and "state.danger" or (state.finished and "state.success" or "text.primary")))
    end

    local best = state.best or (state.mapID and M.global.best[bestKey(state)])
    f.pb:SetShown(M.db.timerBest and best ~= nil)
    if best then f.pb:SetFormattedText(L.MPLUS_BEST, U.FormatClock(best)) end

    local value = math.min(1, elapsed / limit)
    if M.db.bar.smooth and INTERP and not state.sampleRun then f.bar:SetValue(value, INTERP) else f.bar:SetValue(value) end
    f.bar:SetStatusBarColor(barColor(elapsed, limit))
    local width = M.db.width - 2 * PAD -- the bar spans the frame's inner width
    local chests = M.db.timerChests
    for i = 1, 2 do
        local t = f.ticks[i]
        t:SetShown(chests)
        t:ClearAllPoints()
        t:SetPoint("TOP"); t:SetPoint("BOTTOM")
        local x = width * CHEST[i].fraction
        t:SetPoint("LEFT", f.bar, "LEFT", M.db.bar.reverse and (width - x) or x, 0)
    end

    local current
    for i, c in ipairs(CHEST) do
        local remaining = limit * c.fraction - elapsed
        if not current and remaining > 0 then current = i end
        local fs = f.chests[i]
        fs:SetShown(chests)
        fs:SetFormattedText("+%d  %s", c.tier, remaining > 0 and U.FormatClock(remaining) or "—")
        fs:SetTextColor(Theme:Color(chestToken(remaining, current == i)))
    end
end

-- Each body row returns the new anchor, the gap below it and the height it added.
-- "+0:12" behind / "-0:12" ahead of the best run, coloured, or "" without a best split.
local function delta(at, bestAt)
    if not (M.db.timerSplits and at and bestAt) then return "" end
    local d = at - bestAt
    local token = d <= 0 and "state.success" or "state.danger"
    return ("  |cff%s%s%s|r"):format(U.Hex(Theme:Color(token)), d <= 0 and "-" or "+", U.FormatClock(math.abs(d)))
end

local function bestSplitsOf(state)
    if state.bestSplits then return state.bestSplits end
    return state.mapID and M.global.bestSplits[bestKey(state)] or nil
end

local function renderForces(f, forces, anchor, y, best)
    local show = M.db.timerForces and forces ~= nil
    f.forces:SetShown(show)
    if not show then return anchor, y, 0 end
    f.forces:ClearAllPoints()
    f.forces:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
    f.forces:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f.forces.label:SetText(L.MPLUS_FORCES)
    if forces.done and forces.at then
        f.forces.value:SetText(("100%%  %s"):format(U.FormatClock(forces.at)) .. delta(forces.at, best and best.forces))
    else
        local pull = forces.pull or pullPercent(forces)
        local extra = pull and ("  |cff%s+%.2f%%|r"):format(U.Hex(Theme:Color("accent.secondary")), pull) or ""
        f.forces.value:SetText(("%.2f%%"):format(forces.pct) .. extra)
    end
    f.forces.value:SetTextColor(Theme:Color(forces.done and "state.success" or "text.primary"))
    f.forcesBar:SetValue(forces.pct)
    return f.forces, -(FORCES_H + 6), -y + ROW + FORCES_H
end

local function renderBoss(f, i, boss, anchor, y, best)
    local r = bossLine(f, i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
    r:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    r.label:SetText(boss.name)
    r.label:SetTextColor(Theme:Color(boss.done and "text.secondary" or "text.primary"))
    local bestAt = best and boss.key and best[boss.key]
    if boss.at then
        r.value:SetText(U.FormatClock(boss.at) .. delta(boss.at, bestAt))
    elseif boss.done then
        r.value:SetText(L.MPLUS_DONE)
    else
        -- still to kill: the time to beat, muted
        r.value:SetText((M.db.timerSplits and bestAt) and U.FormatClock(bestAt) or "")
    end
    r.value:SetTextColor(Theme:Color(boss.done and "state.success" or (boss.at and "text.secondary" or "text.muted")))
    ns.Icons:Tint(r.icon, boss.done and "state.success" or "text.muted")
    r:Show()
    return r, 0, -y + ROW
end

local function render(f, state)
    local elapsed, limit = elapsedOf(state), state.limit or 1
    local headerH = renderHeader(f, state)
    renderClock(f, state, elapsed, limit)

    -- Height from the known row metrics: rect queries are not resolved until the next layout pass.
    local chests = M.db.timerChests
    local height = PAD + f.level:GetStringHeight() + 4 + headerH + 8 + f.clock:GetStringHeight()
        + 8 + BAR_H + (chests and (6 + f.chests[1]:GetStringHeight()) or 0)
    local best = bestSplitsOf(state)
    local anchor, y, added = renderForces(f, state.forces, chests and f.chests[1] or f.bar, -10, best)
    height = height + added

    local shown = 0
    if M.db.timerBosses then
        for i, boss in ipairs(state.bosses or {}) do
            anchor, y, added = renderBoss(f, i, boss, anchor, y, best)
            height, shown = height + added, i
        end
    end
    for i = shown + 1, #f.bosses do f.bosses[i]:Hide() end
    f:SetHeight(math.floor(height + PAD + 0.5))
end

local function sampleRun()
    if sample then
        sample.syncedAt = GetTime()
        return sample
    end
    sample = {
        name = L.MPLUS_SAMPLE_DUNGEON, level = 12, limit = 1980, elapsed = 1104, syncedAt = GetTime(),
        affixes = { L.MPLUS_SAMPLE_AFFIX1, L.MPLUS_SAMPLE_AFFIX2 }, deaths = 3, timeLost = 15, best = 1712,
        affixIcons = {
            { name = L.MPLUS_SAMPLE_AFFIX1, desc = L.MPLUS_SAMPLE_AFFIX_DESC, icon = SAMPLE_AFFIX_ICONS[1] },
            { name = L.MPLUS_SAMPLE_AFFIX2, desc = L.MPLUS_SAMPLE_AFFIX_DESC, icon = SAMPLE_AFFIX_ICONS[2] },
        },
        deathsBy = { [L.PREVIEW_PARTY_TANK] = 2, [L.PREVIEW_PARTY_DPS1] = 1 }, sampleRun = true,
        forces = { pct = 72.4, pull = 4.1 },
        bosses = {
            { name = L.MPLUS_SAMPLE_BOSS1, done = true, at = 402, key = "b1" },
            { name = L.MPLUS_SAMPLE_BOSS2, done = true, at = 931, key = "b2" },
            { name = L.MPLUS_SAMPLE_BOSS3, done = false, key = "b3" },
        },
        bestSplits = { b1 = 415, b2 = 902, b3 = 1490, forces = 1320 },
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
    render(T, state)
end

function M:BuildTimer()
    if T then return T end
    T = build()
    T:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < TICK then return end
        acc = 0
        local state = current()
        if state and not state.finished then render(T, state) end
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
    ns.Events:On("NAME_PLATE_UNIT_ADDED", events, function(_, _, unit) plateUnits[unit] = true end)
    ns.Events:On("NAME_PLATE_UNIT_REMOVED", events, function(_, _, unit) plateUnits[unit] = nil end)
    ns.Events:On("UNIT_HEALTH", events, function(_, _, unit) M.NoteDeath(unit) end)
    refresh()
end

function M:DisableTimer()
    ns.Events:OffAll(events)
    if T then T:Hide() end
end

function M:RefreshTimer()
    if T then M:StyleTimer(T) end
    update()
end

---------------------------------------------------------------- death log
-- Party deaths in the running key, by name. Dead is a plain unit state; a secret answer is skipped.
local GROUP = { player = true, party1 = true, party2 = true, party3 = true, party4 = true }
local dead = {}
function M.NoteDeath(unit)
    if not (GROUP[unit] and run and not run.finished and M.db.timerDeathLog) then return end
    local isDead = UnitIsDeadOrGhost(unit)
    if Secret.IsSecret(isDead) then return end
    local name = UnitName(unit)
    if not name or Secret.IsSecret(name) then return end
    if isDead and not dead[name] then
        local stored = M.global.run
        stored.deathsBy = stored.deathsBy or {}
        stored.deathsBy[name] = (stored.deathsBy[name] or 0) + 1
        run.deathsBy = stored.deathsBy
    end
    dead[name] = isDead or nil
end

---------------------------------------------------------------- options preview
-- The settings preview: a second timer frame on the preview stage, painted by the same code with the sample run.
function M:BuildTimerPreview(parent)
    local f = build(parent)
    f:SetFrameStrata(parent:GetFrameStrata())
    f:Show()
    return f, function() M:StyleTimer(f); render(f, sampleRun()) end
end

-- Registered once at load: LibEditMode callbacks cannot be removed. update() checks IsEnabled.
local LEM = LibStub("LibEditMode")
LEM:RegisterCallback("enter", function() editing = true; update() end)
LEM:RegisterCallback("exit", function() editing = false; update() end)
