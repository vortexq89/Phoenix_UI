# World of Warcraft: Forever (verified 2026-10-22)

## The client
- Blizzard's permanent level 1–60 Azeroth game; **launch 4 Nov 2026**, beta 17 Sep – 21 Oct 2026
  (news.blizzard.com "World of Warcraft: Forever What's Next Panel Recap"; level cap 30 in the beta).
- TOC interface **16001** (1.60.1). Game type `camelot`, alias `forever`; TOC suffixes `_Forever.toc` and
  `_Camelot.toc`; `mainline` family (warcraft.wiki.gg TOC_format, Patch_1.60.1/API_changes). The wiki notes the
  `Camelot` value "may be changed to Forever in the future", so Phoenix uses the `_Forever` suffix.
  `WOW_PROJECT_CAMELOT` = 18; Phoenix reads the interface number from `GetBuildInfo()` instead (16000–19999).
- **"WoW Forever shares Mainline WoW's UI architecture, including the vast majority of APIs available in 12.1.5…
  secrets will also be active in Forever"** (Blizzard, quoted on the wiki API changes page).
- Builds: wago.tools product `wowf` = 1.60.1.70532; Blizzard UI source `Gethe/wow-ui-source` branch `forever`
  (1.60.1.70450); `Ketho/BlizzardInterfaceResources` branch `forever` (70532).
- Install folder: the beta used `World of Warcraft\_classic_beta_`; the launch folder name is not published yet.
- BigWigs (`Init_Camelot.lua`, `isForever`), Questie (`Questie_Camelot.toc`), EllesmereUI (16001 in the TOC +
  Forever Essentials) and NaowhForever already ship for it.

## API differences that matter (Forever 1.60.1.70450 vs retail 12.1.5.70448)
Measured with `tools/audit` on both UI sources (`dump_api.lua` on Blizzard_APIDocumentationGenerated, then the
mainline file resolver with `[Game]` = Camelot):

| | retail 12.1.5 | Forever 1.60.1 |
|---|---|---|
| API doc entries (functions, methods, events, enums) | 8,347 | 8,521 (243 only in Forever, 69 only in retail, most of them enum values) |
| Retail-only functions/events | `C_PaperDollInfo.CanCursorCanGoInSlot`, `C_SecureTransfer.GetMailInfo`, 2 × `C_TransmogOutfitInfo`, `PET_SPELL_POWER_UPDATE`, 2 more events | — |
| Forever-only | — | `C_GameRules` (hardcore, self-found, Forever experience preset), `C_SkillInfo` (classic skills), `C_SwingTimer`, `C_SpecializationInfo.IsSpecSelectionEnabled`, classic stat helpers (`GetCritChanceFromStat` …) |
| Same in both | `C_EncounterTimeline` 34, `C_EncounterWarnings` 10, `C_ChallengeMode` 29, `C_MythicPlus` 21, `C_WeeklyRewards` 21, `C_CooldownViewer` 7, `C_DamageMeter` 8, `C_EncodingUtil` 10 | |

**"In the docs" is not "works here".** What decides is which Blizzard UI addons the client loads (their TOC
`AllowLoadGameType`) and what content the game has:

| Blizzard addon | Loads on | Phoenix consequence |
|---|---|---|
| Blizzard_EncounterTimeline, Blizzard_EncounterWarnings | `standard` only | Encounters keeps pull/break timers, their bars and the countdown voice; timeline bars, warning banner and their Blizzard settings step aside (runtime check `C_EncounterTimeline/C_EncounterWarnings.IsFeatureAvailable()`) |
| Blizzard_ChallengesUI | `standard, mists` | Mythic+ module, M+ tooltip rating and nameplate enemy forces are retail-only |
| Blizzard_WeeklyRewards | all, but Forever has no weekly chest content | Home's Great Vault card is retail-only |
| Blizzard_CooldownViewer, Blizzard_DamageMeter | `standard, camelot` | Auras & Cooldowns and Damage Meter work unchanged |
| Blizzard_UnitFrame, Blizzard_Minimap | Mainline XML + `Camelot\*.lua` visual overrides | Same frames and parentKeys (`healthbar`, `PlayerFrameContentContextual`, `MinimapCompassTexture` …); every function Phoenix hooks exists |
| Blizzard_HousingDashboard, Blizzard_EncounterJournal | `standard` (+ classic) | not used by Phoenix |

Other 1.60.1 notes from the wiki API changes page: Frame strata became a secret aspect; `DoEmote` needs a
hardware event; `C_PvP.IsWarModeFeatureEnabled()` returns false; creature GUIDs have obfuscated server/spawn
IDs; player/target/pet/focus frames and the minimap header were reskinned. Phoenix reads none of these values.
Spell 6603 is "Attack" on Forever ("Auto Attack" on retail); the ID is the same.

## How Phoenix supports it (stage "WoW Forever", shipped 2026-10-22)
- `Phoenix_UI_Forever.toc` / `Phoenix_UI_Options_Forever.toc` (Interface 16001), generated from the retail TOCs
  by `tools/gen_tocs.py`; same files, same order. `check_api.py` fails when they drift.
- `Core/Flavor.lua`: `ns.flavor` ("retail" / "forever"), `ns:Supports(feature)` and `ns.FEATURES`. Modules carry
  `feature = "…"` (hidden, never initialized or enabled, settings kept), option rows and tabs carry
  `feature = "…"` (dropped by `ns:RegisterOptions`), and `descWithout` swaps a card's description.
- Gated: Mythic+ module, Sim module (SimulationCraft models retail only), Home's Great Vault card, M+ tooltip
  rating, nameplate enemy forces, Sim tooltip line and bag arrow, Encounters timeline/warnings (runtime),
  per-spec profiles where the class cannot choose a spec (runtime, Forever-only API).
- Checks per game: `python3 tools/check_flavors.py` (luacheck with `wowf` std, `check_api` and `check_ids`
  against Forever data, smoke harness booted as a 16001 client).
- Not yet: the Phoenix app only scans `_retail_` (Forever's launch folder is unannounced); Forever-only extras
  (classic talents/spellbook skins, swing timer, hardcore/self-found badges) are candidates for a later stage.

## TOC selection (H2, checked 2026-10-30)
warcraft.wiki.gg TOC_format, "Naming": the client first looks for a TOC whose suffix matches its game type or an alias, then
its family, then the bare `AddOnName.toc`. Forever's game type is `camelot` with the alias `forever`, so `X_Forever.toc` (and
`X_Camelot.toc`) is picked on Forever and ignored on retail (`standard`); the current Forever interface is 16001. The 28
`_Forever.toc` files therefore stay. Fallback if that ever changes: one TOC per folder with `## Interface: 120105, 16001`.
