local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Action Bars.
local _, ns = ...
local H = rawget(_G, "HARNESS") -- the offline harness, nil in game
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local AB, Btn = ns.AB, ns.Buttons

local function enable(t, ...)
  local keys = { "module.ActionBars", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
  Schema:Set("module.ActionBars", true)
end

Tests:Add("ActionBars", "off by default and zero cost while off", function(t)
  t:eq(Schema:Def("module.ActionBars").default, false, "module defaults off")
  if Schema:Get("module.ActionBars") then return end
  t:eq(AB.module:RegisteredEventCount(), 0, "no events")
  for _, bar in pairs(AB.bars) do t:eq(bar.header:IsShown(), false, "bar " .. bar.index .. " hidden") end
  t:eq(next(AB.parked), nil, "no stock bar parked")
end)

Tests:Add("ActionBars", "bars, paging, slots, bindings and stock bars", function(t)
  enable(t)
  local bar1, bar2 = AB.bars[1], AB.bars[2]
  t:ok(bar1 and bar2 and AB.bars[3], "default bars 1-3 built")
  t:eq(AB.bars[4], nil, "bar 4 not built while off")
  local b = bar2.buttons[1]
  t:eq(b:GetAttribute("type"), "action", "secure action button")
  t:eq(b:GetAttribute("action"), 61, "bar 2 shows action page 6")
  t:eq(bar2.buttons[12]:GetAttribute("action"), 72, "last slot of page 6")
  t:eq(Btn.bySlot[61][b], true, "slot index kept from the attribute")
  t:eq(bar1.header:GetAttribute("_onstate-page"), AB.PAGE_SNIPPET, "paging snippet on bar 1")
  t:eq(PUI.Layout:Frame("ab.bar1"), bar1.header, "placed through Layout (Studio)")
  if not H then return end
  t:eq(H.stateDrivers[bar1.header].page, AB.PAGE_DRIVER, "paging driver registered")
  for _, cond in ipairs({ "[vehicleui]", "[overridebar]", "[possessbar]", "[shapeshift]", "[bonusbar]", "[bar:2]" }) do
    t:ok(AB.PAGE_DRIVER:find(cond, 1, true), "paging covers " .. cond)
  end
  t:ok(H.stateDrivers[bar1.header].visibility:find("[petbattle]", 1, true), "pet battle hides the bars")
  t:eq(H.overrideBindings["1"].button, "PhoenixUI_ActionBar1Button1", "ACTIONBUTTON1 key clicks the Phoenix button")
  t:eq(H.overrideBindings["SHIFT-1"].button, "PhoenixUI_ActionBar2Button1", "MULTIACTIONBAR1BUTTON1 key redirected")
  t:eq(bar1.buttons[1].hotkey:GetText(), "1", "keybind text")
  t:ok(H.rangeChecks[61], "range checks enabled for shown slots")
  t:eq(MultiBarBottomLeft:GetParent(), AB.stockHider, "stock bar parked")
  t:eq(b.icon.texture, 132242, "icon from the slot")
end)

Tests:Add("ActionBars", "settings apply live (layout, page, fade, visibility, text)", function(t)
  enable(t, "ab.bar2.buttons", "ab.bar2.perRow", "ab.bar2.size", "ab.bar2.page", "ab.bar2.fade", "ab.bar2.visibility", "ab.hotkeys")
  local bar = AB.bars[2]
  Schema:Set("ab.bar2.size", 40)
  Schema:Set("ab.bar2.perRow", 6)
  t:eq(bar.header:GetWidth(), 6 * 40 + 5 * 2, "width from size and per-row")
  Schema:Set("ab.bar2.buttons", 8)
  t:eq(bar.buttons[9]:IsShown(), false, "extra buttons hidden")
  t:eq(bar.buttons[9].live, false, "hidden buttons skip updates")
  Schema:Set("ab.bar2.page", "2")
  t:eq(bar.buttons[1]:GetAttribute("action"), 13, "page change moves the slots")
  Schema:Set("ab.bar2.fade", true)
  t:eq(bar.header:GetAttribute("fade"), true, "fade attribute for the restricted snippet")
  if H then t:eq(H.stateDrivers[bar.header].fade, "[combat] in; out", "combat fade driver") end
  Schema:Set("ab.bar2.visibility", "[combat] show; hide")
  if H then t:eq(H.stateDrivers[bar.header].visibility, "[combat] show; hide", "user visibility string") end
  Schema:Set("ab.hotkeys", false)
  t:eq(AB.bars[1].buttons[1].hotkey:GetText(), "", "keybind text off")
end)

Tests:Add("ActionBars", "bar changes in combat wait for combat to end", function(t)
  enable(t, "ab.bar4.enabled")
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return true end
  Schema:Set("ab.bar4.enabled", true)
  t:eq(AB.bars[4], nil, "not built in combat")
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:ok(AB.bars[4] and AB.bars[4].buttons[1]:GetAttribute("action") == 25, "built after combat on page 3")
end)

Tests:Add("ActionBars", "secret values only reach widgets; proc glow by slot", function(t)
  enable(t)
  if not H then return end
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  Btn.Each(Btn.Update)
  Btn.UpdateRange(AB.bars[2].buttons[2], H.secret(false))
  H.secretMode = false
  H.fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 133)
  t:eq(AB.bars[2].buttons[2].glow[1]:IsShown(), true, "glow follows FindSpellActionButtons")
  H.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 133)
  t:eq(AB.bars[2].buttons[2].glow[1]:IsShown(), false, "glow cleared")
end)

Tests:Add("ActionBars", "disabling restores stock bars and bindings", function(t)
  enable(t)
  Schema:Set("module.ActionBars", false)
  CQ.Drain()
  t:eq(AB.module:RegisteredEventCount(), 0, "no events")
  t:eq(next(AB.parked), nil, "stock bars restored")
  for _, bar in pairs(AB.bars) do t:eq(bar.header:IsShown(), false, "bar hidden") end
  if H then
    t:eq(next(H.overrideBindings), nil, "override bindings cleared")
    t:eq(MultiBarBottomLeft:GetParent(), UIParent, "stock bar back on UIParent")
    t:eq(H.stateDrivers[AB.bars[1].header].page, nil, "paging driver removed")
  end
end)
