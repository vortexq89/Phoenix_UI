local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix Great Vault window: our own view of this week's vault fed by C_WeeklyRewards. One row per
    track (raid, dungeons, world), three slot cards each with a progress ring (the shared paused-cooldown ring,
    no OnUpdate), "progress / threshold" and, once unlocked, the reward's item level. When rewards are ready
    to pick, Blizzard's vault opens instead, so choosing a reward is always Blizzard's own window and your
    click. Skins > "Phoenix Great Vault window" off: Blizzard's vault, reskinned, live. ]]

local CARD_W, CARD_H, GAP, LABEL_W = 150, 84, 8, 110
local r

function M.VaultTracks()
    local T = Enum.WeeklyRewardChestThresholdType or {}
    return { { kind = T.Raid, label = L.VAULTW_RAID }, { kind = T.Activities, label = L.VAULTW_DUNGEONS },
        { kind = T.World, label = L.VAULTW_WORLD } }
end

-- Activities of one track in slot order, as plain values.
function M.VaultSlots(kind)
    local out = {}
    local all = C_WeeklyRewards and C_WeeklyRewards.GetActivities and C_WeeklyRewards.GetActivities(kind) or {}
    for _, a in ipairs(type(all) == "table" and all or {}) do
        if type(a) == "table" then
            out[#out + 1] = { index = tonumber(a.index) or (#out + 1), progress = tonumber(a.progress) or 0,
                threshold = tonumber(a.threshold) or 0, level = tonumber(a.level) or 0, id = a.id }
        end
    end
    table.sort(out, function(x, y) return x.index < y.index end)
    return out
end

local function rewardLevel(slot)
    if not (slot.id and C_WeeklyRewards.GetExampleRewardItemHyperlinks) then return nil end
    local link = C_WeeklyRewards.GetExampleRewardItemHyperlinks(slot.id)
    if type(link) ~= "string" then return nil end
    return tonumber((C_Item.GetDetailedItemLevelInfo(link)))
end

local function layout()
    for t, track in ipairs(M.VaultTracks()) do
        r.labels[t]:SetText(track.label)
        local slots = M.VaultSlots(track.kind)
        for s = 1, 3 do
            local c = r.cards[t][s]
            local slot = slots[s]
            if slot then
                local frac = M.VaultFraction(slot)
                local done = frac >= 1
                c.text:SetText(("%d / %d"):format(slot.progress, slot.threshold))
                local ilvl = done and rewardLevel(slot)
                c.reward:SetText(done and (ilvl and L.VAULTW_ILVL:format(ilvl) or L.VAULTW_UNLOCKED) or L.VAULTW_LOCKED)
                Skin:Text(c.reward, "small", done and "accent.primary" or "text.muted", 11)
                Skin:Panel(c, done and "hover" or "raised", { border = done and "accent.primary" or "border.subtle" })
                M.VaultRing(c, slot, true)
                c:Show()
            else
                c:Hide()
            end
        end
    end
end

local function build(rr)
    r = rr
    r.labels, r.cards = {}, {}
    for t = 1, 3 do
        local y = -(t - 1) * (CARD_H + GAP)
        local lab = W.Text(r.body, "heading", "text.primary")
        lab:SetPoint("TOPLEFT", 0, y - CARD_H / 2 + 8)
        r.labels[t] = lab
        r.cards[t] = {}
        for s = 1, 3 do
            local c = CreateFrame("Frame", nil, r.body)
            c:SetSize(CARD_W, CARD_H)
            c:SetPoint("TOPLEFT", LABEL_W + (s - 1) * (CARD_W + GAP), y)
            c.text = W.Text(c, "heading", "text.primary"); c.text:SetPoint("CENTER", 0, 6)
            c.reward = W.Text(c, "small", "text.muted"); c.reward:SetPoint("BOTTOM", 0, 8)
            r.cards[t][s] = c
        end
    end
end

local function canPick()
    return C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards() or false
end

local vault = M.Replacement({ key = "ownVault", frame = "WeeklyRewardsFrame", title = L.VAULTW_TITLE,
    width = LABEL_W + 3 * (CARD_W + GAP) + 12, height = 34 + 3 * (CARD_H + GAP) + 20, build = build, layout = layout,
    ready = function() return not canPick() end,
    close = function() if WeeklyRewardsFrame then HideUIPanel(WeeklyRewardsFrame) end end })
M.VaultReplacement = vault

function M:SetupVaultWindow()
    if not M.ReplacementHook(vault) then return end
    ns.Events:On("WEEKLY_REWARDS_UPDATE", vault, function() vault:Sync() end)
    vault:Sync()
end
function M:SyncVault() vault:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupVaultWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncVault"
