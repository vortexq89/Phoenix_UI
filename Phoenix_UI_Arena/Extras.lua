local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Arena, deferred batch C (every part is a setting, drawn by the same paint
-- path in test mode, so the live preview shows it):
--  * pet frames: a small secure button per enemy pet (arenapet1-5), shown by
--    the game's unit watch; health passed straight to the bar.
--  * class-icon aura: the spec icon shows the enemy's top aura by category
--    order (crowd control, big defensive, important). The game filters the
--    auras; Phoenix never reads or compares a secret spell.
--  * dispel tracker: after an enemy is seen using a dispel (plain spell IDs
--    only), a small icon with its cooldown.
--  * range: frames fade when your range spell says the enemy is out of range
--    (the secret answer goes to SetAlphaFromBoolean; Ticker job in arenas only).
--  * click actions per mouse button, applied out of combat.
--  * text page: font size and anchor per text (name, health, number).
--  * FrameSort numbering: numbers follow FrameSort's sorted enemy order.
--  * 'only triggerable by me' DR CVar through the CVar ledger.
--  * healer-only variants: trinket, DR tray and cast bar for enemy healers only.
local _, ns = ...
local Schema, Secret, CQ, Ticker = PUI.Schema, PUI.Secret, PUI.CombatQueue, PUI.Ticker
local AR, FR, ST, DR = PUI.Arena or ns.AR, ns.Frames, ns.State, ns.DR
local OWNER = "Arena"
local s = AR.settings
local X = { pets = {}, dispels = {} }
AR.Extras = X

-- Healer-only variants ---------------------------------------------------------------------------
function X.IsHealer(spec)
  if spec == nil or Secret.IsSecret(spec) then return nil end
  local role = select(5, GetSpecializationInfoForSpecID(spec))
  return role == "HEALER"
end
function X.HealerGate(f, spec)
  local healer = X.IsHealer(spec)
  local function gate(want, only) return want and (not only or healer == true) end
  f.trinket:SetShown(gate(s.trinket, s.trinketHealerOnly))
  f.tray:SetShown(gate(s.drTray, s.drHealerOnly))
  if f.phxCast then f.phxCast.frame:SetShown(gate(s.castBar, s.castHealerOnly)) end
end

-- Pet frames ------------------------------------------------------------------------------------
function X.BuildPet(i, f)
  local p = X.pets[i]
  if p then return p end
  p = CreateFrame("Button", "PhoenixUIArenaPet" .. i, f, "SecureUnitButtonTemplate")
  p.unit = "arenapet" .. i
  p:SetAttribute("unit", p.unit); p:SetAttribute("type1", "target"); p:SetAttribute("type2", "focus")
  p:RegisterForClicks("AnyUp")
  p.bg = p:CreateTexture(nil, "BACKGROUND"); p.bg:SetAllPoints(); p.bg:SetColorTexture(0.04, 0.05, 0.06, 0.9)
  p.health = CreateFrame("StatusBar", nil, p); p.health:SetPoint("TOPLEFT", 1, -1); p.health:SetPoint("BOTTOMRIGHT", -1, 1)
  p.name = p.health:CreateFontString(nil, "OVERLAY"); p.name:SetFontObject(PUI.Media:FontObject("small")); p.name:SetPoint("LEFT", 3, 0)
  X.pets[i] = p
  return p
end
function X.LayoutPet(f)
  local p = X.BuildPet(f.index, f)
  p:SetSize(s.petWidth, s.petHeight)
  p:ClearAllPoints()
  local mirror = s.mirrored
  if s.petAnchor == "below" then p:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2 - (s.castBar and s.castHeight or 0))
  elseif mirror then p:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
  else p:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 2) end
  local tex = PUI.Bars and PUI.Bars:TexturePath() or "Interface\\Buttons\\WHITE8X8"
  p.health:SetStatusBarTexture(tex)
  p.health:SetStatusBarColor(0.45, 0.62, 0.38, 1)
  if s.pets and not AR.test then RegisterUnitWatch(p) else UnregisterUnitWatch(p); p:SetShown(s.pets and AR.test == true) end
end
function X.PaintPet(i)
  local p = X.pets[i]
  if not p then return end
  if UnitExists(p.unit) then
    p.health:SetMinMaxValues(0, UnitHealthMax(p.unit)); p.health:SetValue(UnitHealth(p.unit))
    p.name:SetText(s.petNames and UnitName(p.unit) or "")
  end
end

-- Class-icon aura priority ---------------------------------------------------------------------
X.AURA_FILTERS = { cc = { "HARMFUL", "CROWD_CONTROL" }, defensive = { "HELPFUL", "BIG_DEFENSIVE" }, important = { "HELPFUL", "IMPORTANT" } }
function X.AuraOrder()
  local out = {}
  for word in tostring(s.auraOrder or ""):gmatch("[%a]+") do if X.AURA_FILTERS[word] then out[#out + 1] = word end end
  return out
end
-- TopAura(unit) -> aura data, category (the game's filters pick; no secret compare)
function X.TopAura(unit)
  for _, cat in ipairs(X.AuraOrder()) do
    local a = C_UnitAuras.GetAuraDataByIndex(unit, 1, PUI.Auras.Filter(X.AURA_FILTERS[cat][1], X.AURA_FILTERS[cat][2]))
    if a then return a, cat end
  end
end
function X.PaintAura(f)
  if not s.classAura then return nil end
  local a, cat = X.TopAura(f.unit)
  if a and a.icon ~= nil then f.spec:SetTexture(a.icon) end
  if cat and s.auraGlow then PUI.Glow:Start(f, "arena.aura") else PUI.Glow:Stop(f, "arena.aura") end
  return cat
end

-- Dispel tracker ------------------------------------------------------------------------------
-- Player dispels (spell ID -> cooldown seconds); only plain spell IDs are matched.
X.DISPELS = { [527] = 8, [88423] = 8, [4987] = 8, [115450] = 8, [77130] = 8, [360823] = 8, [2782] = 8, [213644] = 8, [365585] = 8, [51886] = 8 }
function X.BuildDispel(f)
  local d = rawget(f, "dispel")
  if d then return d end
  d = CreateFrame("Frame", nil, f)
  d.tex = d:CreateTexture(nil, "ARTWORK"); d.tex:SetAllPoints(); d.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  d.cd = CreateFrame("Cooldown", nil, d, "CooldownFrameTemplate"); d.cd:SetAllPoints()
  rawset(f, "dispel", d)
  return d
end
function X.LayoutDispel(f)
  local d = X.BuildDispel(f)
  d:SetSize(s.dispelSize, s.dispelSize)
  d:ClearAllPoints()
  local anchor = s.racial and f.racial or f.trinket
  if s.mirrored then d:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", -2, 0) else d:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 2, 0) end
  d:SetShown(s.dispelTracker and X.dispels[f.unit] ~= nil)
end
function X.OnSpell(unit, spellID)
  if not s.dispelTracker or spellID == nil or Secret.IsSecret(spellID) then return false end
  local cd = X.DISPELS[spellID]
  local f = cd and type(unit) == "string" and FR.frames[tonumber(unit:match("^arena(%d)$") or "")]
  if not f then return false end
  X.dispels[unit] = { spell = spellID, start = GetTime(), cd = cd }
  local d = X.BuildDispel(f)
  d.tex:SetTexture(C_Spell.GetSpellTexture(spellID))
  d.cd:SetCooldown(GetTime(), cd)
  d:Show()
  return true
end

-- Range ------------------------------------------------------------------------------------------
X.RANGE_SPELLS = { WARRIOR = 355, PALADIN = 62124, HUNTER = 75, ROGUE = 36554, PRIEST = 589, DEATHKNIGHT = 49576, SHAMAN = 188196,
  MAGE = 118, WARLOCK = 686, MONK = 115546, DRUID = 8921, DEMONHUNTER = 185123, EVOKER = 361469 }
function X.RangeSpell()
  local own = tonumber(s.rangeSpell) or 0
  if own > 0 then return own end
  local _, class = UnitClass("player")
  return X.RANGE_SPELLS[class]
end
function X.CheckRange()
  local spell = X.RangeSpell()
  for i, f in ipairs(FR.frames) do
    if i <= AR.Count() and UnitExists(f.unit) and spell then
      local inRange = C_Spell.IsSpellInRange(spell, f.unit)
      if inRange ~= nil then f:SetAlphaFromBoolean(inRange, 1, s.rangeAlpha) end
    end
  end
end
function X.ArmRange()
  if AR.active and AR.inArena and s.range then Ticker:Register("arena.range", 0.2, X.CheckRange, OWNER)
  else Ticker:Unregister("arena.range") end
end

-- Click actions ------------------------------------------------------------------------------------
-- ParseClicks(list) -> { { prefix, button, type, value } } (pure). Lines: "shift-2: focus", "3: spell:Polymorph".
function X.ParseClicks(list)
  local out = {}
  for _, line in ipairs(list or {}) do
    local mods, button, action = tostring(line):lower():match("^%s*([%a%-]-)(%d)%s*:%s*(.-)%s*$")
    if button then
      local kind, value = action:match("^(%a+):(.+)$")
      kind = kind or action
      if kind == "target" or kind == "focus" or kind == "none" or kind == "spell" or kind == "macro" then
        out[#out + 1] = { prefix = mods, button = button, type = kind, value = value and tostring(line):match(":%s*%a+:(.-)%s*$") }
      end
    end
  end
  return out
end
function X.ApplyClicks()
  if CQ.InCombat() then CQ.Defer("arena.clicks", X.ApplyClicks); return false end
  local rules = X.ParseClicks(s.clicks)
  for _, f in ipairs(FR.frames) do
    for _, r in ipairs(rules) do
      local key = r.prefix .. "type" .. r.button
      f:SetAttribute(key, r.type ~= "none" and r.type or nil)
      if r.type == "spell" then f:SetAttribute(r.prefix .. "spell" .. r.button, r.value)
      elseif r.type == "macro" then f:SetAttribute(r.prefix .. "macrotext" .. r.button, r.value) end
    end
  end
  return true
end

-- Text page --------------------------------------------------------------------------------------
function X.FontPath()
  local Media = PUI.Media
  local name = Schema:Get("media.uiFont")
  return Media:Path("font", name) or Media:Font(name)
end
function X.LayoutText(f)
  local path = X.FontPath()
  local outline = s.textOutline ~= "NONE" and s.textOutline or ""
  if s.nameSize > 0 then f.name:SetFont(path, s.nameSize, outline) end
  if s.hpSize > 0 then f.hp:SetFont(path, s.hpSize, outline) end
  if s.numberSize > 0 then f.number:SetFont(path, s.numberSize, outline) end
  f.name:ClearAllPoints(); f.name:SetPoint(s.nameAnchor, f.health, s.nameAnchor, s.nameAnchor == "LEFT" and 6 or s.nameAnchor == "RIGHT" and -6 or 0, 0)
  f.hp:ClearAllPoints(); f.hp:SetPoint(s.hpAnchor, f.health, s.hpAnchor, s.hpAnchor == "LEFT" and 6 or s.hpAnchor == "RIGHT" and -6 or 0, 0)
end

-- FrameSort numbering ----------------------------------------------------------------------------
function X.SortedNumber(unit)
  local api = rawget(_G, "FrameSortApi")
  local sorting = type(api) == "table" and type(api.v3) == "table" and api.v3.Sorting
  if not (s.frameSortNumbers and sorting and type(sorting.GetEnemyUnits) == "function") then return nil end
  local units = securecallfunction(sorting.GetEnemyUnits, sorting)
  if type(units) ~= "table" then return nil end
  for n, u in ipairs(units) do if u == unit then return n end end
end

-- DR 'only triggerable by me' -------------------------------------------------------------------
X.MINE_CVAR = "spellDiminishPVPOnlyTriggerableByMe"
function X.ApplyDRMine()
  if AR.active and s.drBlizzard and s.drMine then return PUI.CVars:Set(OWNER, X.MINE_CVAR, "1") end
  PUI.CVars:Restore(OWNER, X.MINE_CVAR)
  return true
end

-- Hooks into the shared paint path ---------------------------------------------------------------
local layout = FR.Layout
function FR.Layout(f, st, holder)
  layout(f, st, holder)
  X.LayoutPet(f)
  X.LayoutDispel(f)
  X.LayoutText(f)
end
local paintUnit = FR.PaintUnit
function FR.PaintUnit(f, st)
  paintUnit(f, st)
  local u = ST.Unit(f.unit)
  X.PaintAura(f)
  X.HealerGate(f, u.spec)
  X.PaintPet(f.index)
  local n = X.SortedNumber(f.unit)
  f.number:SetText(tostring(n or f.index))
end
local paintTest = AR.PaintTest
function AR.PaintTest(f, i)
  paintTest(f, i)
  local x = AR.SAMPLE[i]
  X.HealerGate(f, x.spec)
  if s.classAura and i == 1 then f.spec:SetTexture(136071) end -- sample: crowd-controlled (Polymorph art)
  local p = X.pets[i]
  if p then p.name:SetText(s.petNames and ("Pet " .. i) or ""); p.health:SetMinMaxValues(0, 1); p.health:SetValue(0.8) end
  local d = rawget(f, "dispel")
  if d and s.dispelTracker and x.class == "PRIEST" then d.tex:SetTexture(135894); d.cd:SetCooldown(GetTime() - 3, 8); d:Show() end
end

local H = AR.handlers
local onSpell = H.UNIT_SPELLCAST_SUCCEEDED
function H.UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
  onSpell(unit, castGUID, spellID)
  X.OnSpell(unit, spellID)
end
function H.UNIT_AURA(unit)
  local i = type(unit) == "string" and tonumber(unit:match("^arena(%d)$") or "")
  local f = i and FR.frames[i]
  if f and s.classAura then X.PaintAura(f) end
end
local health = H.UNIT_HEALTH
function H.UNIT_HEALTH(unit)
  local i = type(unit) == "string" and tonumber(unit:match("^arenapet(%d)$") or "")
  if i then X.PaintPet(i) else health(unit) end
end
H.UNIT_MAXHEALTH = H.UNIT_HEALTH
AR.ARENA_EVENTS[#AR.ARENA_EVENTS + 1] = "UNIT_AURA"
AR.ARENA_EVENTS[#AR.ARENA_EVENTS + 1] = "UNIT_PET"
function H.UNIT_PET(unit)
  local i = type(unit) == "string" and tonumber(unit:match("^arena(%d)$") or "")
  if i then X.PaintPet(i) end
end
local onZone = AR.OnZone
function AR.OnZone()
  onZone()
  if not AR.inArena then wipe(X.dispels) end
  X.ArmRange()
end
PUI.Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then X.ApplyDRMine(); X.ApplyClicks() end end)
PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then X.ApplyDRMine(); Ticker:Unregister("arena.range") end end)

local function key(name, def, page)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v)
    s[name] = v
    if name == "drMine" or name == "drBlizzard" then X.ApplyDRMine() end
    if name == "clicks" then X.ApplyClicks() end
    if name == "range" then X.ArmRange(); if not v then for _, f in ipairs(FR.frames) do f:SetAlpha(1) end end end
    AR.Refresh()
  end
  def.searchTags = page and { page } or nil
  AR.schema["arena." .. name] = def
  Schema:Register("arena." .. name, def)
  s[name] = Schema:Get("arena." .. name)
end
key("pets", { type = "toggle", default = true, label = "Pet frames", mode = "simple", tooltip = "A small frame for each enemy pet (click to target, right-click to focus)." }, "pets")
key("petWidth", { type = "range", default = 90, min = 40, max = 200, step = 2, label = "Pet frame width", tooltip = "Width of each pet frame." }, "pets")
key("petHeight", { type = "range", default = 14, min = 8, max = 30, step = 1, label = "Pet frame height", tooltip = "Height of each pet frame." }, "pets")
key("petAnchor", { type = "select", default = "above", choices = { "above", "below" }, choiceLabels = { above = "Above the frame (outer corner)", below = "Below the frame" }, label = "Pet frame position", tooltip = "Where each pet frame sits." }, "pets")
key("petNames", { type = "toggle", default = true, label = "Pet names", tooltip = "Writes the pet's name on its bar (the game may hide some)." }, "pets")
key("classAura", { type = "toggle", default = true, label = "Aura on the class icon", mode = "simple", tooltip = "The spec icon shows the enemy's most important aura while it lasts (crowd control, big defensive or important, in your order)." }, "aura")
key("auraOrder", { type = "text", default = "cc defensive important", label = "Aura priority", tooltip = "Order of categories, highest first. Words: cc, defensive, important. Leave one out to never show it (\"cc\" alone shows only crowd control)." }, "aura")
key("auraGlow", { type = "toggle", default = false, label = "Glow while an aura shows", tooltip = "Adds a glow around the frame while the class icon shows an aura." }, "aura")
key("dispelTracker", { type = "toggle", default = true, label = "Dispel tracker", mode = "simple", tooltip = "After an enemy is seen dispelling, shows their dispel with its cooldown. Only dispels the game reports plainly are seen." }, "dispel")
key("dispelSize", { type = "range", default = 20, min = 12, max = 40, step = 1, label = "Dispel icon size", tooltip = "Size of the dispel icon." }, "dispel")
key("range", { type = "toggle", default = true, label = "Fade when out of range", mode = "simple", tooltip = "Fades an enemy's frame while your range spell cannot reach them." }, "range")
key("rangeAlpha", { type = "range", default = 0.45, min = 0.1, max = 1, step = 0.05, label = "Out-of-range opacity", tooltip = "How faded an out-of-range enemy is." }, "range")
key("rangeSpell", { type = "text", default = "", label = "Range spell ID", tooltip = "Spell used to check range. Empty uses a ranged spell of your class." }, "range")
key("clicks", { type = "list", default = { "1: target", "2: focus" }, label = "Click actions", tooltip = "One line per click: \"1: target\", \"2: focus\", \"shift-1: spell:Polymorph\", \"ctrl-3: macro:/cast [@arena1] Kick\", \"3: none\". Applied when you leave combat." }, "clicks")
key("nameSize", { type = "range", default = 0, min = 0, max = 24, step = 1, label = "Name size", tooltip = "Font size of names. 0 uses the font setting." }, "text")
key("nameAnchor", { type = "select", default = "LEFT", choices = { "LEFT", "CENTER", "RIGHT" }, choiceLabels = { LEFT = "Left", CENTER = "Centre", RIGHT = "Right" }, label = "Name position", tooltip = "Where the name sits on the health bar." }, "text")
key("hpSize", { type = "range", default = 0, min = 0, max = 24, step = 1, label = "Health text size", tooltip = "Font size of the health text. 0 uses the font setting." }, "text")
key("hpAnchor", { type = "select", default = "RIGHT", choices = { "LEFT", "CENTER", "RIGHT" }, choiceLabels = { LEFT = "Left", CENTER = "Centre", RIGHT = "Right" }, label = "Health text position", tooltip = "Where the health text sits." }, "text")
key("numberSize", { type = "range", default = 0, min = 0, max = 24, step = 1, label = "Arena number size", tooltip = "Font size of the arena number. 0 uses the default." }, "text")
key("textOutline", { type = "select", default = "NONE", choices = { "NONE", "OUTLINE", "THICKOUTLINE" }, choiceLabels = { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick outline" }, label = "Text outline", tooltip = "Outline for the texts with a size set here." }, "text")
key("frameSortNumbers", { type = "toggle", default = true, label = "Numbers follow FrameSort", tooltip = "With FrameSort loaded, the arena numbers follow its sorted enemy order (matching its EnemyFrame macros)." }, "text")
key("drMine", { type = "toggle", default = false, label = "Only DR I can trigger", tooltip = "Asks the game to show only DR categories your own spells can cause (needs DR tracking on). Your old value comes back when off." }, "dr")
key("trinketHealerOnly", { type = "toggle", default = false, label = "Trinket for healers only", tooltip = "Shows the trinket only on enemy healers (needs their spec, known from the preparation phase)." }, "healer")
key("drHealerOnly", { type = "toggle", default = false, label = "DR tray for healers only", tooltip = "Shows the DR tray only on enemy healers." }, "healer")
key("castHealerOnly", { type = "toggle", default = false, label = "Cast bar for healers only", tooltip = "Shows the cast bar only on enemy healers." }, "healer")
