local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Bars: the shared StatusBar factory and colour helpers for Unit Frames and
-- Resource Bars (PUI_V2 5.3, 5.8). Values that may be secret (health, power,
-- durations) are only ever handed to widget methods here; no Lua arithmetic,
-- comparison or concatenation touches them.
local Bars = { all = setmetatable({}, { __mode = "k" }) }
PUI.Bars = Bars

local Media, Theme, Secret = PUI.Media, PUI.Theme, PUI.Secret

-- Interpolation for SetValue/SetMinMaxValues (12.0.0 Enum.StatusBarInterpolation).
function Bars.Interp(smooth)
  local E = Enum.StatusBarInterpolation
  if not E then return nil end
  return smooth and E.ExponentialEaseOut or E.Immediate
end

-- A StatusBar with a background, painted fill and the current bar texture.
function Bars:Create(parent, owner, layer)
  local bar = PUI:CreateFrame("StatusBar", nil, parent, nil, owner)
  bar:SetStatusBarTexture(Bars:TexturePath())
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  local bg = bar:CreateTexture(nil, layer or "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(Bars:TexturePath())
  bar.bg = bg
  self:SetBackground(bar)
  self.all[bar] = true
  return bar
end

function Bars:SetBackground(bar)
  local r, g, b = Theme:Color("surface.0")
  bar.bg:SetVertexColor(r, g, b, self.backgroundAlpha)
end

-- Fill direction and orientation (non-secret layout values).
function Bars:SetFill(bar, reverse, vertical)
  bar:SetReverseFill(reverse == true)
  bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
end

-- Sets min/max and value straight from engine values (possibly secret).
function Bars:SetValues(bar, maxValue, value, smooth)
  local interp = Bars.Interp(smooth)
  bar:SetMinMaxValues(0, maxValue, interp)
  bar:SetValue(value, interp)
end

-- Colour from r, g, b that may be secret: the widget receives them unchanged.
function Bars.Color(bar, r, g, b, a)
  bar:SetStatusBarColor(r, g, b, a)
end

-- Token colour (Theme) for chrome-coloured bars.
function Bars.TokenColor(bar, token, alpha)
  local r, g, b = Theme:Color(token)
  bar:SetStatusBarColor(r, g, b, alpha or 1)
end

-- Health gradient curve 0 -> red, 0.5 -> yellow, 1 -> green, built once.
function Bars:HealthCurve()
  if self.healthCurve then return self.healthCurve end
  local curve = C_CurveUtil.CreateColorCurve()
  curve:SetType(Enum.LuaCurveType.Linear)
  curve:AddPoint(0, CreateColor(1, 0.1, 0.1, 1))
  curve:AddPoint(0.5, CreateColor(1, 0.85, 0.1, 1))
  curve:AddPoint(1, CreateColor(0.1, 0.9, 0.2, 1))
  self.healthCurve = curve
  return curve
end

-- Class colour for a unit. The class token may be secret; GetClassColor accepts
-- it and the colour components go straight to the widget.
function Bars.ClassColor(bar, unit)
  local _, token = UnitClass(unit)
  if token == nil then return false end
  local color = C_ClassColor.GetClassColor(token)
  if color == nil then return false end
  bar:SetStatusBarColor(color:GetRGB())
  return true
end

-- Power colour from the unit's power token; secret tokens use the accent.
function Bars.PowerColor(bar, unit)
  local _, token = UnitPowerType(unit)
  if token == nil or Secret.IsSecret(token) then return Bars.TokenColor(bar, "accent") end
  local c = PowerBarColor and PowerBarColor[token]
  if c then bar:SetStatusBarColor(c.r, c.g, c.b) else Bars.TokenColor(bar, "accent") end
end

function Bars:TexturePath() return Media:Path("statusbar", self.texture) or Media:Texture(self.texture) end

function Bars:Retexture()
  local path = Bars:TexturePath()
  for bar in pairs(self.all) do
    bar:SetStatusBarTexture(path)
    bar.bg:SetTexture(path)
    self:SetBackground(bar)
  end
  PUI.Kernel:Fire("BARS_CHANGED")
end

Bars.texture = "flat"
Bars.backgroundAlpha = 0.6

Media:RegisterTexture("smooth", "Interface\\TargetingFrame\\UI-StatusBar")
Media:Register("statusbar", "smooth", "Interface\\TargetingFrame\\UI-StatusBar")
Bars.TEXTURES = function() return Media:List("statusbar") end

PUI.Schema:Register("bars.texture", {
  type = "select", default = "flat", choices = Bars.TEXTURES, preview = "statusbar",
  label = "Bar texture", tooltip = "Texture for every Phoenix health, power, cast and resource bar.",
  mode = "simple", owner = "Theme", searchTags = { "texture", "bars" },
  apply = function(value)
    Bars.texture = value
    Bars:Retexture()
  end,
})

PUI.Schema:Register("bars.backgroundAlpha", {
  type = "range", default = 0.6, min = 0, max = 1, step = 0.05,
  label = "Bar background opacity", tooltip = "Opacity of the dark background behind Phoenix bars.",
  mode = "advanced", owner = "Theme", searchTags = { "alpha", "bars" },
  apply = function(value)
    Bars.backgroundAlpha = value
    Bars:Retexture()
  end,
})
