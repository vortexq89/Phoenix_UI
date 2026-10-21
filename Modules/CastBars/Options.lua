local _, ns = ...

ns:RegisterOptions("CastBars", {
    { type = "header", label = "CB_STYLE" },
    { type = "toggle", key = "style", label = "CB_SKIN", desc = "CB_SKIN_DESC", reload = true },
    { type = "toggle", key = "classColor", label = "CB_CLASSCOLOR", desc = "CB_CLASSCOLOR_DESC",
      disabled = function(m) return not m.db.style end },
    { type = "header", label = "CB_PLAYER" },
    { type = "toggle", key = "icon", label = "CB_ICON", desc = "CB_ICON_DESC" },
    { type = "toggle", key = "timer", label = "CB_TIMER", desc = "CB_TIMER_DESC", keywords = "cast time remaining" },
    { type = "toggle", key = "latency", label = "CB_LATENCY", desc = "CB_LATENCY_DESC", keywords = "lag safe zone" },
})
