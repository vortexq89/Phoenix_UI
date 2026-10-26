local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- frFR translations (PUI_V2 5.17). Keys are the English strings Phoenix renders
-- (/pui loc lists coverage; .tools/locales.py writes ../keys.txt). Any
-- string not listed here falls back to English. First pass covers module
-- names and core labels (draft, needs native review); the rest is open to
-- data-pack style pull requests that touch only this file.
PUI.Locale:Add("frFR", {
  ["Action bars"] = "Barres d'action",
  ["Chat"] = "Discussion",
  ["Click-casting"] = "Sorts au clic",
  ["Cooldown manager"] = "Gestionnaire de temps de recharge",
  ["Data bars"] = "Barres de données",
  ["Group Finder"] = "Recherche de groupe",
  ["Language"] = "Langue",
  ["Loadouts"] = "Configurations",
  ["Minimap"] = "Minicarte",
  ["Nameplates"] = "Barres d'info",
  ["Options mode"] = "Mode des options",
  ["Quest Tracker"] = "Suivi des quêtes",
  ["Raid and party frames"] = "Cadres de raid et de groupe",
  ["Reminders"] = "Rappels",
  ["Resource bars"] = "Barres de ressources",
  ["Skins"] = "Apparences",
  ["Tooltip"] = "Infobulle",
  ["Unit frames"] = "Cadres d'unité",
})
