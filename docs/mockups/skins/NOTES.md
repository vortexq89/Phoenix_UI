# v2 (27 Oct 2026): Blizzard layouts
Pages 01–22 were redone. Each window keeps Blizzard's own layout, structure and placement (portrait corner, centred title, bottom, top and right tabs as in 12.1.5) and is restyled in Phoenix themes. The main image is Ember. Midnight, Horde and Alliance versions are in `variants/`. The right-hand legend lists every Blizzard element and its v1 status. Phoenix extras have a dashed outline and a ◆ tag. The ⚙ cog in the title bar opens the inline flyout. The v1 images are in `v1/`. The full table is in `SKINS_FEATURE_AUDIT.md`. Sources are in `src/n01–n22.py`, `src/sk2.py` and `src/feats.py`.

---
# Phoenix UI: Skins mockups (Ember theme), 27 Oct 2026

These are mockups only, and no addon code was changed. There are 24 pages at 1600×1000 plus a contact sheet (`00_contact_sheet.png`). Each page shows the window in Phoenix's Ember design system v1 (obsidian glass, ember accent, Rajdhani/Inter/JetBrains Mono). On the right of each page there are four cards:
1. **Coverage today**: full, partial or none, from reading the code.
2. **Phoenix restyle**: what this design adds.
3. **Restriction → workaround**: the taint-safe method.
4. **Settings**: the simple/advanced chips. Every look is a live setting.

Art: original CSS shapes, Phoenix_UI_Media icons (original Phoenix work and game-icons.net CC BY 3.0 glyphs), and OFL fonts copied from Phoenix_UI_Media. There is no Blizzard art and nothing from other addons. The 3D model areas are placeholders, because Blizzard renders those in game and Phoenix only themes the backdrop.

| File | Window |
|---|---|
| 01_character | Character: paperdoll, stats, reputation, currency |
| 02_spellbook | Spellbook and specialization |
| 03_talents | Class, hero and spec talent trees |
| 04_collections_mounts_pets | Mounts and Pet Journal |
| 05_collections_toys_heirlooms_appearances | Toys, heirlooms, appearances |
| 06_transmog | Transmog (12.x TransmogFrame) and dressing room |
| 07_group_finder | Group Finder / premade / ready dialog / rated PvP |
| 08_friends | Friends, Who, Quick Join |
| 09_loot | Loot window, roll frames, toasts, loot history |
| 10_bags_bank | Vault bags, bank, guild bank |
| 11_merchant | Merchant and buyback |
| 12_mail | Inbox and send mail |
| 13_auction_house | Auction House |
| 14_professions | Professions and specializations |
| 15_achievements | Achievements |
| 16_encounter_journal | Adventure Guide and Traveler's Log |
| 17_map_quest_log | World map and quest log |
| 18_calendar | Calendar and event view |
| 19_guild_communities | Guild and communities |
| 20_game_menu_popups | Game Menu, StaticPopups, ready/role checks |
| 21_tooltips | Every tooltip family |
| 22_more_windows | Great Vault, gossip/quest, Edit Mode, Settings, Housing |
| 23_theme_system | Tokens, surface themes, accents, type, controls, anatomy |
| 24_media_sheet | Proposed new SVG icons and textures, plus the existing licensed media |

The proposed new media is in `media/svg/` (30 original SVG icons) and `media/textures/` (22 original procedural textures, PNG + TGA). Sources are in `src/`. Run `python3 src/m01.py` … `m08.py`. `svg.py` and `tex.py` rebuild the media. The full audit is in `docs/SKINS_AUDIT.md` (a copy is next to this file).
