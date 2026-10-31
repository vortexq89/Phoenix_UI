local _, ns = ...
local Opt = ns.Opt

ns:RegisterOptions("AFK", {
    { type = "preview", kind = "afk" },
    { type = "header", label = "AFK_SCREEN", icon = "afk" },
    { type = "toggle", key = "notInInstances", label = "AFK_NOT_INSTANCES", desc = "AFK_NOT_INSTANCES_DESC",
      keywords = "dungeon raid instance" },
    { type = "range", key = "dim", label = "AFK_DIM", desc = "AFK_DIM_DESC", min = 0, max = 0.9, step = 0.05, percent = true },
    { type = "toggle", key = "showModel", label = "AFK_MODEL", desc = "AFK_MODEL_DESC", keywords = "character model" },
    { type = "toggle", key = "spin", label = "AFK_SPIN", desc = "AFK_SPIN_DESC", disabled = function(m) return not m.db.showModel end },
    { type = "header", label = "AFK_INFO", icon = "user" },
    { type = "toggle", key = "showGuild", label = "AFK_GUILD", desc = "AFK_GUILD_DESC" },
    { type = "toggle", key = "stats", label = "AFK_STATS", desc = "AFK_STATS_DESC", keywords = "item level rating vault" },
    { type = "toggle", key = "showHint", label = "AFK_SHOW_HINT", desc = "AFK_SHOW_HINT_DESC" },
    Opt.Text("timer", "AFK_TIMER_FONT", { min = 14, max = 48 }),
    { type = "button", label = "AFK_PREVIEW", desc = "AFK_PREVIEW_DESC", button = "PREVIEW", icon = "preview",
      disabled = function(m) return not m:IsEnabled() end,
      func = function(m)
          ns.Config.frame:Hide()
          m:Show()
          C_Timer.After(6, function() if not UnitIsAFK("player") then m:Hide() end end)
      end },
})
