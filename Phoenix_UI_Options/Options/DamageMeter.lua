local _, ns = ...
local L = ns.L

local dmGet, dmSet = ns.Combat.CVarAccessors("damageMeterEnabled")

ns:RegisterOptions("DamageMeter", {
    { type = "preview", kind = "damagemeter" },
    { type = "header", label = "BLIZZARD_FEATURES", icon = "general" },
    { type = "toggle", label = "DM_ENABLE", desc = "DM_ENABLE_DESC", get = dmGet, set = dmSet, combat = true, keywords = "dps meter" },
    { type = "header", label = "DM_STYLE", icon = "theme" },
    { type = "toggle", key = "skin", label = "DM_SKIN", desc = "DM_SKIN_DESC", reload = true },
    { type = "header", label = "DM_DETAILS", icon = "damagemeter" },
    { type = "description", text = "DM_DETAILS_TEXT" },
    { type = "button", label = "DM_DETAILS_APPLY", desc = "DM_DETAILS_APPLY_DESC", button = "APPLY", variant = "primary",
      disabled = function(m) return not m:DetailsLoaded() end,
      func = function(m)
          local ok, count = m:ApplyDetails()
          ns.Config:SetStatus(ok and L.DM_DETAILS_DONE:format(count) or L.DM_DETAILS_MISSING, ok and "state.success" or "state.danger")
      end },
})
