from spec_lib import *
import spec_lib

# drop the wrong 'Quality icons' guess: Phoenix's Quality module is quality-of-life
spec_lib.MOD.pop("Quality", None)

mod("General", "Appearance & General", "Phoenix", "Theme, global fonts/textures/colours, scale, sounds; every module's 'Theme default' points here",
    7, "EUI Fonts 37 + Textures + Colors + Glow + General ~90")
G = "Theme"
r(G, "Theme", "D", "Ember / Dawn / Midnight / Classic / Custom", "Ember", "hover", "has")
r(G, "Accent colour", "C", "", "theme", "live", "has")
r(G, "Accent from class colour", "T", "", "Off", "live")
r(G, "Window surface opacity", "S", "60–100 %", "96", "live")
r(G, "Reduce motion", "T", "", "Off", "live", "has")
r(G, "UI scale (pixel perfect)", "S", "auto / 0.53–1.0", "auto", "live")
G = "Fonts"
r(G, "Interface font", "D", "Phoenix fonts + LSM", "Phoenix Sans", "hover", "has")
r(G, "Unit / number font", "D", "Phoenix fonts + LSM", "Phoenix Numbers", "hover", "has")
r(G, "Font scale", "S", "80–130 %", "100", "live", "has")
r(G, "Global outline", "D", "None / Outline / Thick", "Outline", "live")
r(G, "Replace Blizzard fonts (damage, names, chat)", "T", "4 toggles", "Off", "none")
G = "Textures and borders"
r(G, "Default bar texture", "X", "", "Phoenix Satin", "hover", "has")
r(G, "Default border style", "D", "border styles", "Pixel", "hover")
r(G, "Default border colour", "C", "", "#000000", "live")
r(G, "Default shadow", "D", "None / Soft / Hard", "Soft", "hover")
G = "Colours"
r(G, "Class colours override", "C", "13 classes", "Blizzard", "live")
r(G, "Power colours override", "C", "per type", "Blizzard", "live")
r(G, "Reaction colours", "C", "4", "Blizzard", "live")
r(G, "Dispel colours", "C", "5", "Blizzard", "live")
G = "Glow"
r(G, "Default glow style", "D", "Pixel / Autocast / Button / Proc", "Pixel", "hover")
r(G, "Glow colour / lines / speed / thickness", "C", "colour + 3 sliders", "accent / 8 / 4 / 2", "live")
G = "Sounds"
r(G, "Sound channel", "D", "Master / SFX / Dialog", "Master", "none")
r(G, "Mute list (sound file IDs)", "L", "IDs", "", "none")

mod("Profiles", "Profiles", "Phoenix", "Profiles, per-spec switching, import/export strings, presets",
    0, "EUI Profiles 4 pages (Profiles, Presets, Overrides, FullExport)")
G = "Profiles"
r(G, "Active profile", "D", "profiles", "Default", "none", "part")
r(G, "New / copy / rename / delete", "B", "", "", "none")
r(G, "Per-spec profile", "T", "+ profile per spec", "Off", "none")
r(G, "Per-character overrides", "T", "", "Off", "none")
r(G, "Export (all / selected modules)", "B", "string + module picker", "", "none")
r(G, "Import with preview of changes", "B", "", "", "live")
r(G, "Presets (Phoenix Healer / DPS / Tank / Minimal)", "B", "", "", "hover")
r(G, "Reset module", "B", "per module", "", "none")

mod("Movers", "Layout (Movers)", "Phoenix", "Unlock mode for every Phoenix-owned frame + selected Blizzard frames (no Edit Mode conflicts)",
    3, "MoveAny 150 frame toggles · EUI unlock mode (snap, grid, nudge, per-element)")
G = "Unlock mode"
r(G, "Grid", "T", "", "On", "world", "has")
r(G, "Grid size", "S", "8–128 px", "32", "world", "has")
r(G, "Snap to grid", "T", "", "On", "world", "has")
r(G, "Snap to other frames", "T", "", "On", "world")
r(G, "Nudge with arrow keys (shift = 10 px)", "T", "", "On", "world")
r(G, "Show coordinates while dragging", "T", "", "On", "world")
r(G, "Per-element popup (X, Y, anchor, scale, reset)", "B", "", "", "world")
r(G, "Frame list (search, show/hide, reset)", "L", "all movable frames", "", "world")
r(G, "Move Blizzard frames (talking head, loot, alerts, vehicle seat, durability, widgets…)", "T", "per frame", "Off", "world")
r(G, "Scale Blizzard windows", "S", "50–150 %", "100", "world")
r(G, "Unlock keybind", "K", "", "None", "none")

mod("Skins", "Skins", "Interface", "Phoenix look for Blizzard windows",
    3, "EUI BlizzardSkin 123 (character, popups, tooltips, skyriding, CDM, objective tracker)")
G = "Windows (each toggle)"
r(G, "Game menu", "T", "", "On", "live", "has")
r(G, "Popups (StaticPopup)", "T", "", "On", "live", "has")
r(G, "Ready check", "T", "", "On", "live", "has")
for w in ["Character / inspect", "Spellbook / talents", "Group finder", "Collections", "Professions", "Auction house", "Mail / merchant / gossip / quest", "Loot / rolls", "Achievement / encounter journal", "Calendar / guild / communities", "Settings / addon list", "Great vault / keystone", "Alerts / toasts", "Skyriding vigor bar"]:
    r(G, w, "T", "", "On", "live")
G = "Skin options"
backdrop(G, "Window background", opacity="94")
border(G, "Window border")
r(G, "Title bar style", "D", "Phoenix / Minimal / Blizzard", "Phoenix", "hover")
r(G, "Close button style", "D", "Phoenix / Blizzard", "Phoenix", "hover")

mod("CombatText", "Combat Text", "Combat", "Configures Blizzard floating combat text (CVars) + optional Phoenix scrolling areas",
    16, "Blizzard FCT CVars · MSBT-like")
G = "Blizzard combat text"
for n in ["Damage", "Periodic damage", "Pet damage", "Healing", "Self combat text", "Dodge, parry, miss", "Resistances", "Combat state", "Reactive abilities", "Low health / mana", "Auras", "Resource gains", "Honor", "Reputation"]:
    r(G, n, "T", "", "Blizzard", "none", "has")
r(G, "Text scale", "S", "50–200 %", "100", "none", "has")
r(G, "Motion", "D", "Up / Arc / Fountain", "Up", "none", "has")
r(G, "Damage font (needs relog)", "D", "fonts", "Blizzard", "hover")
G = "Phoenix scroll areas (own events only, secret-safe)"
r(G, "Incoming / outgoing / notification areas", "T", "3 toggles", "Off", "world")
r(G, "Area position / size / direction", "S", "+ Up/Down/Arc", "per area", "world")
font(G, "Scroll text", 18)
r(G, "Merge rapid hits", "T", "", "On", "none")
r(G, "Crit style", "D", "Bigger / Shake / Colour", "Bigger", "hover")

mod("CooldownText", "Cooldown Text", "Action Bars & Cooldowns", "Blizzard countdown numbers on all cooldown frames (C_DurationUtil text bindings)",
    3, "EUI cooldown numbers settings")
G = "Countdown"
r(G, "Countdown numbers", "T", "", "On", "live", "has")
font(G, "Countdown", 14, status="part")
r(G, "Colour by remaining (expiring / seconds / minutes)", "C", "3 colours", "red / yellow / white", "live")
r(G, "Expiring threshold", "S", "0–10 s", "3", "live")
r(G, "Decimals below", "S", "0–10 s", "0", "live")
r(G, "Minimum duration shown", "S", "0–10 s", "1.5", "none")
r(G, "Hide on aura icons", "T", "", "Off", "live")
r(G, "Scale with icon size", "T", "", "On", "live")

mod("DamageMeter", "Damage Meter", "Combat", "Restyles Blizzard's built-in damage meter (C_DamageMeter, 12.0)",
    2, "EUI DamageMeters 82")
G = "Window"
r(G, "Restyle damage meter", "T", "", "On", "live", "has")
r(G, "Phoenix style", "T", "", "On", "live", "has")
r(G, "Bar height / spacing", "S", "10–40 / 0–6 px", "18 / 1", "live")
bar(G, "Meter bar")
r(G, "Class colours", "T", "", "On", "live")
backdrop(G, "Window background")
border(G, "Window border")
font(G, "Name", 12)
font(G, "Value", 12)
r(G, "Value format", "D", "Total (DPS) / DPS / Total / Percent", "Total (DPS)", "live")
r(G, "Show rank numbers / spec icons", "T", "2 toggles", "On", "live")
r(G, "Auto-show in combat, hide after", "S", "0–60 s", "Off", "world")
r(G, "Second window", "T", "", "Off", "world")

mod("SpellHistory", "Spell History", "Combat", "Row of recently cast spells",
    6, "—")
G = "Spell history"
r(G, "Icons", "S", "1–12", "6", "live", "has")
r(G, "Icon size", "S", "16–64", "32", "live", "has")
r(G, "Spacing", "S", "0–12", "4", "live", "has")
r(G, "Direction", "D", "Left / Right / Up / Down", "Left", "live", "has")
r(G, "Fade after (s)", "S", "1–30", "8", "live", "has")
r(G, "Only in combat", "T", "", "On", "world", "has")
border(G, "Icon border")
r(G, "Mark interrupted / failed", "T", "", "On", "live")

mod("MythicPlus", "Mythic+", "Content", "Own M+ timer (Blizzard Challenge APIs) + keystone tools",
    10, "EUI MythicTimer 125 · WindTools keystone tooltips")
G = "Timer"
for n in ["Run timer", "Enemy forces", "Boss splits", "Deaths", "Personal best", "Compare with your best run", "Current pull"]:
    r(G, n, "T", "", "On", "live", "has")
r(G, "+2 / +3 chest timers", "T", "", "On", "live")
r(G, "Affix icons with tooltips", "T", "", "On", "live")
r(G, "Death penalty breakdown", "T", "", "On", "live")
r(G, "Width", "S", "180–400", "260", "live")
bar(G, "Timer bar")
r(G, "Colours (on time / +2 / +3 / over)", "C", "4", "theme", "live")
font(G, "Timer", 22)
font(G, "Objectives", 12)
r(G, "Hide Blizzard objective tracker in M+", "T", "", "On", "none")
G = "Keystone"
for n in ["Auto-insert keystone", "Report new keystone", "Share keystones with the party"]:
    r(G, n, "T", "", "On", "none", "has")
r(G, "Party keystones window", "T", "", "On", "live")
r(G, "Teleport buttons on dungeon list", "T", "", "On", "live")

mod("Encounters", "Encounters", "Content", "Restyles Blizzard Boss Timeline + warnings (C_EncounterTimeline), BigWigs bars style",
    61, "Phoenix S3 already deep · EUI none (EUI has no boss mod)")
G = "Encounters (already deep; small adds)"
r(G, "Existing 61 settings", "—", "timeline bars, warnings, countdown voice, pull timers, role filters, fonts", "", "live", "has")
r(G, "Bar grow direction", "D", "Up / Down", "Down", "live")
r(G, "Per-spell colour override", "L", "spell IDs → colour", "", "live")
r(G, "Private aura sounds", "L", "aura → sound", "", "none")
r(G, "Test encounter", "B", "", "", "world")

mod("PvP", "PvP", "Content", "Battleground / arena helpers; arena frames live in Unit Frames",
    3, "sArena 416 (arena frames — goes to Unit Frames › Arena) · WindTools Combat 33")
G = "PvP"
for n in ["Safe queue", "TAB targets players", "/gg to surrender"]:
    r(G, n, "T", "", "On", "none", "has")
r(G, "Auto release in battlegrounds", "T", "(moved from Automation)", "On", "none", "has")
r(G, "Battleground score on top bar", "T", "", "On", "live")
r(G, "Healer marker on enemy plates", "T", "", "On", "live")
r(G, "Arena prep: enemy specs", "T", "", "On", "live")
r(G, "Dampening display", "T", "", "On", "live")

mod("AFK", "AFK screen", "Phoenix", "AFK screen",
    1, "ElvUI AFK")
G = "AFK"
r(G, "Rotate camera", "T", "", "On", "none", "has")
r(G, "AFK screen (model, name, guild, time AFK)", "T", "", "On", "world")
r(G, "Show stats panel (ilvl, M+, vault)", "T", "", "On", "world")
r(G, "Don't show in instances", "T", "", "On", "none")

mod("Automation", "Automation", "Phoenix", "Small automations",
    8, "EUI QoL 75 · WindTools Misc 112")
G = "Automation"
for n in ["Auto repair", "Sell junk", "Accept invites from friends", "Decline duels", "Accept resurrections", "Fill \"DELETE\"", "Skip cinematics"]:
    r(G, n, "T" if n != "Auto repair" else "D", "Off / Personal / Guild first" if n == "Auto repair" else "", "On", "none", "has")
r(G, "Auto loot faster", "T", "", "On", "none")
r(G, "Auto accept / turn in quests (in Quests)", "T", "see Quests", "", "none")
r(G, "Auto gossip single option", "T", "", "Off", "none")
r(G, "Auto role check accept", "T", "", "On", "none")
r(G, "Auto confirm BoP loot solo", "T", "", "Off", "none")
r(G, "Decline pet-battle duels / guild invites", "T", "2", "Off", "none")
r(G, "Combat warning sounds (low health)", "T", "", "Off", "none")

mod("Quality", "Quality of life", "Phoenix", "Small UI tweaks",
    4, "EUI QoL 75 · WindTools Misc 112")
G = "Quality of life"
for n in ["Hide talking heads", "Quiet errors in combat", "Achievement screenshots", "Cooldown Manager"]:
    r(G, n, "T", "", "On", "none", "has")
r(G, "Hide boss banner / zone text / level-up", "T", "3 toggles", "Off", "none")
r(G, "Camera max distance", "S", "15–39 yd", "39", "none")
r(G, "Raid markers bar", "T", "", "Off", "world")
r(G, "Mouse cursor ring / trail", "T", "", "Off", "world")
r(G, "Combat enter/leave alert", "T", "", "Off", "world")
r(G, "Already known recipe tint", "T", "", "On", "live")
r(G, "CVar browser (common safe CVars)", "L", "", "", "none")

mod("Bugs", "Bugs", "Phoenix", "Error catcher (being rebuilt by the other worker)",
    9, "BugSack-like · EUI none")
G = "Bugs (other worker is rebuilding — spec here only for counting)"
for n in ["Lua warnings", "Blocked actions", "Reports kept", "Chat notice", "Sound", "Flash on new errors", "Minimap indicator", "Blizzard error window", "Send error reports to the author"]:
    r(G, n, "T", "", "", "none", "has")
r(G, "Group duplicates with count", "T", "", "On", "live")
r(G, "Filter by addon", "D", "addons", "All", "live")
r(G, "Copy / export report", "B", "", "", "none")

mod("Sim", "Sim", "Content", "Simulationcraft export + uploader results (S2)",
    6, "simc addon (Unlicense)")
G = "Sim"
for n in ["Fight style", "Targets", "Fight length (seconds)", "Use results for (days)", "Sim results", "Arrow from sim results"]:
    r(G, n, "T", "", "", "none", "has")
r(G, "Include bags / bank / vault / catalyst options", "T", "4", "bags+vault", "none")
r(G, "Top gear candidates list", "L", "", "", "live")

# ------------------------------------------------------------------ NEW MODULES
mod("Quests", "Quests", "Content", "NEW: quest tracker restyle + quest helper (giver/turn-in pins from ATT MIT data, DB2 QuestPOI and runtime C_QuestLine; community data later)",
    0, "EUI QuestTracker ~30 · WindTools Quest 41 · Questie (ARR/GPL, learn only)")
G = "Objective tracker"
r(G, "Restyle objective tracker", "T", "", "On", "live")
r(G, "Width / max height", "S", "200–400 / 200–900 px", "260 / 600", "live")
font(G, "Header", 13)
font(G, "Objective", 12)
r(G, "Progress bars style", "X", "", "theme", "hover")
r(G, "Colour by difficulty", "T", "", "On", "live")
r(G, "Auto-collapse in instances / combat", "D", "Off / Instances / Combat / Both", "Instances", "none")
r(G, "Show quest level / tag (daily, campaign)", "T", "", "On", "live")
r(G, "Click to super-track", "T", "", "On", "none")
G = "Quest helper"
r(G, "Waypoint arrow", "T", "", "On", "world")
r(G, "Arrow style / size", "D", "Phoenix / TomTom-like · 24–96 px", "Phoenix 48", "hover")
r(G, "Distance + ETA text", "T", "", "On", "world")
r(G, "Available quests on map (C_QuestLine)", "T", "", "On", "live")
r(G, "Turn-in / objective areas from QuestPOI (DB2)", "T", "", "On", "live")
r(G, "Quest NPC pins (ATT data + community)", "T", "", "On", "live")
r(G, "Hide low-level / trivial", "T", "", "On", "live")
r(G, "Auto accept / turn in (hold Shift to stop)", "T", "", "Off", "none")
r(G, "Auto pick quest reward (highest sell / sim upgrade)", "D", "Off / Vendor value / Sim upgrade", "Off", "none")
r(G, "Contribute positions to Phoenix data (opt-in)", "T", "", "Off", "none")

mod("GroupFinder", "Group Finder", "Content", "NEW: premade group list filters (PGF-style expressions re-implemented), sign-up helpers",
    0, "PremadeGroupsFilter 105 variables (GPL-2, learn only) · EUI GroupFinder · WindTools LFG list")
G = "Filters"
r(G, "Filter panel next to the group list", "T", "", "On", "live")
r(G, "Min / max members, tanks, healers, damage", "S", "0–40 each", "any", "live")
r(G, "Has Bloodlust / Battle res", "T", "2", "Off", "live")
r(G, "Min leader score / item level", "S", "0–4000 / 0–700", "0", "live")
r(G, "Age (minutes)", "S", "0–180", "any", "live")
r(G, "Dungeon / difficulty / key level", "L", "", "any", "live")
r(G, "Advanced expression (Phoenix syntax)", "I", "e.g. tanks==0 and mprating>=2000", "", "live")
r(G, "Sort", "D", "Age / Score / Item level / Fit", "Age", "live")
G = "Helpers"
r(G, "One-click sign up (double click)", "T", "", "On", "none")
r(G, "Remember sign-up note", "T", "", "On", "none")
r(G, "Role / class icons on list entries", "T", "", "On", "live")
r(G, "Leader score + best key in tooltip", "T", "", "On", "live")
r(G, "Raid lockout hint", "T", "", "On", "live")
r(G, "Auto queue (role check) accept", "T", "(AutoQueue idea)", "Off", "none")

mod("Diagnostics", "Diagnostics", "Phoenix", "Status page (secret state, conflicts, versions) — exists as a page, not settings",
    0, "—")
G = "Diagnostics"
r(G, "Conflicting addons report", "B", "", "", "none", "part")
r(G, "Secret restrictions now (combat/instance)", "—", "read-only", "", "live", "part")
r(G, "Reload / reset all", "B", "", "", "none", "part")
