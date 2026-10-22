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

-- Surfaces & text are shared by every preset; presets change the accent family.
T.base = {
    ["bg.base"]       = c("0E0F13", 0.94),
    ["bg.raised"]     = c("16181E", 0.97),
    ["bg.sunken"]     = c("0A0B0E", 0.92),
    ["bg.hover"]      = c("1F222A", 1),
    ["bg.overlay"]    = c("000000", 0.55),
    ["border.subtle"] = c("262A33", 1),
    ["border.strong"] = c("3A3F4B", 1),
    ["border.black"]  = c("000000", 1),
    ["text.primary"]  = c("ECEEF2", 1),
    ["text.secondary"] = c("A3A9B6", 1),
    ["text.muted"]    = c("6B7180", 1),
    ["state.success"] = c("3DDC97", 1),
    ["state.warning"] = c("FFC24B", 1),
    ["state.danger"]  = c("FF4D5E", 1),
    ["state.info"]    = c("4DA3FF", 1),
}

T.presets = {
    { key = "ember",  label = "THEME_EMBER",  primary = "FF6A1A", secondary = "FFB23F", glow = "FF3D00" },
    { key = "frost",  label = "THEME_FROST",  primary = "2FA8FF", secondary = "7EE0FF", glow = "0077FF" },
    { key = "fel",    label = "THEME_FEL",    primary = "5BD43B", secondary = "C8FF5A", glow = "22B000" },
    { key = "arcane", label = "THEME_ARCANE", primary = "A35BFF", secondary = "FF7AE6", glow = "7A2BFF" },
    { key = "class",  label = "THEME_CLASS" },
    { key = "custom", label = "THEME_CUSTOM" },
}

T.fontRoles = {
    brand   = { font = "CinzelBold",        size = 20, flags = "" },
    title   = { font = "InterBold",         size = 17, flags = "" },
    heading = { font = "CondensedBold",     size = 11, flags = "" },
    body    = { font = "RobotoMedium",      size = 12, flags = "" },
    desc    = { font = "Roboto",            size = 11, flags = "" },
    number  = { font = "CondensedSemiBold", size = 12, flags = "" },
    small   = { font = "CondensedMedium",   size = 10, flags = "" },
    unit    = { font = "CondensedSemiBold", size = 12, flags = "" },
    combat  = { font = "CondensedBold",     size = 16, flags = "OUTLINE" },
}

local tokens = {}
T.tokens = tokens
T.settings = {
    preset = "ember", custom = { r = 1, g = 0.42, b = 0.1 }, fontScale = 1,
    uiFont = "", unitFont = "", barTexture = "Satin", reduceMotion = false,
    borderStyle = "solid", borderSize = 1, borderColor = false, shadowAlpha = 0.75, glowColor = false,
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

function T:Rebuild()
    for k, v in pairs(self.base) do tokens[k] = v end
    local p = self:PresetColors(self.settings.preset)
    local r, g, b = p.primary[1], p.primary[2], p.primary[3]
    tokens["accent.primary"] = { r, g, b, 1 }
    tokens["accent.secondary"] = { p.secondary[1], p.secondary[2], p.secondary[3], 1 }
    tokens["accent.glow"] = { p.glow[1], p.glow[2], p.glow[3], 0.35 }
    tokens["accent.soft"] = { r, g, b, 0.14 }
    local tr, tg, tb = lighten(r, g, b, 0.15)
    tokens["accent.text"] = { tr, tg, tb, 1 }
    -- Appearance & General overrides every module inherits: the colour of element borders that follow the theme
    -- ("border.black") and of every glow (ember borders, glow shadows).
    local s = self.settings
    local function rgb(col)
        if col.token == "class" then
            local _, classFile = UnitClass("player")
            return ns.Util.ClassColor(classFile)
        end
        return col.r or 1, col.g or 1, col.b or 1
    end
    local bc, gc = s.borderColor, s.glowColor
    if type(bc) == "table" then
        local br, bg, bb = rgb(bc)
        tokens["border.black"] = { br, bg, bb, bc.a or 1 }
    end
    if type(gc) == "table" then
        local gr, gg, gb = rgb(gc)
        tokens["accent.glow"] = { gr, gg, gb, 0.35 }
    end
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
    return ns.Media:Font(key, role == "brand"), size, r.flags
end

function T:Bar()
    return ns.Media:Bar(self.settings.barTexture)
end

function T:Apply(settings)
    if settings then self.settings = settings end
    self:Rebuild()
    ns.Events:Fire("PUI_THEME_CHANGED")
end

T:Rebuild()
