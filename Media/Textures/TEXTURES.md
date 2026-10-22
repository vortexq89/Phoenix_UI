# Bundled textures

Every texture in this folder is original art drawn procedurally by `tools/media/gen_textures.py` and is
licensed with the rest of Phoenix UI under the MIT licence (see `LICENSE` at the repository root). All files are
32-bit TGA with power-of-two sizes. Status bars are 256×32 white/grey faces that tile horizontally. The game
tints them, so one file works for any colour.

36 status bars are registered with LibSharedMedia as "Phoenix <Name>", grouped in the pickers by style:
flat, gradient, soft, glass, minimal, metal, stripes, pixel, **bold** and **pattern**. The bold and pattern
groups, added in 2.0 Phase 2, hold Neon, Tube, Gloss, Edge, Chevron, Diamond Plate, Honeycomb, Cells,
Pinstripe, Rain, Dots and Segments. They are designed to look clearly different from one another, even on
12 px nameplates.
