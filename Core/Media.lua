local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Media: named fonts and textures for Phoenix chrome. Until the licensed font
-- and texture packs ship (PUI_V2 5.2, 14), every entry points at a file the
-- game client already has, so nothing here can reference a missing path.
-- Fonts are applied through shared Font objects, so changing media.* settings
-- re-fonts every Phoenix string live.
-- The optional Phoenix_UI_Media child adds the licensed library (fonts with
-- Arabic/CJK/Cyrillic coverage, bar textures, backgrounds, borders, glows,
-- icons, sounds) through Media:Register; see Phoenix_UI_Media/LICENSES.md.
local Media = { fonts = {}, fontOrder = {}, textures = {}, objects = {}, kinds = {}, meta = {} }
PUI.Media = Media

-- LibSharedMedia type for each Phoenix kind (nil: Phoenix-only).
Media.LSM_TYPE = { font = "font", statusbar = "statusbar", background = "background", border = "border", sound = "sound" }

local function kindTable(kind)
  local k = Media.kinds[kind]
  if not k then k = { paths = {}, order = {} }; Media.kinds[kind] = k end
  return k
end

-- kind: font|statusbar|background|border|glow|icon|sound. meta: optional
-- { coverage = "Arabic, Latin", licence = "..." } shown in pickers.
function Media:Register(kind, name, path, meta)
  local k = kindTable(kind)
  if not k.paths[name] then k.order[#k.order + 1] = name end
  k.paths[name] = path
  if meta then self.meta[kind .. ":" .. name] = meta end
  if kind == "font" then
    if not self.fonts[name] then self.fontOrder[#self.fontOrder + 1] = name end
    self.fonts[name] = path
  elseif kind ~= "sound" then
    self.textures[name] = self.textures[name] or path
  end
  if self.ShareOne then self:ShareOne(kind, name, path) end
end

function Media:RegisterFont(name, path, meta) self:Register("font", name, path, meta) end
function Media:RegisterTexture(name, path) self.textures[name] = path end
function Media:List(kind) return kindTable(kind).order end
function Media:Path(kind, name) return kindTable(kind).paths[name] end
function Media:Meta(kind, name) return self.meta[kind .. ":" .. name] end
function Media:Count(kind) return #kindTable(kind).order end

-- Sounds: "None" is always first and plays nothing.
Media:Register("sound", "None", "")
function Media:PlaySound(name)
  local path = name and self:Path("sound", name)
  -- PlaySoundFile is not in the generated API docs for 12.1.5 or Forever, so it
  -- is looked up at call time; without it the module's own sound plays instead.
  local play = rawget(_G, "PlaySoundFile")
  if not path or path == "" or not play then return false end
  play(path, "Master")
  return true
end

-- Alert sound used by modules that beep (Reminders, Group Finder, quests):
-- the module's own Blizzard sound unless the player picked one here.
function Media:Alert(soundKit)
  if self:PlaySound(self.alertSound) then return end
  if soundKit then PlaySound(soundKit) end
end

-- LibSharedMedia bridge: only when another addon has loaded the library.
local function lsm()
  local stub = rawget(_G, "LibStub")
  return stub and stub("LibSharedMedia-3.0", true)
end

function Media:ShareOne(kind, name, path)
  if self.shareEnabled == false then return end
  local L, t = lsm(), self.LSM_TYPE[kind]
  if not (L and t and path ~= "") then return end
  L:Register(t, "Phoenix: " .. name, path, kind == "font" and (L.LOCALE_BIT_western or 0) + (L.LOCALE_BIT_ruRU or 0) or nil)
end

-- LibSharedMedia may load after Phoenix: share once it appears, then stop listening.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(self)
  if Media.shareEnabled ~= false and Media:ShareAll() then self:UnregisterEvent("ADDON_LOADED") end
end)

function Media:ShareAll()
  if not lsm() then return false end
  for kind, k in pairs(self.kinds) do
    for i = 1, #k.order do self:ShareOne(kind, k.order[i], k.paths[k.order[i]]) end
  end
  self.shared = true
  return true
end

Media:RegisterFont("Friz Quadrata", "Fonts\\FRIZQT__.TTF")
Media:RegisterFont("Arial Narrow", "Fonts\\ARIALN.TTF")
Media:RegisterFont("Morpheus", "Fonts\\MORPHEUS.TTF")
Media:RegisterFont("Skurri", "Fonts\\SKURRI.TTF")
Media:RegisterTexture("flat", "Interface\\Buttons\\WHITE8X8")
Media:Register("statusbar", "flat", "Interface\\Buttons\\WHITE8X8")

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
local function soundChoices() return Media:List("sound") end

PUI.Schema:Register("media.uiFont", {
  type = "select", default = "Friz Quadrata", choices = fontChoices, preview = "font",
  label = "Interface font", tooltip = "Font for Phoenix UI windows and labels.",
  mode = "simple", owner = "Theme", searchTags = { "font", "text" },
  apply = function() Media:ApplyFonts() end,
})

PUI.Schema:Register("media.numberFont", {
  type = "select", default = "Arial Narrow", choices = fontChoices, preview = "font",
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

PUI.Schema:Register("media.alertSound", {
  type = "select", default = "None", choices = soundChoices, preview = "sound",
  label = "Alert sound", tooltip = "Sound for Phoenix alerts (reminders, group finder, quest complete). None keeps each module's own sound.",
  mode = "advanced", owner = "Theme", searchTags = { "sound", "alert", "audio" },
  apply = function(value) Media.alertSound = value end,
})

PUI.Schema:Register("media.shareLSM", {
  type = "toggle", default = true,
  label = "Share with other addons", tooltip = "Lists Phoenix fonts, textures and sounds in other addons' pickers (LibSharedMedia), when one of them loads it.",
  mode = "advanced", owner = "Theme", searchTags = { "sharedmedia", "lsm", "media" },
  apply = function(value)
    Media.shareEnabled = value
    if value then Media:ShareAll() end
  end,
})
