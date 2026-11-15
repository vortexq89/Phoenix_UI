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
  t:eq(PUI.Glow:IsGlowing(AB.bars[2].buttons[2]), true, "glow follows FindSpellActionButtons (PUI.Glow)")
  H.fire("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 133)
  t:eq(PUI.Glow:IsGlowing(AB.bars[2].buttons[2]), false, "glow cleared")
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

-- Step 6 ---------------------------------------------------------------------------
Tests:Add("ActionBars", "keybind text: short names and the binding ledger", function(t)
  enable(t, "ab.keyAbbrev")
  t:eq(Btn.Abbrev("SHIFT-1"), "S1", "shift")
  t:eq(Btn.Abbrev("CTRL-MOUSEWHEELUP"), "CWU", "ctrl + wheel")
  t:eq(Btn.Abbrev("BUTTON4"), "M4", "mouse button")
  t:eq(Btn.Abbrev("ALT-NUMPAD5"), "AN5", "numpad")
  t:eq(AB.bars[2].buttons[1].hotkey:GetText(), "S1", "short text on the button")
  Schema:Set("ab.keyAbbrev", false)
  t:eq(AB.bars[2].buttons[1].hotkey:GetText(), "SHIFT-1", "full text when off")
  local found = false
  for _, e in ipairs(PUI.Bindings:List()) do if e.key == "1" and e.owner == "ActionBars" then found = true end end
  t:ok(found, "redirect recorded in the binding ledger")
end)

Tests:Add("ActionBars", "paging: forms, skyriding and modifier paging", function(t)
  enable(t, "ab.bar1.formPaging", "ab.bar1.skyridingPaging", "ab.bar2.pageMod", "ab.bar2.pageModTo")
  t:eq(AB.PageDriver(1), AB.PAGE_DRIVER, "defaults give the standard driver")
  Schema:Set("ab.bar1.formPaging", false)
  t:ok(not AB.PageDriver(1):find("[shapeshift]", 1, true), "form paging off")
  t:ok(AB.PageDriver(1):find("[vehicleui]", 1, true), "vehicles still page")
  Schema:Set("ab.bar1.skyridingPaging", false)
  t:ok(AB.PageDriver(1):find("[bonusbar:5] 1", 1, true), "skyriding keeps page 1")
  Schema:Set("ab.bar2.pageMod", "shift")
  Schema:Set("ab.bar2.pageModTo", "3")
  t:eq(AB.PageDriver(2), "[mod:shift] 3; 6", "modifier paging driver")
  if H then t:eq(H.stateDrivers[AB.bars[2].header].page, "[mod:shift] 3; 6", "registered on bar 2") end
  t:eq(AB.bars[2].header:GetAttribute("_onstate-page"), AB.PAGE_SNIPPET, "same restricted snippet")
  Schema:Set("ab.bar2.pageMod", "none")
  if H then t:eq(H.stateDrivers[AB.bars[2].header].page, nil, "driver removed") end
end)

Tests:Add("ActionBars", "where to show: secure parts in the driver, the rest through PUI.Visibility", function(t)
  enable(t, "ab.bar2.show", "ab.bar2.visibility")
  Schema:Set("ab.bar2.show", { mode = "when", combat = "in", hide = { mounted = true, resting = true } })
  CQ.Drain()
  local drv = AB.VisibilityDriver(2)
  t:ok(drv:find("[mounted]", 1, true) and drv:find("[nocombat]", 1, true), "mounted and combat tested securely")
  t:ok(drv:find("[petbattle]", 1, true), "default hides kept")
  t:eq(AB.WatchedRule(2).hide.resting, true, "resting left to PUI.Visibility")
  t:eq(AB.WatchedRule(2).combat, "any", "combat never watched insecurely")
  Schema:Set("ab.bar2.show", { mode = "when", content = { raid = true } })
  CQ.Drain()
  t:eq(AB.VisibilityDriver(2), "hide", "outside raids the bar is hidden")
  if H then t:eq(H.stateDrivers[AB.bars[2].header].visibility, "hide", "driver re-registered out of combat") end
  local shown, why = PUI.Visibility:Why("ab.bar2")
  t:eq(shown, false, "why-hidden readout")
  t:ok(why and why:find("Open world", 1, true), "reason names the content")
  Schema:Set("ab.bar2.show", { mode = "never" })
  t:eq(AB.VisibilityDriver(2), "hide", "never")
  Schema:Set("ab.bar2.visibility", "[combat] show; hide")
  t:eq(AB.VisibilityDriver(2), "[combat] show; hide", "raw macro string wins")
end)

Tests:Add("ActionBars", "fade until mouse-over, linked reveal and opacity", function(t)
  enable(t, "ab.bar2.mouseover", "ab.bar3.mouseover", "ab.mouseoverLinked", "ab.bar2.alpha")
  Schema:Set("ab.bar2.mouseover", true)
  Schema:Set("ab.bar3.mouseover", true)
  local h2, h3 = AB.bars[2].header, AB.bars[3].header
  t:eq(h2:GetAlpha(), 0.3, "faded")
  AB.Hover(2, true)
  t:eq(h2:GetAlpha(), 1, "revealed on hover")
  t:eq(h3:GetAlpha(), 0.3, "other bar stays faded")
  AB.Hover(2, false)
  t:eq(h2:GetAlpha(), 0.3, "fades again")
  Schema:Set("ab.mouseoverLinked", true)
  AB.Hover(2, true)
  t:eq(h3:GetAlpha(), 1, "linked reveal")
  AB.Hover(2, false)
  Schema:Set("ab.bar2.alpha", 0.5)
  t:eq(h2:GetAttribute("fullalpha"), 0.15, "opacity multiplies the fade")
end)

Tests:Add("ActionBars", "usable, power and never-dim colours; look settings live", function(t)
  enable(t, "ab.neverDim", "ab.border", "ab.rangeMode", "ab.dimOnCooldown")
  local b = AB.bars[2].buttons[1]
  if H then
    H.secretMode = true
    Btn.Update(b)
    Btn.UpdateRange(b, H.secret(false))
    H.secretMode = false
    H.actionInfo[61] = { "spell", 18562 }
    t:cleanup(function() H.actionInfo[61] = nil end)
    Btn.UpdateUsable(b)
    t:eq(b.icon.vertex[1], 1, "Swiftmend is never dimmed")
  end
  Schema:Set("ab.border", 0)
  t:eq(b.edges[1]:IsShown(), false, "border 0 hides the edges")
  Schema:Set("ab.dimOnCooldown", true)
  if H then t:ok(b.dim.alphaFlag ~= nil, "cooldown veil driven by the duration's IsZero flag") end
  Schema:Set("ab.rangeMode", "off")
  Btn.UpdateRange(b, true)
  t:eq(b.range:GetAlpha(), 0, "range overlay off")
end)

Tests:Add("ActionBars", "keybind mode binds through the ledger with conflicts and undo", function(t)
  enable(t, "ab.binds")
  local KB = ns.KB
  t:cleanup(function() KB.undo = {}; if KB.on then KB.Stop(true) end end)
  t:ok(KB.Start(), "mode starts out of combat")
  local conflicts, combo = KB.Bind("PhoenixUI_ActionBar2Button3", "ctrl-5")
  t:eq(combo, "CTRL-5", "canonical combo")
  t:eq(#conflicts, 0, "free key")
  t:eq(Schema:Get("ab.binds")[1], "PhoenixUI_ActionBar2Button3=CTRL-5", "saved as a Phoenix setting")
  if H then t:eq(H.overrideBindings["CTRL-5"].button, "PhoenixUI_ActionBar2Button3", "override binding via the ledger") end
  t:eq(AB.bars[2].buttons[3].hotkey:GetText(), "C5", "hotkey text shows it")
  local c2 = KB.Bind("PhoenixUI_ActionBar2Button4", "1")
  t:ok(#c2 >= 1 and c2[1].owner == "ActionBars", "conflict with the bar 1 redirect reported")
  KB.Bind("PhoenixUI_ActionBar2Button5", "CTRL-5")
  t:eq(#Schema:Get("ab.binds"), 2, "one button per key")
  t:ok(KB.Undo(), "undo")
  t:eq(KB.map.PhoenixUI_ActionBar2Button3[1], "CTRL-5", "previous owner of the key is back")
  t:ok(KB.Discard(), "discard")
  t:eq(#Schema:Get("ab.binds"), 0, "everything since the start put back")
  KB.Stop(true)
  local probe = CQ.InCombat
  if H then
    H.inCombat = true
    t:eq(KB.Start(), false, "refused in combat")
    H.inCombat = false
  end
  local _ = probe
end)

Tests:Add("ActionBars", "stance, pet, vehicle exit and item bars", function(t)
  enable(t, "items.list", "items.trinkets", "ab.items.enabled")
  if not H then return end
  H.forms = { { icon = 1, spell = 768, active = true }, { icon = 2, spell = 5487, active = false } }
  H.inventory[13], H.itemSpells[777] = 777, 1
  t:cleanup(function() H.forms = {}; H.inventory[13] = nil; H.itemSpells[777] = nil end)
  local SP = ns.Special
  SP.ApplyAll()
  CQ.Drain()
  local st = SP.bars.stance
  t:eq(st.n, 2, "one button per known form")
  t:eq(st.buttons[1]:GetAttribute("type"), "spell", "stance buttons cast the form spell")
  t:eq(st.buttons[2]:GetAttribute("spell"), 5487, "form spell id")
  t:eq(StanceBar:GetParent(), AB.stockHider, "Blizzard stance bar parked")
  local pet = SP.bars.pet
  t:eq(pet.buttons[1]:GetAttribute("type"), "pet", "pet action buttons")
  t:ok(H.stateDrivers[pet.header].visibility:find("[pet] show", 1, true), "pet bar only with a pet")
  t:eq(H.stateDrivers[SP.bars.vehicle.header].visibility, "[canexitvehicle] show; hide", "vehicle exit only when possible")
  t:eq(SP.bars.vehicle.buttons[1]:GetAttribute("macrotext"), "/leavevehicle", "secure exit")
  local items = SP.bars.items
  t:eq(items.n, 2, "on-use trinket + carried potion (missing items hidden)")
  t:eq(items.buttons[1]:GetAttribute("item"), "13", "trinket by inventory slot")
  t:eq(items.buttons[2]:GetAttribute("item"), "item:5512", "item by id")
  t:eq(items.buttons[2].count:GetText(), "2", "count")
  Schema:Set("items.trinkets", false)
  CQ.Drain()
  t:eq(items.n, 1, "item list change applies live")
  H.forms = {}
  H.fire("UPDATE_SHAPESHIFT_FORMS")
  CQ.Drain()
  t:eq(H.stateDrivers[st.header].visibility, "hide", "no forms: stance bar hidden")
end)

Tests:Add("ActionBars", "conflict notice: another action bar addon waits for the user's pick", function(t)
  if not H then return end
  enable(t, "core.coexist.actionbars")
  H.addonLoaded.Bartender4 = true
  t:cleanup(function() H.addonLoaded.Bartender4 = nil; PUI.Kernel:Evaluate("ActionBars") end)
  local C = PUI.Coexist
  t:eq(C:Allows("actionbars"), false, "dormant while the user has not picked")
  PUI.Kernel:Evaluate("ActionBars")
  t:eq(AB.active, false, "Phoenix bars do not take over")
  t:ok(C:Describe("actionbars"):find("Bartender4", 1, true), "notice names the other addon")
  local before = #H.disabled
  C:Pick("actionbars", "phoenix")
  t:eq(H.disabled[#H.disabled], "Bartender4", "other addon turned off for the next load")
  t:ok(#H.disabled > before, "DisableAddOn called")
  t:eq(AB.active, true, "Phoenix keeps the job")
  C:Pick("actionbars", "other")
  t:eq(AB.active, false, "the other addon keeps the job")
end)
