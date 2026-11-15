# 02 · BugGrabber + BugSack

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\!BugGrabber`, `I:\BugSack`. Licence: **All Rights Reserved** (TOC), so behaviour only. Keep BugGrabber coexistence: Phoenix reads BugGrabber's store when it is present.

## Parity
| Feature | BugSack | Phoenix Bugs (19 rows) | Status |
|---|---|---|---|
| Capture Lua errors and warnings | yes | Catch errors from, Lua warnings | have |
| Blocked or forbidden actions | yes | Blocked actions | have |
| Store and limit reports | limit | Reports kept | have |
| Sessions | yes | viewer sessions | have |
| Viewer with search and copy | copy | search plus copy | have (better) |
| Chat notice, sound, flash | chat, sound | chat, sound, flash | have (better) |
| Minimap icon | LDB icon | Minimap indicator | have |
| Auto popup on error | yes | — | **missing** |
| Throttle or filter of addon mistakes | yes | — | **missing** |
| Mute in combat | yes | — | **missing** |
| Font size of the viewer | yes | — | **missing** (use the Fonts page scale) |
| Alt-click wipe | yes | Clear all reports button | partial |
| Send bugs to a player in game | addon comm | — | **missing** |
| Save as .txt | — | only through the VQ8S app | partial |
| One-click upload | — | Upload reports to VQ8S.com | have (unique) |

## Overlaps and conflicts
- With BugSack loaded, two viewers and two minimap icons show. Detect BugSack and offer "Phoenix is your bug viewer: hide BugSack's icon", or fold under it.
- "Blizzard error window" is a toggle for the game's own window. Keep it, worded as "also show".

## Improvements (spec 006)
1. Auto popup (out of combat only) with a throttle (the same error at most once per N s) and "mute in combat".
2. Send in game: pick a group member or friend, send through `C_ChatInfo.SendAddonMessage` in chunks, and the receiver accepts in a popup. Phoenix to Phoenix only.
3. Export .txt: the viewer gets "Copy all as text" (a pre-selected edit box) and the app writes `PhoenixBugs_<date>.txt`. Nothing writes to disk from Lua (not possible).
4. A viewer layout with a list on the left and the stack on the right, local variables folded, and one-click "Copy for a report" that adds the version, build and addon list.
