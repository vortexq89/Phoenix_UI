local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Move Blizzard windows (plan 4 window mover, MoveAny "MoveFrames" parity).
-- Off on first install. When on, each listed Blizzard window gets a thin
-- Phoenix drag strip over its title area (a Phoenix frame, the window itself
-- is never reparented and gets no fields). Drag to move, Ctrl + mouse wheel on
-- the strip to scale, right-click the strip to reset. Positions are remembered
-- per profile (optional), clamped back on screen, and every window Phoenix
-- touched is recorded in the FrameLedger so turning the feature off restores
-- it. Protected windows are never moved in combat.
local Windows = { handles = {}, taken = {} }
PUI.Windows = Windows
local Schema, CQ, FL = PUI.Schema, PUI.CombatQueue, PUI.FrameLedger
local OWNER = "Studio"

-- { frame global, label, load-on-demand Blizzard addon or nil }
Windows.CATALOG = {
  { "CharacterFrame", "Character" }, { "PlayerSpellsFrame", "Talents and spellbook", "Blizzard_PlayerSpells" },
  { "CollectionsJournal", "Collections", "Blizzard_Collections" }, { "EncounterJournal", "Adventure guide", "Blizzard_EncounterJournal" },
  { "PVEFrame", "Group finder" }, { "FriendsFrame", "Social" }, { "CommunitiesFrame", "Guild and communities", "Blizzard_Communities" },
  { "AchievementFrame", "Achievements", "Blizzard_AchievementUI" }, { "WorldMapFrame", "World map" },
  { "QuestFrame", "Quest dialog" }, { "GossipFrame", "Gossip" }, { "MerchantFrame", "Merchant" }, { "MailFrame", "Mail" },
  { "OpenMailFrame", "Open mail" }, { "BankFrame", "Bank" }, { "AuctionHouseFrame", "Auction house", "Blizzard_AuctionHouseUI" },
  { "ProfessionsFrame", "Professions", "Blizzard_Professions" }, { "ProfessionsCustomerOrdersFrame", "Crafting orders", "Blizzard_ProfessionsCustomerOrders" },
  { "TradeFrame", "Trade" }, { "DressUpFrame", "Dressing room" }, { "InspectFrame", "Inspect", "Blizzard_InspectUI" },
  { "GameMenuFrame", "Game menu" }, { "SettingsPanel", "Settings" }, { "AddonList", "AddOns list" }, { "HelpFrame", "Help" },
  { "ItemSocketingFrame", "Socketing", "Blizzard_ItemSocketingUI" }, { "ItemUpgradeFrame", "Item upgrade", "Blizzard_ItemUpgradeUI" },
  { "WeeklyRewardsFrame", "Great Vault", "Blizzard_WeeklyRewards" }, { "ChallengesKeystoneFrame", "Keystone slot", "Blizzard_ChallengesUI" },
  { "MacroFrame", "Macros", "Blizzard_MacroUI" }, { "TimeManagerFrame", "Stopwatch and clock", "Blizzard_TimeManager" },
  { "CalendarFrame", "Calendar", "Blizzard_Calendar" }, { "ScriptErrorsFrame", "Lua errors", "Blizzard_DebugTools" },
  { "TabardFrame", "Tabard" }, { "GuildBankFrame", "Guild bank", "Blizzard_GuildBankUI" }, { "TransmogFrame", "Transmogrify", "Blizzard_Transmog" },
  { "GenericTraitFrame", "Trait trees", "Blizzard_GenericTraitUI" }, { "ExpansionLandingPage", "Expansion summary", "Blizzard_ExpansionLandingPage" },
  { "DelvesCompanionConfigurationFrame", "Delve companion", "Blizzard_DelvesCompanionConfiguration" },
  { "ClassTrainerFrame", "Class trainer", "Blizzard_TrainerUI" }, { "QuestLogPopupDetailFrame", "Quest details" },
  { "LootFrame", "Loot window" }, { "PetStableFrame", "Stable" }, { "FlightMapFrame", "Flight map", "Blizzard_FlightMap" },
  { "ReforgingFrame", "Reforging" }, { "ChannelFrame", "Chat channels", "Blizzard_Channels" },
  { "PVPMatchScoreboard", "Battleground scoreboard" }, { "PVPMatchResults", "Match results" },
  { "HousingDashboardFrame", "Housing dashboard", "Blizzard_HousingDashboard" },
}
local byName = {}
for _, c in ipairs(Windows.CATALOG) do byName[c[1]] = c end
Windows.byName = byName

function Windows:Enabled() return Schema:Get("studio.windows.enabled") end

-- Pure: keep at least `margin` px of a w x h window on a W x H screen.
-- x, y are CENTER offsets from the screen centre.
function Windows.Clamp(x, y, w, h, W, H, margin)
  margin = margin or 40
  local maxX = W / 2 + w / 2 - margin
  local maxY = H / 2 + h / 2 - margin
  local cx = math.max(-maxX, math.min(maxX, x))
  local cy = math.max(-maxY, math.min(maxY, y))
  return math.floor(cx + 0.5), math.floor(cy + 0.5), (cx ~= x or cy ~= y)
end

local function saved() return Schema:Get("studio.windows.positions") end

local function apply(name, f)
  local r = saved()[name]
  if not (r and Schema:Get("studio.windows.remember")) then return end
  if f.IsProtected and f:IsProtected() and CQ.InCombat() then return end
  local x, y = Windows.Clamp(r.x, r.y, f:GetWidth() or 0, f:GetHeight() or 0, UIParent:GetWidth(), UIParent:GetHeight())
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", x, y)
  if r.scale and f.SetScale then f:SetScale(r.scale) end
end
Windows.Apply = apply

local function store(name, f, scale)
  local cx, cy = f:GetCenter()
  if not cx then return end
  local s = f:GetScale() or 1
  local t = saved()
  local x, y = math.floor(cx * s - UIParent:GetWidth() / 2 + 0.5), math.floor(cy * s - UIParent:GetHeight() / 2 + 0.5)
  t[name] = { point = "CENTER", x = math.floor(x / s + 0.5), y = math.floor(y / s + 0.5), scale = scale or (t[name] and t[name].scale) }
  Schema:Set("studio.windows.positions", t)
end

local function take(name, f)
  if Windows.taken[name] then return true end
  if not FL:Take(OWNER, f, "win." .. name) then return false end
  Windows.taken[name] = true
  return true
end

-- The drag strip: a Phoenix frame over the top of the Blizzard window.
local function handle(name, f)
  local h = Windows.handles[name]
  if h then h:SetShown(Windows:Enabled()); return h end
  h = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
  h:SetPoint("TOPLEFT", f, "TOPLEFT", 40, 0)
  h:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, 0)
  h:SetHeight(Schema:Get("studio.windows.handleHeight"))
  h:EnableMouse(true)
  h:RegisterForDrag("LeftButton")
  h:SetScript("OnDragStart", function()
    if f.IsProtected and f:IsProtected() and CQ.InCombat() then return end
    if not take(name, f) then return end
    f:SetMovable(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    f:StartMoving()
  end)
  h:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    if f.SetUserPlaced then f:SetUserPlaced(false) end -- Phoenix remembers it, not the layout cache
    store(name, f)
  end)
  h:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" and IsShiftKeyDown() then Windows:Reset(name) end
  end)
  h:EnableMouseWheel(true)
  h:SetScript("OnMouseWheel", function(_, delta)
    if not (IsControlKeyDown() and Schema:Get("studio.windows.scaleWheel")) then return end
    if f.IsProtected and f:IsProtected() and CQ.InCombat() then return end
    if not take(name, f) then return end
    local s = math.max(0.5, math.min(1.6, (f:GetScale() or 1) + delta * 0.05))
    f:SetScale(s)
    store(name, f, s)
  end)
  Windows.handles[name] = h
  return h
end

function Windows:Hook(name)
  local f = rawget(_G, name)
  if not f or self.handles[name] or not f.HookScript then return false end
  handle(name, f)
  f:HookScript("OnShow", function(w)
    if not Windows:Enabled() then return end
    C_Timer.After(0, function() if Windows:Enabled() and saved()[name] then take(name, w); apply(name, w) end end)
  end)
  return true
end

function Windows:Scan()
  if not self:Enabled() then return 0 end
  local n = 0
  for _, c in ipairs(self.CATALOG) do if self:Hook(c[1]) then n = n + 1 end end
  return n
end

function Windows:Reset(name)
  local t = saved()
  if name then t[name] = nil else t = {} end
  Schema:Set("studio.windows.positions", t)
  if name then FL:Release(OWNER, "win." .. name); self.taken[name] = nil
  else for n in pairs(self.taken) do FL:Release(OWNER, "win." .. n) end; self.taken = {} end
end

function Windows:Refresh()
  local on = self:Enabled()
  for _, h in pairs(self.handles) do h:SetShown(on) end
  if on then self:Scan() else
    for n in pairs(self.taken) do FL:Release(OWNER, "win." .. n) end
    self.taken = {}
  end
end

Schema:Register("studio.windows.enabled", {
  type = "toggle", default = false,
  label = "Move Blizzard windows", tooltip = "Drag Blizzard windows (character, map, bags, talents and about 50 more) by their title. Ctrl + mouse wheel scales, Shift + right-click resets.",
  mode = "simple", owner = "Studio", searchTags = { "moveany", "windows", "drag", "move frames" },
  apply = function() Windows:Refresh() end,
})
Schema:Register("studio.windows.remember", {
  type = "toggle", default = true,
  label = "Remember window positions", tooltip = "Windows open where you last left them. Off: they move only until closed.",
  mode = "simple", owner = "Studio", searchTags = { "windows", "remember" },
  apply = function() end,
})
Schema:Register("studio.windows.scaleWheel", {
  type = "toggle", default = true,
  label = "Ctrl + wheel scales windows", tooltip = "Hold Ctrl and scroll over a window title to scale it.",
  mode = "advanced", owner = "Studio", searchTags = { "windows", "scale" },
  apply = function() end,
})
Schema:Register("studio.windows.handleHeight", {
  type = "range", default = 24, min = 12, max = 48, step = 2,
  label = "Window drag strip height", tooltip = "Height of the drag area along the top of each window.",
  mode = "advanced", owner = "Studio", searchTags = { "windows", "drag" },
  apply = function(v) for _, h in pairs(Windows.handles) do h:SetHeight(v) end end,
})
Schema:Register("studio.windows.positions", {
  type = "layout", default = {},
  label = "Window positions", tooltip = "Where you dragged Blizzard windows.",
  mode = "advanced", owner = "Studio",
  apply = function() end,
})

PUI.Slash:Register("windows", function(rest)
  if rest == "reset" then
    return PUI.Dialogs:Confirm({ title = "Reset window positions", text = "Clear every remembered Blizzard window position?",
      accept = "Clear", danger = true, onAccept = function() Windows:Reset(); PUI.Slash.Print("every Blizzard window position cleared.") end })
  end
  PUI.Slash.Print("usage: /pui windows reset")
end, "reset: clear every remembered Blizzard window position")
