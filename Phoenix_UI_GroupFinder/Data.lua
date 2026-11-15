local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group Finder data: turns one search result into the plain variables the
-- filter language and the row decorations read. Read-only: nothing here
-- writes a Blizzard table (G14). A value the game hides (secret) is treated as
-- unknown, never compared. Activity info is cached by activity ID.
local _, ns = ...
local Secret = PUI.Secret
local Expr = ns.Expr
local Data = { activity = {}, keywords = {}, firstSeen = {}, status = {} }
ns.Data = Data

local function plain(v) if v == nil or Secret.IsSecret(v) then return nil end return v end
Data.plain = plain

Data.CATEGORY = { [2] = "dungeon", [3] = "raid", [4] = "arena", [9] = "rbg", [121] = "delve" }
Data.LUST = { SHAMAN = true, MAGE = true, HUNTER = true, EVOKER = true }
Data.BREZ = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true, PALADIN = true }
Data.SLOTS = { TANK = 1, HEALER = 1, DAMAGER = 3 }

-- Built-in words (the season's dungeon and raid words are added live).
local BUILTIN = {
  { "tanks", "Tanks in the group", "roles" }, { "heals", "Healers in the group", "roles" }, { "dps", "Damage dealers in the group", "roles" },
  { "members", "Players in the group", "roles" }, { "partyfit", "Your role still has a free spot", "roles" },
  { "mprating", "Leader's Mythic+ score", "rating" }, { "bestkey", "Leader's best timed key in this dungeon", "rating" },
  { "pvprating", "Leader's PvP rating for this bracket", "rating" }, { "ilvl", "Required item level", "rating" },
  { "age", "Minutes since the group was listed", "group" }, { "friends", "Friends, Battle.net friends or guild members in the group", "group" },
  { "guild", "Guild members in the group", "group" }, { "declined", "This leader declined you before", "group" },
  { "delisted", "The group is no longer listed", "group" }, { "new", "Listed since your last search", "group" },
  { "voice", "The group lists a voice channel", "group" }, { "warmode", "War Mode group", "group" },
  { "hasbl", "Someone can cast Bloodlust or Heroism", "utility" }, { "needbl", "Nobody can cast Bloodlust yet", "utility" },
  { "hasbr", "Someone can battle-res", "utility" }, { "needbr", "Nobody can battle-res yet", "utility" },
  { "normal", "Normal difficulty", "difficulty" }, { "heroic", "Heroic difficulty", "difficulty" }, { "mythic", "Mythic difficulty", "difficulty" },
  { "mythicplus", "Mythic+ keystone", "difficulty" }, { "arena2v2", "2v2 arena", "difficulty" }, { "arena3v3", "3v3 arena", "difficulty" },
  { "rbg", "Rated battleground", "difficulty" }, { "tier", "Delve tier (0 when not a delve)", "difficulty" },
  { "hashealer", "The group has a healer", "roles" },
}
for _, b in ipairs(BUILTIN) do Expr.Define(b[1], b[2], b[3]) end

-- Keyword for a dungeon or raid name: lowercase letters of the first word
-- that is longer than three letters ("Ara-Kara, City of Echoes" -> "arakara").
function Data.Keyword(name)
  if type(name) ~= "string" or Secret.IsSecret(name) then return nil end
  for word in name:gmatch("[^%s,:]+") do
    local w = word:lower():gsub("[^%a]", "")
    if #w > 3 and w ~= "the" then return w end
  end
  local w = name:lower():gsub("[^%a]", "")
  return w ~= "" and w or nil
end

function Data.Activity(id)
  if not id then return nil end
  local a = Data.activity[id]
  if a == nil then
    local info = C_LFGList.GetActivityInfoTable(id)
    a = false
    if type(info) == "table" then
      local group = info.groupFinderActivityGroupID
      local gname = group and C_LFGList.GetActivityGroupInfo(group)
      local name = plain(gname) or plain(info.shortName) or plain(info.fullName)
      local full = plain(info.fullName) or ""
      a = { id = id, name = name, full = full, category = Data.CATEGORY[info.categoryID] or "custom", categoryID = info.categoryID,
        mplus = info.isMythicPlusActivity == true, mythic = info.isMythicActivity == true, heroic = info.isHeroicActivity == true,
        normal = info.isNormalActivity == true, rated = info.isRatedPvpActivity == true, maxPlayers = info.maxNumPlayers or 5,
        tier = tonumber(full:match("(%d+)%s*%)?%s*$")) or 0 }
      a.keyword = Data.Keyword(name)
      if a.keyword and not Data.keywords[a.keyword] then
        Data.keywords[a.keyword] = { name = name, category = a.category }
        Expr.Define(a.keyword, name or a.keyword, a.category)
      end
    end
    Data.activity[id] = a
  end
  return a or nil
end

-- Season words are known before the first search (Season service).
function Data.SeedSeason()
  local S = PUI.Season
  for _, d in ipairs(S and S.dungeons or {}) do
    local kw = Data.Keyword(d.name)
    if kw and not Data.keywords[kw] then
      Data.keywords[kw] = { name = d.name, category = "dungeon", mapID = d.id }
      Expr.Define(kw, d.name, "dungeon")
    end
  end
end

function Data.MyRole()
  local index = C_SpecializationInfo.GetSpecialization()
  if not index then return "DAMAGER" end
  local _, _, _, _, role = C_SpecializationInfo.GetSpecializationInfo(index)
  return role or "DAMAGER"
end

local function firstActivity(info)
  local ids = info.activityIDs
  if type(ids) == "table" and ids[1] then return ids[1] end
  return info.activityID
end

-- Vars(resultID[, declinedFn]) -> vars, meta  (nil when the result is gone)
function Data.Vars(resultID, declinedFn)
  if not C_LFGList.HasSearchResultInfo(resultID) then return nil end
  local info = C_LFGList.GetSearchResultInfo(resultID)
  if type(info) ~= "table" then return nil end
  local act = Data.Activity(firstActivity(info)) or { category = "custom", maxPlayers = 5, tier = 0 }
  local members = plain(info.numMembers) or 0
  local v = { tanks = 0, heals = 0, dps = 0, members = members, hasbl = false, hasbr = false }
  local classes = {}
  for i = 1, members do
    local p = C_LFGList.GetSearchResultPlayerInfo(resultID, i)
    if type(p) == "table" then
      local role, class = plain(p.assignedRole), plain(p.classFilename)
      if role == "TANK" then v.tanks = v.tanks + 1 elseif role == "HEALER" then v.heals = v.heals + 1 elseif role == "DAMAGER" then v.dps = v.dps + 1 end
      if class then
        if Data.LUST[class] then v.hasbl = true end
        if Data.BREZ[class] then v.hasbr = true end
      end
      classes[i] = { role = role, class = class, spec = plain(p.specName), leader = p.isLeader == true }
    end
  end
  v.needbl, v.needbr, v.hashealer = not v.hasbl, not v.hasbr, v.heals > 0
  local my = Data.MyRole()
  local slots = act.maxPlayers and act.maxPlayers <= 5 and Data.SLOTS or nil
  if slots then
    local have = my == "TANK" and v.tanks or my == "HEALER" and v.heals or v.dps
    v.partyfit = have < slots[my] and members < 5
  else
    v.partyfit = members < (act.maxPlayers or 40)
  end
  v.mprating = plain(info.leaderOverallDungeonScore) or 0
  local ds = plain(info.leaderDungeonScoreInfo)
  if type(ds) == "table" and ds[1] then ds = ds[1] end
  v.bestkey = type(ds) == "table" and plain(ds.bestRunLevel) or 0
  local pvp = plain(info.leaderPvpRatingInfo)
  if type(pvp) == "table" and pvp[1] then pvp = pvp[1] end
  v.pvprating = type(pvp) == "table" and plain(pvp.rating) or 0
  v.ilvl = plain(info.requiredItemLevel) or 0
  v.age = math.floor((plain(info.age) or 0) / 60)
  v.guild = plain(info.numGuildMates) or 0
  v.friends = (plain(info.numBNetFriends) or 0) + (plain(info.numCharFriends) or 0) + v.guild
  v.delisted = info.isDelisted == true
  local voice = plain(info.voiceChat)
  v.voice = type(voice) == "string" and voice ~= ""
  v.warmode = info.isWarMode == true
  v.normal, v.heroic, v.mythic, v.mythicplus = act.normal == true, act.heroic == true, act.mythic == true and not act.mplus, act.mplus == true
  v.arena2v2 = act.category == "arena" and act.maxPlayers == 2
  v.arena3v3 = act.category == "arena" and act.maxPlayers == 3
  v.rbg = act.category == "rbg"
  v.tier = act.category == "delve" and (act.tier or 0) or 0
  if act.keyword then v[act.keyword] = true end
  local leader = plain(info.leaderName)
  v.declined = leader and declinedFn and declinedFn(leader) or false
  v.new = Data.firstSeen[resultID] == nil or Data.firstSeen[resultID] == Data.searchStamp
  local meta = { id = resultID, leader = leader, activity = act, classes = classes, status = Data.status[resultID],
    title = plain(info.name), lockout = nil }
  return v, meta
end

-- New-result bookkeeping (row colour "new").
function Data.MarkSearch(results)
  Data.searchStamp = (Data.searchStamp or 0) + 1
  for _, id in ipairs(results or {}) do
    if Data.firstSeen[id] == nil then Data.firstSeen[id] = Data.searchStamp end
  end
end
