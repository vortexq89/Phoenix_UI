# Implementation Plan: Group finder: Premade Groups Filter parity

**Spec**: [spec.md](spec.md) | **Date**: 2026-11-03

## Summary

Close the 5 gap(s) of the Premade Groups Filter audit in the Phoenix module named below, then pass the feature checklist.

## Technical context

- Lua 5.1 (WoW retail + Forever), Phoenix module system, Options schema rows, Previews registry, Phoenix Layout.
- Where the code goes: Dim groups that declined you, Filter expression, Raid lockout hint, Specialization icons, class strip

## Constitution check

Principles I–VI and the per-feature checklist (constitution 1.2.0): planned below, re-checked before tasks are closed.

## Approach

1. Read the original addon's options (read-only reference) and list each option in the checklist.
2. Extend the existing Phoenix module (never a second one).
3. Add settings rows, preview state, Layout entry and locale keys together.
4. Harness check per behaviour; then the checklist review against EllesmereUI and Blizzard's UI.
