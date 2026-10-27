local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Action Bars deferred batch (Extras.lua).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local AB, Btn, SP, KB = ns.AB, ns.Buttons, ns.Special, ns.KB
local X = AB.Extras

local function enable(t, ...)
  local keys = { "module.ActionBars", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
  Schema:Set("module.ActionBars", true)
  CQ.Drain()
end

Tests:Add("ActionBarsX", "every new setting is in the schema with a label, tooltip and live apply", function(t)
  t:ok(#X.KEYS >= 20, "keys (" .. #X.KEYS .. ")")
  for _, k in ipairs(X.KEYS) do
    local d = Schema:Def(k)
    t:ok(d and type(d.apply) == "function" and d.label and d.tooltip and (d.mode == "simple" or d.mode == "advanced"), k)
  end
end)

Tests:Add("ActionBarsX", "micro menu and bag bar fade, hide and scale, then come back", function(t)
  if not H then return end
  local micro = CreateFrame("Frame", "MicroMenuContainer")
  t:cleanup(function() _G.MicroMenuContainer = nil end)
  rawset(_G, "MicroMenuContainer", micro)
  enable(t, "ab.micro.mode", "ab.micro.scale")
  Schema:Set("ab.micro.mode", "hide"); CQ.Drain()
  t:eq(micro:GetAlpha(), 0, "hidden by alpha")
  Schema:Set("ab.micro.mode", "fade"); CQ.Drain()
  t:ok(PUI.Ticker:IsRegistered("ab.containerFade"), "fade on one Ticker entry")
  Schema:Set("ab.micro.scale", 0.8); CQ.Drain()
  t:eq(micro:GetScale(), 0.8, "scaled")
  Schema:Set("ab.micro.mode", "game"); Schema:Set("ab.micro.scale", 1); CQ.Drain()
  t:eq(micro:GetScale(), 1, "scale back")
  t:eq(micro:GetAlpha(), 1, "alpha back")
  t:eq(PUI.Ticker:IsRegistered("ab.containerFade"), false, "no fade job")
end)

Tests:Add("ActionBarsX", "right-click on a pet button toggles autocast through a secure macro", function(t)
  if not H then return end
  H.petActions[1] = { name = "Growl", texture = 1, isToken = false }
  t:cleanup(function() H.petActions[1] = nil end)
  enable(t, "ab.pet.rightClickAutocast")
  SP.Apply("pet"); CQ.Drain()
  local b = SP.bars.pet and SP.bars.pet.buttons[1]
  if not b then return end
  t:eq(b:GetAttribute("type2"), "macro", "right button runs a macro")
  t:eq(b:GetAttribute("macrotext2"), "/petautocasttoggle Growl", "toggles that ability")
  Schema:Set("ab.pet.rightClickAutocast", false); CQ.Drain()
  t:eq(b:GetAttribute("type2"), nil, "off: right-click casts as before")
end)

Tests:Add("ActionBarsX", "keybind mode takes mouse buttons and the wheel; the key sheet lists bars", function(t)
  if not H then return end
  enable(t)
  local seen
  local base = KB.OnKey
  KB.OnKey = function(k) seen = k end
  t:cleanup(function() KB.OnKey = base; KB.on = false end)
  KB.on = true
  t:ok(X.OnMouseKey("Button4"), "mouse 4 captured")
  t:eq(seen, "BUTTON4", "as BUTTON4")
  t:eq(X.OnMouseKey("LeftButton"), false, "left click is still a click")
  X.OnWheel(-1)
  t:eq(seen, "MOUSEWHEELDOWN", "wheel down")
  KB.on = false
  t:eq(X.OnMouseKey("Button5"), false, "nothing outside keybind mode")
  local sheet = X.Sheet()
  t:ok(sheet:find("Bar 1", 1, true) and sheet:find("1: 1", 1, true), "sheet lists bar 1 and its key")
end)

Tests:Add("ActionBarsX", "per-button overrides parse, validate and apply live", function(t)
  t:ok(X.ParseOverride("1.12:nohotkey,alpha=0.6"), "parses")
  t:eq(select(2, X.ParseOverride("1.13:hide")), "bar 1-" .. #AB.DEFS .. ", button 1-12", "range checked")
  t:eq(select(2, X.ParseOverride("2.1:sparkle")), "unknown option 'sparkle'", "unknown option refused")
  if not H then return end
  enable(t, "ab.buttonOverrides")
  Schema:Set("ab.buttonOverrides", { "1.1:nohotkey,alpha=0.5" }); CQ.Drain()
  local b = AB.bars[1].buttons[1]
  t:eq(b.hotkey:GetText(), "", "hotkey text gone on that button only")
  t:eq(b:GetAlpha(), 0.5, "alpha")
  t:eq(AB.bars[1].buttons[2].hotkey:GetText(), "2", "other buttons untouched")
  Schema:Set("ab.buttonOverrides", {}); CQ.Drain()
  t:eq(b:GetAlpha(), 1, "back")
  t:eq(b.hotkey:GetText(), "1", "hotkey back")
end)

Tests:Add("ActionBarsX", "cooldown numbers coloured by an engine curve on one Ticker entry", function(t)
  if not H then return end
  enable(t, "ab.cdColors")
  local b = AB.bars[2].buttons[1]
  local fs = CreateFrame("Frame"):CreateFontString()
  rawset(b.cooldown, "GetCountdownFontString", function() return fs end)
  t:cleanup(function() rawset(b.cooldown, "GetCountdownFontString", nil) end)
  Schema:Set("ab.cdColors", true)
  t:ok(PUI.Ticker:IsRegistered("ab.cdColors"), "armed")
  H.step(0.3)
  t:ok(H.evaluated and H.evaluated.isColor, "the countdown was evaluated by a colour curve (no Lua maths)")
  t:eq(fs.textColor[1], 1, "red")
  Schema:Set("ab.cdColors", false)
  t:eq(PUI.Ticker:IsRegistered("ab.cdColors"), false, "disarmed")
end)

Tests:Add("ActionBarsX", "bars hide in housing and with a gamepad, and come back", function(t)
  if not H then return end
  enable(t, "ab.hide.housing", "ab.hide.gamepad")
  Schema:Set("ab.hide.housing", true)
  H.inHouse = true
  t:cleanup(function() H.inHouse = false end)
  H.fire("ZONE_CHANGED_INDOORS"); CQ.Drain()
  t:eq(H.stateDrivers[AB.bars[1].header].visibility, "hide", "hidden inside the house")
  H.inHouse = false
  H.fire("ZONE_CHANGED_INDOORS"); CQ.Drain()
  t:ok(H.stateDrivers[AB.bars[1].header].visibility ~= "hide", "back outside")
  Schema:Set("ab.hide.gamepad", true)
  H.fire("GAME_PAD_ACTIVE_CHANGED", true); CQ.Drain()
  t:eq(H.stateDrivers[AB.bars[1].header].visibility, "hide", "hidden with a gamepad")
  H.fire("GAME_PAD_ACTIVE_CHANGED", false); CQ.Drain()
  t:ok(H.stateDrivers[AB.bars[1].header].visibility ~= "hide", "back with mouse and keyboard")
end)

Tests:Add("ActionBarsX", "Edit Mode bar positions are taken once, never over a moved bar", function(t)
  if not H then return end
  local pos = Schema:Get("layout.positions")
  local g = PUI.DB.sv.global
  local was = g.abEditModeCaptured
  t:cleanup(function() Schema:Set("layout.positions", pos); g.abEditModeCaptured = was; H.editMode = { layouts = {}, activeLayout = 1 } end)
  H.editMode = { activeLayout = 1, layouts = { { systems = {
    { system = 0, systemIndex = 2, anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 10.4, offsetY = 90 } },
    { system = 0, systemIndex = 3, anchorInfo = { point = "BOTTOM", relativeTo = "MainActionBar", relativePoint = "TOP", offsetX = 0, offsetY = 4 } },
  } } } }
  local p = Schema.Copy(pos); p["ab.bar1"] = { point = "CENTER", x = 1, y = 2 }
  Schema:Set("layout.positions", p)
  g.abEditModeCaptured = nil
  t:eq(X.CaptureEditMode(false), 1, "one bar taken")
  local now = Schema:Get("layout.positions")
  t:eq(now["ab.bar2"].x, 10, "bar 2 from Edit Mode")
  t:eq(now["ab.bar3"], nil, "bars anchored to other bars are skipped")
  t:eq(now["ab.bar1"].x, 1, "your own position kept")
  t:eq(X.CaptureEditMode(false), 0, "only once")
end)

Tests:Add("ActionBarsX", "looks and icon masks apply to every button live", function(t)
  if not H then return end
  enable(t, "ab.look", "ab.mask")
  Schema:Set("ab.look", "blizzard")
  local b = AB.bars[1].buttons[1]
  t:ok(rawget(b, "puiFrame") and b.puiFrame:IsShown(), "Blizzard frame drawn")
  t:eq(b.edges[1]:IsShown(), false, "flat border off")
  Schema:Set("ab.mask", "circle")
  t:ok(rawget(b, "puiMask") ~= nil, "mask applied")
  Schema:Set("ab.look", "phoenix"); Schema:Set("ab.mask", "square")
  t:eq(b.puiFrame:IsShown(), false, "Phoenix look again")
  t:eq(rawget(b, "puiMask"), nil, "mask removed")
end)

Tests:Add("ActionBarsX", "reverse CDM dedupe hides buttons the cooldown manager shows, and stands down on conflict", function(t)
  if not H then return end
  enable(t, "ab.cdmDedupe")
  local base = X.CdmSpells
  X.CdmSpells = function() return { [5000] = true } end
  H.actionInfo[61] = { "spell", 5000 }
  t:cleanup(function() X.CdmSpells = base; H.actionInfo[61] = nil end)
  Schema:Set("ab.cdmDedupe", true)
  local b = AB.bars[2].buttons[1]
  t:eq(b:GetAlpha(), 0, "hidden: shown in the CDM")
  Schema:Set("ab.cdmDedupe", false)
  t:eq(b:GetAlpha(), 1, "back")
end)
