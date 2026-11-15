local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group Finder queue helper (AutoQueue parity, plan 1.O "Role-check accept,
-- sign-up confirm, role per spec" and "Queue-pop countdown"):
--  * role checks accepted for you, the sign-up dialog confirmed for you (hold
--    Shift to choose yourself) and double-click a group to sign up. These three
--    start ON (D-MOD-DEF2); each tooltip explains the taint risk as info.
--  * one role-per-spec setting: manual, auto from spec, or your own list.
--  * the docked role bar (lock icons for roles your class cannot play).
--  * a big Enter button and countdown bar when a dungeon or battleground
--    invite pops. Phoenix never presses it for you: entering is your click.
--  * the countdown itself comes from PUI.Queue (Core), the one provider the
--    minimap queue eye and the queue popup skin also read.
-- Event-driven only; the countdown text runs on a Ticker entry while shown.
local _, ns = ...
local Schema, Ticker, Secret = PUI.Schema, PUI.Ticker, PUI.Secret
local GF, Data = ns.GF, ns.Data
local OWNER = "GroupFinder"
local Q = { active = false, hooked = {}, entries = setmetatable({}, { __mode = "k" }), applications = {}, log = {} }
ns.Queue = Q
GF.Queue = Q
local s = { enabled = true, roleCheck = true, autoConfirm = true, doubleClick = true, rolePerSpec = "manual", specRoles = {},
  roleBar = true, roleBarCollapsed = false, enterButton = true, popBar = true, popSound = false, chatConfirm = false,
  autoInvite = false, inviteWords = "inv, invite", warnAt = 10 }
Q.settings = s

local function did(what) Q.log[#Q.log + 1] = what; if #Q.log > 30 then table.remove(Q.log, 1) end end
function Q.Yields() return PUI.Coexist:Yields("gf.queue") end
local function on(name) return Q.active and s.enabled and s[name] and not Q.Yields() end
Q.On = on

-- Role per spec -----------------------------------------------------------------
-- WantedRoles() -> tank, healer, dps booleans, or nil when the setting is manual.
function Q.ParseSpecRoles(list)
  local map = {}
  for _, item in ipairs(list or {}) do
    local spec, roles = tostring(item):match("^%s*(%d+)%s*=%s*(.-)%s*$")
    if spec then
      local r = { tank = false, healer = false, dps = false }
      for word in roles:upper():gmatch("[%a]+") do
        if word == "TANK" then r.tank = true elseif word == "HEALER" or word == "HEAL" then r.healer = true elseif word == "DPS" or word == "DAMAGER" then r.dps = true end
      end
      map[tonumber(spec)] = r
    end
  end
  return map
end
function Q.WantedRoles()
  if s.rolePerSpec == "manual" then return nil end
  if s.rolePerSpec == "auto" and C_AddOns.IsAddOnLoaded("BigWigs") then return nil, "BigWigs sets roles" end
  local index = C_SpecializationInfo.GetSpecialization()
  local specID = index and C_SpecializationInfo.GetSpecializationInfo(index)
  if s.rolePerSpec == "custom" then
    local r = specID and Q.ParseSpecRoles(s.specRoles)[specID]
    if r then return r.tank, r.healer, r.dps end
  end
  local role = Data.MyRole()
  return role == "TANK", role == "HEALER", role == "DAMAGER"
end
function Q.ApplyRoles()
  if not on("enabled") then return false end
  local t, h, d = Q.WantedRoles()
  if t == nil or not rawget(_G, "SetLFGRoles") then return false end
  local leader = rawget(_G, "GetLFGRoles") and select(1, GetLFGRoles()) or false
  SetLFGRoles(leader, t, h, d)
  did("roles")
  return true
end

-- Role check, sign-up dialog, double-click -----------------------------------------
function Q.OnRoleCheck()
  if not on("roleCheck") then return end
  Q.ApplyRoles()
  if rawget(_G, "CompleteLFGRoleCheck") then CompleteLFGRoleCheck(true); did("roleCheck") end
  if s.chatConfirm then Q.PrintRoles() end
end
function Q.PrintRoles()
  if not rawget(_G, "GetLFGRoles") then return end
  local _, t, h, d = GetLFGRoles()
  local parts = {}
  if t then parts[#parts + 1] = "|A:" .. GF.ROLE_ATLAS.TANK .. ":14:14|a Tank" end
  if h then parts[#parts + 1] = "|A:" .. GF.ROLE_ATLAS.HEALER .. ":14:14|a Healer" end
  if d then parts[#parts + 1] = "|A:" .. GF.ROLE_ATLAS.DAMAGER .. ":14:14|a Damage" end
  PUI.Slash.Print("signed up as " .. (#parts > 0 and table.concat(parts, ", ") or "no role"))
end

function Q.OnApplicationDialog(dialog)
  if not on("autoConfirm") or IsShiftKeyDown() then return end
  Q.ApplyRoles()
  local button = dialog and rawget(dialog, "SignUpButton")
  if button and button:IsEnabled() then button:Click(); did("autoConfirm") end
end

function Q.SignUp(resultID)
  local frame = rawget(_G, "LFGListFrame")
  local panel = frame and rawget(frame, "SearchPanel")
  if not (panel and resultID and rawget(_G, "LFGListSearchPanel_SelectResult") and rawget(_G, "LFGListSearchPanel_SignUp")) then return false end
  LFGListSearchPanel_SelectResult(panel, resultID)
  LFGListSearchPanel_SignUp(panel)
  did("doubleClick")
  return true
end
function Q.HookEntry(entry)
  if Q.entries[entry] then return end
  Q.entries[entry] = true
  entry:HookScript("OnDoubleClick", function(self) if on("doubleClick") and self.resultID then Q.SignUp(self.resultID) end end)
end

function Q.Hook()
  if not Q.hooked.dialog and rawget(_G, "LFGListApplicationDialog_Show") then
    Q.hooked.dialog = true
    hooksecurefunc("LFGListApplicationDialog_Show", Q.OnApplicationDialog)
  end
  if not Q.bar and rawget(_G, "PVEFrame") then Q.BuildRoleBar() end
end

-- Applications count (Blizzard allows 5 at once).
Q.MAX_APPS = 5
function Q.OnApplication(_, _, resultID, newStatus)
  if type(newStatus) ~= "string" or not resultID then return end
  if newStatus == "applied" then Q.applications[resultID] = GetTime()
  else Q.applications[resultID] = nil end
  if ns.Panel and ns.Panel.Update then ns.Panel.Update() end
end
function Q.ApplicationCount()
  local n, oldest, oldID = 0
  for id, t in pairs(Q.applications) do n = n + 1; if not oldest or t < oldest then oldest, oldID = t, id end end
  return n, oldID
end

-- Auto-invite on keywords (opt-in; friends, guild and Battle.net only).
function Q.InviteWords()
  local list = {}
  for w in (s.inviteWords or ""):gmatch("[^,]+") do
    w = w:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if w ~= "" then list[#list + 1] = w end
  end
  return list
end
function Q.MatchesInvite(text)
  if type(text) ~= "string" or Secret.IsSecret(text) then return false end
  local t = text:gsub("^%s+", ""):gsub("%s+$", ""):lower()
  for _, w in ipairs(Q.InviteWords()) do if t == w then return true end end
  return false
end
function Q.OnWhisper(_, _, text, sender, _, _, _, _, _, _, _, _, _, guid)
  if not on("autoInvite") then return end
  if not Q.MatchesInvite(text) or type(sender) ~= "string" or Secret.IsSecret(sender) then return end
  local trusted = PUI.Flow and PUI.Flow.IsTrusted and PUI.Flow.IsTrusted(guid)
  if not trusted then return end
  if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
  if C_PartyInfo.CanInvite() then C_PartyInfo.InviteUnit(sender); did("invite") end
end

-- Enter button + countdown bar --------------------------------------------------------
local Kit
function Q.BuildPop()
  if Q.pop then return Q.pop end
  local f = PUI:CreateFrame("Button", "PhoenixUIQueueEnter", UIParent, nil, OWNER)
  f:SetSize(260, 64)
  f:SetPoint("TOP", UIParent, "TOP", 0, -190)
  f:SetFrameStrata("DIALOG")
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  f.bg:SetColorTexture(0.06, 0.07, 0.08, 0.92)
  f.edge = f:CreateTexture(nil, "BORDER")
  f.edge:SetPoint("TOPLEFT", -1, 1); f.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  f.edge:SetColorTexture(0.91, 0.64, 0.24, 0.9)
  f.label = f:CreateFontString(nil, "OVERLAY")
  f.label:SetFontObject(PUI.Media:FontObject("header"))
  f.label:SetPoint("TOP", 0, -10)
  f.time = f:CreateFontString(nil, "OVERLAY")
  f.time:SetFontObject(PUI.Media:FontObject("small"))
  f.time:SetPoint("TOP", f.label, "BOTTOM", 0, -4)
  f.bar = CreateFrame("StatusBar", nil, f)
  f.bar:SetPoint("BOTTOMLEFT", 6, 6); f.bar:SetPoint("BOTTOMRIGHT", -6, 6)
  f.bar:SetHeight(5)
  f.bar:SetStatusBarTexture(PUI.Bars and PUI.Bars.TexturePath and PUI.Bars:TexturePath() or "Interface\\Buttons\\WHITE8x8")
  f.bar:SetMinMaxValues(0, 1)
  f:SetScript("OnClick", function() Q.Enter() end)
  f:Hide()
  Q.pop = f
  return f
end

-- Entering is always the player's own click on this button.
function Q.Enter()
  local p = PUI.Queue:Pop()
  if not p then return false end
  if p.kind == "lfg" and rawget(_G, "AcceptProposal") then AcceptProposal() end
  if p.kind == "pvp" then
    local n = rawget(_G, "GetMaxBattlefieldID") and GetMaxBattlefieldID() or 0
    for i = 1, n do if GetBattlefieldStatus(i) == "confirm" and rawget(_G, "AcceptBattlefieldPort") then AcceptBattlefieldPort(i, true) end end
  end
  Q.HidePop()
  return true
end

function Q.PopText(left, total, kind)
  local label = kind == "pvp" and "ENTER BATTLE" or "ENTER DUNGEON"
  return label, string.format("%d s left", math.max(0, math.ceil(left or 0))), total and total > 0 and (left or 0) / total or 0
end
function Q.TickPop()
  local f = Q.pop
  local p = PUI.Queue:Pop()
  if not (f and p) then Q.HidePop(); return end
  local left = PUI.Queue:Remaining() or 0
  local label, time, frac = Q.PopText(left, p.total, p.kind)
  f.label:SetText(label)
  f.time:SetText(s.popBar and time or "")
  f.bar:SetValue(frac)
  if s.popBar then f.bar:Show() else f.bar:Hide() end
  if left <= s.warnAt then f.bar:SetStatusBarColor(0.95, 0.3, 0.25) else f.bar:SetStatusBarColor(0.91, 0.64, 0.24) end
  if left <= 0 then Q.HidePop() end
end
function Q.ShowPop()
  if not (on("enterButton") or on("popBar")) then return end
  local f = Q.BuildPop()
  f:SetShown(true)
  if not s.enterButton then f:EnableMouse(false) else f:EnableMouse(true) end
  Q.TickPop()
  Ticker:Register("gf.queuepop", 0.2, Q.TickPop, OWNER)
  if s.popSound then PUI.Media:Alert(SOUNDKIT.READY_CHECK) end
  did("pop")
end
function Q.HidePop()
  Ticker:Unregister("gf.queuepop")
  if Q.pop then Q.pop:Hide() end
end
function Q.OnQueueChanged(pop)
  if not Q.active then return end
  if pop then Q.ShowPop() else Q.HidePop() end
end
PUI.Kernel:On("QUEUE_CHANGED", function(pop) Q.OnQueueChanged(pop) end)

-- Role bar (docked above the group finder) --------------------------------------------
local ROLES = { { id = "tank", atlas = "roleicon-tiny-tank", label = "Tank" }, { id = "healer", atlas = "roleicon-tiny-healer", label = "Healer" },
  { id = "dps", atlas = "roleicon-tiny-dps", label = "Damage" } }
function Q.AvailableRoles()
  if rawget(_G, "GetAvailableRoles") then
    local t, h, d = GetAvailableRoles()
    return { tank = t ~= false, healer = h ~= false, dps = d ~= false }
  end
  return { tank = true, healer = true, dps = true }
end
function Q.CurrentRoles()
  if not rawget(_G, "GetLFGRoles") then return { tank = false, healer = false, dps = false } end
  local _, t, h, d = GetLFGRoles()
  return { tank = t == true, healer = h == true, dps = d == true }
end
function Q.ToggleRole(id)
  local avail = Q.AvailableRoles()
  if not avail[id] or not rawget(_G, "SetLFGRoles") then return false end
  local cur = Q.CurrentRoles()
  cur[id] = not cur[id]
  local leader = select(1, GetLFGRoles())
  SetLFGRoles(leader, cur.tank, cur.healer, cur.dps)
  Q.PaintRoleBar()
  return true
end
function Q.BuildRoleBar()
  local parent = rawget(_G, "PVEFrame")
  if not parent or Q.bar then return end
  local bar = PUI:CreateFrame("Frame", nil, parent, nil, OWNER)
  bar:SetSize(250, 30)
  bar:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 60, 2)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  bar.bg:SetColorTexture(0.06, 0.07, 0.08, 0.9)
  bar.buttons = {}
  for i, r in ipairs(ROLES) do
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(64, 24)
    b:SetPoint("LEFT", bar, "LEFT", 6 + (i - 1) * 68, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT", 4, 0); b.icon:SetAtlas(r.atlas)
    b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFontObject(PUI.Media:FontObject("small")); b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    b.lock = b:CreateTexture(nil, "OVERLAY"); b.lock:SetSize(12, 12); b.lock:SetPoint("RIGHT", -2, 0); b.lock:SetAtlas("Garr_LockedBuilding")
    b.sel = b:CreateTexture(nil, "BACKGROUND"); b.sel:SetAllPoints(); b.sel:SetColorTexture(0.91, 0.64, 0.24, 0.25)
    b:SetScript("OnClick", function() Q.ToggleRole(r.id) end)
    b.role = r
    bar.buttons[i] = b
  end
  bar.collapse = CreateFrame("Button", nil, bar)
  bar.collapse:SetSize(20, 20)
  bar.collapse:SetPoint("RIGHT", -4, 0)
  bar.collapse.text = bar.collapse:CreateFontString(nil, "OVERLAY")
  bar.collapse.text:SetFontObject(PUI.Media:FontObject("small"))
  bar.collapse.text:SetPoint("CENTER")
  bar.collapse:SetScript("OnClick", function() Schema:Set("gf.q.roleBarCollapsed", not s.roleBarCollapsed) end)
  Q.bar = bar
  if not Schema:Get("gf.q.tipShown") then
    Schema:Set("gf.q.tipShown", true)
    PUI.Slash.Print("Group Finder: the role bar above the window sets your roles. Locked roles are ones your class cannot play. Collapse it with -.")
  end
  Q.PaintRoleBar()
end
function Q.PaintRoleBar()
  local bar = Q.bar
  if not bar then return end
  local show = on("roleBar")
  bar:SetShown(show and true or false)
  if not show then return end
  local avail, cur = Q.AvailableRoles(), Q.CurrentRoles()
  for _, b in ipairs(bar.buttons) do
    local id = b.role.id
    b:SetShown(not s.roleBarCollapsed)
    b.text:SetText(b.role.label)
    b.lock:SetShown(not avail[id])
    b.sel:SetShown(cur[id] and avail[id])
    b:SetAlpha(avail[id] and 1 or 0.4)
  end
  bar:SetWidth(s.roleBarCollapsed and 28 or 250)
  bar.collapse.text:SetText(s.roleBarCollapsed and "+" or "-")
end

function Q.Enable(mod)
  Q.active = true
  Q.Hook()
  mod:RegisterEvent("LFG_ROLE_CHECK_SHOW", Q.OnRoleCheck)
  mod:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() Q.ApplyRoles(); Q.PaintRoleBar() end)
  mod:RegisterEvent("LFG_ROLE_UPDATE", function() Q.PaintRoleBar() end)
  mod:RegisterEvent("CHAT_MSG_WHISPER", Q.OnWhisper)
  mod:RegisterEvent("CHAT_MSG_BN_WHISPER", Q.OnWhisper)
  Q.PaintRoleBar()
  if PUI.Queue:Pop() then Q.ShowPop() end
end
function Q.Disable()
  Q.active = false
  Q.HidePop()
  if Q.bar then Q.bar:Hide() end
  wipe(Q.applications)
end

PUI.Slash:Register("queue", function(rest)
  local w = (rest or ""):lower():match("^%s*(%S*)")
  if w == "on" or w == "off" then Schema:Set("gf.q.enabled", w == "on") end
  PUI.Slash.Print("queue helper: " .. (s.enabled and "|cff40ff40on|r" or "|cffff6060off|r") .. (Q.Yields() and " (AutoQueue keeps it)" or ""))
end, "queue helper on|off and status")

-- Schema ------------------------------------------------------------------------------
local schema = ns.schema
local TAINT = " Blizzard runs this window with protected code; an addon helping here can, rarely, cause an 'interface action blocked' message. It is on by default because you chose so; turn it off if you ever see that."
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.searchTags = def.searchTags or { "queue", "role", "autoqueue", "lfg" }
  def.apply = function(v) s[name] = v; if Q.bar then Q.PaintRoleBar() end; if name == "rolePerSpec" or name == "specRoles" then Q.ApplyRoles() end end
  schema["gf.q." .. name] = def
end
key("enabled", { type = "toggle", default = true, label = "Queue helper", tooltip = "Role checks, sign-up confirm, double-click sign-up, role bar and the Enter button. Each part also has its own switch.", mode = "simple" })
key("roleCheck", { type = "toggle", default = true, label = "Accept role checks for me", tooltip = "Accepts a dungeon or raid finder role check with the roles you have set." .. TAINT, mode = "simple" })
key("autoConfirm", { type = "toggle", default = true, label = "Confirm sign-up for me", tooltip = "Presses Sign Up on Blizzard's sign-up window with your roles. Hold Shift while signing up to choose yourself." .. TAINT, mode = "simple" })
key("doubleClick", { type = "toggle", default = true, label = "Double-click a group to sign up", tooltip = "Double-click a group (in Blizzard's list or Phoenix's) to open its sign-up." .. TAINT, mode = "simple" })
key("rolePerSpec", { type = "select", default = "manual", choices = { "manual", "auto", "custom" },
  choiceLabels = { manual = "Manual (I set roles)", auto = "Auto from my spec", custom = "My own list per spec" },
  label = "Roles per spec", tooltip = "One setting for every place roles are set: manual, the role your spec plays, or your own list below. Auto stands down while BigWigs sets roles.", mode = "simple" })
key("specRoles", { type = "list", default = {}, maxItems = 40, label = "My roles per spec",
  tooltip = "One line per spec: spec ID = roles, e.g. '105 = HEALER, DPS'. Used when Roles per spec is 'My own list'." })
key("roleBar", { type = "toggle", default = true, label = "Role bar", tooltip = "Docked above the group finder: your roles at a glance, with locks on roles your class cannot play.", mode = "simple" })
key("roleBarCollapsed", { type = "toggle", default = false, label = "Role bar collapsed", tooltip = "Shrinks the role bar to its + button." })
key("enterButton", { type = "toggle", default = true, label = "Big Enter button", tooltip = "When an invite pops, a large Enter button appears. Phoenix never presses it for you.", mode = "simple", searchTags = { "queue", "pop", "enter", "autoqueue" } })
key("popBar", { type = "toggle", default = true, label = "Queue-pop countdown", tooltip = "Shows the time left on the invite under the Enter button. The time comes from the shared queue timer (also used by the minimap eye); set the dungeon invite length with 'Dungeon queue-pop time'.", mode = "simple", searchTags = { "queue", "pop", "countdown", "timer" } })
key("warnAt", { type = "range", default = 10, min = 3, max = 30, step = 1, label = "Countdown turns red at (s)", tooltip = "The countdown bar turns red with this many seconds left." })
key("popSound", { type = "toggle", default = false, label = "Extra sound on queue pop", tooltip = "Plays an extra ready-check sound when the invite appears." })
key("chatConfirm", { type = "toggle", default = false, label = "Print my roles", tooltip = "Prints the roles you signed up with, with icons, after a role check." })
key("autoInvite", { type = "toggle", default = false, label = "Invite on keyword", tooltip = "Invites friends, Battle.net friends and guild members who whisper one of your words. Never strangers; never during chat lockdown." })
key("inviteWords", { type = "text", default = "inv, invite", label = "Invite words", tooltip = "Comma-separated whole words (case does not matter)." })
schema["gf.q.tipShown"] = { type = "toggle", hidden = true, default = false, owner = OWNER, mode = "advanced", label = "Role bar tip shown", tooltip = "First-run tip already shown.", apply = function() end }

local qkey, qdef = PUI.Coexist:Define("gf.queue", { module = OWNER, job = "Queue helper", soft = true, addons = { "AutoQueue" } })
qdef.owner = OWNER
schema[qkey] = qdef

GF.Register()
