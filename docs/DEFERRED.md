# Deferred items (consolidated, PRs #31-#43)

Generated from the Deferred lists in `docs/PLAN.md` (sections 4, 5 and 5.21 step-status lines and section 6), the CHANGELOG and this PR. Each item is a backlog entry, not a to-do: it is scheduled during the test, fix and polish phase after the end-to-end build. Items move out of this file when they are built or dropped by a decision. Deferred batch A (stacked on PR #43) marks its items in place: **done**, **blocked** with the reason, or **left**. Deferred batch B (stacked on batch A) marks the Studio and HUD items the same way and adds live previews for the Action Bars, Cooldown Manager and Resource Bars extras. Moved out in this PR: Arena's Gladiator progress (now on the PvP rated card) and Embers' Pulse page for the combat timer (built in step 9b).

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

- quest-item SecureActionButtons
- auto-share

## Reminders (PR #40)

- season consumable IDs (pack empty)
- talents by zone
- per-reminder sound/icon

## Embers damage meter (PR #40)

- show/hide-all and reset hotkeys (Binding ledger)
- Forever threat meter
- window snapping

## Ascent Mythic+ (PR #40)

- forces current-pull preview
- score projection
- vault planner

## Flow QoL (PR #41)

- leave-queue popups
- open containers
- Train All
- tutorials/banners
- `/gg`
- queue protection
- Tab binder
- screenshot on achievement

## Group Finder (PR #41)

- raid boss-defeated/lockout filters (no encounter API for search results in the catalog)
- cancel-oldest button (`C_LFGList.CancelApplication` not in the catalog)
- Raider.IO variables and region badge
- plugin sort hooks
- click-to-insert word list
- Studio mover for the detached panel

## Raid Tools (PR #41)

- notes out of combat
- boss-frame tooltip line
- stats window

## Pulse (PR #42)

- next-three HUD
- private-aura sounds
- per-boss options
- BigWigs bar-style bridge
- Blizzard timeline view hide

## Arena (PR #42)

- pet frames
- class-icon aura priority
- dispel tracker
- range page
- click-binding editor
- text page per text
- FrameSort numbering
- 'only triggerable by me' DR CVar
- healer-only variants

## Spark (PR #42)

- per-event sounds
- aura gain/fade rows
- ability substitution/abbreviation lists
- visual trigger builder
- profile import from MSBT

## Cast History (PR #42)

- Masque
- Addon Compartment entry
- Embers link button

## PvP UI (PR #43, this PR)

- Read-only overlay on Blizzard's conquest frame (the rated card docks beside the PvP window instead)
- Automatic Legend and Strategist achievement IDs per season (settings take the ID; Phoenix counts wins until then)
- Rated match history page (stored, read by the card; no list window yet)
- Drag-to-reorder column headers on the scoreboard itself (order is set in the list editor)
- Per-round Solo Shuffle win/loss while the game keeps it secret (shown only once plain)
- In-game check: GetPersonalRatedInfo bracket indexes 7 (Shuffle) and 9 (Blitz), LeaveBattlefield from the Ticker, Training Grounds queue calls

## Friends (PR #43, this PR)

- Removing app-only rows from Blizzard's own list (they are dimmed; changing Blizzard's data provider would taint)
- Class icon theme choices beyond the default atlas set
- Friends frame border and accent tab styling (Skins pass)
- Invite-search dropdown on Blizzard's add-friend box (the Phoenix panel search covers it)
- Studio mover check for the free-floating panel
- In-game check: FriendsFrame_UpdateFriendButton hook, recent allies data shape, BNet note dialog

## Sentinel error reporter (PR #43, this PR)

- Addon Compartment / minimap entry for the badge (a movable floating badge ships)
- Opt-in dev recorder (change-only streams, orphan-session recovery)
- Dev event-trace panel for Phoenix's bus
- Warning baseline of stable fingerprints and the one-time excess-error warning
- Fixed-in state synced from the dashboard (marked by hand in game today)
- Protected decode of a received report (needs an approved pcall exception tag; the checksum guards it today)
- Registering as a BugGrabber display object (Sentinel listens to BugGrabber's public callback today)
- Removing the retired safe-mode code paths (setting hidden and inert)
- Sound list from the media library instead of four built-in sounds

## Diagnostics and profiler (PR #43, this PR)

- Per-page CPU chip in the settings window (Profiler:OwnerTotal is ready)
- Top-addons readout on hover
- Self-measurement through the game's addon profiler with signature check
- Privacy kit system-string allow-list
- Diagnostics as its own settings page (it is a tab in the reporter window and /pui diag)
- A/B report window (Profiler.AB returns numbers; no UI)

## Plan-wide (PLAN section 6)

- Arabic locale and real translations
- Plugin system (build last)
- Forever child
- CurseForge/Wago release
- Raid debuff tiles with per-instance data packs
- Nameplate NPC colour data packs
- Data Bars user bars and LDB host
