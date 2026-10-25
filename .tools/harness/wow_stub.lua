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
function UnitClass() return "Mage", "MAGE", 8 end
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

-- Strict globals: any other undefined global is a missing stub or a typo.
local OPTIONAL = { BugGrabber = true, C_PhoenixFake = true, PhoenixUIDB = true, PhoenixUISentinelDB = true }
setmetatable(_G, {
  __index = function(_, k)
    if OPTIONAL[k] then return nil end
    error("harness: undefined global '" .. tostring(k) .. "'", 2)
  end,
})

return H
