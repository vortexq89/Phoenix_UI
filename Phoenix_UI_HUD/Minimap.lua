local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Minimap (PUI_V2 5.9): square or circle mask (live), size, the cluster's
-- border and zone button alpha-zeroed, and Phoenix clock / zone / coordinate
-- texts refreshed by one Ticker entry that exists only while a text is shown.
-- Everything is restored when the module turns off. Off by default.
local _, ns = ...
local Schema, CQ, Ticker, Media = PUI.Schema, PUI.CombatQueue, PUI.Ticker, PUI.Media
local OWNER = "Minimap"

local MM = { active = false, saved = {} }
ns.MM = MM
PUI.Minimap = MM

local s = { shape = "square", size = 200, hideCluster = true, clock = true, zone = true, coords = false }
MM.settings = s
MM.MASKS = { square = "Interface\\Buttons\\WHITE8X8", circle = "Interface\\Masks\\CircleMaskScalable" }

local function clusterParts()
  local c = _G.MinimapCluster
  if not c then return {} end
  return { c.BorderTop, c.ZoneTextButton, _G.MinimapCompassTexture }
end

local texts
local function buildTexts()
  if texts then return texts end
  texts = {}
  for _, k in ipairs({ "clock", "zone", "coords" }) do
    local fs = Minimap:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(Media:FontObject("number"))
    fs:Hide()
    texts[k] = fs
  end
  texts.zone:SetPoint("TOP", Minimap, "TOP", 0, -4)
  texts.clock:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 4)
  texts.coords:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -4, 4)
  MM.texts = texts
  return texts
end

function MM.Coords()
  local map = C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  if PUI.Secret.IsSecret(x) or type(x) == "nil" then return nil end
  return string.format("%.1f, %.1f", x * 100, y * 100)
end

local function tick()
  if not texts then return end
  if s.clock then texts.clock:SetText(date("%H:%M")) end
  if s.zone then texts.zone:SetText(GetMinimapZoneText()) end
  if s.coords then texts.coords:SetText(MM.Coords() or "") end
end
MM.Tick = tick

function MM.Apply()
  if not MM.active then return end
  local t = buildTexts()
  for _, k in ipairs({ "clock", "zone", "coords" }) do t[k]:SetShown(s[k]) end
  local need = s.clock or s.zone or s.coords
  if need and not Ticker:IsRegistered("mm.texts") then Ticker:Register("mm.texts", 1, tick, OWNER)
  elseif not need and Ticker:IsRegistered("mm.texts") then Ticker:Unregister("mm.texts") end
  tick()
  for _, part in ipairs(clusterParts()) do
    if MM.saved[part] == nil then MM.saved[part] = part:GetAlpha() end
    part:SetAlpha(s.hideCluster and 0 or MM.saved[part])
  end
  Minimap:SetMaskTexture(MM.MASKS[s.shape])
  CQ.Defer("mm.size", function()
    if not MM.active then return end
    if MM.savedSize == nil then MM.savedSize = { Minimap:GetWidth(), Minimap:GetHeight() } end
    Minimap:SetSize(s.size, s.size)
  end)
end

local function onEnable(mod)
  MM.active = true
  mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", tick)
  MM.Apply()
end

local function onDisable()
  MM.active = false
  if Ticker:IsRegistered("mm.texts") then Ticker:Unregister("mm.texts") end
  if texts then for _, fs in pairs(texts) do fs:Hide() end end
  for part, alpha in pairs(MM.saved) do part:SetAlpha(alpha) end
  wipe(MM.saved)
  Minimap:SetMaskTexture(MM.MASKS.circle)
  CQ.Defer("mm.size", function()
    if MM.active or not MM.savedSize then return end
    Minimap:SetSize(MM.savedSize[1], MM.savedSize[2])
    MM.savedSize = nil
  end)
end

local schema = {}
MM.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value) s[name] = value; MM.Apply() end
  schema["mm." .. name] = def
end
key("shape", { type = "select", default = "square", choices = { "square", "circle" }, label = "Minimap shape",
  tooltip = "Square or round minimap.", mode = "simple" })
key("size", { type = "range", default = 200, min = 120, max = 400, step = 1, label = "Minimap size",
  tooltip = "Width and height of the minimap.", mode = "simple" })
key("hideCluster", { type = "toggle", default = true, label = "Hide minimap border and zone bar",
  tooltip = "Fades out the game's minimap border and zone text button.", mode = "advanced" })
key("clock", { type = "toggle", default = true, label = "Minimap clock", tooltip = "Local time under the minimap.", mode = "advanced" })
key("zone", { type = "toggle", default = true, label = "Minimap zone text", tooltip = "Current subzone on the minimap.", mode = "advanced" })
key("coords", { type = "toggle", default = false, label = "Minimap coordinates",
  tooltip = "Player coordinates (not available inside instances).", mode = "advanced" })

MM.module = PUI:RegisterModule(OWNER, {
  label = "Minimap", tooltip = "Phoenix minimap shape, size and texts.", enabledByDefault = false,
  schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
