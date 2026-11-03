# Auctionator

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (341 in both).

**Licence:** All Rights Reserved (Copyright (c) 2020-2025 plusmouse, borjamacare). Study only. (Contains an AGENTS.md, which we ignored.)

Auction House tool for modern and legacy AH: shopping lists, price database from full scans, selling with undercut, cancelling, crafting cost info, and tooltips with prices.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `Auctionator` | 341 | 341 | 120100, 120105, 16001, 50504, 38000, 20506, 11508, 11509 | 336 / 39,196 |

- **Title / notes (toc):** Auctionator - A lightweight addon that makes it easy and fast to buy, sell and manage auctions
- **Author (toc):** plusmouse, Borjamacare
- **SavedVariables:** `AUCTIONATOR_CHARACTER_CONFIG`, `AUCTIONATOR_CONFIG`, `AUCTIONATOR_POSTING_HISTORY`, `AUCTIONATOR_PRICE_DATABASE`, `AUCTIONATOR_RECENT_SEARCHES`, `AUCTIONATOR_SAVEDVARS`, `AUCTIONATOR_SELLING_GROUPS`, `AUCTIONATOR_SHOPPING_LISTS`, `AUCTIONATOR_VENDOR_PRICE_CACHE`
- **Slash commands:** `/atr`, `/auctionator`
- **Optional deps:** LibAHTab
- **Embedded libraries:** LibCBOR, LibStub, Manifest.xml (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 31x, `C_Timer` calls 15x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `hooksecurefunc` 25x, `HookScript` 9x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `AUCTION_ITEM_LIST_UPDATE`, `AUCTION_HOUSE_CLOSED`, `REPLICATE_ITEM_LIST_UPDATE`, `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED`, `AUCTION_HOUSE_BROWSE_RESULTS_ADDED`, `AUCTION_HOUSE_BROWSE_FAILURE`, `AUCTION_CANCELED`, `BAG_UPDATE`, `PLAYER_INTERACTION_MANAGER_FRAME_HIDE`, `ITEM_DATA_LOAD_RESULT`, `COMMODITY_SEARCH_RESULTS_UPDATED`, `COMMODITY_PURCHASE_SUCCEEDED`, `ITEM_SEARCH_RESULTS_UPDATED`, `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`, `LIST_SEARCH_START`, `LIST_SEARCH_STATUS`, `AUCTIONATOR_PRICE_DATABASE`, `PLAYER_LOGOUT`, `GET_ITEM_INFO_RECEIVED`, `EXTRA_BROWSE_INFO_RECEIVED`
- **C_ namespaces used:** `C_Item`, `C_AuctionHouse`, `C_TradeSkillUI`, `C_Timer`, `C_Container`, `C_ChatInfo`, `C_PetJournal`, `C_EncodingUtil`, `C_GameRules`, `C_MerchantFrame`, `C_TooltipInfo`, `C_AddOns`, `C_Cursor`, `C_Spell`

## Features

### Shopping lists and search

- **What it does:** Saved lists of search terms with filters, quick search from bags/recipes.
- **Design (UX, settings, defaults):** Shopping tab added to the AH (LibAHTab), import/export lists, recent searches.
- **How it is coded:** Event-bus mixins (`EventBusMixin.lua`), `C_AuctionHouse` search APIs, results tables built with TableBuilder.
- **Benefit to players:** Fast buying of materials.

**Compared with Phoenix_UI** - status: **missing (by scope)**. Phoenix: AH skin only (`skins.auctionHouse`). No AH logic (rg `C_AuctionHouse`: none outside the API catalogue).

Ideas to adopt (original code only): Not planned. Make sure our AH skin coexists with Auctionator's tabs (P3 test).

### Selling and cancelling

- **What it does:** Post with undercut from current prices; cancel undercut auctions.
- **Design (UX, settings, defaults):** Per-item defaults, duration, bag list.
- **How it is coded:** Commodity vs item flows (`COMMODITY_SEARCH_RESULTS_UPDATED`, `GetCommoditySearchResultInfo`, `CanCancelAuction`).
- **Benefit to players:** Saves time posting.

**Compared with Phoenix_UI** - status: **missing**. missing (by scope)

### Price tooltips

- **What it does:** Auction, vendor and disenchant values in item tooltips.
- **Design (UX, settings, defaults):** Toggle per line.
- **How it is coded:** Price database per realm.
- **Benefit to players:** Know what loot is worth.

**Compared with Phoenix_UI** - status: **missing (by scope)**. Phoenix shows vendor price and upgrade info in tooltips (`Phoenix_UI_HUD/TooltipExtras.lua`) but no auction price.

## Verdict

Out of scope; ensure coexistence only (P3).
