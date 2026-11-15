local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Reminders, deferred batch C:
--  * consumables: rows from the pack's consumables list (still empty until the
--    season IDs are read in game) and a weapon oil / temporary enchant check
--    inside instances that needs no IDs (C_PaperDollInfo.GetTemporaryEnchantmentInfo).
--  * talents by zone: remember a saved talent loadout per instance and remind
--    when you enter it with another one (/pui rmtalents save | clear).
--  * per-reminder sound and icon: "key: sound=Name icon=ID" lines.
-- Everything runs inside the existing out-of-combat evaluator.
local _, ns = ...
local RM = ns.RM
local Schema = PUI.Schema
local OWNER = "Reminders"

local X = { s = { consumables = true, oil = false, talents = true, zones = {}, overrides = {} } }
RM.Extras = X
local s = X.s
X.OIL_ICON = "Interface\\Icons\\INV_Misc_Potionsetc_01"
X.TALENT_ICON = "Interface\\Icons\\Ability_Marksmanship"

function X.InstanceID()
  local id = select(8, GetInstanceInfo())
  return type(id) == "number" and id or nil
end
function X.SpecID()
  local idx = C_SpecializationInfo.GetSpecialization()
  local id = idx and C_SpecializationInfo.GetSpecializationInfo(idx)
  return type(id) == "number" and id or nil
end
function X.CurrentConfig()
  local spec = X.SpecID()
  return spec and C_ClassTalents.GetLastSelectedSavedConfigID(spec) or nil
end
function X.ConfigName(id)
  local info = C_Traits.GetConfigInfo(id)
  return type(info) == "table" and info.name or ("loadout " .. tostring(id))
end

-- Overrides: { [key] = { sound = "Name", icon = 12345 } }
function X.ParseOverrides(list)
  local out = {}
  for _, line in ipairs(list or {}) do
    local k, rest = tostring(line):match("^%s*([%w_]+)%s*:%s*(.-)%s*$")
    if k then
      local o = {}
      o.sound = rest:match("sound=([^%s]+)")
      local icon = rest:match("icon=([^%s]+)")
      o.icon = tonumber(icon) or icon
      out[k] = o
    end
  end
  return out
end

function X.Extra(out)
  if not out then return out end
  local pack = RM.Pack()
  local list = out.custom
  if s.consumables then
    for _, r in ipairs(pack.consumables or {}) do
      local has = false
      for _, id in ipairs(r.any or {}) do if RM.HasAura(id) ~= false then has = true end end
      if not has and r.any and r.any[1] then list[#list + 1] = { spell = r.any[1], key = r.key, label = r.label } end
    end
    if s.oil and IsInInstance() and GetInventoryItemID("player", 16) then
      if C_PaperDollInfo.GetTemporaryEnchantmentInfo(16) == nil then list[#list + 1] = { icon = X.OIL_ICON, key = "oil", label = "Weapon oil" } end
    end
  end
  if s.talents then
    local inst, cur = X.InstanceID(), X.CurrentConfig()
    local want = inst and s.zones[inst]
    if want and cur and want ~= cur then
      list[#list + 1] = { icon = X.TALENT_ICON, key = "talents", label = "Talents: " .. X.ConfigName(want) }
    end
  end
  return out
end

local evaluate = RM.Evaluate
function RM.Evaluate()
  return X.Extra(evaluate())
end

local show = RM.Show
X.seen = {}
function RM.Show(out)
  local ov = X.ParseOverrides(s.overrides)
  local fresh = {}
  for _, g in ipairs(RM.GROUPS) do
    for _, r in ipairs(out[g] or {}) do
      local o = r.key and ov[r.key]
      if o and o.icon then r.icon = o.icon end
      if r.key and not X.seen[r.key] then fresh[#fresh + 1] = r.key end
    end
  end
  local n = show(out)
  local now = {}
  for _, g in ipairs(RM.GROUPS) do for _, r in ipairs(out[g] or {}) do if r.key then now[r.key] = true end end end
  X.seen = now
  X.played = {}
  for _, k in ipairs(fresh) do
    local o = ov[k]
    if o and o.sound and PUI.Media:PlaySound(o.sound) then X.played[#X.played + 1] = k end
  end
  return n
end

function X.SaveZone(clear)
  local inst = X.InstanceID()
  if not inst or inst == 0 then return false end
  local map = {}
  for k, v in pairs(Schema:Get("rm.talentZones") or {}) do map[k] = v end
  if clear then map[inst] = nil else
    local cur = X.CurrentConfig()
    if not cur then return false end
    map[inst] = cur
  end
  Schema:Set("rm.talentZones", map)
  return true
end
PUI.Slash:Register("rmtalents", function(rest)
  local ok = X.SaveZone(rest == "clear")
  PUI.Slash.Print(ok and (rest == "clear" and "Reminders: no talent loadout for this instance now." or "Reminders: this loadout is remembered for this instance.")
    or "Enter an instance (and pick a saved loadout) first.")
end, "[save|clear]: remember your talent loadout for this instance, or forget it")

local function key(name, field, def)
  def.owner = OWNER
  def.apply = function(v) s[field] = v; if RM.active then RM.Update() end end
  def.searchTags = { "reminder", "consumable", "talent", "sound", "icon" }
  RM.schema["rm." .. name] = def
  Schema:Register("rm." .. name, def)
  s[field] = Schema:Get("rm." .. name)
end
key("consumables", "consumables", { type = "toggle", default = true, label = "Consumables",
  tooltip = "Missing flask, food, rune and oil reminders from the season pack (its IDs arrive once checked in game).", mode = "simple" })
key("weaponOil", "oil", { type = "toggle", default = false, label = "Weapon oil in instances",
  tooltip = "Reminds you when your main-hand weapon has no oil or other temporary enchant inside an instance.", mode = "simple" })
key("talentZone", "talents", { type = "toggle", default = true, label = "Talents by instance",
  tooltip = "Reminds you to switch to the talent loadout you saved for this instance (/pui rmtalents save).", mode = "simple" })
key("talentZones", "zones", { type = "layout", default = {}, label = "Saved talents per instance",
  tooltip = "Instance to saved talent loadout.", mode = "advanced" })
key("overrides", "overrides", { type = "list", default = {}, maxItems = 30, label = "Sound and icon per reminder",
  tooltip = "One line per reminder: key: sound=SoundName icon=IconID (for example 'oil: sound=Phoenix icon=463543'). Keys: intellect, stamina, lethal, pet, oil, talents, custom12345 ...",
  mode = "advanced" })
