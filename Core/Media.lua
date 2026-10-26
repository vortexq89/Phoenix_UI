local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Media: named fonts and textures for Phoenix chrome. Until the licensed font
-- and texture packs ship (PUI_V2 5.2, 14), every entry points at a file the
-- game client already has, so nothing here can reference a missing path.
-- Fonts are applied through shared Font objects, so changing media.* settings
-- re-fonts every Phoenix string live.
local Media = { fonts = {}, fontOrder = {}, textures = {}, objects = {} }
PUI.Media = Media

function Media:RegisterFont(name, path)
  if not self.fonts[name] then self.fontOrder[#self.fontOrder + 1] = name end
  self.fonts[name] = path
end

function Media:RegisterTexture(name, path) self.textures[name] = path end

Media:RegisterFont("Friz Quadrata", "Fonts\\FRIZQT__.TTF")
Media:RegisterFont("Arial Narrow", "Fonts\\ARIALN.TTF")
Media:RegisterFont("Morpheus", "Fonts\\MORPHEUS.TTF")
Media:RegisterFont("Skurri", "Fonts\\SKURRI.TTF")
Media:RegisterTexture("flat", "Interface\\Buttons\\WHITE8X8")

function Media:Font(name) return self.fonts[name] or self.fonts["Friz Quadrata"] end
function Media:Texture(name) return self.textures[name] or self.textures.flat end

-- Shared font objects. Role -> { setting key, size, flags }.
local ROLES = {
  body = { key = "media.uiFont", size = 12 },
  small = { key = "media.uiFont", size = 10 },
  header = { key = "media.uiFont", size = 15 },
  number = { key = "media.numberFont", size = 12 },
}
Media.ROLES = ROLES

function Media:FontObject(role)
  local obj = self.objects[role]
  if obj then return obj end
  local spec = ROLES[role] or ROLES.body
  obj = CreateFont("PhoenixUIFont_" .. role)
  self.objects[role] = obj
  self:ApplyRole(role, spec)
  return obj
end

function Media:ApplyRole(role, spec)
  local obj = self.objects[role]
  if not obj then return end
  local scale = self.fontScale or 1
  obj:SetFont(self:Font(PUI.Schema:Get(spec.key)), math.floor(spec.size * scale + 0.5), "")
end

function Media:ApplyFonts()
  for role, spec in pairs(ROLES) do self:ApplyRole(role, spec) end
  PUI.Kernel:Fire("MEDIA_CHANGED")
end

local function fontChoices() return Media.fontOrder end

PUI.Schema:Register("media.uiFont", {
  type = "select", default = "Friz Quadrata", choices = fontChoices,
  label = "Interface font", tooltip = "Font for Phoenix UI windows and labels.",
  mode = "simple", owner = "Theme", searchTags = { "font", "text" },
  apply = function() Media:ApplyFonts() end,
})

PUI.Schema:Register("media.numberFont", {
  type = "select", default = "Arial Narrow", choices = fontChoices,
  label = "Number font", tooltip = "Font for numbers and timers in Phoenix UI windows.",
  mode = "advanced", owner = "Theme", searchTags = { "font", "numbers" },
  apply = function() Media:ApplyFonts() end,
})

PUI.Schema:Register("media.fontScale", {
  type = "range", default = 1, min = 0.8, max = 1.5, step = 0.05,
  label = "Text size", tooltip = "Scales every Phoenix UI font.",
  mode = "simple", owner = "Theme", searchTags = { "font", "size", "scale" },
  apply = function(value)
    Media.fontScale = value
    Media:ApplyFonts()
  end,
})
