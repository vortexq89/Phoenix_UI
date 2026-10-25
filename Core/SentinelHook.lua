local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- SentinelHook: the always-loaded part of Sentinel (PUI_V2 16.3).
-- * Chains the Lua error handler (keeps BugGrabber/BugSack or Blizzard's
--   handler working) and buffers Phoenix errors until the Phoenix_UI_Sentinel
--   child has loaded.
-- * Keeps the event ring (last 50 events, 200 in tester mode).
-- * Owns the Sentinel settings so they exist before the child loads.
-- Every captured value goes through PUI.Secret before it is stored.
local Secret = PUI.Secret
local Hook = { pending = {}, ring = {}, ringSize = 50, ringNext = 1, ringCount = 0, captured = 0 }
PUI.SentinelHook = Hook

local CHILD = "Phoenix_UI_Sentinel"
local MAX_PENDING = 50
local GetTime = GetTime

-- Event ring --------------------------------------------------------------
function Hook.RecordEvent(kind, key, value)
  local i = Hook.ringNext
  Hook.ring[i] = { t = GetTime(), kind = kind, key = Secret.Storable(key, 120), value = Secret.Storable(value, 120) }
  Hook.ringNext = (i % Hook.ringSize) + 1
  if Hook.ringCount < Hook.ringSize then Hook.ringCount = Hook.ringCount + 1 end
  if Hook.debugRing then
    print("|cffff7d0aPUI|r ring: " .. kind .. " " .. Secret.ToText(key, 60) .. " " .. Secret.ToText(value, 60))
  end
end

-- Oldest-first copy of the ring.
function Hook.RingSnapshot()
  local out, size = {}, Hook.ringSize
  local start = Hook.ringCount < size and 1 or Hook.ringNext
  for n = 0, Hook.ringCount - 1 do
    local e = Hook.ring[((start - 1 + n) % size) + 1]
    if e then out[#out + 1] = { t = e.t, kind = e.kind, key = e.key, value = e.value } end
  end
  return out
end

function Hook.SetRingSize(size)
  local events = Hook.RingSnapshot()
  Hook.ring, Hook.ringSize, Hook.ringNext, Hook.ringCount = {}, size, 1, 0
  local debugRing = Hook.debugRing
  Hook.debugRing = false
  for i = math.max(1, #events - size + 1), #events do
    local e = events[i]
    Hook.RecordEvent(e.kind, e.key, e.value)
  end
  Hook.debugRing = debugRing
end

-- Error capture -------------------------------------------------------------
-- Which Phoenix module owns a stack, or nil when the error is not Phoenix's.
function Hook.OwnerOf(stack)
  if type(stack) ~= "string" then return nil end
  local child = stack:match("AddOns[/\\]Phoenix_UI_(%w+)[/\\]")
  if child then return child end
  local sub = stack:match("AddOns[/\\]Phoenix_UI[/\\](%w+)[/\\]")
  if sub then return sub == "Core" and "Core" or sub end
  return nil
end

-- Turns one raw error into a plain, storable record.
function Hook.BuildRecord(message, stack, locals)
  local rec = {
    message = Secret.ToText(message, 2000),
    stack = Secret.ToText(stack, 4000),
    locals = locals ~= nil and Secret.ToText(locals, 4000) or nil,
    time = time(),
    combat = InCombatLockdown() and true or false,
  }
  rec.module = Hook.OwnerOf(rec.stack) or Hook.OwnerOf(rec.message)
  return rec
end

function Hook.Deliver(rec)
  if not rec.module then return end -- not a Phoenix error: never recorded (privacy)
  Hook.captured = Hook.captured + 1
  local S = PUI.Sentinel
  if S and S.Capture then
    S.Capture:OnError(rec)
  elseif #Hook.pending < MAX_PENDING then
    Hook.pending[#Hook.pending + 1] = rec
  end
end

local busy = false
local function onError(message, ...)
  if not busy then
    busy = true
    -- Same relative calculation Blizzard's own handler uses: the erroring
    -- frame is (current height - error height + 1) levels above this one.
    local current, errHeight = GetCallstackHeight(), GetErrorCallstackHeight()
    local level = errHeight and (current - (errHeight - 1)) or 2
    local stack = debugstack(level)
    local locals = debuglocals(level)
    -- securecallfunction: if capture itself fails, that error still reaches the
    -- previous handler (busy is set, so it is not re-captured) and busy resets.
    securecallfunction(Hook.Deliver, Hook.BuildRecord(message, stack, locals))
    busy = false
  end
  local previous = Hook.previous
  if previous then return previous(message, ...) end
end
Hook.onError = onError

function Hook.Install()
  local current = geterrorhandler()
  if current == onError then return "chained" end
  Hook.previous = current
  seterrorhandler(onError)
  if geterrorhandler() == onError then
    Hook.mode = "chained"
  elseif type(BugGrabber) == "table" and type(BugGrabber.RegisterCallback) == "function" then
    -- The installed grabber keeps the handler slot; listen to its public callback instead.
    Hook.previous = nil
    BugGrabber.RegisterCallback(Hook, "BugGrabber_BugGrabbed", function(_, err)
      if type(err) == "table" then Hook.Deliver(Hook.BuildRecord(err.message, err.stack, err.locals)) end
    end)
    Hook.mode = "buggrabber"
  else
    Hook.previous = nil
    Hook.mode = "unavailable"
  end
  return Hook.mode
end

-- Test support: run the handler as if the engine called it (no prior handler).
function Hook.Simulate(message, stack, locals)
  Hook.Deliver(Hook.BuildRecord(message, stack, locals))
end

Hook.Install()

-- Child loading -------------------------------------------------------------
function Hook.LoadChild()
  if C_AddOns.IsAddOnLoaded(CHILD) then return true end
  local loaded, reason = C_AddOns.LoadAddOn(CHILD)
  if not loaded then Hook.childError = reason end
  return loaded
end

PUI.Kernel:On("DB_READY", function() Hook.LoadChild() end)

-- Settings ------------------------------------------------------------------
local Schema = PUI.Schema
local function forward(method)
  return function(value)
    local S = PUI.Sentinel
    if S and S[method] then S[method](S, value) end
  end
end

local function toggle(key, label, tooltip, mode, default, method)
  Schema:Register(key, {
    type = "toggle", default = default, label = label, tooltip = tooltip,
    mode = mode, owner = "Sentinel", apply = forward(method),
  })
end

toggle("sentinel.optIn", "Share diagnostics",
  "Allow Sentinel reports to leave this computer (export string and Companion upload). Nothing is shared while off.",
  "simple", false, "ApplyOptIn")
toggle("sentinel.shareCharacterName", "Include my character name",
  "Add your own character name to reports. Other players' names are never collected.",
  "advanced", false, "ApplyShareName")
toggle("sentinel.testerMode", "Tester mode",
  "Deeper capture for designated testers: 200-event history, locals on every error, 1-second performance sampler, test suite on login.",
  "advanced", false, "ApplyTesterMode")
toggle("sentinel.safeMode", "Safe mode",
  "Disable a Phoenix module at the next login when it threw too many errors in the previous session.",
  "simple", false, "ApplySafeMode")
toggle("sentinel.perfSampler", "Performance sampler",
  "Sample Phoenix CPU use every 5 seconds and report modules that stay over budget.",
  "advanced", false, "ApplyPerfSampler")
toggle("sentinel.taintLogSession", "Taint logging this session",
  "Turn on the client's taint log until logout so blocked actions can be traced.",
  "advanced", false, "ApplyTaintLog")
toggle("sentinel.toast", "Error notice",
  "Show a small notice the first time a new Phoenix error happens.",
  "simple", true, "ApplyToast")

Schema:Register("sentinel.safeModeThreshold", {
  type = "range", min = 1, max = 50, step = 1, default = 5,
  label = "Safe mode threshold",
  tooltip = "Errors from one module in a session that trigger safe mode at the next login.",
  mode = "advanced", owner = "Sentinel", apply = forward("ApplySafeModeThreshold"),
})

Schema:Register("core.debugRing", {
  type = "toggle", default = false, label = "Print event history",
  tooltip = "Print every Phoenix event (module changes, setting changes) to chat as it happens. For troubleshooting.",
  mode = "advanced", owner = "Core",
  apply = function(value) Hook.debugRing = value end,
})
