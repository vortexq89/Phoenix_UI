local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Ascent, deferred batch C:
--  * current-pull forces: the enemy forces of every enemy nameplate in combat
--    with your group, added to the forces line ("pull +4.2% -> 63.5%"). Read
--    from C_ScenarioInfo.GetUnitCriteriaProgressValues; any secret value hides
--    the preview for that refresh instead of being compared.
--  * score projection: the dungeon score a timed run of the active (or owned)
--    key would give, against your season best on that dungeon. The constants
--    are a model of the season's formula (AS.SCORE) and are checked in game.
--  * vault planner: what your Mythic+ Great Vault row needs this week (from
--    C_WeeklyRewards activities and C_MythicPlus run history).
local _, ns = ...
local AS = ns.AS or PUI.Ascent
local Schema = PUI.Schema
local Secret = PUI.Secret
local OWNER = "Ascent"

local X = { s = { pull = true, projection = true } }
AS.Extras = X
local s = X.s
local function plain(v) if Secret.IsSecret(v) then return nil end return v end

-- Current pull ----------------------------------------------------------------------------------
X.MAX_PLATES = 40
function X.PullForces()
  local c = AS.Forces()
  local total = c and plain(c.totalQuantity)
  if not (total and total > 0) then return nil end
  local sum, any = 0, false
  for i = 1, X.MAX_PLATES do
    local unit = "nameplate" .. i
    if UnitExists(unit) then
      local fighting = plain(UnitAffectingCombat(unit))
      local enemy = plain(UnitCanAttack("player", unit))
      if fighting == nil or enemy == nil then return nil end
      if fighting and enemy then
        local v = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
        v = plain(v)
        if v == nil then return nil end
        if type(v) == "number" and v > 0 then sum = sum + v; any = true end
      end
    end
  end
  if not any then return { add = 0, after = AS.ForcesPercent(c) or 0 } end
  local now = AS.ForcesPercent(c) or 0
  local add = sum / total * 100
  return { add = add, after = math.min(100, now + add) }
end
function X.PullText(p)
  if not p or p.add <= 0 then return nil end
  return string.format("pull +%.1f%% -> %.1f%%", p.add, p.after)
end

-- Score projection ------------------------------------------------------------------------------
-- Model: base for a timed key, +perLevel each level above 2, a bonus at each
-- affix breakpoint, and up to +timeBonus for finishing early (linear to 40%
-- under the timer). Over time: minus overPenalty, nothing past 40% over.
AS.SCORE = { base = 155, perLevel = 15, breakpoints = { 4, 7, 10, 12 }, breakpointBonus = 15, timeBonus = 15, overPenalty = 15 }
function X.Score(level, fraction)
  local m = AS.SCORE
  if not level or level < 2 then return 0 end
  local score = m.base + (level - 2) * m.perLevel
  for _, b in ipairs(m.breakpoints) do if level >= b then score = score + m.breakpointBonus end end
  fraction = fraction or 1
  if fraction <= 1 then
    score = score + m.timeBonus * math.min(1, (1 - fraction) / 0.4)
  elseif fraction <= 1.4 then
    score = score - m.overPenalty - m.timeBonus * (fraction - 1) / 0.4
  else
    return 0
  end
  return math.floor(score + 0.5)
end
function X.Best(mapID)
  local _, best = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapID)
  best = plain(best)
  return type(best) == "number" and best or 0
end
function X.Projection(mapID, level)
  if not (mapID and level and level > 0) then return nil end
  local timed = X.Score(level, 1)
  local best = X.Best(mapID)
  return { timed = timed, best = best, gain = math.max(0, timed - best) }
end
function X.ProjectionText(p)
  if not p then return nil end
  if p.gain <= 0 then return string.format("score: timed %d, best %d (no gain)", p.timed, p.best) end
  return string.format("score: timed %d (+%d over your best %d)", p.timed, p.gain, p.best)
end

-- Vault planner ---------------------------------------------------------------------------------
function X.VaultPlan()
  local acts = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Activities) or {}
  table.sort(acts, function(a, b) return (a.index or 0) < (b.index or 0) end)
  local runs = C_MythicPlus.GetRunHistory(false, true) or {}
  local levels = {}
  for _, r in ipairs(runs) do levels[#levels + 1] = r.level or 0 end
  table.sort(levels, function(a, b) return a > b end)
  local out = {}
  for i, a in ipairs(acts) do
    local need = a.threshold or 0
    local done = #levels
    local slot = { slot = i, threshold = need, runs = done }
    if done >= need and need > 0 then
      slot.level = levels[need]
      slot.text = string.format("Slot %d: unlocked at +%d", i, slot.level)
    else
      slot.left = need - done
      slot.text = string.format("Slot %d: %d more run%s (%d of %d)", i, slot.left, slot.left == 1 and "" or "s", done, need)
    end
    out[i] = slot
  end
  return out
end

-- Display -------------------------------------------------------------------------------------
local draw = ns.Display and ns.Display.Draw
if draw then
  function ns.Display.Draw()
    draw()
    local f = ns.Display.frame or rawget(ns.Display, "f")
    local run = AS.run
    if not (run and f and rawget(f, "forcesLabel")) then return end
    local parts = { "Enemy forces" }
    if s.pull then local t = X.PullText(X.PullForces()); if t then parts[#parts + 1] = t end end
    if s.projection then local t = X.ProjectionText(X.Projection(run.mapID, run.level)); if t then parts[#parts + 1] = t end end
    f.forcesLabel:SetText(table.concat(parts, "  |  "))
    X.label = f.forcesLabel:GetText()
  end
end

PUI.Slash:Register("vaultplan", function()
  local plan = X.VaultPlan()
  if #plan == 0 then PUI.Slash.Print("No Mythic+ vault row this week.") end
  for _, sl in ipairs(plan) do PUI.Slash.Print(sl.text) end
end, "what your Mythic+ Great Vault row needs this week")

local function key(name, field, def)
  def.owner = OWNER
  def.apply = function(v) s[field] = v; if AS.active and AS.Draw then AS.Draw() end end
  def.searchTags = { "mythic", "forces", "pull", "score", "vault" }
  if AS.schema then AS.schema["ascent." .. name] = def end
  Schema:Register("ascent." .. name, def)
  s[field] = Schema:Get("ascent." .. name)
end
key("pullForces", "pull", { type = "toggle", default = true, label = "Current pull forces",
  tooltip = "Adds the enemy forces of the enemies you are fighting to the forces line.", mode = "simple" })
key("scoreProjection", "projection", { type = "toggle", default = true, label = "Score if timed",
  tooltip = "Shows the dungeon score a timed run of this key would give against your best (an estimate).", mode = "simple" })
