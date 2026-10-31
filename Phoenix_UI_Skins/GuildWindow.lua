local _, ns = ...
local L, W = ns.L, ns.Widgets
local M = ns:GetModule("Skins")

--[[ The Phoenix guild window: our own guild roster fed by the guild roster API, shown when the guild & communities
    window opens while you are in a guild. Roster tab: members as Phoenix rows (name in its class colour, level,
    class, rank, zone or last online, public note), online first, a search box, an "offline" switch and a sort
    cycle (rank / name / level / zone); pick a member, then whisper or invite (double-click whispers). Info tab:
    the message of the day and the guild information text. Communities, chat, news, perks and guild settings stay
    Blizzard's (the arrow button). Skins > "Phoenix guild window" off: Blizzard's window, reskinned, live. ]]

local LIST_W, ROWS, ROW_H = 620, 12, 34
local SORTS = { "rank", "name", "level", "zone" }
local r, list
local mode, search, sortBy, offline, picked = "roster", "", "rank", false, nil

-- One roster member as plain values (index i of the game's roster).
function M.GuildMember(i)
    local name, rank, rankIndex, level, classText, zone, note, _, online, _, class = GetGuildRosterInfo(i)
    if not name then return nil end
    return { index = i, name = tostring(name), short = tostring(name):match("^[^-]+") or tostring(name), rank = tostring(rank or ""),
        rankIndex = tonumber(rankIndex) or 0, level = tonumber(level) or 0, classText = tostring(classText or ""),
        zone = tostring(zone or ""), note = tostring(note or ""), online = online and true or false, class = class }
end

local function before(a, b)
    if a.online ~= b.online then return a.online end
    if sortBy == "name" or a[sortBy] == b[sortBy] then return a.name < b.name end
    if sortBy == "level" then return a.level > b.level end
    if sortBy == "rank" then return a.rankIndex < b.rankIndex end
    return a.zone < b.zone
end

-- The shown roster: search over name / zone / note / rank, offline members only with the switch on, sorted.
function M.GuildRoster()
    local out = {}
    local needle = search:lower()
    for i = 1, tonumber((GetNumGuildMembers())) or 0 do
        local m = M.GuildMember(i)
        if m and (offline or m.online) and (needle == "" or (m.name .. " " .. m.zone .. " " .. m.note .. " " .. m.rank):lower()
            :find(needle, 1, true)) then
            out[#out + 1] = m
        end
    end
    table.sort(out, before)
    return out
end

local function whisper(m) if m and ChatFrameUtil.SendTell then ChatFrameUtil.SendTell(m.name) end end

local function paintMember(b, m)
    b.title:SetText(("%s  |cff999999%d|r"):format(m.short, m.level))
    local c = m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
    if c then b.title:SetTextColor(c.r, c.g, c.b) end
    b.sub:SetText(m.note ~= "" and ("%s - %s"):format(m.classText, m.note) or m.classText)
    b.right:SetText(("%s  |  %s"):format(m.rank, m.zone))
    if picked == m.name then list.Mark(b, "accent.primary", 0.25) end
    if m.online then list.Bar(b, "state.success") else b.title:SetAlpha(0.6) end
end

local function layout()
    r.tabs.Paint(mode)
    local roster = mode == "roster"
    list:SetShown(roster)
    r.info:SetShown(not roster)
    for _, w in ipairs({ r.search, r.offline, r.sort, r.whisper, r.invite }) do w:SetShown(roster) end
    local gname = GetGuildInfo("player")
    local total, on = GetNumGuildMembers()
    r.count:SetText(("%s  %d / %d"):format(tostring(gname or ""), tonumber(on) or 0, tonumber(total) or 0))
    if not roster then
        local motd = _G.GetGuildRosterMOTD or (C_GuildInfo and C_GuildInfo.GetMOTD)
        local info = _G.GetGuildInfoText
        r.info:SetText(("%s\n\n%s"):format(tostring(motd and motd() or ""), tostring(info and info() or "")))
        return
    end
    r.offline.variant = offline and "primary" or "secondary"
    r.offline:GetScript("OnLeave")(r.offline)
    r.sort:SetText(L.GUILDW_SORT:format(L["GUILDW_SORT_" .. sortBy:upper()]))
    local items = M.GuildRoster()
    local pick
    for _, m in ipairs(items) do if m.name == picked then pick = m end end
    r.pick = pick
    list.Set(items, function(b, m) b.title:SetAlpha(1); paintMember(b, m) end)
    r.whisper:SetEnabled(pick ~= nil)
    r.invite:SetEnabled(pick ~= nil and pick.online)
end

local function build(rr)
    r = rr
    list = M.ReplaceList(r.body, ROWS, ROW_H, LIST_W)
    list:SetPoint("TOPLEFT", 0, -30)
    list.onClick = function(m)
        if picked == m.name and r.lastClick and GetTime() - r.lastClick < 0.4 then whisper(m) end
        picked, r.lastClick = m.name, GetTime()
        r:Layout()
    end
    r.tabs = M.ReplaceTabs(r.body, { { key = "roster", label = L.GUILDW_ROSTER }, { key = "info", label = L.GUILDW_INFO } }, 96,
        function(key) mode = key; r:Layout() end)
    r.search = W:Input(r.body, 170, SEARCH or "")
    r.search:SetPoint("TOPLEFT", 2 * 100 + 10, 0)
    r.search.onTextChanged = function(_, text) search = text or ""; list.offset = 0; r:Layout() end
    r.count = W.Text(r.body, "body", "accent.primary")
    r.count:SetPoint("TOPRIGHT", 0, -4)
    r.info = W.Text(r.body, "body", "text.primary")
    r.info:SetPoint("TOPLEFT", 0, -36); r.info:SetWidth(LIST_W); r.info:SetJustifyH("LEFT"); r.info:SetJustifyV("TOP")
    r.whisper = W:Button(r.body, L.FRIENDW_WHISPER, "primary", "friends", 100)
    r.whisper:SetHeight(24); r.whisper:SetPoint("BOTTOMLEFT", 0, 0)
    r.whisper.onClick = function() whisper(r.pick) end
    r.invite = W:Button(r.body, L.FRIENDW_INVITE, "secondary", nil, 100)
    r.invite:SetHeight(24); r.invite:SetPoint("LEFT", r.whisper, "RIGHT", 6, 0)
    r.invite.onClick = function() if r.pick then C_PartyInfo.InviteUnit(r.pick.name) end end
    r.offline = W:Button(r.body, L.GUILDW_OFFLINE, "secondary", nil, 110)
    r.offline:SetHeight(24); r.offline:SetPoint("BOTTOMRIGHT", 0, 0)
    r.offline.onClick = function() offline = not offline; list.offset = 0; r:Layout() end
    r.sort = W:Button(r.body, "", "secondary", nil, 140)
    r.sort:SetHeight(24); r.sort:SetPoint("RIGHT", r.offline, "LEFT", -6, 0)
    r.sort.onClick = function()
        for i, key in ipairs(SORTS) do if key == sortBy then sortBy = SORTS[i % #SORTS + 1]; break end end
        r:Layout()
    end
end

local guild = M.Replacement({ key = "ownGuild", frame = "CommunitiesFrame", title = L.GUILDW_TITLE,
    width = LIST_W + 20, height = 34 + 30 + ROWS * ROW_H + 50, build = build, layout = layout,
    close = function() local f = _G.CommunitiesFrame; if f then HideUIPanel(f) end end,
    ready = function() return IsInGuild() and true or false end })
guild.onOpen = function() if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end end
M.GuildReplacement = guild
function M.GuildState(key, value) if key then ({ mode = function() mode = value end, offline = function() offline = value end,
    sort = function() sortBy = value end, search = function() search = value end })[key]() end; return mode, offline, sortBy end

function M:SetupGuildWindow()
    if not M.ReplacementHook(guild) then return end
    for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "GUILD_MOTD", "PLAYER_GUILD_UPDATE" }) do
        ns.Events:On(event, guild, function() guild:Soon() end)
    end
    guild:Sync()
end
function M:SyncGuildWindow() guild:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupGuildWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncGuildWindow"
