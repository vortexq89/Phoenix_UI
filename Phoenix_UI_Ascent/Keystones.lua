local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Ascent Keystones (1.O owner: keystone data, /keys, insert, auto-slot). Flow
-- and Group Finder link here; Vault's keystone shelf is only a bag category.
--   Keys.Own()        -> { mapID, level } | nil
--   Keys.Scan()       stores your key under your character (alts list)
--   Keys.List()       -> your key, alts' keys, group members' shared keys
--   Keys.FindInBags() -> bag, slot of your keystone
--   Keys.Slot()       inserts it into the open font of power (out of combat)
-- Group keys come from Phoenix users in your group over a hidden addon channel
-- (never in combat or chat lockdown). "!keys" in party chat is answered through
-- the announcement router (Keystones topic), so nothing is sent unless you allow it.
local _, ns = ...
local AS, Schema, CQ, Secret = ns.AS, PUI.Schema, PUI.CombatQueue, PUI.Secret
local OWNER = AS.OWNER
local Keys = { group = {} }
ns.Keys = Keys
AS.Keys = Keys
local s = AS.settings
Keys.PREFIX = "PUIKEYS"

function Keys.Own()
  local mapID, level = C_MythicPlus.GetOwnedKeystoneChallengeMapID(), C_MythicPlus.GetOwnedKeystoneLevel()
  if not mapID or not level or level <= 0 then return nil end
  return { mapID = mapID, level = level }
end

function Keys.Name(mapID)
  local d = PUI.Season and PUI.Season:Dungeon(mapID)
  return (d and d.name) or (C_ChallengeMode.GetMapUIInfo(mapID)) or ("Dungeon " .. tostring(mapID))
end

function Keys.Text(k) return k and string.format("%s +%d", Keys.Name(k.mapID), k.level) or "no key" end

-- Remembers this character's key (alts list); announces a new key once.
function Keys.Scan()
  if InCombatLockdown() then return end
  local all = Schema:Get("ascent.keys")
  local me = PUI.DB:CharKey()
  local own = Keys.Own()
  local old = all[me]
  local changed = (own and (not old or old.mapID ~= own.mapID or old.level ~= own.level)) or (not own and old ~= nil)
  if not changed then return false end
  if own then
    local _, class = UnitClass("player")
    all[me] = { mapID = own.mapID, level = own.level, class = class, at = time() }
    if old then PUI.Announce:Send("keystone", "New key: " .. Keys.Text(own)) end
  else
    all[me] = nil
  end
  Schema:Set("ascent.keys", all)
  Keys.Share()
  return true
end

-- Your key, your alts' keys (highest first), then group members' shared keys.
function Keys.List()
  local out = {}
  local me = PUI.DB:CharKey()
  local own = Keys.Own()
  if own then out[#out + 1] = { who = me, key = own, kind = "me" } end
  local alts = {}
  for char, k in pairs(Schema:Get("ascent.keys")) do
    if char ~= me then alts[#alts + 1] = { who = char, key = k, kind = "alt", class = k.class } end
  end
  table.sort(alts, function(a, b) if a.key.level ~= b.key.level then return a.key.level > b.key.level end return a.who < b.who end)
  for _, a in ipairs(alts) do out[#out + 1] = a end
  local group = {}
  for who, k in pairs(Keys.group) do group[#group + 1] = { who = who, key = k, kind = "group" } end
  table.sort(group, function(a, b) return a.who < b.who end)
  for _, g in ipairs(group) do out[#out + 1] = g end
  return out
end

function Keys.Print()
  local out = PUI.Slash.Print
  local list = Keys.List()
  if #list == 0 then return out("keys: none known yet (alts are remembered when you log in on them)") end
  local label = { me = "you", alt = "alt", group = "group" }
  for _, e in ipairs(list) do out(string.format("%s (%s): %s", e.who, label[e.kind], Keys.Text(e.key))) end
end

-- Group sharing over a hidden addon channel (Phoenix users only).
function Keys.CanTalk()
  if InCombatLockdown() or not IsInGroup() then return false end
  if C_ChatInfo.InChatMessagingLockdown() then return false end
  return true
end

function Keys.Share()
  if not (AS.active and s.keysShare and Keys.CanTalk()) then return false end
  local own = Keys.Own()
  local msg = own and string.format("K:%d:%d", own.mapID, own.level) or "K:0:0"
  C_ChatInfo.SendAddonMessage(Keys.PREFIX, msg, IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY"))
  return true
end

function Keys.OnAddonMessage(_, _, prefix, msg, _, sender)
  if prefix ~= Keys.PREFIX or Secret.IsSecret(msg) or Secret.IsSecret(sender) or type(msg) ~= "string" then return end
  local mapID, level = msg:match("^K:(%d+):(%d+)$")
  mapID, level = tonumber(mapID), tonumber(level)
  if not mapID then return end
  local name = (sender or ""):match("^([^%-]+)") or sender
  if name == UnitName("player") then return end
  Keys.group[name] = (mapID > 0 and level > 0) and { mapID = mapID, level = level } or nil
end

-- "!keys" in party chat: your key goes out through the router (Keystones topic).
function Keys.OnPartyChat(_, _, msg)
  if not s.keysReply or Secret.IsSecret(msg) or type(msg) ~= "string" then return end
  if msg:lower():match("^%s*!keys%s*$") then
    local own = Keys.Own()
    if own then return PUI.Announce:Send("keystone", "My key: " .. Keys.Text(own)) end
  end
end

-- Keystone insert / auto-slot ---------------------------------------------------
function Keys.FindInBags()
  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local id = C_Container.GetContainerItemID(bag, slot)
      if id and C_Item.IsItemKeystoneByID(id) then return bag, slot end
    end
  end
end

function Keys.Slot()
  if not s.autoSlot then return false, "off" end
  if C_ChallengeMode.HasSlottedKeystone() then return false, "already slotted" end
  local bag, slot = Keys.FindInBags()
  if not bag then return false, "no keystone in your bags" end
  CQ.Defer("ascent.slot", function()
    C_Container.PickupContainerItem(bag, slot)
    C_ChallengeMode.SlotKeystone()
    if GetCursorInfo() then ClearCursor() end
  end)
  return true
end

function Keys.Enable(mod)
  C_ChatInfo.RegisterAddonMessagePrefix(Keys.PREFIX)
  mod:RegisterEvent("CHAT_MSG_ADDON", Keys.OnAddonMessage)
  mod:RegisterEvent("CHAT_MSG_PARTY", Keys.OnPartyChat)
  mod:RegisterEvent("CHAT_MSG_PARTY_LEADER", Keys.OnPartyChat)
  mod:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN", function() Keys.Slot() end)
  mod:RegisterEvent("BAG_UPDATE_DELAYED", function() Keys.Scan() end)
  mod:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    if not IsInGroup() then wipe(Keys.group) end
    Keys.Share()
  end)
  Keys.Scan()
end

function Keys.Disable() wipe(Keys.group) end

PUI.Slash:Register("keys", function() Keys.Print() end, "list your keystone, your alts' keys and your group's keys")
-- /keys alias (setting "/keys command"); /pui keys always works.
SLASH_PHOENIXUIKEYS1 = "/keys"
SlashCmdList.PHOENIXUIKEYS = function()
  if not s.keysCommand then return PUI.Slash.Print("/keys is turned off in Ascent settings; /pui keys still works") end
  Keys.Print()
end
