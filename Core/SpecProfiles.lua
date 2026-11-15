local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Spec -> profile auto-switch (plan 1.7, 3.3). Each specialization can name
-- the profile it uses; on a spec change the character's own profile switches,
-- never during combat (CombatQueue). Content profiles (Profiles:Evaluate)
-- still layer on top, so raid / arena / M+ choices keep working. Off at first
-- install; the setup wizard's role step and the Profiles page both carry the
-- switch. The map lives per character in the saved variables, never in a
-- profile (a profile cannot point at itself).
local SpecProfiles = { MAX_SPECS = 4 }
PUI.SpecProfiles = SpecProfiles
local DB, Schema, CQ = PUI.DB, PUI.Schema, PUI.CombatQueue
local OWNER = "Profiles"

local function charRec(create)
  local sv = DB.sv
  if not sv then return nil end
  if create then sv.specProfiles = type(sv.specProfiles) == "table" and sv.specProfiles or {} end
  local all = sv.specProfiles
  if type(all) ~= "table" then return nil end
  local k = DB:CharKey()
  if create and type(all[k]) ~= "table" then all[k] = {} end
  return all[k]
end
SpecProfiles.CharRec = charRec

-- Map(spec) -> profile name or nil. SetMap(spec, name|nil).
function SpecProfiles:Map(spec)
  local r = charRec(false)
  local name = r and r[spec]
  if name and DB.sv.profiles[name] then return name end
  return nil
end
function SpecProfiles:SetMap(spec, name)
  if name == "" then name = nil end
  if name ~= nil and not DB.sv.profiles[name] then return false, "no profile named " .. tostring(name) end
  charRec(true)[spec] = name
  self:Evaluate()
  return true
end

-- Picks the profile for the current spec and switches out of combat.
-- Returns the wanted name (or nil when nothing changes).
function SpecProfiles:Evaluate()
  if not (DB.sv and Schema:Get("core.specProfile")) then return nil end
  local spec = C_SpecializationInfo.GetSpecialization()
  local want = spec and self:Map(spec)
  if not want then return nil end
  local own = DB.sv.chars[DB:CharKey()]
  if want == own then return nil end
  CQ.Defer("profiles.spec", function()
    Schema:Set("core.profile", want)
    if Schema:Get("core.specProfile.announce") then PUI.Slash.Print("profile: " .. want .. " (specialization)") end
    PUI.Profiles:Evaluate() -- re-layer the content profile on the new base
  end)
  return want
end

local events = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
events:SetScript("OnEvent", function() SpecProfiles:Evaluate() end)
local function arm(on)
  if on then events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED") else events:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED") end
end

local function specLabel(i)
  local name
  if C_SpecializationInfo.GetSpecializationInfo then name = select(2, C_SpecializationInfo.GetSpecializationInfo(i)) end
  return "Specialization " .. i .. (type(name) == "string" and (" (" .. name .. ")") or "")
end
local function profileChoices()
  local out = { "" }
  for _, n in ipairs(DB.sv and DB:ProfileNames() or {}) do out[#out + 1] = n end
  return out
end
local function profileLabels()
  local out = { [""] = "No change" }
  for _, n in ipairs(DB.sv and DB:ProfileNames() or {}) do out[n] = n end
  return out
end

Schema:Register("core.specProfile", {
  type = "toggle", default = false,
  label = "Switch profile by specialization",
  tooltip = "Each specialization can use its own profile. When you change spec, Phoenix switches to that profile (after combat). Content profiles for raid, arena or Mythic+ still apply on top.",
  mode = "simple", owner = OWNER, searchTags = { "spec", "dual spec", "profile", "auto" },
  get = function() local r = charRec(false); return r and r.on == true or false end,
  set = function(v) charRec(true).on = v or nil end,
  apply = function(v) arm(v); if v and PUI.Kernel.dbReady then SpecProfiles:Evaluate() end end,
})
Schema:Register("core.specProfile.announce", {
  type = "toggle", default = true, label = "Say it in chat when the spec profile switches",
  tooltip = "Prints one line naming the profile after a specialization switch.", mode = "advanced", owner = OWNER,
  apply = function() end,
})
for i = 1, SpecProfiles.MAX_SPECS do
  Schema:Register("core.specProfile.spec" .. i, {
    type = "select", default = "", choices = profileChoices, choiceLabels = profileLabels,
    label = specLabel(i), tooltip = "The profile this specialization uses. No change keeps whatever profile is active.",
    mode = "simple", owner = OWNER, searchTags = { "spec", "profile" },
    get = function() return SpecProfiles:Map(i) or "" end,
    set = function(v) charRec(true)[i] = v ~= "" and v or nil end,
    apply = function() if PUI.Kernel.dbReady then SpecProfiles:Evaluate() end end,
  })
end

PUI.Kernel:On("DB_READY", function() arm(Schema:Get("core.specProfile")) end)
