# Phoenix UI: Skins audit and theme plan (12.1.5 + Forever)

Date: 27 Oct 2026 (Kuwait, UTC+3). Read-only audit: code read from `feat/gaps` HEAD `7ba1195` (snapshot via `git archive`, nothing changed there) against the Blizzard interface source `Gethe wow-ui-source` live `b9be937` "12.1.5 (70448)" (339 Blizzard_* addons). No commits.

## 1. Answer in one paragraph

No, Phoenix does not have an end-to-end full-suite theme yet. Of **97 player-facing Blizzard surfaces**, **17 are full** (all of them are Phoenix replacements: unit/raid frames, nameplates, bags/bank, tooltips (GameTooltip), chat, tracker, meter, cooldowns, XP bars, error viewer and so on), **37 are partial** and **43 have none** (2 of those are Blizzard-restricted shop/secure windows that no addon can skin). The other 108 Blizzard_* addons are libraries, deprecated shims, glue/login or dev tools with no in-game window. Every "partial" Blizzard window is partial for the same reason: the Skins engine only fades the window shell (NineSlice, Bg, portrait, title bg), puts a flat Phoenix backdrop behind it and restyles tabs, the close button, `UIPanelButtonTemplate` buttons and the title font. The content (list rows, item slots, scroll bars, dropdowns, checkboxes, edit boxes, search boxes, model-scene backdrops, talent nodes) is still Blizzard art, so each window ends up half Blizzard and half Phoenix. The Skins module is also **off by default** (`enabledByDefault = false`).

Theme consistency is fine: every Skins backdrop and outline is painted from `Theme` tokens, so the four surface themes (Ember, Midnight, Horde, Alliance) and the accent apply live, with no /reload, wherever a skin exists. The gaps are coverage and depth, not the colour system. The Phoenix nine-slice, panel and control art in `Phoenix_UI_Media` (Panel_R28, Card_R24, Button_*_R16, ObsidianGlass) is **not used by Skins yet**: it draws flat colour with a 1 px outline.

## 2. How Skins works today (code read)

- `Phoenix_UI_Skins/Skins.lua`: the engine has 6 primitives (`shell`, `inset`, `close`, `tabs`, `buttons`, `title`). Originals go into weak side tables, and the revert is exact. Each pack runs inside `securecallfunction`, and the work goes through `CombatQueue.Defer`. Load-on-demand windows are picked up on `ADDON_LOADED`. Third-party packs come in through `PUI.API.RegisterSkin`.
- `Packs.lua`: 25 Blizzard window packs (character, inspect, spellbook, collections, groupFinder, greatVault, adventureGuide, map, guild, calendar, achievements, mail, merchant, auctionHouse, macros, settings, addonList, gossip, trade, loot, readyCheck, groupInvite, dressingRoom, transmog, professions) plus 4 addon packs (Details!, Pawn, WeakAuras, Plater). Each has its own toggle (advanced view).
- `QueueTimer.lua`: a countdown bar on LFG/PvP ready dialogs.
- Other modules restyle their own areas: the Friends module (row post-hook), Group Finder (row lines), HUD Tooltip, Vault (bags/bank replacement), Chat, Quest Tracker, Minimap, Data Bars, Embers, Arena, Pulse, Spark and Sentinel. `Core/Windows.lua` only moves and scales Blizzard windows (no skin). `Core/Entry.lua` adds a Phoenix button to the Game Menu, and that is all it does there.
- Frame names verified in the 12.1.5 source. `SpellBookFrame`, `PlayerTalentFrame`, `LFGParentFrame` and `QuestLogFrame` exist only on Forever, and they are skipped at runtime on retail, which is correct.

## 3. Coverage table (player-facing surfaces)

Legend: **full** = Phoenix owns or fully restyles it. **partial** = shell-only Skins pack, or a module restyles part of it. **none** = Blizzard art (at most moved by Movers). Priority: P1 = before release, P2 = soon after, P3 = later. The mockup column points to `/workspace/pui_mockups/skins/<file>.png`.

| Blizzard addon(s) | Surface | Main frames | Coverage | Phoenix owner today | Missing | Restriction → workaround | Prio | Mockup |
|---|---|---|---|---|---|---|---|---|
| Blizzard_FrameXML | Alert toasts | AlertFrame subsystems (loot, achievement, mount, currency, WQ) | **none** | Flow (Quiet hides) | No toast skin | hooksecurefunc each subsystem setUpFunction; restyle pooled frame | P1 | 09_loot |
| Blizzard_Menu, Blizzard_UnitPopup, Blizzard_UnitPopupShared | Context menus (right-click) | Menu manager | **none** | — | No skin | Menu entries are protected for some actions: restyle the menu frame via Menu.ModifyMenu / hooks, textures only | P1 |  |
| Blizzard_GameMenu, Blizzard_GameMenuEsc | Game menu | GameMenuFrame | **none** | Entry (adds Phoenix button only) | All buttons Blizzard art | Protected buttons: hook InitButtons, textures only | P1 | 20_game_menu_popups |
| Blizzard_FrameXML | Group loot roll frames | GroupLootContainer, GroupLootFrame1-4 | **none** | Movers only | No roll skin | Hook GroupLootContainer_AddFrame; RollOnLoot stays Blizzard button | P1 | 09_loot |
| Blizzard_StaticPopup, Blizzard_StaticPopup_Game | Popups | StaticPopup1-4 (12.x pool) | **none** | — (Phoenix has own Dialogs) | No skin | Never write StaticPopupDialogs; hook OnShow, textures only | P1 | 20_game_menu_popups |
| Blizzard_SocialToast | Battle.net toasts | BNToastFrame | **none** | — | No skin | Toast skin shared with AlertFrame | P2 | 09_loot |
| Blizzard_FrameXML | Bonus roll & loot history | BonusRollFrame, GroupLootHistoryFrame | **none** | — | No skin | Restyle only | P2 | 09_loot |
| Blizzard_EncounterWarnings | Boss warnings (12.x) | EncounterWarningsFrame | **none** | — | Text/banner restyle missing | Font + backdrop only; never filter warnings | P2 |  |
| Blizzard_DelvesCompanionConfiguration, Blizzard_DelvesDifficultyPicker, Blizzard_DelvesToast | Delves companion & difficulty | DelvesCompanionConfigurationFrame, DelvesDifficultyPickerFrame | **none** | — | No skin | Trait nodes reuse talent node skin | P2 |  |
| Blizzard_EditMode | Edit Mode | EditModeManagerFrame, system settings dialog | **none** | Chat/Studio link only | No skin | Taint-critical: chrome only, opt-in | P2 | 22_more_windows |
| Blizzard_GenericTraitUI | Generic trait trees (e.g. Delves, Skyriding) | GenericTraitFrame | **none** | Mover only | No skin | Reuse talent node skin | P2 |  |
| Blizzard_HousingDashboard, Blizzard_HouseList, Blizzard_HousingBulletinBoard, Blizzard_HousingCornerstone, Blizzard_HousingHouseFinder, B… | Player housing (12.x) | HousingDashboardFrame, house finder, market cart, editor | **none** | Mover only (dashboard) | No skin | Editor is a special camera mode: leave stock; skin dashboard/finder/catalog | P2 | 22_more_windows |
| Blizzard_MajorFactions, Blizzard_ExpansionLandingPage | Renown & expansion summary | MajorFactionRenownFrame, ExpansionLandingPage | **none** | Minimap button only | No skin | Shell + cards | P2 |  |
| Blizzard_ItemSocketingUI, Blizzard_ItemUpgradeUI, Blizzard_ItemInteractionUI, Blizzard_ScrappingMachineUI, Blizzard_ReforgingUI | Socketing, upgrades, catalyst/interaction, scrapping | ItemSocketingFrame, ItemUpgradeFrame, ItemInteractionFrame | **none** | Mover only | No skin | Shell + slot textures | P2 |  |
| Blizzard_UIWidgets, Blizzard_SharedWidgetFrames | Top-centre widgets, alt power | UIWidgetTopCenterContainerFrame, PlayerPowerBarAlt | **none** | Movers only | Widget art not themed | Many widget templates: hook UIWidgetManager widget setup, restyle known templates, skip unknown | P2 |  |
| Blizzard_ArchaeologyUI | Archaeology | ArchaeologyFrame | **none** | — | No skin | Shell only | P3 |  |
| Blizzard_BarbershopUI, Blizzard_CharacterCustomize, Blizzard_CustomizationUI | Barbershop | BarberShopFrame | **none** | — | No skin | Fullscreen customise mode: restyle buttons only | P3 |  |
| Blizzard_BlackMarketUI | Black market | BlackMarketFrame | **none** | — | No skin | Bid is hardware-only | P3 |  |
| Blizzard_MirrorTimer | Breath/fatigue timers | MirrorTimerContainer | **none** | Movers only | Bars not restyled | StatusBar texture swap only | P3 |  |
| Blizzard_ChatBubble | Chat bubbles | C_ChatBubbles frames | **none** | — | No bubble skin | Bubbles are forbidden in instances: skin only in the open world, skip forbidden frames (IsForbidden) | P3 |  |
| Blizzard_Channels, Blizzard_VoiceToggleButton | Chat channels & voice | ChannelFrame | **none** | Mover only | No skin | Voice transcription window never touched | P3 |  |
| Blizzard_TrainerUI | Class/profession trainer | ClassTrainerFrame | **none** | Mover only | No skin | Shell + list rows | P3 |  |
| Blizzard_ClickBindingUI | Click casting | ClickBindingFrame | **none** | — | No skin | Bindings saved by Blizzard: shell only | P3 |  |
| Blizzard_ColorPickerFrame | Colour picker | ColorPickerFrame | **none** | Options uses it | No skin | Shell only | P3 |  |
| Blizzard_DurabilityFrame | Durability doll | DurabilityFrame | **none** | Movers only | Not restyled (Character panel shows durability) | Hide/replace with HUD block | P3 |  |
| Blizzard_FlightMap | Flight map | FlightMapFrame | **none** | Mover only | No skin | Shell only; pins untouched | P3 |  |
| Blizzard_HelpFrame, Blizzard_ReportFrame, Blizzard_ReportFrameShared | Help / report player | HelpFrame, ReportFrame | **none** | Mover only | No skin | Report submit is protected: shell only | P3 |  |
| Blizzard_CovenantRenown, Blizzard_CovenantSanctum, Blizzard_CovenantPreviewUI, Blizzard_CovenantToasts, Blizzard_CovenantCallings, Blizza… | Legacy content windows (Shadowlands, BfA, Legion, WoD, Remix, Trading Post…) | various | **none** | — | No skin | Shell-only generic pack (one primitive set covers most) | P3 |  |
| Blizzard_MatchmakingQueueDisplay | Matchmaking queue display | — | **none** | — | No skin | Shell only | P3 |  |
| Blizzard_PetBattleUI | Pet battle UI | PetBattleFrame | **none** | — | No skin | Fullscreen; restyle bars only | P3 |  |
| Blizzard_StableUI | Pet stable | StableFrame | **none** | Mover only | No skin | Shell + list | P3 |  |
| Blizzard_PingUI | Ping wheel | PingFrame | **none** | — | No skin | Protected input: textures only | P3 |  |
| Blizzard_PlayerChoice | Player choice popups | PlayerChoiceFrame | **none** | — | No skin | Choice buttons Blizzard | P3 |  |
| Blizzard_Plunderstorm, Blizzard_PlunderstormBasics, Blizzard_PlunderstormPrematchUI, Blizzard_GameModeSelect | Plunderstorm / game modes | various | **none** | — | Event mode | Shell only when active | P3 |  |
| Blizzard_RaidWarning | Raid warning / boss emote text | RaidWarningFrame, RaidBossEmoteFrame | **none** | Movers only | Font, shadow, colour not themed | Font object swap only | P3 |  |
| Blizzard_SpectateFrame, Blizzard_Commentator | Spectator / commentator | SpectateFrame | **none** | — | Low value | Shell only | P3 |  |
| Blizzard_Subtitles, Blizzard_Narration | Subtitles | SubtitlesFrame | **none** | — | No skin | Font only | P3 |  |
| Blizzard_TutorialManager, Blizzard_Tutorials, Blizzard_TutorialTemplates, Blizzard_HelpPlate, Blizzard_NewPlayerExperience, Blizzard_NewP… | Tutorial pointers, help plates | HelpTip pool | **none** | — | No skin | Restyle HelpTip pool or allow hiding | P3 |  |
| Blizzard_TokenUI, Blizzard_WowTokenUI | WoW token | TokenFrame popups | **none** | — | No skin | Purchases secure | P3 |  |
| Blizzard_WorldLootObjectList | World loot object list (12.x) | WorldLootObjectList | **none** | — | No skin | Shell + rows | P3 |  |
| Blizzard_BattlefieldMap | Zone map | BattlefieldMapFrame | **none** | — | No skin | Shell only | P3 |  |
| Blizzard_CatalogShop, Blizzard_CatalogShopRefundFlow, Blizzard_CatalogShopSharedTemplates, Blizzard_CatalogShopSharedUtil, Blizzard_Catal… | In-game shop | StoreFrame, CatalogShopFrame | **none** | — | Not skinnable | <b>Restricted:</b> runs in a secure/isolated environment (SecureTransfer, forbidden frames). Workaround: none; leave stock, theme only the button that opens it | — |  |
| Blizzard_SecureTransferUI, Blizzard_AuthChallengeUI, Blizzard_FullscreenBrowser, Blizzard_WowSurveyUI, Blizzard_CodeOfConduct, Blizzard_K… | Secure/legal dialogs | various | **none** | — | Not skinnable | <b>Restricted</b> (forbidden/secure): leave stock | — |  |
| Blizzard_AchievementUI | Achievements | AchievementFrame | **partial** | Skins achievements | Category tree, cards, stats, comparison | Load-on-demand; pooled cards | P1 | 15_achievements |
| Blizzard_EncounterJournal | Adventure guide | EncounterJournal | **partial** | Skins adventureGuide | Instance tiles, bosses, abilities, loot, journeys | Lazy headers; no EJ_Select* from skins | P1 | 16_encounter_journal |
| Blizzard_AuctionHouseUI | Auction House | AuctionHouseFrame | **partial** | Skins auctionHouse | Categories, result tables, buy/sell panels | Purchases hardware-only; never automated | P1 | 13_auction_house |
| Blizzard_UIPanels_Game | Character (paperdoll, reputation, currency) | CharacterFrame, PaperDollFrame, ReputationFrame, TokenFrame | **partial** | Skins character | Slots, stats, model, sidebar, rep/currency rows | Slots not protected but never moved; hooksecurefunc PaperDollItemSlotButton_Update | P1 | 01_character |
| Blizzard_FriendsFrame, Blizzard_AddFriend, Blizzard_QuickJoin, Blizzard_RecentAllies, Blizzard_RecruitAFriend, Blizzard_SocialUI, Blizzar… | Friends, Who, Raid tab, Quick Join, recent allies | FriendsFrame, AddFriendFrame, QuickJoinFrame, RecruitAFriendFrame | **partial** | Friends module (row skin only) | FriendsFrame shell NOT in Skins packs; Who/Raid/QuickJoin tabs | Rows via FriendsFrame_UpdateFriendButton post-hook; never remove rows | P1 | 08_friends |
| Blizzard_GroupFinder, Blizzard_LFGUtil | Group Finder (dungeons, raids, premade, M+, delves) | PVEFrame, LFGListFrame, LFGDungeonReadyDialog, LFGInvitePopup | **partial** | Skins groupFinder + GroupFinder module rows + QueueTimer | Category buttons, role checks, ready dialog chrome, list rows art | Sign up / accept protected (hardware); free text not writable | P1 | 07_group_finder |
| Blizzard_ItemButton, Blizzard_HUDInventoryTemplates | Item button template | ItemButtonTemplate | **partial** | Vault slots | Global quality-border style not applied to Blizzard item buttons outside Vault | Hook SetItemButtonQuality post-call, restyle border texture | P1 |  |
| Blizzard_UIPanels_Game | Loot window | LootFrame | **partial** | Skins loot | Rows, quality, Loot all | — | P1 | 09_loot |
| Blizzard_MailFrame | Mail | MailFrame, OpenMailFrame, SendMailFrame | **partial** | Skins mail | Inbox rows, open/send frames | Server-throttled take; Ticker queue | P1 | 12_mail |
| Blizzard_UIPanels_Game | Merchant | MerchantFrame | **partial** | Skins merchant | Item rows, prices, repair | Restyle pooled buttons on MerchantFrame_UpdateMerchantInfo | P1 | 11_merchant |
| Blizzard_Collections | Mounts, pets, toys, heirlooms, appearances, campsites, warband scenes | CollectionsJournal, WardrobeCollectionFrame | **partial** | Skins collections | List rows, model scenes, tiles, appearance grid, filters | Toys are secure buttons; ScrollBox initializer hooks; model backdrop only | P1 | 04, 05 |
| Blizzard_Professions, Blizzard_ProfessionsTemplates, Blizzard_ProfessionsBook, Blizzard_ProfessionsCustomerOrders | Professions, profession book, customer orders | ProfessionsFrame, ProfessionsBookFrame, ProfessionsCustomerOrdersFrame | **partial** | Skins professions | Recipe list, schematic, spec tree, orders, book | Craft only via Blizzard button | P1 | 14_professions |
| Blizzard_UIPanelTemplates, Blizzard_SharedXML, Blizzard_FrameXMLBase | Shared templates (buttons, scrollbars, dropdowns, checkboxes, edit boxes) | UIPanelButtonTemplate, MinimalScrollBar, WowStyle1Dropdown, UICheckButton, InputBoxTemplate | **partial** | Skins primitives (buttons with Left/Middle/Right only) | Scrollbars, dropdowns, checkboxes, edit boxes, search boxes, sliders not covered by any primitive | Template-level primitives applied per pack; never modify the template mixins | P1 | 23_theme_system |
| Blizzard_PlayerSpells, Blizzard_SharedTalentUI, Blizzard_SpellSearch, Blizzard_TalentUI | Spellbook, talents, specialization | PlayerSpellsFrame (+ SpellBookFrame/PlayerTalentFrame on Forever) | **partial** | Skins spellbook | Spell cards, tree nodes, edges, spec cards, apply bar | Taint-critical: textures/fonts only on pooled nodes, never call frame methods, never in combat | P1 | 02_spellbook, 03_talents |
| Blizzard_GameTooltip | Tooltips | GameTooltip, ItemRefTooltip, ShoppingTooltip1/2, EmbeddedItemTooltip | **partial** | HUD Tooltip | GameTooltip full; ItemRef/Shopping/Embedded/BattlePet tooltips IDs only, no skin | TooltipDataProcessor post-calls; secret values to FontStrings; NineSlice alpha + Phoenix texture | P1 | 21_tooltips |
| Blizzard_Transmog, Blizzard_TransmogShared | Transmog (12.x), dressing room | TransmogFrame, DressUpFrame | **partial** | Skins transmog, dressingRoom | Slot rail, appearance grid, outfits, situations | Apply stays Blizzard; keys read at runtime | P1 | 06_transmog |
| Blizzard_WorldMap, Blizzard_MapCanvas, Blizzard_SharedMapDataProviders, Blizzard_QuestNavigation, Blizzard_POIButton | World map & quest log | WorldMapFrame, QuestMapFrame | **partial** | Skins map (+ QuestTracker owns tracker) | Quest log rows, map buttons, detail pane | Taint-sensitive pins: never add providers/touch pins | P1 | 17_map_quest_log |
| Blizzard_ActionBar, Blizzard_ActionBarController, Blizzard_OverrideActionBar, Blizzard_ZoneAbility, Blizzard_Flyout | Action bars, vehicle/override bar, extra/zone ability, flyouts | MainActionBar, MultiBar*, OverrideActionBar, ExtraActionButton1, ZoneAbilityFrame, SpellFlyout | **partial** | ActionBars | Override/vehicle bar art and SpellFlyout background not restyled | Secure action buttons: restyle textures only; never move ExtraActionButton in combat | P2 |  |
| Blizzard_Calendar | Calendar | CalendarFrame, CalendarViewEventFrame, CalendarCreateEventFrame | **partial** | Skins calendar | Day buttons, event frames | Fixed global day buttons | P2 | 18_calendar |
| Blizzard_UIPanels_Game | Gossip & quest dialogs | GossipFrame, QuestFrame | **partial** | Skins gossip | Option rows, reward tiles, greeting text | — | P2 | 22_more_windows |
| Blizzard_WeeklyRewards | Great Vault | WeeklyRewardsFrame | **partial** | Skins greatVault | Reward cards | Claim stays Blizzard | P2 | 22_more_windows |
| Blizzard_Communities, Blizzard_CommunitiesSecure, Blizzard_GuildControlUI, Blizzard_GuildRename | Guild & communities | CommunitiesFrame, GuildControlUI | **partial** | Skins guild | Club list, chat pane, roster, info, finder | Blizzard_CommunitiesSecure frames never touched | P2 | 19_guild_communities |
| Blizzard_GuildBankUI | Guild bank | GuildBankFrame | **partial** | Vault (read-only view) | Blizzard window unskinned | Restyle slot textures on update | P2 | 10_bags_bank |
| Blizzard_InspectUI | Inspect | InspectFrame | **partial** | Skins inspect | Slots, talents tab, PvP tab | Same as Character | P2 | 01_character |
| Blizzard_ChallengesUI | Mythic+ tab, keystone insert | ChallengesFrame, ChallengesKeystoneFrame | **partial** | groupFinder shell (tab) | Dungeon icons, affix row, keystone slot frame | Keystone slot: restyle only | P2 |  |
| Blizzard_Settings, Blizzard_Settings_Shared, Blizzard_SettingsDefinitions_Frame, Blizzard_SettingsDefinitions_Shared | Options / keybindings | SettingsPanel | **partial** | Skins settings | Category list, controls | Never hook control callbacks | P2 | 22_more_windows |
| Blizzard_PVPUI, Blizzard_PVPMatch, Blizzard_EndOfMatchUI | PvP tabs, scoreboard, results | PVPUIFrame (in PVEFrame), PVPMatchScoreboard, PVPMatchResults | **partial** | PvP module (data) + groupFinder shell | Rated cards art, scoreboard and results windows unskinned | Scores secret in match: widgets only | P2 | 07_group_finder |
| Blizzard_FrameXML | Ready check | ReadyCheckFrame | **partial** | Skins readyCheck | Buttons/countdown | Ready buttons are Blizzard; restyle only | P2 | 20_game_menu_popups |
| Blizzard_AddOnList, Blizzard_AddOnPerformance | AddOn list & performance | AddonList | **partial** | Skins addonList | Rows, checkboxes | — | P3 | 22_more_windows |
| Blizzard_LevelUpDisplay, Blizzard_MatchCelebrationPartyPoseUI, Blizzard_PartyPoseUI, Blizzard_IslandsPartyPoseUI, Blizzard_WarfrontsParty… | Level-up, party pose banners | LevelUpDisplay, BossBanner | **partial** | Flow Extras (hide/shorten) | No theme | — | P3 |  |
| Blizzard_MacroUI | Macros | MacroFrame | **partial** | Skins macros | Macro slots, edit box | — | P3 |  |
| Blizzard_Minimap, Blizzard_HybridMinimap, Blizzard_TimeManager | Minimap, clock, stopwatch | MinimapCluster, TimeManagerFrame, StopwatchFrame | **partial** | HUD Minimap | TimeManagerFrame (alarm) and stopwatch windows not skinned | — | P3 |  |
| Blizzard_MoneyFrame, Blizzard_MoneyReceipt | Money display | MoneyFrame templates | **partial** | Vault/Merchant designs | Template not themed globally | Font swap only | P3 |  |
| Blizzard_QueueStatusFrame | Queue status | QueueStatusButton, QueueStatusFrame | **partial** | HUD ButtonBin / Minimap eye | Status flyout unskinned | — | P3 |  |
| Blizzard_UIPanels_Game | Trade | TradeFrame | **partial** | Skins trade | Slots | Accept protected | P3 |  |
| Blizzard_UIErrorsFrame | UI error text | UIErrorsFrame | **partial** | Flow (filter) | Font not themed | Font object swap only | P3 |  |
| Blizzard_PrivateAurasUI | Private auras | PrivateAura anchors | **partial** | UnitFrames/RaidFrames anchors | Blizzard draws them | Restricted: content is Blizzard-only; Phoenix positions anchors + sound | — |  |
| Blizzard_ChatFrame, Blizzard_ChatFrameBase, Blizzard_ChatFrameUtil | Chat windows | ChatFrame1-10, edit box, tabs | **full** | Chat | Channel pane (Blizzard_Channels) and voice chat panel unskinned | Window 1 owned by Edit Mode; secret chat lines passed through untouched | P3 |  |
| Blizzard_CompactRaidFrames, Blizzard_CUFProfiles, Blizzard_RaidFrame | Party/raid frames | CompactPartyFrame, CompactRaidFrameContainer, PartyFrame | **full** | RaidFrames | Blizzard raid-frame manager panel (side tab) unskinned | Secure group headers; manager hidden only out of combat | P3 |  |
| Blizzard_Deprecated_ArenaUI | Arena frames | CompactArenaFrame | **full** | Arena | — | — | — |  |
| Blizzard_FrameXML, Blizzard_UIPanels_Game | Bags & bank | ContainerFrame1-13, ContainerFrameCombinedBags, BankFrame, AccountBankPanel | **full** | Vault | — | Secure item buttons kept (ContainerFrameItemButtonTemplate) | — | 10_bags_bank |
| Blizzard_EncounterTimeline | Boss timeline (12.x) | EncounterTimeline | **full** | Pulse | — | Encounter data may be secret: widgets only | — |  |
| Blizzard_CooldownViewer | Cooldown manager | EssentialCooldownViewer, UtilityCooldownViewer, Buff*Viewer | **full** | CooldownManager | — | Blizzard viewer data; restyle only | — |  |
| Blizzard_DamageMeter, Blizzard_DeathRecap | Damage meter, death recap | DamageMeter windows, DeathRecapFrame | **full** | Embers (own windows from C_DamageMeter) + Recap | Blizzard meter window restyle (t86u) is planned in feat/gaps | Blizzard counts, Phoenix draws; no combat log | — |  |
| Blizzard_CombatText | Floating combat text | CombatText | **full** | Spark (own SCT) | — | — | — |  |
| Blizzard_ScriptErrors, Blizzard_ScriptErrorsFrame | Lua error frame | ScriptErrorsFrame | **full** | Sentinel (own viewer) | — | — | — |  |
| Blizzard_MicroMenu, Blizzard_MainMenuBarBagButtons | Micro menu, bag bar | MicroMenuContainer, BagsBar | **full** | ActionBars (Extras), Vault | — | Micro buttons are Blizzard buttons: restyle/reposition out of combat only | — |  |
| Blizzard_NamePlates | Nameplates | NamePlate* (C_NamePlate) | **full** | Nameplates | — | Forbidden friendly plates in instances: name-only via CVars; secret values straight to widgets | — |  |
| Blizzard_ObjectiveTracker, Blizzard_QuestTimer | Objective / quest tracker | ObjectiveTrackerFrame | **full** | QuestTracker | — | Blizzard tracker switched off via SetCanAddModules(false), restored on disable | — |  |
| Blizzard_PersonalResourceDisplay | Personal resource display | PersonalResourceDisplayFrame | **full** | ResourceBars (own bars) | — | — | — |  |
| Blizzard_BuffFrame | Player buffs/debuffs | BuffFrame, DebuffFrame | **full** | UnitFrames (AuraBars) | — | Cancel aura is protected: Phoenix uses secure aura header buttons | — |  |
| Blizzard_UnitFrame | Player/target/focus/pet/boss unit frames | PlayerFrame, TargetFrame, FocusFrame, Boss1-5TargetFrame | **full** | UnitFrames | — | Secure unit buttons: Phoenix own SecureUnitButton frames; Blizzard frames hidden via ledger, never in combat | — |  |
| Blizzard_Dispatcher, Blizzard_SpellDiminishUI | Spell DR display (12.x Blizzard DR) | SpellDiminish | **full** | Arena (restyles Blizzard DR, opt-in) | — | CVar-driven Blizzard DR, restyled | — |  |
| Blizzard_FrameXML | XP/rep bars | MainStatusTrackingBarContainer | **full** | HUD DataBars | — | — | — |  |

Counts: **17 full · 37 partial · 43 none** (of the none: 2 restricted, can't be skinned).

### Not applicable (no in-game window to theme): 108
`Blizzard_APIDocumentation`, `Blizzard_APIDocumentationGenerated`, `Blizzard_AccessibilityTemplates`, `Blizzard_AccountSaveUI`, `Blizzard_ActionStatus`, `Blizzard_AnimatedShine`, `Blizzard_ArrowCalloutFrame`, `Blizzard_AsyncRequest`, `Blizzard_AuraContainer`, `Blizzard_AutoComplete`, `Blizzard_AutoCompletePopupList`, `Blizzard_BNet`, `Blizzard_BehavioralMessaging`, `Blizzard_ButtonPulse`, `Blizzard_ClassMenu`, `Blizzard_ClientSavedVariables`, `Blizzard_ClientSceneVisManager`, `Blizzard_Colors`, `Blizzard_CombatAudioAlerts`, `Blizzard_CombatLog`, `Blizzard_CombatLogBase`, `Blizzard_CombatLogProcessor`, `Blizzard_CommandLineUtil`, `Blizzard_Console`, `Blizzard_ContentTracking`, `Blizzard_CooldownBroadcaster`, `Blizzard_DebugTools`, `Blizzard_DebugUtil`, `Blizzard_DeclensionFrame`, `Blizzard_DeclensionFrameGlue`, `Blizzard_Deprecated`, `Blizzard_DeprecatedActionBar`, `Blizzard_DeprecatedAuraFilters`, `Blizzard_DeprecatedAutoComplete`, `Blizzard_DeprecatedBattleNet`, `Blizzard_DeprecatedChatInfo`, `Blizzard_DeprecatedCombatLog`, `Blizzard_DeprecatedGuildScript`, `Blizzard_DeprecatedInstanceEncounter`, `Blizzard_DeprecatedPartyInfo`, `Blizzard_DeprecatedRaidWarning`, `Blizzard_DeprecatedSpecialization`, `Blizzard_DeprecatedSpellBook`, `Blizzard_DeprecatedSpellScript`, `Blizzard_DeprecatedUnitScript`, `Blizzard_EnvironmentCleanup`, `Blizzard_EventTrace`, `Blizzard_Fonts_Shared`, `Blizzard_FrameEffects`, `Blizzard_FrameStack`, `Blizzard_FrameXMLUtil`, `Blizzard_FramerateFrame`, `Blizzard_GMChatUI`, `Blizzard_Game`, `Blizzard_GlobalFXModelScenes`, `Blizzard_GlueSavedVariables`, `Blizzard_GlueXMLBase`, `Blizzard_HardcoreUI`, `Blizzard_IME`, `Blizzard_LoadLocale`, `Blizzard_ManagedFrameSystem`, `Blizzard_MapCanvasSecureUtil`, `Blizzard_MovePad`, `Blizzard_Notification`, `Blizzard_ObjectAPI`, `Blizzard_PTRFeedback`, `Blizzard_PTRFeedbackGlue`, `Blizzard_PagedContent`, `Blizzard_PerformanceBar`, `Blizzard_PrintHandler`, `Blizzard_ProjectConstants`, `Blizzard_QuickKeybind`, `Blizzard_RPE_TurnStrafe`, `Blizzard_RestrictedAddOnEnvironment`, `Blizzard_SavedSets`, `Blizzard_SelectorUI`, `Blizzard_ShakeUtil`, `Blizzard_SharedXMLBase`, `Blizzard_SharedXMLGame`, `Blizzard_SocialUIShared`, `Blizzard_SpellPickUpIndicator`, `Blizzard_StatusTrayManager`, `Blizzard_StatusUI`, `Blizzard_TextStatusBar`, `Blizzard_TimerunningUtil`, `Blizzard_TransformManipulator`, `Blizzard_TransformTree`, `Blizzard_UIFrameManager`, `Blizzard_UIModes`, `Blizzard_UIParent`, `Blizzard_UIParentPanelManager`, `Blizzard_UIParentUtil`, `Blizzard_VisualAlerts`, `Blizzard_WeeklyRewardsUtil`, `Deprecated_PaperDoll`, `middleclass`  (libraries, shims, deprecated, dev tools)

Glue / login screen: `Blizzard_CharacterCreate`, `Blizzard_CharacterSelectNavBar`, `Blizzard_GlueCollections`, `Blizzard_GlueMenuFrame`, `Blizzard_GlueParent`, `Blizzard_GlueStubs`, `Blizzard_GlueXML`, `Blizzard_LoginWarningDialogs`, `Blizzard_ReportFrameGlue`, `Blizzard_SplashFrame`, `Blizzard_StaticPopup_Glue`, `Blizzard_TimerunningCharacterCreate` (out of scope: addons do not load at the login screen).

## 4. Top gaps (by how often the player sees them)

1. **Shared controls everywhere:** scroll bars (`MinimalScrollBar`), dropdowns (`WowStyle1DropdownTemplate`), checkboxes, edit/search boxes, sliders, and the item-button quality border (`SetItemButtonQuality`). Adding these as primitives lifts all 25 packs at once.
1. **Game Menu and StaticPopups:** none today. They appear on every Esc press and every confirm prompt.
1. **Loot:** group roll frames, alert toasts (loot, achievement, mount, currency, world quest), bonus roll, loot history and Battle.net toasts. None are skinned today.
1. **FriendsFrame shell:** missing from the Skins list. Only the rows are styled, by the Friends module. The Who, Raid and Quick Join tabs are stock.
1. **Right-click context menus (Blizzard_Menu / UnitPopup):** none.
1. **Window content in the 25 packs:** character slots and stats, spell cards, talent nodes and edges, collection rows and tiles, transmog grid, group finder rows, merchant rows, mail rows, AH tables, profession schematic, achievement cards, journal ability headers, quest log rows, calendar day buttons, roster.
1. **Tooltips beyond GameTooltip:** ItemRefTooltip, shopping/compare tooltips, embedded and battle-pet tooltips.
1. **12.x surfaces with no pack:** Housing (dashboard, finder, market cart), Delves (companion, difficulty picker), Encounter Warnings, Edit Mode chrome, renown and expansion summary, socketing, upgrades, catalyst, generic trait trees.
1. **Phoenix media not used by Skins:** the nine-slice, panel and button art already exists in Phoenix_UI_Media. Skins draws flat colour instead.
1. **Skins is off by default.** Once the content primitives exist, turning it on at first install should be put to the user as a choice (Ember everywhere vs. Phoenix frames on Blizzard windows).

## 5. Restrictions and the workaround for each (standing rule: always work around)

| Restriction | Where | Workaround (no taint) |
|---|---|---|
| Protected/secure buttons (spell, toy, action, item slots, Game Menu logout/exit, accept/sign-up, AH buy, craft) | Spellbook, collections toys, bags, Game Menu, LFG, AH, professions | Never reparent, move, `SetAttribute`, call or click them. Restyle textures and fonts only, from `hooksecurefunc` post-hooks on the Blizzard update or initializer function. Applied out of combat through CombatQueue. |
| Taint-critical windows | Talents, Edit Mode, world map pins, Settings controls | Nothing written into Blizzard tables (weak side tables only). Never call frame methods (`EJ_Select*`, `EditModeManagerFrame:*`, talent commits) from a skin. Edit Mode chrome is opt-in. Map pins and data providers are never touched. |
| StaticPopupDialogs taint | Popups | Never write `StaticPopupDialogs` and never call `StaticPopup_Show` from a skin. Hook the popup frames' OnShow (12.x pool) and restyle their textures. |
| Secret values (12.x) | Tooltips, chat, PvP scoreboard, encounter data, nameplates | Pass values straight to FontStrings and StatusBars. Never compare, concatenate or use them as keys. |
| Forbidden frames | Chat bubbles in instances, friendly nameplates in instances | Check `IsForbidden()` and skip. Skin bubbles in the open world only. |
| Secure or isolated environments | Shop (CatalogShop/StoreUI/AccountStore), SecureTransfer, auth, Blizzard_CommunitiesSecure parts | Not skinnable. Leave them stock and theme only the button that opens them. In Communities, skin only the outer frame and lists. |
| Hardware-event-only actions | LFG sign-up, AH purchase, bid, accept invite/resurrect | Never automated. Phoenix only restyles Blizzard's own button. |
| 3D model scenes | Character, collections, transmog, journal, housing | The inside of the model cannot be restyled. Fade Blizzard's backdrop and put the Phoenix `Skin_ModelBackdrop_Ember` texture behind it. |
| Load-on-demand windows | Most Blizzard_* windows | Apply on `ADDON_LOADED`. Hook lazily created children (journal headers, roll frames, toasts) at their creation function. |
| Blizzard changes frame keys between builds | Transmog (new in 12.x), housing | Read keys at runtime. A missing key is skipped, and `securecallfunction` contains errors: the pack reverts itself and Sentinel logs it. |

## 6. Build plan (stacked on the current stack after feat/gaps; nothing started)

1. **S1 · Primitive kit v2**: New primitives: `scrollbar`, `dropdown`, `checkbox`, `editbox/search`, `slider`, `itemButton` (quality border), `list` (ScrollBox element-initializer hook helper), `modelBackdrop` and `nineSlice` (uses the Phoenix Panel/Card/Button nine-slices). Each one records its originals and reverts exactly. Tests: apply/revert round trip on the harness stubs.
2. **S2 · Everyday chrome**: Game Menu (InitButtons hook), StaticPopup pool, context menus (Menu), all tooltip families, the ready/role check, LFG proposal and the PvP ready dialog.
3. **S3 · Loot**: Roll frames, AlertFrame toasts (every subsystem), bonus roll, loot history, BN toasts, plus a deeper loot window.
4. **S4 · Content depth for the 25 packs (P1 windows first)**: Character/Inspect, Spellbook/Talents, Collections, Transmog, Group Finder/PvP/M+, Friends (add the shell pack), Merchant, Mail, AH, Professions (+book, orders), Achievements, Journal, Map/Quest log. One `extra` function per pack, from the mockups.
5. **S5 · New packs**: Housing (dashboard, finder, cart), Delves, renown/landing page, socketing/upgrade/catalyst/scrapping, generic traits, guild bank, trainer, stable, barbershop buttons, flight/zone map, time manager, channels, Encounter Warnings and raid-warning fonts, UI widgets, mirror timers, Edit Mode chrome (opt-in), plus a generic shell-only pack for the legacy content windows.
6. **S6 · Whole-suite polish**: A single "Phoenix everywhere" switch with per-window toggles (simple view: one switch; advanced view: per-window toggles, density, card style, glow, fonts). Live preview on the Skins page with before/after thumbnails. Default stays the user's choice (ask). The in-game check list goes in docs/INGAME_CHECKS.md.

The hard rules apply to every step: original code only, every setting applies live, no OnUpdate outside the Ticker registry, secrets go to widgets only, and a step is done only when the guardrails and `/pui test` pass and it has been verified in game.

## 7. Media plan

Everything is either original Phoenix work or openly licensed with its source and licence recorded. Nothing is copied from Blizzard, EllesmereUI, ElvUI, WindTools or any other addon.

| Asset | Status | Source / licence |
|---|---|---|
| 30 window-category icons (SVG, 24 grid, 1.6 stroke): character, spellbook, talents, collections, mounts, pets, toys, heirlooms, transmog, groupfinder, social, loot, bags, merchant, mail, auction, professions, achievements, journal, map, calendar, guild, menu, tooltip, pvp, vault, housing, editmode, popup, readycheck | **New (proposed)**, in `/workspace/pui_mockups/skins/media/svg/` | Original Phoenix UI work (VortexQ8), All Rights Reserved. Rasterise to white TGA (64/128) for the client. |
| 22 skin textures: EmberGlass panel, title bar, R10 border, soft shadow, slot quality frame, empty slot, 6 button states, tab underline, ember hairline, scroll thumb, toast wash, model backdrop, divider, check box/mark, radio, status orb | **New (proposed)**, in `/workspace/pui_mockups/skins/media/textures/` (PNG + TGA), generated by `src/tex.py` | Original procedural Phoenix work. White tintable masters, so the accent and quality colours drive the final colour. |
| Phoenix nine-slices, panels, controls, logo, module, class, role, ability and emoji icons | Existing in Phoenix_UI_Media | Original Phoenix work (per LICENSES.md) |
| 83 glyph icons | Existing | game-icons.net, CC BY 3.0 (zeromancer: CC0), attributed in LICENSES.md |
| Fonts: Rajdhani (headers), Inter (body), JetBrains Mono (numbers), Cinzel/Marcellus (classic option), Noto Sans Arabic/JP/KR/SC | Existing | Google Fonts, SIL OFL 1.1 (Licenses/*-OFL.txt) |
| Sounds | Existing | Kenney, CC0 1.0 |
| Anything from Blizzard art, EllesmereUI, ElvUI, other addons | **Never** | — |

When the media is adopted, every new file gets a `manifest.json` entry (source, author, licence) so the CI licence check passes.

## 8. Mockups (1600×1000 PNG, Ember theme, original CSS art + Phoenix media)

- `/workspace/pui_mockups/skins/00_contact_sheet.png`
- `/workspace/pui_mockups/skins/01_character.png`
- `/workspace/pui_mockups/skins/02_spellbook.png`
- `/workspace/pui_mockups/skins/03_talents.png`
- `/workspace/pui_mockups/skins/04_collections_mounts_pets.png`
- `/workspace/pui_mockups/skins/05_collections_toys_heirlooms_appearances.png`
- `/workspace/pui_mockups/skins/06_transmog.png`
- `/workspace/pui_mockups/skins/07_group_finder.png`
- `/workspace/pui_mockups/skins/08_friends.png`
- `/workspace/pui_mockups/skins/09_loot.png`
- `/workspace/pui_mockups/skins/10_bags_bank.png`
- `/workspace/pui_mockups/skins/11_merchant.png`
- `/workspace/pui_mockups/skins/12_mail.png`
- `/workspace/pui_mockups/skins/13_auction_house.png`
- `/workspace/pui_mockups/skins/14_professions.png`
- `/workspace/pui_mockups/skins/15_achievements.png`
- `/workspace/pui_mockups/skins/16_encounter_journal.png`
- `/workspace/pui_mockups/skins/17_map_quest_log.png`
- `/workspace/pui_mockups/skins/18_calendar.png`
- `/workspace/pui_mockups/skins/19_guild_communities.png`
- `/workspace/pui_mockups/skins/20_game_menu_popups.png`
- `/workspace/pui_mockups/skins/21_tooltips.png`
- `/workspace/pui_mockups/skins/22_more_windows.png`
- `/workspace/pui_mockups/skins/23_theme_system.png`
- `/workspace/pui_mockups/skins/24_media_sheet.png`

The sources are in `/workspace/pui_mockups/skins/src/` (`sk.py` is the kit; `m01.py`–`m08.py`, `svg.py` and `tex.py` build the pages, the SVGs and the textures). Render with headless Chrome.
