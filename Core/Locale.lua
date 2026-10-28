local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Locale (PUI_V2 5.17): English text is the key and is translated at the
-- render boundary (options labels and tooltips, Studio chips, module text).
-- Translations live in the load-on-demand child Phoenix_UI_Locales, loaded
-- only when the active language is not English, so English clients pay
-- nothing. A missing translation falls back to English and is remembered so
-- /pui loc can report coverage.
local Locale = { strings = {}, active = "enUS", missing = {}, CHILD = "Phoenix_UI_Locales", visual = {}, fontOn = true }
-- Languages the game cannot lay out itself: their text goes through PUI.Shaper
-- (joining forms and right-to-left order) once, then is cached.
Locale.shapes = { arSA = true }
-- Script of each language and the Phoenix_UI_Media font that covers it, used
-- when the language differs from the client's (the client's own fonts only
-- cover its own script). Arabic has no client, so it always uses its font.
Locale.SCRIPT_FONTS = { ruRU = "Noto Sans", zhCN = "Noto Sans SC", zhTW = "Noto Sans SC", koKR = "Noto Sans KR", arSA = "Noto Sans Arabic" }
Locale.SCRIPT_NAMES = { ruRU = "Cyrillic", zhCN = "Chinese", zhTW = "Chinese", koKR = "Korean", arSA = "Arabic" }
PUI.Locale = Locale

local LOCALES = { "auto", "enUS", "deDE", "frFR", "esES", "esMX", "ptBR", "ruRU", "koKR", "zhCN", "zhTW", "arSA" }
Locale.CHOICES = LOCALES

PUI.L = setmetatable({}, {
  __index = function(_, key)
    if Locale.active == "enUS" then return key end
    local t = Locale.strings[Locale.active]
    local v = t and t[key]
    if v then
      if Locale.shapes[Locale.active] then
        local c = Locale.visual[v]
        if not c then c = PUI.Shaper.Visual(v); Locale.visual[v] = c end
        return c
      end
      return v
    end
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

-- Path of the font Phoenix text must use for the active language, or nil when
-- the chosen fonts already cover it (same as the client, or a font whose
-- coverage lists the script) or the media child is not loaded.
function Locale:ScriptFont(chosen)
  if not self.fontOn then return nil end
  local a = self.active
  local name = self.SCRIPT_FONTS[a]
  if not name or (a == GetLocale() and a ~= "arSA") then return nil end
  local Media = PUI.Media
  local meta = chosen and Media:Meta("font", chosen)
  local script = self.SCRIPT_NAMES[a]
  if meta and meta.coverage and (meta.coverage:find(script, 1, true) or (script == "Chinese" and meta.coverage:find("Chinese", 1, true))) then return nil end
  return Media:Path("font", name)
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
    if PUI.Media and PUI.Media.ApplyFonts then PUI.Media:ApplyFonts() end
    PUI.Kernel:Fire("LOCALE_CHANGED", Locale.active)
  end,
})

PUI.Schema:Register("core.localeFont", {
  type = "toggle",
  default = true,
  label = "Language font",
  tooltip = "When the language uses letters the game font lacks (Arabic, or Russian and Chinese on another client), Phoenix text uses a matching font from the media pack.",
  mode = "advanced",
  owner = "Core",
  apply = function(value)
    Locale.fontOn = value and true or false
    if PUI.Media and PUI.Media.ApplyFonts then PUI.Media:ApplyFonts() end
  end,
})
