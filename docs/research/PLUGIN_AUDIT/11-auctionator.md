# 11 · Auctionator and plugins

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\Auctionator` (330 Lua files: Search, Shopping lists, Selling, Cancelling, PostingHistory, CraftingInfo, Tooltips, Groups). Licence: check LIBRARIES.md; behaviour only.

| Feature | Phoenix | Status |
|---|---|---|
| AH skin | Skins › Auction house | have |
| Open bags at the AH | Bags | have |
| Undercut alert | Automation › Auction undercut | partial |
| Shopping lists (import/export) | — | **missing** |
| One-click selling (price memory, undercut %) | — | **missing** |
| Cancel undercut auctions | — | **missing** |
| Posting history | — | missing |
| Price database plus tooltip prices | — (vendor price only) | **missing** |
| Crafting cost / profit in Professions | — | missing |

This is the largest gap (P3 by effort). Plan (spec 012): a new module `Phoenix_UI_Auction` that owns all AH features (the Skins row and the Automation undercut row move there); the price DB comes from scans (`C_AuctionHouse.ReplicateItems`), with tooltip prices.
