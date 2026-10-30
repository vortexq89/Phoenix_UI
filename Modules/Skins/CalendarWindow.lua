local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix calendar window: our own month view fed by C_Calendar. A 7 x 6 day grid (today outlined in the
    accent, the picked day filled, a dot count of each day's events), previous / next month, and the picked
    day's events as Phoenix rows (time and title). Invites you have not answered show Accept / Tentative /
    Decline (the event is opened with the calendar's own call, answered, closed). New event: title, time,
    type, description and invites, created with the calendar's own create / set / add calls on your click.
    Edit (your own events): the event is opened with the calendar's own call, the form is filled from it, and Save
    sends the set calls and UpdateEvent on your click. Guild / community sign-ups stay in Blizzard's calendar (the
    arrow button).
    Skins > "Phoenix calendar window" off: Blizzard's calendar, reskinned, live. ]]

local CELL, GAP, LIST_W = 52, 4, 270
local r, list, cells
local pickDay, pickEvent, panel = nil, nil, "day"
local pending -- { day, index, answer } waiting for CALENDAR_OPEN_EVENT
local invites = {}

-- t156: the week starts where Blizzard's calendar starts it: CALENDAR_FIRST_WEEKDAY, set per locale by
-- Blizzard_Calendar (Monday for deDE / enGB / esES / frFR / itIT / ruRU, Sunday for enUS). 1 = Sunday.
function M.CalendarWeekStart()
    local w = tonumber(_G.CALENDAR_FIRST_WEEKDAY)
    return (w and w >= 1 and w <= 7) and math.floor(w) or 1
end

-- Grid position (1..42) of day d for a month whose day 1 falls on weekday first (1 = Sunday), in a week
-- that starts on weekStart (default Sunday).
function M.CalendarCell(first, d, weekStart)
    return ((tonumber(first) or 1) - (tonumber(weekStart) or 1)) % 7 + d
end

-- Weekday shown in header column i (1..7) for a week starting on weekStart.
function M.CalendarColumnDay(i, weekStart) return (i - 1 + (tonumber(weekStart) or 1) - 1) % 7 + 1 end

-- First n characters of s, UTF-8 safe (ruRU / koKR / zhCN weekday names are multi-byte; :sub cut them).
function M.Utf8Head(s, n)
    local out, count = {}, 0
    for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > n then break end
        out[count] = ch
    end
    return table.concat(out)
end

local function events(day)
    local out = {}
    local n = tonumber(C_Calendar.GetNumDayEvents(0, day)) or 0
    for i = 1, n do
        local e = C_Calendar.GetDayEvent(0, day, i)
        if type(e) == "table" then
            local t = type(e.startTime) == "table" and e.startTime or {}
            local S = Enum.CalendarStatus or {}
            out[#out + 1] = { index = i, title = tostring(e.title or ""),
                time = ("%02d:%02d"):format(tonumber(t.hour) or 0, tonumber(t.minute) or 0),
                icon = e.iconTexture, invited = S.Invited ~= nil and e.inviteStatus == S.Invited,
                own = e.calendarType == "PLAYER" and (e.modStatus == "CREATOR" or e.modStatus == "MODERATOR") }
        end
    end
    return out
end

local function drawGrid(info, now, thisMonth, days)
    for i, c in ipairs(cells) do
        local d = i - M.CalendarCell(info.firstWeekday, 1, M.CalendarWeekStart()) + 1
        if d >= 1 and d <= days then
            c.day = d
            c.num:SetText(d)
            local n = tonumber(C_Calendar.GetNumDayEvents(0, d)) or 0
            c.dots:SetText(n > 0 and tostring(n) or "")
            local today = thisMonth and d == tonumber(now.monthDay)
            Skin:Panel(c, d == pickDay and "hover" or "raised", { border = today and "accent.primary" or "border.subtle" })
            Skin:Text(c.num, "body", d == pickDay and "accent.primary" or "text.primary", 12)
            c:Show()
        else
            c.day = nil
            c:Hide()
        end
    end
end

local function layout()
    local info = C_Calendar.GetMonthInfo(0)
    if type(info) ~= "table" then return end
    local now = C_DateAndTime.GetCurrentCalendarTime() or {}
    local thisMonth = tonumber(now.month) == tonumber(info.month) and tonumber(now.year) == tonumber(info.year)
    local days = tonumber(info.numDays) or 30
    if not pickDay or pickDay > days then pickDay = thisMonth and tonumber(now.monthDay) or 1 end
    r.month:SetText(("%s %d"):format(tostring(CALENDAR_FULLDATE_MONTH_NAMES and CALENDAR_FULLDATE_MONTH_NAMES[info.month] or info.month),
        tonumber(info.year) or 0))
    drawGrid(info, now, thisMonth, days)
    r.dayTitle:SetText(L.CALW_DAY:format(pickDay))
    local form = panel == "create" or panel == "edit"
    r.create:SetShown(form)
    list:SetShown(panel == "day")
    r.newBtn:SetShown(panel == "day")
    r.edit:Hide()
    if form then
        r.go:SetText(panel == "edit" and L.CALW_SAVE or L.CALW_CREATE)
        r.invite:SetShown(panel == "create")
        r.none:Hide()
        for _, b in ipairs(r.answers) do b:Hide() end
        r.inviteList:SetText(table.concat(invites, ", "))
        r.typeBtn:SetText(M.CalendarTypes()[r.typeIndex].label)
        return
    end
    local ev = events(pickDay)
    r.none:SetShown(#ev == 0)
    local pick
    list.Set(ev, function(b, e)
        if b.icon then b.icon:SetTexture(e.icon) end
        b.title:SetText(e.title)
        b.sub:SetText(e.invited and L.CALW_INVITED:format(e.time) or e.time)
        b.right:SetText("")
        if e.index == pickEvent then pick = e; list.Mark(b, "accent.primary", 0.25) end
        list.Bar(b, e.invited and "state.warning" or "accent.primary")
    end)
    for _, b in ipairs(r.answers) do b:SetShown(pick ~= nil and pick.invited) end
    r.edit:SetShown(pick ~= nil and pick.own == true)
end

function M.CalendarTypes()
    local T = Enum.CalendarEventType or {}
    return { { value = T.Raid, label = L.VAULTW_RAID }, { value = T.Dungeon, label = L.EJW_DUNGEONS },
        { value = T.PvP, label = L.CALW_TYPE_PVP }, { value = T.Meeting, label = L.CALW_TYPE_MEETING },
        { value = T.Other, label = L.CALW_TYPE_OTHER } }
end

-- Answer an invite: open the event with the calendar's own call; the answer is sent when it is open.
function M:CalendarAnswer(answer)
    if not (pickDay and pickEvent) then return end
    pending = { answer = answer }
    C_Calendar.OpenEvent(0, pickDay, pickEvent)
end

-- Edit one of your own events: open it with the calendar's own call; the form fills when it is open.
function M:CalendarEdit()
    if not (pickDay and pickEvent) then return end
    pending = { edit = true }
    C_Calendar.OpenEvent(0, pickDay, pickEvent)
end

-- The open event into the form (pure on the info table): title, description, hour, minute, type index.
function M.CalendarFormFrom(info, types)
    info = type(info) == "table" and info or {}
    local t = type(info.time) == "table" and info.time or {}
    local typeIndex = 1
    for i, ty in ipairs(types or {}) do if ty.value == info.eventType then typeIndex = i end end
    return tostring(info.title or ""), tostring(info.description or ""), tonumber(t.hour) or 20, tonumber(t.minute) or 0,
        typeIndex
end

local function fillEdit()
    local title, desc, hour, minute, typeIndex = M.CalendarFormFrom(C_Calendar.GetEventInfo(), M.CalendarTypes())
    r.title:SetValue(title)
    r.desc.edit:SetText(desc)
    r.hour:SetValue(("%d"):format(hour))
    r.minute:SetValue(("%02d"):format(minute))
    r.typeIndex = typeIndex
    panel = "edit"
    r:Layout()
end

local function sendAnswer()
    local p = pending
    pending = nil
    if not p then return end
    if p.edit then return fillEdit() end
    if p.answer == "accept" then C_Calendar.EventAvailable()
    elseif p.answer == "tentative" then C_Calendar.EventTentative()
    else C_Calendar.EventDecline() end
    C_Calendar.CloseEvent()
end
M.CalendarSendAnswer = sendAnswer

-- Create the new event from the form: the calendar's own create / set / invite / add calls, in that order.
function M:CalendarCreate()
    local title = r.title:GetText() or ""
    if title == "" then r.title:SetFocus(); return end
    if panel == "edit" then return M:CalendarSave(title) end
    local info = C_Calendar.GetMonthInfo(0) or {}
    local hour = math.max(0, math.min(23, tonumber(r.hour:GetText()) or 20))
    local minute = math.max(0, math.min(59, tonumber(r.minute:GetText()) or 0))
    C_Calendar.CreatePlayerEvent()
    C_Calendar.EventSetTitle(title)
    C_Calendar.EventSetDescription(r.desc.edit:GetText() or "")
    C_Calendar.EventSetDate(tonumber(info.month) or 1, pickDay or 1, tonumber(info.year) or 2026)
    C_Calendar.EventSetTime(hour, minute)
    local t = M.CalendarTypes()[r.typeIndex]
    if t and t.value ~= nil then C_Calendar.EventSetType(t.value) end
    for _, name in ipairs(invites) do C_Calendar.EventInvite(name) end
    C_Calendar.AddEvent()
    invites = {}
    panel = "day"
    r:Layout()
end

-- Save the edited event: the calendar's own set calls on the open event, then UpdateEvent (your click).
function M:CalendarSave(title)
    local hour = math.max(0, math.min(23, tonumber(r.hour:GetText()) or 20))
    local minute = math.max(0, math.min(59, tonumber(r.minute:GetText()) or 0))
    C_Calendar.EventSetTitle(title)
    C_Calendar.EventSetDescription(r.desc.edit:GetText() or "")
    C_Calendar.EventSetTime(hour, minute)
    local t = M.CalendarTypes()[r.typeIndex]
    if t and t.value ~= nil then C_Calendar.EventSetType(t.value) end
    C_Calendar.UpdateEvent()
    C_Calendar.CloseEvent()
    panel = "day"
    r:Layout()
end

local function build(rr)
    r = rr
    cells = {}
    r.prev = W:IconButton(r.body, "reset", 22, PREV or "<")
    r.prev:SetPoint("TOPLEFT", 0, 0)
    r.prev.onClick = function() C_Calendar.SetMonth(-1); pickDay = nil; r:Layout() end
    r.month = W.Text(r.body, "heading", "text.primary")
    r.month:SetPoint("LEFT", r.prev, "RIGHT", 10, 0)
    r.next = W:IconButton(r.body, "play", 22, NEXT or ">")
    r.next:SetPoint("TOPLEFT", 7 * (CELL + GAP) - 22, 0)
    r.next.onClick = function() C_Calendar.SetMonth(1); pickDay = nil; r:Layout() end
    for i = 1, 7 do
        local fs = W.Text(r.body, "small", "text.muted")
        fs:SetPoint("TOPLEFT", (i - 1) * (CELL + GAP) + 4, -30)
        local names = CALENDAR_WEEKDAY_NAMES
        local wd = M.CalendarColumnDay(i, M.CalendarWeekStart())
        fs:SetText(type(names) == "table" and names[wd] and M.Utf8Head(names[wd], 3) or tostring(wd))
    end
    for i = 1, 42 do
        local c = CreateFrame("Button", nil, r.body)
        c:SetSize(CELL, CELL - 8)
        c:SetPoint("TOPLEFT", ((i - 1) % 7) * (CELL + GAP), -46 - math.floor((i - 1) / 7) * (CELL - 8 + GAP))
        c.num = W.Text(c, "body", "text.primary"); c.num:SetPoint("TOPLEFT", 5, -4)
        c.dots = W.Text(c, "small", "accent.primary"); c.dots:SetPoint("BOTTOMRIGHT", -4, 3)
        c:SetScript("OnClick", function(self) if self.day then pickDay, pickEvent = self.day, nil; r:Layout() end end)
        cells[i] = c
    end
    local x = 7 * (CELL + GAP) + 10
    r.dayTitle = W.Text(r.body, "heading", "accent.primary")
    r.dayTitle:SetPoint("TOPLEFT", x, -2)
    list = M.ReplaceList(r.body, 8, 38, LIST_W, 24)
    list:SetPoint("TOPLEFT", x, -30)
    list.onClick = function(e) pickEvent = e.index; r:Layout() end
    r.none = W.Text(r.body, "body", "text.muted")
    r.none:SetPoint("TOPLEFT", x, -36)
    r.none:SetText(L.CALW_NONE)
    r.answers = {}
    for i, def in ipairs({ { "accept", L.CALW_ACCEPT, "primary" }, { "tentative", L.CALW_TENTATIVE, "secondary" },
        { "decline", L.CALW_DECLINE, "danger" } }) do
        local b = W:Button(r.body, def[2], def[3], nil, 82)
        b:SetHeight(22)
        b:SetPoint("BOTTOMLEFT", x + (i - 1) * 86, 30)
        b.onClick = function() M:CalendarAnswer(def[1]) end
        r.answers[i] = b
    end
    r.newBtn = W:Button(r.body, L.CALW_NEW, "secondary", "add", 140)
    r.newBtn:SetHeight(22)
    r.newBtn:SetPoint("BOTTOMLEFT", x, 0)
    r.newBtn.onClick = function() panel = "create"; r.title:SetValue(""); r.desc.edit:SetText(""); r:Layout() end
    r.edit = W:Button(r.body, L.CALW_EDIT, "secondary", "rename", 100)
    r.edit:SetHeight(22)
    r.edit:SetPoint("LEFT", r.newBtn, "RIGHT", 6, 0)
    r.edit.onClick = function() M:CalendarEdit() end
    -- new event form
    local f = CreateFrame("Frame", nil, r.body)
    f:SetPoint("TOPLEFT", x, -26)
    f:SetSize(LIST_W, 330)
    f:Hide()
    r.create = f
    r.title = W:Input(f, LIST_W, L.CALW_EVENT_TITLE); r.title:SetPoint("TOPLEFT", 0, 0)
    r.hour = W:Input(f, 60, "20"); r.hour:SetPoint("TOPLEFT", 0, -32); r.hour:SetNumeric(true)
    r.minute = W:Input(f, 60, "00"); r.minute:SetPoint("LEFT", r.hour, "RIGHT", 6, 0); r.minute:SetNumeric(true)
    r.typeIndex = 1
    r.typeBtn = W:Button(f, "", "secondary", nil, 120); r.typeBtn:SetHeight(26)
    r.typeBtn:SetPoint("LEFT", r.minute, "RIGHT", 6, 0)
    r.typeBtn.onClick = function() r.typeIndex = r.typeIndex % #M.CalendarTypes() + 1; r:Layout() end
    r.desc = W:TextArea(f, LIST_W, 90); r.desc:SetPoint("TOPLEFT", 0, -64)
    r.invite = W:Input(f, LIST_W, L.CALW_INVITE_NAME); r.invite:SetPoint("TOPLEFT", 0, -160)
    r.invite.onChange = function(self, text)
        if type(text) == "string" and text ~= "" then invites[#invites + 1] = text; self:SetValue(""); r:Layout() end
    end
    r.inviteList = W.Text(f, "small", "text.secondary"); r.inviteList:SetPoint("TOPLEFT", 0, -192)
    r.inviteList:SetWidth(LIST_W); r.inviteList:SetJustifyH("LEFT")
    r.go = W:Button(f, L.CALW_CREATE, "primary", "add", 120); r.go:SetPoint("BOTTOMLEFT", 0, 0)
    r.go.onClick = function() M:CalendarCreate() end
    r.cancel = W:Button(f, CANCEL or "Cancel", "secondary", nil, 90); r.cancel:SetPoint("LEFT", r.go, "RIGHT", 6, 0)
    r.cancel.onClick = function()
        if panel == "edit" then C_Calendar.CloseEvent() end
        invites = {}; panel = "day"; r:Layout()
    end
end

local cal = M.Replacement({ key = "ownCalendar", frame = "CalendarFrame", title = L.CALW_TITLE,
    width = 7 * (CELL + GAP) + LIST_W + 30, height = 34 + 46 + 6 * (CELL - 8 + GAP) + 30, build = build, layout = layout,
    close = function() if CalendarFrame then HideUIPanel(CalendarFrame) end end })
M.CalendarReplacement = cal

function M:SetupCalendarWindow()
    if not M.ReplacementHook(cal) then return end
    cal.onOpen = function() pickDay, pickEvent, panel = nil, nil, "day" end
    ns.Events:On("CALENDAR_OPEN_EVENT", cal, function() if pending then sendAnswer(); cal:Soon() end end)
    for _, event in ipairs({ "CALENDAR_UPDATE_EVENT_LIST", "CALENDAR_UPDATE_EVENT", "CALENDAR_NEW_EVENT" }) do
        ns.Events:On(event, cal, function() cal:Soon() end)
    end
    cal:Sync()
end
function M:SyncCalendar() cal:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupCalendarWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncCalendar"
