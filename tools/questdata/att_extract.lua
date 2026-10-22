--[[ Reads AllTheThings (MIT) source DB files at build time and prints plain facts, one per line, for
    tools/questdata/build_questdata.py. Phoenix's own reader: it gives the DB's constructor names
    (q, n, m, header, ...) tiny stand-ins that only record what was passed, so no ATT parser code is used.

    lua5.1 tools/questdata/att_extract.lua <retail|forever> <shared-dir> <file.lua> [file.lua ...] > facts.txt

    The DB's `-- #if AFTER 12.1.0` / `#else` / `#endif` comment directives are honoured for the chosen game
    (retail = build 12.1.5, forever = WoW Forever), so each game gets the coordinates that apply to it.

    Output lines (fields separated by |, lists by ,):
      Q|questID|uiMapID|x|y|npcIDs|sourceQuests|sourceQuestNumRequired|races|classes|minLevel|flags|timeline|u|file
      N|npcID|uiMapID|x|y|file
    x and y are map percentages as the DB writes them (0-100). Unknown names resolve to inert stubs. ]]
local FLAVOR = assert(arg[1], "usage: att_extract.lua <retail|forever> <shared-dir> <file.lua> ...")
local shared = assert(arg[2], "usage: att_extract.lua <retail|forever> <shared-dir> <file.lua> ...")

---------------------------------------------------------------- directives
local EXPANSIONS = { CLASSIC = "1", TBC = "2", WRATH = "3", CATA = "4", MOP = "5", WOD = "6", LEGION = "7", BFA = "8",
    SL = "9", SHADOWLANDS = "9", DF = "10", TWW = "11", MID = "12", MIDNIGHT = "12", TLT = "13" }
local CURRENT = FLAVOR == "forever" and "1.60.1" or "12.1.5"
local FLAGS = FLAVOR == "forever" and { FOREVER = true } or { RETAIL = true }

local function version(text)
    local out = {}
    for part in tostring(EXPANSIONS[text:upper()] or text):gmatch("%d+") do out[#out + 1] = tonumber(part) end
    return out
end
local function compare(a, b) -- -1, 0, 1 comparing the parts both have
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end
local function test(cond)
    cond = cond:gsub("^%s+", ""):gsub("%s+$", "")
    local a, b = cond:match("^(.-)%s+OR%s+(.+)$")
    if a then return test(a) or test(b) end
    a, b = cond:match("^(.-)%s+AND%s+(.+)$")
    if a then return test(a) and test(b) end
    local rest = cond:match("^NOT%s+(.+)$")
    if rest then return not test(rest) end
    local word, arg1 = cond:match("^(%u+)%s+(%S+)")
    if word == "AFTER" then return compare(version(CURRENT), version(arg1)) >= 0 end
    if word == "BEFORE" then return compare(version(CURRENT), version(arg1)) < 0 end
    return FLAGS[cond:upper()] == true
end
-- Comments out lines in inactive #if branches (nested), keeping line numbers.
local function preprocess(text)
    local out, stack = {}, {}
    local function active() for _, f in ipairs(stack) do if not f.on then return false end end return true end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local dir, cond = line:match("^%s*%-%-%s*#(%a+)%s*(.-)%s*$")
        dir = dir and dir:lower()
        if dir == "if" then
            local parent = active()
            local on = test(cond)
            stack[#stack + 1] = { on = on, taken = on, parent = parent }
        elseif dir == "elseif" and #stack > 0 then
            local top = stack[#stack]
            top.on = not top.taken and test(cond)
            top.taken = top.taken or top.on
        elseif dir == "else" and #stack > 0 then
            local top = stack[#stack]
            top.on = not top.taken
            top.taken = true
        elseif dir == "endif" and #stack > 0 then
            stack[#stack] = nil
        elseif not active() then
            line = "-- " .. line
        end
        out[#out + 1] = line
    end
    return table.concat(out, "\n")
end

local stubMeta
local function stub(name)
    return setmetatable({ __stub = name }, stubMeta)
end
-- What an unknown call returns: a plain record that also survives being joined into a string.
local resultMeta = { __concat = function(a, b) return tostring(a) .. tostring(b) end }
stubMeta = {
    __call = function(self, ...)
        return setmetatable({ __fn = rawget(self, "__stub"), n = select("#", ...), ... }, resultMeta)
    end,
    __index = function(self, k)
        local v = stub(tostring(rawget(self, "__stub")) .. "." .. tostring(k))
        rawset(self, k, v)
        return v
    end,
    __concat = function(a, b) return tostring(a) .. tostring(b) end,
    __tostring = function(self) return "<" .. tostring(rawget(self, "__stub")) .. ">" end,
}
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__unm", "__mod", "__pow" }) do
    stubMeta[op] = function() return 0 end
end

local env = {}
setmetatable(env, { __index = function(t, k)
    local g = _G[k]
    if g ~= nil and k ~= "arg" then return g end
    local s = stub(k)
    rawset(t, k, s)
    return s
end })

function env.SelfAutoTable(t, metafunc)
    return setmetatable(t or {}, { __index = metafunc or function(tt, key)
        if type(key) == "string" then local v = env.SelfAutoTable(); rawset(tt, key, v); return v end
    end })
end
env.createHeader = function(t) return { __header = type(t) == "table" and t.readable or true } end
env.createPhase = function(t) return type(t) == "table" and (t.phaseID or t.id) or 0 end
env.print = function() end

local function node(kind) return function(id, t, ...) return { __k = kind, id = id, t = t, extra = { ... } } end end
env.q = node("q")
env.n = node("n")
env.m = node("m")
env.npc = node("n")
env.hqt = node("hqt")
env.root = function(...) env.__roots[#env.__roots + 1] = { ... } end
-- WoW Forever files: maproot(parentMapID, mapID, { ... }) is a root holding one map.
env.maproot = function(_, mapID, t) env.__roots[#env.__roots + 1] = { env.m(mapID, t) } end

local function run(path)
    local h = io.open(path, "rb")
    if not h then io.stderr:write("missing " .. path .. "\n"); return false end
    local text = h:read("*a"); h:close()
    local f, err = loadstring(preprocess(text), "@" .. path)
    if not f then io.stderr:write("skip " .. path .. ": " .. tostring(err) .. "\n"); return false end
    setfenv(f, env)
    local ok, e = pcall(f)
    if not ok then io.stderr:write("error " .. path .. ": " .. tostring(e) .. "\n") end
    return ok
end

local CONSTANTS = { "constants/raceIDs.lua", "constants/classIDs.lua", "constants/factionIDs.lua",
    "constants/expansionIDs.lua", "constants/lvl.lua", "lib/Constants/Maps.lua", "lib/Constants/Timelines.lua",
    "lib/Constants/Phases.lua", "lib/Headers/Common/Quests.lua" }
for _, rel in ipairs(CONSTANTS) do run(shared .. "/" .. rel) end
if FLAVOR == "forever" then
    -- WoW Forever's own constants (its map IDs and TIMELINE table) sit next to the shared folder.
    for _, rel in ipairs({ "maps.lua", "races.lua", "timelines.lua" }) do
        run(shared .. "/../forever/.config/constants/" .. rel)
    end
end

local function num(v) return type(v) == "number" and v or nil end
local function list(v)
    local out = {}
    if type(v) == "number" then return tostring(v) end
    if type(v) ~= "table" then return "" end
    for _, x in ipairs(v) do if type(x) == "number" then out[#out + 1] = tostring(x) end end
    return table.concat(out, ",")
end
local function fmt(x) return x and string.format("%.1f", x) or "" end

local current
local function coordsOf(t)
    local out = {}
    if type(t.coord) == "table" then out[#out + 1] = t.coord end
    if type(t.coords) == "table" then for _, c in ipairs(t.coords) do if type(c) == "table" then out[#out + 1] = c end end end
    return out
end

local function emitQuest(id, t)
    local sources = t.sourceQuests
    if num(t.sourceQuest) then sources = { t.sourceQuest } end
    local npcs = {}
    if type(t.provider) == "table" and t.provider[1] == "n" then npcs[#npcs + 1] = num(t.provider[2]) end
    if type(t.providers) == "table" then
        for _, p in ipairs(t.providers) do if type(p) == "table" and p[1] == "n" then npcs[#npcs + 1] = num(p[2]) end end
    end
    if num(t.qg) then npcs[#npcs + 1] = t.qg end
    if type(t.qgs) == "table" then for _, x in ipairs(t.qgs) do npcs[#npcs + 1] = num(x) end end
    local flags = {}
    for _, f in ipairs({ "isDaily", "isWeekly", "isBreadcrumb", "repeatable", "isWorldQuest", "isMonthly", "isYearly" }) do
        if t[f] then flags[#flags + 1] = f end
    end
    local lvl = t.lvl
    if type(lvl) == "table" then lvl = lvl[1] end
    local tl = {}
    if type(t.timeline) == "table" then for _, e in ipairs(t.timeline) do if type(e) == "string" then tl[#tl + 1] = e end end end
    local cs = coordsOf(t)
    if #cs == 0 then cs = { {} } end
    for _, c in ipairs(cs) do
        local map = num(c[3]) or current.map
        io.write(table.concat({ "Q", id, map or "", fmt(num(c[1])), fmt(num(c[2])), list(npcs), list(sources),
            num(t.sourceQuestNumRequired) or "", list(t.races), list(t.classes), num(lvl) or "",
            table.concat(flags, ","), table.concat(tl, ";"), tostring(num(t.u) or ""), current.file }, "|"), "\n")
    end
end

local walk
local function walkChildren(t)
    if type(t) ~= "table" or getmetatable(t) == stubMeta then return end
    for k, v in pairs(t) do
        if type(v) == "table" and k ~= "coord" and k ~= "coords" and k ~= "timeline" then walk(v) end
    end
end
walk = function(t)
    if type(t) ~= "table" or getmetatable(t) == stubMeta then return end
    local kind = rawget(t, "__k")
    if kind == "m" then
        local saved = current.map
        if num(t.id) then current.map = t.id end
        walkChildren(t.t)
        for _, e in ipairs(t.extra) do walk(e) end
        current.map = saved
        return
    elseif kind == "q" then
        if num(t.id) and type(t.t) == "table" then emitQuest(t.id, t.t) end
        if type(t.t) == "table" then walkChildren(t.t) end
        return
    elseif kind == "n" then
        if num(t.id) and t.id > 0 and type(t.t) == "table" then
            for _, c in ipairs(coordsOf(t.t)) do
                local map = num(c[3]) or current.map
                io.write(table.concat({ "N", t.id, map or "", fmt(num(c[1])), fmt(num(c[2])), current.file }, "|"), "\n")
            end
        end
        walkChildren(t.t)
        return
    elseif kind == "hqt" then
        return
    end
    walkChildren(t)
end

for i = 3, #arg do
    env.__roots = {}
    current = { file = arg[i]:match("standard/(.*)$") or arg[i]:match("forever/(.*)$") or arg[i], map = nil }
    if run(arg[i]) then
        for _, r in ipairs(env.__roots) do for _, x in ipairs(r) do walk(x) end end
    end
end
