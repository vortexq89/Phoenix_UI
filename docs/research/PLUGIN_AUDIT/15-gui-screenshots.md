# 15 · GUI review of the user's 20 screenshots

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Every pixel-level issue found. Fix in spec 003 (GUI polish) unless a plugin spec is named.

| ID | Where | Issue | Fix |
|---|---|---|---|
| H1 | Home | "This week" squares are blank | Draw the week data or hide the card when there is none |
| H2 | Home | The accent glow blob overlaps the Edit Mode button | Clip the glow to the hero card; z-order the buttons above it |
| H3 | Home | Bags and What's new cut at the bottom | Scroll frame for Home, or cards sized to the 946 px body |
| S1 | Sidebar | Subtitles truncated | One-line titles; the subtitle goes to a tooltip |
| S2 | Sidebar | Dot markers unclear | Remove them, or use a legend ("new", "off") |
| A1 | About | URLs truncated | Wrap, or show a "copy link" button |
| P1 | Unit Frames, Group Frames | Previews empty | Live preview frames (spec 004) |
| P2 | Unit Frames | The tags help line overflows | Multi-line description with wrap; tag list in a cog |
| P3 | Buffs, Cast Bars, Group Frames | RELOAD badges on "drawn by" rows | Make the owner swap live, or a confirm button "Switch now" |
| P4 | CDM, QoL, Item Level, Encounters | Header descriptions truncated | Wrap the header description to 2 lines, or move it to the intro row |
| P5 | Item Level, Sim | Hover tooltips cover row text; Sim help clipped; gear list "(scroll)" and cramped icons | Anchor tooltips to the right of the row; see 03 |
| P6 | CDM and long pages | Bottom rows cut by the footer | Content scroll height = body − FOOTER_H (82) |
| M1 | Movers | Huge combat-text boxes | Clamp overlay boxes to 400×200, with a dashed outline for big areas |
| M2 | Movers | Labels overlap (Boss banner …) | Labels inside the box, ellipsis, collision offset |
| M3 | Movers | Cramped toolbar | Two rows: unlock/grid/snap and frames/reset/Edit Mode |
| E1 | Encounters › BigWigs | Thin tab; "BigWigs is not loaded" while installed (LoD) | See 05 |
| V1 | PvP | Queue pop sound dropdown blank | Default value missing from the sound list: fall back to the first entry |
| Q1 | QoL | "Combat" text clipped in the preview | Preview width from the text width |
| F1 | AFK | Preview model is a grey circle placeholder | A PlayerModel with the player unit, or hide it until it loads |
| C1 | Combat Text › Crits | Greyed out, 0 %, blank sound | See 08 |
| D1 | Data bar | Crowded; overlaps the action bar and chat | Default position above the bars; overflow into a second bar; Layout entry |
| W1 | Window | Runs at 85 % scale; footer shows "Pixel-perfect UI scale 0.53" | Window scale independent of the UI scale (default 100 %); move the scale readout to General |
