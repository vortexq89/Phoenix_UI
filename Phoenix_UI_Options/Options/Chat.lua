local _, ns = ...
local L, Opt, W = ns.L, ns.Opt, ns.Widgets

local function unstyled(m) return not m.db.styleText end
local function plainWindows(m) return not m.db.skinWindows end
-- The game's own chat settings (Options > Social), shown here so chat is set up in one place.
local tsGet, tsSet = ns.Combat.CVarAccessors("showTimestamps", "string")
local classGet, classSet = ns.Combat.CVarAccessors("chatClassColorOverride", "string")
local whisperGet, whisperSet = ns.Combat.CVarAccessors("whisperMode", "string")

local function sounds()
    local out = { { value = "", label = "NONE" } }
    for _, s in ipairs(ns.Media:List("sound")) do out[#out + 1] = { value = s.value, label = s.label } end
    return out
end

-- Chat frame 1's size is Edit Mode's ("Chat Frame" system): this row shows it and opens Edit Mode.
local function sizeRow(row)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(W.CONTROL_WIDTH, 28)
    holder.open = W:Button(holder, L.OPEN_EDIT_MODE, "secondary", "editmode", 112)
    holder.open:SetPoint("RIGHT")
    holder.open.onClick = function() ns.EditMode:Open() end
    holder.badge = W:Badge(holder, "", "accent.primary")
    holder.badge:SetPoint("RIGHT", holder.open, "LEFT", -10, 0)
    function holder:SetValue()
        local cf = DEFAULT_CHAT_FRAME
        local w, h = cf and cf:GetWidth(), cf and cf:GetHeight()
        self.badge:Set(w and ("%d × %d"):format(w, h) or "—", "accent.primary")
    end
    EventRegistry:RegisterCallback("EditMode.Exit", function() holder:SetValue() end, holder)
    return holder
end

ns:RegisterOptions("Chat", {
    { type = "preview", kind = "chat" },
    { type = "tab", label = "CHAT_TAB_WINDOW" },
    { type = "header", label = "CHAT_WINDOW", icon = "chat" },
    { type = "toggle", key = "skinWindows", label = "CHAT_SKIN_WINDOWS", desc = "CHAT_SKIN_WINDOWS_DESC",
      keywords = "background border backdrop window style" },
    Opt.With(Opt.Background("background", nil, "bg.sunken"), { disabled = plainWindows }),
    Opt.With(Opt.Border("border", nil, "border.default"), { disabled = plainWindows }),
    { type = "custom", label = "CHAT_SIZE", desc = "CHAT_SIZE_DESC", get = function() return true end,
      keywords = "width height size edit mode", build = sizeRow },
    { type = "toggle", key = "fade", label = "CHAT_FADE", desc = "CHAT_FADE_DESC", keywords = "fade lines disappear",
      cog = { { type = "range", key = "fadeAfter", label = "CHAT_FADE_AFTER", min = 10, max = 600, step = 10 } } },
    { type = "range", key = "maxLines", label = "CHAT_MAX_LINES", desc = "CHAT_MAX_LINES_DESC", min = 0, max = 2048, step = 64,
      keywords = "history scrollback lines kept" },
    { type = "toggle", key = "hideInCombat", label = "CHAT_HIDE_COMBAT", desc = "CHAT_HIDE_COMBAT_DESC" },
    { type = "toggle", key = "sideButtons", label = "CHAT_SIDE_BUTTONS", desc = "CHAT_SIDE_BUTTONS_DESC",
      keywords = "menu channel voice social buttons" },
    { type = "toggle", key = "scrollButton", label = "CHAT_JUMP", desc = "CHAT_JUMP_DESC", keywords = "scroll bottom newest" },
    { type = "toggle", key = "copyButton", label = "CHAT_COPY_BUTTON", desc = "CHAT_COPY_BUTTON_DESC" },
    { type = "toggle", key = "fastScroll", label = "CHAT_FAST_SCROLL", desc = "CHAT_FAST_SCROLL_DESC",
      keywords = "mouse wheel scroll top bottom page" },
    { type = "header", label = "CHAT_TABS", icon = "layout" },
    { type = "toggle", key = "tabFlash", label = "CHAT_TAB_FLASH", desc = "CHAT_TAB_FLASH_DESC",
      keywords = "tab flash alert new message glow" },
    { type = "toggle", key = "whisperTabs", label = "CHAT_WHISPER_TABS", desc = "CHAT_WHISPER_TABS_DESC",
      keywords = "whisper tab colour color" },
    { type = "toggle", key = "fadeTabs", label = "CHAT_FADE_TABS", desc = "CHAT_FADE_TABS_DESC", keywords = "tabs visible idle" },
    { type = "color", key = "selectedTabColor", label = "CHAT_SELECTED_TAB", desc = "CHAT_SELECTED_TAB_DESC",
      token = "accent.primary", reset = true },
    Opt.Text("tabs", "CHAT_TAB_FONT", { max = 16, row = { disabled = unstyled } }),
    { type = "tab", label = "CHAT_TAB_MESSAGES" },
    { type = "header", label = "CHAT_TEXT", icon = "fonts" },
    { type = "toggle", key = "styleText", label = "CHAT_STYLE_TEXT", desc = "CHAT_STYLE_TEXT_DESC" },
    { type = "font", key = "messages.font", label = "CHAT_MESSAGE_FONT", allowDefault = true, disabled = unstyled,
      cog = {
          { type = "select", key = "messages.outline", label = "FONT_OUTLINE", values = Opt.OUTLINE },
          { type = "toggle", key = "messages.shadow", label = "FONT_SHADOW" },
      } },
    { type = "select", label = "CHAT_TIMESTAMPS", desc = "CHAT_TIMESTAMPS_DESC", get = tsGet, set = tsSet,
      values = function() return ns.modules.Chat.TimestampValues() end, keywords = "time clock stamp" },
    { type = "select", label = "CHAT_CLASS_NAMES", desc = "CHAT_CLASS_NAMES_DESC", get = classGet, set = classSet,
      keywords = "class colour color names", values = {
        { value = "2", label = "CHAT_CLASS_GAME" }, { value = "0", label = "CHAT_CLASS_ALWAYS" },
        { value = "1", label = "CHAT_CLASS_NEVER" },
    } },
    { type = "toggle", key = "shortChannels", label = "CHAT_SHORT_CHANNELS", desc = "CHAT_SHORT_CHANNELS_DESC",
      keywords = "channel names trade general number" },
    { type = "toggle", key = "urls", label = "CHAT_URLS", desc = "CHAT_URLS_DESC", keywords = "links website",
      cog = { { type = "color", key = "urlColor", label = "CHAT_URL_COLOR", token = "state.info", reset = true } } },
    { type = "toggle", key = "itemLevels", label = "CHAT_ITEM_LEVELS", desc = "CHAT_ITEM_LEVELS_DESC",
      keywords = "item level ilvl links loot" },
    { type = "toggle", key = "linkIcons", label = "CHAT_LINK_ICONS", desc = "CHAT_LINK_ICONS_DESC",
      keywords = "icons links item spell achievement" },
    { type = "toggle", key = "roleIcons", label = "CHAT_ROLE_ICONS", desc = "CHAT_ROLE_ICONS_DESC",
      keywords = "role tank healer damage icon names" },
    { type = "header", label = "CHAT_KEYWORDS", icon = "bell" },
    { type = "input", key = "keywords", label = "CHAT_KEYWORD_LIST", desc = "CHAT_KEYWORD_LIST_DESC",
      keywords = "highlight words mention alert" },
    { type = "toggle", key = "keywordOwnName", label = "CHAT_KEYWORD_NAME", desc = "CHAT_KEYWORD_NAME_DESC" },
    { type = "color", key = "keywordColor", label = "CHAT_KEYWORD_COLOR", token = "accent.primary", reset = true },
    { type = "select", key = "keywordSound", label = "CHAT_KEYWORD_SOUND", desc = "CHAT_KEYWORD_SOUND_DESC", values = sounds },
    { type = "range", key = "throttle", label = "CHAT_THROTTLE", desc = "CHAT_THROTTLE_DESC", min = 0, max = 120, step = 5,
      keywords = "spam repeat flood filter" },
    { type = "tab", label = "CHAT_TAB_INPUT" },
    { type = "header", label = "CHAT_INPUT", icon = "keyboard" },
    { type = "toggle", key = "editBoxTop", label = "CHAT_EDITBOX_TOP", desc = "CHAT_EDITBOX_TOP_DESC",
      keywords = "edit box input position above" },
    { type = "toggle", key = "skinEditBox", label = "CHAT_EDITBOX_SKIN", desc = "CHAT_EDITBOX_SKIN_DESC",
      keywords = "edit box style backdrop border" },
    Opt.Text("editBox", "CHAT_EDITBOX_FONT", { max = 20, row = { disabled = unstyled } }),
    { type = "toggle", key = "arrowKeys", label = "CHAT_ARROW_KEYS", desc = "CHAT_ARROW_KEYS_DESC",
      keywords = "alt up down history edit box" },
    { type = "toggle", key = "keepHistory", label = "CHAT_KEEP_HISTORY", desc = "CHAT_KEEP_HISTORY_DESC",
      keywords = "remember typed messages commands" },
    { type = "range", key = "historyLines", label = "CHAT_HISTORY_LINES", desc = "CHAT_HISTORY_LINES_DESC", min = 10, max = 100,
      step = 1 },
    { type = "button", label = "CHAT_CLEAR_HISTORY", desc = "CHAT_CLEAR_HISTORY_DESC", button = "CLEAR", icon = "delete",
      variant = "danger", func = function(m) m:ClearHistory() end },
    { type = "header", label = "CHAT_TOOLS", icon = "cog" },
    { type = "toggle", key = "chatBar", label = "CHAT_BAR", desc = "CHAT_BAR_DESC",
      keywords = "channel buttons roll ready check pull countdown",
      cog = { { type = "select", key = "chatBarSide", label = "CHAT_BAR_SIDE", values = {
          { value = "TOP", label = "CHAT_BAR_TOP" }, { value = "LEFT", label = "CHAT_BAR_LEFT" },
      } } } },
    { type = "toggle", key = "raidIcons", label = "CHAT_RAID_ICONS", desc = "CHAT_RAID_ICONS_DESC",
      keywords = "raid target marker star skull emote picker" },
    { type = "select", label = "CHAT_WHISPER_MODE", desc = "CHAT_WHISPER_MODE_DESC", get = whisperGet, set = whisperSet,
      keywords = "whisper new tab window popout inline", values = {
        { value = "inline", label = "CHAT_WHISPER_INLINE" }, { value = "popout", label = "CHAT_WHISPER_POPOUT" },
        { value = "popout_and_inline", label = "CHAT_WHISPER_BOTH" },
    } },
    { type = "select", key = "whisperSound", label = "CHAT_WHISPER_SOUND", desc = "CHAT_WHISPER_SOUND_DESC", values = sounds },
})
