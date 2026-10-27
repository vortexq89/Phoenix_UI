local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Friends (data shape, sort, filter, search, invites).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local F = ns.F
local D = F.Data

Tests:Add("Friends", "first-install defaults: invite accept off for both sources; keys apply live", function(t)
  t:eq(Schema:Get("friends.inviteFriends"), false, "friends off")
  t:eq(Schema:Get("friends.inviteGuild"), false, "guild off")
  t:eq(Schema:Get("friends.skin"), true, "skin on")
  for k, def in pairs(F.schema) do t:eq(type(def.apply), "function", k .. " apply") end
  Schema:Set("friends.sort", "name"); t:eq(F.settings.sort, "name", "live"); Schema:Set("friends.sort", "status")
end)

Tests:Add("Friends", "Battle.net entry: zone, activity, region, app-only", function(t)
  local e = D.FromBNet(1, { accountName = "Kael", battleTag = "Kael#2211", gameAccountInfo = { isOnline = true, clientProgram = "WoW",
    characterName = "Vex", areaName = "Silvermoon", richPresence = "Mythic+ +16", regionID = 3, factionName = "Horde" } })
  t:eq(e.activity, "M+ +16", "activity from the game's text")
  t:eq(e.region, "EU", "region")
  t:eq(e.appOnly, false, "in game")
  local app = D.FromBNet(2, { accountName = "App", gameAccountInfo = { isOnline = true, clientProgram = "BSAp" } })
  t:eq(app.appOnly, true, "app-only")
  t:eq(#D.Filter({ e, app }, { hideAppOnly = true }), 1, "app-only filter")
  if H then t:eq(D.FromBNet(3, { accountName = "S", gameAccountInfo = { isOnline = true, areaName = H.secret("x") } }).zone, nil, "secret zone dropped, never compared") end
end)

Tests:Add("Friends", "sort and one search across friends, guild and recent", function(t)
  local list = D.Sort({ { name = "b", status = "offline", online = false }, { name = "c", status = "online", online = true }, { name = "a", status = "afk", online = true } }, "status")
  t:eq(list[1].name, "c", "online first"); t:eq(list[2].name, "a", "then AFK")
  D.Sort(list, "name"); t:eq(list[1].name, "a", "by name")
  local res = D.Search("dorn", { { { name = "Vex", source = "friends", zone = "Silvermoon" } }, { { name = "Gil", source = "guild", zone = "Dornogal" } },
    { { name = "Rae", source = "recent", note = "dorn tank" } } })
  t:eq(#res, 2, "matches in guild and recent")
  t:eq(#D.Search("%d", { { { name = "a%d", source = "friends" } } }), 1, "plain text, not a pattern")
end)

Tests:Add("Friends", "invite accept per source, never queued or in combat; Flow stands down", function(t)
  local ok, why = F.ShouldAccept("Player-1-FRIEND", { inviteFriends = false })
  t:eq(ok, false, "off by default"); t:eq(why, "friends switch off", "reason")
  t:eq((F.ShouldAccept("Player-1-FRIEND", { inviteFriends = true })), true, "friend accepted when on")
  t:eq((F.ShouldAccept("Player-1-FRIEND", { inviteFriends = true, queued = true })), false, "never while queued")
  t:eq((F.ShouldAccept("Player-1-FRIEND", { inviteFriends = true, inCombat = true })), false, "never in combat")
  t:eq((F.ShouldAccept("Player-1-STRANGER", { inviteFriends = true, inviteGuild = true })), false, "strangers never")
end)

Tests:Add("Friends", "search panel lists every source and the find command", function(t)
  if not H then return end
  Schema:Set("module.Friends", true)
  local res = F.Panel.Results(F.settings, "", "all")
  t:ok(#res >= 3, "WoW + Battle.net friends listed")
  F.Panel.Show(F.settings, true)
  t:ok(F.Panel.shown >= 1, "rows painted")
  F.Panel.Show(F.settings, false)
end)

Tests:Add("Friends", "live preview follows the settings", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Friends(card)
  local n = P.State(card).friendsLines
  Schema:Set("friends.hideAppOnly", true)
  t:cleanup(function() Schema:Set("friends.hideAppOnly", false) end)
  P.Friends(card)
  t:eq(P.State(card).friendsLines, n - 1, "app-only friend leaves the preview")
end)
