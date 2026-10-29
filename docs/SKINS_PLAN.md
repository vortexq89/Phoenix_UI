# Phoenix skins plan: Blizzard windows in the Phoenix theme (plan only, no code yet)

Request t121u: every Blizzard window restyled end to end in the Phoenix design, following the accent colour
live, with dedicated designs per window. This plan builds on the approved mockups in `pui_mockups/skins`
(pages 01–24, the v2 "Blizzard layouts" round: each window keeps Blizzard's layout and is restyled; Ember main,
Midnight/Horde/Alliance variants) and on `SKINS_AUDIT.md` / `SKINS_FEATURE_AUDIT.md`. The existing
`Modules/Skins` already has entries for 24 windows; this plan replaces "partial" coverage with a full design.

## Rules for every skin
- **Original work only.** No code, art or layout data from other addons. Phoenix art is from Phoenix_UI_Media.
- **Game content icons are never changed** (spells, items, currencies, mounts, pets, toys, talents, achievements).
  Only Phoenix's own chrome (menu/micro-menu glyphs, close/cog/search glyphs, frames, borders) may be custom.
- **Taint-safe.** Cosmetic regions only: hide Blizzard textures with `SetAlpha(0)` (or `SetTexture(nil)` on
  non-secure regions), add Phoenix backgrounds as new regions under the frame, never call protected methods,
  never touch secure attributes, never move protected frames in combat (`ns.Combat:Run`). Skins are applied on
  the Blizzard addon's `ADDON_LOADED` (`Blizzard_*`), once per frame, and hooks use `hooksecurefunc` only.
- **Live theme.** Every texture/text a skin adds is painted through `Skin:Register(frame, painter)` and theme
  tokens (`bg.*`, `border.*`, `text.*`, `accent.*`), so a preset or custom accent change repaints every open
  window without /reload. A per-window toggle (Skins page) restores Blizzard's look after /reload only where
  textures were removed (documented per window).
- **Shared kit, dedicated layouts.** Common pieces: title bar (portrait corner kept, centred title, close +
  cog), tab strip (top / bottom / side rail), list row, card, grid cell, progress bar, modal, search field,
  scrollbar, dropdown, checkbox, footer bar. Each window then gets its own composition (below).
- **Quality.** 1 px borders snapped to the pixel grid, opaque surfaces, text ≥ 12 effective px, outlines only
  on text over art; checked with the dev diagnostics (`/pui dev pages`-style audit extended to skinned
  windows: truncation, overlap, small fonts, icon rule).

## Status
- Phase 1 built (awaiting the in-game checklist), each switch live both ways (no /reload):
  1 Game Menu (`Skins/GameMenu.lua`, with group dividers), 2 Micro menu (`Skins/MicroMenu.lua`),
  3 Chat pill tabs + channel bar (`Chat/Pills.lua`), 4 Bags/bank chrome (`Bags/Chrome.lua`; slots in `Bags.lua`),
  5 World map + quest log (`Skins/WorldMap.lua`) and tracker header ticks (`Quests/Tracker.lua`),
  6 Character slots (`Skins/Character.lua`; stats in ItemLevel), 26 Popups / ready check (`Skins/Popups.lua`;
  tooltips are the Tooltip module's 1 px border with quality and class colours).
- Phase 1 gaps closed: bag category chips (`Bags/Chrome.lua`), reputation and currency lists with search
  (`Skins/CharacterLists.lua`), quest log campaign cards (`Skins/WorldMap.lua`).
- Phase 2 built on the shared kit (`Skins/Kit.lua`: rows, cards, ScrollBox dressing), every switch live both ways:
  7 Group Finder / PvP (`GroupFinder.lua`), 8 Talents & spellbook (`Talents.lua`), 9 Loot & rolls (`Loot.lua`),
  10 Auction House (`Auction.lua`), 11 Professions (`Professions.lua`), 12 Friends (`Friends.lua`),
  13 Guild & communities (`Guild.lua`). Lists are found by their Blizzard paths; a path that a client build
  renames is skipped (no error), so the in-game check is where any missing list shows up.
- Phase 2 details closed: ready-dialog role ring timer, rated PvP cards, premade search chips (your last
  searches), talents loadout bar, Auction House column headers, professions specialization rings, community
  avatar rings. Declined: the spellbook two-column layout (it would re-anchor Blizzard frames, outside the
  taint-safe rules); the spellbook keeps Blizzard's page layout with Phoenix tabs.
- Phase 3 built: 14 Adventure Guide (`Journal.lua`), 15 Achievements, 16 Collections, 17 Transmog, 18 Mail,
  19 Merchant, 20 Great Vault (`Vault.lua`), 21 Calendar. Not in phase 3: the Great Vault progress rings (cards
  are outlined instead), collection favourite stars and filter chips, the Merchant extended-cost layout.
  All three were added after phase 3 (Vault rings, favourite star + mount filter chips, cost cards).
- Phase 4 built: 22 Housing (`Housing.lua`, new switch, cosmetic only), 24 Settings & Edit Mode
  (`Settings.lua`: rail and list rows, Edit Mode dialog, our own accent outline on each system's selection;
  nothing in Edit Mode is moved or saved by us), 27 Gossip/quest (`Gossip.lua`), trade (`Trade.lua`),
  inspect (`Inspect.lua`). 23 Shop: launcher only, the micro menu's Shop tile; `StoreFrame` is never touched
  (harness checks this). Settings, gossip, trade and inspect now switch live.
- Phoenix replacement windows (our own frames fed by the API; Blizzard's window kept open but tucked with
  Skin:Tuck, so Escape and "is it open" checks still work; each has a switch back to the reskinned Blizzard
  window, live, and an arrow button for Blizzard's window this visit): bags (default view now Phoenix, live
  switch), bank (`Bags/Bank.lua`), mail (`Skins/MailWindow.lua`), merchant, friends, achievements, calendar,
  Great Vault, collections (mounts, pets, toys, heirlooms, appearances), Adventure Guide (boss abilities, journeys), loot
  (`Skins/LootWindow.lua`, the only one that also stands in during combat: LootFrame holds no protected child)
  (`Skins/*Window.lua` on the shared `Skins/Replace.lua`). Also own: achievements guild / statistics / summary, calendar
  create event + invite answers, friends Who / ignore / remove, bank tab settings + gold transfer, Character
  (stats, reputation, currency, titles, equipment sets), Guild roster. Partial overlays (`M.Overlay`, our panel over
  one part of a Blizzard window): Professions recipe list (Craft and the details page stay Blizzard's), quest log
  list inside the map (details stay Blizzard's). Group Finder premade apply stays Blizzard's: calling ApplyToGroup or
  touching the secure SearchPanel taints Blizzard's own sign-up (see GROUP_FINDER.md). Still Blizzard's:
  buying bank tabs, the tab icon picker, editing existing calendar events, Raid / Quick Join, Traveler's Log, vault reward pick.
  Protected windows keep the deep reskin.
- 25 PvP: the scoreboard and match results (`PvPMatch.lua`, new switch, live): score table on a sunken card, column
  headers as cells (last sorted in the accent), player rows with a team-coloured bar read back from Blizzard's own row
  art, your row outlined once the match is over, Leave / Requeue as Phoenix buttons. The queue side (honor/conquest
  cards, rating badges) was done in phase 2 with the Group Finder skin. Every window in the plan now has a skin.
- Dev self-test: every list path a window skin looks for inside a loaded window and does not find is reported
  as `skin-missing` (Core/DevDiag.lua), so the overnight loop shows lists that stay unstyled.

## Delivery phases (ordered by how often players open the window)
| Phase | Windows |
|---|---|
| 1 – every session | Game Menu, Micro menu, Chat, Bags/bank, Quest log + map + tracker, Character, Popups/tooltips |
| 2 – most days | Group Finder/PvE/PvP, Talents & Spellbook, Loot, Auction House, Professions, Friends, Guild |
| 3 – weekly | Adventure Guide, Achievements, Collections, Transmog, Mail, Merchant, Great Vault, Calendar |
| 4 – occasional / new | Housing dashboard, Settings & Edit Mode, Gossip/quest/trade/inspect, Shop (launcher only) |

Each window ships as its own commit with: the skin, a harness test (skin applies to a stub frame, adds no
OnUpdate, touches no protected method), an entry on the Skins options page, and its checklist below run in game.

## Windows
### 1. Game Menu (Esc)
- **Frames:** `GameMenuFrame`  · **Mockup:** 20_game_menu_popups
- **Design:** Centred obsidian card, Phoenix emblem header with the accent underline, buttons as full-width rows with a Phoenix line icon on the left (Phoenix-made icons allowed: these are menu icons), grouped Game / Interface / Phoenix / Exit with thin dividers; the Phoenix UI button sits first in its own group.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Esc opens it; every button works (Options, Macros, AddOns, Support, Logout, Exit, Return); the Phoenix button opens settings and closes the menu; no taint warning after using Logout; accent change recolours underline + hover live. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 2. Micro menu
- **Frames:** `MicroMenuContainer / *MicroButton`  · **Mockup:** 20_game_menu_popups
- **Design:** Flat 1px-bordered tiles in a bar, Phoenix custom glyphs per button (character, spellbook, talents, achievements, quests, guild, group finder, collections, adventure guide, shop, housing, help), notification dot and the guild/quest alert in the accent; latency/FPS on the menu button tooltip.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Every tile opens its window; alert badges (talent points, mail, guild) still appear; glyphs crisp at 0.53 and 1.0 UI scale; hover tooltip shows keybind; works in combat (no protected calls). Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 3. Chat
- **Frames:** `ChatFrame1..10, edit box, tabs, ChatFrameMenu`  · **Mockup:** —
- **Design:** Opaque-optional dark panel, tabs as pills with the accent on the active tab and an unread dot, edit box with a channel-coloured left bar, copy-chat and URL buttons as Phoenix icons, timestamps in the muted token.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Tabs drag/undock/rename; new whispers flash; edit box keeps channel colour; combat log tab untouched in function; accent swap repaints tabs. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 4. Bags / bank / warband bank
- **Frames:** `ContainerFrameCombinedBags, BankFrame, AccountBankPanel`  · **Mockup:** 10_bags_bank
- **Design:** One-panel grid, item quality as 1px borders (game icons untouched), search bar in the header, category chips, gold + currency footer, bank tabs as side rail; warband tab tinted with a secondary accent.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Open/close with B and at the banker; drag, split, sort, deposit; quality borders correct; new-item glow; no item icon replaced; reagent/warband bank tabs switch. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 5. Quest log / world map / tracker
- **Frames:** `WorldMapFrame + QuestMapFrame, ObjectiveTrackerFrame`  · **Mockup:** 17_map_quest_log
- **Design:** Map in an ember-framed card with a slim header; quest log as cards with campaign/side headers in the accent, progress bars themed; tracker headers as small caps with the accent tick, collapsible.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Map zoom/pan, quest click to track, abandon/share; tracker collapse in combat (no taint); waypoints; accent live. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 6. Character + reputation + currency
- **Frames:** `CharacterFrame, PaperDollFrame, ReputationFrame, TokenFrame`  · **Mockup:** 01_character
- **Design:** Portrait corner kept, paperdoll slots as square 1px item slots (game icons untouched, quality border), stats as a right column of labelled rows, ilvl badge, reputation as progress rows, currency as a searchable list.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Equip/unequip by drag; stats update; titles and equipment manager; reputation expand/collapse; currency transfer to warband; model rotates. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 7. Group Finder / PvE / PvP
- **Frames:** `PVEFrame, LFGListFrame, PVPUIFrame, LFGDungeonReadyDialog`  · **Mockup:** 07_group_finder
- **Design:** Tabs on top, dungeon/raid lists as cards, premade search with chips for filters, ready dialog as a Phoenix modal with a role ring timer; rated PvP shows rating cards.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Queue/leave; premade search/apply/list; role check popup accept; ready check timer counts; no taint when joining in combat. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 8. Talents & Spellbook
- **Frames:** `PlayerSpellsFrame (ClassTalentsFrame, SpecFrame, SpellBookFrame)`  · **Mockup:** 02_spellbook, 03_talents
- **Design:** Tree background darkened behind a Phoenix vignette, node rings in the accent when selected (node icons untouched), loadout bar in the header, spellbook as a two-column list with Phoenix category headers.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Spend/refund points, loadout import/export/apply out of combat, spell drag to bars, hero tree switch; never errors with 'action blocked'. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 9. Loot / rolls / toasts
- **Frames:** `LootFrame, GroupLootFrame, AlertFrame toasts, LootHistory`  · **Mockup:** 09_loot
- **Design:** Compact loot list with quality bar, roll frames as slim cards with Need/Greed/Transmog buttons in Phoenix style, toasts as dark pills sliding in.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Loot all/single, master/group roll, toasts readable and clickable, loot history scroll. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 10. Auction House
- **Frames:** `AuctionHouseFrame`  · **Mockup:** 13_auction_house
- **Design:** Left category rail, search header, results as a dense table with sortable columns, price in gold token font, buy dialog as Phoenix modal.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Search/browse/buy/post/cancel; commodity quantity dialog; favourites; no frame errors on rapid search. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 11. Professions
- **Frames:** `ProfessionsFrame, ProfessionsCustomerOrdersFrame`  · **Mockup:** 14_professions
- **Design:** Recipe list with Phoenix headers, schematic panel as card with reagent slots (icons untouched), quality pips, specialization tree in the accent.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Craft, recraft, orders (place/fill), specialization points, concentration, tool slots. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 12. Friends / Who / Quick Join
- **Frames:** `FriendsFrame`  · **Mockup:** 08_friends
- **Design:** List rows with class-coloured name, game icon chips, status dots; tabs as pills; add-friend modal.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Add/remove, whisper, invite, BNet notes, Who search, quick join. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 13. Guild & communities
- **Frames:** `CommunitiesFrame`  · **Mockup:** 19_guild_communities
- **Design:** Left community rail with avatars, chat area themed like Chat, roster table, guild perks/news cards.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Switch communities, chat, roster sort, invite, guild bank tab link, news. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 14. Adventure Guide / Encounter Journal / Traveler's Log
- **Frames:** `EncounterJournal`  · **Mockup:** 16_encounter_journal
- **Design:** Instance cards with art kept, boss list as rows, abilities as collapsible sections; Traveler's Log as progress cards.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Browse tiers, boss abilities expand, loot filter, suggested content, traveler's log claim. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 15. Achievements
- **Frames:** `AchievementFrame`  · **Mockup:** 15_achievements
- **Design:** Category rail, achievement rows with points badge in the accent, progress bars themed, summary dashboard.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Search, track, compare with target, criteria expand, guild tab. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 16. Warband collections (mounts, pets, toys, heirlooms, appearances)
- **Frames:** `CollectionsJournal, WardrobeCollectionFrame`  · **Mockup:** 04_*, 05_*
- **Design:** Shared shell with tabs; grid cards for toys/heirlooms/appearances, list + model for mounts/pets; favourites star in accent; filter chips.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Summon mount/pet, use toy, upgrade heirloom, appearance sets, search and filters, favourites persist. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 17. Transmog & dressing room
- **Frames:** `TransmogFrame (12.x), DressUpFrame`  · **Mockup:** 06_transmog
- **Design:** Slot rail left and right of the model, outfit bar on top, pending-change cost footer.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Apply/cancel, outfits save/load, illusions, hide slot, dressing room link. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 18. Mail
- **Frames:** `MailFrame, SendMailFrame, OpenMailFrame`  · **Mockup:** 12_mail
- **Design:** Inbox rows with attachment icons (untouched), COD in danger token, send form as a Phoenix form.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Open, take all, return, send with attachment and money, COD. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 19. Merchant & buyback
- **Frames:** `MerchantFrame`  · **Mockup:** 11_merchant
- **Design:** Item grid cards with price in token font, buyback tab, repair buttons as Phoenix icon buttons.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Buy, buy stack, sell, buyback, repair (own/guild), extended cost currencies. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 20. Great Vault
- **Frames:** `WeeklyRewardsFrame`  · **Mockup:** 22_more_windows
- **Design:** Three rows (raid, dungeon, world) of reward cards with progress rings in the accent.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Progress shown, select reward when unlocked, preview item. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 21. Calendar
- **Frames:** `CalendarFrame`  · **Mockup:** 18_calendar
- **Design:** Month grid with today in the accent, event dots by type, event view as modal.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Create/edit event, invite, holidays visible, filters. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 22. Housing dashboard
- **Frames:** `HousingDashboardFrame (12.x)`  · **Mockup:** 22_more_windows
- **Design:** Dashboard cards for plots, decor and neighbourhood; decor catalogue as grid.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Open from micro menu, browse catalogue, teleport/visit actions work; only cosmetic regions touched (housing is new and changes often). Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 23. Shop
- **Frames:** `StoreFrame / in-game shop (protected)`  · **Mockup:** —
- **Design:** Only the outer frame chrome if Blizzard allows; the shop is a secure, forbidden frame in most clients: plan is no skin, a themed launch button only.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Shop opens and purchases are unaffected (no hooks inside). Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 24. Settings & Edit Mode
- **Frames:** `SettingsPanel, EditModeManagerFrame`  · **Mockup:** 22_more_windows
- **Design:** Category rail and control rows like Phoenix options (shared widgets look only, Blizzard controls kept), Edit Mode system frames get Phoenix selection outlines.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Every setting changes; keybinding page; Edit Mode save/revert; no taint in Edit Mode after Phoenix layout mode. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 25. PvP
- **Frames:** `PVPUIFrame, PVPMatchScoreboard`  · **Mockup:** 07_group_finder
- **Design:** Honor/conquest cards, rating badges, scoreboard as a dense themed table.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Queue skirmish/rated, scoreboard sort, leave match. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 26. Popups, ready/role checks, tooltips
- **Frames:** `StaticPopup1-4, ReadyCheckFrame, GameTooltip family`  · **Mockup:** 20_game_menu_popups, 21_tooltips
- **Design:** Phoenix modal cards with accent primary button; tooltips 1px border, quality-coloured title.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Every StaticPopup kind (delete item typing, confirm), ready check timer, tooltips for items/spells/units correct. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

### 27. Gossip / quest dialog / trade / inspect
- **Frames:** `GossipFrame, QuestFrame, TradeFrame, InspectFrame`  · **Mockup:** 22_more_windows
- **Design:** Dialog card with NPC portrait corner, options as rows with Phoenix bullets; trade as two-column card.
- **Accent live:** active tab / selection / progress fills / primary buttons use `accent.primary`, hovers use `accent.soft`, headers' tick uses the primary→secondary gradient; repainted on theme change.
- **Test checklist:** Accept/complete quests, gossip options, trade both sides, inspect gear. Plus: open at UI scale 0.53 and 1.0 (crisp 1 px borders, no clipped text), switch accent preset while open, `/pui dev audit` shows no new issues, no Lua errors or taint in BugSack/Phoenix Bugs.

## Open questions for the user
1. Phase 1 order: Game Menu + Micro menu first (fast, visible), or Bags first (most used)?
2. Micro menu glyph set: the 30 SVGs proposed in `pui_mockups/skins/media/svg` or a new set?
3. Shop: themed launcher only (safe) — confirm it's acceptable to leave the shop window itself untouched.
