local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- The 25 Phase 1 window packs and the module registration. Frame names are
-- the ones in the 12.1.5 and Forever interface source; names a build does not
-- have are skipped at runtime (several windows load with their Blizzard addon).
local _, ns = ...
local SK = ns.SK
local Schema = PUI.Schema
local OWNER = "Skins"

local WINDOWS = {
  { "character", "Character", { "CharacterFrame" } },
  { "inspect", "Inspect", { "InspectFrame" } },
  { "spellbook", "Spellbook and talents", { "PlayerSpellsFrame", "SpellBookFrame", "PlayerTalentFrame" } },
  { "collections", "Collections", { "CollectionsJournal" } },
  { "groupFinder", "Group Finder", { "PVEFrame", "LFGParentFrame" } },
  { "greatVault", "Great Vault", { "WeeklyRewardsFrame" } },
  { "adventureGuide", "Adventure Guide", { "EncounterJournal" } },
  { "map", "Map and quest log", { "WorldMapFrame", "QuestLogFrame" } },
  { "guild", "Guild and communities", { "CommunitiesFrame" } },
  { "calendar", "Calendar", { "CalendarFrame" } },
  { "achievements", "Achievements", { "AchievementFrame" } },
  { "mail", "Mail", { "MailFrame" } },
  { "merchant", "Merchant", { "MerchantFrame" } },
  { "auctionHouse", "Auction House", { "AuctionHouseFrame" } },
  { "macros", "Macros", { "MacroFrame" } },
  { "settings", "Settings", { "SettingsPanel" } },
  { "addonList", "AddOn list", { "AddonList" } },
  { "gossip", "Gossip and quests", { "GossipFrame", "QuestFrame" } },
  { "trade", "Trade", { "TradeFrame" } },
  { "loot", "Loot", { "LootFrame" } },
  { "readyCheck", "Ready check", { "ReadyCheckFrame" } },
  { "groupInvite", "Group invite", { "LFGInvitePopup" } },
  { "dressingRoom", "Dressing room", { "DressUpFrame" } },
  { "transmog", "Transmog", { "TransmogFrame" } },
  { "professions", "Professions", { "ProfessionsFrame" } },
}
SK.WINDOWS = WINDOWS

local schema = {}
SK.schema = schema
for _, w in ipairs(WINDOWS) do
  local id, label, frames = w[1], w[2], w[3]
  SK.Register(id, { label = label, frames = frames })
  schema["skins." .. id] = {
    type = "toggle", default = true, label = label, owner = OWNER, mode = "advanced",
    tooltip = "Phoenix skin for the " .. label .. " window.",
    apply = function() if SK.active then SK.Refresh() end end,
  }
end

-- Third-party addon windows (PUI_V2 13 Phase 6). Frame names were read from
-- each addon's own source (Details! d1e8ad7, Pawn 2.14.1, WeakAuras 37c3950,
-- Plater 536b2ea; October 2026): only the frame shell, close button and title
-- are touched, never the addon's content, and a missing frame is skipped.
local ADDONS = {
  { "details", "Details! windows", { "DetailsBaseFrame1", "DetailsBaseFrame2", "DetailsBaseFrame3", "DetailsBaseFrame4", "DetailsBaseFrame5" }, { "shell" } },
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
    tooltip = "Phoenix frame skin for " .. label .. " when that addon is installed.",
    apply = function() if SK.active then SK.Refresh() end end,
  }
end

local function onEnable(mod)
  SK.active = true
  mod:RegisterEvent("ADDON_LOADED", function() SK.Refresh() end)
  SK.Refresh()
end

local function onDisable()
  SK.active = false
  for _, id in ipairs(SK.order) do if SK.applied[id] then SK.Revert(id) end end
end

SK.module = PUI:RegisterModule(OWNER, {
  label = "Skins", tooltip = "Phoenix look for 25 Blizzard windows and Details!, Pawn, WeakAuras and Plater; each has its own switch.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
