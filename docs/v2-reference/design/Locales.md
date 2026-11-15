# Locales (PUI_V2 5.17, Phase 6 depth)

English text is the key; `PUI.L[...]` translates at the render boundary (options labels/tooltips, Studio chips). `Phoenix_UI_Locales` is LoadOnDemand and loads only when the active language (`core.locale`, auto = client) is not English. Missing strings fall back to English and are remembered; `/pui loc` prints coverage. `.tools/locales.py` harvests every rendered string through the offline harness into `Phoenix_UI_Locales/keys.txt` (CI `--check` fails when it is out of date or a locale file holds a stale key). Guardrails allow non-ASCII only under a `Locales/` folder.

Shipped: deDE, frFR, esES, esMX, ptBR, ruRU, koKR, zhCN, zhTW with a first pass of 18 strings each (module names and core labels, drafted, needs native review). 827 strings are harvestable.

Deferred: native translations of the remaining strings, module text outside the schema (chat messages, window titles), live re-render of an open options window on language change, controller navigation.
