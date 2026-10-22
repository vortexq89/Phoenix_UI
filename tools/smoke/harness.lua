-- Offline load test for Phoenix_UI (Lua 5.1). Not a WoW emulator: every unknown global, frame and
-- method is a permissive stub. It catches load-order mistakes, nil indexing in file scope and in the
-- boot path, and errors while building every settings page.
-- Usage (from the repo root): lua5.1 tools/smoke/harness.lua [root] [retail|forever]
-- "forever" boots the WoW Forever client (Interface 16001, the _Forever TOCs, no encounter timeline or
-- warnings) and checks that retail-only features are gone rather than broken. tools/check_flavors.py runs both.
local ROOT = arg and arg[1] or "."
local FLAVOR = arg and arg[2] or os.getenv("PUI_FLAVOR") or "retail"
assert(FLAVOR == "retail" or FLAVOR == "forever", "flavor must be retail or forever")
local RETAIL = FLAVOR == "retail"
local TOC_SUFFIX = RETAIL and "" or "_Forever"
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
    GetVerticalScrollRange = 0, GetNumMaskTextures = 0, EnumerateActive = { function() end }, GetHorizontalScrollRange = 0, GetVerticalScroll = 0, GetNumRegions = 0,
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
    -- visibility is tracked so layout code (collapsed groups, hidden rows) can be asserted
    Show = function(self) rawset(self, "__shown", true) end,
    Hide = function(self) rawset(self, "__shown", false) end,
    SetShown = function(self, v) rawset(self, "__shown", v and true or false) end,
    IsShown = function(self) return owned[self] ~= nil and rawget(self, "__shown") ~= false end,
}
-- Frame-only methods (SimpleFrameAPI, not SimpleRegion/TextureBase): a texture or font string does not have
-- them, so calling one is "attempt to call a nil value" in game and must be one here too.
local FRAME_ONLY = { GetEffectiveAlpha = true, CreateTexture = true, CreateFontString = true, RegisterEvent = true,
    RegisterUnitEvent = true, UnregisterEvent = true, SetFrameLevel = true, GetFrameLevel = true, SetFrameStrata = true,
    EnableMouse = true, SetMovable = true, RegisterForDrag = true, GetChildren = true, SetScript = true, HookScript = true }
local regions = setmetatable({}, { __mode = "k" })
local function newRegion()
    local r = newMagic()
    owned[r] = true
    regions[r] = true
    return r
end
frameMethods.CreateTexture = function() return newRegion() end
frameMethods.CreateMaskTexture = function() return newRegion() end
frameMethods.CreateFontString = function() return newRegion() end
local mt = {}
mt.__index = function(self, k)
    if regions[self] and FRAME_ONLY[k] then return nil end
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
local NIL = { PhoenixUIDB = true, PhoenixUIBugsDB = true, Phoenix_UIDB = true, Phoenix_UIPerCharDB = true, BugGrabber = true,
    PhoenixUISimDB = true, PhoenixUISimResults = true }
local postCalls = {} -- TooltipDataProcessor.AddTooltipPostCall registrations
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
    -- instance hooks on plain fields run after the original (enough to test our post-hooks); others are ignored
    hooksecurefunc = function(t, name, fn)
        if type(t) == "table" and type(name) == "string" and type(rawget(t, name)) == "function" then
            local orig = rawget(t, name)
            rawset(t, name, function(...) local r = { orig(...) }; fn(...); return unpack(r) end)
        end
    end,
    bit = { band = band, bor = bor },
    NUM_CONTAINER_FRAMES = 6, NUM_BAG_SLOTS = 4, BACKPACK_CONTAINER = 0, INVSLOT_HEAD = 1, INVSLOT_LAST_EQUIPPED = 19,
    -- WoW's xpcall forwards extra arguments (Lua 5.1's does not).
    xpcall = function(fn, handler, ...)
        local args, n = { ... }, select("#", ...)
        return xpcall(function() return fn(unpack(args, 1, n)) end, handler)
    end,
    issecretvalue = function() return false end, canaccessvalue = function() return true end,
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCalls[#postCalls + 1] = fn end },
    issecure = function() return false end, InCombatLockdown = function() return false end,
    GetLocale = function() return "enUS" end, GetTime = function() return os.clock() end,
    GetBuildInfo = RETAIL and function() return "12.1.5", "70448", "Oct 2026", 120105 end
        or function() return "1.60.1", "70532", "Oct 2026", 16001 end,
    UnitName = function() return "Tester", "Realm" end, GetRealmName = function() return "Realm" end,
    GetNormalizedRealmName = function() return "Realm" end,
    BreakUpLargeNumbers = function(n) return tostring(n) end,
    UnitClass = function() return "Mage", "MAGE", 8 end, UnitLevel = function() return 90 end,
    UnitThreatSituation = function() return nil end,
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
    C_CVar = { GetCVar = function() return "1" end, GetCVarBool = function() return true end, SetCVar = function() end,
               GetCVarBitfield = function() return false end, SetCVarBitfield = function() end },
    -- encounter timeline / warnings (12.x): no events unless a test adds them
    -- (Forever: the APIs exist but the game's timeline and warnings are off, IsFeatureAvailable says so)
    C_EncounterTimeline = { IsFeatureAvailable = function() return RETAIL end,
        GetEventList = function() return {} end, AddEditModeEvents = function() return 30 end,
        CancelEditModeEvents = function() end, GetEventInfo = function() return nil end,
        GetEventState = function() return 0 end, GetEventTimeRemaining = function() return 5 end,
        GetEventTrack = function() return 1 end, IsEventBlocked = function() return false end },
    C_EncounterWarnings = { IsFeatureAvailable = function() return RETAIL end, PlaySound = function() end,
        GetEditModeWarningInfo = function(sev)
        return { text = "Sample %s", casterName = "Boss", targetName = "You", iconFileID = 1, severity = sev, duration = 4 }
    end },
    C_PartyInfo = { DoCountdown = function() return true end },
    -- IsSpecSelectionEnabled is Forever-only; the stub Forever character's class has spec choice switched off
    C_SpecializationInfo = { GetSpecialization = function() return 1 end,
        IsSpecSelectionEnabled = not RETAIL and function() return false end or nil,
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

for line in readAll("Phoenix_UI" .. TOC_SUFFIX .. ".toc"):gmatch("[^\r\n]+") do
    if not line:match("^%s*#") and line:match("%S") then
        local p = line:gsub("\\", "/"):gsub("%s+$", "")
        if p:match("^Libs/") then -- replaced by the fakes above
        elseif p:match("%.xml$") then walkXml(p) else run(p) end
    end
end

-- Phoenix_UI_Options: the load-on-demand settings addon, loaded the way the client does it (its own private
-- table, files run in TOC order) when Phoenix_UI calls C_AddOns.LoadAddOn("Phoenix_UI_Options").
local OPTIONS = "Phoenix_UI_Options"
local optionsLoads = 0
local function loadOptions()
    optionsLoads = optionsLoads + 1
    local private = {}
    for line in readAll(OPTIONS .. "/" .. OPTIONS .. TOC_SUFFIX .. ".toc"):gmatch("[^\r\n]+") do
        if not line:match("^%s*#") and line:match("%S") then
            local path = OPTIONS .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")
            local chunk, err = loadfile(ROOT .. "/" .. path)
            if not chunk then errors[#errors + 1] = err else
                setfenv(chunk, env)
                local ok, e = pcall(chunk, OPTIONS, private)
                if not ok then errors[#errors + 1] = path .. ": " .. tostring(e) end
                loaded = loaded + 1
            end
        end
    end
    return true
end
env.C_AddOns.LoadAddOn = function(name)
    if name ~= OPTIONS then return false, "MISSING" end
    if optionsLoads > 0 then return true end
    return loadOptions()
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
-- Features that only exist on retail (ns.FEATURES): the Forever run checks they are gone instead ("flavor").
local function retailTry(label, fn, ...)
    if RETAIL then try(label, fn, ...) end
end
-- the settings window is not loaded at login; the first /pui loads Phoenix_UI_Options once
try("load on demand", function()
    assert(ns.Config and not ns.Config.loaded and optionsLoads == 0, "Phoenix_UI_Options loaded before it was asked for")
    assert(not ns.Previews and not next(ns.options), "option schemas or previews are in the main addon")
    slashes.pui("")
    assert(ns.Config.loaded and optionsLoads == 1, "/pui did not load Phoenix_UI_Options")
    assert(rawget(env, "PhoenixUI_Bridge") == nil, "the bridge global outlived the load")
    assert(ns.options.NamePlates and ns.Previews, "options schemas did not register into the main namespace")
    ns.Config:Toggle()
    assert(optionsLoads == 1, "Phoenix_UI_Options loaded twice")
end)
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
local function eachItem(list, fn, parent)
    for _, item in ipairs(list or {}) do
        fn(item, parent)
        eachItem(item.cog, fn, item)
    end
end
local function scopeUnits(list)
    for _, item in ipairs(list or {}) do
        if item.type == "scope" then
            local out = {}
            for _, v in ipairs(item.values) do out[#out + 1] = v.value end
            return out
        end
    end
    return { "player" }
end
for _, m in ipairs(ns.moduleList or {}) do
  for _, unit in ipairs(scopeUnits(ns.options[m.key])) do
    eachItem(ns.options[m.key], function(item, parent)
        local owner = (parent and parent.hidden) and parent or item
        local hiddenHere = owner.hidden and item.key and item.key:find("@", 1, true) and owner.hidden(m, unit)
        local key = item.key and not hiddenHere and item.key:gsub("@", unit)
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
        if item.hidden then try("hidden " .. m.key, item.hidden, m, unit) end
    end)
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
for _, msg in ipairs({ "", "", "profile", "profile Default", "debug", "debug", "general", "nonsense", "reset", "help", "?", "bags", "minimap" }) do
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
    local v = bugs:GetViewer()
    v:Select(2)
    assert(#v.header.session:GetItems() >= 3, "session menu")
    v.header.source.onChange(v.header.source, "all")
    local sources = v.header.source:GetItems()
    assert(sources[1].value == "all" and #sources >= 2, "addon menu lists the sources")
    -- open both menus so every item icon is requested (unknown glyph names fail the run)
    E:Record("error", "Interface/AddOns/Blizzard_UIPanels/x.lua:1: y")
    for _, d in ipairs({ v.header.session, v.header.source }) do d:GetScript("OnClick")(d); ns.Widgets.HideDropdownList() end
    local newest = db.reports[#db.reports]
    v.header.source.onChange(v.header.source, newest.source)
    v.detail.mark.onClick(v.detail.mark)
    assert(newest.reported == true, "viewer: mark as reported")
    local n = #db.reports
    v.detail.delete.onClick(v.detail.delete)
    assert(#db.reports == n - 1, "viewer: delete")
    v.header.source.onChange(v.header.source, "all")
    ns.Events:Fire("PUI_BUG", db.reports[1], true)
    E:Clear("all")
    assert(#db.reports == 0, "clear all failed")
end)
-- BugGrabber 12.x owns the handler and announces captures through EventRegistry; Phoenix must import what it
-- caught before we loaded, count every announcement once and keep kinds apart. (In game, the 2.0 build listened
-- for the CallbackHandler event that BugGrabber 12.x no longer has, so PhoenixUIBugsDB stayed empty.)
try("bugs buggrabber", function()
    local saved = { BugGrabber = rawget(env, "BugGrabber"), EventRegistry = rawget(env, "EventRegistry"),
        PhoenixUIBugsDB = rawget(env, "PhoenixUIBugsDB") }
    local callbacks = {}
    rawset(env, "EventRegistry", {
        RegisterCallback = function(_, event, fn, owner) callbacks[event] = function(...) return fn(owner, ...) end end,
        UnregisterCallback = function() end, TriggerEvent = function() end,
    })
    local early = { message = "Interface/AddOns/Early/Early.lua:5: attempt to index a nil value", session = 7, counter = 9,
        stack = "[Interface/AddOns/Early/Early.lua]:5: in main chunk", locals = "debuglocals() returned secrets." }
    local old = { message = "Interface/AddOns/Old/Old.lua:1: from yesterday", session = 6, counter = 1 }
    local db = { old, early }
    local addon = {}
    function addon:GetDB() return db end
    function addon:GetSessionId() return 7 end
    function addon:GetErrorByID(id) for _, e in ipairs(db) do if tostring(e) == id then return e end end end
    rawset(env, "BugGrabber", setmetatable({}, { __index = addon, __newindex = function() end, __metatable = false }))
    rawset(env, "PhoenixUIBugsDB", nil)
    local ns2 = setmetatable({}, { __index = ns })
    local chunk = assert(loadfile(ROOT .. "/Core/Errors.lua"))
    setfenv(chunk, env)
    chunk("Phoenix_UI", ns2)
    local E = ns2.Errors
    assert(E.mode == "buggrabber" and E:GetMode() == "buggrabber", "BugGrabber not detected")
    assert(callbacks["BugGrabber.BugGrabbed"], "not subscribed to BugGrabber.BugGrabbed (EventRegistry)")
    E:Open(true)
    local reports = env.PhoenixUIBugsDB.reports
    assert(#reports == 1 and reports[1].source == "Early" and reports[1].count == 1 and E.imported == 1,
        "this session's BugGrabber errors were not imported (" .. #reports .. ")")
    assert(reports[1].locals == "debuglocals() returned secrets.", "BugGrabber's secret placeholder must be kept as text")
    -- a repeat of a known error, then a new error, a warning and a blocked action, each announced once
    local announce = callbacks["BugGrabber.BugGrabbed"]
    announce(tostring(early))
    assert(#reports == 1 and reports[1].count == 2, "a repeat must count, not add a report")
    local new = { message = "Interface/AddOns/New/New.lua:2: boom", session = 7, counter = 1 }
    local warn = { message = "LUA_WARNING: Interface/AddOns/Warn/Warn.lua:1: deprecated", session = 7, counter = 1 }
    local taint = { message = "[ADDON_ACTION_BLOCKED] AddOn 'Bar' tried to call the protected function 'CastSpellByName'.",
        session = 7, counter = 1 }
    for _, e in ipairs({ new, warn, taint }) do db[#db + 1] = e; announce(tostring(e)) end
    assert(#reports == 4, "new BugGrabber errors were not recorded (" .. #reports .. ")")
    assert(reports[2].kind == "error" and reports[2].source == "New", "error kind/source")
    assert(reports[3].kind == "warning" and not reports[3].message:find("LUA_WARNING", 1, true), "warning kind")
    assert(reports[4].kind == "taint", "blocked-action kind")
    announce("table: nothing") -- unknown id: ignored
    -- scope "phoenix": other addons' errors are skipped, ours kept
    E:SetScope("phoenix")
    local mine = { message = "Interface/AddOns/Phoenix_UI/Core/X.lua:1: ours", session = 7, counter = 1 }
    local theirs = { message = "Interface/AddOns/Other/O.lua:1: theirs", session = 7, counter = 1 }
    db[#db + 1] = mine; announce(tostring(mine))
    db[#db + 1] = theirs; announce(tostring(theirs))
    assert(#reports == 5 and reports[5].source == "Phoenix_UI", "the Phoenix-only scope let another addon through")
    E:SetScope("all")
    -- viewer actions on the core: delete, mark, sessions
    E:SetReported(reports[2], true)
    assert(reports[2].reported == true, "mark as reported")
    local victim = reports[3]
    E:Delete(victim)
    assert(#reports == 4 and reports[3] ~= victim, "delete")
    assert(#E:Sessions() == 1 and E:Sessions()[1].count == 4, "sessions summary")
    for _, k in ipairs({ "BugGrabber", "EventRegistry", "PhoenixUIBugsDB" }) do rawset(env, k, saved[k]) end
end)
-- without BugGrabber, errors Blizzard's handler kept before Phoenix loaded are taken over once
try("bugs early errors", function()
    local E, db = ns.Errors, env.PhoenixUIBugsDB
    local saved = rawget(env, "ScriptErrorsFrame")
    rawset(env, "ScriptErrorsFrame", { errorData = {
        { message = "Interface/AddOns/Zed/Zed.lua:3: early", stack = "[Interface/AddOns/Zed/Zed.lua]:3: in main chunk",
          locals = "", count = 3, messageType = 0 },
        { message = "Interface/AddOns/Zed/Zed.lua:9: old api", stack = "", locals = "", count = 1, messageType = 1 },
    } })
    local before, imported = #db.reports, E.imported
    E.ImportBlizzard()
    rawset(env, "ScriptErrorsFrame", saved)
    assert(#db.reports == before + 2 and E.imported == imported + 2, "Blizzard's early errors were not imported")
    local r = db.reports[before + 1]
    assert(r.source == "Zed" and r.count == 3 and r.kind == "error", "early error fields")
    assert(db.reports[before + 2].kind == "warning", "early warning kind")
    assert(E:OwnsHandler() and ns.modules.Bugs:CaptureState() == "handler", "capture state should be handler")
    E:Clear("all")
end)
-- "Send error reports to the author": account-wide in PhoenixUIBugsDB, on by default, one notice, slash + option
try("bugs share", function()
    local E, db, bugs = ns.Errors, env.PhoenixUIBugsDB, ns.modules.Bugs
    assert(db.share == true and E:GetShare(), "share must default to true")
    assert(db.shareNotice == true and not E:TakeShareNotice(), "the share notice must show exactly once")
    bugs:OnSlash("share off")
    assert(db.share == false and not E:GetShare(), "/pui bugs share off")
    bugs:OnSlash("share")
    assert(db.share == true, "/pui bugs share toggles back on")
    bugs:OnSlash("share maybe")
    assert(db.share == true, "an unknown argument must not change the setting")
    local row
    for _, item in ipairs(ns.options.Bugs) do if item.label == "BUGS_SHARE" then row = item end end
    assert(row and row.type == "toggle" and row.icon and row.get() == true, "share toggle row")
    row.set(bugs, false)
    assert(db.share == false and row.get() == false, "the option row writes PhoenixUIBugsDB.share")
    row.set(bugs, true)
    db.share = nil -- an install from before the setting: missing means on
    assert(E:GetShare(), "a missing flag reads as on")
    db.share = true
end)
-- privacy: what is stored (and so what the uploader can send) carries no identity
try("bugs scrub", function()
    local E, db = ns.Errors, env.PhoenixUIBugsDB
    E.ResetIdentity()
    local s = E.Scrub("Tester-Realm hit Player-1-0001ABCD; Vortex#21345 at C:\\Users\\Vorte\\WTF\\Account\\ACC123\\x.lua; Testers stays")
    assert(not s:find("Tester%-") and not s:find("Realm") and s:find("<player>%-<player>"), "name/realm not scrubbed: " .. s)
    assert(s:find("Player%-<guid>") and s:find("<battletag>") and s:find("Users\\<user>") and s:find("Account\\<account>"),
        "guid/battletag/paths not scrubbed: " .. s)
    assert(s:find("Testers stays", 1, true), "only whole-word names are scrubbed: " .. s)
    local l = E.Scrub('unit = "player"\nmsg = "hello there, how are you"\n  name = "Tester"\nn = 4', true)
    assert(l:find('unit = "player"', 1, true) and l:find('msg = "<text, 24 bytes>"', 1, true)
        and l:find('name = "<player>"', 1, true) and l:find("n = 4", 1, true), "locals not scrubbed: " .. l)
    E:Record("error", "Interface/AddOns/Foo/Foo.lua:1: Tester broke it", "Interface/AddOns/Foo/Foo.lua:1: in function", "who = \"Tester\"")
    local r = db.reports[#db.reports]
    assert(r.source == "Foo" and r.message:find("<player> broke it", 1, true) and r.locals == 'who = "<player>"',
        "stored report not scrubbed")
    E:Clear("all")
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
retailTry("mythic+ timer", function()
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
retailTry("mythic+ pull", function()
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
retailTry("mythic+ keystones", function()
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
-- this week on Home: vault slots from C_WeeklyRewards, season from the rating summary and run history
retailTry("weekly summary", function()
    local saved = {}
    for _, k in ipairs({ "C_WeeklyRewards", "C_MythicPlus", "C_PlayerInfo" }) do saved[k] = rawget(env, k) or false end
    rawset(env, "C_WeeklyRewards", { GetActivities = function()
        return { { index = 2, threshold = 4, progress = 3, level = 10 }, { index = 1, threshold = 1, progress = 3, level = 12 },
                 { index = 3, threshold = 8, progress = 3, level = 0 } }
    end })
    rawset(env, "C_MythicPlus", { GetRunHistory = function()
        return { { level = 12, thisWeek = true }, { level = 14, thisWeek = true }, { level = 9, thisWeek = true } }
    end, RequestMapInfo = function() end })
    rawset(env, "C_PlayerInfo", { GetPlayerMythicPlusRatingSummary = function() return { currentSeasonScore = 2875 } end })
    local t = ns.Weekly:Track(ns.Weekly.TRACKS[1])
    assert(#t.slots == 3 and t.done == 1 and t.slots[1].threshold == 1, "vault slots are wrong")
    local season = ns.Weekly:Season()
    assert(season.rating == 2875 and season.runs == 3 and season.best == 14, "season summary is wrong")
    ns.Config:Show("home")
    rawset(env, "C_WeeklyRewards", { GetActivities = function() error("not ready") end })
    assert(#ns.Weekly:Track(ns.Weekly.TRACKS[2]).slots == 0, "a failing API must read as no data")
    for k, v in pairs(saved) do rawset(env, k, v or nil) end
end)
-- an unsubstituted packager token (the stub returns one) never reaches the screen
try("version", function()
    assert(type(ns.version) == "string" and not ns.version:find("@", 1, true), "version shows a placeholder: " .. tostring(ns.version))
end)
-- /phoenix testerror schedules a labelled error for the bug catcher
try("test error", function()
    local queued
    local after = env.C_Timer.After
    env.C_Timer.After = function(_, fn) queued = fn end
    ns.TestSlash("testerror")
    env.C_Timer.After = after
    assert(queued, "testerror did not schedule an error")
    local ok, e = pcall(queued)
    assert(not ok and tostring(e):find("PHOENIX TEST ERROR", 1, true), "wrong test error: " .. tostring(e))
end)
-- /pui diag probes every bundled texture and stores a report in the SavedVariables
try("diag", function()
    local after = env.C_Timer.After
    env.C_Timer.After = function(_, fn) fn() end
    ns.TestSlash("diag")
    env.C_Timer.After = after
    local report = ns.DB.sv.global.diag
    assert(type(report) == "table" and report.version == ns.version, "diag wrote no report")
    assert(report.total >= 40 and #report.media == report.total, "diag probed " .. tostring(report.total) .. " files")
    assert(type(report.glyphs) == "table", "diag lacks the glyph list")
    assert(#report.glyphs > 0, "diag recorded no glyphs although the settings window was built")
    -- a widget method that throws (or is missing) costs one entry, never the report
    local bad = env.CreateFrame("Frame"):CreateTexture()
    bad.GetSize = function() error("boom") end
    ns.Icons:Apply(bad, "bugs", 16)
    ns.Icons:Tracked()[bad].name = "bugs"
    ns.DB.sv.global.diag = nil
    env.C_Timer.After = function(_, fn) fn() end
    ns.TestSlash("diag")
    env.C_Timer.After = after
    ns.Icons:Tracked()[bad] = nil
    report = ns.DB.sv.global.diag
    assert(type(report) == "table" and report.total >= 40, "a throwing glyph lost the diag report")
end)
-- every translation listed in Locales.xml loads only on its own client, covers every enUS key and keeps format specifiers
try("locales", function()
    local function capture(path, locale)
        local got = {}
        local fake = { RegisterLocale = function(loc, t) got[loc] = t end }
        local chunk = assert(loadfile(ROOT .. "/" .. path))
        local saved = env.GetLocale
        rawset(env, "GetLocale", function() return locale end)
        setfenv(chunk, env)
        local ok, e = pcall(chunk, NAME, fake)
        rawset(env, "GetLocale", saved)
        assert(ok, path .. ": " .. tostring(e))
        return got
    end
    local en = capture("Locales/enUS.lua", "enUS").enUS
    local function specs(v)
        local t = {}
        for sp in v:gmatch("%%[-+ 0#]*%d*%.?%d*[sdifgxXc]") do t[#t + 1] = sp end
        table.sort(t)
        return table.concat(t, ",")
    end
    local n = 0
    for file in readAll("Locales/Locales.xml"):gmatch("file=\"([%a]+)%.lua\"") do
        if file ~= "Locales" and file ~= "enUS" then
            n = n + 1
            assert(next(capture("Locales/" .. file .. ".lua", "enUS")) == nil, file .. " registers on an English client")
            local got = capture("Locales/" .. file .. ".lua", file)
            local t = assert(got[file], file .. " did not register for its own client")
            for k, v in pairs(en) do
                assert(type(t[k]) == "string" and t[k] ~= "", file .. " misses " .. k)
                assert(specs(t[k]) == specs(v), file .. "." .. k .. " changes the format specifiers")
            end
            for k in pairs(t) do assert(en[k], file .. " has unknown key " .. k) end
            if file == "esES" then assert(capture("Locales/esES.lua", "esMX").esMX, "esES strings must also register for esMX") end
        end
    end
    assert(n > 0, "no translations listed in Locales.xml")
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
            if r.cog and r.item.cog then -- (link rows reuse the cog slot for their chevron)
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
    local textTab, n = nil, 0
    for _, item in ipairs(ns.options.NamePlates) do
        if item.type == "tab" then n = n + 1; if item.label == "TAB_TEXT" then textTab = n end end
    end
    assert(page.tab == textTab, "focusing a Text-tab option did not switch tabs")
    ns.Config:Search("")
end)
-- layout: the 7 rail groups of plan v2; every module and built-in page sits in exactly one; every option row is reachable
try("layout coverage", function()
    local C = ns.Config
    local groups, seen = C:Groups(), {}
    assert(#C.GROUPS == 7, "expected 7 rail groups, have " .. #C.GROUPS)
    for _, g in ipairs(groups) do
        for _, key in ipairs(g.entries) do
            assert(not seen[key], key .. " is listed in two groups")
            seen[key] = g.key
        end
    end
    for _, m in ipairs(ns.moduleList) do
        if not m.hidden then assert(seen[m.key], "module " .. m.key .. " is not in the sidebar") end
    end
    for key in pairs(C.builders) do assert(seen[key], "page " .. key .. " is not in the sidebar") end
    -- every labelled option of every page owns a row (cog options a row in their popover)
    local rows = 0
    for key in pairs(seen) do
        local page = C:Show(key)
        assert(C.navRows[key] and C.navRows[key]:IsShown(), key .. ": its sidebar row is hidden after Show")
        local schema = ns.options[key] or page.schema
        local owned = {}
        for _, r in ipairs(page.rows or {}) do
            owned[r.item] = true
            for _, sub in ipairs(r.item.cog or {}) do owned[sub] = true end
        end
        for _, item in ipairs(schema or {}) do
            if item.label and item.type ~= "tab" and item.type ~= "header" and item.type ~= "scope" and item.type ~= "preview" then
                assert(owned[item], key .. ": option " .. tostring(item.label) .. " has no row")
                rows = rows + 1
            end
        end
    end
    assert(rows > 200, "only " .. rows .. " option rows reached")
    -- groups fold and unfold; the group of the shown page opens by itself
    C:ToggleGroup("combat", false)
    C:Show("SpellHistory")
    assert(C.navRows.SpellHistory:IsShown(), "showing a page did not open its group")
end)
-- search: multi-word queries, group names and built-in pages
try("search pages and groups", function()
    local C = ns.Config
    local function find(q, pred)
        C:Search(q)
        for _, r in ipairs(C.results.rows) do if r:IsShown() and pred(r.entry) then return r.entry end end
    end
    assert(find("unit frames texture", function(e) return e.key == "UnitFrames" and e.item end), "multi-word search failed")
    assert(find("export", function(e) return e.key == "profiles" and e.item end), "profiles page rows are not searchable")
    local e = find(ns.L.SUB_ITEMS:lower(), function(x) return x.key == "ItemLevel" end)
    assert(e, "a sub-heading does not find its pages")
    e = find(ns.L.RAIL_CONTENT:lower(), function(x) return x.key == "Encounters" end)
    assert(e, "a rail group name does not find its pages")
    assert(find("hp", function(x) return x.item and (ns.L[x.item.label] or ""):lower():find("health") end),
        "the synonym hp does not find health options")
    C:Search("")
end)
-- resets: a row, a card and a whole module go back to their defaults; the module keeps its on/off state
try("resets", function()
    local C, U = ns.Config, ns.Util
    local m = ns.modules.NamePlates
    local page = C:Show("NamePlates")
    local row
    for _, r in ipairs(page.rows) do if r.item.key == "bar" then row = r end end
    assert(row and row.reset, "the nameplate texture row has no reset arrow")
    ns.DB:Set(m, "bar", "Neon")
    assert(row:IsModified(), "a changed row is not reported as modified")
    scripts[row].OnMouseUp(row, "RightButton")
    assert(m.db.bar == m.defaults.bar, "right-click did not reset the row")
    ns.DB:Set(m, "bar", "Neon")
    if page.tabs then page.tabs.onChange(page.tabs, 1) end
    page:Layout()
    assert(row.card.reset and row.card.reset:IsShown(), "the card reset button is hidden on a changed card")
    row.card.reset.onClick(row.card.reset); row.card.reset.onClick(row.card.reset)
    assert(m.db.bar == m.defaults.bar, "the card reset did not reset its rows")
    local enabled = m.db.enabled
    ns.DB:Set(m, "bar", "Tube"); ns.DB:Set(m, "health.size", 17)
    local hb = page.header.reset
    hb.onClick(hb); hb.onClick(hb)
    assert(m.db.bar == m.defaults.bar and m.db.health.size == m.defaults.health.size, "module reset missed keys")
    assert(m.db.enabled == enabled, "module reset changed the enabled state")
    assert(U.Equal({ a = 1, b = { 2 } }, { a = 1, b = { 2 } }) and not U.Equal({ a = 1 }, { a = 1, b = 2 }), "U.Equal")
end)
-- hover preview: pointing at a picker entry writes only the profile table, silently, and leaving restores it
try("hover preview", function()
    local C = ns.Config
    local m = ns.modules.NamePlates
    local page = C:Show("NamePlates")
    assert(page.pinned and page.preview, "NamePlates has no pinned preview")
    local row
    for _, r in ipairs(page.rows) do if r.item.key == "bar" then row = r end end
    local before, fired = m.db.bar, 0
    local probe = {}
    ns.Events:Listen("PUI_SETTING_CHANGED", probe, function() fired = fired + 1 end)
    row.control.onHover(row.control, "Neon")
    assert(m.db.bar == "Neon", "hover did not reach the preview's settings")
    row.control.onHover(row.control, "Tube")
    row.control.onHover(row.control, nil)
    assert(m.db.bar == before, "hover was not undone")
    assert(fired == 0, "hover fired PUI_SETTING_CHANGED")
    row.control.onHover(row.control, "Neon")
    C.EndHoverPreview()
    assert(m.db.bar == before, "EndHoverPreview did not restore")
    -- the pinned card folds and sticks
    page.pinned.fold.onClick(page.pinned.fold)
    assert(page.pinned.collapsed and not page.pinned.pane:IsShown(), "the preview did not fold")
    page.pinned.fold.onClick(page.pinned.fold)
    page:Stick()
end)
-- card pickers: every kind opens, filters, renders cards and picks
try("media pickers", function()
    local W = ns.Widgets
    for _, kind in ipairs({ "font", "statusbar", "sound" }) do
        local d = W:MediaPicker(env.CreateFrame("Frame"), kind, function() return ns.Media:List(kind) end)
        local picked
        d.onChange = function(_, v) picked = v end
        d:SetValue(ns.Media:List(kind)[1].value)
        scripts[d].OnClick(d)
        assert(d.open, kind .. " picker did not open")
        local p = ns.Widgets.MediaPickerPopup()
        assert(#p.visible == #ns.Media:List(kind), kind .. ": not every entry is listed")
        p.filter.onChange(p.filter, p.filters[2].value)
        assert(#p.visible > 0 and #p.visible <= #ns.Media:List(kind), kind .. ": filter emptied the list")
        local card = p.cards[1]
        assert(card and card:IsShown(), kind .. ": no card rendered")
        scripts[card].OnClick(card)
        assert(picked == card.item.value, kind .. ": clicking a card did not pick it")
    end
    assert(#ns.Media:List("sound") >= 2 and ns.Media:Voice("Jim", 3):find("Countdown\\Jim\\3.ogg", 1, true), "sounds")
end)
-- previews: every kind builds and redraws with its module's settings, and with a unit picked
try("previews", function()
    local n = 0
    for kind, def in pairs(ns.Previews.kinds) do
        local m = assert(ns.modules[def.module], kind .. " preview names no module")
        local stage = ns.Previews:Create(kind, env.CreateFrame("Frame"), m, { scope = { unit = "target" } })
        stage:Redraw()
        for _, st in ipairs(ns.Previews:States(kind) or {}) do stage.states[st.key] = true end
        stage:Redraw()
        n = n + 1
    end
    assert(n >= 19, "expected a preview for every visual module, have " .. n)
    -- every visual module's page carries one
    for _, key in ipairs({ "CooldownText", "SpellHistory", "DamageMeter", "Minimap", "ItemLevel", "Skins", "CombatText", "AFK" }) do
        assert(ns.Config:Show(key).pinned, key .. " has no preview")
    end
end)
-- Auras & Cooldowns: item frames of the Cooldown Manager are dressed (the countdown voice moved to Encounters)
try("tracker", function()
    local M = ns.modules.Tracker
    assert(M and M.db.viewers.bars.texture == "" and M.db.countdown == nil, "tracker defaults")
    local icon = env.CreateFrame("Frame"):CreateTexture()
    M:StyleIcon("essential", icon, env.CreateFrame("Frame"), env.CreateFrame("Frame"):CreateFontString())
    M:StyleBar("bars", env.CreateFrame("StatusBar"), env.CreateFrame("Frame"):CreateFontString())
    local stage = ns.Previews:Create("tracker", env.CreateFrame("Frame"), M, { scope = { unit = "bars" } })
    M.db.viewers.essential.square = false
    stage:Redraw()
    M.db.viewers.essential.square = true
end)
-- Encounters: countdown voice (moved from Tracker), timeline bars, warnings banner, pull / break, CVar
-- ownership, the BigWigs bar style and the first-install module picker
try("encounters", function()
    local M = ns.modules.Encounters
    assert(M and M:IsEnabled() and M.db.countdown.voice == "Jim" and M.db.timeline.display == "phoenix", "encounters defaults")
    -- migration: an old profile's Tracker.countdown lands in Encounters and leaves Tracker
    local old = { modules = { Tracker = { countdown = { voice = "David", from = 7 } } } }
    ns.Migrations:UpgradeProfile(old, 3)
    assert(old.modules.Encounters.countdown.voice == "David" and old.modules.Tracker.countdown == nil, "countdown not migrated")
    local played, ticks, cvars, sounds, counts = {}, {}, {}, {}, {}
    local saved = { PlaySoundFile = rawget(env, "PlaySoundFile"), C_Timer = env.C_Timer, C_CVar = env.C_CVar,
        C_EncounterWarnings = env.C_EncounterWarnings, C_PartyInfo = env.C_PartyInfo, GetTime = rawget(env, "GetTime") }
    local now = 100
    rawset(env, "GetTime", function() return now end)
    rawset(env, "PlaySoundFile", function(path) played[#played + 1] = path end)
    rawset(env, "C_Timer", { After = function(_, fn) fn() end,
        NewTicker = function(_, fn) ticks[#ticks + 1] = fn; return { Cancel = function() end } end,
        NewTimer = function() return { Cancel = function() end } end })
    local values = {}
    rawset(env, "C_CVar", { GetCVar = function(k) return values[k] or "1" end,
        GetCVarBool = function(k) return (values[k] or "1") ~= "0" end,
        SetCVar = function(k, v) values[k] = v; cvars[#cvars + 1] = k .. "=" .. v end,
        GetCVarBitfield = function() return false end, SetCVarBitfield = function() end })
    rawset(env, "C_EncounterWarnings", { PlaySound = function(sev) sounds[#sounds + 1] = sev end,
        GetEditModeWarningInfo = saved.C_EncounterWarnings.GetEditModeWarningInfo })
    rawset(env, "C_PartyInfo", { DoCountdown = function(n) counts[#counts + 1] = n; return true end })
    -- countdown voice: secret or missing payloads stay silent
    local isSecret = ns.Secret.IsSecret
    ns.Secret.IsSecret = function(v) return v == 777 end
    fire("START_PLAYER_COUNTDOWN", "guid", 777, 777, false)
    fire("START_PLAYER_COUNTDOWN", "guid", nil)
    assert(#played == 0 and #ticks == 0, "a secret or missing countdown payload must stay silent")
    fire("START_PLAYER_COUNTDOWN", "guid", 3, 10, false)
    assert(#ticks == 1 and played[1] and played[1]:find("Jim\\3.ogg", 1, true), "a 3 s pull did not say three")
    assert(M.Bars:HasTimer("pull"), "a pull did not start the pull bar")
    fire("CANCEL_PLAYER_COUNTDOWN", "guid")
    assert(not M.Bars:HasTimer("pull"), "a cancelled pull kept its bar")
    fire("START_TIMER", env.Enum.StartTimerType and env.Enum.StartTimerType.PlayerCountdown, 3, 10)
    M.db.countdown.enabled = false
    M:StartCountdown(4)
    M.db.countdown.enabled = true
    assert(#played == 1, "the countdown spoke while switched off")
    if RETAIL then
        -- CVars: Phoenix owns the Blizzard views it replaces, and gives them back
        M:ApplyCVars()
        assert(values.encounterTimelineEnabled == "0" and values.encounterWarningsEnabled == "0", "Blizzard views not handed over")
        assert(M.global.cvars.timeline == "1", "the player's own timeline value was not kept")
        ns.DB:Set(M, "timeline.display", "blizzard")
        assert(values.encounterTimelineEnabled == "1" and M.global.cvars.timeline == nil, "the timeline CVar was not restored")
        ns.DB:Set(M, "timeline.display", "phoenix")
        assert(M:BlizzardValue("timeline") == true, "BlizzardValue should report the player's value")
        -- timeline events become bars; secret names only reach SetText
        fire("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 41, source = 0, duration = 20, spellName = "Breath", iconFileID = 1 })
        fire("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 42, source = 2, duration = 8, spellName = "Edit", iconFileID = 2 })
        assert(M.Bars:Draw() == 2, "two timeline events should draw two bars")
        M.db.timeline.horizon = 3
        assert(M.Bars:Draw() == 0, "events beyond the horizon should not draw")
        M.db.timeline.horizon = 0
        fire("ENCOUNTER_TIMELINE_EVENT_REMOVED", 41)
        fire("ENCOUNTER_TIMELINE_EVENT_REMOVED", 42)
        assert(M.Bars:Draw() == 0, "removed events still draw")
        -- warnings: severity is plain, everything else goes to the sinks; secret severity is ignored
        fire("ENCOUNTER_WARNING", { text = "%s breathes on %s", casterName = "Boss", targetName = "You", severity = 2,
            duration = 3, iconFileID = 1 })
        assert(sounds[1] == 2 and M.Warnings:Count() == 1, "a critical warning did not show with the game's sound")
        fire("ENCOUNTER_WARNING", { text = "x", severity = 777, duration = 3 })
        assert(M.Warnings:Count() == 1, "a warning with a secret severity was shown")
        values.encounterWarningsLevel = "2"
        fire("ENCOUNTER_WARNING", { text = "minor", severity = 0, duration = 3 })
        assert(M.Warnings:Count() == 1, "a warning under the minimum severity was shown")
        values.encounterWarningsLevel = nil
    else
        -- no game timeline or warnings (WoW Forever): the game's settings stay untouched, its events draw nothing
        M:ApplyCVars()
        assert(#cvars == 0 and next(M.global.cvars) == nil, "Phoenix touched timeline CVars on a client without one")
        assert(not M:Draws("timeline") and not M:Draws("warnings"), "Phoenix claims a view this client lacks")
        fire("ENCOUNTER_TIMELINE_EVENT_ADDED", { id = 41, source = 0, duration = 20, spellName = "Breath", iconFileID = 1 })
        assert(M.Bars:Draw() == 0, "a timeline event drew on a client without the timeline")
        fire("ENCOUNTER_TIMELINE_EVENT_REMOVED", 41)
        fire("ENCOUNTER_WARNING", { text = "x", severity = 2, duration = 3 })
        assert(M.Warnings:Count() == 0 and #sounds == 0, "a warning showed on a client without warnings")
        assert(M:Test() and M.Bars:HasTimer("pull"), "test mode should show a pull bar without the timeline")
        M.Bars:StopTimer("pull")
    end
    ns.Secret.IsSecret = isSecret
    -- test mode, pull, break and the D5 break message
    assert(M:Test(), "test mode did not start")
    M:StopTest()
    assert(M:Pull(12) and counts[1] == 12, "pull did not call DoCountdown")
    assert(not M:Pull(90), "a 90 s pull was accepted")
    assert(M:Break(5) and M.Bars:HasTimer("break"), "break did not start a bar")
    assert(M:Break(0) and not M.Bars:HasTimer("break"), "break 0 did not end it")
    fire("CHAT_MSG_ADDON", "D5", "Lead-Realm\t1\tBT\t300", "RAID", "Lead-Realm")
    assert(M.Bars:HasTimer("break"), "a DBM/BigWigs break message did not start the break bar")
    M.Bars:StopTimer("break")
    ns.TestSlash("encounters pull 10")
    assert(counts[#counts] == 10, "/pui encounters pull 10")
    -- BigWigs bar style: registers through the public API and restores what it changes
    local style
    rawset(env, "BigWigsAPI", { RegisterBarStyle = function(_, key, data) assert(key == "Phoenix"); style = data end })
    M.BigWigs.status = "absent"
    M.BigWigs:Enable()
    assert(M.BigWigs.status == "registered" and style and style:GetStyleName() == "Phoenix" and style.apiVersion == 1,
        "BigWigs style not registered")
    local bar = env.CreateFrame("Frame")
    bar.candyBarBar = env.CreateFrame("StatusBar")
    bar.candyBarLabel = env.CreateFrame("Frame"):CreateFontString()
    bar.candyBarDuration = env.CreateFrame("Frame"):CreateFontString()
    style.ApplyStyle(bar); style.BarStopped(bar)
    rawset(env, "BigWigsAPI", nil)
    -- preview, options page and the module picker
    local stage = ns.Previews:Create("encounters", env.CreateFrame("Frame"), M, {})
    M.db.timeline.emphasize = false
    stage:Redraw()
    M.db.timeline.emphasize = true
    local picker = ns.Config:ShowModulePicker(true)
    assert(picker and picker.rows and #picker.rows > 10, "module picker has no rows")
    picker.keep.onClick()
    for k, v in pairs(saved) do rawset(env, k, v or nil) end
end)
-- flavour gating: retail-only features are present on retail and cleanly absent on WoW Forever
try("flavor", function()
    local C = ns.Config
    assert(ns.flavor == FLAVOR, "ns.flavor is " .. tostring(ns.flavor) .. " on a " .. FLAVOR .. " client")
    local function sidebar()
        local keys, labels = {}, {}
        for _, g in ipairs(C:Groups()) do
            labels[g.key] = g.label
            for _, key in ipairs(g.entries) do keys[key] = true end
        end
        return keys, labels
    end
    local function rowKeys(key)
        local out = {}
        local function walk(list) for _, item in ipairs(list or {}) do
            out[item.key or item.label or "?"] = true
            walk(item.cog)
        end end
        walk(ns.options[key])
        return out
    end
    local keys, labels = sidebar()
    local tooltip, plates, bags, enc = rowKeys("Tooltip"), rowKeys("NamePlates"), rowKeys("Bags"), rowKeys("Encounters")
    local profiles, specRows = C:Show("profiles"), false
    for _, item in ipairs(profiles.schema or {}) do if item.label == "SPEC_PROFILES" then specRows = true end end
    assert(specRows == RETAIL, "per-spec profiles should show only where a specialization can be chosen")
    local home = C:Show("home")
    local tests = {}
    for _, item in ipairs(ns.options.Encounters) do if item.label == "ENC_TEST" then tests[#tests + 1] = item.desc end end
    assert(#tests == 1 and tests[1] == (RETAIL and "ENC_TEST_DESC" or "ENC_TEST_TIMERS_DESC"),
        "Encounters should have one test button that says what it shows on this client")
    if RETAIL then
        for _, k in ipairs({ "MythicPlus", "Sim" }) do
            local m = ns.modules[k]
            assert(not m.unavailable and not m.hidden and m:IsEnabled() and keys[k], k .. " should be on retail")
        end
        assert(labels.content == "RAIL_CONTENT" and keys.MythicPlus and keys.Sim, "the Content group lost Mythic+ or Sim on retail")
        assert(tooltip.mplusRating and tooltip.simLine and plates.forces and plates["forcesText.font"] and bags.simArrow,
            "retail lost a Mythic+ or Sim option")
        assert(enc.ENC_TAB_TIMELINE and enc.ENC_TAB_WARNINGS and enc["timeline.display"] and enc.ENC_MASTER,
            "retail lost the encounter timeline or warnings options")
        assert(home.week, "Home lost its Great Vault card on retail")
        assert(ns.modules.Encounters.desc == "ENCOUNTERS_DESC" and ns.modules.NamePlates.desc == "NAMEPLATES_DESC",
            "retail module descriptions changed")
        return
    end
    -- Forever: the modules exist (profiles stay portable) but never initialize, enable or show
    for _, k in ipairs({ "MythicPlus", "Sim" }) do
        local m = ns.modules[k]
        assert(m and m.unavailable and m.hidden and not m:IsEnabled() and not m:ShouldEnable(), k .. " is not gated")
        assert(not keys[k], k .. " is in the sidebar on Forever")
        ns:SetModuleEnabled(k, true)
        assert(not m:IsEnabled(), k .. " could be switched on on Forever")
        assert(C:Show(k) == C.pages.home, "opening " .. k .. " on Forever did not fall back to Home")
    end
    assert(ns.modules.Sim.db and type(ns.modules.Sim.db.mode) == "string", "a gated module lost its saved settings")
    assert(labels.content == "RAIL_CONTENT" and keys.Encounters and keys.PvP, "the Content group lost its pages on Forever")
    assert(not (tooltip.mplusRating or tooltip.simLine or plates.forces or plates["forcesText.font"] or bags.simArrow),
        "a Mythic+ or Sim option is left on Forever")
    assert(tooltip.ids and plates.healthText and bags.upgrade, "filtering dropped options that Forever has")
    assert(not (enc.ENC_TAB_TIMELINE or enc.ENC_TAB_WARNINGS or enc["timeline.display"] or enc["warnings.display"]
        or enc.ENC_MASTER or enc["warnings.sounds.high"] or enc.ENC_SOUND_TEST), "timeline or warning options left")
    assert(enc.ENC_TAB_TIMERS and enc["pull.seconds"] and enc["countdown.voice"] and enc.ENC_TAB_BIGWIGS,
        "Forever lost the pull, break or countdown options")
    assert(not home.week, "Home shows the Great Vault on Forever")
    assert(ns.modules.Encounters.desc == "ENCOUNTERS_DESC_TIMERS" and ns.modules.NamePlates.desc == "NAMEPLATES_DESC_PLAIN",
        "a module card still promises boss timers or Mythic+ forces")
    C:Search("keystone")
    for _, r in ipairs(C.results.rows) do
        assert(not (r:IsShown() and r.entry and r.entry.key == "MythicPlus"), "search reaches the hidden Mythic+ page")
    end
    C:Search("")
    local picker = C:ShowModulePicker(true)
    for _, row in ipairs(picker.rows) do
        local k = row.module and row.module.key or row.key
        assert(k ~= "MythicPlus" and k ~= "Sim", "the module picker offers " .. tostring(k))
    end
    picker.keep.onClick()
end)
-- unit frames: boss scope, test frames (never in combat), portraits and range fade options exist
try("unit frames depth", function()
    local M = ns.modules.UnitFrames
    assert(M.db.units.boss and M.db.units.target.portrait == "game" and M.db.range.alpha, "unit frame defaults")
    assert(M:ShowTest(true) and M.testShown, "test frames did not show")
    assert(M:ShowTest(false) and not M.testShown, "test frames did not hide")
    local saved = env.InCombatLockdown
    rawset(env, "InCombatLockdown", function() return true end)
    local ok = M:ShowTest(true)
    rawset(env, "InCombatLockdown", saved)
    assert(ok == false and not M.testShown, "test frames must not open in combat")
    for _, mode in ipairs({ "class", "hide", "game" }) do
        M.db.units.target.portrait = mode
        M:Refresh()
    end
    M.db.range.enabled = true; M:Refresh(); M.db.range.enabled = false; M:Refresh()
end)
-- nameplates: target/focus highlight wins, threat colours depend on the role
try("nameplate colours", function()
    local M = ns.modules.NamePlates
    local db = M.db
    local was = { db.threat.enabled, db.highlight.target, db.highlight.focus }
    db.threat.enabled, db.highlight.target, db.highlight.focus = true, true, true
    db.threat.aggro, db.threat.safe, db.threat.warning = { r = 1, g = 0, b = 0 }, { r = 0, g = 1, b = 0 }, { r = 1, g = 1, b = 0 }
    db.highlight.targetColor = { r = 0, g = 0, b = 1 }
    local function rgb(sample)
        local r, g, b = M:PlateColor(nil, sample)
        return r and table.concat({ r, g, b }, ",") or ""
    end
    assert(rgb({ target = true, threat = 3 }) == "0,0,1", "target highlight should win over threat")
    assert(rgb({ threat = 3, tank = true }) == "0,1,0", "a tank holding aggro should be safe")
    assert(rgb({ threat = 0, tank = true }) == "1,0,0", "a tank without aggro should be in danger")
    assert(rgb({ threat = 3 }) == "1,0,0", "a damage dealer with aggro should be in danger")
    assert(rgb({ threat = 1 }) == "1,1,0", "rising threat should warn")
    assert(rgb({ threat = 0 }) == "", "no threat keeps Blizzard's colour")
    db.threat.enabled = false
    assert(rgb({ threat = 3 }) == "", "threat colours while switched off")
    db.threat.enabled, db.highlight.target, db.highlight.focus = was[1], was[2], was[3]
end)
-- aura rows: Blizzard's nameplate and target-frame aura buttons are dressed after Blizzard lays them out
try("aura rows", function()
    local function pool(items)
        return { EnumerateActive = function() local i = 0; return function() i = i + 1; return items[i] end end }
    end
    local function button()
        local b = env.CreateFrame("Frame")
        b.Icon = b:CreateTexture()
        b.Count = b:CreateFontString()
        b.CountFrame = { Count = b.Count }
        b.Cooldown = env.CreateFrame("Cooldown")
        return b
    end
    -- nameplates
    local NP = ns.modules.NamePlates
    local plate = env.CreateFrame("Frame")
    plate.UnitFrame = env.CreateFrame("Frame")
    plate.UnitFrame.healthBar = env.CreateFrame("StatusBar")
    local auras = env.CreateFrame("Frame")
    rawset(auras, "RefreshList", function() end)
    auras.auraItemFramePool = pool({ button(), button() })
    plate.UnitFrame.AurasFrame = auras
    local saved = rawget(env, "C_NamePlate")
    rawset(env, "C_NamePlate", { GetNamePlateForUnit = function() return plate end })
    local styled = 0
    local orig = NP.StyleAuraIcon
    NP.StyleAuraIcon = function(...) styled = styled + 1; return orig(...) end
    fire("NAME_PLATE_UNIT_ADDED", "nameplate9")
    auras:RefreshList()
    auras:RefreshList()
    NP.StyleAuraIcon = orig
    rawset(env, "C_NamePlate", saved or nil)
    fire("NAME_PLATE_UNIT_REMOVED", "nameplate9")
    assert(styled == 2, "nameplate aura items styled " .. styled .. " times (each once expected)")
    assert(NP.db.auras.style and NP.db.auras.count and NP.db.auras.timer, "nameplate aura defaults")
    -- unit frames: the container's ApplyLayout post-hook (installed at enable) styles each button once
    local UF = ns.modules.UnitFrames
    assert(UF.db.auras.style and UF.db.auras.count, "unit frame aura defaults")
    local b = button()
    UF:StyleAuraIcon(b, b.Icon, b.Count)
end)
-- data texts: the saved order is normalised (unknown dropped, new segments appended) and drives the bar
try("data text order", function()
    local DT = ns.modules.DataTexts
    local order = DT:Order("clock,nope,fps,clock")
    assert(order[1] == "clock" and order[2] == "fps" and order[3] == "latency", "order normalisation")
    assert(#order == #DT.ORDER, "every segment appears once")
    for _, key in ipairs(DT.ORDER) do assert(DT.db[key] ~= nil, "no default for segment " .. key) end
    assert(DT:Order(DT.defaults.order)[1] == "fps", "default order")
    local was = DT.db.order
    ns.DB:Set(DT, "order", "mail,bags")
    assert(DT:Order()[1] == "mail" and DT:Order()[2] == "bags", "saved order not used")
    ns.DB:Set(DT, "order", was)
end)
-- minimap bin: LibDBIcon buttons (present now or created later) are collected; hidden ones are skipped
try("minimap bin", function()
    local MM = ns.modules.Minimap
    local buttons, names, cb = {}, {}, nil
    local function make(name, hidden)
        local b = env.CreateFrame("Button")
        b.db = { hide = hidden }
        buttons[name] = b
        names[#names + 1] = name
        return b
    end
    make("Alpha"); make("Beta"); make("Gamma", true)
    libs["LibDBIcon-1.0"] = {
        GetButtonList = function() return names end,
        GetMinimapButton = function(_, name) return buttons[name] end,
        RegisterCallback = function(_, event, fn) if event == "LibDBIcon_IconCreated" then cb = fn end end,
    }
    MM.ScanBin()
    assert(MM:BinCount() == 2, "bin holds " .. MM:BinCount() .. " buttons (2 expected)")
    assert(cb, "no LibDBIcon_IconCreated callback")
    local late = make("Delta")
    cb("LibDBIcon_IconCreated", late, "Delta")
    MM.ScanBin()
    assert(MM:BinCount() == 3, "late button not collected")
    MM:OpenBin()
    libs["LibDBIcon-1.0"] = nil
end)
-- bags: upgrade rule (slot minimum, armour type, usability) and dressing a stub item button
try("bags", function()
    local B = ns.modules.Bags
    local eq = B.equipped
    local saved = {}
    for k, v in pairs(eq) do saved[k] = v end
    eq[1], eq[11], eq[12], eq[16], eq[15] = 680, 690, 670, 700, 0
    local PLATE, CLOTH = 4, 1
    local ARMOR = env.Enum.ItemClass.Armor
    assert(B:IsUpgrade(685, "INVTYPE_HEAD", ARMOR, PLATE, nil, "WARRIOR"), "higher plate helm for a warrior")
    assert(not B:IsUpgrade(685, "INVTYPE_HEAD", ARMOR, CLOTH, nil, "WARRIOR"), "cloth helm is no warrior upgrade")
    assert(not B:IsUpgrade(675, "INVTYPE_HEAD", ARMOR, PLATE, nil, "WARRIOR"), "lower helm")
    assert(B:IsUpgrade(675, "INVTYPE_FINGER", ARMOR, 0, nil, "MAGE"), "ring beats the weaker of two rings")
    assert(B:IsUpgrade(600, "INVTYPE_CLOAK", ARMOR, CLOTH, nil, "WARRIOR"), "any cloak fills an empty back")
    assert(not B:IsUpgrade(800, "INVTYPE_BAG", nil, nil, nil, "MAGE"), "bags are never upgrades")
    for k in pairs(eq) do eq[k] = saved[k] end
    local b = env.CreateFrame("Button")
    b.icon = b:CreateTexture()
    b.Count = b:CreateFontString()
    b.IconBorder = b:CreateTexture()
    B.StyleButton(b, nil)
    B.StyleButton(b, {})
    B:Refresh()
end)
-- every settings row explains itself on hover (description, default, reset, reload/combat notes)
try("row tooltips", function()
    local hovered = 0
    for _, m in ipairs(ns.moduleList) do
        local page = ns.Config:Show(m.key)
        for _, r in ipairs(page.rows or {}) do
            local enter = scripts[r] and scripts[r].OnEnter
            if enter and r.item and r.item.label then enter(r); hovered = hovered + 1 end
        end
    end
    assert(hovered > 150, "only " .. hovered .. " rows show a tooltip")
    for key, schema in pairs(ns.options) do
        for _, item in ipairs(schema) do
            assert(item.type ~= "header" or item.icon, key .. ": card header " .. tostring(item.label) .. " has no icon")
        end
    end
end)
-- presets: one click writes only existing keys, Undo restores them; the picker opens only on a fresh install
try("presets", function()
    local C = ns.Config
    local function snapshot()
        local out = {}
        for _, m in ipairs(ns.moduleList) do out[m.key] = ns.Util.DeepCopy(m.db) end
        return out
    end
    local function keys(t, prefix, out)
        for k, v in pairs(t) do
            local p = prefix .. "." .. tostring(k)
            out[p] = true
            if type(v) == "table" then keys(v, p, out) end
        end
        return out
    end
    local before = snapshot()
    local n = C:ApplyPreset("clean")
    assert(n > 5 and C:CanUndoPreset(), "the clean preset changed only " .. n .. " settings")
    assert(ns.modules.General.db.theme.barTexture == "Flat", "the preset did not set the bar texture")
    local after = snapshot()
    local kb, ka = keys(before, "", {}), keys(after, "", {})
    for k in pairs(ka) do
        if not kb[k] and not k:find("%.r$") and not k:find("%.g$") and not k:find("%.b$") and not k:find("%.a$") then
            error("a preset created the new key " .. k)
        end
    end
    C:UndoPreset()
    assert(ns.Util.Equal(snapshot(), before), "Undo did not restore every setting")
    assert(not C:CanUndoPreset(), "Undo is still offered")
    C:Show("presets")
    local ui = ns.DB.sv.global.ui
    local fresh, picked = ns.DB.fresh, ui.stylePicked
    ns.DB.fresh, ui.stylePicked = false, nil
    assert(C:ShowStylePicker() == nil, "the picker opened for an existing install")
    ns.DB.fresh = true
    local pk = C:ShowStylePicker()
    assert(pk and pk:IsShown(), "the picker did not open on a fresh install")
    pk.skip.onClick(pk.skip)
    assert(ui.stylePicked == "skip" and C:ShowStylePicker() == nil, "Skip did not stick")
    ns.DB.fresh, ui.stylePicked = fresh, picked
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

---------------------------------------------------------------- 2.0 S6: settings window v2 and the widget kit
-- chips: single pick, Shift-click extras, multi sets
try("chips", function()
    local W = ns.Widgets
    local shift = false
    local saved = rawget(env, "IsShiftKeyDown")
    rawset(env, "IsShiftKeyDown", function() return shift end)
    local c = W:Chips(env.CreateFrame("Frame"), { { value = "a", label = "A" }, { value = "b", label = "B" }, { value = "c" } })
    local got
    c.onChange = function(_, v, sh) got = { v, sh } end
    scripts[c.chips[2]].OnClick(c.chips[2])
    assert(c:GetValue() == "b" and got[1] == "b" and not got[2], "a chip click did not pick it")
    shift = true
    scripts[c.chips[3]].OnClick(c.chips[3])
    assert(c:GetValue() == "b" and c:GetExtra().c and got[2], "Shift-click did not add an extra chip")
    shift = false
    c:ClearExtra()
    assert(not next(c:GetExtra()), "ClearExtra kept extras")
    local m = W:Chips(env.CreateFrame("Frame"), { { value = "x" }, { value = "y" } }, true)
    scripts[m.chips[1]].OnClick(m.chips[1]); scripts[m.chips[2]].OnClick(m.chips[2]); scripts[m.chips[1]].OnClick(m.chips[1])
    assert(not m:GetValue().x and m:GetValue().y, "multi chips do not toggle a set")
    rawset(env, "IsShiftKeyDown", saved)
end)
-- section gates: the switch sits in the card header and turns the card's other rows off
try("gates", function()
    local C = ns.Config
    local m = ns.modules.NamePlates
    local page = C:Show("NamePlates")
    local gate, colors
    for _, r in ipairs(page.rows) do
        if r.item.key == "threat.enabled" then gate = r end
        if r.item.label == "NP_THREAT_PICK" then colors = r end
    end
    assert(gate and colors and gate.card.gateRow == gate, "the threat switch is not its card's gate")
    page.tabs.onChange(page.tabs, 2)
    page:Layout()
    assert(gate.mode == "gate", "the gate row was not laid out in the card header")
    ns.DB:Set(m, "threat.enabled", false); page:Refresh()
    assert(colors.enabledState == false, "a gated-off card left its rows enabled")
    ns.DB:Set(m, "threat.enabled", true); page:Refresh()
    assert(colors.enabledState == true, "turning the gate on did not enable its rows")
    -- every gate is the first row under a header
    for key, schema in pairs(ns.options) do
        for i, item in ipairs(schema) do
            if item.gate then assert(schema[i - 1] and schema[i - 1].type == "header", key .. ": a gate is not right after a header") end
        end
    end
end)
-- paired cells: compact rows sit two per line on a wide card, one per line on a narrow one
try("paired cells", function()
    local C = ns.Config
    local page = C:Show("UnitFrames")
    if page.tabs then page.tabs.onChange(page.tabs, 1) end -- the Frames tab: size and position rows pair up
    rawset(page.scroll.child, "GetWidth", function() return 1100 end)
    page:Layout()
    local cells = 0
    for _, r in ipairs(page.rows) do if r:IsShown() and r.mode == "cell" then cells = cells + 1 end end
    assert(cells >= 2, "no paired cells on a wide page")
    rawset(page.scroll.child, "GetWidth", nil)
    page:Layout()
    for _, r in ipairs(page.rows) do assert(r.mode ~= "cell", "a narrow page still pairs rows") end
end)
-- ⇄ apply to all copies a scoped row to every element
try("apply to all", function()
    local C = ns.Config
    local m = ns.modules.UnitFrames
    local page = C:Show("UnitFrames")
    local row
    for _, r in ipairs(page.rows) do if r.item.key == "units.@.texture" then row = r end end
    assert(row and row.applyAll, "a scoped row has no apply-to-all button")
    ns.DB:Set(m, "units." .. page.scope.unit .. ".texture", "Neon")
    local n = C.ApplyRowToAll(page, m, row.item)
    assert(n == #page.scope.values - 1, "apply to all wrote " .. n .. " elements")
    for _, e in ipairs(page.scope.values) do assert(m.db.units[e.value].texture == "Neon", e.value .. " was not updated") end
    for _, e in ipairs(page.scope.values) do ns.DB:Set(m, "units." .. e.value .. ".texture", m.defaults.units[e.value].texture) end
end)
-- the style library: every border, shadow and backdrop style draws; "theme" follows Appearance & General
try("border styles", function()
    local Skin, Opt = ns.Skin, ns.Opt
    local f = env.CreateFrame("Frame")
    for _, b in ipairs(Opt.BORDER) do
        for _, sh in ipairs(Opt.SHADOW) do Skin:BorderSpec(f, { style = b.value, size = 2, color = false, shadow = sh.value }) end
    end
    for _, bd in ipairs(Opt.BACKDROP) do Skin:Backdrop(f, { alpha = 0.6, color = false, style = bd.value }) end
    local General = ns.modules.General
    ns.DB:Set(General, "theme.borderStyle", "ember"); ns.DB:Set(General, "theme.borderSize", 3)
    local style, size = Skin:ResolveBorder({ style = "theme", size = 1 })
    assert(style == "ember" and size == 3, "a theme border does not follow Appearance & General")
    ns.DB:Set(General, "theme.borderStyle", "solid"); ns.DB:Set(General, "theme.borderSize", 1)
    for _, b in ipairs(Opt.BORDER_GLOBAL) do assert(b.value ~= "theme", "the global border list can point at itself") end
end)
-- colour fields: Class follows the class colour live, Theme returns to the token; a global border colour works
try("class token", function()
    local W, Skin = ns.Widgets, ns.Skin
    local f = W:ColorField(env.CreateFrame("Frame"), false, "border.black")
    local got
    f.onChange = function(_, v) got = v end
    f.chips.onChange(f.chips, "class")
    assert(type(got) == "table" and got.token == "class", "the Class chip did not save a class token")
    local r, g, b = Skin:SpecColor(got)
    assert(r and g and b, "a class token does not resolve to a colour")
    f.chips.onChange(f.chips, "theme")
    assert(got == false, "the Theme chip did not return to the theme")
    local General = ns.modules.General
    ns.DB:Set(General, "theme.borderColor", { token = "class" })
    ns.Theme:Apply(General.db.theme)
    ns.DB:Set(General, "theme.borderColor", false)
    ns.Theme:Apply(General.db.theme)
end)
-- search: the placeholder counts the settings it reaches
try("search count", function()
    local C = ns.Config
    C:InvalidateSearch()
    local n = C:SearchCount()
    assert(n > 300, "search reaches only " .. n .. " settings")
    C:UpdateSearchHint()
end)
-- profiles: export chosen modules, preview an import's changes, merge into the active profile
try("profiles v2", function()
    local P, DB = ns.Profiles, ns.DB
    local np = ns.modules.NamePlates
    local before = np.db.bar
    DB:Set(np, "bar", "Neon")
    local payload = P:Decode(P:Export({ NamePlates = true }))
    assert(payload and payload.partial and payload.profile.modules.NamePlates and not payload.profile.modules.UnitFrames,
        "a module export carried other modules")
    DB:Set(np, "bar", before)
    local diff = P:Diff(payload)
    assert(#diff == 1 and diff[1].key == "NamePlates" and diff[1].changes >= 1, "the import preview missed a change")
    assert(P:Merge(payload) == 1 and np.db.bar == "Neon", "merging did not write the module into this profile")
    DB:Set(np, "bar", before)
    assert(#DB:GetCharacters() >= 1, "no characters listed")
    assert(DB:SetCharacterProfile(DB.charKey, DB:GetProfileName()), "assigning this character's profile failed")
    assert(not DB:SetCharacterProfile("Nobody-Realm", "\0missing"), "a missing profile was assigned")
end)
-- the preview dock: wide windows pin the preview beside the page, narrow ones keep it in the page
try("dock", function()
    local C = ns.Config
    local f = C.frame
    rawset(f, "GetWidth", function() return 1280 end)
    local page = C:Show("NamePlates")
    C:LayoutShell()
    assert(page.docked and f.dock:IsShown(), "a 1280 px window did not dock the preview")
    assert(page.pinned:GetScale() <= 1, "the docked preview is not fitted")
    rawset(f, "GetWidth", function() return 1000 end)
    C:LayoutShell()
    assert(not page.docked and not f.dock:IsShown(), "a 1000 px window still docks the preview")
    rawset(f, "GetWidth", function() return 1280 end)
    local home = C:Show("home")
    C:LayoutShell()
    assert(home.docked and home.side, "Home's side panel did not dock")
    rawset(f, "GetWidth", nil)
    C:LayoutShell()
    -- stages wider than the dock scale down instead of clipping
    local stage = ns.Previews:Create("nameplate", env.CreateFrame("Frame"), ns.modules.NamePlates, {})
    assert(stage:Fit(300) < 1 and stage:Fit(900) == 1, "stage:Fit does not scale a wide preview")
end)
-- Home: filter chips narrow the module grid, every card shows its depth
try("home v2", function()
    local C = ns.Config
    local home = C:Show("home")
    home.filter:SetValue("frames"); home:Layout()
    local shown = 0
    for _, c in ipairs(home.cards) do if c:IsShown() then shown = shown + 1; assert(c.group == "frames", "filter let another group through") end end
    assert(shown >= 3, "the Frames filter shows " .. shown .. " cards")
    home.filter:SetValue("all"); home:Layout()
    for _, c in ipairs(home.cards) do assert(c.depth, "a module card has no depth meter") end
    home.side:Refresh()
end)

for _, e in ipairs(events) do fire(unpack(e)) end
-- A value written the way WoW writes SavedVariables (sorted keys, array items marked "-- [n]").
local function savedVariable(name, value)
    local out = { name .. " = " }
    local function emit(v, depth)
        local t = type(v)
        if t == "string" then out[#out + 1] = ("%q"):format(v):gsub("\\\n", "\\n")
        elseif t ~= "table" then out[#out + 1] = tostring(v)
        else
            local pad = ("\t"):rep(depth + 1)
            out[#out + 1] = "{\n"
            local keys = {}
            for k in pairs(v) do if type(k) == "string" then keys[#keys + 1] = k end end
            table.sort(keys)
            for _, k in ipairs(keys) do
                out[#out + 1] = pad .. ("[%q] = "):format(k)
                emit(v[k], depth + 1)
                out[#out + 1] = ",\n"
            end
            for i, item in ipairs(v) do
                out[#out + 1] = pad
                emit(item, depth + 1)
                out[#out + 1] = (", -- [%d]\n"):format(i)
            end
            out[#out + 1] = ("\t"):rep(depth) .. "}"
        end
    end
    emit(value, 0)
    out[#out + 1] = "\n"
    return table.concat(out)
end

-- Sim: item export, request shape, and importing what the app writes (uploader/testdata/sim_results.lua is
-- rendered by the Go writer and checked by its tests, so this is the shared file contract)
retailTry("sim", function()
    local M, X = ns.modules.Sim, ns.SimExport
    assert(M and X and M.db.mode == "compare", "sim defaults")
    local function link(fields, name)
        return ("|cffa335ee|Hitem:%s|h[%s]|h|r"):format(table.concat(fields, ":"), name)
    end
    -- id enchant gem1-4 suffix unique level spec mask context | 3 bonus IDs | 2 modifiers | relics, crafter
    local ring = link({ 212400, 7334, 213743, "", "", "", "", "", 90, 63, "", 13, 3, 10390, 11977, 1520,
        2, 9, 90, 29, 36, "", "", "", "" }, "Band of Tests")
    local saved = { C_TradeSkillUI = env.C_TradeSkillUI }
    rawset(env, "C_TradeSkillUI", { GetItemCraftedQualityByItemInfo = function() return 5 end })
    assert(X.Key(ring) == "212400:1520:10390:11977", "item key: " .. tostring(X.Key(ring)))
    local line = X.ItemLine(ring)
    assert(line == ",id=212400,enchant_id=7334,gem_id=213743,bonus_id=10390/11977/1520,drop_level=90,crafted_stats=36,crafting_quality=5",
        "item line: " .. tostring(line))
    assert(X.Split("|Hspell:1|h") == nil and X.ItemLine("junk") == nil, "non-item links must not export")
    -- a full profile and a compare request from stubbed character, equipment and bags
    local old = { link = ring, slot = 11 }
    local plain = link({ 190000, "", "", "", "", "", "", "", 90, 63, "", 13, 1, 1520, 0 }, "Old Ring")
    old.link = plain
    local stub = {
        UnitClass = function() return "Mage", "MAGE", 8 end, UnitRace = function() return "Void Elf", "VoidElf", 29 end,
        UnitLevel = function() return 90 end, GetCurrentRegionName = function() return "EU" end,
        GetProfessions = function() return nil end, CanDualWield = function() return false end,
        GetInventoryItemLink = function(_, slot) return slot == 11 and plain or nil end,
        C_SpecializationInfo = { GetSpecialization = function() return 2 end,
            GetSpecializationInfo = function() return 63 end },
        C_ClassTalents = { GetActiveConfigID = function() return 1 end },
        C_Traits = { GenerateImportString = function() return "CABBBBtest" end },
        ItemLocation = { CreateFromEquipmentSlot = function(_, slot) return { slot = slot } end,
            CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, bagSlot = slot } end },
        C_Item = { DoesItemExist = function(loc) return loc.slot == 11 or loc.bag == 0 end,
            GetItemLink = function(loc) return loc.slot == 11 and plain or ring end,
            GetCurrentItemLevel = function(loc) return loc.slot and 250 or 263 end,
            GetItemInfoInstant = function(l) return l:find("212400") and 212400 or 190000, nil, nil, "INVTYPE_FINGER", 1, 4, 0 end,
            GetItemQualityByID = function() return 4 end, GetItemInfo = function() return nil end },
        C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
            GetContainerItemInfo = function(bag) return bag == 0 and { hyperlink = ring, itemID = 212400 } or nil end },
        C_PlayerInfo = { CanUseItem = function() return true end },
    }
    for k, v in pairs(stub) do saved[k] = rawget(env, k); rawset(env, k, v) end
    local profile = X.Profile()
    assert(profile and profile:find('mage="Tester"', 1, true) and profile:find("spec=fire", 1, true)
        and profile:find("race=void_elf", 1, true) and profile:find("talents=CABBBBtest", 1, true)
        and profile:find("finger1=,id=190000", 1, true), "profile:\n" .. tostring(profile))
    local bag = M:BagItems()
    assert(#bag == 1 and bag[1].key == "212400:1520:10390:11977" and bag[1].slot == "finger", "bag gear")
    M.prepared = nil
    assert(select(2, M:Prepare()) == "SIM_ERR_NOTHING", "a compare with nothing ticked was accepted")
    M:Toggle(bag[1].key, true)
    assert(M:SetCount("compare", M:SelectedItems(bag), M:Equipped()) == 2, "a ring compares in both finger slots")
    local id = M:Prepare()
    local req = id and env.PhoenixUISimDB.requests[id]
    assert(req and req.char == "Tester-Realm" and req.mode == "compare" and #req.items == 1 and #req.equipped == 1
        and req.fight.style == "Patchwerk" and req.items[1].line == line, "request shape")
    assert(M:Status() == "ready", "a prepared request should be ready to send")
    -- the request as WoW saves it, for the app's tests (uploader/testdata/sim_request.lua, read by
    -- TestAddonRequest); PHOENIX_UPDATE_FIXTURES=1 rewrites it
    local fixture = env.CopyTable(req)
    fixture.id, fixture.created = "68f8e510c0ffee", 1761130000
    local sv = savedVariable("PhoenixUISimDB", { schema = 1, requests = { [fixture.id] = fixture } })
    local path = "uploader/testdata/sim_request.lua"
    if os.getenv("PHOENIX_UPDATE_FIXTURES") == "1" then
        local f = assert(io.open(path, "wb"))
        f:write(sv)
        f:close()
    end
    local f = assert(io.open(path, "rb"), path .. " is missing; run with PHOENIX_UPDATE_FIXTURES=1")
    assert(f:read("*a") == sv, path .. " is stale; run with PHOENIX_UPDATE_FIXTURES=1")
    f:close()
    M.prepared = nil
    assert(M:Status() == "sent", "a request on disk should be sent")
    -- what the app writes: a done compare and a failure, imported once
    rawset(env, "time", function() return 1761130000 + 600 end)
    local chunk = assert(loadfile("uploader/testdata/sim_results.lua"))
    setfenv(chunk, env)
    chunk()
    assert(M:Import() == 2 and env.PhoenixUISimResults == nil, "results not imported")
    env.PhoenixUISimResults = nil
    local hist = M:History()
    assert(#hist == 2 and hist[1].state == "done" and hist[1].sets[2].label == "Band of | Tests", "history")
    assert(hist[2].error:find("no talents", 1, true), "the failure text was lost")
    -- the request answered by the fixture is closed (its id differs, so the open one stays)
    assert(env.PhoenixUISimDB.requests[id], "an unrelated request was closed")
    M.index = nil
    local r = M:ItemResult(ring)
    assert(r and r.pct == 0.42 and r.delta == 960, "item result from the sim")
    assert(M:Describe(r):find("+0.4%", 1, true), "describe: " .. M:Describe(r))
    assert(M:ItemResult(plain) == nil, "an item that was not simmed has no result")
    chunk()
    assert(M:Import() == 0, "the same results imported twice")
    rawset(env, "time", function() return 1761130000 + 40 * 86400 end)
    env.PhoenixUISimDB.imported = {}
    chunk()
    assert(M:Import() == 0, "results older than the import marks came back")
    rawset(env, "time", function() return 1761130000 + 600 end)
    M:Delete(hist[2].id)
    assert(#M:History() == 1, "delete")
    M:Cancel()
    assert(M:Status() == "idle", "cancel")
    rawset(env, "time", nil)
    M.selected = {}
    for k, v in pairs(saved) do rawset(env, k, v) end
end)

-- action bars (plan v2 S7): pure layout, state drivers, paging macro, short keys, fading, items, glow, depth
try("action bars layout", function()
    local M = ns.modules.ActionBars
    local b = { buttons = 12, rows = 2, width = 40, height = 30, square = false, spacingX = 2, spacingY = 4,
        grow = "RIGHT", wrap = "DOWN", order = "normal" }
    local pts, w, h, bw, bh = M.Layout(b, 12)
    assert(#pts == 12 and w == 6 * 40 + 5 * 2 and h == 2 * 30 + 4 and bw == 40 and bh == 30, "2x6 grid size")
    assert(pts[1][1] == 0 and pts[1][2] == 0 and pts[7][1] == 0 and pts[7][2] == 34, "second row starts under the first")
    b.grow, b.wrap = "LEFT", "UP"
    pts = M.Layout(b, 12)
    assert(pts[1][1] == 5 * 42 and pts[1][2] == 34, "LEFT/UP should start bottom right")
    b.grow, b.wrap, b.rows, b.square = "DOWN", "DOWN", 1, true
    pts, w, h = M.Layout(b, 3)
    assert(w == 40 and h == 3 * 40 + 2 * 4 and pts[3][2] == 88, "vertical bars stack and square uses the width")
    b.order = "reversed"
    pts = M.Layout(b, 3)
    assert(pts[1][2] == 88 and pts[3][2] == 0, "reversed order fills from the last slot")
    assert(#M.Layout(b, 0) == 0, "zero buttons")
    assert(M.BarsEngine.Encode({ { 0, 0 }, { 42.5, -3 } }) == "0.00,0.00;42.50,-3.00;", "snippet encoding")
    -- the restricted snippet's own pattern reads every encoded point back
    local n = 0
    for x, y in ("0.00,0.00;42.50,-3.00;"):gmatch("([%-%d%.]+),([%-%d%.]+);") do n = n + 1; assert(tonumber(x) and tonumber(y)) end
    assert(n == 2, "LAYOUT snippet pattern does not parse the encoding")
    assert(M.BarsEngine.Flyout({ grow = "RIGHT" }, 0, 100, 1024, 768) == "UP", "flyouts near the bottom open up")
    assert(M.BarsEngine.Flyout({ grow = "DOWN" }, 1000, 0, 1024, 768) == "LEFT", "flyouts near the right open left")
end)
try("action bars drivers", function()
    local M = ns.modules.ActionBars
    local vis = { combat = true, ooc = true, hideVehicle = true, macro = "" }
    local d = M.VisibilityDriver({ vis = vis })
    assert(d == "[petbattle] hide; [vehicleui] hide; [overridebar] hide; show", d)
    vis.ooc, vis.hideVehicle = false, false
    assert(M.VisibilityDriver({ vis = vis }, "pet") == "[petbattle] hide; [nopet] hide; [combat] show; hide", "pet combat")
    vis.macro = "  [mod:alt] show; hide "
    assert(M.VisibilityDriver({ vis = vis }):find("; %[mod:alt%] show; hide$"), "a custom macro replaces the rules")
    local p = M.PageDriver({ possess = true, forms = true, sky = true, shift = 2, ctrl = 0, alt = 9 })
    assert(p:find("^%[vehicleui%] vehicle; %[overridebar%] override; %[possessbar%] possess; %[shapeshift%] temp; "), p)
    assert(p:find("[mod:shift] 2", 1, true) and not p:find("mod:alt", 1, true), "modifier pages are range checked")
    assert(p:find("[bar:2] p2", 1, true) < p:find("[bonusbar:1] b1", 1, true), "manual pages win over form pages")
    assert(p:find("[bonusbar:5] b5", 1, true) and p:find("; p1$"), "skyriding and the default page")
    assert(not M.PageDriver({ sky = true }, false):find("bonusbar:5", 1, true), "skyriding without the feature")
    local up = M.BarsEngine.PageMacro(1)
    assert(up == "/changeactionbar [bar:1] 2; [bar:2] 3; [bar:3] 4; [bar:4] 5; [bar:5] 6; 1", up)
    assert(M.BarsEngine.PageMacro(-1):find("^/changeactionbar %[bar:1%] 6; "), "page down wraps to 6")
    local v = { alpha = 1, fade = true, oocAlpha = 0.4, mouseover = false }
    assert(M.TargetAlpha(v, {}) == 0.4 and M.TargetAlpha(v, { combat = true }) == 1, "fade out of combat")
    v.mouseover = true
    assert(M.TargetAlpha(v, { combat = true }) == 0 and M.TargetAlpha(v, { hover = true }) == 1, "mouseover")
    assert(M.TargetAlpha(v, { reveal = true }) == 1, "dragging a spell reveals the bars")
    assert(M.ShortKey("SHIFT-BUTTON4") == "S-M4" and M.ShortKey("CTRL-ALT-NUMPAD5") == "C-A-N5", "short keys")
    assert(M.ShortKey("MOUSEWHEELUP") == "WU" and M.ShortKey("Q") == "Q" and M.ShortKey("") == nil, "short keys 2")
    local ids = M.ParseItems("5512, 5512 ;abc 171267\n0")
    assert(#ids == 2 and ids[1] == 5512 and ids[2] == 171267, "item list parsing")
    local G = ns.Glow
    local x, y, side = G.Perimeter(0, 40, 20); assert(x == 0 and y == 0 and side == "top", "perimeter start")
    x, y, side = G.Perimeter(50, 40, 20); assert(x == 40 and y == 10 and side == "right", "perimeter right")
    x, y, side = G.Perimeter(110, 40, 20); assert(x == 0 and y == 10 and side == "left", "perimeter wraps")
    local owner = env.CreateFrame("Button")
    for _, style in ipairs({ "pixel", "autocast", "button" }) do
        G:Show(owner, style, 1, 1, 0, 1)
        assert(G:IsShown(owner), style .. " glow did not show")
        G:Hide(owner)
        assert(not G:IsShown(owner), style .. " glow did not hide")
    end
end)
try("action bars engine", function()
    local M = ns.modules.ActionBars
    local B = M.BarsEngine
    assert(M.DEFAULTS.mode == "phoenix", "Phoenix bars are the default (" .. tostring(M.db.mode) .. ")")
    for _, def in ipairs(M.BARS) do
        assert(M.db.bars[def.key] and M.DEFAULTS.bars[def.key], "bar " .. def.key .. " has no saved shape")
        assert(B.Shown(def, M.db.bars[def.key]) <= def.count, "more buttons than the bar holds")
    end
    for _, key in ipairs({ "bar1", "bar2", "bar3" }) do M:RefreshBar(key) end
    M:RefreshButtons(); M:RefreshItems(); M:RefreshExtras(); M:Refresh()
    assert(M:FeedbackColor("range") and M:BorderColor(), "feedback colours")
    -- Layout mode writes bar positions through the store delegate
    local mv = ns.modules.Movers
    local e
    for _, it in ipairs(mv and mv:GetEntries() or {}) do if it.key == "ab.bar2" then e = it end end
    if M:IsPhoenix() then assert(e and e.store, "bar 2 is not in Layout mode") end
    if e and e.store then
        local was = M.db.bars.bar2.y
        e.store.set({ point = "BOTTOM", x = 10, y = 333 })
        assert(M.db.bars.bar2.y == 333 and M.db.bars.bar2.x == 10, "a moved bar did not save its offset")
        e.store.reset()
        assert(M.db.bars.bar2.y == was and M.db.bars.bar2.x == 0, "resetting a bar did not restore the default")
    end
    -- cooldown numbers follow the icon size when scaling is on
    local C = ns.modules.CooldownText
    local size, scale = C.db.size, C.db.scale
    C.db.size, C.db.scale = 16, true
    assert(C:SizeFor(36) == 16 and C:SizeFor(18) == 8 and C:SizeFor(72) == 32 and C:SizeFor(200) == 32, "SizeFor")
    C.db.scale = false
    assert(C:SizeFor(72) == 16, "SizeFor without scaling")
    C.db.size, C.db.scale = size, scale
end)
try("action bars depth", function()
    local Config = ns.Config
    for key, target in pairs({ ActionBars = 114, CooldownText = 12 }) do
        local n = Config.CountSettings(ns.options[key])
        assert(n >= target and Config.DEPTH[key] == target, ("%s has %d of %d settings"):format(key, n, target))
    end
end)


-- unit frames (S8): tag compiler, number breakpoints, pure geometry, Phoenix frames, movers, cast bar hook, depth
try("unit frame tags", function()
    local M = ns.modules.UnitFrames
    local c = M.CompileTags("[name] 100% [health:percent]", 1)
    assert(c.fmt == "%s 100%% %.1f%%", "tag format: " .. tostring(c.fmt))
    assert(#c.getters == 2 and not c.empty, "tag getters")
    assert(M.CompileTags("[nope]", 0).fmt == "[nope]", "unknown tags stay literal")
    assert(M.CompileTags("", 0).empty, "an empty tag string is empty")
    assert(M.CompileTags("[name]", 0) == M.CompileTags("[name]", 0), "compiled tags are cached")
    local many = M.CompileTags(("[name]"):rep(12), 0)
    assert(#many.getters == M.MAX_TAG_VALUES, "more than 8 values are dropped")
    for _, name in ipairs(M.TAG_LIST) do assert(M.TAGS[name], "listed tag missing: " .. name) end
    local data = M.AbbrevOptions(1).breakpointData
    assert(#data == 8 and data[1].breakpoint == 1e13 and data[2].fractionDivisor == 10, "abbreviation breakpoints")
    assert(M.AbbrevOptions(0).breakpointData[2].fractionDivisor == 1, "no-decimal breakpoints")
end)
try("unit frame geometry", function()
    local M = ns.modules.UnitFrames
    local u = M.db.units.player
    local g = M.Geometry({ width = 200, height = 40, portrait = "game", portraitPos = "left",
        powerBar = { show = "always", height = 8, position = "inside", gap = 1 } })
    assert(g.portrait[3] == 40 and g.health[1] == 41 and g.health[3] == 159, "portrait on the left")
    assert(g.power[2] == 32 and g.power[4] == 8 and g.health[4] == 31, "inside power bar")
    g = M.Geometry({ width = 200, height = 40, portrait = "hide", powerBar = { show = "off", height = 8 } })
    assert(not g.portrait and not g.power and g.health[3] == 200, "no portrait, no power")
    local pips = M.Pips(5, 100, 2)
    assert(#pips == 5 and pips[1][2] == 18 and pips[5][1] + pips[5][2] == 100, "pips fill the width")
    local slots = M.AuraSlots(10, 20, 8, 2, "LEFT", true)
    assert(slots[2][1] == -22 and slots[9][1] == 0 and slots[9][2] == 22, "aura slots wrap and grow")
    assert(M.ClassPowerKind("ROGUE") == "ComboPoints" and M.ClassPowerKind("DRUID", nil, "ENERGY") == "ComboPoints"
        and M.ClassPowerKind("DRUID", nil, "MANA") == nil and M.ClassPowerKind("MONK", 268) == "Stagger"
        and M.ClassPowerKind("WARRIOR") == nil, "class power kinds")
    assert(M.KeyOf("boss3") == "boss" and M.KeyOf("targettarget") == "targettarget" and M.KeyOf("raid1") == nil, "KeyOf")
    assert(u.enabled and M.DEFAULTS.units.arena.enabled == false, "arena frames are off by default")
end)
try("unit frames phoenix", function()
    local M = ns.modules.UnitFrames
    assert(M:IsPhoenix(), "Phoenix frames are the default")
    for _, key in ipairs({ "player", "target", "targettarget", "focus", "focustarget", "pet", "boss" }) do
        local list = M.frames[key]
        assert(list and list[1] and list[1].layoutDone, key .. " frame was not built")
        assert(list[1].watched, key .. " is not a secure unit button")
    end
    assert(#M.frames.boss == 5, "five boss frames")
    for _, f in ipairs(M.frames.arena or {}) do assert(not f.watched, "an arena frame is watched while off") end
    local movers = ns:GetModule("Movers")
    local e = movers and movers:GetEntry("uf.player")
    assert(e and e.store and e.store.active(), "the player frame has no mover")
    local st = e.store.get()
    e.store.set({ point = st.point, x = st.x + 5, y = st.y }); assert(M.db.units.player.x == st.x + 5, "mover set")
    e.store.reset(); assert(M.db.units.player.x == M.DEFAULTS.units.player.x, "mover reset")
    assert(M:CastBarAnchor("target") and M:CastBarAnchor("boss", 3), "no cast bar anchor for S9")
    -- a sample frame builds, lays out and updates with every element on
    local f = M:Build(env.UIParent, "target", { sample = M.SampleData("target", 1) })
    M:Layout(f); M:UpdateAll(f)
    local u = M.db.units.target
    for _, mode in ipairs({ "class", "reaction", "health", "fixed", "theme" }) do u.bar.color = mode; M:UpdateHealth(f, M.Sample) end
    for _, mode in ipairs({ "model", "class", "hide", "game" }) do u.portrait = mode; M:Layout(f); M:UpdatePortrait(f, M.Sample) end
    u.bar.color = M.DEFAULTS.units.target.bar.color
    local p = M:Build(env.UIParent, "player", { sample = M.SampleData("player", 1) })
    M:Layout(p); M:UpdateAll(p)
    for _, n in ipairs({ "full", "asian", "short" }) do M.db.numbers = n; assert(M:Number(12345) ~= nil, "number " .. n) end
    assert(M:ShowTest(true) and M.testShown and M.frames.boss[2].sample, "Phoenix test frames")
    assert(M:ShowTest(false) and not M.testShown and not M.frames.boss[2].sample, "Phoenix test frames did not hide")
end)
try("unit frames blizzard fallback", function()
    local M = ns.modules.UnitFrames
    M.db.mode = "blizzard"
    assert(M:ShowTest(true) and M.testShown, "Blizzard-mode test frames")
    assert(M:ShowTest(false) and not M.testShown, "Blizzard-mode test frames did not hide")
    M:RefreshBlizzard(); M:UpdateBlizzardRange()
    M.db.mode = "phoenix"
end)
try("unit frames depth (S8)", function()
    local n = ns.Config.CountSettings(ns.options.UnitFrames)
    assert(n >= 150 and ns.Config.DEPTH.UnitFrames == 150, ("UnitFrames has %d of 150 settings"):format(n))
    print(("  UnitFrames settings: %d"):format(n))
end)

-- cast bars (S9): pure helpers, Phoenix bars and parking, anchors, test casts, live cast events, depth
try("cast bar helpers", function()
    local M = ns.modules.CastBars
    assert(M.FormatTime("remaining", 1, 1.25, 3) == "1.2" or M.FormatTime("remaining", 1, 1.25, 3) == "1.3", "remaining")
    assert(M.FormatTime("both", 0, 1, 3) == "1 / 3" and M.FormatTime("elapsedTotal", 1, 1, 3) == "2.0 / 3.0", "both / elapsed")
    assert(M.FormatTime("none", 1, 1, 3) == "" and M.FormatTime("elapsed", 0, 0.4, 2) == "2", "none / elapsed")
    local t = M.ParseTicks("15407:4, 5143=3 junk 99:0 12:31")
    assert(t[15407] == 4 and t[5143] == 3 and t[99] == nil and t[12] == nil, "tick list parsing")
    M.db.customTicks = "15407:4"
    assert(M:TickCount(15407) == 4 and M:TickCount(5143) == M.TICKS[5143] and M:TickCount(1) == nil, "custom ticks override")
    M.db.customTicks = ""
    local o = M.TickOffsets(4, 200)
    assert(#o == 3 and o[1] == 50 and o[3] == 150 and #M.TickOffsets(1, 200) == 0, "tick offsets")
    local st = M.StageOffsets({ 0.25, 0.25, 0.5 }, 100)
    assert(#st == 2 and st[1] == 25 and st[2] == 50, "empower stage offsets")
    assert(M.LatencyShare(100, 2) == 0.05 and M.LatencyShare(5000, 2) == 1 and M.LatencyShare(nil, 2) == 0, "latency share")
    assert(M.CutName("Pyroblast", 4) == "Pyro…" and M.CutName("Pyro", 0) == "Pyro", "name cut")
    local g = M.Geometry({ icon = "left", iconGap = 2 }, 200, 20)
    assert(g.icon[3] == 20 and g.bar[1] == 22 and g.bar[3] == 178, "icon inside on the left")
    g = M.Geometry({ icon = "right", iconDetached = true, iconSize = 30, iconGap = 4 }, 200, 20)
    assert(g.icon[1] == 204 and g.icon[2] == -5 and g.bar[3] == 200, "detached icon on the right")
    assert(not M.Geometry({ icon = "off" }, 200, 20).icon, "no icon")
    assert(M.KeyOf("boss2") == "boss" and M.KeyOf("player") == "player" and M.KeyOf("raid1") == nil, "KeyOf")
    for _, kind in ipairs({ "cast", "channel", "locked", "notReady", "interrupted", "success" }) do
        assert(M:StateColor("target", kind), "state colour " .. kind)
    end
end)
try("cast bars phoenix", function()
    local M = ns.modules.CastBars
    assert(M:IsPhoenix(), "Phoenix cast bars are the default")
    for _, key in ipairs(M.KEYS) do
        local list = M.bars[key]
        assert(list and #list == (M.COUNT[key] or 1), key .. " bars were not built")
        assert(list[1].layoutDone, key .. " bar was not laid out")
    end
    assert(M:Owns("player") and M:Owns("target") and M:Owns("boss"), "the module owns its bars")
    local movers = ns:GetModule("Movers")
    local e = movers and movers:GetEntry("cb.player")
    assert(e and e.store, "the player cast bar has no mover")
    local before = M.db.bars.player.x
    local st = e.store.get()
    e.store.set({ point = st.point, x = st.x + 7, y = st.y }); assert(M.db.bars.player.x == st.x + 7, "mover set")
    e.store.reset(); assert(M.db.bars.player.x == before or M.db.bars.player.x == M.DEFAULTS.bars.player.x, "mover reset")
    assert(M.AnchorOf("target", 1), "the target bar should sit on the Unit Frames anchor")
    M.db.bars.target.attach = "free"; M:Refresh()
    assert(not M.AnchorOf("target", 1), "a free bar must not use the anchor")
    M.db.bars.target.attach = "frame"; M:Refresh()
    -- test casts on every bar, then off again
    assert(M:ShowTest(true) and M.testShown and M.bars.boss[3].sample, "test casts")
    for _, key in ipairs(M.KEYS) do
        for _, f in ipairs(M.bars[key]) do M.OnBarUpdate(f, 0.2); M.OnBarUpdate(f, 5) end
    end
    assert(M:ShowTest(false) and not M.testShown and not M.bars.boss[3].sample, "test casts did not stop")
    -- the preview path: a frozen sample on a free-standing bar, the interrupted flash, every time format
    local f = M:BuildBar(env.UIParent, "target", { preview = true })
    for _, kind in ipairs(M.TIME_FORMATS) do
        M.db.bars.target.timeFormat = kind
        M:LayoutBar(f, 200, 18)
        M:StartSample(f, { kind = "channel", total = 3, elapsed = 1, kick = 0.5, frozen = true, ticks = 5 })
    end
    M.db.bars.target.timeFormat = "remaining"
    f.sample = nil; M:EndCast(f, "interrupted"); M:EndCast(f, "success")
    local p = M:BuildBar(env.UIParent, "player", { preview = true })
    M:LayoutBar(p, 200, 18)
    M:StartSample(p, { kind = "empower", total = 3, elapsed = 1, stages = { 0.3, 0.3, 0.4 }, frozen = true })
    M:StartSample(p, { kind = "channel", total = 3, elapsed = 1, ticks = 5, latency = 0.1, frozen = true })
    -- live events: the stub client returns opaque values for every cast query; nothing may error
    for _, ev in ipairs(M.CAST_EVENTS) do M:OnCastEvent(M.bars.target[1], ev, "target") end
    M:OnCastEvent(M.bars.player[1], "UNIT_SPELLCAST_START", "player")
    M:OnCastEvent(M.bars.player[1], "UNIT_SPELLCAST_STOP", "player")
    for _, ev in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
        "ARENA_OPPONENT_UPDATE", "PLAYER_ENTERING_WORLD" }) do fire(ev, "player") end
end)
try("cast bars blizzard fallback", function()
    local M = ns.modules.CastBars
    M.db.mode = "blizzard"
    assert(M:ShowTest(true) and M:ShowTest(false), "Blizzard-mode test casts")
    M:RefreshBlizzard()
    M.db.mode = "phoenix"
end)
try("cast bars depth (S9)", function()
    local n = ns.Config.CountSettings(ns.options.CastBars)
    assert(n >= 55 and ns.Config.DEPTH.CastBars == 55, ("CastBars has %d of 55 settings"):format(n))
    print(("  CastBars settings: %d"):format(n))
end)
-- auras (S9): header attributes, slots, time formats, headers and buttons, test auras, depth
try("aura helpers", function()
    local M = ns.modules.Auras
    local h = M:Header("buffs")
    local f = M.Flow(h)
    assert(f.point == "TOPRIGHT" and f.horizontal == "Left" and f.vertical == "Down", "buffs flow left and down")
    assert(f.lineSize == h.perRow * h.size + (h.perRow - 1) * h.hSpacing, "rows wrap after perRow buttons")
    local method, dir = M.SortMethod({ sort = "TIME", separateOwn = 1, direction = "+" })
    assert(method == "Expiration" and dir == "Normal", "time, own first")
    method, dir = M.SortMethod({ sort = "NAME", separateOwn = 0, direction = "-" })
    assert(method == "NameOnly" and dir == "Reverse", "name, mixed, reversed")
    assert(M.SortMethod({ sort = "INDEX", separateOwn = 0 }) == "AuraInstanceIDOnly", "applied order")
    local up = { size = 30, perRow = 4, rows = 2, hSpacing = 2, vSpacing = 10, growth = "RIGHT", wrap = "UP" }
    local point, x, y = M.Layout(up)
    assert(point == "BOTTOMLEFT" and x == 32 and y == 40, "right and up")
    local slots = M.Slots(up, 6)
    assert(#slots == 6 and slots[5][1] == 0 and slots[5][2] == 40 and slots[4][1] == 96, "slots wrap")
    assert(#M.Slots(up, 20) == 8, "slots stop at rows x per row")
    local w, ht = M.HolderSize(up)
    assert(w == 126 and ht == 70, "holder size")
    assert(M.FormatDuration("short", 5, 7300) == "3h" and M.FormatDuration("short", 5, 125) == "3m", "short hours/minutes")
    assert(M.FormatDuration("short", 5, 4.25) == "4.2" or M.FormatDuration("short", 5, 4.25) == "4.3", "tenths")
    assert(M.FormatDuration("clock", 0, 3723) == "1:02:03" and M.FormatDuration("clock", 0, 245) == "4:05", "clock")
    assert(M.FormatDuration("seconds", 0, 844.2) == "845" and M.FormatDuration("short", 0, 0) == "", "seconds / none")
    assert(#M.Breakpoints("short", 5) >= 3, "duration breakpoints")
    M.db.shape = "wide"; assert(M.Height({ size = 40 }) == 28, "wide buttons"); M.db.shape = "square"
end)
try("auras phoenix", function()
    local M = ns.modules.Auras
    assert(M:IsPhoenix(), "Phoenix auras are the default")
    assert(M.containers.buffs and M.containers.debuffs and M.containers.enchants, "the aura containers were not created")
    local movers = ns:GetModule("Movers")
    for _, k in ipairs({ "auras.buffs", "auras.debuffs", "auras.enchants", "auras.private" }) do
        assert(movers and movers:GetEntry(k), "no mover " .. k)
    end
    assert(M:ShowTest(true) and M.testShown, "test auras")
    assert(M:ShowTest(false) and not M.testShown, "test auras did not hide")
    for _, mode in ipairs({ "separate", "hide", "buffs" }) do M.db.enchants = mode; M:Refresh() end
    M.db.private.enabled = false; M:Refresh(); M.db.private.enabled = true; M:Refresh()
    local b = M:Dress(env.CreateFrame("Button"), "debuffs")
    M:Style(b)
    for _, s in ipairs(M.SAMPLES.debuffs) do M:ShowSample(b, s, "debuffs") end
    -- a container button: the initializer dresses it and hands its widgets to the container
    for _, kind in ipairs({ "buffs", "debuffs", "enchant" }) do
        local btn = env.CreateFrame("Button")
        M.Initializer(kind)(btn)
        assert(btn.puiNative and M.buttons[btn] == kind, "container button not dressed: " .. kind)
    end
    M.db.shape = "wide"; M.db.typeBorder = true; M.db.buffTypes = true; M:Refresh()
    M.db.shape = "square"; M.db.buffTypes = false; M.db.colorByTime = false; M:Refresh(); M.db.colorByTime = true
end)
try("auras blizzard fallback", function()
    local M = ns.modules.Auras
    M.db.mode = "blizzard"
    assert(M:ShowTest(true) and M:ShowTest(false), "Blizzard-mode test auras")
    M:RefreshBlizzard()
    M.db.mode = "phoenix"
end)
try("auras depth (S9)", function()
    local n = ns.Config.CountSettings(ns.options.Auras)
    assert(n >= 41 and ns.Config.DEPTH.Auras == 41, ("Auras has %d of 41 settings"):format(n))
    print(("  Auras settings: %d"):format(n))
end)

fire("PLAYER_LOGOUT")

-- icon system: every name the UI asked for must exist, and tier selection must follow physical pixels
for name in pairs(ns.Icons and ns.Icons.missing or {}) do errors[#errors + 1] = "unknown icon: " .. name end
-- tooltip post-calls run for every tooltip in the game: non-GameTooltips, forbidden ones and secret data are skipped
try("tooltip hooks", function()
    assert(#postCalls >= 3, "tooltip post-calls not registered (" .. #postCalls .. ")")
    local faults = {}
    local handler = env.geterrorhandler
    rawset(env, "geterrorhandler", function() return function(e) faults[#faults + 1] = tostring(e) end end)
    local plainFrame = { IsForbidden = function() return false end } -- e.g. an embedded or third-party tooltip
    local forbidden = { IsForbidden = function() return true end }
    local SECRET = {}
    local secretTip = setmetatable({ IsForbidden = function() return false end, AddLine = function() end,
        GetUnit = function() return "Tester", SECRET end, GetItem = function() return "x", SECRET end }, { __index = magic })
    local isSecret = ns.Secret.IsSecret
    ns.Secret.IsSecret = function(v) return v == SECRET end
    for _, fn in ipairs(postCalls) do
        fn(plainFrame, {}); fn(forbidden, {}); fn(secretTip, { id = SECRET, hyperlink = SECRET })
    end
    ns.Secret.IsSecret = isSecret
    rawset(env, "geterrorhandler", handler)
    assert(#faults == 0, "a tooltip hook failed: " .. tostring(faults[1]))
end)
try("icon fallback", function()
    local I = ns.Icons
    -- the stub client "fails" every probe, so the automatic source must switch to game icons
    ns.DB.sv.global.diag = { version = ns.version, media = { { kind = "icons", ok = false } } }
    I:SetSource("auto")
    assert(I.game, "a failed atlas in /pui diag did not switch to game icons")
    local probe = env.CreateFrame("Frame"):CreateTexture()
    I:Apply(probe, "close", 16)
    assert(I:Markup("home", 14):find("Interface\\Icons\\", 1, true), "game markup should use a stock icon")
    I:SetSource("phoenix")
    assert(not I.game and ns.DB.sv.global.icons == "phoenix", "choosing Phoenix glyphs did not stick")
    local page = ns.Config:Show("diagnostics")
    assert(ns.Config.DiagReport():find("Phoenix UI", 1, true), "diagnostics report is empty")
    assert(page.rows and #page.rows > 5, "diagnostics page has no rows")
end)
try("icon tiers", function()
    local probe = env.CreateFrame("Frame"):CreateTexture()
    ns.Icons:Apply(probe, "home", 16) -- 16 * 1 / (768/2160) = 45 px -> 48 px cells
    local _, cell = ns.Icons:GetTier(probe)
    assert(cell == 48, "16 pt icon at 4K should use 48 px cells, got " .. tostring(cell))
    ns.Icons:Apply(probe, "home", 30)
    _, cell = ns.Icons:GetTier(probe)
    assert(cell == 64, "30 pt icon at 4K should use 64 px cells, got " .. tostring(cell))
    -- the game loads power-of-two textures up to 1024 px per edge; the shipped atlases stay inside that
    for _, t in ipairs(ns.IconData.tiers) do
        assert(t.width <= 1024 and t.height <= 1024, t.file .. " is " .. t.width .. "x" .. t.height)
        assert(t.width >= ns.IconData.cols * t.cell, t.file .. " is narrower than its columns")
    end
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
