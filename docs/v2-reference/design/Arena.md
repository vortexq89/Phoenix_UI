# Arena (plan 5.21, 1.O, mockup 04) - step 9b

47 settings, a module switch and a conflict choice (sArena, sArena Reloaded, Gladius, GladiusEx: nothing changes until you pick).

- **Zero cost outside arenas:** only zone events until you enter an arena; arena events, the Targeting subscription and the cast bars arm there.
- **Frames** (`Frames.lua`): secure unit buttons (left click target, right click focus; geometry and visibility changes wait for the CombatQueue). Presets Phoenix / Compact / Gladiator write their values once into their own settings (a profile switch never does). Mirror, grow, power bar, class colours, names, percent health through the engine formatter, arena number, spec icon from the preparation room, stale look for enemies who left, stealth look, and the cosmetic "assume full health in stealth" (off).
- **Trinket and racial** (`State.lua`): trinket from `C_PvP.GetArenaCrowdControlInfo` (faction art before it is seen); racial from `UNIT_SPELLCAST_SUCCEEDED` with a shared-cooldown state machine (both directions; secret spell IDs skipped).
- **DR tray** (`DR.lua`): opt-in, off by default, sets `spellDiminishPVPEnemiesEnabled` through the CVar ledger (prior value restored). Draws `UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED` data: icon, swipe, immune overlay via `SetAlphaFromBoolean`; stage label and stage border only when the values are plain. Right of the trinket by default; anchor trinket / racial / frame, X/Y offsets, grow, size, spacing, numbers. No Phoenix DR maths.
- **Targeting:** party dots per enemy (shared `PUI.Targeting` refresh), gold border on your target, focus mark; `UnitIsUnit` results only reach alpha.
- **Match** (`Match.lua`): match time, dampening (engine formatter), Shadowsight countdown on a 1 Hz Ticker while live; after-match card (result, both comps from the scoreboard, rating change, trinket uses and DR reported per enemy), `/pui arena card`.
- Blizzard's arena frames are hidden through the frame ledger (setting, on; restored when off); never reparented, Edit Mode never toggled.
- Test mode (`/pui arena test`) and the live preview use the same tray paint.

Deferred: pet frames, class-icon aura priority, dispel tracker, arena range page, click-binding editor, per-text page, Gladiator progress overlay, FrameSort numbering, "only triggerable by me" DR CVar, healer-only variants.
