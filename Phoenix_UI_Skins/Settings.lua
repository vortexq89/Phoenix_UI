local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Settings and Edit Mode, skins plan window 24 (window chrome: shared skin): the settings category rail and
    the settings list as Phoenix rows (Blizzard's controls kept), the Edit Mode manager as a Phoenix dialog, and
    every Edit Mode system frame's selection with a 1 px accent outline of ours (a child frame of the
    selection, shown and hidden with it). Nothing in Edit Mode is moved, saved or called by us, so layouts
    save and revert as Blizzard's. Live with Skins > Settings. ]]

local function on() return M:IsEnabled() and M.db.settings and true or false end

local outlines = setmetatable({}, { __mode = "k" })
function M.EditOutline(system, isOn)
    local sel = type(system) == "table" and rawget(system, "Selection")
    if type(sel) ~= "table" or not sel.GetObjectType then return end
    local o = outlines[sel]
    if not isOn then if o then o:Hide() end; return end
    if not o then
        o = CreateFrame("Frame", nil, sel)
        o:SetAllPoints()
        o:SetFrameLevel(sel:GetFrameLevel() + 1)
        ns.Skin:Border(o, "accent.primary")
        outlines[sel] = o
    end
    ns.Skin:SetBorderColor(o, "accent.primary")
    o:Show()
end

function M:SkinSettings()
    local isOn = on()
    local sp = _G.SettingsPanel
    if sp then
        M.KitScrollBox(M.FramePath(sp, { "CategoryList", "ScrollBox" }), on, function(row, o) M.KitRow(row, o, { alpha = 0.3 }) end)
        M.KitScrollBox(M.FramePath(sp, { "Container", "SettingsList", "ScrollBox" }), on,
            function(row, o) M.KitRow(row, o, { alpha = 0.25 }) end)
        M.KitCard(rawget(sp, "SearchBox"), isOn, "sunken", false)
    end
    local em = _G.EditModeManagerFrame
    if em then
        if isOn then M.SkinWindow(em, true) else M.UnskinWindow(em) end
        local systems = rawget(em, "registeredSystemFrames")
        if type(systems) == "table" then
            for _, sys in ipairs(systems) do M.EditOutline(sys, isOn) end
        else
            M.FramePath(em, { "registeredSystemFrames" })
        end
        M.SkinPopupButton(rawget(em, "SaveChangesButton"), "primary", isOn)
        M.SkinPopupButton(rawget(em, "RevertAllChangesButton"), "secondary", isOn)
    end
end

local settingsHooked
function M:SetupSettings()
    self:SkinSettings()
    local root = _G.SettingsPanel
    if settingsHooked or not root then return end
    settingsHooked = true
    root:HookScript("OnShow", function() M:SkinSettings() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupSettings"
M.RESKINS[#M.RESKINS + 1] = "SkinSettings"
