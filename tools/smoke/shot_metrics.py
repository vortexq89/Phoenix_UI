#!/usr/bin/env python3
"""Writes the advance widths of the bundled fonts as a Lua table, so tools/smoke/shot.lua measures text the way the
game does (GetStringWidth) instead of the harness's fixed glyph width.
    python3 tools/smoke/shot_metrics.py <out.lua>"""
import glob, os, sys
from fontTools.ttLib import TTFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
WANT = ('PhoenixFont-', 'Cinzel', 'PTSansNarrow', 'Roboto-', 'JetBrainsMono')
out = ['return {']
for path in sorted(glob.glob(os.path.join(ROOT, 'Media', 'Fonts', '*.ttf'))):
    name = os.path.basename(path)
    if not name.startswith(WANT):
        continue
    f = TTFont(path)
    cmap, hmtx = f.getBestCmap(), f['hmtx']
    upm = f['head'].unitsPerEm
    adv = []
    for cp in range(32, 0x250):
        g = cmap.get(cp)
        if g:
            adv.append('[%d]=%d' % (cp, hmtx[g][0]))
    out.append('  [%r] = { upm = %d, adv = { %s } },' % (name, upm, ', '.join(adv)))
out.append('}')
open(sys.argv[1], 'w').write('\n'.join(out).replace("['", '["').replace("']", '"]'))
print(sys.argv[1])
