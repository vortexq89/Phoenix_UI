local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group Finder (PUI_V2 6.6, plan 5.16 / 15.7, mockup 08): Premade Groups
-- Filter parity done Phoenix's way, plus AutoQueue's queue helper.
--  * Blizzard's list is never rebuilt and its result or decline tables are
--    never written (G14). Each Blizzard row gets a Phoenix line (score, best
--    key, missing roles, role fit, age, declined) and role indicators; rows the
--    filter rejects are dimmed. Phoenix's own docked panel lists the matching
--    groups, sorted, with a "showing X of Y - why hidden" line.
--  * Filters are chips per category that generate a readable expression; the
--    expression can be edited and is validated in plain words.
--  * The free-text boxes (title, comment, sign-up note) belong to Blizzard and
--    cannot be written by addons, so Phoenix never tries.
--  * With Premade Groups Filter loaded the conflict notice asks which side
--    keeps the job; nothing changes until the player picks.
local _, ns = ...
local Schema, Media, Secret = PUI.Schema, PUI.Media, PUI.Secret
local Data, Filters = ns.Data, ns.Filters
local OWNER = "GroupFinder"

local GF = { active = false, lines = setmetatable({}, { __mode = "k" }), marks = setmetatable({}, { __mode = "k" }), seen = {},
  rows = {}, shown = {}, why = { order = {} }, hidden = 0 }
ns.GF = GF
PUI.GroupFinder = GF
GF.Data, GF.Filters, GF.Expr = Data, Filters, ns.Expr
local s = { scoreColor = true, missingRoles = true, roleFit = true, declined = true, dim = true, minRating = 0, needMyRole = false, sound = false,
  bestKey = true, age = true, roleIcons = "icons", leaderCrown = true, rowColors = true, dimAlpha = 0.45, tooltip = true, classNames = true }
GF.settings = s
GF.SLOTS = Data.SLOTS
GF.MyRole = Data.MyRole

-- Filter settings: gf.<category>.<field>; read through one accessor.
local fs = {}
GF.filterSettings = fs
function GF.FilterGet(cat, id)
  local c = fs[cat]
  return c and c[id]
end

function GF.Roles(resultID, numMembers)
  local have = { TANK = 0, HEALER = 0, DAMAGER = 0 }
  for i = 1, numMembers or 0 do
    local p = C_LFGList.GetSearchResultPlayerInfo(resultID, i)
    local role = p and Data.plain(p.assignedRole)
    if role and have[role] then have[role] = have[role] + 1 end
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
  return type(leader) == "string" and not Secret.IsSecret(leader) and declinedList()[leader] ~= nil
end

-- Info(resultID): the row data used by the Blizzard-row line and our list.
function GF.Info(resultID)
  local v, meta = Data.Vars(resultID, GF.WasDeclined)
  if not v then return nil end
  local have = { TANK = v.tanks, HEALER = v.heals, DAMAGER = v.dps }
  return { leader = meta.leader, score = v.mprating, bestKey = v.bestkey, age = v.age, missing = GF.Missing(have), fits = v.partyfit,
    declined = v.declined, members = v.members, vars = v, meta = meta, status = meta.status, new = v.new }
end

function GF.ScoreText(score)
  if not score or score <= 0 then return nil end
  if PUI.Season and PUI.Season.ColoredScore then return PUI.Season:ColoredScore(score) end
  return tostring(score)
end

function GF.Text(d)
  local parts = {}
  if s.scoreColor and d.score > 0 then
    parts[#parts + 1] = GF.ScoreText(d.score) .. ((s.bestKey and (d.bestKey or 0) > 0) and (" |cffb0b0b0best +" .. d.bestKey .. "|r") or "")
  end
  if s.missingRoles and #d.missing > 0 then parts[#parts + 1] = "needs " .. table.concat(d.missing, ", ") end
  if s.roleFit then parts[#parts + 1] = d.fits and "|cff40ff40fits you|r" or "|cff808080role full|r" end
  if s.age and d.age then parts[#parts + 1] = "|cffb0b0b0" .. d.age .. "m|r" end
  if s.declined and d.declined then parts[#parts + 1] = "|cffff6060declined you before|r" end
  return table.concat(parts, "  ")
end

-- Row colour for a result (new / declined / cancelled / delisted), or nil.
function GF.RowColor(d)
  if not s.rowColors then return nil end
  if d.status == "cancelled" then return Schema:Get("gf.color.cancelled") end
  if d.declined or d.status == "declined" or d.status == "declined_full" then return Schema:Get("gf.color.declined") end
  if d.vars and d.vars.delisted then return Schema:Get("gf.color.delisted") end
  if d.new then return Schema:Get("gf.color.new") end
  return nil
end

-- Dimmed when the Phoenix filter (current category) or the minimum rejects it.
function GF.Dimmed(d)
  if not s.dim then return false end
  if s.minRating > 0 and d.score < s.minRating then return true end
  if s.declined and d.declined then return true end
  if d.vars and GF.category and GF.FilterGet(GF.category, "enabled") then
    for _, c in ipairs(Filters.Chips(GF.category, GF.FilterGet)) do if not Filters.Check(c, d.vars) then return true end end
  end
  return false
end

-- Role indicators on a Blizzard row: our own textures, fixed tank-healer-dps order.
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
GF.ROLE_ATLAS = ROLE_ATLAS
local ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }
function GF.SortedMembers(classes)
  local list = {}
  for _, c in pairs(classes or {}) do list[#list + 1] = c end
  table.sort(list, function(a, b)
    local x, y = ORDER[a.role or "DAMAGER"] or 4, ORDER[b.role or "DAMAGER"] or 4
    if x ~= y then return x < y end
    return (a.class or "") < (b.class or "")
  end)
  return list
end
local function marks(entry)
  local m = GF.marks[entry]
  if not m then
    m = {}
    for i = 1, 5 do
      local icon = entry:CreateTexture(nil, "OVERLAY")
      icon:SetSize(14, 14)
      icon:SetPoint("RIGHT", entry, "RIGHT", -150 + i * 17, 0)
      local bar = entry:CreateTexture(nil, "OVERLAY")
      bar:SetSize(14, 2)
      bar:SetPoint("TOP", icon, "BOTTOM", 0, -1)
      local crown = entry:CreateTexture(nil, "OVERLAY")
      crown:SetSize(9, 9)
      crown:SetPoint("BOTTOM", icon, "TOP", 0, -2)
      m[i] = { icon = icon, bar = bar, crown = crown }
    end
    GF.marks[entry] = m
  end
  return m
end
function GF.PaintMarks(entry, d)
  local m = marks(entry)
  local party = d.meta and d.meta.activity and (d.meta.activity.maxPlayers or 5) <= 5
  local list = (s.roleIcons ~= "off" and party) and GF.SortedMembers(d.meta.classes) or {}
  for i = 1, 5 do
    local slot, c = m[i], list[i]
    if c then
      local cc = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
      slot.icon:SetAtlas(ROLE_ATLAS[c.role or "DAMAGER"] or ROLE_ATLAS.DAMAGER)
      slot.icon:Show()
      if cc and s.roleIcons ~= "plain" then slot.bar:SetColorTexture(cc.r, cc.g, cc.b, 1); slot.bar:Show() else slot.bar:Hide() end
      if c.leader and s.leaderCrown then slot.crown:SetAtlas("groupfinder-icon-leader"); slot.crown:Show() else slot.crown:Hide() end
    else
      slot.icon:Hide(); slot.bar:Hide(); slot.crown:Hide()
    end
  end
  GF.lastMarks = #list
end
function GF.HideMarks(entry)
  local m = GF.marks[entry]
  if not m then return end
  for i = 1, 5 do m[i].icon:Hide(); m[i].bar:Hide(); m[i].crown:Hide() end
end

-- Post-hook on Blizzard's entry update: our own regions only.
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
  if not d then line:SetText(""); GF.HideMarks(entry); return end
  line:SetText(GF.Text(d))
  line:Show()
  GF.PaintMarks(entry, d)
  local c = GF.RowColor(d)
  local name = rawget(entry, "Name")
  if c and name and name.SetTextColor then name:SetTextColor(c.r, c.g, c.b) end
  entry:SetAlpha(GF.Dimmed(d) and s.dimAlpha or 1)
  if ns.Queue and ns.Queue.HookEntry then ns.Queue.HookEntry(entry) end
end

-- Structured tooltip section (post-hook on Blizzard's tooltip builder).
function GF.TooltipLines(d)
  local out = {}
  local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
  local classes = {}
  for _, c in ipairs(GF.SortedMembers(d.meta.classes)) do
    counts[c.role or "DAMAGER"] = (counts[c.role or "DAMAGER"] or 0) + 1
    if c.class then classes[c.class] = (classes[c.class] or 0) + 1 end
  end
  out[#out + 1] = string.format("Tanks %d   Healers %d   Damage %d", counts.TANK, counts.HEALER, counts.DAMAGER)
  if s.classNames then
    local names = {}
    for class, n in pairs(classes) do
      local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
      local names_ = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
      local label = (names_ and names_[class]) or class
      names[#names + 1] = (cc and cc.colorStr and ("|c" .. cc.colorStr .. label .. "|r") or label) .. (n > 1 and (" x" .. n) or "")
    end
    table.sort(names)
    if #names > 0 then out[#out + 1] = table.concat(names, ", ") end
  end
  local tail = {}
  if d.age then tail[#tail + 1] = "listed " .. d.age .. " min ago" end
  if d.score > 0 then tail[#tail + 1] = "leader " .. GF.ScoreText(d.score) end
  if d.declined then tail[#tail + 1] = "|cffff6060declined you before|r" end
  if #tail > 0 then out[#out + 1] = table.concat(tail, "   ") end
  return out
end
function GF.OnTooltip(tooltip, resultID)
  if not (GF.active and s.tooltip and tooltip and resultID) then return end
  local d = GF.Info(resultID)
  if not d then return end
  tooltip:AddLine(" ")
  tooltip:AddLine("|cffe8a33dPhoenix|r")
  for _, l in ipairs(GF.TooltipLines(d)) do tooltip:AddLine(l, 0.9, 0.9, 0.9, true) end
  tooltip:Show()
end

local hooked = {}
function GF.Hook()
  if not hooked.entry and rawget(_G, "LFGListSearchEntry_Update") then
    hooked.entry = true
    hooksecurefunc("LFGListSearchEntry_Update", GF.Decorate)
  end
  if not hooked.tip and rawget(_G, "LFGListUtil_SetSearchEntryTooltip") then
    hooked.tip = true
    hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", GF.OnTooltip)
  end
  if ns.Panel and ns.Panel.Hook then ns.Panel.Hook() end
  if ns.Queue and ns.Queue.Hook then ns.Queue.Hook() end
end

-- Current Blizzard search category -> Phoenix filter category.
function GF.CurrentCategory()
  local frame = rawget(_G, "LFGListFrame")
  local panel = frame and rawget(frame, "SearchPanel")
  local id = panel and rawget(panel, "categoryID")
  return Data.CATEGORY[id] or (id and "custom") or GF.category or "dungeon"
end

-- Refresh(): re-reads results, runs the filter, updates the panel.
function GF.Refresh()
  if not GF.active then return end
  GF.category = GF.CurrentCategory()
  local _, results = C_LFGList.GetSearchResults()
  local rows = {}
  for _, id in ipairs(results or {}) do
    local v, meta = Data.Vars(id, GF.WasDeclined)
    if v then rows[#rows + 1] = { id = id, vars = v, meta = meta } end
  end
  GF.rows = rows
  local shown, why, hidden = Filters.Evaluate(GF.category, rows, GF.FilterGet)
  GF.shown = Filters.Sort(shown, GF.FilterGet(GF.category, "sort"))
  GF.why, GF.hidden = why, hidden
  GF.countLine = Filters.CountLine(#shown, #rows, why)
  if ns.Panel and ns.Panel.Update then ns.Panel.Update() end
  PUI.Kernel:Fire("GROUPFINDER_RESULTS", #shown, #rows)
end

-- "Click to relax": turns off the chip that hides the most groups.
function GF.RelaxTop()
  local best, n
  for _, e in ipairs(GF.why.order or {}) do
    if (GF.why[e.id] or 0) > (n or 0) then best, n = e.id, GF.why[e.id] end
  end
  if not best then return nil end
  local cat = GF.category
  if best == "expression" then Schema:Set("gf." .. cat .. ".expr", "")
  elseif best == "dungeons" then Schema:Set("gf." .. cat .. ".dungeons", {})
  elseif best == "difficulty" or best == "bracket" then
    for _, f in ipairs(Filters.FIELDS) do if f.group == best and Filters.Applies(f, cat) then Schema:Set("gf." .. cat .. "." .. f.id, false) end end
  else
    local k = "gf." .. cat .. "." .. best
    if Schema:Def(k) then Schema:Set(k, Schema.Copy(Schema:Def(k).default)) end
    if best == "notDelisted" or best == "notDeclined" or Filters.BY_ID[best].kind == "on" then Schema:Set(k, false) end
  end
  return best
end

-- Server-side narrowing (opt-in). Blizzard's own filter is saved on first
-- write and restored when Phoenix stops narrowing.
function GF.ApplyFilter()
  if not GF.active then return end
  local wants = s.minRating > 0 or s.needMyRole
  if not wants and not GF.ownsFilter then return end
  local f = C_LFGList.GetAdvancedFilter()
  if type(f) ~= "table" then return end
  if wants and not GF.ownsFilter then
    Schema:Set("gf.priorFilter", { minimumRating = f.minimumRating or 0, needsTank = f.needsTank == true, needsHealer = f.needsHealer == true, needsDamage = f.needsDamage == true })
  end
  GF.ownsFilter = wants
  if wants then
    f.minimumRating = s.minRating
    local role = Data.MyRole()
    f.needsTank = s.needMyRole and role == "TANK" or false
    f.needsHealer = s.needMyRole and role == "HEALER" or false
    f.needsDamage = s.needMyRole and role == "DAMAGER" or false
  else
    local p = Schema:Get("gf.priorFilter")
    f.minimumRating = p.minimumRating or 0
    f.needsTank, f.needsHealer, f.needsDamage = p.needsTank == true, p.needsHealer == true, p.needsDamage == true
    Schema:Set("gf.priorFilter", {})
  end
  C_LFGList.SaveAdvancedFilter(f)
end

function GF.OnStatus(_, _, resultID, newStatus)
  if type(newStatus) ~= "string" then return end
  Data.status[resultID] = newStatus
  if newStatus ~= "declined" and newStatus ~= "declined_full" and newStatus ~= "declined_delisted" then return end
  local info = C_LFGList.HasSearchResultInfo(resultID) and C_LFGList.GetSearchResultInfo(resultID)
  local leader = info and info.leaderName
  if type(leader) ~= "string" or Secret.IsSecret(leader) then return end
  local list = declinedList()
  list[leader] = time()
  local n, oldest, oldKey = 0
  for k, t in pairs(list) do n = n + 1; if not oldest or t < oldest then oldest, oldKey = t, k end end
  if n > 200 and oldKey then list[oldKey] = nil end
  Schema:Set("gf.declined", list)
end

function GF.OnResults()
  local _, results = C_LFGList.GetSearchResults()
  Data.MarkSearch(results)
  GF.Refresh()
  if not s.sound then GF.primed = true; return end
  local fresh = false
  for _, id in ipairs(results or {}) do
    if not GF.seen[id] then
      GF.seen[id] = true
      local d = GF.Info(id)
      if d and d.fits and not GF.Dimmed(d) then fresh = true end
    end
  end
  if fresh and GF.primed then Media:Alert(SOUNDKIT.RAID_WARNING) end
  GF.primed = true
end

-- Presets: named filter sets per category (/pui lfg save|filter <name>).
function GF.SavePreset(name)
  if type(name) ~= "string" or name == "" then return false end
  local cat = GF.category or "dungeon"
  local all = Schema:Get("gf.presets")
  all[cat] = all[cat] or {}
  local p = {}
  for _, f in ipairs(Filters.FIELDS) do if Filters.Applies(f, cat) then p[f.id] = Schema.Copy(fs[cat][f.id]) end end
  p.expr, p.dungeons, p.sort = fs[cat].expr, Schema.Copy(fs[cat].dungeons), fs[cat].sort
  all[cat][name:lower()] = p
  Schema:Set("gf.presets", all)
  return true
end
function GF.LoadPreset(name, cat)
  cat = cat or GF.category or "dungeon"
  local all = Schema:Get("gf.presets")
  local p = all[cat] and all[cat][(name or ""):lower()]
  if not p then return false end
  for k, v in pairs(p) do if Schema:Def("gf." .. cat .. "." .. k) then Schema:Set("gf." .. cat .. "." .. k, Schema.Copy(v)) end end
  return true
end

PUI.Slash:Register("lfg", function(rest)
  local verb, arg = (rest or ""):match("^(%S*)%s*(.-)%s*$")
  if verb == "filter" then PUI.Slash.Print(GF.LoadPreset(arg) and ("filter preset: " .. arg) or ("no preset named " .. arg))
  elseif verb == "save" then PUI.Slash.Print(GF.SavePreset(arg) and ("saved preset: " .. arg) or "name the preset: /pui lfg save <name>")
  elseif verb == "why" then PUI.Slash.Print(GF.countLine or "no search yet")
  else PUI.Slash.Print("/pui lfg filter <preset> | save <name> | why") end
end, "Group Finder filter presets and the hidden-count line")

local function onEnable(mod)
  GF.active = true
  Data.SeedSeason()
  GF.Hook()
  mod:RegisterEvent("ADDON_LOADED", function() GF.Hook() end)
  mod:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", function(...) GF.OnStatus(...); if ns.Queue then ns.Queue.OnApplication(...) end end)
  mod:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", GF.OnResults)
  mod:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED", function() GF.Refresh() end)
  if ns.Queue then ns.Queue.Enable(mod) end
  GF.ApplyFilter()
end
local function onDisable()
  for entry, line in pairs(GF.lines) do line:Hide(); entry:SetAlpha(1) end
  for entry in pairs(GF.marks) do GF.HideMarks(entry) end
  wipe(GF.seen); GF.primed = nil
  if GF.ownsFilter then
    local a, b = s.minRating, s.needMyRole
    s.minRating, s.needMyRole = 0, false
    GF.ApplyFilter()
    s.minRating, s.needMyRole = a, b
  end
  GF.active = false
  if ns.Panel and ns.Panel.Hide then ns.Panel.Hide() end
  if ns.Queue then ns.Queue.Disable() end
end

-- Schema ----------------------------------------------------------------------
local schema = {}
GF.schema = schema
ns.schema = schema
local LIVE = { minRating = true, needMyRole = true }
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(value)
    s[name] = value
    if LIVE[name] then GF.ApplyFilter() end
    if GF.active then GF.Refresh() end
  end
  schema["gf." .. name] = def
end
GF.key = key
key("scoreColor", { type = "toggle", default = true, label = "Leader score", tooltip = "Shows the leader's Mythic+ score in the colour source you picked (Blizzard, Raider.IO or your own gradient).", mode = "simple" })
key("bestKey", { type = "toggle", default = true, label = "Leader's best key", tooltip = "Adds the leader's best timed key level in that dungeon next to the score." })
key("missingRoles", { type = "toggle", default = true, label = "Missing roles", tooltip = "Shows which roles the group still needs.", mode = "simple" })
key("roleFit", { type = "toggle", default = true, label = "Role fit", tooltip = "Shows whether your current role still fits the group.", mode = "simple" })
key("age", { type = "toggle", default = true, label = "Group age", tooltip = "Shows how many minutes ago the group was listed." })
key("roleIcons", { type = "select", default = "icons", choices = { "icons", "plain", "off" },
  choiceLabels = { icons = "Role icons with class colour bar", plain = "Role icons only", off = "Off" },
  label = "Member indicators", tooltip = "Role icons for each member in tank, healer, damage order, with an optional class colour bar.", mode = "simple" })
key("leaderCrown", { type = "toggle", default = true, label = "Leader crown", tooltip = "Marks the group leader above their role icon." })
key("rowColors", { type = "toggle", default = true, label = "Row colours", tooltip = "Colours a group's name: new since your last search, declined you, cancelled or delisted. Each colour is its own setting." })
key("declined", { type = "toggle", default = true, label = "Declined memory", tooltip = "Remembers leaders who declined you and marks their groups." })
key("dim", { type = "toggle", default = true, label = "Dim filtered groups", tooltip = "Dims Blizzard rows your filter or minimum rating rejects. Blizzard's list itself is never changed.", mode = "simple" })
key("dimAlpha", { type = "range", default = 0.45, min = 0.1, max = 0.9, step = 0.05, label = "Dim strength", tooltip = "How visible a filtered row stays (lower is fainter)." })
key("tooltip", { type = "toggle", default = true, label = "Group tooltip section", tooltip = "Adds roles in fixed order, class-coloured counts, age, leader score and decline memory to the group tooltip." })
key("classNames", { type = "toggle", default = true, label = "Class names in tooltip", tooltip = "Lists the classes in the group, class-coloured, in the tooltip section." })
key("minRating", { type = "range", default = 0, min = 0, max = 4000, step = 50, label = "Also narrow Blizzard's search: minimum rating",
  tooltip = "Writes Blizzard's own server-side minimum rating filter. Your previous Blizzard filter is saved and put back when this returns to 0." })
key("needMyRole", { type = "toggle", default = false, label = "Also narrow Blizzard's search: needs my role",
  tooltip = "Blizzard's server-side filter for groups missing your current role. Your previous Blizzard filter is restored when turned off." })
key("sound", { type = "toggle", default = false, label = "New group sound", tooltip = "Plays a sound when a new group that fits you shows up in a refreshed search." })

local function color(name, label, r, g, b)
  schema["gf.color." .. name] = { type = "color", default = { r = r, g = g, b = b, a = 1 }, owner = OWNER, mode = "advanced", label = label,
    tooltip = "Row colour used when row colours are on. The sample rows on this page show it live.", apply = function() if GF.active then GF.Refresh() end end }
end
color("new", "Colour: new group", 0.35, 0.9, 0.45)
color("declined", "Colour: declined you", 1, 0.45, 0.25)
color("cancelled", "Colour: you cancelled", 1, 0.45, 0.8)
color("delisted", "Colour: delisted", 0.55, 0.55, 0.55)

-- One block of filter keys per category.
for _, cat in ipairs(Filters.CATS) do
  fs[cat] = {}
  local C = fs[cat]
  local catLabel = Filters.CAT_LABEL[cat]
  local function fkey(id, def)
    def.owner = OWNER
    def.mode = def.mode or "advanced"
    def.searchTags = { "filter", "group finder", "lfg", cat }
    def.apply = function(v) C[id] = v; Filters.ForgetCompiled(); if GF.active then GF.Refresh() end end
    schema["gf." .. cat .. "." .. id] = def
  end
  fkey("enabled", { type = "toggle", default = true, label = catLabel .. ": Phoenix filter on", tooltip = "Turns the Phoenix filter for this category on or off without losing your chips.", mode = "simple" })
  for _, f in ipairs(Filters.FIELDS) do
    if Filters.Applies(f, cat) then
      local off = (f.kind == "max") and ("Off at " .. f.max .. ".") or (f.kind == "on" or f.kind == "any") and "Off when unticked." or "Off at 0."
      if f.kind == "on" or f.kind == "any" then
        fkey(f.id, { type = "toggle", default = f.default == true, label = catLabel .. ": " .. f.label,
          tooltip = "Filter chip. " .. off .. (f.group and (" Ticks in the same " .. f.group .. " row mean any of them.") or ""), mode = f.simple and "simple" or "advanced" })
      else
        fkey(f.id, { type = "range", default = f.kind == "max" and f.max or 0, min = 0, max = f.max, step = f.step or 1, label = catLabel .. ": " .. f.label,
          tooltip = "Filter chip. " .. off, mode = f.simple and "simple" or "advanced" })
      end
    end
  end
  if cat == "dungeon" or cat == "raid" or cat == "delve" then
    fkey("dungeons", { type = "list", default = {}, maxItems = 40, label = catLabel .. ": only these",
      tooltip = "Words for the dungeons, raids or delves to keep (see the word list in the help panel; the season's words are added live). Empty keeps all.", mode = "simple" })
  end
  fkey("expr", { type = "text", default = "", label = catLabel .. ": expression",
    tooltip = "Extra rule in Phoenix's filter words, e.g. 'mprating >= 2600 and partyfit'. Checked as you type; mistakes are explained in plain words." })
  fkey("sort", { type = "text", default = "", label = catLabel .. ": sort",
    tooltip = "Order of Phoenix's list, e.g. 'mprating desc, age asc'. Empty keeps Blizzard's order." })
end
schema["gf.declined"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Declined leaders", tooltip = "Leaders who declined you (newest 200).", apply = function() end }
schema["gf.presets"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Filter presets", tooltip = "Named filter presets per category.", apply = function() end }
schema["gf.priorFilter"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Your Blizzard filter", tooltip = "Blizzard filter values saved before Phoenix narrowed the search.", apply = function() end }

-- Conflict with Premade Groups Filter (D-PGF): the player picks; nothing changes before.
local ckey, cdef = PUI.Coexist:Define("groupfinder", { module = OWNER, job = "Group finder filtering", addons = { "PremadeGroupsFilter" } })
cdef.owner = OWNER
schema[ckey] = cdef
GF.coexistKey = ckey

-- Registered by the last file (QueueHelper.lua) once every key is in.
function GF.Register()
  GF.module = PUI:RegisterModule(OWNER, {
    label = "Group Finder", tooltip = "Filter builder with a why-hidden count, Phoenix's own sorted list, row colours, role indicators and the queue helper. Asks before sharing the job with Premade Groups Filter.",
    enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
    loadCondition = function() return PUI.Coexist:Allows("groupfinder") end,
  })
  for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
end
