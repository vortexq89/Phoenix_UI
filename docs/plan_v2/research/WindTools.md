# EllesmereUI_WindTools 0.2.8

**Purpose:** migration shell porting WindTools (an ElvUI plugin by fang2hou) onto EllesmereUI; TOC says most original modules are intentionally disconnected.
**Licence:** WindTools' own licence allows use only with ElvUI/NDui and forbids redistribution in other UIs → study only. **Altered attribution:** `## Author:  VortexQ8  fang2hou, XanaHopper`.
**Size:** 337 Lua files, 115 k lines. **Options:** 361 (Misc 112, Quest 41, Combat 33, Maps 29, Announcement 27, ExtraItemBar 27, Item 27, Tooltips 27, Social 16, Advanced 10, UnitFrames 9).

## Features worth matching (Phoenix module that takes it)
- Combat: raid markers bar (QoL), combat alert (QoL), quick focus key (Unit Frames), already known (Tooltip/Bags).
- Extra item bar for quest items/consumables (Action Bars › Extra bars).
- Maps: rectangle minimap, minimap buttons bar, instance difficulty text, world map reveal, event tracker (Minimap).
- Quest: objective tracker restyle, auto collapse in instances, turn-in automation, progress messages, achievement tracker (Quests).
- Tooltips: raid progression, keystone, group info (Tooltip).
- Item: inspect, already known, extended vendor (Item Level / Bags).
- Social: chat bar, emote picker, smart tab (Chat).
- Advanced: CVars editor, mute list (General › Sounds, QoL › CVar browser).
- Announcement (interrupt / quest progress / thanks messages) — **left out of Phoenix**: chat automation is low value and risks spam.

**Data shipped:** keystone/affix tables, prey hunt quest IDs, emote lists. No NPC coordinates.
