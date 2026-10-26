local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Raid and Party Frames.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local RF, E = ns.RF, ns.Elements

local function enable(t, ...)
  local keys = { "module.RaidFrames", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
  Schema:Set("module.RaidFrames", true)
end

-- The harness does not run SecureGroupHeader code: make a child like the
-- header would and hand it over through the header's CallMethod target.
local function child(t, unit)
  local h = RF.headers.party
  local b = CreateFrame("Button", "PhoenixUI_RF_partyUnitButton" .. unit, h, "SecureUnitButtonTemplate")
  h:PhoenixInit(b:GetName())
  b:SetAttribute("unit", unit)
  t:cleanup(function() b:SetAttribute("unit", nil) end)
  return RF.byButton[b]
end

Tests:Add("RaidFrames", "off by default and zero cost while off", function(t)
  t:eq(Schema:Def("module.RaidFrames").default, false, "module defaults off")
  if Schema:Get("module.RaidFrames") then return end
  t:eq(RF.active, false, "inactive")
  t:eq(RF.module:RegisteredEventCount(), 0, "no module events")
  t:eq(next(RF.parked), nil, "Blizzard frames untouched")
end)

Tests:Add("RaidFrames", "every setting has a schema entry with apply", function(t)
  local n = 0
  for key, def in pairs(RF.schema) do
    n = n + 1
    t:ok(Schema:Def(key) == def, key .. " registered")
    t:eq(type(def.apply), "function", key .. " apply")
  end
  t:ok(n >= 22, "keys registered (" .. n .. ")")
end)

Tests:Add("RaidFrames", "secure headers, Blizzard frames parked, layout through Studio", function(t)
  enable(t)
  local party, raid = RF.headers.party, RF.headers.raid
  t:ok(party and raid, "party and raid headers")
  t:eq(raid:GetAttribute("groupBy"), "GROUP", "raid grouped by group")
  t:eq(party:GetAttribute("initialConfigFunction"), RF.INIT, "restricted init snippet")
  t:eq(party:GetAttribute("phx-width"), RF.settings.width, "child width attribute")
  t:eq(PUI.Layout:Frame("rf.raid"), raid, "placed through Layout (Studio)")
  if H then
    t:eq(raid.template, "SecureGroupHeaderTemplate", "secure group header")
    t:eq(H.stateDrivers[raid].visibility, "[group:raid] show; hide", "raid visibility driver")
    t:eq(PartyFrame:GetParent(), RF.hider, "Blizzard party frame parked")
  end
end)

Tests:Add("RaidFrames", "children get elements, unit routing and click-cast registration", function(t)
  if not H then return end
  enable(t)
  local o = child(t, "player")
  t:ok(o and o.content, "elements built on an unprotected content frame")
  t:eq(o.unit, "player", "unit from the header attribute")
  t:ok(RF.byUnit.player[o], "unit routing")
  t:ok(rawget(_G, "ClickCastFrames")[o.button], "registered for click-casting")
  t:eq(#o.privateAnchors, RF.settings.privateAuras, "private aura anchors added")
  H.dispellable = { player = true }
  t:cleanup(function() H.dispellable = nil end)
  H.fire("UNIT_AURA", "player")
  t:ok(o.dispel:IsShown(), "dispel highlight on UNIT_AURA")
  H.roles.player = "HEALER"
  t:cleanup(function() H.roles.player = nil end)
  H.fire("PLAYER_ROLES_ASSIGNED")
  t:ok(o.showPower and o.power:IsShown(), "healer mana bar for healers")
  H.ready = { player = "ready" }
  t:cleanup(function() H.ready = nil end)
  H.fire("READY_CHECK")
  t:eq(o.center.texture, E.READY.ready, "ready check icon")
end)

Tests:Add("RaidFrames", "settings apply live; channels follow settings", function(t)
  if not H then return end
  enable(t, "rf.sort", "rf.width", "rf.rangeFade", "rf.privateAuras")
  local o = child(t, "party1")
  Schema:Set("rf.sort", "role")
  t:eq(RF.headers.raid:GetAttribute("groupBy"), "ASSIGNEDROLE", "role sort")
  Schema:Set("rf.width", 120)
  t:eq(o.button:GetWidth(), 120, "existing children resized")
  Schema:Set("rf.rangeFade", false)
  t:eq(RF.Channels().range, nil, "range channel off")
  Schema:Set("rf.privateAuras", 0)
  t:eq(#o.privateAnchors, 0, "private aura anchors removed")
end)

Tests:Add("RaidFrames", "layout changes in combat wait; secrets only reach widgets", function(t)
  if not H then return end
  enable(t, "rf.width", "rf.healthText", "rf.colorMode")
  local o = child(t, "party2")
  H.units.party2 = true
  t:cleanup(function() H.units.party2 = nil end)
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return true end
  local w = RF.settings.width
  o.button:SetSize(w, RF.settings.height)
  Schema:Set("rf.width", w + 10)
  t:eq(o.button:GetWidth(), w, "unchanged in combat")
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:eq(o.button:GetWidth(), w + 10, "applied after combat")
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  for _, mode in ipairs({ "class", "gradient", "accent" }) do
    Schema:Set("rf.colorMode", mode)
    for _, text in ipairs({ "none", "percent", "deficit" }) do
      Schema:Set("rf.healthText", text)
      E.UpdateAll(o, RF.settings)
    end
  end
  t:ok(true, "no secret compared")
end)

Tests:Add("RaidFrames", "disabling hides headers, removes anchors and restores Blizzard", function(t)
  enable(t)
  if not H then return end
  local o = child(t, "player")
  Schema:Set("module.RaidFrames", false)
  t:eq(RF.active, false, "inactive")
  t:eq(#o.privateAnchors, 0, "anchors removed")
  t:eq(H.stateDrivers[RF.headers.raid].visibility, nil, "driver removed")
  t:eq(PartyFrame:GetParent(), UIParent, "Blizzard party frame restored")
  t:eq(next(RF.parked), nil, "nothing parked")
end)
