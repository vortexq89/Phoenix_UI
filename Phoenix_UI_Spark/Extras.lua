local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Spark, deferred batch C:
--  * per-event sounds: every event row gets a sound from the media library
--    (throttled per row so a big pull never stacks sounds).
--  * aura gain / fade rows for your own buffs and debuffs (UNIT_AURA on you;
--    a secret aura name is skipped, never compared).
--  * substitution and abbreviation: "Original = New" lines and an optional
--    auto-shortening of long ability names (plain names only).
--  * triggers with a builder window: when <you cast / gain / lose an aura /
--    enter / leave combat> matching <name or ID> show <message>, colour, sound.
--  * MSBT profile import: with MikScrollingBattleText loaded, copies its
--    scroll-area look, event on/off, colours and messages, number shortening and
--    ability substitutions into Spark's own settings (never touches MSBT's data).
local _, ns = ...
local Schema, Secret = PUI.Schema, PUI.Secret
local SP, E, F = ns.SP, ns.Engine, ns.Feed
local OWNER = "Spark"
local S = SP.settings
local X = { lastSound = {}, auraNames = {} }
SP.Extras = X
local M = S.master

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end

-- New rows ---------------------------------------------------------------------------------------
X.NEW_ROWS = {
  { id = "auraGain", label = "Auras you gain", area = "notification", color = { r = 0.45, g = 0.9, b = 1 }, template = "+%s" },
  { id = "auraFade", label = "Auras you lose", area = "notification", color = { r = 0.6, g = 0.6, b = 0.7 }, template = "-%s" },
  { id = "trigger", label = "Your triggers", area = "static", color = { r = 1, g = 0.82, b = 0.25 }, template = "%s" },
}
for _, r in ipairs(X.NEW_ROWS) do
  F.ROWS[#F.ROWS + 1] = r
  F.BY_ID[r.id] = r
  S.rows[r.id] = S.rows[r.id] or {}
end

-- Text: substitutions and abbreviation (plain names only) --------------------------------------------
function X.ParsePairs(list)
  local out = {}
  for _, line in ipairs(list or {}) do
    local a, b = tostring(line):match("^%s*(.-)%s*=%s*(.-)%s*$")
    if a and a ~= "" then out[a:lower()] = b end
  end
  return out
end
function X.Abbreviate(name, maxLen)
  if #name <= maxLen then return name end
  local out = {}
  for w in name:gmatch("%S+") do out[#out + 1] = w:sub(1, 1):upper() end
  return table.concat(out)
end
function X.Text(name)
  if not plain(name) or type(name) ~= "string" then return name end
  local sub = X.ParsePairs(M.substitutions)[name:lower()]
  if sub then return sub end
  if M.abbreviate then return X.Abbreviate(name, M.abbreviateLength) end
  return name
end

local emit = F.Emit
function F.Emit(rowId, tok, extra)
  if tok and tok.spell then tok.spell = X.Text(tok.spell) end
  local out = emit(rowId, tok, extra)
  local rs = S.rows[rowId]
  if out ~= nil and rs and rs.sound and rs.sound ~= "None" then
    local now = GetTime()
    if now - (X.lastSound[rowId] or 0) >= 0.3 then X.lastSound[rowId] = now; PUI.Media:PlaySound(rs.sound) end
  end
  if rowId == "combatIn" or rowId == "combatOut" then X.Fire(rowId, nil) end
  return out
end

-- Aura rows --------------------------------------------------------------------------------------
function X.OnAura(unit, info)
  if unit ~= "player" or type(info) ~= "table" then return end
  for _, a in ipairs(info.addedAuras or {}) do
    local id = a.auraInstanceID
    if plain(id) and plain(a.name) then
      X.auraNames[id] = a.name
      F.Emit("auraGain", { spell = a.name, icon = a.icon })
      X.Fire("auraGain", a.name, a.spellId)
    end
  end
  for _, id in ipairs(info.removedAuraInstanceIDs or {}) do
    local name = plain(id) and X.auraNames[id]
    if name then
      X.auraNames[id] = nil
      F.Emit("auraFade", { spell = name })
      X.Fire("auraFade", name)
    end
  end
end

-- Triggers -----------------------------------------------------------------------------------------
X.KINDS = { "cast", "auraGain", "auraFade", "combatIn", "combatOut" }
X.KIND_LABELS = { cast = "I cast", auraGain = "I gain the aura", auraFade = "I lose the aura", combatIn = "I enter combat", combatOut = "I leave combat" }
-- ParseTriggers(list) -> { { kind, match, message, color, sound } } (pure). Line: "kind | match | message | RRGGBB | sound"
function X.ParseTriggers(list)
  local out = {}
  for _, line in ipairs(list or {}) do
    local parts = {}
    for p in (tostring(line) .. "|"):gmatch("(.-)|") do parts[#parts + 1] = p:match("^%s*(.-)%s*$") end
    local kind = parts[1]
    if X.KIND_LABELS[kind] and parts[3] and parts[3] ~= "" then
      local hex = parts[4] or ""
      local color = #hex == 6 and { r = tonumber(hex:sub(1, 2), 16) / 255, g = tonumber(hex:sub(3, 4), 16) / 255, b = tonumber(hex:sub(5, 6), 16) / 255 } or nil
      out[#out + 1] = { kind = kind, match = (parts[2] or ""):lower(), message = parts[3], color = color, sound = parts[5] ~= "" and parts[5] or nil }
    end
  end
  return out
end
function X.TriggerLine(t)
  return table.concat({ t.kind, t.match or "", t.message or "", t.hex or "", t.sound or "" }, " | ")
end
function X.Fire(kind, name, id)
  if not (SP.active and M.triggersOn) then return 0 end
  local n = 0
  for _, t in ipairs(X.ParseTriggers(M.triggers)) do
    local ok = t.kind == kind and (t.match == "" or (plain(name) and type(name) == "string" and name:lower() == t.match) or (plain(id) and tostring(id) == t.match))
    if ok then
      n = n + 1
      F.Emit("trigger", { spell = t.message }, { color = t.color })
      if t.sound then PUI.Media:PlaySound(t.sound) end
    end
  end
  return n
end
local onCast = F.OnCast
function F.OnCast(unit, guid, spellID)
  onCast(unit, guid, spellID)
  if unit == "player" and plain(spellID) then X.Fire("cast", C_Spell.GetSpellName(spellID), spellID) end
end

-- Builder window ------------------------------------------------------------------------------------
function X.Builder()
  local f = X.builder
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUISparkTriggerBuilder", UIParent, nil, OWNER)
    f:SetSize(360, 196); f:SetPoint("CENTER")
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.96)
    f.accent = f:CreateTexture(nil, "BORDER"); f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("TOPRIGHT"); f.accent:SetHeight(2); f.accent:SetColorTexture(0.91, 0.64, 0.24, 1)
    f.title = f:CreateFontString(nil, "OVERLAY"); f.title:SetFontObject(PUI.Media:FontObject("normal")); f.title:SetPoint("TOPLEFT", 10, -8); f.title:SetText("New Spark trigger")
    f.draft = { kind = "cast", match = "", message = "", hex = "", sound = "" }
    local function label(text, y)
      local l = f:CreateFontString(nil, "OVERLAY"); l:SetFontObject(PUI.Media:FontObject("small")); l:SetPoint("TOPLEFT", 10, y); l:SetText(text)
    end
    local function edit(field, y)
      local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate"); e:SetSize(200, 18); e:SetPoint("TOPLEFT", 140, y); e:SetAutoFocus(false)
      e:SetScript("OnTextChanged", function(self) f.draft[field] = self:GetText() or "" end)
      return e
    end
    label("When", -34)
    f.kind = CreateFrame("Button", nil, f); f.kind:SetSize(200, 18); f.kind:SetPoint("TOPLEFT", 140, -32)
    f.kind.text = f.kind:CreateFontString(nil, "OVERLAY"); f.kind.text:SetFontObject(PUI.Media:FontObject("small")); f.kind.text:SetAllPoints()
    f.kind:SetScript("OnClick", function() X.CycleKind() end)
    label("Name or spell ID (empty: any)", -58); f.match = edit("match", -56)
    label("Show this text", -82); f.message = edit("message", -80)
    label("Colour (RRGGBB, optional)", -106); f.hex = edit("hex", -104)
    label("Sound (media name, optional)", -130); f.sound = edit("sound", -128)
    f.add = CreateFrame("Button", nil, f); f.add:SetSize(80, 20); f.add:SetPoint("BOTTOMRIGHT", -10, 10)
    f.add.text = f.add:CreateFontString(nil, "OVERLAY"); f.add.text:SetFontObject(PUI.Media:FontObject("small")); f.add.text:SetAllPoints(); f.add.text:SetText("|cffe8a33dAdd|r")
    f.add:SetScript("OnClick", function() if X.AddDraft() then f:Hide() end end)
    f.cancel = CreateFrame("Button", nil, f); f.cancel:SetSize(80, 20); f.cancel:SetPoint("RIGHT", f.add, "LEFT", -8, 0)
    f.cancel.text = f.cancel:CreateFontString(nil, "OVERLAY"); f.cancel.text:SetFontObject(PUI.Media:FontObject("small")); f.cancel.text:SetAllPoints(); f.cancel.text:SetText("Cancel")
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    X.builder = f
  end
  f.kind.text:SetText("|cff9ad0ff" .. X.KIND_LABELS[f.draft.kind] .. "|r  (click to change)")
  f:Show()
  return f
end
function X.CycleKind()
  local f = X.builder
  for i, k in ipairs(X.KINDS) do
    if k == f.draft.kind then f.draft.kind = X.KINDS[i % #X.KINDS + 1]; break end
  end
  f.kind.text:SetText("|cff9ad0ff" .. X.KIND_LABELS[f.draft.kind] .. "|r  (click to change)")
end
function X.AddDraft()
  local d = X.builder and X.builder.draft
  if not d or (d.message or "") == "" then return false end
  local list = {}
  for _, l in ipairs(Schema:Get("spark.triggers") or {}) do list[#list + 1] = l end
  list[#list + 1] = X.TriggerLine(d)
  Schema:Set("spark.triggers", list)
  return true
end

-- MSBT import --------------------------------------------------------------------------------------
X.MSBT_AREAS = { Incoming = "incoming", Outgoing = "outgoing", Notification = "notification", Static = "static" }
X.MSBT_ANIM = { Straight = "scroll", Parabola = "parabola", Static = "static" }
X.MSBT_ALIGN = { "LEFT", "CENTER", "RIGHT" }
X.MSBT_EVENTS = { INCOMING_DAMAGE = "inDamage", INCOMING_HEAL = "inHeal", INCOMING_MISS = "inAvoid", PET_INCOMING_DAMAGE = "petDamage",
  PET_INCOMING_HEAL = "petHeal", OUTGOING_DAMAGE = "outDamage", OUTGOING_HEAL = "outHeal", OUTGOING_MISS = "outAvoid",
  NOTIFICATION_COMBAT_ENTER = "combatIn", NOTIFICATION_COMBAT_LEAVE = "combatOut", NOTIFICATION_LOOT = "loot", NOTIFICATION_MONEY = "money",
  NOTIFICATION_CURRENCY = "currency", NOTIFICATION_REP_GAIN = "reputation", NOTIFICATION_EXPERIENCE_GAIN = "xp", NOTIFICATION_HONOR_GAIN = "honor",
  NOTIFICATION_SKILL_GAIN = "skill", NOTIFICATION_BUFF = "auraGain", NOTIFICATION_BUFF_FADE = "auraFade", NOTIFICATION_ITEM_COOLDOWN = "itemReady" }
-- MSBT messages use %n/%sl/%t tokens Phoenix does not have; keep %a, %s, %e and drop the rest.
function X.MSBTMessage(m)
  if type(m) ~= "string" then return nil end
  return (m:gsub("%%sl", "%%s"):gsub("%%n", ""):gsub("%%t", ""):gsub("%(%s*%)", ""):gsub("%s%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
-- ImportMSBT(sv, charSv) -> count of settings written, or nil + reason
function X.ImportMSBT(sv, charSv)
  sv = sv or rawget(_G, "MSBTProfiles_SavedVars")
  charSv = charSv or rawget(_G, "MSBTProfiles_SavedVarsPerChar")
  if type(sv) ~= "table" or type(sv.profiles) ~= "table" then return nil, "MikScrollingBattleText's saved settings are not loaded" end
  local name = type(charSv) == "table" and charSv.currentProfileName or "Default"
  local p = sv.profiles[name]
  if type(p) ~= "table" then return nil, "no MSBT profile named " .. tostring(name) end
  local n = 0
  local function set(k, v) if v ~= nil and Schema:Def(k) then Schema:Set(k, v); n = n + 1 end end
  for msbtArea, area in pairs(X.MSBT_AREAS) do
    local a = type(p.scrollAreas) == "table" and p.scrollAreas[msbtArea]
    if type(a) == "table" then
      local base = "spark.area." .. area .. "."
      set(base .. "behaviour", X.MSBT_ANIM[a.animationStyle])
      set(base .. "direction", a.direction == "Up" and "up" or a.direction == "Down" and "down" or nil)
      set(base .. "align", X.MSBT_ALIGN[tonumber(a.textAlignIndex) or 0])
      if tonumber(a.scrollHeight) then set(base .. "distance", math.max(40, math.min(400, tonumber(a.scrollHeight)))) end
      if tonumber(a.normalFontSize) then set(base .. "size", math.max(10, math.min(48, tonumber(a.normalFontSize)))) end
      if a.isDisabled ~= nil then set(base .. "enabled", not a.isDisabled) end
    end
  end
  for key, row in pairs(X.MSBT_EVENTS) do
    local e = type(p.events) == "table" and p.events[key]
    if type(e) == "table" then
      local base = "spark.ev." .. row .. "."
      if e.disabled ~= nil then set(base .. "on", not e.disabled) end
      if X.MSBT_AREAS[e.scrollArea] then set(base .. "area", X.MSBT_AREAS[e.scrollArea]) end
      if e.colorR or e.colorG or e.colorB then
        local function c(v) v = tonumber(v); return v and math.max(0, math.min(1, v)) or 1 end
        set(base .. "color", { r = c(e.colorR), g = c(e.colorG), b = c(e.colorB), a = 1 })
      end
      local msg = X.MSBTMessage(e.message)
      if msg and msg ~= "" then set(base .. "template", msg) end
    end
  end
  if p.shortenNumbers ~= nil then set("spark.shortNumbers", p.shortenNumbers == true) end
  if type(p.abilitySubstitutions) == "table" then
    local list = {}
    for from, to in pairs(p.abilitySubstitutions) do if type(from) == "string" and type(to) == "string" then list[#list + 1] = from .. " = " .. to end end
    table.sort(list)
    if #list > 0 then set("spark.substitutions", list) end
  end
  return n
end
function X.ConfirmImport()
  PUI.Dialogs:Confirm({ title = "Import from MSBT", text = "Copy MikScrollingBattleText's scroll areas, events, colours, messages and substitutions into Spark? Your Spark settings are overwritten; MSBT is not changed.",
    accept = "Import", cancel = "Cancel", onAccept = function()
      local n, why = X.ImportMSBT()
      PUI.Slash.Print(n and ("Spark: imported " .. n .. " settings from MSBT") or ("Spark: " .. why))
    end })
end

PUI.Slash:Register("spark", function(rest)
  local word = (rest or ""):match("^(%S*)")
  if word == "trigger" then X.Builder()
  elseif word == "msbt" then X.ConfirmImport()
  elseif word == "test" then SP.Test()
  elseif word == "clear" then E.Clear()
  else PUI.Slash.Print("/pui spark test | clear | trigger (builder) | msbt (import)") end
end, "Spark combat text: test, clear, trigger builder, MSBT import")

local enable = F.Enable
function F.Enable(mod, st)
  enable(mod, st)
  mod:RegisterUnitEvent("UNIT_AURA", function(_, _, unit, info) X.OnAura(unit, info) end, "player")
end

-- Schema ----------------------------------------------------------------------------------------------
local function reg(k, def, target, field)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) target[field] = v end
  SP.schema[k] = def
  Schema:Register(k, def)
  target[field] = Schema:Get(k)
end
local AREA_CHOICES = { "incoming", "outgoing", "notification", "static" }
for _, r in ipairs(X.NEW_ROWS) do
  local R, p = S.rows[r.id], "spark.ev." .. r.id .. "."
  reg(p .. "on", { type = "toggle", default = r.id == "trigger", label = r.label, tooltip = "Shows " .. r.label:lower() .. " in Spark." }, R, "on")
  reg(p .. "area", { type = "select", default = r.area, choices = AREA_CHOICES, choiceLabels = E.AREA_LABELS, label = r.label .. ": area", tooltip = "Which scroll area shows it." }, R, "area")
  reg(p .. "color", { type = "color", default = { r = r.color.r, g = r.color.g, b = r.color.b, a = 1 }, label = r.label .. ": colour", tooltip = "Text colour." }, R, "color")
  reg(p .. "template", { type = "text", default = "", label = r.label .. ": message", tooltip = "Empty uses \"" .. r.template .. "\". Tokens: %s aura or text, %c count." }, R, "template")
end
local function sounds() return PUI.Media:List("sound") end
for _, r in ipairs(F.ROWS) do
  reg("spark.ev." .. r.id .. ".sound", { type = "select", default = "None", choices = sounds, preview = "sound", label = r.label .. ": sound",
    tooltip = "Plays this sound with the line (at most once every 0.3 s per row)." }, S.rows[r.id], "sound")
end
reg("spark.substitutions", { type = "list", default = {}, label = "Ability substitutions", tooltip = "One line each: \"Original name = New text\". Blank new text hides the name." }, M, "substitutions")
reg("spark.abbreviate", { type = "toggle", default = false, label = "Shorten long ability names", tooltip = "Names longer than the limit become their initials (Shadow Word: Pain -> SWP)." }, M, "abbreviate")
reg("spark.abbreviateLength", { type = "range", default = 16, min = 6, max = 40, step = 1, label = "Shorten names longer than", tooltip = "Character limit before a name is shortened." }, M, "abbreviateLength")
reg("spark.triggersOn", { type = "toggle", default = true, mode = "simple", label = "Triggers", tooltip = "Your own lines for casts, auras and combat. Build them with /pui spark trigger." }, M, "triggersOn")
reg("spark.triggers", { type = "list", default = {}, label = "Trigger list", tooltip = "Built by the trigger builder; each line is \"when | name or ID | text | RRGGBB | sound\" (when: cast, auraGain, auraFade, combatIn, combatOut)." }, M, "triggers")
