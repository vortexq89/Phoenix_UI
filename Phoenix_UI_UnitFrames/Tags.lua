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
