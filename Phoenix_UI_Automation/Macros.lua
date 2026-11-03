local _, ns = ...
local L = ns.L
local M = ns:GetModule("Automation")

--[[ Smart macros: one click writes (or updates) a few general macros, out of combat only:
      PUI Heal   - healthstone, then a healing potion
      PUI Kick   - your interrupt on the focus when there is a hostile one, else on your target
      PUI Mount  - dismounts when mounted; else your swimmer underwater, your flyer where you can fly and your
                   ground mount elsewhere (MountsJournal-style rules, names typed on the Automation page), or a random
                   favourite when none is set
    They are character macros named "PUI …"; existing ones with those names are updated, nothing else is touched. ]]
-- icon 134400 is the question mark: with #showtooltip the macro shows the spell or item it will use
local HEALTHSTONE, POTIONS = 5512, { 211880, 211879, 211878, 191380, 191379, 191378, 187802 }

-- A mount name as typed: trimmed, without the characters that would break a /cast line.
local function mountName(v)
    if type(v) ~= "string" then return nil end
    v = v:gsub("[%[%];\n\r]", ""):match("^%s*(.-)%s*$")
    return v ~= "" and v or nil
end

-- The PUI Mount body. mounts = { swimmer, flyer, ground } names (any may be empty).
function M.MountMacro(mounts)
    mounts = mounts or {}
    local swim, fly, ground = mountName(mounts.swimmer), mountName(mounts.flyer), mountName(mounts.ground)
    if not (swim or fly or ground) then
        return "#showtooltip\n/dismount [mounted]\n/run if not IsMounted() then C_MountJournal.SummonByID(0) end"
    end
    local clauses = {}
    if swim then clauses[#clauses + 1] = "[swimming] " .. swim end
    if fly and ground then clauses[#clauses + 1] = "[flyable] " .. fly end
    clauses[#clauses + 1] = ground or fly or swim
    return "#showtooltip\n/dismount [mounted]\n/stopmacro [mounted]\n/cast " .. table.concat(clauses, "; ")
end

function M.SmartMacros(kickName, mounts)
    local heal = { "#showtooltip", "/use item:" .. HEALTHSTONE }
    for _, id in ipairs(POTIONS) do heal[#heal + 1] = "/use item:" .. id end
    local out = {
        { name = "PUI Heal", icon = 134400, body = table.concat(heal, "\n") },
        { name = "PUI Mount", icon = 134400, body = M.MountMacro(mounts) },
    }
    if type(kickName) == "string" and kickName ~= "" then
        out[#out + 1] = { name = "PUI Kick", icon = 134400,
            body = ("#showtooltip %s\n/cast [@focus,exists,harm,nodead][] %s"):format(kickName, kickName) }
    end
    return out
end

function M:WriteSmartMacros()
    if InCombatLockdown() then ns:Print(L.AUTO_MACROS_COMBAT); return 0 end
    local cb = ns:Loaded("CastBars")
    local kick = cb and cb.KickSpell and cb:KickSpell()
    local kickName = kick and C_Spell.GetSpellName(kick)
    local n = 0
    local db = self.db
    local mounts = { swimmer = db.mountSwimmer, flyer = db.mountFlyer, ground = db.mountGround }
    for _, mac in ipairs(M.SmartMacros(kickName, mounts)) do
        if #mac.body > 255 then mac.body = mac.body:sub(1, 255) end
        local index = GetMacroIndexByName(mac.name)
        if index and index > 0 then
            EditMacro(index, mac.name, mac.icon, mac.body)
            n = n + 1
        else
            local _, perChar = GetNumMacros()
            if perChar < (_G.MAX_CHARACTER_MACROS or 18) then
                CreateMacro(mac.name, mac.icon, mac.body, true)
                n = n + 1
            end
        end
    end
    ns:Print(L.AUTO_MACROS_DONE:format(n))
    return n
end

-- GUI-only macro helpers (t191): put a PUI macro on the cursor, or open the game's macro window.
function M:PickupSmartMacro(name)
    if InCombatLockdown() then ns:Print(L.AUTO_MACROS_COMBAT); return false end
    local index = GetMacroIndexByName(name)
    if not index or index == 0 then
        self:WriteSmartMacros()
        index = GetMacroIndexByName(name)
    end
    if index and index > 0 then PickupMacro(index); return true end
    ns:Print(L.AUTO_MACROS_MISSING)
    return false
end

function M.OpenMacroWindow()
    if InCombatLockdown() then ns:Print(L.AUTO_MACROS_COMBAT); return false end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_MacroUI") end
    if type(ShowMacroFrame) == "function" then ShowMacroFrame(); return true end
    if MacroFrame and MacroFrame.Show then MacroFrame:Show(); return true end
    return false
end
