local _, private = ...
--[[ A Phoenix UI plugin: shares Phoenix_UI's private namespace. Phoenix_UI sets PhoenixUI_Bridge only while
    its plugin loader (Core/Plugins.lua) calls C_AddOns.LoadAddOn, so nothing stays global. Turn the plugin on
    in Phoenix > Plugins; loading this folder any other way is not supported. ]]
local ns = PhoenixUI_Bridge
assert(type(ns) == "table", "Phoenix UI plugins are loaded by Phoenix UI itself: /pui > Plugins")
setmetatable(private, { __index = ns, __newindex = ns })
