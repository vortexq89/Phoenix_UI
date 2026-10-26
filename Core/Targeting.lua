local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Targeting (plan 1.O "Party<->arena targeting dots", mockups 03/04): the one
-- service that knows which enemy is targeting which friendly unit. Arena
-- frames and party/raid frames both draw from it, so they always agree.
-- Enemy sources (each a setting of the consumer, not of this service):
--   "arena"  arena1..arena5 while in an arena (the default)
--   "boss"   boss1..boss5 during an encounter (PvE "who is the boss on")
-- Nothing is compared: UnitIsUnit(enemy .. "target", unit) may be secret, so
-- the answer goes straight to a texture's SetAlphaFromBoolean.
--   Targeting:Subscribe(id, fn)    fn() runs (coalesced, one per frame) when
--                                  any enemy changes target or the roster moves
--   Targeting:Unsubscribe(id)
--   Targeting:Enemies(sources)     -> ordered list of enemy unit tokens
--   Targeting:Paint(dots, unit, sources)  dot[i] shows when enemy i targets unit
--   Targeting.COLORS[i]            default per-enemy dot colours (arena 1..5)
-- Zero cost while nobody subscribes: no events, no Ticker entry (G2, G21).
local Targeting = { subs = {}, order = {}, armed = false, dirty = false }
PUI.Targeting = Targeting

local ARENA = { "arena1", "arena2", "arena3", "arena4", "arena5" }
local BOSS = { "boss1", "boss2", "boss3", "boss4", "boss5" }
Targeting.ARENA, Targeting.BOSS = ARENA, BOSS
Targeting.COLORS = {
  { r = 1, g = 0.33, b = 0.41 }, { r = 0.35, g = 0.71, b = 1 }, { r = 1, g = 0.76, b = 0.29 },
  { r = 0.69, g = 0.49, b = 1 }, { r = 0.24, g = 0.86, b = 0.59 },
}
Targeting.EVENTS = { "UNIT_TARGET", "ARENA_OPPONENT_UPDATE", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "GROUP_ROSTER_UPDATE",
  "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED" }

local frame
local function flush()
  PUI.Ticker:Unregister("targeting.flush")
  Targeting.dirty = false
  for _, id in ipairs(Targeting.order) do
    local fn = Targeting.subs[id]
    if fn then securecallfunction(fn) end
  end
end

function Targeting:Invalidate()
  if self.dirty or #self.order == 0 then return end
  self.dirty = true
  PUI.Ticker:Register("targeting.flush", 0, flush, "Core")
end

local RELEVANT = {}
for _, u in ipairs(ARENA) do RELEVANT[u] = true end
for _, u in ipairs(BOSS) do RELEVANT[u] = true end

local function onEvent(_, event, unit)
  if event == "UNIT_TARGET" and not (type(unit) == "string" and RELEVANT[unit]) then return end
  Targeting:Invalidate()
end

local function arm(on)
  if on == Targeting.armed then return end
  frame = frame or PUI:CreateFrame("Frame", nil, nil, nil, "Core")
  frame:SetScript("OnEvent", onEvent)
  for _, ev in ipairs(Targeting.EVENTS) do
    if on then frame:RegisterEvent(ev) else frame:UnregisterEvent(ev) end
  end
  Targeting.armed = on
end

function Targeting:Subscribe(id, fn)
  assert(type(id) == "string" and type(fn) == "function", "Targeting:Subscribe(id, fn)")
  if not self.subs[id] then self.order[#self.order + 1] = id end
  self.subs[id] = fn
  arm(true)
  self:Invalidate()
end

function Targeting:Unsubscribe(id)
  if not self.subs[id] then return end
  self.subs[id] = nil
  for i = #self.order, 1, -1 do if self.order[i] == id then table.remove(self.order, i) end end
  if #self.order == 0 then
    arm(false)
    PUI.Ticker:Unregister("targeting.flush")
    self.dirty = false
  end
end

function Targeting:Count() return #self.order end

-- Instance type is never secret; arena enemies only count inside an arena.
local function inArena()
  local _, kind = IsInInstance()
  return kind == "arena"
end

-- sources: { arena = true, boss = true } (nil = arena only).
function Targeting:Enemies(sources)
  sources = sources or { arena = true }
  local out = {}
  if sources.arena and inArena() then
    for _, u in ipairs(ARENA) do if UnitExists(u) then out[#out + 1] = u end end
  end
  if sources.boss then
    for _, u in ipairs(BOSS) do if UnitExists(u) then out[#out + 1] = u end end
  end
  return out
end

-- dots: array of textures (or frames). Dot i follows enemy i; spare dots hide.
function Targeting:Paint(dots, unit, sources)
  local enemies = (unit and self:Enemies(sources)) or {}
  for i = 1, #dots do
    local d, enemy = dots[i], enemies[i]
    if enemy then
      d:Show()
      d:SetAlphaFromBoolean(UnitIsUnit(enemy .. "target", unit), 1, 0)
    else
      d:Hide()
    end
  end
  return #enemies
end
