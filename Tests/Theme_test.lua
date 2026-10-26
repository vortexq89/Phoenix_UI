local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Theme, Media, Schema = PUI.Tests, PUI.Theme, PUI.Media, PUI.Schema

-- Puts settings back exactly as the player had them.
local function keep(t, ...)
  local keys, saved = { ... }, {}
  for i = 1, #keys do saved[keys[i]] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for k, v in pairs(saved) do if not PUI.DB.DeepEqual(Schema:Get(k), v) then Schema:Set(k, v) end end
  end)
end
Tests.Keep = keep

-- A texture-like probe that records the last colour it was given.
local function probe()
  local p = {}
  function p:SetColorTexture(r, g, b, a) self.c = { r, g, b, a } end
  function p:SetVertexColor(r, g, b, a) self.c = { r, g, b, a } end
  function p:SetTextColor(r, g, b, a) self.c = { r, g, b, a } end
  return p
end
Tests.ColorProbe = probe

Tests:Add("Theme", "tokens resolve and unknown tokens raise", function(t)
  local r, g, b = Theme:Color("ember")
  t:eq(math.floor(r * 255 + 0.5), 255, "ember red")
  t:eq(math.floor(g * 255 + 0.5), 125, "ember green")
  t:eq(math.floor(b * 255 + 0.5), 10, "ember blue")
  t:throws(function() Theme:Color("nope") end, "unknown token")
  local _, _, _, a = Theme:Color("accent.soft")
  t:eq(a, 0.2, "accent.soft alpha")
end)

Tests:Add("Theme", "accent change repaints painted objects live", function(t)
  keep(t, "theme.accent", "theme.panelAlpha")
  local p, panel = probe(), probe()
  Theme:Paint(p, "accent")
  Theme:Paint(panel, "surface.0", nil, "panel")
  t:cleanup(function() Theme.painted[p] = nil; Theme.painted[panel] = nil end)
  Schema:Set("theme.accent", "spark")
  local r, g, b = Theme:Color("spark")
  t:eq(p.c[1], r, "red follows spark"); t:eq(p.c[2], g, "green follows spark"); t:eq(p.c[3], b, "blue follows spark")
  Schema:Set("theme.accent", "class")
  local c = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
  t:eq(p.c[1], c.r, "class colour mode")
  Schema:Set("theme.panelAlpha", 0.7)
  t:eq(panel.c[4], 0.7, "panel opacity applied live")
end)

Tests:Add("Theme", "fonts are shared objects re-fonted live", function(t)
  keep(t, "media.uiFont", "media.fontScale")
  local obj = Media:FontObject("body")
  t:eq(Media:FontObject("body"), obj, "one object per role")
  Schema:Set("media.uiFont", "Arial Narrow")
  Schema:Set("media.fontScale", 1.5)
  local path, size = obj:GetFont()
  t:eq(path, Media:Font("Arial Narrow"), "font path applied")
  t:eq(size, 18, "size scaled")
  t:eq(Media:Font("missing"), Media:Font("Friz Quadrata"), "unknown font falls back to the default face")
  t:ok(not Schema:Validate(Schema:Def("media.uiFont"), "missing"), "only registered fonts are valid")
end)
