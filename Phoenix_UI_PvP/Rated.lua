local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Rated data (plan 5.21 PvP UI row, mockup 18; owner of rated progress per
-- plan 1.O; the Arena post-match card links here for history):
--  * brackets read from the game's personal rated info (rating, season best,
--    weekly record, Solo Shuffle and Blitz rounds);
--  * rating change after each match = after - before snapshot, or the game's
--    own ratingChange once the match is over (scores are secret during play,
--    so nothing is read while a match runs);
--  * Gladiator / Legend / Strategist progress: the game's achievement
--    criteria when the season gives an ID, else Phoenix's own count of wins
--    taken at or above the title rating (thresholds are settings);
--  * conquest and the PvP row of the Great Vault on the same card.
local _, ns = ...
local Secret = PUI.Secret
local R = { history = {} }
ns.Rated = R

R.BRACKETS = {
  { id = "2v2", index = 1, label = "2v2" },
  { id = "3v3", index = 2, label = "3v3" },
  { id = "rbg", index = 4, label = "Rated BG" },
  { id = "shuffle", index = 7, label = "Solo Shuffle", rounds = true },
  { id = "blitz", index = 9, label = "BG Blitz", rounds = true },
}
R.BY_ID = {}
for _, b in ipairs(R.BRACKETS) do R.BY_ID[b.id] = b end
R.TITLES = {
  { id = "gladiator", label = "Gladiator", bracket = "3v3" },
  { id = "legend", label = "Legend", bracket = "shuffle" },
  { id = "strategist", label = "Strategist", bracket = "blitz" },
}
R.CONQUEST = 1602

local function num(v) if v == nil or Secret.IsSecret(v) or type(v) ~= "number" then return nil end return v end

-- Info(bracketId) -> plain table or nil (never compares a secret).
function R.Info(id)
  local b = R.BY_ID[id]
  local fn = rawget(_G, "GetPersonalRatedInfo")
  if not (b and fn) then return nil end
  local rating, best, weeklyBest, sPlayed, sWon, wPlayed, wWon, _, _, _, _, rsPlayed, rsWon, rwPlayed, rwWon = fn(b.index)
  local t = { id = id, rating = num(rating), best = num(best), weeklyBest = num(weeklyBest),
    seasonPlayed = num(sPlayed), seasonWon = num(sWon), weekPlayed = num(wPlayed), weekWon = num(wWon) }
  if b.rounds then
    t.roundsSeason, t.roundsSeasonWon = num(rsPlayed), num(rsWon)
    t.roundsWeek, t.roundsWeekWon = num(rwPlayed), num(rwWon)
  end
  return t
end

function R.Snapshot()
  local out = {}
  for _, b in ipairs(R.BRACKETS) do out[b.id] = R.Info(b.id) end
  return out
end

-- Weekly record across every bracket (rounds count for Shuffle and Blitz).
function R.WeekRecord(snap)
  local won, played = 0, 0
  for _, b in ipairs(R.BRACKETS) do
    local i = snap and snap[b.id]
    if i then
      if b.rounds and i.roundsWeek then won, played = won + (i.roundsWeekWon or 0), played + i.roundsWeek
      else won, played = won + (i.weekWon or 0), played + (i.weekPlayed or 0) end
    end
  end
  return won, played - won, played
end

-- Wins in a bracket (rounds for Shuffle and Blitz), for progress counting.
function R.Wins(info, bracket)
  if not info then return nil end
  if R.BY_ID[bracket] and R.BY_ID[bracket].rounds then return info.roundsSeasonWon end
  return info.seasonWon
end

-- Diff(before, after, bracket) -> { change, wins } from two snapshots.
function R.Diff(before, after, bracket)
  local a, b = before and before[bracket], after and after[bracket]
  if not (a and b and a.rating and b.rating) then return nil end
  local wa, wb = R.Wins(a, bracket), R.Wins(b, bracket)
  return { change = b.rating - a.rating, rating = b.rating, wins = (wa and wb) and math.max(0, wb - wa) or 0, before = a.rating }
end

-- Progress counting: wins only count when you were at or above the title
-- rating before the match (the same rule the titles use).
function R.Count(db, season, diff, bracket, thresholds)
  if not diff then return end
  db.progress = db.progress or {}
  local p = db.progress[season] or {}
  db.progress[season] = p
  for _, t in ipairs(R.TITLES) do
    if t.bracket == bracket and diff.before >= (thresholds[t.id] or 2400) and diff.wins > 0 then
      p[t.id] = (p[t.id] or 0) + diff.wins
    end
  end
end

-- Achievement criteria from the game when an ID is known.
function R.Criteria(achID)
  local nCrit = rawget(_G, "GetAchievementNumCriteria")
  local info = rawget(_G, "GetAchievementCriteriaInfo")
  if not (achID and achID > 0 and nCrit and info) then return nil end
  if (nCrit(achID) or 0) < 1 then return nil end
  local _, _, done, have, need = info(achID, 1)
  have, need = num(have), num(need)
  if not need then return nil end
  return have or 0, need, done == true
end

-- Progress(title, db, season, s) -> have, need, source ("game" or "phoenix").
function R.Progress(id, db, season, s)
  local achID = s["ach_" .. id]
  if id == "gladiator" and (achID or 0) == 0 and C_PvP.GetPVPSeasonRewardAchievementID then achID = C_PvP.GetPVPSeasonRewardAchievementID() end
  local have, need = R.Criteria(num(achID))
  if need then return have, need, "game" end
  local p = db.progress and db.progress[season] or {}
  return p[id] or 0, s["need_" .. id] or 50, "phoenix"
end

function R.Conquest()
  local c = C_CurrencyInfo.GetCurrencyInfo(R.CONQUEST)
  if not c then return nil end
  return num(c.quantity) or 0, num(c.maxQuantity) or 0, num(c.totalEarned)
end

-- Great Vault PvP row: slots unlocked of 3 and the next threshold.
function R.Vault()
  if not (C_WeeklyRewards.GetActivities and Enum.WeeklyRewardChestThresholdType) then return nil end
  local acts = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.RankedPvP) or {}
  local open, nextAt, progress = 0, nil, 0
  for _, a in ipairs(acts) do
    local pr, th = num(a.progress) or 0, num(a.threshold) or 0
    progress = math.max(progress, pr)
    if th > 0 and pr >= th then open = open + 1 elseif th > 0 and not nextAt then nextAt = th end
  end
  return open, #acts, progress, nextAt
end

-- History ring of rated matches (newest first).
function R.Remember(db, entry, cap)
  db.history = db.history or {}
  table.insert(db.history, 1, entry)
  for i = #db.history, (cap or 50) + 1, -1 do db.history[i] = nil end
end
