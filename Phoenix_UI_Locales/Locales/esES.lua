local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- esES translations (PUI_V2 5.17). Keys are the English strings Phoenix renders
-- (/pui loc lists coverage; .tools/locales.py writes ../keys.txt). Any
-- string not listed here falls back to English. First pass covers module
-- names and core labels (draft, needs native review); the rest is open to
-- data-pack style pull requests that touch only this file.
PUI.Locale:Add("esES", {
  ["Action bars"] = "Barras de acción",
  ["Chat"] = "Chat",
  ["Click-casting"] = "Lanzar con clic",
  ["Cooldown manager"] = "Gestor de reutilizaciones",
  ["Data bars"] = "Barras de datos",
  ["Group Finder"] = "Buscador de grupos",
  ["Language"] = "Idioma",
  ["Loadouts"] = "Configuraciones",
  ["Minimap"] = "Minimapa",
  ["Nameplates"] = "Placas de nombre",
  ["Options mode"] = "Modo de opciones",
  ["Quest Tracker"] = "Seguimiento de misiones",
  ["Raid and party frames"] = "Marcos de banda y grupo",
  ["Reminders"] = "Recordatorios",
  ["Resource bars"] = "Barras de recursos",
  ["Skins"] = "Aspectos",
  ["Tooltip"] = "Descripción emergente",
  ["Unit frames"] = "Marcos de unidad",
})
