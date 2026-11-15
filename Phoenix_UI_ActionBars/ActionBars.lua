local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Action Bars module (plan 5.4, 13.5, mockup 05): ten bars of secure action
-- buttons. Each bar is a SecureHandlerStateTemplate header with
--   * a visibility driver: the readable "where to show" rule (PUI.Visibility)
--     is split into the parts the secure state driver can test in combat
--     (combat, vehicle, pet battle, mounted, skyriding) and the parts Phoenix
--     evaluates out of combat (content, group, specialization, resting); an
--     advanced raw macro string replaces both when set;
--   * a paging driver: bar 1 covers [vehicleui][overridebar][possessbar] and,
--     by setting, form and skyriding paging; any bar can page on a modifier;
--   * fade: out of combat (restricted snippet) and/or until mouse-over, with
--     an option to reveal every mouse-over bar together.
-- Keybinds of the matching Blizzard bars are redirected through the binding
-- ledger (PUI.Bindings, plan 1.20). Stock bars are parked under a hidden
-- parent. All protected work happens out of combat through the CombatQueue.
local _, ns = ...
local Schema, Layout, CQ, Ticker = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Ticker
local Btn = ns.Buttons
local S = Btn.S
local OWNER = "ActionBars"

local AB = { active = false, bars = {}, parked = {}, hover = {} }
ns.AB = AB
PUI.ActionBars = AB
AB.Buttons = Btn

-- Bar definitions: action page (1 is paged), Blizzard binding prefix, stock frame.
local DEFS = {
  { page = 1, bind = "ACTIONBUTTON", stock = "MainActionBar", on = true, pos = { "BOTTOM", 0, 40 } },
  { page = 6, bind = "MULTIACTIONBAR1BUTTON", stock = "MultiBarBottomLeft", on = true, pos = { "BOTTOM", 0, 74 } },
  { page = 5, bind = "MULTIACTIONBAR2BUTTON", stock = "MultiBarBottomRight", on = true, pos = { "BOTTOM", 0, 108 } },
  { page = 3, bind = "MULTIACTIONBAR3BUTTON", stock = "MultiBarRight", on = false, pos = { "RIGHT", -40, 0 }, vertical = true },
  { page = 4, bind = "MULTIACTIONBAR4BUTTON", stock = "MultiBarLeft", on = false, pos = { "RIGHT", -80, 0 }, vertical = true },
  { page = 13, bind = "MULTIACTIONBAR5BUTTON", stock = "MultiBar5", on = false, pos = { "BOTTOM", 0, 160 } },
  { page = 14, bind = "MULTIACTIONBAR6BUTTON", stock = "MultiBar6", on = false, pos = { "BOTTOM", 0, 200 } },
  { page = 15, bind = "MULTIACTIONBAR7BUTTON", stock = "MultiBar7", on = false, pos = { "BOTTOM", 0, 240 } },
  { page = 2, on = false, pos = { "BOTTOM", -300, 160 } },
  { page = 10, on = false, pos = { "BOTTOM", 300, 160 } },
}
AB.DEFS = DEFS
local NUM_BARS, SLOTS_PER_PAGE = #DEFS, 12
AB.SLOTS_PER_PAGE = SLOTS_PER_PAGE

local DEFAULT_VIS_MAIN = "[petbattle] hide; show"
local DEFAULT_VIS = "[petbattle][vehicleui][overridebar][possessbar] hide; show"
AB.DEFAULT_VIS, AB.DEFAULT_VIS_MAIN = DEFAULT_VIS, DEFAULT_VIS_MAIN

-- Restricted snippets (run in the secure environment).
local PAGE_SNIPPET = [[
  local page = newstate
  if page == "dynamic" then
    if HasVehicleActionBar() then page = GetVehicleBarIndex()
    elseif HasOverrideActionBar() then page = GetOverrideBarIndex()
    elseif HasTempShapeshiftActionBar() then page = GetTempShapeshiftBarIndex()
    elseif HasBonusActionBar() then page = GetBonusBarIndex()
    else page = GetActionBarPage() end
  end
  page = tonumber(page) or 1
  self:SetAttribute("actionpage", page)
  for i = 1, 12 do
    local b = self:GetFrameRef("button" .. i)
    if b then b:SetAttribute("action", (page - 1) * 12 + i) end
  end
]]
local FADE_SNIPPET = [[
  if newstate == "in" or not self:GetAttribute("fade") then
    self:SetAlpha(tonumber(self:GetAttribute("fullalpha")) or 1)
  else
    self:SetAlpha(tonumber(self:GetAttribute("fadealpha")) or 1)
  end
]]
AB.PAGE_SNIPPET, AB.FADE_SNIPPET = PAGE_SNIPPET, FADE_SNIPPET

-- Resolved per-bar settings.
local cfg = {}
AB.cfg = cfg
for i, d in ipairs(DEFS) do
  cfg[i] = { on = d.on, buttons = 12, perRow = d.vertical and 1 or 12, size = 36, spacing = 2, scale = 1,
    fade = false, fadeAlpha = 0.3, mouseover = false, alpha = 1, visibility = "", show = { mode = "always" },
    page = d.page, pageMod = "none", pageModTo = 2, growX = "RIGHT", growY = "DOWN", clickThrough = false,
    formPaging = true, skyridingPaging = true }
end
local linked = { on = false }

-- Paging driver for a bar, or nil for a fixed page set directly.
local MODS = { shift = "[mod:shift]", ctrl = "[mod:ctrl]", alt = "[mod:alt]" }
function AB.PageDriver(i)
  local c = cfg[i]
  local parts = {}
  if c.pageMod ~= "none" and MODS[c.pageMod] then parts[#parts + 1] = MODS[c.pageMod] .. " " .. c.pageModTo end
  if i ~= 1 then
    if #parts == 0 then return nil end
    parts[#parts + 1] = tostring(c.page)
    return table.concat(parts, "; ")
  end
  local dyn = "[vehicleui][overridebar][possessbar]"
  if not c.skyridingPaging then
    parts[#parts + 1] = dyn .. " dynamic"
    parts[#parts + 1] = "[bonusbar:5] 1"
    dyn = ""
  end
  if c.formPaging then dyn = dyn .. "[shapeshift][bonusbar]" end
  if dyn ~= "" then parts[#parts + 1] = dyn .. " dynamic" end
  for p = 2, 6 do parts[#parts + 1] = "[bar:" .. p .. "] " .. p end
  parts[#parts + 1] = "1"
  return table.concat(parts, "; ")
end
AB.PAGE_DRIVER = AB.PageDriver(1)

-- Visibility: the parts of a "where to show" rule a secure driver can test.
local MACRO_HIDE = { vehicle = "[vehicleui]", petBattle = "[petbattle]", mounted = "[mounted]", skyriding = "[bonusbar:5]" }
function AB.VisibilityDriver(i)
  local c = cfg[i]
  if c.visibility ~= "" then return c.visibility end
  local bar = AB.bars[i]
  if bar and bar.ruleShown == false then return "hide" end
  local rule = c.show or {}
  if rule.mode == "never" then return "hide" end
  local conds = {}
  local base = i == 1 and DEFAULT_VIS_MAIN or DEFAULT_VIS
  if rule.mode == "when" then
    for _, h in ipairs({ "vehicle", "petBattle", "mounted", "skyriding" }) do
      if rule.hide and rule.hide[h] then conds[#conds + 1] = MACRO_HIDE[h] end
    end
    if rule.combat == "in" then conds[#conds + 1] = "[nocombat]" end
    if rule.combat == "out" then conds[#conds + 1] = "[combat]" end
  end
  if #conds == 0 then return base end
  return table.concat(conds) .. " hide; " .. base
end

-- The out-of-combat part of the rule, for PUI.Visibility.
function AB.WatchedRule(i)
  local rule = cfg[i].show or {}
  if rule.mode ~= "when" then return { mode = "always" } end
  local out = { mode = "when", content = rule.content, group = rule.group, specs = rule.specs, combat = "any" }
  if rule.hide and rule.hide.resting then out.hide = { resting = true } end
  return out
end

-- Bars -------------------------------------------------------------------------------
local function baseAlpha(i)
  local c = cfg[i]
  if c.mouseover or (c.fade and not InCombatLockdown()) then return c.fadeAlpha * c.alpha end
  return c.alpha
end

function AB.Hover(i, on)
  AB.hover[i] = on or nil
  local list = linked.on and AB.bars or { [i] = AB.bars[i] }
  for k, bar in pairs(list) do
    local c = cfg[k]
    if (c.mouseover or c.fade) and (k == i or linked.on) then
      bar.header:SetAlpha(on and c.alpha or baseAlpha(k))
    end
  end
end

local function build(i)
  local bar = AB.bars[i]
  if bar then return bar end
  local header = PUI:CreateFrame("Frame", "PhoenixUI_ActionBar" .. i, UIParent, "SecureHandlerStateTemplate", OWNER)
  header:SetAttribute("_onstate-page", PAGE_SNIPPET)
  header:SetAttribute("_onstate-fade", FADE_SNIPPET)
  bar = { index = i, header = header, buttons = {} }
  local hover = function(_, on) AB.Hover(i, on) end
  for j = 1, SLOTS_PER_PAGE do
    local b = Btn.Create(header, "PhoenixUI_ActionBar" .. i .. "Button" .. j, j)
    b.onHover = hover
    b.barIndex = i
    header:SetFrameRef("button" .. j, b)
    bar.buttons[j] = b
  end
  AB.bars[i] = bar
  return bar
end

-- Grid position of button j (1-based) in a bar's config.
function AB.Offset(c, j)
  local perRow, size, gap = math.min(c.perRow, c.buttons), c.size, c.spacing
  local col, row = (j - 1) % perRow, math.floor((j - 1) / perRow)
  local x, y = col * (size + gap), row * (size + gap)
  local point = (c.growY == "UP" and "BOTTOM" or "TOP") .. (c.growX == "LEFT" and "RIGHT" or "LEFT")
  return point, c.growX == "LEFT" and -x or x, c.growY == "UP" and y or -y
end

local function layoutBar(bar)
  local c = cfg[bar.index]
  local n, perRow, size, gap = c.buttons, math.min(c.perRow, c.buttons), c.size, c.spacing
  local rows = math.ceil(n / perRow)
  local header = bar.header
  header:SetScale(c.scale)
  header:SetSize(perRow * size + (perRow - 1) * gap, rows * size + (rows - 1) * gap)
  for j, b in ipairs(bar.buttons) do
    b:ClearAllPoints()
    b:SetSize(size, size)
    if j <= n then
      local point, x, y = AB.Offset(c, j)
      b:SetPoint(point, header, point, x, y)
      b:EnableMouse(not c.clickThrough)
      b:Show()
      b.live = true
    else
      b:Hide()
      b.live = false
    end
  end
  local el = Layout:Element("ab.bar" .. bar.index)
  if el then el.size = { header:GetWidth(), header:GetHeight() } end
  Layout:Place(header, "ab.bar" .. bar.index)
end

-- Base slots are set directly; a paging driver (bar 1, modifier paging) moves them.
local function assignSlots(bar)
  local c = cfg[bar.index]
  if bar.index ~= 1 then
    for j, b in ipairs(bar.buttons) do b:SetAttribute("action", (c.page - 1) * SLOTS_PER_PAGE + j) end
  end
  local driver = AB.PageDriver(bar.index)
  if driver then RegisterStateDriver(bar.header, "page", driver) else UnregisterStateDriver(bar.header, "page") end
end

local function applyDrivers(bar)
  local i = bar.index
  local c = cfg[i]
  RegisterStateDriver(bar.header, "visibility", AB.VisibilityDriver(i))
  bar.header:SetAttribute("fade", c.fade)
  bar.header:SetAttribute("fadealpha", c.fadeAlpha * c.alpha)
  bar.header:SetAttribute("fullalpha", c.mouseover and c.fadeAlpha * c.alpha or c.alpha)
  if c.fade then
    RegisterStateDriver(bar.header, "fade", "[combat] in; out")
  else
    UnregisterStateDriver(bar.header, "fade")
  end
  bar.header:SetAlpha(baseAlpha(i))
end

local function watch(bar)
  local i = bar.index
  PUI.Visibility:Watch("ab.bar" .. i, AB.WatchedRule(i), function(shown)
    if bar.ruleShown == shown then return end
    bar.ruleShown = shown
    CQ.Defer("ab.vis" .. i, function()
      if AB.active and cfg[i].on then RegisterStateDriver(bar.header, "visibility", AB.VisibilityDriver(i)) end
    end)
  end)
end

local function stopBar(bar)
  PUI.Visibility:Unwatch("ab.bar" .. bar.index)
  bar.ruleShown = nil
  UnregisterStateDriver(bar.header, "visibility")
  UnregisterStateDriver(bar.header, "page")
  UnregisterStateDriver(bar.header, "fade")
  bar.header:Hide()
  for _, b in ipairs(bar.buttons) do
    b.live = false
    Btn.index(b, nil)
  end
end
AB.StopBar = stopBar

-- Applies one bar's settings (protected: deferred out of combat).
function AB.ApplyBar(i)
  if not AB.active then return end
  CQ.Defer("ab.bar" .. i, function()
    if not AB.active then return end
    local c = cfg[i]
    if not c.on then
      if AB.bars[i] then stopBar(AB.bars[i]) end
    else
      local bar = build(i)
      layoutBar(bar)
      watch(bar)
      assignSlots(bar)
      applyDrivers(bar)
      for _, b in ipairs(bar.buttons) do
        if b.live then
          Btn.index(b, b:GetAttribute("action"))
          Btn.ApplyLook(b)
          Btn.Update(b)
        end
      end
    end
    AB.ApplyStock()
    AB.ApplyBindings()
  end)
end

-- Stock bars: parked under a hidden frame while the matching Phoenix bar is on.
function AB.Park(id, frame, want)
  if not frame then return end
  if want and not AB.parked[id] then
    AB.stockHider = AB.stockHider or PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
    AB.stockHider:Hide()
    AB.parked[id] = frame:GetParent() or UIParent
    frame:SetParent(AB.stockHider)
  elseif not want and AB.parked[id] then
    frame:SetParent(AB.parked[id])
    AB.parked[id] = nil
  end
end

function AB.ApplyStock()
  for i, d in ipairs(DEFS) do
    if d.stock then AB.Park(i, _G[d.stock], AB.active and cfg[i].on) end
  end
end

-- Keybinds: the keys bound to a Blizzard bar's commands click the Phoenix
-- button, as override bindings owned by the binding ledger (never saved).
function AB.ApplyBindings()
  PUI.Bindings:Release(OWNER)
  for _, b in ipairs(Btn.all) do b.bindKey = false end
  if AB.active then
    for i, d in ipairs(DEFS) do
      local bar = AB.bars[i]
      if d.bind and bar and cfg[i].on then
        for j, b in ipairs(bar.buttons) do
          if b.live then
            local k1, k2 = GetBindingKey(d.bind .. j)
            if k1 then PUI.Bindings:Claim(OWNER, k1, { click = b:GetName(), button = "LeftButton" }) end
            if k2 then PUI.Bindings:Claim(OWNER, k2, { click = b:GetName(), button = "LeftButton" }) end
            b.bindKey = k1 or false
          end
        end
      end
    end
  end
  if ns.KB then ns.KB.Apply() end
  for _, b in ipairs(Btn.all) do Btn.UpdateHotkey(b) end
end

function AB.ApplyAll()
  for i = 1, NUM_BARS do AB.ApplyBar(i) end
  if ns.Special then ns.Special.ApplyAll() end
  if ns.ItemBars then ns.ItemBars.ApplyAll() end
end

function AB.ApplyLookAll()
  for _, b in ipairs(Btn.all) do Btn.ApplyLook(b) end
  if AB.active then
    Btn.Each(Btn.Update)
    if ns.Special then ns.Special.Refresh() end
    if ns.ItemBars then ns.ItemBars.Refresh() end
  end
end

local function armAssist()
  if AB.active and S.assist then
    if not Ticker:IsRegistered("ab.assist") then Ticker:Register("ab.assist", 0.2, Btn.Assist, OWNER) end
  else
    if Ticker:IsRegistered("ab.assist") then Ticker:Unregister("ab.assist") end
    Btn.Assist()
  end
end
AB.ArmAssist = armAssist

-- Events -----------------------------------------------------------------------------------
local function onEnable(mod)
  AB.active, AB.mod = true, mod
  AB.ApplyAll()
  mod:RegisterEvent("ACTIONBAR_SLOT_CHANGED", function(_, _, slot) Btn.ForSlot(slot, Btn.Update) end)
  mod:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", function() Btn.Each(Btn.UpdateCooldown) end)
  mod:RegisterEvent("LOSS_OF_CONTROL_UPDATE", function() Btn.Each(Btn.UpdateCooldown) end)
  mod:RegisterEvent("SPELL_UPDATE_CHARGES", function() Btn.Each(Btn.UpdateCount) end)
  mod:RegisterEvent("ACTIONBAR_UPDATE_USABLE", function() Btn.Each(Btn.UpdateUsable) end)
  mod:RegisterEvent("ACTIONBAR_UPDATE_STATE", function() Btn.Each(Btn.UpdateState) end)
  mod:RegisterEvent("ACTION_RANGE_CHECK_UPDATE", function(_, _, slot, inRange) Btn.ForSlot(slot, Btn.UpdateRange, inRange) end)
  mod:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(_, _, spellID) Btn.Glow(spellID, true) end)
  mod:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(_, _, spellID) Btn.Glow(spellID, false) end)
  mod:RegisterEvent("UPDATE_BINDINGS", function() CQ.Defer("ab.bindings", AB.ApplyBindings) end)
  mod:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if ns.KB and ns.KB.on then ns.KB.Stop(true) end
    for i, bar in pairs(AB.bars) do if cfg[i].on and not AB.hover[i] then bar.header:SetAlpha(cfg[i].mouseover and baseAlpha(i) or cfg[i].alpha) end end
  end)
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", function() Btn.Each(Btn.Update) end)
  if ns.Special then ns.Special.Wire(mod) end
  if ns.ItemBars then ns.ItemBars.Wire(mod) end
  armAssist()
end

local function onDisable()
  AB.active = false
  armAssist()
  if ns.KB and ns.KB.on then ns.KB.Stop(true) end
  CQ.Defer("ab.off", function()
    if AB.active then return end
    for _, bar in pairs(AB.bars) do stopBar(bar) end
    if ns.Special then ns.Special.Off() end
    if ns.ItemBars then ns.ItemBars.Off() end
    AB.ApplyStock()
    AB.ApplyBindings()
  end)
end

-- Schema -------------------------------------------------------------------------------------------
local schema = {}
AB.schema = schema

local function look(key, def, set)
  def.owner = OWNER
  def.apply = function(value)
    set(value)
    AB.ApplyLookAll()
  end
  schema[key] = def
end
local function rgba(r, g, b, a) return { r = r, g = g, b = b, a = a } end

look("ab.tooltips", { type = "toggle", default = true, label = "Action button tooltips",
  tooltip = "Shows the spell or item tooltip when the pointer is over an action button.", mode = "advanced" },
  function(v) S.tooltips = v end)
look("ab.hotkeys", { type = "toggle", default = true, label = "Keybind text",
  tooltip = "Shows the bound key on each action button.", mode = "simple" }, function(v) S.hotkeys = v end)
look("ab.keyAbbrev", { type = "toggle", default = true, label = "Short keybind text",
  tooltip = "Shortens key names so they fit: SHIFT-1 becomes S1, mouse button 4 becomes M4, mouse wheel up becomes WU.",
  mode = "simple", searchTags = { "abbreviate", "keybind", "hotkey" } }, function(v) S.keyAbbrev = v end)
look("ab.hotkeySize", { type = "range", default = 11, min = 6, max = 24, step = 1, label = "Keybind text size",
  tooltip = "Font size of the keybind text.", mode = "advanced" }, function(v) S.hotkeySize = v end)
look("ab.hotkeyColor", { type = "color", default = rgba(0.92, 0.92, 0.95, 1), label = "Keybind text colour",
  tooltip = "Colour of the keybind text.", mode = "advanced" }, function(v) S.hotkeyColor = v end)
look("ab.macroText", { type = "toggle", default = true, label = "Macro names",
  tooltip = "Shows macro names on action buttons.", mode = "advanced" }, function(v) S.macroText = v end)
look("ab.macroSize", { type = "range", default = 10, min = 6, max = 20, step = 1, label = "Macro name size",
  tooltip = "Font size of macro names.", mode = "advanced" }, function(v) S.macroSize = v end)
look("ab.countSize", { type = "range", default = 12, min = 6, max = 24, step = 1, label = "Charges and count size",
  tooltip = "Font size of charges and item counts.", mode = "advanced" }, function(v) S.countSize = v end)
look("ab.showEmpty", { type = "toggle", default = false, label = "Show empty buttons",
  tooltip = "Draws the frame of buttons that hold no action.", mode = "advanced" }, function(v) S.showEmpty = v end)
look("ab.lock", { type = "toggle", default = true, label = "Lock action buttons",
  tooltip = "Actions can only be dragged off with the pick-up modifier (Shift by default).", mode = "advanced" },
  function(v) S.lock = v end)
look("ab.cdText", { type = "toggle", default = true, label = "Cooldown numbers",
  tooltip = "Shows the time left on a cooldown as numbers on the button (drawn by the game's own countdown).",
  mode = "simple", searchTags = { "cooldown", "timer", "omnicc" } }, function(v) S.cdText = v end)
look("ab.cdTextSize", { type = "range", default = 14, min = 8, max = 32, step = 1, label = "Cooldown number size",
  tooltip = "Font size of cooldown numbers.", mode = "advanced" }, function(v) S.cdTextSize = v end)
look("ab.cdEdge", { type = "toggle", default = true, label = "Cooldown edge line",
  tooltip = "Draws the bright moving edge on the cooldown swipe.", mode = "advanced" }, function(v) S.cdEdge = v end)
look("ab.swipeAlpha", { type = "range", default = 0.8, min = 0, max = 1, step = 0.05, label = "Cooldown swipe darkness",
  tooltip = "How dark the cooldown swipe is.", mode = "advanced" }, function(v) S.swipeAlpha = v end)
look("ab.dimOnCooldown", { type = "toggle", default = false, label = "Dim buttons on cooldown",
  tooltip = "Darkens a button while its action is on cooldown.", mode = "advanced" }, function(v) S.dimOnCooldown = v end)
look("ab.dimAlpha", { type = "range", default = 0.45, min = 0.05, max = 0.9, step = 0.05, label = "Cooldown dim strength",
  tooltip = "How much a button darkens while on cooldown.", mode = "advanced" }, function(v) S.dimAlpha = v end)
look("ab.lossOfControl", { type = "toggle", default = true, label = "Loss of control swipe",
  tooltip = "Shows a red swipe on buttons you cannot use because you are stunned, silenced or locked out.",
  mode = "advanced", searchTags = { "stun", "silence", "lockout" } }, function(v) S.lossOfControl = v end)
look("ab.rangeMode", { type = "select", default = "overlay", choices = { "overlay", "tint", "off" },
  choiceLabels = { overlay = "Red overlay", tint = "Tint the icon", off = "Off" }, label = "Out of range",
  tooltip = "How a button shows that its target is out of range.", mode = "simple", searchTags = { "range" } },
  function(v) S.rangeMode = v end)
look("ab.rangeColor", { type = "color", default = rgba(0.9, 0.2, 0.2, 0.5), label = "Out of range colour",
  tooltip = "Colour used for out of range buttons.", mode = "advanced" }, function(v) S.rangeColor = v end)
look("ab.unusableColor", { type = "color", default = rgba(0.4, 0.4, 0.4, 1), label = "Unusable colour",
  tooltip = "Tint of buttons you cannot use right now.", mode = "advanced" }, function(v) S.unusableColor = v end)
look("ab.manaColor", { type = "color", default = rgba(0.35, 0.45, 1, 1), label = "Not enough power colour",
  tooltip = "Tint of buttons you lack the mana, energy or other power for.", mode = "advanced" }, function(v) S.manaColor = v end)
look("ab.neverDim", { type = "list", default = { "18562" }, maxItems = 40, label = "Never dim these spells",
  tooltip = "Spell IDs that keep full colour even when the game marks them unusable (for example Swiftmend, usable only on a target with your heal over time).",
  mode = "advanced", itemValidate = function(v) return tonumber(v) ~= nil, "a spell ID" end, searchTags = { "swiftmend", "usable" } },
  function(v) S.neverDim = v end)
look("ab.zoom", { type = "range", default = 0.08, min = 0, max = 0.2, step = 0.01, label = "Icon zoom",
  tooltip = "Crops the icon edge so the artwork fills the button.", mode = "advanced" }, function(v) S.zoom = v end)
look("ab.border", { type = "range", default = 1, min = 0, max = 4, step = 1, label = "Button border",
  tooltip = "Border thickness in pixels (0 hides it).", mode = "simple" }, function(v) S.border = v end)
look("ab.borderColor", { type = "color", default = rgba(0, 0, 0, 1), label = "Button border colour",
  tooltip = "Colour of the button border.", mode = "advanced" }, function(v) S.borderColor = v end)
look("ab.procGlow", { type = "select", default = "pulse", choices = PUI.Glow.STYLES, choiceLabels = PUI.Glow.STYLE_LABELS,
  label = "Proc glow", tooltip = "How a button glows when the game highlights the spell (a proc).", mode = "simple",
  searchTags = { "glow", "proc", "highlight" } }, function(v) S.procGlow = v end)
look("ab.procColor", { type = "color", default = rgba(1, 0.78, 0.25, 1), label = "Proc glow colour",
  tooltip = "Colour of the proc glow.", mode = "advanced" }, function(v) S.procColor = v end)
local assistKey = function(key, def, set)
  def.owner = OWNER
  def.apply = function(v) set(v); AB.ApplyLookAll(); armAssist() end
  schema[key] = def
end
assistKey("ab.assist", { type = "toggle", default = false, label = "Assisted combat highlight",
  tooltip = "Outlines the button that holds the spell the game's rotation helper suggests next.", mode = "advanced",
  searchTags = { "rotation", "assisted", "one button" } }, function(v) S.assist = v end)
assistKey("ab.assistColor", { type = "color", default = rgba(0.3, 0.85, 1, 1), label = "Assisted highlight colour",
  tooltip = "Colour of the assisted combat outline.", mode = "advanced" }, function(v) S.assistColor = v end)
schema["ab.mouseoverLinked"] = { type = "toggle", default = false, label = "Reveal all mouse-over bars together",
  tooltip = "Pointing at any bar that fades until mouse-over shows every such bar at once.", mode = "advanced", owner = OWNER,
  apply = function(v) linked.on = v end }

local PAGES = {}
for p = 1, 15 do PAGES[#PAGES + 1] = tostring(p) end

local function barKey(i, key, def, set)
  def.owner = OWNER
  def.apply = function(value)
    set(cfg[i], value)
    AB.ApplyBar(i)
  end
  schema["ab.bar" .. i .. "." .. key] = def
end

for i, d in ipairs(DEFS) do
  local label = "Bar " .. i
  local simple = i <= 3 and "simple" or "advanced"
  barKey(i, "enabled", { type = "toggle", default = d.on, label = label,
    tooltip = "Shows Phoenix action bar " .. i .. (d.stock and " and hides the matching Blizzard bar." or "."), mode = "simple" },
    function(c, v) c.on = v end)
  barKey(i, "buttons", { type = "range", default = 12, min = 1, max = 12, step = 1, label = label .. " buttons",
    tooltip = "How many buttons bar " .. i .. " shows (an action page holds 12).", mode = simple, overridable = true }, function(c, v) c.buttons = v end)
  barKey(i, "perRow", { type = "range", default = d.vertical and 1 or 12, min = 1, max = 12, step = 1, label = label .. " buttons per row",
    tooltip = "Buttons in each row of bar " .. i .. ".", mode = simple, overridable = true }, function(c, v) c.perRow = v end)
  barKey(i, "size", { type = "range", default = 36, min = 20, max = 64, step = 1, label = label .. " button size",
    tooltip = "Button size of bar " .. i .. " in pixels.", mode = simple, overridable = true }, function(c, v) c.size = v end)
  barKey(i, "spacing", { type = "range", default = 2, min = 0, max = 12, step = 1, label = label .. " spacing",
    tooltip = "Gap between the buttons of bar " .. i .. ".", mode = "advanced" }, function(c, v) c.spacing = v end)
  barKey(i, "scale", { type = "range", default = 1, min = 0.5, max = 2, step = 0.05, label = label .. " scale",
    tooltip = "Scale of bar " .. i .. ".", mode = "advanced", overridable = true }, function(c, v) c.scale = v end)
  barKey(i, "alpha", { type = "range", default = 1, min = 0.1, max = 1, step = 0.05, label = label .. " opacity",
    tooltip = "Overall opacity of bar " .. i .. ".", mode = "advanced", overridable = true }, function(c, v) c.alpha = v end)
  barKey(i, "growX", { type = "select", default = "RIGHT", choices = { "RIGHT", "LEFT" },
    choiceLabels = { RIGHT = "Left to right", LEFT = "Right to left" }, label = label .. " button order",
    tooltip = "Which way the buttons of bar " .. i .. " run.", mode = "advanced" }, function(c, v) c.growX = v end)
  barKey(i, "growY", { type = "select", default = "DOWN", choices = { "DOWN", "UP" },
    choiceLabels = { DOWN = "Rows go down", UP = "Rows go up" }, label = label .. " row direction",
    tooltip = "Which way extra rows of bar " .. i .. " are added.", mode = "advanced" }, function(c, v) c.growY = v end)
  barKey(i, "fade", { type = "toggle", default = false, label = label .. " fade out of combat",
    tooltip = "Bar " .. i .. " fades to the fade opacity while you are out of combat.", mode = "advanced", overridable = true }, function(c, v) c.fade = v end)
  barKey(i, "mouseover", { type = "toggle", default = false, label = label .. " fade until mouse-over",
    tooltip = "Bar " .. i .. " stays at the fade opacity until you point at it.", mode = simple, overridable = true,
    searchTags = { "mouseover", "hover", "fade" } }, function(c, v) c.mouseover = v end)
  barKey(i, "fadeAlpha", { type = "range", default = 0.3, min = 0, max = 1, step = 0.05, label = label .. " fade opacity",
    tooltip = "Opacity of bar " .. i .. " while faded.", mode = "advanced" }, function(c, v) c.fadeAlpha = v end)
  barKey(i, "show", { type = "visibility", default = { mode = "always" }, label = label .. ": where to show",
    tooltip = "Show bar " .. i .. " everywhere, never, or only in the content, combat state, group and specialization you pick. Combat, vehicle, pet battle, mounted and skyriding apply instantly even in combat.",
    mode = simple, overridable = true, watchId = "ab.bar" .. i, searchTags = { "visibility", "combat", "hide", "mounted" } },
    function(c, v) c.show = v end)
  barKey(i, "visibility", { type = "text", default = "", label = label .. " visibility (macro conditions)",
    tooltip = "Advanced: macro conditions that show or hide bar " .. i .. ", e.g. [combat] show; hide. When set, this replaces the where-to-show choice.",
    mode = "advanced" }, function(c, v) c.visibility = v end)
  barKey(i, "pageMod", { type = "select", default = "none", choices = { "none", "shift", "ctrl", "alt" },
    choiceLabels = { none = "No modifier paging", shift = "While Shift is held", ctrl = "While Ctrl is held", alt = "While Alt is held" },
    label = label .. " modifier paging", tooltip = "Bar " .. i .. " switches to another action page while the modifier is held.",
    mode = "advanced", searchTags = { "paging", "modifier" } }, function(c, v) c.pageMod = v end)
  barKey(i, "pageModTo", { type = "select", default = "2", choices = PAGES, label = label .. " page while the modifier is held",
    tooltip = "The action page bar " .. i .. " shows while its paging modifier is held.", mode = "advanced" },
    function(c, v) c.pageModTo = tonumber(v) end)
  barKey(i, "clickThrough", { type = "toggle", default = false, label = label .. " click-through",
    tooltip = "Mouse clicks pass through bar " .. i .. " (keybinds still work).", mode = "advanced" }, function(c, v) c.clickThrough = v end)
  if i ~= 1 then
    barKey(i, "page", { type = "select", default = tostring(d.page), choices = PAGES, label = label .. " action page",
      tooltip = "Which action page (12 slots) bar " .. i .. " shows.", mode = "advanced" }, function(c, v) c.page = tonumber(v) end)
  else
    barKey(1, "formPaging", { type = "toggle", default = true, label = "Bar 1 follows forms and stances",
      tooltip = "Bar 1 switches page in cat, bear, stealth, shadowform and other forms, like the default bar.",
      mode = "advanced", searchTags = { "paging", "stance", "form", "druid", "rogue" } }, function(c, v) c.formPaging = v end)
    barKey(1, "skyridingPaging", { type = "toggle", default = true, label = "Bar 1 shows skyriding abilities",
      tooltip = "Bar 1 switches to the skyriding page while you skyride.", mode = "advanced",
      searchTags = { "paging", "dragonriding", "skyriding" } }, function(c, v) c.skyridingPaging = v end)
  end
  Layout:RegisterElement("ab.bar" .. i, { label = "Action bar " .. i, owner = OWNER, size = { 12 * 38, 36 },
    default = { point = d.pos[1], x = d.pos[2], y = d.pos[3] } })
end

for k, def in pairs(ns.Special and ns.Special.schema or {}) do schema[k] = def end
for k, def in pairs(ns.KB and ns.KB.schema or {}) do schema[k] = def end
for k, def in pairs(ns.ItemBars and ns.ItemBars.schema or {}) do schema[k] = def end
AB.ItemBars = ns.ItemBars

-- Conflict notice (plan 1.35): other action bar addons.
local Coexist = PUI.Coexist
local ckey, cdef = Coexist:Define("actionbars", { module = OWNER, job = "Action bars",
  addons = { "Bartender4", "Dominos", "ElvUI", "EllesmereUIActionBars", "ConsolePort_Bar", "LUI" } })
cdef.owner = OWNER
schema[ckey] = cdef

AB.module = PUI:RegisterModule(OWNER, {
  label = "Action bars",
  tooltip = "Phoenix action bars with paging, where-to-show rules, mouse-over fade, keybind mode, cooldowns, range colouring and proc glow, plus stance, pet, vehicle exit and item bars.",
  enabledByDefault = false,
  loadCondition = function() return Coexist:Allows("actionbars") end,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
for key, def in pairs(schema) do if key ~= ckey then def.apply(Schema:Get(key)) end end
