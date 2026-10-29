local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix calendar window: our own month view fed by C_Calendar. A 7 x 6 day grid (today outlined in the
    accent, the picked day filled, a dot count of each day's events), previous / next month, and the picked
    day's events as Phoenix rows (time and title). Creating, editing and answering invites stay in Blizzard's
    calendar (the arrow button, this visit). Skins > "Phoenix calendar window" off: Blizzard's calendar,
    reskinned, live. ]]

local CELL, GAP, LIST_W = 52, 4, 260
local r, list, cells
local pickDay

-- Grid position (1..42) of day d for a month starting on weekday first (1 = Sunday).
function M.CalendarCell(first, d) return (tonumber(first) or 1) - 1 + d end

local function events(day)
    local out = {}
    local n = tonumber(C_Calendar.GetNumDayEvents(0, day)) or 0
    for i = 1, n do
        local e = C_Calendar.GetDayEvent(0, day, i)
        if type(e) == "table" then
            local t = type(e.startTime) == "table" and e.startTime or {}
            out[#out + 1] = { title = tostring(e.title or ""), time = ("%02d:%02d"):format(tonumber(t.hour) or 0, tonumber(t.minute) or 0),
                icon = e.iconTexture }
        end
    end
    return out
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
    for i, c in ipairs(cells) do
        local d = i - (tonumber(info.firstWeekday) or 1) + 1
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
    r.dayTitle:SetText(L.CALW_DAY:format(pickDay))
    local ev = events(pickDay)
    r.none:SetShown(#ev == 0)
    list.Set(ev, function(b, e)
        if b.icon then b.icon:SetTexture(e.icon) end
        b.title:SetText(e.title)
        b.sub:SetText(e.time)
        b.right:SetText("")
        list.Bar(b, "accent.primary")
    end)
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
        fs:SetText(type(names) == "table" and names[i] and tostring(names[i]):sub(1, 3) or tostring(i))
    end
    for i = 1, 42 do
        local c = CreateFrame("Button", nil, r.body)
        c:SetSize(CELL, CELL - 8)
        c:SetPoint("TOPLEFT", ((i - 1) % 7) * (CELL + GAP), -46 - math.floor((i - 1) / 7) * (CELL - 8 + GAP))
        c.num = W.Text(c, "body", "text.primary"); c.num:SetPoint("TOPLEFT", 5, -4)
        c.dots = W.Text(c, "small", "accent.primary"); c.dots:SetPoint("BOTTOMRIGHT", -4, 3)
        c:SetScript("OnClick", function(self) if self.day then pickDay = self.day; r:Layout() end end)
        cells[i] = c
    end
    local x = 7 * (CELL + GAP) + 10
    r.dayTitle = W.Text(r.body, "heading", "accent.primary")
    r.dayTitle:SetPoint("TOPLEFT", x, -2)
    list = M.ReplaceList(r.body, 8, 38, LIST_W, 24)
    list:SetPoint("TOPLEFT", x, -30)
    r.none = W.Text(r.body, "body", "text.muted")
    r.none:SetPoint("TOPLEFT", x, -36)
    r.none:SetText(L.CALW_NONE)
end

local cal = M.Replacement({ key = "ownCalendar", frame = "CalendarFrame", title = L.CALW_TITLE,
    width = 7 * (CELL + GAP) + LIST_W + 30, height = 34 + 46 + 6 * (CELL - 8 + GAP) + 30, build = build, layout = layout,
    close = function() if CalendarFrame then HideUIPanel(CalendarFrame) end end })
M.CalendarReplacement = cal

function M:SetupCalendarWindow()
    if not M.ReplacementHook(cal) then return end
    cal.onOpen = function() pickDay = nil end
    for _, event in ipairs({ "CALENDAR_UPDATE_EVENT_LIST", "CALENDAR_UPDATE_EVENT", "CALENDAR_NEW_EVENT" }) do
        ns.Events:On(event, cal, function() cal:Soon() end)
    end
    cal:Sync()
end
function M:SyncCalendar() cal:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupCalendarWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncCalendar"
