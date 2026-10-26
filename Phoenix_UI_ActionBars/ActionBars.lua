local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Action Bars module (PUI_V2 5.6): ten bars of secure action buttons. Each
-- bar is a SecureHandlerStateTemplate header with a visibility driver (user
-- macro conditions), a combat fade driver that runs in the restricted
-- environment, and - for bar 1 - a paging driver covering [vehicleui],
-- [overridebar], [possessbar], [shapeshift], [bonusbar] (class paging) and
-- [bar:N]. Keybinds of the matching Blizzard bars are redirected with
-- SetOverrideBindingClick; stock bars are parked under a hidden parent. All
-- protected work happens out of combat through the CombatQueue.
local _, ns = ...
local Schema, Layout, CQ = PUI.Schema, PUI.Layout, PUI.CombatQueue
local Btn = ns.Buttons
local OWNER = "ActionBars"

local AB = { active = false, bars = {}, parked = {} }
ns.AB = AB
PUI.ActionBars = AB

local settings = { tooltips = true, hotkeys = true, macroText = true, showEmpty = false, lock = true }
ns.settings = settings

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

local PAGE_DRIVER = "[vehicleui][overridebar][possessbar][shapeshift][bonusbar] dynamic; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"
AB.PAGE_DRIVER = PAGE_DRIVER
local DEFAULT_VIS_MAIN = "[petbattle] hide; show"
local DEFAULT_VIS = "[petbattle][vehicleui][overridebar][possessbar] hide; show"

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
    self:SetAlpha(1)
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
    fade = false, fadeAlpha = 0.3, visibility = "", page = d.page }
end

-- Bars -------------------------------------------------------------------------------
local function build(i)
  local bar = AB.bars[i]
  if bar then return bar end
  local header = PUI:CreateFrame("Frame", "PhoenixUI_ActionBar" .. i, UIParent, "SecureHandlerStateTemplate", OWNER)
  header:SetAttribute("_onstate-page", PAGE_SNIPPET)
  header:SetAttribute("_onstate-fade", FADE_SNIPPET)
  bar = { index = i, header = header, buttons = {} }
  for j = 1, SLOTS_PER_PAGE do
    local b = Btn.Create(header, "PhoenixUI_ActionBar" .. i .. "Button" .. j, j)
    header:SetFrameRef("button" .. j, b)
    bar.buttons[j] = b
  end
  AB.bars[i] = bar
  return bar
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
      local col, row = (j - 1) % perRow, math.floor((j - 1) / perRow)
      b:SetPoint("TOPLEFT", header, "TOPLEFT", col * (size + gap), -row * (size + gap))
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

-- Fixed-page bars set their slots directly; bar 1 is driven by the page state.
local function assignSlots(bar)
  local c = cfg[bar.index]
  if bar.index == 1 then
    RegisterStateDriver(bar.header, "page", PAGE_DRIVER)
  else
    for j, b in ipairs(bar.buttons) do b:SetAttribute("action", (c.page - 1) * SLOTS_PER_PAGE + j) end
  end
end

local function applyDrivers(bar)
  local c = cfg[bar.index]
  local vis = c.visibility ~= "" and c.visibility or (bar.index == 1 and DEFAULT_VIS_MAIN or DEFAULT_VIS)
  RegisterStateDriver(bar.header, "visibility", vis)
  bar.header:SetAttribute("fade", c.fade)
  bar.header:SetAttribute("fadealpha", c.fadeAlpha)
  if c.fade then
    RegisterStateDriver(bar.header, "fade", "[combat] in; out")
  else
    UnregisterStateDriver(bar.header, "fade")
    bar.header:SetAlpha(1)
  end
end

local function stopBar(bar)
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
      assignSlots(bar)
      applyDrivers(bar)
      for _, b in ipairs(bar.buttons) do
        if b.live then
          Btn.index(b, b:GetAttribute("action"))
          Btn.Update(b)
        end
      end
    end
    AB.ApplyStock()
    AB.ApplyBindings()
  end)
end

-- Stock bars: parked under a hidden frame while the matching Phoenix bar is on.
function AB.ApplyStock()
  for i, d in ipairs(DEFS) do
    local frame = d.stock and _G[d.stock]
    if frame then
      local want = AB.active and cfg[i].on
      if want and not AB.parked[i] then
        AB.stockHider = AB.stockHider or PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
        AB.stockHider:Hide()
        AB.parked[i] = frame:GetParent() or UIParent
        frame:SetParent(AB.stockHider)
      elseif not want and AB.parked[i] then
        frame:SetParent(AB.parked[i])
        AB.parked[i] = nil
      end
    end
  end
end

-- Keybinds: the keys bound to a Blizzard bar's commands click the Phoenix button.
function AB.ApplyBindings()
  local owner = AB.bindingOwner
  if not owner then
    owner = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
    AB.bindingOwner = owner
  end
  ClearOverrideBindings(owner)
  for _, b in ipairs(Btn.all) do b.bindKey = nil end
  if not AB.active then
    for _, b in ipairs(Btn.all) do Btn.UpdateHotkey(b) end
    return
  end
  for i, d in ipairs(DEFS) do
    local bar = AB.bars[i]
    if d.bind and bar and cfg[i].on then
      for j, b in ipairs(bar.buttons) do
        if b.live then
          local k1, k2 = GetBindingKey(d.bind .. j)
          if k1 then SetOverrideBindingClick(owner, false, k1, b:GetName(), "LeftButton") end
          if k2 then SetOverrideBindingClick(owner, false, k2, b:GetName(), "LeftButton") end
          b.bindKey = k1
        end
        Btn.UpdateHotkey(b)
      end
    end
  end
end

function AB.ApplyAll()
  for i = 1, NUM_BARS do AB.ApplyBar(i) end
end

-- Events -----------------------------------------------------------------------------------
local function onEnable(mod)
  AB.active, AB.mod = true, mod
  AB.ApplyAll()
  mod:RegisterEvent("ACTIONBAR_SLOT_CHANGED", function(_, _, slot) Btn.ForSlot(slot, Btn.Update) end)
  mod:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", function() Btn.Each(Btn.UpdateCooldown) end)
  mod:RegisterEvent("SPELL_UPDATE_CHARGES", function() Btn.Each(Btn.UpdateCount) end)
  mod:RegisterEvent("ACTIONBAR_UPDATE_USABLE", function() Btn.Each(Btn.UpdateUsable) end)
  mod:RegisterEvent("ACTIONBAR_UPDATE_STATE", function() Btn.Each(Btn.UpdateState) end)
  mod:RegisterEvent("ACTION_RANGE_CHECK_UPDATE", function(_, _, slot, inRange) Btn.ForSlot(slot, Btn.UpdateRange, inRange) end)
  mod:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(_, _, spellID) Btn.Glow(spellID, true) end)
  mod:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(_, _, spellID) Btn.Glow(spellID, false) end)
  mod:RegisterEvent("UPDATE_BINDINGS", function() CQ.Defer("ab.bindings", AB.ApplyBindings) end)
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", function() Btn.Each(Btn.Update) end)
end

local function onDisable()
  AB.active = false
  CQ.Defer("ab.off", function()
    if AB.active then return end
    for _, bar in pairs(AB.bars) do stopBar(bar) end
    AB.ApplyStock()
    AB.ApplyBindings()
  end)
end

-- Schema -------------------------------------------------------------------------------------------
local schema = {}
AB.schema = schema

local function global(key, def, set)
  def.owner = OWNER
  def.apply = function(value)
    set(value)
    if AB.active then Btn.Each(Btn.Update) end
  end
  schema[key] = def
end
global("ab.tooltips", { type = "toggle", default = true, label = "Action button tooltips",
  tooltip = "Shows the spell or item tooltip when the pointer is over an action button.", mode = "advanced" },
  function(v) settings.tooltips = v end)
global("ab.hotkeys", { type = "toggle", default = true, label = "Keybind text",
  tooltip = "Shows the bound key on each action button.", mode = "simple" }, function(v) settings.hotkeys = v end)
global("ab.macroText", { type = "toggle", default = true, label = "Macro names",
  tooltip = "Shows macro names on action buttons.", mode = "advanced" }, function(v) settings.macroText = v end)
global("ab.showEmpty", { type = "toggle", default = false, label = "Show empty buttons",
  tooltip = "Draws the frame of buttons that hold no action.", mode = "advanced" }, function(v) settings.showEmpty = v end)
global("ab.lock", { type = "toggle", default = true, label = "Lock action buttons",
  tooltip = "Actions can only be dragged off with the pick-up modifier (Shift by default).", mode = "advanced" },
  function(v) settings.lock = v end)

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
    tooltip = "How many buttons bar " .. i .. " shows (an action page holds 12).", mode = simple }, function(c, v) c.buttons = v end)
  barKey(i, "perRow", { type = "range", default = d.vertical and 1 or 12, min = 1, max = 12, step = 1, label = label .. " buttons per row",
    tooltip = "Buttons in each row of bar " .. i .. ".", mode = simple }, function(c, v) c.perRow = v end)
  barKey(i, "size", { type = "range", default = 36, min = 20, max = 64, step = 1, label = label .. " button size",
    tooltip = "Button size of bar " .. i .. " in pixels.", mode = simple }, function(c, v) c.size = v end)
  barKey(i, "spacing", { type = "range", default = 2, min = 0, max = 12, step = 1, label = label .. " spacing",
    tooltip = "Gap between the buttons of bar " .. i .. ".", mode = "advanced" }, function(c, v) c.spacing = v end)
  barKey(i, "scale", { type = "range", default = 1, min = 0.5, max = 2, step = 0.05, label = label .. " scale",
    tooltip = "Scale of bar " .. i .. ".", mode = "advanced" }, function(c, v) c.scale = v end)
  barKey(i, "fade", { type = "toggle", default = false, label = label .. " fade out of combat",
    tooltip = "Bar " .. i .. " fades to the fade opacity while you are out of combat.", mode = "advanced" }, function(c, v) c.fade = v end)
  barKey(i, "fadeAlpha", { type = "range", default = 0.3, min = 0, max = 1, step = 0.05, label = label .. " fade opacity",
    tooltip = "Opacity of bar " .. i .. " out of combat when fading is on.", mode = "advanced" }, function(c, v) c.fadeAlpha = v end)
  barKey(i, "visibility", { type = "text", default = "", label = label .. " visibility",
    tooltip = "Macro conditions that show or hide bar " .. i .. ", e.g. [combat] show; hide. Empty uses the default.",
    mode = "advanced" }, function(c, v) c.visibility = v end)
  if i ~= 1 then
    barKey(i, "page", { type = "select", default = tostring(d.page), choices = PAGES, label = label .. " action page",
      tooltip = "Which action page (12 slots) bar " .. i .. " shows.", mode = "advanced" }, function(c, v) c.page = tonumber(v) end)
  end
  Layout:RegisterElement("ab.bar" .. i, { label = "Action bar " .. i, owner = OWNER, size = { 12 * 38, 36 },
    default = { point = d.pos[1], x = d.pos[2], y = d.pos[3] } })
end

AB.module = PUI:RegisterModule(OWNER, {
  label = "Action bars",
  tooltip = "Phoenix action bars with paging, keybinds, cooldowns, range colouring and proc glow.",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
for key, def in pairs(schema) do def.apply(Schema:Get(key)) end
