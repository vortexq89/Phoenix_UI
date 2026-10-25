local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, DB, Schema = PUI.Tests, PUI.DB, PUI.Schema

-- Point the DB at a scratch table for one case and restore afterwards.
local function scratch(t, sv)
  local saved = { sv = DB.sv, profile = DB.profile, name = DB.profileName }
  t:cleanup(function()
    DB.sv, DB.profile, DB.profileName = saved.sv, saved.profile, saved.name
    Schema:ApplyAll()
  end)
  return DB:Init(sv)
end

-- Writes a table the way SavedVariables are written, then reads it back.
local function serialize(value, out)
  local t = type(value)
  if t == "string" then out[#out + 1] = string.format("%q", value)
  elseif t == "number" or t == "boolean" then out[#out + 1] = tostring(value)
  else
    out[#out + 1] = "{"
    for k, v in pairs(value) do
      out[#out + 1] = "["
      serialize(k, out)
      out[#out + 1] = "]="
      serialize(v, out)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  end
  return out
end
Tests.Serialize = function(v) return table.concat(serialize(v, {})) end

Tests:Add("DB", "defaults are merged on read and stripped at logout", function(t)
  local sv = {}
  scratch(t, sv)
  t:eq(Schema:Get("core.debugRing"), false, "default read through")
  t:eq(DB:GetRaw("core.debugRing"), nil, "default not copied in")
  DB:SetRaw("core.debugRing", false)
  DB:SetRaw("sentinel.safeModeThreshold", 9)
  DB:StripDefaults()
  t:eq(DB:GetRaw("core.debugRing"), nil, "value equal to default stripped")
  t:eq(DB:GetRaw("sentinel.safeModeThreshold"), 9, "changed value kept")
end)

Tests:Add("DB", "fresh install is genesis-stamped; migrations run once", function(t)
  local id = "9999_test_migration"
  local runs = 0
  DB:RegisterMigration(id, function(sv) runs = runs + 1; sv.profiles.Migrated = {}; return true end)
  t:cleanup(function()
    DB.migrations[id] = nil
    for i = #DB.migrationOrder, 1, -1 do if DB.migrationOrder[i] == id then table.remove(DB.migrationOrder, i) end end
  end)
  local fresh = {}
  t:eq(scratch(t, fresh), true, "fresh")
  t:eq(fresh.migrations[id], true, "genesis stamped")
  t:eq(runs, 0, "not run on fresh install")
  local old = { profiles = { Default = {} }, chars = {}, migrations = {} }
  scratch(t, old)
  t:eq(runs, 1, "ran once on existing data")
  t:eq(old.migrations[id], true, "stamped")
  DB:RunMigrations()
  t:eq(runs, 1, "not run again")
end)

Tests:Add("DB", "SavedVariables round-trip is lossless", function(t)
  local sv = { profiles = { Default = { ["sentinel.safeModeThreshold"] = 7, ["core.locale"] = "deDE" }, Raid = {} },
    chars = { ["Test-Realm"] = "Raid" }, migrations = { ["0001_x"] = true } }
  t:ok(PUI.ClientGate.CheckSerializable(sv), "serializable")
  local text = "return " .. Tests.Serialize(sv)
  local back = loadstring(text)()
  t:same(back, sv, "read back equals written")
end)

Tests:Add("DB", "profile switch applies settings live", function(t)
  local sv = { profiles = { Default = {}, Other = { ["core.locale"] = "frFR" } }, chars = {}, migrations = {} }
  scratch(t, sv)
  local before = PUI.Locale.active
  t:cleanup(function() PUI.Locale.active = before end)
  Schema:Set("core.profile", "Other")
  t:eq(DB:GetProfileName(), "Other", "switched")
  t:eq(PUI.Locale.active, "frFR", "locale applied without reload")
end)
