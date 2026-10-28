local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Nameplates. Tests that enable the module restore every
-- touched setting and the module toggle in cleanup.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local NP, P, R = ns.NP, ns.Plate, ns.Rules

local function enable(t, ...)
  local keys = { "module.Nameplates", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
  Schema:Set("module.Nameplates", true)
end

local function plate(t, unit, opts)
  opts = opts or {}
  H.addPlate(unit)
  if opts.friendly then H.friendly[unit] = true end
  t:cleanup(function()
    H.fire("NAME_PLATE_UNIT_REMOVED", unit)
    H.plates[unit] = nil; H.units[unit] = nil; H.friendly[unit] = nil; H.reaction[unit] = nil
    H.creatureIDs[unit] = nil; H.forces[unit] = nil
  end)
  H.fire("NAME_PLATE_UNIT_ADDED", unit)
  return NP.plates[unit]
end

Tests:Add("Nameplates", "off by default and zero cost while off", function(t)
  t:eq(Schema:Def("module.Nameplates").default, false, "module defaults off")
  if Schema:Get("module.Nameplates") then return end
  t:eq(NP.active, false, "inactive")
  t:eq(NP.module:RegisteredEventCount(), 0, "no module events")
  t:eq(next(NP.plates), nil, "no plates owned")
  local owned = 0
  for _, rec in ipairs(PUI.CVars:List()) do for _, o in ipairs(rec.owners) do if o == "Nameplates" then owned = owned + 1 end end end
  t:eq(owned, 0, "no CVars held")
end)

Tests:Add("Nameplates", "every setting has a schema entry, simple or advanced, with apply", function(t)
  local n, simple, adv = 0, 0, 0
  for key, def in pairs(NP.schema) do
    n = n + 1
    t:ok(Schema:Def(key) == def, key .. " registered")
    t:eq(type(def.apply), "function", key .. " apply")
    t:ok(type(def.label) == "string" and type(def.tooltip) == "string", key .. " label and tooltip")
    if def.mode == "simple" then simple = simple + 1 else adv = adv + 1 end
  end
  t:ok(n >= 80, "keys registered (" .. n .. ")")
  t:ok(simple >= 20 and adv >= 40, "simple and advanced views both populated")
end)

Tests:Add("Nameplates", "friendly plates are name-only everywhere by default", function(t)
  local grid = Schema:Def("np.friendly.bars").default
  for _, c in ipairs(PUI.Visibility.CONTENT) do
    t:eq(grid.players[c], false, "players name-only in " .. c)
    t:eq(grid.npcs[c], false, "NPCs name-only in " .. c)
  end
end)

Tests:Add("Nameplates", "plates are pooled over Blizzard's and released", function(t)
  if not H then return end
  enable(t)
  local f = plate(t, "nameplate1")
  local bp = H.plates.nameplate1
  t:ok(f and f:IsShown(), "Phoenix plate shown")
  t:eq(f:GetParent(), bp, "parented to the Blizzard plate")
  t:eq(bp.UnitFrame:GetAlpha(), 0, "Blizzard UnitFrame parked at alpha 0")
  t:ok(f.health:IsShown(), "enemy plate shows health")
  H.fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
  t:eq(NP.plates.nameplate1, nil, "released")
  t:eq(bp.UnitFrame:GetAlpha(), 1, "Blizzard UnitFrame restored")
  t:ok(P.pool[#P.pool] == f, "frame back in the pool")
  t:eq(f.castBar.enabled, false, "pooled cast bar is idle")
  H.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
  t:ok(NP.plates.nameplate1 == f, "pooled frame reused")
  t:eq(f.castBar.unit, "nameplate1", "cast bar follows the new unit")
end)

Tests:Add("Nameplates", "friendly name-only or health bars per content type, live", function(t)
  if not H then return end
  enable(t, "np.friendly.bars")
  local f = plate(t, "nameplate2", { friendly = true })
  t:eq(f.nameOnly, true, "friendly is name-only by default")
  t:ok(not f.health:IsShown(), "no health bar in name-only")
  local grid = Schema:Get("np.friendly.bars")
  grid.npcs.world = true
  Schema:Set("np.friendly.bars", grid)
  t:eq(f.nameOnly, false, "health bars in the open world after ticking the box")
  t:eq(f:GetWidth(), NP.settings.friendly.width, "friendly bar size")
  local saved = NP.settings.content
  t:cleanup(function() NP.settings.content = saved end)
  NP.settings.content = "raid"
  NP.RefreshAll()
  t:eq(f.nameOnly, true, "still name-only in raids")
end)

Tests:Add("Nameplates", "settings apply live and events follow settings", function(t)
  if not H then return end
  enable(t, "np.enemy.width", "np.cast.enabled", "np.icons.execute", "np.colors.threat", "np.cast.important", "np.resource.enabled")
  local f = plate(t, "nameplate3")
  Schema:Set("np.enemy.width", 200)
  t:eq(f:GetWidth(), 200, "width applied live")
  Schema:Set("np.icons.execute", 20)
  t:ok(f.execute:IsShown(), "execute marker shown")
  Schema:Set("np.cast.enabled", false)
  t:eq(f.castBar.enabled, false, "cast bar off live")
  local events = 0
  for ev in pairs(NP.WantedEvents()) do if ev:find("SPELLCAST") then events = events + 1 end end
  t:eq(events, 0, "no cast events without cast bars")
  Schema:Set("np.cast.enabled", true)
  t:eq(f.castBar.enabled, true, "cast bar back on")
  Schema:Set("np.colors.threat", false)
  t:eq(NP.WantedEvents().UNIT_THREAT_LIST_UPDATE, nil, "no threat events without threat colours")
  t:eq(NP.WantedEvents().UNIT_POWER_UPDATE, nil, "no power events without the target resource")
  Schema:Set("np.resource.enabled", true)
  t:eq(NP.WantedEvents().UNIT_POWER_UPDATE, true, "power events with the target resource")
end)

Tests:Add("Nameplates", "cast bar is the shared PUI.CastBar with the own-kick state", function(t)
  if not H then return end
  enable(t)
  local f = plate(t, "nameplate4")
  t:ok(PUI.CastBar.bars[f.castBar], "registered with PUI.CastBar")
  t:eq(f.castBar.owner, "Nameplates", "owned by Nameplates")
  t:eq(f.castBar.style.kick, true, "own-kick indicator on")
  H.casting = true
  H.important[133] = true
  t:cleanup(function() H.casting = false; H.important[133] = nil end)
  H.fire("UNIT_SPELLCAST_START", "nameplate4")
  t:ok(f.castBar.casting, "cast shown")
  t:eq(f.important:GetAlpha(), 1, "important cast glow from IsSpellImportant")
  H.important[133] = nil
  H.fire("UNIT_SPELLCAST_START", "nameplate4")
  t:eq(f.important:GetAlpha(), 0, "no glow on ordinary casts")
end)

Tests:Add("Nameplates", "aura lanes run on PUI.Auras with their filters", function(t)
  if not H then return end
  enable(t, "np.auras.buffs.filter", "np.auras.cc.enabled")
  local f = plate(t, "nameplate5")
  t:eq(f.lanes.debuffs:GroupState("debuffs").filter, PUI.Auras.Filter("HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY"), "your plate debuffs")
  t:eq(f.lanes.cc:GroupState("cc").filter, PUI.Auras.Filter("HARMFUL|CROWD_CONTROL"), "crowd control lane")
  Schema:Set("np.auras.buffs.filter", "purgeable")
  t:eq(f.lanes.buffs:GroupState("buffs").filter, PUI.Auras.Filter("HELPFUL|DISPELLABLE"), "purgeable buffs live")
  Schema:Set("np.auras.cc.enabled", false)
  t:eq(f.lanes.cc:GroupState("cc").cap, 0, "lane off: engine cap 0")
  local friend = plate(t, "nameplate6", { friendly = true })
  t:eq(friend.lanes.debuffs:GroupState("debuffs").cap, 0, "name-only plates show no auras")
end)

Tests:Add("Nameplates", "threat colours by role, classic style and off-tank", function(t)
  t:eq(P.THREAT.tank[3], "safe", "tank holding aggro is as wanted")
  t:eq(P.THREAT.other[3], "danger", "dps holding aggro is wrong")
  t:eq(P.THREAT.classic[0], nil, "classic leaves no-aggro plates alone")
  if not H then return end
  local s = NP.settings
  H.threat = 3
  t:cleanup(function() H.threat = 0; H.group = nil; H.roles = {}; H.unitThreat = {} end)
  t:eq(P.ThreatKey("target", "TANK", s), "safe", "tank key")
  H.threat = 0
  H.group = { "player", "party1" }
  H.roles.party1 = "TANK"
  H.unitThreat.party1 = 3
  t:eq(P.ThreatKey("target", "TANK", s), "offTank", "another tank holds it")
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  t:eq(P.ThreatKey("target", "TANK", s), nil, "secret threat is never compared")
end)

Tests:Add("Nameplates", "custom NPC colours: list editor validation, priority and scale", function(t)
  t:ok(R.Validate("185680:B07CFF"), "id rule")
  t:ok(R.Validate("Void Acolyte:b07cff:1.1:glow"), "name rule with scale and glow")
  t:ok(not R.Validate("Void Acolyte"), "colour required")
  t:ok(not R.Validate("1:ZZZZZZ"), "bad colour refused")
  t:ok(not R.Validate("1:FFFFFF:9"), "scale range checked")
  t:eq(R.Label("185680:B07CFF:1.2"), "NPC 185680 - custom colour, scale 1.2", "readable label")
  if not H then return end
  enable(t, "np.rules.list", "np.rules.priority")
  H.creatureIDs.nameplate7 = 185680
  local f = plate(t, "nameplate7")
  Schema:Set("np.rules.list", { "185680:B07CFF:1.2", "185680:FF0000" })
  t:ok(f.rule and f.rule.color.r < 0.7, "first rule for an id wins")
  t:eq(f.colorWhy, "rule", "rule colour used")
  t:eq(f:GetScale(), 1.2, "rule scale")
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  P.UpdateAll(f, NP.settings)
  t:ok(not f.rule, "secret id and name never match")
end)

Tests:Add("Nameplates", "target and focus highlights, arrows and non-target alpha", function(t)
  if not H then return end
  enable(t, "np.target.nonTargetAlpha", "np.target.arrows")
  H.targetUnit, H.focusUnit = "nameplate12", "nameplate8"
  t:cleanup(function() H.targetUnit, H.focusUnit = nil, nil end)
  local f = plate(t, "nameplate12")
  local other = plate(t, "nameplate8")
  t:eq(other.focus:GetAlpha(), 1, "focus outline")
  t:eq(f.focus:GetAlpha(), 0, "no focus outline on the target")
  t:eq(f.glow:GetAlpha(), 1, "target outline")
  t:eq(f.arrows:GetAlpha(), 1, "target arrows")
  t:eq(f:GetScale(), 1.1, "target plate larger")
  t:eq(other.glow:GetAlpha(), 0, "no outline on others")
  t:eq(other:GetAlpha(), 0.6, "others faded while you have a target")
  Schema:Set("np.target.arrows", false)
  t:eq(f.arrows:GetAlpha(), 0, "arrows off live")
  Schema:Set("np.target.nonTargetAlpha", 1)
  t:eq(other:GetAlpha(), 1, "no fade at 1")
end)

Tests:Add("Nameplates", "M+ forces text comes from PUI.Season", function(t)
  if not H then return end
  enable(t, "np.icons.forces")
  H.forces.nameplate9 = { 4, 0.84, "0.84%" }
  local f = plate(t, "nameplate9")
  t:ok(not f.forces:IsShown(), "hidden outside Mythic+")
  H.mplus = { mapID = 501, level = 10, limit = 1800, elapsed = 0, deaths = 0, lost = 0 }
  t:cleanup(function() H.mplus = nil end)
  H.fire("SCENARIO_CRITERIA_UPDATE")
  t:ok(f.forces:IsShown(), "shown in Mythic+")
  t:eq(PUI.Season:UnitForces("nameplate9"), "0.84%", "provider returns the game's text")
  Schema:Set("np.icons.forces", false)
  t:ok(not f.forces:IsShown(), "off live")
end)

Tests:Add("Nameplates", "class resource on the target plate uses the Resource Bars resolver", function(t)
  if not H then return end
  local RB = PUI.ResourceBars
  if not (RB and RB.ClassResource) then return end
  enable(t, "np.resource.enabled")
  local orig = RB.ClassResource.Resolve
  RB.ClassResource.Resolve = function() return "points", 4, 5 end
  t:cleanup(function() RB.ClassResource.Resolve = orig end)
  Schema:Set("np.resource.enabled", true)
  H.targetUnit = "nameplate13"
  t:cleanup(function() H.targetUnit = nil end)
  local f = plate(t, "nameplate13")
  t:ok(f.res:IsShown(), "pips on the target plate")
  t:eq(#f.res.pips, 5, "one pip per point")
  local other = plate(t, "nameplate10")
  t:ok(not other.res:IsShown(), "not on other plates")
end)

Tests:Add("Nameplates", "secret values only reach widgets", function(t)
  if not H then return end
  enable(t, "np.enemy.healthText", "np.colors.mode", "np.icons.executeRecolor", "np.icons.execute")
  local f = plate(t, "nameplate11")
  H.secretMode, H.casting = true, true
  t:cleanup(function() H.secretMode, H.casting = false, false end)
  Schema:Set("np.icons.execute", 20)
  Schema:Set("np.icons.executeRecolor", true)
  for _, mode in ipairs({ "none", "percent", "value", "both" }) do
    Schema:Set("np.enemy.healthText", mode)
    for _, cm in ipairs({ "reaction", "class" }) do
      Schema:Set("np.colors.mode", cm)
      P.UpdateAll(f, NP.settings)
    end
  end
  t:ok(f.castBar.casting, "cast bar from a duration object")
end)

Tests:Add("Nameplates", "CVars go through the ledger out of combat and come back on disable", function(t)
  if not H then return end
  local before = H.cvars.nameplateMotion
  t:cleanup(function() H.cvars.nameplateMotion = before end)
  H.cvars.nameplateMotion = "0"
  enable(t, "np.system.stacking", "np.system.maxDistance")
  t:eq(H.cvars.nameplateMotion, "0", "nothing written until you change it")
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return true end
  Schema:Set("np.system.stacking", "stacked")
  t:eq(H.cvars.nameplateMotion, "0", "unchanged in combat")
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:eq(H.cvars.nameplateMotion, "1", "stacked after combat")
  local listed = false
  for _, rec in ipairs(PUI.CVars:List()) do if rec.name == "nameplateMotion" then listed = true end end
  t:ok(listed, "shown on the ledger page")
  Schema:Set("np.system.maxDistance", 60)
  CQ.Drain()
  t:eq(H.cvars.nameplateMaxDistance, "60", "distance written")
  Schema:Set("np.system.maxDistance", 0)
  CQ.Drain()
  t:eq(H.cvars.nameplateMaxDistance, "41", "0 gives the game's value back")
  Schema:Set("module.Nameplates", false)
  CQ.Drain()
  t:eq(H.cvars.nameplateMotion, "0", "original value restored")
end)

Tests:Add("Nameplates", "legacy step-3 keys move without resetting values", function(t)
  local prof = PUI.DB.profile
  if not prof then return end
  local keys = { "np.width", "np.friendlyNameOnly", "np.stacking", "np.enemy.width", "np.friendly.bars", "np.system.stacking" }
  local saved = {}
  for _, k in ipairs(keys) do saved[k] = prof[k] end
  t:cleanup(function() for _, k in ipairs(keys) do prof[k] = saved[k] end; NP.SyncFromDB() end)
  prof["np.enemy.width"], prof["np.friendly.bars"], prof["np.system.stacking"] = nil, nil, nil
  prof["np.width"], prof["np.friendlyNameOnly"], prof["np.stacking"] = 180, false, "overlap"
  NP.SyncFromDB()
  t:eq(prof["np.width"], nil, "old key removed")
  t:eq(Schema:Get("np.enemy.width"), 180, "width kept")
  t:eq(Schema:Get("np.friendly.bars").players.raid, true, "health bars kept where name-only was off")
  t:eq(Schema:Get("np.system.stacking"), "overlap", "stacking kept")
end)

Tests:Add("Nameplates", "preview paints samples from the same builder", function(t)
  local f = P.Build()
  for i = 1, #P.SAMPLES do P.PaintSample(f, NP.settings, i) end
  P.PaintSample(f, NP.settings, 3)
  t:ok(f.nameOnly and not f.health:IsShown(), "friendly sample is name-only")
  P.PaintSample(f, NP.settings, 1)
  t:eq(f.glow:GetAlpha(), 1, "target sample outlined")
  t:ok(f.health:IsShown(), "enemy sample has a bar")
end)
