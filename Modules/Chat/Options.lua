local _, ns = ...

ns:RegisterOptions("Chat", {
    { type = "header", label = "CHAT_FEATURES" },
    { type = "toggle", key = "urls", label = "CHAT_URLS", desc = "CHAT_URLS_DESC", keywords = "links website" },
    { type = "toggle", key = "copyButton", label = "CHAT_COPY_BUTTON", desc = "CHAT_COPY_BUTTON_DESC" },
})
