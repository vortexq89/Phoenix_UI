local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Phoenix_UI_Sentinel: load-on-demand diagnostics child (PUI_V2 16.3).
-- Loaded by Core/SentinelHook.lua right after PhoenixUIDB is ready, so safe
-- mode and the drift check run before modules enable at PLAYER_LOGIN.
local ADDON_NAME = ...
local S = { ADDON_NAME = ADDON_NAME, startTime = 0 }
PUI.Sentinel = S

local MAX_SESSIONS_KEPT = 3

local function hex32()
  local parts = {}
  for i = 1, 4 do parts[i] = string.format("%08x", math.random(0, 0x7fffffff)) end
  return table.concat(parts)
end

function S:InitDB(svOverride)
  local db = svOverride or _G.PhoenixUISentinelDB
  if type(db) ~= "table" then db = {} end
  if not svOverride then _G.PhoenixUISentinelDB = db end
  db.installId = db.installId or hex32()
  db.session = (db.session or 0) + 1
  db.incidents = db.incidents or {}
  db.sessionErrors = db.sessionErrors or {}
  db.sessionErrors[db.session] = {}
  for s in pairs(db.sessionErrors) do
    if s <= db.session - MAX_SESSIONS_KEPT then db.sessionErrors[s] = nil end
  end
  db.safeModed = db.safeModed or {}
  db.heartbeats = db.heartbeats or {}
  db.tests = db.tests or {}
  self.db = db
  return db
end

function S:Setting(key) return PUI.Schema:Get(key) end

function S:Version()
  return C_AddOns.GetAddOnMetadata(PUI.ADDON_NAME, "Version") or "dev"
end

function S:Track()
  local v = self:Version()
  if v:find("canary", 1, true) then return "canary" end
  if v == "dev" or v:find("project%-version") then return "dev" end
  return "stable"
end

-- Settings apply functions (called live by the schema through SentinelHook).
function S:ApplyOptIn(value) self.db.optIn = value end
function S:ApplyShareName(value) self.db.shareCharacterName = value end
function S:ApplyToast(value) self.toastEnabled = value end
function S:ApplySafeModeThreshold(value) self.safeModeThreshold = value end
function S:ApplySafeMode() end -- retired key, kept so old profiles load
function S:ApplyTesterMode(value)
  self.testerMode = value
  PUI.SentinelHook.SetRingSize(value and 200 or 50)
  if self.Perf then self.Perf:Refresh() end
end
function S:ApplyPerfSampler(value)
  self.perfEnabled = value
  if self.Perf then self.Perf:Refresh() end
end
function S:ApplyTaintLog(value)
  if self.Taint then self.Taint:SetSessionLogging(value) end
end

-- Error reporter keys (registered by SentinelHook so they exist early).
S.REPORTER_KEYS = { "captureOthers", "uploadOthers", "alertBadge", "alertSound", "alertSoundName", "alertChat", "autoOpen", "throttle",
  "redactNames", "shareAccept", "viewerSession", "viewerSource", "profiler", "baselineWarn", "trace", "recorder", "uploadAddonList", "viewerGroup", "viewerCollapsed" }
function S:ApplyReporter(key, value)
  if self.Alerts then self.Alerts.opts[key] = value; if key == "alertBadge" then self.Alerts:PaintBadge() end end
  if key == "profiler" and PUI.Profiler then if value then PUI.Profiler:Start() else PUI.Profiler:Stop() end end
  if self.Reporter and self.Reporter.frame and self.Reporter.frame:IsShown() then self.Reporter:Paint() end
end

local function applyAll()
  local keys = { "sentinel.optIn", "sentinel.shareCharacterName", "sentinel.toast", "sentinel.safeModeThreshold",
    "sentinel.safeMode", "sentinel.testerMode", "sentinel.perfSampler", "sentinel.taintLogSession" }
  for i = 1, #S.REPORTER_KEYS do keys[#keys + 1] = "sentinel." .. S.REPORTER_KEYS[i] end
  for i = 1, #keys do PUI.Schema.defs[keys[i]].apply(PUI.Schema:Get(keys[i])) end
end

local frame = PUI:CreateFrame("Frame", nil, nil, nil, "Sentinel")
S.frame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1, ...)
  if event == "CHAT_MSG_ADDON" then return S.Share:OnMessage(arg1, ...) end
  if event == "PLAYER_LOGOUT" then return S.Upload:MarkSaved() end
  if event ~= "ADDON_LOADED" or arg1 ~= ADDON_NAME then return end
  self:UnregisterEvent("ADDON_LOADED")
  S.startTime = GetTime()
  S:InitDB()
  applyAll()
  S.SafeMode:ApplyAtLoad()
  S.Integrity:Run()
  S.Drift:Run()
  S.Capture:DrainPending()
  S.Store:DrainOthers()
  C_ChatInfo.RegisterAddonMessagePrefix(S.Share.PREFIX)
  self:RegisterEvent("CHAT_MSG_ADDON")
  self:RegisterEvent("PLAYER_LOGOUT")
  S.Taint:Start()
  S.Sections:RegisterLaunchers()
  S.Heartbeat:Start()
end)
