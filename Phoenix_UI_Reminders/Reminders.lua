local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Reminders (plan 5.13, 15.3): one declarative reminder engine. Every reminder
-- is a rule row (group, spells, class, spec, "where to show" by content) taken
-- from the data pack or from your own custom list; the same evaluator decides
-- all of them and records why a row is hidden ("why hidden" in the preview and
-- /pui rm why). Aura data is secret in combat, so checks run out of combat and
-- the icons stay as they were; nothing is compared while a value is secret.
-- Icon pools are pre-built out of combat; class and custom icons can be
-- clicked to cast (secure buttons, set up only out of combat). Off by default.
local _, ns = ...
local Schema, Layout, Secret, Theme, CQ = PUI.Schema, PUI.Layout, PUI.Secret, PUI.Theme, PUI.CombatQueue
local OWNER = "Reminders"
local POOL = 8

local RM = { active = false, pools = {}, missing = {}, why = {} }
ns.RM = RM
PUI.Reminders = RM
RM.GROUPS = { "raid", "class", "pet", "custom" }
RM.GROUP_LABELS = { raid = "Raid buffs", class = "Class buffs", pet = "Missing pet", custom = "My reminders" }
local s = { raid = true, class = true, pet = true, custom = true, onlyGrouped = false, size = 36, sound = false, text = true,
  spacing = 4, click = true, readyCheck = true, glow = true, customList = {}, where = nil, keyBelow = 0, soundName = "raidwarning" }
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

-- Custom rows: "spellID" or "spellID:label" (one per line in the list).
function RM.ParseCustom(list)
  local out = {}
  for _, line in ipairs(list or {}) do
    local id, label = tostring(line):match("^%s*(%d+)%s*:?%s*(.-)%s*$")
    id = tonumber(id)
    if id then out[#out + 1] = { key = "custom" .. id, any = { id }, label = label ~= "" and label or nil } end
  end
  return out
end

-- Where to show: per group, per content type (grid setting).
function RM.Allowed(group, content)
  content = content or PUI.Profiles:Content()
  local row = s.where and s.where[group]
  if row and row[content] == false then return false, "turned off for " .. (PUI.Profiles.CONTENT_LABEL[content] or content) end
  if content == "mythicplus" and s.keyBelow > 0 then
    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    if type(level) == "number" and level >= s.keyBelow then return false, "key level " .. level .. " is at or above your limit" end
  end
  return true
end

-- Builds the missing lists and the "why hidden" notes; nil in combat.
function RM.Evaluate()
  if InCombatLockdown() then return nil end
  local pack = RM.Pack()
  local out, why = { raid = {}, class = {}, pet = {}, custom = {} }, {}
  local content = PUI.Profiles:Content()
  local function gate(group)
    if not s[group] then why[group] = "turned off"; return false end
    local ok, reason = RM.Allowed(group, content)
    if not ok then why[group] = reason end
    return ok
  end
  if gate("raid") then
    if s.onlyGrouped and not IsInGroup() and not RM.readyCheck then
      why.raid = "only shown in a group"
    else
      local classes = RM.GroupClasses()
      for _, b in ipairs(pack.raid) do
        if classes[b.class] and RM.HasAura(b.spell) == false then out.raid[#out.raid + 1] = { spell = b.spell, key = b.key } end
      end
    end
  end
  local _, mine = UnitClass("player")
  local function anyRows(rows, into, needKnown)
    for _, r in ipairs(rows) do
      if not needKnown or RM.KnowsAny(r.any) then
        local has = false
        for _, id in ipairs(r.any) do if RM.HasAura(id) ~= false then has = true end end
        if not has then into[#into + 1] = { spell = r.any[1], key = r.key, label = r.label } end
      end
    end
  end
  if gate("class") then anyRows(pack.class[mine] or {}, out.class, true) end
  if gate("custom") then anyRows(RM.ParseCustom(s.customList), out.custom, false) end
  if gate("pet") then
    local p = pack.pets and pack.pets[mine]
    if p then
      local spec = C_SpecializationInfo.GetSpecialization()
      local noPet = false
      for _, x in ipairs(p.noPetSpecs or {}) do if x == spec then noPet = true end end
      if noPet then why.pet = "this specialization plays without a pet"
      elseif IsMounted() then why.pet = "mounted"
      elseif not UnitExists("pet") then out.pet[1] = { icon = 136218, key = "pet", label = "Summon your pet" } end
    else
      why.pet = "your class has no pet reminder"
    end
  end
  RM.why = why
  return out
end

local function pool(name)
  local p = RM.pools[name]
  if p then return p end
  p = { icons = {} }
  local holder = PUI:CreateFrame("Frame", "PhoenixUI_Reminders_" .. name, UIParent, nil, OWNER)
  holder:SetSize(s.size * POOL, s.size)
  p.holder = holder
  Layout:Place(holder, "rm." .. name)
  for i = 1, POOL do
    -- secure button so a class/custom icon can be clicked to cast (attributes set out of combat)
    local f = PUI:CreateFrame("Button", nil, holder, "SecureActionButtonTemplate", OWNER)
    f:RegisterForClicks("AnyUp", "AnyDown")
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
  for _, name in ipairs(RM.GROUPS) do
    local p = RM.pools[name]
    if p then
      p.holder:SetSize((s.size + s.spacing) * POOL, s.size)
      for i, icon in ipairs(p.icons) do
        icon.frame:SetSize(s.size, s.size)
        icon.frame:ClearAllPoints()
        icon.frame:SetPoint("LEFT", (i - 1) * (s.size + s.spacing), 0)
      end
    end
  end
end

-- Out of combat only (callers check): sets texture, label and click-to-cast.
function RM.Show(out)
  local newCount = 0
  for _, name in ipairs(RM.GROUPS) do
    local p = pool(name)
    local list = out[name] or {}
    for i, icon in ipairs(p.icons) do
      local r = list[i]
      if r then
        icon.tex:SetTexture(r.icon or C_Spell.GetSpellTexture(r.spell))
        icon.label:SetText(s.text and (r.label or (r.spell and C_Spell.GetSpellName(r.spell))) or "")
        local castable = s.click and r.spell and (name == "class" or name == "custom") and C_SpellBook.IsSpellKnown(r.spell)
        icon.frame:SetAttribute("type", castable and "spell" or nil)
        icon.frame:SetAttribute("spell", castable and r.spell or nil)
        if not icon.frame:IsShown() then newCount = newCount + 1 end
        if s.glow and PUI.Glow then PUI.Glow:Start(icon.frame, "pulse") end
        icon.frame:Show()
      else
        if PUI.Glow then PUI.Glow:Stop(icon.frame) end
        icon.frame:Hide()
      end
    end
  end
  if newCount > 0 and s.sound then PUI.Media:Alert(SOUNDKIT.RAID_WARNING) end
  RM.missing = out
  return newCount
end

function RM.Update()
  if not RM.active then return end
  if InCombatLockdown() then CQ.Defer("rm.update", RM.Update) return end
  local out = RM.Evaluate()
  if out then RM.Show(out) end
end

-- Ready check: raid buffs show even when "only in a group" would hide them.
function RM.OnReadyCheck()
  if not s.readyCheck then return end
  RM.readyCheck = true
  RM.Update()
  RM.readyCheck = nil
end

local function hideAll()
  for _, p in pairs(RM.pools) do
    for _, icon in ipairs(p.icons) do
      if PUI.Glow then PUI.Glow:Stop(icon.frame) end
      icon.frame:Hide()
    end
  end
  RM.missing = {}
end

local function onEnable(mod)
  RM.active = true
  CQ.Defer("rm.pools", function() for _, name in ipairs(RM.GROUPS) do pool(name) end; RM.Layout() end)
  mod:RegisterUnitEvent("UNIT_AURA", RM.Update, "player")
  mod:RegisterUnitEvent("UNIT_PET", RM.Update, "player")
  mod:RegisterEvent("GROUP_ROSTER_UPDATE", RM.Update)
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", RM.Update)
  mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", RM.Update)
  mod:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", RM.Update)
  mod:RegisterEvent("READY_CHECK", RM.OnReadyCheck)
  RM.Update()
end

local function onDisable()
  RM.active = false
  CQ.Defer("rm.hide", hideAll)
end

for i, name in ipairs(RM.GROUPS) do
  Layout:RegisterElement("rm." .. name, { label = "Reminders: " .. RM.GROUP_LABELS[name], owner = OWNER, size = { 40 * POOL, 36 },
    default = { point = "TOP", x = 0, y = -24 - (i - 1) * 56 } })
end

local function contentColumns()
  local out = {}
  for i, c in ipairs(PUI.Profiles.CONTENT) do out[i] = { id = c, label = PUI.Profiles.CONTENT_LABEL[c] } end
  return out
end
local function allWhere()
  local g = {}
  for _, name in ipairs(RM.GROUPS) do
    g[name] = {}
    for _, c in ipairs(PUI.Profiles.CONTENT) do g[name][c] = true end
  end
  return g
end

local schema = {}
RM.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value) s[name] = value; if RM.active then CQ.Defer("rm.layout", RM.Layout); RM.Update() end end
  schema["rm." .. name] = def
end
-- Simple
key("raid", { type = "toggle", default = true, label = "Raid buffs", tooltip = "Shows raid buffs someone in your group can give that you are missing.", mode = "simple" })
key("class", { type = "toggle", default = true, label = "Class buffs", tooltip = "Shows your own class buffs that are missing, like rogue poisons or a paladin aura.", mode = "simple" })
key("pet", { type = "toggle", default = true, label = "Missing pet", tooltip = "Reminds warlocks and hunters (not Marksmanship) to summon their pet.", mode = "simple" })
key("custom", { type = "toggle", default = true, label = "My reminders", tooltip = "Shows the buffs from your own list below when they are missing.", mode = "simple" })
key("customList", { type = "list", default = {}, maxItems = 30, label = "My reminder list",
  tooltip = "One per line: a spell ID, optionally followed by :name (for example 1234:Flask). Shows when you lack that buff.", mode = "simple",
  searchTags = { "flask", "food", "rune", "oil", "buff", "custom" } })
key("where", { type = "grid", default = allWhere(), rows = function() local r = {}; for i, n in ipairs(RM.GROUPS) do r[i] = { id = n, label = RM.GROUP_LABELS[n] } end; return r end,
  columns = contentColumns, label = "Where to remind", tooltip = "Pick, per reminder group, the content types where it shows.", mode = "simple" })
key("click", { type = "toggle", default = true, label = "Click to cast", tooltip = "Click a class or custom reminder to cast that spell (set up out of combat).", mode = "simple" })
-- Advanced
key("onlyGrouped", { type = "toggle", default = false, label = "Raid buffs only in a group", tooltip = "Raid buff reminders only while you are in a group (a ready check still shows them).", mode = "advanced" })
key("readyCheck", { type = "toggle", default = true, label = "Check on ready check", tooltip = "Re-checks everything when a ready check starts.", mode = "advanced" })
key("keyBelow", { type = "range", default = 0, min = 0, max = 30, step = 1, label = "Hide from key level",
  tooltip = "In Mythic+, hide reminders on keys at or above this level (0 never hides).", mode = "advanced" })
key("size", { type = "range", default = 36, min = 20, max = 64, step = 2, label = "Icon size", tooltip = "Reminder icon size.", mode = "advanced" })
key("spacing", { type = "range", default = 4, min = 0, max = 16, step = 1, label = "Icon spacing", tooltip = "Space between reminder icons.", mode = "advanced" })
key("text", { type = "toggle", default = true, label = "Show names", tooltip = "Writes the buff name under each icon.", mode = "advanced" })
key("glow", { type = "toggle", default = true, label = "Glow", tooltip = "A soft glow around reminder icons.", mode = "advanced" })
key("sound", { type = "toggle", default = false, label = "Sound", tooltip = "Plays a sound when a reminder appears.", mode = "advanced" })

PUI.Slash:Register("rm", function(rest)
  local out = PUI.Slash.Print
  if (rest or ""):match("^why") then
    RM.Evaluate()
    local any = false
    for _, g in ipairs(RM.GROUPS) do if RM.why[g] then any = true; out(RM.GROUP_LABELS[g] .. ": " .. RM.why[g]) end end
    if not any then out("nothing is hidden right now") end
  else
    out("/pui rm why - why a reminder group is hidden")
  end
end, "Reminders: why a reminder is hidden")

RM.module = PUI:RegisterModule(OWNER, {
  label = "Reminders", tooltip = "Missing raid buffs, class buffs, pets and your own buff list, checked out of combat, with click to cast.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
