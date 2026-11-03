# 07 · Premade Groups Filter

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\PremadeGroupsFilter` (Modules: AdvancedFilter, Expression, OneClickSignUp, SignUpOnEnter, PersistSignUpNote, RoleIndicators, Specializations, RatingInfo, Lockout, GroupAge, MemberInfo, ApplicationStatus, CompactListEntries; UI panels for Dungeon, Arena, Delve, Raid, RBG, Mini; plugins RaiderIO, PremadeRegions). Licence: **GPL-2+**, so behaviour only.

| Feature | Phoenix GroupFinder (59 rows) | Status |
|---|---|---|
| Per-category panels (Dungeon, Raid, Arena, RBG, **Delve**) | one filter panel | partial (no **Delve** panel) |
| Difficulty, role slots, members, item level, rating, age | yes | have |
| Expression filter | Filter expression | have |
| One-click sign up, Enter signs up | yes | have |
| Persist sign-up note | — | **missing** |
| Role and spec indicators on the list | Specialization icons, class strip | have |
| Compact list entries | — | missing |
| Lockout hint | Raid lockout hint | have |
| Application status (declined dimming) | Dim groups that declined you | have |
| Leader score and best key | yes | have |
| Region or realm (PremadeRegions) | — | missing |
| Dungeon picker (per-dungeon checkboxes) | — | **missing** |

Plan (spec 009, with 06): category tabs including Delve, a dungeon checkbox grid, a persistent note, a compact list and the region. All in the Phoenix style.
