local _, ns = ...
local L, W = ns.L, ns.Widgets
local M = ns:GetModule("Skins")

--[[ The Phoenix quest log: our own quest list in place of the list beside the world map, fed by C_QuestLog. Zone
    headers collapse, each quest shows its level, a complete / tracked / daily mark and its first unfinished
    objective; a search box over titles and objectives. Click: Blizzard's quest details (abandon, share and the
    map stay Blizzard's), right-click: track / untrack, shift-click: link in chat.
    Skins > "Phoenix quest log" off (or the arrow): Blizzard's list, live. ]]

local ROW_H = 34
local list
local search = ""

local function objectiveLine(questID)
    local objs = C_QuestLog.GetQuestObjectives(questID)
    for _, ob in ipairs(type(objs) == "table" and objs or {}) do
        if type(ob) == "table" and not ob.finished and ob.text then return tostring(ob.text) end
    end
    return ""
end

-- Headers and quests in the log's order; quests under a collapsed header are not in the log's list.
function M.QuestRows()
    local out = {}
    local needle = search:lower()
    local header
    for i = 1, tonumber(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local q = C_QuestLog.GetInfo(i)
        if type(q) == "table" and not q.isHidden then
            if q.isHeader then
                header = { header = true, index = i, name = tostring(q.title or ""), open = not q.isCollapsed }
                out[#out + 1] = header
            elseif q.questID then
                local obj = objectiveLine(q.questID)
                local title = tostring(q.title or "")
                if needle == "" or (title .. " " .. obj):lower():find(needle, 1, true) then
                    out[#out + 1] = { id = q.questID, name = title, level = tonumber(q.level) or 0, obj = obj,
                        complete = C_QuestLog.IsComplete(q.questID) and true or false,
                        tracked = C_QuestLog.GetQuestWatchType(q.questID) ~= nil,
                        daily = (tonumber(q.frequency) or 0) > 0 }
                end
            end
        end
    end
    if needle ~= "" then -- headers left without matches are dropped while searching
        local kept = {}
        for i, r in ipairs(out) do
            if not r.header or (out[i + 1] and not out[i + 1].header) then kept[#kept + 1] = r end
        end
        out = kept
    end
    return out
end

local function rows(o)
    local h = (tonumber(o.panel:GetHeight()) or 0) > 0 and o.panel:GetHeight() or 480
    return math.max(4, math.floor((h - 44) / ROW_H))
end

local function onClick(o, q, button)
    if q.header then
        local fn = _G[q.open and "CollapseQuestHeader" or "ExpandQuestHeader"]
        if fn then fn(q.index) end
        o:Soon()
        return
    end
    if IsModifiedClick("CHATLINK") and GetQuestLink then ChatFrameUtil.InsertLink(GetQuestLink(q.id)); return end
    if button == "RightButton" then
        if q.tracked then C_QuestLog.RemoveQuestWatch(q.id) else C_QuestLog.AddQuestWatch(q.id) end
        o:Soon()
        return
    end
    local show = _G.QuestMapFrame_ShowQuestDetails
    if show then show(q.id) end
end

local function layout(o)
    local p = o.panel
    if not list or #list.rows ~= rows(o) then
        if list then list:Hide() end
        list = M.ReplaceList(p, rows(o), ROW_H, math.max(160, (tonumber(p:GetWidth()) or 280) - 16))
        list:SetPoint("TOPLEFT", 8, -38)
        list.onClick = function(q, button) onClick(o, q, button) end
        list.onEnter = function(q, b)
            if q.header then return end
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(GetQuestLink and GetQuestLink(q.id) or ("quest:" .. q.id))
            GameTooltip:Show()
        end
    end
    list.Set(M.QuestRows(), function(b, q)
        if q.header then
            b.title:SetText((q.open and "- " or "+ ") .. q.name)
            b.sub:SetText(""); b.right:SetText("")
            list.Mark(b, "bg.hover", 0.8)
            return
        end
        b.title:SetText(("[%d] %s"):format(q.level, q.name))
        b.sub:SetText(q.complete and L.QLOGW_COMPLETE or q.obj)
        b.right:SetText((q.daily and L.QLOGW_DAILY or "") .. (q.tracked and "  *" or ""))
        if q.complete then list.Bar(b, "state.success") elseif q.tracked then list.Bar(b, "accent.primary") end
    end)
end

local function build(o)
    local p = o.panel
    p.search = W:Input(p, 180, SEARCH or "")
    p.search:SetPoint("TOPLEFT", 8, -8)
    p.search.onTextChanged = function(_, text) search = text or ""; if list then list.offset = 0 end; o:Layout() end
end

local qlog = M.Overlay({ key = "ownQuestLog", build = build, layout = layout,
    host = function() local q = _G.QuestMapFrame; return q and (q.QuestsFrame or _G.QuestScrollFrame) end })
M.QuestLogOverlay = qlog
function M.QuestLogSearch(text) search = text or "" end

function M:SetupQuestLogWindow()
    if not qlog:Hook() then return end
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED" }) do
        ns.Events:On(event, qlog, function() qlog:Soon() end)
    end
    qlog:Sync()
end
function M:SyncQuestLogWindow() qlog:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupQuestLogWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncQuestLogWindow"
