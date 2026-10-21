local ADDON, ns = ...

-- Single private namespace. Nothing in Phoenix_UI is global except the SavedVariables.
ns.ADDON = ADDON
local version = C_AddOns.GetAddOnMetadata(ADDON, "Version")
ns.version = (version and not version:find("^@")) and version or "2.0.0-dev" -- unpackaged checkout
ns.title = "Phoenix UI"

ns.C = {
    MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\",
    PREFIX = "|cffff6a1aPhoenix|r|cffffb23fUI|r",
    SCHEMA = 1,
    MESSAGE_PREFIX = "PUI_",
}
ns.C.TEXTURES = ns.C.MEDIA .. "Textures\\"
ns.C.FONTS = ns.C.MEDIA .. "Fonts\\"

ns.L = ns.L or {}
ns.modules, ns.moduleList, ns.options = {}, {}, {}

function ns:Print(fmt, ...)
    local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
    DEFAULT_CHAT_FRAME:AddMessage(ns.C.PREFIX .. "  " .. msg)
end

function ns:Debug(fmt, ...)
    if not ns.debug then return end
    ns:Print("|cff6b7180[debug]|r " .. fmt, ...)
end

-- Error reporting that never stops the caller: shows the standard Lua error frame (BugSack compatible).
function ns.ErrorHandler(err)
    return geterrorhandler()(err)
end

function ns.SafeCall(fn, ...)
    return xpcall(fn, ns.ErrorHandler, ...)
end
