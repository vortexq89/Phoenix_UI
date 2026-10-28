local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Window catalog (skins v2): every Blizzard window and surface Phoenix skins,
-- with its frames, the Blizzard addon that owns it and its Phoenix extras.
-- Frame names were read from the 12.1.5 interface source (Gethe wow-ui-source
-- b9be937) and the Forever source; a build without a frame skips it, and
-- load-on-demand windows are skinned when their addon loads. Each window keeps
-- Blizzard's layout and every Blizzard feature (docs/SKINS_FEATURE_AUDIT.md):
-- Phoenix restyles the shell, tabs, buttons, title and all shared controls.
-- Extras are schema keys skins.<group>.<name>: they show in the window's gear
-- flyout and on /pui -> Skins (tabs Player, Social, Trade, World).
local _, ns = ...
local SK = ns.SK
local Schema = PUI.Schema
local OWNER = "Skins"

local function N(prefix, a, b) local t = {} for i = a, b do t[#t + 1] = prefix .. i end return t end
local function cat(...) local t = {} for _, l in ipairs({ ... }) do for _, v in ipairs(l) do t[#t + 1] = v end end return t end

-- { id, label, frames, group, extras = { name, ... } }; extras names refer to SK.EXTRAS.
local WINDOWS = {
  -- 01-06 player windows
  { "character", "Character", { "CharacterFrame" }, "player", { "charIlvl", "charEnchants", "charDurability", "charModelLight" } },
  { "inspect", "Inspect", { "InspectFrame" }, "player", { "charIlvl", "charEnchants" } },
  { "spellbook", "Spellbook and talents", { "PlayerSpellsFrame", "SpellBookFrame", "PlayerTalentFrame" }, "player", {} },
  { "collections", "Collections", { "CollectionsJournal", "WardrobeFrame" }, "player", {} },
  { "transmog", "Transmog", { "TransmogFrame" }, "player", {} },
  { "dressingRoom", "Dressing room", { "DressUpFrame" }, "player", {} },
  -- 07-09 group and social
  { "groupFinder", "Group Finder", { "PVEFrame", "LFGParentFrame" }, "social", {} },
  { "lfgDialogs", "Ready, role check and proposals", { "LFGDungeonReadyDialog", "PVPReadyDialog", "RolePollPopup", "LFDRoleCheckPopup" }, "social", {} },
  { "groupInvite", "Group invite", { "LFGInvitePopup" }, "social", {} },
  { "challenges", "Mythic+ keystone", { "ChallengesKeystoneFrame" }, "social", {} },
  { "pvpMatch", "PvP scoreboard and results", { "PVPMatchScoreboard", "PVPMatchResults" }, "social", {} },
  { "friends", "Friends, Who, Raid, Quick Join", { "FriendsFrame", "AddFriendFrame", "RecruitAFriendFrame" }, "social", {} },
  { "loot", "Loot", { "LootFrame" }, "social", {} },
  { "lootRolls", "Loot rolls", N("GroupLootFrame", 1, 4), "social", {} },
  { "bonusRoll", "Bonus roll", { "BonusRollFrame" }, "social", {} },
  { "lootHistory", "Loot history", { "GroupLootHistoryFrame" }, "social", {} },
  { "readyCheck", "Ready check", { "ReadyCheckFrame" }, "social", {} },
  { "guild", "Guild and communities", { "CommunitiesFrame", "GuildControlUI" }, "social", {} },
  { "calendar", "Calendar", { "CalendarFrame", "CalendarViewEventFrame", "CalendarCreateEventFrame" }, "social", {} },
  { "channels", "Chat channels", { "ChannelFrame" }, "social", {} },
  -- 10-14 trade
  { "bags", "Bags (when Vault is off)", cat({ "ContainerFrameCombinedBags" }, N("ContainerFrame", 1, 6)), "trade", {} },
  { "bank", "Bank and Warband bank", { "BankFrame" }, "trade", {} },
  { "guildBank", "Guild bank", { "GuildBankFrame" }, "trade", {} },
  { "merchant", "Merchant", { "MerchantFrame" }, "trade", {} },
  { "mail", "Mail", { "MailFrame", "OpenMailFrame" }, "trade", { "mailCollectGold" } },
  { "auctionHouse", "Auction House", { "AuctionHouseFrame" }, "trade", {} },
  { "blackMarket", "Black market", { "BlackMarketFrame" }, "trade", {} },
  { "trade", "Trade", { "TradeFrame" }, "trade", {} },
  { "professions", "Professions", { "ProfessionsFrame", "ProfessionsBookFrame", "ProfessionsCustomerOrdersFrame" }, "trade", {} },
  { "trainer", "Trainer", { "ClassTrainerFrame" }, "trade", {} },
  { "socketing", "Socketing", { "ItemSocketingFrame" }, "trade", {} },
  { "itemUpgrade", "Item upgrades", { "ItemUpgradeFrame" }, "trade", {} },
  { "catalyst", "Catalyst and item interaction", { "ItemInteractionFrame" }, "trade", {} },
  { "scrapping", "Scrapping", { "ScrappingMachineFrame" }, "trade", {} },
  { "archaeology", "Archaeology", { "ArchaeologyFrame" }, "trade", {} },
  { "stable", "Pet stable", { "StableFrame" }, "trade", {} },
  -- 15-22 world and system
  { "achievements", "Achievements", { "AchievementFrame" }, "world", {} },
  { "adventureGuide", "Adventure Guide", { "EncounterJournal" }, "world", {} },
  { "map", "Map and quest log", { "WorldMapFrame", "QuestLogFrame" }, "world", { "mapCoords" } },
  { "flightMap", "Flight map", { "FlightMapFrame" }, "world", {} },
  { "zoneMap", "Zone map", { "BattlefieldMapFrame" }, "world", {} },
  { "greatVault", "Great Vault", { "WeeklyRewardsFrame" }, "world", {} },
  { "gossip", "Gossip and quests", { "GossipFrame", "QuestFrame" }, "world", {} },
  { "playerChoice", "Player choice", { "PlayerChoiceFrame" }, "world", {} },
  { "delves", "Delves companion and difficulty", { "DelvesCompanionConfigurationFrame", "DelvesCompanionAbilityListFrame", "DelvesDifficultyPickerFrame" }, "world", {} },
  { "genericTraits", "Trait trees (Delves, Skyriding)", { "GenericTraitFrame" }, "world", {} },
  { "landing", "Expansion summary and renown", { "ExpansionLandingPage" }, "world", {} },
  { "housing", "Housing", { "HousingDashboardFrame", "HouseFinderFrame", "HouseListFrame", "HousingBulletinBoardFrame", "HousingCornerstoneFrame" }, "world", {} },
  { "legacy", "Legacy content windows", { "CovenantSanctumFrame", "CovenantRenownFrame", "GarrisonLandingPage", "OrderHallTalentFrame", "AzeriteEssenceUI" }, "world", {} },
  { "gameMenu", "Game Menu", { "GameMenuFrame" }, "world", {} },
  { "popups", "Popups", N("StaticPopup", 1, 4), "world", { "popupDanger" } },
  { "editMode", "Edit Mode", { "EditModeManagerFrame", "EditModeSystemSettingsDialog" }, "world", { "editModeStudio" } },
  { "settings", "Settings", { "SettingsPanel" }, "world", {} },
  { "addonList", "AddOn list", { "AddonList" }, "world", {} },
  { "macros", "Macros", { "MacroFrame" }, "world", {} },
  { "clickBinding", "Click casting", { "ClickBindingFrame" }, "world", {} },
  { "colorPicker", "Colour picker", { "ColorPickerFrame" }, "world", {} },
  { "help", "Help and report", { "HelpFrame" }, "world", {} },
  { "timeManager", "Clock and stopwatch", { "TimeManagerFrame", "StopwatchFrame" }, "world", {} },
  { "queueStatus", "Queue status", { "QueueStatusFrame" }, "world", {} },
  { "bnToast", "Battle.net toasts", { "BNToastFrame" }, "world", {} },
  { "worldLoot", "World loot list", { "WorldLootObjectList" }, "world", {} },
}
SK.WINDOWS = WINDOWS
SK.WINDOW_GROUPS = { player = "Player", social = "Social", trade = "Trade", world = "World" }

local schema = {}
SK.schema = schema
local function refresh() if SK.active then SK.Refresh() end end
for _, w in ipairs(WINDOWS) do
  local id, label, frames, group, extras = w[1], w[2], w[3], w[4], w[5]
  local keys = { "skins." .. id }
  for _, name in ipairs(extras or {}) do keys[#keys + 1] = "skins." .. group .. "." .. name end
  local impl = (SK.WINDOW_IMPL or {})[id] or {}
  SK.Register(id, { label = label, frames = frames, group = group, extras = keys, extraNames = extras,
    hooks = impl.hooks, update = impl.update, extra = impl.extra, revert = impl.revert })
  for _, name in ipairs(extras or {}) do
    local key, def = "skins." .. group .. "." .. name, SK.EXTRA_DEFS[name]
    if not schema[key] then
      schema[key] = { type = def.type, default = def.default, label = def.label, tooltip = def.tooltip, owner = OWNER, mode = def.mode,
        apply = function(v) SK.Extras.s[name] = v; refresh(); if SK.Gear.flyout and SK.Gear.flyout:IsShown() then SK.Gear.Fill(SK.Gear.flyout.packId) end end }
    end
  end
  schema["skins." .. id] = {
    type = "toggle", default = true, label = label, owner = OWNER, mode = "advanced",
    tooltip = "Phoenix skin for the " .. label .. " window.", apply = refresh,
  }
end
for _, sf in ipairs(SK.SURFACES or {}) do
  schema["skins." .. sf[1]] = { type = "toggle", default = true, label = sf[2], owner = OWNER, mode = "advanced", tooltip = sf[3], apply = refresh }
end
schema["skins.menus"] = { type = "toggle", default = true, label = "Right-click and dropdown menus", owner = OWNER, mode = "simple",
  tooltip = "Phoenix look for every context menu and dropdown list, including the damage meter's.", apply = refresh }

-- Shared controls: one switch per template family, live.
local CONTROL_KEYS = {
  { "scrollBars", "Scroll bars", "Thin Phoenix scroll bars in every skinned window." },
  { "dropdowns", "Dropdowns", "Phoenix dropdown boxes with an accent arrow." },
  { "checks", "Checkboxes and radios", "Phoenix boxes; the check mark takes the accent colour." },
  { "edits", "Edit and search boxes", "Phoenix input boxes with a hairline border." },
  { "sliders", "Sliders", "Thin rail with an accent thumb." },
  { "quality", "Item quality borders", "Phoenix slot frame on Blizzard item buttons, in the item's quality colour." },
  { "buttons", "Panel buttons", "Phoenix button face on Blizzard panel buttons." },
}
for _, c in ipairs(CONTROL_KEYS) do
  schema["skins.controls." .. c[1]] = { type = "toggle", default = true, label = c[2], owner = OWNER, mode = "simple", tooltip = c[3],
    apply = function(v) SK.Controls.s[c[1]] = v; if SK.active then SK.RevertAll(); SK.Refresh() end end }
end

-- Third-party addon windows (PUI_V2 13 Phase 6). Frame names were read from
-- each addon's own source (Details! d1e8ad7, Pawn 2.14.1, WeakAuras 37c3950,
-- Plater 536b2ea; October 2026): only the frame shell, close button and title
-- are touched, never the addon's content, and a missing frame is skipped.
local ADDONS = {
  { "details", "Details! windows", N("DetailsBaseFrame", 1, 5), { "shell" } },
  { "pawn", "Pawn", { "PawnUIFrame" }, { "shell", "close", "tabs", "buttons" } },
  { "weakauras", "WeakAuras options", { "WeakAurasOptions" }, { "shell", "close", "title" } },
  { "plater", "Plater options", { "PlaterOptionsPanelFrame" }, { "shell", "close" } },
}
SK.ADDONS = ADDONS
for _, a in ipairs(ADDONS) do
  local id, label, frames, parts = a[1], a[2], a[3], a[4]
  SK.Register(id, { label = label, frames = frames, parts = parts })
  schema["skins." .. id] = {
    type = "toggle", default = true, label = label, owner = OWNER, mode = "advanced",
    tooltip = "Phoenix frame skin for " .. label .. " when that addon is installed.", apply = refresh,
  }
end

function SK.RevertAll() for _, id in ipairs(SK.order) do if SK.applied[id] then SK.Revert(id) end end end

local function onEnable(mod)
  SK.active = true
  mod:RegisterEvent("ADDON_LOADED", function() SK.Refresh() end)
  SK.Refresh()
end

local function onDisable()
  SK.active = false
  SK.RevertAll()
end

SK.module = PUI:RegisterModule(OWNER, {
  label = "Skins", tooltip = "Phoenix look for Blizzard's windows, menus, tooltips and popups (their own layout and features, your theme), and Details!, Pawn, WeakAuras and Plater; each has its own switch.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
