local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.CombatTimer (plan 1.O "Combat / encounter / stage timer"): the one combat
-- and encounter clock. The Pulse page will own its display and settings; until
-- Pulse exists this minimal shared service is what the Embers header, the
-- Ascent run card and the Quest Tracker read, so nothing keeps its own clock.
-- Times come from GetTime() (never secret). While in combat a 0.5 s Ticker
-- job watches for the end of combat (PLAYER_REGEN_ENABLED belongs to the
-- CombatQueue only), so nothing runs out of combat.
--   CombatTimer:Elapsed() -> seconds of the running (or last) fight
--   CombatTimer:Running() -> bool
--   CombatTimer:Kind()    -> "encounter" | "combat" | nil
--   CombatTimer:Text([fmt]) -> "3:42" (fmt "clock" | "tenths")
--   CombatTimer:Encounter() -> { id, name, difficulty, size } | nil
-- Fires Kernel "COMBAT_TIMER" with ("start"|"stop", kind).
local Timer = { started = nil, stopped = nil, kind = nil, encounter = nil, last = nil }
PUI.CombatTimer = Timer
local Ticker = PUI.Ticker
local OWNER = "Core"

local function fire(what) PUI.Kernel:Fire("COMBAT_TIMER", what, Timer.kind) end

function Timer:Running() return self.started ~= nil and self.stopped == nil end
function Timer:Kind() return self.kind end
function Timer:Encounter() return self.encounter end

function Timer:Elapsed()
  if not self.started then return 0 end
  return math.max(0, (self.stopped or GetTime()) - self.started)
end

function Timer.Format(seconds, fmt)
  seconds = math.max(0, seconds or 0)
  local m = math.floor(seconds / 60)
  if fmt == "tenths" then return string.format("%d:%04.1f", m, seconds - m * 60) end
  return string.format("%d:%02d", m, math.floor(seconds) % 60)
end

function Timer:Text(fmt) return Timer.Format(self:Elapsed(), fmt) end

function Timer:Start(kind)
  if self:Running() then
    -- an encounter that starts inside an already running fight takes over the clock
    if kind == "encounter" and self.kind ~= "encounter" then self.kind = kind; self.started = GetTime(); fire("start") end
    return
  end
  self.started, self.stopped, self.kind = GetTime(), nil, kind
  Ticker:Register("timer.watch", 0.5, function() Timer:Watch() end, OWNER)
  fire("start")
end

function Timer:Stop()
  if not self:Running() then return end
  self.stopped = GetTime()
  self.last = { kind = self.kind, seconds = self:Elapsed(), encounter = self.encounter }
  Ticker:Unregister("timer.watch")
  fire("stop")
end

-- Combat end check (only while a fight runs). An encounter ends only on
-- ENCOUNTER_END, so a wipe-and-run-back does not split the boss clock.
function Timer:Watch()
  if self.kind == "encounter" then return end
  if not InCombatLockdown() then self:Stop() end
end

local f = PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")
f:SetScript("OnEvent", function(_, event, id, name, difficulty, size)
  if event == "PLAYER_REGEN_DISABLED" then
    Timer:Start("combat")
  elseif event == "ENCOUNTER_START" then
    Timer.encounter = { id = id, name = name, difficulty = difficulty, size = size }
    Timer:Start("encounter")
  elseif event == "ENCOUNTER_END" then
    if Timer.kind == "encounter" then Timer:Stop() end
    Timer.encounter = nil
  end
end)
