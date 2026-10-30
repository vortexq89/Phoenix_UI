# Credits

Phoenix UI is original code. It bundles these third-party assets, each under its own licence (texts in the
folders named).

## Fonts

- **Phoenix Font** (Regular, SemiBold, Bold) - the default UI font. A modified version of
  **Barlow Semi Condensed** by Jeremy Tribby (Copyright 2017 The Barlow Project Authors), re-proportioned
  for UI text by `tools/media/phoenix_font/build.py` and renamed as the SIL Open Font License 1.1 requires.
  Licence: `Media/Fonts/Licenses/OFL-PhoenixFont.txt`.
- **PT Sans Narrow** by ParaType (SIL OFL 1.1) - used for Cyrillic text on Russian clients.
- The other bundled families and their licences are listed in `Media/Fonts/FONTS.md`.
- **Expressway** (Typodermic Fonts) is **not** part of Phoenix UI. When another addon already installed on the
  player's PC provides it (ElvUI, EllesmereUI or a LibSharedMedia pack), Phoenix UI uses that copy at run time
  (Settings > General > "Use Expressway when installed"). Nothing of Expressway is copied, traced or shipped.

## Icons and media

- Phosphor icons (MIT) - `Media/Icons/LICENSE`.

## Spec icon styles (t163)

The spec icon styles (UI/SpecIcon.lua) use the game's own spec icons as the client draws them; nothing is
redistributed. Every mask, ring, frame and effect on top (diamond, shield, octagon, squircle masks and rings, gloss,
inner shade, ember frame) is Phoenix's own, procedurally drawn by tools/media/gen_spec_icons.py (MIT). No third-party
icon set is used: none of the WoW class/spec icon sets we found is CC0 or permissively licensed.
