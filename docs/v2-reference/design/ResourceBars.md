# Resource Bars (PUI_V2 5.8) - Phase 2 design

Child addon `Phoenix_UI_ResourceBars`, module `ResourceBars`, off by default. One movable stack (`rb.stack`) with, top to bottom: health, power, class resource, cast, global cooldown, totems. Each bar has `rb.<bar>.enabled` and `rb.<bar>.height`.

- Events are wired per enabled bar (`RB.Wire`); the stagger bar uses a 0.1 s Ticker entry only while a Brewmaster stagger bar is shown.
- Class resource (`ClassResource.lua`): the first candidate power type with `UnitPowerMax > 0` decides (follows spec and form): combo points (rogue, druid in cat form), holy power, chi, soul shards (tenths with `unmodified`), arcane charges, essence; runes (death knight) and stagger (Brewmaster). Each pip is a StatusBar spanning `[i-1, i]` that receives the whole amount, so the engine clamps the fill and secret amounts never meet Lua arithmetic.
- Runes recharge from `C_DurationUtil.CreateDuration():SetTimeFromStart` into `SetTimerDuration`; secret rune states fall back to `SetAlphaFromBoolean`.
- GCD from `C_Spell.GetSpellCooldownDuration(61304)`; totems from `GetTotemDuration(slot)`; cast from the unit duration objects.
- Hash lines: `rb.power.ticks` ("30, 60").

## Not in this phase (reported)
Swing timer (Forever) - needs a swing event source that is not verified on 1.60.1; thresholds with talent gates; spender/buff colouring; aura-based resources (soul fragments, maelstrom weapon, tip of the spear, icicles) that need hidden one-slot aura containers; warrior charges.

## Step 6 (feat/bars)
Cast bar on `PUI.CastBar` (`RB.castBar`, style from `rb.cast.icon|iconSide|spellName|timer|fadeOut|castColor|channelColor`, no kick marker); `rb.health.text`, `rb.power.text`, `rb.power.color`; `rb.matchHostWidth` beside `uf.player.resources` (attach / keep separate, owned by Unit Frames); `core.coexist.resourcebars`.
