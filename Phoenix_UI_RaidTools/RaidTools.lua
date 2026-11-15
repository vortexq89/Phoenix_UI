local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Raid Tools (plan 1.O "Pull / break / M+ countdown, /cd" and "Raid markers,
-- ready check"; spec 22.13; mockup 16 links): the one owner of
--  * countdowns: pull (Blizzard's group countdown, C_PartyInfo.DoCountdown),
--    break (a Phoenix countdown announced through the router) and the M+ key
--    countdown. Every countdown, including one someone else starts, becomes
--    one shared state; Pulse draws the bar from the Kernel signal "COUNTDOWN".
--    /pui cd is an alias of /pui pull.
--  * raid target and world markers on a small bar (secure world-marker
--    buttons, created and moved out of combat only);
--  * ready check with a plain summary of who is not ready.
-- Event-driven; the bar's countdown text runs on a Ticker entry only while a
-- countdown is running. No secret value is compared: names that the game
-- hides are left out of summaries.
local _, ns = ...
local Schema, Ticker, Secret, CQ = PUI.Schema, PUI.Ticker, PUI.Secret, PUI.CombatQueue
local OWNER = "RaidTools"
local RT = { active = false, countdown = nil, ready = {}, log = {} }
ns.RT = RT
PUI.RaidTools = RT
local s = { slash = true, pullSeconds = 10, breakMinutes = 5, announceBreak = true, bar = "lead", markers = true, worldMarkers = true,
  readyButton = true, pullButton = true, readySummary = true, scale = 1, vertical = false, mplusCountdown = 10 }
RT.settings = s
local function did(w) RT.log[#RT.log + 1] = w; if #RT.log > 40 then table.remove(RT.log, 1) end end
local function plain(v) return v ~= nil and not Secret.IsSecret(v) end

-- Countdown state ------------------------------------------------------------
-- RT.countdown = { kind = "pull"|"break"|"mplus", deadline, total, by }
function RT.Remaining()
  local c = RT.countdown
  if not c then return nil end
  return math.max(0, c.deadline - GetTime())
end
local function fire() PUI.Kernel:Fire("COUNTDOWN", RT.countdown) end
function RT.StartState(kind, seconds, by)
  RT.countdown = { kind = kind, deadline = GetTime() + seconds, total = seconds, by = by }
  Ticker:Register("rt.countdown", 0.25, RT.Tick, OWNER)
  fire()
end
function RT.StopState()
  if not RT.countdown then return end
  RT.countdown = nil
  Ticker:Unregister("rt.countdown")
  fire()
  RT.PaintBar()
end
function RT.Tick()
  if RT.Remaining() == 0 then RT.StopState() return end
  RT.PaintBar()
end

function RT.CanLead()
  if not IsInGroup() then return true end
  return UnitIsGroupLeader("player") == true or UnitIsGroupAssistant("player") == true
end

-- Pull(seconds): Blizzard's group countdown (everyone sees it).
function RT.Pull(seconds)
  seconds = math.floor(tonumber(seconds) or s.pullSeconds)
  if seconds <= 0 then return RT.Cancel() end
  seconds = math.max(1, math.min(60, seconds))
  if not RT.CanLead() then PUI.Slash.Print("pull timer: you need lead or assist"); return false end
  C_PartyInfo.DoCountdown(seconds)
  did("pull")
  return true
end
function RT.Cancel()
  if RT.countdown and RT.countdown.kind ~= "break" then C_PartyInfo.DoCountdown(0) end
  RT.StopState()
  did("cancel")
  return true
end
-- Break(minutes): a Phoenix countdown; the router announces it if you allow it.
function RT.Break(minutes)
  minutes = tonumber(minutes) or s.breakMinutes
  if minutes <= 0 then RT.StopState(); return false end
  minutes = math.min(60, minutes)
  RT.StartState("break", minutes * 60, "player")
  if s.announceBreak and PUI.Announce then PUI.Announce:Send("raid", string.format("Break: %d min (back at %s)", minutes, date("%H:%M", time() + minutes * 60))) end
  did("break")
  RT.PaintBar()
  return true
end
-- Key countdown (Ascent's keystone insert calls this; plan 1.O).
function RT.KeyCountdown()
  RT.nextKind = "mplus"
  local ok = RT.Pull(s.mplusCountdown)
  if not ok then RT.nextKind = nil end
  return ok
end

function RT.OnCountdown(_, _, initiatedBy, timeRemaining, totalTime)
  local by = plain(initiatedBy) and initiatedBy or nil
  local left = tonumber(timeRemaining) or 0
  if left <= 0 then RT.StopState(); return end
  local kind = RT.nextKind or "pull"
  RT.nextKind = nil
  RT.StartState(kind, left, by)
  RT.countdown.total = tonumber(totalTime) or left
  RT.PaintBar()
end
function RT.OnCountdownCancel() if RT.countdown and RT.countdown.kind ~= "break" then RT.StopState() end end

-- Ready check -------------------------------------------------------------------
function RT.ReadyCheck()
  if not RT.CanLead() then PUI.Slash.Print("ready check: you need lead or assist"); return false end
  C_PartyInfo.DoReadyCheck()
  did("ready")
  return true
end
function RT.OnReadyStart() wipe(RT.ready) end
function RT.OnReadyConfirm(_, _, unit, isReady)
  if type(unit) ~= "string" then return end
  RT.ready[unit] = isReady == true
end
-- Summary(units) -> "All ready" | "Not ready: A, B - AFK: C" (names the game hides are counted, not named)
function RT.Summary(units)
  local notReady, afk, hidden = {}, {}, 0
  for _, unit in ipairs(units) do
    local name = UnitName(unit)
    local state = RT.ready[unit]
    if state ~= true then
      if not plain(name) then hidden = hidden + 1
      elseif state == false then notReady[#notReady + 1] = name
      else afk[#afk + 1] = name end
    end
  end
  table.sort(notReady); table.sort(afk)
  if #notReady == 0 and #afk == 0 and hidden == 0 then return "All ready" end
  local parts = {}
  if #notReady > 0 then parts[#parts + 1] = "Not ready: " .. table.concat(notReady, ", ") end
  if #afk > 0 then parts[#parts + 1] = "No answer: " .. table.concat(afk, ", ") end
  if hidden > 0 then parts[#parts + 1] = hidden .. " more" end
  return table.concat(parts, " - ")
end
function RT.GroupUnits()
  local out = {}
  if IsInRaid() then for i = 1, GetNumGroupMembers() do out[#out + 1] = "raid" .. i end
  else out[1] = "player"; for i = 1, GetNumSubgroupMembers() do out[#out + 1] = "party" .. i end end
  return out
end
function RT.OnReadyFinished()
  if not s.readySummary then return end
  local text = RT.Summary(RT.GroupUnits())
  PUI.Slash.Print("ready check: " .. text)
  RT.lastSummary = text
end

-- Bar ----------------------------------------------------------------------------
RT.MARKERS = 8
function RT.BarWanted()
  if not RT.active or s.bar == "off" then return false end
  if s.bar == "always" then return true end
  if s.bar == "group" then return IsInGroup() end
  return IsInGroup() and RT.CanLead()
end
local function button(parent, w, h, label, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(1, 1, 1, 0.06)
  b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFontObject(PUI.Media:FontObject("small")); b.text:SetPoint("CENTER"); b.text:SetText(label or "")
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end
function RT.BuildBar()
  if RT.bar then return RT.bar end
  if CQ.InCombat() then CQ.Defer("rt.bar", RT.BuildBar); return nil end
  local f = PUI:CreateFrame("Frame", "PhoenixUIRaidTools", UIParent, nil, OWNER)
  f:SetSize(330, 52)
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.9)
  f.accent = f:CreateTexture(nil, "BORDER"); f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("TOPRIGHT"); f.accent:SetHeight(2); f.accent:SetColorTexture(0.91, 0.64, 0.24, 1)
  f.targets, f.world = {}, {}
  for i = 1, RT.MARKERS do
    local b = button(f, 22, 22, nil, function() SetRaidTarget("target", i); did("mark" .. i) end)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 4 + (i - 1) * 24, -4)
    f.targets[i] = b
    local w = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    w:SetSize(22, 16)
    w:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
    w:RegisterForClicks("AnyUp", "AnyDown")
    w:SetAttribute("type", "worldmarker"); w:SetAttribute("marker", i); w:SetAttribute("action", "toggle")
    w.bg = w:CreateTexture(nil, "BACKGROUND"); w.bg:SetAllPoints(); w.bg:SetColorTexture(1, 1, 1, 0.1)
    f.world[i] = w
  end
  f.clearWorld = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
  f.clearWorld:SetSize(30, 16); f.clearWorld:SetPoint("LEFT", f.world[RT.MARKERS], "RIGHT", 4, 0)
  f.clearWorld:RegisterForClicks("AnyUp", "AnyDown")
  f.clearWorld:SetAttribute("type", "worldmarker"); f.clearWorld:SetAttribute("action", "clear")
  f.ready = button(f, 50, 20, "Ready", function() RT.ReadyCheck() end)
  f.ready:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  f.pull = button(f, 50, 20, "Pull", function() if RT.countdown and RT.countdown.kind == "pull" then RT.Cancel() else RT.Pull() end end)
  f.pull:SetPoint("TOPRIGHT", f.ready, "BOTTOMRIGHT", 0, -2)
  f.brk = button(f, 44, 20, "Break", function() if RT.countdown and RT.countdown.kind == "break" then RT.StopState() else RT.Break() end end)
  f.brk:SetPoint("RIGHT", f.ready, "LEFT", -4, 0)
  f.time = f:CreateFontString(nil, "OVERLAY"); f.time:SetFontObject(PUI.Media:FontObject("small")); f.time:SetPoint("RIGHT", f.pull, "LEFT", -6, 0)
  RT.bar = f
  PUI.Layout:Place(f, "raidtools.bar")
  RT.PaintBar()
  return f
end
function RT.CountdownText()
  local c, left = RT.countdown, RT.Remaining()
  if not c then return "" end
  local label = c.kind == "break" and "Break" or c.kind == "mplus" and "Key" or "Pull"
  if left >= 60 then return string.format("%s %d:%02d", label, math.floor(left / 60), math.floor(left) % 60) end
  return string.format("%s %d", label, math.ceil(left))
end
function RT.PaintBar()
  local f = RT.bar
  if not f then return end
  if CQ.InCombat() then CQ.Defer("rt.paint", RT.PaintBar); return end
  local want = RT.BarWanted()
  f:SetShown(want)
  if not want then return end
  f:SetScale(s.scale)
  for i = 1, RT.MARKERS do f.targets[i]:SetShown(s.markers); f.world[i]:SetShown(s.worldMarkers) end
  f.clearWorld:SetShown(s.worldMarkers)
  f.ready:SetShown(s.readyButton)
  f.pull:SetShown(s.pullButton); f.brk:SetShown(s.pullButton)
  f.pull.text:SetText(RT.countdown and RT.countdown.kind == "pull" and "Cancel" or "Pull")
  f.time:SetText(RT.CountdownText())
end

-- Slash -------------------------------------------------------------------------
local function slashOk() return RT.active and s.slash end
PUI.Slash:Register("pull", function(rest) if slashOk() then RT.Pull(tonumber(rest)) end end, "pull countdown (Raid Tools): /pui pull [seconds], 0 cancels")
PUI.Slash:Register("cd", function(rest) if slashOk() then RT.Pull(tonumber(rest)) end end, "alias of /pui pull (Raid Tools)")
PUI.Slash:Register("break", function(rest) if slashOk() then RT.Break(tonumber(rest)) end end, "break countdown in minutes (Raid Tools)")
PUI.Slash:Register("rc", function() if slashOk() then RT.ReadyCheck() end end, "ready check (Raid Tools)")

local function onEnable(mod)
  RT.active = true
  mod:RegisterEvent("START_PLAYER_COUNTDOWN", RT.OnCountdown)
  mod:RegisterEvent("CANCEL_PLAYER_COUNTDOWN", RT.OnCountdownCancel)
  mod:RegisterEvent("READY_CHECK", RT.OnReadyStart)
  mod:RegisterEvent("READY_CHECK_CONFIRM", RT.OnReadyConfirm)
  mod:RegisterEvent("READY_CHECK_FINISHED", RT.OnReadyFinished)
  mod:RegisterEvent("GROUP_ROSTER_UPDATE", RT.PaintBar)
  mod:RegisterEvent("PARTY_LEADER_CHANGED", RT.PaintBar)
  if s.bar ~= "off" then RT.BuildBar() end
  if ns.Stats then ns.Stats.Enable(mod) end
end
local function onDisable()
  RT.active = false
  RT.StopState()
  if RT.bar then RT.PaintBar() end
end

local schema = {}
RT.schema = schema
ns.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[name] = v; if RT.active and name == "bar" and v ~= "off" then RT.BuildBar() end; RT.PaintBar() end
  schema["rt." .. name] = def
end
key("slash", { type = "toggle", default = true, label = "Slash commands", tooltip = "/pui pull [s] (also /pui cd), /pui break [min], /pui rc.", mode = "simple", searchTags = { "cd", "pull", "countdown", "slash" } })
key("pullSeconds", { type = "range", default = 10, min = 3, max = 60, step = 1, label = "Pull countdown (s)", tooltip = "Length of a pull countdown started from the bar or /pui pull without a number.", mode = "simple" })
key("mplusCountdown", { type = "range", default = 10, min = 3, max = 30, step = 1, label = "Key countdown (s)", tooltip = "Countdown started when your keystone goes in (the Mythic+ tracker asks Raid Tools for it)." })
key("breakMinutes", { type = "range", default = 5, min = 1, max = 60, step = 1, label = "Break length (min)", tooltip = "Length of a break started from the bar or /pui break." })
key("announceBreak", { type = "toggle", default = true, label = "Announce breaks", tooltip = "Sends the break through the announcement router (where it goes is set on the Announcements page; off until you turn it on there)." })
key("bar", { type = "select", default = "lead", choices = { "off", "lead", "group", "always" },
  choiceLabels = { off = "Off", lead = "When I lead or assist", group = "In any group", always = "Always" },
  label = "Raid tools bar", tooltip = "Markers, world markers, ready check, pull and break on one small bar. Move it in Studio.", mode = "simple" })
key("markers", { type = "toggle", default = true, label = "Target markers", tooltip = "Eight buttons that put a raid marker on your target." })
key("worldMarkers", { type = "toggle", default = true, label = "World markers", tooltip = "Eight secure buttons that place or remove a world marker, plus clear all. Changes wait until combat ends." })
key("readyButton", { type = "toggle", default = true, label = "Ready check button", tooltip = "Starts a ready check (needs lead or assist)." })
key("pullButton", { type = "toggle", default = true, label = "Pull and break buttons", tooltip = "Pull starts or cancels the countdown; Break starts or stops a break." })
key("readySummary", { type = "toggle", default = true, label = "Ready check summary", tooltip = "After a ready check, prints who was not ready or did not answer.", mode = "simple" })
key("scale", { type = "range", default = 1, min = 0.6, max = 1.6, step = 0.05, label = "Bar scale", tooltip = "Size of the raid tools bar." })
PUI.Layout:RegisterElement("raidtools.bar", { label = "Raid tools bar", owner = OWNER, size = { 330, 52 }, default = { point = "TOP", x = 0, y = -24 } })

function RT.Register()
  RT.module = PUI:RegisterModule(OWNER, {
    label = "Raid Tools", tooltip = "Pull, break and key countdowns (/pui cd), markers, ready check and encounter stats. Pulse draws the countdown bar.",
    enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
  })
  for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
end
