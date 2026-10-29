local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix Adventure Guide window: our own dungeon and raid browser fed by the encounter journal API.
    Dungeons / Raids tabs and the expansion (tier) stepper, the tier's instances as Phoenix rows, the picked
    instance's bosses, and the picked boss's description with its loot (the items' own icons, tooltips,
    shift-click links) or its ability tree (Abilities: sections with the game's own icons, click a section to
    open its children). Journeys tab: the renown factions with level and progress. Traveler's Log tab (retail):
    this month's activities with their requirement and points, completed ones dimmed, click to track or untrack
    (the game's own track calls). Suggested content stays in Blizzard's guide (the arrow button, this visit).
    The journal's own selection calls are used, so Blizzard's guide opens where you left off.
    Skins > "Phoenix Adventure Guide window" off: Blizzard's guide, reskinned, live. ]]

local COL_W, ROWS, ROW_H, LOOT = 220, 11, 34, 16
local r, instances, bosses
local raid, instanceID, encounterID = false, nil, nil
local view, detailTab, openSections = "dungeon", "overview", {}
local abilities, journeys

-- The boss's ability tree flattened for display: every section at depth 0, children of open ones below.
function M.JournalSections(rootID, open)
    local out = {}
    local function walk(id, depth, guard)
        while id and id > 0 and guard < 400 do
            guard = guard + 1
            local info = C_EncounterJournal.GetSectionInfo(id)
            if type(info) ~= "table" then return guard end
            if not info.filteredByDifficulty then
                local hasKids = (tonumber(info.firstChildSectionID) or 0) > 0
                out[#out + 1] = { id = id, depth = depth, title = tostring(info.title or ""), desc = info.description,
                    icon = info.abilityIcon, kids = hasKids }
                if hasKids and open[id] then guard = walk(info.firstChildSectionID, depth + 1, guard) end
            end
            id = tonumber(info.siblingSectionID)
        end
        return guard
    end
    walk(tonumber(rootID), 0, 0)
    return out
end

-- Renown factions (journeys) as rows: name, level, progress inside the level.
function M.JournalJourneys()
    local out = {}
    local ids = C_MajorFactions and C_MajorFactions.GetMajorFactionIDs and C_MajorFactions.GetMajorFactionIDs() or {}
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        local d = C_MajorFactions.GetMajorFactionData(id)
        if type(d) == "table" and d.name then
            local earned, need = tonumber(d.renownReputationEarned) or 0, tonumber(d.renownLevelThreshold) or 0
            out[#out + 1] = { id = id, name = tostring(d.name), level = tonumber(d.renownLevel) or 0,
                unlocked = d.isUnlocked ~= false, progress = need > 0 and earned / need or 0,
                count = ("%d / %d"):format(earned, need) }
        end
    end
    return out
end

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

local function layoutJourneys()
    journeys.Set(M.JournalJourneys(), function(b, j)
        b.title:SetText(j.name)
        b.sub:SetText(L.EJW_RENOWN:format(j.level))
        b.right:SetText(j.count)
        if not j.unlocked then b.title:SetAlpha(0.5) else b.title:SetAlpha(1) end
        journeys.Progress(b, j.progress)
    end)
end

-- This month's Traveler's Log: { id, name, req, points, done, tracked }, open ones first.
function M.TravelersLog()
    local api = _G.C_PerksActivities
    local info = api and api.GetPerksActivitiesInfo and api.GetPerksActivitiesInfo()
    local out = {}
    if type(info) ~= "table" or type(info.activities) ~= "table" then return out end
    for _, a in ipairs(info.activities) do
        local req = type(a.requirementsList) == "table" and a.requirementsList[1]
        out[#out + 1] = { id = a.ID, name = tostring(a.activityName or ""), done = a.completed and true or false,
            tracked = a.tracked and true or false, points = tonumber(a.thresholdContributionAmount) or 0,
            req = req and tostring(req.requirementText or "") or "" }
    end
    table.sort(out, function(x, y)
        if x.done ~= y.done then return not x.done end
        if x.tracked ~= y.tracked then return x.tracked end
        return x.name < y.name
    end)
    return out
end

local function layoutLog()
    journeys.Set(M.TravelersLog(), function(b, a)
        b.title:SetText(a.name)
        b.sub:SetText(a.req)
        b.right:SetText(a.points > 0 and ("+" .. a.points) or "")
        b.title:SetAlpha(a.done and 0.5 or 1)
        if a.tracked then journeys.Mark(b, "accent.primary", 0.25); journeys.Bar(b, "accent.primary") end
    end)
end

local function toggleTrack(a)
    local api = _G.C_PerksActivities
    if not (api and a and a.id) or a.done then return end
    if a.tracked then api.RemoveTrackedPerksActivity(a.id) else api.AddTrackedPerksActivity(a.id) end
end

local function layoutAbilities(rootID)
    abilities.Set(M.JournalSections(rootID, openSections), function(b, sec)
        b.icon:SetTexture(sec.icon)
        b.title:SetText(("%s%s%s"):format(("  "):rep(sec.depth), sec.kids and (openSections[sec.id] and "- " or "+ ") or "",
            sec.title))
        b.sub:SetText("")
        b.right:SetText("")
        if sec.depth == 0 then abilities.Bar(b, "accent.primary") end
    end)
end

local function layout()
    r.tabs.Paint(view)
    local isJourney = view == "journeys" or view == "log"
    for _, el in ipairs({ instances, bosses, r.detail, r.prev, r.next, r.tier }) do el:SetShown(not isJourney) end
    journeys:SetShown(isJourney)
    journeys.onClick = view == "log" and function(a) toggleTrack(a); r:Layout() end or nil
    if view == "log" then layoutLog(); return end
    if isJourney then layoutJourneys(); return end
    raid = view == "raid"
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
    r.detailTabs.Paint(detailTab)
    abilities:SetShown(detailTab == "abilities" and encounterID ~= nil)
    r.desc:SetShown(detailTab == "overview")
    if encounterID then
        EJ_SelectEncounter(encounterID)
        local name, desc, _, rootID = EJ_GetEncounterInfo(encounterID)
        r.name:SetText(tostring(name or ""))
        r.desc:SetText(tostring(desc or ""))
        if detailTab == "abilities" then layoutAbilities(rootID); return end
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
    local tabs = { { key = "dungeon", label = L.EJW_DUNGEONS }, { key = "raid", label = L.EJW_RAIDS },
        { key = "journeys", label = L.EJW_JOURNEYS } }
    if _G.C_PerksActivities then tabs[#tabs + 1] = { key = "log", label = L.EJW_LOG } end
    r.tabs = M.ReplaceTabs(r.body, tabs, 100,
        function(key) view = key; instanceID, encounterID = nil, nil; r:Layout() end)
    r.prev = W:IconButton(r.body, "reset", 22, PREV or "<")
    r.prev:SetPoint("TOPLEFT", 330, 0)
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
    bosses.onClick = function(bo) encounterID, openSections = bo.id, {}; r:Layout() end
    r.detail = CreateFrame("Frame", nil, r.body)
    r.detail:SetPoint("TOPLEFT", 2 * COL_W + 20, -32)
    r.detail:SetPoint("BOTTOMRIGHT")
    r.name = W.Text(r.detail, "heading", "accent.primary"); r.name:SetPoint("TOPLEFT", 10, -8)
    r.desc = W.Text(r.detail, "small", "text.secondary"); r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -8)
    r.desc:SetPoint("RIGHT", -10, 0); r.desc:SetJustifyH("LEFT"); r.desc:SetJustifyV("TOP"); r.desc:SetHeight(150)
    Skin:Panel(r.detail, "sunken", { border = "border.subtle" })
    r.detailTabs = M.ReplaceTabs(r.detail, { { key = "overview", label = L.EJW_OVERVIEW }, { key = "abilities", label = L.EJW_ABILITIES } },
        90, function(key) detailTab = key; r:Layout() end)
    r.detailTabs.buttons.overview:ClearAllPoints()
    r.detailTabs.buttons.overview:SetPoint("BOTTOMLEFT", r.detail, "BOTTOMLEFT", 8, 8)
    abilities = M.ReplaceList(r.detail, 9, 30, COL_W + 100, 22)
    abilities:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", -4, -8)
    abilities.onClick = function(sec)
        if sec.kids then openSections[sec.id] = not openSections[sec.id] or nil; r:Layout() end
    end
    abilities.onEnter = function(sec, b)
        if not sec.desc then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:AddLine(sec.title, 1, 1, 1)
        GameTooltip:AddLine(tostring(sec.desc), nil, nil, nil, true)
        GameTooltip:Show()
    end
    journeys = M.ReplaceList(r.body, ROWS, ROW_H, 3 * COL_W + 100)
    journeys:SetPoint("TOPLEFT", 0, -32)
    journeys:Hide()
end

local ej = M.Replacement({ key = "ownJournal", frame = "EncounterJournal", title = L.EJW_TITLE,
    width = 3 * COL_W + 140, height = 34 + 32 + ROWS * ROW_H + 24, build = build, layout = layout,
    close = function() local f = _G.EncounterJournal; if f then HideUIPanel(f) end end })
M.JournalReplacement = ej

function M:SetupJournalWindow()
    if not M.ReplacementHook(ej) then return end
    local events = { "EJ_LOOT_DATA_RECIEVED", "EJ_DIFFICULTY_UPDATE" }
    if _G.C_PerksActivities then
        events[#events + 1] = "PERKS_ACTIVITIES_TRACKED_UPDATED"
        events[#events + 1] = "PERKS_ACTIVITY_COMPLETED"
    end
    for _, event in ipairs(events) do
        ns.Events:On(event, ej, function() ej:Soon() end)
    end
    ej:Sync()
end
function M:SyncJournal() ej:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupJournalWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncJournal"
