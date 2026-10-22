local ADDON, ns = ...

-- Single private namespace. Nothing in Phoenix_UI is global except the SavedVariables.
ns.ADDON = ADDON
-- The TOC carries a real version in source (2.0.0-beta1) and the packager swaps in the tag; a placeholder
-- that slipped through any other way never reaches the screen.
local version = C_AddOns.GetAddOnMetadata(ADDON, "Version")
ns.version = (type(version) == "string" and version ~= "" and not version:find("@", 1, true)) and version or "2.0.0-dev"
ns.title = "Phoenix UI"

ns.C = {
    MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\",
    PREFIX = "|cffff6a1aPhoenix|r|cffffb23fUI|r",
    SCHEMA = 4,   -- the last ns.Migrations step; export strings carry it
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
