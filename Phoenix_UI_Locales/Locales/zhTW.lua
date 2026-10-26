local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- zhTW translations (PUI_V2 5.17). Keys are the English strings Phoenix renders
-- (/pui loc lists coverage; .tools/locales.py writes ../keys.txt). Any
-- string not listed here falls back to English. First pass covers module
-- names and core labels (draft, needs native review); the rest is open to
-- data-pack style pull requests that touch only this file.
PUI.Locale:Add("zhTW", {
  ["Action bars"] = "快捷列",
  ["Chat"] = "聊天",
  ["Click-casting"] = "點擊施法",
  ["Cooldown manager"] = "冷卻管理器",
  ["Data bars"] = "資訊列",
  ["Group Finder"] = "預組隊伍",
  ["Language"] = "語言",
  ["Loadouts"] = "配置方案",
  ["Minimap"] = "小地圖",
  ["Nameplates"] = "名條",
  ["Options mode"] = "選項模式",
  ["Quest Tracker"] = "任務追蹤",
  ["Raid and party frames"] = "團隊與隊伍框架",
  ["Reminders"] = "提醒",
  ["Resource bars"] = "資源條",
  ["Skins"] = "外觀",
  ["Tooltip"] = "浮動提示",
  ["Unit frames"] = "單位框架",
})
