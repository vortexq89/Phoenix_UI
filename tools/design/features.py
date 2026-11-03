"""Builds docs/design_v3/FEATURES.md from the harness dump (PUI_DUMP) plus the per-feature design notes below."""
import json, sys
src, out = sys.argv[1], sys.argv[2]
d = {x['key']: x for x in json.load(open(src))}
COMP = {'toggle': 'Toggle', 'range': 'Slider + value field', 'select': 'Select', 'font': 'Media picker (font)',
        'texture': 'Media picker (bar)', 'sound': 'Media picker (sound)', 'color': 'Colour swatch', 'colors': 'Colour swatch row',
        'button': 'Button', 'input': 'Text field', 'style': 'Style picker (cog popover)', 'custom': 'Custom widget',
        'description': 'Hint text', 'scope': 'Scope chips', 'preview': 'Preview card'}
# purpose / shows / neighbours / preview verdict (Y = keep, N = drop, W = "Show in world" instead) + why (spec §6)
N = {
 'ActionBars': ("Phoenix's own secure action bars.", "Up to 15 bars, pet / stance / extra buttons, keybinds, cooldowns, charges.",
   "Bars group, first page; Cooldown Manager and Cooldown Text sit next to it and share the button look (one Style picker).",
   'Y', "Size, shape, spacing and text are visual and the bars are hidden behind the window; shown at real size, one bar, scrolls if wider."),
 'Tracker': ("Cooldown Manager: Blizzard's tracked spells laid out by Phoenix.", "Essential / Utility / buff icons and bars, custom bars, reminders.",
   "Bars group; shares the icon border, zoom and font with Action Bars.", 'Y', "Grid and growth are visual; the viewer is hidden out of combat."),
 'CooldownText': ("Countdown numbers on every cooldown.", "Numbers by time left, colours by threshold.", "Bars group; also used by Auras and the Tracker.",
   'Y', "Thresholds and colours only make sense seen ticking; small strip of 4 icons."),
 'UnitFrames': ("Player, target, focus, pet, target-of-target, boss and arena frames.", "Health, power, cast bar, portrait, auras, indicators, text tags.",
   "Frames group, first page; Group Frames and Cast Bars reuse its bar and text styles.", 'Y', "Highly visual; per-frame scope chips pick which frame the preview draws."),
 'GroupFrames': ("Party and raid frames.", "Grid of members with health, roles, debuffs, dispel highlight.", "Frames group; inherits Unit Frames' bar look.",
   'Y', "Layout (grid, growth, sorting) is visual and needs a group to see."),
 'CastBars': ("Player, target, focus and boss cast bars.", "Bar, icon, spell name, timer, latency, interrupt state.", "Frames group; detached or attached to Unit Frames.",
   'Y', "Only visible while casting; the preview animates a cast."),
 'NamePlates': ("Enemy and friendly nameplates.", "Health, cast bar, threat colour, auras, target highlight, class / NPC colours.",
   "Frames group; colours shared with Unit Frames' Colours tab.", 'Y', "Plates need enemies on screen; the preview shows three states (normal, target, casting)."),
 'Auras': ("Buffs, debuffs and weapon enchants (Phoenix containers or Blizzard's frames, skinned).", "Icon grid with timers and stacks.",
   "Frames group; timers come from Cooldown Text.", 'Y', "Grid, growth and borders are visual; fitted, no fixed black box."),
 'CombatText': ("MSBT-style scrolling combat text.", "Separate movable areas for damage and heals in and out, power, notifications, crits.",
   "Combat group, first page; areas are Phoenix movers (Layout mode).", 'Y', "Animation and scroll paths only make sense moving; the preview is a scaled screen."),
 'DamageMeter': ("Phoenix view on Blizzard's damage meter data.", "Bars per player, modes, segments.", "Combat group.", 'W',
   "Shows only real combat data; a sample table preview teaches little. 'Show in world' with test data instead."),
 'SpellHistory': ("Recent casts as an icon strip.", "Last N spells with failed-cast cross.", "Combat group.", 'Y', "Small, cheap, visual; the strip at real size."),
 'Chat': ("Chat frame look and behaviour.", "Tabs, edit box, fade, URLs, class colours, copy.", "Interface › Chat & maps.", 'N',
   "Chat is on screen behind the window; changes are visible live. Drop the preview, use the full width."),
 'Minimap': ("Minimap shape, coordinates, zone text and addon button bin.", "Square / round map, clock, bin.", "Interface › Chat & maps.", 'N',
   "The minimap stays visible at the top right while settings are open."),
 'DataTexts': ("Info panels with data texts (gold, durability, latency...).", "Panels and their texts.", "Interface › Chat & maps.", 'N',
   "Panels are visible on screen; preview duplicates them."),
 'Tooltip': ("Game tooltip look and extra lines.", "Border, health bar, item level, target, IDs.", "Interface › Tooltips & items.", 'Y',
   "Tooltips are not on screen while configuring; one sample unit tooltip."),
 'Bags': ("Phoenix bag window (one combined bag) or skinned Blizzard bags.", "Item grid, categories, search, gold, bank.", "Interface › Tooltips & items.", 'W',
   "The real bag opens beside the settings ('Show in world'); a fake grid is redundant."),
 'ItemLevel': ("Item level on items in bags, character, inspect and loot.", "Number + quality colour on icons.", "Interface › Tooltips & items.", 'Y',
   "Position and size on an icon: a 3-icon strip."),
 'Skins': ("Phoenix theme on Blizzard windows, in the game's own layout (ElvUI / EllesmereUI style).", "Per-window on/off, skin design (v3 §8, §10), extras per window.", "Interface › Windows.", 'N',
   "Window skins are judged on the real window; each row gets an 'Open' button instead of a preview."),
 'Quests': ("Objective tracker and quest log styling.", "Tracker headers, progress bars, quest item button, automation.", "Content › Questing & groups.", 'N',
   "The tracker is on screen; a preview duplicates it."),
 'GroupFinder': ("Group Finder helpers and filters.", "Filter panel, applicant info, sign-up helpers.", "Content › Questing & groups.", 'N',
   "Only meaningful in the real Group Finder; 'Open Group Finder' button."),
 'MythicPlus': ("Mythic+ timer and keystone tools.", "Timer, chests, forces, deaths; party keystones.", "Content › Dungeons, raids & PvP.", 'Y',
   "Only visible inside a key; preview runs a sample timer."),
 'Encounters': ("Raid and dungeon helpers.", "Boss timers, notes, markers.", "Content › Dungeons, raids & PvP.", 'Y', "Only visible in encounters; sample timeline."),
 'PvP': ("PvP helpers.", "Arena / battleground info, queue tools.", "Content › Dungeons, raids & PvP.", 'W', "Only in PvP; 'Show in world' test mode."),
 'Sim': ("SimulationCraft gear sims through the uploader.", "Requests, results, upgrades.", "Content › Gear.", 'N', "Results are a table, not a visual setting."),
 'General': ("Theme, colours, fonts, borders, scale.", "Accent preset, surface, typography, class / power colours.", "Phoenix › Look.", 'Y',
   "A small swatch card that shows the theme on a sample card; global and visual."),
 'Movers': ("Layout mode: move every Phoenix element.", "Grid, snap, nudge, per-profile positions.", "Phoenix › Setup.", 'N',
   "It is itself on-screen editing; the page opens Layout mode."),
 'Quality': ("Quality-of-life toggles.", "Talking head, error filter, auto-actions, raid marker bar.", "Phoenix › Utility.", 'N', "Behaviour switches, nothing to draw."),
 'Automation': ("Automatic actions (repair, sell junk, accept, release...).", "Rules and exceptions.", "Phoenix › Utility.", 'N', "Behaviour only."),
 'AFK': ("AFK screen.", "Model, info panel, timer.", "Phoenix › Utility.", 'W', "'Show in world' runs the AFK screen for 10 s."),
 'Bugs': ("Error capture and reporting.", "Error list, chat notice, sharing with the author.", "Phoenix › Support.", 'N', "A list, not a visual."),
}
PAGES = [
 ('home', 'Home', 'Dashboard: module grid, health checks, quick actions.', 'Home', 'N'),
 ('profiles', 'Profiles', 'Profiles: switch, copy, export / import, per-spec.', 'Phoenix › Setup', 'N'),
 ('presets', 'Presets', 'Whole-UI starting layouts with thumbnails.', 'Phoenix › Setup', 'N (thumbnails are the preview)'),
 ('fonts', 'Fonts', 'Font library browser with samples (§9).', 'Phoenix › Look', 'N (samples in the picker)'),
 ('textures', 'Textures', 'Bar / border / glow library with samples.', 'Phoenix › Look', 'N (samples in the picker)'),
 ('sounds', 'Sounds', 'Sound library with play buttons.', 'Phoenix › Look', 'N'),
 ('diagnostics', 'Diagnostics', 'Self-test, taint report, performance.', 'Phoenix › Support', 'N'),
 ('about', 'About', 'Version, credits, licences.', 'Phoenix › Support', 'N'),
]
V = {'Y': 'Yes', 'N': 'No', 'W': "No - 'Show in world' (test mode) instead"}
o = ["# Phoenix UI v3 — feature catalogue", "",
     "Generated by `tools/design/features.py` from the live option schemas (harness `PUI_DUMP`), plus design notes. "
     "Every module, and every section (card) inside it, has an entry. The preview verdicts apply DESIGN_SYSTEM_V3 §6.", "",
     "Legend: **Component** names are from §5. A section's options are listed in order; ⟳ = control type.", ""]
tot = 0
for k in sorted(d, key=lambda k: (d[k]['where'], k)):
    x = d[k]; n = N.get(k)
    if not n: continue
    o += [f"## {x['label'] or k}  (`{k}`)", "",
          f"- **Purpose:** {n[0]}", f"- **Shows:** {n[1]}", f"- **Settings tree:** {x['where']} › {x['label'] or k}",
          f"- **Fits with:** {n[2]}", f"- **Live preview:** {V[n[3]]} — {n[4]}", ""]
    tab, sec, items = None, None, []
    def flush():
        global items
        if sec and items:
            o.append(f"**{sec}**" + (f" _(tab {tab})_" if tab else ""))
            comps = sorted({COMP.get(t, t) for t, _ in items if t in COMP})
            o.append(f"- Component: Card · {', '.join(comps)}")
            for t, l in items: o.append(f"  - {l} ⟳ {COMP.get(t, t)}")
            o.append("")
        items = []
    for r in x['rows']:
        if r['t'] == 'tab': flush(); tab = r['l']; sec = r['l']
        elif r['t'] == 'header': flush(); sec = r['l'] or sec
        elif r['t'] in ('preview', 'scope'): continue
        else:
            items.append((r['t'], r['l'] or r['k'] or '(unnamed)')); tot += 1
            if sec is None: sec = 'General'
    flush()
o += ["## Built-in pages", "", "| Page | Purpose | Settings tree | Preview |", "|---|---|---|---|"]
for key, lab, p, w, pv in PAGES: o.append(f"| {lab} (`{key}`) | {p} | {w} | {pv} |")
o += ["", f"_{len(N)} modules, {tot} options, {len(PAGES)} built-in pages._", ""]
open(out, 'w').write("\n".join(o))
print(len(N), tot)
