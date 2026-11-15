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

## Button shapes (2.0 S7)

`MaskRounded`, `MaskCircle` and `MaskHex` are 64×64 white textures with the shape in the alpha channel. Action
buttons use them as a `MaskTexture` on the icon, the cooldown swipe (`SetSwipeTexture`), the highlight and the
pushed/checked overlays, so every layer follows the chosen shape. `RingRounded`, `RingCircle` and `RingHex` are
the matching outline, 1/16 of the size wide, which the game tints with the border colour. They are drawn at 4×
and downsampled (Lanczos) in `button_shapes()` of `tools/media/gen_textures.py`. The circle also turns on
`SetUseCircularEdge` for the swipe. Square buttons need neither file.
