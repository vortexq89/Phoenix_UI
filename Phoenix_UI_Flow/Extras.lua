local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Flow, deferred batch C (every switch off at first install, events only
-- registered while a switch is on, nothing protected in combat):
--  * leave prompt after a finder dungeon (own confirm dialog, never automatic)
--  * open containers (lootable bag items, one per bag update, out of combat)
--  * Train All button on the class trainer
--  * hide tutorials and achievement/level-up banners (CVar restored on off)
--  * /gg in instance chat
--  * queue protection: the ready pop-up's buttons ignore clicks for a moment
--  * Tab binder: Tab targets enemy players in arenas and battlegrounds
--  * screenshot when you earn an achievement
local _, ns = ...
local FL = ns.Flow
local Schema, Ticker, CQ = PUI.Schema, PUI.Ticker, PUI.CombatQueue
local OWNER = "Flow"
local s = FL.settings
local A = FL.actions

-- Leave prompt -----------------------------------------------------------------------------------
function A.leavePrompt()
  if not IsInGroup() then return false end
  PUI.Dialogs:Confirm({ title = "Dungeon complete", text = "Leave the group?", accept = "Leave", cancel = "Stay",
    onAccept = function() C_PartyInfo.LeaveParty() end })
  FL.log[#FL.log + 1] = "leavePrompt"
  return true
end

-- Open containers ----------------------------------------------------------------------------------
function FL.NextContainer()
  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if type(info) == "table" and info.hasLoot and not info.isLocked then return bag, slot end
    end
  end
end
function A.openContainers()
  if InCombatLockdown() or IsShiftKeyDown() then return false end
  local merchant, bank = rawget(_G, "MerchantFrame"), rawget(_G, "BankFrame")
  if (merchant and merchant:IsShown()) or (bank and bank:IsShown()) then return false end
  local bag, slot = FL.NextContainer()
  if not bag then return false end
  C_Container.UseContainerItem(bag, slot)
  FL.log[#FL.log + 1] = "openContainers"
  return true
end

-- Train All -------------------------------------------------------------------------------------------
function FL.Trainable()
  local out = {}
  for i = 1, GetNumTrainerServices() or 0 do
    local _, kind = GetTrainerServiceInfo(i)
    if kind == "available" then out[#out + 1] = i end
  end
  return out
end
function FL.TrainAll()
  if InCombatLockdown() then return 0 end
  local list = FL.Trainable()
  for i = #list, 1, -1 do BuyTrainerService(list[i]) end
  return #list
end
function A.trainAll()
  local parent = rawget(_G, "ClassTrainerFrame")
  if not parent then return end
  local b = FL.trainButton
  if not b then
    b = PUI:CreateFrame("Button", "PhoenixUI_TrainAll", parent, "UIPanelButtonTemplate", OWNER)
    b:SetSize(90, 22)
    b:SetText("Train all")
    b:SetScript("OnClick", function() FL.TrainAll() end)
    FL.trainButton = b
  end
  b:ClearAllPoints()
  local train = rawget(_G, "ClassTrainerTrainButton")
  if train then b:SetPoint("RIGHT", train, "LEFT", -4, 0) else b:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -100, 4) end
  b:SetShown(s.trainAll and #FL.Trainable() > 0)
end

-- Banners -------------------------------------------------------------------------------------------
FL.CVARS.hideTutorials = { name = "showTutorials", on = "0" }
FL.BANNERS = { "BossBanner", "LevelUpDisplay" }
function FL.ApplyBanners()
  for _, name in ipairs(FL.BANNERS) do
    local f = rawget(_G, name)
    if f and f.SetAlpha then f:SetAlpha((FL.active and s.hideBanners) and 0 or 1) end
  end
end

-- /gg ----------------------------------------------------------------------------------------------------
function FL.GG()
  if not (FL.active and s.gg) then return false end
  local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID") or (IsInGroup() and "PARTY") or nil
  if not channel then return false end
  C_ChatInfo.SendChatMessage(s.ggText ~= "" and s.ggText or "gg", channel)
  return channel
end
PUI.Kernel:On("LOGIN", function()
  if rawget(_G, "SlashCmdList") and SlashCmdList.GG == nil then
    SLASH_PHOENIXUIGG1 = "/gg"
    SlashCmdList.PHOENIXUIGG = function() FL.GG() end
  end
end)
PUI.Slash:Register("gg", function() FL.GG() end, "say gg in instance chat (Flow)")

-- Queue protection ----------------------------------------------------------------------------------
FL.QUEUE_BUTTONS = { "LFGDungeonReadyDialogEnterDungeonButton", "LFGDungeonReadyDialogLeaveQueueButton" }
function A.queueProtect()
  if InCombatLockdown() then return false end
  local any = false
  for _, n in ipairs(FL.QUEUE_BUTTONS) do
    local b = rawget(_G, n)
    if b and b.Disable then b:Disable(); any = true end
  end
  if not any then return false end
  if Ticker:IsRegistered("flow.queueProtect") then Ticker:Unregister("flow.queueProtect") end
  Ticker:Register("flow.queueProtect", s.queueProtectTime, function()
    Ticker:Unregister("flow.queueProtect")
    FL.QueueRelease()
  end, OWNER)
  return true
end
function FL.QueueRelease()
  if InCombatLockdown() then CQ.Defer("flow.queueRelease", FL.QueueRelease); return end
  for _, n in ipairs(FL.QUEUE_BUTTONS) do local b = rawget(_G, n); if b and b.Enable then b:Enable() end end
end

-- Tab binder -------------------------------------------------------------------------------------------
function A.tabBinder()
  local pvp = FL.active and s.tabBinder and FL.InPvPInstance()
  if pvp then PUI.Bindings:Claim(OWNER, "TAB", "TARGETNEARESTENEMYPLAYER")
  else PUI.Bindings:Release(OWNER, "TAB") end
  FL.tabClaimed = pvp and true or false
  return FL.tabClaimed
end

-- Screenshot -----------------------------------------------------------------------------------------
function A.screenshot()
  if Ticker:IsRegistered("flow.screenshot") then return end
  Ticker:Register("flow.screenshot", 1, function() Ticker:Unregister("flow.screenshot"); Screenshot() end, OWNER)
end

-- Events per switch ---------------------------------------------------------------------------------
local E = FL.EVENTS
E.leavePrompt = { LFG_COMPLETION_REWARD = A.leavePrompt }
E.openContainers = { BAG_UPDATE_DELAYED = A.openContainers }
E.trainAll = { TRAINER_SHOW = A.trainAll, TRAINER_UPDATE = A.trainAll }
E.hideBanners = { PLAYER_ENTERING_WORLD = FL.ApplyBanners }
E.queueProtect = { LFG_PROPOSAL_SHOW = A.queueProtect }
E.tabBinder = { PLAYER_ENTERING_WORLD = A.tabBinder, ZONE_CHANGED_NEW_AREA = A.tabBinder }
E.screenshot = { ACHIEVEMENT_EARNED = A.screenshot }

local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v)
    s[name] = v
    FL.Sync(); FL.ApplyCVars(); FL.ApplyBanners()
    if name == "tabBinder" then A.tabBinder() end
    if name == "trainAll" and FL.trainButton then A.trainAll() end
  end
  FL.schema["flow." .. name] = def
  Schema:Register("flow." .. name, def)
  s[name] = Schema:Get("flow." .. name)
end
local function toggle(name, label, tooltip, mode) key(name, { type = "toggle", default = false, label = label, tooltip = tooltip, mode = mode }) end
toggle("leavePrompt", "Leave prompt after finder dungeons", "Asks whether to leave the group when a Dungeon Finder run is complete. Never leaves on its own.", "simple")
toggle("openContainers", "Open containers", "Opens lootable bag items (caches, satchels) one at a time out of combat. Hold Shift to keep them closed.")
toggle("trainAll", "Train All button", "Adds a Train all button to the class trainer.")
toggle("hideTutorials", "Hide tutorials", "Turns off the game's tutorial pop-ups; your setting comes back when this is off.")
toggle("hideBanners", "Hide boss and level-up banners", "Hides the big boss-loot and level-up banners.")
toggle("gg", "/gg", "Enables /gg (and /pui gg) to say a message in instance, raid or party chat.")
key("ggText", { type = "text", default = "gg", label = "/gg message", tooltip = "What /gg says." })
toggle("queueProtect", "Queue pop protection", "The dungeon ready pop-up ignores clicks for a moment so a stray click cannot accept or leave.")
key("queueProtectTime", { type = "range", default = 1, min = 0.5, max = 3, step = 0.5, label = "Queue protection time (seconds)",
  tooltip = "How long the ready pop-up ignores clicks." })
toggle("tabBinder", "Tab targets players in PvP", "In arenas and battlegrounds Tab targets the nearest enemy player (an override binding; your own Tab comes back outside).")
toggle("screenshot", "Screenshot on achievement", "Takes a screenshot a second after you earn an achievement.")
PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then A.tabBinder(); FL.ApplyBanners() end end)
