local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Calendar, skins plan window 21: day cells on sunken Phoenix cells, today outlined in the accent, the event
    view / create / holiday panels as Phoenix dialogs, Create as the primary button. Event icons are the
    game's own; inviting and signing up stay Blizzard's clicks.
    Live both ways with its Skins switch, repainted on theme change (kit rows / cards). ]]

local function on() return M:IsEnabled() and M.db.calendar and true or false end

function M:SkinCalendar()
    if not _G.CalendarFrame then return end
    local isOn = on()
    for i = 1, 42 do M.KitCard(_G["CalendarDayButton" .. i], isOn, "sunken", false) end
    local today = _G.CalendarTodayFrame
    if today then
        local card = M.KitCard(today, isOn, "raised", true)
        if card then card:SetFrameLevel(today:GetFrameLevel() + 1) end
    end
    for _, name in ipairs({ "CalendarViewEventFrame", "CalendarCreateEventFrame", "CalendarViewHolidayFrame" }) do
        local f = _G[name]
        if f then if isOn then M.SkinWindow(f, true) else M.UnskinWindow(f) end end
    end
    M.SkinPopupButton(_G.CalendarCreateEventCreateButton, "primary", isOn)
end

local calendarHooked
function M:SetupCalendar()
    self:SkinCalendar()
    local root = _G.CalendarFrame
    if calendarHooked or not root then return end
    calendarHooked = true
    root:HookScript("OnShow", function() M:SkinCalendar() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupCalendar"
M.RESKINS[#M.RESKINS + 1] = "SkinCalendar"
