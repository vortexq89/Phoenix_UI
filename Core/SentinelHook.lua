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

-- Which addon an error belongs to, from the first AddOns/<Folder>/ path in
-- the message or stack (the message names the failing file, so it wins).
-- Blizzard's own code (Blizzard_* folders, FrameXML, SharedXML) is grouped
-- as "Blizzard"; nothing recognisable is "Unknown".
local function folderIn(text)
  if type(text) ~= "string" then return nil end
  return text:match("AddOns[/\\]([%w_%-%.!]+)[/\\]")
end
function Hook.AddonOf(stack, message)
  local folder = folderIn(message) or folderIn(stack)
  if folder then
    if folder:find("^Blizzard_") then return "Blizzard" end
    return folder
  end
  for _, text in ipairs({ message or "", stack or "" }) do
    if type(text) == "string" and (text:find("Interface[/\\]FrameXML") or text:find("Interface[/\\]SharedXML") or text:find("Blizzard_")) then return "Blizzard" end
  end
  return "Unknown"
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
  rec.addon = Hook.AddonOf(rec.stack, rec.message)
  return rec
end

Hook.others = {}
-- Flood guard: the same error (same message) is processed at most FLOOD_MAX
-- times per second (an OnUpdate error fires every frame); the rest are only
-- counted in Hook.flooded, so a storm cannot stall the game or the log.
Hook.FLOOD_MAX, Hook.flooded = 10, 0
local floodSecond, floodCount = 0, {}
function Hook.Flooding(now, message)
  if now ~= floodSecond then floodSecond, floodCount = now, {} end
  local key = message or ""
  local n = (floodCount[key] or 0) + 1
  floodCount[key] = n
  if n > Hook.FLOOD_MAX then Hook.flooded = Hook.flooded + 1; return true end
  return false
end
function Hook.ResetFlood() floodSecond, floodCount = 0, {} end
function Hook.Deliver(rec)
  if Hook.Flooding(rec.time or time(), rec.message) then return end
  if not rec.module then
    -- Another addon's error (BugSack parity): kept on this PC only, in its
    -- own list, and only while "Capture other addons" is on. It never joins
    -- Phoenix's reports and never leaves unless you allow it.
    if not Hook.captureOthers then return end
    local S = PUI.Sentinel
    if S and S.Store then S.Store:OnOther(rec)
    elseif #Hook.others < MAX_PENDING then Hook.others[#Hook.others + 1] = rec end
    return
  end
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

toggle("sentinel.optIn", "Auto-upload via Companion",
  "Phoenix error reports go to the vq8s.com dashboard through the Companion app (and the export string works). See exactly what leaves this PC with Preview on the error reporter. Nothing is shared while off.",
  "simple", true, "ApplyOptIn")
toggle("sentinel.shareCharacterName", "Include my character name",
  "Add your own character name to reports. Other players' names are never collected.",
  "advanced", false, "ApplyShareName")
toggle("sentinel.testerMode", "Tester mode",
  "Deeper capture for designated testers: 200-event history, locals on every error, 1-second performance sampler, test suite on login.",
  "advanced", false, "ApplyTesterMode")
toggle("sentinel.safeMode", "Safe mode (retired)",
  "Retired: Phoenix never turns modules off after errors and never hides errors. Kept only so old profiles load; it does nothing.",
  "advanced", false, "ApplySafeMode")
Schema.defs["sentinel.safeMode"].hidden = true
toggle("sentinel.perfSampler", "Performance sampler",
  "Sample Phoenix CPU use every 5 seconds and report modules that stay over budget.",
  "advanced", false, "ApplyPerfSampler")
toggle("sentinel.taintLogSession", "Taint logging this session",
  "Turn on the client's taint log until logout so blocked actions can be traced.",
  "advanced", false, "ApplyTaintLog")
toggle("sentinel.toast", "New-error popup",
  "A small popup the first time a new error happens (repeats are only counted).",
  "simple", true, "ApplyToast")

-- Error reporter (mockup 15, BugSack parity + upgrades). Applied live by the
-- child through S:ApplyReporter(key, value).
local function rep(key, def)
  def.owner, def.mode = "Sentinel", def.mode or "advanced"
  def.apply = function(v)
    if key == "captureOthers" then Hook.captureOthers = v end
    local S = PUI.Sentinel
    if S and S.ApplyReporter then S:ApplyReporter(key, v) end
  end
  Schema:Register("sentinel." .. key, def)
end
rep("captureOthers", { type = "toggle", default = true, mode = "simple", label = "Capture other addons' errors",
  tooltip = "Also keeps errors from other addons and Blizzard's code in the viewer, on this PC only. They never join Phoenix's reports unless you allow it below." })
rep("uploadOthers", { type = "toggle", default = true, mode = "simple", label = "Include other addons' errors in uploads",
  tooltip = "On: the full log goes to the dashboard, other addons' errors included, so conflicts with Phoenix can be found (same privacy filters: names and paths scrubbed). Off: only Phoenix's own errors leave this PC." })
rep("uploadAddonList", { type = "toggle", default = true, label = "Include the loaded addon list in uploads",
  tooltip = "Sends each installed addon's folder name, version and whether it is enabled, so the dashboard can rank possible conflicts. Nothing else about your addons or character." })
rep("viewerGroup", { type = "select", default = "addon", mode = "simple", choices = { "addon", "flat" },
  choiceLabels = { addon = "One section per addon", flat = "One list, newest first" }, label = "Viewer layout",
  tooltip = "One section per addon (collapsible, with counts, first and last seen and the session), or a single newest-first list." })
rep("viewerCollapsed", { type = "toggle", default = false, label = "Sections start collapsed",
  tooltip = "Addon sections in the viewer open collapsed; click a section header to expand it." })
rep("alertBadge", { type = "toggle", default = true, mode = "simple", label = "Error count badge",
  tooltip = "A small badge with the number of new errors this session; click it to open the viewer." })
rep("alertSound", { type = "toggle", default = false, mode = "simple", label = "Sound on a new error", tooltip = "Plays a sound the first time a new error happens." })
rep("alertSoundName", { type = "select", default = "Raid Warning", choices = function()
    local list = { "Raid Warning", "Ready Check", "Tell", "Alarm" }
    for _, name in ipairs(PUI.Media:List("sound")) do if name ~= "None" then list[#list + 1] = name end end
    return list
  end, label = "Error sound", tooltip = "Which sound plays: four game sounds, then every sound in the media library (yours and other addons' shared sounds)." })
rep("baselineWarn", { type = "range", default = 0, min = 0, max = 50, step = 1, label = "Warn once on many new errors",
  tooltip = "0 = off. Errors seen in 3 or more sessions become your baseline; when this many errors outside the baseline happen in one session, one chat line says so (once per session)." })
rep("privacyAllow", { type = "list", default = {}, maxItems = 30, label = "Words never hidden in paths",
  tooltip = "If your character shares a name with an addon or a system word, it stays visible inside file paths in reports. Addon folder names and client words are already on this list." })
rep("recorder", { type = "toggle", default = false, label = "Developer recorder",
  tooltip = "Records zone, combat, group size, frame-rate band and Phoenix errors, one row per change, into your saved data (/pui record). Off records nothing." })
rep("trace", { type = "toggle", default = false, label = "Developer event trace",
  tooltip = "Keeps the last 200 Phoenix bus signals (module enabled, profile changes, settings) for /pui trace. Off costs nothing." })
rep("alertChat", { type = "toggle", default = false, label = "Chat line on a new error", tooltip = "Prints one line with a link that opens the viewer." })
rep("autoOpen", { type = "toggle", default = false, mode = "simple", label = "Open the viewer on a new error",
  tooltip = "Opens the error viewer by itself. Never during combat: it waits until the fight ends." })
rep("throttle", { type = "range", default = 60, min = 0, max = 600, step = 10, label = "Alert again after (s)",
  tooltip = "The same error alerts at most once in this many seconds (it is always counted)." })
rep("redactNames", { type = "toggle", default = true, label = "Hide names in reports",
  tooltip = "Your character name is replaced by [player] as a whole word, and GUIDs keep only their kind, before anything is shared or uploaded." })
rep("shareAccept", { type = "select", default = "ask", choices = { "ask", "trusted", "never" },
  choiceLabels = { ask = "Ask me every time", trusted = "Ask only for friends and guild", never = "Never accept" },
  label = "Reports shared with you", tooltip = "When another player sends you a report, you get a prompt first (or it is refused)." })
rep("viewerSession", { type = "select", default = "this", choices = { "this", "previous", "all" },
  choiceLabels = { this = "This session", previous = "Previous session", all = "All sessions" }, label = "Viewer opens on", tooltip = "Which session the viewer shows first." })
rep("viewerSource", { type = "select", default = "all", choices = { "all", "phoenix", "others" },
  choiceLabels = { all = "Every addon", phoenix = "Phoenix only", others = "Other addons" }, label = "Viewer shows", tooltip = "Which errors the viewer lists first." })
rep("profiler", { type = "toggle", default = false, label = "Developer profiler",
  tooltip = "Times Phoenix's registered entry points and Ticker jobs (/pui profile). Off costs nothing: no wrappers exist while it is off." })

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
