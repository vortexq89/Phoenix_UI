local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Reminders (PUI_V2 6.7, Phase 5 core): icons for raid buffs your group can
-- give but you lack, and class buffs you forgot (poisons). Aura data is secret
-- in combat, so checks run only out of combat and the icons simply stay as
-- they were; nothing is compared while a value is secret. Three icon pools
-- (raid, class, custom) are pre-built out of combat so showing or hiding an
-- icon never creates a frame. Off by default.
local _, ns = ...
local Schema, Layout, Secret, Theme = PUI.Schema, PUI.Layout, PUI.Secret, PUI.Theme
local OWNER = "Reminders"
local POOL = 6

local RM = { active = false, pools = {}, missing = {} }
ns.RM = RM
PUI.Reminders = RM
local s = { raid = true, class = true, onlyGrouped = false, size = 36, sound = false, text = true }
RM.settings = s

function RM.Pack() return PUI.IS_FOREVER and ns.PACK.forever or ns.PACK.retail end

-- True / false, or nil when the game hides the answer.
function RM.HasAura(spell)
  local aura = C_UnitAuras.GetPlayerAuraBySpellID(spell)
  if Secret.IsSecret(aura) then return nil end
  return aura ~= nil
end

function RM.GroupClasses()
  local classes = {}
  local _, mine = UnitClass("player")
  classes[mine] = true
  if IsInGroup() then
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do
      local _, token = UnitClass(prefix .. i)
      if type(token) == "string" and not Secret.IsSecret(token) then classes[token] = true end
    end
  end
  return classes
end

function RM.KnowsAny(list)
  for _, id in ipairs(list) do if C_SpellBook.IsSpellKnown(id) then return true end end
  return false
end

-- Builds the missing lists; returns nil in combat (unchanged display).
function RM.Evaluate()
  if InCombatLockdown() then return nil end
  local pack = RM.Pack()
  local out = { raid = {}, class = {}, custom = {} }
  if s.raid and (not s.onlyGrouped or IsInGroup()) then
    local classes = RM.GroupClasses()
    for _, b in ipairs(pack.raid) do
      if classes[b.class] and RM.HasAura(b.spell) == false then out.raid[#out.raid + 1] = { spell = b.spell, key = b.key } end
    end
  end
  if s.class then
    local _, mine = UnitClass("player")
    for _, r in ipairs(pack.class[mine] or {}) do
      if RM.KnowsAny(r.any) then
        local has = false
        for _, id in ipairs(r.any) do if RM.HasAura(id) ~= false then has = true end end
        if not has then out.class[#out.class + 1] = { spell = r.any[1], key = r.key, label = r.label } end
      end
    end
  end
  return out
end

local ROWS = { "raid", "class", "custom" }
local function pool(name)
  local p = RM.pools[name]
  if p then return p end
  p = { icons = {} }
  local holder = PUI:CreateFrame("Frame", "PhoenixUI_Reminders_" .. name, UIParent, nil, OWNER)
  holder:SetSize(s.size * POOL, s.size)
  p.holder = holder
  Layout:Place(holder, "rm." .. name)
  for i = 1, POOL do
    local f = PUI:CreateFrame("Frame", nil, holder, nil, OWNER)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(PUI.Media:FontObject("small"))
    label:SetPoint("TOP", f, "BOTTOM", 0, -2)
    Theme:Outline(f, "accent")
    p.icons[i] = { frame = f, tex = tex, label = label }
    f:Hide()
  end
  RM.pools[name] = p
  return p
end

function RM.Layout()
  for _, name in ipairs(ROWS) do
    local p = RM.pools[name]
    if p then
      p.holder:SetSize(s.size * POOL, s.size)
      for i, icon in ipairs(p.icons) do
        icon.frame:SetSize(s.size, s.size)
        icon.frame:ClearAllPoints()
        icon.frame:SetPoint("LEFT", (i - 1) * (s.size + 4), 0)
      end
    end
  end
end

function RM.Show(out)
  local newCount = 0
  for _, name in ipairs(ROWS) do
    local p = pool(name)
    local list = out[name] or {}
    for i, icon in ipairs(p.icons) do
      local r = list[i]
      if r then
        icon.tex:SetTexture(C_Spell.GetSpellTexture(r.spell))
        icon.label:SetText(s.text and (r.label or C_Spell.GetSpellName(r.spell)) or "")
        if not icon.frame:IsShown() then newCount = newCount + 1 end
        icon.frame:Show()
      else
        icon.frame:Hide()
      end
    end
  end
  if newCount > 0 and s.sound then PUI.Media:Alert(SOUNDKIT.RAID_WARNING) end
  RM.missing = out
end

function RM.Update()
  if not RM.active then return end
  if InCombatLockdown() then PUI.CombatQueue.Defer("rm.update", RM.Update) return end
  local out = RM.Evaluate()
  if out then RM.Show(out) end
end

local function hideAll()
  for _, p in pairs(RM.pools) do for _, icon in ipairs(p.icons) do icon.frame:Hide() end end
  RM.missing = {}
end

local function onEnable(mod)
  RM.active = true
  for _, name in ipairs(ROWS) do pool(name) end
  RM.Layout()
  mod:RegisterUnitEvent("UNIT_AURA", RM.Update, "player")
  mod:RegisterEvent("GROUP_ROSTER_UPDATE", RM.Update)
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", RM.Update)
  RM.Update()
end

local function onDisable()
  RM.active = false
  hideAll()
end

for i, name in ipairs(ROWS) do
  Layout:RegisterElement("rm." .. name, { label = "Reminders: " .. name, owner = OWNER, size = { 36 * POOL, 36 },
    default = { point = "TOP", x = 0, y = -24 - (i - 1) * 56 } })
end

local schema = {}
RM.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value) s[name] = value; RM.Layout(); RM.Update() end
  schema["rm." .. name] = def
end
key("raid", { type = "toggle", default = true, label = "Raid buffs", tooltip = "Shows raid buffs someone in your group can give that you are missing.", mode = "simple" })
key("class", { type = "toggle", default = true, label = "Class buffs", tooltip = "Shows your own class buffs that are missing, like rogue poisons.", mode = "simple" })
key("onlyGrouped", { type = "toggle", default = false, label = "Only in a group", tooltip = "Raid buff reminders only while you are in a group.", mode = "advanced" })
key("size", { type = "range", default = 36, min = 20, max = 64, step = 2, label = "Icon size", tooltip = "Reminder icon size.", mode = "advanced" })
key("text", { type = "toggle", default = true, label = "Show names", tooltip = "Writes the buff name under each icon.", mode = "advanced" })
key("sound", { type = "toggle", default = false, label = "Sound", tooltip = "Plays a sound when a reminder appears.", mode = "advanced" })

RM.module = PUI:RegisterModule(OWNER, {
  label = "Reminders", tooltip = "Missing raid buffs and class buffs, checked out of combat.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
