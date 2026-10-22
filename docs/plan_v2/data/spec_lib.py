"""Helpers for the Phoenix target spec (GAP_MATRIX source of truth).

Row = (group, name, type, range_or_choices, default, preview, status)
type:    T toggle · S slider · D dropdown · C colour · X texture picker · I input · B button · L list editor · K keybind · R reorder
preview: live = pinned preview redraws · hover = dropdown item previews on hover · world = Test/Unlock frames in the world
         · none = behaviour only (status line confirms)
status:  has = Phoenix has it now · part = exists but shallower than the target · new = missing
"""
ROWS = []
MOD = {}

def mod(key, label, group, kind, now, refs, notes=""):
    MOD[key] = dict(key=key, label=label, group=group, kind=kind, now=now, refs=refs, notes=notes, rows=[])
    global CUR
    CUR = MOD[key]

def r(group, name, typ, rng="", default="", preview="live", status="new"):
    CUR["rows"].append(dict(group=group, name=name, type=typ, range=rng, default=default, preview=preview, status=status))

def font(group, label, size=12, outline="Outline", status="new", color="#FFFFFF"):
    r(group, f"{label} font", "D", "Phoenix fonts + LibSharedMedia", "Theme UI font", "hover", status)
    r(group, f"{label} size", "S", "6–40", str(size), "live", status)
    r(group, f"{label} outline", "D", "None / Outline / Thick / Monochrome", outline, "live", status)
    r(group, f"{label} shadow", "T", "", "Off", "live", status)
    r(group, f"{label} colour", "C", "colour + class colour + theme token", color, "live", status)

def textpos(group, label, anchor="Center", status="new"):
    r(group, f"{label} anchor", "D", "9 points", anchor, "live", status)
    r(group, f"{label} X offset", "S", "-200–200", "0", "live", status)
    r(group, f"{label} Y offset", "S", "-200–200", "0", "live", status)

def border(group, label="Border", default="Pixel", status="new", shadow=True):
    r(group, f"{label} style", "D", "None / Pixel / Thin / Thick / Glow / Phoenix Ember / Inset", default, "hover", status)
    r(group, f"{label} size", "S", "0–4 px (pixel-perfect)", "1", "live", status)
    r(group, f"{label} colour", "C", "colour + class colour + quality + theme token", "#000000", "live", status)
    if shadow:
        r(group, f"{label} shadow", "D", "None / Soft / Hard / Glow", "Soft", "hover", "new")
        r(group, f"{label} shadow size", "S", "0–16 px", "4", "live", "new")

def backdrop(group, label="Background", status="new", default_on="On", opacity="70"):
    r(group, f"{label}", "T", "", default_on, "live", status)
    r(group, f"{label} texture", "X", "Phoenix surfaces + LSM", "Solid", "hover", "new")
    r(group, f"{label} colour", "C", "colour + theme token", "#0B0C0F", "live", status)
    r(group, f"{label} opacity", "S", "0–100 %", opacity, "live", status)

def bar(group, label="Bar", status="new"):
    r(group, f"{label} texture", "X", "Phoenix bars + LSM, cards with samples", "Phoenix Satin", "hover", status)
    r(group, f"{label} fill direction", "D", "Left→Right / Right→Left / Bottom→Top / Top→Bottom", "Left→Right", "live", "new")
    r(group, f"{label} smooth fill", "T", "", "On", "live", "new")
    r(group, f"{label} gradient", "D", "None / Horizontal / Vertical", "None", "live", "new")

def visibility(group, status="new"):
    r(group, "Show in combat", "T", "", "On", "world", status)
    r(group, "Show out of combat", "T", "", "On", "world", status)
    r(group, "Fade out of combat", "T", "", "Off", "world", status)
    r(group, "Out-of-combat opacity", "S", "0–100 %", "40", "world", status)
    r(group, "Show on mouseover", "T", "", "Off", "world", status)
    r(group, "Hide in vehicles / pet battles", "T", "", "On", "none", status)
    r(group, "Custom state macro", "I", "[combat] show; hide …", "", "none", "new")

def position(group, status="new"):
    r(group, "Anchor", "D", "9 points + frame picker", "per element", "world", status)
    r(group, "X offset", "S", "-2000–2000", "per element", "world", status)
    r(group, "Y offset", "S", "-1200–1200", "per element", "world", status)
    r(group, "Frame strata", "D", "BACKGROUND … TOOLTIP", "MEDIUM", "none", status)
    r(group, "Scale", "S", "50–200 %", "100", "world", status)
