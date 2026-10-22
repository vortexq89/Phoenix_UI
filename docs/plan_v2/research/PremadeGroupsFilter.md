# PremadeGroupsFilter 7.6.5 (Bernhard Saumweber)

**Purpose:** filter the Premade Groups list with a UI or advanced expressions; sign-up helpers.
**Licence:** GPL-2.0 → Phoenix (MIT) may not copy code; we re-implement ideas (features are not copyrightable). **Altered attribution:** README rewritten to "licens by VortexQ8e … GNU General Public licens by VortexQ8e, Version 2"; 56 files touched.
**Size:** 53 files, 9 k lines.

**Expression variables (105):** activity, age, boss/bosses*, defeated, dps/heals/tanks (+ per class counts), hasbl/hasbr/haslust, ilvl, mprating, myilvl, mydungeonrating, friends, leader, members, voice, autoinv, difficulty flags, keylevel, partyfit, warmode, …
**Modules:** OneClickSignUp, PersistSignUpNote, RoleIndicators, RatingInfo, GroupTooltip, Lockout, SignUpOnEnter, CompactListEntries; UI panels Arena / Delve / Dungeon / Raid / Mini / Dialog.
**Phoenix target:** Group Finder module (14 settings) with a smaller Phoenix expression syntax; no code reuse.
**Data shipped:** activity → dungeon/boss tables (game facts, re-derivable from DB2 GroupFinderActivity / JournalEncounter).
**Implemented (S15):** Group Finder module, 57 settings (docs/GROUP_FINDER.md): own expression grammar (39 words), dim instead of rewriting the results table, game advanced filter for removal, secure click delegates for one-click / Enter sign-up and the role-check key. Not built: persist note (Blizzard blocks SetText on the note box), skip dialog.
