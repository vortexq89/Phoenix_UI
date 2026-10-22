# MoveAny 1.13.22

**Purpose:** unlock, move and scale almost every Blizzard frame (bars, unit frames, chat, quest, widgets, class bars).
**Licence:** GitHub repo GPL-3.0; CurseForge lists All Rights Reserved. Conflicting → study only. **Altered attribution:** `## Title: MoveAny by VortexQ8`, Author line.
**Size:** 72 files, 36 k lines. **Options:** ~150 `AddCheckBox` rows, mostly one toggle per movable frame, in categories GENERAL, FRAMES, MOVEFRAMES, SCALEFRAMES, RESETFRAMES, BUILTIN, CATACTIONBARS, UNITFRAMES, PLAYERFRAME, PETFRAME, TARGETFRAME, FOCUSFRAME, CATPARTYRAID, CATCHAT, CATQUEST, CATWIDGETS, CLASSSPECIFIC, ADVANCED.

**Lessons:** a searchable frame list with per-frame enable/scale/reset beats 150 checkboxes; Phoenix Movers target spec uses a frame list editor plus per-element popup. Moving Blizzard secure frames must happen out of combat with `SetUserPlaced`/`SetMovable` care — MoveAny has many combat guards worth mirroring (ideas only).
**Data shipped:** frame name lists.
