local _, ns = ...

local Opt = ns.Opt
local function unstyled(m) return not m.db.styleText end

ns:RegisterOptions("Chat", {
    { type = "preview", kind = "chat" },
    { type = "header", label = "CHAT_FEATURES", icon = "chat" },
    { type = "toggle", key = "urls", label = "CHAT_URLS", desc = "CHAT_URLS_DESC", keywords = "links website",
      cog = { { type = "color", key = "urlColor", label = "CHAT_URL_COLOR", token = "state.info", reset = true } } },
    { type = "toggle", key = "copyButton", label = "CHAT_COPY_BUTTON", desc = "CHAT_COPY_BUTTON_DESC" },
    { type = "toggle", key = "fastScroll", label = "CHAT_FAST_SCROLL", desc = "CHAT_FAST_SCROLL_DESC",
      keywords = "mouse wheel scroll top bottom page" },
    { type = "header", label = "CHAT_TEXT" },
    { type = "toggle", key = "styleText", label = "CHAT_STYLE_TEXT", desc = "CHAT_STYLE_TEXT_DESC" },
    { type = "font", key = "messages.font", label = "CHAT_MESSAGE_FONT", allowDefault = true, disabled = unstyled,
      cog = {
          { type = "select", key = "messages.outline", label = "FONT_OUTLINE", values = Opt.OUTLINE },
          { type = "toggle", key = "messages.shadow", label = "FONT_SHADOW" },
      } },
    Opt.Text("tabs", "CHAT_TAB_FONT", { max = 16, row = { disabled = unstyled } }),
    { type = "header", label = "CHAT_INPUT", icon = "keyboard" },
    { type = "toggle", key = "arrowKeys", label = "CHAT_ARROW_KEYS", desc = "CHAT_ARROW_KEYS_DESC",
      keywords = "alt up down history edit box" },
    { type = "toggle", key = "keepHistory", label = "CHAT_KEEP_HISTORY", desc = "CHAT_KEEP_HISTORY_DESC",
      keywords = "remember typed messages commands" },
    { type = "button", label = "CHAT_CLEAR_HISTORY", desc = "CHAT_CLEAR_HISTORY_DESC", button = "CLEAR", icon = "delete",
      variant = "danger", func = function(m) m:ClearHistory() end },
})
