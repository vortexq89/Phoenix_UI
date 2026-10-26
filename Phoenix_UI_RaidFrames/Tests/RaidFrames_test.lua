local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Raid and Party Frames (plan 5.2, mockup 03).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local RF, E, I = ns.RF, ns.Elements, ns.Indicators

local function enable(t, ...)
  local keys = { "module.RaidFrames", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    if RF.test then RF.SetTestMode(false) end
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
  Schema:Set("module.RaidFrames", true)
end

-- The harness does not run SecureGroupHeader code: make a child like the
-- header would and hand it over through the header's CallMethod target.
local n = 0
local function child(t, unit, kind)
  local h = RF.headers[kind or "party"]
  n = n + 1
  local b = CreateFrame("Button", "PhoenixUI_RF_testUnitButton" .. n, h, "SecureUnitButtonTemplate")
  b.GetParent = function() return h end
  h:PhoenixInit(b:GetName())
  b:SetAttribute("unit", unit)
  RF.byButton[b].unitAttr = unit
  t:cleanup(function() RF.SetUnit(RF.byButton[b], nil) end)
  RF.SetUnit(RF.byButton[b], unit)
  return RF.byButton[b]
end

Tests:Add("RaidFrames", "off by default and zero cost while off", function(t)
  t:eq(Schema:Def("module.RaidFrames").default, false, "module defaults off")
  if Schema:Get("module.RaidFrames") then return end
  t:eq(RF.active, false, "inactive")
  t:eq(RF.module:RegisteredEventCount(), 0, "no module events")
  t:eq(next(RF.parked), nil, "Blizzard frames untouched")
  t:eq(PUI.Targeting.subs["rf.dots"], nil, "no targeting subscription")
end)

Tests:Add("RaidFrames", "every setting is registered, labelled, live and the right ones overridable", function(t)
  local count = 0
  for key, def in pairs(RF.schema) do
    count = count + 1
    t:ok(Schema:Def(key) == def, key .. " registered")
    t:eq(type(def.apply), "function", key .. " apply")
    t:ok(type(def.label) == "string" and def.label ~= "", key .. " label")
    t:ok(type(def.tooltip) == "string" and def.tooltip ~= "", key .. " tooltip")
    t:ok(def.mode == "simple" or def.mode == "advanced", key .. " simple/advanced")
  end
  t:ok(count >= 90, "keys registered (" .. count .. ")")
  for _, k in ipairs({ "rf.party.width", "rf.large.height", "rf.sort", "rf.dispelStyle", "rf.debuffs.max", "rf.corners",
    "rf.privateAuras", "rf.raid.visibility", "rf.rangeFade" }) do
    t:eq(Schema:Def(k).overridable, true, k .. " overridable (per spec / content)")
  end
end)

Tests:Add("RaidFrames", "secure headers, Blizzard frames parked, layout through Studio", function(t)
  enable(t)
  local party, raid = RF.headers.party, RF.headers.raid
  t:ok(party and raid, "party and raid headers")
  t:eq(raid:GetAttribute("groupBy"), "GROUP", "raid grouped by group")
  t:eq(party:GetAttribute("initialConfigFunction"), RF.INIT, "restricted init snippet")
  t:eq(party:GetAttribute("phx-width"), RF.settings.tiers.party.width, "party child width from the party layout")
  t:eq(raid:GetAttribute("phx-width"), RF.settings.tiers[RF.tier].width, "raid child width from the active tier")
  t:eq(PUI.Layout:Frame("rf.raid"), raid, "placed through Layout (Studio)")
  if H then
    t:eq(raid.template, "SecureGroupHeaderTemplate", "secure group header")
    t:eq(H.stateDrivers[raid].visibility, "[group:raid] show; hide", "raid visibility driver")
    t:eq(PartyFrame:GetParent(), RF.hider, "Blizzard party frame parked")
  end
end)

Tests:Add("RaidFrames", "size tier follows group size; fixed tier and Mythic 20-player cap", function(t)
  if not H then return end
  enable(t, "rf.autoTier", "rf.tier", "rf.large.width", "rf.mythicCap")
  t:cleanup(function() H.group = nil; H.instanceInfo = nil end)
  t:eq(RF.TierFor(8), "small", "8 -> up to 10")
  t:eq(RF.TierFor(18), "medium", "18 -> up to 20")
  t:eq(RF.TierFor(31), "large", "31 -> up to 40")
  H.group = {}
  for i = 1, 30 do H.group[i] = "MAGE" end
  RF.OnRoster()
  CQ.Drain()
  t:eq(RF.tier, "large", "roster crossing a boundary switches the tier")
  Schema:Set("rf.large.width", 66)
  t:eq(RF.headers.raid:GetAttribute("phx-width"), 66, "tier width applied live")
  Schema:Set("rf.autoTier", false)
  Schema:Set("rf.tier", "small")
  t:eq(RF.tier, "small", "fixed tier when automatic is off")
  H.instanceInfo = { "Raid", "raid", 16 }
  RF.ApplyLayout()
  t:eq(RF.headers.raid:GetAttribute("groupFilter"), "1,2,3,4", "Mythic: groups 1-4 only")
  Schema:Set("rf.mythicCap", false)
  t:eq(RF.headers.raid:GetAttribute("groupFilter"), "1,2,3,4,5,6,7,8", "cap off: all groups")
end)

Tests:Add("RaidFrames", "sorting, role order and growth become header attributes", function(t)
  enable(t, "rf.sort", "rf.roleOrder", "rf.partySort", "rf.medium.growUp", "rf.medium.orientation", "rf.medium.growLeft",
    "rf.autoTier", "rf.tier")
  Schema:Set("rf.autoTier", false)
  Schema:Set("rf.tier", "medium")
  Schema:Set("rf.sort", "role")
  Schema:Set("rf.roleOrder", "HEALER,TANK,DAMAGER")
  local raid, party = RF.headers.raid, RF.headers.party
  t:eq(raid:GetAttribute("groupBy"), "ASSIGNEDROLE", "role sort")
  t:eq(raid:GetAttribute("groupingOrder"), "HEALER,TANK,DAMAGER,NONE", "role order")
  Schema:Set("rf.partySort", "role")
  t:eq(party:GetAttribute("groupBy"), "ASSIGNEDROLE", "party by role")
  Schema:Set("rf.partySort", "name")
  t:eq(party:GetAttribute("sortMethod"), "NAME", "party by name")
  Schema:Set("rf.medium.growUp", true)
  t:eq(raid:GetAttribute("point"), "BOTTOM", "grow upwards")
  t:ok(raid:GetAttribute("yOffset") > 0, "positive y offset upwards")
  Schema:Set("rf.medium.orientation", "horizontal")
  Schema:Set("rf.medium.growLeft", true)
  t:eq(raid:GetAttribute("point"), "RIGHT", "rows grow left")
  t:eq(raid:GetAttribute("columnAnchorPoint"), "BOTTOM", "rows stack upwards")
end)

Tests:Add("RaidFrames", "children get elements, routing, click-cast, private anchors and dispel colour", function(t)
  if not H then return end
  enable(t, "rf.privatePoint", "rf.privateNumbers")
  local o = child(t, "player")
  t:ok(o and o.content, "elements built on an unprotected content frame")
  t:eq(o.unit, "player", "unit routing")
  t:ok(RF.byUnit.player[o], "unit routing table")
  t:ok(rawget(_G, "ClickCastFrames")[o.button], "registered for click-casting")
  t:eq(#o.privateAnchors, RF.settings.privateAuras, "private aura anchors added")
  Schema:Set("rf.privatePoint", "TOPLEFT")
  Schema:Set("rf.privateNumbers", true)
  local args = H.privateAnchors[o.privateAnchors[1]]
  t:eq(args.iconInfo.iconAnchor.point, "TOPLEFT", "private anchor point setting")
  t:eq(args.showCountdownNumbers, true, "countdown numbers setting")
  H.dispellable = { player = true }
  t:cleanup(function() H.dispellable = nil end)
  local calls = H.dispelColorCalls or 0
  H.fire("UNIT_AURA", "player")
  t:ok(o.dispel:IsShown(), "dispel border on UNIT_AURA")
  t:ok((H.dispelColorCalls or 0) > calls, "coloured by debuff type through the engine curve")
  H.roles.player = "HEALER"
  t:cleanup(function() H.roles.player = nil end)
  H.fire("PLAYER_ROLES_ASSIGNED")
  t:ok(o.showPower and o.power:IsShown(), "healer mana bar for healers")
  H.ready = { player = "ready" }
  t:cleanup(function() H.ready = nil end)
  H.fire("READY_CHECK")
  t:eq(o.center.texture, E.READY.ready, "ready check icon")
end)

Tests:Add("RaidFrames", "dispel styles, role styles and colour modes apply live", function(t)
  if not H then return end
  enable(t, "rf.dispelStyle", "rf.dispelSource", "rf.roleStyle", "rf.roleHideDamager", "rf.colorMode")
  local o = child(t, "party1")
  H.units.party1 = true
  H.dispellable = { party1 = true }
  H.roles.party1 = "DAMAGER"
  t:cleanup(function() H.units.party1 = nil; H.dispellable = nil; H.roles.party1 = nil end)
  Schema:Set("rf.dispelStyle", "tint")
  t:ok(o.tint:IsShown() and not o.dispel:IsShown(), "tint style")
  Schema:Set("rf.dispelStyle", "glow")
  t:ok(PUI.Glow:IsGlowing(o.content), "glow style")
  Schema:Set("rf.dispelStyle", "both")
  t:ok(o.tint:IsShown() and o.dispel:IsShown() and not PUI.Glow:IsGlowing(o.content), "border and tint")
  Schema:Set("rf.dispelSource", "all")
  t:ok(o.dispel:IsShown(), "any dispellable debuff")
  Schema:Set("rf.roleStyle", "letter")
  t:ok(o.roleText:IsShown() and o.roleText:GetText() == "D", "role letter")
  Schema:Set("rf.roleHideDamager", true)
  t:ok(not o.roleText:IsShown() and not o.role:IsShown(), "damage role hidden")
  Schema:Set("rf.colorMode", "custom")
  t:ok(true, "custom colour applied")
end)

Tests:Add("RaidFrames", "aura icons run on PUI.Auras; lockout preset; settings live", function(t)
  if not H then return end
  enable(t, "rf.debuffs.max", "rf.buffs.enabled", "rf.debuffs.filter", "rf.lockouts")
  local o = child(t, "party2")
  local deb = o.auras and o.auras.debuffs
  t:ok(deb and deb.container, "debuff container from the aura engine")
  t:eq(deb:GroupState("debuffs").filter, PUI.Auras.Filter("HARMFUL|RAID_IN_COMBAT"), "raid-rules filter")
  Schema:Set("rf.debuffs.max", 5)
  t:eq(deb:GroupState("debuffs").cap, 5, "count applied live")
  Schema:Set("rf.debuffs.filter", "dispellable")
  t:eq(deb:GroupState("debuffs").filter, PUI.Auras.Filter("HARMFUL|RAID_PLAYER_DISPELLABLE"), "filter applied live")
  t:same(deb.exclusions, PUI.Auras.LOCKOUTS, "lockout debuffs excluded")
  Schema:Set("rf.lockouts", false)
  t:same(deb.exclusions, {}, "lockouts shown when the preset is off")
  Schema:Set("rf.buffs.enabled", false)
  t:eq(o.auras.buffs:GroupState("buffs").cap, 0, "buffs off -> engine cap 0")
  t:ok(o.auras.defensive and o.auras.defensive:GroupState("external").cap > 0, "big + external defensive groups")
end)

Tests:Add("RaidFrames", "corner indicators: parse, validate, presets and live squares", function(t)
  if not H then return end
  enable(t, "rf.corners")
  local e = I.ParseCorner("TOPLEFT:774:mine:3DDC97")
  t:eq(e.point, "TOPLEFT", "corner")
  t:eq(e.id, 774, "spell id")
  t:eq(e.mine, true, "mine")
  t:eq(I.ParseCorner("MIDDLE:774"), nil, "unknown corner rejected")
  t:eq(I.ParseCorner("TOPLEFT:774:who"), nil, "bad who rejected")
  t:throws(function() Schema:Set("rf.corners", { "nonsense" }) end, "invalid list item refused")
  for class, list in pairs(I.PRESETS) do
    for _, item in ipairs(list) do t:ok(I.ValidateCorner(item), class .. " preset " .. item) end
  end
  local o = child(t, "party3")
  H.units.party3 = true
  t:cleanup(function() H.units.party3 = nil; H.unitAuras.party3 = nil end)
  Schema:Set("rf.corners", { "TOPLEFT:774:mine", "TOPLEFT:33763:any" })
  t:eq(#RF.corners, 2, "compiled")
  t:eq(RF.corners[2].slot, 2, "second square in the same corner")
  t:ok(RF.Channels().aura, "aura channel on for corners")
  H.unitAuras.party3 = { [33763] = true }
  H.fire("UNIT_AURA", "party3")
  t:ok(not o.corners[1]:IsShown() and o.corners[2]:IsShown(), "square follows the aura")
  t:ok(I.CornerLabel("TOPLEFT:774:mine"):find("Top left", 1, true) ~= nil, "friendly label")
end)

Tests:Add("RaidFrames", "enemy target dots come from the shared targeting service", function(t)
  if not H then return end
  enable(t, "rf.targetDots")
  local o = child(t, "party4")
  H.units.party4, H.units.arena1, H.units.arena2 = true, true, true
  H.instance = "arena"
  H.unitTargets = { arena1 = "party4", arena2 = "party1" }
  t:cleanup(function() H.units.party4, H.units.arena1, H.units.arena2 = nil, nil, nil; H.instance = nil; H.unitTargets = {} end)
  t:ok(PUI.Targeting.subs["rf.dots"] ~= nil, "subscribed")
  H.fire("UNIT_TARGET", "arena1")
  H.step()
  t:ok(o.dots[1]:IsShown() and o.dots[1].alphaFlag == true, "arena1 targets this member")
  t:ok(o.dots[2]:IsShown() and o.dots[2].alphaFlag == false, "arena2 targets someone else")
  t:ok(not o.dots[3]:IsShown(), "no third enemy")
  Schema:Set("rf.targetDots", false)
  t:eq(PUI.Targeting.subs["rf.dots"], nil, "unsubscribed when off")
  t:ok(not o.dots[1]:IsShown(), "dots hidden")
end)

Tests:Add("RaidFrames", "range uses PUI.Range; prediction overflow marks; channels follow settings", function(t)
  if not H then return end
  enable(t, "rf.rangeFade", "rf.overflow", "rf.heals", "rf.absorbs", "rf.healAbsorbs", "rf.privateAuras")
  local o = child(t, "party1")
  t:ok(o.range ~= nil, "range handle")
  t:ok(PUI.Ticker:IsRegistered("range.poll"), "one shared range poll")
  Schema:Set("rf.rangeFade", false)
  t:eq(o.range, nil, "released when off")
  E.UpdatePrediction(o, RF.settings)
  t:eq(o.pred.overHeal.alphaFlag, false, "heal-absorb overflow flag goes to the widget")
  Schema:Set("rf.overflow", false)
  t:eq(o.pred.overHeal:GetAlpha(), 0, "overflow marks off")
  Schema:Set("rf.heals", false); Schema:Set("rf.absorbs", false); Schema:Set("rf.healAbsorbs", false)
  t:eq(RF.Channels().prediction, nil, "prediction channel off")
  Schema:Set("rf.privateAuras", 0)
  t:eq(#o.privateAnchors, 0, "private aura anchors removed")
end)

Tests:Add("RaidFrames", "where to show fades the header; test mode lays out sample members", function(t)
  if not H then return end
  enable(t, "rf.raid.visibility", "rf.hiddenAlpha", "rf.autoTier")
  Schema:Set("rf.hiddenAlpha", 0.2)
  Schema:Set("rf.raid.visibility", { mode = "never" })
  for _ = 1, 3 do H.step() end
  t:eq(RF.headers.raid:GetAlpha(), 0.2, "hidden alpha from the rule")
  local why = select(2, PUI.Visibility:Why("rf.raid"))
  t:ok(why ~= nil, "a why-hidden reason")
  t:ok(RF.SetTestMode(true, 20), "test mode on")
  t:eq(RF.testTier, "medium", "20 members -> up to 20 layout")
  local shown = 0
  for _, f in ipairs(RF.testFrames) do if f.button:IsShown() then shown = shown + 1 end end
  t:eq(shown, 20, "20 sample members")
  t:eq(RF.headers.raid:GetAlpha(), 0, "live headers faded while testing")
  local tt = RF.settings.tiers.medium
  local x, y = RF.TestPosition(6, tt)
  t:eq(x, tt.width + tt.groupSpacing, "member 6 starts group 2")
  t:eq(y, 0, "at the top")
  RF.SetTestMode(true, 5)
  t:eq(RF.testTier, "party", "5 -> party layout")
  H.fire("PLAYER_REGEN_DISABLED")
  t:eq(RF.test, false, "combat ends test mode")
  local probe = InCombatLockdown
  t:cleanup(function() InCombatLockdown = probe end)
  InCombatLockdown = function() return true end
  local ok = RF.SetTestMode(true)
  t:eq(ok, false, "refused in combat")
end)

Tests:Add("RaidFrames", "layout changes in combat wait; secrets only reach widgets", function(t)
  if not H then return end
  enable(t, "rf.party.width", "rf.healthText", "rf.colorMode", "rf.dispelStyle", "rf.roleStyle")
  local o = child(t, "party2")
  H.units.party2 = true
  t:cleanup(function() H.units.party2 = nil end)
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return true end
  local w = RF.settings.tiers.party.width
  o.button:SetSize(w, RF.settings.tiers.party.height)
  Schema:Set("rf.party.width", w + 10)
  t:eq(o.button:GetWidth(), w, "unchanged in combat")
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:eq(o.button:GetWidth(), w + 10, "applied after combat")
  H.secretMode = true
  H.dispellable = { party2 = true }
  t:cleanup(function() H.secretMode = false; H.dispellable = nil end)
  for _, mode in ipairs({ "class", "gradient", "accent", "custom" }) do
    Schema:Set("rf.colorMode", mode)
    for _, text in ipairs({ "none", "percent", "deficit", "current" }) do
      Schema:Set("rf.healthText", text)
      for _, style in ipairs({ "border", "glow", "tint", "both" }) do
        Schema:Set("rf.dispelStyle", style)
        E.UpdateAll(o, RF.settings)
        I.UpdateCorners(o, RF.settings)
      end
    end
  end
  Schema:Set("rf.roleStyle", "letter")
  t:ok(true, "no secret compared")
end)

Tests:Add("RaidFrames", "legacy size keys move into every tier, never reset", function(t)
  local DB = PUI.DB
  local saved = {}
  for _, k in ipairs({ "rf.width", "rf.party.width", "rf.small.width", "rf.medium.width", "rf.large.width" }) do saved[k] = DB.profile[k] end
  t:cleanup(function() for k, v in pairs(saved) do DB.profile[k] = v end; RF.SyncFromDB() end)
  DB.profile["rf.width"] = 123
  DB.profile["rf.small.width"] = 77
  t:eq(RF.MigrateLegacy(), 1, "one legacy key moved")
  t:eq(DB.profile["rf.width"], nil, "legacy key removed")
  t:eq(DB.profile["rf.party.width"], 123, "party gets it")
  t:eq(DB.profile["rf.small.width"], 77, "an existing tier value is kept")
end)

Tests:Add("RaidFrames", "disabling hides headers, removes anchors, stops services and restores Blizzard", function(t)
  enable(t)
  if not H then return end
  local o = child(t, "player")
  Schema:Set("module.RaidFrames", false)
  t:eq(RF.active, false, "inactive")
  t:eq(#o.privateAnchors, 0, "anchors removed")
  t:eq(H.stateDrivers[RF.headers.raid].visibility, nil, "driver removed")
  t:eq(PartyFrame:GetParent(), UIParent, "Blizzard party frame restored")
  t:eq(next(RF.parked), nil, "nothing parked")
  t:eq(PUI.Targeting.subs["rf.dots"], nil, "targeting released")
  t:eq(PUI.Visibility.watchers["rf.raid"], nil, "visibility unwatched")
  t:eq(o.range, nil, "range released")
end)
