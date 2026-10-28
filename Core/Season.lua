local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Season (plan 1.28): current season data filled from the live API, so no
-- module hard-codes dungeon, affix or season tables. Also the single source of
-- M+ score colours (1.O): Blizzard's rarity colours, Raider.IO's when that
-- addon is loaded, or the user's own two-colour gradient.
local Season = { id = 0, dungeons = {}, byMap = {}, affixes = {}, ready = false }
PUI.Season = Season
local Schema = PUI.Schema

-- Refresh(): rebuilds from the API; safe to call any time (cheap, pure reads).
function Season:Refresh()
  local id = C_MythicPlus.GetCurrentSeason() or 0
  local list, byMap = {}, {}
  local maps = C_ChallengeMode.GetMapTable() or {}
  for i = 1, #maps do
    local mapID = maps[i]
    local name, _, timeLimit, texture, _, uiMapID = C_ChallengeMode.GetMapUIInfo(mapID)
    if name then
      local d = { id = mapID, name = name, timeLimit = timeLimit or 0, texture = texture, uiMapID = uiMapID }
      list[#list + 1] = d
      byMap[mapID] = d
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end) -- stable display order (G24)
  local affixes = {}
  local cur = C_MythicPlus.GetCurrentAffixes() or {}
  for i = 1, #cur do
    local a = cur[i]
    affixes[i] = type(a) == "table" and a.id or a
  end
  self.id, self.dungeons, self.byMap, self.affixes = id, list, byMap, affixes
  self.ready = id > 0 and #list > 0
  PUI.Kernel:Fire("SEASON_CHANGED", id)
  return self.ready
end

function Season:Dungeon(mapID) return self.byMap[mapID] end

-- Pace (seconds) a run must beat for +1/+2/+3 (Blizzard's 100/80/60 % rule).
function Season:Thresholds(mapID)
  local d = self.byMap[mapID]
  if not d or d.timeLimit <= 0 then return nil end
  return { d.timeLimit, d.timeLimit * 0.8, d.timeLimit * 0.6 }
end

-- Enemy forces one unit is worth in the running Mythic+ (plan 1.O "Enemy
-- forces %": Ascent owns forces data; this is the minimal shared provider
-- the Nameplates text slot and tooltips read). Returns the game's own
-- percent text, possibly secret: callers hand it straight to a FontString.
-- When the Ascent child is loaded it owns this data (its settings can turn it
-- off or leave it to MythicDungeonTools); otherwise this minimal read is used.
function Season:UnitForces(unit)
  local AS = PUI.Ascent
  if AS and AS.UnitForces then return AS.UnitForces(unit) end
  if not C_ChallengeMode.IsChallengeModeActive() then return nil end
  local _, _, text = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
  return text
end

------------------------------------------------------------------------------
-- Score colours. ScoreColor(score) -> r, g, b. Score is a plain number from
-- the summary APIs; a secret score is never compared: it gets the neutral colour.
Season.SOURCES = { "blizzard", "raiderio", "custom" }
Season.SOURCE_LABELS = { blizzard = "Blizzard colours", raiderio = "Raider.IO colours (when installed)", custom = "My own gradient" }
Season.source = "blizzard"
Season.custom = { low = { r = 0.62, g = 0.62, b = 0.62 }, high = { r = 1, g = 0.5, b = 0 }, max = 3500 }

local function lerp(a, b, t) return a + (b - a) * t end

function Season:ScoreColor(score)
  if PUI.Secret.IsSecret(score) or type(score) ~= "number" then return 1, 1, 1 end
  local src = self.source
  if src == "raiderio" then
    local rio = _G.RaiderIO
    if type(rio) == "table" and type(rio.GetScoreColor) == "function" then
      local r, g, b = rio.GetScoreColor(score)
      if type(r) == "number" then return r, g, b end
    end
    src = "blizzard" -- fallback when Raider.IO is absent
  end
  if src == "blizzard" then
    local c = C_ChallengeMode.GetDungeonScoreRarityColor(score)
    if c then return c.r, c.g, c.b end
    src = "custom"
  end
  local cu = self.custom
  local t = math.max(0, math.min(1, score / (cu.max > 0 and cu.max or 1)))
  return lerp(cu.low.r, cu.high.r, t), lerp(cu.low.g, cu.high.g, t), lerp(cu.low.b, cu.high.b, t)
end

-- "|cffRRGGBB2,845|r" for tooltips and lists.
function Season:ColoredScore(score)
  if PUI.Secret.IsSecret(score) or type(score) ~= "number" then return "" end
  local r, g, b = self:ScoreColor(score)
  return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, PUI.Format.Number(score, "full"))
end

local function changed() PUI.Kernel:Fire("SEASON_COLORS_CHANGED") end
Schema:Register("season.scoreColors", {
  type = "select", default = "blizzard", choices = Season.SOURCES, labels = Season.SOURCE_LABELS,
  label = "M+ score colours", tooltip = "Where Mythic+ score colours come from in tooltips, Group Finder and data bars.",
  mode = "simple", owner = "Core", searchTags = { "mythic", "score", "rating", "raider.io", "colour" },
  apply = function(v) Season.source = v; changed() end,
})
Schema:Register("season.customLow", {
  type = "color", default = { r = 0.62, g = 0.62, b = 0.62 },
  label = "Gradient start colour", tooltip = "Colour for a score of 0 when using your own gradient.",
  mode = "advanced", owner = "Core", searchTags = { "mythic", "score", "gradient" },
  apply = function(v) Season.custom.low = v; changed() end,
})
Schema:Register("season.customHigh", {
  type = "color", default = { r = 1, g = 0.5, b = 0 },
  label = "Gradient end colour", tooltip = "Colour for the top score when using your own gradient.",
  mode = "advanced", owner = "Core", searchTags = { "mythic", "score", "gradient" },
  apply = function(v) Season.custom.high = v; changed() end,
})
Schema:Register("season.customMax", {
  type = "range", default = 3500, min = 500, max = 6000, step = 50,
  label = "Gradient top score", tooltip = "Score that gets the end colour; higher scores keep it.",
  mode = "advanced", owner = "Core", searchTags = { "mythic", "score", "gradient" },
  apply = function(v) Season.custom.max = v; changed() end,
})

-- Data arrives after login and changes on a new season: refresh then.
local f = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
f:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
f:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
f:SetScript("OnEvent", function() Season:Refresh() end)
PUI.Kernel:On("LOGIN", function()
  C_MythicPlus.RequestMapInfo()
  C_MythicPlus.RequestCurrentAffixes()
  Season:Refresh()
end)
