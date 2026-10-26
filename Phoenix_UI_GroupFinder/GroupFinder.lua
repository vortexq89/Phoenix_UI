local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group Finder (PUI_V2 6.6). Adds information to Blizzard's search results
-- without touching how the list is built or how you sign up (both run
-- protected code; changing them would taint signing up): each entry gets a
-- Phoenix line with the leader's score in its rarity colour, the roles still
-- missing, whether your role fits and whether that leader declined you
-- before. Entries below your minimum rating or from declining leaders are
-- dimmed, not removed. Server-side filters (minimum rating, needs my role)
-- go through Blizzard's own advanced filter. A sound can play when a new
-- fitting group appears. On by default (display only); it stands down when
-- Premade Groups Filter is loaded.
local _, ns = ...
local Schema, Media = PUI.Schema, PUI.Media
local OWNER = "GroupFinder"

local GF = { active = false, lines = setmetatable({}, { __mode = "k" }), seen = {} }
ns.GF = GF
PUI.GroupFinder = GF
local s = { scoreColor = true, missingRoles = true, roleFit = true, declined = true, dim = true, minRating = 0, needMyRole = false, sound = false }
GF.settings = s

GF.SLOTS = { TANK = 1, HEALER = 1, DAMAGER = 3 }

function GF.MyRole()
  local index = C_SpecializationInfo.GetSpecialization()
  if not index then return "DAMAGER" end
  local _, _, _, _, role = C_SpecializationInfo.GetSpecializationInfo(index)
  return role or "DAMAGER"
end

-- Members by assigned role for a result (party-sized activities).
function GF.Roles(resultID, numMembers)
  local have = { TANK = 0, HEALER = 0, DAMAGER = 0 }
  for i = 1, numMembers or 0 do
    local p = C_LFGList.GetSearchResultPlayerInfo(resultID, i)
    local role = p and p.assignedRole
    if have[role] then have[role] = have[role] + 1 end
  end
  return have
end

function GF.Missing(have)
  local out = {}
  for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
    local n = GF.SLOTS[role] - (have[role] or 0)
    if n > 0 then out[#out + 1] = (n > 1 and (n .. " ") or "") .. role:sub(1, 1) .. role:sub(2):lower() end
  end
  return out
end

local function declinedList() return Schema:Get("gf.declined") end

function GF.WasDeclined(leader)
  return type(leader) == "string" and declinedList()[leader] ~= nil
end

function GF.Info(resultID)
  if not C_LFGList.HasSearchResultInfo(resultID) then return nil end
  local info = C_LFGList.GetSearchResultInfo(resultID)
  if not info then return nil end
  local have = GF.Roles(resultID, info.numMembers)
  local myRole = GF.MyRole()
  return {
    leader = info.leaderName, score = info.leaderOverallDungeonScore or 0,
    missing = GF.Missing(have), fits = (have[myRole] or 0) < GF.SLOTS[myRole],
    declined = GF.WasDeclined(info.leaderName), members = info.numMembers,
  }
end

function GF.Text(d)
  local parts = {}
  if s.scoreColor and d.score > 0 then
    local c = C_ChallengeMode.GetDungeonScoreRarityColor(d.score)
    local hex = c and c.GenerateHexColor and c:GenerateHexColor() or "ffffffff"
    parts[#parts + 1] = "|c" .. hex .. d.score .. "|r"
  end
  if s.missingRoles and #d.missing > 0 then parts[#parts + 1] = "needs " .. table.concat(d.missing, ", ") end
  if s.roleFit then parts[#parts + 1] = d.fits and "|cff40ff40fits you|r" or "|cff808080role full|r" end
  if s.declined and d.declined then parts[#parts + 1] = "|cffff6060declined you before|r" end
  return table.concat(parts, "  ")
end

function GF.Dimmed(d)
  if not s.dim then return false end
  if s.minRating > 0 and d.score < s.minRating then return true end
  if s.declined and d.declined then return true end
  return false
end

-- Hook on Blizzard's entry update: our own font string, Blizzard's frame left as is.
function GF.Decorate(entry)
  if not GF.active or not entry or not entry.resultID then return end
  local line = GF.lines[entry]
  if not line then
    line = entry:CreateFontString(nil, "OVERLAY")
    line:SetFontObject(Media:FontObject("small"))
    line:SetPoint("BOTTOMRIGHT", entry, "BOTTOMRIGHT", -40, 3)
    GF.lines[entry] = line
  end
  local d = GF.Info(entry.resultID)
  if not d then line:SetText(""); return end
  line:SetText(GF.Text(d))
  line:Show()
  entry:SetAlpha(GF.Dimmed(d) and 0.45 or 1)
end

local hooked = false
function GF.Hook()
  if hooked or not rawget(_G, "LFGListSearchEntry_Update") then return end
  hooked = true
  hooksecurefunc("LFGListSearchEntry_Update", GF.Decorate)
end

-- Advanced filter: only the fields Phoenix owns are written.
function GF.ApplyFilter()
  if not GF.active then return end
  -- Never overwrite the player's own Blizzard filter unless a Phoenix filter is
  -- (or was just) on; turning ours off writes the neutral values once.
  local wants = s.minRating > 0 or s.needMyRole
  if not wants and not GF.ownsFilter then return end
  GF.ownsFilter = wants
  local f = C_LFGList.GetAdvancedFilter()
  if type(f) ~= "table" then return end
  f.minimumRating = s.minRating
  local role = GF.MyRole()
  f.needsTank = s.needMyRole and role == "TANK" or false
  f.needsHealer = s.needMyRole and role == "HEALER" or false
  f.needsDamage = s.needMyRole and role == "DAMAGER" or false
  C_LFGList.SaveAdvancedFilter(f)
end

function GF.OnStatus(_, _, resultID, newStatus)
  if newStatus ~= "declined" and newStatus ~= "declined_full" and newStatus ~= "declined_delisted" then return end
  local info = C_LFGList.HasSearchResultInfo(resultID) and C_LFGList.GetSearchResultInfo(resultID)
  local leader = info and info.leaderName
  if type(leader) ~= "string" or PUI.Secret.IsSecret(leader) then return end
  local list = declinedList()
  list[leader] = time()
  -- keep the newest 200
  local n, oldest, oldKey = 0
  for k, t in pairs(list) do n = n + 1; if not oldest or t < oldest then oldest, oldKey = t, k end end
  if n > 200 and oldKey then list[oldKey] = nil end
  Schema:Set("gf.declined", list)
end

function GF.OnResults()
  if not s.sound then return end
  local _, results = C_LFGList.GetSearchResults()
  local fresh = false
  for _, id in ipairs(results or {}) do
    if not GF.seen[id] then
      GF.seen[id] = true
      local d = GF.Info(id)
      if d and d.fits and not GF.Dimmed(d) then fresh = true end
    end
  end
  if fresh and GF.primed then PUI.Media:Alert(SOUNDKIT.RAID_WARNING) end
  GF.primed = true
end

local function onEnable(mod)
  GF.active = true
  GF.Hook()
  mod:RegisterEvent("ADDON_LOADED", function() GF.Hook() end)
  mod:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", GF.OnStatus)
  mod:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", GF.OnResults)
end
local function onDisable()
  GF.active = false
  for entry, line in pairs(GF.lines) do line:Hide(); entry:SetAlpha(1) end
  wipe(GF.seen); GF.primed = nil
end

local schema = {}
GF.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value) s[name] = value; if name == "minRating" or name == "needMyRole" then GF.ApplyFilter() end end
  schema["gf." .. name] = def
end
key("scoreColor", { type = "toggle", default = true, label = "Leader score", tooltip = "Shows the leader's Mythic+ score in its rarity colour.", mode = "simple" })
key("missingRoles", { type = "toggle", default = true, label = "Missing roles", tooltip = "Shows which roles the group still needs.", mode = "simple" })
key("roleFit", { type = "toggle", default = true, label = "Role fit", tooltip = "Shows whether your current role still fits the group.", mode = "simple" })
key("declined", { type = "toggle", default = true, label = "Declined memory", tooltip = "Remembers leaders who declined you and marks their groups.", mode = "advanced" })
key("dim", { type = "toggle", default = true, label = "Dim unwanted groups", tooltip = "Dims groups below your minimum rating or from leaders who declined you.", mode = "advanced" })
key("minRating", { type = "range", default = 0, min = 0, max = 4000, step = 50, label = "Minimum leader rating", tooltip = "Blizzard's server-side minimum rating filter; 0 turns it off.", mode = "simple" })
key("needMyRole", { type = "toggle", default = false, label = "Only groups that need my role", tooltip = "Blizzard's server-side filter for groups missing your current role.", mode = "advanced" })
key("sound", { type = "toggle", default = false, label = "New group sound", tooltip = "Plays a sound when a new group that fits you shows up in a refreshed search.", mode = "advanced" })
schema["gf.declined"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Declined leaders",
  tooltip = "Leaders who declined you (newest 200).", apply = function() end }

GF.module = PUI:RegisterModule(OWNER, {
  label = "Group Finder", tooltip = "Leader scores, missing roles, role fit and declined memory in the group finder. Stands down when Premade Groups Filter is loaded.",
  enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
  loadCondition = function() return not C_AddOns.IsAddOnLoaded("PremadeGroupsFilter") end,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
