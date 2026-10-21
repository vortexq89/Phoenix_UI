local _, ns = ...

ns:RegisterOptions("MythicPlus", {
    { type = "header", label = "MPLUS_KEYSTONE" },
    { type = "toggle", key = "autoInsert", label = "MPLUS_AUTO_INSERT", desc = "MPLUS_AUTO_INSERT_DESC",
      keywords = "keystone font of power" },
    { type = "toggle", key = "reportKey", label = "MPLUS_REPORT", desc = "MPLUS_REPORT_DESC" },
})
