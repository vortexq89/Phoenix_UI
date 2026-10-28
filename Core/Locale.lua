local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Locale (PUI_V2 5.17): English text is the key and is translated at the
-- render boundary (options labels and tooltips, Studio chips, module text).
-- Translations live in the load-on-demand child Phoenix_UI_Locales, loaded
-- only when the active language is not English, so English clients pay
-- nothing. A missing translation falls back to English and is remembered so
-- /pui loc can report coverage.
local Locale = { strings = {}, active = "enUS", missing = {}, CHILD = "Phoenix_UI_Locales" }
PUI.Locale = Locale

local LOCALES = { "auto", "enUS", "deDE", "frFR", "esES", "esMX", "ptBR", "ruRU", "koKR", "zhCN", "zhTW", "arSA" }
Locale.CHOICES = LOCALES

PUI.L = setmetatable({}, {
  __index = function(_, key)
    if Locale.active == "enUS" then return key end
    local t = Locale.strings[Locale.active]
    local v = t and t[key]
    if v then return v end
    if type(key) == "string" then Locale.missing[key] = true end
    return key
  end,
})

-- Called by the locale child: Locale:Add("deDE", { ["English"] = "Deutsch", ... }).
function Locale:Add(code, map)
  local t = self.strings[code] or {}
  for k, v in pairs(map) do t[k] = v end
  self.strings[code] = t
end

function Locale:Resolve(value)
  if value == "auto" then return GetLocale() end
  return value
end

function Locale:LoadChild()
  if self.active == "enUS" or C_AddOns.IsAddOnLoaded(self.CHILD) then return true end
  local loaded = C_AddOns.LoadAddOn(self.CHILD)
  return loaded
end

-- Coverage of the active language over a list of English keys.
function Locale:Coverage(keys)
  local t = self.strings[self.active] or {}
  local have = 0
  for _, k in ipairs(keys) do if t[k] then have = have + 1 end end
  return have, #keys
end

-- Every visible English string Phoenix renders from the schema and Studio.
function Locale:Harvest()
  local seen, out = {}, {}
  local function add(s) if type(s) == "string" and s ~= "" and not seen[s] then seen[s] = true; out[#out + 1] = s end end
  for _, key in ipairs(PUI.Schema.keys) do
    local def = PUI.Schema.defs[key]
    if not def.hidden then add(def.label); add(def.tooltip) end
  end
  for _, el in pairs(PUI.Layout.elements) do add(el.label) end
  table.sort(out)
  return out
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
    if Locale.active == "enGB" then Locale.active = "enUS" end
    Locale:LoadChild()
    PUI.Kernel:Fire("LOCALE_CHANGED", Locale.active)
  end,
})
