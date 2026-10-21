local _, ns = ...

ns:RegisterOptions("MythicPlus", {
    { type = "header", label = "MPLUS_TIMER", icon = "clock" },
    { type = "toggle", key = "timer", label = "MPLUS_TIMER_SHOW", desc = "MPLUS_TIMER_SHOW_DESC",
      keywords = "timer chest upgrade clock overlay" },
    { type = "toggle", key = "timerForces", label = "MPLUS_TIMER_FORCES", desc = "MPLUS_TIMER_FORCES_DESC",
      keywords = "enemy forces count percent trash", disabled = function(m) return not m.db.timer end },
    { type = "toggle", key = "timerBosses", label = "MPLUS_TIMER_BOSSES", desc = "MPLUS_TIMER_BOSSES_DESC",
      keywords = "splits boss kill time", disabled = function(m) return not m.db.timer end },
    { type = "toggle", key = "timerDeaths", label = "MPLUS_TIMER_DEATHS", desc = "MPLUS_TIMER_DEATHS_DESC",
      keywords = "death penalty", disabled = function(m) return not m.db.timer end },
    { type = "toggle", key = "timerBest", label = "MPLUS_TIMER_BEST", desc = "MPLUS_TIMER_BEST_DESC",
      keywords = "personal best record", disabled = function(m) return not m.db.timer end },
    { type = "button", label = "MPLUS_TIMER_PLACE", desc = "MPLUS_TIMER_PLACE_DESC", button = "OPEN_EDIT_MODE",
      icon = "editmode", combat = true, func = function() ns.EditMode:Open() end },
    { type = "header", label = "MPLUS_KEYSTONE", icon = "mythicplus" },
    { type = "toggle", key = "autoInsert", label = "MPLUS_AUTO_INSERT", desc = "MPLUS_AUTO_INSERT_DESC",
      keywords = "keystone font of power" },
    { type = "toggle", key = "reportKey", label = "MPLUS_REPORT", desc = "MPLUS_REPORT_DESC" },
})
