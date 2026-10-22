local _, ns = ...
local Opt = ns.Opt

local function unstyled(m) return not m.db.style end

ns:RegisterOptions("CastBars", {
    { type = "scope", key = "bars", label = "CB_BAR", values = {
        { value = "player", label = "UF_PLAYER" }, { value = "target", label = "UF_TARGET" },
        { value = "focus", label = "UF_FOCUS" },
    } },
    { type = "preview", kind = "castbar" },
    { type = "header", label = "CB_STYLE", icon = "castbars" },
    { type = "toggle", gate = true, key = "style", label = "CB_SKIN", desc = "CB_SKIN_DESC", reload = true },
    { type = "texture", key = "bars.@.texture", label = "BAR_TEXTURE", allowDefault = true, disabled = unstyled },
    Opt.Border("bars.@.border"),
    Opt.Background("bars.@.background"),
    { type = "header", label = "CB_COLORS", icon = "palette" },
    { type = "colors", keys = { "bars.@.colors.cast", "bars.@.colors.channel", "bars.@.colors.locked" },
      tokens = { "accent.primary", "state.info", "text.muted" }, label = "CB_FILL_COLORS", desc = "CB_FILL_COLORS_DESC",
      labels = { "CB_COLOR_CAST", "CB_COLOR_CHANNEL", "CB_COLOR_LOCKED" }, disabled = unstyled,
      keywords = "colour cast channel interrupt" },
    { type = "toggle", key = "classColor", label = "CB_CLASSCOLOR", desc = "CB_CLASSCOLOR_DESC", disabled = unstyled },
    { type = "header", label = "CB_TEXT", icon = "fonts" },
    Opt.Text("bars.@.text", "CB_SPELL_FONT", { row = { disabled = unstyled } }),
    Opt.Text("bars.@.time", "CB_TIME_FONT", { row = { disabled = unstyled } }),
    { type = "header", label = "CB_PLAYER", icon = "user" },
    { type = "toggle", key = "icon", label = "CB_ICON", desc = "CB_ICON_DESC",
      cog = { { type = "range", key = "iconZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } },
    { type = "toggle", key = "timer", label = "CB_TIMER", desc = "CB_TIMER_DESC", keywords = "cast time remaining" },
    { type = "toggle", key = "latency", label = "CB_LATENCY", desc = "CB_LATENCY_DESC", keywords = "lag safe zone" },
})
