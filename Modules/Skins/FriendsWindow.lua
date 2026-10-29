local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix friends window: our own friends list fed by the Battle.net and friend-list APIs. Online
    friends first, each row with a status bar (online / away / busy in the theme's state colours), name,
    character and zone; Whisper and Invite for the picked friend, and an Add friend box. Who, Raid, Quick
    Join, ignore and removing a friend stay in Blizzard's window (the arrow button, for this visit).
    Only the Friends tab is replaced: opening Blizzard's window on another tab shows Blizzard's.
    Values that the game reports secret are shown as they are and never compared.
    Skins > "Phoenix friends window" off: Blizzard's friends window, reskinned, live. ]]

local ROWS, ROW_H, WIDTH = 11, 36, 330
local offset, selected = 0, nil
local r

local function plain(v)
    if ns.Secret.IsSecret and ns.Secret.IsSecret(v) then return nil end
    return v
end

local function bnetRecord(i)
    local a = C_BattleNet and C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(i)
    if type(a) ~= "table" then return nil end
    local g = type(a.gameAccountInfo) == "table" and a.gameAccountInfo or {}
    local online = plain(g.isOnline) == true
    local wow = online and plain(g.clientProgram) == "WoW"
    local char = wow and plain(g.characterName) or nil
    local realm = wow and plain(g.realmName) or nil
    local sub = g.richPresence or ""
    if char then sub = ("%s  %s"):format(tostring(char), tostring(g.areaName or "")) end
    return { bnet = true, id = i, name = a.accountName or a.battleTag or "?", sub = sub, online = online,
        afk = plain(a.isAFK) == true, dnd = plain(a.isDND) == true, wow = wow and char ~= nil,
        character = char and (realm and (char .. "-" .. realm) or char) or nil }
end

local function wowRecord(i)
    local f = C_FriendList.GetFriendInfoByIndex(i)
    if type(f) ~= "table" or not f.name then return nil end
    local online = plain(f.connected) == true
    local sub = ""
    if online then sub = ("%s %s  %s"):format(tostring(f.level or ""), tostring(f.className or ""), tostring(f.area or "")) end
    return { bnet = false, id = i, name = f.name, online = online, afk = plain(f.afk) == true, dnd = plain(f.dnd) == true,
        character = f.name, wow = true, sub = sub }
end

-- Every friend as a plain record: { bnet, id, name, sub, online, afk, dnd, wow, character } (name / sub may be
-- secret: display only).
function M.FriendList()
    local out = {}
    for i = 1, (BNGetNumFriends and tonumber((BNGetNumFriends())) or 0) do out[#out + 1] = bnetRecord(i) end
    local nf = C_FriendList and C_FriendList.GetNumFriends and tonumber(C_FriendList.GetNumFriends()) or 0
    for i = 1, nf do out[#out + 1] = wowRecord(i) end
    -- online first; inside each group the game's own order (no name comparisons)
    local sorted = {}
    for _, want in ipairs({ true, false }) do
        for _, rec in ipairs(out) do if rec.online == want then sorted[#sorted + 1] = rec end end
    end
    return sorted
end

function M.FriendStatusToken(rec)
    if not rec.online then return "text.muted" end
    if rec.dnd then return "state.danger" end
    if rec.afk then return "state.warning" end
    return "state.success"
end

local function whisper(rec)
    if not ChatFrameUtil then return end
    if rec.bnet then
        if ChatFrameUtil.SendBNetTell then ChatFrameUtil.SendBNetTell(rec.name) end
    elseif ChatFrameUtil.SendTell then
        ChatFrameUtil.SendTell(rec.name)
    end
end

local function invite(rec)
    if not (rec.online and rec.wow and rec.character) then return end
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(rec.character) end
end

local function row(i)
    local b = r.rows[i]
    if b then return b end
    b = CreateFrame("Button", nil, r.body)
    b:SetSize(WIDTH, ROW_H - 2)
    b:SetPoint("TOPLEFT", 0, -24 - (i - 1) * ROW_H)
    b.bg = W.Texture(b, "BACKGROUND", 0); b.bg:SetAllPoints()
    b.bar = W.Texture(b, "ARTWORK", 1); b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(3)
    b.name = W.Text(b, "body", "text.primary"); b.name:SetPoint("TOPLEFT", 10, -4)
    b.name:SetPoint("RIGHT", -8, 0); b.name:SetJustifyH("LEFT")
    b.sub = W.Text(b, "small", "text.muted"); b.sub:SetPoint("BOTTOMLEFT", 10, 4)
    b.sub:SetPoint("RIGHT", -8, 0); b.sub:SetJustifyH("LEFT")
    b:SetScript("OnClick", function(self) selected = self.key; r:Layout() end)
    b:SetScript("OnDoubleClick", function(self) if self.rec then whisper(self.rec) end end)
    r.rows[i] = b
    return b
end

local function layout()
    local list = M.FriendList()
    local online = 0
    for _, rec in ipairs(list) do if rec.online then online = online + 1 end end
    r.count:SetText(L.FRIENDW_ONLINE:format(online, #list))
    offset = math.max(0, math.min(offset, #list - ROWS))
    local pick
    for i = 1, ROWS do
        local rec = list[offset + i]
        local b = row(i)
        if rec then
            b.rec, b.key = rec, (rec.bnet and "b" or "f") .. rec.id
            local sel = b.key == selected
            if sel then pick = rec end
            b.name:SetText(rec.name)
            b.sub:SetText(rec.sub or "")
            W.Color(b.bar, M.FriendStatusToken(rec), 1)
            W.Color(b.bg, sel and "accent.primary" or "bg.raised", sel and 0.25 or (rec.online and 0.7 or 0.35))
            Skin:Text(b.name, "body", rec.online and "text.primary" or "text.secondary", 12)
            b:Show()
        else
            b:Hide()
        end
    end
    r.whisper:SetShown(pick ~= nil)
    r.invite:SetShown(pick ~= nil and pick.online and pick.wow)
    r.pick = pick
end

local function build(rr)
    r = rr
    r.rows = {}
    r.count = W.Text(r.body, "small", "text.muted")
    r.count:SetPoint("TOPLEFT", 0, -2)
    r.body:EnableMouseWheel(true)
    r.body:SetScript("OnMouseWheel", function(_, d) offset = offset - d; r:Layout() end)
    r.whisper = W:Button(r.body, L.FRIENDW_WHISPER, "primary", "friends", 100)
    r.whisper:SetHeight(24)
    r.whisper:SetPoint("BOTTOMLEFT", 0, 34)
    r.whisper.onClick = function() if r.pick then whisper(r.pick) end end
    r.invite = W:Button(r.body, L.FRIENDW_INVITE, "secondary", "add", 100)
    r.invite:SetHeight(24)
    r.invite:SetPoint("LEFT", r.whisper, "RIGHT", 6, 0)
    r.invite.onClick = function() if r.pick then invite(r.pick) end end
    r.add = W:Input(r.body, 220, L.FRIENDW_ADD)
    r.add:SetPoint("BOTTOMLEFT", 0, 0)
    r.add.onChange = function(self, text)
        if type(text) == "string" and text ~= "" and C_FriendList and C_FriendList.AddFriend then
            C_FriendList.AddFriend(text)
            self:SetValue("")
        end
    end
end

local function friendsTab()
    local f = _G.FriendsFrame
    local t = f and PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(f)
    return tonumber(t) == nil or tonumber(t) == 1
end

local friends = M.Replacement({ key = "ownFriends", frame = "FriendsFrame", title = L.FRIENDW_TITLE,
    width = WIDTH + 20, height = 34 + 24 + ROWS * ROW_H + 80, build = build, layout = layout, ready = friendsTab,
    close = function() if FriendsFrame then HideUIPanel(FriendsFrame) end end })
M.FriendsReplacement = friends

local hooked
function M:SetupFriendsWindow()
    local f = _G.FriendsFrame
    if not f then return end
    if not hooked then
        hooked = true
        f:HookScript("OnShow", function() selected, offset = nil, 0; friends:Opened() end)
        f:HookScript("OnHide", function() friends:Closed() end)
        local owner = friends
        for _, event in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE",
            "BN_FRIEND_ACCOUNT_OFFLINE", "BN_FRIEND_LIST_SIZE_CHANGED" }) do
            ns.Events:On(event, owner, function() friends:Soon() end)
        end
        ns.Events:On("PLAYER_REGEN_ENABLED", owner, function() friends:Sync() end)
    end
    friends:Sync()
end
function M:SyncFriends() friends:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupFriendsWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncFriends"
