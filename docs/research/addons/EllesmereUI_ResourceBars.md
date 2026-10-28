# EllesmereUI Resource Bars

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Personal health, power, class resource, cast, GCD and totem bars with per-spec thresholds and several class-specific engine drivers. ~19k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIResourceBars` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 23 / 18,900 |

- **Title / notes (toc):** EllesmereUI Resource Bars - Custom Resource Bars with thresholds, hash lines and more.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIResourceBarsDB`
- **Slash commands:** `/ellesresource`, `/erb`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 20x, `C_Timer` calls 18x.
- **Secure surface:** `SetAttribute` 2x, `RegisterStateDriver` 2x, `SecureHandlerStateTemplate` 1x
- **Hooks:** `HookScript` 3x, `hooksecurefunc` 13x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `IGNOREPAIN_BAR`, `UNIT_SPELLCAST_SUCCEEDED`, `EBON_MIGHT`, `VERTICAL_DOWN`, `PLAYER_ENTERING_WORLD`, `BREWMASTER_STAGGER`, `IRONFUR_BAR`, `UNIT_MAXHEALTH`, `UNIT_MAX_HEALTH_MODIFIERS_CHANGED`, `UNIT_ABSORB_AMOUNT_CHANGED`, `PLAYER_TARGET_CHANGED`, `UNIT_SPELLCAST_START`, `SPELL_UPDATE_COOLDOWN`, `PLAYER_REGEN_DISABLED`, `UNIT_POWER_FREQUENT`, `UNIT_MAXPOWER`, `PLAYER_DEAD`, `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_FAILED`, `UNIT_SPELLCAST_INTERRUPTED`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_EMPOWER_START`
- **C_ namespaces used:** `C_Spell`, `C_Timer`, `C_SpecializationInfo`, `C_UnitAuras`, `C_Texture`, `C_StringUtil`, `C_CurveUtil`, `C_DurationUtil`, `C_SwingTimer`, `C_Traits`, `C_SpellBook`, `C_ClassTalents`, `C_Item`, `C_CooldownViewer`, `C_PingSecure`

## Features

### Thresholds and colour bands per spec

- **What it does:** Fill colour changes at resource thresholds (e.g. 5 combo points), tick marks.
- **Design (UX, settings, defaults):** Per-spec threshold entries.
- **How it is coded:** `EUI_ResourceBars_Thresholds.lua` resolves colours from curves (`C_CurveUtil`) so secret values never need comparing in Lua.
- **Benefit to players:** Know at a glance when to spend.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_ResourceBars` (`rb.*`), CooldownManager thresholds. Colour-by-threshold through curves: unverified. `C_CurveUtil` is used in `Phoenix_UI_ResourceBars/Extras.lua` and `Core/Bars.lua`.

Ideas to adopt (original code only): Use `C_CurveUtil` colour curves for threshold colours (secret-safe, no comparisons). P2 check.

### Tank active mitigation bars

- **What it does:** Ironfur stacks/uptime bar, Ignore Pain absorb bar, Brewmaster stagger.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `Build.lua` Ironfur overlay, `Update.lua` Ignore Pain and Ironfur bars.
- **Benefit to players:** Tanks track mitigation.

**Compared with Phoenix_UI** - status: **partial**. Phoenix has Brewmaster stagger (`ClassResource.lua`); no Ironfur / Ignore Pain bars (rg: none).

Ideas to adopt (original code only): **P2:** active-mitigation bar for Guardian (Ironfur stacks) and Protection Warrior (Ignore Pain absorb, passed as a secret straight to the bar).

### Spec-specific engine drivers

- **What it does:** Aug Evoker Ebon Might bar, Arcane Mage "Arcane Soul" callout, warrior charges.
- **Design (UX, settings, defaults):** -
- **How it is coded:** 12.1 "engine-slot" drivers that feed secret-flagged values to widgets (`EbonMight121.lua`, `ArcaneSoul.lua`).
- **Benefit to players:** Accurate class tools after Midnight restrictions.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: not found (rg `ebon might` only in Movers).

Ideas to adopt (original code only): P3: Ebon Might duration bar for Augmentation.

### GCD bar, cast bar with latency and channel ticks, totem bar

- **What it does:** -
- **Design (UX, settings, defaults):** -
- **How it is coded:** `GCD.lua`, `CastBar.lua`, `Totem.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `rb.gcd`, `rb.cast`, `rb.totem`.

### Forever: swing timer, druid mana in forms, call totem bar

- **What it does:** Swing timer (combat log lost, so based on swing events), mana bar while shapeshifted, shaman call-totem bar skin.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `SwingTimer.lua` notes addons lost SWING_DAMAGE in 12.0; uses swing timer API.
- **Benefit to players:** Classic players.

**Compared with Phoenix_UI** - status: **partial**. Phoenix Forever swing timer (`forever.swingTimer`). No druid form mana bar.

Ideas to adopt (original code only): P3 (Forever): mana bar while shapeshifted.

## Verdict

Main gap: tank active-mitigation bars (P2).
