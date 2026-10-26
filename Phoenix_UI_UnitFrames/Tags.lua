local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Text tags for the four unit-frame text zones (PUI_V2 5.3). Every renderer
-- hands engine values (possibly secret) straight to the font string: names via
-- SetText, numbers via AbbreviateNumbers or SetFormattedText. Lua never
-- compares, concatenates or does arithmetic on them.
local _, ns = ...
local Secret = PUI.Secret

local Tags = { order = {}, render = {}, events = {} }
ns.Tags = Tags

local function abbreviate(value) return AbbreviateNumbers(value) end
local function pct100() return CurveConstants.ScaleTo100 end

-- events: which unit-event channel refreshes the tag (health, power, name).
local function add(id, channel, fn)
  Tags.order[#Tags.order + 1] = id
  Tags.render[id] = fn
  Tags.events[id] = channel
end

add("none", nil, function(fs) fs:SetText("") end)
add("name", "name", function(fs, unit) fs:SetText(UnitName(unit)) end)
add("name:target", "name", function(fs, unit)
  local target = unit .. "target"
  local exists = UnitExists(target)
  if not Secret.IsSecret(exists) and exists then
    fs:SetFormattedText("%s > %s", UnitName(unit), UnitName(target))
  else
    fs:SetText(UnitName(unit))
  end
end)
add("level", "name", function(fs, unit)
  local level = UnitEffectiveLevel(unit)
  if not Secret.IsSecret(level) and level < 1 then fs:SetText("??") return end
  fs:SetFormattedText("%d", level)
end)
add("level:name", "name", function(fs, unit)
  local level = UnitEffectiveLevel(unit)
  if not Secret.IsSecret(level) and level < 1 then fs:SetFormattedText("?? %s", UnitName(unit)) return end
  fs:SetFormattedText("%d %s", level, UnitName(unit))
end)
add("classification", "name", function(fs, unit)
  local c = UnitClassification(unit)
  if Secret.IsSecret(c) or c == "normal" or c == "minus" or c == "trivial" then fs:SetText("") return end
  fs:SetText(c == "worldboss" and "Boss" or c == "rareelite" and "Rare Elite" or c == "rare" and "Rare" or "Elite")
end)
add("health:percent", "health", function(fs, unit)
  fs:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, pct100()))
end)
add("health:current", "health", function(fs, unit) fs:SetText(abbreviate(UnitHealth(unit))) end)
add("health:current-max", "health", function(fs, unit)
  fs:SetFormattedText("%s / %s", abbreviate(UnitHealth(unit)), abbreviate(UnitHealthMax(unit)))
end)
add("health:current-percent", "health", function(fs, unit)
  fs:SetFormattedText("%s | %.0f%%", abbreviate(UnitHealth(unit)), UnitHealthPercent(unit, true, pct100()))
end)
add("health:missing", "health", function(fs, unit) fs:SetText(abbreviate(UnitHealthMissing(unit, true))) end)
add("health:max", "health", function(fs, unit) fs:SetText(abbreviate(UnitHealthMax(unit))) end)
add("power:current", "power", function(fs, unit) fs:SetText(abbreviate(UnitPower(unit))) end)
add("power:percent", "power", function(fs, unit)
  fs:SetFormattedText("%.0f%%", UnitPowerPercent(unit, nil, false, pct100()))
end)
add("power:current-max", "power", function(fs, unit)
  fs:SetFormattedText("%s / %s", abbreviate(UnitPower(unit)), abbreviate(UnitPowerMax(unit)))
end)
add("status", "health", function(fs, unit)
  local offline = UnitIsConnected(unit)
  local dead = UnitIsDeadOrGhost(unit)
  if Secret.IsSecret(offline) or Secret.IsSecret(dead) then fs:SetText("") return end
  fs:SetText((not offline) and "Offline" or dead and "Dead" or "")
end)

add("name:level", "name", function(fs, unit)
  local level = UnitEffectiveLevel(unit)
  if not Secret.IsSecret(level) and level < 1 then fs:SetFormattedText("%s ??", UnitName(unit)) return end
  fs:SetFormattedText("%s %d", UnitName(unit), level)
end)
add("class", "name", function(fs, unit) fs:SetText((UnitClass(unit))) end)
add("race", "name", function(fs, unit) fs:SetText((UnitRace(unit))) end)
add("level:difficulty", "name", function(fs, unit)
  local level = UnitEffectiveLevel(unit)
  if Secret.IsSecret(level) then fs:SetFormattedText("%d", level) return end
  if level < 1 then fs:SetText("|cffff2020??|r") return end
  local c = GetCreatureDifficultyColor(level)
  fs:SetFormattedText("|cff%02x%02x%02x%d|r", c.r * 255, c.g * 255, c.b * 255, level)
end)
add("classification:short", "name", function(fs, unit)
  local c = UnitClassification(unit)
  if Secret.IsSecret(c) then fs:SetText("") return end
  fs:SetText(c == "worldboss" and "B" or c == "rareelite" and "R+" or c == "rare" and "R" or c == "elite" and "+" or "")
end)
add("health:percent-decimal", "health", function(fs, unit)
  fs:SetFormattedText("%.1f%%", UnitHealthPercent(unit, true, pct100()))
end)
add("health:current-max-percent", "health", function(fs, unit)
  fs:SetFormattedText("%s / %s | %.0f%%", abbreviate(UnitHealth(unit)), abbreviate(UnitHealthMax(unit)),
    UnitHealthPercent(unit, true, pct100()))
end)
add("health:deficit", "health", function(fs, unit) fs:SetFormattedText("-%s", abbreviate(UnitHealthMissing(unit, true))) end)
add("absorb", "health", function(fs, unit) fs:SetText(abbreviate(UnitGetTotalAbsorbs(unit))) end)
add("status:health", "health", function(fs, unit)
  local connected = UnitIsConnected(unit)
  local dead = UnitIsDeadOrGhost(unit)
  if not Secret.IsSecret(connected) and not connected then fs:SetText("Offline") return end
  if not Secret.IsSecret(dead) and dead then fs:SetText("Dead") return end
  fs:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, pct100()))
end)
add("power:max", "power", function(fs, unit) fs:SetText(abbreviate(UnitPowerMax(unit))) end)
-- Smart power: percent for mana users, the current value for rage/energy/etc.
add("power:smart", "power", function(fs, unit)
  local _, token = UnitPowerType(unit)
  if not Secret.IsSecret(token) and token == "MANA" then
    fs:SetFormattedText("%.0f%%", UnitPowerPercent(unit, nil, false, pct100()))
  else
    fs:SetText(abbreviate(UnitPower(unit)))
  end
end)

-- Human labels for the token chips in options (no code needed, plan 5.1).
Tags.LABELS = {
  none = "Nothing", name = "Name", ["name:target"] = "Name > target", level = "Level", ["level:name"] = "Level + name",
  ["name:level"] = "Name + level", classification = "Elite / rare", ["classification:short"] = "Elite mark (+, R, B)",
  ["health:percent"] = "Health %", ["health:current"] = "Health", ["health:current-max"] = "Health / max",
  ["health:current-percent"] = "Health | %", ["health:missing"] = "Missing health", ["health:max"] = "Max health",
  ["power:current"] = "Power", ["power:percent"] = "Power %", ["power:current-max"] = "Power / max", status = "Dead / offline",
  class = "Class", race = "Race", ["level:difficulty"] = "Level (difficulty colour)", ["health:percent-decimal"] = "Health % (0.1)",
  ["health:current-max-percent"] = "Health / max | %", ["health:deficit"] = "Health deficit (-)", absorb = "Absorb amount",
  ["status:health"] = "Health % or dead/offline", ["power:max"] = "Max power", ["power:smart"] = "Smart power (mana %)",
}

function Tags.Render(fs, id, unit)
  local fn = Tags.render[id] or Tags.render.none
  fn(fs, unit)
end

-- Channels the given tags need (so text refreshes only on those events).
function Tags.Channels(ids, out)
  for i = 1, #ids do
    local ch = Tags.events[ids[i]]
    if ch then out[ch] = true end
  end
  return out
end
