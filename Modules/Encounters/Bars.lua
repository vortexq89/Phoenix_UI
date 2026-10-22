local _, ns = ...
local L, Skin, Media, Theme, Secret = ns.L, ns.Skin, ns.Media, ns.Theme, ns.Secret
local M = ns:GetModule("Encounters")
local LEM = LibStub("LibEditMode")

--[[ Encounter bars: Blizzard's encounter timeline drawn as Phoenix bars, plus the pull and break timers.
    Per event we read only what is never secret (id, source, duration from the event info; time remaining and
    state from C_EncounterTimeline) and do all sorting, filtering and emphasis on those. The spell name and
    icon may be secret: they go straight into SetText / SetTexture and are never compared or stored on disk.
    Pull and break are Phoenix timers in the same stack, so the screen has one timer list, sorted by time. ]]
local B = {}
M.Bars = B

local STATE = Enum.EncounterTimelineEventState
local TRACK = Enum.EncounterTimelineTrack
local SOURCE_EDITMODE = 2 -- Enum.EncounterTimelineEventSource.EditMode
local THROTTLE = 0.05

local anchor
local bars = {}      -- pooled bar frames, bars[i] shows rows[i]
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
    f.name = f.edge:CreateFontString(nil, "OVERLAY")
    f.name:SetPoint("LEFT", 6, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.time = f.edge:CreateFontString(nil, "OVERLAY")
    f.time:SetPoint("RIGHT", -6, 0)
    f.time:SetJustifyH("RIGHT")
    f.name:SetPoint("RIGHT", f.time, "LEFT", -6, 0)
    return f
end

function M:BarTexture()
    local t = self.db.timeline.texture
    return t ~= "" and Media:Bar(t) or Theme:Bar()
end

function M:BarColor(emphasized)
    local db = self.db.timeline
    local c = emphasized and db.emphasizeColor or db.color
    if type(c) == "table" then return c.r, c.g, c.b end
    return Theme:Color(emphasized and "state.danger" or "accent.primary")
end

-- Size, texture, colours, fonts and border of one bar; the preview calls this too.
function M:StyleBar(f, emphasized)
    local db = self.db.timeline
    local h = db.height
    f:SetSize(db.width, h)
    f.iconHolder:SetSize(h, h)
    f.iconHolder:ClearAllPoints()
    f.iconHolder:SetPoint("LEFT")
    f.iconHolder:SetShown(db.icon)
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", db.icon and (h + 2) or 0, 0)
    f.bar:SetPoint("BOTTOMRIGHT")
    f.bar:SetStatusBarTexture(self:BarTexture())
    f.bar:SetStatusBarColor(self:BarColor(emphasized))
    Skin:Backdrop(f.bar, db.background, "bg.sunken")
    Skin:BorderSpec(f.edge, db.border, "border.black")
    Skin:BorderSpec(f.iconHolder, db.border, "border.black")
    Skin:TextSpec(f.name, db.name, "unit", "text.primary")
    Skin:TextSpec(f.time, db.time, "number", "text.primary")
end

function M.FormatTime(left)
    if left >= 60 then return ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60)) end
    if left < 10 then return ("%.1f"):format(left) end
    return ("%d"):format(left)
end

---------------------------------------------------------------- data
local function remember(info)
    if type(info) ~= "table" or info.id == nil then return end
    local e = { info = info, duration = info.duration }
    if info.source == SOURCE_EDITMODE then
        editCount = editCount + 1
        e.label = L.ENC_TEST_EVENT:format(editCount)
    end
    events[info.id] = e
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
            if (state == STATE.Active or state == STATE.Paused) and not hidden and type(left) == "number"
                and not Secret.IsSecret(left) and (db.horizon <= 0 or left <= db.horizon) then
                rows[#rows + 1] = { key = id, label = e.label, info = e.info, left = left, total = e.duration,
                    dim = state == STATE.Paused or query(C_EncounterTimeline.IsEventBlocked, id) == true }
            end
        end
    end
    for key, t in pairs(timers) do
        local left = t.endsAt - now
        if left <= 0 then
            timers[key] = nil
        else
            rows[#rows + 1] = { key = key, label = t.label, icon = t.icon, left = left, total = t.total }
        end
    end
    table.sort(rows, function(a, b) return a.left < b.left end)
    return rows
end

---------------------------------------------------------------- drawing
local function barAt(i)
    local f = bars[i]
    if not f then
        f = M:CreateBar(anchor)
        bars[i] = f
        f.styled = nil
    end
    return f
end

local function place(f, i)
    local db = M.db.timeline
    local step = (i - 1) * (db.height + db.spacing)
    f:ClearAllPoints()
    if db.grow == "DOWN" then
        f:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -step)
    else
        f:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, step)
    end
end

local function draw(now)
    local db = M.db.timeline
    local list = collect(now)
    local shown = math.min(#list, db.max)
    for i = 1, shown do
        local r, f = list[i], barAt(i)
        local emphasized = db.emphasize and r.left <= db.emphasizeAt
        if f.styled ~= emphasized then M:StyleBar(f, emphasized); place(f, i); f.styled = emphasized end
        if f.key ~= r.key then
            f.key = r.key
            -- Our own label and icon are plain; the event's spell name and icon may be secret, so they are
            -- handed to the sinks without any test (not even `or`).
            if r.label then f.name:SetText(r.label) elseif r.info then f.name:SetText(r.info.spellName) end
            if r.icon then f.icon:SetTexture(r.icon) elseif r.info then f.icon:SetTexture(r.info.iconFileID) end
            place(f, i)
        end
        f.bar:SetMinMaxValues(0, r.total > 0 and r.total or 1)
        f.bar:SetValue(r.left)
        f.time:SetText(r.left > 0.05 and M.FormatTime(r.left) or L.ENC_SOON)
        f:SetAlpha(r.dim and 0.55 or 1)
        f:Show()
    end
    for i = shown + 1, #bars do bars[i]:Hide(); bars[i].key = nil end
    return shown
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
end

function B:Enable()
    if not anchor then
        anchor = CreateFrame("Frame", "PhoenixEncounterBars", UIParent)
        anchor:SetFrameStrata("MEDIUM")
        anchor:SetClampedToScreen(true)
        anchor:Hide()
        anchor:SetScript("OnUpdate", onUpdate)
        layoutAnchor()
        ns.EditMode:Register(anchor, { key = "EncounterBars", name = ns.title .. " – " .. L.ENC_TIMELINE,
            default = { point = "CENTER", x = 320, y = 80 } })
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
    for _, f in ipairs(bars) do f:Hide(); f.key = nil end
end

function B:Refresh()
    if not anchor then return end
    layoutAnchor()
    for i, f in ipairs(bars) do f.styled = nil; f.key = nil; place(f, i) end
    if anchor:IsShown() then draw(GetTime()) end
end

-- Draws now and returns the number of bars shown (the smoke test and the options use it).
function B:Draw()
    if not anchor then return 0 end
    return draw(GetTime())
end
