-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local M = ns.modules.Automation

--[[ Gamepad: the game's controller console variables behind Phoenix switches and sliders, so a controller can be
    set up without the console. Values are read from the game each time (no copy kept); set out of combat. ]]

M.GAMEPAD_CVARS = { enable = "GamePadEnable", yaw = "GamePadCameraYawSpeed", pitch = "GamePadCameraPitchSpeed" }

function M.GamepadGet(which)
    local name = M.GAMEPAD_CVARS[which]
    local v = name and C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name)
    if which == "enable" then return v == "1" end
    return tonumber(v) or 1
end

function M.GamepadSet(which, value)
    local name = M.GAMEPAD_CVARS[which]
    if not (name and C_CVar and C_CVar.SetCVar) or InCombatLockdown() then return false end
    if which == "enable" then value = value and "1" or "0" else value = tostring(value) end
    return pcall(C_CVar.SetCVar, name, value)
end

function M.GamepadConnected()
    local id = C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID()
    return type(id) == "number" and id >= 0
end
