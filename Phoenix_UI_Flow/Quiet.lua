local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Quiet mode (plan 1.O "Skip cinematics, talking head, toasts, auto-accept
-- res", BigWigs BossBlock parity, mockup 16): one row set owned by Flow.
-- Every option starts OFF in every content type (D-MOD-DEF3). Each option is
-- switched per content type (grid) and per instance (override list: an
-- instance follows its content type, or is set on or off for one option).
-- Sound options go through the CVar ledger, so your own values come back when
-- you leave, turn the cell off or turn Flow off. Stands down while BigWigs is
-- loaded unless you pick Phoenix in the conflict notice.
local _, ns = ...
local Schema, Secret = PUI.Schema, PUI.Secret
local FL = ns.Flow
local OWNER = "Flow"
local QM = { effective = {}, overrides = {}, where = {}, inEncounter = false, log = {} }
ns.Quiet = QM
FL.Quiet = QM

QM.OPTIONS = {
  { id = "talkingHead", label = "Hide talking heads" },
  { id = "movies", label = "Skip movies and cinematics (hold Shift to watch)" },
  { id = "toasts", label = "Hide toasts (loot, achievement and other pop-ups)" },
  { id = "emotes", label = "Hide boss emotes" },
  { id = "errorSpeech", label = "Mute error speech", cvar = "Sound_EnableErrorSpeech" },
  { id = "sfxBoss", label = "Mute sound effects during boss fights", cvar = "Sound_EnableSFX", bossOnly = true },
  { id = "music", label = "Mute music", cvar = "Sound_EnableMusic" },
  { id = "acceptRes", label = "Accept resurrection out of combat" },
}
QM.BY_ID = {}
for _, o in ipairs(QM.OPTIONS) do QM.BY_ID[o.id] = o end

local function emptyGrid()
  local g = {}
  for _, o in ipairs(QM.OPTIONS) do
    g[o.id] = {}
    for _, c in ipairs(PUI.Profiles.CONTENT) do g[o.id][c] = false end
  end
  return g
end
QM.EmptyGrid = emptyGrid
local function columns()
  local out = {}
  for i, c in ipairs(PUI.Profiles.CONTENT) do out[i] = { id = c, label = PUI.Profiles.CONTENT_LABEL[c] } end
  return out
end

-- Override list items: "2769:talkingHead=on" (instance ID : option = on|off).
function QM.ParseOverride(item)
  local id, opt, v = tostring(item):match("^%s*(%d+)%s*:%s*([%w]+)%s*=%s*(%a+)%s*$")
  if not id or not QM.BY_ID[opt] or (v ~= "on" and v ~= "off") then return nil end
  return tonumber(id), opt, v == "on"
end
function QM.ValidateOverride(item)
  if QM.ParseOverride(item) then return true end
  return false, "write instance ID:option=on|off, e.g. 2769:talkingHead=on"
end
function QM.BuildOverrides(list)
  local map = {}
  for _, item in ipairs(list or {}) do
    local id, opt, on = QM.ParseOverride(item)
    if id then map[id] = map[id] or {}; map[id][opt] = on end
  end
  return map
end

-- Cell(opt, content, instanceID) -> on?, source ("instance"|"content")
function QM.Cell(opt, content, instanceID)
  local o = instanceID and QM.overrides[instanceID]
  if o and o[opt] ~= nil then return o[opt], "instance" end
  local row = QM.where[opt]
  return (row and row[content]) == true, "content"
end

function QM.Yields() return PUI.Coexist:Yields("flow.quiet") end
function QM.Here()
  local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
  return PUI.Profiles:Content(), instanceID
end

-- Recompute(): what is on right now; applies or restores the sound CVars.
function QM.Recompute()
  local active = FL.active and not QM.Yields()
  local content, instanceID = QM.Here()
  QM.content, QM.instanceID = content, instanceID
  for _, o in ipairs(QM.OPTIONS) do
    local on = active and QM.Cell(o.id, content, instanceID)
    if o.bossOnly then on = on and QM.inEncounter end
    QM.effective[o.id] = on and true or false
    if o.cvar then
      if on then PUI.CVars:Set(OWNER, o.cvar, "0") else PUI.CVars:Restore(OWNER, o.cvar) end
    end
  end
  return QM.effective
end
function QM.On(id) return QM.effective[id] == true end

-- Any cell on anywhere (Flow registers Quiet's events only then).
function QM.AnyCell()
  for _, row in pairs(QM.where) do for _, v in pairs(row) do if v then return true end end end
  return next(QM.overrides) ~= nil
end

-- Actions --------------------------------------------------------------------------
local function did(w) QM.log[#QM.log + 1] = w; if #QM.log > 40 then table.remove(QM.log, 1) end end
function QM.Cinematic()
  if QM.On("movies") and not IsShiftKeyDown() then CinematicFrame_CancelCinematic(); did("cinematic") end
end
function QM.Movie()
  if QM.On("movies") and not IsShiftKeyDown() and MovieFrame:IsShown() then MovieFrame:StopMovie(); did("movie") end
end
function QM.TalkingHead()
  if FL.active and QM.On("talkingHead") then TalkingHeadFrame:CloseImmediately(); did("talkingHead") end
end
function QM.Toast(_, frame)
  if FL.active and QM.On("toasts") and frame and frame.Hide then frame:Hide(); did("toast") end
end
function QM.Emote(frame)
  local target = rawget(_G, "RaidBossEmoteFrame")
  if FL.active and QM.On("emotes") and frame and frame == target and rawget(_G, "RaidNotice_Clear") then RaidNotice_Clear(frame); did("emote") end
end
function QM.Res()
  if not QM.On("acceptRes") or InCombatLockdown() then return end
  AcceptResurrect()
  StaticPopup_Hide("RESURRECT"); StaticPopup_Hide("RESURRECT_NO_SICKNESS"); StaticPopup_Hide("RESURRECT_NO_TIMER")
  did("acceptRes")
end
function QM.EncounterStart() QM.inEncounter = true; QM.Recompute() end
function QM.EncounterEnd() QM.inEncounter = false; QM.Recompute() end
function QM.Zone() QM.Recompute() end

local hooked = {}
function QM.Hook()
  if not hooked.th and rawget(_G, "TalkingHeadFrame") then hooked.th = true; hooksecurefunc(TalkingHeadFrame, "PlayCurrent", QM.TalkingHead) end
  local af = rawget(_G, "AlertFrame")
  if not hooked.af and af and af.AddAlertFrame then hooked.af = true; hooksecurefunc(af, "AddAlertFrame", QM.Toast) end
  if not hooked.em and rawget(_G, "RaidNotice_AddMessage") then hooked.em = true; hooksecurefunc("RaidNotice_AddMessage", QM.Emote) end
end

QM.EVENTS = { CINEMATIC_START = QM.Cinematic, PLAY_MOVIE = QM.Movie, RESURRECT_REQUEST = QM.Res,
  ENCOUNTER_START = QM.EncounterStart, ENCOUNTER_END = QM.EncounterEnd, ZONE_CHANGED_NEW_AREA = QM.Zone, PLAYER_ENTERING_WORLD = QM.Zone }

-- /pui quiet here <option> on|off|inherit  (adds or removes an override for this instance)
function QM.SetHere(opt, value)
  local _, instanceID = QM.Here()
  if not instanceID or instanceID == 0 or not QM.BY_ID[opt] then return false end
  local list = Schema.Copy(Schema:Get("flow.quiet.instances"))
  for i = #list, 1, -1 do
    local id, o = QM.ParseOverride(list[i])
    if id == instanceID and o == opt then table.remove(list, i) end
  end
  if value == "on" or value == "off" then list[#list + 1] = instanceID .. ":" .. opt .. "=" .. value end
  Schema:Set("flow.quiet.instances", list)
  return true
end
PUI.Slash:Register("quiet", function(rest)
  local verb, opt, v = (rest or ""):match("^(%S*)%s*(%S*)%s*(%S*)")
  if verb == "here" then
    PUI.Slash.Print(QM.SetHere(opt, v) and ("quiet mode: " .. opt .. " " .. (v ~= "" and v or "inherit") .. " in this instance") or "use /pui quiet here <option> on|off|inherit inside an instance")
  else
    local parts = {}
    for _, o in ipairs(QM.OPTIONS) do parts[#parts + 1] = o.id .. (QM.On(o.id) and "=on" or "=off") end
    PUI.Slash.Print("quiet mode now (" .. tostring(QM.content) .. "): " .. table.concat(parts, " "))
  end
end, "Quiet mode status, or per-instance overrides (/pui quiet here <option> on|off|inherit)")

-- Schema: added to Flow's schema before Flow registers its module.
local schema = FL.schema
schema["flow.quiet.where"] = { type = "grid", default = emptyGrid(), rows = QM.OPTIONS, columns = columns, owner = OWNER, mode = "simple",
  label = "Quiet mode by content", tooltip = "Tick an option for the content types where it should apply. Everything starts unticked; sound options return to your own values when they stop applying.",
  searchTags = { "quiet", "bossblock", "talking head", "cinematic", "toast", "emote", "music", "sound", "error speech" },
  apply = function(v) QM.where = v or {}; FL.Sync(); QM.Recompute() end }
schema["flow.quiet.instances"] = { type = "list", default = {}, maxItems = 200, owner = OWNER, mode = "advanced",
  label = "Quiet mode per instance", tooltip = "Overrides for single instances: 'instance ID:option=on' or '=off'. An instance without a line follows its content type. Inside an instance, /pui quiet here <option> on|off|inherit adds or removes a line.",
  itemValidate = QM.ValidateOverride, searchTags = { "quiet", "instance", "override", "per instance" },
  apply = function(v) QM.overrides = QM.BuildOverrides(v); FL.Sync(); QM.Recompute() end }
local qkey, qdef = PUI.Coexist:Define("flow.quiet", { module = OWNER, job = "Quiet mode", soft = true, addons = { "BigWigs" } })
qdef.owner = OWNER
qdef.apply = function() QM.Recompute() end
schema[qkey] = qdef
FL.Register()
