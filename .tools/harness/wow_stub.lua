-- Offline WoW API stub for running the Phoenix UI smoke suite under plain Lua 5.1.
-- Only what Phase 1 touches; unknown globals raise so missing stubs are noticed.
local H = { frames = {}, timers = {}, clock = 1000, output = {}, loaded = {}, cvars = { taintLog = "0" } }
_G.HARNESS = H

local flavor = os.getenv("PUI_FLAVOR") or "retail"
H.flavor = flavor

-- Frames ------------------------------------------------------------------
local noop = function() end
local Region = {}
local function newObject(kind)
  return setmetatable({ kind = kind, scripts = {}, events = {}, shown = true }, Region)
end
Region.__index = function(self, key)
  local v = rawget(Region, key)
  if v ~= nil then return v end
  return noop
end
function Region:RegisterEvent(ev) self.events[ev] = true end
function Region:RegisterUnitEvent(ev) self.events[ev] = true end
function Region:UnregisterEvent(ev) self.events[ev] = nil end
function Region:UnregisterAllEvents() self.events = {} end
function Region:IsEventRegistered(ev) return self.events[ev] == true end
function Region:SetScript(name, fn) self.scripts[name] = fn end
function Region:GetScript(name) return self.scripts[name] end
function Region:HookScript(name, fn) self.scripts[name] = fn end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:IsShown() return self.shown end
function Region:SetText(t) self.text = t end
function Region:GetText() return self.text end
function Region:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
function Region:CreateTexture() return newObject("Texture") end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:GetWidth() return rawget(self, "width") or 0 end
function Region:GetHeight() return rawget(self, "height") or 0 end
function Region:GetFrameLevel() return rawget(self, "level") or 1 end
function Region:SetFrameLevel(l) self.level = l end
function Region:SetChecked(v) self.checked = v end
function Region:GetChecked() return rawget(self, "checked") end
function Region:SetValue(v) self.value = v end
function Region:GetValue() return rawget(self, "value") end
function Region:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Region:CreateFontString() return newObject("FontString") end
function Region:CreateAnimationGroup()
  local g = newObject("AnimationGroup")
  g.playing = false
  function g:CreateAnimation() local a = newObject("Animation"); function a:SetDuration(d) g.duration = d end; return a end
  function g:Play() self.playing = true; self.elapsed = 0; H.groups[self] = true end
  function g:Stop() self.playing = false; H.groups[self] = nil end
  function g:IsPlaying() return self.playing end
  return g
end
H.groups = {}

function CreateFrame(frameType, name, parent, template)
  local f = newObject(frameType)
  H.frames[#H.frames + 1] = f
  if name then _G[name] = f end
  return f
end
UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
function CreateFont(name)
  local f = { name = name }
  function f:SetFont(path, size, flags) self.path, self.size, self.flags = path, size, flags end
  function f:GetFont() return self.path, self.size, self.flags end
  _G[name] = f
  return f
end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
function IsShiftKeyDown() return false end
function IsAltKeyDown() return false end
function IsControlKeyDown() return false end
UISpecialFrames = {}
SlashCmdList = {}
ChatFontSmall = {}

-- Engine-like dispatch: errors go to the installed error handler.
local errorHandler = function(msg) H.output[#H.output + 1] = "UNHANDLED: " .. tostring(msg); return msg end
function seterrorhandler(fn) errorHandler = fn end
function geterrorhandler() return errorHandler end
local function dispatch(fn, ...)
  local args, n = { ... }, select("#", ...)
  return xpcall(function() return fn(unpack(args, 1, n)) end, function(err) return errorHandler(err) end)
end
H.dispatch = dispatch
function securecallfunction(fn, ...)
  local res = { dispatch(fn, ...) }
  if res[1] then return unpack(res, 2) end
end

function H.fire(event, ...)
  for i = 1, #H.frames do
    local f = H.frames[i]
    if f.events[event] and f.scripts.OnEvent then dispatch(f.scripts.OnEvent, f, event, ...) end
  end
end

-- One frame: run due timers, OnUpdate scripts and animation loops.
function H.step(dt)
  dt = dt or 0.016
  H.clock = H.clock + dt
  local due = H.timers
  H.timers = {}
  for i = 1, #due do
    local t = due[i]
    if t.at <= H.clock then dispatch(t.fn) else H.timers[#H.timers + 1] = t end
  end
  for i = 1, #H.frames do
    local f = H.frames[i]
    if f.scripts.OnUpdate then dispatch(f.scripts.OnUpdate, f, dt) end
  end
  for g in pairs(H.groups) do
    g.elapsed = g.elapsed + dt
    if g.duration and g.elapsed >= g.duration then
      g.elapsed = 0
      if g.scripts.OnLoop then dispatch(g.scripts.OnLoop, g, "FORWARD") end
    end
  end
end

C_Timer = {
  After = function(seconds, fn) H.timers[#H.timers + 1] = { at = H.clock + seconds, fn = fn } end,
}

-- Game state --------------------------------------------------------------
function GetBuildInfo()
  if flavor == "forever" then return "1.60.1", "70532", "Oct 1 2026", 16001 end
  return "12.1.5", "70575", "Oct 23 2026", 120105
end
function GetTime() return H.clock end
function debugprofilestop() return os.clock() * 1000 end
time, date = os.time, os.date
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
function debugstack() return debug.traceback("", 2) end
function debuglocals() return "harness: locals unavailable" end
function GetCallstackHeight() return 1 end
function GetErrorCallstackHeight() return nil end
function issecretvalue() return false end
C_Secrets = { ShouldAurasBeSecret = function() return false end }
function InCombatLockdown() return H.inCombat == true end
function GetLocale() return "enUS" end
function UnitName() return "Tester", nil end
function GetRealmName() return "HarnessRealm" end
H.class = "MAGE"
function UnitClass() return "Class", H.class, 8 end
function UnitLevel() return 80 end
function GetInstanceInfo() return "Dornogal", "none", 0 end
function GetNumGroupMembers() return 0 end
function GetFramerate() return 60 end
function GetNetStats() return 0, 0, 20, 30 end
C_SpecializationInfo = { GetSpecialization = function() return 1 end }
C_ChallengeMode = { GetActiveKeystoneInfo = function() return 0 end }
C_CVar = { GetCVar = function(k) return H.cvars[k] end, SetCVar = function(k, v) H.cvars[k] = v; return true end }
C_UI = { Reload = function() H.reloaded = true end }
C_AddOnProfiler = { IsEnabled = function() return true end, GetAddOnMetric = function() return 0.0001 end }
Enum = { AddOnProfilerMetric = { RecentAverageTime = 1 } }
function print(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  H.output[#H.output + 1] = table.concat(parts, " ")
end

-- Base64 + "compression" stand-ins (the real client uses zlib/deflate).
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function encode64(s)
  local out = {}
  for i = 1, #s, 3 do
    local a, b, c = s:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local q = { math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64 }
    out[#out + 1] = B64:sub(q[1] + 1, q[1] + 1) .. B64:sub(q[2] + 1, q[2] + 1)
      .. (b and B64:sub(q[3] + 1, q[3] + 1) or "=") .. (c and B64:sub(q[4] + 1, q[4] + 1) or "=")
  end
  return table.concat(out)
end
local function decode64(s)
  local map = {}
  for i = 1, 64 do map[B64:sub(i, i)] = i - 1 end
  local out = {}
  s = s:gsub("[^%w%+/=]", "")
  for i = 1, #s, 4 do
    local c = { s:byte(i, i + 3) }
    local v = {}
    for k = 1, 4 do local ch = c[k] and string.char(c[k]); v[k] = (ch and map[ch]) or 0 end
    local n = v[1] * 262144 + v[2] * 4096 + v[3] * 64 + v[4]
    out[#out + 1] = string.char(math.floor(n / 65536) % 256)
    if s:sub(i + 2, i + 2) ~= "=" then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
    if s:sub(i + 3, i + 3) ~= "=" then out[#out + 1] = string.char(n % 256) end
  end
  return table.concat(out)
end
C_EncodingUtil = {
  CompressString = function(s) return "Z" .. s end,
  DecompressString = function(s) if s:sub(1, 1) ~= "Z" then return nil end return s:sub(2) end,
  EncodeBase64 = encode64,
  DecodeBase64 = decode64,
}

-- Addon loading -------------------------------------------------------------
H.root = os.getenv("PUI_ROOT") or "."
local metadata = { Version = "dev" }
local function tocFiles(dir, name)
  local fh = assert(io.open(H.root .. "/" .. dir .. "/" .. name .. ".toc"))
  local files = {}
  for line in fh:lines() do
    line = line:gsub("\r", "")
    if line ~= "" and not line:find("^#") then files[#files + 1] = line:gsub("\\", "/") end
  end
  fh:close()
  return files
end

function H.loadAddon(name)
  local dir = name == "Phoenix_UI" and "." or name
  local ns = {}
  for _, file in ipairs(tocFiles(dir, name)) do
    local path = H.root .. "/" .. dir .. "/" .. file
    local fh = assert(io.open(path))
    local src = fh:read("*a")
    fh:close()
    local chunk = assert(loadstring(src, "@Interface/AddOns/" .. name .. "/" .. file))
    local ok, err = dispatch(chunk, name, ns)
    if not ok then error("loading " .. file .. " failed: " .. tostring(err)) end
  end
  H.loaded[name] = true
  H.fire("ADDON_LOADED", name, false)
end

C_AddOns = {
  IsAddOnLoaded = function(n) if type(n) == "number" then return n <= 2 end return H.loaded[n] == true end,
  LoadAddOn = function(n)
    if n ~= "Phoenix_UI_Sentinel" and n ~= "Phoenix_UI_Options" then return false, "MISSING" end
    H.loadAddon(n)
    return true
  end,
  GetAddOnMetadata = function(_, key) return metadata[key] end,
  GetNumAddOns = function() return 2 end, -- Integrity/Drift scan; Options loads on demand
  GetAddOnInfo = function(i) return i == 1 and "Phoenix_UI" or "Phoenix_UI_Sentinel" end,
}

-- Phase 2: secure templates, unit/bar/action APIs ------------------------------
-- Secret simulation: H.secret(v) returns an opaque value that raises on any
-- comparison, arithmetic, concatenation, indexing or length, like 12.x secrets.
local SecretMT = {}
local function refuse(what) return function() error("harness: attempted " .. what .. " on a secret value", 2) end end
SecretMT.__index = refuse("index")
SecretMT.__newindex = refuse("index")
SecretMT.__eq, SecretMT.__lt, SecretMT.__le = refuse("compare"), refuse("compare"), refuse("compare")
SecretMT.__add, SecretMT.__sub, SecretMT.__mul, SecretMT.__div = refuse("arithmetic"), refuse("arithmetic"), refuse("arithmetic"), refuse("arithmetic")
SecretMT.__mod, SecretMT.__pow, SecretMT.__unm = refuse("arithmetic"), refuse("arithmetic"), refuse("arithmetic")
SecretMT.__concat, SecretMT.__len = refuse("concatenate"), refuse("length")
SecretMT.__tostring = function() return "<harness secret>" end
SecretMT.__metatable = false
function H.secret(v) local o = newproxy(true); local mt = getmetatable(o); for k, f in pairs(SecretMT) do mt[k] = f end; H.secrets[o] = v; return o end
H.secrets = setmetatable({}, { __mode = "k" })
function issecretvalue(v) return H.secrets[v] ~= nil end
H.secretMode = false
local function maybe(v) if H.secretMode and v ~= nil then return H.secret(v) end return v end
local function anySecret(...)
  for i = 1, select("#", ...) do if H.secrets[(select(i, ...))] ~= nil then return true end end
  return false
end

function Region:SetFormattedText(fmt, ...)
  if anySecret(...) then self.text = "<secret-formatted>" return end
  self.text = string.format(fmt, ...)
end
function Region:SetText(t) self.text = t end
function Region:SetParent(p) self.parent = p end
function Region:GetParent() return rawget(self, "parent") end
function Region:SetAttribute(k, v)
  self.attributes = rawget(self, "attributes") or {}
  self.attributes[k] = v
  local fn = self.scripts.OnAttributeChanged
  if fn then fn(self, k, v) end
end
function Region:GetAttribute(k) local a = rawget(self, "attributes"); return a and a[k] end
function Region:SetShown(v) self.shown = v and true or false end
function Region:SetAlpha(a) self.alpha = a end
function Region:GetAlpha() return rawget(self, "alpha") or 1 end
function Region:SetScale(v) self.scale = v end
function Region:GetScale() return rawget(self, "scale") or 1 end
function Region:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
function Region:SetStatusBarColor(r, g, b, a) self.barColor = { r, g, b, a } end
function Region:GetStatusBarTexture()
  local t = rawget(self, "barTexture")
  if not t then t = newObject("Texture"); self.barTexture = t end
  return t
end
function Region:SetTimerDuration(d, interp, dir) self.timer = { d, interp, dir } end
function Region:SetAlphaFromBoolean(flag, a, b) self.alphaFlag = flag end
function Region:SetCooldownFromDurationObject(d) self.cooldown = d end
function Region:SetTexture(t) self.texture = t end
function Region:SetSpriteSheetCell(cell) self.cell = cell end
function Region:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
function Region:IsProtected() return rawget(self, "secure") == true end
function Region:SetPoint(p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
function Region:GetName() return rawget(self, "name") end
function Region:SetID(id) self.id = id end
function Region:GetID() return rawget(self, "id") or 0 end
function Region:CreateTexture() return newObject("Texture") end

local baseCreateFrame = CreateFrame
function CreateFrame(frameType, name, parent, template)
  local f = baseCreateFrame(frameType, name, parent, template)
  f.name, f.template, f.parent = name, template, parent
  if template and (template:find("Secure") or template:find("ActionButtonTemplate")) then f.secure = true end
  return f
end

H.stateDrivers, H.unitWatch = {}, {}
function RegisterStateDriver(frame, state, values) H.stateDrivers[frame] = H.stateDrivers[frame] or {}; H.stateDrivers[frame][state] = values end
function UnregisterStateDriver(frame, state) if H.stateDrivers[frame] then H.stateDrivers[frame][state] = nil end end
function RegisterUnitWatch(frame) H.unitWatch[frame] = true end
function UnregisterUnitWatch(frame) H.unitWatch[frame] = nil end
function GameTooltip_SetDefaultAnchor() end
H.overrideBindings = {}
function SetOverrideBindingClick(owner, prio, key, button, mouse) H.overrideBindings[key] = { owner = owner, button = button, mouse = mouse } end
function ClearOverrideBindings(owner) for k, v in pairs(H.overrideBindings) do if v.owner == owner then H.overrideBindings[k] = nil end end end
H.bindings = { ACTIONBUTTON1 = "1", ACTIONBUTTON2 = "2", MULTIACTIONBAR1BUTTON1 = "SHIFT-1" }
function GetBindingKey(command) return H.bindings[command] end
function GetBindingText(key) return key end
function PickupAction(slot) H.picked = slot end
function PlaceAction(slot) H.placed = slot end
function IsModifiedClick() return false end

-- Blizzard frames that get parked/restored.
for _, n in ipairs({ "BuffFrame", "DebuffFrame", "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "BossTargetFrameContainer", "MainActionBar",
  "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
  "PlayerCastingBarFrame" }) do
  local f = CreateFrame("Frame", n, UIParent)
  f.parent = UIParent
end
TargetFrame.totFrame = CreateFrame("Frame", nil, TargetFrame); TargetFrame.totFrame.parent = TargetFrame
FocusFrame.totFrame = CreateFrame("Frame", nil, FocusFrame); FocusFrame.totFrame.parent = FocusFrame

-- Units: "player" and "target" exist with fixed values; values are secret in secretMode.
H.units = { player = true, target = true }
local function exists(u) return H.units[u] == true end
function UnitExists(u) return exists(u) end
H.hostile = H.hostile or {}
function UnitCanAttack(a, b) return H.hostile[b] == true end
function UnitHealth(u) return maybe(exists(u) and 800 or 0) end
function UnitHealthMax(u) return maybe(exists(u) and 1000 or 0) end
function UnitHealthMissing(u) return maybe(exists(u) and 200 or 0) end
function UnitGetTotalAbsorbs(u) return maybe(exists(u) and 20 or 0) end
function UnitRace() return maybe("Blood Elf"), "BloodElf", 10 end
function GetCreatureDifficultyColor() return { r = 1, g = 0.82, b = 0 } end
function GetThreatStatusColor() return 1, 0.6, 0, 1 end
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.49, 0, 0.25 } }
function UnitHealthPercent(u, pred, curve)
  if curve and curve.isColor then return CreateColor(0.5, 0.5, 0.1, 1) end
  return maybe(80)
end
function UnitPower(u) return maybe(50) end
function UnitPowerMax(u, ptype)
  if ptype == 16 then return H.powerMax16 or 4 end
  if ptype ~= nil then return H.powerMaxByType and H.powerMaxByType[ptype] or 0 end
  return maybe(100)
end
function UnitPowerPercent() return maybe(50) end
function UnitPowerType() return 0, "MANA", 0, 0, 1 end
function UnitName(u) return maybe(u == "player" and "Tester" or "Dummy"), nil end
function UnitEffectiveLevel() return maybe(80) end
function UnitClassification() return maybe("normal") end
function UnitIsPlayer(u) return maybe(u == "player") end
function UnitSelectionColor() return maybe(1), maybe(0.2), maybe(0.2), 1 end
function UnitIsConnected() return maybe(true) end
function UnitIsDeadOrGhost() return maybe(false) end
function UnitIsGroupLeader() return maybe(false) end
function UnitAffectingCombat() return maybe(false) end
function UnitIsPVP() return maybe(false) end
function UnitFactionGroup() return "Horde", "Horde" end
function IsResting() return false end
function GetRaidTargetIndex() if H.secretMode then return H.secret(3) end return nil end
function UnitCastingInfo(u) if H.casting then return maybe("Fireball"), nil, 135812, 0, 1, false, "id", maybe(false), 133 end return nil end
function UnitChannelInfo() return nil end
function UnitCastingDuration() if H.casting then return { duration = true } end return nil end
function UnitChannelDuration() return nil end
function UnitStagger() return maybe(0) end
function UnitPartialPower() return maybe(0) end
function GetComboPoints() return maybe(0) end
function GetRuneCooldown(i) if H.secretMode then return H.secret(100), H.secret(10), H.secret(i <= 3) end return 100, 10, i <= 3 end
function SetPortraitTexture(tex, unit) tex.portraitUnit = unit end
function AbbreviateNumbers(n) if H.secrets[n] ~= nil then return H.secret("abbr") end return tostring(n) end
function CreateUnitHealPredictionCalculator()
  local c = {}
  function c:GetIncomingHeals() return maybe(10), 0, 0, false end
  function c:GetDamageAbsorbs() return maybe(20), false end
  function c:GetHealAbsorbs() return maybe(5), false end
  return c
end
function UnitGetDetailedHealPrediction(unit, healer, calc) calc.lastUnit = unit end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(self) return self.r, self.g, self.b end, GetRGBA = function(self) return self.r, self.g, self.b, self.a end } end
C_ClassColor = { GetClassColor = function(token) if token == nil then return nil end return CreateColor(0.25, 0.78, 0.92, 1) end }
local function curve(isColor)
  local c = { points = {}, isColor = isColor }
  function c:SetType(t) self.type = t end
  function c:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
  return c
end
C_CurveUtil = { CreateCurve = function() return curve(false) end, CreateColorCurve = function() return curve(true) end,
  EvaluateColorFromBoolean = function(b, t, f) return t end }
CurveConstants = { ScaleTo100 = curve(false), ZeroToOne = curve(false), Reverse = curve(false) }
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 } }
Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
Enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }
Enum.LuaCurveType = { Linear = 0, Step = 1 }
Enum.PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6, SoulShards = 7,
  LunarPower = 8, HolyPower = 9, Maelstrom = 11, Chi = 12, Insanity = 13, ArcaneCharges = 16, Fury = 17, Pain = 18, Essence = 19 }
H.spec = 1
C_SpecializationInfo.GetSpecialization = function() return H.spec end
function H.duration(tag)
  return { tag = tag, IsZero = function() return maybe(false) end, SetTimeFromStart = function(self, s, d) self.start, self.length = s, d end }
end
C_Spell = { GetSpellCooldownDuration = function() return H.duration("gcd") end }
C_DurationUtil = { CreateDuration = function() return H.duration("custom") end }
function GetNumTotemSlots() return 4 end
function GetTotemInfo(i) return maybe(i == 1), maybe("Totem"), 0, 0, 136000 end
function GetTotemDuration(i) return H.duration("totem" .. i) end

-- Action bars.
H.actions = { [1] = 136243, [2] = 135812, [61] = 132242 }
C_ActionBar = {
  HasAction = function(id) return H.actions[id] ~= nil end,
  GetActionTexture = function(id) return H.actions[id] end,
  GetActionCooldownDuration = function() return H.duration("cd") end,
  GetActionChargeDuration = function() return H.duration("charge") end,
  GetActionDisplayCount = function() return maybe("") end,
  GetActionText = function() return maybe("") end,
  IsUsableAction = function() return maybe(true), maybe(false) end,
  IsActionInRange = function() return maybe(true) end,
  IsCurrentAction = function() return maybe(false) end,
  IsAutoRepeatAction = function() return maybe(false) end,
  EnableActionRangeCheck = function(id, on) H.rangeChecks = H.rangeChecks or {}; H.rangeChecks[id] = on end,
  FindSpellActionButtons = function(spell) if spell == 133 then return { 62 } end return {} end,
  GetActionBarPage = function() return 1 end,
  GetBonusBarOffset = function() return 0 end,
}

-- Phase 3: nameplates, group frames, click-casting.
function Region:WrapScript(frame, script, pre) H.wrapped = H.wrapped or {}; H.wrapped[#H.wrapped + 1] = { header = self, frame = frame, script = script, pre = pre } end
function Region:SetTextColor(r, g, b) self.textColor = { r, g, b } end
H.plates = {}
function H.addPlate(unit)
  local plate = CreateFrame("Frame", nil, UIParent)
  plate.UnitFrame = CreateFrame("Frame", nil, plate)
  plate.namePlateUnitToken = unit
  H.plates[unit] = plate
  H.units[unit] = true
  return plate
end
C_NamePlate = {
  GetNamePlateForUnit = function(unit) return H.plates[unit] end,
  GetNamePlates = function() local t = {}; for _, p in pairs(H.plates) do t[#t + 1] = p end; return t end,
}
H.threat = 0
function UnitThreatSituation() return maybe(H.threat) end
function UnitIsTapDenied() return maybe(false) end
function UnitIsUnit(a, b) return maybe(a == b) end
H.friendly = {}
function UnitIsFriend(_, u) return maybe(H.friendly[u] == true) end
C_QuestLog = { UnitIsRelatedToActiveQuest = function() return maybe(false) end }
C_SpecializationInfo.GetSpecializationInfo = function() return 62, "Arcane", "", 0, H.role or "DAMAGER" end
function UnitInRange() return maybe(true), maybe(true) end
H.roles = {}
function UnitGroupRolesAssigned(u) return maybe(H.roles[u] or "NONE") end
function GetReadyCheckStatus(u) return H.ready and H.ready[u] or nil end
function UnitHasIncomingResurrection() return maybe(false) end
C_IncomingSummon = { IncomingSummonStatus = function() return maybe(0) end }
function UnitPhaseReason() return nil end
H.privateAnchors, H.nextAnchor = {}, 0
C_UnitAuras = {
  AddPrivateAuraAnchor = function(args) H.nextAnchor = H.nextAnchor + 1; H.privateAnchors[H.nextAnchor] = args; return H.nextAnchor end,
  RemovePrivateAuraAnchor = function(id) H.privateAnchors[id] = nil end,
  GetAuraDataByIndex = function(u, i, filter)
    local set = (type(filter) == "string" and filter:find("HELPFUL")) and H.purgeable or H.dispellable
    if set and set[u] then return { auraInstanceID = maybe(7) } end
    return nil
  end,
}
for _, n in ipairs({ "PartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager" }) do
  local f = CreateFrame("Frame", n, UIParent); f.parent = UIParent
end

-- Phase 4: cooldown viewer, minimap, tooltip, data bars, chat.
function hooksecurefunc(a, b, c)
  local tbl, name, fn = a, b, c
  if type(a) == "string" then tbl, name, fn = _G, a, b end
  local orig = rawget(tbl, name) or tbl[name]
  rawset(tbl, name, function(...) local r = { orig(...) }; fn(...); return unpack(r) end)
end
H.cdItems = {}
for _, n in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
  local v = CreateFrame("Frame", n, UIParent)
  H.cdItems[n] = {}
  for i = 1, 3 do local f = CreateFrame("Frame", nil, v); f.layoutIndex = 4 - i; H.cdItems[n][i] = f end
  rawset(v, "GetItemFrames", function() return H.cdItems[n] end)
  rawset(v, "RefreshLayout", function() H.cdRefreshed = (H.cdRefreshed or 0) + 1 end)
  rawset(v, "Layout", function() end)
end
Minimap = CreateFrame("Minimap", "Minimap", UIParent)
Minimap:SetSize(198, 198)
function Region:SetMaskTexture(t) self.mask = t end
MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
MinimapCluster.BorderTop = CreateFrame("Frame", nil, MinimapCluster)
MinimapCluster.ZoneTextButton = CreateFrame("Button", nil, MinimapCluster)
MinimapCompassTexture = CreateFrame("Frame", "MinimapCompassTexture", Minimap)
function GetMinimapZoneText() return "Dornogal" end
C_Map = { GetBestMapForUnit = function() return 2339 end,
  GetPlayerMapPosition = function() return { GetXY = function() return maybe(0.5), maybe(0.25) end } end }
Enum.TooltipDataType = { Item = 0, Spell = 1, Unit = 2 }
H.tooltipCalls = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) H.tooltipCalls[kind] = fn end }
function Region:AddLine(t) self.lines = rawget(self, "lines") or {}; self.lines[#self.lines + 1] = t end
function Region:GetUnit() return "Tester", "player" end
function Region:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function GetGuildInfo() return maybe("Phoenix"), maybe("Officer") end
C_PlayerInfo = { GetPlayerMythicPlusRatingSummary = function() return { currentSeasonScore = maybe(2500) } end }
function GetMoney() return 1234567 end
C_Container = { GetContainerNumFreeSlots = function() return 10 end }
function GetInventoryItemDurability(slot) if slot == 5 then return 30, 100 end return nil end
function GetAverageItemLevel() return 640, 638.5 end
function UnitXP() return 50 end
function UnitXPMax() return 200 end
SOUNDKIT = { TELL_MESSAGE = 3081 }
H.sounds = {}
function PlaySound(id) H.sounds[#H.sounds + 1] = id end
function FlashClientIcon() H.flashed = true end
for i = 1, 2 do
  local c = CreateFrame("ScrollingMessageFrame", "ChatFrame" .. i, UIParent)
  c.FontStringContainer = CreateFrame("Frame", nil, c)
  c.offset = 0
  rawset(c, "AddMessage", function(self, msg) self.last = msg end)
  rawset(c, "SetScrollOffset", function(self, o) self.offset = o end)
  rawset(c, "GetScrollOffset", function(self) return self.offset end)
  rawset(c, "GetFont", function() return "Fonts\\FRIZQT__.TTF", 14, "" end)
  rawset(c, "GetMaxLines", function() return 128 end)
  rawset(c, "GetJustifyH", function() return "LEFT" end)
  rawset(c, "GetSpacing", function() return 0 end)
end
function Region:AddMessage(msg) self.messages = rawget(self, "messages") or {}; self.messages[#self.messages + 1] = msg end
function Region:SetScrollOffset(o) self.offset = o end
function Region:GetScrollOffset() return rawget(self, "offset") or 0 end

-- Phase 5: skins, vault, flow, quest tracker, setup, reminders.
function Region:GetObjectType() return rawget(self, "otype") or "Frame" end
function Region:SetFontObject(o) self.fontObject = o end
function Region:GetFontObject() return rawget(self, "fontObject") end
function Region:SetEnabled(v) self.enabled = v end
function Region:GetChildren() return unpack(rawget(self, "kids") or {}) end
H.calls = {}
local function call(name) return function(...) H.calls[#H.calls + 1] = { name, ... }; return H.ret and H.ret[name] end end
for _, n in ipairs({ "RepairAllItems", "RepopMe", "AcceptResurrect", "CancelDuel", "DeclineGuild", "AcceptGroup", "StaticPopup_Hide",
  "CinematicFrame_CancelCinematic", "LootSlot", "AcceptQuest", "CompleteQuest", "GetQuestReward", "ReloadUI", "QuestMapFrame_OpenToQuestDetails",
  "SetItemButtonTexture", "SetItemButtonCount", "SetItemButtonQuality", "SetItemButtonDesaturated", "ToggleAllBags", "OpenAllBags",
  "CloseAllBags", "ToggleBackpack" }) do _G[n] = call(n) end
function CanMerchantRepair() return true end
function GetRepairAllCost() return 5000, true end
function CanGuildBankRepair() return H.guildRepair == true end
C_MerchantFrame = { GetNumJunkItems = function() return H.junk or 0 end, SellAllJunkItems = call("SellAllJunkItems") }
C_PvP = { IsBattleground = function() return H.pvp == "bg" end, IsArena = function() return H.pvp == "arena" end }
function IsInInstance() return H.instance == true end
C_DeathInfo = { GetSelfResurrectOptions = function() return H.selfRes or {} end }
C_FriendList = { IsFriend = function(g) return g == "Player-1-FRIEND" end }
function IsGuildMember() return false end
C_BattleNet = { GetAccountInfoByGUID = function() return nil end }
MovieFrame = CreateFrame("Frame", "MovieFrame", UIParent)
StaticPopup_FindVisible = function() return nil end
DELETE_ITEM_CONFIRM_STRING = "DELETE"
C_GossipInfo = { GetNumAvailableQuests = function() return 0 end, GetNumActiveQuests = function() return 0 end,
  GetOptions = function() return H.gossip or {} end, SelectOption = call("SelectOption") }
function GetNumLootItems() return H.lootCount or 0 end
function LoggingCombat(v) if v ~= nil then H.logging = v end return H.logging == true end
TalkingHeadFrame = CreateFrame("Frame", "TalkingHeadFrame", UIParent)
UIErrorsFrame = CreateFrame("MessageFrame", "UIErrorsFrame", UIParent)
C_PartyInfo = { DoCountdown = call("DoCountdown") }
SOUNDKIT.RAID_WARNING = 8959
SOUNDKIT.IG_QUEST_LIST_COMPLETE = 878
PlaySoundFile = function() return true end
H.quests = {}
H.questLog = {}
C_QuestLog.GetNumQuestWatches = function() return #H.quests end
C_QuestLog.GetQuestIDForQuestWatchIndex = function(i) return H.quests[i] and H.quests[i].id end
local function q(id) for _, v in ipairs(H.quests) do if v.id == id then return v end end end
C_QuestLog.GetTitleForQuestID = function(id) return q(id) and q(id).title end
C_QuestLog.GetQuestObjectives = function(id) return q(id) and q(id).objectives or {} end
C_QuestLog.IsComplete = function(id) return q(id) and q(id).done or false end
C_QuestLog.ReadyForTurnIn = function(id) return q(id) and q(id).done or false end
C_QuestLog.GetQuestDifficultyLevel = function(id) return q(id) and q(id).level or 1 end
C_QuestLog.GetDistanceSqToQuest = function(id) return q(id) and q(id).dist end
C_QuestLog.IsWorldQuest = function(id) return q(id) and q(id).world or false end
C_QuestLog.GetQuestTagInfo = function() return nil end
C_QuestLog.GetNumQuestLogEntries = function() return #H.questLog end
C_QuestLog.GetInfo = function(i) return H.questLog[i] end
C_QuestLog.AddQuestWatch = call("AddQuestWatch")
function GetZoneText() return "Dornogal" end
function IsQuestCompletable() return true end
function GetNumQuestChoices() return H.choices or 0 end
ObjectiveTrackerFrame = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
ObjectiveTrackerFrame:Show()
H.auras = {}
C_UnitAuras.GetPlayerAuraBySpellID = function(id) local a = H.auras[id]; if a then return maybe(a) end return nil end
H.known = {}
C_SpellBook = { IsSpellKnown = function(id) return H.known[id] == true end }
C_Spell.GetSpellTexture = function(id) return 100000 + id end
C_Spell.GetSpellName = function(id) return "Spell " .. id end
function IsInGroup() return (H.group and #H.group or 0) > 0 end
function IsInRaid() return false end
local baseUnitClass = UnitClass
function UnitClass(u) if u ~= "player" and H.group then local c = H.group[tonumber(u:match("%d+") or 0)]; if c then return c, c, 1 end end return baseUnitClass(u) end
local baseNum = GetNumGroupMembers
function GetNumGroupMembers() if H.group then return #H.group end return baseNum() end
H.bags = { [0] = 4, 2, 0, 0, 0, 0 }
H.items = {}
C_Container.GetContainerNumSlots = function(bag) return H.bags[bag] or 0 end
C_Container.GetContainerItemInfo = function(bag, slot) return H.items[bag .. ":" .. slot] end
C_Container.SortBags = call("SortBags")
C_Container.SetItemSearch = call("SetItemSearch")
C_Item = { IsEquippableItem = function(id) return id == 900 end, GetItemInfoInstant = function(id) return id, "", "", "INVTYPE_HEAD" end,
  DoesItemExist = function() return true end, GetCurrentItemLevel = function() return 645 end }
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
C_CurrencyInfo = { GetCoinTextureString = function(m) return tostring(math.floor(m / 10000)) .. "g" end }
ContainerFrameCombinedBags = CreateFrame("Frame", "ContainerFrameCombinedBags", UIParent)
function GetPhysicalScreenSize() return 2560, 1440 end
H.addons = { "Phoenix_UI", "Phoenix_UI_Skins", "OtherAddon" }
C_AddOns.GetNumAddOns = function() return #H.addons end
C_AddOns.GetAddOnInfo = function(i) return H.addons[i] end
H.disabled = {}
C_AddOns.DisableAddOn = function(n) H.disabled[#H.disabled + 1] = n end
CharacterFrame = CreateFrame("Frame", "CharacterFrame", UIParent)
CharacterFrame.NineSlice = CreateFrame("Frame", nil, CharacterFrame)
CharacterFrame.Inset = CreateFrame("Frame", nil, CharacterFrame)
CharacterFrame.Inset.Bg = CreateFrame("Frame", nil, CharacterFrame.Inset)
CharacterFrameTab1 = CreateFrame("Button", "CharacterFrameTab1", CharacterFrame)
CharacterFrameTab1.Left = CreateFrame("Frame", nil, CharacterFrameTab1)

-- Phase 6: embers, ascent, oracle, wisdom, loadouts, group finder, locales.
Enum.DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6, DamageTaken = 7,
  AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }
Enum.DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 }
H.meter = { available = true, sessions = {}, current = nil, list = {} }
C_DamageMeter = {
  IsDamageMeterAvailable = function() return H.meter.available, H.meter.available and "" or "disabled" end,
  GetCombatSessionFromType = function(sessionType, kind) local c = H.meter.current; if not c then return nil end
    local out = { maxAmount = maybe(c.max), totalAmount = maybe(c.total), durationSeconds = maybe(c.duration), combatSources = {} }
    for i, r in ipairs(c.rows) do out.combatSources[i] = { name = maybe(r.name), classFilename = r.class, specIconID = 1, totalAmount = maybe(r.amount),
      amountPerSecond = maybe(r.aps), isLocalPlayer = r.me == true, deathRecapID = 0, deathTimeSeconds = maybe(0), classification = "normal" } end
    return out end,
  GetCombatSessionFromID = function(id, kind) local c = H.meter.sessions[id]; if not c then return nil end
    local out = { maxAmount = maybe(c.max), totalAmount = maybe(c.total), durationSeconds = maybe(c.duration), combatSources = {} }
    for i, r in ipairs(c.rows) do out.combatSources[i] = { name = maybe(r.name), classFilename = r.class, specIconID = 1, totalAmount = maybe(r.amount),
      amountPerSecond = maybe(r.aps), isLocalPlayer = r.me == true } end
    return out end,
  GetAvailableCombatSessions = function() return H.meter.list end,
  ResetAllCombatSessions = function() H.meter.reset = true end,
}
H.chat = {}
C_ChatInfo = { InChatMessagingLockdown = function() return H.chatLocked == true end, SendChatMessage = function(msg, ch) H.chat[#H.chat + 1] = { msg, ch } end }
Enum.WorldElapsedTimerTypes = { None = 0, ChallengeMode = 1, ProvingGround = 2 }
Enum.TtsVoiceType = { Standard = 0, Alternate = 1 }
H.mplus = nil -- { mapID, level, limit, elapsed, deaths, lost, forces = { q, total, text } }
function GetWorldElapsedTimers() if H.mplus then return 7 end end
function GetWorldElapsedTime(id) if H.mplus and id == 7 then return 0, H.mplus.elapsed, 1 end return 0, 0, 0 end
C_ChallengeMode.IsChallengeModeActive = function() return H.mplus ~= nil end
C_ChallengeMode.GetActiveChallengeMapID = function() return H.mplus and H.mplus.mapID end
C_ChallengeMode.GetMapUIInfo = function(id) return "Dungeon " .. id, id, H.mplus and H.mplus.limit or 1800 end
C_ChallengeMode.GetActiveKeystoneInfo = function() if H.mplus then return H.mplus.level, { 9 }, false end return 0 end
C_ChallengeMode.GetAffixInfo = function(id) return "Affix" .. id, "", 0 end
C_ChallengeMode.GetDeathCount = function() if H.mplus then return maybe(H.mplus.deaths), maybe(H.mplus.lost) end return 0, 0 end
C_ChallengeMode.GetChallengeCompletionInfo = function() return H.completion end
C_ChallengeMode.GetDungeonScoreRarityColor = function() return { GenerateHexColor = function() return "ff1eff00" end } end
C_ScenarioInfo = { GetCriteriaInfo = function(i)
  if i == 1 and H.mplus then return { isWeightedProgress = false, quantity = 0, totalQuantity = 1, quantityString = "" } end
  if i == 2 and H.mplus and H.mplus.forces then local f = H.mplus.forces; return { isWeightedProgress = true, quantity = maybe(f[1]), totalQuantity = f[2], quantityString = maybe(f[3]) } end
  return nil end }
C_MythicPlus = { GetOwnedKeystoneChallengeMapID = function() return H.ownedKey end }
H.spoken = {}
C_VoiceChat = { SpeakText = function(voice, text) H.spoken[#H.spoken + 1] = text end }
H.settingsCategories = {}
Settings = {
  RegisterCanvasLayoutCategory = function(frame, name) return { frame = frame, name = name } end,
  RegisterAddOnCategory = function(cat) H.settingsCategories[#H.settingsCategories + 1] = cat end,
}
function IsInInstance()
  local i = H.instance
  if i == true then return true, "party" end
  if type(i) == "string" then return true, i end
  return false, "none"
end
function GetBindingAction(key) return (H.blizzBindings or {})[key] or "" end
C_TTSSettings = { GetVoiceOptionID = function() return 1 end }
H.macros = { "Focus Kick", "Burst" }
function GetNumMacros() return #H.macros, 0 end
function GetMacroInfo(i) return H.macros[i] end
H.mounts = { [1] = { "Swift Phoenix", true }, [2] = { "Slow Mule", false } }
C_MountJournal = {
  GetMountIDs = function() local t = {}; for id in pairs(H.mounts) do t[#t + 1] = id end; table.sort(t); return t end,
  GetMountInfoByID = function(id) local m = H.mounts[id]; if not m then return nil end return m[1], 1000 + id, 500 + id, false, true, 0, false, false, nil, false, m[2], id end,
  SummonByID = function(id) H.summoned = id end,
}
H.itemStats = {}
C_Item.GetItemStats = function(link) return H.itemStats[link] end
C_Item.GetDetailedItemLevelInfo = function(link) local st = H.itemStats[link]; return st and st.ilvl end
C_Item.GetItemInfoInstant = function(id) if type(id) == "string" then return 1, "", "", (H.itemStats[id] or {}).loc or "INVTYPE_HEAD" end return id, "", "", "INVTYPE_HEAD" end
H.equipped = {}
function GetInventoryItemLink(unit, slot) return H.equipped[slot] end
local baseInstance = GetInstanceInfo
function GetInstanceInfo() if H.instanceInfo then return unpack(H.instanceInfo) end return baseInstance() end
H.specIndex = 1
C_SpecializationInfo.GetSpecialization = function() return H.specIndex end
C_SpecializationInfo.SetSpecialization = function(i) H.calls[#H.calls + 1] = { "SetSpecialization", i }; H.specIndex = i; return true end
H.config = 100
C_ClassTalents = { GetLastSelectedSavedConfigID = function() return H.config end, CanChangeTalents = function() return true end,
  LoadConfig = function(id) H.calls[#H.calls + 1] = { "LoadConfig", id }; H.config = id; return 1 end }
H.sets = { [1] = { "Raid", false }, [2] = { "Dungeon", true } }
C_EquipmentSet = { GetEquipmentSetIDs = function() return { 1, 2 } end,
  GetEquipmentSetInfo = function(id) local x = H.sets[id]; return x[1], 0, id, x[2] end,
  UseEquipmentSet = function(id) H.calls[#H.calls + 1] = { "UseEquipmentSet", id }; for k, v in pairs(H.sets) do v[2] = (k == id) end; return true end }
H.lfg = {}
C_LFGList = {
  HasSearchResultInfo = function(id) return H.lfg[id] ~= nil end,
  GetSearchResultInfo = function(id) local r = H.lfg[id]; return r and { leaderName = r.leader, leaderOverallDungeonScore = r.score, numMembers = #r.roles } end,
  GetSearchResultPlayerInfo = function(id, i) local r = H.lfg[id]; return r and { assignedRole = r.roles[i] } end,
  GetSearchResults = function() local t = {}; for id in pairs(H.lfg) do t[#t + 1] = id end; table.sort(t); return #t, t end,
  GetAdvancedFilter = function() return H.lfgFilter or { minimumRating = 0, needsTank = false, needsHealer = false, needsDamage = false } end,
  SaveAdvancedFilter = function(f) H.lfgFilter = f end,
}
function LFGListSearchEntry_Update(entry) rawset(entry, "updates", (rawget(entry, "updates") or 0) + 1) end
H.addonLoaded = {}
local baseLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(n) if H.addonLoaded[n] then return true end return baseLoaded(n) end
local baseLoad = C_AddOns.LoadAddOn
C_AddOns.LoadAddOn = function(n) if n == "Phoenix_UI_Locales" then H.loadAddon(n); return true end return baseLoad(n) end


-- Foundations (ledgers, visibility, services, season, cast bar, auras) ---------
function SetOverrideBinding(owner, prio, key, command) H.overrideBindings[key] = { owner = owner, command = command } end
function BreakUpLargeNumbers(n) local s = tostring(n); local k; repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0; return s end
H.cursor = { 100, 200 }
function GetCursorPosition() return H.cursor[1], H.cursor[2] end
function UnitHasVehicleUI() return H.vehicle == true end
function IsMounted() return H.mounted == true end
C_PlayerInfo.GetGlidingInfo = function() return H.gliding == true, true, 0 end
H.season = { id = 15, maps = { 501, 502 }, info = { [501] = { "Ara-Kara", 1800 }, [502] = { "The Dawnbreaker", 1980 } }, affixes = { 9, 152 } }
C_MythicPlus.GetCurrentSeason = function() return H.season.id end
C_MythicPlus.GetCurrentAffixes = function() local out = {}; for i, a in ipairs(H.season.affixes) do out[i] = { id = a } end; return out end
C_MythicPlus.RequestMapInfo = function() end
C_MythicPlus.RequestCurrentAffixes = function() end
C_ChallengeMode.GetMapTable = function() return H.season.maps end
C_ChallengeMode.GetMapUIInfo = function(id) local i = H.season.info[id]; if i then return i[1], id, i[2], 0, 0, 2000 + id end end
C_ChallengeMode.GetDungeonScoreRarityColor = function(score) if score >= 2500 then return { r = 1, g = 0.5, b = 0 } end return { r = 0, g = 0.44, b = 0.87 } end
H.auraContainers = {}
local function auraContainer()
  local c = newObject("AuraContainer")
  c.groupLog = {}
  rawset(c, "SetUnit", function(self, u) self.unit = u end)
  rawset(c, "AddAuraGroup", function(self, key, filter, opts) self.groupLog[#self.groupLog + 1] = { "add", key, filter, opts.maxFrameCount } end)
  rawset(c, "SetAuraGroupFilterString", function(self, key, filter) self.groupLog[#self.groupLog + 1] = { "filter", key, filter } end)
  rawset(c, "SetAuraGroupMaxFrameCount", function(self, key, n) self.groupLog[#self.groupLog + 1] = { "cap", key, n } end)
  rawset(c, "SetAuraGroupSortMethod", function(self, key, m, d) self.groupLog[#self.groupLog + 1] = { "sort", key, m, d } end)
  H.auraContainers[#H.auraContainers + 1] = c
  return c
end
local baseCreateFrame = CreateFrame
function CreateFrame(frameType, name, parent, template)
  if frameType == "AuraContainer" then return auraContainer() end
  return baseCreateFrame(frameType, name, parent, template)
end
AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4, ExpirationOnly = 5, Name = 6 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
H.addonLoaded.Blizzard_AuraContainer = true
H.secretAuras = false
C_Secrets.ShouldAurasBeSecret = function() return H.secretAuras == true end
H.callbacks = {}
EventRegistry = { RegisterCallback = function(_, event, fn, owner) H.callbacks[event] = H.callbacks[event] or {}; table.insert(H.callbacks[event], fn) end }

-- Phase 4: group frames (dispel colours, corner indicators, arena targeting).
C_UnitAuras.GetAuraDispelTypeColor = function(u, id, curve) H.dispelColorCalls = (H.dispelColorCalls or 0) + 1; return CreateColor(0.2, 0.6, 1, 1) end
H.unitAuras = {}
C_UnitAuras.GetUnitAuraBySpellID = function(u, id) local a = H.unitAuras[u]; if a and a[id] then return { auraInstanceID = maybe(id) } end return nil end
C_UnitAuras.GetAuraDataBySpellName = function(u, name, filter) local a = H.unitAuras[u]; local id = tonumber(tostring(name):match("%d+") or 0)
  if a and a[id] then return { auraInstanceID = maybe(id) } end return nil end
H.unitTargets = {}
local baseUnitIsUnit = UnitIsUnit
function UnitIsUnit(a, b)
  local enemy = type(a) == "string" and a:match("^(.+)target$")
  if enemy and H.unitTargets[enemy] then return maybe(H.unitTargets[enemy] == b) end
  return baseUnitIsUnit(a, b)
end

-- Strict globals: any other undefined global is a missing stub or a typo.
local OPTIONAL = { PawnUIFrame = true, ClickCastFrames = true, Clique = true, BugGrabber = true, C_PhoenixFake = true, PhoenixUIDB = true, PhoenixUISentinelDB = true,
  AnchorUtil = true, RaiderIO = true, CustomAuraContainerTemplate = true }
setmetatable(_G, {
  __index = function(_, k)
    if OPTIONAL[k] then return nil end
    error("harness: undefined global '" .. tostring(k) .. "'", 2)
  end,
})

return H
