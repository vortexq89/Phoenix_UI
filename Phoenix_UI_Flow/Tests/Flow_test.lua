local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Flow.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local FL = ns.Flow

local function enable(t, ...)
  local keys = { "module.Flow", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end end)
  Schema:Set("module.Flow", true)
end
local function called(name)
  for _, c in ipairs(H.calls) do if c[1] == name then return c end end
end

Tests:Add("Flow", "everything off by default; no events while toggles are off", function(t)
  t:eq(Schema:Def("module.Flow").default, false, "module defaults off")
  for key, def in pairs(FL.schema) do
    t:eq(type(def.apply), "function", key .. " apply")
    if def.type == "toggle" then t:eq(def.default, false, key .. " defaults off") end
    if def.type == "select" and not key:match("^core%.coexist") then t:eq(def.default, "off", key .. " defaults off") end
  end
  if not H then return end
  enable(t)
  t:eq(FL.module:RegisteredEventCount(), 0, "enabled module with no toggles registers nothing")
end)

Tests:Add("Flow", "repair, junk and release follow their settings", function(t)
  if not H then return end
  enable(t, "flow.repair", "flow.sellJunk", "flow.release")
  wipe(H.calls)
  Schema:Set("flow.repair", "guild")
  Schema:Set("flow.sellJunk", true)
  t:ok(FL.wanted.MERCHANT_SHOW ~= nil, "merchant event registered live")
  H.junk = 3
  H.fire("MERCHANT_SHOW")
  t:same({ called("RepairAllItems")[2] }, { nil }, "no guild funds -> own gold")
  t:ok(called("SellAllJunkItems"), "junk sold")
  Schema:Set("flow.release", "world")
  H.pvp = "arena"
  wipe(H.calls); H.fire("PLAYER_DEAD")
  t:eq(called("RepopMe"), nil, "never releases in arena")
  H.pvp = nil
  H.fire("PLAYER_DEAD")
  t:ok(called("RepopMe"), "releases in the world")
  H.junk = 0
end)

Tests:Add("Flow", "invites only from trusted players; secret GUID ignored", function(t)
  if not H then return end
  enable(t, "flow.acceptInvites")
  Schema:Set("flow.acceptInvites", true)
  wipe(H.calls)
  H.fire("PARTY_INVITE_REQUEST", "Stranger", false, false, false, false, false, "Player-1-STRANGER")
  t:eq(called("AcceptGroup"), nil, "stranger not accepted")
  H.fire("PARTY_INVITE_REQUEST", "Pal", false, false, false, false, false, "Player-1-FRIEND")
  t:ok(called("AcceptGroup"), "friend accepted")
  t:eq(FL.IsTrusted(H.secret("Player-1-FRIEND")), false, "secret GUID never trusted")
end)

Tests:Add("Flow", "camera CVar saved and restored", function(t)
  if not H then return end
  H.cvars.cameraDistanceMaxZoomFactor = "1.9"
  enable(t, "flow.maxCamera")
  Schema:Set("flow.maxCamera", true)
  t:eq(H.cvars.cameraDistanceMaxZoomFactor, "2.6", "raised")
  t:eq(Schema:Get("flow.savedCVars").cameraDistanceMaxZoomFactor, "1.9", "original kept in the profile across reloads")
  Schema:Set("module.Flow", false)
  t:eq(H.cvars.cameraDistanceMaxZoomFactor, "1.9", "restored when the module turns off")
  t:eq(next(Schema:Get("flow.savedCVars")), nil, "nothing left to restore")
end)

local QM = FL.Quiet
Tests:Add("Flow", "quiet mode: every cell off at first install; nothing registered", function(t)
  for id, row in pairs(Schema:Def("flow.quiet.where").default) do
    for c, v in pairs(row) do t:eq(v, false, id .. "/" .. c .. " off at first install (D-MOD-DEF3)") end
  end
  t:eq(#Schema:Def("flow.quiet.instances").default, 0, "no instance overrides")
  t:eq(Schema:Def("core.coexist.flow.quiet").default, "ask", "BigWigs conflict asks first")
  if not H then return end
  enable(t, "flow.quiet.where", "flow.quiet.instances")
  t:eq(FL.module:RegisteredEventCount(), 0, "Quiet mode costs nothing while every cell is off")
end)

Tests:Add("Flow", "quiet mode per content and per instance; sound CVars restored", function(t)
  if not H then return end
  enable(t, "flow.quiet.where", "flow.quiet.instances")
  H.instance = "raid"
  H.instanceInfo = { "Liberation of Undermine", "raid", 16, "Mythic", 20, 0, false, 2769 }
  t:cleanup(function() H.instance = nil; H.instanceInfo = nil end)
  local g = QM.EmptyGrid()
  g.talkingHead.raid = true
  g.music.raid = true
  g.sfxBoss.raid = true
  Schema:Set("flow.quiet.where", g)
  t:ok(QM.On("talkingHead"), "talking head hidden in raids")
  t:eq(H.cvars.Sound_EnableMusic, "0", "music muted through the CVar ledger")
  t:eq(H.cvars.Sound_EnableSFX, "1", "SFX untouched outside boss fights")
  H.fire("ENCOUNTER_START", 3009, "Vexie", 16, 20)
  t:eq(H.cvars.Sound_EnableSFX, "0", "SFX muted during the boss")
  H.fire("ENCOUNTER_END", 3009, "Vexie", 16, 20, 1)
  t:eq(H.cvars.Sound_EnableSFX, "1", "SFX back after the boss")
  Schema:Set("flow.quiet.instances", { "2769:talkingHead=off", "2769:emotes=on" })
  t:eq(QM.On("talkingHead"), false, "instance override beats the content type")
  t:ok(QM.On("emotes"), "instance can turn an option on")
  local on, src = QM.Cell("music", "raid", 2769)
  t:eq(src, "content", "untouched options inherit the content type")
  t:eq((QM.ValidateOverride("2769:music=loud")), false, "bad override text rejected")
  t:ok(QM.SetHere("music", "off"), "/pui quiet here adds a line")
  t:eq(QM.On("music"), false, "music override off")
  t:eq(H.cvars.Sound_EnableMusic, "1", "your music setting is back")
  H.addonLoaded.BigWigs = true
  QM.Recompute()
  t:eq(QM.On("emotes"), false, "stands down while BigWigs is loaded (until you pick Phoenix)")
  H.addonLoaded.BigWigs = nil
  Schema:Set("flow.quiet.where", QM.EmptyGrid())
  Schema:Set("flow.quiet.instances", {})
  t:eq(H.cvars.Sound_EnableMusic, "1", "nothing left changed")
end)

Tests:Add("Flow", "auto combat logging by content; never stops a log it did not start", function(t)
  if not H then return end
  enable(t, "flow.combatLog")
  H.logging = false
  H.instance = "raid"
  t:cleanup(function() H.instance = nil; H.logging = false end)
  Schema:Set("flow.combatLog", true)
  H.fire("PLAYER_ENTERING_WORLD")
  t:eq(H.logging, true, "logging in raids")
  H.instance = nil
  H.fire("ZONE_CHANGED_NEW_AREA")
  t:eq(H.logging, false, "stopped in the world (Flow started it)")
  H.logging = true
  H.fire("ZONE_CHANGED_NEW_AREA")
  t:eq(H.logging, true, "a log you started yourself keeps running")
end)

Tests:Add("Flow", "old single switches carried into Quiet mode; /pui cd state moved to Raid Tools", function(t)
  local sv = { profiles = { Default = { ["flow.skipCinematics"] = true, ["flow.hideTalkingHead"] = false, ["flow.countdown"] = true } } }
  t:eq(PUI.DB.migrations["0009a_flow_quiet"](sv), true, "migration ran")
  local p = sv.profiles.Default
  t:eq(p["flow.quiet.where"].movies.raid, true, "skip cinematics kept everywhere")
  t:eq(p["flow.quiet.where"].talkingHead.raid, false, "an off switch stays off")
  t:eq(p["flow.skipCinematics"], nil, "old key removed")
  t:eq(p["rt.slash"], true, "/pui cd choice kept")
end)

Tests:Add("Flow", "live preview shows the Quiet mode grid", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  enable(t, "flow.quiet.where")
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Flow(card)
  t:eq(P.State(card).flowOn, 0, "all off at first install")
  local g = FL.Quiet.EmptyGrid(); g.music.delve = true
  Schema:Set("flow.quiet.where", g)
  P.Flow(card)
  t:eq(P.State(card).flowOn, 1, "a ticked cell shows live")
end)
