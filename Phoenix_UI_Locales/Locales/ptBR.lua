local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- ptBR translations (PUI_V2 5.17). Keys are the English strings Phoenix renders
-- (/pui loc lists coverage; .tools/locales.py writes ../keys.txt). Any
-- string not listed here falls back to English. First pass covers module
-- names and core labels (draft, needs native review); the rest is open to
-- data-pack style pull requests that touch only this file.
PUI.Locale:Add("ptBR", {
  ["Action bars"] = "Barras de ação",
  ["Chat"] = "Bate-papo",
  ["Click-casting"] = "Lançar com clique",
  ["Cooldown manager"] = "Gerenciador de recargas",
  ["Data bars"] = "Barras de dados",
  ["Group Finder"] = "Localizador de grupos",
  ["Language"] = "Idioma",
  ["Loadouts"] = "Configurações",
  ["Minimap"] = "Minimapa",
  ["Nameplates"] = "Placas de identificação",
  ["Options mode"] = "Modo de opções",
  ["Quest Tracker"] = "Rastreador de missões",
  ["Raid and party frames"] = "Quadros de raide e grupo",
  ["Reminders"] = "Lembretes",
  ["Resource bars"] = "Barras de recursos",
  ["Skins"] = "Visuais",
  ["Tooltip"] = "Dica",
  ["Unit frames"] = "Quadros de unidade",
})
