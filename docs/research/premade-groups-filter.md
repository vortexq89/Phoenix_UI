# Premade Groups Filter (0xbs) — v7.6.5, interface 120105

## Licence
GPL-2.0-or-later (file headers). Not compatible with Phoenix's MIT licence: **clean-room** (or relicense Phoenix to GPL).

## What it offers
- Panels per category: Dungeon (M+ rating, roles, dungeon picks), Raid (bosses defeated), Arena / RBG (rating),
  Delve, Role; a Mini panel; a help page.
- **Expression language** (~150 keywords: `mythicplus`, `tanks`, `heals`, `dps`, `members`, `ilvl`, `mprating`,
  `age`, `declined`, `voice`, `myrealm` …, plus sort keys). Implemented with `loadstring("return "..exp)` +
  `setfenv(func, env)`.
- UI extras: class names in tooltip, coloured group names (new / declined / locked out), class-colour bars under
  roles, leader crown, leader rating (Raider.IO colours), spec icons, missing-role icons, one-click sign-up,
  cancel oldest application, persist note, sign-up on Enter, skip dialog, sign up to declined groups.

## Technical lessons
- It filters by **writing `LFGListFrame.SearchPanel.results = results`** and hooks `LFGListSearchEntry_Update`
  etc. Writing into a Blizzard frame field taints the LFG panel (the user's BugSack shows PGF in taint/secret
  errors). Phoenix rule 2 forbids this.
- `C_LFGList.Search` is `HasRestrictions` (needs a hardware event) and `GetSearchResultInfo` is
  `SecretInChatMessagingLockdown`. `ApplyToGroup` is not in the public API docs; Blizzard calls it from its own
  sign-up dialog.

## How Phoenix does it better
- **Own results browser** (Phoenix frame) fed by `C_LFGList.GetSearchResults/GetSearchResultInfo` after a Search
  started from a Phoenix button (hardware event); sign-up opens Blizzard's own dialog for the chosen result. No
  Blizzard tables touched → no taint.
- **Filter builder instead of raw Lua:** chips and sliders compile to a small Phoenix expression grammar parsed by
  our own parser (no `loadstring`, rule 4), with an "advanced" text box using the same grammar and live match count.
- Saved filter presets per activity, role-aware defaults, keystone-aware ("groups for my key level ±2").
- Activity names/icons from DB2 `GroupFinderActivity`/runtime `C_LFGList.GetActivityInfoTable`, dungeon art from
  `MapChallengeMode` + `C_ChallengeMode.GetMapUIInfo`.
