local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Looks for unit frames (mockup 01): Ember (portrait, flat bars, thick power),
-- Glass (rounded, thin power, class-icon portrait), Blizzard-like and
-- Classic-like. A look is only a set of starting values: every attribute below
-- is also its own setting whose "look" choice means "follow the selected
-- look", so any part can be changed on its own (D-MOD-DEF). One table feeds
-- both the real frames and the options preview, so they never disagree.
local _, ns = ...

local Styles = { order = { "ember", "glass", "blizzard", "classic" } }
ns.Styles = Styles

Styles.LABELS = { ember = "Ember", glass = "Glass", blizzard = "Blizzard-like", classic = "Classic-like" }
Styles.DESCRIPTIONS = {
  ember = "Portrait, flat bars and a thick power bar with a warm edge.",
  glass = "Rounded, translucent body, thin power bar and a class-icon portrait.",
  blizzard = "Close to the default frames: round 3D portrait, gold edge.",
  classic = "Dark frame, square 2D portrait and a gradient health colour.",
}

-- border: none | thin | thick | glow; borderColor: black | class | accent | gold
-- background: solid | translucent | clear; power: attached | inset | floating
-- portrait: off | 2d | 3d | class; shape: square | circle
Styles.LOOKS = {
  ember = { border = "thick", borderColor = "black", background = "solid", power = "attached", portrait = "3d",
    shape = "square", powerRatio = 0.22, gap = 1, edge = true, nameRole = "body" },
  glass = { border = "thin", borderColor = "accent", background = "translucent", power = "inset", portrait = "class",
    shape = "square", powerRatio = 0.12, gap = 2, edge = false, nameRole = "body" },
  blizzard = { border = "thick", borderColor = "gold", background = "solid", power = "attached", portrait = "3d",
    shape = "circle", powerRatio = 0.25, gap = 1, edge = false, nameRole = "body" },
  classic = { border = "thin", borderColor = "black", background = "solid", power = "attached", portrait = "2d",
    shape = "square", powerRatio = 0.25, gap = 1, edge = false, nameRole = "body", colorMode = "gradient" },
}

Styles.BORDERS = { "look", "none", "thin", "thick", "glow" }
Styles.BORDER_COLORS = { "look", "black", "class", "accent", "gold" }
Styles.BACKGROUNDS = { "look", "solid", "translucent", "clear" }
Styles.POWER = { "look", "attached", "inset", "floating" }
Styles.PORTRAITS = { "look", "off", "2d", "3d", "class" }
Styles.SHAPES = { "look", "square", "circle" }

Styles.BORDER_PX = { none = 0, thin = 1, thick = 2, glow = 1 }
Styles.BG_ALPHA = { solid = 0.85, translucent = 0.45, clear = 0 }
Styles.GOLD = { r = 0.85, g = 0.68, b = 0.3 }

-- Resolve(look, overrides) -> plain table of effective values. overrides holds
-- the per-attribute settings; "look" (or nil) falls through to the look.
function Styles.Resolve(look, o)
  local base = Styles.LOOKS[look] or Styles.LOOKS.ember
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  for k, v in pairs(o or {}) do
    if v ~= nil and v ~= "look" then out[k] = v end
  end
  out.borderPx = Styles.BORDER_PX[out.border] or 1
  out.bgAlpha = Styles.BG_ALPHA[out.background] or 0.85
  return out
end
