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
    if def.type == "select" then t:eq(def.default, "off", key .. " defaults off") end
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
  Schema:Set("module.Flow", false)
  t:eq(H.cvars.cameraDistanceMaxZoomFactor, "1.9", "restored when the module turns off")
end)
