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
  label = "Skins", tooltip = "Phoenix look for 25 Blizzard windows; each window has its own switch.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
