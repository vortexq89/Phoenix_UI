-- Prints the module registry and every visible settings key as JSON, from the
-- loaded addon under the offline stub. Used by .tools/site_features.py so the
-- website's feature list only names modules and settings that exist in code.
local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local H = dofile(here .. "/wow_stub.lua")
H.loadAddon("Phoenix_UI")
for _, child in ipairs({ "Phoenix_UI_UnitFrames", "Phoenix_UI_ResourceBars", "Phoenix_UI_ActionBars", "Phoenix_UI_Nameplates", "Phoenix_UI_RaidFrames", "Phoenix_UI_CooldownManager", "Phoenix_UI_HUD", "Phoenix_UI_Chat", "Phoenix_UI_Skins", "Phoenix_UI_Vault", "Phoenix_UI_Flow", "Phoenix_UI_QuestTracker", "Phoenix_UI_Reminders", "Phoenix_UI_Setup" }) do
  local fh = io.open(H.root .. "/" .. child .. "/" .. child .. ".toc")
  if fh then fh:close(); H.loadAddon(child) end
end
local PUI = PhoenixUI
local function str(s)
  s = tostring(s or "")
  s = s:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end)
  return '"' .. s .. '"'
end
local mods, names = {}, {}
for name in pairs(PUI.Modules) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
  local spec = PUI.Modules[name].spec
  local keys = {}
  for key, def in pairs(PUI.Schema.defs) do
    if def.owner == name and not def.hidden and key ~= "module." .. name then keys[#keys + 1] = key end
  end
  table.sort(keys)
  local settings = {}
  for _, key in ipairs(keys) do
    local def = PUI.Schema.defs[key]
    settings[#settings + 1] = "{" .. table.concat({ '"key":' .. str(key), '"label":' .. str(def.label), '"tooltip":' .. str(def.tooltip),
      '"mode":' .. str(def.mode), '"type":' .. str(def.type) }, ",") .. "}"
  end
  mods[#mods + 1] = "{" .. table.concat({ '"name":' .. str(name), '"label":' .. str(spec.label or name), '"tooltip":' .. str(spec.tooltip),
    '"enabledByDefault":' .. tostring(spec.enabledByDefault == true), '"settings":[' .. table.concat(settings, ",") .. "]" }, ",") .. "}"
end
io.stdout:write('{"modules":[' .. table.concat(mods, ",") .. "]}\n")
