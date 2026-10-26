local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Profiles: manage (new / copy / rename / delete / reset), export and import
-- (!PUI1! strings, validated against the schema, merge or replace, all or
-- nothing) and content auto-switch (D-SET-UI: on by default). A content
-- profile is a layer over the character's own profile: it stores only its
-- differences. Switching is combat-deferred and re-applies every setting live.
local Profiles = { CONTENT = { "world", "dungeon", "mythicplus", "raid", "arena", "battleground", "delve" } }
PUI.Profiles = Profiles
local DB, Schema, CQ = PUI.DB, PUI.Schema, PUI.CombatQueue

Profiles.CONTENT_LABEL = { world = "Open world", dungeon = "Dungeon", mythicplus = "Mythic+", raid = "Raid",
  arena = "Arena", battleground = "Battleground", delve = "Delve" }
local MAX_NAME, MAX_IMPORT = 48, 512 * 1024
local PREFIX = "!PUI1!"

local function global()
  local sv = DB.sv
  sv.global = type(sv.global) == "table" and sv.global or {}
  return sv.global
end
local function contentMap()
  local sv = DB.sv
  sv.contentProfiles = type(sv.contentProfiles) == "table" and sv.contentProfiles or {}
  return sv.contentProfiles
end

local function validName(name)
  if type(name) ~= "string" then return false, "name required" end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return false, "name required" end
  if #name > MAX_NAME then return false, "name longer than " .. MAX_NAME end
  if name:find("[%c|]") then return false, "name has control characters" end
  return name
end

-- Re-apply every setting after the active profile changed (one pass).
local function reapply()
  Schema.defs["core.profile"].apply()
  PUI.Kernel:Fire("SETTING_CHANGED", "core.profile", DB.profileName)
  PUI.Kernel:Fire("PROFILES_CHANGED")
end

-- Manage -------------------------------------------------------------------------
function Profiles:List() return DB:ProfileNames() end
function Profiles:Active() return DB.profileName, DB:BaseProfileName() end
function Profiles:Exists(name) return DB.sv.profiles[name] ~= nil end

function Profiles:Create(name, copyFrom)
  local n, why = validName(name)
  if not n then return false, why end
  if DB.sv.profiles[n] then return false, "a profile named " .. n .. " already exists" end
  local src = copyFrom and DB.sv.profiles[copyFrom]
  if copyFrom and not src then return false, "no profile named " .. tostring(copyFrom) end
  DB.sv.profiles[n] = src and Schema.Copy(src) or {}
  PUI.Kernel:Fire("PROFILES_CHANGED")
  return n
end

function Profiles:Switch(name)
  if not DB.sv.profiles[name] then return false, "no profile named " .. tostring(name) end
  CQ.Defer("profiles.switch", function() Schema:Set("core.profile", name); PUI.Kernel:Fire("PROFILES_CHANGED") end)
  return true
end

function Profiles:Rename(old, new)
  local n, why = validName(new)
  if not n then return false, why end
  local sv = DB.sv
  if not sv.profiles[old] then return false, "no profile named " .. tostring(old) end
  if sv.profiles[n] then return false, "a profile named " .. n .. " already exists" end
  sv.profiles[n], sv.profiles[old] = sv.profiles[old], nil
  for char, p in pairs(sv.chars) do if p == old then sv.chars[char] = n end end
  for c, p in pairs(contentMap()) do if p == old then contentMap()[c] = n end end
  if DB.profileName == old then DB.profileName = n end
  if DB.baseName == old then DB.baseName = n end
  PUI.Kernel:Fire("PROFILES_CHANGED")
  return n
end

-- Deleting is refused for the active profile and for one any character uses.
function Profiles:Delete(name)
  local sv = DB.sv
  if not sv.profiles[name] then return false, "no profile named " .. tostring(name) end
  if name == DB.profileName or name == DB.baseName then return false, "switch away from it first" end
  for char, p in pairs(sv.chars) do if p == name then return false, char .. " uses it" end end
  sv.profiles[name] = nil
  for c, p in pairs(contentMap()) do if p == name then contentMap()[c] = nil end end
  PUI.Kernel:Fire("PROFILES_CHANGED")
  return true
end

-- Reset a profile to defaults (live when it is the active one).
function Profiles:Reset(name)
  local p = DB.sv.profiles[name]
  if not p then return false, "no profile named " .. tostring(name) end
  wipe(p)
  if name == DB.profileName or name == DB.baseName then reapply() end
  return true
end

-- Serialize: length-prefixed tokens, parsed without loadstring.
local function ser(v, out)
  local t = type(v)
  if t == "string" then out[#out + 1] = "s" .. #v .. ":" .. v
  elseif t == "number" then out[#out + 1] = "n" .. string.format("%.17g", v) .. ";"
  elseif t == "boolean" then out[#out + 1] = v and "T" or "F"
  elseif t == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      if type(a) == type(b) then return a < b end
      return type(a) == "number"
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do ser(k, out); ser(v[k], out) end
    out[#out + 1] = "}"
  end
  return out
end
Profiles.Serialize = function(v) return table.concat(ser(v, {})) end

local function de(s, i, depth)
  if depth > 12 then return nil, i, "too deep" end
  local c = s:sub(i, i)
  if c == "s" then
    local len, j = s:match("^(%d+):()", i + 1)
    len = tonumber(len)
    if not len then return nil, i, "bad string" end
    return s:sub(j, j + len - 1), j + len
  elseif c == "n" then
    local num, j = s:match("^([-%deE%.infa]+);()", i + 1)
    local v = tonumber(num)
    if not v then return nil, i, "bad number" end
    return v, j
  elseif c == "T" then return true, i + 1
  elseif c == "F" then return false, i + 1
  elseif c == "{" then
    local t = {}
    i = i + 1
    while s:sub(i, i) ~= "}" do
      if i > #s then return nil, i, "unterminated table" end
      local k, v, err
      k, i, err = de(s, i, depth + 1)
      if err then return nil, i, err end
      v, i, err = de(s, i, depth + 1)
      if err then return nil, i, err end
      if k == nil then return nil, i, "nil key" end
      t[k] = v
    end
    return t, i + 1
  end
  return nil, i, "unexpected token"
end
function Profiles.Deserialize(s)
  local v, i, err = de(s, 1, 0)
  if err then return nil, err end
  if i <= #s then return nil, "trailing data" end
  return v
end

-- Export --------------------------------------------------------------------------
-- owner: optional module tag ("UnitFrames") to export one module only.
function Profiles:Export(name, owner)
  local p = DB.sv.profiles[name or DB.profileName]
  if not p then return nil, "no profile named " .. tostring(name) end
  local values = {}
  for key, v in pairs(p) do
    local def = Schema.defs[key]
    if def and not def.get and not def.private and (owner == nil or def.owner == owner) then values[key] = Schema.Copy(v) end
  end
  local payload = Profiles.Serialize({ v = 1, kind = owner and "module" or "profile", owner = owner, name = name or DB.profileName, values = values })
  local packed = C_EncodingUtil and C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(payload)) or payload
  return PREFIX .. packed
end

-- Import: decode and validate; returns a plan to preview and Apply (G19/G26).
function Profiles:Decode(text)
  if type(text) ~= "string" then return nil, "paste a Phoenix export string" end
  text = text:gsub("%s", "")
  if #text > MAX_IMPORT then return nil, "string is too large" end
  if text:sub(1, #PREFIX) ~= PREFIX then return nil, "not a Phoenix UI export string (should start with " .. PREFIX .. ")" end
  local body = text:sub(#PREFIX + 1)
  local raw = body
  if C_EncodingUtil then
    local bin = C_EncodingUtil.DecodeBase64(body)
    raw = bin and C_EncodingUtil.DecompressString(bin)
    if not raw then return nil, "string is damaged (could not decompress)" end
  end
  local data, err = Profiles.Deserialize(raw)
  if not data then return nil, "string is damaged (" .. err .. ")" end
  if type(data) ~= "table" or data.v ~= 1 or type(data.values) ~= "table" then return nil, "unsupported export version" end
  local plan = { name = type(data.name) == "string" and data.name or "Imported", owner = data.owner, values = {}, unknown = 0, invalid = {}, count = 0 }
  for key, v in pairs(data.values) do
    local def = type(key) == "string" and Schema.defs[key]
    if not def or def.get or def.private then
      plan.unknown = plan.unknown + 1
    else
      local ok, why = Schema:Validate(def, v)
      if ok then plan.values[key] = Schema.Copy(v); plan.count = plan.count + 1
      else plan.invalid[#plan.invalid + 1] = key .. ": " .. why end
    end
  end
  table.sort(plan.invalid)
  return plan
end

-- Apply a decoded plan. mode: "new" (into a new profile named target),
-- "merge" (over target) or "replace" (target cleared first). All or nothing:
-- a plan with invalid values is refused and nothing changes.
function Profiles:Apply(plan, mode, target)
  if #plan.invalid > 0 then return false, #plan.invalid .. " invalid value(s); nothing was changed" end
  local p
  if mode == "new" then
    local n, why = self:Create(target or plan.name)
    if not n then return false, why end
    target, p = n, DB.sv.profiles[n]
  else
    p = DB.sv.profiles[target]
    if not p then return false, "no profile named " .. tostring(target) end
    if mode == "replace" then
      for key in pairs(p) do
        local def = Schema.defs[key]
        if plan.owner == nil or (def and def.owner == plan.owner) then p[key] = nil end
      end
    end
  end
  for key, v in pairs(plan.values) do p[key] = Schema.Copy(v) end
  if target == DB.profileName or target == DB.baseName then reapply() end
  PUI.Kernel:Fire("PROFILES_CHANGED")
  return target
end

-- Content auto-switch ------------------------------------------------------------
function Profiles:Content()
  local inInstance, kind = IsInInstance()
  if not inInstance then return "world" end
  if kind == "party" then
    local active = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
    return active and "mythicplus" or "dungeon"
  elseif kind == "raid" then return "raid"
  elseif kind == "arena" then return "arena"
  elseif kind == "pvp" then return "battleground"
  elseif kind == "scenario" then
    local delve = C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress()
    return delve and "delve" or "world"
  end
  return "world"
end

function Profiles:MapContent(content, name)
  assert(self.CONTENT_LABEL[content], "unknown content " .. tostring(content))
  if name ~= nil and not DB.sv.profiles[name] then return false, "no profile named " .. tostring(name) end
  contentMap()[content] = name
  self:Evaluate()
  return true
end
function Profiles:Mapped(content) return contentMap()[content] end

-- Picks the layer for the current content and switches (combat-deferred).
function Profiles:Evaluate()
  if not DB.sv then return end
  local content = self:Content()
  local want
  if Schema:Get("core.autoProfile") and Schema:Cell("core.autoProfile.where", "switch", content) then
    want = contentMap()[content]
  end
  local own = DB.sv.chars[DB:CharKey()]
  if want == own then want = nil end
  local current = DB.baseName and DB.profileName or nil
  if want == current then return false end
  CQ.Defer("profiles.auto", function()
    DB:SetContentLayer(want)
    reapply()
    if Schema:Cell("core.autoProfile.where", "announce", content) then
      PUI.Slash.Print("profile: " .. (want or own) .. " (" .. self.CONTENT_LABEL[content] .. ")")
    end
  end)
  return true
end

local events = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED" }
events:SetScript("OnEvent", function() Profiles:Evaluate() end)
local function arm(on)
  for _, e in ipairs(EVENTS) do
    if on then events:RegisterEvent(e) else events:UnregisterEvent(e) end
  end
end

local defaultWhere = { switch = {}, announce = {} }
for _, c in ipairs(Profiles.CONTENT) do defaultWhere.switch[c] = true; defaultWhere.announce[c] = false end

Schema:Register("core.autoProfile", {
  type = "toggle", default = true,
  label = "Switch profile by content", tooltip = "Use the profile you picked for raid, Mythic+, arena and other content automatically. Applies when you enter, never in combat.",
  mode = "simple", owner = "Profiles", searchTags = { "profile", "auto", "content", "raid", "arena", "mythic" },
  get = function() local g = DB.sv and global(); if g and g.autoProfile ~= nil then return g.autoProfile end return true end,
  set = function(v) if v then global().autoProfile = nil else global().autoProfile = false end end,
  apply = function(v) arm(v); if PUI.Kernel.dbReady then Profiles:Evaluate() end end,
})

Schema:Register("core.autoProfile.where", {
  type = "grid", default = defaultWhere,
  rows = { { id = "switch", label = "Switch profile" }, { id = "announce", label = "Say it in chat" } },
  columns = function()
    local out = {}
    for i, c in ipairs(Profiles.CONTENT) do out[i] = { id = c, label = Profiles.CONTENT_LABEL[c] } end
    return out
  end,
  label = "Where to switch", tooltip = "Pick, per content type, whether the profile switches and whether a chat line tells you.",
  mode = "simple", owner = "Profiles", searchTags = { "profile", "content", "announce" },
  get = function() local g = DB.sv and global(); return Schema.Copy(g and g.autoWhere or defaultWhere) end,
  set = function(v) global().autoWhere = (not DB.DeepEqual(v, defaultWhere)) and v or nil end,
  apply = function() if PUI.Kernel.dbReady then Profiles:Evaluate() end end,
})

PUI.Kernel:On("DB_READY", function() arm(Schema:Get("core.autoProfile")) end)

-- /pui profile list|use <name>|export [module]|content
PUI.Slash:Register("profile", function(rest)
  local cmd, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  if cmd == "use" and arg ~= "" then
    local ok, why = Profiles:Switch(arg)
    PUI.Slash.Print(ok and ("profile: " .. arg) or ("not switched: " .. why))
  elseif cmd == "content" then
    PUI.Slash.Print("content: " .. Profiles:Content() .. "  active: " .. tostring(DB.profileName) .. (DB.baseName and (" over " .. DB.baseName) or ""))
  else
    PUI.Slash.Print("profiles: " .. table.concat(Profiles:List(), ", ") .. "  (active: " .. tostring(DB.profileName) .. ")")
  end
end, "list | use <name> | content: manage profiles")
