local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the first-install wizard and presets.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local SU, P = ns.SU, ns.P

local function snapshot(t)
  local keys = { "setup.state", "layout.positions", "theme.accent", "theme.panel", "core.locale", "module.Skins" }
  for _, m in ipairs(P.MANAGED) do if Schema:Def("module." .. m) then keys[#keys + 1] = "module." .. m end end
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
end

Tests:Add("Setup", "six steps, five role presets, three layouts, four looks", function(t)
  t:eq(#SU.STEPS, 6, "six steps")
  t:eq(SU.STEPS[6], "skins", "skins is the last step")
  t:eq(#P.ROLE_ORDER, 5, "role presets")
  t:eq(#P.LAYOUT_ORDER, 3, "layout presets")
  t:eq(#P.LOOK_ORDER, 4, "looks")
  for _, id in ipairs(P.LAYOUT_ORDER) do
    for elem in pairs(P.LAYOUTS[id].positions) do t:ok(PUI.Layout:Element(elem) ~= nil, id .. " uses a real element " .. elem) end
  end
  t:eq(SU.PixelScale(), 0.5333 < 0.64 and 0.64 or 0.5333, "pixel scale clamps to the game's minimum")
end)

Tests:Add("Setup", "applying choices sets modules, layout, look and saves CVars to restore", function(t)
  if not H then return end
  snapshot(t)
  H.cvars.uiScale = "0.9"
  SU.ApplyChoices({ language = "enUS", scale = "pixel", role = "minimal", layout = "healer", look = "blizzard" })
  t:eq(Schema:Get("module.Tooltip"), true, "minimal keeps tooltip")
  t:eq(Schema:Get("module.UnitFrames"), false, "minimal turns unit frames off")
  t:eq(Schema:Get("module.Skins"), false, "Blizzard look turns skins off")
  t:eq(Schema:Get("layout.positions")["rf.raid"].y, -230, "healer layout written")
  t:eq(H.cvars.uiScale, "0.64", "pixel scale applied")
  t:eq(SU.State().cvars.uiScale, "0.9", "original scale saved")
  t:eq(SU.State().wizardDone, true, "wizard marked done")
  wipe(H.calls); wipe(H.disabled)
  t:eq(SU.Uninstall(), false, "uninstall asks for confirmation")
  SU.Uninstall("confirm")
  t:eq(H.cvars.uiScale, "0.9", "CVar restored")
  t:same(H.disabled, { "Phoenix_UI", "Phoenix_UI_Skins" }, "only Phoenix addons disabled")
end)

Tests:Add("Setup", "wizard navigation and cycling", function(t)
  if not H then return end
  snapshot(t)
  SU.OpenWizard()
  CQ.Drain()
  t:ok(SU.frame:IsShown(), "wizard open")
  t:eq(SU.step, 0, "opens on the welcome page")
  t:ok(SU.frame.pages.welcome:IsShown(), "welcome shown")
  SU.Go(1); SU.Go(1); SU.Go(1)
  t:eq(SU.STEPS[SU.step], "role", "third step")
  SU.choices.role = "dps"
  SU.Cycle("role", 1)
  t:eq(SU.choices.role, "healer", "cycled from dps to healer")
  SU.Go(1); SU.Go(1)
  t:eq(SU.STEPS[SU.step], "look", "look step")
  SU.frame.pages.look.swatches[5]:GetScript("OnClick")()
  t:eq(Schema:Get("theme.accent"), "frost", "accent previews live")
  SU.choices.scale = 0.7
  SU.Go(1)
  t:eq(SU.STEPS[SU.step], "skins", "skins step after look")
  t:ok(SU.frame.pages.skins:IsShown(), "skins page shown")
  t:eq(#SU.frame.pages.skins.cards, 2, "Phoenix and Blizzard cards with previews")
  t:ok(SU.frame.pages.skins.cards[1].preview ~= nil, "preview drawn")
  SU.frame.pages.skins.cards[1]:GetScript("OnClick")()
  t:eq(SU.choices.skins, true, "Phoenix skins chosen")
  SU.Go(1)
  t:ok(SU.frame.pages.finish:IsShown(), "finish page after applying")
  t:eq(H.cvars.uiScale, "0.7", "fine-tuned scale applied")
  t:eq(SU.State().wizardDone, true, "done without a reload")
  t:eq(Schema:Get("module.Skins"), true, "skins turned on live from the wizard")
  SU.Go(1)
  t:ok(not SU.frame:IsShown(), "enter the game closes")
end)
