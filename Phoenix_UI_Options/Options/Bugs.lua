local _, ns = ...
local L = ns.L
local W = ns.Widgets
local Errors = ns.Errors

local popupGet, popupSet = ns.Combat.CVarAccessors("scriptErrors")
local WEBSITE = "https://vq8s.com/phoenix-ui"

local function openViewer(m) ns.Config.frame:Hide(); m:OpenViewer() end
local MODE_TEXT = { buggrabber = L.BUGS_MODE_BUGGRABBER, handler = L.BUGS_MODE_HANDLER, lost = L.BUGS_MODE_LOST }

-- Where captures come from right now, and what is in the sack.
local function captureStatus()
    local m = ns.modules.Bugs
    local unique, total = m:Counts()
    return MODE_TEXT[m:CaptureState()] .. "\n" .. L.BUGS_STATUS_COUNTS:format(unique, total, #Errors:GetReports())
end

ns:RegisterOptions("Bugs", {
    { type = "preview", kind = "bugs" },
    { type = "header", label = "BUGS_CAPTURE", icon = "bugs" },
    { type = "description", text = captureStatus },
    { type = "select", key = "scope", label = "BUGS_SCOPE", desc = "BUGS_SCOPE_DESC", keywords = "filter addons own only", values = {
        { value = "all", label = "BUGS_SCOPE_ALL", icon = "addon" },
        { value = "phoenix", label = "BUGS_SCOPE_PHOENIX", icon = "home" },
    } },
    { type = "toggle", key = "warnings", label = "BUGS_WARNINGS", desc = "BUGS_WARNINGS_DESC", keywords = "lua warning" },
    { type = "toggle", key = "taint", label = "BUGS_TAINT", desc = "BUGS_TAINT_DESC",
      keywords = "addon_action_blocked forbidden protected" },
    { type = "range", key = "maxReports", label = "BUGS_MAX", desc = "BUGS_MAX_DESC", min = 100, max = 500, step = 50,
      get = function(m) return m.global.maxReports end,
      set = function(m, v) m.global.maxReports = v end },
    { type = "button", label = "BUGS_OPEN_VIEWER", desc = "BUGS_OPEN_VIEWER_DESC", button = "BUGS_OPEN", icon = "preview",
      variant = "primary", func = openViewer, disabled = function(m) return not m:IsEnabled() end },
    { type = "header", label = "BUGS_NOTIFY", icon = "bell" },
    { type = "toggle", key = "chat", label = "BUGS_CHAT", desc = "BUGS_CHAT_DESC" },
    { type = "select", key = "sound", label = "BUGS_SOUND", desc = "BUGS_SOUND_DESC", values = {
        { value = "none", label = "BUGS_SOUND_NONE" },
        { value = "chime", label = "BUGS_SOUND_CHIME", icon = "sound" },
        { value = "alert", label = "BUGS_SOUND_ALERT", icon = "sound" },
        { value = "bell", label = "BUGS_SOUND_BELL", icon = "sound" },
        { value = "alarm", label = "BUGS_SOUND_ALARM", icon = "sound" },
    } },
    { type = "toggle", key = "flash", label = "BUGS_FLASH", desc = "BUGS_FLASH_DESC" },
    { type = "select", key = "indicator", label = "BUGS_INDICATOR", desc = "BUGS_INDICATOR_DESC", values = {
        { value = "errors", label = "BUGS_INDICATOR_ERRORS" },
        { value = "always", label = "BUGS_INDICATOR_ALWAYS" },
        { value = "never", label = "BUGS_INDICATOR_NEVER" },
    } },
    { type = "toggle", label = "BUGS_POPUP", desc = "BUGS_POPUP_DESC", get = popupGet, set = popupSet, combat = true,
      keywords = "scripterrors blizzard error frame popup" },
    { type = "header", label = "BUGS_UPLOAD_HEADER", icon = "upload" },
    { type = "toggle", label = "BUGS_SHARE", desc = "BUGS_SHARE_DESC", icon = "upload",
      keywords = "upload send author report privacy telemetry",
      get = function() return Errors:GetShare() end, set = function(m, v) m:SetShare(v) end },
    { type = "description", text = "BUGS_UPLOAD_TEXT" },
    { type = "custom", label = "BUGS_WEBSITE", build = function(row) return W:CopyField(row, WEBSITE, "web") end },
    { type = "custom", label = "BUGS_INSTALL_ID", desc = "BUGS_INSTALL_ID_DESC",
      get = function() return Errors:GetInstallId() end,
      build = function(row) return W:CopyField(row, Errors:GetInstallId(), "fingerprint", L.BUGS_COPY_ID) end },
    { type = "header", label = "BUGS_DATA", icon = "delete" },
    { type = "button", label = "BUGS_CLEAR_ALL", desc = "BUGS_CLEAR_ALL_DESC", button = "BUGS_CLEAR", icon = "delete",
      variant = "danger", func = function(m) Errors:Clear("all"); m:Refresh(); ns.Config:SetStatus(L.BUGS_CLEARED, "state.success") end },
})
