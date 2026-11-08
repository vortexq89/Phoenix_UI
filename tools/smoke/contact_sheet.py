#!/usr/bin/env python3
"""Contact sheets of the settings window (GUI polish plan §5): renders every scene in a directory written by
tools/smoke/shot.lua and packs them six to a sheet, each labelled with its page and tab. With --compare <old dir>
it also writes each scene's old and new picture side by side when they differ, and lists how much changed, so a
GUI change is seen page by page before it ships.

    python3 tools/smoke/contact_sheet.py <scene dir> <out dir> [--compare <old scene dir>]"""
import glob
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shot_render  # noqa: E402

THUMB_W, COLS, ROWS = 900, 2, 3


def render(scene):
    d = json.load(open(scene, encoding='utf-8'))
    wx, wy, ww, wh = d['window']
    sw, sh = d['screen']
    canvas = Image.new('RGBA', (int(sw), int(sh)), (10, 10, 12, 255))
    for it in sorted(d['items'], key=lambda i: (i['lvl'], i['layer'], i['sub'], i['seq'])):
        (shot_render.draw_tex if it['kind'] == 'tex' else shot_render.draw_text)(canvas, it, 1.0)
    return canvas.crop((int(wx), int(wy), int(wx + ww), int(wy + wh))).convert('RGB')


def thumb(img, label):
    t = img.copy()
    t.thumbnail((THUMB_W, THUMB_W))
    ImageDraw.Draw(t).rectangle((0, 0, 8 + 7 * len(label), 16), fill=(0, 0, 0))
    ImageDraw.Draw(t).text((4, 2), label, fill=(255, 210, 60))
    return t


def main():
    src, out = sys.argv[1], sys.argv[2]
    old = sys.argv[sys.argv.index('--compare') + 1] if '--compare' in sys.argv else None
    os.makedirs(out, exist_ok=True)
    thumbs, changed = [], []
    for scene in sorted(glob.glob(os.path.join(src, '*.json'))):
        name = os.path.splitext(os.path.basename(scene))[0]
        img = render(scene)
        thumbs.append(thumb(img, name))
        prev = old and os.path.join(old, name + '.json')
        if prev and os.path.exists(prev):
            before = render(prev)
            if before.size != img.size:
                before = before.resize(img.size)
            diff = ImageChops.difference(before, img).convert('L').point(lambda v: 255 if v > 24 else 0)
            share = sum(diff.histogram()[255:]) / float(img.width * img.height)
            if share > 0.001:
                changed.append((share, name))
                pair = Image.new('RGB', (img.width * 2 + 10, img.height), (40, 40, 40))
                pair.paste(before, (0, 0)); pair.paste(img, (img.width + 10, 0))
                pair.save(os.path.join(out, 'diff_' + name + '.jpg'), quality=85)
    per = COLS * ROWS
    for k in range(0, len(thumbs), per):
        group = thumbs[k:k + per]
        w, h = max(t.width for t in group), max(t.height for t in group)
        sheet = Image.new('RGB', (w * COLS, h * ROWS), (24, 24, 26))
        for i, t in enumerate(group):
            sheet.paste(t, ((i % COLS) * w, (i // COLS) * h))
        sheet.save(os.path.join(out, 'sheet_%02d.jpg' % (k // per)), quality=85)
    print('contact_sheet: %d scenes, %d sheets in %s' % (len(thumbs), (len(thumbs) + per - 1) // per, out))
    for share, name in sorted(changed, reverse=True):
        print('  changed %5.1f%%  %s' % (share * 100, name))


if __name__ == '__main__':
    main()
