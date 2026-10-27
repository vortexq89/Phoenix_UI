local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Cooldown Manager deferred batch (Extras.lua).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, Ticker = PUI.Tests, PUI.Schema, PUI.Ticker
local CDM = ns.CDM
local X = CDM.Extras

local function enable(t, ...)
  local keys = { "module.CooldownManager", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end end)
  Schema:Set("module.CooldownManager", true)
end
local function spells(t, list, ids)
  for i, id in ipairs(ids) do rawset(list[i], "GetSpellID", function() return id end) end
  t:cleanup(function() for i in ipairs(ids) do rawset(list[i], "GetSpellID", nil) end end)
end

Tests:Add("CooldownManagerX", "new settings are labelled, moded, live and travel in the share string", function(t)
  t:ok(#X.KEYS >= 12, "keys")
  for _, k in ipairs(X.KEYS) do
    local d = Schema:Def(k)
    t:ok(d and d.label and d.tooltip and (d.mode == "simple" or d.mode == "advanced") and type(d.apply) == "function", k)
  end
  if not H then return end
  enable(t, "cdm.hideSpells")
  Schema:Set("cdm.hideSpells", "111, 222")
  local s = CDM.Export()
  Schema:Set("cdm.hideSpells", "")
  t:ok(CDM.Import(s) > 0, "imported")
  t:eq(Schema:Get("cdm.hideSpells"), "111, 222", "per-spell list carried by !PUI_CDM")
end)

Tests:Add("CooldownManagerX", "spell picker leaves chosen spells out of the rows and lists the tracked ones", function(t)
  if not H then return end
  local items = H.cdItems.EssentialCooldownViewer
  spells(t, items, { 501, 502, 503 })
  enable(t, "cdm.hideSpells")
  Schema:Set("cdm.hideSpells", "502")
  t:eq(CDM.active, true, "active"); t:eq(CDM.SpellOf(items[2]), 502, "spell"); t:eq(X.settings.hide[502], true, "parsed"); t:eq(CDM.cfg.essential.enabled, true, "ess"); t:eq(items[2]:GetAlpha(), 0, "hidden spell left out")
  t:eq(#CDM.Items(EssentialCooldownViewer), 2, "two left in the row")
  local text = table.concat(X.TrackedList(), "\n")
  t:ok(text:find("(502) - hidden", 1, true), "listed as hidden")
  Schema:Set("cdm.hideSpells", "")
  t:eq(items[2]:GetAlpha(), 1, "back")
end)

Tests:Add("CooldownManagerX", "cooldowns glow on procs and while their buff is up", function(t)
  if not H then return end
  local items = H.cdItems.EssentialCooldownViewer
  spells(t, items, { 601, 602, 603 })
  enable(t, "cdm.glow.mode", "cdm.glow.spells")
  Schema:Set("cdm.glow.mode", "both")
  t:ok(X.eventFrame:IsEventRegistered("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"), "listens for procs")
  H.fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 601)
  t:ok(X.glows[items[1]] and X.glows[items[1]]:IsShown(), "proc glows")
  H.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 601)
  t:eq(X.glows[items[1]]:IsShown(), false, "proc gone")
  H.auras[603] = { applications = 1 }
  t:cleanup(function() H.auras[603] = nil end)
  H.fire("UNIT_AURA", "player")
  t:ok(X.glows[items[3]] and X.glows[items[3]]:IsShown(), "buff up glows")
  Schema:Set("cdm.glow.spells", "601")
  t:eq(X.glows[items[3]]:IsShown(), false, "limited to the chosen spells")
  Schema:Set("cdm.glow.mode", "off")
  t:eq(X.eventFrame:IsEventRegistered("UNIT_AURA"), false, "off: no events")
end)

Tests:Add("CooldownManagerX", "focus kick bar and rotation assist icon", function(t)
  if not H then return end
  enable(t, "cdm.focusKick", "cdm.assist")
  Schema:Set("cdm.focusKick", true)
  t:ok(X.kickBar and X.kickBar.unit == "focus" and X.kickHost:IsShown(), "focus cast bar with kick")
  t:eq(PUI.Layout:Frame("cdm.focusKick"), X.kickHost, "moved in Studio")
  Schema:Set("cdm.focusKick", false)
  t:eq(X.kickHost:IsShown(), false, "off")
  H.assistSpell = 133
  t:cleanup(function() H.assistSpell = nil end)
  Schema:Set("cdm.assist", true)
  t:ok(Ticker:IsRegistered("cdm.assist"), "on the Ticker")
  t:eq(X.assistFrame.icon.texture, 100133, "suggested spell icon")
  H.assistSpell = nil
  X.UpdateAssist()
  t:eq(X.assistFrame.icon:GetAlpha(), 0, "nothing suggested: blank")
  Schema:Set("cdm.assist", false)
  t:eq(Ticker:IsRegistered("cdm.assist"), false, "no ticker while off")
end)

Tests:Add("CooldownManagerX", "sound when a chosen cooldown comes ready; buff bar ticks", function(t)
  if not H then return end
  local items = H.cdItems.EssentialCooldownViewer
  spells(t, items, { 701, 702, 703 })
  local cd = CreateFrame("Cooldown", nil, items[1])
  rawset(items[1], "Cooldown", cd)
  t:cleanup(function() rawset(items[1], "Cooldown", nil) end)
  enable(t, "cdm.sounds", "cdm.bars.ticks")
  Schema:Set("cdm.sounds", "701")
  local n = #H.sounds
  X.lastSound = nil
  cd.scripts.OnCooldownDone()
  t:eq(#H.sounds, n + 1, "alert played")
  local bar = H.cdItems.BuffBarCooldownViewer[1]
  local sb = CreateFrame("StatusBar", nil, bar)
  rawset(bar, "Bar", sb)
  t:cleanup(function() rawset(bar, "Bar", nil) end)
  Schema:Set("cdm.bars.ticks", "30")
  t:ok(X.ticks[bar] and X.ticks[bar][1]:IsShown(), "pandemic tick drawn")
end)

Tests:Add("CooldownManagerX", "crafted quality badge on the custom bar", function(t)
  if not H then return end
  enable(t, "cdm.custom.enabled", "cdm.custom.quality")
  H.craftedQuality[5512] = 3
  t:cleanup(function() H.craftedQuality[5512] = nil end)
  Schema:Set("cdm.custom.enabled", true)
  local b = CDM.custom[1]
  t:ok(b and X.quality[b] and X.quality[b]:IsShown(), "badge shown")
  Schema:Set("cdm.custom.quality", false)
  t:eq(X.quality[b]:IsShown(), false, "off")
end)
