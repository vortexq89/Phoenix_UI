# EllesmereUI suite (v9.6.1, 23 addons) and LibGetFrame

## Licences
- EllesmereUI: custom licence, "copyrighted to their authors with **all rights reserved**". Clean-room only;
  no fonts/icons/textures (REDESIGN.md §2 media list).
- LibGetFrame (EllesmereGaming fork): **GPL-2.0** — cannot be embedded in MIT Phoenix. Phoenix already has its
  own frame lookup in Core (rule 5: no second implementation).

## What the suite offers (TOC notes, local copy)
Action Bars, Aura/Buff Reminders, Bags, Blizzard Skin, Chat, Cooldown Manager replacement, Damage Meters, Data
Bars, **Forever Essentials** (Forever-only: classic spellbook/talents, flight timer, gather skill, junk items,
loot feed, macro manager, map fade/reveal/travel, pet summon, quest rewards, simplified stats, threat meter,
uprank, zone levels), Friends list, **Group Finder** (search filters, listing, applications), Minimap, **Mythic
Timer**, Nameplates, QoL, **Quest Tracker reskin** (+ Forever variant), Quickdraw (radial action menu), Raid
Frames, Resource Bars, Unit Frames; Options load on demand; Locales load on demand.

## UX lessons already adopted in Phoenix 2.0
Grouped sidebar, pinned live previews with eye toggles, central Fonts/Textures pages, cog popovers, apply-to-all,
presets + first-install picker, global search, LoD options addon (REDESIGN.md §2).

## New lessons from this pass
- **Per-client file variants** (`_Forever.lua`) inside one addon instead of separate products.
- **Quickdraw** radial menu (hold key → pick) is a distinct, well-liked interaction; Phoenix could offer it for
  markers, mounts, toys (secure action buttons, out-of-combat setup).
- **Resource Bars** with thresholds/hash lines — Phoenix has none; must use secret-safe StatusBar sinks.
- **Friends list** redesign and **Aura/Buff reminders** — Phoenix has neither.

## How Phoenix does it better
Same depth with: zero secret/taint errors as a hard rule enforced by static checks, data pulled from DB2 with
pinned snapshots (`tools/check_ids.py`), and a single coherent module map with no duplicate features.
