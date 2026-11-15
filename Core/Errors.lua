local ADDON, ns = ...

--[[ ns.Errors — the error catcher behind the Bugs module (ARCHITECTURE §15, docs/BUG_REPORTS.md).
    Installed when this file loads, so everything that runs after Phoenix_UI's Core is seen.

    * Lua errors: seterrorhandler(handler). 12.x Blizzard_ScriptErrors installs HandleLuaError the same
      way (its AddLuaErrorHandler hook asserts issecure(), so addons cannot use it). We keep the
      previous handler and ALWAYS call it afterwards: Blizzard's logging, the ScriptErrorsFrame and the
      crash reporter keep working, and so does any other catcher that was installed before us.
    * ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN (kind "taint") and LUA_WARNING (kind "warning")
      arrive as synchronous events.
    * BugGrabber (an OptionalDep, so it loads first) owns the handler: it calls seterrorhandler once and then
      replaces the global with a no-op, and handles those events itself. We consume its results instead of
      fighting it. BugGrabber 12.x (no CallbackHandler any more) announces every capture, new or repeat, with
      EventRegistry:TriggerEvent("BugGrabber.BugGrabbed", tostring(errorTable)); older builds fired
      BugGrabber_BugGrabbed(errorTable) through CallbackHandler. Each announcement counts once. The errors it
      caught this session before we loaded are imported when the SavedVariables bind.
    * Errors from before Phoenix loaded, without BugGrabber: Blizzard's handler (the one we chain to) already
      kept them in ScriptErrorsFrame.errorData (or ScriptErrors.unhandledErrors before that frame exists); they
      are imported once, here, before our handler goes in.
    * Scope: "all" (every addon, the default) or "phoenix" (only Phoenix UI's own errors).

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
E.imported = 0      -- reports taken over from BugGrabber or Blizzard's error frame this session

local db              -- PhoenixUIBugsDB once bound
local buffer = {}     -- reports caught before the SavedVariables are available
local bySession = {}  -- hash -> report, this session only
local active = true   -- capture switch; the chain to the previous handler never stops
local kinds = { error = true, warning = true, taint = true }
local scope = "all"   -- "all" | "phoenix"
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

---------------------------------------------------------------- privacy
-- Reports may leave the PC (PhoenixUploader), so identity is removed before anything is stored or hashed:
-- this character's name and realm, player GUIDs, BattleTags, the Windows user and WoW account folders.
-- Text-like string locals (anything with spaces or non-ASCII: chat lines, tooltips, names of others) are
-- replaced by their length; short token-like values ("player", "BOTTOMLEFT", "Foo.lua") are kept.
local identity -- { name, realm, realmNormalized } once the client knows them

local function plain(v) return type(v) == "string" and v ~= "" and not Secret.IsSecret(v) and canaccessvalue(v) end
local function esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
local WORD, NOTWORD = "%f[%w\128-\255]", "%f[^%w\128-\255]"

local function loadIdentity()
    if identity then return identity end
    local okName, name = pcall(UnitName, "player")
    local okRealm, realm = pcall(GetRealmName)
    local okNorm, norm = pcall(GetNormalizedRealmName)
    name = okName and plain(name) and name or nil
    if not name then return nil end -- too early: try again on the next capture
    identity = {}
    for _, v in ipairs({ name, okRealm and realm, okNorm and norm }) do
        if plain(v) then identity[#identity + 1] = WORD .. esc(v) .. NOTWORD end
    end
    return identity
end
E.ResetIdentity = function() identity = nil end -- smoke tests

local function scrubLocal(line)
    local head, value = line:match('^(%s*[^=]-=%s*)"(.*)"$')
    if not head or value:match("^[%w_%.%-:/\\<>]*$") and #value <= 40 then return line end
    return ('%s"<text, %d bytes>"'):format(head, #value)
end

local function scrub(s, isLocals)
    if s == "" or s == SECRET_TEXT then return s end
    s = s:gsub("Player%-%d+%-%x+", "Player-<guid>")
    s = s:gsub("[%w\128-\255]+#%d%d%d%d+", "<battletag>")
    s = s:gsub("([Uu]sers[/\\])[^/\\\n\"']+", "%1<user>")
    s = s:gsub("([Aa]ccount[/\\])[^/\\\n\"']+", "%1<account>")
    for _, pat in ipairs(loadIdentity() or {}) do s = s:gsub(pat, "<player>") end
    if isLocals then
        local out = {}
        for line in (s .. "\n"):gmatch("(.-)\n") do out[#out + 1] = scrubLocal(line) end
        if out[#out] == "" then out[#out] = nil end
        s = table.concat(out, "\n")
    end
    return s
end
E.Scrub = scrub

local function clean(s, max, isLocals) return scrub(readable(s, max), isLocals) end

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

-- Where the player was: zone name (plain text only) and the combat lockdown flag. Never errors.
local function context()
    local okZone, zone = pcall(GetRealZoneText)
    local okCombat, combat = pcall(InCombatLockdown)
    return okZone and readable(zone, 100) or "", okCombat and combat == true
end

local function add(kind, h, message, stack, locals, source, count)
    if not E.client then build() end
    local t = time()
    local zone, combat = context()
    local r = {
        id = "", hash = h, kind = kind, message = message, stack = stack, locals = locals or "",
        count = count or 1, firstSeen = t, lastSeen = t, session = 0,
        addonVersion = ns.version, interface = E.client.interface, build = E.client.build, locale = E.client.locale,
        source = source or E.Source(message, stack), uploaded = false,
        flavor = ns.flavor, zone = zone, combat = combat,
    }
    bySession[h] = r
    if db then place(r) else buffer[#buffer + 1] = r end
    notify(r, true)
    return r
end

-- Public entry for already-captured text (events, BugGrabber, tests). Returns the report.
local function inScope(source) return scope ~= "phoenix" or source == ADDON end

function E:Record(kind, message, stack, locals, source, count)
    if not active or not kinds[kind] then return nil end
    -- source is worked out before scrubbing: an addon folder is never personal, a "<player>" in its name would be wrong
    source = source or E.Source(readable(message, MAX_MESSAGE), readable(stack, MAX_STACK))
    if not inScope(source) then return nil end
    message, stack = clean(message, MAX_MESSAGE), clean(stack, MAX_STACK)
    local h = E.Hash(message, stack)
    return bump(h, count) or add(kind, h, message, stack, clean(locals, MAX_LOCALS, true), source, count)
end

---------------------------------------------------------------- capture: Lua errors
local previous

local function capture(msg)
    if not allow() then return end
    -- Same arithmetic as Blizzard's GetErrorData: the erroring frame, wherever we sit above it.
    local errHeight = GetErrorCallstackHeight()
    local level = errHeight and (GetCallstackHeight() - (errHeight - 1)) or 4
    local message, stack = readable(msg, MAX_MESSAGE), readable(debugstack(level), MAX_STACK)
    local source = E.Source(message, stack)
    if not inScope(source) then return end
    message, stack = scrub(message), scrub(stack)
    local h = E.Hash(message, stack)
    if bump(h) then return end
    -- skipFunctionsAndUserdata, like Blizzard's own handler: shorter dumps, nothing that cannot be read anyway
    local locals = inEncounter() and "" or clean(debuglocals(level, true), MAX_LOCALS, true)
    add("error", h, message, stack, locals, source)
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
local seenBG = setmetatable({}, { __mode = "k" }) -- BugGrabber error table -> our report (this session)

-- BugGrabber stores LUA_WARNING text with a prefix and blocked actions in its own (localised) sentence, which
-- always starts with the event name in brackets.
local function bugGrabberKind(message)
    if message:find("^LUA_WARNING: ") then return "warning", message:sub(14) end
    if message:find("^%[ADDON_ACTION_") then return "taint", message end
    return "error", message
end

local function fromBugGrabber(err)
    if type(err) ~= "table" then return end
    local known = seenBG[err]
    if known and bySession[known.hash] == known then
        known.count = known.count + 1
        known.lastSeen = time()
        notify(known, false)
        return known
    end
    local message = err.message
    if type(message) ~= "string" or Secret.IsSecret(message) then return end
    local kind, text = bugGrabberKind(message)
    local stack = type(err.stack) == "string" and err.stack or nil
    local locals = type(err.locals) == "string" and err.locals or nil
    local r = E:Record(kind, text, stack, kind == "error" and not inEncounter() and locals or "", nil, 1)
    if r then seenBG[err] = r end
    return r
end
E.FromBugGrabber = fromBugGrabber -- smoke tests

-- BugGrabber 12.x: the payload is tostring(errorTable); BugGrabber:GetErrorByID finds the table again.
local function onBugGrabbed(_, id)
    if not active or capturing or type(id) ~= "string" then return end
    local BG = BugGrabber
    if type(BG) ~= "table" or type(BG.GetErrorByID) ~= "function" then return end
    capturing = true
    local ok, err = pcall(BG.GetErrorByID, BG, id)
    if ok then pcall(fromBugGrabber, err) end
    capturing = false
end
E.OnBugGrabbed = onBugGrabbed -- smoke tests

local function importBugGrabber()
    local BG = BugGrabber
    if type(BG) ~= "table" or type(BG.GetDB) ~= "function" or type(BG.GetSessionId) ~= "function" then return end
    local ok, list = pcall(BG.GetDB, BG)
    local okSession, session = pcall(BG.GetSessionId, BG)
    if not ok or not okSession or type(list) ~= "table" then return end
    for _, err in ipairs(list) do
        if type(err) == "table" and err.session == session and not seenBG[err] then
            if pcall(fromBugGrabber, err) and seenBG[err] then E.imported = E.imported + 1 end
        end
    end
end

---------------------------------------------------------------- errors from before we loaded (no BugGrabber)
local BLIZZARD_WARNING = 1 -- WarningMessageType, a file local in Blizzard_ScriptErrorsFrame.lua

local function importBlizzard()
    local frame = ScriptErrorsFrame
    local data = type(frame) == "table" and frame.errorData
    if type(data) == "table" then
        for _, e in ipairs(data) do
            if type(e) == "table" then
                local kind = e.messageType == BLIZZARD_WARNING and "warning" or "error"
                local ok, r = pcall(E.Record, E, kind, e.message, e.stack, e.locals, nil, tonumber(e.count) or 1)
                if ok and r then E.imported = E.imported + 1 end
            end
        end
    end
    local pending = type(ScriptErrors) == "table" and ScriptErrors.unhandledErrors
    if type(pending) == "table" then
        for _, e in ipairs(pending) do
            if type(e) == "table" then
                local ok, r = pcall(E.Record, E, "error", e.errorMessage, e.stack, e.locals)
                if ok and r then E.imported = E.imported + 1 end
            end
        end
    end
end
E.ImportBlizzard = importBlizzard -- smoke tests

local BG = BugGrabber
if type(BG) == "table" then
    E.mode = "buggrabber"
    if BG.setupCallbacks or BG.RegisterCallback then
        -- BugGrabber before 12.x: CallbackHandler, available once a display addon has embedded it
        if not BG.RegisterCallback and BG.setupCallbacks then pcall(BG.setupCallbacks) end
        if BG.RegisterCallback then
            BG.RegisterCallback(E, "BugGrabber_BugGrabbed", function(_, err)
                if active and not capturing then pcall(fromBugGrabber, err) end
            end)
        end
    elseif EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", onBugGrabbed, E)
    end
else
    pcall(importBlizzard)
    previous = geterrorhandler()
    seterrorhandler(handler)
    ns.Events:On("ADDON_ACTION_BLOCKED", E, onEvent)
    ns.Events:On("ADDON_ACTION_FORBIDDEN", E, onEvent)
    ns.Events:On("LUA_WARNING", E, onEvent)
end

-- True while our handler is the one the game calls (an addon loaded after us may have replaced it).
function E:OwnsHandler() return self.mode == "handler" and geterrorhandler() == handler end

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
    -- share: may PhoenixUploader send this account's reports to the author? On unless the player said no;
    -- installs from before the setting existed get it too. The uploader treats a missing value as true.
    if type(sv.share) ~= "boolean" then sv.share = true end
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
function E:SetScope(v) scope = v == "phoenix" and "phoenix" or "all" end
function E:GetScope() return scope end
function E:GetMode() return self.mode end
function E:SetListener(fn) listener = fn end
function E:GetSession() return db and db.session or 0 end
function E:GetInstallId() return db and db.installId or "" end
function E:GetShare() return not db or db.share ~= false end
function E:SetShare(on) if db then db.share = on and true or false end end
-- The one-time "reports are on by default" notice: true the first time it is asked for, then never again.
function E:TakeShareNotice()
    if not db or db.shareNotice then return false end
    db.shareNotice = true
    return true
end

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

-- Remove one report (viewer). Its hash may be caught again this session as a new report.
function E:Delete(r)
    local list = self:GetReports()
    for i = #list, 1, -1 do
        if list[i] == r then table.remove(list, i) end
    end
    if bySession[r.hash] == r then bySession[r.hash] = nil end
end

-- "Mark as reported": a flag of the player's own (the uploader ignores it; it sends by id, see BUG_REPORTS.md).
function E:SetReported(r, on) r.reported = on and true or nil end

-- Sessions that have reports, newest first: { session, count, firstSeen }.
function E:Sessions()
    local by, out = {}, {}
    for _, r in ipairs(self:GetReports()) do
        local s = by[r.session]
        if not s then
            s = { session = r.session, count = 0, firstSeen = r.firstSeen }
            by[r.session] = s
            out[#out + 1] = s
        end
        s.count = s.count + 1
        if r.firstSeen < s.firstSeen then s.firstSeen = r.firstSeen end
    end
    table.sort(out, function(a, b) return a.session > b.session end)
    return out
end

-- scope: "session" (this session) or "all".
function E:Clear(which)
    local list = self:GetReports()
    if which == "all" then
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
