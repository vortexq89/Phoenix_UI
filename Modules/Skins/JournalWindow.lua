local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix Adventure Guide window: our own dungeon and raid browser fed by the encounter journal API.
    Dungeons / Raids tabs and the expansion (tier) stepper, the tier's instances as Phoenix rows, the picked
    instance's bosses, and the picked boss's description with its loot (the items' own icons, tooltips,
    shift-click links). Journeys, the Traveler's Log, suggested content and the boss ability tree stay in
    Blizzard's guide (the arrow button, this visit). The journal's own selection calls are used, so Blizzard's
    guide opens where you left off. Skins > "Phoenix Adventure Guide window" off: Blizzard's guide,
    reskinned, live. ]]

local COL_W, ROWS, ROW_H, LOOT = 220, 11, 34, 16
local r, instances, bosses
local raid, instanceID, encounterID = false, nil, nil

function M.JournalInstances(isRaid)
    local out = {}
    for i = 1, 200 do
        local id, name = EJ_GetInstanceByIndex(i, isRaid)
        if not id then break end
        out[#out + 1] = { id = id, name = tostring(name or "") }
    end
    return out
end

function M.JournalBosses()
    local out = {}
    for i = 1, 40 do
        local name, _, id = EJ_GetEncounterInfoByIndex(i)
        if not name then break end
        out[#out + 1] = { id = id, name = tostring(name) }
    end
    return out
end

local function loot()
    local out = {}
    if not (C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex) then return out end
    for i = 1, math.min(LOOT, tonumber(EJ_GetNumLoot()) or 0) do
        local info = C_EncounterJournal.GetLootInfoByIndex(i)
        if type(info) == "table" and info.name then out[#out + 1] = info end
    end
    return out
end

local function lootButton(i)
    local b = r.loot[i]
    if b then return b end
    b = CreateFrame("Button", nil, r.detail)
    b:SetSize(30, 30)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    Skin:Border(b, "border.subtle")
    b:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        if self.link and IsModifiedClick("CHATLINK") then ChatFrameUtil.InsertLink(self.link) end
    end)
    r.loot[i] = b
    return b
end

local function layout()
    r.tabs.Paint(raid and "raid" or "dungeon")
    local tier = tonumber(EJ_GetCurrentTier and EJ_GetCurrentTier()) or 1
    r.tier:SetText(tostring((EJ_GetTierInfo(tier)) or ""))
    local list = M.JournalInstances(raid)
    local found
    for _, inst in ipairs(list) do if inst.id == instanceID then found = true end end
    if not found then instanceID = list[1] and list[1].id; encounterID = nil end
    instances.Set(list, function(b, inst)
        b.title:SetText(inst.name); b.sub:SetText(""); b.right:SetText("")
        if inst.id == instanceID then instances.Mark(b, "accent.primary", 0.25); instances.Bar(b, "accent.primary") end
    end)
    local blist = {}
    if instanceID then
        EJ_SelectInstance(instanceID)
        blist = M.JournalBosses()
    end
    local bfound
    for _, bo in ipairs(blist) do if bo.id == encounterID then bfound = true end end
    if not bfound then encounterID = blist[1] and blist[1].id end
    bosses.Set(blist, function(b, bo)
        b.title:SetText(bo.name); b.sub:SetText(""); b.right:SetText("")
        if bo.id == encounterID then bosses.Mark(b, "accent.primary", 0.25); bosses.Bar(b, "accent.primary") end
    end)
    for _, b in ipairs(r.loot) do b:Hide() end
    if encounterID then
        EJ_SelectEncounter(encounterID)
        local name, desc = EJ_GetEncounterInfo(encounterID)
        r.name:SetText(tostring(name or ""))
        r.desc:SetText(tostring(desc or ""))
        for i, item in ipairs(loot()) do
            local b = lootButton(i)
            b.link = item.link
            b.icon:SetTexture(item.icon)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", r.desc, "BOTTOMLEFT", ((i - 1) % 8) * 34, -10 - math.floor((i - 1) / 8) * 34)
            b:Show()
        end
    else
        r.name:SetText(""); r.desc:SetText("")
    end
end

local function step(d)
    local n = tonumber(EJ_GetNumTiers()) or 1
    local cur = tonumber(EJ_GetCurrentTier()) or 1
    EJ_SelectTier(math.max(1, math.min(n, cur + d)))
    instanceID, encounterID = nil, nil
    instances.offset, bosses.offset = 0, 0
    r:Layout()
end

local function build(rr)
    r = rr
    r.loot = {}
    r.tabs = M.ReplaceTabs(r.body, { { key = "dungeon", label = L.EJW_DUNGEONS }, { key = "raid", label = L.EJW_RAIDS } }, 100,
        function(key) raid = key == "raid"; instanceID, encounterID = nil, nil; r:Layout() end)
    r.prev = W:IconButton(r.body, "reset", 22, PREV or "<")
    r.prev:SetPoint("TOPLEFT", 220, 0)
    r.prev.onClick = function() step(-1) end
    r.tier = W.Text(r.body, "body", "accent.primary")
    r.tier:SetPoint("LEFT", r.prev, "RIGHT", 8, 0)
    r.next = W:IconButton(r.body, "play", 22, NEXT or ">")
    r.next:SetPoint("LEFT", r.tier, "RIGHT", 8, 0)
    r.next.onClick = function() step(1) end
    instances = M.ReplaceList(r.body, ROWS, ROW_H, COL_W)
    instances:SetPoint("TOPLEFT", 0, -32)
    instances.onClick = function(inst) instanceID, encounterID = inst.id, nil; bosses.offset = 0; r:Layout() end
    bosses = M.ReplaceList(r.body, ROWS, ROW_H, COL_W)
    bosses:SetPoint("TOPLEFT", COL_W + 10, -32)
    bosses.onClick = function(bo) encounterID = bo.id; r:Layout() end
    r.detail = CreateFrame("Frame", nil, r.body)
    r.detail:SetPoint("TOPLEFT", 2 * COL_W + 20, -32)
    r.detail:SetPoint("BOTTOMRIGHT")
    r.name = W.Text(r.detail, "heading", "accent.primary"); r.name:SetPoint("TOPLEFT", 10, -8)
    r.desc = W.Text(r.detail, "small", "text.secondary"); r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -8)
    r.desc:SetPoint("RIGHT", -10, 0); r.desc:SetJustifyH("LEFT"); r.desc:SetJustifyV("TOP"); r.desc:SetHeight(150)
    Skin:Panel(r.detail, "sunken", { border = "border.subtle" })
end

local ej = M.Replacement({ key = "ownJournal", frame = "EncounterJournal", title = L.EJW_TITLE,
    width = 3 * COL_W + 140, height = 34 + 32 + ROWS * ROW_H + 24, build = build, layout = layout,
    close = function() local f = _G.EncounterJournal; if f then HideUIPanel(f) end end })
M.JournalReplacement = ej

function M:SetupJournalWindow()
    if not M.ReplacementHook(ej) then return end
    for _, event in ipairs({ "EJ_LOOT_DATA_RECIEVED", "EJ_DIFFICULTY_UPDATE" }) do
        ns.Events:On(event, ej, function() ej:Soon() end)
    end
    ej:Sync()
end
function M:SyncJournal() ej:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupJournalWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncJournal"
