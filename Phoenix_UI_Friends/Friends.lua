local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Friends (plan 13.9 Friends rows, EUI parity audit 2026-10-26, mockup 19;
-- owner per plan 1.O of the friends-list skin, the cross-source search and
-- group-invite accept from friends and guild). The minimap friends tooltip
-- (with notes on a second line) is the Minimap's; it reads the same game data.
-- Invite accept: off at first install for both sources, never while you are
-- queued or in combat. Flow's older single switch stands down while this
-- module is on.
local _, ns = ...
local Schema = PUI.Schema
local D, K, P = ns.Data, ns.Skin, ns.Panel
local OWNER = "Friends"
local F = { active = false }
ns.F = F
PUI.Friends = F
F.Data, F.Skin, F.Panel = D, K, P
local s = {}
F.settings = s

-- Invite accept rule (pure; tests drive it).
function F.ShouldAccept(guid, opts)
  local src = D.InviteSource(guid)
  if not src then return false, "not a friend or guild member" end
  if src == "friend" and not opts.inviteFriends then return false, "friends switch off" end
  if src == "guild" and not opts.inviteGuild then return false, "guild switch off" end
  if opts.inCombat then return false, "in combat" end
  if opts.queued then return false, "queued" end
  return true, src
end
local function queued()
  local st = PUI.Queue and PUI.Queue:Status()
  return st ~= nil and (st.lfg or st.pvp or st.listed) == true
end
function F.OnInvite(_, _, _, _, _, _, _, _, inviterGUID)
  local ok = F.ShouldAccept(inviterGUID, { inviteFriends = s.inviteFriends, inviteGuild = s.inviteGuild, inCombat = InCombatLockdown(), queued = queued() })
  if not ok then return end
  AcceptGroup()
  StaticPopup_Hide("PARTY_INVITE")
  if s.inviteChat then PUI.Slash.Print("friends: accepted a group invite") end
end

function F.Refresh()
  if not F.active then return end
  local host = rawget(_G, "FriendsFrame")
  if host and host:IsShown() and rawget(_G, "FriendsList_Update") then FriendsList_Update() end
  P.Paint(s)
end

local function hookHost()
  local host = rawget(_G, "FriendsFrame")
  if F.hostHooked or not host then return end
  F.hostHooked = true
  host:HookScript("OnShow", function() if F.active and s.panel then P.Show(s, true) end end)
  host:HookScript("OnHide", function() if s.dock ~= "free" and P.frame then P.frame:Hide() end end)
end

local function onEnable(mod)
  F.active = true
  K.Hook(s)
  hookHost()
  mod:RegisterEvent("PARTY_INVITE_REQUEST", function(...) F.OnInvite(...) end)
  for _, ev in ipairs({ "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "GUILD_ROSTER_UPDATE" }) do
    mod:RegisterEvent(ev, function() P.Paint(s) end)
  end
end
local function onDisable()
  F.active = false
  if P.frame then P.frame:Hide() end
  F.Refresh()
end

local schema = {}
F.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[name] = v; F.Refresh(); if name == "dock" and P.frame then P.Dock(s) end end
  schema["friends." .. name] = def
end
key("skin", { type = "toggle", default = true, mode = "simple", label = "Style the friends list", tooltip = "Phoenix's look on Blizzard's friends list (through hooks; Blizzard still builds the list)." })
key("classIcons", { type = "toggle", default = true, mode = "simple", label = "Class icons", tooltip = "A class icon on each friend row." })
key("classNames", { type = "toggle", default = true, mode = "simple", label = "Class-coloured names", tooltip = "Online friends' names in their class colour." })
key("statusOrb", { type = "toggle", default = true, label = "Status orb", tooltip = "Green online, yellow AFK, red DND." })
key("zoneLine", { type = "toggle", default = true, mode = "simple", label = "Zone on the row", tooltip = "Where each online friend is." })
key("activity", { type = "toggle", default = true, mode = "simple", label = "Activity on the row", tooltip = "Mythic+ key level, arena, battleground, delve or raid when the game shows it." })
key("regionIcons", { type = "toggle", default = true, label = "Region tags", tooltip = "EU, US, KR, TW or CN for Battle.net friends." })
key("factionBanners", { type = "toggle", default = true, label = "Faction tint", tooltip = "A light Horde or Alliance tint behind Battle.net friends in World of Warcraft." })
key("hideAppOnly", { type = "toggle", default = false, label = "Hide Battle.net app-only friends",
  tooltip = "Friends only signed in to the Battle.net app are left out of the Phoenix list and dimmed on Blizzard's list." })
key("appOnlyAlpha", { type = "range", default = 0.35, min = 0, max = 1, step = 0.05, label = "App-only dimming", tooltip = "How faded app-only friends are on Blizzard's list while hidden." })
key("wowOnly", { type = "toggle", default = false, mode = "simple", label = "In game only",
  tooltip = "Show only friends playing World of Warcraft: others are left out of the Phoenix list and dimmed on Blizzard's list (the game has no such filter of its own).",
  searchTags = { "online", "in game", "wow" } })
key("sameGame", { type = "toggle", default = false, label = "In game only: this game version",
  tooltip = "With In game only, also leave out friends playing a different version of World of Warcraft." })
key("hideOffline", { type = "toggle", default = false, label = "Hide offline in the Phoenix list", tooltip = "Only online players in the search panel." })
key("panel", { type = "toggle", default = true, mode = "simple", label = "Search panel", tooltip = "One search across friends, guild and recent players, with sort and actions, beside the friends list." })
key("dock", { type = "select", default = "right", choices = { "right", "left", "free" }, choiceLabels = { right = "Right of the list", left = "Left of the list", free = "Free (move in Studio)" },
  label = "Panel position", tooltip = "Where the search panel sits." })
key("sort", { type = "select", default = "status", choices = { "status", "name", "class", "zone", "level" },
  choiceLabels = { status = "Online first", name = "Name", class = "Class", zone = "Zone", level = "Level" }, mode = "simple", label = "Sort", tooltip = "Order of the search panel." })
key("searchGuild", { type = "toggle", default = true, label = "Search includes guild", tooltip = "The All tab also searches your guild." })
key("searchRecent", { type = "toggle", default = true, label = "Search includes recent players", tooltip = "The All tab also searches players you grouped with recently." })
key("notesInList", { type = "toggle", default = true, label = "Notes in the panel", tooltip = "Your note after each friend in the search panel." })
key("rowHeight", { type = "range", default = 30, min = 20, max = 44, step = 1, label = "Row height", tooltip = "Height of each row in the search panel." })
key("inviteFriends", { type = "toggle", default = false, mode = "simple", label = "Accept group invites from friends",
  tooltip = "Accepts group invites from WoW and Battle.net friends. Never while you are queued or in combat." })
key("inviteGuild", { type = "toggle", default = false, mode = "simple", label = "Accept group invites from guild", tooltip = "Accepts group invites from guild members. Never while you are queued or in combat." })
key("inviteChat", { type = "toggle", default = false, label = "Chat line when accepted", tooltip = "Prints a line when an invite is accepted for you." })
PUI.Layout:RegisterElement("friends.panel", { label = "Friends search panel", owner = OWNER, size = { 300, 540 }, default = { point = "LEFT", x = 420, y = 0 } })

PUI.Slash:Register("friends", function(rest)
  local word, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  if word == "find" then
    for _, e in ipairs(P.Results(s, arg, "all")) do PUI.Slash.Print(string.format("%s  %s  %s", e.name or "?", e.source, e.zone or "")) end
  elseif word == "panel" then P.Show(s, not (P.frame and P.frame:IsShown()))
  else PUI.Slash.Print("/pui friends find <text> | panel") end
end, "Friends: search friends, guild and recent players; open the panel")

F.module = PUI:RegisterModule(OWNER, {
  label = "Friends", tooltip = "Phoenix's look on the friends list, zone and activity per friend, one search across friends, guild and recent players, and invite accept per source (off).",
  enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
