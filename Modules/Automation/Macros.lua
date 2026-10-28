local _, ns = ...
local L = ns.L
local M = ns:GetModule("Automation")

--[[ Smart macros: one click writes (or updates) a few general macros, out of combat only:
      PUI Heal   - healthstone, then a healing potion
      PUI Kick   - your interrupt on the focus when there is a hostile one, else on your target
      PUI Mount  - a random favourite mount; dismounts when mounted
    They are character macros named "PUI …"; existing ones with those names are updated, nothing else is touched. ]]
-- icon 134400 is the question mark: with #showtooltip the macro shows the spell or item it will use
local HEALTHSTONE, POTIONS = 5512, { 211880, 211879, 211878, 191380, 191379, 191378, 187802 }

function M.SmartMacros(kickName)
    local heal = { "#showtooltip", "/use item:" .. HEALTHSTONE }
    for _, id in ipairs(POTIONS) do heal[#heal + 1] = "/use item:" .. id end
    local out = {
        { name = "PUI Heal", icon = 134400, body = table.concat(heal, "\n") },
        { name = "PUI Mount", icon = 134400,
          body = "#showtooltip\n/dismount [mounted]\n/run if not IsMounted() then C_MountJournal.SummonByID(0) end" },
    }
    if type(kickName) == "string" and kickName ~= "" then
        out[#out + 1] = { name = "PUI Kick", icon = 134400,
            body = ("#showtooltip %s\n/cast [@focus,exists,harm,nodead][] %s"):format(kickName, kickName) }
    end
    return out
end

function M:WriteSmartMacros()
    if InCombatLockdown() then ns:Print(L.AUTO_MACROS_COMBAT); return 0 end
    local cb = ns.modules.CastBars
    local kick = cb and cb.KickSpell and cb:KickSpell()
    local kickName = kick and C_Spell.GetSpellName(kick)
    local n = 0
    for _, mac in ipairs(M.SmartMacros(kickName)) do
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
