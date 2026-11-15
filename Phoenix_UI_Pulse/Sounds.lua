local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Pulse, review gap: aura sounds, including private auras. Since 12.1.0 the
-- game plays a sound for an aura itself (C_UnitAuras.AddAuraSound): Phoenix
-- only registers "spell ID -> sound", the client watches the aura, so it
-- works for private boss debuffs addons cannot see. Lines are
-- "spellID: sound name" with an optional ", removed" or ", stacks" trigger.
local _, ns = ...
local Schema, Media, Kernel = PUI.Schema, PUI.Media, PUI.Kernel
local PL = PUI.Pulse or ns.PL
local OWNER = "Pulse"
local s = { auraSounds = {}, auraSoundChannel = "Master", auraSoundThrottle = 1, auraSoundUnit = "player" }
local A = { ids = {} }
PL.Sounds = A
A.s = s
A.TRIGGERS = { added = "Added", removed = "Removed", stacks = "ApplicationsIncreased" }

-- Parse(line) -> { spellID, sound, trigger } or nil, why
function A.Parse(line)
  if type(line) ~= "string" then return nil, "not text" end
  local id, rest = line:match("^%s*(%d+)%s*:%s*(.-)%s*$")
  if not id then return nil, "write it as spellID: sound" end
  local sound, trig = rest:match("^(.-)%s*,%s*(%a+)$")
  if not sound then sound, trig = rest, "added" end
  trig = trig:lower()
  if not A.TRIGGERS[trig] then return nil, "trigger must be added, removed or stacks" end
  if sound == "" then return nil, "no sound" end
  return { spellID = tonumber(id), sound = sound, trigger = trig }
end

local function path(name) return Media:Path("sound", name) or (name:find("[\\/]") and name) or nil end
A.SoundPath = path

function A.Clear()
  for i = #A.ids, 1, -1 do C_UnitAuras.RemoveAuraSound(A.ids[i]); A.ids[i] = nil end
end
-- Apply(): drops every registration and registers the current list (module on only).
function A.Apply()
  A.Clear()
  if not (PL.active and type(s.auraSounds) == "table") then return 0 end
  local trig = Enum.UnitAuraSoundTrigger
  for _, line in ipairs(s.auraSounds) do
    local e = A.Parse(line)
    local file = e and path(e.sound)
    local t = e and trig and trig[A.TRIGGERS[e.trigger]]
    if file and t then
      local info = { unitToken = s.auraSoundUnit, spellID = e.spellID, outputChannel = s.auraSoundChannel, throttleSeconds = s.auraSoundThrottle }
      if type(file) == "number" then info.soundFileID = file else info.soundFileName = file end
      local id = C_UnitAuras.AddAuraSound(t, info)
      if type(id) == "number" then A.ids[#A.ids + 1] = id end
    end
  end
  return #A.ids
end
Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then A.Apply() end end)
Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then A.Apply() end end)

local function key(name, def)
  def.owner = OWNER
  def.apply = function(v) s[name] = v; A.Apply() end
  PL.schema["pulse." .. name] = def
  Schema:Register("pulse." .. name, def)
  s[name] = Schema:Get("pulse." .. name)
end
key("auraSounds", { type = "list", default = {}, mode = "simple", label = "Aura sounds",
  tooltip = "One line each: \"spellID: sound\" (a Phoenix or shared sound name), optionally \", removed\" or \", stacks\". The game plays it itself, so it works for private boss debuffs too.",
  searchTags = { "private aura", "sound", "debuff" } })
key("auraSoundChannel", { type = "select", default = "Master", choices = { "Master", "SFX", "Dialog", "Ambience" }, mode = "advanced",
  label = "Aura sound channel", tooltip = "Sound channel for aura sounds (Master plays even with effects muted)." })
key("auraSoundThrottle", { type = "range", default = 1, min = 0, max = 5, step = 0.5, mode = "advanced",
  label = "Aura sound repeat gap", tooltip = "Least seconds between two plays of the same sound (the game allows 0 to 5)." })
key("auraSoundUnit", { type = "select", default = "player", choices = { "player", "target", "focus" }, mode = "advanced",
  label = "Aura sounds watch", tooltip = "Whose auras the sounds watch: you (boss debuffs on you), your target or your focus." })
A.Apply()
