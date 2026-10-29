local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix gossip window: our own NPC dialog fed by C_GossipInfo. The NPC's portrait and name, the greeting
    text (scrolls when long), then Available quests, Quests in progress (ready ones marked) and Options, each row with
    the game's own icon for it (quest offer / turn-in icons drawn by the game's QuestUtil, option icons from the
    gossip data). A click is the game's own select call, as Blizzard's button would make it; gold-cost and other
    confirmations stay Blizzard's popups, and Goodbye closes the dialog.

    Safety: Blizzard's GossipFrame stays open the whole visit (Escape, the hand-over to the quest window and every
    "is gossip open" check behave as usual); the shared Replacement shell tucks it. Special gossip frames (a
    texture kit's own dialog) never show GossipFrame and stay Blizzard's. Skins > "Phoenix gossip window" off:
    Blizzard's dialog, reskinned, live; the arrow button shows Blizzard's for this visit. ]]

local ROWS, ROW_H, WIDTH, ICON, TEXT_H = 10, 30, 340, 18, 96
local r

local function flag(flags, name)
    local e = Enum.GossipOptionRecFlags and Enum.GossipOptionRecFlags[name]
    return e and type(flags) == "number" and bit.band(flags, e) ~= 0 or false
end

-- The option's label with the game's own "(Quest)" / "(Play movie)" prefixes.
function M.GossipOptionText(o)
    local pre = {}
    if flag(o.flags, "QuestLabelPrepend") then pre[#pre + 1] = QUEST_PREPEND end
    if flag(o.flags, "PlayMovieLabelPrepend") then pre[#pre + 1] = PLAY_MOVIE_PREPEND end
    local name = tostring(o.name or "")
    if #pre > 0 and GOSSIP_OPTION_PREPEND then return GOSSIP_OPTION_PREPEND:format(table.concat(pre, " "), name) end
    return name
end

-- Every row of the dialog in Blizzard's order: available quests, active quests, options; a header before each group.
function M.GossipRows(api)
    api = api or C_GossipInfo
    local rows = {}
    local function group(label, list, kind)
        if type(list) ~= "table" or #list == 0 then return end
        rows[#rows + 1] = { kind = "header", text = label }
        for _, info in ipairs(list) do rows[#rows + 1] = { kind = kind, info = info } end
    end
    group(L.GOSSIPW_AVAILABLE, api.GetAvailableQuests and api.GetAvailableQuests(), "available")
    group(L.GOSSIPW_ACTIVE, api.GetActiveQuests and api.GetActiveQuests(), "active")
    local options = api.GetOptions and api.GetOptions() or {}
    table.sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    group(L.GOSSIPW_OPTIONS, options, "option")
    return rows
end

function M:GossipPick(row)
    if not row or row.kind == "header" then return end
    local info = row.info
    if row.kind == "available" then C_GossipInfo.SelectAvailableQuest(info.questID)
    elseif row.kind == "active" then C_GossipInfo.SelectActiveQuest(info.questID)
    else C_GossipInfo.SelectOptionByIndex(info.orderIndex or 0) end
end

local function questIcon(tex, row)
    local q, util = row.info, QuestUtil
    if not util then tex:SetTexture(nil); return end
    if row.kind == "available" and util.ApplyQuestIconOfferToTextureForQuestID then
        util.ApplyQuestIconOfferToTextureForQuestID(tex, q.questID, q.isLegendary, q.frequency, q.isRepeatable, q.isImportant,
            q.isMeta, q.questInfoID)
    elseif util.ApplyQuestIconActiveToTextureForQuestID then
        util.ApplyQuestIconActiveToTextureForQuestID(tex, q.questID, q.isComplete, q.isLegendary, q.frequency, q.isRepeatable,
            q.isImportant, q.isMeta, q.questInfoID)
    end
end

local function paint(b, row)
    b.icon:SetTexCoord(0, 1, 0, 1)
    b.icon:SetVertexColor(1, 1, 1, 1)
    b.right:SetText("")
    b.sub:SetText("")
    if row.kind == "header" then
        b.icon:SetTexture(nil)
        b.title:SetText(row.text)
        Skin:Text(b.title, "small", "text.muted")
        r.list.Mark(b, "bg.raised", 0)
        return
    end
    Skin:Text(b.title, "body", "text.primary")
    local info = row.info
    if row.kind == "option" then
        b.icon:SetTexture(info.overrideIconID or info.icon)
        b.title:SetText(M.GossipOptionText(info))
        return
    end
    questIcon(b.icon, row)
    b.title:SetText(tostring(info.title or ""))
    if info.isIgnored or info.isTrivial then
        Skin:Text(b.title, "body", "text.muted")
        b.icon:SetVertexColor(0.5, 0.5, 0.5, 1)
        b.right:SetText(info.isIgnored and L.GOSSIPW_IGNORED or L.GOSSIPW_TRIVIAL)
    end
    if row.kind == "active" and info.isComplete then
        r.list.Bar(b, "state.success")
        b.right:SetText(L.GOSSIPW_READY)
    end
end

local function onEnter(row, b)
    if row.kind == "option" and row.info.spellID and GameTooltip.SetSpellByID then
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(row.info.spellID)
        GameTooltip:Show()
    end
end

local function layout()
    local rows = M.GossipRows()
    r.list.Set(rows, paint)
    -- The NPC's name may be secret: then it only goes to SetText, never tested.
    local name = UnitName and UnitName("npc")
    if ns.Secret.IsSecret and ns.Secret.IsSecret(name) then r.win.title:SetText(name)
    else r.win.title:SetText(type(name) == "string" and name ~= "" and name or L.GOSSIPW_TITLE) end
    local hasPortrait = M.db.gossipPortrait and UnitExists and UnitExists("npc")
    r.portrait:SetShown(hasPortrait and true or false)
    r.frame:SetShown(hasPortrait and true or false)
    if hasPortrait then SetPortraitTexture(r.portrait, "npc") end
    r.scroll:ClearAllPoints()
    r.scroll:SetPoint("TOPLEFT", hasPortrait and 58 or 0, 0)
    r.scroll:SetPoint("RIGHT", 0, 0)
    r.scroll:SetHeight(TEXT_H)
    r.text:SetWidth(WIDTH - (hasPortrait and 58 or 0) - 6)
    local text = C_GossipInfo.GetText and C_GossipInfo.GetText()
    r.text:SetText(type(text) == "string" and text or "")
    r.scroll:SetVerticalScroll(0)
    local shown = math.max(1, math.min(ROWS, #rows))
    r.win:SetHeight(34 + 20 + TEXT_H + 8 + shown * ROW_H + 36)
end

local function build(rr)
    r = rr
    r.portrait = r.body:CreateTexture(nil, "ARTWORK")
    r.portrait:SetSize(50, 50)
    r.portrait:SetPoint("TOPLEFT", 0, 0)
    r.frame = CreateFrame("Frame", nil, r.body)
    r.frame:SetPoint("TOPLEFT", r.portrait, -1, 1)
    r.frame:SetPoint("BOTTOMRIGHT", r.portrait, 1, -1)
    Skin:Border(r.frame, "accent.primary")
    r.scroll = CreateFrame("ScrollFrame", nil, r.body)
    r.text = W.Text(r.scroll, "body", "text.secondary")
    r.text:SetWordWrap(true)
    r.text:SetJustifyV("TOP")
    local child = CreateFrame("Frame", nil, r.scroll)
    child:SetSize(WIDTH, 1)
    r.text:SetParent(child)
    r.text:SetPoint("TOPLEFT", 0, 0)
    r.scroll:SetScrollChild(child)
    r.scroll:EnableMouseWheel(true)
    r.scroll:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, (r.text:GetStringHeight() or 0) - TEXT_H)
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 20)))
    end)
    r.list = M.ReplaceList(r.body, ROWS, ROW_H, WIDTH, ICON)
    r.list:SetPoint("TOPLEFT", 0, -(TEXT_H + 8))
    r.list.onClick = function(row) M:GossipPick(row) end
    r.list.onEnter = onEnter
    r.bye = W:Button(r.body, GOODBYE or CLOSE, "secondary", nil, 120)
    r.bye:SetHeight(24)
    r.bye:SetPoint("BOTTOMRIGHT", 0, 0)
    r.bye.onClick = function() C_GossipInfo.CloseGossip() end
end

local gossip
local place, mover, reposition = M.ReplacePlace("gossipPlace", "gossipPos", "GossipFrame", function() return gossip end)

gossip = M.Replacement({ key = "ownGossip", frame = "GossipFrame", title = L.GOSSIPW_TITLE,
    width = WIDTH + 20, height = 34 + 20 + TEXT_H + 8 + ROWS * ROW_H + 36, build = build, layout = layout,
    place = place, mover = mover, close = function() C_GossipInfo.CloseGossip() end })
M.GossipReplacement = gossip

function M:SetupGossipWindow()
    if gossip.listening then gossip:Sync(); return end
    if not M.ReplacementHook(gossip) then return end
    gossip.listening = true
    -- GOSSIP_SHOW also comes while the dialog is open (a new page of options): repaint then.
    ns.Events:On("GOSSIP_SHOW", gossip, function() gossip:Soon() end)
    ns.Events:On("QUEST_LOG_UPDATE", gossip, function() if gossip.win and gossip.win:IsShown() then gossip:Soon() end end)
    gossip:Sync()
end
function M:SyncGossip()
    gossip:Sync()
    if gossip.win and gossip.win:IsShown() then reposition(); gossip:Layout() end
end
M.SETUPS[#M.SETUPS + 1] = "SetupGossipWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncGossip"
