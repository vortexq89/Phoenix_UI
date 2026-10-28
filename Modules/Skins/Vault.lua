local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Great Vault, skins plan window 20: every reward slot (raid, dungeon, world / PvP rows) on a raised Phoenix
    card outlined in the accent once unlocked, Select reward as the primary button. Reward icons are the
    game's own; choosing stays Blizzard's click.
    Live both ways with its Skins switch, repainted on theme change (kit rows / cards). ]]

local function on() return M:IsEnabled() and M.db.vault and true or false end

-- An activity card is outlined in the accent once its slot is unlocked (plain progress numbers).
function M.VaultUnlocked(info)
    if type(info) ~= "table" then return false end
    local p, t = tonumber(info.progress), tonumber(info.threshold)
    return p ~= nil and t ~= nil and t > 0 and p >= t
end

function M:SkinVault()
    local wr = _G.WeeklyRewardsFrame
    if not wr then return end
    local isOn = on()
    local acts = rawget(wr, "Activities")
    if type(acts) ~= "table" then M.FramePath(wr, { "Activities" }); return end
    for _, a in ipairs(acts) do
        local card = M.KitCard(a, isOn, "raised", false)
        if card and isOn then
            ns.Skin:SetBorderColor(card, M.VaultUnlocked(rawget(a, "info")) and "accent.primary" or "border.subtle")
        end
    end
    M.SkinPopupButton(rawget(wr, "SelectRewardButton"), "primary", isOn)
end

local vaultHooked
function M:SetupVault()
    self:SkinVault()
    local root = _G.WeeklyRewardsFrame
    if vaultHooked or not root then return end
    vaultHooked = true
    root:HookScript("OnShow", function() M:SkinVault() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupVault"
M.RESKINS[#M.RESKINS + 1] = "SkinVault"
