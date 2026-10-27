local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Opt-in developer recorder (deferred batch D). While on, a 1 s Ticker job
-- reads a few plain channels (zone, combat, group size, frame-rate band,
-- Phoenix errors) and stores a row only when a channel's value changes.
-- Each recording is marked open in the saved data; one still open at the
-- next load (the game closed without stopping it, e.g. a crash after a
-- /reload saved it) is kept and marked "recovered" instead of lost.
local S = PUI.Sentinel
local R = { last = {} }
S.Recorder = R
R.MAX_ROWS, R.MAX_RECORDINGS = 3000, 5
local KEY = "sentinel.recorder"

local function zone()
  local fn = rawget(_G, "GetRealZoneText")
  local z = fn and fn()
  return type(z) == "string" and z ~= "" and z or "?"
end
R.CHANNELS = {
  zone = zone,
  combat = function() return InCombatLockdown() and "in" or "out" end,
  group = function() return GetNumGroupMembers() end,
  fps = function() return math.floor((GetFramerate() or 0) / 10) * 10 end,
}
R.ORDER = { "zone", "combat", "group", "fps" }

function R.List()
  local db = S.db
  if not db then return {} end
  db.recordings = db.recordings or {}
  return db.recordings
end
function R.Current()
  local list = R.List()
  local rec = list[#list]
  if rec and not rec.stopped and not rec.recovered and rec.session == S.db.session then return rec end
end

-- Recovery: runs once per load (from ApplyReporter or Start).
function R.Recover()
  if R.recovered then return 0 end
  R.recovered = true
  local n = 0
  for _, rec in ipairs(R.List()) do
    if not rec.stopped and rec.session ~= S.db.session then rec.recovered = true; rec.stopped = rec.lastAt or rec.started; n = n + 1 end
  end
  if n > 0 then PUI.Slash.Print(string.format("recorder: %d unfinished recording%s kept (marked recovered). /pui record list", n, n > 1 and "s" or "")) end
  return n
end

function R.Add(channel, value)
  local rec = R.Current()
  if not rec then return false end
  if #rec.rows >= R.MAX_ROWS then rec.full = true return false end
  local t = GetTime() - (R.t0 or GetTime())
  rec.rows[#rec.rows + 1] = { math.floor(t * 10) / 10, channel, value }
  rec.lastAt = time()
  return true
end

function R.Sample()
  for _, ch in ipairs(R.ORDER) do
    local v = R.CHANNELS[ch]()
    if R.last[ch] ~= v then R.last[ch] = v; R.Add(ch, v) end
  end
end

function R.Start()
  if not S.db then return false end
  R.Recover()
  if R.Current() then return true end
  local list = R.List()
  list[#list + 1] = { session = S.db.session, started = time(), rows = {} }
  while #list > R.MAX_RECORDINGS do table.remove(list, 1) end
  R.last, R.t0 = {}, GetTime()
  R.Sample()
  PUI.Ticker:Register(KEY, 1, R.Sample, "Sentinel")
  return true
end
function R.Stop()
  PUI.Ticker:Unregister(KEY)
  local rec = R.Current()
  if rec then rec.stopped = time() end
  R.last = {}
end
function R.Apply(on)
  if S.db then R.Recover() end
  if on then R.Start() else R.Stop() end
end

-- Errors join the stream as their signature.
local onError = S.Alerts.OnError
function S.Alerts:OnError(inc, isNew)
  if inc and inc.hash and inc.kind ~= "heartbeat" and inc.kind ~= "test" then R.Add("error", inc.hash) end
  return onError(self, inc, isNew)
end

function R.Text(i)
  local list = R.List()
  local rec = list[i or #list]
  if not rec then return { "No recordings. /pui record start (or the Developer recorder setting)." } end
  local out = { string.format("Recording %d  session %d  %s  %d rows%s%s", i or #list, rec.session, date("%Y-%m-%d %H:%M", rec.started),
    #rec.rows, rec.recovered and "  (recovered)" or "", rec.full and "  (full)" or "") }
  for n = #rec.rows, math.max(1, #rec.rows - 18), -1 do
    local row = rec.rows[n]
    out[#out + 1] = string.format("%7.1f s  %-6s %s", row[1], row[2], tostring(row[3]))
  end
  return out
end

-- Window: header plus the newest 18 rows.
PUI.Layout:RegisterElement("sentinel.recorder", { label = "Developer recorder", owner = "Sentinel", size = { 420, 300 }, default = { point = "CENTER", x = 40, y = -20 } })
function R.Show(i)
  local f = R.frame
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUISentinelRecorder", UIParent, nil, "Sentinel")
    f:SetSize(420, 300)
    PUI.Layout:Place(f, "sentinel.recorder")
    f:SetFrameStrata("DIALOG")
    PUI.Theme:Backdrop(f, "surface.0")
    local close = CreateFrame("Button", nil, f); close:SetSize(18, 18); close:SetPoint("TOPRIGHT", -6, -6)
    local x = close:CreateFontString(nil, "OVERLAY"); x:SetFontObject(PUI.Media:FontObject("small")); x:SetPoint("CENTER"); x:SetText("x")
    close:SetScript("OnClick", function() f:Hide() end)
    R.lines = {}
    for n = 1, 20 do
      local l = f:CreateFontString(nil, "OVERLAY"); l:SetFontObject(PUI.Media:FontObject(n == 1 and "normal" or "small"))
      l:SetPoint("TOPLEFT", 10, -8 - (n - 1) * 14); l:SetJustifyH("LEFT")
      R.lines[n] = l
    end
    R.frame = f
  end
  local text = R.Text(i)
  for n = 1, 20 do R.lines[n]:SetText(text[n] or "") end
  f:Show()
end

PUI.Slash:Register("record", function(rest)
  local cmd, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  if cmd == "start" then PUI.Schema:Set("sentinel.recorder", true)
  elseif cmd == "stop" then PUI.Schema:Set("sentinel.recorder", false)
  elseif cmd == "clear" then R.Stop(); S.db.recordings = {}; if PUI.Schema:Get("sentinel.recorder") then R.Start() end
  elseif cmd == "list" then
    for n, rec in ipairs(R.List()) do
      PUI.Slash.Print(string.format("%d: session %d, %d rows%s", n, rec.session, #rec.rows, rec.recovered and " (recovered)" or (rec.stopped and "" or " (recording)")))
    end
  else R.Show(tonumber(arg)) end
end, "developer recorder: start | stop | show [n] | list | clear")
