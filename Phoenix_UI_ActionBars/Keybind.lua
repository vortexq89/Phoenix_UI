local _, ns = ...
local L = ns.L
local M = ns:GetModule("ActionBars")

--[[ Quick keybind mode. Phoenix bars hold Blizzard's own action buttons (ActionBars.lua), so the game's Quick Keybind
    mode binds them directly: hover a button, press a key. Phoenix adds the way in (Action Bars > Keybinds,
    /pui kb, the Layout mode toolbar) and makes faded or mouseover bars fully visible while the mode is open
    (B.State's reveal, the same rule as dragging a spell). Bars hidden by a visibility rule stay as they are.
    The game reopens its Settings panel when the mode closes; that is Blizzard's behaviour. Out of combat only. ]]

local function setMode(on)
    M.keybindMode = on and true or nil
    local B = M.BarsEngine
    if B and B.Headers then
        for _, h in pairs(B.Headers()) do ns.SafeCall(B.Fade, h, true) end
    end
end
M.SetKeybindMode = setMode

-- Opens the game's Quick Keybind mode. -> true, or false and a locale key for why not.
function M:OpenQuickKeybind()
    if InCombatLockdown() then return false, "AB_KEYBIND_COMBAT" end
    if not QuickKeybindFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_QuickKeybind") end
    local frame = rawget(_G, "QuickKeybindFrame")
    if not frame then return false, "AB_KEYBIND_MISSING" end
    self:HookQuickKeybind()
    if ns.Config and ns.Config.frame and ns.Config.frame:IsShown() then ns.Config.frame:Hide() end
    if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end
    return true
end

local hooked
-- Follows the game's Quick Keybind window however it is opened (ours, Settings > Keybindings, Edit Mode).
function M:HookQuickKeybind()
    local frame = rawget(_G, "QuickKeybindFrame")
    if hooked == frame or not (frame and frame.HookScript) then return end
    hooked = frame
    frame:HookScript("OnShow", function() setMode(true) end)
    frame:HookScript("OnHide", function() setMode(false) end)
    if frame:IsShown() then setMode(true) end
end

ns.Events:On("ADDON_LOADED", {}, function(_, _, name)
    if name == "Blizzard_QuickKeybind" then M:HookQuickKeybind() end
end)

function M:OnSlash(rest)
    if rest == "kb" or rest == "keybind" or rest == "bind" then
        local ok, why = self:OpenQuickKeybind()
        if not ok then ns:Print(L[why]) end
        return
    end
    ns.Config:Show(self.key)
end
