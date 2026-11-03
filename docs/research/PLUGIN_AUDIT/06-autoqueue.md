# 06 · AutoQueue → merged into the group filter

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\AutoQueue` (6 Lua files; role from the active spec, role override, keybind, role bar). Licence: unclear, so behaviour only.

| Feature | AutoQueue | Phoenix GroupFinder | Status |
|---|---|---|---|
| Accept role check automatically | yes | "Accept role checks with a key" | partial (key only) |
| Role from the **active spec** | yes | — | **missing** |
| Role override (tank, healer, dps) | yes | — | **missing** |
| Role bar (small buttons) | yes | — | missing |
| Keybind to queue or sign up | yes | Enter signs up | partial |

Plan (spec 009): GroupFinder › Helpers gets "Auto queue": the role follows the active spec or a chosen override, and the role check is accepted automatically outside combat. Signing up still needs a hardware click (protected), so automation only pre-fills the role and accepts the role check.
