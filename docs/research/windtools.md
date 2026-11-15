# EllesmereUI_WindTools (local, v0.2.8) and upstream ElvUI_WindTools

## Licence
"Restricted-source": GPLv3 **only inside the ElvUI and NDui ecosystems**; any reuse elsewhere needs written
permission. Phoenix: **clean-room only**, no media.

## What is actually live in the EllesmereUI port
The TOC says "most original WindTools modules are intentionally disconnected". Loaded: **Extra Item Bar**
(quest items, potions, flasks, custom IDs), **Chat Bar** (channel buttons above chat), **Smart Tab** (Tab cycles
the right chat channel), **Raid Markers bar** (world/target markers with modifier inversion, visibility rules,
mouse-over fade), **Friendly Nameplate Outline**, **Quick Focus** (modifier+click to focus, override bindings,
deferred out of combat), data texts **Range** and **Micro Menu**. Damage Meter Layout, Combat Alert and Quick
Tools render as "not ported".

## Full upstream catalogue (option headers in Options/*.lua) — the idea list
Announcements (keystone, quest progress, reset instance, goodbye), Combat Alert (enter/leave text + sound +
animation), Damage Meter Layout, Destroy Totem, Quick Keystone; Already Known, Contacts (mail), Delete Item
(fill "DELETE"), Extend Merchant Pages, Extra Item Bar, Fast Loot, Inspect (gear list with enchant/gem icons),
Item Level (flyout, scrapping), Trade; Event Tracker (world events with timers), Instance Difficulty badge,
Minimap Buttons bar, Rectangle Minimap, Super Tracker (distance text, waypoint parsing from chat), World Map
(reveal, scale); Misc: CVars editor, Game Bar (micro menu + time + friends + group finder), Keybind Alias,
Keybind text above, LFG List (class line, spec icons, party keystone, right panel), Move Frames, Mute (sounds),
Pause to slash, Skip cut scene, Spell Activation Alert, Talking Head off; Quest: Achievement Screenshot,
Achievement Tracker, Auto Collapse tracker in instances, Objective Tracker styling (header, progress colours),
Prey Hunt, Switch Buttons, Turn In (automation conditions); Social: chat bar/link/text, context menu,
emotes, friend list; Tooltips: group info, health bar, keystone, M+ score, objective progress, progression,
tier set count, unit info; Unit frames: absorb, name clip, role icon, tags.

## UX lessons
- One page per category with **module groups inline** and section headers; dual-row controls (two sliders/toggles
  per row) for density; disabled-but-visible options for not-ported features (honest, but noisy).
- Heavy hooking of Blizzard frames; the user's BugSack shows WindTools secret-value errors (REDESIGN.md §2).

## Already in Phoenix (no duplicate)
Delete fill (Automation `fillDelete`) · Achievement screenshot, Talking Head (Quality) · Skip
cinematics (Automation) · Minimap button bin (Minimap) · Item level on gear/bags (ItemLevel) · Tooltip M+ rating,
role, IDs, health bar (Tooltip) · Data bar segments (DataTexts) · Movers (Movers) · Chat copy/URLs/tabs (Chat).

## How Phoenix does it better
Adopt the *ideas* that fit Midnight rules into existing modules (see EXPANSION_PLAN master table): Raid Markers
bar + Quick Focus (Group & Mythic+), Extra Item Bar (Action Bars), Chat Bar/Smart Tab (Chat), Instance difficulty
badge + Event Tracker (Maps), Already Known + Merchant pages + Inspect panel (Tooltips & Items), CVar editor
(Tools), Mute list (Quality). Each with a pinned preview and Phoenix theme, all secret-safe.
