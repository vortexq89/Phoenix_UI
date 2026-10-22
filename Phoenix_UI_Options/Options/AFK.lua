local _, ns = ...

ns:RegisterOptions("AFK", {
    { type = "preview", kind = "afk" },
    { type = "header", label = "AFK_SCREEN" },
    { type = "toggle", key = "spin", label = "AFK_SPIN", desc = "AFK_SPIN_DESC" },
    { type = "button", label = "AFK_PREVIEW", desc = "AFK_PREVIEW_DESC", button = "PREVIEW", icon = "preview",
      disabled = function(m) return not m:IsEnabled() end,
      func = function(m)
          ns.Config.frame:Hide()
          m:Show()
          C_Timer.After(6, function() if not UnitIsAFK("player") then m:Hide() end end)
      end },
})
