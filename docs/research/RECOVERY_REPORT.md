# Phoenix_UI recovery diagnosis (read-only)

Date: 2026-10-28 (Asia/Kuwait). Scope: tested build `review-99ca1d5` (feat/qol-b), compared with the "old Phoenix" the user liked.
Sources on the box:
- `v2/`: `git archive 99ca1d5` of the current code (taken from /workspace/pui_skins, which was left untouched)
- `old_src/`: `git archive refs/pull/1/head` (13cb3f8, 2026-10-23 01:00). This is the old Phoenix.
- `old/`, `oldj/`: the user's "old hpoenix" screenshots (25 PNGs, copied from the PC through a temp zip that was then deleted)
- `shots/`: the 16 test screenshots, downscaled
- `gh/`: a full clone with every PR ref

No code changed, nothing pushed, nothing installed.

---

## 0. Which build is the "old Phoenix"?

The user's folder contains **screenshots only, not code**. Their content identifies the build:
- the window title badge reads "v2.0.0 BETA"
- the Bugs viewer shows stacks in `Modules/ActionBars/Bars.lua`, `Modules/Minimap/Minimap.lua`, `Core/Namespace.lua` and `Core/Modules.lua`
- the screenshots are dated 2026-10-23 12:42

The only git ref containing that tree is **`refs/pull/1/head` (PR #1, head 13cb3f8)**. This is the "plan v2 S1–S18" line built on 21–23 Oct: one `Phoenix_UI` addon, plus the load-on-demand `Phoenix_UI_Options` and `Phoenix_UI_Data`. It is **not on any branch**. It survives only as the PR ref, so a branch should be cut from it before anything else happens. It is also not `main` / `legacy-baseline` (4464963), which is the 11.0.58 Vajalol code with bundled third-party addons (MSBT, MoveAny, PGF, BuffOverlay, idTip). That code breaks the "original code only" rule and must not be the base.

The 25 Oct "main-v2: start from empty tree" (3f7d27d) is the from-scratch rework the user regrets. The tested 99ca1d5 descends from it.

## 1. What the old Phoenix (PR #1 / 13cb3f8) was

**Structure** (`old_src/`)
- A single addon, `Phoenix_UI.toc` (Interface 120105), plus a Forever TOC.
- `Phoenix_UI_Options` is load-on-demand. `Phoenix_UI_Data` holds the quest data and loads on demand.
- `Core/` (3.6k lines): Namespace, Events, DB, Profiles, Migrations, Theme, Style, Skin, Secret, Flavor, EditMode, Errors.
- `UI/` (2.4k): a real widget library. `UI/Widgets/{Button,Toggle,Slider,Dropdown,MediaPicker,ColorSwatch,Scroll,Section,Chips,Popup,StylePicker}.lua`
- `Modules/` (24.7k): 31 feature folders, each a self-contained module. Examples: UnitFrames 4.1k, CastBars 1.7k, Tracker 1.5k, Quests 1.5k, NamePlates 1.5k, ActionBars 1.4k, GroupFinder 1.4k, GroupFrames 1.1k, Chat, MythicPlus, Encounters, Sim, Auras, DataTexts, Bags, Movers, Tooltip, Bugs, Minimap, ItemLevel, CooldownText, Skins, CombatText, Quality, PvP, AFK, Automation, DamageMeter, General.
- **Every module maps 1:1** to `Phoenix_UI_Options/Options/<Module>.lua` and `Phoenix_UI_Options/Previews/<Module>.lua`. One owner, one page, one preview.

**Options UI** (screenshots `oldj/sheet0–2`; code in `Phoenix_UI_Options/Config/*`)
- The window has a header (logo, version badge, search, three icon buttons and a close button) and a **collapsible left tree** in 7 groups (`Config/Groups.lua:10-27`): Home, Frames, Bars, Combat, Interface, Content and Phoenix, with sub-headings. Every module sits in exactly one group.
- Each page has the same layout:
  - title, description and an **Enabled toggle with an ACTIVE badge**
  - a **LIVE PREVIEW card** with real-looking samples (health bars, cast bar, nameplates, encounter warnings)
  - **section cards in two columns** (e.g. APPEARANCE | TYPOGRAPHY)
  - **dropdowns with font and texture previews** inside the list
  - a gear button for per-element text settings (font size, outline, shadow, colour, position, offsets)
- The footer shows the profile, the number of modules active, "Changes apply instantly", a window scale slider, Reload UI and Close.
- The content area clips its children (`Config/Window.lua:581 content:SetClipsChildren(true)`), so nothing draws outside its box.

**Visual style**
- Dark charcoal panels with an ember-orange accent, used sparingly.
- Consistent 1px borders, small caps section headings, and a consistent icon set (`oldj/sheet2` "Phoenix icon set": 48 duotone glyphs).
- Calm and dense, with nothing overlapping.

**Behaviour that made it good**
- It **skinned Blizzard's own frames and buttons**, post-hooking `ActionButton_UpdateRangeIndicator` and `UpdateUsable` (`Modules/ActionBars/Buttons.lua:8,22,199`). Icons, range and usability were Blizzard's, so they were always correct.
- It had a Bugs viewer in BugSack style (`oldj/sheet4`) that actually listed errors with full stacks.

**Known bugs in the old build** (visible in the user's own Bugs screenshot). Both are one-line fixes:
- `Modules/ActionBars/Bars.lua:262-264`: the page-arrow FontString gets `SetText` without a font, which raises "Font not set".
- `Modules/Minimap/Minimap.lua:459`: registers `MINIMAP_PING`, which no longer exists in 12.x and raises "unknown event".

## 2. Defects in the test screenshots, with root causes in v2 (99ca1d5)

The **systemic cause** behind most of these: about 495 "passing" tests run against an offline stub (`.tools/harness/wow_stub.lua`) that renders nothing. Layout, clipping, z-order, fonts and real event payloads were never checked in the real client. There is also a code pattern that turns any build-time error into permanent visual garbage. Each view registers itself in `Options.views` only on its **last line**. If anything throws during the build, the half-built frame stays shown forever, because nothing knows to hide it. Meanwhile the error viewer that should reveal the error is itself broken (D9).

| # | Screenshot | Defect | Root cause (file:line) |
|---|---|---|---|
| D1 | new01 | The "Phoenix UI" button sits on the Game Menu's title plate | `Core/Entry.lua:86-107` anchors a `UIPanelButtonTemplate` at `BOTTOM` of GameMenuFrame `TOP` +6. The 12.x Game Menu has a header plate above its top edge, so the button collides with it. The file also **defines `Entry` and `BuildGameMenu` twice** (lines 6/39 and 78/86, two versions pasted together). The styled mockup version is dead code. |
| D2 | new09/10/11-15 | The action bar shows **solid red squares** with doubled key text ("SQ" over "S1"…) | (a) The red comes from `Phoenix_UI_ActionBars/ActionBars.lua:369`, which reads only `(slot, inRange)` from `ACTION_RANGE_CHECK_UPDATE` and ignores the third arg `checksRange`. The API catalog confirms the args are `slot, isInRange, checksRange` (Data/ApiCatalog.json `event:ACTION_RANGE_CHECK_UPDATE`). `Buttons.lua:246` then does `range:SetAlphaFromBoolean(inRange, 0, 1)`, so every action with no valid target (e.g. no target selected) gets the full red overlay (`Buttons.lua:23,137-139,180`, default `rangeMode="overlay"`). The icon is real, but it is buried under red at 50% alpha. The red is absent in new01 (09:18) and appears by 09:21. (b) The doubled hotkey text means **two buttons are stacked**. Bars 1-3 default to `BOTTOM` y=40/74/108 (`ActionBars.lua:29-31`) with size 36 and spacing 2, and buttons grow **DOWN** from the header (`AB.Offset`, `ActionBars.lua:182-184`). Rows overlap, or a stock or item bar sits under them. Abbreviation code: `Buttons.lua:37-56`. |
| D3 | new02/09/10 | The Skins preview text runs over the sample window | `Phoenix_UI_Options/PreviewsSkins.lua:22-76` draws a 300×150 sample at the card's TOPLEFT, then calls `PreviewsGaps.lua:14-29 G.Lines`, which pins up to 10 right-aligned, unwrapped lines at the card's **TOPRIGHT**, on top of the sample and the "LIVE PREVIEW" caption. No space is reserved and nothing wraps. The same helper causes the overlaps on the General (new04), Unit Frames (new05: "Extra texts / Add one…" over the frame sample) and Quests (new06: bottom lines over the footer) previews. |
| D4 | new07→new08 | Theme & Media stays drawn on top of the Tooltip page. Only one narrow column renders, and **every** font shows a check mark | `Phoenix_UI_Options/ThemePage.lua:128-179` registers `Options.views.theme` only at line 177. Column 1 renders and columns 2/3 never do, so `build()` threw partway, most likely in `buildFonts`/`Kit.Slider` (`ThemePage.lua:61-85`, `Kit.lua:192-237`). A "FontString:SetText(): Font not set" from a font that failed to load fits, and the old build hit the same class of error. Because the throw happened before line 177, `Options:HideViews()` (`Panel.lua:338-342`) never hides this view, and `TP:Refresh` (which clears the checks) never runs. The exact message needs BugSack or `/console scriptErrors 1`, since Sentinel can't show it (D9). |
| D5 | all options shots | The sidebar runs past the bottom of the window (Cooldown Manager … Spark, Cast History, PvP drawn over the chat frame) | `Panel.lua:94-108` makes the sidebar a plain Frame with no ScrollFrame and no `SetClipsChildren`. `RenderSidebar` (`Panel.lua:262-325`) stacks about 50 pages at 36 px each, which needs about 1,900 px, in an 860 px window (`Panel.lua:10`). Nav lists 50+ pages (`Nav.lua:11-70`). |
| D6 | new04-08 | The sidebar highlight stays on "Skins" while other pages show | The highlight is computed from `self.page` (`Panel.lua:273`). Either the page was opened through a path that doesn't re-render the sidebar, or a leaked orphan frame (D4 pattern) left an old item set. Low confidence; check in game. |
| D7 | new11-14 | The setup wizard draws over the open Dashboard, and earlier steps stay visible under later ones (scale cards "Compact 0.85x / Pixel perfect / Large" and "Fine tune" under the Layout step; Look cards under the Skins step) | (a) `Phoenix_UI_Setup/Wizard.lua:147-155` builds the wizard at DIALOG strata over the Options window, which is not hidden or dimmed (no modal shade). (b) Same orphan pattern as D4. `page()` (`Wizard.lua:622-630`) stores `f.pages[id]` only after `Pages[id](f)` returns. `Pages.scale` (`:304-339`) builds its cards, then `Kit.Slider` at `:323`. A throw there leaves the frame unregistered, so `SU.Render` (`:635`) can never hide it. The same happens to `Pages.look` (`:410+`). The common factor with D4 is `Kit.Slider`. |
| D8 | new00 | Studio shows hundreds of movers at once and is unreadable | `Phoenix_UI_Options/StudioModel.lua:26-33 Studio.Ids` returns **every** registered element in `Layout.order` (59 `RegisterElement` sites, many in loops: bars 1-8, item bars 1-5, boss 1-5, arena, raid tools, Sentinel toasts, waypoint…), whether or not the module is on or the frame exists. `Studio.lua:546-551` creates a mover for each. `ApplyFilter` (`Studio.lua:373-384`) filters only by category, and the default category is "All". The right-hand inspector shows 20+ controls for one element. |
| D9 | new15 | The Sentinel window is empty: no title, no counts on the S0-S3 chips, no body text | `Phoenix_UI_Sentinel/Reporter.lua`: the chips are created as "All/S0…" (`:123-127`), and their counts are written by `PaintFilters` (`:267-276`), the first call in `Paint()` (`:281-309`). The title is written at `:300`. Since nothing painted, `R:Open` (`:311-322`) or the first line of `Paint` threw: `Opts()`/`Sections:SeverityCounts`/`S.Alerts:Seen()`. Layout bug too: the body scroll and the side list both anchor at x=14 (`:134` and `:140`) until `PaintSections` moves them. **A second, older Sentinel window also exists** (`Phoenix_UI_Sentinel/Panel.lua:27-235`, "Phoenix UI - Sentinel"), and the Options Sentinel page and Diagnostics page are a third and fourth way in. It uses Blizzard red `UIPanelButtonTemplate` buttons (`Reporter.lua:14-18`), which clash with the rest of v2's look. |
| D10 | new07 | Theme & Media marks all 49 fonts as selected | This is D4: `TP:Refresh` never ran. |
| D11 | new05 | Unit Frames preview: "Extra texts / Add one: health percent @ TOPRIGHT…" overlaps the bars, and the frame mock is cut off | This is D3 (`G.Lines` at TOPRIGHT) plus fixed sample sizes in `Previews.lua`. |
| D12 | general | The UI uses opaque brand names (Ascent, Embers, Pulse, Spark, Flow, Vault, Oracle, Wisdom, Sentinel, Ledger, Studio) | `Nav.lua:28-59`. The user has to guess what "Pulse" or "Flow" means. The old build used plain names: Encounters, Combat Text, Automation, Bags. |

## 3. Duplicated and overlapping settings and modules (v2)

- **Fonts in three places.** The font picker is on Theme & Media (`ThemePage.lua:61-85`) and on the separate Fonts page (Nav `Fonts`, `Core/Look.lua`), and there is per-module "Text size/outline" in 7+ modules (Arena, Embers, Minimap, Pulse, QuestTracker, Chat, Spark, UnitFrames).
- **Theme pages split into five:** Theme & Media, Fonts, Colours, Glows and Cursor, plus Celebrations. The old build had one General page plus Fonts/Textures/Sounds sub-pages under the Phoenix group.
- **Icon shape** is defined three times: global `Core/Look.lua`, `Phoenix_UI_ActionBars/Extras.lua` and `Phoenix_UI_HUD/ButtonBin.lua`.
- **Role and class icons:** `Core/Look.lua` vs Chat, RaidFrames and Friends.
- **Panel opacity:** `Core/Theme.lua` vs `Phoenix_UI_Chat/Chat.lua`.
- **Queue-pop countdown:** `Phoenix_UI_GroupFinder/QueueHelper.lua` and `Phoenix_UI_HUD/Minimap.lua`.
- **Experience/Honor:** `HUD/DataBars.lua` vs `Spark/Feed.lua` and `PvP/Columns.lua`.
- **Out-of-range opacity / range spell id:** Arena, Nameplates and RaidFrames each have their own.
- **"Developer recorder" and "Error count badge"** are registered twice (`Core/SentinelHook.lua` and `Phoenix_UI_Sentinel/Recorder.lua`/`Alerts.lua`).
- **Error UI ×4:** `Sentinel/Panel.lua`, `Sentinel/Reporter.lua`, the Options `SentinelPage.lua` and `DiagPage.lua`.
- **Moving frames ×4:** Studio, `Core/Movers.lua` (Blizzard windows), the Options `BlizzardPage.lua` ("Blizzard elements") and Edit Mode.
- **Layout presets ×2:** wizard `Phoenix_UI_Setup/Presets.lua` and Studio "Layouts".
- **Item bars ×2:** the old single item bar (`ActionBars/Special.lua`) and 5 auto item bars (`ActionBars/ItemBars.lua`), whose bar 5 also carries teleports.
- **Bolt-on files:** **29 `Extras*.lua` files**, plus `PreviewsExtras*`/`PreviewsGaps`/`PreviewsItemBars`. Features were added in later passes rather than designed into their module. `Previews.Update` is wrapped by monkey-patching **5 times** (`Previews.lua:1292`, `PreviewsExtras.lua:17`, and `PreviewsItemBars.lua:146,183,236`).
- **Packaging:** 33 `Phoenix_UI_*` addon folders, against 1 (+2 load-on-demand) in the old build. There are 2,439 settings and about 50 sidebar pages, and the sidebar can't scroll.
- **Settings in two places:** the Dashboard "Quick toggles" duplicate the settings on their own pages.

## 4. Recommendation

### Option A: Restore the old Phoenix (PR #1, 13cb3f8) as the base and port only proven v2 pieces. **Recommended.**

**Why**
- It is the design the user explicitly loves.
- Its architecture is already clean: one addon, 1:1 module/options/preview files, a real widget library, a clipped and scrolled content area and a grouped tree.
- It targets 12.1.5 (Interface 120105), is already Midnight-aware (`Core/Secret.lua`, `Core/Flavor.lua`) and was written clean-room.
- It skins Blizzard's real buttons, so icons and range are correct by construction.

**Work**
1. Cut a branch `restore/v1-ui` from `refs/pull/1/head`. Today it exists only as a PR ref.
2. Fix its known errors (Bars.lua:262, Minimap.lua:459), then run a real in-game smoke test of every page.
3. Port by value, one at a time, with an in-game check of each. Proven v2 pieces worth keeping:
   - the Arabic shaper (`Core/Shaper.lua`)
   - signed fixed-errors sync and the Uploader 1.2.0 contract
   - full locales
   - the CI guardrails and manifest tooling
   - auto item bars logic (data tables only)
   - party CD tracker
   - loot roll
   - Masque glue
   - the secret-value-safe patterns for 12.x
   - the "Font language" switch

   Each one has to be re-homed into an existing old module and page (e.g. item bars into Modules/ActionBars plus its options page), not added as a new addon.

**Effort:** about 1–2 days to restore and stabilise, then about 0.5 day per ported feature.

**Risk:** low to medium.
- The old build had fewer features, so the gap list must be re-checked.
- PR #1 needs its own in-game pass, since it also had "Font not set" errors.
- Saved variables differ (`PhoenixUIDB` vs v2's DB), so test on a fresh WTF profile or add a one-time migration.
- The `vq8-website` fixed-errors endpoint expects v2's Sentinel format, so the Bugs uploader needs a small adapter.

### Option B: Fix v2 in place

**Work**
- Make every view and page register itself before it builds, and wrap builds in error capture.
- Add a sidebar scroll with clipping, a modal wizard, and range handling via `checksRange`.
- Fix the bar default positions and the G.Lines layout.
- Have Studio show only enabled and existing elements.
- Merge the four error UIs into one, collapse the 5 theme pages and 29 Extras files, rename the brand-named modules, and redo the 50-page IA.
- Then do a visual pass of every one of the about 50 pages in game.

**Effort:** 4–7 days before it is merely "not broken". The design the user dislikes stays.

**Risk:** high. The breadth (76k lines, 2,439 settings, 33 addons) was never visually verified. More hidden orphan or overlap bugs are likely, and the result still won't look like what the user loved.

**Honest verdict:** v2's core plumbing is reasonable (Schema, Kernel, CombatQueue, Ticker and the secret-value handling). Its UI layer and its sprawl are the problem. Restore the old build as the product and treat v2 as a parts bin.

## 5. Prioritised recovery plan

1. **Freeze v2.** Make no more features or PRs on that stack. Keep the PRs open; do not delete or force-push anything.
2. **Preserve the old code.** Push branch `restore/v1-ui` at 13cb3f8. This needs the user's OK, since it is a push.
3. **Make the old build clean.** Fix `Modules/ActionBars/Bars.lua:262-264` (set a font before SetText) and `Modules/Minimap/Minimap.lua:459` (drop or guard MINIMAP_PING). Install it on its own (only `Phoenix_UI`, `Phoenix_UI_Options` and `Phoenix_UI_Data`, and remove or disable the 33 v2 folders first, with permission). The user then checks each page in game with BugSack on.
4. **Bring back proven infrastructure** without changing the UI: CI guardrails and manifest, locales and the Arabic shaper, and the Bugs uploader adapter for the signed fixed-errors list.
5. **Port features one by one**, in user priority: action bar extras (item bars and battle res) → party CDs → loot roll → Masque → anything else from the gap list. Each goes into an existing module and page, with a screenshot check in game before the next one starts.
6. **Add a visual gate** to "done": every task needs an in-game screenshot of the affected page or frame, plus zero errors in BugSack. The stub tests alone don't count.
7. **Only then** set the version (2.0.0-beta2 from the restored line), write the changelog and do store work.

If the user still chooses Option B, the minimum fix order is:
1. Make views register before they build, and catch build errors. This fixes D4, D7 and D10.
2. Fix D9 (the error viewer), so the remaining errors become visible.
3. Fix D2 (range and bar overlap) and D5 (sidebar scroll).
4. Fix D3 (preview text) and D8 (Studio filter).
5. Fix D1, then consolidate the duplicates in section 3.
