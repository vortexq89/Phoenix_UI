local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Cast History (state machine, blocklists, strips).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local CH = ns.CH
local T, SR = CH.Tracker, CH.Strip

local function icons(unit) local st = SR.strips[unit]; return st and st.icons or {} end

Tests:Add("CastHistory", "owner of spell history; every key applies live", function(t)
  t:eq(Schema:Def("module.CastHistory").default, true, "on")
  t:eq(Schema:Get("ch.unit.player"), true, "your strip on")
  t:eq(Schema:Get("ch.printLink"), false, "print link is opt-in")
  for k, def in pairs(CH.schema) do t:eq(type(def.apply), "function", k .. " apply") end
end)

Tests:Add("CastHistory", "cast state machine: cast, instant, interrupted, cancelled, channel, empower held", function(t)
  if not H then return end
  Schema:Set("module.CastHistory", true)
  SR.ClearAll(); wipe(T.history)
  H.fire("UNIT_SPELLCAST_START", "player", "G1", 133)
  t:eq(#icons("player"), 1, "cast shows at start")
  H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "G1", 133)
  H.fire("UNIT_SPELLCAST_STOP", "player", "G1", 133)
  t:eq(icons("player")[1].state, "done", "finished cast")
  H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "G2", 2948)
  t:eq(#icons("player"), 2, "instant added on success")
  H.fire("UNIT_SPELLCAST_START", "player", "G3", 116)
  H.fire("UNIT_SPELLCAST_INTERRUPTED", "player", "G3", 116)
  t:eq(icons("player")[1].cross.shown, true, "interrupted cross")
  H.fire("UNIT_SPELLCAST_START", "player", "G4", 116)
  H.fire("UNIT_SPELLCAST_STOP", "player", "G4", 116)
  t:eq(icons("player")[1].state, "cancelled", "stopped without success: cancelled")
  H.fire("UNIT_SPELLCAST_FAILED", "player", "G9", 116)
  t:eq(#icons("player"), 4, "a failed press that never started adds nothing")
  H.fire("UNIT_SPELLCAST_EMPOWER_START", "player", "G5", 357208)
  t:eq(icons("player")[1].held:GetText(), "hold", "held empowered cast marked")
  H.fire("UNIT_SPELLCAST_EMPOWER_STOP", "player", "G5", 357208)
  t:eq(icons("player")[1].held:GetText(), "", "released")
  t:eq(T.History("player")[1].id, 357208, "history newest first (Embers reads it)")
  t:eq(T.History("player")[2].state, "cancelled", "history keeps the outcome")
  t:ok(PUI.Glow:IsGlowing(icons("player")[1]), "newest icon glows")
  t:eq(PUI.Glow:IsGlowing(icons("player")[2]), false, "only the newest")
  SR.ClearAll()
end)

Tests:Add("CastHistory", "secret IDs skip the blocklist and go straight to the widget; spell and item blocklists", function(t)
  if not H then return end
  Schema:Set("module.CastHistory", true)
  SR.ClearAll()
  H.fire("UNIT_SPELLCAST_SUCCEEDED", "target", H.secret("GX"), H.secret(6603))
  t:eq(#icons("target"), 1, "hidden spell shown (cannot be checked)")
  H.fire("UNIT_SPELLCAST_SUCCEEDED", "target", "G1", 6603)
  t:eq(#icons("target"), 1, "built-in list hides auto attack")
  Schema:Set("ch.blockSpells", { "2948" })
  t:cleanup(function() Schema:Set("ch.blockSpells", {}); Schema:Set("ch.blockItems", {}); H.itemSpells[5512] = nil end)
  H.fire("UNIT_SPELLCAST_SUCCEEDED", "target", "G2", 2948)
  t:eq(#icons("target"), 1, "your spell blocklist")
  H.itemSpells = H.itemSpells or {}
  H.itemSpells[5512] = 6262
  Schema:Set("ch.blockItems", { "5512" })
  H.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "G3", 6262)
  t:eq(#icons("player"), 0, "item blocklist maps the item to its spell")
  t:ok(CH.AddBlock(116), "Ctrl+Alt+click path adds to the list")
  t:eq(Schema:Get("ch.blockSpells")[2], "116", "stored as a setting")
  T.seen[133] = true; T.seen[1133] = true
  local found = T.Find("spell 1")
  t:ok(#found >= 2, "picker lists every name match")
  SR.ClearAll()
end)

Tests:Add("CastHistory", "moving strip with catch-up and pause on hover; still and fade", function(t)
  if not H then return end
  Schema:Set("module.CastHistory", true)
  SR.ClearAll()
  CH.Test()
  t:ok(PUI.Ticker:IsRegistered("ch.move"), "movement runs only while moving")
  local st = SR.strips.player
  st.hover = true
  for _ = 1, 30 do H.step(0.05) end
  t:ok(PUI.Ticker:IsRegistered("ch.move"), "paused while hovered")
  st.hover = false
  for _ = 1, 60 do H.step(0.05) end
  t:eq(PUI.Ticker:IsRegistered("ch.move"), false, "settles and stops the Ticker entry")
  t:eq(st.icons[2].offset, Schema:Get("ch.iconSize") + Schema:Get("ch.spacing"), "icons sit in their slots")
  Schema:Set("ch.mode", "fade")
  t:cleanup(function() Schema:Set("ch.mode", "move"); SR.ClearAll() end)
  CH.Test()
  t:ok(PUI.Ticker:IsRegistered("ch.fade"), "fade timer while icons show")
  H.step(10); H.step(0.3)
  t:eq(#st.icons, 0, "faded out")
  Schema:Set("ch.where", "combat")
  t:eq(st.frame:IsShown(), false, "where to show: out of combat hidden")
  Schema:Set("ch.where", "always")
end)

Tests:Add("CastHistory", "live preview follows the settings", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.CastHistory(card)
  t:eq(P.State(card).chIcons, Schema:Get("ch.count"), "sample strip uses the icon count")
  Schema:Set("ch.count", 4)
  t:cleanup(function() Schema:Set("ch.count", 8) end)
  P.CastHistory(card)
  t:eq(P.State(card).chIcons, 4, "live")
end)
