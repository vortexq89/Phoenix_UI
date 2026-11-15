local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Action bars, deferred batch A (docs/DEFERRED.md): micro menu and bag bar,
-- extra action and zone ability (scale, art; moved in Studio), flyout skin,
-- right-click pet autocast, mouse buttons and wheel in keybind mode plus a
-- printable key sheet, per-button overrides, Blizzard / Classic looks and icon
-- masks, cooldown number colours by time left (engine curve, no Lua maths on
-- the secret countdown), hide in player housing and while a gamepad is
-- active, first-install capture of your Edit Mode bar positions, and the
-- reverse cooldown-manager dedupe. Every part is a setting and applies live.
local _, ns = ...
local AB, Btn, SP, KB = ns.AB, ns.Buttons, ns.Special, ns.KB
local Schema, Secret, Ticker, CQ, Kernel, Slash = PUI.Schema, PUI.Secret, PUI.Ticker, PUI.CombatQueue, PUI.Kernel, PUI.Slash
local OWNER = "ActionBars"
local S = Btn.S
local function plain(v) return v ~= nil and not Secret.IsSecret(v) end

local X = { saved = {}, suppressed = false }
AB.Extras = X

local E = {
  micro = { mode = "game", scale = 1 }, bags = { mode = "game", scale = 1 }, fadeAlpha = 0.25,
  extra = { scale = 1, hideArt = false }, zone = { hideArt = false },
  flyout = true, petRightClick = true,
  look = "phoenix", mask = "square",
  cdColors = false, cdSoon = 3, cdMid = 10, cdSoonColor = { r = 1, g = 0.33, b = 0.33 }, cdMidColor = { r = 1, g = 0.82, b = 0.25 },
  cdColor = { r = 1, g = 1, b = 1 },
  hideHousing = false, hideGamepad = false,
  editModeCapture = true, cdmDedupe = false, overrides = {},
}
X.settings = E

-- Micro menu and bag bar -------------------------------------------------------------
local TARGETS = { micro = "MicroMenuContainer", bags = "BagsBar" }
local function frameOf(name) return rawget(_G, name) end
function X.ApplyContainer(kind)
  local f = frameOf(TARGETS[kind])
  if not f then return end
  CQ.Defer("ab.container." .. kind, function()
    local c = E[kind]
    local saved = X.saved[kind]
    if AB.active and c.mode ~= "game" or AB.active and c.scale ~= 1 then
      if not saved then saved = { scale = f:GetScale(), alpha = f:GetAlpha() }; X.saved[kind] = saved end
      f:SetScale(saved.scale * c.scale)
      if c.mode == "hide" then f:SetAlpha(0)
      elseif c.mode == "fade" then f:SetAlpha(f:IsMouseOver() and 1 or E.fadeAlpha)
      else f:SetAlpha(saved.alpha) end
    elseif saved then
      f:SetScale(saved.scale); f:SetAlpha(saved.alpha)
      X.saved[kind] = nil
    end
  end)
  X.ArmFade()
end
-- Mouse-over fade for the two containers: one Ticker entry while either fades.
function X.ArmFade()
  local want = AB.active and (E.micro.mode == "fade" or E.bags.mode == "fade")
  if want then
    Ticker:Register("ab.containerFade", 0.15, function()
      for kind, name in pairs(TARGETS) do
        local f = frameOf(name)
        if f and E[kind].mode == "fade" then f:SetAlpha(f:IsMouseOver() and 1 or E.fadeAlpha) end
      end
    end, OWNER)
  else
    Ticker:Unregister("ab.containerFade")
  end
end

-- Extra action and zone ability ----------------------------------------------------------
function X.ApplyExtra()
  local extra, zone = frameOf("ExtraActionButton1"), frameOf("ZoneAbilityFrame")
  CQ.Defer("ab.extra", function()
    local on = AB.active
    local container = frameOf("ExtraAbilityContainer")
    if container then
      X.saved.extraScale = X.saved.extraScale or container:GetScale()
      container:SetScale(on and X.saved.extraScale * E.extra.scale or X.saved.extraScale)
    end
    local art = extra and rawget(extra, "style")
    if art then art:SetAlpha((on and E.extra.hideArt) and 0 or 1) end
    local zart = zone and rawget(zone, "Style")
    if zart then zart:SetAlpha((on and E.zone.hideArt) and 0 or 1) end
  end)
end

-- Flyout skin ------------------------------------------------------------------------------
function X.SkinFlyout()
  local fly = frameOf("SpellFlyout")
  if not fly then return end
  local on = AB.active and E.flyout
  for _, child in ipairs({ fly:GetChildren() }) do
    local icon = rawget(child, "icon") or rawget(child, "Icon")
    if icon then
      if on then
        icon:SetTexCoord(S.zoom, 1 - S.zoom, S.zoom, 1 - S.zoom)
        if not rawget(child, "puiEdge") then
          local e = child:CreateTexture(nil, "OVERLAY", nil, 1)
          e:SetPoint("TOPLEFT", -1, 1); e:SetPoint("BOTTOMRIGHT", 1, -1)
          e:SetColorTexture(S.borderColor.r, S.borderColor.g, S.borderColor.b, 1)
          e:SetDrawLayer("BACKGROUND", -1)
          child.puiEdge = e
        end
        child.puiEdge:Show()
      else
        icon:SetTexCoord(0, 1, 0, 1)
        if rawget(child, "puiEdge") then child.puiEdge:Hide() end
      end
    end
  end
end
function X.HookFlyout()
  local fly = frameOf("SpellFlyout")
  if fly and not X.flyHooked then
    X.flyHooked = true
    fly:HookScript("OnShow", X.SkinFlyout)
  end
end

-- Pet autocast on right-click (secure macro on the right button) -------------------------
function X.PetAutocast()
  local bar = SP.bars.pet
  if not bar then return end
  CQ.Defer("ab.petAutocast", function()
    for j = 1, bar.n do
      local b = bar.buttons[j]
      local name, _, isToken = GetPetActionInfo(j)
      if plain(name) and isToken then name = rawget(_G, name) or name end
      if AB.active and E.petRightClick and plain(name) and type(name) == "string" and name ~= "" then
        b:SetAttribute("type2", "macro")
        b:SetAttribute("macrotext2", "/petautocasttoggle " .. name)
      else
        b:SetAttribute("type2", nil)
        b:SetAttribute("macrotext2", nil)
      end
    end
  end)
end

-- Keybind mode: mouse buttons and wheel; the key sheet ---------------------------------------
X.MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
function X.OnMouseKey(button)
  if not KB.on then return false end
  local key = X.MOUSE[button]
  if not key then return false end
  KB.OnKey(key)
  return true
end
function X.OnWheel(delta)
  if not KB.on then return false end
  KB.OnKey(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
  return true
end
function X.HookKeybindMode()
  for _, b in ipairs(Btn.all) do
    if not rawget(b, "puiMouseHook") then
      b.puiMouseHook = true
      b:HookScript("OnMouseDown", function(_, button) X.OnMouseKey(button) end)
    end
  end
  local f = KB.frame
  if f and not rawget(f, "puiWheel") then
    f.puiWheel = true
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) X.OnWheel(delta) end)
  end
end
local baseStart = KB.Start
function KB.Start()
  local ok = baseStart()
  if ok then X.HookKeybindMode() end
  return ok
end

-- Sheet(): every Phoenix bar's keys as plain text lines (bar, button, key).
function X.Sheet()
  local lines = { "Phoenix UI key sheet - " .. date("%Y-%m-%d"), "" }
  for i = 1, #AB.DEFS do
    local bar = AB.bars[i]
    if bar and AB.cfg[i].on then
      local row = {}
      for j, b in ipairs(bar.buttons) do
        if b.live then
          local k = rawget(b, "extraKey") or rawget(b, "bindKey")
          if k then row[#row + 1] = j .. ": " .. (GetBindingText and GetBindingText(k) or k) end
        end
      end
      lines[#lines + 1] = "Bar " .. i .. (#row > 0 and ("  " .. table.concat(row, "   ")) or "  (no keys)")
    end
  end
  return table.concat(lines, "\n")
end
function X.OpenSheet() PUI.Dialogs:Copy("Key sheet", X.Sheet(), "Copy with Ctrl+C and paste it anywhere to print.") end

-- Per-button overrides: "bar.button:option,option" -------------------------------------------
-- options: nohotkey, nomacro, nocount, hide, alpha=0.5, glow=none|pulse|solid|flash
X.OVERRIDE_FLAGS = { nohotkey = true, nomacro = true, nocount = true, hide = true }
function X.ParseOverride(line)
  if type(line) ~= "string" then return nil, "not text" end
  local bar, btn, opts = line:match("^%s*(%d+)%.(%d+)%s*:%s*(.-)%s*$")
  bar, btn = tonumber(bar), tonumber(btn)
  if not (bar and btn) then return nil, "start with bar.button, for example 1.5:nohotkey" end
  if bar < 1 or bar > #AB.DEFS or btn < 1 or btn > 12 then return nil, "bar 1-" .. #AB.DEFS .. ", button 1-12" end
  local o = { bar = bar, button = btn }
  for part in (opts or ""):gmatch("[^,%s]+") do
    local k, v = part:match("^(%a+)=(.+)$")
    if X.OVERRIDE_FLAGS[part] then o[part] = true
    elseif k == "alpha" and tonumber(v) and tonumber(v) >= 0 and tonumber(v) <= 1 then o.alpha = tonumber(v)
    elseif k == "glow" and PUI.Glow.STYLE_LABELS[v] then o.glow = v
    else return nil, "unknown option '" .. part .. "'" end
  end
  return o
end
function X.CompileOverrides()
  X.byButton = {}
  for _, line in ipairs(E.overrides) do
    local o = X.ParseOverride(line)
    if o then X.byButton[o.bar .. "." .. o.button] = X.byButton[o.bar .. "." .. o.button] or o end
  end
end
X.byButton = {}
function X.OverrideOf(b)
  local bar, j = rawget(b, "puiBar"), rawget(b, "puiIndex")
  return bar and X.byButton[bar .. "." .. j]
end
function X.ApplyOverride(b)
  local o = X.OverrideOf(b)
  if not o then
    if rawget(b, "puiOverridden") then b.puiOverridden = nil; b:SetAlpha(1) end
    return
  end
  b.puiOverridden = true
  if o.nohotkey then b.hotkey:SetText("") end
  if o.nomacro then b.macro:SetText("") end
  if o.nocount then b.count:SetText("") end
  b:SetAlpha(o.hide and 0 or (o.alpha or 1))
  if o.glow and rawget(b, "glowOn") then
    if o.glow == "none" then PUI.Glow:Stop(b) else PUI.Glow:Start(b, o.glow, S.procColor) end
  end
end
function X.IndexButtons()
  for i, bar in pairs(AB.bars) do
    for j, b in ipairs(bar.buttons) do b.puiBar, b.puiIndex = i, j end
  end
end

-- Looks and masks ------------------------------------------------------------------------------
X.LOOKS = { "phoenix", "blizzard", "classic" }
X.LOOK_LABELS = { phoenix = "Phoenix (flat, thin border)", blizzard = "Blizzard (the game's own frame)", classic = "Classic (square bevel)" }
X.MASKS = { "square", "rounded", "circle" }
X.MASK_LABELS = { square = "Square", rounded = "Rounded corners", circle = "Circle" }
X.MASK_ART = { rounded = { atlas = "UI-HUD-ActionBar-IconFrame-Mask" }, circle = { file = "Interface\\CharacterFrame\\TempPortraitAlphaMask" } }
function X.ApplyLookExtras(b)
  local look, mask = E.look, E.mask
  local frame = rawget(b, "puiFrame")
  if look ~= "phoenix" and not frame then
    frame = b:CreateTexture(nil, "OVERLAY", nil, 2)
    frame:SetPoint("TOPLEFT", -2, 2); frame:SetPoint("BOTTOMRIGHT", 2, -2)
    b.puiFrame = frame
  end
  if frame then
    if look == "blizzard" then frame:SetAtlas("UI-HUD-ActionBar-IconFrame"); frame:Show()
    elseif look == "classic" then frame:SetTexture("Interface\\Buttons\\UI-Quickslot2"); frame:SetTexCoord(0.2, 0.8, 0.2, 0.8); frame:Show()
    else frame:Hide() end
  end
  if look ~= "phoenix" then
    for i = 1, 4 do b.edges[i]:Hide() end
    b.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
  end
  local m = rawget(b, "puiMask")
  if mask ~= "square" then
    if not m then m = b:CreateMaskTexture(); m:SetAllPoints(b.icon); b.puiMask = m; b.icon:AddMaskTexture(m) end
    local art = X.MASK_ART[mask]
    if art.atlas then m:SetAtlas(art.atlas) else m:SetTexture(art.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
    if b.cooldown.SetUseCircularEdge then b.cooldown:SetUseCircularEdge(mask == "circle") end
  elseif m then
    b.icon:RemoveMaskTexture(m)
    b.puiMask = nil
  end
end

-- Cooldown number colours by time left (engine-evaluated colour curve) ------------------------
function X.CooldownCurve()
  local curve = C_CurveUtil.CreateColorCurve()
  if curve.SetType and Enum.LuaCurveType then curve:SetType(Enum.LuaCurveType.Step) end
  local a, b, c = E.cdSoonColor, E.cdMidColor, E.cdColor
  curve:AddPoint(0, CreateColor(a.r, a.g, a.b, 1))
  curve:AddPoint(E.cdSoon, CreateColor(b.r, b.g, b.b, 1))
  curve:AddPoint(math.max(E.cdMid, E.cdSoon + 1), CreateColor(c.r, c.g, c.b, 1))
  return curve
end
function X.PaintCooldownText(b, curve)
  local slot = rawget(b, "slot")
  local fs = b.cooldown.GetCountdownFontString and b.cooldown:GetCountdownFontString()
  if not (slot and fs) then return end
  local d = C_ActionBar.GetActionCooldownDuration(slot)
  if d == nil or not d.EvaluateRemainingDuration then return end
  local color = d:EvaluateRemainingDuration(curve)
  if color and color.GetRGBA then fs:SetTextColor(color:GetRGBA()) end
end
function X.ArmCooldownColors()
  if AB.active and E.cdColors and S.cdText then
    X.curve = X.CooldownCurve()
    Ticker:Register("ab.cdColors", 0.25, function() Btn.Each(function(b) X.PaintCooldownText(b, X.curve) end) end, OWNER)
  else
    Ticker:Unregister("ab.cdColors")
    Btn.Each(function(b)
      local fs = b.cooldown.GetCountdownFontString and b.cooldown:GetCountdownFontString()
      if fs then fs:SetTextColor(1, 1, 1, 1) end
    end)
  end
end

-- Hide in housing / while a gamepad is active -------------------------------------------------
function X.ShouldSuppress()
  if E.hideHousing and C_Housing and C_Housing.IsInsideHouse then
    local inside = C_Housing.IsInsideHouse()
    if plain(inside) and inside then return true, "housing" end
  end
  if E.hideGamepad and X.gamepadActive then return true, "gamepad" end
  return false
end
function X.ApplySuppress()
  local want = AB.active and X.ShouldSuppress() or false
  if want == X.suppressed then return end
  X.suppressed = want
  CQ.Defer("ab.suppress", function()
    for i, bar in pairs(AB.bars) do
      if AB.cfg[i].on and rawget(bar, "header") then
        if X.suppressed then RegisterStateDriver(bar.header, "visibility", "hide")
        else AB.ApplyBar(i) end
      end
    end
  end)
end

-- First-install capture of the Edit Mode bar positions ------------------------------------------
-- systemIndex of the action bar system -> Phoenix bar
X.EDITMODE_BARS = { [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7, [8] = 8 }
function X.EditModePositions(info)
  local out = {}
  if type(info) ~= "table" or type(info.layouts) ~= "table" then return out end
  local layout = info.layouts[info.activeLayout or 1]
  local barSystem = Enum.EditModeSystem and Enum.EditModeSystem.ActionBar or 0
  for _, sys in ipairs(layout and layout.systems or {}) do
    local bar = sys.system == barSystem and X.EDITMODE_BARS[sys.systemIndex]
    local a = sys.anchorInfo
    if bar and type(a) == "table" and a.relativeTo == "UIParent" and a.point == a.relativePoint and PUI.Schema.POINTS[a.point] then
      out["ab.bar" .. bar] = { point = a.point, x = math.floor((a.offsetX or 0) + 0.5), y = math.floor((a.offsetY or 0) + 0.5) }
    end
  end
  return out
end
function X.CaptureEditMode(force)
  local g = PUI.DB.sv and PUI.DB.sv.global
  if not g then return 0 end
  if g.abEditModeCaptured and not force then return 0 end
  local positions = Schema.Copy(Schema:Get("layout.positions"))
  local n = 0
  for id, r in pairs(X.EditModePositions(C_EditMode.GetLayouts())) do
    if force or positions[id] == nil then positions[id] = r; n = n + 1 end
  end
  g.abEditModeCaptured = true
  if n > 0 then Schema:Set("layout.positions", positions) end
  return n
end

-- Reverse cooldown-manager dedupe ----------------------------------------------------------------
function X.CdmSpells()
  local CDM = PUI.CooldownManager
  local set = {}
  if not (CDM and CDM.Items) then return set end
  for _, name in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
    local v = frameOf(name)
    if v and v.GetItemFrames then
      for _, f in ipairs(CDM.Items(v, true)) do
        local id = CDM.SpellOf(f)
        if id then set[id] = true end
      end
    end
  end
  return set
end
function X.DedupeConflict()
  local CDM = PUI.CooldownManager
  return CDM and CDM.look and CDM.look.hideOnBars == true and CDM.active == true
end
function X.ApplyDedupe()
  local on = AB.active and E.cdmDedupe and not X.DedupeConflict()
  local spells = on and X.CdmSpells() or {}
  Btn.Each(function(b)
    local slot = rawget(b, "slot")
    local hide = false
    if on and slot then
      local kind, id = GetActionInfo(slot)
      hide = plain(kind) and kind == "spell" and plain(id) and spells[id] == true
    end
    if hide then b:SetAlpha(0); b.puiDeduped = true
    elseif rawget(b, "puiDeduped") then b.puiDeduped = nil; b:SetAlpha(1); X.ApplyOverride(b) end
  end)
end

-- Wiring -------------------------------------------------------------------------------------------
local baseApplyLook, baseUpdate = Btn.ApplyLook, Btn.Update
function Btn.ApplyLook(b) baseApplyLook(b); X.ApplyLookExtras(b) end
function Btn.Update(b)
  baseUpdate(b)
  if rawget(b, "puiBar") then X.ApplyOverride(b) end
end
local baseApplyBar = AB.ApplyBar
function AB.ApplyBar(i)
  baseApplyBar(i)
  CQ.Defer("ab.extrasAfter" .. i, function() X.IndexButtons(); X.CompileOverrides(); Btn.Each(X.ApplyOverride) end)
end
local baseSPApply = SP.Apply
function SP.Apply(kind) baseSPApply(kind); if kind == "pet" then X.PetAutocast() end end

function X.ApplyAll()
  X.ApplyContainer("micro"); X.ApplyContainer("bags"); X.ApplyExtra(); X.HookFlyout(); X.PetAutocast()
  X.ArmCooldownColors(); X.ApplySuppress(); X.ApplyDedupe()
end
X.events = PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
X.events:SetScript("OnEvent", function(_, event, arg)
  if event == "GAME_PAD_ACTIVE_CHANGED" then X.gamepadActive = arg == true end
  if event == "COOLDOWN_VIEWER_DATA_LOADED" or event == "SPELLS_CHANGED" or event == "ACTIONBAR_SLOT_CHANGED" then X.ApplyDedupe() return end
  X.ApplySuppress()
end)
local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "GAME_PAD_ACTIVE_CHANGED",
  "SPELLS_CHANGED", "ACTIONBAR_SLOT_CHANGED" }
Kernel:On("MODULE_ENABLED", function(name)
  if name ~= OWNER then return end
  for _, e in ipairs(EVENTS) do X.events:RegisterEvent(e) end
  if E.editModeCapture then X.CaptureEditMode(false) end
  X.ApplyAll()
end)
Kernel:On("MODULE_DISABLED", function(name)
  if name ~= OWNER then return end
  X.events:UnregisterAllEvents()
  X.suppressed = false
  X.ApplyAll()
end)

Slash:Register("keys", function() X.OpenSheet() end, "show your action bar keys as a sheet you can copy or print")
Slash:Register("abcapture", function()
  local n = X.CaptureEditMode(true)
  Slash.Print(n > 0 and (n .. " bar position(s) taken from your Edit Mode layout") or "no Edit Mode bar positions to take")
end, "copy your Edit Mode action bar positions onto the Phoenix bars")

-- Schema ----------------------------------------------------------------------------------------------
X.KEYS = {}
local function key(name, def, set, after)
  def.owner = OWNER
  def.apply = function(v) set(v); if after then after(v) end end
  Schema:Register("ab." .. name, def)
  X.KEYS[#X.KEYS + 1] = "ab." .. name
end
local MODES = { "game", "fade", "hide" }
local MODE_LABELS = { game = "As the game shows it", fade = "Faded until the mouse is over it", hide = "Hidden" }
for _, k in ipairs({ { "micro", "Micro menu" }, { "bags", "Bag bar" } }) do
  key(k[1] .. ".mode", { type = "select", default = "game", choices = MODES, choiceLabels = MODE_LABELS, label = k[2],
    tooltip = "How the " .. k[2]:lower() .. " shows. Move it in Studio (Edit Mode owns its position).", mode = "simple",
    searchTags = { "micro", "bags", "menu", "fade" } }, function(v) E[k[1]].mode = v end, function() X.ApplyContainer(k[1]) end)
  key(k[1] .. ".scale", { type = "range", default = 1, min = 0.5, max = 1.5, step = 0.05, label = k[2] .. " size",
    tooltip = "Size of the " .. k[2]:lower() .. ".", mode = "advanced" }, function(v) E[k[1]].scale = v end, function() X.ApplyContainer(k[1]) end)
end
key("microbags.fadeAlpha", { type = "range", default = 0.25, min = 0, max = 1, step = 0.05, label = "Micro menu and bag bar faded opacity",
  tooltip = "How visible the faded micro menu and bag bar stay.", mode = "advanced" }, function(v) E.fadeAlpha = v end,
  function() X.ApplyContainer("micro"); X.ApplyContainer("bags") end)
key("extra.scale", { type = "range", default = 1, min = 0.5, max = 2, step = 0.05, label = "Extra action button size",
  tooltip = "Size of the extra action and zone ability buttons. Move them in Studio.", mode = "simple",
  searchTags = { "extra action", "zone ability" } }, function(v) E.extra.scale = v end, X.ApplyExtra)
key("extra.hideArt", { type = "toggle", default = false, label = "Hide the extra action button's art",
  tooltip = "Shows only the button, without the decorative frame around it.", mode = "advanced" }, function(v) E.extra.hideArt = v end, X.ApplyExtra)
key("zone.hideArt", { type = "toggle", default = false, label = "Hide the zone ability art",
  tooltip = "Shows only the zone ability button, without its frame.", mode = "advanced" }, function(v) E.zone.hideArt = v end, X.ApplyExtra)
key("flyout.skin", { type = "toggle", default = true, label = "Phoenix look on flyouts",
  tooltip = "Spell flyouts (portals, pets, totems) use the same icon crop and border as your bars.", mode = "advanced",
  searchTags = { "flyout", "portal" } }, function(v) E.flyout = v end, X.SkinFlyout)
key("pet.rightClickAutocast", { type = "toggle", default = true, label = "Right-click a pet button to toggle autocast",
  tooltip = "Like the default pet bar: right-click switches the ability's autocast on or off.", mode = "simple",
  searchTags = { "pet", "autocast" } }, function(v) E.petRightClick = v end, X.PetAutocast)
key("look", { type = "select", default = "phoenix", choices = X.LOOKS, choiceLabels = X.LOOK_LABELS, label = "Button look",
  tooltip = "The frame around every button. Each part (border, zoom, fonts) can still be changed on its own.", mode = "simple",
  searchTags = { "skin", "style", "blizzard", "classic" } }, function(v) E.look = v end, function() AB.ApplyLookAll() end)
key("mask", { type = "select", default = "square", choices = X.MASKS, choiceLabels = X.MASK_LABELS, label = "Icon shape",
  tooltip = "Square, rounded or round icons.", mode = "simple", searchTags = { "round", "circle", "mask" } },
  function(v) E.mask = v end, function() AB.ApplyLookAll() end)
key("cdColors", { type = "toggle", default = false, label = "Colour cooldown numbers by time left",
  tooltip = "Cooldown numbers turn yellow, then red, as the cooldown ends. The game works out the colour, so it also works in restricted content.",
  mode = "simple", searchTags = { "cooldown", "timer", "colour" } }, function(v) E.cdColors = v end, X.ArmCooldownColors)
key("cdSoon", { type = "range", default = 3, min = 1, max = 10, step = 1, label = "Red below (seconds)",
  tooltip = "Cooldown numbers are red below this many seconds.", mode = "advanced" }, function(v) E.cdSoon = v end, X.ArmCooldownColors)
key("cdMid", { type = "range", default = 10, min = 2, max = 60, step = 1, label = "Yellow below (seconds)",
  tooltip = "Cooldown numbers are yellow below this many seconds.", mode = "advanced" }, function(v) E.cdMid = v end, X.ArmCooldownColors)
for _, c in ipairs({ { "cdSoonColor", "Red colour" }, { "cdMidColor", "Yellow colour" }, { "cdColor", "Normal colour" } }) do
  key(c[1], { type = "color", default = Schema.Copy(E[c[1]]), label = "Cooldown numbers: " .. c[2]:lower(),
    tooltip = "Colour used in this part of the cooldown.", mode = "advanced" }, function(v) E[c[1]] = v end, X.ArmCooldownColors)
end
key("hide.housing", { type = "toggle", default = false, label = "Hide action bars inside your house",
  tooltip = "Phoenix action bars hide while you are inside a player house and come back when you leave.", mode = "simple",
  searchTags = { "housing", "house" } }, function(v) E.hideHousing = v end, X.ApplySuppress)
key("hide.gamepad", { type = "toggle", default = false, label = "Hide action bars while using a gamepad",
  tooltip = "Phoenix action bars hide while a controller is active, for controller addons that bring their own bars.", mode = "simple",
  searchTags = { "gamepad", "controller", "consoleport" } }, function(v) E.hideGamepad = v end, X.ApplySuppress)
key("editModeCapture", { type = "toggle", default = true, label = "Start from my Edit Mode bar positions",
  tooltip = "The first time Phoenix bars turn on, each bar starts where your Edit Mode layout had it. Bars you already moved are kept. /pui abcapture copies them again.",
  mode = "advanced", searchTags = { "edit mode", "import", "layout" } }, function(v) E.editModeCapture = v end)
key("cdmDedupe", { type = "toggle", default = false, label = "Hide bar buttons the cooldown manager shows",
  tooltip = "A spell shown in the cooldown manager's Essential or Utility rows is hidden on your bars. Off while the cooldown manager hides icons that are on your bars (pick one).",
  mode = "advanced", searchTags = { "cdm", "duplicate", "dedupe" } }, function(v) E.cdmDedupe = v end, X.ApplyDedupe)
key("buttonOverrides", { type = "list", default = {}, maxItems = 120, label = "Per-button changes",
  tooltip = "One button per line: bar.button: options. Options: nohotkey, nomacro, nocount, hide, alpha=0.5, glow=none|pulse|solid|flash. Example: 1.12:nohotkey,alpha=0.6",
  mode = "advanced", itemValidate = function(l) local o, why = X.ParseOverride(l); if not o then return false, why end return true end,
  searchTags = { "button", "override", "single" } }, function(v) E.overrides = v end,
  function() X.CompileOverrides(); Btn.Each(Btn.Update) end)

for _, k in ipairs(X.KEYS) do Schema.defs[k].apply(Schema:Get(k)) end
