local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Arena module (plan 5.21 "Arena", 1.O rows "DR display", "Arena match timer,
-- dampening, Shadowsight", "Party<->arena targeting dots"; mockup 04;
-- sArena parity 15.7 rebuilt in Phoenix's own code and art).
-- Zero events outside arenas: the module listens for zone changes only and
-- arms its arena events when you enter an arena. Never toggles Edit Mode and
-- never reparents Blizzard's arena frames; hiding them is a setting that goes
-- through the frame ledger (restored when turned off).
-- Conflict: with sArena (or Gladius) loaded, nothing changes until you pick.
local _, ns = ...
local Schema, Ticker, Secret, CQ = PUI.Schema, PUI.Ticker, PUI.Secret, PUI.CombatQueue
local ST, DR, M, FR = ns.State, ns.DR, ns.Match, ns.Frames
local OWNER = "Arena"
local AR = { active = false, inArena = false, test = false, log = {} }
ns.AR = AR
PUI.Arena = AR
AR.State, AR.DR, AR.Match, AR.Frames = ST, DR, M, FR

local s = {}
AR.settings = s
local function did(w) AR.log[#AR.log + 1] = w; if #AR.log > 40 then table.remove(AR.log, 1) end end

AR.ARENA_EVENTS = { "ARENA_OPPONENT_UPDATE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS", "ARENA_CROWD_CONTROL_SPELL_UPDATE",
  "ARENA_COOLDOWNS_UPDATE", "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE",
  "UNIT_NAME_UPDATE", "UNIT_SPELLCAST_SUCCEEDED", "PVP_MATCH_STATE_CHANGED", "PVP_MATCH_COMPLETE", "PLAYER_FOCUS_CHANGED" }

function AR.Count()
  if AR.test then return s.testCount end
  local n = 0
  for i = 1, 5 do
    local u = ST.units[ST.UNITS[i]]
    if UnitExists(ST.UNITS[i]) or (u and u.life ~= "none") then n = i end
  end
  return math.max(n, AR.prepCount or 0)
end

function AR.Holder()
  if not AR.holder then
    AR.holder = PUI:CreateFrame("Frame", "PhoenixUIArenaHolder", UIParent, nil, OWNER)
    AR.holder:SetSize(s.width, 5 * (s.height + s.spacing))
    AR.holder.header = AR.holder:CreateFontString(nil, "OVERLAY")
    AR.holder.header:SetPoint("BOTTOMLEFT", AR.holder, "TOPLEFT", 0, 16)
    PUI.Layout:Place(AR.holder, "arena.frames")
  end
  return AR.holder
end

-- Refresh(): geometry (out of combat) and data for every shown frame.
function AR.Refresh()
  if not AR.active then return end
  local want = AR.inArena or AR.test
  local holder = AR.Holder()
  if CQ.InCombat() then CQ.Defer("arena.refresh", AR.Refresh) else holder:SetShown(want) end
  if not want then FR.Sleep(); return end
  holder:SetScale(s.scale)
  holder.header:SetFontObject(PUI.Media:FontObject("small"))
  local count = AR.Count()
  FR.Apply(s, holder, count)
  for i, f in ipairs(FR.frames) do
    if not CQ.InCombat() then f:SetShown(i <= count) end
    if i <= count then
      if AR.test then AR.PaintTest(f, i) else FR.PaintUnit(f, s); FR.PaintTargets(f, s) end
    end
  end
end

-- Test mode: deterministic sample comps drawn by the same paint function.
AR.SAMPLE = {
  { name = "Kaelith", spec = 267, hp = 0.72, class = "WARLOCK", life = "seen", trinket = 0, dr = { { cat = 1, stage = 1 }, { cat = 3, stage = 3 } } },
  { name = "Shadowstep", spec = 261, hp = 1, class = "ROGUE", life = "unseen", trinket = 72, dr = {} },
  { name = "Durgan", spec = 256, hp = 0.58, class = "PRIEST", life = "seen", trinket = 0, dr = { { cat = 2, stage = 2 } } },
  { name = "Rogue (left)", spec = 261, hp = 0, class = "ROGUE", life = "left", trinket = 0, dr = {} },
  { name = "Vorna", spec = 105, hp = 0.9, class = "DRUID", life = "seen", trinket = 0, dr = {} },
}
function AR.PaintTest(f, i)
  local x = AR.SAMPLE[i]
  local _, specName, _, icon = GetSpecializationInfoForSpecID(x.spec)
  f.spec:SetTexture(icon)
  f.name:SetText(s.name and x.name or "")
  f.health:SetMinMaxValues(0, 1); f.health:SetValue(x.hp)
  f.hp:SetText(s.healthText ~= "none" and string.format("%d%%", x.hp * 100) or "")
  local c = s.classColors and C_ClassColor.GetClassColor(x.class)
  if c then f.health:SetStatusBarColor(c.r, c.g, c.b, 1) end
  f.status:SetText(x.life == "unseen" and (s.assumeRegen and "Stealthed - 100%*" or "Stealthed") or (x.life == "left" and "Left arena" or ""))
  f.stealth:SetShown(x.life == "unseen")
  f:SetAlpha(x.life == "left" and s.staleAlpha or 1)
  f.trinket.tex:SetTexture(1322720)
  if x.trinket > 0 then f.trinket.cd:SetCooldown(GetTime() - (120 - x.trinket), 120) else f.trinket.cd:Clear() end
  local entries = {}
  for _, d in ipairs(x.dr) do
    entries[#entries + 1] = { key = "t" .. d.cat, category = d.cat, plain = true, stage = d.stage,
      info = { category = d.cat, startTime = GetTime(), duration = 18, isImmune = d.stage >= 3, showCountdown = true } }
  end
  f.testDR = s.drTray and DR.Paint(f.tray, entries, FR.TrayStyle(s)) or 0
  for d, t in ipairs(f.dots) do t:SetShown(s.targetDots and d <= 2 and i == 1) end
  f.targetBorder:SetAlpha((s.targetBorder and i == 1) and 0.9 or 0)
  f.focusMark:SetAlpha((s.focusMark and i == 3) and 1 or 0)
  f.specName = specName
end
function AR.SetTest(on)
  AR.test = on and true or false
  if AR.test then AR.prepCount = nil end
  AR.Refresh()
  if M.fs == nil and AR.holder then AR.holder.header:SetText(AR.test and "Arena test - Match 2:41 - Dampening 12%" or "") end
  return AR.test
end

-- Blizzard arena frames: hidden (alpha 0, no mouse) through the frame ledger.
function AR.ApplyBlizzard()
  if CQ.InCombat() then CQ.Defer("arena.blizzard", AR.ApplyBlizzard); return end
  local f = _G.CompactArenaFrame
  if not f then return end
  if AR.active and s.hideBlizzard then
    if not PUI.FrameLedger:Owner("arena.blizzard") then PUI.FrameLedger:Take(OWNER, f, "arena.blizzard") end
    f:SetAlpha(0)
    f:EnableMouse(false)
  elseif PUI.FrameLedger:Owner("arena.blizzard") then
    PUI.FrameLedger:Release(OWNER, "arena.blizzard")
    f:EnableMouse(true)
  end
end

-- Events ---------------------------------------------------------------------
local function frameFor(unit)
  if type(unit) ~= "string" then return nil end
  local i = tonumber(unit:match("^arena(%d)$") or "")
  return i and FR.frames[i]
end
local handlers = {}
function handlers.ARENA_OPPONENT_UPDATE(unit, reason)
  if type(unit) ~= "string" or not unit:match("^arena%d$") then return end
  ST.SetLife(unit, reason)
  if reason == "seen" and C_PvP.RequestCrowdControlSpell then C_PvP.RequestCrowdControlSpell(unit) end
  AR.Refresh()
end
function handlers.ARENA_PREP_OPPONENT_SPECIALIZATIONS()
  local n = 0
  for i = 1, 5 do
    local spec = C_PvP.GetArenaOpponentSpec(i)
    if spec ~= nil and not Secret.IsSecret(spec) and spec > 0 then ST.Prep(ST.UNITS[i], spec); n = i end
  end
  AR.prepCount = n
  AR.Refresh()
end
function handlers.ARENA_CROWD_CONTROL_SPELL_UPDATE(unit)
  local f = frameFor(unit)
  if not f then return end
  local _, start, duration = C_PvP.GetArenaCrowdControlInfo(unit)
  if start ~= nil and not Secret.IsSecret(start) and not Secret.IsSecret(duration) and duration > 0 then
    ST.TrinketUsed(unit, start, duration)
  end
  FR.PaintCooldowns(f, s)
end
function handlers.ARENA_COOLDOWNS_UPDATE()
  for i, f in ipairs(FR.frames) do if i <= AR.Count() then handlers.ARENA_CROWD_CONTROL_SPELL_UPDATE(f.unit) end end
end
function handlers.UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED(unit, info)
  local f = frameFor(unit)
  if not f then return end
  DR.Update(unit, info, GetTime())
  FR.PaintTray(f, s)
  AR.ArmExpire()
end
function handlers.UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
  local f = frameFor(unit)
  if f and ST.RacialUsed(unit, spellID, GetTime()) then FR.PaintCooldowns(f, s); did("racial") end
end
local function unitPaint(unit) local f = frameFor(unit); if f then FR.PaintUnit(f, s) end end
handlers.UNIT_HEALTH, handlers.UNIT_MAXHEALTH, handlers.UNIT_POWER_UPDATE, handlers.UNIT_NAME_UPDATE = unitPaint, unitPaint, unitPaint, unitPaint
function handlers.PLAYER_FOCUS_CHANGED() for i, f in ipairs(FR.frames) do if i <= AR.Count() then FR.PaintTargets(f, s) end end end
function handlers.PVP_MATCH_STATE_CHANGED()
  if C_PvP.IsMatchActive and C_PvP.IsMatchActive() then M.Start(AR.Holder().header, s) end
end
function handlers.PVP_MATCH_COMPLETE(winner, duration)
  M.Stop()
  if s.card then AR.lastCard = M.Collect(winner, duration); M.ShowCard(AR.lastCard, s) end
end

-- Plain DR windows expire on a 1 s Ticker entry while any are listed.
function AR.ArmExpire()
  local any = false
  for _, u in pairs(ST.units) do if #u.dr > 0 then any = true end end
  if any and not Ticker:IsRegistered("arena.dr") then
    Ticker:Register("arena.dr", 1, function()
      local left = 0
      for unit in pairs(ST.units) do left = left + DR.Expire(unit, GetTime()); unitPaint(unit) end
      if left == 0 then Ticker:Unregister("arena.dr") end
    end, OWNER)
  end
end

local armed
local function arm(on)
  if on == armed then return end
  armed = on
  local mod = AR.module
  for _, ev in ipairs(AR.ARENA_EVENTS) do
    if on then mod:RegisterEvent(ev, function(_, _, ...) handlers[ev](...) end) else mod:UnregisterEvent(ev) end
  end
  if on then PUI.Targeting:Subscribe("arena", function() for i, f in ipairs(FR.frames) do if i <= AR.Count() then FR.PaintTargets(f, s) end end end)
  else PUI.Targeting:Unsubscribe("arena") end
end
AR.Arm = arm
function AR.OnZone()
  local _, kind = IsInInstance()
  local now = kind == "arena"
  if now and not AR.inArena then ST.Reset(); AR.prepCount = nil end
  AR.inArena = now
  arm(now and AR.active)
  if now then
    if C_PvP.IsMatchActive and C_PvP.IsMatchActive() then M.Start(AR.Holder().header, s) end
  else
    M.Stop()
    Ticker:Unregister("arena.dr")
  end
  AR.Refresh()
end

local function onEnable(mod)
  AR.active = true
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", AR.OnZone)
  mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", AR.OnZone)
  DR.Apply(s.drBlizzard)
  AR.ApplyBlizzard()
  AR.OnZone()
end
local function onDisable()
  arm(false)
  AR.active, AR.inArena, AR.test = false, false, false
  M.Stop()
  Ticker:Unregister("arena.dr")
  DR.Apply(false)
  AR.ApplyBlizzard()
  if AR.holder and not CQ.InCombat() then AR.holder:Hide() end
end

-- Schema -------------------------------------------------------------------------
local schema = {}
AR.schema = schema
ns.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v)
    s[name] = v
    if name == "drBlizzard" and AR.active then DR.Apply(v) end
    if name == "hideBlizzard" then AR.ApplyBlizzard() end
    AR.Refresh()
  end
  schema["arena." .. name] = def
end
key("preset", { type = "select", default = "phoenix", choices = { "phoenix", "compact", "gladiator" }, choiceLabels = FR.PRESET_LABELS, mode = "simple",
  label = "Look", tooltip = "A starting look for size, spacing and icon side. Every part can still be changed on its own below." })
key("scale", { type = "range", default = 1, min = 0.5, max = 2, step = 0.05, label = "Scale", tooltip = "Size of all arena frames.", mode = "simple" })
key("width", { type = "range", default = 220, min = 120, max = 360, step = 2, label = "Width", tooltip = "Width of each enemy frame." })
key("height", { type = "range", default = 46, min = 24, max = 80, step = 1, label = "Height", tooltip = "Height of each enemy frame." })
key("spacing", { type = "range", default = 22, min = 0, max = 60, step = 1, label = "Space between frames", tooltip = "Gap between enemy frames (room for the cast bar)." })
key("grow", { type = "select", default = "DOWN", choices = { "DOWN", "UP" }, choiceLabels = { DOWN = "Downwards", UP = "Upwards" }, label = "Frames grow", tooltip = "Direction from enemy 1 to enemy 3." })
key("mirrored", { type = "toggle", default = false, label = "Mirror", tooltip = "Flips every part to the other side (for frames on the left of the screen).", mode = "simple" })
key("showPower", { type = "toggle", default = true, label = "Power bar", tooltip = "Mana, energy or rage under the health bar." })
key("powerHeight", { type = "range", default = 6, min = 2, max = 16, step = 1, label = "Power bar height", tooltip = "Height of the power bar." })
key("classColors", { type = "toggle", default = true, label = "Class colours", tooltip = "Health bars in each enemy's class colour." })
key("name", { type = "toggle", default = true, label = "Names", tooltip = "Enemy names on the health bar (the game may hide some)." })
key("healthText", { type = "select", default = "percent", choices = { "percent", "none" }, choiceLabels = { percent = "Percent", none = "None" },
  label = "Health text", tooltip = "Health as a percent, written by the game so hidden values still show." })
key("font", { type = "select", default = "small", choices = { "small", "normal" }, choiceLabels = { small = "Small", normal = "Normal" }, label = "Text size", tooltip = "Size of names and health text." })
key("arenaNumber", { type = "toggle", default = true, label = "Arena number", tooltip = "Writes 1, 2, 3 beside each frame (matches /target arena1)." })
key("specIcon", { type = "toggle", default = true, label = "Spec icon", tooltip = "The enemy's spec icon, shown from the preparation room on." })
key("iconSide", { type = "select", default = "LEFT", choices = { "LEFT", "RIGHT" }, choiceLabels = { LEFT = "Left", RIGHT = "Right" }, label = "Spec icon side", tooltip = "Which side the spec icon sits on." })
key("trinket", { type = "toggle", default = true, label = "PvP trinket", tooltip = "The enemy's trinket with its cooldown, from the game's own data.", mode = "simple" })
key("trinketFaction", { type = "toggle", default = true, label = "Faction trinket art", tooltip = "Before a trinket is seen, show the Horde or Alliance trinket art." })
key("racial", { type = "toggle", default = true, label = "Racial", tooltip = "The enemy's racial ability. Racials that share a cooldown with the trinket lock when the trinket is used." })
key("trinketSize", { type = "range", default = 34, min = 16, max = 60, step = 1, label = "Trinket and racial size", tooltip = "Size of the trinket and racial icons." })
key("desaturate", { type = "toggle", default = true, label = "Grey out on cooldown", tooltip = "Greys the racial icon while it is on cooldown." })
key("castBar", { type = "toggle", default = true, label = "Cast bars", tooltip = "The shared Phoenix cast bar under each enemy, with your kick state.", mode = "simple" })
key("castHeight", { type = "range", default = 14, min = 8, max = 30, step = 1, label = "Cast bar height", tooltip = "Height of the enemy cast bars." })
key("drBlizzard", { type = "toggle", default = false, mode = "simple", label = "DR tracking (game's own)",
  tooltip = "Turns on the game's own enemy DR tracking (setting spellDiminishPVPEnemiesEnabled) and shows it in Phoenix's tray. Off: no DR is shown. Your old value comes back when this goes off.",
  searchTags = { "dr", "diminishing", "returns" } })
key("drTray", { type = "toggle", default = true, label = "DR tray", tooltip = "Where the game's DR data is drawn. Needs DR tracking on." })
key("drAnchor", { type = "select", default = "trinket", choices = FR.TRAY_ANCHORS, choiceLabels = { trinket = "Right of the trinket", racial = "Right of the racial", frame = "Beside the frame" },
  label = "DR tray position", tooltip = "What the DR tray attaches to. Move it further with the offsets." })
key("drX", { type = "range", default = 0, min = -200, max = 200, step = 1, label = "DR tray X offset", tooltip = "Moves the DR tray left or right." })
key("drY", { type = "range", default = 0, min = -100, max = 100, step = 1, label = "DR tray Y offset", tooltip = "Moves the DR tray up or down." })
key("drGrow", { type = "select", default = "AUTO", choices = { "AUTO", "RIGHT", "LEFT", "UP", "DOWN" },
  choiceLabels = { AUTO = "Away from the frame", RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" }, label = "DR icons grow", tooltip = "Direction new DR icons are added." })
key("drSize", { type = "range", default = 26, min = 14, max = 48, step = 1, label = "DR icon size", tooltip = "Size of each DR icon." })
key("drSpacing", { type = "range", default = 2, min = 0, max = 12, step = 1, label = "DR icon spacing", tooltip = "Gap between DR icons." })
key("drText", { type = "toggle", default = true, label = "DR countdown numbers", tooltip = "Seconds left until the DR resets, written by the game." })
key("drStage", { type = "toggle", default = true, label = "DR stage label", tooltip = "Writes 1/2, 1/4 or immune when the game's values are readable (hidden values show icon and swipe only)." })
key("drColorBorder", { type = "toggle", default = true, label = "Colour the DR border by stage", tooltip = "Green, yellow, red borders for 1/2, 1/4 and immune." })
key("targetDots", { type = "toggle", default = true, label = "Party target dots", tooltip = "A coloured dot for each party member targeting this enemy (shared with the party frames' enemy dots)." })
key("targetBorder", { type = "toggle", default = true, label = "Border on my target", tooltip = "A gold border around the enemy you are targeting." })
key("focusMark", { type = "toggle", default = true, label = "Mark my focus", tooltip = "A small mark on your focus." })
key("assumeRegen", { type = "toggle", default = false, label = "Assume full health in stealth",
  tooltip = "Cosmetic guess: a stealthed enemy's bar fills to full, marked with *. Phoenix cannot see health in stealth." })
key("staleAlpha", { type = "range", default = 0.4, min = 0, max = 1, step = 0.05, label = "Left enemy opacity", tooltip = "How faded the frame of an enemy who left is." })
key("matchTimer", { type = "toggle", default = true, label = "Match timer", tooltip = "Match time above the frames.", mode = "simple" })
key("dampening", { type = "toggle", default = true, label = "Dampening", tooltip = "Current dampening above the frames." })
key("shadowsight", { type = "toggle", default = true, label = "Shadowsight timer", tooltip = "Counts down to the Shadowsight eyes." })
key("card", { type = "toggle", default = true, label = "Card after each match", mode = "simple",
  tooltip = "Both teams' specs, your rating change, match time, trinket uses and the DR the game reported." })
key("cardRating", { type = "toggle", default = true, label = "Rating change on the card", tooltip = "Shows your rating change on the card." })
key("cardScale", { type = "range", default = 1, min = 0.6, max = 1.6, step = 0.05, label = "Card scale", tooltip = "Size of the after-match card." })
key("hideBlizzard", { type = "toggle", default = true, label = "Hide Blizzard's arena frames",
  tooltip = "Hides the game's arena frames while Phoenix shows its own (never moved or changed; shown again when this is off)." })
key("testCount", { type = "range", default = 3, min = 2, max = 5, step = 1, label = "Test mode enemies", tooltip = "How many sample enemies the test mode shows." })
local ckey, cdef = PUI.Coexist:Define("arena", { module = OWNER, job = "Arena frames", addons = { "sArena", "sArena_Reloaded", "sArenaReloaded", "Gladius", "GladiusEx" } })
cdef.owner = OWNER
schema[ckey] = cdef
PUI.Layout:RegisterElement("arena.frames", { label = "Arena frames", owner = OWNER, size = { 220, 300 }, default = { point = "RIGHT", x = -260, y = 80 } })
PUI.Layout:RegisterElement("arena.card", { label = "After-match card", owner = OWNER, size = { 340, 170 }, default = { point = "CENTER", x = 0, y = 160 } })

-- ApplyPreset(name): writes the preset's values into their own settings once.
function AR.ApplyPreset(name)
  local p = FR.PRESETS[name]
  if not p then return false end
  AR.applyingPreset = true
  Schema:Set("arena.width", p.width); Schema:Set("arena.height", p.height); Schema:Set("arena.powerHeight", p.power)
  Schema:Set("arena.spacing", p.spacing); Schema:Set("arena.iconSide", p.icon); Schema:Set("arena.trinketSize", p.trinket)
  AR.applyingPreset = false
  return true
end

-- Only a pick you make writes the preset's values (a profile switch never does).
PUI.Kernel:On("SETTING_CHANGED", function(k, v) if k == "arena.preset" and not AR.applyingPreset then AR.ApplyPreset(v) end end)

PUI.Slash:Register("arena", function(rest)
  local word = (rest or ""):match("^(%S*)")
  if word == "test" then AR.SetTest(not AR.test)
  elseif word == "card" then if AR.lastCard then M.ShowCard(AR.lastCard, s) end
  else PUI.Slash.Print("/pui arena test | card") end
end, "Arena frames: test mode, last match card")

AR.module = PUI:RegisterModule(OWNER, {
  label = "Arena", tooltip = "Enemy arena frames with trinket, racial, the game's DR in Phoenix's tray, casts, targeting dots, match timer and an after-match card.",
  enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
  loadCondition = function() return PUI.Coexist:Allows("arena") end,
})
for k, def in pairs(schema) do if def.type ~= "layout" and k:sub(1, 6) == "arena." then def.apply(Schema:Get(k)) end end
