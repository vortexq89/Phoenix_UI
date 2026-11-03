# Media library (Phoenix_UI_Media)

Optional child, not load-on-demand (it only registers paths; the client reads a file when it is first used). About 39 MB, most of it the three CJK fonts.

- Fonts (43, SIL OFL 1.1, Google Fonts): Latin/Cyrillic/Greek families, Arabic (Noto Sans Arabic, Cairo, Tajawal), Simplified Chinese, Japanese and Korean (Noto Sans SC/JP/KR). Variable fonts are cut to static instances (.tools/media/fonts.py).
- Bar textures (22), backgrounds (12), borders (6 backdrop edge files), glows/shapes (12): original procedural work (.tools/media/textures.py), power-of-two TGA.
- Icons (84): game-icons.net, CC BY 3.0 (one CC0), rendered white on transparent 64x64 TGA (.tools/media/icons.py). Authors not named in game-icons' licence file (badges, lucasms, various-artists) are excluded.
- Sounds (145): Kenney Interface Sounds, UI Audio and RPG Audio, CC0, OGG unchanged (.tools/media/sounds.py).

Core/Media: `Media:Register(kind, name, path, meta)`, `List`, `Path`, `Meta`, `Count`, `PlaySound`, `Alert`. Pickers preview fonts in their own face, bars as a strip, sounds on hover; long lists wrap into columns. Settings: `bars.texture` (now lists the library), `media.uiFont`/`media.numberFont` (library fonts), `media.alertSound` (None = each module's own sound; used by Reminders, Group Finder, Quest Tracker), `media.shareLSM` (register fonts, bars, backgrounds, borders and sounds with LibSharedMedia when another addon loads it, as "Phoenix: <name>").

Licence record: Phoenix_UI_Media/manifest.json (one entry per file), LICENSES.md and Licenses/. Guardrail `mediamanifest` fails on an unlisted file, a missing file, a licence outside OFL/CC0/CC BY/MIT/Apache/original, or a non-power-of-two TGA.

Unverified: `PlaySoundFile` is not in the generated API docs, so it is looked up at call time (no sound file plays if absent; the Blizzard sound is used). WoW does not shape Arabic (no joining or right-to-left), so Arabic fonts show isolated letter forms.

Deferred: backgrounds/borders/glows/icons in Theme and module pickers (registered and shared with LibSharedMedia now), font outline/shadow options per role, importing other addons' LibSharedMedia entries into Phoenix pickers, BLP conversion, a smaller CJK-free build.
