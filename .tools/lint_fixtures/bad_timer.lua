-- must fail: a C_Timer ticker outside the Ticker registry
local t = C_Timer.NewTicker(1, function() end)
