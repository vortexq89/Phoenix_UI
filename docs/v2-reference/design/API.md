# Public API (PUI_V2 10), version 2

`PUI.API_VERSION = 2`; additive only. Registries live in `Core/API.lua` so plugins can register before or after the owning module loads.

- `RegisterPlugin(id, { label, schema })` - own sidebar section; keys must start with `plugin.<id>.`; reserved labels (Phoenix, Core, General, Profiles, Studio, Sentinel, Options) refused.
- `RegisterSkin(id, { frames, parts, extra })` - picked up by the Skins module whenever it loads (per-addon toggle `skins.addon.<id>` not yet in the options; the pack follows the module switch).
- `RegisterDataBlock(id, { label, text = fn })`
- `RegisterOracleProvider(id, fn(query) -> { { text, run, icon } })` - plain results only.
- `RegisterVaultRule(id, { label, match = fn(itemInfo) })`
- `RegisterNicknameProvider(id, fn(name) -> nickname)`; `PUI.API.Nickname(name)` resolves.

Deferred: consumers for data blocks (Data Bars), vault rules (Vault categories) and nicknames (unit/raid frame names); plugin sidebar rendering in the Options window; the extra skin primitives Panel/ScrollBar/EditBox/Checkbox/Dropdown/Bar.
