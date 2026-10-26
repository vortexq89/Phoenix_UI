local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Loadouts (PUI_V2 6.5): for each kind of content (open world, dungeon,
-- Mythic+, raid, PvP, delve/scenario) remember a specialization, a saved
-- talent loadout and an equipment set. Zoning in compares what you have with
-- the rule and announces the difference; "equip now" (/pui loadout apply, or
-- automatically when that switch is on) puts it right, always out of combat
-- through the combat queue, one step at a time (spec, then talents, then
-- gear). Off by default; the automatic switch is off by default too.
local _, ns = ...
local Schema, CQ = PUI.Schema, PUI.CombatQueue
local OWNER = "Loadouts"

local LO = { active = false }
ns.LO = LO
PUI.Loadouts = LO
local s = { announce = true, auto = false, sound = false }
LO.settings = s

LO.CONTENT = { "world", "dungeon", "mythicplus", "raid", "pvp", "scenario" }
LO.MYTHIC_KEYSTONE = 8 -- DifficultyUtil.ID.DungeonChallenge (live 12.1.5)

function LO.Content()
  local _, kind, difficulty = GetInstanceInfo()
  if kind == "party" then return difficulty == LO.MYTHIC_KEYSTONE and "mythicplus" or "dungeon" end
  if kind == "raid" then return "raid" end
  if kind == "pvp" or kind == "arena" then return "pvp" end
  if kind == "scenario" then return "scenario" end
  return "world"
end

local function rules() return Schema:Get("loadouts.rules") end
LO.Rules = rules

function LO.Current()
  local index = C_SpecializationInfo.GetSpecialization()
  local specID = index and C_SpecializationInfo.GetSpecializationInfo(index)
  local config = specID and C_ClassTalents.GetLastSelectedSavedConfigID(specID)
  local equipped
  for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
    local _, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(id)
    if isEquipped then equipped = id end
  end
  return { spec = index, specID = specID, config = config, set = equipped }
end

-- Saves what you have now as the rule for a content kind.
function LO.SaveRule(content)
  content = content or LO.Content()
  local cur = LO.Current()
  local all = rules()
  all[content] = { spec = cur.spec, config = cur.config, set = cur.set }
  Schema:Set("loadouts.rules", all)
  return all[content]
end

function LO.ClearRule(content)
  local all = rules()
  all[content] = nil
  Schema:Set("loadouts.rules", all)
end

-- Differences between the rule for `content` and the current state.
function LO.Check(content)
  local rule = rules()[content or LO.Content()]
  if not rule then return nil end
  local cur, diff = LO.Current(), {}
  if rule.spec and rule.spec ~= cur.spec then diff.spec = rule.spec end
  if rule.config and rule.config ~= cur.config then diff.config = rule.config end
  if rule.set and rule.set ~= cur.set then diff.set = rule.set end
  if next(diff) == nil then return nil end
  return diff, rule
end

local function describe(diff)
  local parts = {}
  if diff.spec then
    local _, name = C_SpecializationInfo.GetSpecializationInfo(diff.spec)
    parts[#parts + 1] = "spec " .. tostring(name or diff.spec)
  end
  if diff.config then parts[#parts + 1] = "talent loadout" end
  if diff.set then parts[#parts + 1] = "gear set " .. tostring((C_EquipmentSet.GetEquipmentSetInfo(diff.set)) or diff.set) end
  return table.concat(parts, ", ")
end
LO.Describe = describe

-- One step per call; the next step runs when the game confirms the change.
function LO.Apply()
  CQ.Defer("loadouts.apply", function()
    local diff = LO.Check()
    if not diff then LO.applying = nil; return end
    LO.applying = true
    if diff.spec then
      C_SpecializationInfo.SetSpecialization(diff.spec)
      return -- ACTIVE_PLAYER_SPECIALIZATION_CHANGED continues
    end
    if diff.config then
      local ok, why = C_ClassTalents.CanChangeTalents()
      if ok then C_ClassTalents.LoadConfig(diff.config, true) else PUI.Slash.Print("talents not changed: " .. tostring(why)) end
    end
    if diff.set then C_EquipmentSet.UseEquipmentSet(diff.set) end
    LO.applying = nil
  end)
end

function LO.Evaluate()
  if not LO.active then return end
  local content = LO.Content()
  local diff = LO.Check(content)
  if not diff then return end
  if LO.applying then LO.Apply() return end
  if s.announce then PUI.Slash.Print(string.format("loadout for %s: %s differs. /pui loadout apply to switch.", content, describe(diff))) end
  if s.sound then PlaySound(SOUNDKIT.RAID_WARNING) end
  if s.auto then LO.Apply() end
end

local function onEnable(mod)
  LO.active = true
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", LO.Evaluate)
  mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", LO.Evaluate)
  mod:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", LO.Evaluate)
  mod:RegisterEvent("TRAIT_CONFIG_UPDATED", function() if LO.applying then LO.Apply() end end)
end
local function onDisable() LO.active = false; LO.applying = nil end

local schema = {}
LO.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value) s[name] = value end
  schema["loadouts." .. name] = def
end
key("announce", { type = "toggle", default = true, label = "Announce differences", tooltip = "Tells you in chat when your spec, talents or gear do not match the loadout for where you are.", mode = "simple" })
key("auto", { type = "toggle", default = false, label = "Switch automatically", tooltip = "Switches to the saved loadout on its own when you zone in (out of combat).", mode = "simple" })
key("sound", { type = "toggle", default = false, label = "Sound", tooltip = "Plays a sound with the announcement.", mode = "advanced" })
schema["loadouts.rules"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Loadout rules",
  tooltip = "Spec, talents and gear set saved per kind of content.", apply = function() end }

PUI.Slash:Register("loadout", function(rest)
  local word, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  local out = PUI.Slash.Print
  local content = arg ~= "" and arg or LO.Content()
  if word == "save" then
    LO.SaveRule(content)
    out("loadout saved for " .. content)
  elseif word == "clear" then
    LO.ClearRule(content)
    out("loadout cleared for " .. content)
  elseif word == "apply" then
    LO.Apply()
  elseif word == "check" then
    local diff = LO.Check(content)
    out(diff and (content .. ": " .. describe(diff)) or (content .. ": matches (or no loadout saved)"))
  else
    out("/pui loadout save|clear|check [" .. table.concat(LO.CONTENT, "|") .. "] | apply")
  end
end, "loadouts per content: save, check, apply, clear")

LO.module = PUI:RegisterModule(OWNER, {
  label = "Loadouts", tooltip = "Spec, talent loadout and gear set per kind of content, checked when you zone in.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
