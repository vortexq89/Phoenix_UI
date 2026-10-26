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
for _, n in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "BossTargetFrameContainer", "MainActionBar",
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
function UnitHealth(u) return maybe(exists(u) and 800 or 0) end
function UnitHealthMax(u) return maybe(exists(u) and 1000 or 0) end
function UnitHealthMissing(u) return maybe(exists(u) and 200 or 0) end
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

-- Strict globals: any other undefined global is a missing stub or a typo.
local OPTIONAL = { ClickCastFrames = true, BugGrabber = true, C_PhoenixFake = true, PhoenixUIDB = true, PhoenixUISentinelDB = true }
setmetatable(_G, {
  __index = function(_, k)
    if OPTIONAL[k] then return nil end
    error("harness: undefined global '" .. tostring(k) .. "'", 2)
  end,
})

return H
