local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Locale: English keys, translated at the render boundary. Phase 1 ships the
-- engine only; translations arrive with the Locales child in a later phase.
local Locale = { strings = {}, active = "enUS" }
PUI.Locale = Locale

local LOCALES = { "auto", "enUS", "deDE", "frFR", "esES", "esMX", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
Locale.CHOICES = LOCALES

PUI.L = setmetatable({}, {
  __index = function(_, key)
    local t = Locale.strings[Locale.active]
    return (t and t[key]) or key
  end,
})

function Locale:Resolve(value)
  if value == "auto" then return GetLocale() end
  return value
end

PUI.Schema:Register("core.locale", {
  type = "select",
  default = "auto",
  choices = LOCALES,
  label = "Language",
  tooltip = "Language for Phoenix UI text. Auto follows the game client.",
  mode = "simple",
  owner = "Core",
  apply = function(value)
    Locale.active = Locale:Resolve(value)
    PUI.Kernel:Fire("LOCALE_CHANGED", Locale.active)
  end,
})
