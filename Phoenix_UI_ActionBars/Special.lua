local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Stance, pet, vehicle exit and item bars (plan 5.4, 1.O "Extra item bar",
-- mockup 05). Every button is a SecureActionButtonTemplate child of a
-- SecureHandlerStateTemplate header, so clicks work in combat; the set of
-- buttons (forms known, items carried) is rebuilt only out of combat through
-- the CombatQueue. Visual state that may be secret goes to widgets only.
--   stance  type "spell" with the form's spell, active form highlighted
--   pet     type "pet" with the pet action index, autocast outline
--   vehicle a vehicle exit button shown by [canexitvehicle]
--   items   type "item": the shared PUI.ItemList (this bar is its owner;
--           the Cooldown Manager custom bar shows the same list display-only)
local _, ns = ...
local Schema, Layout, CQ, Secret = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Secret
local Btn = ns.Buttons
local OWNER = "ActionBars"

local SP = { bars = {} }
ns.Special = SP

local KINDS = {
  stance = { label = "Stance bar", max = 10, stock = "StanceBar", on = true, pos = { "BOTTOMLEFT", 380, 142 },
    vis = "[petbattle][vehicleui][overridebar][possessbar] hide; show" },
  pet = { label = "Pet bar", max = 10, stock = "PetActionBar", on = true, pos = { "BOTTOM", 0, 142 },
    vis = "[petbattle][vehicleui][overridebar][possessbar] hide; [pet] show; hide" },
  vehicle = { label = "Vehicle exit button", max = 1, on = true, pos = { "BOTTOM", 260, 40 },
    vis = "[canexitvehicle] show; hide" },
  items = { label = "Item bar", max = 12, on = true, pos = { "BOTTOM", 330, 108 },
    vis = "[petbattle][vehicleui][overridebar][possessbar] hide; show" },
}
local ORDER = { "stance", "pet", "vehicle", "items" }
SP.KINDS, SP.ORDER = KINDS, ORDER
local cfg = {}
SP.cfg = cfg
for k, d in pairs(KINDS) do cfg[k] = { on = d.on, size = k == "vehicle" and 36 or 30, spacing = 2, perRow = d.max, mouseover = false, fadeAlpha = 0.3, hideBlizzard = true } end

local function AB() return ns.AB end

local function header(kind)
  local bar = SP.bars[kind]
  if bar then return bar end
  local h = PUI:CreateFrame("Frame", "PhoenixUI_" .. kind:sub(1, 1):upper() .. kind:sub(2) .. "Bar", UIParent, "SecureHandlerStateTemplate", OWNER)
  bar = { kind = kind, header = h, buttons = {}, n = 0 }
  SP.bars[kind] = bar
  return bar
end

local function hoverFn(kind)
  return function(_, on)
    local c, bar = cfg[kind], SP.bars[kind]
    if c.mouseover and bar then bar.header:SetAlpha(on and 1 or c.fadeAlpha) end
  end
end

local function button(bar, j)
  local b = bar.buttons[j]
  if b then return b end
  local name = bar.header:GetName() .. "Button" .. j
  b = PUI:CreateFrame("Button", name, bar.header, "SecureActionButtonTemplate", OWNER)
  b:RegisterForClicks("AnyUp", "AnyDown")
  Btn.Skin(b)
  b.onHover = hoverFn(bar.kind)
  b:SetScript("OnEnter", function(self)
    self.onHover(self, true)
    if not Btn.S.tooltips then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    if bar.kind == "pet" then GameTooltip:SetPetAction(j)
    elseif bar.kind == "stance" then GameTooltip:SetShapeshift(j)
    elseif self.entry then
      if self.entry.kind == "slot" then GameTooltip:SetInventoryItem("player", self.entry.slot) else GameTooltip:SetItemByID(self.entry.id) end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self) self.onHover(self, false); GameTooltip:Hide() end)
  bar.buttons[j] = b
  return b
end

-- Number of buttons each kind needs right now (plain data).
function SP.Count(kind)
  if kind == "stance" then return GetNumShapeshiftForms() or 0 end
  if kind == "pet" then return 10 end
  if kind == "vehicle" then return 1 end
  SP.items = PUI.ItemList:Items()
  return math.min(#SP.items, KINDS.items.max)
end

-- Secure attributes for button j of a kind (out of combat only).
local function configure(kind, b, j)
  if kind == "stance" then
    local _, _, _, spellID = GetShapeshiftFormInfo(j)
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", spellID)
  elseif kind == "pet" then
    b:SetAttribute("type", "pet")
    b:SetAttribute("action", j)
  elseif kind == "vehicle" then
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/leavevehicle")
  else
    local e = SP.items[j]
    b.entry = e
    b:SetAttribute("type", "item")
    b:SetAttribute("item", e.kind == "slot" and tostring(e.slot) or ("item:" .. e.id))
  end
end

local function layout(bar)
  local c = cfg[bar.kind]
  local n = bar.n
  local perRow = math.max(1, math.min(c.perRow, math.max(n, 1)))
  local rows = math.max(1, math.ceil(n / perRow))
  local size, gap = c.size, c.spacing
  bar.header:SetSize(perRow * size + (perRow - 1) * gap, rows * size + (rows - 1) * gap)
  for j, b in ipairs(bar.buttons) do
    b:ClearAllPoints()
    b:SetSize(size, size)
    if j <= n then
      local col, row = (j - 1) % perRow, math.floor((j - 1) / perRow)
      b:SetPoint("TOPLEFT", bar.header, "TOPLEFT", col * (size + gap), -row * (size + gap))
      b:Show()
      b.live = true
    else
      b:Hide()
      b.live = false
    end
  end
  local el = Layout:Element("ab." .. bar.kind)
  if el then el.size = { bar.header:GetWidth(), bar.header:GetHeight() } end
  Layout:Place(bar.header, "ab." .. bar.kind)
end

-- Visual refresh (safe in combat).
function SP.Paint(kind)
  local bar = SP.bars[kind]
  if not bar then return end
  for j = 1, bar.n do
    local b = bar.buttons[j]
    if kind == "stance" then
      local icon, active = GetShapeshiftFormInfo(j)
      b.icon:SetTexture(icon)
      b.current:SetAlphaFromBoolean(active, 1, 0)
      local start, dur = GetShapeshiftFormCooldown(j)
      b.cooldown:SetCooldown(start or 0, dur or 0)
    elseif kind == "pet" then
      local name, texture, isToken, isActive, _, autoCastEnabled = GetPetActionInfo(j)
      if type(name) == "nil" and type(texture) == "nil" then
        b.icon:SetTexture(nil)
        b.bg:SetAlpha(Btn.S.showEmpty and 1 or 0)
      else
        local tex = texture
        if isToken and not Secret.IsSecret(texture) then tex = _G[texture] or texture end
        b.icon:SetTexture(tex)
        b.bg:SetAlpha(1)
      end
      b.current:SetAlphaFromBoolean(isActive, 1, 0)
      b.range:SetAlpha(0)
      if autoCastEnabled ~= nil then b.dim:SetAlpha(0) end
      b.autocast = b.autocast or Btn.AutoCastMark(b)
      b.autocast:SetAlphaFromBoolean(autoCastEnabled, 1, 0)
      local start, dur = GetPetActionCooldown(j)
      b.cooldown:SetCooldown(start or 0, dur or 0)
    elseif kind == "vehicle" then
      b.icon:SetTexture(136190) -- generic exit arrow file id
    else
      local e = SP.items and SP.items[j]
      if e then
        b.icon:SetTexture(PUI.ItemList.Icon(e))
        b.count:SetText(PUI.ItemList.Count(e))
        PUI.ItemList.ApplyCooldown(b.cooldown, e)
      end
    end
    b.hotkey:SetText("")
  end
end

-- Autocast mark: a thin accent ring drawn inside a pet button.
function Btn.AutoCastMark(b)
  local t = b:CreateTexture(nil, "OVERLAY", nil, 3)
  t:SetPoint("TOPLEFT", 2, -2)
  t:SetPoint("BOTTOMRIGHT", -2, 2)
  PUI.Theme:Paint(t, "accent", 0.35)
  t:SetAlpha(0)
  return t
end

function SP.Apply(kind)
  local ab = AB()
  if not (ab and ab.active) then return end
  CQ.Defer("ab." .. kind, function()
    if not ab.active then return end
    local c = cfg[kind]
    local bar = SP.bars[kind]
    if not c.on then
      if bar then
        UnregisterStateDriver(bar.header, "visibility")
        bar.header:Hide()
        for _, b in ipairs(bar.buttons) do b.live = false end
      end
    else
      bar = header(kind)
      local n = SP.Count(kind)
      for j = 1, n do
        local b = button(bar, j)
        configure(kind, b, j)
        Btn.ApplyLook(b)
      end
      bar.n = n
      layout(bar)
      local vis = KINDS[kind].vis
      if n == 0 then vis = "hide" end
      RegisterStateDriver(bar.header, "visibility", vis)
      bar.header:SetAlpha(c.mouseover and c.fadeAlpha or 1)
      SP.Paint(kind)
    end
    local stock = KINDS[kind].stock
    if stock then ab.Park("sp." .. kind, _G[stock], ab.active and c.on and c.hideBlizzard) end
  end)
end

function SP.ApplyAll() for _, k in ipairs(ORDER) do SP.Apply(k) end end
function SP.Refresh() for _, k in ipairs(ORDER) do SP.Paint(k) end end

function SP.Off()
  local ab = AB()
  for kind, bar in pairs(SP.bars) do
    UnregisterStateDriver(bar.header, "visibility")
    bar.header:Hide()
    for _, b in ipairs(bar.buttons) do b.live = false end
    local stock = KINDS[kind].stock
    if stock and ab then ab.Park("sp." .. kind, _G[stock], false) end
  end
end

function SP.Wire(mod)
  local stance = function() SP.Paint("stance") end
  mod:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", function() SP.Apply("stance") end)
  mod:RegisterEvent("UPDATE_SHAPESHIFT_FORM", stance)
  mod:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", stance)
  mod:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", stance)
  local pet = function() SP.Paint("pet") end
  mod:RegisterEvent("PET_BAR_UPDATE", pet)
  mod:RegisterEvent("PET_BAR_UPDATE_COOLDOWN", pet)
  mod:RegisterEvent("PET_UI_UPDATE", pet)
  mod:RegisterUnitEvent("UNIT_PET", pet, "player")
  mod:RegisterEvent("BAG_UPDATE_DELAYED", function() SP.Apply("items") end)
  mod:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() SP.Apply("items") end)
  mod:RegisterEvent("BAG_UPDATE_COOLDOWN", function() SP.Paint("items") end)
end

PUI.ItemList:OnChange("ab.items", function() SP.Apply("items") end)

-- Schema -------------------------------------------------------------------------
local schema = {}
SP.schema = schema
local function key(kind, name, def, set)
  def.owner = OWNER
  def.apply = function(v) set(cfg[kind], v); SP.Apply(kind) end
  schema["ab." .. kind .. "." .. name] = def
end
for _, kind in ipairs(ORDER) do
  local d = KINDS[kind]
  local L = d.label
  key(kind, "enabled", { type = "toggle", default = d.on, label = L,
    tooltip = kind == "items" and "Clickable buttons for the items in the shared item list (potions, healthstones, quest items, on-use trinkets)."
      or kind == "vehicle" and "A button that leaves the vehicle, shown only when you can exit."
      or ("Phoenix " .. L:lower() .. (d.stock and " (hides the Blizzard one)." or ".")), mode = "simple" }, function(c, v) c.on = v end)
  key(kind, "size", { type = "range", default = cfg[kind].size, min = 16, max = 64, step = 1, label = L .. " button size",
    tooltip = "Button size of the " .. L:lower() .. " in pixels.", mode = "simple", overridable = true }, function(c, v) c.size = v end)
  if d.max > 1 then
    key(kind, "perRow", { type = "range", default = d.max, min = 1, max = d.max, step = 1, label = L .. " buttons per row",
      tooltip = "Buttons in each row of the " .. L:lower() .. ".", mode = "advanced" }, function(c, v) c.perRow = v end)
    key(kind, "spacing", { type = "range", default = 2, min = 0, max = 12, step = 1, label = L .. " spacing",
      tooltip = "Gap between buttons of the " .. L:lower() .. ".", mode = "advanced" }, function(c, v) c.spacing = v end)
  end
  key(kind, "mouseover", { type = "toggle", default = false, label = L .. " fade until mouse-over",
    tooltip = "The " .. L:lower() .. " stays faded until you point at it.", mode = "advanced" }, function(c, v) c.mouseover = v end)
  key(kind, "fadeAlpha", { type = "range", default = 0.3, min = 0, max = 1, step = 0.05, label = L .. " fade opacity",
    tooltip = "Opacity of the " .. L:lower() .. " while faded.", mode = "advanced" }, function(c, v) c.fadeAlpha = v end)
  if d.stock then
    key(kind, "hideBlizzard", { type = "toggle", default = true, label = "Hide Blizzard " .. L:lower(),
      tooltip = "Hides the default " .. L:lower() .. " while the Phoenix one is on.", mode = "advanced" }, function(c, v) c.hideBlizzard = v end)
  end
  Layout:RegisterElement("ab." .. kind, { label = L, owner = OWNER, size = { d.max * 32, 30 },
    default = { point = d.pos[1], x = d.pos[2], y = d.pos[3] } })
end
