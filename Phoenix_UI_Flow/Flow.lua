local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Flow (PUI_V2 5.14): small automations, every one off by default. The module
-- registers only the events its enabled toggles need, so a toggle that is off
-- costs nothing. Nothing here runs a protected action in combat, and nothing
-- reads a secret value: invite and resurrect checks bail out when the game
-- hides the name or GUID. A held Shift always skips an automation that would
-- otherwise act on a window (gossip, cinematics, quests, quick loot).
local _, ns = ...
local Schema, Secret, Slash = PUI.Schema, PUI.Secret, PUI.Slash
local OWNER = "Flow"

local FL = { active = false, settings = {}, hooked = {}, saved = {} }
ns.Flow = FL
PUI.Flow = FL
local s = FL.settings

local function plain(v) return type(v) ~= "nil" and not Secret.IsSecret(v) end
local function skip() return IsShiftKeyDown() end
FL.log = {}
local function did(what) FL.log[#FL.log + 1] = what; if #FL.log > 50 then table.remove(FL.log, 1) end end

-- Actions -------------------------------------------------------------------
local A = {}
FL.actions = A

function A.repair()
  if s.repair == "off" or not CanMerchantRepair() then return end
  local cost, can = GetRepairAllCost()
  if not can or not cost or cost <= 0 then return end
  if s.repair == "guild" and CanGuildBankRepair() then RepairAllItems(true) else RepairAllItems() end
  did("repair")
end

function A.sellJunk()
  if not s.sellJunk then return end
  local n = C_MerchantFrame.GetNumJunkItems()
  if n and n > 0 then C_MerchantFrame.SellAllJunkItems(); did("sellJunk") end
end

function FL.InPvPInstance() return C_PvP.IsBattleground() or C_PvP.IsArena() end

function A.release()
  if s.release == "off" then return end
  if FL.InPvPInstance() then return end
  if s.release == "world" and IsInInstance() then return end
  local opts = C_DeathInfo.GetSelfResurrectOptions()
  if opts and #opts > 0 then return end
  RepopMe()
  did("release")
end

function A.acceptRes()
  if not s.acceptRes or InCombatLockdown() then return end
  AcceptResurrect()
  StaticPopup_Hide("RESURRECT")
  StaticPopup_Hide("RESURRECT_NO_SICKNESS")
  StaticPopup_Hide("RESURRECT_NO_TIMER")
  did("acceptRes")
end

function A.declineDuel()
  if not s.declineDuels then return end
  CancelDuel()
  StaticPopup_Hide("DUEL_REQUESTED")
  did("declineDuel")
end

function A.declineGuild()
  if not s.declineGuild then return end
  DeclineGuild()
  did("declineGuild")
end

function FL.IsTrusted(guid)
  if not plain(guid) or guid == "" then return false end
  if C_FriendList.IsFriend(guid) or IsGuildMember(guid) then return true end
  return C_BattleNet.GetAccountInfoByGUID(guid) ~= nil
end

function A.invite(_, _, _, _, _, _, inviterGUID)
  if not s.acceptInvites or not FL.IsTrusted(inviterGUID) then return end
  AcceptGroup()
  StaticPopup_Hide("PARTY_INVITE")
  did("acceptInvite")
end

function A.cinematic()
  if not s.skipCinematics or skip() then return end
  CinematicFrame_CancelCinematic()
  did("skipCinematic")
end

function A.movie()
  if not s.skipCinematics or skip() then return end
  if MovieFrame:IsShown() then MovieFrame:StopMovie() end
  did("skipMovie")
end

function A.delete()
  if not s.autoDelete then return end
  local dialog = StaticPopup_FindVisible("DELETE_GOOD_ITEM") or StaticPopup_FindVisible("DELETE_GOOD_QUEST_ITEM")
  local box = dialog and dialog.GetEditBox and dialog:GetEditBox()
  if box then box:SetText(DELETE_ITEM_CONFIRM_STRING); did("autoDelete") end
end

function A.gossip()
  if not s.autoGossip or skip() then return end
  if C_GossipInfo.GetNumAvailableQuests() > 0 or C_GossipInfo.GetNumActiveQuests() > 0 then return end
  local options = C_GossipInfo.GetOptions()
  if type(options) == "table" and #options == 1 and options[1].gossipOptionID then
    C_GossipInfo.SelectOption(options[1].gossipOptionID)
    did("gossip")
  end
end

function A.loot()
  if not s.quickLoot or skip() then return end
  for i = GetNumLootItems(), 1, -1 do LootSlot(i) end
  did("quickLoot")
end

local warned = false
function FL.LowestDurability()
  local low
  for slot = 1, 18 do
    local cur, max = GetInventoryItemDurability(slot)
    if cur and max and max > 0 then
      local pct = cur / max
      if not low or pct < low then low = pct end
    end
  end
  return low
end
function A.durability()
  if not s.durabilityWarn then return end
  local low = FL.LowestDurability()
  if low and low <= s.durabilityThreshold / 100 then
    if not warned then
      warned = true
      Slash.Print(string.format("Durability low: %d%%", math.floor(low * 100)))
      PlaySound(SOUNDKIT.RAID_WARNING)
      did("durabilityWarn")
    end
  else
    warned = false
  end
end

function A.combatLog()
  if not s.combatLog then return end
  local _, kind, difficulty = GetInstanceInfo()
  local want = kind == "raid" or difficulty == 8
  if want ~= LoggingCombat() then LoggingCombat(want); did("combatLog") end
end

-- Hook-driven toggles ------------------------------------------------------
function FL.OnTalkingHead()
  if FL.active and s.hideTalkingHead then TalkingHeadFrame:CloseImmediately(); did("talkingHead") end
end
function FL.OnError()
  if FL.active and s.hideErrors and InCombatLockdown() then UIErrorsFrame:Clear() end
end
local function hookOnce(key, fn)
  if FL.hooked[key] then return end
  FL.hooked[key] = true
  fn()
end

-- Toggle -> events ---------------------------------------------------------
local EVENTS = {
  repair = { MERCHANT_SHOW = A.repair },
  sellJunk = { MERCHANT_SHOW = A.sellJunk },
  release = { PLAYER_DEAD = A.release },
  acceptRes = { RESURRECT_REQUEST = A.acceptRes },
  declineDuels = { DUEL_REQUESTED = A.declineDuel },
  declineGuild = { GUILD_INVITE_REQUEST = A.declineGuild },
  acceptInvites = { PARTY_INVITE_REQUEST = A.invite },
  skipCinematics = { CINEMATIC_START = A.cinematic, PLAY_MOVIE = A.movie },
  autoDelete = { DELETE_ITEM_CONFIRM = A.delete },
  autoGossip = { GOSSIP_SHOW = A.gossip },
  quickLoot = { LOOT_READY = A.loot },
  durabilityWarn = { UPDATE_INVENTORY_DURABILITY = A.durability },
  combatLog = { ZONE_CHANGED_NEW_AREA = A.combatLog, PLAYER_ENTERING_WORLD = A.combatLog },
}
FL.EVENTS = EVENTS

local function isOn(name)
  local v = s[name]
  return v == true or (type(v) == "string" and v ~= "off")
end

-- Re-registers exactly the events the enabled toggles need.
function FL.Sync()
  local mod = FL.module
  if not (FL.active and mod and mod.enabled) then return end
  local wanted = {}
  for name, map in pairs(EVENTS) do
    if isOn(name) then
      for event, fn in pairs(map) do
        wanted[event] = wanted[event] or {}
        table.insert(wanted[event], fn)
      end
    end
  end
  mod.frame:UnregisterAllEvents()
  wipe(mod.handlers)
  for event, list in pairs(wanted) do
    mod:RegisterEvent(event, function(_, _, ...) for i = 1, #list do list[i](...) end end)
  end
  FL.wanted = wanted
  if s.hideTalkingHead then hookOnce("talkingHead", function() hooksecurefunc(TalkingHeadFrame, "PlayCurrent", FL.OnTalkingHead) end) end
  if s.hideErrors then hookOnce("errors", function() hooksecurefunc(UIErrorsFrame, "AddMessage", FL.OnError) end) end
end

-- CVars: saved on first change, restored when the toggle or module goes off.
local CVARS = { maxCamera = { name = "cameraDistanceMaxZoomFactor", on = "2.6" } }
FL.CVARS = CVARS
function FL.ApplyCVars()
  for key, c in pairs(CVARS) do
    if FL.active and s[key] then
      if FL.saved[c.name] == nil then FL.saved[c.name] = C_CVar.GetCVar(c.name) end
      C_CVar.SetCVar(c.name, c.on)
    elseif FL.saved[c.name] ~= nil then
      C_CVar.SetCVar(c.name, FL.saved[c.name])
      FL.saved[c.name] = nil
    end
  end
end

-- Slash shortcuts (Phoenix slash: /pui rl, /pui cd N).
Slash:Register("rl", function() if FL.active and s.reloadSlash then ReloadUI() end end, "reload the UI (Flow)")
Slash:Register("cd", function(rest)
  if not (FL.active and s.countdown) then return end
  local n = tonumber(rest) or 10
  C_PartyInfo.DoCountdown(math.max(1, math.min(30, n)))
end, "start a pull countdown (Flow)")

local schema = {}
FL.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(value) s[name] = value; FL.Sync(); FL.ApplyCVars() end
  schema["flow." .. name] = def
end
local function toggle(name, label, tooltip) key(name, { type = "toggle", default = false, label = label, tooltip = tooltip }) end
key("repair", { type = "select", default = "off", choices = { "off", "player", "guild" }, label = "Auto repair",
  tooltip = "Repairs everything at a vendor. Guild uses guild funds when allowed, else your own gold.", mode = "simple" })
toggle("sellJunk", "Auto sell junk", "Sells grey items when you open a vendor.")
key("release", { type = "select", default = "off", choices = { "off", "world", "instances" }, label = "Auto release",
  tooltip = "Releases your spirit on death. World only, or also in dungeons and raids; never in battlegrounds or arenas, and never when you can self-resurrect." })
toggle("acceptRes", "Auto accept resurrection", "Accepts a resurrection out of combat.")
toggle("declineDuels", "Auto decline duels", "Declines duel requests.")
toggle("declineGuild", "Auto decline guild invites", "Declines guild invitations.")
toggle("acceptInvites", "Accept invites from friends", "Accepts group invites from friends, Battle.net friends and guild members.")
toggle("skipCinematics", "Skip cinematics", "Skips cinematics and movies. Hold Shift to watch.")
toggle("autoDelete", "Fill DELETE", "Types the confirmation word when deleting a good item.")
toggle("autoGossip", "Auto gossip", "Picks the only dialogue option when there is no quest. Hold Shift to read.")
toggle("quickLoot", "Quick loot", "Takes every item as soon as the loot window opens. Hold Shift to choose.")
toggle("durabilityWarn", "Low durability warning", "Warns once when any item drops to the threshold.")
key("durabilityThreshold", { type = "range", default = 20, min = 5, max = 50, step = 5, label = "Durability threshold (%)",
  tooltip = "Warning level for the low durability warning." })
toggle("hideTalkingHead", "Hide talking head", "Closes the talking head popup as it opens.")
toggle("hideErrors", "Hide errors in combat", "Clears red error text (out of range, not ready) during combat.")
toggle("combatLog", "Combat log in raids and M+", "Turns /combatlog on in raids and Mythic+ and off elsewhere.")
toggle("maxCamera", "Max camera distance", "Raises the camera zoom limit; restored when turned off.")
toggle("reloadSlash", "/pui rl", "Enables /pui rl to reload the UI.")
toggle("countdown", "/pui cd", "Enables /pui cd <seconds> for a pull countdown.")

FL.module = PUI:RegisterModule(OWNER, {
  label = "Flow", tooltip = "Automations: repair, junk, release, invites, cinematics, quick loot and more. Each one off until you turn it on.",
  enabledByDefault = false, schema = schema,
  onEnable = function() FL.active = true; FL.Sync(); FL.ApplyCVars() end,
  onDisable = function() FL.active = false; FL.ApplyCVars() end,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
