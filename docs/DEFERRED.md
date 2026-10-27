# Deferred items (consolidated, PRs #31-#43)

Generated from the Deferred lists in `docs/PLAN.md` (sections 4, 5 and 5.21 step-status lines and section 6), the CHANGELOG and this PR. Each item is a backlog entry, not a to-do: it is scheduled during the test, fix and polish phase after the end-to-end build. Items move out of this file when they are built or dropped by a decision. Deferred batch A (stacked on PR #43) marks its items in place: **done**, **blocked** with the reason, or **left**. Deferred batch B (stacked on batch A) marks the Studio and HUD items the same way and adds live previews for the Action Bars, Cooldown Manager and Resource Bars extras. Deferred batch C (stacked on batch B) marks every remaining module from Quest Tracker to Plan-wide the same way, with each extra shown live in its module's preview. Moved out in this PR: Arena's Gladiator progress (now on the PvP rated card) and Embers' Pulse page for the combat timer (built in step 9b).

| Module | Items |
|---|---|
| Options & Core (PRs #31-#32) | 3 |
| Unit Frames (PR #33) | 1 |
| Nameplates (PR #35) | 12 |
| Action Bars (PR #36) | 11 |
| Cooldown Manager (PR #36) | 8 |
| Resource Bars (PR #36) | 7 |
| Studio movers (PR #37) | 8 |
| HUD: Minimap, Data Bars, Tooltip (PR #38) | 7 |
| Quest Tracker (PR #40) | 2 |
| Reminders (PR #40) | 3 |
| Embers damage meter (PR #40) | 3 |
| Ascent Mythic+ (PR #40) | 3 |
| Flow QoL (PR #41) | 8 |
| Group Finder (PR #41) | 6 |
| Raid Tools (PR #41) | 3 |
| Pulse (PR #42) | 5 |
| Arena (PR #42) | 9 |
| Spark (PR #42) | 5 |
| Cast History (PR #42) | 3 |
| PvP UI (PR #43, this PR) | 6 |
| Friends (PR #43, this PR) | 6 |
| Sentinel error reporter (PR #43, this PR) | 9 |
| Diagnostics and profiler (PR #43, this PR) | 6 |
| Plan-wide (PLAN section 6) | 7 |
| **Total** | **141** |

## Options & Core (PRs #31-#32)

- **done (deferred A):** Core/SpecProfiles.lua + wizard role page; Spec auto-switch wizard toggle (1.7, omitted in PR #14)
- **done (deferred A):** layer key (Core/KeyLayer.lua) and "keybind" override condition; Conditional override for keybind condition (1.9 still P)
- **left (test phase):** In-game checks pending: profiles manager (1.6), spec and condition overrides (1.8, 1.9), ledger page (1.22), copy dialog and chat links (1.26), own confirm dialogs (1.27), PUI.Season (1.28), shared services (1.29)

## Unit Frames (PR #33)

- **left (test phase):** Verify in game: private-aura anchors and AnimatedHealthLoss on addon frames

## Nameplates (PR #35)

- **done (deferred A):** totem/pet compact plates
- **done (deferred A):** range fade; **blocked:** line of sight (no LoS API in the 12.x API docs); range/LoS opacity for enemies (PUI.Range is group-only)
- **done (deferred A):** "interrupted by <name>"
- **done (deferred A):** NPC subtitles and quest objective text (C_TooltipInfo cache)
- **done (deferred A):** hit-box insets (`C_NamePlateManager`), click-through and friendly CVar enable path
- **done (deferred A):** hover highlight
- **done (deferred A):** important-aura glow per lane and pandemic glow
- **done (deferred A):** purge glow per engine group
- **done (deferred A):** pre-warm pool sizing
- **done (deferred A):** rule conditions beyond NPC id/name (classification, reaction, casting) and data packs
- **done (deferred A):** Blizzard nameplate driver suppression
- **done (deferred A):** drag-slot layout editor

## Action Bars (PR #36)

- **done (deferred A):** micro menu and bag bar
- **done (deferred A):** extra action / zone ability movers
- **done (deferred A):** flyout reskin
- **done (deferred A):** pet autocast toggle on right-click
- **done (deferred A):** mouse-button capture in keybind mode and a printable key sheet
- **done (deferred A):** per-button overrides
- **done (deferred A):** Blizzard/Classic looks and masks
- **done (deferred A):** threshold colours on cooldown numbers (needs a secret-safe curve on the countdown)
- **done (deferred A):** "hide in housing" and gamepad hide
- **done (deferred A):** first-install capture of the Edit Mode layout
- **done (deferred A):** reverse CDM dedupe (hide a bar button already in the CDM)

## Cooldown Manager (PR #36)

- **done (deferred A):** as a "Hidden spells" ID list plus /pui cdmspells (copy dialog); a dedicated picker page is polish; spell picker page
- **done (deferred A):** glow conditions
- **done (deferred A):** tracking-bar reskin (thresholds, ticks, stacks)
- **done (deferred A):** focus kick bar
- **done (deferred A):** rotation assist icon
- **done (deferred A):** audio cues
- **done (deferred A):** per-spell import
- **done (deferred A):** crafted-quality rank

## Resource Bars (PR #36)

- **done (deferred A):** latency overlay and channel ticks
- **done (deferred A):** empower stages
- **done (deferred A):** GCD bar instance/instant-only modes
- **blocked:** needs COMBAT_LOG_EVENT_UNFILTERED (not delivered to addons; guardrails DEPRECATED_TOKENS) and there is no swing event or API; swing timer (Forever)
- **done (deferred A):** spec helpers on hidden aura slots
- **done (deferred A):** threshold colour curves
- **done (deferred A):** bar shifting when a resource is missing

## Studio movers (PR #37)

- **done (deferred B):** connector lines drawn between attached movers (Studio connectors setting, elbow lines redrawn on every placement)
- **done (deferred B):** layout template thumbnails (Saved layouts section in the Layouts panel; click applies)
- **done (deferred B):** free per-member party placement (`rf.party.free`, movers rf.party.member1..5, secure buttons with state drivers)
- **done (deferred B):** a Blizzard-element list page in options (Interface > Blizzard: enable, hide/show, reset, open in Studio)
- **done (deferred B):** resize handles on the mover corners (width/height for resizable elements, scale 0.25-4 for the rest)
- **done (deferred B):** grow-direction anchors per bar inside Studio (inspector buttons cycle the module's own grow keys)
- **done (deferred B):** fades for Blizzard elements re-evaluated on state events (Movers:Refade on the Layout fade events)
- **done (deferred B):** importers for other mover addons (ElvUI movers added next to MoveAny)

## HUD: Minimap, Data Bars, Tooltip (PR #38)

- **done (deferred B):** inspect-based lines (other players' item level and spec), transmog-known and upgrade-track lines, tier-set count (Phoenix_UI_HUD/TooltipExtras.lua; inspect cached 5 min, never in combat or with the Inspect window open)
- **done (deferred B):** ID sources: achievement criteria rows (hook on AchievementObjectives_DisplayCriteria), artifact power (GameTooltip:SetArtifactPowerByID), garrison follower abilities and pet-battle abilities (own ID line on those custom tooltip frames; new kind "Follower ability", 28 kinds)
- **done (deferred B):** Phoenix-drawn tracking/calendar/mail buttons (`mm.buttons`; Blizzard's faded by alpha only; invites badge, mail senders)
- **done (deferred B):** LDB host (`ldb:Name` block through another addon's LibStub) and secure travel/profession blocks (hearth, prof1, prof2 via SecureActionButtons on UIParent, placed out of combat)
- **done (deferred B):** per-spec data-bar sets (`db.spec.on`, `/pui dbspec save|clear`)
- **done (deferred B):** queue-popup timer in Skins reading PUI.Queue (Phoenix_UI_Skins/QueueTimer.lua)
- **done (deferred B):** Group Finder page for `queue.lfgSeconds` (schema `page` field: owned by Core, shown on Group Finder; queue timer sample in its preview)

## Quest Tracker (PR #40)

- **done (deferred C):** quest-item SecureActionButtons (Phoenix_UI_QuestTracker/Extras.lua; placed and resized out of combat only, `qt.itemButtons`, `qt.itemSize`)
- **done (deferred C):** auto-share (`qt.autoShare`, optional skip of daily/weekly quests)

## Reminders (PR #40)

- **done (deferred C):** season consumables and weapon oil reminders (Phoenix_UI_Reminders/Extras.lua); **left:** the season item ID pack stays empty until the in-game test phase
- **done (deferred C):** talents by zone (saved per instance, reminder on entering)
- **done (deferred C):** per-reminder sound/icon overrides (`rm.overrides` list)

## Embers damage meter (PR #40)

- **done (deferred C):** show/hide-all and reset hotkeys through the Binding ledger (Phoenix_UI_Embers/Extras.lua)
- **done (deferred C):** threat warning at a set percentage with a media sound (Forever and retail; reads the plain threat API)
- **done (deferred C):** window snapping (edges or grid, with a gap)

## Ascent Mythic+ (PR #40)

- **done (deferred C):** forces current-pull preview (Phoenix_UI_Ascent/Extras.lua)
- **done (deferred C):** score projection (`AS.SCORE` model; **left:** constants checked in the test phase)
- **done (deferred C):** vault planner (`/pui vaultplan`)

## Flow QoL (PR #41)

- **done (deferred C):** leave-queue popups (Phoenix_UI_Flow/Extras.lua)
- **done (deferred C):** open containers (out of combat, Ticker-paced)
- **done (deferred C):** Train All
- **done (deferred C):** tutorials/banners
- **done (deferred C):** `/gg` (custom text)
- **done (deferred C):** queue protection (accept button guarded for a set time)
- **done (deferred C):** Tab binder (Binding ledger, out of combat)
- **done (deferred C):** screenshot on achievement

## Group Finder (PR #41)

- **blocked:** raid boss-defeated/lockout filters: `C_LFGList.GetSearchResultEncounterInfo` is used by Blizzard_GroupFinder/Mainline/LFGList.lua:4536 but is absent from the 12.1.5 generated API docs and the catalog
- **blocked:** cancel-oldest button: `C_LFGList.CancelApplication` is used by QueueStatusFrame.lua:1554 but is absent from the 12.1.5 generated API docs and the catalog
- **done (deferred C):** Raider.IO words `rio`/`riomain` and region badge `[DE]` plus `samelang` (Phoenix_UI_GroupFinder/Extras.lua; RaiderIO and LibRealmInfo looked up at call time)
- **done (deferred C):** plugin sort hooks (`GF.RegisterSort`/`UnregisterSort`)
- **done (deferred C):** click-to-insert word list (Words button; Shift+click keeps the help)
- **done (deferred C):** Studio mover for the detached panel (`gf.panel`)

## Raid Tools (PR #41)

- **done (deferred C):** notes window (hidden in combat, back after it through CombatQueue; Phoenix_UI_RaidTools/Extras.lua)
- **done (deferred C):** boss-frame tooltip line (TooltipDataProcessor)
- **done (deferred C):** stats window (`/pui statswin`, export, confirmed row reset)

## Pulse (PR #42)

- **done (deferred C):** next-three HUD (Ticker `pulse.next`, boss fights only; Phoenix_UI_Pulse/Extras.lua)
- **blocked:** private-aura sounds: UnitAuraDocumentation.lua (12.1.5) has only AddPrivateAuraAnchor/RemovePrivateAuraAnchor; no sound or applied-event API for private auras
- **done (deferred C):** per-boss options (`pulse.bossRules`)
- **done (deferred C):** BigWigs bar-style bridge (BigWigsAPI.RegisterBarStyle)
- **done (deferred C):** Blizzard timeline view hide (C_EncounterTimeline.SetViewType, restored when off)

## Arena (PR #42)

- **done (deferred C):** pet frames (Phoenix_UI_Arena/Extras.lua)
- **done (deferred C):** class-icon aura priority
- **done (deferred C):** dispel tracker (**left:** spell ID list checked in game)
- **done (deferred C):** range fading (**left:** per-class range spells checked in game)
- **done (deferred C):** click-binding list (applied out of combat)
- **done (deferred C):** text size and anchor per text
- **done (deferred C):** FrameSort numbering (**left:** FrameSort API checked in game)
- **done (deferred C):** 'only triggerable by me' DR CVar (CVar ledger)
- **done (deferred C):** healer-only variants (trinket, DR, cast)

## Spark (PR #42)

- **done (deferred C):** per-event sounds (Phoenix_UI_Spark/Extras.lua)
- **done (deferred C):** aura gain/fade rows
- **done (deferred C):** ability substitution/abbreviation lists
- **done (deferred C):** visual trigger builder
- **done (deferred C):** profile import from MSBT (confirmed; **left:** key mapping checked against a real MSBT profile)

## Cast History (PR #42)

- **done (deferred C):** Masque group (Phoenix_UI_CastHistory/Extras.lua)
- **done (deferred C):** Addon Compartment: Alt+click on Phoenix's entry toggles the test strip (the game has no remove-entry call, so a second entry could not follow its setting live)
- **done (deferred C):** Embers link button ("Casts" in the breakdown)

## PvP UI (PR #43, this PR)

- **done (deferred C):** read-only overlay on Blizzard's conquest frame (Phoenix_UI_PvP/Extras.lua)
- **done (deferred C):** automatic Legend and Strategist achievement IDs (category scan; a typed ID still wins)
- **done (deferred C):** rated match history window (`/pui pvphistory`)
- **done (deferred C):** drag-to-reorder scoreboard headers
- **done (deferred C):** per-round Solo Shuffle win/loss when plain
- **left:** in-game check: GetPersonalRatedInfo bracket indexes 7 and 9, LeaveBattlefield from the Ticker, Training Grounds queue calls

## Friends (PR #43, this PR)

- **blocked:** removing app-only rows from Blizzard's own list: it would mean replacing Blizzard's data provider, which taints the friends frame (rows stay dimmed)
- **done (deferred C):** class icon themes atlas/square/letter (Phoenix_UI_Friends/Extras.lua)
- **done (deferred C):** friends frame border and tab line styling
- **done (deferred C):** suggestions on Blizzard's add-friend box
- **done (deferred C):** Studio mover check for the free-floating panel (test)
- **left:** in-game check: FriendsFrame_UpdateFriendButton hook, recent allies data shape, BNet note dialog

## Sentinel error reporter (PR #43, this PR)

- **done (deferred C):** compartment entry: Shift+click on Phoenix's compartment entry opens Sentinel (existing, Core/Entry.lua)
- **left:** opt-in dev recorder (change-only streams, orphan-session recovery): larger design, not started
- **done (deferred C):** dev event-trace panel (`sentinel.trace`, `/pui trace`; wraps Kernel.Fire only while on; Phoenix_UI_Sentinel/Extras.lua)
- **done (deferred C):** warning baseline (errors seen in 3+ sessions) and the one-time excess warning (`sentinel.baselineWarn`)
- **left:** fixed-in state synced from the dashboard: needs a Companion-to-addon channel that does not exist yet
- **blocked:** protected decode of a received report: needs an approved pcall exception tag (guardrails); the checksum guards it today
- **left:** BugGrabber display object: BugGrabber picks its display from the `X-BugGrabber-Display` TOC field at its own load, and Sentinel is load-on-demand, so the global would not exist then; needs a Core-side shim
- **left:** removing the retired safe-mode code paths: cleanup for the polish pass (setting hidden and inert)
- **done (deferred C):** sound list from the media library (four game sounds, then every media sound)

## Diagnostics and profiler (PR #43, this PR)

- **done (deferred C):** per-page CPU chip in the settings header (`sentinel.cpuChip`; Phoenix_UI_Options/CpuChip.lua)
- **left:** top-addons readout on hover
- **left:** self-measurement through the game's addon profiler with signature check
- **left:** privacy kit system-string allow-list
- **left:** Diagnostics as its own settings page
- **left:** A/B report window

## Plan-wide (PLAN section 6)

- **left:** Arabic locale and real translations (needs a translator)
- **left:** plugin system (build last, by plan)
- **left:** Forever child
- **blocked:** CurseForge/Wago release: an external publishing action that needs your approval; not done by an agent
- **left:** raid debuff tiles with per-instance data packs (needs data from the test phase)
- **left:** nameplate NPC colour data packs (needs data)
- **done (deferred B):** Data Bars user bars and LDB host
