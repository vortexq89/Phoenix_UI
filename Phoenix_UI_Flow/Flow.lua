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
  if PUI.Vault and PUI.Vault.OwnsJunk and PUI.Vault.OwnsJunk() then return end -- Vault owns junk while it is on (plan 1.O)
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

-- Auto combat logging (Flow owns it, plan 1.O): on in the content types you
-- tick, off elsewhere. Only turns off a log Flow itself turned on, so a log
-- you or a recorder addon started by hand keeps running.
function A.combatLog()
  if not s.combatLog then return end
  local content = PUI.Profiles:Content()
  local want = ((s.combatLogWhere or {}).log or {})[content] == true
  if want and not LoggingCombat() then LoggingCombat(true); FL.loggingByFlow = true; did("combatLog")
  elseif not want and FL.loggingByFlow and LoggingCombat() then LoggingCombat(false); FL.loggingByFlow = false; did("combatLogOff") end
end

-- Hook-driven toggles ------------------------------------------------------
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
  declineDuels = { DUEL_REQUESTED = A.declineDuel },
  declineGuild = { GUILD_INVITE_REQUEST = A.declineGuild },
  acceptInvites = { PARTY_INVITE_REQUEST = A.invite },
  autoDelete = { DELETE_ITEM_CONFIRM = A.delete },
  autoGossip = { GOSSIP_SHOW = A.gossip },
  quickLoot = { LOOT_READY = A.loot },
  durabilityWarn = { UPDATE_INVENTORY_DURABILITY = A.durability },
  combatLog = { ZONE_CHANGED_NEW_AREA = A.combatLog, PLAYER_ENTERING_WORLD = A.combatLog },
}
FL.EVENTS = EVENTS

local function isOn(name)
  if name == "quiet" then return FL.Quiet ~= nil and FL.Quiet.AnyCell() end
  local v = s[name]
  return v == true or (type(v) == "string" and v ~= "off")
end

-- Re-registers exactly the events the enabled toggles need.
function FL.Sync()
  local mod = FL.module
  if not (FL.active and mod and mod.enabled) then return end
  local wanted = {}
  if FL.Quiet then EVENTS.quiet = FL.Quiet.EVENTS end
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
  if FL.Quiet and FL.Quiet.AnyCell() then FL.Quiet.Hook() end
  if s.hideErrors then hookOnce("errors", function() hooksecurefunc(UIErrorsFrame, "AddMessage", FL.OnError) end) end
end

-- CVars: the original value is saved (in the profile, so it survives a
-- reload) on first change and restored when the toggle or module goes off.
local CVARS = { maxCamera = { name = "cameraDistanceMaxZoomFactor", on = "2.6" } }
FL.CVARS = CVARS
function FL.ApplyCVars()
  if not Schema:Def("flow.savedCVars") then return end
  local saved = Schema:Get("flow.savedCVars")
  local changed = false
  for key, c in pairs(CVARS) do
    if FL.active and s[key] then
      if saved[c.name] == nil then saved[c.name] = C_CVar.GetCVar(c.name) or ""; changed = true end
      C_CVar.SetCVar(c.name, c.on)
    elseif saved[c.name] ~= nil then
      C_CVar.SetCVar(c.name, saved[c.name])
      saved[c.name] = nil
      changed = true
    end
  end
  if changed then Schema:Set("flow.savedCVars", saved) end
  FL.saved = saved
end

-- Slash shortcuts (Phoenix slash: /pui rl, /pui cd N).
Slash:Register("rl", function() if FL.active and s.reloadSlash then ReloadUI() end end, "reload the UI (Flow)")
-- /pui cd and the pull, break and ready-check tools belong to Raid Tools (plan 1.O).

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
toggle("sellJunk", "Auto sell junk", "Sells grey items when you open a vendor. While Vault is on, Vault's own junk setting decides instead.")
key("release", { type = "select", default = "off", choices = { "off", "world", "instances" }, label = "Auto release",
  tooltip = "Releases your spirit on death. World only, or also in dungeons and raids; never in battlegrounds or arenas, and never when you can self-resurrect." })
toggle("declineDuels", "Auto decline duels", "Declines duel requests.")
toggle("declineGuild", "Auto decline guild invites", "Declines guild invitations.")
toggle("acceptInvites", "Accept invites from friends", "Accepts group invites from friends, Battle.net friends and guild members.")
toggle("autoDelete", "Fill DELETE", "Types the confirmation word when deleting a good item.")
toggle("autoGossip", "Auto gossip", "Picks the only dialogue option when there is no quest. Hold Shift to read.")
toggle("quickLoot", "Quick loot", "Takes every item as soon as the loot window opens. Hold Shift to choose.")
toggle("durabilityWarn", "Low durability warning", "Warns once when any item drops to the threshold.")
key("durabilityThreshold", { type = "range", default = 20, min = 5, max = 50, step = 5, label = "Durability threshold (%)",
  tooltip = "Warning level for the low durability warning." })
toggle("hideErrors", "Hide errors in combat", "Clears red error text (out of range, not ready) during combat.")
toggle("combatLog", "Auto combat logging", "Turns /combatlog on in the content types ticked below and off elsewhere (only a log Flow started). Raids and Mythic+ are ticked to start with.")
schema["flow.combatLogWhere"] = { type = "grid", default = { log = { raid = true, mythicplus = true, world = false, dungeon = false, arena = false, battleground = false, delve = false } },
  rows = { { id = "log", label = "Combat log" } }, columns = function()
    local out = {}
    for i, c in ipairs(PUI.Profiles.CONTENT) do out[i] = { id = c, label = PUI.Profiles.CONTENT_LABEL[c] } end
    return out
  end, owner = OWNER, mode = "advanced", label = "Combat log by content", tooltip = "Where auto combat logging turns the log on. Works alongside recorder addons: a log they started is never stopped.",
  searchTags = { "combat log", "logging", "warcraftlogs", "recorder" }, apply = function(v) s.combatLogWhere = v; FL.Sync(); if FL.active then A.combatLog() end end }
toggle("maxCamera", "Max camera distance", "Raises the camera zoom limit; restored when turned off.")
toggle("reloadSlash", "/pui rl", "Enables /pui rl to reload the UI.")
schema["flow.savedCVars"] = { type = "layout", default = {}, mode = "advanced", owner = OWNER, label = "Saved game settings",
  tooltip = "Original values of game settings Flow changed, restored when the switch is turned off.", apply = function() end }

-- Quiet mode (Quiet.lua) adds its keys first; it calls FL.Register().
function FL.Register()
FL.module = PUI:RegisterModule(OWNER, {
  label = "Flow", tooltip = "Automations: repair, junk, release, invites, cinematics, quick loot and more. Each one off until you turn it on.",
  enabledByDefault = false, schema = schema,
  onEnable = function() FL.active = true; FL.Sync(); FL.ApplyCVars(); if FL.Quiet then FL.Quiet.Recompute() end end,
  onDisable = function() FL.active = false; FL.ApplyCVars(); if FL.Quiet then FL.Quiet.Recompute() end end,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
end

-- Step 9a carry-over (never resets a choice): the old single switches for
-- skipping cinematics, hiding the talking head and accepting resurrection
-- become Quiet mode cells ticked in every content type; /pui cd moves to
-- Raid Tools with the same on/off state.
PUI.DB:RegisterMigration("0009a_flow_quiet", function(sv)
  local map = { skipCinematics = "movies", hideTalkingHead = "talkingHead", acceptRes = "acceptRes" }
  for _, p in pairs(sv.profiles or {}) do
    if type(p) == "table" then
      for old, opt in pairs(map) do
        if p["flow." .. old] == true then
          local g = p["flow.quiet.where"] or FL.Quiet.EmptyGrid()
          g[opt] = g[opt] or {}
          for _, c in ipairs(PUI.Profiles.CONTENT) do g[opt][c] = true end
          p["flow.quiet.where"] = g
        end
        p["flow." .. old] = nil
      end
      if p["flow.countdown"] ~= nil then
        if p["rt.slash"] == nil then p["rt.slash"] = p["flow.countdown"] end
        p["flow.countdown"] = nil
      end
    end
  end
  return true
end)
