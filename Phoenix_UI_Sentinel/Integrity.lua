local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Integrity: validates PhoenixUIDB against the schema at load. Invalid values
-- are repaired to defaults and reported with before/after. Unknown keys are
-- reported but kept (they may belong to a module that has not loaded yet).
local S = PUI.Sentinel
local Integrity = {}
S.Integrity = Integrity

function Integrity:Check(sv)
  local problems = {}
  local defs = PUI.Schema.defs
  for profileName, profile in pairs(sv.profiles or {}) do
    if type(profile) ~= "table" then
      problems[#problems + 1] = { profile = profileName, issue = "profile is not a table", repaired = true }
      sv.profiles[profileName] = {}
    else
      for key, value in pairs(profile) do
        local def = defs[key]
        if not def then
          problems[#problems + 1] = { profile = profileName, key = key, issue = "unknown key", repaired = false }
        else
          local ok, why = PUI.Schema:Validate(def, value)
          if not ok then
            problems[#problems + 1] = { profile = profileName, key = key, issue = why, repaired = true,
              before = PUI.Secret.Storable(value, 120), after = def.default }
            profile[key] = nil
          end
        end
      end
    end
  end
  for char, profileName in pairs(sv.chars or {}) do
    if type(profileName) ~= "string" or type((sv.profiles or {})[profileName]) ~= "table" then
      problems[#problems + 1] = { issue = "orphaned profile reference", repaired = true,
        before = PUI.Secret.Storable(profileName, 64), after = "Default" }
      sv.chars[char] = "Default"
      sv.profiles.Default = sv.profiles.Default or {}
    end
  end
  for i = 1, #PUI.DB.migrationOrder do
    local id = PUI.DB.migrationOrder[i]
    if not (sv.migrations or {})[id] then
      problems[#problems + 1] = { issue = "migration not applied", key = id, repaired = false }
    end
  end
  if PUI.DB.loadIssue then
    problems[#problems + 1] = { issue = "unserializable value", key = PUI.DB.loadIssue, repaired = false }
  end
  return problems
end

function Integrity:Run()
  local problems = self:Check(PUI.DB.sv)
  for i = 1, #problems do
    local p = problems[i]
    S.Capture:Report("integrity", "Core", {
      message = "PhoenixUIDB: " .. p.issue .. (p.key and (" (" .. p.key .. ")") or ""),
      extra = p,
    })
  end
  return problems
end
