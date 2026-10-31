local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix friends window: our own friends list fed by the Battle.net and friend-list APIs. Online
    friends first, each row with a status bar (online / away / busy in the theme's state colours), name,
    character and zone; Whisper, Invite and Remove (a second click confirms) for the picked friend, and an Add
    friend box. Who tab: type a search and press Enter (the game's own who query on your key press; results come
    to this window), then whisper, invite or befriend. Ignore tab: the ignore list, add and remove.
    Raid and Quick Join stay in Blizzard's window (the arrow button, for this visit).
    Values that the game reports secret are shown as they are and never compared.
    Skins > "Phoenix friends window" off: Blizzard's friends window, reskinned, live. ]]

local ROWS, ROW_H, WIDTH = 11, 36, 330
local offset, selected, tab, armed = 0, nil, "friends", nil
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
        character = char and (realm and (char .. "-" .. realm) or char) or nil,
        gameAccountID = wow and plain(g.gameAccountID) or nil, bnetAccountID = plain(a.bnetAccountID),
        guid = wow and plain(g.playerGuid) or nil,
        accountName = a.accountName }
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

-- Who results as rows (the game's own text, shown as is).
function M.WhoList()
    local out = {}
    for i = 1, (tonumber((C_FriendList.GetNumWhoResults())) or 0) do
        local w = C_FriendList.GetWhoInfo(i)
        if type(w) == "table" and w.fullName then
            out[#out + 1] = { who = true, id = i, name = w.fullName, character = w.fullName, online = true, wow = true,
                sub = ("%s %s %s  %s"):format(tostring(w.level or ""), tostring(w.raceStr or ""), tostring(w.classStr or ""),
                    tostring(w.area or "")) }
        end
    end
    return out
end

function M.IgnoreList()
    local out = {}
    for i = 1, (tonumber(C_FriendList.GetNumIgnores()) or 0) do
        local name = C_FriendList.GetIgnoreName(i)
        if name then out[#out + 1] = { ignore = true, id = i, name = name, online = false, sub = "" } end
    end
    return out
end

-- Remove a friend: Battle.net friends by account ID, character friends by name.
function M.RemoveFriendRecord(rec)
    if rec.bnet then
        if rec.bnetAccountID and BNRemoveFriend then BNRemoveFriend(rec.bnetAccountID) end
    elseif rec.name then
        C_FriendList.RemoveFriend(rec.name)
    end
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
        -- Blizzard's own Battle.net whisper takes the account's (tokenised) name, the same value its list passes
        if ChatFrameUtil.SendBNetTell and rec.accountName then ChatFrameUtil.SendBNetTell(rec.accountName) end
    elseif ChatFrameUtil.SendTell then
        ChatFrameUtil.SendTell(rec.name)
    end
end

local function invite(rec)
    if not (rec.online and rec.wow) then return end
    if rec.bnet then
        -- by game account: Blizzard's friends-list invite (handles cross-realm / request-to-join), else the older call
        if not rec.gameAccountID then return end
        if FriendsFrame_InviteOrRequestToJoin and rec.guid then
            FriendsFrame_InviteOrRequestToJoin(rec.guid, rec.gameAccountID)
        elseif _G.BNInviteFriend then
            _G.BNInviteFriend(rec.gameAccountID)
        end
    elseif rec.character and C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(rec.character)
    end
end

local function row(i)
    local b = r.rows[i]
    if b then return b end
    b = CreateFrame("Button", nil, r.body)
    b:SetSize(WIDTH, ROW_H - 2)
    b:SetPoint("TOPLEFT", 0, -48 - (i - 1) * ROW_H)
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

function M.FriendTabList(which)
    if which == "who" then return M.WhoList() end
    if which == "ignore" then return M.IgnoreList() end
    return M.FriendList()
end

local function rowKey(rec)
    return (rec.bnet and "b" or rec.who and "w" or rec.ignore and "i" or "f") .. rec.id
end

local function layout()
    r.tabs.Paint(tab)
    local list = M.FriendTabList(tab)
    local online = 0
    for _, rec in ipairs(list) do if rec.online then online = online + 1 end end
    r.count:SetText(tab == "friends" and L.FRIENDW_ONLINE:format(online, #list) or tostring(#list))
    r.add.placeholder:SetText(({ who = L.FRIENDW_WHO_HINT, ignore = L.FRIENDW_IGNORE_ADD })[tab] or L.FRIENDW_ADD)
    offset = math.max(0, math.min(offset, #list - ROWS))
    local pick
    for i = 1, ROWS do
        local rec = list[offset + i]
        local b = row(i)
        if rec then
            b.rec, b.key = rec, rowKey(rec)
            local sel = b.key == selected
            if sel then pick = rec end
            b.name:SetText(rec.name)
            b.sub:SetText(rec.sub or "")
            W.Color(b.bar, rec.ignore and "state.danger" or M.FriendStatusToken(rec), 1)
            local alpha = sel and 0.25 or (rec.online and 0.7 or 0.35)
            W.Color(b.bg, sel and "accent.primary" or "bg.raised", alpha)
            Skin:Text(b.name, "body", rec.online and "text.primary" or "text.secondary", 12)
            b:Show()
        else
            b:Hide()
        end
    end
    r.pick = pick
    M.FriendButtons(pick)
end

function M.FriendButtons(pick)
    if not pick then armed = nil end
    r.whisper:SetShown(pick ~= nil and not pick.ignore)
    r.invite:SetShown(pick ~= nil and pick.online and pick.wow and not pick.ignore)
    r.remove:SetShown(pick ~= nil and not pick.who)
    r.remove:SetText(armed and armed == selected and L.FRIENDW_REMOVE_CONFIRM or REMOVE or "Remove")
    r.befriend:SetShown(pick ~= nil and pick.who == true)
end

local function build(rr)
    r = rr
    r.rows = {}
    r.count = W.Text(r.body, "small", "text.muted")
    r.count:SetPoint("TOPRIGHT", 0, -30)
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
    r.remove = W:Button(r.body, "", "danger", nil, 100)
    r.remove:SetHeight(24)
    r.remove:SetPoint("LEFT", r.invite, "RIGHT", 6, 0)
    r.remove.onClick = function()
        local rec = r.pick
        if not rec then return end
        if armed ~= selected then armed = selected; r:Layout(); return end -- second click removes
        armed = nil
        if rec.ignore then C_FriendList.DelIgnoreByIndex(rec.id) else M.RemoveFriendRecord(rec) end
        selected = nil
        r:Soon()
    end
    r.befriend = W:Button(r.body, L.FRIENDW_ADD_SHORT, "secondary", "add", 100)
    r.befriend:SetHeight(24)
    r.befriend:SetPoint("LEFT", r.invite, "RIGHT", 6, 0)
    r.befriend.onClick = function() if r.pick then C_FriendList.AddFriend(r.pick.name) end end
    r.add = W:Input(r.body, WIDTH, L.FRIENDW_ADD)
    r.add:SetPoint("BOTTOMLEFT", 0, 0)
    r.add.onChange = function(self, text)
        if type(text) ~= "string" or text == "" then return end
        if tab == "who" then
            C_FriendList.SetWhoToUi(true)
            C_FriendList.SendWho(text) -- on your Enter key press
        elseif tab == "ignore" then
            C_FriendList.AddIgnore(text)
            self:SetValue("")
        else
            C_FriendList.AddFriend(text)
            self:SetValue("")
        end
    end
    r.tabs = M.ReplaceTabs(r.body, { { key = "friends", label = L.FRIENDW_TITLE }, { key = "who", label = L.FRIENDW_WHO },
        { key = "ignore", label = L.FRIENDW_IGNORE } }, 106,
        function(key) tab, selected, armed, offset = key, nil, nil, 0; r.add:SetValue(""); r:Layout() end)
end


local friends = M.Replacement({ key = "ownFriends", frame = "FriendsFrame", title = L.FRIENDW_TITLE,
    width = WIDTH + 20, height = 34 + 48 + ROWS * ROW_H + 80, build = build, layout = layout,
    close = function() if FriendsFrame then HideUIPanel(FriendsFrame) end end })
M.FriendsReplacement = friends

local hooked
function M:SetupFriendsWindow()
    local f = _G.FriendsFrame
    if not f then return end
    if not hooked then
        hooked = true
        f:HookScript("OnShow", function() selected, offset = nil, 0; friends:Opened() end)
        f:HookScript("OnHide", function()
            friends:Closed()
            if tab == "who" then C_FriendList.SetWhoToUi(false) end -- who results back to chat
        end)
        local owner = friends
        for _, event in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE",
            "BN_FRIEND_ACCOUNT_OFFLINE", "BN_FRIEND_LIST_SIZE_CHANGED", "WHO_LIST_UPDATE", "IGNORELIST_UPDATE" }) do
            ns.Events:On(event, owner, function() friends:Soon() end)
        end
        ns.Events:On("PLAYER_REGEN_ENABLED", owner, function() friends:Sync() end)
    end
    friends:Sync()
end
function M:SyncFriends() friends:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupFriendsWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncFriends"
