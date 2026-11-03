# Chat mirror (PUI_V2 5.12) - Phase 4 core

Each ChatFrameN gets a Phoenix ScrollingMessageFrame laid over it (mouse off, hyperlinks off, same font/justify/spacing). Blizzard's `FontStringContainer` goes to alpha 0; `hooksecurefunc` post-hooks on `AddMessage` and `SetScrollOffset` copy lines and keep scroll offsets identical, so Blizzard's hyperlink hit zones still sit under the mirrored text. Secret lines pass through unchanged and are never searched, stamped or stored.

Never touched: AddMessage replacement, ScrollToBottom, GetMessageInfo, SetItemRef, ItemRefTooltip.SetHyperlink, window management, tabs.

Settings: `chat.timestamps`, `chat.abbreviate`, `chat.keywords`, `chat.whisperSound`, `chat.fade`. `/pui copychat` opens a copy window of recent plain lines.

Deferred: edit-box skin, tab skin, URL detection, class-coloured names, history persistence, per-window settings, sticky channels, mirror for windows created after enable (until /reload).
