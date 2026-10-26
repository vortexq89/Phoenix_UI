local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Visibility (plan 1.19): the one "where to show" engine every module uses.
-- A rule is plain data (stored in a schema key of the owning module):
--   { mode = "always" | "never" | "when",
--     content = { world = true, party = true, raid = true, arena = true, pvp = true, scenario = true, delve = true },
--     combat = "any" | "in" | "out",
--     group = { solo = true, party = true, raid = true },
--     specs = { [specIndex] = true } (empty = any),
--     hide = { resting = true, vehicle = true, skyriding = true, petBattle = true, mounted = true } }
-- Missing fields mean "any". State is event-driven and coalesced to one
-- evaluation per frame through a self-disarming Ticker entry (G2, G21): no
-- events are registered while nothing is watched.
local Visibility = { watchers = {}, order = {}, state = {}, dirty = false }
PUI.Visibility = Visibility

local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE",
  "PLAYER_UPDATE_RESTING", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_SPECIALIZATION_CHANGED",
  "PLAYER_MOUNT_DISPLAY_CHANGED", "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE", "PLAYER_CAN_GLIDE_CHANGED",
  "PLAYER_IS_GLIDING_CHANGED" }
-- PLAYER_REGEN_ENABLED is CombatQueue's (guardrail "regen"): leaving combat is
-- observed through a CombatQueue entry armed when combat starts.
Visibility.EVENTS = EVENTS

Visibility.CONTENT = { "world", "party", "raid", "scenario", "delve", "arena", "pvp" }
Visibility.CONTENT_LABELS = { world = "Open world", party = "Dungeons & M+", raid = "Raids", scenario = "Scenarios",
  delve = "Delves", arena = "Arenas", pvp = "Battlegrounds" }
Visibility.HIDE = { "resting", "vehicle", "skyriding", "petBattle", "mounted" }
Visibility.HIDE_LABELS = { resting = "While resting", vehicle = "In a vehicle", skyriding = "While skyriding",
  petBattle = "In a pet battle", mounted = "While mounted" }

local frame = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
local petBattle = false

-- Reads the world into a plain table. Overridable by tests (Visibility.Probe).
function Visibility.Probe()
  local _, instanceType, difficultyID = GetInstanceInfo()
  local content = "world"
  if instanceType == "party" then content = "party"
  elseif instanceType == "raid" then content = "raid"
  elseif instanceType == "arena" then content = "arena"
  elseif instanceType == "pvp" then content = "pvp"
  elseif instanceType == "scenario" then content = (difficultyID == 208) and "delve" or "scenario" end
  local n = GetNumGroupMembers() or 0
  local group = "solo"
  if n > 5 then group = "raid" elseif n > 0 then group = "party" end
  local gliding = false
  if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then gliding = C_PlayerInfo.GetGlidingInfo() == true end
  return {
    content = content, difficulty = difficultyID or 0, group = group,
    combat = InCombatLockdown() == true,
    spec = C_SpecializationInfo.GetSpecialization() or 0,
    resting = IsResting and IsResting() == true or false,
    vehicle = UnitHasVehicleUI and UnitHasVehicleUI("player") == true or false,
    mounted = IsMounted and IsMounted() == true or false,
    skyriding = gliding,
    petBattle = petBattle,
  }
end

-- Pure: does rule allow showing in state? Returns shown, reason (for "why hidden").
function Visibility.Test(rule, s)
  if rule == nil or rule.mode == nil or rule.mode == "always" then return true, nil end
  if rule.mode == "never" then return false, "set to never show" end
  if rule.content and next(rule.content) and not rule.content[s.content] then
    return false, "not shown in " .. (Visibility.CONTENT_LABELS[s.content] or s.content)
  end
  if rule.combat == "in" and not s.combat then return false, "only shown in combat" end
  if rule.combat == "out" and s.combat then return false, "hidden in combat" end
  if rule.group and next(rule.group) and not rule.group[s.group] then return false, "not shown when " .. s.group end
  if rule.specs and next(rule.specs) and not rule.specs[s.spec] then return false, "not shown for this specialization" end
  if rule.hide then
    for _, h in ipairs(Visibility.HIDE) do
      if rule.hide[h] and s[h] then return false, "hidden " .. Visibility.HIDE_LABELS[h]:lower() end
    end
  end
  return true, nil
end

local function evaluate()
  Visibility.dirty = false
  PUI.Ticker:Unregister("visibility.flush")
  local s = Visibility.Probe()
  Visibility.state = s
  for i = 1, #Visibility.order do
    local id = Visibility.order[i]
    local w = Visibility.watchers[id]
    if w then
      local shown, why = Visibility.Test(w.rule, s)
      w.why = why
      if shown ~= w.shown then
        w.shown = shown
        securecallfunction(w.fn, shown, why)
      end
    end
  end
end
Visibility.Evaluate = evaluate

function Visibility:Invalidate()
  if self.dirty then return end
  self.dirty = true
  PUI.Ticker:Register("visibility.flush", 0, evaluate, "Core") -- one frame, then it disarms itself
end

local function armRegen()
  PUI.CombatQueue.Defer("visibility.regen", function() Visibility:Invalidate() end)
end

frame:SetScript("OnEvent", function(_, event)
  if event == "PET_BATTLE_OPENING_START" then petBattle = true
  elseif event == "PET_BATTLE_CLOSE" then petBattle = false end
  if event == "PLAYER_REGEN_DISABLED" then
    -- InCombatLockdown is already true here; queue the "left combat" refresh.
    Visibility:Invalidate()
    return armRegen()
  end
  Visibility:Invalidate()
end)

local function arm(on)
  for i = 1, #EVENTS do
    if on then frame:RegisterEvent(EVENTS[i]) else frame:UnregisterEvent(EVENTS[i]) end
  end
  Visibility.armed = on
end

-- Watch(id, rule, fn): fn(shown, why) runs now and on every change.
function Visibility:Watch(id, rule, fn)
  assert(type(id) == "string" and id ~= "", "Visibility:Watch needs a stable id")
  assert(type(fn) == "function", "Visibility:Watch needs a callback")
  if not self.watchers[id] then self.order[#self.order + 1] = id end
  self.watchers[id] = { rule = rule, fn = fn }
  if not self.armed then arm(true) end
  local s = self.Probe()
  self.state = s
  local shown, why = self.Test(rule, s)
  self.watchers[id].shown, self.watchers[id].why = shown, why
  fn(shown, why)
end

-- New rule from a settings change: applied live.
function Visibility:SetRule(id, rule)
  local w = self.watchers[id]
  if not w then return false end
  w.rule = rule
  w.shown = nil
  self:Invalidate()
  return true
end

function Visibility:Unwatch(id)
  if not self.watchers[id] then return end
  self.watchers[id] = nil
  for i = #self.order, 1, -1 do if self.order[i] == id then table.remove(self.order, i) end end
  if #self.order == 0 then arm(false); PUI.Ticker:Unregister("visibility.flush"); self.dirty = false end
end

-- "Why hidden right now" for the options readout.
function Visibility:Why(id)
  local w = self.watchers[id]
  if not w then return nil end
  return w.shown, w.why
end

function Visibility:Count() return #self.order end
