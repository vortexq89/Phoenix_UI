local ADDON, ns = ...
local L = ns.L

--[[ Boot sequence (ARCHITECTURE §3):
    ADDON_LOADED  -> DB:Init (migrations), theme, module OnInitialize
    PLAYER_LOGIN  -> enable modules, Blizzard integration, one-time migration notice ]]
local Init = {}
-- Fixed English text (not localised) so reports are easy to find and delete on the dashboard.
ns.TEST_ERROR = "PHOENIX TEST ERROR - safe to delete (/phoenix testerror)"

local function slash(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.Config:Toggle()
    elseif cmd == "settings" then
        ns.Config:OpenBlizzardSettings()
    elseif cmd == "edit" or cmd == "editmode" or cmd == "move" then
        ns.EditMode:Open()
    elseif cmd == "profile" then
        if rest == "" then
            ns:Print(L.SLASH_PROFILE_CURRENT, ns.DB:GetProfileName())
        elseif ns.DB.sv.profiles[rest] then
            ns.DB:SetProfile(rest)
            ns:Print(L.SLASH_PROFILE_SET, rest)
        else
            ns:Print(L.SLASH_PROFILE_MISSING, rest)
        end
    elseif cmd == "reset" then
        ns.Config:ResetPosition()
        ns:Print(L.SLASH_RESET_DONE)
    elseif cmd == "testerror" then
        -- Hidden: a harmless, clearly labelled Lua error to try the bug catcher and the uploader end to end.
        -- Raised on the next frame so it reaches the global error handler like any real addon error.
        ns:Print(L.SLASH_TEST_ERROR)
        C_Timer.After(0, function() error(ns.TEST_ERROR, 0) end)
    elseif cmd == "diag" then
        ns.Diag:Run(false)
    elseif cmd == "debug" then
        ns.debug = not ns.debug
        ns:Print(L.SLASH_DEBUG, ns.debug and L.ENABLED or L.DISABLED)
    elseif cmd == "help" or cmd == "?" then
        for line in (L.SLASH_HELP_TEXT .. "\n" .. L.SLASH_HELP_MORE):gmatch("[^\n]+") do ns:Print(line) end
    else
        for _, m in ipairs(ns.moduleList) do
            if m.key:lower() == cmd then
                if m.OnSlash and m:IsEnabled() then return m:OnSlash(rest:lower()) end
                return ns.Config:Show(m.key)
            end
        end
        ns:Print(L.SLASH_UNKNOWN:format(cmd))
        ns:Print(L.SLASH_HELP)
    end
end

ns.TestSlash = slash -- the smoke harness drives sub-commands through this

ns.Events:On("ADDON_LOADED", Init, function(_, _, name)
    if name ~= ADDON then return end
    ns.Events:Off("ADDON_LOADED", Init)
    ns.DB:Init()
    ns:InitializeModules()
    RegisterNewSlashCommand(slash, "pui", "phoenix")
end)

ns.Events:On("PLAYER_LOGIN", Init, function()
    ns:EnableModules()
    ns.SafeCall(ns.Config.RegisterBlizzard, ns.Config)
    local report = ns.Migrations.legacyReport
    if report then
        ns:Print(L.MIGRATION_DONE, report.imported)
        ns.Migrations.legacyReport = nil
    end
end)
