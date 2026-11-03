# Raid and Party Frames and click-casting (PUI_V2 5.4) - Phase 3 design

Child addon `Phoenix_UI_RaidFrames` (depends on `Phoenix_UI`, optional dependency Clique), modules `RaidFrames` and `ClickCast`, both off by default.

## Structure
- `Elements.lua`: everything drawn on a group button, on one unprotected content frame.
- `RaidFrames.lua`: party header and one merged raid header (`SecureGroupHeaderTemplate`), child spawning, unit routing, channels, Blizzard party/raid frame parking, schema, Studio elements.
- `ClickCast.lua`: binding parser, secure attributes, hovercast through a `SecureHandlerBaseTemplate` header, Clique interop.

## Rules applied
- Children are created out of combat when the module turns on (`startingIndex` pulled back to spawn every slot, then restored), sized by a restricted `initialConfigFunction`, and handed to Lua by `header:CallMethod("PhoenixInit", name)`. The unit comes from the `unit` attribute (`OnAttributeChanged` hook).
- Raid sorting by group, assigned role, class or name through header attributes; visibility by state drivers (`[group:raid]`).
- One tracker registers only the channels the settings need: base, healer mana, absorbs, range (`UNIT_IN_RANGE_UPDATE`), threat, auras (dispel), status (phase, resurrection, summon).
- Range fade uses `SetAlphaFromBoolean` on the content frame (never on the secure button).
- Dispel highlight: `C_UnitAuras.GetAuraDataByIndex(unit, 1, "HARMFUL|RAID_PLAYER_DISPELLABLE")` tested only for nil.
- Private auras: `C_UnitAuras.AddPrivateAuraAnchor` slots the game fills; removed on unit change, setting change and disable.
- Click-casting writes attributes only out of combat; mouse bindings use `<mods>type<n>`; keyboard bindings are hovercast (`SetBindingClick` in the restricted OnEnter, `ClearBindings` on leave). With Clique loaded Phoenix writes nothing and only registers frames in `ClickCastFrames`.

## Step 4 additions (feat/groupframes)
- `Indicators.lua`: debuff/buff/defensive containers on `PUI.Auras` (lockout exclusions on debuffs), corner indicators (`POINT:spellID[:mine|any][:RRGGBB]`, per-class heal presets), private-aura anchors with placement, enemy-target dots painted from `PUI.Targeting` (`SetAlphaFromBoolean(UnitIsUnit(enemy.."target", unit))`, never compared).
- Size tiers party / ≤10 / ≤20 / ≤40 (auto by group size or fixed), Mythic cap `groupFilter 1,2,3,4`; header attributes changed only out of combat (CombatQueue).
- `Core/Prediction.lua` shared renderer: incoming heals, absorbs, heal absorbs, overflow marks from the calculator's clamped flags.
- Dispel highlight styles border / glow / tint / both, type colour from `GetAuraDispelTypeColor` with a step curve.
- Test mode builds unsecured sample buttons (refused and ended in combat); the Options preview uses the same `Build` / `Layout` / `PaintSample`.
- Click-cast `cc.list` (one binding per item, validated), composer in Options, hovercast keys reserved in `PUI.Bindings` for one conflict check.

## Not in this phase (reported)
Debuff priority tiles per instance, bar / health-colour indicator types, per-spec indicator lists, self-first sort through `nameList`, FrameSort compatibility check, pet frames, friendly boss frames, tank duplicates, party target buttons, absorb coalescer, range spell refiner, role-aware layout presets.
