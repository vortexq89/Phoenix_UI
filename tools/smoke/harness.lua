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
    GetStringWidth = 50, GetStringHeight = 12, GetLineHeight = 12, GetText = "", GetValue = 0, GetNumber = 0,
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
    C_EncodingUtil = { SerializeCBOR = function() return "x" end, CompressString = function(s) return s end,
        EncodeBase64 = function(s) return s end, DecodeBase64 = function(s) return s end,
        DecompressString = function(s) return s end, DeserializeCBOR = function() return nil end },
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
        AddFrame = function() end, AddFrameSettings = function() end, RegisterCallback = function() end,
        GetActiveLayoutName = function() return "Modern" end, IsInEditMode = function() return false end,
        SettingType = setmetatable({}, { __index = function(_, k) return k end }),
    },
}
rawset(env, "LibStub", setmetatable({}, { __call = function(_, name)
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
for _, m in ipairs(ns.moduleList or {}) do
    for _, item in ipairs(ns.options[m.key] or {}) do
        if item.key then
            try("set " .. m.key .. "." .. item.key, function() ns.DB:Set(m, item.key, ns.DB:Get(m, item.key)) end)
        elseif item.get and item.set then
            try("set " .. m.key .. "." .. tostring(item.label), function() item.set(m, item.get(m)) end)
        end
        if item.disabled then try("disabled " .. m.key, item.disabled, m) end
        if item.hidden then try("hidden " .. m.key, item.hidden, m) end
    end
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
-- a representative set of gameplay events with plausible payloads
local events = {
    { "PLAYER_REGEN_DISABLED" }, { "PLAYER_REGEN_ENABLED" }, { "MERCHANT_SHOW" }, { "PLAYER_FLAGS_CHANGED", "player" },
    { "NAME_PLATE_UNIT_ADDED", "nameplate1" }, { "UNIT_HEALTH", "nameplate1" }, { "NAME_PLATE_UNIT_REMOVED", "nameplate1" },
    { "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 133 }, { "UNIT_SPELLCAST_START", "player", "Cast-2", 133 },
    { "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" }, { "CHALLENGE_MODE_COMPLETED" }, { "DUEL_REQUESTED", "Someone" },
    { "ZONE_CHANGED_NEW_AREA" }, { "UI_ERROR_MESSAGE", 1, "x" }, { "BAG_UPDATE_DELAYED" },
}
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

print(("smoke: %d files loaded, %d modules, %d errors"):format(loaded, #(ns.moduleList or {}), #errors))
for _, e in ipairs(errors) do print("  " .. e) end
os.exit(#errors == 0 and 0 or 1)
