local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Look (review gaps 2026-10-27): the global appearance pages and their shared
-- service, so every module reads one place.
--  * Fonts page: one font everywhere (optional), outline, shadow and sizes of
--    Phoenix's shared font objects, per-module fonts for the quest tracker and
--    the meter. Specimens show in the page preview.
--  * Colours page: class and power colour overrides, reaction colours and
--    colour-blind palettes (they swap the theme's red/green state tokens).
--    Class tokens can be secret: then the game's own colour is used as-is
--    (never compared, never used as a table key).
--  * Glows page: thickness, speed, accent colour for every glow and reduced
--    motion, applied inside PUI.Glow so every module's glows follow.
--  * Themes: Ember (default), Midnight, Horde and Alliance surface palettes.
--  * Icon shape masks, Phoenix class and role icon sets, Phoenix emoji art.
local Theme, Media, Schema, Secret = PUI.Theme, PUI.Media, PUI.Schema, PUI.Secret
local Look = { masked = setmetatable({}, { __mode = "k" }) }
PUI.Look = Look
local MEDIA = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\"
local s = { everywhere = "keep", outline = "none", shadow = true, headerSize = 15, bodySize = 12, smallSize = 10,
  quests = "global", meter = "global", classOverride = false, class = {}, power = {}, palette = "standard",
  reaction = {}, thickness = 2, speed = 1, accentGlow = false, reducedMotion = false, theme = "ember", gradient = "classic", gradientMid = 0.5,
  shape = "square", classIcons = "game", roleIcons = "game" }
Look.s = s

local function refresh()
  for _, name in ipairs({ "UnitFrames", "RaidFrames", "Nameplates", "QuestTracker", "Embers", "ActionBars", "CooldownManager" }) do
    local m = PUI[name]
    if m and m.active then
      local fn = m.RefreshAll or m.Refresh or m.RefreshWindows
      if fn then fn() end
    end
  end
  PUI.Kernel:Fire("LOOK_CHANGED")
end
Look.Refresh = refresh

-- Fonts -----------------------------------------------------------------------------------------------
Look.OUTLINES = { "none", "OUTLINE", "THICKOUTLINE" }
local font = Media.Font
function Media:Font(name)
  if s.everywhere ~= "keep" and self.fonts[s.everywhere] then return self.fonts[s.everywhere] end
  return font(self, name)
end
function Look.Flags() return s.outline ~= "none" and s.outline or "" end
function Media:ApplyRole(role, spec)
  local obj = self.objects[role]
  if not obj then return end
  local scale = self.fontScale or 1
  local size = (role == "header" and s.headerSize) or (role == "small" and s.smallSize) or (role == "body" and s.bodySize) or spec.size
  obj:SetFont(self:Font(PUI.Schema:Get(spec.key)), math.floor(size * scale + 0.5), Look.Flags())
  if s.shadow then obj:SetShadowOffset(1, -1); obj:SetShadowColor(0, 0, 0, 0.8) else obj:SetShadowOffset(0, 0) end
end
-- FontFor(which): path for a module font key ("quests", "meter"); "global" follows the interface font.
function Look.FontFor(which)
  local v = s[which]
  if v and v ~= "global" then return Media:Font(v) end
  return Media:Font(Schema:Get("media.uiFont"))
end

-- Colours ---------------------------------------------------------------------------------------------
Look.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
Look.POWERS = { "MANA", "RAGE", "FOCUS", "ENERGY", "RUNIC_POWER", "LUNAR_POWER", "MAELSTROM", "INSANITY", "FURY", "PAIN", "ESSENCE" }
Look.POWER_DEFAULTS = { MANA = { 0, 0.55, 1 }, RAGE = { 1, 0, 0 }, FOCUS = { 1, 0.5, 0.25 }, ENERGY = { 1, 1, 0 }, RUNIC_POWER = { 0, 0.82, 1 },
  LUNAR_POWER = { 0.3, 0.52, 0.9 }, MAELSTROM = { 0, 0.5, 1 }, INSANITY = { 0.4, 0, 0.8 }, FURY = { 0.79, 0.26, 0.99 }, PAIN = { 1, 0.61, 0 },
  ESSENCE = { 0.4, 0.8, 1 } }
Look.REACTIONS = { hostile = { 0.86, 0.2, 0.2 }, neutral = { 0.95, 0.8, 0.25 }, friendly = { 0.25, 0.8, 0.35 } }
-- Colour-blind palettes: state tokens and reactions (red/green pairs moved apart).
Look.PALETTES = {
  standard = {},
  deuteranopia = { tokens = { ok = "3A9BDC", success = "3A9BDC", life = "3A9BDC", err = "E69F00", danger = "E69F00", void = "E69F00" },
    reaction = { hostile = { 0.9, 0.62, 0 }, friendly = { 0.23, 0.6, 0.86 } } },
  protanopia = { tokens = { ok = "56B4E9", success = "56B4E9", life = "56B4E9", err = "F0E442", danger = "F0E442", void = "D55E00" },
    reaction = { hostile = { 0.94, 0.89, 0.26 }, friendly = { 0.34, 0.71, 0.91 } } },
  tritanopia = { tokens = { ok = "009E73", success = "009E73", life = "009E73", err = "CC79A7", danger = "CC79A7", info = "D55E00" },
    reaction = { hostile = { 0.8, 0.47, 0.65 }, friendly = { 0, 0.62, 0.45 } } },
  contrast = { tokens = { ok = "00FF7F", success = "00FF7F", life = "00FF7F", err = "FF2D2D", danger = "FF2D2D", warn = "FFE600", line = "6A6D78" },
    reaction = { hostile = { 1, 0.18, 0.18 }, neutral = { 1, 0.9, 0 }, friendly = { 0, 1, 0.5 } } },
}
Look.PALETTE_ORDER = { "standard", "deuteranopia", "protanopia", "tritanopia", "contrast" }
local BASE = {}
for k, v in pairs(Theme.TOKENS) do BASE[k] = v end
Look.BASE = BASE

-- ClassRGB(token): r, g, b or nil. Secret tokens go to the game unchanged.
function Look.ClassRGB(token)
  if token == nil then return nil end
  if not Secret.IsSecret(token) and s.classOverride then
    local c = s.class[token]
    if c then return c.r, c.g, c.b end
  end
  local color = C_ClassColor.GetClassColor(token)
  if color then return color:GetRGB() end
  return nil
end
function Look.PowerRGB(token)
  if token == nil or Secret.IsSecret(token) then return nil end
  local c = s.power[token]
  if c then return c.r, c.g, c.b end
  return nil
end
function Look.ReactionRGB(kind)
  local c = s.reaction[kind]
  if c then return c.r, c.g, c.b end
  local p = Look.PALETTES[s.palette] or {}
  local d = (p.reaction and p.reaction[kind]) or Look.REACTIONS[kind]
  return d[1], d[2], d[3]
end

-- Reaction colour on a bar: plain reactions use the Colours page, secret ones the game's colour.
function PUI.Bars.ReactionColor(bar, unit)
  local reaction = UnitReaction(unit, "player")
  if reaction ~= nil and not Secret.IsSecret(reaction) then
    local kind = reaction <= 3 and "hostile" or (reaction == 4 and "neutral" or "friendly")
    bar:SetStatusBarColor(Look.ReactionRGB(kind))
    return true
  end
  PUI.Bars.Color(bar, UnitSelectionColor(unit))
  return false
end

-- Themes: surface palettes (the accent stays the user's own choice) ---------------------------------
Look.THEMES = {
  ember = {},
  midnight = { bg0 = "05060A", bg1 = "090B11", bg2 = "0F121A", bg3 = "151924", line = "202432", ["surface.0"] = "07080D", ["surface.1"] = "090B11", ["surface.2"] = "151924" },
  horde = { bg0 = "0F0707", bg1 = "170B0B", bg2 = "1F1010", bg3 = "2A1414", line = "3A1C1C", ["surface.0"] = "130909", ["surface.1"] = "170B0B", ["surface.2"] = "2A1414", acc2 = "E04848" },
  alliance = { bg0 = "070A12", bg1 = "0B101B", bg2 = "101826", bg3 = "162034", line = "1E2C46", ["surface.0"] = "090D17", ["surface.1"] = "0B101B", ["surface.2"] = "162034", acc2 = "F4C46A" },
}
Look.THEME_ORDER = { "ember", "midnight", "horde", "alliance" }
Theme.TOKENS.horde = "C8243D"
Theme.TOKENS.alliance = "2F6FD6"
Theme.ACCENTS[#Theme.ACCENTS + 1] = "horde"
Theme.ACCENTS[#Theme.ACCENTS + 1] = "alliance"
Theme.ACCENT_LABELS.horde, Theme.ACCENT_LABELS.alliance = "Horde red", "Alliance blue"

function Look.ApplyTokens()
  local T = Theme.TOKENS
  for k, v in pairs(BASE) do T[k] = v end
  for k, v in pairs(Look.THEMES[s.theme] or {}) do T[k] = v end
  local p = Look.PALETTES[s.palette]
  for k, v in pairs(p and p.tokens or {}) do T[k] = v end
  Theme:Repaint()
end

-- Glows: global look applied in PUI.Glow ---------------------------------------------------------------
local Glow = PUI.Glow
local start = Glow.Start
function Glow:Start(target, style, color, speedScale)
  if s.reducedMotion and (style == "pulse" or style == "flash") then style = "solid" end
  if s.accentGlow and style ~= "none" then local r, g, b = Theme:Color("accent"); color = { r = r, g = g, b = b, a = 1 } end
  local g = start(self, target, style, color, (speedScale or 1) * s.speed)
  if g and g.edges then
    local t = s.thickness
    g.edges[1]:SetHeight(t); g.edges[2]:SetHeight(t); g.edges[3]:SetWidth(t); g.edges[4]:SetWidth(t)
    g.args = { style, color, speedScale }
  end
  return g
end
function Look.RestyleGlows()
  for target, g in pairs(Glow.active) do
    if g.style and g.args then Glow:Start(target, g.args[1], g.args[2], g.args[3]) end
  end
end

-- Icon shapes ---------------------------------------------------------------------------------------
Look.SHAPES = { "square", "rounded", "squircle", "circle", "hexagon", "octagon", "diamond", "shield" }
function Look.MaskPath(shape) return shape ~= "square" and (MEDIA .. "Textures\\Masks\\" .. shape) or nil end
-- Shape(tex, frame): masks an icon texture with the chosen shape (live).
function Look.Shape(tex, frame)
  local rec = Look.masked[tex]
  if not rec then rec = { frame = frame or tex:GetParent() }; Look.masked[tex] = rec end
  local path = Look.MaskPath(s.shape)
  if not path then
    if rec.mask and rec.on then tex:RemoveMaskTexture(rec.mask); rec.on = false end
    return false
  end
  if not rec.mask then
    rec.mask = rec.frame:CreateMaskTexture()
    rec.mask:SetAllPoints(tex)
  end
  rec.mask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  if not rec.on then tex:AddMaskTexture(rec.mask); rec.on = true end
  return true
end
function Look.Reshape() for tex, rec in pairs(Look.masked) do Look.Shape(tex, rec.frame) end end

-- Class and role icon sets, emoji ---------------------------------------------------------------------
function Look.ClassIcon(classFile)
  if s.classIcons ~= "phoenix" or type(classFile) ~= "string" or Secret.IsSecret(classFile) then return nil end
  return MEDIA .. "Icons\\Classes\\" .. classFile:lower()
end
function Look.RoleIcon(role)
  if s.roleIcons ~= "phoenix" or type(role) ~= "string" or Secret.IsSecret(role) then return nil end
  if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then return nil end
  return MEDIA .. "Icons\\Roles\\" .. role:lower()
end
Look.EMOJI = { "smile", "grin", "laugh", "wink", "sad", "cry", "angry", "cool", "wow", "think", "sleep", "gg", "heart", "fire", "thumbsup", "dead" }
function Look.EmojiPath(name) return MEDIA .. "Icons\\Emoji\\" .. (name == "dead" and "skull" or name) end

-- Settings ------------------------------------------------------------------------------------------
local function fonts(keep)
  local out = { keep }
  for _, n in ipairs(Media.fontOrder or {}) do out[#out + 1] = n end
  return out
end
local function key(k, owner, field, def, after)
  def.owner = owner
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[field] = v; if after then after(v) end end
  Schema:Register(k, def)
end
local applyFonts = function() Media:ApplyFonts(); refresh() end
key("fonts.everywhere", "Fonts", "everywhere", { type = "select", default = "keep", choices = function() return fonts("keep") end, preview = "font", mode = "simple",
  choiceLabels = { keep = "Each module's own font" }, label = "One font everywhere", tooltip = "Use one font in every Phoenix module, or keep each module's own font choice." }, applyFonts)
key("fonts.outline", "Fonts", "outline", { type = "select", default = "none", choices = Look.OUTLINES, mode = "simple",
  choiceLabels = { none = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick outline" }, label = "Window text outline", tooltip = "Outline on Phoenix window and label text." }, applyFonts)
key("fonts.shadow", "Fonts", "shadow", { type = "toggle", default = true, label = "Text shadow", tooltip = "A soft shadow under Phoenix window text." }, applyFonts)
key("fonts.headerSize", "Fonts", "headerSize", { type = "range", default = 15, min = 10, max = 24, step = 1, label = "Heading size", tooltip = "Size of window headings." }, applyFonts)
key("fonts.bodySize", "Fonts", "bodySize", { type = "range", default = 12, min = 8, max = 20, step = 1, label = "Body text size", tooltip = "Size of normal window text." }, applyFonts)
key("fonts.smallSize", "Fonts", "smallSize", { type = "range", default = 10, min = 7, max = 16, step = 1, label = "Small text size", tooltip = "Size of small labels and hints." }, applyFonts)
key("fonts.quests", "Fonts", "quests", { type = "select", default = "global", choices = function() return fonts("global") end, preview = "font",
  choiceLabels = { global = "Interface font" }, label = "Quest tracker font", tooltip = "Font of the quest tracker." }, applyFonts)
key("fonts.meter", "Fonts", "meter", { type = "select", default = "global", choices = function() return fonts("global") end, preview = "font",
  choiceLabels = { global = "Interface font" }, label = "Meter font", tooltip = "Font of the Embers meter windows." }, applyFonts)

key("colors.palette", "Colors", "palette", { type = "select", default = "standard", choices = Look.PALETTE_ORDER, mode = "simple",
  choiceLabels = { standard = "Standard", deuteranopia = "Deuteranopia (red-green)", protanopia = "Protanopia (red-weak)", tritanopia = "Tritanopia (blue-yellow)", contrast = "High contrast" },
  label = "Colour-blind palette", tooltip = "Swaps the red and green state colours (good/bad, friendly/hostile) for pairs you can tell apart." }, function() Look.ApplyTokens(); if PUI.Bars then PUI.Bars.healthCurve = nil end; refresh() end)
local function curve() if PUI.Bars then PUI.Bars.healthCurve = nil end; refresh() end
key("colors.healthGradient", "Colors", "gradient", { type = "select", default = "classic", choices = { "classic", "theme" }, mode = "simple",
  choiceLabels = { classic = "Red, yellow, green", theme = "Theme bad, warning, good (follows the palette)" },
  label = "Health-by-percent colours", tooltip = "Colours of health bars set to colour by health. The theme option follows the colour-blind palette." }, curve)
key("colors.gradientMid", "Colors", "gradientMid", { type = "range", default = 0.5, min = 0.2, max = 0.8, step = 0.05,
  label = "Health colour middle point", tooltip = "At which health share the middle (yellow or warning) colour sits." }, curve)
key("colors.classOverride", "Colors", "classOverride", { type = "toggle", default = false, mode = "simple", label = "Use my class colours",
  tooltip = "Phoenix bars and names use the class colours below instead of the game's." }, refresh)
local function rgb(t) return { r = t[1], g = t[2], b = t[3], a = 1 } end
local CLASS_DEFAULT = { WARRIOR = "C69B6D", PALADIN = "F48CBA", HUNTER = "AAD372", ROGUE = "FFF468", PRIEST = "FFFFFF", DEATHKNIGHT = "C41E3A",
  SHAMAN = "0070DD", MAGE = "3FC7EB", WARLOCK = "8788EE", MONK = "00FF98", DRUID = "FF7C0A", DEMONHUNTER = "A330C9", EVOKER = "33937F" }
local function hexrgb(h) return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 } end
local NAMES = { DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter" }
for _, c in ipairs(Look.CLASSES) do
  local label = NAMES[c] or (c:sub(1, 1) .. c:sub(2):lower())
  Schema:Register("colors.class." .. c, { type = "color", default = rgb(hexrgb(CLASS_DEFAULT[c])), owner = "Colors", mode = "advanced",
    label = label .. " colour", tooltip = "Class colour used when 'Use my class colours' is on.",
    apply = function(v) s.class[c] = v; refresh() end })
end
for _, p in ipairs(Look.POWERS) do
  local label = p:sub(1, 1) .. p:sub(2):lower():gsub("_(%a)", function(a) return " " .. a end)
  Schema:Register("colors.power." .. p, { type = "color", default = rgb(Look.POWER_DEFAULTS[p]), owner = "Colors", mode = "advanced",
    label = label .. " bar colour", tooltip = "Colour of this power type on Phoenix power bars.",
    apply = function(v) s.power[p] = v; refresh() end })
end
for _, r in ipairs({ "hostile", "neutral", "friendly" }) do
  Schema:Register("colors.reaction." .. r, { type = "color", default = rgb(Look.REACTIONS[r]), owner = "Colors", mode = "advanced",
    label = (r:sub(1, 1):upper() .. r:sub(2)) .. " colour", tooltip = "Reaction colour of non-player unit frames (nameplates keep their own colours; the colour-blind palette changes these defaults).",
    apply = function(v)
      local d = Look.REACTIONS[r]
      s.reaction[r] = (math.abs(v.r - d[1]) + math.abs(v.g - d[2]) + math.abs(v.b - d[3]) > 0.01) and v or nil
      refresh()
    end })
end

key("glows.thickness", "Glows", "thickness", { type = "range", default = 2, min = 1, max = 5, step = 1, mode = "simple", label = "Glow thickness",
  tooltip = "Line thickness of every Phoenix glow (procs, cooldowns, dispels, arena trinkets)." }, Look.RestyleGlows)
key("glows.speed", "Glows", "speed", { type = "range", default = 1, min = 0.5, max = 2, step = 0.1, label = "Glow speed", tooltip = "How fast pulsing and flashing glows animate." }, Look.RestyleGlows)
key("glows.accent", "Glows", "accentGlow", { type = "toggle", default = false, mode = "simple", label = "Glows follow the theme colour",
  tooltip = "One colour for every glow: the theme's accent. Off keeps each glow's own colour." }, Look.RestyleGlows)
key("glows.reducedMotion", "Glows", "reducedMotion", { type = "toggle", default = false, label = "Reduced motion",
  tooltip = "Glows stay solid instead of pulsing or flashing." }, Look.RestyleGlows)

key("theme.preset", "Theme", "theme", { type = "select", default = "ember", choices = Look.THEME_ORDER, mode = "simple",
  choiceLabels = { ember = "Ember (default)", midnight = "Midnight (darker)", horde = "Horde", alliance = "Alliance" },
  label = "Theme", tooltip = "Colour of window surfaces and lines. Pair it with an accent (Horde red and Alliance blue are in the accent list)." }, Look.ApplyTokens)
key("theme.iconShape", "Theme", "shape", { type = "select", default = "square", choices = Look.SHAPES,
  label = "Icon shape", tooltip = "Shape of action-button and cooldown icons: square, rounded, circle, hexagon and more (Phoenix masks)." }, Look.Reshape)
key("theme.classIcons", "Theme", "classIcons", { type = "select", default = "game", choices = { "game", "phoenix" },
  choiceLabels = { game = "Game icons", phoenix = "Phoenix icons" }, label = "Class icons", tooltip = "Class icons in friends and group lists: the game's or Phoenix's own set." }, refresh)
key("theme.roleIcons", "Theme", "roleIcons", { type = "select", default = "game", choices = { "game", "phoenix" },
  choiceLabels = { game = "Game icons", phoenix = "Phoenix icons" }, label = "Role icons", tooltip = "Tank, healer and damage icons on raid frames: the game's or Phoenix's own set." }, refresh)

-- Borders (review gap: Textures page parity) ------------------------------------------------------------
-- Every Phoenix outline (Theme:Outline) follows one border style and size:
-- "pixel" (the 1 px edges), "soft" (the soft nine-slice border art) or "none".
Look.outlines = setmetatable({}, { __mode = "k" })
s.borderStyle, s.borderSize = "pixel", 1
local outline = Theme.Outline
function Theme:Outline(frame, token, alpha)
  local edges = outline(self, frame, token, alpha)
  Look.outlines[edges] = frame
  Look.StyleOutline(edges, frame)
  return edges
end
function Look.StyleOutline(edges, frame)
  local size = s.borderSize
  edges[1]:SetHeight(size); edges[2]:SetHeight(size); edges[3]:SetWidth(size); edges[4]:SetWidth(size)
  local pixel = s.borderStyle == "pixel" and size > 0
  for i = 1, 4 do edges[i]:SetAlpha(pixel and 1 or 0) end
  local soft = rawget(edges, "soft")
  if s.borderStyle == "soft" then
    if not soft then soft = Theme:Slice(frame, MEDIA .. "Textures\\NineSlice\\Border_Soft", 16, "BORDER"); rawset(edges, "soft", soft) end
    soft:SetVertexColor(edges[1]:GetVertexColor())
    soft:Show()
  elseif soft then soft:Hide() end
end
function Look.RestyleOutlines()
  local n = 0
  for edges, frame in pairs(Look.outlines) do Look.StyleOutline(edges, frame); n = n + 1 end
  return n
end
key("theme.borderStyle", "Theme", "borderStyle", { type = "select", default = "pixel", choices = { "pixel", "soft", "none" }, mode = "simple",
  choiceLabels = { pixel = "Pixel line", soft = "Soft edge", none = "No border" },
  label = "Border style", tooltip = "The border around every Phoenix window, frame and icon outline." }, function() Look.RestyleOutlines() end)
key("theme.borderSize", "Theme", "borderSize", { type = "range", default = 1, min = 0, max = 4, step = 1,
  label = "Border thickness", tooltip = "Thickness of pixel-line borders (0 hides them)." }, function() Look.RestyleOutlines() end)
