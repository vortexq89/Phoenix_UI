local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- ruRU translations (PUI_V2 5.17). Keys are the English strings Phoenix renders
-- (/pui loc lists coverage; .tools/locales.py writes ../keys.txt). Any
-- string not listed here falls back to English. First pass covers module
-- names and core labels (draft, needs native review); the rest is open to
-- data-pack style pull requests that touch only this file.
PUI.Locale:Add("ruRU", {
  ["Action bars"] = "Панели команд",
  ["Chat"] = "Чат",
  ["Click-casting"] = "Заклинания по щелчку",
  ["Cooldown manager"] = "Менеджер восстановления",
  ["Data bars"] = "Информационные панели",
  ["Group Finder"] = "Поиск группы",
  ["Language"] = "Язык",
  ["Loadouts"] = "Наборы",
  ["Minimap"] = "Миникарта",
  ["Nameplates"] = "Индикаторы здоровья",
  ["Options mode"] = "Режим настроек",
  ["Quest Tracker"] = "Список заданий",
  ["Raid and party frames"] = "Рамки рейда и группы",
  ["Reminders"] = "Напоминания",
  ["Resource bars"] = "Полосы ресурсов",
  ["Skins"] = "Оформление",
  ["Tooltip"] = "Подсказка",
  ["Unit frames"] = "Рамки юнитов",
})
