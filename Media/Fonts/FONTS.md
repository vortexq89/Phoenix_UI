# Bundled fonts

Phoenix_UI ships 89 font files in 36 families (10.0 MB). All of them may be redistributed
with the addon under the SIL Open Font License 1.1, the Ubuntu Font Licence 1.0 or Apache 2.0, and each
licence text travels with the files in `Licenses/`. Every face is registered with LibSharedMedia as
"Phoenix <Family> <Weight>", so other addons can use them too.

Everything except Roboto and Roboto Condensed is built by `tools/media/gen_fonts.py` from the google/fonts
repository:

- Fonts whose licence declares a Reserved Font Name, and Ubuntu (UFL), are copied **byte-for-byte as
  published**, because modified versions may not carry those names. Only static releases are used for them.
- All other fonts are instanced from their variable masters to static weights where needed and **subset** to
  Latin, Latin-1, Latin Extended-A/B and Additional, Greek, Cyrillic, general punctuation, currency signs and
  a few symbols, keeping kerning and hinting. Copyright notices stay in the font files.

Fonts without Cyrillic are hidden from the pickers on Russian clients, and text set in them falls back to
Roboto. Korean and Chinese clients use the game font throughout, since none of these fonts cover CJK.

| Family | Weights | Group | Cyrillic | Shipped | Licence | Size |
|---|---|---|---|---|---|---|
| Roboto | Regular, Medium, Bold | core | yes | as published | Apache 2.0 — Licenses/LICENSE-Roboto.txt | 429 KB |
| Roboto Condensed | Regular, Medium, SemiBold, Bold | core | yes | as published | Apache 2.0 — Licenses/LICENSE-Roboto.txt | 571 KB |
| Inter | Regular, Medium, SemiBold, Bold | sans | yes | subset | SIL OFL 1.1 — Licenses/OFL-Inter.txt | 484 KB |
| Barlow | Regular, Medium, SemiBold, Bold | sans | no | subset | SIL OFL 1.1 — Licenses/OFL-Barlow.txt | 245 KB |
| Barlow Semi Condensed | Medium, SemiBold, Bold | condensed | no | subset | SIL OFL 1.1 — Licenses/OFL-BarlowSemiCondensed.txt | 190 KB |
| Barlow Condensed | Medium, SemiBold, Bold | condensed | no | subset | SIL OFL 1.1 — Licenses/OFL-BarlowCondensed.txt | 186 KB |
| Rajdhani | Medium, SemiBold, Bold | display | no | subset | SIL OFL 1.1 — Licenses/OFL-Rajdhani.txt | 202 KB |
| Oswald | Regular, Medium, SemiBold | condensed | yes | subset | SIL OFL 1.1 — Licenses/OFL-Oswald.txt | 198 KB |
| Exo 2 | Medium, SemiBold, Bold | display | yes | subset | SIL OFL 1.1 — Licenses/OFL-Exo2.txt | 322 KB |
| Montserrat | Medium, SemiBold, Bold | sans | yes | subset | SIL OFL 1.1 — Licenses/OFL-Montserrat.txt | 316 KB |
| Fira Sans | Regular, Medium, SemiBold, Bold | sans | yes | subset | SIL OFL 1.1 — Licenses/OFL-FiraSans.txt | 759 KB |
| Fira Sans Condensed | Medium, SemiBold | condensed | yes | subset | SIL OFL 1.1 — Licenses/OFL-FiraSansCondensed.txt | 377 KB |
| Noto Sans | Regular, Medium, Bold | sans | yes | subset | SIL OFL 1.1 — Licenses/OFL-NotoSans.txt | 386 KB |
| Open Sans | Regular, SemiBold, Bold | sans | yes | subset | SIL OFL 1.1 — Licenses/OFL-OpenSans.txt | 232 KB |
| Lato | Regular, Bold | sans | yes | as published | SIL OFL 1.1 — Licenses/OFL-Lato.txt | 1282 KB |
| Ubuntu | Regular, Medium, Bold | sans | yes | as published | Ubuntu Font Licence 1.0 — Licenses/UFL-Ubuntu.txt | 999 KB |
| Manrope | Medium, Bold | sans | yes | subset | SIL OFL 1.1 — Licenses/OFL-Manrope.txt | 158 KB |
| Space Grotesk | Medium, Bold | sans | no | subset | SIL OFL 1.1 — Licenses/OFL-SpaceGrotesk.txt | 96 KB |
| Sora | SemiBold | sans | no | subset | SIL OFL 1.1 — Licenses/OFL-Sora.txt | 32 KB |
| Titillium Web | Regular, SemiBold, Bold | sans | no | subset | SIL OFL 1.1 — Licenses/OFL-TitilliumWeb.txt | 140 KB |
| Archivo Narrow | Medium, SemiBold, Bold | condensed | no | subset | SIL OFL 1.1 — Licenses/OFL-ArchivoNarrow.txt | 105 KB |
| PT Sans Narrow | Regular, Bold | condensed | yes | as published | SIL OFL 1.1 — Licenses/OFL-PTSansNarrow.txt | 863 KB |
| Saira Semi Condensed | Medium, SemiBold, Bold | condensed | no | as published | SIL OFL 1.1 — Licenses/OFL-SairaSemiCondensed.txt | 281 KB |
| Khand | Medium, SemiBold | condensed | no | subset | SIL OFL 1.1 — Licenses/OFL-Khand.txt | 96 KB |
| Teko | Medium, SemiBold | display | no | subset | SIL OFL 1.1 — Licenses/OFL-Teko.txt | 44 KB |
| Kanit | Medium, SemiBold | display | no | subset | SIL OFL 1.1 — Licenses/OFL-Kanit.txt | 236 KB |
| Chakra Petch | Medium, SemiBold, Bold | display | no | subset | SIL OFL 1.1 — Licenses/OFL-ChakraPetch.txt | 111 KB |
| Oxanium | Medium, Bold | display | no | subset | SIL OFL 1.1 — Licenses/OFL-Oxanium.txt | 46 KB |
| Play | Regular, Bold | display | yes | as published | SIL OFL 1.1 — Licenses/OFL-Play.txt | 400 KB |
| Quantico | Regular, Bold | display | no | as published | SIL OFL 1.1 — Licenses/OFL-Quantico.txt | 41 KB |
| Bebas Neue | Regular | display | no | subset | SIL OFL 1.1 — Licenses/OFL-BebasNeue.txt | 37 KB |
| Russo One | Regular | display | yes | as published | SIL OFL 1.1 — Licenses/OFL-RussoOne.txt | 38 KB |
| Black Ops One | Regular | display | no | subset | SIL OFL 1.1 — Licenses/OFL-BlackOpsOne.txt | 125 KB |
| Cinzel | Regular, Bold | serif | no | subset | SIL OFL 1.1 — Licenses/OFL-Cinzel.txt | 82 KB |
| JetBrains Mono | Medium, Bold | mono | yes | subset | SIL OFL 1.1 — Licenses/OFL-JetBrainsMono.txt | 82 KB |
| Roboto Mono | Medium | mono | yes | subset | SIL OFL 1.1 — Licenses/OFL-RobotoMono.txt | 66 KB |
