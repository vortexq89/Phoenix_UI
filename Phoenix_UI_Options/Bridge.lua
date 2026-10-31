local _, private = ...
--[[ Phoenix_UI_Options shares Phoenix_UI's private namespace. Phoenix_UI sets PhoenixUI_Bridge only for the
    duration of its own C_AddOns.LoadAddOn call (UI/Launcher.lua), so every file here reads and writes the
    main addon's ns through this proxy and nothing stays global. Open the window with /pui; loading this
    addon any other way is not supported. ]]
local ns = PhoenixUI_Bridge
assert(type(ns) == "table", "Phoenix_UI_Options is loaded by Phoenix UI itself: type /pui")
setmetatable(private, { __index = ns, __newindex = ns })
