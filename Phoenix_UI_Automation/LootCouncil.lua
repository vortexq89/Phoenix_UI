-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L = ns.L
local M = ns.modules.Automation
local Secret = ns.Secret

--[[ Loot council: a window of this session's boss drops in your group (who got what). "Want" tells the group,
    with your equipped item level in that slot, so the looter sees who could use a tradeable piece. Phoenix users
    see each other's interest (addon message "PUI_LC"); nothing is sent unless you click. Event driven. ]]

local PREFIX, MAX = "PUI_LC", 20
M.lcDrops = M.lcDrops or {}

-- inventory type -> equipped slot ids to compare against
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_RANGED = { 16 }, INVTYPE_RANGEDRIGHT = { 16 },
}
M.LC_SLOTS = SLOTS

-- lowest equipped item level among the slots the item would go in (0 when empty or unknown)
function M.EquippedLevelFor(itemID)
    local equip = C_Item and C_Item.GetItemInfo and select(9, C_Item.GetItemInfo(itemID))
    local slots = equip and SLOTS[equip]
    if not slots then return 0 end
    local low
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        local lvl = link and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link) or 0
        low = math.min(low or lvl, lvl)
    end
    return math.floor(low or 0)
end

function M.EncodeWant(itemID, level) return ("W\t%d\t%d"):format(itemID, level) end
function M.DecodeWant(text)
    local id, lvl = text:match("^W\t(%d+)\t(%d+)$")
    if id then return tonumber(id), tonumber(lvl) end
end

local function channel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

function M:AddDrop(itemID, link, looter, class)
    local list = M.lcDrops
    table.insert(list, 1, { id = itemID, link = link, looter = looter, class = class, wants = {} })
    while #list > MAX do table.remove(list) end
    if self.db.lootCouncilOpen and not InCombatLockdown() then self:ShowLootCouncil() else self:RefreshLootCouncil() end
end

function M:AddWant(itemID, who, level)
    for _, d in ipairs(M.lcDrops) do
        if d.id == itemID then d.wants[who] = level end
    end
    self:RefreshLootCouncil()
end

function M:SendWant(drop)
    local level = M.EquippedLevelFor(drop.id)
    local me = UnitName("player")
    self:AddWant(drop.id, me, level)
    local ch = channel()
    if ch then C_ChatInfo.SendAddonMessage(PREFIX, M.EncodeWant(drop.id, level), ch) end
end

local function onLoot(_, _, itemID, link, _, player, class)
    if not M.db.lootCouncil or Secret.IsSecret(link) or Secret.IsSecret(player) then return end
    if M.db.lootCouncilRaidOnly and not IsInRaid() then return end
    if type(itemID) == "number" and type(link) == "string" then M:AddDrop(itemID, link, player, class) end
end

local function onMessage(_, prefix, text, _, sender)
    if prefix ~= PREFIX or Secret.IsSecret(text) or type(text) ~= "string" or not M.db.lootCouncil then return end
    local id, lvl = M.DecodeWant(text)
    if id and type(sender) == "string" then
        local me = UnitName("player")
        local name = Ambiguate and Ambiguate(sender, "short") or sender
        if name ~= me then M:AddWant(id, name, lvl) end
    end
end

local owner = {}
function M:EnableLootCouncil()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
    ns.Events:On("ENCOUNTER_LOOT_RECEIVED", owner, onLoot)
    ns.Events:On("CHAT_MSG_ADDON", owner, onMessage)
end

-- "Name (639), Other (626)" sorted by the lowest equipped level first (biggest upgrade)
function M.WantText(wants)
    local list = {}
    for who, lvl in pairs(wants or {}) do list[#list + 1] = { who = who, lvl = lvl } end
    table.sort(list, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return a.who < b.who end)
    for i, w in ipairs(list) do list[i] = ("%s (%d)"):format(w.who, w.lvl) end
    return table.concat(list, ", ")
end

local win
local ROWS = 8
function M:RefreshLootCouncil()
    if not (win and win:IsShown()) then return end
    for i = 1, ROWS do
        local r, d = win.rows[i], M.lcDrops[i]
        if d then
            r.item:SetText(d.link .. "  |cffa0a0a0" .. (d.looter or "") .. "|r")
            local w = M.WantText(d.wants)
            r.wants:SetText(w ~= "" and L.LC_WANTS:format(w) or L.LC_NO_WANTS)
            r.drop = d
            r:Show()
        else
            r:Hide()
        end
    end
    win.empty:SetShown(#M.lcDrops == 0)
end

function M:ShowLootCouncil()
    local W = ns.Widgets
    if not win then
        win = W:Popup(L.LC_TITLE, 520, 120 + ROWS * 44, "items")
        win.empty = W.Text(win, "body", "text.secondary")
        win.empty:SetPoint("TOPLEFT", 18, -50); win.empty:SetText(L.LC_EMPTY)
        win.rows = {}
        for i = 1, ROWS do
            local r = CreateFrame("Frame", nil, win)
            r:SetSize(484, 40); r:SetPoint("TOPLEFT", 18, -46 - (i - 1) * 44)
            r.item = W.Text(r, "body", "text.primary"); r.item:SetPoint("TOPLEFT"); r.item:SetWidth(380)
            r.item:SetJustifyH("LEFT")
            r.wants = W.Text(r, "small", "text.secondary"); r.wants:SetPoint("TOPLEFT", r.item, "BOTTOMLEFT", 0, -4)
            r.wants:SetWidth(380); r.wants:SetJustifyH("LEFT")
            r.want = W:Button(r, L.LC_WANT, "ghost", "check", 90); r.want:SetPoint("RIGHT")
            r.want.onClick = function() if r.drop then M:SendWant(r.drop) end end
            win.rows[i] = r
        end
        win.clear = W:Button(win, L.LC_CLEAR, "ghost", "reset", 110); win.clear:SetPoint("BOTTOMRIGHT", -16, 14)
        win.clear.onClick = function() wipe(M.lcDrops); M:RefreshLootCouncil() end
    end
    win:Show()
    self:RefreshLootCouncil()
    return win
end
