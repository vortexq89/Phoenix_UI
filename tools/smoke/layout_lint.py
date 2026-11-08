#!/usr/bin/env python3
"""Layout lint for the settings window: reads the scenes tools/smoke/shot.lua writes (PUI_SHOT_OUT) and reports
text that overlaps other text, text cut off with an ellipsis, text outside the window, and text with fighting
anchors (a centre and an edge anchor on one axis). Text is laid out with
the real font files (shot_render.layout_text), as the game draws it.

    python3 tools/smoke/layout_lint.py <scene dir> [--strict] [--cuts]
      --strict  exit 1 on any overlap or text outside the window (CI); anchor conflicts are listed only
      --cuts    also list every text cut off with an ellipsis

Usually run through tools/smoke/layout_matrix.sh, which writes the scenes for every page and tab at several window
sizes, font scales and languages first."""
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shot_render  # noqa: E402

MIN_OVERLAP_W, MIN_OVERLAP_H = 2.0, 3.0  # px: anti-aliasing and line-gap noise below this is ignored


def ink(it):
    """The rectangle the glyphs of a font string cover (x0, y0, x1, y1), or None when nothing is visible."""
    if it.get('alpha', 1) < 0.05:
        return None, None
    L = shot_render.layout_text(it, 1.0)
    f, lines = L['f'], L['lines']
    if not lines or not any(ln.strip() for ln in lines):
        return None, L
    widths = [f.getlength(ln) for ln in lines]
    tw, width = max(widths), L['width']
    if L['jh'] == 'LEFT':
        x0 = L['left']
    elif L['jh'] == 'RIGHT':
        x0 = L['left'] + width - tw
    else:
        x0 = L['left'] + (width - tw) / 2
    # the glyph band of each line, not the full line height: stacked labels may touch without overlapping
    gap = (L['lh'] - L['size']) / 2
    r = [x0, L['top'] + gap, x0 + tw, L['top'] + L['bh'] - gap]
    clip = it.get('clip')
    if clip:
        r = [max(r[0], clip[0]), max(r[1], clip[1]), min(r[2], clip[2]), min(r[3], clip[3])]
        if r[2] - r[0] < 1 or r[3] - r[1] < 1:
            return None, L
    return r, L


def lint(scene):
    d = json.load(open(scene, encoding='utf-8'))
    wx, wy, ww, wh = d['window']
    texts = []
    for it in d['items']:
        if it['kind'] != 'text':
            continue
        r, L = ink(it)
        if r:
            texts.append((r, L, it))
    problems = {'overlap': [], 'outside': [], 'cut': [], 'conflict': []}
    for it in d['items']:
        # a centre anchor (LEFT/RIGHT pin the vertical centre, TOP/BOTTOM the horizontal one) next to an edge anchor
        # on the same axis fights it: the game stretches the box and the text lands somewhere in between
        if it['kind'] == 'text':
            for axis, pts in (('vertical', it.get('ys') or []), ('horizontal', it.get('xs') or [])):
                kinds = {p[0] for p in pts}
                if 0.5 in kinds and (0.0 in kinds or 1.0 in kinds):
                    problems['conflict'].append('"%s" has a centre and an edge anchor on the %s axis'
                                                % (it['text'][:50], axis))
    for r, L, it in texts:
        if r[0] < wx - 1 or r[2] > wx + ww + 1 or r[1] < wy - 1 or r[3] > wy + wh + 1:
            problems['outside'].append('"%s" leaves the window' % L['text'][:60])
        if L['cut']:
            problems['cut'].append('"%s" is cut to "%s"' % (L['text'][:60], L['lines'][0][:60]))
    for i in range(len(texts)):
        a, La, ia = texts[i]
        for j in range(i + 1, len(texts)):
            b, Lb, ib = texts[j]
            w = min(a[2], b[2]) - max(a[0], b[0])
            h = min(a[3], b[3]) - max(a[1], b[1])
            if w <= MIN_OVERLAP_W or h <= MIN_OVERLAP_H:
                continue
            if La['text'] == Lb['text'] and abs(a[0] - b[0]) < 2 and abs(a[1] - b[1]) < 2:
                continue  # the same string drawn twice (shadow / glow copy)
            problems['overlap'].append('"%s" overlaps "%s" (%dx%d px at %d,%d)' % (
                La['text'][:40], Lb['text'][:40], w, h, max(a[0], b[0]) - wx, max(a[1], b[1]) - wy))
    return problems


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    strict, cuts = '--strict' in sys.argv, '--cuts' in sys.argv
    total = {'overlap': 0, 'outside': 0, 'cut': 0, 'conflict': 0}
    scenes = sorted(glob.glob(os.path.join(args[0], '*.json')))
    for scene in scenes:
        p = lint(scene)
        name = os.path.splitext(os.path.basename(scene))[0]
        for k in total:
            total[k] += len(p[k])
        shown = p['overlap'] + p['outside'] + p['conflict'] + (p['cut'] if cuts else [])
        if shown:
            print('%s:' % name)
            for line in p['overlap']:
                print('  overlap  ' + line)
            for line in p['outside']:
                print('  outside  ' + line)
            for line in p['conflict']:
                print('  anchors  ' + line)
            if cuts:
                for line in p['cut']:
                    print('  cut      ' + line)
    print('layout_lint: %d scenes, %d overlaps, %d outside the window, %d anchor conflicts, %d cut with an ellipsis'
          % (len(scenes), total['overlap'], total['outside'], total['conflict'], total['cut']))
    # anchor conflicts are reported but do not fail yet: the TOPLEFT + RIGHT idiom is still common (GUI plan §5)
    if strict and (total['overlap'] or total['outside']):
        sys.exit(1)


if __name__ == '__main__':
    main()
