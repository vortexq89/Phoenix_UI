local _, ns = ...

--[[ ns.Theme — design tokens for the "Phoenix Ember" design language (docs/ARCHITECTURE.md §11).
    Modules never hard-code colours, fonts or spacing: they ask the theme. ]]
local T = {}
ns.Theme = T
local hex = ns.Util.HexToRGB

local function c(h, a)
    local r, g, b = hex(h)
    return { r, g, b, a or 1 }
end

-- ONE theme (t213 #5, t215; Phoenix colours from 7 Nov 2026): Phoenix's own palette. Neutral graphite surfaces, white
-- borders and text at fixed alphas (they adapt to any surface), one accent: Phoenix ember by default. The build quality
-- (sizes, alphas, spacing) stays at the EllesmereUI bar; the colours are Phoenix's (plan section 18).
local function w(a) return { 1, 1, 1, a } end
T.base = {
    ["bg.base"]       = c("0E0E10", 1),              -- panel background
    ["bg.raised"]     = c("161618", 1),              -- buttons, cards
    ["bg.sunken"]     = c("08080A", 1),              -- inputs, wells
    ["bg.hover"]      = c("1E1E22", 1),              -- dropdowns, hovered rows
    ["bg.control"]    = c("232328", 1),              -- checkbox boxes, one step above hover
    ["bg.overlay"]    = { 0, 0, 0, 0.6 },
    ["border.subtle"] = w(0.05),                     -- the global 1 px border
    ["border.strong"] = w(0.20),                     -- dropdown / emphasised border
    ["border.black"]  = { 0, 0, 0, 1 },              -- game-frame element borders
    ["text.primary"]  = w(1),
    ["text.secondary"] = w(0.53),                    -- dim text
    ["text.muted"]    = w(0.41),                     -- section headers, hints
    ["state.success"] = c("3DDC97", 1),
    ["state.warning"] = c("FFC24B", 1),
    ["state.danger"]  = c("FF4D5E", 1),
    ["state.info"]    = c("4DA3FF", 1),
}

-- The accent: Phoenix ember (default), the class colour, or one colour you pick.
T.presets = {
    { key = "phoenix", label = "THEME_PHOENIX", primary = "FF7D0A", secondary = "FFB547", glow = "FF5500" },
    { key = "class",   label = "THEME_CLASS" },
    { key = "custom",  label = "THEME_CUSTOM" },
}

-- No role below 12: smaller sizes turn into blurry, blocky glyphs once the UI scale goes under 0.7.
-- ONE family for all Phoenix text (DESIGN_SYSTEM_V3 §3, §3a, §3b): Phoenix Font (OFL, a tuned Barlow Semi Condensed),
-- drawn with Expressway instead when another installed addon provides it (Media:ResolveExternal). Russian clients use
-- PT Sans Narrow. Weights carry the hierarchy: title 21 Bold > heading 14 Bold > body 15 > desc 13. Only the brand
-- wordmark is Cinzel.
T.fontRoles = {
    brand   = { font = "CinzelBold",          size = 20, flags = "" },
    title   = { font = "PhoenixFontBold",     size = 21, flags = "" },
    heading = { font = "PhoenixFontBold",     size = 14, flags = "" },
    body    = { font = "PhoenixFont",         size = 15, flags = "" },
    desc    = { font = "PhoenixFont",         size = 13, flags = "" },
    number  = { font = "PhoenixFontSemiBold", size = 14, flags = "" },
    small   = { font = "PhoenixFont",         size = 13, flags = "" },
    unit    = { font = "PhoenixFontSemiBold", size = 13, flags = "OUTLINE" },
    combat  = { font = "PhoenixFontBold",     size = 18, flags = "OUTLINE" },
}

local tokens = {}
T.tokens = tokens
T.settings = {
    preset = "phoenix", custom = { r = 1, g = 0.490, b = 0.039 }, fontScale = 1,
    uiFont = "", unitFont = "", expressway = true, barTexture = "Satin", reduceMotion = false, emblemFX = true, windowArt = true,
    borderStyle = "solid", borderSize = 1, borderColor = false, shadowAlpha = 0.75, glowColor = false,
    surfaceAlpha = 1, outline = "NONE", soundChannel = "Master", classColors = {},
    powerColors = {}, dispelColors = {},
}

local function lighten(r, g, b, f) return r + (1 - r) * f, g + (1 - g) * f, b + (1 - b) * f end

-- Accent family for a preset key: { primary = {r,g,b}, secondary = {...}, glow = {...} }.
function T:PresetColors(key)
    local preset
    for _, p in ipairs(self.presets) do if p.key == key then preset = p end end
    preset = preset or self.presets[1]
    if preset.primary then
        return { primary = { hex(preset.primary) }, secondary = { hex(preset.secondary) }, glow = { hex(preset.glow) } }
    end
    local r, g, b
    if preset.key == "class" then
        local _, classFile = UnitClass("player")
        r, g, b = ns.Util.ClassColor(classFile)
    else
        local cu = self.settings.custom
        r, g, b = cu.r, cu.g, cu.b
    end
    return { primary = { r, g, b }, secondary = { lighten(r, g, b, 0.45) }, glow = { r * 0.8, g * 0.8, b * 0.8 } }
end

-- Classes for the class colour overrides (General); "class.<FILE>" tokens hold the game's own colour.
T.CLASSES = { "WARRIOR", "DEATHKNIGHT", "PALADIN", "MONK", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK",
    "HUNTER", "DEMONHUNTER", "EVOKER" }

-- Power types and dispel types for General's colour overrides; "power.<TOKEN>" / "dispel.<Type>" tokens hold the
-- game's own colour (PowerBarColor / DEBUFF_TYPE_*_COLOR, read only).
T.POWERS = { "MANA", "RAGE", "FOCUS", "ENERGY", "RUNIC_POWER", "LUNAR_POWER", "MAELSTROM", "INSANITY", "FURY", "PAIN",
    "COMBO_POINTS", "HOLY_POWER", "CHI", "SOUL_SHARDS", "ARCANE_CHARGES", "ESSENCE" }
T.DISPELS = { "Magic", "Curse", "Disease", "Poison", "Bleed" }

function T:Rebuild()
    for k, v in pairs(self.base) do tokens[k] = v end
    local pbc = rawget(_G, "PowerBarColor")
    for _, p in ipairs(T.POWERS) do
        local col = type(pbc) == "table" and pbc[p]
        tokens["power." .. p] = (type(col) == "table" and col.r) and { col.r, col.g, col.b, 1 } or { 1, 1, 1, 1 }
    end
    for _, d in ipairs(T.DISPELS) do
        local col = rawget(_G, "DEBUFF_TYPE_" .. d:upper() .. "_COLOR")
        tokens["dispel." .. d] = (type(col) == "table" and col.r) and { col.r, col.g, col.b, 1 } or { 0.8, 0.8, 0.8, 1 }
    end
    for _, cf in ipairs(T.CLASSES) do
        local cc = C_ClassColor and C_ClassColor.GetClassColor(cf)
        tokens["class." .. cf] = cc and { cc.r, cc.g, cc.b, 1 } or { 1, 1, 1, 1 }
    end
    local p = self:PresetColors(self.settings.preset)
    local r, g, b = p.primary[1], p.primary[2], p.primary[3]
    tokens["accent.primary"] = { r, g, b, 1 }
    tokens["accent.secondary"] = { p.secondary[1], p.secondary[2], p.secondary[3], 1 }
    tokens["accent.glow"] = { p.glow[1], p.glow[2], p.glow[3], 0.35 }
    tokens["accent.soft"] = { r, g, b, 0.10 }
    local tr, tg, tb = lighten(r, g, b, 0.15)
    tokens["accent.text"] = { tr, tg, tb, 1 }
end

function T:Color(token)
    local v = tokens[token] or tokens["text.primary"]
    return v[1], v[2], v[3], v[4]
end

function T:ColorObj(token)
    return CreateColor(self:Color(token))
end

function T:HexOf(token)
    local r, g, b = self:Color(token)
    return ns.Util.Hex(r, g, b)
end

function T:Wrap(text, token)
    return "|cff" .. self:HexOf(token) .. text .. "|r"
end

-- Returns path, size, flags for a role; sizeOverride lets in-world elements set their own size.
function T:Font(role, sizeOverride)
    local r = self.fontRoles[role] or self.fontRoles.body
    local s = self.settings
    local key = r.font
    if (role == "unit" or role == "combat") and s.unitFont ~= "" then key = s.unitFont end
    if (role == "body" or role == "desc") and s.uiFont ~= "" then key = s.uiFont end
    local size = sizeOverride or math.floor(r.size * (role ~= "unit" and role ~= "combat" and s.fontScale or 1) + 0.5)
    -- the global outline (Appearance & General) applies to every role drawn without one of its own
    local flags = r.flags
    if flags == "" and s.outline and s.outline ~= "NONE" then flags = ns.Skin and ns.Skin.OUTLINES[s.outline] or "" end
    return ns.Media:Font(key, role == "brand"), size, flags
end

function T:Bar()
    -- the phoenix-wings look: the greyscale v8.1 fill whenever the bar texture is the theme's default
    local art = ns.Art and ns.Art.BarFill and (self.settings.barTexture or "Satin") == "Satin" and ns.Art.BarFill()
    return art or ns.Media:Bar(self.settings.barTexture)
end

function T:Apply(settings)
    if settings then self.settings = settings end
    self:Rebuild()
    ns.Events:Fire("PUI_THEME_CHANGED")
end

T:Rebuild()
