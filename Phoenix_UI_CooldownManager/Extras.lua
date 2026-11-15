local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Cooldown Manager, deferred batch A (docs/DEFERRED.md): a spell picker (hide
-- chosen tracked spells, list with /pui cdm spells), glow on procs and/or
-- while your aura is up, a buff-bar reskin (texture, colour, threshold
-- ticks), a focus kick bar on the shared cast bar, the rotation assist icon,
-- a sound when chosen cooldowns come ready, and the crafted-quality badge on
-- the custom item bar. The picker, glow and sound lists are plain cdm.* text
-- settings, so the !PUI_CDM share string carries them (per-spell import).
-- Blizzard frames keep their data; Phoenix extras live in weak side tables.
local _, ns = ...
local CDM = ns.CDM
local Schema, Layout, Slash, Ticker, Secret, Theme, Media = PUI.Schema, PUI.Layout, PUI.Slash, PUI.Ticker, PUI.Secret, PUI.Theme, PUI.Media
local OWNER = "CooldownManager"
local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
local weak = function() return setmetatable({}, { __mode = "k" }) end

local X = { KEYS = {}, glows = weak(), ticks = weak(), sounded = weak(), procs = {}, quality = weak() }
CDM.Extras = X
local E = { hide = {}, glowMode = "off", glowSpells = {}, glowColor = { r = 1, g = 0.82, b = 0.25, a = 1 },
  barTexture = "game", barColor = nil, barTicks = {}, focusKick = false, assist = false, assistSize = 48,
  sounds = {}, quality = true }
X.settings = E

-- "123, 456" -> { [123] = true, [456] = true }
function X.ParseIDs(text)
  local out = {}
  for id in tostring(text or ""):gmatch("%d+") do out[tonumber(id)] = true end
  return out
end
function X.ParsePercents(text)
  local out = {}
  for n in tostring(text or ""):gmatch("[%d%.]+") do
    local v = tonumber(n)
    if v and v > 0 and v < 100 and #out < 6 then out[#out + 1] = v end
  end
  return out
end

-- Spell picker: chosen spells are left out of the rows (alpha 0, never Hide).
local items = CDM.Items
function CDM.Items(viewer, all)
  local list = items(viewer, all)
  if all or next(E.hide) == nil then return list end
  local out = {}
  for _, f in ipairs(list) do
    local id = CDM.SpellOf(f)
    if id and E.hide[id] then CDM.hidden[f] = true; f:SetAlpha(0) else out[#out + 1] = f end
  end
  return out
end
-- Item frames without touching alpha (CDM.Items(v, true) would undo the picker).
local function rawItems(viewer)
  local list = viewer:GetItemFrames()
  return type(list) == "table" and list or {}
end
function X.TrackedList()
  local lines = {}
  for _, v in ipairs(CDM.ORDER) do
    local viewer = _G[CDM.VIEWERS[v].global]
    if viewer then
      for _, f in ipairs(rawItems(viewer)) do
        local id = CDM.SpellOf(f)
        if id then
          lines[#lines + 1] = ("%s: %s (%d)%s"):format(CDM.VIEWERS[v].label, C_Spell.GetSpellName(id) or "?", id, E.hide[id] and " - hidden" or "")
        end
      end
    end
  end
  return lines
end

-- Glow -------------------------------------------------------------------------------
local function glowOf(f)
  local g = X.glows[f]
  if not g then
    g = f:CreateTexture(nil, "OVERLAY", nil, 6)
    g:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
    g:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
    g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    g:SetBlendMode("ADD")
    X.glows[f] = g
  end
  return g
end
function X.WantsGlow(id)
  if E.glowMode == "off" or not id then return false end
  if next(E.glowSpells) and not E.glowSpells[id] then return false end
  if (E.glowMode == "proc" or E.glowMode == "both") and X.procs[id] then return true end
  if (E.glowMode == "aura" or E.glowMode == "both") and C_UnitAuras.GetPlayerAuraBySpellID(id) ~= nil then return true end
  return false
end
function X.UpdateGlows()
  for _, v in ipairs({ "essential", "utility" }) do
    local viewer = CDM.active and _G[CDM.VIEWERS[v].global]
    if viewer then
      for _, f in ipairs(rawItems(viewer)) do
        local on = X.WantsGlow(CDM.SpellOf(f))
        if on or X.glows[f] then
          local g = glowOf(f)
          local c = E.glowColor
          g:SetVertexColor(c.r, c.g, c.b, c.a or 1)
          g:SetShown(on)
        end
      end
    end
  end
end

-- Buff bar reskin ----------------------------------------------------------------------
function X.SkinBar(f)
  local bar = rawget(f, "Bar")
  if type(bar) ~= "table" or not bar.SetStatusBarTexture then return end
  local path = Media:Path("statusbar", E.barTexture)
  if path then bar:SetStatusBarTexture(path) end
  if E.barColor then bar:SetStatusBarColor(E.barColor.r, E.barColor.g, E.barColor.b, 1) end
  local list = X.ticks[f]
  if not list then list = {}; X.ticks[f] = list end
  for i, pct in ipairs(E.barTicks) do
    local t = list[i]
    if not t then t = bar:CreateTexture(nil, "OVERLAY"); Theme:Paint(t, "text.primary", 0.8); list[i] = t end
    t:ClearAllPoints()
    t:SetSize(1, bar:GetHeight())
    t:SetPoint("LEFT", bar, "LEFT", math.floor(bar:GetWidth() * pct / 100 + 0.5), 0)
    t:Show()
  end
  for i = #E.barTicks + 1, #list do list[i]:Hide() end
end

-- Sounds when chosen cooldowns come ready --------------------------------------------
function X.HookSound(f)
  local cd = rawget(f, "Cooldown")
  if X.sounded[f] or type(cd) ~= "table" or not cd.HookScript then return end
  X.sounded[f] = true
  cd:HookScript("OnCooldownDone", function()
    local id = CDM.active and CDM.SpellOf(f)
    if id and E.sounds[id] then X.Ready(id) end
  end)
end
function X.Ready(id)
  local now = GetTime()
  if X.lastSound and now - X.lastSound < 0.5 then return end
  X.lastSound = now
  Media:Alert(8959)
end

local skin = CDM.Skin
function CDM.Skin(f, bars)
  skin(f, bars)
  if bars then X.SkinBar(f) else X.HookSound(f) end
end
local place = CDM.Place
function CDM.Place(v)
  place(v)
  if v == "essential" or v == "utility" then X.UpdateGlows() end
end

-- Focus kick bar ---------------------------------------------------------------------
Layout:RegisterElement("cdm.focusKick", { label = "Focus kick bar", owner = OWNER, size = { 200, 18 },
  default = { point = "CENTER", x = 0, y = 120 } })
function X.FocusKick()
  local want = CDM.active and E.focusKick
  if not want then
    if X.kickBar then X.kickBar:Disable(); X.kickHost:Hide() end
    return
  end
  if not X.kickBar then
    X.kickHost = PUI:CreateFrame("Frame", "PhoenixUI_CDM_FocusKick", UIParent, nil, OWNER)
    X.kickHost:SetSize(200, 18)
    X.kickBar = PUI.CastBar:Create(OWNER, X.kickHost, "focus", { width = 182, height = 18, kick = true, shield = true })
    X.kickBar.frame:SetPoint("RIGHT", X.kickHost, "RIGHT", 0, 0)
  else
    X.kickBar:Enable()
  end
  Layout:Place(X.kickHost, "cdm.focusKick")
  X.kickHost:Show()
end

-- Rotation assist icon ----------------------------------------------------------------
Layout:RegisterElement("cdm.assist", { label = "Rotation assist icon", owner = OWNER, size = { 48, 48 },
  default = { point = "CENTER", x = -150, y = -215 } })
function X.UpdateAssist()
  local f = X.assistFrame
  local id = C_AssistedCombat.GetNextCastSpell(false)
  if id == nil then f.icon:SetAlpha(0) return end
  f.icon:SetTexture(C_Spell.GetSpellTexture(id)) -- may be secret: straight to the widget
  f.icon:SetAlpha(1)
end
function X.Assist()
  local want = CDM.active and E.assist
  if not want then
    if X.assistFrame then X.assistFrame:Hide() end
    if Ticker:IsRegistered("cdm.assist") then Ticker:Unregister("cdm.assist") end
    return
  end
  local f = X.assistFrame
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUI_CDM_Assist", UIParent, nil, OWNER)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    X.assistFrame = f
  end
  f:SetSize(E.assistSize, E.assistSize)
  Layout:Place(f, "cdm.assist")
  f:Show()
  Ticker:Register("cdm.assist", 0.1, X.UpdateAssist, OWNER)
  X.UpdateAssist()
end

-- Crafted quality on the custom bar ----------------------------------------------------
local custom = CDM.Custom
function CDM.Custom()
  custom()
  local list = (CDM.active and CDM.customCfg.on) and PUI.ItemList:Items() or {}
  for i, b in ipairs(CDM.custom) do
    local e = list[i]
    local q = E.quality and e and C_TradeSkillUI.GetItemCraftedQualityByItemInfo(e.id) or nil
    local tex = X.quality[b]
    if plain(q) and q > 0 then
      if not tex then tex = b:CreateTexture(nil, "OVERLAY", nil, 7); tex:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2); tex:SetSize(16, 16); X.quality[b] = tex end
      tex:SetAtlas(("Professions-Icon-Quality-Tier%d-Small"):format(q))
      tex:Show()
    elseif tex then tex:Hide() end
  end
end

-- Events (own frame, registered only while needed) -------------------------------------
local ev = CreateFrame("Frame")
X.eventFrame = ev
ev:SetScript("OnEvent", function(_, event, a1)
  if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then X.procs[a1] = true
  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then X.procs[a1] = nil end
  X.UpdateGlows()
end)
function X.Wire()
  ev:UnregisterAllEvents()
  if not (CDM.active and E.glowMode ~= "off") then X.UpdateGlows(); return end
  if E.glowMode ~= "aura" then
    ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
  end
  if E.glowMode ~= "proc" then ev:RegisterUnitEvent("UNIT_AURA", "player") end
  X.UpdateGlows()
end
function X.ApplyAll()
  X.Wire(); X.FocusKick(); X.Assist()
end
PUI.Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then X.ApplyAll() end end)
PUI.Kernel:On("MODULE_DISABLED", function(name)
  if name ~= OWNER then return end
  X.procs = {}
  X.ApplyAll()
  for _, g in pairs(X.glows) do g:Hide() end
end)

Slash:Register("cdmspells", function()
  local lines = X.TrackedList()
  if #lines == 0 then Slash.Print("no tracked spells (turn the Cooldown Manager on and open Blizzard's cooldown settings)") return end
  PUI.Dialogs:Copy("Tracked spells", table.concat(lines, "\n"), "Put the IDs you want left out in Cooldown Manager > Hidden spells.")
end, "list the spells the cooldown manager tracks, with their IDs")

-- Schema ---------------------------------------------------------------------------------
local function key(name, def, set, after)
  def.owner = OWNER
  def.apply = function(v) set(v); (after or function() CDM.Refresh() end)() end
  CDM.schema["cdm." .. name] = def
  X.KEYS[#X.KEYS + 1] = "cdm." .. name
end
key("hideSpells", { type = "text", default = "", label = "Hidden spells",
  tooltip = "Spell IDs left out of the Phoenix rows, comma-separated. /pui cdmspells lists the tracked spells with their IDs.",
  mode = "simple", searchTags = { "spell picker" } }, function(v) E.hide = X.ParseIDs(v) end)
key("glow.mode", { type = "select", default = "off", choices = { "off", "proc", "aura", "both" },
  choiceLabels = { off = "Off", proc = "When the spell procs", aura = "While its buff is on you", both = "Proc or buff" },
  label = "Glow cooldowns", tooltip = "When a tracked cooldown glows.", mode = "simple" }, function(v) E.glowMode = v end, X.Wire)
key("glow.spells", { type = "text", default = "", label = "Glow only these spells",
  tooltip = "Spell IDs that may glow, comma-separated. Empty means every tracked cooldown.", mode = "advanced" },
  function(v) E.glowSpells = X.ParseIDs(v) end, X.Wire)
key("glow.color", { type = "color", default = { r = 1, g = 0.82, b = 0.25, a = 1 }, label = "Glow colour",
  tooltip = "Colour of the cooldown glow.", mode = "advanced" }, function(v) E.glowColor = v end, X.Wire)
key("bars.texture", { type = "select", default = "game",
  choices = function() local out = { "game" }; for _, n in ipairs(Media:List("statusbar")) do out[#out + 1] = n end; return out end,
  choiceLabels = { game = "Blizzard's texture" },
  label = "Buff bar texture", tooltip = "Texture of the tracked buff bars.", mode = "simple" }, function(v) E.barTexture = v end)
key("bars.classColor", { type = "toggle", default = false, label = "Buff bars in class colour",
  tooltip = "Colours the tracked buff bars in your class colour instead of Blizzard's.", mode = "advanced" },
  function(v)
    local c = v and C_ClassColor.GetClassColor(select(2, UnitClass("player")))
    E.barColor = c and { r = c.r, g = c.g, b = c.b } or nil
  end)
key("bars.ticks", { type = "text", default = "", label = "Buff bar threshold ticks",
  tooltip = "Percentages where thin lines are drawn on each buff bar (for example 30 for the pandemic window).",
  mode = "advanced" }, function(v) E.barTicks = X.ParsePercents(v) end)
key("focusKick", { type = "toggle", default = false, label = "Focus kick bar",
  tooltip = "Your focus target's cast bar with your interrupt's cooldown beside it. Move it in Studio.",
  mode = "simple" }, function(v) E.focusKick = v end, function() X.FocusKick() end)
key("assist", { type = "toggle", default = false, label = "Rotation assist icon",
  tooltip = "Shows the game's suggested next spell (Assisted Combat) as one icon. Move it in Studio.", mode = "simple" },
  function(v) E.assist = v end, function() X.Assist() end)
key("assist.size", { type = "range", default = 48, min = 24, max = 96, step = 1, label = "Rotation assist icon size",
  tooltip = "Size of the assist icon.", mode = "advanced" }, function(v) E.assistSize = v end, function() X.Assist() end)
key("sounds", { type = "text", default = "", label = "Sound when ready",
  tooltip = "Spell IDs that play your alert sound when their cooldown finishes, comma-separated.", mode = "simple" },
  function(v) E.sounds = X.ParseIDs(v) end, function() end)
key("custom.quality", { type = "toggle", default = true, label = "Crafted quality on items",
  tooltip = "Shows the crafted quality badge on items in the custom cooldown bar.", mode = "advanced" },
  function(v) E.quality = v end, function() CDM.Custom() end)
for _, k in ipairs(X.KEYS) do Schema:Register(k, CDM.schema[k]) end
for _, k in ipairs(X.KEYS) do CDM.schema[k].apply(Schema:Get(k)) end
