# Oracle - command palette (PUI_V2 6.3)

`Ctrl+K` (setting `oracle.key`) through `SetOverrideBindingClick` on a plain button, set out of combat. Nothing is built until the first open. Fuzzy subsequence scoring (contiguous letters, word starts, exact substring bonus). Providers: settings (deep link into Options), Phoenix slash commands, profiles, game panels via their micro buttons (secure `type=click`), macros (secure `type=macro`), collected usable mounts (`C_MountJournal.SummonByID`, out of combat), plugin providers (`PUI.API.RegisterOracleProvider`, plain results only). Recent picks first on an empty query (`oracle.recent`).

Secure results use ONE `SecureActionButtonTemplate` button: attributes set out of combat when chosen, laid over the row and bound to Enter; the next Enter or a click runs it. In combat panels/macros/mounts are hidden and the palette says so.

Settings: `oracle.key`, `maxResults`, `remember`. Slash `/pui oracle`.

Deferred: toys and pets (`C_ToyBox`/`C_PetJournal.SummonPetByGUID` are not in the API catalog, so they are not called), spells, items and teleports/hearth (secure spell/item results), Studio actions, "do X after combat" queue, controller navigation.
