# NaowhForever (naowh-gaming, pushed 2026-10-22)

"Naowh's companion addon for World of Warcraft Forever." Licence: **all rights reserved** (externals excepted).
Clean-room only. Forever only (interface 16001).

## Modules (README)
BiS List (paperdoll, ranked picks per slot, drop sources, tooltip marks, drop alert), Stat Weights (per spec,
user-editable, tooltip "+9% upgrade"), Dungeon Journal (every Forever dungeon/raid, bosses in order, loot, BiS
marks, your quests there, tips, kill counts), Discovery (books, quest list per zone, chains), Training Planner
(what to train per level, cost, nearest trainer), Professions (recipes incl. unlearned, reagents), Gear &
Trinkets swap bar, Paladin Blessings, Macros generator, Action Bar sets, Buffs & Reminders, Threat Meter,
Group Inspect (score, ilvl, gear, talents), PvP target CC/buffs, Swing Timer, Raid Debuffs, QoL bundle + Top
Bar, supporter badges. Every module starts **off** and costs nothing until enabled; profiles; `/nf setup` onboarding.

## Lessons
- **Modules off by default + onboarding picker** keeps a big addon light; Phoenix already has a first-install
  style picker — extend it to a module picker.
- Per-module slash commands and its own keybinding per window.
- BiS/stat-weight data is curated by the Naowh team (not client data) — Phoenix would need its own source:
  stat weights from local **simc** runs (see simulationcraft.md) are a better, personal answer.

## How Phoenix does it better
Forever support through Phoenix's existing Mainline-family code (wow-forever.md), item/encounter data generated
from the `wowf` DB2 build, personal stat weights from the Sim flow instead of static lists.
