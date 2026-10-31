# Wisdom - gear advisor (PUI_V2 6.4)

Score = sum(weight x stat) from `C_Item.GetItemStats` (stat keys ITEM_MOD_*; mapping in `Pack.lua`, data pack `wisdom`, stamped 2026-10-26 / 12.1.5). Weights are per profile (`wisdom.weights`), set with `/pui wisdom weight`, imported from a Pawn-style scale string or exported as one. The pack ships NO spec weights: none were available from a dated, attributable source, so with no weights Wisdom compares item level (`C_Item.GetDetailedItemLevelInfo`) and says "item level" in the line. Compared against the weakest equipped item in the slots the item can use (`GetInventoryItemLink`). Tooltip line via `TooltipDataProcessor.AddTooltipPostCall` (Item) with an upgrade star; Vault slots get a star badge (atlas `PetJournal-FavoritesIcon`) when Wisdom is on.

Settings: `wisdom.tooltip`, `star`, `bags`, `decimals`.

Deferred: community spec weights (dated pack entries), vendor and loot-roll badges, upgrade-track and crest calculator (needs a season data pack), comparison panel, "what to upgrade next" list, sim-string export, gems/enchant values. Unverified: the exact ITEM_MOD_* key names returned on 12.1.5 (check in game with /pui wisdom weight and a tooltip).
