local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Friends data (mockup 19): one plain entry shape for WoW friends,
-- Battle.net friends, guild members and recent players, so the list, the
-- sort, the app-only filter and the one search across every source share
-- the same code. Entries are rebuilt on the game's events, never polled.
--   { source, name, battleTag, online, status ("online"|"afk"|"dnd"|
--     "offline"), classFile, level, zone, activity, region, faction, note,
--     appOnly, guid, index }
local _, ns = ...
local Secret = PUI.Secret
local D = {}
ns.Data = D

D.REGIONS = { [1] = "US", [2] = "KR", [3] = "EU", [4] = "TW", [5] = "CN" }
D.APP_CLIENTS = { App = true, BSAp = true }

local function plain(v) if v == nil or Secret.IsSecret(v) then return nil end return v end
local classByName
function D.ClassFile(localized)
  localized = plain(localized)
  if not localized then return nil end
  if not classByName then
    classByName = {}
    for _, src in ipairs({ rawget(_G, "LOCALIZED_CLASS_NAMES_MALE"), rawget(_G, "LOCALIZED_CLASS_NAMES_FEMALE") }) do
      for file, name in pairs(src or {}) do classByName[name] = file end
    end
  end
  return classByName[localized] or (localized:upper():gsub("%s", ""))
end

-- Activity from what the game shows: Mythic+, arena, battleground, delve.
function D.Activity(text)
  text = plain(text)
  if type(text) ~= "string" or text == "" then return nil end
  local key = text:match("%+%d+")
  if key then return "M+ " .. key end
  local lower = text:lower()
  if lower:find("arena") then return "Arena" end
  if lower:find("battleground") or lower:find("blitz") then return "Battleground" end
  if lower:find("delve") then return "Delve" end
  if lower:find("raid") then return "Raid" end
  return nil
end

function D.FromWoW(i, f)
  local status = not f.connected and "offline" or (f.dnd and "dnd") or (f.afk and "afk") or "online"
  return { source = "friends", kind = "wow", index = i, name = plain(f.name), online = f.connected == true, status = status,
    classFile = D.ClassFile(f.className), level = plain(f.level), zone = plain(f.area), activity = D.Activity(f.area),
    note = plain(f.notes), guid = plain(f.guid) }
end
function D.FromBNet(i, a)
  local g = a.gameAccountInfo or {}
  local online = g.isOnline == true
  local status = not online and "offline" or (a.isDND and "dnd") or (a.isAFK and "afk") or "online"
  local client = plain(g.clientProgram)
  return { source = "friends", kind = "bnet", index = i, name = plain(g.characterName) or plain(a.accountName), battleTag = plain(a.battleTag),
    account = plain(a.accountName), online = online, status = status, classFile = D.ClassFile(g.className), level = plain(g.characterLevel),
    zone = plain(g.areaName), activity = D.Activity(g.richPresence) or D.Activity(g.areaName), region = D.REGIONS[plain(g.regionID) or 0],
    faction = plain(g.factionName), note = plain(a.note), appOnly = online and client ~= nil and D.APP_CLIENTS[client] == true,
    client = client, guid = plain(g.playerGuid), realm = plain(g.realmName) }
end

function D.Friends()
  local out = {}
  for i = 1, C_FriendList.GetNumFriends() or 0 do
    local f = C_FriendList.GetFriendInfoByIndex(i)
    if f then out[#out + 1] = D.FromWoW(i, f) end
  end
  local n = BNGetNumFriends() or 0
  for i = 1, n do
    local a = C_BattleNet.GetFriendAccountInfo(i)
    if a then out[#out + 1] = D.FromBNet(i, a) end
  end
  return out
end
function D.Guild()
  local out = {}
  local fn = rawget(_G, "GetGuildRosterInfo")
  if not (fn and IsInGuild()) then return out end
  local total = GetNumGuildMembers() or 0
  for i = 1, total do
    local name, _, _, level, _, zone, note, _, online, status, classFile, _, _, _, _, _, guid = fn(i)
    if name then
      out[#out + 1] = { source = "guild", index = i, name = plain(name), online = online == true,
        status = not online and "offline" or (status == 1 and "afk") or (status == 2 and "dnd") or "online",
        classFile = plain(classFile), level = plain(level), zone = plain(zone), activity = D.Activity(zone), note = plain(note), guid = plain(guid) }
    end
  end
  return out
end
function D.Recent()
  local out = {}
  local RA = rawget(_G, "C_RecentAllies")
  local list = RA and RA.GetRecentAllies and RA.GetRecentAllies() or {}
  for i, r in ipairs(list) do
    local c = r.characterData or r
    local st = r.stateData or {}
    local name = plain(c.fullName) or plain(c.name)
    if name then
      out[#out + 1] = { source = "recent", index = i, name = name, online = st.isOnline == true, status = st.isOnline and "online" or "offline",
        classFile = plain(c.classFile), level = plain(c.level), zone = plain(st.currentLocation), guid = plain(c.guid) }
    end
  end
  return out
end

-- Filter(list, opts): app-only and offline filters.
function D.Filter(list, opts)
  local out = {}
  for _, e in ipairs(list) do
    if not (opts.hideAppOnly and e.appOnly) and not (opts.hideOffline and not e.online) then out[#out + 1] = e end
  end
  return out
end

-- Sort(list, how): "status" (online first, then AFK/DND, then name),
-- "name", "class", "zone", "level".
local RANK = { online = 1, afk = 2, dnd = 3, offline = 4 }
function D.Sort(list, how)
  local function name(e) return (e.name or ""):lower() end
  table.sort(list, function(a, b)
    if how ~= "name" and RANK[a.status] ~= RANK[b.status] and (how == "status" or a.online ~= b.online) then return RANK[a.status] < RANK[b.status] end
    if how == "class" and (a.classFile or "") ~= (b.classFile or "") then return (a.classFile or "~") < (b.classFile or "~") end
    if how == "zone" and (a.zone or "") ~= (b.zone or "") then return (a.zone or "~") < (b.zone or "~") end
    if how == "level" and (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
    return name(a) < name(b)
  end)
  return list
end

-- Search(query, sources): one search across friends, guild and recent
-- players by name, BattleTag, zone, note or activity. Plain-text find, no
-- patterns from the user (G12).
function D.Search(query, sources)
  query = (query or ""):lower()
  local out, seen = {}, {}
  for _, src in ipairs(sources) do
    for _, e in ipairs(src) do
      local hay = table.concat({ e.name or "", e.battleTag or "", e.zone or "", e.note or "", e.activity or "", e.realm or "" }, " "):lower()
      local id = (e.name or "?") .. "|" .. e.source
      if (query == "" or hay:find(query, 1, true)) and not seen[id] then seen[id] = true; out[#out + 1] = e end
    end
  end
  return out
end

-- Invite source of a GUID: "friend", "guild" or nil.
function D.InviteSource(guid)
  if not plain(guid) or guid == "" then return nil end
  if C_FriendList.IsFriend(guid) or C_BattleNet.GetAccountInfoByGUID(guid) ~= nil then return "friend" end
  if IsGuildMember(guid) then return "guild" end
  return nil
end
