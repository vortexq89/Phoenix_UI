local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- zhCN translations (PUI_V2 5.17). Keys are the English strings Phoenix renders
-- (/pui loc lists coverage; .tools/locales.py writes ../keys.txt). Any
-- string not listed here falls back to English. First pass covers module
-- names and core labels (draft, needs native review); the rest is open to
-- data-pack style pull requests that touch only this file.
PUI.Locale:Add("zhCN", {
  ["Action bars"] = "动作条",
  ["Chat"] = "聊天",
  ["Click-casting"] = "点击施法",
  ["Cooldown manager"] = "冷却管理器",
  ["Data bars"] = "信息条",
  ["Group Finder"] = "预创建队伍",
  ["Language"] = "语言",
  ["Loadouts"] = "配置方案",
  ["Minimap"] = "小地图",
  ["Nameplates"] = "姓名板",
  ["Options mode"] = "选项模式",
  ["Quest Tracker"] = "任务追踪",
  ["Raid and party frames"] = "团队与小队框体",
  ["Reminders"] = "提醒",
  ["Resource bars"] = "资源条",
  ["Skins"] = "皮肤",
  ["Tooltip"] = "鼠标提示",
  ["Unit frames"] = "单位框体",
})
