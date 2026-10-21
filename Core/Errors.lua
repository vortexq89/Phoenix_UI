local ADDON, ns = ...

--[[ ns.Errors — the error catcher behind the Bugs module (ARCHITECTURE §15, docs/BUG_REPORTS.md).
    Installed when this file loads, so everything that runs after Phoenix_UI's Core is seen.

    * Lua errors: seterrorhandler(handler). 12.x Blizzard_ScriptErrors installs HandleLuaError the same
      way (its AddLuaErrorHandler hook asserts issecure(), so addons cannot use it). We keep the
      previous handler and ALWAYS call it afterwards: Blizzard's logging, the ScriptErrorsFrame and the
      crash reporter keep working, and so does any other catcher that was installed before us.
    * ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN (kind "taint") and LUA_WARNING (kind "warning")
      arrive as synchronous events.
    * BugGrabber (an OptionalDep, so it loads first) replaces seterrorhandler with a no-op and listens to
      those events itself. We then subscribe to its BugGrabber_BugGrabbed callback and import the errors
      it caught earlier this session instead of installing anything.

    Midnight: an error raised by tainted code may carry a secret message; secrets are never stored,
    compared or concatenated (they become SECRET_TEXT), and |K strings are neutralised like Blizzard does.
    Reports are deduplicated per session by a stable hash, flood-throttled, and capped. ]]
local E = {}
ns.Errors = E

local Secret = ns.Secret
local MAX_MESSAGE, MAX_STACK, MAX_LOCALS, HASH_FRAMES = 2000, 6000, 6000, 3
local RATE, BURST = 10, 30            -- flood throttle: sustained captures per second, burst size
local SECRET_TEXT = "<secret value>"
local TAINT = "[%s] AddOn '%s' tried to call the protected function '%s'."
local SCHEMA = 1

E.cap = 500         -- reports kept in PhoenixUIBugsDB (oldest dropped first)
E.dropped = 0       -- captures refused by the throttle this session
E.mode = "handler"  -- "handler" or "buggrabber"

local db              -- PhoenixUIBugsDB once bound
local buffer = {}     -- reports caught before the SavedVariables are available
local bySession = {}  -- hash -> report, this session only
local active = true   -- capture switch; the chain to the previous handler never stops
local kinds = { error = true, warning = true, taint = true }
local capturing, seq = false, 0
local tokens, refilled = BURST, 0
local listener, queued, flushScheduled = nil, {}, false

---------------------------------------------------------------- text helpers
-- Plain, storable text: secrets and inaccessible values never leave this function.
local function readable(s, max)
    if s == nil then return "" end
    if Secret.IsSecret(s) or not canaccessvalue(s) then return SECRET_TEXT end
    s = (tostring(s):gsub("|([kK])", "%1"))
    if #s > max then s = s:sub(1, max) .. "\n…" end
    return s
end

-- Remove what varies between otherwise identical errors: line numbers, memory addresses, path prefixes.
local function normalize(s)
    s = s:gsub("[Ii]nterface[/\\][Aa]dd[Oo]ns[/\\]", "")
    s = s:gsub("%[string \"@?", "[")
    s = s:gsub("0x%x+", "0x")
    s = s:gsub("(%a+): 0*%x%x%x%x%x%x+", "%1:")
    s = s:gsub(":%d+:", ":")
    return s
end

local function stackHead(stack)
    local out, n = {}, 0
    for line in stack:gmatch("[^\n]+") do
        n = n + 1
        out[n] = line
        if n >= HASH_FRAMES then break end
    end
    return table.concat(out, "\n")
end

-- Two 32-bit polynomial hashes -> 16 hex digits. Formatted in 16-bit halves: %x on doubles above 2^31
-- is not portable across the 32-bit `long` of the Windows client.
local function hex32(v) return ("%04x%04x"):format(math.floor(v / 65536), v % 65536) end
local function hash(s)
    local a, b = 5381, 0
    for i = 1, #s do
        local c = s:byte(i)
        a = (a * 33 + c) % 4294967296
        b = (b * 131 + c) % 4294967296
    end
    return hex32(a) .. hex32(b)
end
E.Hash = function(message, stack) return hash(normalize(message) .. "\n" .. normalize(stackHead(stack or ""))) end

-- Which addon raised it: the first Interface/AddOns/<name>/ in the message, else in the stack.
local function addonIn(text)
    local name = text:match("[Aa]dd[Oo]ns[/\\]([^/\\\"%]]+)[/\\]")
    if not name then return nil end
    if name == ADDON then return ADDON end
    if name:find("^Blizzard_") then return "Blizzard" end
    return name
end
function E.Source(message, stack)
    return addonIn(message) or addonIn(stack or "") or "Unknown"
end

-- Drop the frames of our own capture path (event dispatch, SafeCall, this file) from the top of a stack.
local OWN = { "Core[/\\]Errors%.lua", "Core[/\\]Events%.lua", "Core[/\\]Namespace%.lua", "^%[C%]" }
local function ownFrame(line)
    for _, pat in ipairs(OWN) do
        if line:find(pat) and (pat:sub(1, 1) == "^" or line:find(ADDON, 1, true)) then return true end
    end
    return false
end
local function trimOwn(stack)
    local out, skipping = {}, true
    for line in stack:gmatch("[^\n]+") do
        if not (skipping and ownFrame(line)) then
            skipping = false
            out[#out + 1] = line
        end
    end
    return table.concat(out, "\n")
end

local function inEncounter()
    local v = C_InstanceEncounter.IsEncounterInProgress()
    return Secret.IsSecret(v) or v == true
end

-- Flood throttle (token bucket).
local function allow()
    local t = GetTime()
    tokens = math.min(BURST, tokens + (t - refilled) * RATE)
    refilled = t
    if tokens < 1 then
        E.dropped = E.dropped + 1
        return false
    end
    tokens = tokens - 1
    return true
end

---------------------------------------------------------------- storage
local function build()
    local version, buildNumber, _, interface = GetBuildInfo()
    E.client = { interface = interface, build = version .. "." .. buildNumber, locale = GetLocale() }
end

local function notify(r, isNew)
    if not listener then return end
    queued[#queued + 1] = { r, isNew }
    if flushScheduled then return end
    flushScheduled = true
    -- outside the erroring call: UI work never runs inside someone else's error path
    C_Timer.After(0, function()
        flushScheduled = false
        local list = queued
        queued = {}
        for _, q in ipairs(list) do ns.SafeCall(listener, q[1], q[2]) end
    end)
end

local function place(r)
    seq = seq + 1
    r.session = db.session
    r.id = ("%s-%d-%d"):format(db.installId, db.session, seq)
    local list = db.reports
    list[#list + 1] = r
    while #list > E.cap do
        local old = table.remove(list, 1)
        if bySession[old.hash] == old then bySession[old.hash] = nil end
    end
end

-- Existing report for this hash this session: count it and return it.
local function bump(h, count)
    local r = bySession[h]
    if not r then return nil end
    r.count = r.count + (count or 1)
    r.lastSeen = time()
    notify(r, false)
    return r
end

local function add(kind, h, message, stack, locals, source, count)
    if not E.client then build() end
    local t = time()
    local r = {
        id = "", hash = h, kind = kind, message = message, stack = stack, locals = locals or "",
        count = count or 1, firstSeen = t, lastSeen = t, session = 0,
        addonVersion = ns.version, interface = E.client.interface, build = E.client.build, locale = E.client.locale,
        source = source or E.Source(message, stack), uploaded = false,
    }
    bySession[h] = r
    if db then place(r) else buffer[#buffer + 1] = r end
    notify(r, true)
    return r
end

-- Public entry for already-captured text (events, BugGrabber, tests). Returns the report.
function E:Record(kind, message, stack, locals, source, count)
    if not active or not kinds[kind] then return nil end
    message, stack = readable(message, MAX_MESSAGE), readable(stack, MAX_STACK)
    local h = E.Hash(message, stack)
    return bump(h, count) or add(kind, h, message, stack, readable(locals, MAX_LOCALS), source, count)
end

---------------------------------------------------------------- capture: Lua errors
local previous

local function capture(msg)
    if not allow() then return end
    -- Same arithmetic as Blizzard's GetErrorData: the erroring frame, wherever we sit above it.
    local errHeight = GetErrorCallstackHeight()
    local level = errHeight and (GetCallstackHeight() - (errHeight - 1)) or 4
    local message = readable(msg, MAX_MESSAGE)
    local stack = readable(debugstack(level), MAX_STACK)
    local h = E.Hash(message, stack)
    if bump(h) then return end
    local locals = inEncounter() and "" or readable(debuglocals(level), MAX_LOCALS)
    add("error", h, message, stack, locals)
end

local function handler(msg, ...)
    if active and not capturing then
        capturing = true
        pcall(capture, msg)
        capturing = false
    end
    if previous then return previous(msg, ...) end
end
E.handler = handler

---------------------------------------------------------------- capture: blocked actions and warnings
local function onEvent(_, event, a, b)
    if not active or capturing or not kinds[event == "LUA_WARNING" and "warning" or "taint"] or not allow() then return end
    capturing = true
    local stack = trimOwn(readable(debugstack(2), MAX_STACK))
    if event == "LUA_WARNING" then
        local text = type(a) == "string" and a or b -- payload is (warningText); older clients sent (type, text)
        pcall(E.Record, E, "warning", text, stack, "")
    else
        local name = readable(a, 200)
        name = name ~= "" and name or "Unknown"
        pcall(E.Record, E, "taint", TAINT:format(event, name, readable(b, 200)), stack, "", name == ADDON and ADDON or name)
    end
    capturing = false
end

---------------------------------------------------------------- BugGrabber coexistence
local function fromBugGrabber(err, count)
    if type(err) ~= "table" or type(err.message) ~= "string" then return end
    local kind = err.message:find("ADDON_ACTION_", 1, true) and "taint" or "error"
    E:Record(kind, err.message, err.stack, err.locals, nil, count)
end

local function importBugGrabber()
    local BG = BugGrabber
    local ok, list = pcall(BG.GetDB, BG)
    local okSession, session = pcall(BG.GetSessionId, BG)
    if not ok or not okSession or type(list) ~= "table" then return end
    for _, err in ipairs(list) do
        if err.session == session then fromBugGrabber(err, tonumber(err.counter) or 1) end
    end
end

local BG = BugGrabber
if type(BG) == "table" then
    E.mode = "buggrabber"
    -- BugGrabber does not embed CallbackHandler; setupCallbacks makes RegisterCallback appear when one is loaded.
    if not BG.RegisterCallback and BG.setupCallbacks then pcall(BG.setupCallbacks) end
    if BG.RegisterCallback then
        BG.RegisterCallback(E, "BugGrabber_BugGrabbed", function(_, err) fromBugGrabber(err) end)
    end
else
    previous = geterrorhandler()
    seterrorhandler(handler)
    ns.Events:On("ADDON_ACTION_BLOCKED", E, onEvent)
    ns.Events:On("ADDON_ACTION_FORBIDDEN", E, onEvent)
    ns.Events:On("LUA_WARNING", E, onEvent)
end

---------------------------------------------------------------- binding and queries
local function newInstallId()
    local p = {}
    for i = 1, 4 do p[i] = ("%04x"):format(math.random(0, 65535)) end
    return table.concat(p)
end

-- Called once at ADDON_LOADED by the Bugs module. enabled = false: stop capturing and drop the buffer.
function E:Open(enabled)
    active = enabled and true or false
    if not active then
        wipe(buffer)
        wipe(bySession)
        return
    end
    if db then return end
    local sv = type(PhoenixUIBugsDB) == "table" and PhoenixUIBugsDB or {}
    sv.schema = sv.schema or SCHEMA
    if type(sv.installId) ~= "string" or not sv.installId:match("^%x+$") or #sv.installId ~= 16 then
        sv.installId = newInstallId()
    end
    sv.reports = type(sv.reports) == "table" and sv.reports or {}
    sv.session = (tonumber(sv.session) or 0) + 1
    PhoenixUIBugsDB = sv
    db = sv
    for _, r in ipairs(buffer) do place(r) end
    wipe(buffer)
    if E.mode == "buggrabber" then importBugGrabber() end
end

function E:SetActive(on)
    if on and not db then return self:Open(true) end
    active = on and true or false
end

function E:IsActive() return active end
function E:SetKinds(t) kinds = t end
function E:SetListener(fn) listener = fn end
function E:GetSession() return db and db.session or 0 end
function E:GetInstallId() return db and db.installId or "" end

function E:GetReports()
    return db and db.reports or buffer
end

-- Reports this session: unique count and total occurrences.
function E:CountSession()
    local unique, total = 0, 0
    for _, r in pairs(bySession) do
        unique = unique + 1
        total = total + r.count
    end
    return unique, total
end

-- scope: "session" (this session) or "all".
function E:Clear(scope)
    local list = self:GetReports()
    if scope == "all" then
        wipe(list)
    else
        local session = self:GetSession()
        for i = #list, 1, -1 do
            if list[i].session == session then table.remove(list, i) end
        end
    end
    wipe(bySession)
    E.dropped = 0
end
