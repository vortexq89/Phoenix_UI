-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local M = ns:GetModule("Automation")

--[[ CVar editor (WindTools idea, our own code): look up any console variable by name, read its value and the
    game's default, change it or put the default back, all from Automation > CVar editor. Writes go through
    ns.Combat (out of combat only); nothing is typed into chat and no slash command is needed. ]]

M.cvarName = ""

local function clean(name) return type(name) == "string" and name:match("^%s*(.-)%s*$") or "" end

-- value, default of a known CVar, or nil
function M.CVarInfo(name)
    name = clean(name)
    if name == "" or not (C_CVar and C_CVar.GetCVar) then return nil end
    local v = C_CVar.GetCVar(name)
    if type(v) ~= "string" then return nil end
    local d = C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(name)
    return v, type(d) == "string" and d or nil
end

function M.CVarSet(name, value)
    name = clean(name)
    if M.CVarInfo(name) == nil then return false end
    ns.Combat:Run("cvar." .. name, C_CVar.SetCVar, name, tostring(value or ""))
    return true
end

function M.CVarReset(name)
    local v, d = M.CVarInfo(name)
    if v == nil or d == nil then return false end
    return M.CVarSet(name, d)
end
