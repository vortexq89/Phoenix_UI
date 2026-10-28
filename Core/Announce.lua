local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Announce (plan 1.O "Announcements"): the one announcement router. Every
-- module that wants to say something in chat (quest progress, keystones,
-- instance resets, interrupts, meter reports, loadout warnings, goodbyes)
-- calls Announce:Send(topic, text) and chooses nothing else; where it goes,
-- whether it goes at all and in which content is decided here, on the QoL
-- page. Off at first install; the default channel is "self" (a local line
-- only you see). Restriction-aware: during chat lockdown, or when the text is
-- a secret value, the line is shown to you only and never sent.
--   Announce:Send(topic, text) -> "sent" | "self" | "off" | "throttled"
--   Announce:Route(topic, content) -> channel or nil   (pure, tested)
local Announce = { last = {}, log = {} }
PUI.Announce = Announce
local Schema, Secret = PUI.Schema, PUI.Secret
local OWNER = "QoL"

Announce.TOPICS = {
  { id = "quest", label = "Quest progress" },
  { id = "keystone", label = "Keystones (!keys, new key)" },
  { id = "reset", label = "Instance reset and difficulty" },
  { id = "interrupt", label = "Interrupts and utility spells" },
  { id = "meter", label = "Damage meter reports" },
  { id = "loadout", label = "Loadout mismatch" },
  { id = "goodbye", label = "Goodbye after a run" },
  { id = "raid", label = "Raid tools (breaks) and encounter stats" },
}
Announce.CHANNELS = { "self", "auto", "PARTY", "RAID", "INSTANCE_CHAT", "SAY", "YELL", "GUILD" }
Announce.CHANNEL_LABELS = { self = "Only me (local line)", auto = "Group (party, raid or instance)", PARTY = "Party", RAID = "Raid",
  INSTANCE_CHAT = "Instance", SAY = "Say", YELL = "Yell", GUILD = "Guild" }
Announce.THROTTLE = 5

local function contentColumns()
  local P = PUI.Profiles
  local out = {}
  for i, c in ipairs(P.CONTENT) do out[i] = { id = c, label = P.CONTENT_LABEL[c] } end
  return out
end
local function emptyGrid()
  local g = {}
  for _, t in ipairs(Announce.TOPICS) do
    g[t.id] = {}
    for _, c in ipairs(PUI.Profiles.CONTENT) do g[t.id][c] = false end
  end
  return g
end

local s = { enabled = false, channel = "self", where = emptyGrid(), throttle = true, prefix = true }
Announce.settings = s

-- "auto" resolves to the group channel that fits; nil means nobody to tell.
function Announce.GroupChannel()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) then return "INSTANCE_CHAT" end
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
  return nil
end

function Announce:Route(topic, content)
  if not s.enabled then return nil end
  local row = s.where[topic]
  if not (row and row[content]) then return nil end
  if s.channel == "auto" then return self.GroupChannel() or "self" end
  return s.channel
end

local function say(text)
  local line = (s.prefix and "|cffe8a33dPhoenix|r " or "") .. text
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) end
  Announce.log[#Announce.log + 1] = line
  if #Announce.log > 50 then table.remove(Announce.log, 1) end
end
Announce.Say = say

function Announce:Send(topic, text, content)
  if Secret.IsSecret(text) or type(text) ~= "string" or text == "" then return "off" end
  local channel = self:Route(topic, content or PUI.Profiles:Content())
  if not channel then return "off" end
  local now = GetTime()
  if s.throttle and self.last[text] and now - self.last[text] < self.THROTTLE then return "throttled" end
  self.last[text] = now
  local locked = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
  if channel == "self" or locked then say(text); return "self" end
  C_ChatInfo.SendChatMessage(text, channel)
  return "sent"
end

local schema = {}
Announce.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(v) s[name] = v end
  schema["announce." .. name] = def
  Schema:Register("announce." .. name, def)
end
key("enabled", { type = "toggle", default = false, label = "Announcements",
  tooltip = "One switch for every chat announcement Phoenix modules can make. Modules only pick what to say; where it goes is set here.",
  mode = "simple", searchTags = { "announce", "chat", "router", "quest", "keys", "interrupt", "report" } })
key("channel", { type = "select", default = "self", choices = Announce.CHANNELS, choiceLabels = Announce.CHANNEL_LABELS,
  label = "Announce to", tooltip = "Where announcements go. Only me prints a local line nobody else sees; Group picks party, raid or instance for you.",
  mode = "simple" })
key("where", { type = "grid", default = emptyGrid(), rows = Announce.TOPICS, columns = contentColumns,
  label = "What to announce, by content", tooltip = "Tick a topic for the content types where it may be announced. Everything starts unticked.",
  mode = "simple", searchTags = { "announce", "content", "per content" } })
key("throttle", { type = "toggle", default = true, label = "Skip repeats",
  tooltip = "Does not repeat the exact same announcement within 5 seconds.", mode = "advanced" })
key("prefix", { type = "toggle", default = true, label = "Phoenix tag on local lines",
  tooltip = "Starts lines that only you see with a Phoenix tag so you can tell them apart.", mode = "advanced" })
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
PUI.Kernel:On("DB_READY", function() for k, def in pairs(schema) do def.apply(Schema:Get(k)) end end)

-- Step 8b settings carry-over (never resets a choice): chat.abbreviate ->
-- chat.channelNames, vault.mode -> vault.view (grid/compact kept as chosen);
-- chat.fade (old per-line fade) has no new meaning and is dropped.
PUI.DB:RegisterMigration("0008b_chat_vault_keys", function(sv)
  for _, p in pairs(sv.profiles or {}) do
    if type(p) == "table" then
      if p["chat.abbreviate"] ~= nil then
        if p["chat.channelNames"] == nil then p["chat.channelNames"] = p["chat.abbreviate"] and "short" or "full" end
        p["chat.abbreviate"] = nil
      end
      if p["vault.mode"] ~= nil then
        if p["vault.view"] == nil and (p["vault.mode"] == "grid" or p["vault.mode"] == "compact") then p["vault.view"] = p["vault.mode"] end
        p["vault.mode"] = nil
      end
      p["chat.fade"] = nil
    end
  end
  return true
end)
