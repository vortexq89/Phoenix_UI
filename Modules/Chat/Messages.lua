local _, ns = ...
local Secret, Skin = ns.Secret, ns.Skin

--[[ Chat messages: everything that changes a line goes through one message event filter (Blizzard's registry
    only calls it when every argument is readable, so restricted Midnight chat passes untouched) and one
    sender name filter (role icons). Both return the game's own values when a setting is off.
    The pure helpers below are shared with the options preview and the smoke tests. ]]
local M = ns:GetModule("Chat")

M.EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
    "CHAT_MSG_LOOT",
}
-- Public chat where a repeat flood happens; group, guild and whispers are never throttled.
local THROTTLED = { CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_CHANNEL = true, CHAT_MSG_EMOTE = true }
local PATTERNS = {
    "(%a[%w+.-]+://[^%s|]+)",            -- scheme://…
    "(www%.[%w_-]+%.[^%s|]+)",           -- www.example.com/…
    "([%w_.-]+%.%a%a+/[^%s|]*)",          -- example.com/path
}
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }

---------------------------------------------------------------- pure helpers
-- "2. Trade - City" -> "2"; anything without a channel number stays as it is.
function M.ShortChannel(name)
    if type(name) ~= "string" then return name end
    return name:match("^(%d+)%.") or name
end

-- Runs fn on the plain text between hyperlinks and keeps every |H…|h…|h link intact.
function M.OutsideLinks(msg, fn)
    local out, pos = {}, 1
    while true do
        local s, e = msg:find("|H.-|h.-|h", pos)
        if not s then out[#out + 1] = fn(msg:sub(pos)); break end
        out[#out + 1] = fn(msg:sub(pos, s - 1))
        out[#out + 1] = msg:sub(s, e)
        pos = e + 1
    end
    return table.concat(out)
end

-- A case-insensitive whole-word Lua pattern for a keyword (ASCII letters fold; others match as typed).
function M.WordPattern(word)
    local p = word:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%a", function(c)
        return "[" .. c:lower() .. c:upper() .. "]"
    end)
    return "%f[%w_]" .. p .. "%f[^%w_]"
end

-- "Raid, Tank ,  boss" -> { "Raid", "Tank", "boss" } (two letters at least, duplicates dropped).
function M.ParseKeywords(text, extra)
    local out, seen = {}, {}
    local function add(w)
        w = w and w:gsub("^%s+", ""):gsub("%s+$", "")
        if w and #w >= 2 and not seen[w:lower()] then seen[w:lower()] = true; out[#out + 1] = w end
    end
    for word in tostring(text or ""):gmatch("[^,;]+") do add(word) end
    if extra then add(extra) end
    return out
end

-- msg with every keyword (outside links) wrapped in hex colour; returns the text and whether one matched.
function M.Highlight(msg, words, hex)
    if #words == 0 then return msg, false end
    local hit = false
    local out = M.OutsideLinks(msg, function(part)
        for _, w in ipairs(words) do
            local n
            part, n = part:gsub(M.WordPattern(w), function(found) return "|cff" .. hex .. found .. "|r" end)
            if n > 0 then hit = true end
        end
        return part
    end)
    return out, hit
end

-- URLs become clickable links (never inside messages that already carry links).
function M.URLs(msg, linkify)
    if msg:find("|H", 1, true) then return msg, false end
    for _, p in ipairs(PATTERNS) do
        local out, c = msg:gsub(p, linkify)
        if c > 0 then return out, true end
    end
    return msg, false
end

-- Item links get their item level ("[Name (684)]") and links an icon in front; info(kind, id, link) answers
-- { level = n } / { icon = fileID } from the game (nil while an item is not cached yet).
function M.DecorateLinks(msg, levels, icons, info)
    if not (levels or icons) then return msg end
    return (msg:gsub("(|H(%a+):([^|]*)|h%[(.-)%]|h)", function(whole, kind, data, name)
        local id = tonumber(data:match("^(%-?%d+)"))
        local d = id and info(kind, id, whole)
        if not d then return nil end
        local text = whole
        if levels and kind == "item" and d.level then
            text = ("|H%s:%s|h[%s (%d)]|h"):format(kind, data, name, d.level)
        end
        if icons and d.icon then text = ("|T%s:0|t"):format(tostring(d.icon)) .. text end
        return text
    end))
end

-- Spam throttle: the same text from the same sender within `window` seconds is dropped. The filter runs once
-- per chat window for each line, so a repeat is only a repeat when its line ID differs.
function M.NewThrottle()
    local seen, added = {}, 0
    return function(key, lineID, now, window)
        local last = seen[key]
        if last and last.line ~= lineID and now - last.time < window then return true end
        if not last or last.line ~= lineID then
            seen[key] = { line = lineID, time = now }
            added = added + 1
            if added > 200 then -- forget lines older than the longest window the page offers
                added = 0
                for k, v in pairs(seen) do if now - v.time > 300 then seen[k] = nil end end
            end
        end
        return false
    end, seen
end

---------------------------------------------------------------- game data for links
local function linkInfo(kind, id, link)
    if kind == "item" then
        local _, _, _, equipLoc, icon, classID = C_Item.GetItemInfoInstant(id)
        local d = { icon = icon }
        local isGear = (classID == 2 or classID == 4) and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
        if isGear then
            local level = C_Item.GetDetailedItemLevelInfo(link)
            if type(level) == "number" and level > 1 then d.level = level end
        end
        return d
    elseif kind == "spell" then
        return { icon = C_Spell.GetSpellTexture(id) }
    elseif kind == "achievement" then
        return { icon = select(10, GetAchievementInfo(id)) }
    end
end
M.LinkInfo = linkInfo

---------------------------------------------------------------- the filter
local throttle = M.NewThrottle()
local words, keywordHex = {}, "ffd100"
local soundLine -- the last line a keyword sound played for (each window filters every line)

local function linkify(url) return M:Linkify(url) end

local function filter(_, event, msg, author, arg3, channel, ...)
    if not M:IsEnabled() or Secret.IsSecret(msg) or type(msg) ~= "string" then return false end
    local db = M.db
    local lineID = select(7, ...) -- arg11
    if db.throttle > 0 and THROTTLED[event] and type(author) == "string" and author ~= UnitName("player") then
        if throttle(author .. "\1" .. msg, lineID, GetTime(), db.throttle) then return true end
    end
    local out, changed = msg, false
    if db.itemLevels or db.linkIcons then
        local d = M.DecorateLinks(out, db.itemLevels, db.linkIcons, linkInfo)
        changed = changed or d ~= out
        out = d
    end
    if db.urls then
        local u, hit = M.URLs(out, linkify)
        if hit then out, changed = u, true end
    end
    if #words > 0 and event ~= "CHAT_MSG_LOOT" and author ~= UnitName("player") then
        local h, hit = M.Highlight(out, words, keywordHex)
        if hit then
            out, changed = h, true
            if db.keywordSound ~= "" and lineID ~= soundLine then
                soundLine = lineID
                ns.Media:PlaySound(db.keywordSound)
            end
        end
    end
    local short = channel
    if db.shortChannels and type(channel) == "string" then short = M.ShortChannel(channel) end
    if not changed and short == channel then return false end
    return false, out, author, arg3, short, ...
end
M.Filter = filter

-- Role icon in front of group members' names (the game's sender name filter; nil keeps the name as is).
local function senderFilter(_, name, ...)
    if not (M:IsEnabled() and M.db.roleIcons) or Secret.IsSecret(name) or type(name) ~= "string" then return nil end
    local guid = select(12, ...)
    if Secret.IsSecret(guid) or type(guid) ~= "string" or not IsInGroup() then return nil end
    local unit = UnitTokenFromGUID(guid)
    if Secret.IsSecret(unit) or not unit then return nil end
    local role = UnitGroupRolesAssigned(unit)
    if Secret.IsSecret(role) or not ROLE_ATLAS[role] then return nil end
    return CreateAtlasMarkup(ROLE_ATLAS[role], 12, 12) .. name
end
M.SenderFilter = senderFilter

local function onWhisper()
    if M:IsEnabled() and M.db.whisperSound ~= "" then ns.Media:PlaySound(M.db.whisperSound) end
end

function M:RefreshMessages()
    words = M.ParseKeywords(self.db.keywords, self.db.keywordOwnName and UnitName("player") or nil)
    keywordHex = ns.Util.Hex(Skin:SpecColor(self.db.keywordColor, "accent.primary"))
end

function M:EnableMessages()
    for _, event in ipairs(M.EVENTS) do ChatFrameUtil.AddMessageEventFilter(event, filter) end
    if ChatFrameUtil.AddSenderNameFilter then ChatFrameUtil.AddSenderNameFilter(senderFilter) end
    ns.Events:On("CHAT_MSG_WHISPER", self, onWhisper)
    ns.Events:On("CHAT_MSG_BN_WHISPER", self, onWhisper)
    self:RefreshMessages()
end

function M:DisableMessages()
    for _, event in ipairs(M.EVENTS) do ChatFrameUtil.RemoveMessageEventFilter(event, filter) end
    if ChatFrameUtil.RemoveSenderNameFilter then ChatFrameUtil.RemoveSenderNameFilter(senderFilter) end
end

---------------------------------------------------------------- the game's chat settings (CVars, shown on this page)
-- Timestamp formats: Blizzard's list (Settings > Social), labelled with an example time like the game does.
function M.TimestampValues()
    local out = { { value = "none", label = "CHAT_TIMESTAMP_NONE" } }
    local sample = time({ year = 2026, month = 10, day = 22, hour = 15, min = 27, sec = 32 })
    for _, fmt in ipairs({ TIMESTAMP_FORMAT_HHMM, TIMESTAMP_FORMAT_HHMMSS, TIMESTAMP_FORMAT_HHMM_AMPM,
        TIMESTAMP_FORMAT_HHMMSS_AMPM, TIMESTAMP_FORMAT_HHMM_24HR, TIMESTAMP_FORMAT_HHMMSS_24HR }) do
        if type(fmt) == "string" then out[#out + 1] = { value = fmt, label = date(fmt, sample) } end
    end
    return out
end
