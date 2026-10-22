local _, ns = ...

--[[ ns.Style — saved shapes for per-element styling, and ns.Opt — the matching option rows.
    A module declares defaults with ns.Style.* and its options with ns.Opt.*; ns.Skin:TextSpec / Place /
    BorderSpec / Backdrop / IconZoom apply them to real frames and to the option previews alike.
    Colours default to false: "use the theme token", so the theme stays in charge until a user picks one. ]]
local Style, Opt = {}, {}
ns.Style, ns.Opt = Style, Opt

local function with(base, extra)
    if extra then for k, v in pairs(extra) do base[k] = v end end
    return base
end

function Style.Text(size, extra)
    return with({ font = "", size = size or 12, outline = "NONE", shadow = true, color = false,
        anchor = "CENTER", x = 0, y = 0, show = true }, extra)
end

-- style "theme" follows Appearance & General (theme.borderStyle / borderSize), so one change there restyles every
-- module that kept the default; shadow "auto" lets the style decide (only "shadow" draws one).
function Style.Border(extra) return with({ style = "theme", size = 1, color = false, shadow = "auto", shadowSize = 0 }, extra) end
function Style.Background(extra) return with({ alpha = 0.6, color = false, style = "solid" }, extra) end
function Style.Icons(size, extra) return with({ size = size or 32, spacing = 4, zoom = 0.08, growth = "RIGHT" }, extra) end

---------------------------------------------------------------- option rows
Opt.OUTLINE = {
    { value = "NONE", label = "OUTLINE_NONE" }, { value = "OUTLINE", label = "OUTLINE_THIN" },
    { value = "THICK", label = "OUTLINE_THICK" }, { value = "MONO", label = "OUTLINE_MONO" },
}
Opt.ANCHOR = {
    { value = "LEFT", label = "ANCHOR_LEFT" }, { value = "CENTER", label = "ANCHOR_CENTER" },
    { value = "RIGHT", label = "ANCHOR_RIGHT" }, { value = "TOPLEFT", label = "ANCHOR_TOPLEFT" },
    { value = "TOP", label = "ANCHOR_TOP" }, { value = "TOPRIGHT", label = "ANCHOR_TOPRIGHT" },
    { value = "BOTTOMLEFT", label = "ANCHOR_BOTTOMLEFT" }, { value = "BOTTOM", label = "ANCHOR_BOTTOM" },
    { value = "BOTTOMRIGHT", label = "ANCHOR_BOTTOMRIGHT" },
}
-- The style library (ns.Skin:BorderSpec). Order is the picker's: follow Appearance first, then plain to loud.
Opt.BORDER = {
    { value = "theme", label = "BORDER_THEME" }, { value = "none", label = "BORDER_NONE" },
    { value = "pixel", label = "BORDER_PIXEL" }, { value = "solid", label = "BORDER_SOLID" },
    { value = "thick", label = "BORDER_THICK" }, { value = "inset", label = "BORDER_INSET" },
    { value = "shadow", label = "BORDER_SHADOW" }, { value = "glow", label = "BORDER_GLOW" },
    { value = "ember", label = "BORDER_EMBER" },
}
-- Appearance's own list: everything but "follow Appearance".
Opt.BORDER_GLOBAL = {}
for i = 2, #Opt.BORDER do Opt.BORDER_GLOBAL[#Opt.BORDER_GLOBAL + 1] = Opt.BORDER[i] end
Opt.SHADOW = {
    { value = "auto", label = "SHADOW_AUTO" }, { value = "none", label = "SHADOW_NONE" },
    { value = "soft", label = "SHADOW_SOFT" }, { value = "hard", label = "SHADOW_HARD" },
    { value = "glow", label = "SHADOW_GLOW" },
}
Opt.BACKDROP = {
    { value = "solid", label = "BACKDROP_SOLID" }, { value = "gradient", label = "BACKDROP_GRADIENT" },
    { value = "glass", label = "BACKDROP_GLASS" },
}
Opt.GROWTH = {
    { value = "RIGHT", label = "GROW_RIGHT" }, { value = "LEFT", label = "GROW_LEFT" },
    { value = "UP", label = "GROW_UP" }, { value = "DOWN", label = "GROW_DOWN" },
}
-- Fill gradient over a status bar's fill (Skin:FillGradient): none, darker toward the end, darker toward the bottom.
Opt.GRADIENT = {
    { value = "none", label = "GRADIENT_NONE" }, { value = "HORIZONTAL", label = "GRADIENT_HORIZONTAL" },
    { value = "VERTICAL", label = "GRADIENT_VERTICAL" },
}
Opt.STRATA = {
    { value = "BACKGROUND", label = "STRATA_BACKGROUND" }, { value = "LOW", label = "STRATA_LOW" },
    { value = "MEDIUM", label = "STRATA_MEDIUM" }, { value = "HIGH", label = "STRATA_HIGH" },
    { value = "DIALOG", label = "STRATA_DIALOG" },
}

local function extend(row, extra) return with(row, extra) end

--[[ One row per text element: the font picker, with a cog for size, outline, shadow, colour and (when the
    element is ours to place) its slot and offsets. opts: { min, max, place = bool, token, show = bool } ]]
function Opt.Text(path, label, opts)
    opts = opts or {}
    local cog = {
        { type = "range", key = path .. ".size", label = "FONT_SIZE", min = opts.min or 6, max = opts.max or 32, step = 1 },
        { type = "select", key = path .. ".outline", label = "FONT_OUTLINE", values = Opt.OUTLINE },
        { type = "toggle", key = path .. ".shadow", label = "FONT_SHADOW" },
        { type = "color", key = path .. ".color", label = "TEXT_COLOR", token = opts.token or "text.primary", reset = true },
    }
    if opts.place then
        cog[#cog + 1] = { type = "select", key = path .. ".anchor", label = "TEXT_POSITION", values = Opt.ANCHOR }
        cog[#cog + 1] = { type = "range", key = path .. ".x", label = "OFFSET_X", min = -50, max = 50, step = 1 }
        cog[#cog + 1] = { type = "range", key = path .. ".y", label = "OFFSET_Y", min = -30, max = 30, step = 1 }
    end
    if opts.show then table.insert(cog, 1, { type = "toggle", key = path .. ".show", label = "SHOW" }) end
    return extend({ type = "font", key = path .. ".font", label = label, allowDefault = true, cog = cog,
        keywords = "font text size outline shadow" }, opts.row)
end

-- A border row: the visual style picker, with size, colour (Class / Theme tokens) and shadow behind its cog.
function Opt.Border(path, label, token)
    return { type = "style", kind = "border", key = path .. ".style", label = label or "BORDER", values = Opt.BORDER,
        keywords = "border edge glow outline shadow pixel inset ember",
        cog = {
            { type = "range", key = path .. ".size", label = "BORDER_SIZE", min = 1, max = 6, step = 1 },
            { type = "color", key = path .. ".color", label = "BORDER_COLOR", token = token or "border.black", alpha = true,
              reset = true, classToken = true },
            { type = "style", kind = "shadow", key = path .. ".shadow", label = "SHADOW", values = Opt.SHADOW },
            -- 0 = sized from the border (the default look)
            { type = "range", key = path .. ".shadowSize", label = "SHADOW_SIZE", min = 0, max = 16, step = 1 },
        } }
end

function Opt.Background(path, label, token)
    return { type = "range", key = path .. ".alpha", label = label or "BACKGROUND_OPACITY", min = 0, max = 1, step = 0.05,
        percent = true, keywords = "background backdrop opacity alpha gradient glass",
        cog = {
            { type = "color", key = path .. ".color", label = "BACKGROUND_COLOR", token = token or "bg.sunken", reset = true,
              classToken = true },
            { type = "style", kind = "backdrop", key = path .. ".style", label = "BACKDROP_STYLE", values = Opt.BACKDROP },
        } }
end

function Opt.Icons(path, opts)
    opts = opts or {}
    local rows = {
        { type = "range", key = path .. ".size", label = "ICON_SIZE", min = opts.min or 16, max = opts.max or 64, step = 1 },
        { type = "range", key = path .. ".spacing", label = "ICON_SPACING", min = 0, max = 16, step = 1 },
        { type = "range", key = path .. ".zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 },
    }
    if opts.growth ~= false then
        rows[#rows + 1] = { type = "select", key = path .. ".growth", label = "ICON_GROWTH", values = Opt.GROWTH }
    end
    return rows
end

-- Rows for a cog popover (which cannot nest cogs): each row followed by its own cog rows.
function Opt.Flat(...)
    local out = {}
    for i = 1, select("#", ...) do
        local row = select(i, ...)
        local copy = {}
        for k, v in pairs(row) do if k ~= "cog" then copy[k] = v end end
        out[#out + 1] = copy
        for _, sub in ipairs(row.cog or {}) do out[#out + 1] = sub end
    end
    return out
end

-- Adds fields (disabled, hidden, desc …) to a row built by the helpers above.
function Opt.With(row, extra) return with(row, extra) end
