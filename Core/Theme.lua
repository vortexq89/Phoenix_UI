local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Theme: the "Ember" design tokens (PUI_V2 5.2, 18.1) and the live accent.
-- Phoenix chrome never hard-codes colours: it asks Theme:Color(token) and
-- registers accent-coloured textures/font strings with Theme:Paint, which
-- repaints them in place the moment theme.* settings change (no /reload).
local Theme = { painted = setmetatable({}, { __mode = "k" }) }
PUI.Theme = Theme

local function hex(s)
  return tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255
end

-- Brand tokens (5.2) and semantic roles (18.1).
local TOKENS = {
  flame = "FF5500", ember = "FF7D0A", spark = "FFD700", ash = "121212", smoke = "1E1E1E", void = "FF0044", life = "20FF20",
  ["surface.0"] = "0E0E10", ["surface.1"] = "161618", ["surface.2"] = "1E1E22", line = "2A2A2F",
  ["text.primary"] = "F2F2F2", ["text.secondary"] = "A0A0A8", danger = "FF0044", success = "20FF20",
}
Theme.TOKENS = TOKENS
Theme.ACCENTS = { "ember", "flame", "spark", "void", "life", "class" }

local accent = { hex(TOKENS.ember) }
Theme.accent = accent

-- r, g, b for a token name; "accent" and "accent.soft" follow the setting.
function Theme:Color(token)
  if token == "accent" then return accent[1], accent[2], accent[3], 1 end
  if token == "accent.soft" then return accent[1], accent[2], accent[3], 0.2 end
  local v = TOKENS[token]
  if not v then error("unknown theme token '" .. tostring(token) .. "'", 2) end
  local r, g, b = hex(v)
  return r, g, b, 1
end

local function classColor()
  local _, class = UnitClass("player")
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return hex(TOKENS.ember)
end

function Theme:ResolveAccent(name)
  if name == "class" then return classColor() end
  return hex(TOKENS[name] or TOKENS.ember)
end

-- Panel opacity multiplier for surface backgrounds (theme.panelAlpha).
Theme.panelAlpha = 0.95

local function paintOne(obj, spec)
  local r, g, b, a = Theme:Color(spec.token)
  a = (spec.alpha or 1) * a
  if spec.how == "panel" then obj:SetColorTexture(r, g, b, Theme.panelAlpha)
  elseif spec.how == "text" then obj:SetTextColor(r, g, b, a)
  elseif spec.how == "vertex" then obj:SetVertexColor(r, g, b, a)
  else obj:SetColorTexture(r, g, b, a) end
end

-- Paints obj with a token now and again whenever the theme changes.
-- how: "texture" (SetColorTexture, default), "vertex", "text" or "panel"
-- (a surface whose opacity follows theme.panelAlpha).
function Theme:Paint(obj, token, alpha, how)
  local spec = { token = token, alpha = alpha, how = how }
  self.painted[obj] = spec
  paintOne(obj, spec)
  return obj
end

function Theme:Repaint()
  for obj, spec in pairs(self.painted) do paintOne(obj, spec) end
  PUI.Kernel:Fire("THEME_CHANGED")
end

PUI.Schema:Register("theme.accent", {
  type = "select", default = "ember", choices = Theme.ACCENTS,
  label = "Accent colour", tooltip = "The single highlight colour of Phoenix UI. Class uses your class colour.",
  mode = "simple", owner = "Theme", searchTags = { "colour", "color", "class" },
  apply = function(value)
    accent[1], accent[2], accent[3] = Theme:ResolveAccent(value)
    Theme:Repaint()
  end,
})

PUI.Schema:Register("theme.panelAlpha", {
  type = "range", default = 0.95, min = 0.5, max = 1, step = 0.05,
  label = "Panel opacity", tooltip = "Background opacity of Phoenix UI windows.",
  mode = "advanced", owner = "Theme", searchTags = { "alpha", "transparency" },
  apply = function(value)
    Theme.panelAlpha = value
    Theme:Repaint()
  end,
})

-- Surface helper: a full-size background texture painted with a surface token.
function Theme:Backdrop(frame, token)
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  return self:Paint(bg, token or "surface.0", nil, "panel")
end

-- 1 px outline in a token colour around frame (four textures).
function Theme:Outline(frame, token, alpha)
  local edges = {}
  local function edge(p1, p2, w, h)
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetPoint(p1)
    t:SetPoint(p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
    self:Paint(t, token or "line", alpha)
    edges[#edges + 1] = t
  end
  edge("TOPLEFT", "TOPRIGHT", nil, 1)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
  edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
  return edges
end
