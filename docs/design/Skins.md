# Skins (PUI_V2 5.11) - Phase 5 core

Engine: per-window packs (`SK.Register(id, {frames, parts, extra})`). Primitives found by reading each window's own keys: shell (NineSlice/Bg/Background/TopTileStreaks/PortraitContainer/TitleBg/BorderFrame faded to alpha 0 + Phoenix backdrop one level below), inset, close button, tabs (`Tabs` table or `<Name>TabN`), panel buttons (Left/Middle/Right), title font. Every change is recorded in weak side tables and reverted exactly. Each pack runs through `securecallfunction`, so one failure is reported to the error handler and reverted while the others continue. Work is combat-deferred; load-on-demand windows are retried on ADDON_LOADED.

25 windows: Character, Inspect, Spellbook/Talents, Collections, Group Finder, Great Vault, Adventure Guide, Map/Quest Log, Guild (Communities), Calendar, Achievements, Mail, Merchant, Auction House, Macros, Settings, AddOn List, Gossip/Quest, Trade, Loot, Ready Check, Group Invite, Dressing Room, Transmog, Professions. Settings `skins.<window>`; third-party `PUI.API.RegisterSkin(id, pack)`.

Deferred: scrollbar, editbox, checkbox and dropdown primitives; selected-tab state art; tooltip, dialogs, HUD bits, chat bubbles; per-window detail polish; shipped third-party skins (Details!, Pawn, WeakAuras, Plater - Phase 6).
