-- Offline load test for Phoenix_UI (Lua 5.1). Not a WoW emulator: every unknown global, frame and
-- method is a permissive stub. It catches load-order mistakes, nil indexing in file scope and in the
-- boot path, and errors while building every settings page.
-- Usage (from the repo root): lua5.1 tools/smoke/harness.lua
local ROOT = arg and arg[1] or "."
local errors, NAME = {}, "Phoenix_UI"
local function errorHandler(e) errors[#errors + 1] = tostring(e) end
local slashes = {}

---------------------------------------------------------------- permissive stubs
local magic
local function newMagic() return setmetatable({}, getmetatable(magic)) end
local defaults = {
    GetWidth = 400, GetHeight = 300, GetScale = 1, GetEffectiveScale = 1, GetAlpha = 1, GetFrameLevel = 1,
    GetLeft = 10, GetRight = 410, GetTop = 310, GetBottom = 10, GetNumPoints = 1, GetCenter = { 210, 160 },
    GetStringWidth = 50, GetUnboundedStringWidth = 50, GetStringHeight = 12, GetLineHeight = 12, GetText = "", GetValue = 0, GetNumber = 0,
    IsShown = false, IsVisible = false, IsForbidden = false, IsProtected = false, IsMouseOver = false,
    HasFocus = false, GetChecked = false, IsEnabled = true, GetObjectType = "Frame", GetName = nil,
    GetMinMaxValues = { 0, 1 }, GetTexCoord = { 0, 1, 0, 1 }, GetTextColor = { 1, 1, 1, 1 },
    GetVertexColor = { 1, 1, 1, 1 }, GetFont = { "font", 12, "" }, GetCursorPosition = 0, GetNumLetters = 0,
    GetVerticalScrollRange = 0, GetHorizontalScrollRange = 0, GetVerticalScroll = 0, GetNumRegions = 0,
    GetTexture = nil, GetAtlas = nil, GetFontObject = nil, GetParent = nil, GetRegions = {}, GetChildren = {},
}
local scripts = setmetatable({}, { __mode = "k" })
-- Objects Phoenix created itself: unknown lowercase fields are nil (they are our own optional fields),
-- unlike Blizzard globals where any child key exists.
local owned = setmetatable({}, { __mode = "k" })
local frames = {}
local frameMethods = {
    SetScript = function(self, k, fn) scripts[self] = scripts[self] or {}; scripts[self][k] = fn end,
    GetScript = function(self, k) return scripts[self] and scripts[self][k] end,
    HookScript = function(self, k, fn)
        scripts[self] = scripts[self] or {}
        local old = scripts[self][k]
        scripts[self][k] = old and function(...) old(...); fn(...) end or fn
    end,
    RegisterEvent = function(self, ev) self.__events = self.__events or {}; self.__events[ev] = true end,
    RegisterUnitEvent = function(self, ev) self.__events = self.__events or {}; self.__events[ev] = true end,
    UnregisterEvent = function(self, ev) if self.__events then self.__events[ev] = nil end end,
    UnregisterAllEvents = function(self) self.__events = {} end,
    IsEventRegistered = function(self, ev) return self.__events and self.__events[ev] or false end,
    CreateAnimationGroup = function() return newMagic() end,
}
local mt = {}
mt.__index = function(self, k)
    if frameMethods[k] then return frameMethods[k] end
    if owned[self] and type(k) == "string" and k:match("^[%l_]") then return nil end
    if type(k) == "string" and defaults[k] ~= nil or (type(k) == "string" and k:match("^Get") and defaults[k] == nil
        and rawget(defaults, k) == nil and false) then
        local v = defaults[k]
        return function() if type(v) == "table" then return unpack(v) end return v end
    end
    if type(k) == "string" and (k:match("^Is") or k:match("^Has") or k:match("^Can")) then
        return function() return false end
    end
    local child = newMagic()
    if owned[self] then owned[child] = true end
    rawset(self, k, child)
    return child
end
mt.__call = function(self)
    local o = newMagic()
    if owned[self] then owned[o] = true end
    return o
end
mt.__concat = function(a, b) return tostring(a) .. tostring(b) end
mt.__tostring = function() return "<stub>" end
mt.__unm = function() return 0 end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow" }) do mt[op] = function() return 0 end end
mt.__lt = function() return false end
mt.__le = function() return false end
mt.__len = function() return 0 end
magic = setmetatable({}, mt)

local function CreateFrame(_, name)
    local f = newMagic()
    owned[f] = true
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end

---------------------------------------------------------------- environment
-- Globals that must start out nil (libraries create them; SavedVariables start empty).
local NIL = { PhoenixUIDB = true, PhoenixUIBugsDB = true, Phoenix_UIDB = true, Phoenix_UIPerCharDB = true, BugGrabber = true }
local env_cbor -- last payload given to the CBOR stub, so export -> decode round-trips
local env = setmetatable({}, { __index = function(t, k)
    local v = _G[k]
    if v ~= nil or NIL[k] then return v end
    v = newMagic(); rawset(t, k, v); return v
end })
local function band(a, b)
    local r, bit = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + bit end
        a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
    end
    return r
end
local function bor(a, b)
    local r, bit = 0, 1
    while a > 0 or b > 0 do
        if a % 2 == 1 or b % 2 == 1 then r = r + bit end
        a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
    end
    return r
end
local api = {
    CreateFrame = CreateFrame,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    strmatch = string.match, strfind = string.find, strsub = string.sub, strlen = string.len,
    strlower = string.lower, strupper = string.upper, strrep = string.rep, gsub = string.gsub,
    strsplit = function(sep, s)
        local out = {}
        for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
        return unpack(out)
    end,
    tinsert = table.insert, tremove = table.remove, format = string.format,
    hooksecurefunc = function() end,
    bit = { band = band, bor = bor },
    NUM_CONTAINER_FRAMES = 6, NUM_BAG_SLOTS = 4, BACKPACK_CONTAINER = 0, INVSLOT_HEAD = 1, INVSLOT_LAST_EQUIPPED = 19,
    -- WoW's xpcall forwards extra arguments (Lua 5.1's does not).
    xpcall = function(fn, handler, ...)
        local args, n = { ... }, select("#", ...)
        return xpcall(function() return fn(unpack(args, 1, n)) end, handler)
    end,
    issecretvalue = function() return false end, canaccessvalue = function() return true end,
    issecure = function() return false end, InCombatLockdown = function() return false end,
    GetLocale = function() return "enUS" end, GetTime = function() return os.clock() end,
    GetBuildInfo = function() return "12.1.5", "70448", "Oct 2026", 120105 end,
    UnitName = function() return "Tester", "Realm" end, GetRealmName = function() return "Realm" end,
    UnitClass = function() return "Mage", "MAGE", 8 end, UnitLevel = function() return 90 end,
    UnitGUID = function() return "Player-1-0001" end, UnitRace = function() return "Human", "Human" end,
    GetMoney = function() return 12345678 end, GetFramerate = function() return 60 end,
    GetNetStats = function() return 0, 0, 20, 30 end, GetServerTime = function() return os.time() end,
    date = os.date, time = os.time,
    debugstack = function() return "[Interface/AddOns/Phoenix_UI/Core/Test.lua]:1: in function <x>\n[C]: ?" end,
    debuglocals = function() return "x = 1" end,
    GetCallstackHeight = function() return 6 end, GetErrorCallstackHeight = function() return 3 end,
    -- a real handler chain: Core/Errors.lua must keep calling the one it replaced
    geterrorhandler = function() return errorHandler end,
    seterrorhandler = function(fn) errorHandler = fn end,
    C_InstanceEncounter = { IsEncounterInProgress = function() return false end },
    securecallfunction = function(fn, ...) return fn(...) end,
    CreateColor = function(r, g, b, a)
        return { r = r, g = g, b = b, a = a, GetRGB = function() return r, g, b end,
                 GetRGBA = function() return r, g, b, a end }
    end,
    CopyTable = function(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end,
    RegisterNewSlashCommand = function(fn, cmd) slashes[cmd] = fn end,
    PixelUtil = { ConvertPixelsToUIForRegion = function(n) return n end, SetPoint = function() end,
                  GetPixelToUIUnitFactor = function() return 768 / 2160 end, -- 4K panel
                  SetSize = function() end, SetWidth = function() end, SetHeight = function() end },
    C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end, IsAddOnLoaded = function() return false end },
    C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end,
                NewTimer = function() return { Cancel = function() end } end },
    C_CVar = { GetCVar = function() return "1" end, GetCVarBool = function() return true end, SetCVar = function() end },
    C_SpecializationInfo = { GetSpecialization = function() return 1 end,
        GetNumSpecializationsForClassID = function() return 3 end,
        GetSpecializationInfo = function(i) return i, "Spec" .. i, "", 0 end },
    C_EncodingUtil = { SerializeCBOR = function(t) env_cbor = t; return "x" end, CompressString = function(s) return s end,
        EncodeBase64 = function(s) return s end, DecodeBase64 = function(s) return s end,
        DecompressString = function(s) return s end, DeserializeCBOR = function() return env_cbor end },
    RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end }),
    LEVEL = "Level", GetGuildInfo = function() return nil end,
    C_MerchantFrame = { GetNumJunkItems = function() return 0 end, SellAllJunkItems = function() end },
    CanMerchantRepair = function() return false end, GetRepairAllCost = function() return 0, false end,
    C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() return nil end },
    STANDARD_TEXT_FONT = "font", UNIT_NAME_FONT = "font", DAMAGE_TEXT_FONT = "font",
    UISpecialFrames = {}, SlashCmdList = {},
    Settings = { RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end } end,
                 RegisterAddOnCategory = function() end, OpenToCategory = function() end },
    Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return 0 end }) end }),
}
for k, v in pairs(api) do rawset(env, k, v) end
env._G = env
rawset(env, "getfenv", function(n) if n == 0 then return env end return getfenv(n) end)
rawset(env, "PhoenixUIDB", nil)

---------------------------------------------------------------- fake embedded libraries
local libs = {
    ["LibSharedMedia-3.0"] = {
        LOCALE_BIT_western = 1, LOCALE_BIT_ruRU = 2, media = {},
        Register = function(self, kind, name, file)
            self.media[kind] = self.media[kind] or {}; self.media[kind][name] = file; return true
        end,
        Fetch = function(self, kind, name) return self.media[kind] and self.media[kind][name] end,
        List = function(self, kind)
            local out = {}
            for name in pairs(self.media[kind] or {}) do out[#out + 1] = name end
            table.sort(out); return out
        end,
        HashTable = function(self, kind) return self.media[kind] or {} end,
        RegisterCallback = function() end,
    },
    LibEditMode = {
        callbacks = {},
        AddFrame = function() end, AddFrameSettings = function() end,
        RegisterCallback = function(self, event, fn)
            self.callbacks[event] = self.callbacks[event] or {}
            table.insert(self.callbacks[event], fn)
        end,
        GetActiveLayoutName = function() return "Modern" end, IsInEditMode = function() return false end,
        SettingType = setmetatable({}, { __index = function(_, k) return k end }),
    },
}
rawset(env, "LibStub", setmetatable({}, { __call = function(_, name, silent)
    if silent then return libs[name] end -- optional libraries embedded by other addons
    return assert(libs[name], "unknown library " .. tostring(name))
end }))

---------------------------------------------------------------- loader
local ns, loaded = {}, 0
local function run(path)
    local chunk, err = loadfile(ROOT .. "/" .. path)
    if not chunk then errors[#errors + 1] = err; return end
    setfenv(chunk, env)
    local ok, e = pcall(chunk, NAME, path:match("^Libs/") and nil or ns)
    if not ok then errors[#errors + 1] = path .. ": " .. tostring(e) end
    loaded = loaded + 1
end

local function readAll(path)
    local f = assert(io.open(ROOT .. "/" .. path, "r"))
    local s = f:read("*a"); f:close(); return s
end

local function walkXml(path)
    local dir = path:match("^(.*)/") or ""
    local text = readAll(path):gsub("<!%-%-.-%-%->", "")
    for tag, file in text:gmatch("<(%a+)%s+file=[\"']([^\"']+)[\"']") do
        local p = (dir ~= "" and dir .. "/" or "") .. file:gsub("\\", "/")
        if p:match("^Libs/") then -- replaced by the fakes above
        elseif tag == "Include" or p:match("%.xml$") then walkXml(p) else run(p) end
    end
end

for line in readAll("Phoenix_UI.toc"):gmatch("[^\r\n]+") do
    if not line:match("^%s*#") and line:match("%S") then
        local p = line:gsub("\\", "/"):gsub("%s+$", "")
        if p:match("^Libs/") then -- replaced by the fakes above
        elseif p:match("%.xml$") then walkXml(p) else run(p) end
    end
end

---------------------------------------------------------------- boot + exercise
local function fire(event, ...)
    for _, f in ipairs(frames) do
        local s = scripts[f] and scripts[f].OnEvent
        if s and f.__events and f.__events[event] then
            local ok, e = pcall(s, f, event, ...)
            if not ok then errors[#errors + 1] = event .. ": " .. tostring(e) end
        end
    end
end
fire("ADDON_LOADED", NAME)
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)

local function try(label, fn, ...)
    local ok, e = pcall(fn, ...)
    if not ok then errors[#errors + 1] = label .. ": " .. tostring(e) end
end
if ns.Config then
    try("Config:Toggle", ns.Config.Toggle, ns.Config)
    for _, key in ipairs({ "home", "profiles", "about" }) do try("page " .. key, ns.Config.Show, ns.Config, key) end
    for _, m in ipairs(ns.moduleList or {}) do try("page " .. m.key, ns.Config.Show, ns.Config, m.key) end
    for _, m in ipairs(ns.moduleList or {}) do
        try("toggle " .. m.key, ns.SetModuleEnabled, ns, m.key, false)
        try("toggle " .. m.key, ns.SetModuleEnabled, ns, m.key, true)
    end
end
if ns.Profiles then
    try("export", function()
        local s = ns.Profiles:Export()
        assert(type(s) == "string", "export returned " .. tostring(s))
    end)
end
-- write every option back with its current value (exercises OnSettingChanged/Refresh paths)
local function eachItem(list, fn)
    for _, item in ipairs(list or {}) do
        fn(item)
        eachItem(item.cog, fn)
    end
end
for _, m in ipairs(ns.moduleList or {}) do
    eachItem(ns.options[m.key], function(item)
        local key = item.key and item.key:gsub("@", "player")
        if key and not (item.get and item.set) then
            try("set " .. m.key .. "." .. key, function()
                local v = ns.DB:Get(m, key)
                assert(v ~= nil, "option " .. m.key .. "." .. key .. " has no default")
                ns.DB:Set(m, key, v)
            end)
        elseif item.get and item.set then
            try("set " .. m.key .. "." .. tostring(item.label), function() item.set(m, item.get(m)) end)
        end
        if item.disabled then try("disabled " .. m.key, item.disabled, m) end
        if item.hidden then try("hidden " .. m.key, item.hidden, m) end
    end)
end
-- profiles, theme and slash commands
try("profile new", function()
    assert(ns.DB:NewProfile("Smoke", ns.DB:GetProfileName()) ~= false)
    ns.DB:SetProfile("Smoke")
    assert(ns.DB:GetProfileName() == "Smoke", "profile switch failed")
    ns.DB:Set(ns.modules.General, "theme.preset", "frost")
    ns.DB:ResetProfile()
    ns.DB:SetProfile("Default")
    ns.DB:DeleteProfile("Smoke")
end)
-- 11.x settings: chat history and the Mythic+ panel land on their 2.0 keys
try("legacy import", function()
    rawset(env, "Phoenix_UIDB", { profiles = { Old = {
        chat = { history = { enabled = false, lines = 500 } },
        mythicplus = { enabled = true, showTimer = false, showObjectives = false, deathTracker = true, autoGossip = true },
    } } })
    local sv = { profiles = {}, profileKeys = {} }
    ns.Migrations.steps[1].run(sv)
    rawset(env, "Phoenix_UIDB", nil)
    local m = sv.profiles.Old.modules
    assert(m.Chat.keepHistory == false, "chat.history.enabled was not migrated")
    assert(m.MythicPlus.enabled == true and m.MythicPlus.timer == false, "mythicplus.enabled/showTimer were not migrated")
    assert(m.MythicPlus.timerForces == false and m.MythicPlus.timerBosses == false, "showObjectives was not migrated")
    assert(m.MythicPlus.timerDeaths == true and m.MythicPlus.autoGossip == nil, "deathTracker/autoGossip mapping is wrong")
end)
-- colour values are keyed { r, g, b } end to end: swatch -> saved setting -> theme
try("colour round-trip", function()
    local swatch = ns.Widgets:ColorSwatch(env.CreateFrame("Frame"))
    swatch:SetValue({ r = 0.2, g = 0.4, b = 0.6 })
    local v = swatch:GetValue()
    assert(v.r == 0.2 and v.g == 0.4 and v.b == 0.6, "swatch lost a channel")
    local general = ns.modules.General
    ns.DB:Set(general, "theme.custom", v)
    ns.DB:Set(general, "theme.preset", "custom")
    local r, g, b = ns.Theme:Color("accent.primary")
    assert(r == 0.2 and g == 0.4 and b == 0.6, ("custom accent is %s %s %s"):format(tostring(r), tostring(g), tostring(b)))
    ns.DB:Set(general, "theme.preset", "ember")
end)
for _, msg in ipairs({ "", "", "profile", "profile Default", "debug", "debug", "general", "nonsense", "reset" }) do
    try("/pui " .. msg, slashes.pui or error, msg)
end
-- error catcher: the stored shape must match the uploader contract (docs/BUG_REPORTS.md)
try("bugs contract", function()
    local E, db = ns.Errors, env.PhoenixUIBugsDB
    assert(type(db) == "table" and db.schema == 1, "PhoenixUIBugsDB missing or wrong schema")
    assert(type(db.installId) == "string" and db.installId:match("^%x+$") and #db.installId == 16, "bad installId")
    assert(db.session == 1, "session should start at 1, got " .. tostring(db.session))
    local before = #errors
    env.geterrorhandler()("Interface/AddOns/Foo/Foo.lua:12: attempt to index a nil value")
    assert(#errors == before + 1, "the handler must chain to the previous one")
    errors[#errors] = nil
    env.geterrorhandler()("Interface/AddOns/Foo/Foo.lua:99: attempt to index a nil value")
    errors[#errors] = nil
    local r = db.reports[#db.reports]
    assert(#db.reports == 1 and r.count == 2, "same error on another line should dedupe to count 2")
    assert(r.kind == "error" and r.source == "Foo" and r.uploaded == false, "bad kind/source/uploaded")
    assert(r.id == ("%s-%d-%d"):format(db.installId, db.session, 1), "bad id " .. tostring(r.id))
    assert(r.hash:match("^%x+$") and #r.hash == 16, "hash must be 16 hex")
    assert(r.interface and r.build and r.locale and r.addonVersion and r.firstSeen and r.lastSeen, "missing field")
    assert(r.stack ~= "" and r.locals == "x = 1", "stack/locals not captured")
    fire("ADDON_ACTION_BLOCKED", "Bar", "CastSpellByName")
    r = db.reports[#db.reports]
    assert(r.kind == "taint" and r.source == "Bar", "blocked action not recorded")
    fire("LUA_WARNING", "Interface/AddOns/Baz/Baz.lua:3: deprecated")
    assert(db.reports[#db.reports].kind == "warning", "warning not recorded")
    assert(E.Hash("a.lua:1: x", "") == E.Hash("a.lua:2: x", ""), "hash must ignore line numbers")
    assert(E.Source("Interface/AddOns/Blizzard_UIPanels/x.lua:1: y") == "Blizzard", "Blizzard source")
    assert(E.Source("Interface/AddOns/Phoenix_UI/x.lua:1: y") == "Phoenix_UI", "own source")
    local cap = E.cap
    E.cap = 5
    for i = 1, 8 do E:Record("error", "cap test " .. string.rep("z", i)) end
    assert(#db.reports == 5, "cap not applied: " .. #db.reports)
    E.cap = cap
    local bugs = ns.modules.Bugs
    bugs:OpenViewer()
    bugs:GetViewer():Select(2)
    ns.Events:Fire("PUI_BUG", db.reports[1], true)
    E:Clear("all")
    assert(#db.reports == 0, "clear all failed")
end)
-- movers: Edit Mode systems are refused, positions round-trip through the profile
try("movers", function()
    local M = ns.modules.Movers
    assert(M.IsManaged({ system = 1 }) and M.IsManaged({ isManagedFrame = true }) and not M.IsManaged({}),
        "Edit Mode detection")
    M:SetUnlocked(true)
    local e = M:GetEntry("Errors")
    assert(e, "UIErrorsFrame entry missing")
    M.Nudge(e, 10, 0)
    assert(M.db.frames.Errors and M.db.frames.Errors.point, "nudge did not save a position")
    M.SetFrameScale(e, 1.2)
    M:ResetFrame("Errors")
    assert(M.db.frames.Errors == nil, "reset did not clear the position")
    M:SetUnlocked(false)
end)
-- mythic+ timer: Edit Mode sample, a live run with splits, completion and personal best
try("mythic+ timer", function()
    local M, LEM = ns.modules.MythicPlus, libs.LibEditMode
    for _, fn in ipairs(LEM.callbacks.enter or {}) do fn() end
    for _, fn in ipairs(LEM.callbacks.exit or {}) do fn() end
    local done, saved = false, {}
    for _, k in ipairs({ "GetWorldElapsedTimers", "GetWorldElapsedTime", "C_Scenario", "C_ScenarioInfo", "C_ChallengeMode" }) do
        saved[k] = rawget(env, k) or false
    end
    local criteria = {
        { description = "Boss A", completed = true, quantity = 1, totalQuantity = 1, criteriaID = 11, quantityString = "1" },
        { description = "Boss B", completed = false, quantity = 0, totalQuantity = 1, criteriaID = 12, quantityString = "0" },
        { description = "Enemy Forces", completed = false, quantity = 40, totalQuantity = 285, criteriaID = 13,
          isWeightedProgress = true, quantityString = "123%" },
    }
    rawset(env, "GetWorldElapsedTimers", function() return 7 end)
    rawset(env, "GetWorldElapsedTime", function() return 0, 600, 0 end) -- the stub Enum maps every value to 0
    rawset(env, "C_Scenario", { GetStepInfo = function() return "Stage", "", #criteria end })
    rawset(env, "C_ScenarioInfo", { GetCriteriaInfo = function(i) return criteria[i] end })
    rawset(env, "C_ChallengeMode", {
        GetActiveChallengeMapID = function() return 500 end,
        GetMapUIInfo = function() return "Test Dungeon", 500, 1800 end,
        GetActiveKeystoneInfo = function() return 10, { 9, 10 }, true end,
        GetAffixInfo = function(id) return "Affix" .. id end,
        GetDeathCount = function() return 2, 10 end,
        GetChallengeCompletionInfo = function()
            return done and { time = 1500000, onTime = true, practiceRun = false } or nil
        end,
    })
    fire("CHALLENGE_MODE_START")
    assert(M.global.run.mapID == 500 and M.global.run.splits["11"] == 600, "boss split not recorded")
    criteria[2].completed = true
    fire("SCENARIO_CRITERIA_UPDATE")
    assert(M.global.run.splits["12"] == 600, "second split not recorded")
    done = true
    fire("CHALLENGE_MODE_COMPLETED")
    assert(M.global.best["500:10"] == 1500, "personal best not stored: " .. tostring(M.global.best["500:10"]))
    local bs = M.global.bestSplits["500:10"]
    assert(bs and bs["11"] == 600 and bs["12"] == 600, "best run splits not stored")
    -- a later run renders deltas against them
    done = false
    M.global.run = { splits = {} }
    fire("CHALLENGE_MODE_RESET")
    fire("CHALLENGE_MODE_START")
    M:RefreshTimer()
    M.global.best["500:10"], M.global.bestSplits["500:10"] = nil, nil
    M.global.run = { splits = {} }
    for k, v in pairs(saved) do rawset(env, k, v or nil) end
end)
-- current pull: summed over hostile nameplates in combat, dropped as soon as one value is secret
try("mythic+ pull", function()
    local M = ns.modules.MythicPlus
    local saved = {}
    for _, k in ipairs({ "UnitAffectingCombat", "UnitCanAttack", "C_ScenarioInfo" }) do saved[k] = rawget(env, k) or false end
    rawset(env, "UnitAffectingCombat", function() return true end)
    rawset(env, "UnitCanAttack", function() return true end)
    rawset(env, "C_ScenarioInfo", { GetUnitCriteriaProgressValues = function(unit) return unit == "nameplate2" and 4 or 3 end })
    fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    assert(M.PullCount() == 7, "pull sum is " .. tostring(M.PullCount()))
    local isSecret = ns.Secret.IsSecret
    ns.Secret.IsSecret = function(v) return v == 4 end
    local ok, sum = pcall(M.PullCount)
    ns.Secret.IsSecret = isSecret
    assert(ok and sum == nil, "a secret count must drop the pull silently")
    fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
    assert(M.PullCount() == 0, "removed plates still counted")
    for k, v in pairs(saved) do rawset(env, k, v or nil) end
end)
-- party keystones over the LibKeystone protocol: store answers, answer requests, stay quiet in lockdown
try("mythic+ keystones", function()
    local K = ns.modules.MythicPlus.Keystones
    local saved, sent, locked = {}, {}, false
    for _, k in ipairs({ "UnitName", "UnitClass", "IsInGroup", "IsInRaid", "Ambiguate", "C_ChatInfo", "C_MythicPlus" }) do
        saved[k] = rawget(env, k) or false
    end
    rawset(env, "UnitName", function(unit) return unit == "party1" and "Tank" or (unit == "player" and "Me" or nil) end)
    rawset(env, "UnitClass", function() return "Warrior", "WARRIOR" end)
    rawset(env, "IsInGroup", function() return true end)
    rawset(env, "IsInRaid", function() return false end)
    rawset(env, "Ambiguate", function(name) return (name:gsub("%-.*$", "")) end)
    rawset(env, "C_MythicPlus", { GetOwnedKeystoneLevel = function() return 12 end,
        GetOwnedKeystoneChallengeMapID = function() return 501 end })
    rawset(env, "C_ChatInfo", { RegisterAddonMessagePrefix = function() end,
        InChatMessagingLockdown = function() return locked end,
        SendAddonMessage = function(prefix, text, channel) sent[#sent + 1] = prefix .. "|" .. text .. "|" .. channel end })
    fire("CHAT_MSG_ADDON", "LibKS", "14,500,3120", "PARTY", "Tank-Realm")
    assert(K.keys.Tank and K.keys.Tank.level == 14 and K.keys.Tank.mapID == 500, "a party keystone was not stored")
    fire("CHAT_MSG_ADDON", "LibKS", "R", "PARTY", "Tank-Realm")
    assert(sent[#sent] and sent[#sent]:match("^LibKS|12,501,%d+|PARTY$"), "no answer to a request: " .. tostring(sent[#sent]))
    local rows = K:Rows()
    assert(#rows == 2 and rows[1].own and rows[2].level == 14, "keystone rows are wrong")
    locked = true
    local n = #sent
    K:Request(); K:Share()
    assert(#sent == n, "addon messages were sent during chat lockdown")
    fire("CHAT_MSG_ADDON", "LibKS", "garbage", "PARTY", "Tank-Realm")
    K.keys = {}
    for k, v in pairs(saved) do rawset(env, k, v or nil) end
end)
-- a representative set of gameplay events with plausible payloads
local events = {
    { "PLAYER_REGEN_DISABLED" }, { "PLAYER_REGEN_ENABLED" }, { "MERCHANT_SHOW" }, { "PLAYER_FLAGS_CHANGED", "player" },
    { "NAME_PLATE_UNIT_ADDED", "nameplate1" }, { "UNIT_HEALTH", "nameplate1" }, { "NAME_PLATE_UNIT_REMOVED", "nameplate1" },
    { "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 133 }, { "UNIT_SPELLCAST_START", "player", "Cast-2", 133 },
    { "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" }, { "CHALLENGE_MODE_COMPLETED" }, { "DUEL_REQUESTED", "Someone" },
    { "ZONE_CHANGED_NEW_AREA" }, { "UI_ERROR_MESSAGE", 1, "x" }, { "BAG_UPDATE_DELAYED" },
}
-- scope bar: "Apply to: All" writes every unit, "Copy settings from" replaces the picked unit's settings
try("scope apply/copy", function()
    local m = ns.modules.UnitFrames
    local page = ns.Config:Show("UnitFrames")
    assert(page.scope and page.scope.unit == "player", "UnitFrames page has no unit scope")
    local row
    for _, r in ipairs(page.rows) do if r.item.key == "units.@.texture" then row = r end end
    page.scope.mode = "all"
    row.control.onChange(row.control, "Aurora")
    for _, u in ipairs(m.UNITS) do assert(m.db.units[u].texture == "Aurora", u .. " missed Apply to: All") end
    page.scope.mode = "this"
    row.control.onChange(row.control, "Frost")
    assert(m.db.units.player.texture == "Frost" and m.db.units.target.texture == "Aurora", "Apply to: This leaked")
    page.scope.mode, page.scope.multi = "multi", { focus = true }
    row.control.onChange(row.control, "Glass")
    assert(m.db.units.focus.texture == "Glass" and m.db.units.target.texture == "Aurora", "Apply to: Multiple is wrong")
    page.scope.mode, page.scope.unit = "this", "pet"
    m.db.units.player.name.size = 17
    ns.DB:Set(m, "units.pet", ns.Util.DeepCopy(m.db.units.player))
    assert(m.db.units.pet.name.size == 17 and m.db.units.pet ~= m.db.units.player, "copy settings shares tables")
    assert(m.db.units["@"] == nil, "a scoped key was written literally")
end)
-- every cog popover builds its rows (and none nests another cog); tabs switch
try("cogs and tabs", function()
    local opened = 0
    for _, m in ipairs(ns.moduleList) do
        local page = ns.Config:Show(m.key)
        for _, r in ipairs(page.rows or {}) do
            if r.cog then
                r.cog.onClick(r.cog)
                assert(r.cogContent and #r.cogContent.rows == #r.item.cog, m.key .. ": cog rows missing")
                opened = opened + 1
            end
        end
        if page.tabs then page.tabs.onChange(page.tabs, 2) end
    end
    assert(opened > 10, "expected the style cogs to be reachable, opened " .. opened)
end)
-- search reaches cog sub-options and a result focuses the right tab
try("search", function()
    ns.Config:Search("outline")
    local rows = ns.Config.results and ns.Config.results.rows or {}
    local hit
    for _, r in ipairs(rows) do if r.entry and r.entry.item and r.entry.item.key == "health.outline" then hit = r.entry end end
    assert(hit, "the nameplate health text outline (a cog option) is not searchable")
    local page = ns.Config:Show("NamePlates")
    page:Focus(hit.item)
    assert(page.tab == 2, "focusing a Text-tab option did not switch tabs")
    ns.Config:Search("")
end)
-- previews: every kind builds and redraws with its module's settings, and with a unit picked
try("previews", function()
    local n = 0
    for kind, def in pairs(ns.Previews.kinds) do
        local m = assert(ns.modules[def.module], kind .. " preview names no module")
        local stage = ns.Previews:Create(kind, env.CreateFrame("Frame"), m, { scope = { unit = "target" } })
        stage:Redraw()
        n = n + 1
    end
    assert(n >= 1, "no previews registered")
end)
-- 2.0 -> 2.1: flat size keys move into the per-element style tables
try("style keys move", function()
    local sv = { profiles = { P = { modules = { NamePlates = { textSize = 13 } } } } }
    ns.Migrations.steps[2].run(sv)
    local np = sv.profiles.P.modules.NamePlates
    assert(np.health.size == 13 and np.textSize == nil, "NamePlates.textSize was not moved")
    sv = { profiles = { P = { modules = { ActionBars = { fontSize = 9 }, Auras = { durationSize = 8, countSize = 15 } } } } }
    ns.Migrations.steps[2].run(sv)
    local mods = sv.profiles.P.modules
    assert(mods.ActionBars.hotkey.size == 9 and mods.Auras.duration.size == 8 and mods.Auras.count.size == 15,
        "ActionBars/Auras sizes were not moved")
    sv = { profiles = { P = { modules = { GroupFrames = { nameSize = 13 } } } } }
    ns.Migrations.steps[3].run(sv)
    assert(sv.profiles.P.modules.GroupFrames.name.size == 13, "GroupFrames.nameSize was not moved by step 3")
end)

-- export strings carry the schema; our own strings must import, older ones are upgraded on the way in
try("schema and import", function()
    local steps = ns.Migrations.steps
    assert(steps[#steps].version == ns.C.SCHEMA, "ns.C.SCHEMA is not the last migration step")
    assert(ns.DB.sv.schema == ns.C.SCHEMA, "saved schema " .. tostring(ns.DB.sv.schema) .. " after migrations")
    local payload, err = ns.Profiles:Decode(ns.Profiles:Export())
    assert(payload, "a fresh export does not decode: " .. tostring(err))
    local old = { schema = 1, name = "Old", profile = { modules = { NamePlates = { textSize = 14 } } } }
    local current = ns.DB:GetProfileName()
    local name = ns.Profiles:Import(old, "Old")
    local np = ns.DB.sv.profiles[name].modules.NamePlates
    assert(np.health and np.health.size == 14 and np.textSize == nil, "an old export was not upgraded on import")
    ns.DB:SetProfile(current)
    ns.DB.sv.profiles[name] = nil
end)

for _, e in ipairs(events) do fire(unpack(e)) end
fire("PLAYER_LOGOUT")

-- icon system: every name the UI asked for must exist, and tier selection must follow physical pixels
for name in pairs(ns.Icons and ns.Icons.missing or {}) do errors[#errors + 1] = "unknown icon: " .. name end
try("icon tiers", function()
    local probe = env.CreateFrame("Frame"):CreateTexture()
    ns.Icons:Apply(probe, "home", 16) -- 16 * 1 / (768/2160) = 45 px -> 48 px cells
    local _, cell = ns.Icons:GetTier(probe)
    assert(cell == 48, "16 pt icon at 4K should use 48 px cells, got " .. tostring(cell))
    ns.Icons:Apply(probe, "home", 30)
    _, cell = ns.Icons:GetTier(probe)
    assert(cell == 96, "30 pt icon at 4K should use 96 px cells, got " .. tostring(cell))
    assert(ns.Icons:Markup("home", 14):find("Icons48", 1, true), "markup should pick the 48 px atlas")
end)

-- media: every bundled font and bar resolves to a file of ours, old keys still work, pickers open
try("media", function()
    local M = ns.Media
    assert(#M.fonts >= 80 and #M.bars >= 20, "bundled media lists are short")
    for _, f in ipairs(M.fonts) do
        assert(M:Font(f.key):find("Phoenix_UI", 1, true), "font " .. f.key .. " does not resolve")
        assert(f.name:find("^Phoenix "), "font " .. f.key .. " is not registered under Phoenix")
    end
    assert(M:Font("Inter") == M:Font("InterBold") and M:Font("Cinzel") == M:Font("CinzelBold"), "2.0 font keys lost")
    for _, b in ipairs(M.bars) do assert(M:Bar(b.key):find("Phoenix_UI", 1, true), "bar " .. b.key) end
    local lsm = env.LibStub("LibSharedMedia-3.0")
    assert(lsm:Fetch("font", "Phoenix Inter Bold") and lsm:Fetch("statusbar", "Phoenix Aurora"), "LSM registration")
    assert(lsm:Fetch("border", "Phoenix Solid"), "LSM border")
    local list = M:List("font")
    assert(list[1].font and list[1].group, "font list items lack their sample font or group")
    local d = ns.Widgets:Dropdown(env.CreateFrame("Frame"), function() return M:List("statusbar") end, "bar")
    d:SetValue("Aurora")
    scripts[d].OnClick(d)
end)

print(("smoke: %d files loaded, %d modules, %d errors"):format(loaded, #(ns.moduleList or {}), #errors))
for _, e in ipairs(errors) do print("  " .. e) end
os.exit(#errors == 0 and 0 or 1)
