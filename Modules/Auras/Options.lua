local _, ns = ...

ns:RegisterOptions("Auras", {
    { type = "header", label = "AURAS_STYLE" },
    { type = "toggle", key = "style", label = "AURAS_SKIN", desc = "AURAS_SKIN_DESC", reload = true, keywords = "buffs debuffs" },
    { type = "range", key = "durationSize", label = "AURAS_DURATION_SIZE", min = 8, max = 16, step = 1 },
    { type = "range", key = "countSize", label = "AURAS_COUNT_SIZE", min = 8, max = 18, step = 1 },
    { type = "description", text = "AURAS_NOTE" },
})
