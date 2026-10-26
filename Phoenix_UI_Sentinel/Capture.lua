local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Capture: turns errors and other findings into deduplicated incidents in
-- PhoenixUISentinelDB.incidents, keyed by a hash of (module, normalised stack,
-- message without numbers). All context values pass through PUI.Secret.
local S = PUI.Sentinel
local Secret = PUI.Secret
local Capture = {}
S.Capture = Capture

local MAX_INCIDENTS = 100
local MAX_ADDONS = 120
local storable = Secret.Storable

-- 32-bit djb2-style hash as 8 hex digits (Lua 5.1 numbers are doubles).
function Capture.Hash(text)
  local h = 5381
  for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
  return string.format("%08x", h)
end

function Capture.NormaliseMessage(message)
  return (message:gsub("0x%x+", "ADDR"):gsub("%d+", "N"))
end

function Capture.NormaliseStack(stack)
  local lines = {}
  for line in stack:gmatch("[^\n]+") do
    line = line:gsub('%[string "@?([^"]*)"%]', "%1"):gsub("Interface[/\\]AddOns[/\\]", ""):gsub("0x%x+", "ADDR")
    lines[#lines + 1] = line
    if #lines >= 12 then break end
  end
  return table.concat(lines, "\n")
end

local function addonList()
  local out = {}
  local n = C_AddOns.GetNumAddOns()
  for i = 1, n do
    if C_AddOns.IsAddOnLoaded(i) then
      local name = C_AddOns.GetAddOnInfo(i)
      out[#out + 1] = storable(name, 64) .. " " .. storable(C_AddOns.GetAddOnMetadata(i, "Version") or "", 32)
      if #out >= MAX_ADDONS then break end
    end
  end
  return out
end
Capture.AddonList = addonList

local function profileHash()
  local snap = PUI.Schema:Snapshot()
  local parts = {}
  for i = 1, #PUI.Schema.keys do
    local k = PUI.Schema.keys[i]
    parts[#parts + 1] = k .. "=" .. Secret.ToText(snap[k], 64)
  end
  return Capture.Hash(table.concat(parts, ";"))
end
Capture.ProfileHash = profileHash

function Capture:CpuByModule()
  if not (C_AddOnProfiler and C_AddOnProfiler.IsEnabled()) then return nil end
  local metric = Enum.AddOnProfilerMetric.RecentAverageTime
  return {
    Phoenix_UI = storable(C_AddOnProfiler.GetAddOnMetric(PUI.ADDON_NAME, metric)),
    Phoenix_UI_Sentinel = storable(C_AddOnProfiler.GetAddOnMetric(S.ADDON_NAME, metric)),
  }
end

-- Session context (PUI_V2 16.3 item 1). Only the tester's own character data.
function Capture:Context(module, events)
  local _, classToken = UnitClass("player")
  local instanceName, instanceType, difficultyID = GetInstanceInfo()
  local ctx = {
    class = storable(classToken),
    level = storable(UnitLevel("player")),
    zone = storable(instanceName, 80),
    instanceType = storable(instanceType),
    difficulty = storable(difficultyID),
    combat = InCombatLockdown() and true or false,
    groupSize = storable(GetNumGroupMembers()),
    profile = storable(PUI.DB:GetProfileName(), 64),
    profileHash = profileHash(),
    settings = {},
    events = events,
    addons = addonList(),
    cpu = self:CpuByModule(),
    fps = storable(math.floor(GetFramerate() + 0.5)),
    forever = PUI.IS_FOREVER,
  }
  local _, _, latencyHome, latencyWorld = GetNetStats()
  ctx.latencyHome, ctx.latencyWorld = storable(latencyHome), storable(latencyWorld)
  if not PUI.IS_FOREVER then
    ctx.spec = storable(C_SpecializationInfo.GetSpecialization())
    local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
    ctx.keyLevel = storable(keyLevel)
  end
  if S.db.shareCharacterName then ctx.character = storable(UnitName("player"), 64) end
  local snap = PUI.Schema:Snapshot(module)
  for k, v in pairs(snap) do ctx.settings[k] = storable(v, 120) end
  return ctx
end

local SEVERITY = { secret = "S1", drift = "S1", integrity = "S2", error = "S2", perf = "S3", taint = "S2", test = "S3", heartbeat = "S3" }

function Capture:Severity(kind, inc)
  if kind == "taint" and inc.context and inc.context.combat then return "S1" end
  if kind == "error" and inc.count >= (S.safeModeThreshold or 5) then return "S1" end
  return SEVERITY[kind] or "S2"
end

local function trimIncidents(incidents)
  local n, oldestKey, oldest = 0, nil, nil
  for key, inc in pairs(incidents) do
    n = n + 1
    if not oldest or inc.lastSeen < oldest then oldest, oldestKey = inc.lastSeen, key end
  end
  if n > MAX_INCIDENTS and oldestKey then incidents[oldestKey] = nil end
end

-- Generic incident writer. fields: message, stack, locals, combat, extra (table).
function Capture:Report(kind, module, fields)
  local db = S.db
  local message = Secret.ToText(fields.message, 2000)
  local stack = Secret.ToText(fields.stack or "", 4000)
  local normStack = Capture.NormaliseStack(stack)
  local hash = Capture.Hash(module .. "|" .. normStack .. "|" .. Capture.NormaliseMessage(message))
  local now = time()
  local inc = db.incidents[hash]
  local isNew = inc == nil
  if isNew then
    local events = S.Ring:Snapshot()
    inc = {
      hash = hash, kind = kind, module = module, message = message, stack = normStack,
      count = 0, firstSeen = now, lastSeen = now, session = db.session,
      addonVersion = S:Version(), interface = PUI.TOC, build = PUI.BUILD,
      locale = GetLocale(), track = S:Track(),
      context = self:Context(module, events),
      extra = fields.extra,
    }
    if kind == "secret" then inc.apiFamily = S.Ring:LastApiFamily(events) end
    db.incidents[hash] = inc
    trimIncidents(db.incidents)
  end
  if fields.locals and (isNew or S.testerMode) then inc.locals = Secret.ToText(fields.locals, 4000) end
  inc.count = inc.count + 1
  inc.lastSeen = now
  inc.lastSession = db.session
  inc.severity = self:Severity(kind, inc)
  local counts = db.sessionErrors[db.session]
  counts[module] = (counts[module] or 0) + 1
  PUI:Log("sentinel." .. kind, module, hash)
  if isNew and S.Toast then S.Toast:Notify(inc) end
  return inc, isNew
end

function Capture:OnError(rec)
  local kind = S.SecretTag:IsSecretError(rec.message) and "secret" or "error"
  return self:Report(kind, rec.module, rec)
end

function Capture:DrainPending()
  local pending = PUI.SentinelHook.pending
  PUI.SentinelHook.pending = {}
  for i = 1, #pending do self:OnError(pending[i]) end
end

function Capture:Clear()
  wipe(S.db.incidents)
end
