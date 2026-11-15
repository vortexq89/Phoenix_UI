local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Nameplates, deferred batch A (docs/DEFERRED.md): compact totem / pet plates,
-- range fade, "interrupted by <name>", NPC subtitles and quest objective text,
-- clickable area and click-through (C_NamePlateManager hit-test insets),
-- friendly plates through the CVar ledger, hover highlight, important-aura,
-- pandemic and purge borders drawn by the aura engine, pool pre-warm, rule
-- conditions (classification, reaction, casting, any NPC) and rule packs,
-- Blizzard plate suppression, and element slots (drag-slot editor in the
-- preview). Every part is a setting with a simple/advanced view and applies
-- live. Secret values are only handed to widgets (SetAlphaFromBoolean,
-- SetText); Lua never compares them.
local _, ns = ...
local NP, P, R = ns.NP, ns.Plate, ns.Rules
local Schema, Secret, Ticker, CQ, Kernel = PUI.Schema, PUI.Secret, PUI.Ticker, PUI.CombatQueue, PUI.Kernel
local OWNER = "Nameplates"
local s = NP.settings
local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
local function rgb(r, g, b) return { r = r, g = g, b = b } end

local X = {}
NP.Extras = X

s.compact = { totems = true, pets = true, scale = 0.6, hideName = true }
s.range = { enabled = false, alpha = 0.45, spell = 0 }
s.interrupt = { enabled = true, seconds = 2, classColor = true }
s.npc = { subtitle = true, quest = false, questColor = rgb(1, 0.82, 0.1) }
s.click = { enemyX = 0, enemyY = 0, friendlyX = 0, friendlyY = 0, enemyThrough = false, friendlyThrough = false, friendlyShow = "game" }
s.hover = { enabled = true, color = rgb(1, 1, 1), alpha = 0.35 }
s.auraGlow = { important = true, importantColor = rgb(1, 0.33, 0.41), pandemic = true, pandemicColor = rgb(1, 0.82, 0.1),
  purge = true, purgeColor = rgb(0.36, 0.7, 1) }
s.pool = { prewarm = 10 }
s.blizzard = { suppress = "alpha" }
s.slots = { name = "default", healthText = "default", forces = "default", marker = "default", classification = "default", quest = "default" }

-- Unit kinds ------------------------------------------------------------------
-- "totem" / "pet" / nil. Only plain answers count; a secret answer is "normal".
local TOTEM = rawget(_G, "TOTEM") or "Totem"
function X.Kind(unit)
  if not unit then return nil end
  local isPlayer = UnitIsPlayer(unit)
  if plain(isPlayer) and isPlayer then return nil end
  local ctype = UnitCreatureType(unit)
  if plain(ctype) and ctype == TOTEM then return "totem" end
  local controlled = UnitPlayerControlled(unit)
  if plain(controlled) and controlled then return "pet" end
  return nil
end

function X.CompactFactor(f)
  local kind = rawget(f, "kind")
  if kind == "totem" and s.compact.totems then return s.compact.scale end
  if kind == "pet" and s.compact.pets then return s.compact.scale end
  return 1
end

-- The plate's own scale (target size and rule scale) times the compact factor.
function X.ApplyScale(f)
  local base = (f.isTarget and s.target.scale or 1) * (f.rule and f.rule.scale or 1)
  f:SetScale(base * X.CompactFactor(f))
  if X.CompactFactor(f) < 1 and s.compact.hideName then f.name:Hide() end
end

-- Element slots -------------------------------------------------------------------
X.SLOT_ELEMENTS = { "name", "healthText", "forces", "marker", "classification", "quest" }
X.SLOT_LABELS = { name = "Name", healthText = "Health text", forces = "M+ forces", marker = "Raid marker",
  classification = "Elite / rare icon", quest = "Quest icon" }
X.SLOT_ZONES = { "default", "top", "bottom", "left", "right", "inside", "hidden" }
X.SLOT_ZONE_LABELS = { default = "Phoenix standard place", top = "Above the bar", bottom = "Below the bar", left = "Left of the bar", right = "Right of the bar",
  inside = "Inside the bar", hidden = "Hidden" }
local function region(f, el)
  if el == "name" then return f.name elseif el == "healthText" then return f.hp elseif el == "forces" then return f.forces
  elseif el == "marker" then return f.marker elseif el == "classification" then return f.classif else return f.quest end
end
local ZONE_POINT = {
  top = { "BOTTOM", "TOP", 0, 2 }, bottom = { "TOP", "BOTTOM", 0, -2 }, left = { "RIGHT", "LEFT", -3, 0 },
  right = { "LEFT", "RIGHT", 3, 0 }, inside = { "CENTER", "CENTER", 0, 0 },
}
-- Stacks elements that share a zone so they never overlap.
function X.ApplySlots(f)
  if f.nameOnly then return end
  local used = {}
  for _, el in ipairs(X.SLOT_ELEMENTS) do
    local zone, r = s.slots[el], region(f, el)
    if r then
      if zone == "default" then
        r:SetAlpha(1) -- the plate's own layout placed it
      elseif zone == "hidden" then
        r:SetAlpha(0)
      else
        local p = ZONE_POINT[zone] or ZONE_POINT.top
        local n = used[zone] or 0
        used[zone] = n + 1
        local dx, dy = 0, 0
        if zone == "top" then dy = n * 14 elseif zone == "bottom" then dy = -n * 14
        elseif zone == "left" then dx = -n * 18 elseif zone == "right" then dx = n * 18 end
        r:ClearAllPoints()
        r:SetPoint(p[1], f.health, p[2], p[3] + dx, p[4] + dy)
        r:SetAlpha(1)
      end
    end
  end
end

-- NPC subtitle and quest objective text (C_TooltipInfo, cached per NPC id) ---------
X.subCache = {}
local LINE = Enum.TooltipDataLineType or {}
function X.TooltipLines(unit)
  local data = C_TooltipInfo.GetUnit(unit)
  local sub, quest = nil, nil
  if type(data) ~= "table" or type(data.lines) ~= "table" then return nil, nil end
  for i, line in ipairs(data.lines) do
    local t, text = line.type, line.leftText
    if i == 2 and plain(text) and plain(t) and t ~= LINE.QuestObjective and not text:find("%d") then sub = text end
    if plain(t) and t == LINE.QuestObjective and quest == nil then quest = text end -- may be secret: only shown
  end
  return sub, quest
end

function X.UpdateNpcText(f)
  local fs = rawget(f, "npcText")
  if not fs then return end
  local unit = f.unit
  local isPlayer = unit and UnitIsPlayer(unit)
  if not unit or (plain(isPlayer) and isPlayer) or not (s.npc.subtitle or s.npc.quest) then fs:Hide() return end
  local id = UnitCreatureID and UnitCreatureID(unit)
  local cached = plain(id) and X.subCache[id]
  local sub, quest
  if cached and not s.npc.quest then sub = cached ~= false and cached or nil
  else
    sub, quest = X.TooltipLines(unit)
    if plain(id) then X.subCache[id] = sub or false end
  end
  if s.npc.quest and quest ~= nil then
    fs:SetText(quest)
    fs:SetTextColor(s.npc.questColor.r, s.npc.questColor.g, s.npc.questColor.b)
    fs:Show()
  elseif s.npc.subtitle and sub then
    fs:SetFormattedText("<%s>", sub)
    fs:SetTextColor(0.75, 0.75, 0.75)
    fs:Show()
  else
    fs:Hide()
  end
end

-- Interrupted by <name> -----------------------------------------------------------
function X.OnInterrupted(f, interruptedBy)
  local fs = rawget(f, "interruptText")
  if not (fs and s.interrupt.enabled) or interruptedBy == nil then return end
  local name = UnitNameFromGUID(interruptedBy)
  if name == nil then return end
  fs:SetFormattedText("Interrupted by %s", name) -- a secret name is drawn by the engine, never compared
  if s.interrupt.classColor then
    local _, class = GetPlayerInfoByGUID(interruptedBy)
    local c = plain(class) and C_ClassColor.GetClassColor(class)
    if c then fs:SetTextColor(c.r, c.g, c.b) else fs:SetTextColor(1, 1, 1) end
  end
  fs:Show()
  f.interruptToken = (rawget(f, "interruptToken") or 0) + 1
  local token = f.interruptToken
  C_Timer.After(s.interrupt.seconds, function() if f.interruptToken == token then fs:Hide() end end)
end

-- Range fade (enemies; line of sight has no API in 12.x) ---------------------------
function X.RangeSpell()
  if s.range.spell and s.range.spell > 0 then return s.range.spell end
  return PUI.CastBar.Kick.spellID
end
function X.UpdateRange(f)
  if not (s.range.enabled and f.unit and not f.nameOnly) then
    f.health:SetAlpha(1)
    return
  end
  local spell = X.RangeSpell()
  if not spell then f.health:SetAlpha(1) return end
  local inRange = C_Spell.IsSpellInRange(spell, f.unit)
  if inRange == nil then f.health:SetAlpha(1) return end
  f.health:SetAlphaFromBoolean(inRange, 1, s.range.alpha)
  f.name:SetAlphaFromBoolean(inRange, 1, s.range.alpha)
end
function X.ArmRange()
  if s.range.enabled and NP.active then
    Ticker:Register("np.range", 0.25, function() NP.ForAll(X.UpdateRange) end, OWNER)
  else
    Ticker:Unregister("np.range")
    NP.ForAll(X.UpdateRange)
  end
end

-- Hover highlight ---------------------------------------------------------------------
function X.UpdateHover(f)
  local h = rawget(f, "hoverTex")
  if not h then return end
  if not (s.hover.enabled and f.unit and not f.nameOnly) then h:SetAlpha(0) return end
  h:SetColorTexture(s.hover.color.r, s.hover.color.g, s.hover.color.b, 1)
  h:SetAlphaFromBoolean(UnitIsUnit("mouseover", f.unit), s.hover.alpha, 0)
end
function X.OnMouseoverChanged()
  NP.ForAll(X.UpdateHover)
  -- the game has no "mouseover left" event: one Ticker entry clears it, then stops
  Ticker:Register("np.hover", 0.1, function()
    local e = UnitExists("mouseover")
    if plain(e) and e then return end
    NP.ForAll(X.UpdateHover)
    Ticker:Unregister("np.hover")
  end, OWNER)
end

-- Aura borders drawn by the engine ---------------------------------------------------
local function colorMap(c)
  local m = {}
  for _, k in ipairs({ "None", "Magic", "Curse", "Disease", "Poison", "Enrage", "Bleed" }) do m[k] = { r = c.r, g = c.g, b = c.b } end
  return m
end
X.pandemicCurve = nil
function X.PandemicOptions()
  if not s.auraGlow.pandemic then return nil end
  local curve = C_CurveUtil.CreateColorCurve()
  if curve.SetType and Enum.LuaCurveType then curve:SetType(Enum.LuaCurveType.Step) end
  local pc = s.auraGlow.pandemicColor
  curve:AddPoint(0, CreateColor(pc.r, pc.g, pc.b, 1))
  curve:AddPoint(0.3, CreateColor(1, 1, 1, 1)) -- the last 30 % of a debuff is the refresh (pandemic) window
  X.pandemicCurve = curve
  return { textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingPercent } }
end
function X.ConfigureAuraBorders(f)
  if not f.lanes then return end
  local g = s.auraGlow
  local style = Enum.CustomAuraButtonDispelTypeTextureStyle
  local debuffs, buffs, cc = f.lanes.debuffs, f.lanes.buffs, f.lanes.cc
  debuffs:SetButtonOptions("debuffs", "durationText", X.PandemicOptions())
  buffs:SetButtonOptions("buffs", "dispelTexture", g.purge and {
    showAlways = false, showWhenHelpful = true, showWhenHarmful = false, showWithoutDispelType = true,
    stealableFilter = Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable, style = style.Border,
    customDispelColorMap = colorMap(g.purgeColor) } or nil)
  cc:SetButtonOptions("cc", "dispelTexture", g.important and {
    showAlways = true, style = style.Border, customDispelColorMap = colorMap(g.importantColor) } or nil)
  -- important buffs lane: when it shows important buffs only, every icon gets the border
  if g.important and s.auras.buffs.filter == "important" and not g.purge then
    buffs:SetButtonOptions("buffs", "dispelTexture", { showAlways = true, style = style.Border, customDispelColorMap = colorMap(g.importantColor) })
  end
end

-- Hit-test insets, click-through and the friendly-plates CVar ----------------------------
X.savedInsets = nil
local function insetsFor(kind)
  local cx, cy, through
  if kind == "enemy" then cx, cy, through = s.click.enemyX, s.click.enemyY, s.click.enemyThrough
  else cx, cy, through = s.click.friendlyX, s.click.friendlyY, s.click.friendlyThrough end
  if through then return 10000, 10000, 10000, 10000 end -- collapsed: clicks fall through to the world
  return -cx, -cx, -cy, -cy -- negative insets grow the clickable area, positive shrink it
end
X.insetsFor = insetsFor
function X.ApplyClicks()
  CQ.Defer("np.insets", function()
    local T = Enum.NamePlateType
    if not T then return end
    local M = C_NamePlateManager
    if not X.savedInsets then
      X.savedInsets = {}
      for kind, id in pairs({ enemy = T.Enemy, friendly = T.Friendly }) do X.savedInsets[kind] = { M.GetNamePlateHitTestInsets(id) } end
    end
    for kind, id in pairs({ enemy = T.Enemy, friendly = T.Friendly }) do
      if NP.active then
        local cx = kind == "enemy" and s.click.enemyX or s.click.friendlyX
        local cy = kind == "enemy" and s.click.enemyY or s.click.friendlyY
        local through = kind == "enemy" and s.click.enemyThrough or s.click.friendlyThrough
        if cx ~= 0 or cy ~= 0 or through then M.SetNamePlateHitTestInsets(id, insetsFor(kind))
        else M.SetNamePlateHitTestInsets(id, unpack(X.savedInsets[kind])) end
      else
        M.SetNamePlateHitTestInsets(id, unpack(X.savedInsets[kind]))
      end
    end
    if not NP.active then X.savedInsets = nil end
    local show = s.click.friendlyShow
    if NP.active and show ~= "game" then PUI.CVars:Set(OWNER, "nameplateShowFriends", show == "on" and "1" or "0")
    else PUI.CVars:Restore(OWNER, "nameplateShowFriends") end
  end)
end

-- Blizzard plate suppression ------------------------------------------------------------
X.hooked = setmetatable({}, { __mode = "k" })
function X.Suppress(f)
  local blizz = f.plate and f.plate.UnitFrame
  if not blizz then return end
  if s.blizzard.suppress == "hide" then
    if not X.hooked[blizz] then
      X.hooked[blizz] = true
      hooksecurefunc(blizz, "Show", function(self) if rawget(self, "phoenixHidden") then self:Hide() end end)
    end
    blizz.phoenixHidden = true
    blizz:Hide()
  end
end
function X.Unsuppress(plate)
  local blizz = plate and plate.UnitFrame
  if blizz and rawget(blizz, "phoenixHidden") then blizz.phoenixHidden = nil; blizz:Show() end
end

-- Pool pre-warm (out of combat, once per enable / setting change) ----------------------------
function X.Prewarm()
  CQ.Defer("np.prewarm", function()
    local live = 0
    for _ in pairs(NP.plates) do live = live + 1 end
    while #P.pool + live < s.pool.prewarm do P.pool[#P.pool + 1] = P.Build() end
  end)
end

-- Per-plate widgets (built lazily on the pooled frame) ------------------------------------
function X.Ensure(f)
  if rawget(f, "npcText") then return end
  local path, size, flags = f.sub:GetFont()
  f.npcText = f:CreateFontString(nil, "OVERLAY")
  if path then f.npcText:SetFont(path, size, flags) else f.npcText:SetFontObject("GameFontNormalSmall") end
  f.npcText:SetPoint("TOP", f.name, "BOTTOM", 0, -1)
  f.npcText:Hide()
  f.interruptText = f:CreateFontString(nil, "OVERLAY")
  if path then f.interruptText:SetFont(path, size, flags) else f.interruptText:SetFontObject("GameFontNormalSmall") end
  f.interruptText:SetPoint("TOP", f.health, "BOTTOM", 0, -16)
  f.interruptText:Hide()
  f.hoverTex = f.health:CreateTexture(nil, "OVERLAY")
  f.hoverTex:SetAllPoints(f.health)
  f.hoverTex:SetBlendMode("ADD")
  f.hoverTex:SetAlpha(0)
end

function X.Update(f)
  X.Ensure(f)
  f.kind = X.Kind(f.unit)
  X.ApplySlots(f)
  X.ApplyScale(f)
  X.UpdateNpcText(f)
  X.UpdateHover(f)
  X.UpdateRange(f)
  X.ConfigureAuraBorders(f)
end

-- Wiring into Plate / NP ------------------------------------------------------------
local baseUpdateAll, baseUpdateTarget, baseAdd, baseRemove = P.UpdateAll, P.UpdateTarget, NP.Add, NP.Remove
function P.UpdateAll(f, st) baseUpdateAll(f, st); if f.unit then X.Update(f) end end
function P.UpdateTarget(f, st) baseUpdateTarget(f, st); if f.unit then X.ApplyScale(f) end end
function NP.Add(unit)
  baseAdd(unit)
  local f = NP.plates[unit]
  if f then X.Suppress(f) end
end
function NP.Remove(unit)
  local f = NP.plates[unit]
  local plate = f and f.plate
  if f and rawget(f, "interruptText") then f.interruptText:Hide() end
  baseRemove(unit)
  X.Unsuppress(plate)
end

-- the dispatcher passes only the plate; route the event's interruptedBy argument here
X.dispatchFrame = PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
X.dispatchFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "UPDATE_MOUSEOVER_UNIT" then X.OnMouseoverChanged() return end
  if event == "UNIT_SPELLCAST_INTERRUPTED" then
    local unit, _, _, by = ...
    local f = type(unit) == "string" and NP.plates[unit]
    if f then X.OnInterrupted(f, by) end
  end
end)
function X.Track()
  local d = X.dispatchFrame
  d:UnregisterAllEvents()
  if not NP.active then return end
  if s.hover.enabled then d:RegisterEvent("UPDATE_MOUSEOVER_UNIT") end
  if s.interrupt.enabled then d:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED") end
end

Kernel:On("MODULE_ENABLED", function(name)
  if name ~= OWNER then return end
  X.Track(); X.ArmRange(); X.ApplyClicks(); X.Prewarm()
end)
Kernel:On("MODULE_DISABLED", function(name)
  if name ~= OWNER then return end
  X.Track(); X.ArmRange(); X.ApplyClicks()
  Ticker:Unregister("np.hover")
end)

-- Rule conditions and packs (Rules.lua grows here so the parser stays in one place) ---------
R.CONDITIONS = { elite = "classification", rare = "classification", rareelite = "classification", worldboss = "classification",
  minus = "classification", normal = "classification", hostile = "reaction", neutral = "reaction", friendly = "reaction",
  casting = "casting" }
local baseParse = R.Parse
function R.Parse(line)
  if type(line) ~= "string" then return nil, "not text" end
  local conds, kept = {}, {}
  local parts = {}
  for p in (line .. ":"):gmatch("([^:]*):") do parts[#parts + 1] = p:match("^%s*(.-)%s*$") end
  for i, p in ipairs(parts) do
    if i > 2 and R.CONDITIONS[p] then conds[#conds + 1] = p else kept[#kept + 1] = p end
  end
  local any = kept[1] == "*"
  if any then kept[1] = "0" end
  local rule, why = baseParse(table.concat(kept, ":"))
  if not rule then return nil, why end
  if any then rule.id, rule.any = nil, true end
  if #conds > 0 then rule.conds = conds end
  if any and #conds == 0 then return nil, "'*' (any NPC) needs a condition such as elite, hostile or casting" end
  return rule
end
local baseLabel = R.Label
function R.Label(line)
  local rule = R.Parse(line)
  if not rule then return line end
  local text = rule.any and "Any NPC - custom colour" or baseLabel((line:gsub(":(%a+)", function(w) if R.CONDITIONS[w] then return "" end end)))
  if rule.conds then text = text .. " (only when " .. table.concat(rule.conds, ", ") .. ")" end
  return text
end
R.packs, R.enabledPacks = {}, {}
-- RegisterPack(id, label, lines): a named rule list a data pack ships (PUI.Packs).
function R.RegisterPack(id, label, lines)
  R.packs[id] = { label = label, lines = lines }
  if PUI.Packs then PUI.Packs:Register("np.rules." .. id, { packVersion = "2026-10-27", gameBuild = "12.1.0", data = lines }) end
end
local baseCompile = R.Compile
function R.Compile(list)
  local all = {}
  for i = 1, #(list or {}) do all[#all + 1] = list[i] end
  for _, id in ipairs(R.enabledPacks) do
    local p = R.packs[id]
    for _, l in ipairs(p and p.lines or {}) do all[#all + 1] = l end
  end
  local n = baseCompile(all)
  R.any = {}
  for i = 1, #all do
    local rule = R.Parse(all[i])
    if rule then
      rule.index = i
      if rule.any then R.any[#R.any + 1] = rule; n = n + 1
      elseif rule.conds then
        -- keyed rules with conditions replace the plain entry the base compiler stored
        if rule.id and R.byID[rule.id] and R.byID[rule.id].index == i then R.byID[rule.id] = rule end
        if rule.name and R.byName[rule.name] and R.byName[rule.name].index == i then R.byName[rule.name] = rule end
      end
    end
  end
  R.count = n
  return n
end
-- Condition check; secret answers never match.
function R.Holds(rule, unit, f)
  if not rule.conds then return true end
  for _, c in ipairs(rule.conds) do
    local kind = R.CONDITIONS[c]
    if kind == "classification" then
      local v = UnitClassification(unit)
      if not (plain(v) and v == c) then return false end
    elseif kind == "reaction" then
      local r = UnitReaction(unit, "player")
      if not plain(r) then return false end
      local got = r <= 3 and "hostile" or (r == 4 and "neutral" or "friendly")
      if got ~= c then return false end
    elseif kind == "casting" then
      if not (f and f.casting) then return false end
    end
  end
  return true
end
local baseMatch = R.Match
function R.Match(unit, f)
  if R.count == 0 then return nil end
  local rule = baseMatch(unit)
  if rule and R.Holds(rule, unit, f) then return rule end
  for _, r in ipairs(R.any or {}) do if R.Holds(r, unit, f) then return r end end
  return nil
end
-- casting rules re-check when a cast starts or stops
local baseCastExtras = P.UpdateCastExtras
function P.UpdateCastExtras(f, st)
  baseCastExtras(f, st)
  if R.any and f.unit then
    local was = f.rule
    f.rule = R.Match(f.unit, f) or false
    if was ~= f.rule then P.UpdateColor(f, st); X.ApplyScale(f) end
  end
end

-- Schema ---------------------------------------------------------------------------
local function copyColor(c) return { r = c.r, g = c.g, b = c.b } end
X.KEYS = {}
local function key(name, def, set, after)
  def.owner = OWNER
  def.apply = function(value)
    set(value)
    if after then after(value) end
    NP.RefreshAll()
    Kernel:Fire("NP_SETTINGS")
  end
  NP.schema["np." .. name] = def
  Schema:Register("np." .. name, def)
  X.KEYS[#X.KEYS + 1] = "np." .. name
end
local function at(tbl, k) return function(v) tbl[k] = v end end

key("compact.totems", { type = "toggle", default = true, label = "Small plates for totems",
  tooltip = "Totems get a smaller plate so they never crowd real enemies.", mode = "simple", searchTags = { "totem", "compact", "small" } },
  at(s.compact, "totems"))
key("compact.pets", { type = "toggle", default = true, label = "Small plates for pets and guardians",
  tooltip = "Pets, guardians and other summons controlled by players get a smaller plate.", mode = "simple", searchTags = { "pet", "guardian", "compact" } },
  at(s.compact, "pets"))
key("compact.scale", { type = "range", default = 0.6, min = 0.3, max = 1, step = 0.05, label = "Small plate size",
  tooltip = "Size of totem and pet plates compared with a normal plate.", mode = "advanced" }, at(s.compact, "scale"))
key("compact.hideName", { type = "toggle", default = true, label = "Hide names on small plates",
  tooltip = "Totem and pet plates show only their bar.", mode = "advanced" }, at(s.compact, "hideName"))

key("range.enabled", { type = "toggle", default = false, label = "Fade enemies out of range",
  tooltip = "Enemy plates fade when they are out of range of your interrupt (or the spell you pick below). The game has no line-of-sight check for addons, so plates behind walls stay as they are.",
  mode = "simple", overridable = true, searchTags = { "range", "distance", "fade" } }, at(s.range, "enabled"), function() X.ArmRange() end)
key("range.alpha", { type = "range", default = 0.45, min = 0.1, max = 1, step = 0.05, label = "Out-of-range opacity",
  tooltip = "How visible an out-of-range enemy plate stays.", mode = "advanced", overridable = true }, at(s.range, "alpha"))
key("range.spell", { type = "range", default = 0, min = 0, max = 2000000, step = 1, label = "Range spell ID",
  tooltip = "The spell whose range is checked. 0 uses your interrupt.", mode = "advanced" }, at(s.range, "spell"))

key("interrupt.enabled", { type = "toggle", default = true, label = "Show who interrupted a cast",
  tooltip = "After an enemy's cast is interrupted, the plate shows \"Interrupted by <name>\" for a moment.", mode = "simple",
  searchTags = { "kick", "interrupt", "who" } }, at(s.interrupt, "enabled"), function() X.Track() end)
key("interrupt.seconds", { type = "range", default = 2, min = 0.5, max = 5, step = 0.5, label = "Interrupted-by time",
  tooltip = "How long the line stays (seconds).", mode = "advanced" }, at(s.interrupt, "seconds"))
key("interrupt.classColor", { type = "toggle", default = true, label = "Class colour for the interrupter",
  tooltip = "Colours the name by the interrupter's class.", mode = "advanced" }, at(s.interrupt, "classColor"))

key("npc.subtitle", { type = "toggle", default = true, label = "NPC titles",
  tooltip = "Shows an NPC's title, such as <Innkeeper> or <Flight Master>, under its name.", mode = "simple",
  searchTags = { "subtitle", "title", "npc" } }, at(s.npc, "subtitle"))
key("npc.quest", { type = "toggle", default = false, label = "Quest objective text",
  tooltip = "Shows your quest progress for an enemy, such as \"Void Acolytes slain: 3/8\", under its name.", mode = "simple",
  searchTags = { "quest", "objective", "progress" } }, at(s.npc, "quest"))
key("npc.questColor", { type = "color", default = copyColor(s.npc.questColor), label = "Quest objective colour",
  tooltip = "Colour of the quest progress text.", mode = "advanced" }, at(s.npc, "questColor"))

for _, side in ipairs({ { "enemy", "Enemy" }, { "friendly", "Friendly" } }) do
  key("click." .. side[1] .. "X", { type = "range", default = 0, min = -40, max = 40, step = 1, label = side[2] .. " clickable area: width",
    tooltip = "Grows (positive) or shrinks (negative) the clickable area left and right of " .. side[1] .. " plates.", mode = "advanced",
    searchTags = { "hitbox", "click", "insets" } }, at(s.click, side[1] .. "X"), function() X.ApplyClicks() end)
  key("click." .. side[1] .. "Y", { type = "range", default = 0, min = -20, max = 20, step = 1, label = side[2] .. " clickable area: height",
    tooltip = "Grows (positive) or shrinks (negative) the clickable area above and below " .. side[1] .. " plates.", mode = "advanced",
    searchTags = { "hitbox", "click", "insets" } }, at(s.click, side[1] .. "Y"), function() X.ApplyClicks() end)
  key("click." .. side[1] .. "Through", { type = "toggle", default = false, label = side[2] .. " plates are click-through",
    tooltip = "Clicks pass through " .. side[1] .. " plates to the world. Your old clickable area comes back when this is off.",
    mode = side[1] == "friendly" and "simple" or "advanced", searchTags = { "click through", "hitbox" } },
    at(s.click, side[1] .. "Through"), function() X.ApplyClicks() end)
end
key("click.friendlyShow", { type = "select", default = "game", choices = { "game", "on", "off" },
  choiceLabels = { game = "Keep the game's setting", on = "Always show friendly plates", off = "Never show friendly plates" },
  label = "Friendly plates", tooltip = "Turns the game's friendly nameplates on or off for you. Your own value comes back when Phoenix nameplates turn off.",
  mode = "simple", searchTags = { "cvar", "friendly", "show" } }, at(s.click, "friendlyShow"), function() X.ApplyClicks() end)

key("hover.enabled", { type = "toggle", default = true, label = "Highlight the plate under the mouse",
  tooltip = "Brightens the plate you are pointing at.", mode = "simple", searchTags = { "mouseover", "hover" } },
  at(s.hover, "enabled"), function() X.Track() end)
key("hover.color", { type = "color", default = copyColor(s.hover.color), label = "Hover colour",
  tooltip = "Colour added to the hovered plate.", mode = "advanced" }, at(s.hover, "color"))
key("hover.alpha", { type = "range", default = 0.35, min = 0.05, max = 1, step = 0.05, label = "Hover strength",
  tooltip = "How strong the hover highlight is.", mode = "advanced" }, at(s.hover, "alpha"))

key("auraGlow.important", { type = "toggle", default = true, label = "Border important auras",
  tooltip = "Crowd control and important buffs get a coloured border so they stand out from the rest.", mode = "simple",
  searchTags = { "aura", "glow", "important", "border" } }, at(s.auraGlow, "important"))
key("auraGlow.importantColor", { type = "color", default = copyColor(s.auraGlow.importantColor), label = "Important aura border colour",
  tooltip = "Border colour for important auras.", mode = "advanced" }, at(s.auraGlow, "importantColor"))
key("auraGlow.pandemic", { type = "toggle", default = true, label = "Pandemic colour on your debuffs",
  tooltip = "Your debuff timers change colour in the last 30 % of their duration, when refreshing loses nothing.", mode = "simple",
  searchTags = { "pandemic", "refresh", "dot" } }, at(s.auraGlow, "pandemic"))
key("auraGlow.pandemicColor", { type = "color", default = copyColor(s.auraGlow.pandemicColor), label = "Pandemic colour",
  tooltip = "Timer colour inside the refresh window.", mode = "advanced" }, at(s.auraGlow, "pandemicColor"))
key("auraGlow.purge", { type = "toggle", default = true, label = "Border buffs you can purge",
  tooltip = "Enemy buffs you can purge, steal or soothe get a coloured border.", mode = "simple",
  searchTags = { "purge", "steal", "dispel", "soothe" } }, at(s.auraGlow, "purge"))
key("auraGlow.purgeColor", { type = "color", default = copyColor(s.auraGlow.purgeColor), label = "Purge border colour",
  tooltip = "Border colour for purgeable buffs.", mode = "advanced" }, at(s.auraGlow, "purgeColor"))

key("pool.prewarm", { type = "range", default = 10, min = 0, max = 40, step = 1, label = "Plates made ahead of time",
  tooltip = "Phoenix builds this many plates out of combat so big pulls never build frames mid-fight.", mode = "advanced",
  searchTags = { "performance", "pool" } }, at(s.pool, "prewarm"), function() if NP.active then X.Prewarm() end end)

key("blizzard.suppress", { type = "select", default = "alpha", choices = { "alpha", "hide" },
  choiceLabels = { alpha = "Make it invisible (safest)", hide = "Hide it completely (saves a little work)" },
  label = "Blizzard's own plate", tooltip = "How Phoenix keeps the game's plate out of sight under its own. It always comes back when Phoenix lets the plate go.",
  mode = "advanced", searchTags = { "blizzard", "driver" } }, at(s.blizzard, "suppress"))

for _, el in ipairs(X.SLOT_ELEMENTS) do
  key("slots." .. el, { type = "select", default = s.slots[el], choices = X.SLOT_ZONES, choiceLabels = X.SLOT_ZONE_LABELS,
    label = "Place: " .. X.SLOT_LABELS[el], tooltip = "Where the " .. X.SLOT_LABELS[el]:lower() .. " sits on enemy plates. You can also drag it in the preview.",
    mode = "advanced", searchTags = { "layout", "slot", "position", "drag" } }, at(s.slots, el))
end

-- Packs (rule lists another add-on or data file ships); tick the ones to use.
key("rules.packs", { type = "list", default = {}, maxItems = 20, label = "Rule packs in use",
  tooltip = "Names of the NPC colour packs to add after your own rules (your own lines always win).", mode = "advanced",
  searchTags = { "pack", "npc", "rules" } }, function(v) R.enabledPacks = v end, function() R.Compile(s.rules.list) end)

-- Load-time sync of the saved values for the keys above.
for _, k in ipairs(X.KEYS) do Schema.defs[k].apply(Schema:Get(k)) end
