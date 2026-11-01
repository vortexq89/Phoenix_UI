# Implementation Plan: Global pages

**Branch**: `restore/v1-ui` | **Date**: 2026-11-01 | **Spec**: specs/002-global-pages/spec.md

## Summary
Move General's colour and font rows onto Phoenix › Colors / Fonts / Textures, add a Glows mirror page, fold the
Presets page into General › Looks and reorder the Phoenix group. Rows keep their owner through a new `module`
field on schema rows, so no saved key moves.

## Technical Context
Lua 5.1 (WoW 12.x retail and 1.60 Forever), Phoenix_UI_Options. Tests: tools/smoke/harness.lua, luacheck,
tools/check_locales.py, tools/prepush. Constraints: constitution v1.0.0 (original code, live apply, no OnUpdate,
10 locales, CHANGES entry per commit).

## Constitution Check
- Original code only: yes (Phoenix's own renderer and pages).
- Live apply: rows still write through ns.DB:Set on their module.
- No OnUpdate, no slash commands, no new media: yes.

## Project Structure
```
Phoenix_UI_Options/Config/Renderer.lua    # row owner (item.module)
Phoenix_UI_Options/Config/Appearance.lua  # Colors and Glows pages, global sections on Fonts and Textures
Phoenix_UI_Options/Options/General.lua    # General trimmed, Looks tab
Phoenix_UI_Options/Config/Presets.lua     # rows exported, page retired
Phoenix_UI_Options/Config/Groups.lua      # Phoenix group order
Locales/*.lua                             # page names
```
