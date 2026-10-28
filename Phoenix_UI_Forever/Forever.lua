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
--  * Fishing helper (opt-in, off by default): cast bar, catch count, louder splash.
--  * Swing timer (opt-in, off by default): see the Swing section below; the
--    only combat-log reader in Phoenix UI (approved guardrail exception).
-- Threat is Embers' Threat window.
local _, ns = ...
local Schema = PUI.Schema
local OWNER = "Forever"
local FV = { active = false }
ns.Forever = FV
PUI.Forever = FV
local s = { flightTimer = true, flightScale = 1, petHappiness = true, petWarn = false, swingTimer = false, swingScale = 1 }
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

-- Swing timer (opt-in, off by default) -------------------------------------------------------------
-- APPROVED GUARDRAIL EXCEPTION (deprecated: COMBAT_LOG_EVENT_UNFILTERED and
-- CombatLogGetCurrentEventInfo), 2026-10-28, approver VortexQ8 (t96u). Scope:
--  * Forever client only: Swing.Wanted() requires PUI.IS_FOREVER, where the
--    combat log is still open to addons. Retail never registers the event.
--  * Opt-in: the event is registered only while "Swing timer" is on (default
--    off) and unregistered the moment it, the module or the client gate goes off.
--  * Reads only the player's own SWING_DAMAGE / SWING_MISSED lines; a value
--    that is secret is never compared (it is dropped).
--  * The bar moves from a Ticker job that exists only while a swing is running.
-- See docs/GUARDRAIL_EXCEPTIONS.md.
local Swing = {}
FV.Swing = Swing
Swing.EVENTS = { SWING_DAMAGE = true, SWING_MISSED = true }
-- guardrails-allow: deprecated 2026-10-28 approver=VortexQ8 reason=Forever-only-opt-in-swing-timer-(t96u,docs/GUARDRAIL_EXCEPTIONS.md)
Swing.EVENT = "COMBAT_LOG_EVENT_UNFILTERED"
function Swing.Wanted() return PUI.IS_FOREVER == true and FV.active == true and s.swingTimer == true end
local function plain(v) return v ~= nil and not PUI.Secret.IsSecret(v) end
function Swing.Speed()
  local main = UnitAttackSpeed and UnitAttackSpeed("player")
  if type(main) ~= "number" or not plain(main) or main <= 0 then return nil end
  return main
end
function Swing.Read()
  -- guardrails-allow: deprecated 2026-10-28 approver=VortexQ8 reason=Forever-only-opt-in-swing-timer-(t96u,docs/GUARDRAIL_EXCEPTIONS.md)
  local reader = rawget(_G, "CombatLogGetCurrentEventInfo")
  if not reader then return nil end
  local _, sub, _, src = reader()
  return sub, src
end
-- One combat-log line: a player swing restarts the timer. Returns true when it did.
function Swing.OnLog(sub, src, now)
  if not Swing.Wanted() or not plain(sub) or not plain(src) then return false end
  if not Swing.EVENTS[sub] or src ~= UnitGUID("player") then return false end
  Swing.t0, Swing.dur = now, Swing.Speed() or 2
  PUI.Ticker:Register("forever.swing", 0.05, Swing.Paint, OWNER)
  Swing.Paint()
  return true
end
function Swing.OnEvent() local sub, src = Swing.Read(); Swing.OnLog(sub, src, GetTime()) end
function Swing.Text(t0, dur, now)
  local left = math.max(0, t0 + dur - now)
  return string.format("Swing  %.1f", left), math.min(1, math.max(0, (now - t0) / dur))
end
PUI.Layout:RegisterElement("forever.swing", { label = "Swing timer", owner = OWNER, size = { 200, 14 }, default = { point = "CENTER", x = 0, y = -180 } })
function Swing.Build()
  local b = PUI:CreateFrame("StatusBar", "PhoenixUIForeverSwing", UIParent, nil, OWNER)
  b:SetSize(200, 14)
  PUI.Layout:Place(b, "forever.swing")
  b:SetStatusBarTexture(PUI.Bars and PUI.Bars:TexturePath() or PUI.Media:Texture("flat"))
  b:SetMinMaxValues(0, 1)
  local r, g, bl = PUI.Theme:Color("accent")
  b:SetStatusBarColor(r or 1, g or 0.48, bl or 0.1, 0.9)
  PUI.Theme:Backdrop(b, "surface.0")
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFontObject(PUI.Media:FontObject("small"))
  b.text:SetPoint("CENTER")
  Swing.bar = b
  return b
end
function Swing.Stop()
  PUI.Ticker:Unregister("forever.swing")
  Swing.t0 = nil
  if Swing.bar then Swing.bar:Hide() end
end
function Swing.Paint()
  if not (Swing.t0 and s.swingTimer) then return Swing.Stop() end
  local now = GetTime()
  if now > Swing.t0 + Swing.dur + 0.5 then return Swing.Stop() end -- idle: the job goes away
  local b = Swing.bar or Swing.Build()
  b:SetScale(s.swingScale or 1)
  local text, frac = Swing.Text(Swing.t0, Swing.dur, now)
  b.text:SetText(text)
  b:SetValue(frac)
  b:Show()
end
-- Registers or drops the combat-log event to match the setting (live, no reload).
function Swing.Refresh()
  local mod = FV.module
  if not mod then return end
  if Swing.Wanted() then
    if not Swing.listening then
      Swing.listening = true
      mod:RegisterEvent(Swing.EVENT, Swing.OnEvent)
    end
  else
    if Swing.listening then
      Swing.listening = false
      mod:UnregisterEvent(Swing.EVENT)
    end
    Swing.Stop()
  end
end

-- Fishing helper (opt-in, off by default) ----------------------------------------------------------
-- While you channel Fishing: a bar with the time left on the cast (Ticker job
-- only while channelling), a catch counter for the session (LOOT_OPENED with
-- IsFishingLoot), and an optional louder splash: the sound-effects volume is
-- raised for the cast and put back the moment it ends. The original volume is
-- also kept in PhoenixUIForeverDB so a disconnect mid-cast restores it at login.
local Fish = { catches = 0 }
FV.Fish = Fish
Fish.SPELLS = { [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true, [88868] = true, [131474] = true }
function Fish.IsFishing(spellID) return type(spellID) == "number" and not PUI.Secret.IsSecret(spellID) and Fish.SPELLS[spellID] == true end
function Fish.Text(left, catches)
  return string.format("Fishing  %.1f   catches %d", math.max(0, left), catches or 0)
end
PUI.Layout:RegisterElement("forever.fish", { label = "Fishing helper", owner = OWNER, size = { 220, 16 }, default = { point = "CENTER", x = 0, y = -210 } })
function Fish.Build()
  local b = PUI:CreateFrame("StatusBar", "PhoenixUIForeverFish", UIParent, nil, OWNER)
  b:SetSize(220, 16)
  PUI.Layout:Place(b, "forever.fish")
  b:SetStatusBarTexture(PUI.Bars and PUI.Bars:TexturePath() or PUI.Media:Texture("flat"))
  b:SetMinMaxValues(0, 1)
  local r, g, bl = PUI.Theme:Color("accent")
  b:SetStatusBarColor(r or 1, g or 0.48, bl or 0.1, 0.9)
  PUI.Theme:Backdrop(b, "surface.0")
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFontObject(PUI.Media:FontObject("small"))
  b.text:SetPoint("CENTER")
  Fish.bar = b
  return b
end
function Fish.Boost(on)
  local db = FV.DB()
  if on and s.fishLoud then
    if db.fishVolume == nil then
      db.fishVolume = C_CVar.GetCVar("Sound_SFXVolume")
      C_CVar.SetCVar("Sound_SFXVolume", "1")
    end
  elseif db.fishVolume ~= nil then
    C_CVar.SetCVar("Sound_SFXVolume", db.fishVolume)
    db.fishVolume = nil
  end
end
function Fish.Stop()
  PUI.Ticker:Unregister("forever.fish")
  Fish.t0, Fish.t1 = nil, nil
  Fish.Boost(false)
  if Fish.bar then Fish.bar:Hide() end
end
function Fish.Paint()
  if not (Fish.t1 and s.fishHelper and FV.active) then return Fish.Stop() end
  local now = GetTime()
  if now > Fish.t1 + 0.5 then return Fish.Stop() end
  local b = Fish.bar or Fish.Build()
  b:SetScale(s.fishScale or 1)
  b.text:SetText(Fish.Text(Fish.t1 - now, Fish.catches))
  b:SetValue(math.min(1, math.max(0, (now - Fish.t0) / math.max(0.1, Fish.t1 - Fish.t0))))
  b:Show()
end
-- Channel start: (t0, t1) in seconds from UnitChannelInfo, or a 21 s cast.
function Fish.Start(spellID, now)
  if not (FV.active and s.fishHelper and Fish.IsFishing(spellID)) then return false end
  local _, _, _, startMS, endMS = UnitChannelInfo("player")
  if type(startMS) == "number" and type(endMS) == "number" and not PUI.Secret.IsSecret(endMS) and endMS > startMS then
    Fish.t0, Fish.t1 = startMS / 1000, endMS / 1000
  else
    Fish.t0, Fish.t1 = now, now + 21
  end
  Fish.Boost(true)
  PUI.Ticker:Register("forever.fish", 0.1, Fish.Paint, OWNER)
  Fish.Paint()
  return true
end
function Fish.OnLoot()
  if FV.active and s.fishHelper and rawget(_G, "IsFishingLoot") and IsFishingLoot() then Fish.catches = Fish.catches + 1 end
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
    elseif name == "fishHelper" or name == "fishScale" or name == "fishLoud" then
      if not s.fishHelper or not s.fishLoud then Fish.Boost(false) end
      if Fish.t1 then Fish.Paint() end
    elseif name == "swingTimer" or name == "swingScale" then
      Swing.Refresh()
      if Swing.t0 then Swing.Paint() end
    else Pet.Refresh() end
  end
  schema["forever." .. name] = def
end
key("flightTimer", { type = "toggle", default = true, mode = "simple", label = "Flight timer",
  tooltip = "A countdown bar while you fly. The first flight on a route is timed and remembered." })
key("flightScale", { type = "range", default = 1, min = 0.6, max = 1.8, step = 0.05, label = "Flight timer size", tooltip = "Scale of the flight bar." })
key("petHappiness", { type = "toggle", default = true, mode = "simple", label = "Pet happiness badge",
  tooltip = "Happy, Content or Unhappy, with the loyalty rate, while you have a pet out." })
key("swingTimer", { type = "toggle", default = false, mode = "simple", label = "Swing timer",
  tooltip = "A bar that counts down to your next melee swing. Off by default; Forever only. It reads your own swings from the combat log." })
key("swingScale", { type = "range", default = 1, min = 0.6, max = 1.8, step = 0.05, label = "Swing timer size", tooltip = "Scale of the swing bar." })
key("fishHelper", { type = "toggle", default = false, mode = "simple", label = "Fishing helper",
  tooltip = "While you fish: a bar with the time left on the cast and a catch counter for this session. Off by default." })
key("fishLoud", { type = "toggle", default = false, label = "Louder splash while fishing",
  tooltip = "Raises the sound-effects volume during the cast so the bobber splash is easy to hear, and puts it back when the cast ends." })
key("fishScale", { type = "range", default = 1, min = 0.6, max = 1.8, step = 0.05, label = "Fishing bar size", tooltip = "Scale of the fishing bar." })
key("petWarn", { type = "toggle", default = false, label = "Chat line when the pet is unhappy", tooltip = "One line each time your pet becomes unhappy." })

local hooked = false
FV.module = PUI:RegisterModule(OWNER, {
  enabledByDefault = true,
  label = "Forever",
  tooltip = "Flight timer, pet happiness, an optional swing timer and an optional fishing helper for the Forever client.",
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
    mod:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, _, unit, _, spellID) if unit == "player" then Fish.Start(spellID, GetTime()) end end)
    mod:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(_, _, unit) if unit == "player" and Fish.t1 then Fish.Stop() end end)
    mod:RegisterEvent("LOOT_OPENED", Fish.OnLoot)
    Fish.Boost(false) -- a volume left raised by a disconnect mid-cast comes back
    Pet.Refresh()
    Swing.Refresh()
  end,
  onDisable = function()
    FV.active = false
    Swing.Refresh()
    Fish.Stop()
    Flight.trip, Flight.pending = nil, nil
    if Flight.bar then Flight.bar:Hide() end
    Pet.Paint(nil)
  end,
})
