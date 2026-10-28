local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Forever child (plan phase K, first slice, deferred batch D). Turns on only
-- in the Forever client (loadCondition PUI.IS_FOREVER).
--  * Flight timer: when you take a flight, the origin (the taxi map's current
--    node) and the destination (the slot you clicked, via a post-hook on the
--    game's TakeTaxiNode) name the route. The first flight on a route is
--    timed and saved; later flights show a countdown bar. The bar updates
--    from a Ticker job that exists only while you are on a taxi.
--  * Pet happiness: a small badge (Happy / Content / Unhappy) with your pet's
--    loyalty rate, polled every 2 s by a Ticker job only while you have a pet;
--    optional chat line when it becomes unhappy.
-- Threat is Embers' Threat window; swing timers are Resource Bars'.
local _, ns = ...
local Schema = PUI.Schema
local OWNER = "Forever"
local FV = { active = false }
ns.Forever = FV
PUI.Forever = FV
local s = { flightTimer = true, flightScale = 1, petHappiness = true, petWarn = false }
FV.settings = s

function FV.DB()
  local db = rawget(_G, "PhoenixUIForeverDB")
  if type(db) ~= "table" then
    db = {}
    -- lint-allow: global own SavedVariables
    PhoenixUIForeverDB = db
  end
  db.flights = db.flights or {}
  return db
end

-- Flight timer --------------------------------------------------------------------------------------
local Flight = { }
FV.Flight = Flight
function Flight.Route(from, to) return tostring(from) .. ">" .. tostring(to) end

-- Nodes on the open taxi map: origin is the node in state Current.
function Flight.Nodes()
  local map = C_Map.GetBestMapForUnit("player")
  if not map then return {} end
  local nodes = C_TaxiMap.GetAllTaxiNodes(map)
  return type(nodes) == "table" and nodes or {}
end
function Flight.OnMapOpened()
  Flight.origin, Flight.slots = nil, {}
  local current = Enum.FlightPathState and Enum.FlightPathState.Current or 0
  for _, n in ipairs(Flight.Nodes()) do
    if n.state == current then Flight.origin = n.nodeID; Flight.originName = n.name end
    if n.slotIndex then Flight.slots[n.slotIndex] = n end
  end
end
-- Post-hook on TakeTaxiNode(slot): remembers where you are going.
function Flight.OnTake(slot)
  local n = Flight.slots and Flight.slots[slot]
  if not (n and Flight.origin) then return end
  Flight.pending = { from = Flight.origin, to = n.nodeID, name = n.name }
end
function Flight.Known(from, to) return FV.DB().flights[Flight.Route(from, to)] end

function Flight.Start()
  local p = Flight.pending
  if not p then return false end
  Flight.pending = nil
  Flight.trip = { from = p.from, to = p.to, name = p.name, t0 = GetTime(), known = Flight.Known(p.from, p.to) }
  if s.flightTimer then
    Flight.Paint()
    PUI.Ticker:Register("forever.flight", 0.2, Flight.Paint, OWNER)
  end
  return true
end
-- Landing: a full flight teaches (or refines) the route time.
function Flight.Land()
  local trip = Flight.trip
  PUI.Ticker:Unregister("forever.flight")
  if Flight.bar then Flight.bar:Hide() end
  Flight.trip = nil
  if not trip then return nil end
  local secs = GetTime() - trip.t0
  if secs < 5 then return nil end
  local key = Flight.Route(trip.from, trip.to)
  local old = FV.DB().flights[key]
  FV.DB().flights[key] = old and math.floor((old + secs) / 2 + 0.5) or math.floor(secs + 0.5)
  return FV.DB().flights[key]
end
function Flight.Text(trip, now)
  local gone = now - trip.t0
  if trip.known then
    local left = math.max(0, trip.known - gone)
    return string.format("%s  %d:%02d", trip.name or "Flight", math.floor(left / 60), math.floor(left % 60)), math.min(1, gone / trip.known)
  end
  return string.format("%s  %d:%02d (learning this route)", trip.name or "Flight", math.floor(gone / 60), math.floor(gone % 60)), 0
end

PUI.Layout:RegisterElement("forever.flight", { label = "Flight timer", owner = OWNER, size = { 260, 22 }, default = { point = "TOP", x = 0, y = -140 } })
function Flight.Build()
  local b = PUI:CreateFrame("StatusBar", "PhoenixUIForeverFlight", UIParent, nil, OWNER)
  b:SetSize(260, 22)
  PUI.Layout:Place(b, "forever.flight")
  b:SetStatusBarTexture(PUI.Bars and PUI.Bars:TexturePath() or PUI.Media:Texture("flat"))
  b:SetMinMaxValues(0, 1)
  local r, g, bl = PUI.Theme:Color("accent")
  b:SetStatusBarColor(r or 1, g or 0.48, bl or 0.1, 0.9)
  PUI.Theme:Backdrop(b, "surface.0")
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFontObject(PUI.Media:FontObject("small"))
  b.text:SetPoint("CENTER")
  Flight.bar = b
  return b
end
function Flight.Paint()
  local trip = Flight.trip
  if not (trip and s.flightTimer) then if Flight.bar then Flight.bar:Hide() end return end
  local b = Flight.bar or Flight.Build()
  b:SetScale(s.flightScale or 1)
  local text, frac = Flight.Text(trip, GetTime())
  b.text:SetText(text)
  b:SetValue(frac)
  b:Show()
end

-- Pet happiness -------------------------------------------------------------------------------------
local Pet = { last = nil }
FV.Pet = Pet
Pet.LABELS = { "Unhappy", "Content", "Happy" }
Pet.COLORS = { { 0.9, 0.25, 0.2 }, { 0.95, 0.8, 0.25 }, { 0.3, 0.85, 0.35 } }
-- (happiness 1-3, loyalty rate) or nil; C_PetInfo.GetPetHappiness exists only in Forever.
function Pet.Read()
  if not PUI.IS_FOREVER or not UnitExists("pet") then return nil end
  if not (C_PetInfo and C_PetInfo.GetPetHappiness) then return nil end
  local h, _, loyalty = C_PetInfo.GetPetHappiness()
  if type(h) ~= "number" or PUI.Secret.IsSecret(h) then return nil end
  return h, loyalty
end
PUI.Layout:RegisterElement("forever.pet", { label = "Pet happiness", owner = OWNER, size = { 120, 20 }, default = { point = "BOTTOM", x = -200, y = 160 } })
function Pet.Paint(h, loyalty)
  local f = Pet.frame
  if not h or not s.petHappiness then if f then f:Hide() end return end
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUIForeverPet", UIParent, nil, OWNER)
    f:SetSize(120, 20)
    PUI.Layout:Place(f, "forever.pet")
    PUI.Theme:Backdrop(f, "surface.0")
    f.dot = f:CreateTexture(nil, "ARTWORK"); f.dot:SetSize(10, 10); f.dot:SetPoint("LEFT", 6, 0)
    f.text = f:CreateFontString(nil, "OVERLAY"); f.text:SetFontObject(PUI.Media:FontObject("small")); f.text:SetPoint("LEFT", f.dot, "RIGHT", 6, 0)
    Pet.frame = f
  end
  local c = Pet.COLORS[h] or Pet.COLORS[2]
  f.dot:SetColorTexture(c[1], c[2], c[3], 1)
  f.text:SetText((Pet.LABELS[h] or "?") .. (type(loyalty) == "number" and not PUI.Secret.IsSecret(loyalty) and loyalty ~= 0 and string.format("  %+d", loyalty) or ""))
  f:Show()
end
function Pet.Tick()
  local h, loyalty = Pet.Read()
  if h == 1 and Pet.last and Pet.last > 1 and s.petWarn then PUI.Slash.Print("your pet is unhappy: feed it.") end
  Pet.last = h
  Pet.Paint(h, loyalty)
end
function Pet.Refresh()
  PUI.Ticker:Unregister("forever.pet")
  if FV.active and s.petHappiness and UnitExists("pet") then
    PUI.Ticker:Register("forever.pet", 2, Pet.Tick, OWNER)
    Pet.Tick()
  else
    Pet.last = nil
    Pet.Paint(nil)
  end
end

-- Module --------------------------------------------------------------------------------------------
local schema = {}
FV.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v)
    s[name] = v
    if not FV.active then return end
    if name == "flightTimer" or name == "flightScale" then
      if s.flightTimer and Flight.trip then PUI.Ticker:Register("forever.flight", 0.2, Flight.Paint, OWNER) else PUI.Ticker:Unregister("forever.flight") end
      Flight.Paint()
    else Pet.Refresh() end
  end
  schema["forever." .. name] = def
end
key("flightTimer", { type = "toggle", default = true, mode = "simple", label = "Flight timer",
  tooltip = "A countdown bar while you fly. The first flight on a route is timed and remembered." })
key("flightScale", { type = "range", default = 1, min = 0.6, max = 1.8, step = 0.05, label = "Flight timer size", tooltip = "Scale of the flight bar." })
key("petHappiness", { type = "toggle", default = true, mode = "simple", label = "Pet happiness badge",
  tooltip = "Happy, Content or Unhappy, with the loyalty rate, while you have a pet out." })
key("petWarn", { type = "toggle", default = false, label = "Chat line when the pet is unhappy", tooltip = "One line each time your pet becomes unhappy." })

local hooked = false
FV.module = PUI:RegisterModule(OWNER, {
  enabledByDefault = true,
  label = "Forever",
  tooltip = "Flight timer and pet happiness for the Forever client.",
  loadCondition = function() return PUI.IS_FOREVER == true end,
  schema = schema,
  onEnable = function(mod)
    FV.active = true
    for k in pairs(schema) do s[k:sub(9)] = Schema:Get(k) end
    if not hooked and rawget(_G, "TakeTaxiNode") then
      hooked = true
      hooksecurefunc("TakeTaxiNode", function(slot) if FV.active then Flight.OnTake(slot) end end)
    end
    mod:RegisterEvent("TAXIMAP_OPENED", Flight.OnMapOpened)
    mod:RegisterEvent("PLAYER_CONTROL_LOST", function() if UnitOnTaxi("player") then Flight.Start() end end)
    mod:RegisterEvent("PLAYER_CONTROL_GAINED", function() if Flight.trip and not UnitOnTaxi("player") then Flight.Land() end end)
    mod:RegisterEvent("UNIT_PET", function(_, _, unit) if unit == "player" then Pet.Refresh() end end)
    Pet.Refresh()
  end,
  onDisable = function()
    FV.active = false
    Flight.trip, Flight.pending = nil, nil
    if Flight.bar then Flight.bar:Hide() end
    Pet.Paint(nil)
  end,
})
