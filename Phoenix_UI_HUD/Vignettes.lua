local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Rare and treasure alerts: when a rare, treasure or event vignette appears
-- on the minimap (C_VignetteInfo), Phoenix alerts once per vignette with a
-- sound, a client flash and/or a chat line. Phoenix's own design. Names on
-- your ignore list are skipped; instances are skipped unless asked. A name
-- the game hands over as a secret value is never compared (no ignore check,
-- still alerted as "Rare").
local Schema, Secret = PUI.Schema, PUI.Secret
local OWNER = "Vignettes"
local VG = { active = false, seen = {} }
PUI.Vignettes = VG
local s = { rare = true, treasure = true, event = false, sound = true, flash = false, chat = true, instances = false, ignore = {} }
VG.settings = s

-- "rare" | "treasure" | "event" | nil, from the vignette's atlas name (plain data).
function VG.Kind(info)
  local atlas = info and info.atlasName
  if type(atlas) ~= "string" or Secret.IsSecret(atlas) then return nil end
  local a = atlas:lower()
  if a:find("kill") or a:find("rare") then return "rare" end
  if a:find("loot") or a:find("treasure") then return "treasure" end
  if a:find("event") then return "event" end
  return nil
end

function VG.Ignored(name)
  if name == nil or Secret.IsSecret(name) then return false end
  local n = name:lower()
  for _, v in ipairs(s.ignore) do if v:lower() == n then return true end end
  return false
end

VG.LABEL = { rare = "Rare", treasure = "Treasure", event = "Event" }

function VG.Check(guid)
  if not VG.active or guid == nil or Secret.IsSecret(guid) or VG.seen[guid] then return end
  if not s.instances and IsInInstance() then return end
  local info = C_VignetteInfo.GetVignetteInfo(guid)
  if type(info) ~= "table" or info.isDead then return end
  local kind = VG.Kind(info)
  if not kind or not s[kind] then return end
  if VG.Ignored(info.name) then return end
  VG.seen[guid] = true
  if s.sound then PUI.Media:Alert(SOUNDKIT.RAID_WARNING) end
  if s.flash then FlashClientIcon() end
  if s.chat then PUI.Slash.Print(VG.LABEL[kind] .. ": " .. Secret.ToText(info.name)) end
  VG.last = { kind = kind, name = info.name }
end

function VG.Scan()
  for _, guid in ipairs(C_VignetteInfo.GetVignettes() or {}) do VG.Check(guid) end
end

local function onEnable(mod)
  VG.active = true
  mod:RegisterEvent("VIGNETTE_MINIMAP_UPDATED", function(_, _, guid, onMinimap) if onMinimap then VG.Check(guid) end end)
  mod:RegisterEvent("VIGNETTES_UPDATED", VG.Scan)
  mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() wipe(VG.seen) end)
end
local function onDisable() VG.active = false end

local schema = {}
VG.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(v) s[name] = v end
  def.searchTags = { "rare", "treasure", "vignette", "alert" }
  schema["vignette." .. name] = def
end
key("rare", { type = "toggle", default = true, label = "Rare alerts", tooltip = "Alert when a rare appears on the minimap.", mode = "simple" })
key("treasure", { type = "toggle", default = true, label = "Treasure alerts", tooltip = "Alert when a treasure appears on the minimap.", mode = "simple" })
key("event", { type = "toggle", default = false, label = "Event alerts", tooltip = "Alert when a world event marker appears on the minimap.", mode = "advanced" })
key("sound", { type = "toggle", default = true, label = "Alert sound", tooltip = "Plays the alert sound (Theme & Media) for a rare or treasure.", mode = "simple" })
key("flash", { type = "toggle", default = false, label = "Flash the game icon", tooltip = "Flashes the game's taskbar icon when the game is in the background.", mode = "advanced" })
key("chat", { type = "toggle", default = true, label = "Chat line", tooltip = "Prints the rare or treasure name in chat.", mode = "simple" })
key("instances", { type = "toggle", default = false, label = "Also in dungeons and raids", tooltip = "Alerts inside instances too (off: open world only).", mode = "advanced" })
key("ignore", { type = "list", default = {}, maxItems = 50, label = "Ignored rares and treasures",
  tooltip = "Names that never alert (one per line, as shown in the alert).", mode = "advanced" })

VG.module = PUI:RegisterModule(OWNER, {
  label = "Rare alerts",
  tooltip = "A sound, flash or chat line when a rare, treasure or event appears on your minimap, once each, with an ignore list.",
  enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
