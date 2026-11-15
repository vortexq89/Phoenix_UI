"""Phoenix chrome icons v4 (t149): full-colour, original work (Phoenix UI licence). UI chrome only - micro menu,
settings nav/tabs, macro window controls, window controls, and one PANEL icon per window (top-left corner).
Never used for class, spec, ability, spell, item, mount, pet or toy icons.
Look: the v3 24-grid geometry rendered as a solid ember body - vertical gradient (pale gold -> ember orange ->
crimson), dark rim, top light, soft drop shadow. States: normal, hover (ember glow), pressed (light burst + bright
core, 94% scale), disabled (desaturated). Panel icons sit on an obsidian medallion with a gold rim.
Masters are rendered at 4x and downsampled; export() writes 256px PNGs."""
import io, math, os, cairosvg
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageEnhance
from gen_chrome_icons import P as BASE

PANEL = {
 'panel-character':   BASE['micro-character'],
 'panel-bags':        '<path d="M7 9a5 5 0 0110 0"/><path d="M5 9h14l-1 11H6z"/><path d="M9 13h6v3H9z"/>',
 'panel-mail':        '<rect x="3.5" y="6" width="17" height="12" rx="1.5"/><path d="M3.5 7l8.5 6.5L20.5 7"/>',
 'panel-collections': BASE['micro-collections'],
 'panel-macro':       '<path d="M6 4h10a2 2 0 012 2v14H8a2 2 0 01-2-2z"/><path d="M10.5 9.5l-2 2.5 2 2.5M13.5 9.5l2 2.5-2 2.5"/>',
 'panel-friends':     '<circle cx="8.5" cy="8.5" r="3"/><circle cx="15.5" cy="8.5" r="3"/><path d="M3 19c0-3 2.5-5.5 5.5-5.5 1.4 0 2.6.5 3.5 1.3.9-.8 2.1-1.3 3.5-1.3 3 0 5.5 2.5 5.5 5.5"/>',
 'panel-guild':       BASE['micro-guild'],
 'panel-groupfinder': '<circle cx="12" cy="12" r="8"/><path d="M15.5 8.5l-2 5-5 2 2-5z"/>',
 'panel-settings':    '<path d="M12 3.5l1.6 2.3 2.7-.6.6 2.7 2.3 1.6-1.4 2.5 1.4 2.5-2.3 1.6-.6 2.7-2.7-.6L12 20.5l-1.6-2.3-2.7.6-.6-2.7-2.3-1.6L6.2 12 4.8 9.5l2.3-1.6.6-2.7 2.7.6z"/><circle cx="12" cy="12" r="3"/>',
 'panel-achievements':BASE['micro-achievements'],
 'panel-spellbook':   BASE['micro-spells'],
 'panel-talents':     '<circle cx="12" cy="5.5" r="2"/><circle cx="6.5" cy="12" r="2"/><circle cx="17.5" cy="12" r="2"/><circle cx="12" cy="18.5" r="2"/><path d="M10.7 7l-3 3.5M13.3 7l3 3.5M7.8 13.5l3 3.5M16.2 13.5l-3 3.5"/>',
 'panel-quests':      BASE['micro-quests'],
 'panel-map':         '<path d="M3.5 6l5-2 7 2.5 5-2V18l-5 2-7-2.5-5 2z"/><path d="M8.5 4v13.5M15.5 6.5V20"/>',
 'panel-calendar':    '<rect x="4" y="5.5" width="16" height="14.5" rx="2"/><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4"/><path d="M8 14h2M12 14h2M8 17h2"/>',
 'panel-professions': BASE['micro-professions'],
 'panel-journal':     BASE['micro-journal'],
 'panel-pvp':         '<path d="M12 3.5l7 2.5v5.5c0 4.2-3 7.4-7 9-4-1.6-7-4.8-7-9V6z"/><path d="M9 9l6 6M15 9l-6 6"/>',
 'panel-shop':        BASE['micro-shop'],
 'panel-help':        BASE['micro-help'],
 'panel-gamemenu':    BASE['nav-phoenix'],
 'panel-bank':        '<path d="M3.5 9L12 4l8.5 5z"/><path d="M5.5 9.5v8M9.8 9.5v8M14.2 9.5v8M18.5 9.5v8M3.5 20h17"/>',
 'panel-merchant':    '<ellipse cx="12" cy="7" rx="6.5" ry="2.5"/><path d="M5.5 7v5c0 1.4 2.9 2.5 6.5 2.5s6.5-1.1 6.5-2.5V7"/><path d="M5.5 12v5c0 1.4 2.9 2.5 6.5 2.5s6.5-1.1 6.5-2.5v-5"/>',
 'panel-auction':     '<path d="M13 4.5l5 5-2.5 2.5-5-5z"/><path d="M12.2 10.8L5 18l1.5 1.5 7.2-7.2"/><path d="M13 20h7"/>',
 'panel-trade':       '<path d="M4 8.5h14l-3.5-3.5M20 15.5H6l3.5 3.5"/>',
 'panel-loot':        '<path d="M4 10a3 3 0 013-3h10a3 3 0 013 3v9H4z"/><path d="M4 12h16"/><rect x="10.5" y="10.5" width="3" height="4" rx=".8"/>',
 'panel-communities': '<path d="M4 5h11a1.5 1.5 0 011.5 1.5v6A1.5 1.5 0 0115 14H9l-3.5 3v-3H4a1.5 1.5 0 01-1.5-1.5v-6A1.5 1.5 0 014 5z"/><path d="M18.5 9h1.5A1.5 1.5 0 0121.5 10.5V16a1.5 1.5 0 01-1.5 1.5h-1V20l-3-2.5H12"/>',
}
ALL = {**BASE, **PANEL}
STOPS = [(0.0, (255, 236, 170)), (0.32, (255, 176, 64)), (0.62, (240, 96, 28)), (1.0, (150, 30, 18))]

def _mask(body, n, sw, fill):
    s = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{n}" height="{n}" viewBox="0 0 24 24" '
         f'fill="{"#fff" if fill else "none"}" stroke="{"none" if fill else "#fff"}" color="#fff" stroke-width="{sw}" '
         f'stroke-linecap="round" stroke-linejoin="round">{body}</svg>')
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=s.encode(), output_width=n, output_height=n))).split()[3]

def _grad(n, stops, horiz=False):
    g = Image.new('RGB', (1, n)); px = g.load()
    for i in range(n):
        t = i / (n - 1)
        for (a, ca), (b, cb) in zip(stops, stops[1:]):
            if a <= t <= b:
                u = (t - a) / (b - a); px[0, i] = tuple(int(ca[k] + (cb[k] - ca[k]) * u) for k in range(3)); break
    return g.resize((n, n))

def _glyph(name, n):
    body = ALL[name]
    st = _mask(body, n, 2.5, False); fl = _mask(body, n, 2.5, True)
    a = ImageChops.lighter(st, fl.point(lambda v: v * 0.62))
    g = _grad(n, STOPS)
    dark = ImageEnhance.Brightness(g).enhance(0.62)
    col = Image.composite(g, dark, st)                     # stroke bright, fill body deeper -> volume
    out = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    rim = a.filter(ImageFilter.MaxFilter(max(3, n // 64 * 2 + 1)))
    sh = rim.filter(ImageFilter.GaussianBlur(n / 40))
    out.paste((0, 0, 0, 255), (int(n * .012), int(n * .03)), sh.point(lambda v: v * .75))
    out.paste((52, 10, 6, 255), (0, 0), rim)
    out.paste(col, (0, 0), a)
    hl = Image.new('L', (n, n), 0); ImageDraw.Draw(hl).ellipse([-n * .2, -n * .62, n * 1.2, n * .48], fill=110)
    hl = hl.filter(ImageFilter.GaussianBlur(n / 30))
    out.paste((255, 250, 225, 255), (0, 0), ImageChops.multiply(hl, st))
    return out, a

def _burst(n, a_strength=1.0):
    b = Image.new('RGBA', (n, n), (0, 0, 0, 0)); d = ImageDraw.Draw(b); c = n / 2
    for i in range(16):
        ang = i * math.pi / 8 + math.pi / 16; L = n * (0.50 if i % 2 else 0.40); w = 0.07
        d.polygon([(c, c), (c + L * math.cos(ang - w), c + L * math.sin(ang - w)), (c + L * math.cos(ang + w), c + L * math.sin(ang + w))],
                  fill=(255, 214, 120, int(150 * a_strength)))
    b = b.filter(ImageFilter.GaussianBlur(n / 90))
    core = Image.new('L', (n, n), 0); ImageDraw.Draw(core).ellipse([c - n * .3, c - n * .3, c + n * .3, c + n * .3], fill=int(200 * a_strength))
    core = core.filter(ImageFilter.GaussianBlur(n / 9))
    b.paste((255, 230, 160, 255), (0, 0), ImageChops.multiply(core, Image.new('L', (n, n), 255)))
    return b

def _medallion(n):
    m = Image.new('RGBA', (n, n), (0, 0, 0, 0)); c = n / 2
    sh = Image.new('L', (n, n), 0); ImageDraw.Draw(sh).ellipse([n * .06, n * .09, n * .96, n * .99], fill=190)
    m.paste((0, 0, 0, 255), (0, 0), sh.filter(ImageFilter.GaussianBlur(n / 30)))
    rim = _grad(n, [(0, (255, 226, 150)), (0.5, (214, 130, 40)), (1, (110, 44, 14))])
    k = Image.new('L', (n, n), 0); ImageDraw.Draw(k).ellipse([n * .04, n * .04, n * .96, n * .96], fill=255); m.paste(rim, (0, 0), k)
    inner = Image.new('RGB', (n, n)); dd = ImageDraw.Draw(inner)
    for r in range(int(n * .42), 0, -1):
        t = r / (n * .42); dd.ellipse([c - r, c - r * 1.0 - n * .04 * (1 - t), c + r, c + r - n * .04 * (1 - t)],
                                      fill=(int(14 + 52 * (1 - t) ** 1.6), int(9 + 22 * (1 - t) ** 1.6), int(10 + 18 * (1 - t) ** 1.6)))
    k2 = Image.new('L', (n, n), 0); ImageDraw.Draw(k2).ellipse([n * .09, n * .09, n * .91, n * .91], fill=255); m.paste(inner, (0, 0), k2)
    ring = Image.new('L', (n, n), 0); ImageDraw.Draw(ring).ellipse([n * .12, n * .12, n * .88, n * .88], outline=90, width=max(1, n // 90))
    m.paste((255, 170, 70, 255), (0, 0), ring)
    gl = Image.new('L', (n, n), 0); ImageDraw.Draw(gl).ellipse([n * .2, n * .1, n * .8, n * .42], fill=38)
    m.paste((255, 255, 255, 255), (0, 0), gl.filter(ImageFilter.GaussianBlur(n / 25)))
    return m

def render(name, size=64, state='normal', medallion=None):
    n = size * 4; medallion = name.startswith('panel-') if medallion is None else medallion
    canvas = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    gs = int(n * (0.60 if medallion else 0.86)); 
    if state == 'pressed': gs = int(gs * .94)
    g, a = _glyph(name, gs)
    if state == 'hover': g = ImageEnhance.Brightness(g).enhance(1.12)
    if state == 'pressed': g = ImageEnhance.Brightness(g).enhance(1.28)
    if state == 'disabled':
        rgb = ImageEnhance.Color(g.convert('RGB')).enhance(0.05); rgb = ImageEnhance.Brightness(rgb).enhance(0.6)
        g = Image.merge('RGBA', (*rgb.split(), g.split()[3].point(lambda v: v * .6)))
    if state == 'pressed': canvas.alpha_composite(_burst(n, 1.0))
    if medallion: canvas.alpha_composite(_medallion(n))
    o = (n - gs) // 2
    if state in ('hover', 'pressed'):
        glow = Image.new('L', (n, n), 0); glow.paste(a, (o, o)); glow = glow.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(n / 22))
        canvas.paste((255, 140, 40, 255), (0, 0), glow.point(lambda v: v * (.9 if state == 'hover' else 1)))
        if state == 'pressed': canvas.alpha_composite(_burst(n, .55))
    canvas.alpha_composite(g, (o, o))
    return canvas.resize((size, size), Image.LANCZOS)

STATES = ('normal', 'hover', 'pressed', 'disabled')
def export(out, size=256):
    os.makedirs(out, exist_ok=True)
    for nm in ALL:
        for st in STATES: render(nm, size, st).save(os.path.join(out, f'{nm}_{st}.png'))
