# Spark (plan 5.21, 1.O, mockup 09) - step 9b

125 settings, a module switch and a conflict choice (MikScrollingBattleText, Parrot, xCT+).

- **Blizzard combat text:** outgoing, incoming and notifications each switched OFF at first install through the CVar ledger; each switch (or Spark off) restores your values.
- **Areas** (`Engine.lua`): incoming, outgoing, notifications, static; each with on, animation (straight, curve, stay), direction, align, size, scroll height, time on screen, opacity and lines-per-second cap; Studio movers. Lines are pooled and animated by C-side AnimationGroups.
- **Messages:** a format string plus arguments, so secret amounts only reach `SetFormattedText`. Tokens %a amount, %s spell or item, %c count, %e event, %t trailer; plain text escaped. Merge window (plain sums, hidden amounts show the latest), "+N more" overflow line.
- **Feed** (`Feed.lua`): incoming from `UNIT_COMBAT` (you, pet); outgoing on your target worked out from your own casts within the attribution window (only confident hits by default, or all hits with unsure ones unnamed); school colours; combat in/out (Ticker watch only during a fight); item ready (watch list of item IDs, threshold; Ticker only while one is cooling down); loot (own, quality floor), money, currency, reputation, XP, honor, skill ups.
- 18 event rows, each: on, area, colour, message. Master: merge, merge window, short numbers, crit size, outline, icons, speed, school colours, outgoing mode, attribution window.

Deferred: per-event sounds, aura gain/fade rows, ability substitution and abbreviation lists, visual trigger builder, MSBT profile import.
