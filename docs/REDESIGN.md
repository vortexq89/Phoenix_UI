# Phoenix UI: Redesign (Phase 1 findings, Phase 2 plan)

Written 2026-10-22 after the first in-game test of 2.0.0-beta1 (WoW 12.1.5, Interface 120105).

What the user reported:
- The addon works but needs a lot of work.
- Not a single icon works in game.
- The live preview does not work.
- Texture pickers show no samples.
- Features are not deep enough.
- Settings are missing and badly organised. Modules of the same kind belong in one section.
- The GUI needs a professional rework.

## 1. Phase 1 root-cause investigation

### Evidence gathered (read-only)

I read the following from the user's PC:

- **Installed copy:** `Interface\AddOns\Phoenix_UI`. It has 308 files and no strays from older builds. Its file list matches the repo's package. The robocopy excludes did **not** drop any media: all 3 icon atlases, 37 textures and 85 fonts are present.
- **SavedVariables:**
  - `PhoenixUIDB` shows the window was opened and moved. The profile is almost untouched: ActionBars `iconZoom`/`macroText`, PvP `tabBinder`, DataTexts `speed` and Bugs `sound`.
  - `PhoenixUIBugsDB.reports` is empty.
- **`!BugGrabber.lua`:** this is 51 errors across sessions 2–192. The current session is 198.
  - Only **one** of them is from Phoenix: `Modules/Tooltip/Tooltip.lua:88: attempt to call a nil value`, ×43, session 192 (2026-10-21 20:12 Kuwait). That line was `tt:GetItem()`.
  - Sessions 193–198, which are the test sessions where only Phoenix + BugGrabber/BugSack were enabled per `AddOns.txt`, recorded **no Lua errors at all**.
  - The other entries belong to EllesmereUI, WindTools, sArena, Tust_EUI, PremadeGroupsFilter, MountsJournal and BigWigs.
- **`Logs\`:** there is no `taint.log` and no texture warnings.

### Icons: format and paths verified correct, cause not provable offline

| Check | Result |
|---|---|
| Format | 32-bit TGA. Icon atlases and brand art are RLE (type 10); bars are uncompressed (type 2). Power-of-two sizes (256², 512², 1024², 256×32…). 8 alpha bits, bottom-left origin, TGA 2.0 footer. |
| WoW support | warcraft.wiki.gg [TextureBase:SetTexture](https://warcraft.wiki.gg/wiki/API_TextureBase_SetTexture): "Custom images must be in BLP, JPEG, PNG, or TGA format with power-of-two dimensions … TGA … 32 bpp RGBA; RLE is supported." PNG has been supported since 10.0.7, but it needs the explicit `.png` extension. |
| Real-world comparison | I parsed 1 077 TGAs from the user's other addons. 92 working files use exactly our layout: RLE, 32 bpp, bottom-left origin, footer. 607 use the uncompressed one. No RLE packet in our files crosses a scan line. |
| Decode | Decoding the atlases with PIL gives the expected glyph grid. Index 1 = home is top-left, matching `Core/IconData.lua`. |
| Paths | `Interface\AddOns\Phoenix_UI\Media\Icons\Icons24` etc. The folder name matches `ns.ADDON`, and the case matches on disk (NTFS is case-insensitive anyway). |
| Code | `Icons:Apply` sets the file, then the tex-coords. Tinting is `SetVertexColor` with theme tokens (alpha 1). Tier choice uses `PixelUtil.GetPixelToUIUnitFactor`. Nothing raised an error in 6 sessions. |

**Conclusion:** the files, paths and calls all follow the documented rules, and nothing failed loudly. The failure is therefore silent, or the report means something else, for example icon *buttons*, action-bar icon options, or icons that are present but hard to see.

I could not see the game, so instead of guessing I added a **self-test** (below) that records what the client actually did.

### Live preview and texture samples

- **Live preview:**
  - The wiring is correct: `DB:Set` fires `PUI_SETTING_CHANGED (module, path, value)`, and every preview stage listens and redraws while visible.
  - But only **11 of 24** modules have a preview, and each preview is a card *inside* the scrolling page. As soon as the user scrolls to the option they are changing, the preview scrolls out of view, so it looks dead.
  - Also, nothing previews on *hover* (EllesmereUI previews a dropdown item while you hover it).
  - This is a GUI architecture problem → Phase 2 (sticky preview pane).
- **Texture samples:**
  - The picker does draw every bar texture, but tinted in the accent orange at 60 % alpha.
  - Our 24 procedural bars differ only by subtle shading. Rendered at 16 px tall in orange (checked offline), most look identical, which reads as "no sample".
  - Partial fix now: neutral light tint, with the accent kept for the chosen row.
  - Real fix in Phase 2: picker cards, plus more distinct textures.

### Fixed in this phase (commit `Phase 1: …`)

1. **Tooltip crash (proven, ×43).** The `TooltipDataProcessor` post-calls also run for tooltips that are not GameTooltips (embedded/third-party), and those have no `GetItem`/`GetUnit`.
   - All three post-calls now check `usable(tt)` first.
   - The item quality border reads `data.hyperlink` first and falls back to `GetItem`.
2. **`/pui diag` self-test (new, `Core/Diag.lua`).** This gives the next in-game session evidence instead of a guess.
   - **What it checks:**
     - It loads every bundled texture (3 icon atlases, 5 brand files, 24 bars, glows, border, shapes) into probe textures.
     - It waits for `IsObjectLoaded` and compares the native size with the file.
     - If the settings window has been opened, it records up to 24 on-screen glyph textures: file, size, effective alpha, vertex colour, tex-coords, layer and visibility.
   - **Where the results go:**
     - Saved to `PhoenixUIDB.global.diag`.
     - It runs quietly once per version 8 s after login, and prints only if something failed.
     - `/pui diag` runs it on demand and prints a summary.
   - Smoke test added.
3. **Texture picker** rows use a neutral tint (accent only on the selected row), so each texture's own shading shows.

**What to ask the user:** type `/pui`, then `/pui diag`, then `/reload`. After that, read `WTF\Account\*\SavedVariables\Phoenix_UI.lua` → `global.diag`. It tells us exactly whether any media failed to load, and what the icons in the window look like to the client.

## 2. AddOns study (user's folder, 77 folders, read-only)

### Inventory

| Addon | Interface | Author | Licence | Purpose / notable design |
|---|---|---|---|---|
| **EllesmereUI** (+20 modules, Options, Locales) | 120000–120105 | Ellesmere | Custom, all rights reserved | Full UI suite. One shared options panel built on demand (`EllesmereUIOptions`, 98 files, ~90k lines). See lessons below. |
| EllesmereUI_WindTools | 120100/120105 | fang2hou, XanaHopper | Restricted (GPLv3 inside ElvUI/NDui only) | Port of WindTools modules as an EUI plugin. Many secret-value errors in BugGrabber. |
| Tust_EUI | 120000–120105 | Tust | none | EUI companion plugin (sounds, presets). Taints LFG. |
| BigWigs (+Core/Options/Plugins + 20 zone packs) | 1.15–12.1 | Funkeh et al. | ARR (fork on GitHub OK) | Boss mods. AceConfig tree: General → Bars/Messages/Sounds/Colors/Countdown plugins, each with a **Test** button and movable **anchors**. Per-ability option flags (icon, bar, sound, emphasise) shown as compact toggles. Load-on-demand zone packs. |
| LittleWigs (+10 packs) | 1.15–12.1 | Funkeh, Delk | ARR | Dungeon boss mods on BigWigs. |
| !BugGrabber / BugSack | 1.15–12.1 | Funkeh | ARR | Error capture + session browser. The model for our Bugs module. |
| Auctionator | 1.15–12.1 | plusmouse, Borjamacare | ARR | AH tabs inside Blizzard's frame; options split into "Basic / Tooltips / Selling / Shopping / Profile". |
| MythicDungeonTools (+_UI) | 120105/120107 | Nnoggie | GPL-2.0 | Large standalone window. Load-on-demand UI addon split from data. Sidebar of pulls, map canvas. |
| RaiderIO | 120100/120105 | Vladinator et al. | ARR | Tooltip enrichment. Config = checkbox groups by "General / Tooltip / Tooltip lines / Profile". Data in separate LoD addons. |
| PremadeGroupsFilter (+EUI skin) | 120105 | B. Saumweber | GPL-2.0 | Simple filter UI + advanced expression box. Taints LFG under 12.x (BugGrabber). |
| sArena_Reloaded | 120100/120105 | Stako / Bodify | MIT except ARR files | Arena frames. **`/sarena test`** shows fake frames for live layout; layout presets ("BlizzArena", "Gladiuish", "Xaryu"…). |
| MoveAny | 120105 | D4KiR | ARR | Move/scale/alpha any frame. Searchable list with per-frame rows, grid and snap. |
| SpecBisTooltip | 120105 | D4KiR | ARR | Tooltip lines. |
| MountsJournal (+UI, EUI skin) | 120105 | sfmict | Apache-2.0 / GPL-3 skin | Mount journal replacement; LoD UI addon. |
| BetterWardrobe (+SourceData) | 120100 | SLOKnightfall | ARR (no redistribution) | Transmog tabs. |
| AutoQueue | 120105/120107 | Azaleth | none | Auto-accept role checks. |
| idTip | 1.15–12.1 | silverwind | none | IDs in tooltips, zero config. |

Enabled in `AddOns.txt` but not installed: GreatVaultKeyInfo, KeystoneLoot, NemHealerAlerts, TooltipID, MDT_Legacy, TrufiGCD.

### Lessons for Phoenix (ranked)

1. **Grouped sidebar with a few strong sections** (EllesmereUI `ADDON_GROUPS`: Core / QoL / Reskin, order authoritative). Our five categories (System / Interface / Combat / Social / Utility) mix kinds. For example, "Interface" holds unit frames, bags-like item level, minimap and data texts.
2. **Each big module is several pages, not one long scroll.** EUI Nameplates = Display Layout · Display Bars · Colors · Text Coloring · General. Unit Frames and Raid Frames have *manager pages* with a unit/frame selector at the top.
3. **The preview stays on screen.** EUI builds the nameplate preview once, keeps it pinned above the controls and refreshes it on every setter and every panel re-open.
   - It has "eye" toggles to show optional elements in the preview: raid marker, classification, target glow, absorbs.
   - It re-randomises sample values on tab switch.
   - Dropdowns can call `onItemHover` to preview an item before it is picked.
4. **Central Fonts and Textures pages.** These are card pages that mirror every module's font/texture setting with the same DB keys and an "apply to all" action. One place to restyle everything.
5. **Inline cog popups and apply-to-all.** Secondary settings sit behind a cog on the row (we have this, Options 2.1). "Apply to all units" plus "copy from" (we have it for unit frames; EUI has it everywhere).
6. **Test/Unlock modes.** BigWigs bar **Test** buttons, sArena `/sarena test` fake frames, EUI Unlock Mode (anchors, grid, snap, per-element nudging). Every positional module needs a "show test frames" button.
7. **Presets and a first-install style picker.** EUI StyleChoice/FirstInstall popups and sArena layout presets let new users get a complete look in one click.
8. **Global search** that lands on the exact row and highlights it (EUI GlobalSearch). Ours searches labels only.
9. **Load-on-demand options addon** (EUI, BigWigs_Options, MDT_UI). This keeps login memory low. Phoenix should move `UI/Config` into `Phoenix_UI_Options` with `## LoadOnDemand: 1` later.
10. **What not to copy:**
    - EllesmereUI, WindTools, Tust, PremadeGroupsFilter, MountsJournalUI and EllesmereUIQuestTracker all appear in BugGrabber with *secret-value* errors or `ADDON_ACTION_BLOCKED`.
    - The cause is touching LFG, chat or tracker internals or comparing secrets.
    - Phoenix's rule set (IsSecret before truthiness, no combat log, cosmetic-only on secure frames) must stay. Every new feature goes through `tools/check_api.py`.

### Media found and licences

About 4 300 media files. Only the open-licensed ones are candidates. Copied to `/workspace/phoenix_media_candidates/` with `MANIFEST.md` (not committed):

- **22 sounds (CC0):**
  - 2 BigWigs alerts (unfa).
  - 2 × 10 countdown voices, "Jim" (tekgnosis) and "David" (davidbain).
- **10 font files / 7 families (SIL OFL 1.1):**
  - Noto Sans SemiCondensed from BigWigs.
  - Cinzel Decorative, Poppins, Changa, Exo, Fira Code and Chivo Mono, re-sourced from google/fonts because the addons that bundle them don't ship their licences.
- **7 textures (Apache-2.0):** MountsJournal glyphs (low value).

**Not safe:**
- everything from EllesmereUI (ARR, JiberishUI icons, commercial fonts)
- WindTools (restricted)
- Tust (no licence)
- BigWigs icons, Victory sounds, Amy (BY-NC) and Heroes (© Blizzard)
- BugSack
- sArena textures (Blizzard copies)
- MDT and PGF (GPL-2.0, incompatible with MIT)
- all ARR addons

## 3. WeakAuras in Midnight

WeakAuras has **no retail Midnight version** and none is planned. The team announced this on 2025-10-03 ([Patreon "WeakAuras x The Addon Apocalypse"](https://www.patreon.com/WeakAuras/posts/weakauras-x-140349416), [Wowhead](https://www.wowhead.com/news/no-weakauras-addon-for-midnight-378740)) and reaffirmed it on 2025-11-28 ([Wowhead](https://www.wowhead.com/news/still-no-plans-for-weakauras-in-midnight-update-from-weakauras-379433)).

Their reason: secret values on the player's *own* buffs, resources and cooldowns make conditions, actions, multi-triggers and clones impossible. Even replicating the built-in Cooldown Manager is impractical. Classic is still supported.

**What Phoenix can do: an "Auras & Cooldowns" tracker (Phase 2), within the 12.x rules:**

- **Source:**
  - Skin, re-arrange and extend Blizzard's Cooldown Manager viewers (Essential / Utility / Buff Icon / Buff Bar), which already receive the protected data.
  - Add *display* options only: size, spacing, rows, zoom, borders, fonts, swipe/edge, glow on proc using Blizzard's own glow events where exposed, and sound/countdown cues on events that are not secret.
- **Secret data:** where cooldown or aura data is secret, pass it straight into widgets that accept secrets (`Cooldown:SetCooldownFromDurationObject`, StatusBar with secret values, `C_CurveUtil` colour curves). Never compare it.
- **Non-combat trackers** (fully allowed):
  - consumables, flask/food/rune/augment reminders
  - missing raid buffs out of combat
  - durability
  - M+ affixes and keys
  - weekly vault progress
  - reputation/XP/currency
  - profession cooldowns
- **Rules:** no imports of WA strings, no custom Lua triggers (taint + security).

## 4. Proposed settings information architecture

The sidebar has 11 groups, each with an icon. A group expands to its modules, and a module opens to sub-tabs. Every page has a sticky live-preview pane where a preview makes sense. **(new)** marks pages or features that don't exist yet.

| # | Group (icon) | Modules → sub-tabs | Current options mapped here | Gaps (Phase 2) |
|---|---|---|---|---|
| 1 | **Home** (home) | Dashboard · What's new · Quick setup (presets) | Home page, About | **(new)** first-install style picker, preset gallery, health checks (diag summary) |
| 2 | **General** (general) | Theme · Typography · Accessibility · Pixel/scale | General: `theme.preset`, `theme.custom`, `theme.fontScale`, `theme.reduceMotion` | **(new)** UI scale helper, pixel-perfect toggle, class-colour accent option |
| 3 | **Appearance & Media** (skins) | Fonts (card page) · Textures (card page) · Borders & shadows · Sounds | General: `theme.uiFont`, `theme.unitFont`, `theme.barTexture`; Bugs: `sound`; every module's `Text:*`, `Border:*`, `Background:*` mirrored | **(new)** central Fonts/Textures mirror pages with apply-to-all, sound picker with play button, more distinct bar textures |
| 4 | **Unit Frames** (unitframes) | Player · Target · Focus · Pet · Boss · Arena (unit selector) · Party · Raid → tabs Bars · Colors · Text · Auras · Cast bar | UnitFrames: `units.@.*` (texture, background, border, health/name/power text), `classColor`, `powerColor`, `fonts`; GroupFrames: `texture`, `bar`, `fonts`, `background`, `border`, `name`, `status`; CastBars: `bars.@.*` | **(new)** boss/arena styling, auras on frames, portraits, range fade, role/leader icons, test frames |
| 5 | **Nameplates** (nameplates) | Layout · Bars · Colors · Text · Cast bar · Auras · Behaviour | NamePlates: `texture`, `bar`, `background`, `border`, `health`, `healthText`, `name.styled`, `name`, `forces`, `forcesText`, Blizzard features tab | **(new)** threat colours, target/focus highlight, cast bar on plates, debuff row, quest/forces icons, preview eye toggles |
| 6 | **Action Bars & Cooldowns** (actionbars) | Action buttons · Text · Feedback · Cooldown text · Cooldown Manager | ActionBars: `style`, `iconZoom`, `border`, `hotkeys`, `hotkey`, `count`, `macro`, `macroText`, `rangeTint`, `rangeColor`; CooldownText: `size`, `color` | **(new)** Cooldown Manager skin/extension (WA replacement core), fade out of combat, hide macro text per bar, proc glow style |
| 7 | **Combat** (cat-combat) | Cast bars · Auras (buffs/debuffs) · Aura & Cooldown tracker · Combat text · Spell history · Damage meter | CastBars: `style`, `classColor`, `icon`, `iconZoom`, `timer`, `latency`, `bars.@.texture/background/border/text/time`; Auras: `style`, `iconZoom`, `border`, `count`, `duration`; CombatText (Blizzard features); SpellHistory: `count`, `size`, `spacing`, `grow`, `fade`, `inCombatOnly`; DamageMeter: `skin` | **(new)** tracker + reminders, countdown voices (CC0 Jim/David), aura filters/whitelists for non-secret auras, damage meter bar/fonts |
| 8 | **Group & Mythic+** (mythicplus) | M+ timer · Keystones · Party keys · PvP · Group finder helpers | MythicPlus: `timer*`, `autoInsert`, `reportKey`, `partyKeys`; PvP: `safeQueue`, `tabBinder`, `surrender` | **(new)** timer layout presets + test run, affix help, vault tracker, ready-check helper |
| 9 | **Chat & Social** (chat) | Chat · Tabs · Input · AFK screen · Automation (social) | Chat: `urls`, `urlColor`, `copyButton`, `fastScroll`, `tabFlash`, `whisperTabs`, `styleText`, `messages.*`, `tabs`, `arrowKeys`, `keepHistory`; AFK: `spin`; Automation: `acceptInvites`, `declineDuels`, `acceptResurrect` | **(new)** chat background/edit-box skin, timestamps, class-coloured names (non-secret paths only), AFK screen styles |
| 10 | **Maps, Minimap & Data** (minimap) | Minimap · Data bar | Minimap: `square`, `zoneText`, `coords`; DataTexts: `fps`, `latency`, `speed`, `durability`, `gold`, `clock`, `clock24`, `bugs`, `background`, `backdrop`, `border`, `scale`, `height`, `spacing`, `strata`, `colorValues`, `icons`, `value`, `unitText` | **(new)** minimap size/border/button bin, world-map coords, data bar segments drag-order, more data texts (bag space, currencies, vault) |
| 11 | **Tooltips & Items** (tooltip) | Tooltip · Item level · Bags (new) | Tooltip: `skin`, `backdrop`, `border`, `healthBar`, `barTexture`, `barHeight`, `classBorder`, `qualityBorder`, `fonts`, `header`, `body`, `anchor`, `hideInCombat`, `target`, `role`, `mplusRating`, `ids`; ItemLevel: `character`, `bags`, `qualityColor`, `size` | **(new)** bag skin + item level/upgrade arrows, tooltip anchor mover, inspect ilvl |
| 12 | **Quality of Life** (quality) | Interface tweaks · Automation (vendor/misc) · Skins | Quality: `hideTalkingHead`, `filterErrors`, `achievementScreenshot`; Automation: `repair`, `sellJunk`, `fillDelete`, `autoRelease`, `skipCinematics`; Skins: `gameMenu`, `popups`, `readyCheck` | **(new)** more window skins, auto-loot speed, quest auto-accept (opt-in) |
| 13 | **Tools** (profiles) | Movers · Edit Mode · Profiles · Bugs · Diagnostics · About | Movers: `grid`, `gridSize`, `snap`; Bugs: `warnings`, `taint`, `maxReports`, `chat`, `sound`, `flash`, `indicator`, share; Profiles page; `/pui diag` | **(new)** diagnostics page (diag report view), profile import preview, per-spec profiles UI |

All 24 current modules map to this table: AFK, ActionBars, Auras, Automation (split between social and vendor), Bugs, CastBars, Chat, CombatText, CooldownText, DamageMeter, DataTexts, General, GroupFrames, ItemLevel, Minimap, Movers, MythicPlus, NamePlates, PvP, Quality, Skins, SpellHistory, Tooltip and UnitFrames.

## 5. GUI layout proposal

- **Window:** 1100×720 by default, resizable, with a remembered position.
  - Header: emblem, search (global, jumps to the row and flashes it), Edit Mode, Reload, Close.
  - Footer: profile switcher, status line, scale.
- **Sidebar (240 px):** group headers with icon, label and collapse chevron, then module rows with icon, an enable switch and a "needs reload" dot.
  - The active row gets the accent bar. Groups remember their open state.
- **Module page:**
  - Title row: icon, name, description, enable toggle, "Reset section" and "Reset module".
  - Sub-tabs as a segmented control: General · Bars · Colors · Text · Behaviour…
  - Content: two-column cards, each with a header icon and a per-card reset cog.
- **Sticky live preview:**
  - A fixed pane at the top of the content area (or the right column on wide windows). It never scrolls away.
  - It redraws on every `PUI_SETTING_CHANGED` and on dropdown hover (preview-before-pick).
  - It has eye toggles for optional elements and a "randomise" button for sample values.
  - "Show in world" opens test frames (unit frames, cast bars, M+ timer, data bar) via Movers.
- **Pickers:**
  - *Font picker:* a popup grid of cards, each showing the name in its own face plus "Aa 123". Filter by family and weight, and a "Cyrillic" badge.
  - *Texture picker:* a cards grid with a 200×18 neutral sample, a sample in the class colour, and a hover preview applied live.
  - *Colour:* a swatch with a theme-token reset.
  - *Sound:* a list with ▶ play.
- **Search:** it indexes labels, descriptions, tab and group names, and synonyms ("hp" → health). Results are grouped by module.
- **Resets:** per row (right-click), per card (cog), per module (header) and global (Tools). All are undoable within the session.
- **Visual quality:**
  - an 8-pt grid, 1-px pixel-perfect borders
  - a consistent 13/11 type scale
  - icon tiers verified by `/pui diag`
  - hover/active states on every control
  - a reduced-motion option respected everywhere

## 6. Phase 2 build list (prioritised)

**P0: trust and first impression**
1. Read `global.diag` from the user's next session. Fix whatever media or icon issue it shows (or redefine "icons" with the user). Add a Diagnostics page that shows the report in game.
2. Settings IA migration to the 13 groups above:
   - a `group` field on modules
   - sub-tabs from the existing `tab` schema rows
   - sidebar rebuild with collapsible groups
   - search update
   - Saved data does not move; only the presentation changes.
3. Sticky preview pane plus dropdown hover-preview. Add previews for the 13 modules that lack one: CooldownText, SpellHistory, DamageMeter, Minimap, ItemLevel, Skins, AFK, Automation (summary), PvP, Quality, Movers, Bugs, CombatText.
4. Card-based font and texture pickers with real samples. Commission or generate 12 visually distinct bar textures. Add the OFL font candidates after instancing the variable ones to static weights.

**P1: depth**

5. Central Appearance pages (Fonts / Textures / Borders / Sounds) mirroring every module key, with apply-to-all.
6. Unit Frames: boss/arena units, aura rows, portraits, range fade, role/leader/raid-marker icons, test frames.
7. Nameplates: threat/target/focus colours, plate cast bar, debuff row, M+ forces icon, preview eye toggles.
8. Auras & Cooldowns tracker (the WeakAuras replacement within the 12.x limits, section 3), with CC0 countdown voices.
9. Presets and a first-install style picker (3 complete looks).

**P2: breadth and polish**

10. Bags skin with item level and upgrade arrows; minimap buttons bin; data-bar drag ordering and new data texts.
11. Move `UI/Config` into a load-on-demand `Phoenix_UI_Options` addon.
12. End-to-end polish pass: pixel audit at 1080p/1440p/4K, all 11 locales, reduced motion, a combat-lockdown sweep, and `/pui diag` clean.
