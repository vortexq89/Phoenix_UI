local _, ns = ...
local L, Skin, Media, Theme, Secret = ns.L, ns.Skin, ns.Media, ns.Theme, ns.Secret
local M = ns:GetModule("Encounters")
local LEM = LibStub("LibEditMode")

--[[ Encounter bars: Blizzard's encounter timeline drawn as Phoenix bars, plus the pull and break timers.
    Per event we read only what is never secret (id, source, duration from the event info; time remaining and
    state from C_EncounterTimeline) and do all sorting, filtering and emphasis on those. The spell name and
    icon may be secret: they go straight into SetText / SetTexture and are never compared or stored on disk.
    Pull and break are Phoenix timers in the same stack, so the screen has one timer list, sorted by time.
    Review 28 (BigWigs parity): emphasised bars can move to their own, bigger stack ("Move emphasised bars"),
    bars drain or fill, a spark marks the fill edge, and the countdown voice can count an ability in
    (spellID=count, or every emphasised bar). ]]
local B = {}
M.Bars = B

local STATE = Enum.EncounterTimelineEventState
local TRACK = Enum.EncounterTimelineTrack
local SOURCE_EDITMODE = 2 -- Enum.EncounterTimelineEventSource.EditMode
local THROTTLE = 0.05

local anchor, bigAnchor, timerAnchor
local timerBars = {} -- the pull / break stack's bars (Pull and break bars > Own anchor)
local bars = {}      -- pooled bar frames, bars[i] shows rows[i]
local bigBars = {}   -- the emphasised stack's bars (Move emphasised bars)
local events = {}    -- eventID -> { info = EncounterTimelineEventInfo, duration, label? }
local timers = {}    -- key -> { label, icon, endsAt, total }
local editCount = 0  -- numbering for Blizzard's Edit Mode sample events ("Test 1", "Test 2" …)
local editing = false

---------------------------------------------------------------- bar frames (shared with the options preview)
-- f.bar (StatusBar) holds name and time; f.iconHolder carries the icon and its border.
function M:CreateBar(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.iconHolder = CreateFrame("Frame", nil, f)
    f.icon = f.iconHolder:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    Skin:IconZoom(f.icon, 0.08)
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetMinMaxValues(0, 1)
    f.edge = CreateFrame("Frame", nil, f.bar)
    f.edge:SetAllPoints()
    f.edge:SetFrameLevel(f.bar:GetFrameLevel() + 2)
    f.name = f.edge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.name:SetPoint("LEFT", 6, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.time = f.edge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.time:SetPoint("RIGHT", -6, 0)
    f.time:SetJustifyH("RIGHT")
    f.name:SetPoint("RIGHT", f.time, "LEFT", -6, 0)
    return f
end

-- Bar groups (t202): "bars" the normal stack (timeline.*), "big" the emphasised stack (timeline.big.*),
-- "timers" the pull / break stack (timeline.timerBars.*). Each has its own size, look and anchor.
function M:BarGroup(group)
    local db = self.db.timeline
    if group == "big" or group == true then return db.big end
    if group == "timers" then return db.timerBars end
    return db
end

function M:BarTexture(group)
    local t = self:BarGroup(group).texture
    return t ~= "" and Media:Bar(t) or Theme:Bar()
end

function M:BarColor(emphasized, group)
    local db, g = self.db.timeline, self:BarGroup(group)
    local c
    if g ~= db then c = g.color or (group ~= "timers" and db.emphasizeColor) else c = emphasized and db.emphasizeColor or db.color end
    if type(c) == "table" then return c.r, c.g, c.b end
    return Theme:Color((emphasized or group == "big" or group == true) and "state.danger" or "accent.primary")
end

-- Size, texture, colours, fonts and border of one bar; the preview calls this too. `group`: see BarGroup.
function M:StyleBar(f, emphasized, group)
    local db = self:BarGroup(group)
    local h = db.height
    f:SetSize(db.width, h)
    f.iconHolder:SetSize(h, h)
    f.iconHolder:ClearAllPoints()
    f.iconHolder:SetPoint("LEFT")
    f.iconHolder:SetShown(db.icon)
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", db.icon and (h + 2) or 0, 0)
    f.bar:SetPoint("BOTTOMRIGHT")
    f.bar:SetStatusBarTexture(self:BarTexture(group))
    f.bar:SetStatusBarColor(self:BarColor(emphasized, group))
    Skin:Backdrop(f.bar, db.background, "bg.sunken")
    Skin:BorderSpec(f.edge, db.border, "border.black")
    Skin:BorderSpec(f.iconHolder, db.border, "border.black")
    Skin:TextSpec(f.name, db.name, "unit", "text.primary")
    Skin:TextSpec(f.time, db.time, "number", "text.primary")
    Skin:FillSpark(f.bar, self.db.timeline.spark, false)
end

-- Bar value for `left` of `total`: "drain" empties as the ability comes (the default), "fill" fills up.
function M.BarValue(fill, left, total)
    if fill == "fill" then return math.max(0, (total or 0) - left) end
    return left
end

function M.FormatTime(left)
    if left >= 60 then return ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60)) end
    if left < 10 then return ("%.1f"):format(left) end
    return ("%d"):format(left)
end

---------------------------------------------------------------- data
local function remember(info)
    if type(info) ~= "table" or info.id == nil then return end
    local e = { info = info, duration = info.duration, rule = M.RuleFor(info) }
    if e.rule == "sound" then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
    if info.source == SOURCE_EDITMODE then
        editCount = editCount + 1
        e.label = L.ENC_TEST_EVENT:format(editCount)
    end
    events[info.id] = e
end

-- Per-ability overrides (Encounters > Ability rules): "spellID=hide|emph|sound, …". They apply only when the
-- event's spell ID is a plain number; a secret ID is never compared, so such events keep the defaults.
local ruleCache, ruleText = {}, nil
local RULE = { hide = true, emph = true, sound = true, count = true }
function M.ParseAbilityRules(text)
    local out = {}
    for id, what in tostring(text or ""):gmatch("(%d+)%s*=%s*(%a+)") do
        what = what:lower()
        if RULE[what] then out[tonumber(id)] = what end
    end
    return out
end
local function ruleFor(info)
    local db = M.db.timeline
    if ruleText ~= db.rules then ruleCache, ruleText = M.ParseAbilityRules(db.rules), db.rules end
    local id = info and info.spellID
    if id == nil or Secret.IsSecret(id) or type(id) ~= "number" then return nil end
    M.seenAbilities = M.seenAbilities or {}
    M.seenAbilities[id] = true
    -- your choice on the Boss modules tab, then the typed rules, then Phoenix's data default (Journal.lua)
    local own = type(db.abilities) == "table" and db.abilities[id]
    if own then return own end
    return ruleCache[id] or (M.DataDefault and M.DataDefault(id))
end
M.RuleFor = ruleFor

-- The abilities seen this session (plain IDs only), with names, to copy into the rules.
local seenWin
function M:ShowSeenAbilities()
    local W = ns.Widgets
    if not seenWin then
        seenWin = W:Popup(L.ENC_RULES_SEEN, 420, 380, "encounters")
        seenWin.text = W.Text(seenWin, "body", "text.primary")
        seenWin.text:SetPoint("TOPLEFT", 16, -44); seenWin.text:SetPoint("RIGHT", -16, 0)
        seenWin.text:SetJustifyH("LEFT"); seenWin.text:SetSpacing(3)
    end
    local ids, lines = {}, {}
    for id in pairs(M.seenAbilities or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for i = 1, math.min(#ids, 20) do
        local name = C_Spell.GetSpellName(ids[i])
        lines[i] = ("%d  %s"):format(ids[i], (type(name) == "string" and not Secret.IsSecret(name)) and name or "?")
    end
    seenWin.text:SetText(#lines > 0 and table.concat(lines, "\n") or L.ENC_RULES_NONE)
    seenWin:Show()
    return seenWin, #ids
end

local function query(fn, id)
    local ok, v = pcall(fn, id)
    if ok then return v end
end

-- Rows to draw this frame, soonest first: { key, label|nil, info|nil, icon|nil, left, total, dim }.
-- dim: paused, or blocked (the cast may not happen because its encounter condition is not met).
local rows = {}
local function collect(now)
    wipe(rows)
    local db = M.db.timeline
    if M:Draws("timeline") then
        -- the game's own "hide long / queued countdowns" settings apply to Phoenix's bars too
        local hideLong = C_CVar.GetCVarBool("encounterTimelineHideLongCountdowns")
        local hideQueued = C_CVar.GetCVarBool("encounterTimelineHideQueuedCountdowns")
        for id, e in pairs(events) do
            local state = query(C_EncounterTimeline.GetEventState, id)
            local left = query(C_EncounterTimeline.GetEventTimeRemaining, id)
            local track = query(C_EncounterTimeline.GetEventTrack, id)
            local hidden = track == TRACK.Indeterminate or (hideLong and track == TRACK.Long)
                or (hideQueued and track == TRACK.Queued)
            if e.rule == "hide" then hidden = true end
            if (state == STATE.Active or state == STATE.Paused) and not hidden and type(left) == "number"
                and not Secret.IsSecret(left) and (db.horizon <= 0 or left <= db.horizon) then
                rows[#rows + 1] = { key = id, label = e.label, info = e.info, left = left, total = e.duration,
                    emph = e.rule == "emph" or e.rule == "count", count = e.rule == "count",
                    dim = state == STATE.Paused or query(C_EncounterTimeline.IsEventBlocked, id) == true }
            end
        end
    end
    for key, t in pairs(timers) do
        local left = t.endsAt - now
        if left <= 0 then
            timers[key] = nil
        else
            rows[#rows + 1] = { key = key, label = t.label, icon = t.icon, left = left, total = t.total, timer = true }
        end
    end
    table.sort(rows, function(a, b) return a.left < b.left end)
    return rows
end

---------------------------------------------------------------- drawing
local function barAt(pool, parent, i)
    local f = pool[i]
    if not f then
        f = M:CreateBar(parent)
        pool[i] = f
        f.styled = nil
    end
    return f
end

local function place(f, i, parent, group)
    if f.slot == i and f.slotParent == parent and f.slotBig == group then return end
    f.slot, f.slotParent, f.slotBig = i, parent, group
    local db = M:BarGroup(group)
    local step = (i - 1) * (db.height + db.spacing)
    f:ClearAllPoints()
    if db.grow == "DOWN" then
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -step)
    else
        f:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, step)
    end
end

-- Countdown voice for one ability (spellID=count, or every emphasised bar with "Count down emphasised bars"):
-- the soonest such bar speaks its whole seconds from Countdown from down to 1. Off while the pull voice runs.
local spoken = {} -- key -> last number spoken
local function countIn(list)
    local c = M.db.countdown
    if not c.enabled or M.CountdownRunning() then return end
    for _, r in ipairs(list) do
        if r.count or (c.bars and r.emphasized and r.info) then
            local n = math.ceil(r.left - 0.05)
            if n >= 1 and n <= c.from and spoken[r.key] ~= n then
                spoken[r.key] = n
                local path = Media:Voice(c.voice, n)
                if path then PlaySoundFile(path, "Master") end
            end
            return
        end
    end
end

local function fillBar(f, r, group, emphasized)
    local db = M.db.timeline
    if f.styled ~= emphasized or f.big ~= group then
        M:StyleBar(f, emphasized, group); f.styled, f.big = emphasized, group
    end
    if f.key ~= r.key then
        f.key = r.key
        -- Our own label and icon are plain; the event's spell name and icon may be secret, so they are
        -- handed to the sinks without any test (not even `or`).
        if r.label then f.name:SetText(r.label) elseif r.info then f.name:SetText(r.info.spellName) end
        if r.icon then f.icon:SetTexture(r.icon) elseif r.info then f.icon:SetTexture(r.info.iconFileID) end
    end
    f.bar:SetMinMaxValues(0, r.total > 0 and r.total or 1)
    f.bar:SetValue(M.BarValue(db.fill, r.left, r.total))
    f.time:SetText(r.left > 0.05 and M.FormatTime(r.left) or L.ENC_SOON)
    f:SetAlpha(r.dim and 0.55 or 1)
    f:Show()
end

local small, big, timed = {}, {}, {}
local function drawStack(list, pool, parent, group, n, emphasized)
    for i = 1, n do
        local f = barAt(pool, parent, i)
        fillBar(f, list[i], group, emphasized or list[i].emphasized)
        place(f, i, parent, group)
    end
    for i = n + 1, #pool do pool[i]:Hide(); pool[i].key = nil end
end
local function draw(now)
    local db = M.db.timeline
    local list = collect(now)
    wipe(small); wipe(big); wipe(timed)
    local move = db.emphasizeMove and bigAnchor ~= nil
    local moveTimers = db.timerBars.move and timerAnchor ~= nil
    for _, r in ipairs(list) do
        r.emphasized = r.emph or (db.emphasize and r.left <= db.emphasizeAt)
        if moveTimers and r.timer then timed[#timed + 1] = r
        elseif move and r.emphasized then big[#big + 1] = r
        elseif #small < db.max then small[#small + 1] = r end
    end
    drawStack(small, bars, anchor, "bars", #small)
    local nBig = bigAnchor and math.min(#big, db.big.max) or 0
    if bigAnchor then drawStack(big, bigBars, bigAnchor, "big", nBig, true) end
    local nTimed = timerAnchor and math.min(#timed, db.timerBars.max) or 0
    if timerAnchor then drawStack(timed, timerBars, timerAnchor, "timers", nTimed) end
    if bigAnchor then bigAnchor:SetShown(nBig > 0 or (editing and move)) end
    if timerAnchor then timerAnchor:SetShown(nTimed > 0 or (editing and moveTimers)) end
    countIn(list)
    if not next(events) then wipe(spoken) end
    return #small + nBig + nTimed
end

local elapsed = 0
local function onUpdate(_, dt)
    elapsed = elapsed + dt
    if elapsed < THROTTLE then return end
    elapsed = 0
    if draw(GetTime()) == 0 and not editing then anchor:Hide() end
end

local function wake()
    if not anchor or not M.active then return end
    anchor:Show()
    elapsed = THROTTLE
end

---------------------------------------------------------------- events
local function onAdded(_, _, info)
    remember(info)
    wake()
end

local function onRemoved(_, _, id)
    events[id] = nil
    if not next(events) then editCount = 0 end
end

-- Events already on the timeline when Phoenix starts drawing (a /reload mid-pull).
local function seed()
    for _, id in ipairs(C_EncounterTimeline.GetEventList() or {}) do
        if not events[id] then remember(query(C_EncounterTimeline.GetEventInfo, id)) end
    end
end

---------------------------------------------------------------- timers (pull, break)
function B:StartTimer(key, label, seconds, total, icon)
    timers[key] = { label = label, icon = icon, endsAt = GetTime() + seconds, total = math.max(total or seconds, seconds) }
    wake()
end

function B:StopTimer(key)
    timers[key] = nil
end

function B:HasTimer(key) return timers[key] ~= nil end

---------------------------------------------------------------- lifecycle
local function layoutAnchor()
    local db = M.db.timeline
    anchor:SetSize(db.width, db.height)
    if bigAnchor then bigAnchor:SetSize(db.big.width, db.big.height) end
    if timerAnchor then timerAnchor:SetSize(db.timerBars.width, db.timerBars.height) end
end

-- The pull / break stack (Pull and break bars > Own anchor): its own anchor, in Edit Mode and Layout mode.
local function ensureTimers()
    if timerAnchor or not M.db.timeline.timerBars.move then return end
    timerAnchor = CreateFrame("Frame", "PhoenixEncounterTimerBars", UIParent)
    timerAnchor:SetFrameStrata("MEDIUM")
    timerAnchor:SetClampedToScreen(true)
    timerAnchor:Hide()
    layoutAnchor()
    ns.EditMode:Register(timerAnchor, { key = "EncounterTimerBars", name = ns.title .. " – " .. L.ENC_TIMER_STACK,
        default = { point = "TOP", x = 0, y = -120 },
        active = function() return M.active and M.db.timeline.timerBars.move end,
        preview = function(unlocked) timerAnchor:SetShown(unlocked and M.db.timeline.timerBars.move) end })
end

-- The emphasised stack (Move emphasised bars): its own anchor, in Edit Mode and Layout mode.
local function ensureBig()
    if bigAnchor or not M.db.timeline.emphasizeMove then return end
    bigAnchor = CreateFrame("Frame", "PhoenixEncounterBarsBig", UIParent)
    bigAnchor:SetFrameStrata("MEDIUM")
    bigAnchor:SetClampedToScreen(true)
    bigAnchor:Hide()
    layoutAnchor()
    ns.EditMode:Register(bigAnchor, { key = "EncounterBarsBig", name = ns.title .. " – " .. L.ENC_BIG_STACK,
        default = { point = "CENTER", x = 0, y = 140 },
        active = function() return M.active and M:Draws("timeline") and M.db.timeline.emphasizeMove end,
        preview = function(unlocked) bigAnchor:SetShown(unlocked and M.db.timeline.emphasizeMove) end })
end

function B:Enable()
    if not anchor then
        anchor = CreateFrame("Frame", "PhoenixEncounterBars", UIParent)
        anchor:SetFrameStrata("MEDIUM")
        anchor:SetClampedToScreen(true)
        anchor:Hide()
        anchor:SetScript("OnUpdate", onUpdate)
        ensureBig()
        ensureTimers()
        layoutAnchor()
        ns.EditMode:Register(anchor, { key = "EncounterBars", name = ns.title .. " – " .. L.ENC_TIMELINE,
            default = { point = "CENTER", x = 320, y = 80 },
            active = function() return M.active and M:Draws("timeline") end,
            -- Layout mode: three sample bars so the box has the stack's real size and look
            preview = function(unlocked)
                for i = 1, 3 do
                    if unlocked then B:StartTimer("layout" .. i, L.ENC_TEST_EVENT:format(i), 8 * i + 2, 30, M.PULL_ICON)
                    else B:StopTimer("layout" .. i) end
                end
            end })
        LEM:RegisterCallback("enter", function() editing = true; if M.active then anchor:Show() end end)
        LEM:RegisterCallback("exit", function() editing = false end)
    end
    ns.Events:On("ENCOUNTER_TIMELINE_EVENT_ADDED", B, onAdded)
    ns.Events:On("ENCOUNTER_TIMELINE_EVENT_REMOVED", B, onRemoved)
    ns.Events:On("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", B, wake)
    seed()
    if next(events) or next(timers) then wake() end
end

function B:Disable()
    ns.Events:OffAll(B)
    wipe(timers)
    if anchor then anchor:Hide() end
    if bigAnchor then bigAnchor:Hide() end
    if timerAnchor then timerAnchor:Hide() end
    for _, pool in ipairs({ bars, bigBars, timerBars }) do
        for _, f in ipairs(pool) do f:Hide(); f.key = nil end
    end
end

function B:Refresh()
    if not anchor then return end
    ensureBig()
    ensureTimers()
    layoutAnchor()
    for _, pool in ipairs({ bars, bigBars, timerBars }) do
        for _, f in ipairs(pool) do f.styled, f.key, f.slot = nil, nil, nil end
    end
    if timerAnchor and not M.db.timeline.timerBars.move then timerAnchor:Hide() end
    if anchor:IsShown() then draw(GetTime()) end
end

-- Draws now and returns the number of bars shown (the smoke test and the options use it).
function B:Draw()
    if not anchor then return 0 end
    return draw(GetTime())
end
