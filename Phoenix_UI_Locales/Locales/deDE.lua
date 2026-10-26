local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- deDE translations (PUI_V2 5.17). Keys are the English strings Phoenix renders
-- (/pui loc lists coverage; .tools/locales.py writes ../keys.txt). Any
-- string not listed here falls back to English. First pass covers module
-- names and core labels (draft, needs native review); the rest is open to
-- data-pack style pull requests that touch only this file.
PUI.Locale:Add("deDE", {
  ["Action bars"] = "Aktionsleisten",
  ["Chat"] = "Chat",
  ["Click-casting"] = "Klickzauber",
  ["Cooldown manager"] = "Abklingzeit-Manager",
  ["Data bars"] = "Datenleisten",
  ["Group Finder"] = "Gruppensuche",
  ["Language"] = "Sprache",
  ["Loadouts"] = "Ausrüstungssätze",
  ["Minimap"] = "Minikarte",
  ["Nameplates"] = "Namensplaketten",
  ["Options mode"] = "Optionsmodus",
  ["Quest Tracker"] = "Questverfolgung",
  ["Raid and party frames"] = "Schlachtzugs- und Gruppenfenster",
  ["Reminders"] = "Erinnerungen",
  ["Resource bars"] = "Ressourcenleisten",
  ["Skins"] = "Designs",
  ["Tooltip"] = "Tooltip",
  ["Unit frames"] = "Einheitenfenster",
})
