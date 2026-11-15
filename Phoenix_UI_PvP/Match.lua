local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Match helpers (mockup 18 "leave countdown", "Training Grounds & queues"):
--  * battleground leave countdown: ON at first install, 15 s; cancel, leave
--    now, and it never leaves while you are in combat (waits instead);
--    arenas are never left for you (Solo Shuffle has more rounds);
--  * Solo Shuffle round tracker: round N of 6 from the game's match state,
--    a round clock, and your round record once the game shows it;
--  * Training Grounds: queue buttons and "won today" from the game.
-- One 1 s Ticker entry, only while a countdown or a round clock runs.
local _, ns = ...
local Secret, Ticker = PUI.Secret, PUI.Ticker
local M = { left = nil, round = 0, rounds = 6 }
ns.Match = M
local OWNER = "PvP"

-- Leave countdown ---------------------------------------------------------
-- Step(state, inCombat, s) is the pure rule the Ticker runs each second.
function M.Step(st, inCombat, s)
  if not st.left then return "idle" end
  if st.left > 0 then st.left = st.left - 1 end
  if st.left > 0 then return "counting" end
  if inCombat and s.leaveNotInCombat then return "waiting" end
  return "leave"
end
function M.Leave()
  M.left = nil
  Ticker:Unregister("pvp.leave")
  local fn = rawget(_G, "LeaveBattlefield")
  if fn then fn() end
  if M.onChange then M.onChange() end
end
function M.Cancel()
  M.left = nil
  Ticker:Unregister("pvp.leave")
  if M.onChange then M.onChange() end
end
function M.StartLeave(s)
  if not s.leave or M.left then return false end
  if s.leaveRatedOnly == "unrated" and C_PvP.IsRatedBattleground() then return false end
  M.left = s.leaveSeconds
  Ticker:Register("pvp.leave", 1, function()
    local r = M.Step(M, InCombatLockdown(), s)
    if r == "leave" then M.Leave() elseif M.onChange then M.onChange() end
  end, OWNER)
  if s.leaveSound then PlaySound(SOUNDKIT.READY_CHECK or 8960) end
  if M.onChange then M.onChange() end
  return true
end

-- Solo Shuffle rounds -----------------------------------------------------
local function matchState() return C_PvP.GetActiveMatchState and C_PvP.GetActiveMatchState() end
function M.OnState(s)
  if not (s.shuffleTracker and C_PvP.IsSoloShuffle()) then return end
  local state = matchState()
  local E = Enum.PvPMatchState or {}
  if state == E.Engaged and M.lastState ~= E.Engaged then
    M.round = math.min(M.rounds, M.round + 1)
    M.roundStart = GetTime()
    Ticker:Register("pvp.round", 1, function() if M.onChange then M.onChange() end end, OWNER)
  elseif state == E.PostRound or state == E.Complete then
    Ticker:Unregister("pvp.round")
    M.roundStart = nil
  end
  M.lastState = state
  if M.onChange then M.onChange() end
end
function M.ResetRounds() M.round, M.lastState, M.roundStart = 0, nil, nil; Ticker:Unregister("pvp.round") end
-- Your round record, only once the game shows a plain value.
function M.RoundRecord()
  local sc = C_PvP.GetScoreInfoByPlayerGuid and C_PvP.GetScoreInfoByPlayerGuid(UnitGUID("player"))
  local won = sc and sc.roundsWon
  if won == nil or Secret.IsSecret(won) then return nil end
  return won, math.max(0, M.round - won - ((M.roundStart and 1) or 0))
end
function M.RoundText()
  if M.round == 0 then return nil end
  local t = string.format("Round %d of %d", M.round, M.rounds)
  if M.roundStart then t = t .. string.format("  %d:%02d", math.floor((GetTime() - M.roundStart) / 60), math.floor(GetTime() - M.roundStart) % 60) end
  local w, l = M.RoundRecord()
  if w then t = t .. string.format("  (%d-%d)", w, l) end
  return t
end

-- Training Grounds --------------------------------------------------------
function M.TrainingStatus()
  local enabled = C_PvP.AreTrainingGroundsEnabled and C_PvP.AreTrainingGroundsEnabled()
  local canUse = C_PvP.CanPlayerUseTrainingGroundsUI and C_PvP.CanPlayerUseTrainingGroundsUI()
  return {
    available = enabled ~= false and canUse ~= false,
    bgWon = C_PvP.HasRandomTrainingGroundBGWinToday and C_PvP.HasRandomTrainingGroundBGWinToday() == true,
    arenaWon = C_PvP.HasRandomTrainingGroundArenaWinToday and C_PvP.HasRandomTrainingGroundArenaWinToday() == true,
  }
end
-- Called from a button click (a hardware event), never from a timer.
function M.QueueTraining(kind)
  if InCombatLockdown() then return false end
  if kind == "arena" then C_PvP.JoinRandomTrainingGroundArena() else C_PvP.JoinRandomTrainingGroundBG() end
  return true
end
