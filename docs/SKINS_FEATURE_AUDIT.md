# Phoenix UI: Skins feature audit (v2), 27 Oct 2026

Source: Gethe wow-ui-source b9be937 (12.1.5). Each table lists the elements of the Blizzard window, the v1 mockup status of each, and its status in v2. v2 keeps Blizzard's layout, structure and placement and restyles them in Phoenix themes. Every v2 mockup shows all the listed features.

Phoenix extras are reached from the ⚙ cog in the title bar, which opens an inline flyout with live settings, and from the full Skins page (`/pui → Skins`). Extras are marked with a dashed outline and a ◆ tag in the mockups.

| # | Window | Blizzard features | v1 missing | v1 altered | v2 |
|---|---|---|---|---|---|
| 01 | Character | 16 | 5 | 7 | 16/16 |
| 02 | Spellbook | 12 | 5 | 3 | 12/12 |
| 03 | Talents | 12 | 6 | 3 | 12/12 |
| 04 | Collections · Mounts & Pets | 13 | 5 | 4 | 13/13 |
| 05 | Collections · Toys, Heirlooms, Appearances | 8 | 3 | 4 | 8/8 |
| 06 | Transmog | 10 | 4 | 5 | 10/10 |
| 07 | Group Finder | 11 | 6 | 4 | 11/11 |
| 08 | Friends | 10 | 5 | 3 | 10/10 |
| 09 | Loot | 7 | 2 | 3 | 7/7 |
| 10 | Bags & bank | 6 | 1 | 5 | 6/6 |
| 11 | Merchant | 10 | 3 | 4 | 10/10 |
| 12 | Mail | 7 | 2 | 4 | 7/7 |
| 13 | Auction House | 10 | 4 | 4 | 10/10 |
| 14 | Professions | 11 | 3 | 4 | 11/11 |
| 15 | Achievements | 8 | 4 | 3 | 8/8 |
| 16 | Adventure Guide | 10 | 3 | 4 | 10/10 |
| 17 | World map & quest log | 10 | 4 | 3 | 10/10 |
| 18 | Calendar | 9 | 5 | 1 | 9/9 |
| 19 | Guild & Communities | 9 | 4 | 4 | 9/9 |
| 20 | Game menu & popups | 5 | 0 | 1 | 5/5 |
| 21 | Tooltips | 7 | 2 | 1 | 7/7 |
| 22 | More windows | 6 | 0 | 5 | 6/6 |
| | **Total** | **207** | **76** | **79** | **207/207** |

## 01_character — Character

Source: `CharacterFrame.xml, PaperDollFrame.xml/.lua, ReputationFrame.xml, Blizzard_TokenUI` · native size 338×424 (540×424 expanded) · mockup `skins/01_character.png` (variants: `skins/variants/01_character_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Portrait + title (name) + level/class line | v1 altered | present |
| Close button | v1 ok | present |
| Bottom tabs: Character / Reputation / Currency | v1 altered | present |
| 8 left + 8 right gear slots, 2 weapon slots bottom-centre | v1 altered | present |
| Slot flyout popout (equip alternatives, Alt) | v1 missing | present |
| Character model scene (rotate/zoom drag) | v1 ok | present |
| Expand/collapse stats pane toggle | v1 missing | present |
| Sidebar tabs: Character Stats / Titles / Equipment Manager | v1 missing | present |
| Item level header + stats categories (Attributes, Enhancements) | v1 altered | present |
| Titles list with search | v1 missing | present |
| Equipment Manager: set list, New Set, Equip, Save, edit (icon picker), delete | v1 altered | present |
| Repair/durability overlays on slots | v1 missing | present |
| Reputation: filter dropdown, collapsible headers, bars, paragon icon, View Renown, Watch/At War/Inactive checkboxes, detail pane | v1 altered | present |
| Currency: filter dropdown, headers, transfer (Warband), log | v1 altered | present |
| Shirt and tabard slots | v1 ok | present |
| Item quality borders on slots | v1 ok | present |

| Phoenix extra | Access |
|---|---|
| Item level + enchant/gem flags on slots | inline on each slot (toggle in ⚙ flyout) |
| Missing enchant/gem summary | stats pane footer chip |
| Durability % + repair cost | stats pane |
| Stat order & % view | ⚙ flyout → Stats |
| Model backdrop light | ⚙ flyout → Look |
| Theme / accent | ⚙ flyout → Theme (full page: /pui → Skins → Character) |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 02_spellbook — Spellbook

Source: `Blizzard_PlayerSpellsFrame.xml, SpellBook/*.xml/.lua` · native size 1618×883 (PlayerSpellsFrame, shared with Talents/Spec) · mockup `skins/02_spellbook.png` (variants: `skins/variants/02_spellbook_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Bottom tab system: Specialization / Talents / Spellbook | v1 altered | present |
| Category tabs (class / spec / General / pet) as top tabs | v1 altered | present |
| Two-page spread of spell slots with headers per group | v1 altered | present |
| Search box (spells, talents, passives) | v1 ok | present |
| Hide passives checkbox | v1 ok | present |
| Settings dropdown (cog) in title area | v1 missing | present |
| Page counter + prev/next | v1 ok | present |
| Help plate button (?) | v1 missing | present |
| Drag spell to action bar, right-click/shift-link | v1 missing | present |
| Spell tooltip | v1 ok | present |
| Assisted combat / rotation highlight button where available | v1 missing | present |
| Maximise/minimise (frame size toggle) | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Cast/CD line under each spell | ⚙ flyout → Cards |
| Spell IDs on Shift | tooltip (HUD Tooltip IDs) |
| Card size / font | ⚙ flyout |
| Theme | ⚙ flyout → Theme |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 03_talents — Talents

Source: `ClassTalents/*.xml, HeroTalents/*.xml` · native size 1618×883 · mockup `skins/03_talents.png` (variants: `skins/variants/03_talents_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Class tree (left) / hero tree centre / spec tree (right) | v1 ok | present |
| Points remaining per tree | v1 ok | present |
| Loadout dropdown (create/import/edit/share/delete) | v1 altered | present |
| Search box | v1 ok | present |
| Apply changes / Undo / Reset tree | v1 altered | present |
| Inspect copy button (inspect mode) | v1 missing | present |
| PvP talents button + war mode | v1 missing | present |
| Hero spec selection dialog | v1 missing | present |
| Node tooltips with rank | v1 missing | present |
| Choice nodes (octagon) and gates (points required) | v1 altered | present |
| Uses shared action bars checkbox (loadout dialog) | v1 missing | present |
| Starter build toggle | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Node state rings and lit edges | ⚙ flyout → Look |
| Loadouts module: spec auto-swap + share | loadout bar (Phoenix chip) |
| Compact tree | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 04_collections_mounts_pets — Collections · Mounts & Pets

Source: `Blizzard_Collections.xml, Blizzard_MountCollection.xml, Shared/Blizzard_PetCollection.xml` · native size 703×606 · mockup `skins/04_collections_mounts_pets.png` (variants: `skins/variants/04_collections_mounts_pets_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Bottom tabs: Mounts / Pets / Toy Box / Heirlooms / Appearances / Warband Campsites | v1 altered | present |
| Collected counter top-left | v1 ok | present |
| Search box + filter dropdown | v1 altered | present |
| Mount list (icon, name, favourite, not-usable) | v1 ok | present |
| Mount model with rotate buttons + Summon/Mount button | v1 ok | present |
| Mount source/description text | v1 ok | present |
| Mount equipment slot + suppressed toggle | v1 missing | present |
| Skyriding: dynamic flight mode button + skill tree button | v1 missing | present |
| Random favourite mount button (drag to bar) | v1 missing | present |
| Pets: list, card, 3 battle slots with 3 ability picks each | v1 altered | present |
| Pets: heal pets button, summon random, find battle, XP/health bars | v1 altered | present |
| Achievement points shield | v1 missing | present |
| Tutorial (?) button | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Source line under each row | ⚙ flyout |
| Dim uncollected | ⚙ flyout |
| Model backdrop light | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 05_collections_toys_heirlooms_appearances — Collections · Toys, Heirlooms, Appearances

Source: `Blizzard_ToyBox.xml, Blizzard_HeirloomCollection.xml, Blizzard_Wardrobe.xml, Wardrobe_Sets.xml, WarbandSceneCollection.xml` · native size 703×606 · mockup `skins/05_collections_toys_heirlooms_appearances.png` (variants: `skins/variants/05_collections_toys_heirlooms_appearances_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Toy Box: 18 toy buttons per page, search, filter dropdown, page arrows, progress bar | v1 altered | present |
| Heirlooms: class dropdown, filter, upgrade level, progress bar, paging | v1 altered | present |
| Appearances: Items / Sets tabs | v1 ok | present |
| Appearances: slot buttons row across top, weapon dropdown | v1 altered | present |
| Appearances: 3×6 model grid, paging, progress bar, search, filter | v1 altered | present |
| Sets: list left, detail model right, variant dropdown | v1 missing | present |
| Warband Campsites tab | v1 missing | present |
| Tracking shortcuts (track appearance) | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Upgrade pips | on heirloom tile |
| Grey uncollected | ⚙ flyout |
| Collected ✓ chips | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 06_transmog — Transmog

Source: `Blizzard_Transmog.xml/.lua, DressUpFrames.xml` · native size 1618×883 · mockup `skins/06_transmog.png` (variants: `skins/variants/06_transmog_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Character model centre with slot columns left/right | v1 altered | present |
| Tabs: Items / Sets / Custom Sets / Situations | v1 altered | present |
| Search + filter, weapon dropdown, sheathe dropdown | v1 missing | present |
| Appearance grid with paging | v1 ok | present |
| Outfit list + Save outfit / Purchase outfit slot | v1 altered | present |
| Apply + cost, Undo, Clear all pending, Defaults | v1 altered | present |
| Display type: equipped / unassigned | v1 missing | present |
| Show mount checkbox (situations) | v1 missing | present |
| Help plate | v1 missing | present |
| Dressing room: Reset, Undress, link dropdown, custom set dropdown, side dress-up | v1 altered | present |

| Phoenix extra | Access |
|---|---|
| Pending-change highlight | slot rail |
| Cost line | footer |
| Card size | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 07_group_finder — Group Finder

Source: `PVEFrame.xml, LFDFrame.xml, LFGList.xml, LFGFrame.xml, Blizzard_PVPUI` · native size 563×428 (PVEFrame) · mockup `skins/07_group_finder.png` (variants: `skins/variants/07_group_finder_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Bottom tabs: Dungeons & Raids / Player vs. Player / Mythic+ Dungeons / Delves | v1 altered | present |
| Left category buttons (Dungeon Finder, Raid Finder, Premade Groups) | v1 altered | present |
| Dungeon Finder: type dropdown, role buttons (tank/heal/dps/leader), rewards, Find Group | v1 missing | present |
| Premade: categories, search box, filter, results with role icons, Sign Up, Refresh, Back | v1 altered | present |
| Premade: Start a group (entry creation: title, item level, voice, rating, private) | v1 missing | present |
| Application viewer (your listing): applicants, invite/decline, edit/unlist | v1 missing | present |
| Ready dialog: Enter / Leave, role, proposal status | v1 ok | present |
| Role check popup | v1 missing | present |
| PvP tab: Quick Match, Rated (Solo Shuffle, 2v2, 3v3, RBG Blitz), Premade, Training Grounds | v1 altered | present |
| Conquest bar / honor level | v1 missing | present |
| Mythic+: dungeon icons with best runs, affixes, weekly best | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Score, best key, missing roles, age on rows | each row (Group Finder module) |
| Filter chips + "why hidden" | above results (P badge) |
| Queue pop countdown bar | ready dialog |
| Hide declined | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 08_friends — Friends

Source: `Blizzard_FriendsFrame (Mainline), Blizzard_QuickJoin` · native size 385×424 · mockup `skins/08_friends.png` (variants: `skins/variants/08_friends_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Bottom tabs: Friends / Who / Raid / Quick Join | v1 ok | present |
| Top tabs (Friends tab): Friends / Recent Allies / Recruit-A-Friend | v1 missing | present |
| Battle.net status dropdown + broadcast text | v1 missing | present |
| Contacts menu (ignore list, etc.) | v1 missing | present |
| Friend list with headers (BNet, WoW), status, game icon, travel pass invite, summon | v1 altered | present |
| Add Friend, Send Message buttons | v1 altered | present |
| Who: edit box, column headers (name, zone/guild/race dropdown, level, class), Refresh, Add Friend, Invite | v1 altered | present |
| Raid tab: raid info, convert to raid, raid frames toggle | v1 missing | present |
| Quick Join: list + Join Queue | v1 ok | present |
| Friends tooltip | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Class icons, faction tint, status orb, zone/activity | friend rows |
| Search friends/guild/recent | search above list (P badge) |
| Copy BattleTag | row right-click → Phoenix entry |
| Auto-accept invites | ⚙ flyout (off) |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 09_loot — Loot

Source: `LootFrame.xml, GroupLootFrame.xml, AlertFrames, LootHistory, BonusRoll` · native size 220×290 loot · roll frames · alerts · mockup `skins/09_loot.png` (variants: `skins/variants/09_loot_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Loot window: title, close, item rows with counts, scroll (auto-loot via setting) | v1 altered | present |
| Roll frame: icon, name, timer bar, Need / Greed / Transmog / Pass | v1 ok | present |
| Roll frame: bind type, item level hint | v1 altered | present |
| Loot history: encounter dropdown, rolls per player, resize | v1 altered | present |
| Bonus roll frame | v1 missing | present |
| Alert toasts: loot, upgrade, achievement, mount/pet/toy, currency, WQ, garrison | v1 ok | present |
| Encounter journal link (loot history) | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Upgrade hint on rolls | roll frame |
| Toast style/position | ⚙ flyout (Movers for position) |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 10_bags_bank — Bags & bank

Source: `ContainerFrame.xml, BankFrame.xml, Blizzard_GuildBankUI` · native size 738×460 bank · combined bags · mockup `skins/10_bags_bank.png` (variants: `skins/variants/10_bags_bank_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Combined bags: portrait/bag menu dropdown, search, auto-sort, money, token/currency watch | v1 altered | present |
| Bag menu: assign to (equipment, consumables…), ignore clean up, show junk | v1 missing | present |
| Bank: tabs Bank / Warband, tab bar on right with tab settings, purchase tab | v1 altered | present |
| Bank: search, auto-sort, deposit settings menu, deposit all reagents, include reagents | v1 altered | present |
| Warband bank: deposit/withdraw money | v1 altered | present |
| Guild bank: 6/8 tabs right, Deposit/Withdraw, log, money log, tab info | v1 altered | present |

| Phoenix extra | Access |
|---|---|
| Vault: category/grid/list views, junk overlay, new items, gold history | Vault window (replaces bags) |
| Guild bank skin | Skins toggle |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 11_merchant — Merchant

Source: `MerchantFrame.xml/.lua` · native size 336×444 · mockup `skins/11_merchant.png` (variants: `skins/variants/11_merchant_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Portrait + vendor name title | v1 altered | present |
| Filter dropdown (class/spec, all) | v1 altered | present |
| 10 items per page in 2 columns (icon, name, price/alt currency) | v1 altered | present |
| Page counter + prev/next | v1 missing | present |
| Bottom tabs: Merchant / Buyback | v1 altered | present |
| Repair all, repair item (cursor), guild repair | v1 ok | present |
| Sell all junk button | v1 ok | present |
| Money frame | v1 ok | present |
| Buyback item slot preview on Merchant tab | v1 missing | present |
| Stack split on shift-click | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Dim unusable, collected check | ⚙ flyout |
| Search vendor | title bar (P badge) |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 12_mail — Mail

Source: `MailFrame.xml/.lua` · native size 384×512 · mockup `skins/12_mail.png` (variants: `skins/variants/12_mail_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Portrait + title | v1 altered | present |
| Bottom tabs: Inbox / Send Mail | v1 altered | present |
| Inbox: 7 items per page, sender, subject, days left, money/COD, attachment icon | v1 altered | present |
| Open All button | v1 ok | present |
| Inbox paging | v1 missing | present |
| Open mail: body, attachments grid, Take money, Reply, Delete/Return, Report spam | v1 missing | present |
| Send: To (autocomplete, contacts dropdown), Subject, body, 12 attachments, Send Money / COD radios, money input, Send, Cancel | v1 altered | present |

| Phoenix extra | Access |
|---|---|
| Collect gold only | inbox toolbar (P badge) |
| Skip COD | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 13_auction_house — Auction House

Source: `Blizzard_AuctionHouseUI/*` · native size 800×538 · mockup `skins/13_auction_house.png` (variants: `skins/variants/13_auction_house_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Bottom tabs: Buy / Sell / Auctions | v1 altered | present |
| Search bar with favourites ★ button, filter dropdown, search | v1 altered | present |
| Categories list left | v1 ok | present |
| Results table with sortable column headers | v1 altered | present |
| Commodity buy: quantity input, unit/total, Buy Now | v1 altered | present |
| Item buy: bid/buyout list, bid, buyout | v1 missing | present |
| Sell: item slot, quantity, max, price input, duration dropdown, deposit, Post | v1 missing | present |
| Auctions: Auctions/Bids tabs, cancel auction, refresh | v1 missing | present |
| WoW Token display | v1 missing | present |
| Money frame | v1 ok | present |

| Phoenix extra | Access |
|---|---|
| Price font, favourites first | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 14_professions — Professions

Source: `Blizzard_ProfessionsFrame.xml, Crafting, RecipeList, Specializations, CrafterOrder*` · native size 942×658 · mockup `skins/14_professions.png` (variants: `skins/variants/14_professions_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Top tab system: Recipes / Specializations / Crafting Orders | v1 ok | present |
| Skill bar + expansion in title | v1 altered | present |
| Recipe list: search, filter, favourites | v1 altered | present |
| Schematic: output, reagents, finishing reagents, optional slots | v1 ok | present |
| Quality meter + concentration checkbox | v1 ok | present |
| Create / Create All / count input | v1 ok | present |
| Track recipe, link dropdown, view guild crafters | v1 altered | present |
| Profession equipment slots (tools, accessories) | v1 missing | present |
| Recraft mode | v1 missing | present |
| Specializations tree: paths, Apply/Undo, spend points | v1 altered | present |
| Crafting orders: Public/Guild/Personal/NPC tabs, list, start/complete order | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Have/need colours | reagent rows |
| Compact recipe list | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 15_achievements — Achievements

Source: `Blizzard_AchievementUI.xml` · native size 768×500 · mockup `skins/15_achievements.png` (variants: `skins/variants/15_achievements_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Bottom tabs: Achievements / Guild / Statistics | v1 altered | present |
| Header: points total, search box with preview + show all results, filter dropdown | v1 altered | present |
| Category list with progress bars | v1 ok | present |
| Summary view: recent, category progress | v1 missing | present |
| Achievement rows: shield points, icon, description, date, tracked checkbox, criteria expand | v1 altered | present |
| Comparison mode (inspect) | v1 missing | present |
| Statistics list | v1 missing | present |
| Guild tab with guild tabard | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Hide completed | ⚙ flyout |
| Earned colour | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 16_encounter_journal — Adventure Guide

Source: `Blizzard_EncounterJournal/Mainline/*` · native size 800×496 · mockup `skins/16_encounter_journal.png` (variants: `skins/variants/16_encounter_journal_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Bottom tabs: Journeys / Traveler's Log / Suggested Content / Dungeons / Raids / Item Sets / Tutorials | v1 ok | present |
| Expansion dropdown, search box | v1 altered | present |
| Instance select grid | v1 missing | present |
| Encounter: boss list, model, overview/abilities/loot/model tabs on right edge | v1 altered | present |
| Difficulty dropdown | v1 altered | present |
| Loot: class/spec filter, slot filter | v1 altered | present |
| Ability headers collapsible with role icons | v1 ok | present |
| Map button, prev/next | v1 missing | present |
| Journeys: renown cards | v1 missing | present |
| Traveler's Log activities with threshold rewards | v1 ok | present |

| Phoenix extra | Access |
|---|---|
| Spec loot only | ⚙ flyout |
| Open from Pulse boss timers | Pulse |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 17_map_quest_log — World map & quest log

Source: `Blizzard_WorldMap.xml, QuestMapFrame.xml` · native size ~1020×700 + 330 quest log · mockup `skins/17_map_quest_log.png` (variants: `skins/variants/17_map_quest_log_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Map canvas with zoom/pan | v1 ok | present |
| Top-left: map navigation (breadcrumb dropdown) | v1 missing | present |
| Top-right: tracking/filter dropdown, map pin, legend toggles | v1 altered | present |
| Quest log side panel (330) with tabs Quests / Events / Map Legend | v1 altered | present |
| Quest log search + settings dropdown | v1 altered | present |
| Campaign header, zone headers, quest rows (track checkbox) | v1 ok | present |
| Quest details: Abandon, Share, Track, back | v1 missing | present |
| Maximise/minimise button | v1 missing | present |
| Floor dropdown | v1 missing | present |
| Coordinates (Phoenix) | v1 ok | present |

| Phoenix extra | Access |
|---|---|
| Coords strip | map bottom (P badge) |
| Player arrow glow | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 18_calendar — Calendar

Source: `Blizzard_Calendar.xml` · native size 659×624 · mockup `skins/18_calendar.png` (variants: `skins/variants/18_calendar_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Month/year title with prev/next | v1 ok | present |
| Filter dropdown (show holidays etc.) | v1 missing | present |
| Weekday header + 6×7 day grid with event icons | v1 altered | present |
| Today highlight | v1 ok | present |
| Day context menu (create event, paste, etc.) | v1 missing | present |
| Create event: title, type, difficulty, date/time dropdowns, description, invite list, mass invite, lock | v1 missing | present |
| View event: RSVP Accept/Tentative/Decline, invite list, remove | v1 ok | present |
| Holiday / raid lockout views | v1 missing | present |
| Class totals button | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Event colours by type | ⚙ flyout |
| Week start | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 19_guild_communities — Guild & Communities

Source: `CommunitiesFrame.xml and siblings` · native size 814×426 · mockup `skins/19_guild_communities.png` (variants: `skins/variants/19_guild_communities_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Community list left (with + join/create) | v1 ok | present |
| Right-edge tabs: Chat / Roster / Guild Benefits / Info | v1 altered | present |
| Chat: stream dropdown, chat pane, edit box, jump to unread, mute/deafen voice | v1 altered | present |
| Member list right with show offline | v1 altered | present |
| Roster view: columns, member list dropdown, guild controls, add member, recruitment | v1 missing | present |
| Guild benefits: perks + rewards | v1 altered | present |
| Info: MOTD (edit), details, news with filters, log | v1 missing | present |
| Settings button, calendar button, invite button | v1 missing | present |
| Club finder | v1 missing | present |

| Phoenix extra | Access |
|---|---|
| Unread badges | community list |
| Roster columns | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 20_game_menu_popups — Game menu & popups

Source: `Blizzard_GameMenu, Blizzard_StaticPopup, ReadyCheck.xml, LFGFrame.xml` · native size 195 wide menu · 320 popups · mockup `skins/20_game_menu_popups.png` (variants: `skins/variants/20_game_menu_popups_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Game menu buttons: Options, Shop, What's New, Edit Mode, Support, Macros, AddOns, Ratings, Log Out, Exit, Return | v1 altered | present |
| StaticPopup: text, edit box, money input, item frame, 1–4 buttons, close, alert icon | v1 ok | present |
| Ready check: portrait, text, Yes/No | v1 ok | present |
| Role check: role buttons | v1 ok | present |
| LFG proposal: Enter/Leave | v1 ok | present |

| Phoenix extra | Access |
|---|---|
| Phoenix UI entry | first menu button (P badge) |
| Danger colour for destructive | popup skin |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 21_tooltips — Tooltips

Source: `Blizzard_GameTooltip, SharedTooltipTemplates.xml` · native size dynamic · mockup `skins/21_tooltips.png` (variants: `skins/variants/21_tooltips_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Item tooltip lines + comparison (shopping) tooltips | v1 ok | present |
| Unit tooltip with health bar | v1 ok | present |
| Spell/aura tooltips | v1 ok | present |
| Embedded item tooltip (quest rewards) | v1 missing | present |
| Item ref tooltip (chat links, close button) | v1 altered | present |
| Battle pet tooltip | v1 missing | present |
| Map/POI tooltips | v1 ok | present |

| Phoenix extra | Access |
|---|---|
| Info lines (M+, guild, target, forces) | tooltip |
| IDs on Shift | tooltip |
| Anchor / scale | ⚙ on Tooltip page |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |

## 22_more_windows — More windows

Source: `WeeklyRewards, Gossip/Quest, EditMode, SettingsPanel, HousingDashboard` · native size varies · mockup `skins/22_more_windows.png` (variants: `skins/variants/22_more_windows_midnight|horde|alliance.png`)

| Blizzard element | v1 | v2 |
|---|---|---|
| Great Vault: 3 rows × 3, header, Select Reward | v1 altered | present |
| Gossip: greeting, options with icons, Goodbye | v1 ok | present |
| Quest frame: detail/progress/reward pages, Accept/Decline/Complete | v1 altered | present |
| Edit Mode: layout dropdown, show grid, snap, grid spacing, system checkboxes, Revert/Save | v1 altered | present |
| Settings: Game / AddOns tabs, search, category list, settings list, Defaults/Close | v1 altered | present |
| Housing dashboard: house dropdown, House Info / Catalog / Collection tabs, upgrade, endeavors, teleport | v1 altered | present |

| Phoenix extra | Access |
|---|---|
| Open Phoenix Studio | Edit Mode dialog (P badge) |
| Great Vault glow | ⚙ flyout |
| All options | ⚙ title-bar flyout and /pui → Skins (simple / advanced, live) |
