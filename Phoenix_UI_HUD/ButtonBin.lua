local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Minimap button bin (plan 5.7 / mockup 14 "Buttons bin (owner)"): addon
-- buttons made by LibDBIcon and similar minimap buttons are collected into a
-- searchable flyout grid. Phoenix's own entry stays in the addon compartment.
-- Each collected button's parent and points are recorded and given back when
-- the bin is turned off. Collection is done out of combat only (CombatQueue).
local _, ns = ...
local Schema, CQ, Theme, Media = PUI.Schema, PUI.CombatQueue, PUI.Theme, PUI.Media
local MM = ns.MM
local OWNER = "Minimap"

local Bin = { buttons = {}, original = {}, filter = "" }
ns.Bin = Bin
PUI.ButtonBin = Bin

local s = { enabled = true, columns = 6, size = 28, spacing = 4, open = "click", blacklist = {}, keep = {}, mouseover = false }
Bin.settings = s

local function listHas(list, name)
  for i = 1, #list do if list[i] == name then return true end end
  return false
end

-- A collectable button: a named child of the minimap that is not Blizzard's.
local BLIZZARD = { MinimapZoomIn = true, MinimapZoomOut = true, MiniMapTrackingButton = true, GameTimeFrame = true,
  MinimapBackdrop = true, MiniMapMailFrame = true, QueueStatusButton = true, ExpansionLandingPageMinimapButton = true,
  AddonCompartmentFrame = true, PhoenixUI_BinButton = true }
function Bin.IsAddonButton(frame)
  if type(frame) ~= "table" or not frame.GetName then return false end
  local name = frame:GetName()
  if type(name) ~= "string" or BLIZZARD[name] then return false end
  if name:find("^LibDBIcon10_") then return true end
  return (name:find("MinimapButton") or name:find("MiniMapButton")) ~= nil and frame:GetObjectType() == "Button"
end

-- Label shown in search: the LibDBIcon data object name when present.
function Bin.Label(frame)
  local name = frame:GetName() or ""
  return (name:gsub("^LibDBIcon10_", ""):gsub("_?Mini[mM]ap[bB]utton$", ""))
end

function Bin.Scan()
  local found = {}
  for _, child in ipairs({ Minimap:GetChildren() }) do
    if Bin.IsAddonButton(child) then found[#found + 1] = child end
  end
  table.sort(found, function(a, b) return Bin.Label(a):lower() < Bin.Label(b):lower() end)
  return found
end

local flyout, toggle
local function buildFlyout()
  if flyout then return flyout end
  flyout = PUI:CreateFrame("Frame", "PhoenixUI_ButtonBin", UIParent, "BackdropTemplate", OWNER)
  Theme:Backdrop(flyout, "surface.1")
  flyout:SetFrameStrata("DIALOG")
  flyout.title = flyout:CreateFontString(nil, "OVERLAY")
  flyout.title:SetFontObject(Media:FontObject("label"))
  flyout.title:SetPoint("TOPLEFT", 8, -8)
  flyout.search = CreateFrame("EditBox", nil, flyout, "InputBoxTemplate")
  flyout.search:SetSize(110, 18)
  flyout.search:SetPoint("TOPRIGHT", -8, -5)
  flyout.search:SetAutoFocus(false)
  flyout.search:SetScript("OnTextChanged", function(self) Bin.filter = self:GetText() or ""; Bin.Layout() end)
  flyout.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  flyout:Hide()
  Bin.flyout = flyout
  toggle = PUI:CreateFrame("Button", "PhoenixUI_BinButton", Minimap, nil, OWNER)
  toggle:SetSize(18, 18)
  toggle:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -2)
  toggle.tex = toggle:CreateTexture(nil, "ARTWORK")
  toggle.tex:SetAllPoints()
  toggle.tex:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
  toggle:SetScript("OnClick", function() if s.open == "click" then Bin.Toggle() end end)
  toggle:SetScript("OnEnter", function() if s.open == "hover" then Bin.Toggle(true) end end)
  Bin.toggle = toggle
  return flyout
end

-- Grid solver: positions of n cells in `columns` columns (row-major).
function Bin.Grid(n, columns, size, spacing)
  local out = {}
  for i = 1, n do
    local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
    out[i] = { x = 8 + col * (size + spacing), y = -30 - row * (size + spacing) }
  end
  local rows = math.max(1, math.ceil(n / columns))
  return out, 16 + math.min(n, columns) * (size + spacing) - spacing, 38 + rows * (size + spacing) - spacing
end

function Bin.Visible()
  local out, q = {}, (Bin.filter or ""):lower()
  for _, b in ipairs(Bin.buttons) do
    if q == "" or Bin.Label(b):lower():find(q, 1, true) then out[#out + 1] = b end
  end
  return out
end

function Bin.Layout()
  if not flyout then return end
  for _, b in ipairs(Bin.buttons) do b:Hide() end
  local vis = Bin.Visible()
  local cells, w, h = Bin.Grid(#vis, s.columns, s.size, s.spacing)
  for i, b in ipairs(vis) do
    b:ClearAllPoints()
    b:SetSize(s.size, s.size)
    b:SetPoint("TOPLEFT", flyout, "TOPLEFT", cells[i].x, cells[i].y)
    b:Show()
  end
  flyout:SetSize(math.max(w, 200), h)
  flyout.title:SetText(string.format("Addon buttons  %d collected", #Bin.buttons))
end

function Bin.Toggle(show)
  local f = buildFlyout()
  if show == nil then show = not f:IsShown() end
  if show then
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -6, 0)
    Bin.Layout()
  end
  f:SetShown(show)
end

local function release(b)
  local o = Bin.original[b]
  if not o then return end
  b:SetParent(o.parent)
  b:ClearAllPoints()
  for _, p in ipairs(o.points) do b:SetPoint(unpack(p)) end
  b:SetShown(o.shown)
  Bin.original[b] = nil
end

function Bin.Collect()
  CQ.Defer("mm.bin", function()
    local on = MM.active and s.enabled
    for i = #Bin.buttons, 1, -1 do
      local b = Bin.buttons[i]
      local name = Bin.Label(b)
      if not on or listHas(s.blacklist, name) or listHas(s.keep, name) then release(b); table.remove(Bin.buttons, i) end
    end
    if toggle then toggle:SetShown(on) end
    if not on then if flyout then flyout:Hide() end return end
    buildFlyout()
    toggle:Show()
    for _, b in ipairs(Bin.Scan()) do
      local name = Bin.Label(b)
      if not Bin.original[b] and not listHas(s.blacklist, name) and not listHas(s.keep, name) then
        local points = {}
        for i = 1, b:GetNumPoints() do points[i] = { b:GetPoint(i) } end
        Bin.original[b] = { parent = b:GetParent(), points = points, shown = b:IsShown() }
        b:SetParent(flyout)
        Bin.buttons[#Bin.buttons + 1] = b
      end
    end
    Bin.Layout()
  end)
end

PUI.Kernel:On("MINIMAP_APPLIED", function() Bin.Collect() end)

local schema = {}
Bin.schema = schema
local function key(k, field, def)
  def.owner = OWNER
  def.apply = function(v) s[field] = v; if MM.active then Bin.Collect() end end
  def.searchTags = { "minimap", "buttons", "bin", "libdbicon", "addon" }
  schema[k] = def
end
key("mm.bin.enabled", "enabled", { type = "toggle", default = true, label = "Collect addon buttons",
  tooltip = "Gathers other addons' minimap buttons into one searchable bin; turning it off puts every button back where it was.", mode = "simple" })
key("mm.bin.open", "open", { type = "select", default = "click", choices = { "click", "hover" },
  choiceLabels = { click = "Click the bin button", hover = "Hover the bin button" }, label = "Open the bin by",
  tooltip = "How the button bin opens.", mode = "simple" })
key("mm.bin.columns", "columns", { type = "range", default = 6, min = 1, max = 12, step = 1, label = "Bin columns",
  tooltip = "Buttons per row in the bin.", mode = "advanced" })
key("mm.bin.size", "size", { type = "range", default = 28, min = 16, max = 44, step = 1, label = "Bin button size",
  tooltip = "Size of each button in the bin.", mode = "advanced" })
key("mm.bin.spacing", "spacing", { type = "range", default = 4, min = 0, max = 12, step = 1, label = "Bin spacing",
  tooltip = "Gap between buttons in the bin.", mode = "advanced" })
key("mm.bin.blacklist", "blacklist", { type = "list", default = {}, label = "Never collect",
  tooltip = "Buttons listed here are left alone exactly where their addon put them.", mode = "advanced" })
key("mm.bin.keep", "keep", { type = "list", default = {}, label = "Always on the minimap",
  tooltip = "Buttons listed here stay on the minimap instead of going into the bin.", mode = "advanced" })
for k, def in pairs(schema) do PUI.Schema:Register(k, def); def.apply(Schema:Get(k)) end
