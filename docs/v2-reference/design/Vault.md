# Vault (PUI_V2 5.13) - Phase 5 core

One window for bags 0-5. Slots are `ContainerFrameItemButtonTemplate` buttons created out of combat under one holder per bag (holder ID = bag ID), so item use stays Blizzard's secure code. Search `C_Container.SetItemSearch`, sort `C_Container.SortBags`, junk count + Sell junk button at vendors, item level on gear, new-item glow, free slots and gold. Bag keys open the Vault through post-hooks on ToggleAllBags/ToggleBackpack/OpenAllBags/CloseAllBags, settled one frame later because those functions call each other.

Settings: `vault.mode` (grid/compact), `vault.columns`, `vault.ilvl`, `vault.junk`, `vault.newGlow`. Layout element `vault.window`.

Deferred: LoadOnDemand packaging, List mode, rules engine/categories with drag-assign, recent items, BoE/WuE and track labels, unusable tint, keystone level, physical sort plan, stack merge, currencies, offline alt/bank search, bank (character/warband/reagent), deposit queue, guild bank skin, stack splitter, controller.
