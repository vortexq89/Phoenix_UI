# Feature Specification: Global pages (Colors, Fonts, Textures, Glows, General, Profiles)

**Feature Branch**: `restore/v1-ui` (no feature branch; the git extension is not installed)
**Created**: 2026-11-01
**Status**: Draft
**Input**: Rebuild map (docs/research/ELLESMERE_REBUILD_MAP.md) §8 step 2: "Global pages: Colors, Fonts, Textures,
Glows, General (merging the Presets page, Skins › Appearance and the Textures page: item 5 part 2), Profiles."
§7 group 5 gives the Phoenix group order. EllesmereUI's global pages are listed in
docs/research/ellesmere_inventory/SETTINGS.md (EUI__General, EUI_Colors, EUI_Fonts, EUI_Textures, EUI_Glows).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One place per kind of look (Priority: P1)
A player who wants to change colours, fonts, textures or glows opens the page with that name in the Phoenix group
and finds the global choice at the top and every module's own choice under it, like EllesmereUI.

**Independent Test**: open Phoenix › Colors, Fonts, Textures and Glows; each starts with its global section, then
lists the module settings of its kind; every change applies live.

**Acceptance Scenarios**:
1. **Given** Phoenix › Colors, **Then** it shows the accent (theme preset and custom colour), class colours, power
   colours and dispel colours, and changing one repaints at once.
2. **Given** Phoenix › Fonts, **Then** the global font section (UI font, unit font, font size, outline, Expressway,
   Blizzard fonts) comes first, then the "everywhere at once" row and the per-module fonts.
3. **Given** Phoenix › Textures, **Then** the global bar texture comes first, then the per-module textures.
4. **Given** Phoenix › Glows, **Then** every module glow setting is listed with an arrow to its module.

### User Story 2 - General is general (Priority: P2)
General keeps what EllesmereUI keeps there: display (scale, minimap button, spec icons), sound and accessibility,
plus the three looks (the old Presets page) as its Looks tab. The colour and font tabs leave General.

**Independent Test**: General has no colour or font rows; the looks cards, undo and setup buttons are under
General › Looks; the Presets page is no longer in the sidebar and search still finds every setting.

### User Story 3 - Sidebar order (Priority: P3)
The Phoenix group lists General, Colors, Fonts, Textures, Glows, Sounds, Profiles, Layout, Plugins, Bugs,
Diagnostics, About (map §7 group 5).

### Edge Cases
- Settings keep their saved keys: every moved row still reads and writes the General module, so profiles,
  presets, reset and the changed-from-default count are unchanged (no migration).
- A row shown on a global page but owned by another module resets and counts against that module.
- Search finds each setting once, on its new page.

## Requirements *(mandatory)*
- **FR-001**: a schema row may name its owner (`module = "General"`); the renderer reads, writes, resets and
  counts it against that module.
- **FR-002**: a Colors page (key `colors`) with the accent, class, power and dispel colour rows.
- **FR-003**: the Fonts page starts with the global font section; the Textures page with the global bar texture.
- **FR-004**: a Glows page (key `glows`) mirroring every module row whose key names a glow, each linking to its
  module.
- **FR-005**: General loses its colour and text tabs and gains Looks (the old Presets page rows); the `presets`
  page is retired from the sidebar.
- **FR-006**: Phoenix group order per US3. New page names in 10 locales.
- **FR-008**: the Profiles page is split into three tabs: Profile, Automatic (characters, spec, place), Share.
- **FR-007**: no saved-variable key changes; every setting applies live.

Out of scope here: Skins › Appearance stays with Blizzard Skins, which step 8 rebuilds (t225: no work on code
about to be replaced); EllesmereUI's dark mode, combat CVars and module glow templates are new features for later
steps. Profiles keeps its settings (per-spec and per-place profiles already exist) and gains tabs (FR-008).

## Success Criteria *(mandatory)*
- **SC-001**: the four global pages exist and lead with their global section (harness).
- **SC-002**: the number of settings found by search and by CountSettings over all pages is unchanged.
- **SC-003**: every module and page is in exactly one sidebar group (layout coverage test).
