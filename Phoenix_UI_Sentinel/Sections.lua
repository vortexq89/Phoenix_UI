local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Sections: the error log organised per addon (Phoenix first, then every
-- other addon, Blizzard and Unknown), copy formats (plain, Markdown,
-- Discord), local conflict hints, clear-this-session, the addon list for
-- uploads and the launchers (addon compartment + LibDataBroker when present).
-- Pure functions over S.Store lists, so the viewer and the tests share them.
local S = PUI.Sentinel
local Sections = {}
S.Sections = Sections

local PHOENIX = "Phoenix_UI"
Sections.PHOENIX = PHOENIX
Sections.SEVERITIES = { "S0", "S1", "S2", "S3" }

-- Addon a stored incident belongs to.
function Sections.AddonOf(inc)
  if inc.other then return inc.addon or "Unknown" end
  return PHOENIX
end

local function sevOk(inc, sev) return not sev or sev == "all" or (inc.severity or (inc.other and "S2")) == sev end

-- Groups(opts) -> { { addon, errors = {...}, count, events, firstSeen, lastSeen, sessions = "3, 4", phoenix } }
-- Phoenix first, then by events (most first), then by name. opts as Store:List plus opts.severity.
function Sections:Groups(opts)
  local byAddon, order = {}, {}
  for _, inc in ipairs(S.Store:List(opts)) do
    if sevOk(inc, opts and opts.severity) then
      local name = Sections.AddonOf(inc)
      local g = byAddon[name]
      if not g then
        g = { addon = name, errors = {}, count = 0, events = 0, phoenix = name == PHOENIX, sessionSet = {} }
        byAddon[name] = g; order[#order + 1] = g
      end
      g.errors[#g.errors + 1] = inc
      g.count = g.count + 1
      g.events = g.events + (inc.count or 1)
      if not g.firstSeen or (inc.firstSeen or 0) < g.firstSeen then g.firstSeen = inc.firstSeen end
      if not g.lastSeen or (inc.lastSeen or 0) > g.lastSeen then g.lastSeen = inc.lastSeen end
      for _, s in ipairs({ inc.session, inc.lastSession }) do if s then g.sessionSet[s] = true end end
    end
  end
  for _, g in ipairs(order) do
    local list = {}
    for s in pairs(g.sessionSet) do list[#list + 1] = s end
    table.sort(list)
    for i = 1, #list do list[i] = tostring(list[i]) end
    g.sessions = table.concat(list, ", ")
    g.sessionSet = nil
  end
  table.sort(order, function(a, b)
    if a.phoenix ~= b.phoenix then return a.phoenix end
    if a.events ~= b.events then return a.events > b.events end
    return a.addon < b.addon
  end)
  return order
end

-- Severity chip counts for the filter row.
function Sections:SeverityCounts(opts)
  local t = { all = 0 }
  for _, inc in ipairs(S.Store:List(opts)) do
    local sev = inc.severity or (inc.other and "S2") or "S2"
    t[sev] = (t[sev] or 0) + 1; t.all = t.all + 1
  end
  return t
end

-- Phoenix vs other addons split (events and distinct errors).
function Sections:Split(opts)
  local t = { phoenix = 0, others = 0, phoenixEvents = 0, otherEvents = 0 }
  for _, inc in ipairs(S.Store:List(opts)) do
    if inc.other then t.others = t.others + 1; t.otherEvents = t.otherEvents + (inc.count or 1)
    else t.phoenix = t.phoenix + 1; t.phoenixEvents = t.phoenixEvents + (inc.count or 1) end
  end
  return t
end

-- Conflict hints: other addons whose errors happened in the same sessions as
-- Phoenix errors, ranked by shared sessions then events. Blizzard/Unknown are
-- listed too but never ranked above a named addon with the same score.
function Sections:Conflicts()
  local phoenixSessions = {}
  for _, inc in ipairs(S.Store:List({ session = "all", source = "phoenix" })) do
    for _, s in ipairs({ inc.session, inc.lastSession }) do if s then phoenixSessions[s] = true end end
  end
  local score = {}
  for _, inc in ipairs(S.Store:List({ session = "all", source = "others" })) do
    local hit = {}
    for _, s in ipairs({ inc.session, inc.lastSession }) do if s and phoenixSessions[s] then hit[s] = true end end
    if next(hit) then
      local a = inc.addon or "Unknown"
      local c = score[a] or { addon = a, shared = {}, events = 0 }
      for s in pairs(hit) do c.shared[s] = true end
      c.events = c.events + (inc.count or 1)
      score[a] = c
    end
  end
  local out = {}
  for _, c in pairs(score) do
    local n = 0
    for _ in pairs(c.shared) do n = n + 1 end
    out[#out + 1] = { addon = c.addon, sessions = n, events = c.events, generic = c.addon == "Blizzard" or c.addon == "Unknown" }
  end
  table.sort(out, function(a, b)
    if a.sessions ~= b.sessions then return a.sessions > b.sessions end
    if a.generic ~= b.generic then return not a.generic end
    if a.events ~= b.events then return a.events > b.events end
    return a.addon < b.addon
  end)
  return out
end

-- Copy formats -----------------------------------------------------------------
Sections.FORMATS = { "plain", "markdown", "discord" }
local function stamp(t) return t and date("%Y-%m-%d %H:%M", t) or "?" end
local function fence(text, lang)
  local s = tostring(text or "")
  local ticks = "```"
  while s:find(ticks, 1, true) do ticks = ticks .. "`" end
  return ticks .. (lang or "") .. "\n" .. s .. "\n" .. ticks
end

-- One error in a format. Discord keeps under its 2000-character message cap.
function Sections.ErrorText(inc, fmt)
  fmt = fmt or "plain"
  local head = string.format("[%s] x%d %s  (session %s, %s -> %s)", Sections.AddonOf(inc), inc.count or 1, inc.severity or "", tostring(inc.lastSession or inc.session or "?"),
    stamp(inc.firstSeen), stamp(inc.lastSeen))
  if fmt == "markdown" then
    local parts = { "**" .. Sections.AddonOf(inc) .. "** x" .. (inc.count or 1) .. " " .. (inc.severity or ""), fence(inc.message, "text"), "Stack:", fence(inc.stack ~= "" and inc.stack or "(none)", "lua") }
    if inc.locals and inc.locals ~= "" then parts[#parts + 1] = "Locals:"; parts[#parts + 1] = fence(inc.locals, "lua") end
    parts[#parts + 1] = "_session " .. tostring(inc.lastSession or inc.session or "?") .. " - " .. stamp(inc.firstSeen) .. " -> " .. stamp(inc.lastSeen) .. "_"
    return table.concat(parts, "\n")
  elseif fmt == "discord" then
    local body = tostring(inc.message or "") .. "\n" .. tostring(inc.stack or "")
    local text = "**" .. Sections.AddonOf(inc) .. "** x" .. (inc.count or 1) .. "\n" .. fence(body:sub(1, 1700), "lua")
    return text:sub(1, 1990)
  end
  return head .. "\n" .. tostring(inc.message or "") .. "\nStack:\n" .. ((inc.stack and inc.stack ~= "") and inc.stack or "(none)")
    .. "\nLocals:\n" .. ((inc.locals and inc.locals ~= "") and inc.locals or "(none)")
end

function Sections.GroupHeader(g)
  return string.format("%s - %d error%s, %d event%s - first %s, last %s - session%s %s", g.addon, g.count, g.count == 1 and "" or "s", g.events, g.events == 1 and "" or "s",
    stamp(g.firstSeen), stamp(g.lastSeen), g.sessions:find(",") and "s" or "", g.sessions ~= "" and g.sessions or "?")
end

function Sections.GroupText(g, fmt)
  local sep = fmt == "plain" and "\n\n----\n\n" or "\n\n"
  local parts = { (fmt == "plain" and "== " or "## ") .. Sections.GroupHeader(g) .. (fmt == "plain" and " ==" or "") }
  for i = 1, #g.errors do parts[#parts + 1] = Sections.ErrorText(g.errors[i], fmt) end
  return table.concat(parts, sep)
end

function Sections:AllText(opts, fmt)
  local groups = self:Groups(opts)
  if #groups == 0 then return "No errors here." end
  local parts = {}
  for i = 1, #groups do parts[i] = Sections.GroupText(groups[i], fmt) end
  return table.concat(parts, "\n\n")
end

-- Clear only this session's errors (BugSack "clear session"); Store:Wipe clears all.
function Sections:ClearSession()
  local db = S.Store:DB()
  local cur = db.session
  local n = 0
  for _, src in ipairs({ db.incidents, db.others }) do
    for hash, inc in pairs(src) do
      if inc.kind ~= "heartbeat" and (inc.lastSession or inc.session) == cur then src[hash] = nil; n = n + 1 end
    end
  end
  return n
end

-- Loaded addon list for uploads: folder name, version, enabled, loaded.
function Sections.AddonInventory(max)
  local out = {}
  local storable = PUI.Secret.Storable
  local n = C_AddOns.GetNumAddOns()
  for i = 1, n do
    local name = C_AddOns.GetAddOnInfo(i)
    if type(name) == "string" then
      local state = C_AddOns.GetAddOnEnableState and C_AddOns.GetAddOnEnableState(i) or 2
      out[#out + 1] = { name = storable(name, 64), version = storable(C_AddOns.GetAddOnMetadata(i, "Version") or "", 32),
        enabled = (tonumber(state) or 0) > 0, loaded = C_AddOns.IsAddOnLoaded(i) and true or false }
      if #out >= (max or 300) then break end
    end
  end
  return out
end

-- Launchers ------------------------------------------------------------------
-- The addon compartment entry (retail) and an LDB launcher when a broker
-- display is installed; both show the count of new errors and open the viewer.
function Sections.LauncherText()
  local c = S.Store:Counts()
  return string.format("Sentinel: %d new, %d this session", (S.Alerts and S.Alerts.unseen) or 0, c.session)
end
function Sections:RegisterLaunchers()
  if self.launched then return end
  self.launched = true
  local open = function() S.Reporter:Toggle() end
  local comp = rawget(_G, "AddonCompartmentFrame")
  if comp and type(comp.RegisterAddon) == "function" then
    comp:RegisterAddon({ text = "Phoenix Sentinel", icon = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Modules\\64\\sentinel", notCheckable = true, func = open,
      funcOnEnter = function(button)
        GameTooltip:SetOwner(button, "ANCHOR_LEFT"); GameTooltip:SetText(Sections.LauncherText()); GameTooltip:Show()
      end,
      funcOnLeave = function() GameTooltip:Hide() end })
    self.compartment = true
  end
  local stub = rawget(_G, "LibStub")
  local ldb = stub and stub("LibDataBroker-1.1", true)
  if ldb then
    self.broker = ldb:NewDataObject("PhoenixSentinel", { type = "launcher", label = "Sentinel", text = Sections.LauncherText(),
      icon = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Icons\\Modules\\64\\sentinel", OnClick = open,
      OnTooltipShow = function(tt) tt:AddLine(Sections.LauncherText()) end })
  end
end
function Sections:RefreshLaunchers()
  if self.broker then self.broker.text = Sections.LauncherText() end
end
