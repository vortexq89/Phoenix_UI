local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Sentinel extras (deferred batch C): a baseline of errors you already know
-- (seen in 3+ sessions) with one warning per session when too many errors
-- outside it pile up, and a developer trace of Phoenix's internal bus
-- signals. The trace wraps Kernel.Fire only while it is on; off restores
-- the original function, so it costs nothing.
local S = PUI.Sentinel
local Kernel = PUI.Kernel
local Alerts = S.Alerts
local X = { warned = false, outside = 0, ring = {}, max = 200 }
S.Extras = X
local o = Alerts.opts
X.BASELINE_SESSIONS = 3

-- Baseline ------------------------------------------------------------------------------------------
-- db.seenIn[hash] = { n = sessions seen, last = last session }
function X.Seen(hash)
  local db = S.db
  if not (db and hash) then return 0 end
  db.seenIn = db.seenIn or {}
  local rec = db.seenIn[hash]
  if not rec then rec = { n = 0 }; db.seenIn[hash] = rec end
  if rec.last ~= db.session then rec.n = rec.n + 1; rec.last = db.session end
  return rec.n
end
function X.InBaseline(hash)
  local rec = S.db and S.db.seenIn and S.db.seenIn[hash]
  -- Counted before this session, so a new error does not join on its 3rd occurrence today.
  local n = rec and rec.n or 0
  if rec and rec.last == S.db.session then n = n - 1 end
  return n >= X.BASELINE_SESSIONS
end
function X.Note(inc)
  if not inc or inc.kind == "heartbeat" or inc.kind == "test" then return end
  local known = X.InBaseline(inc.hash)
  X.Seen(inc.hash)
  if known then return end
  X.outside = X.outside + 1
  local limit = o.baselineWarn or 0
  if limit > 0 and not X.warned and X.outside >= limit then
    X.warned = true
    PUI.Slash.Print(string.format("%d errors outside your usual ones this session. /pui bugs lists them.", X.outside))
  end
end
local onError = Alerts.OnError
function Alerts:OnError(inc, isNew)
  X.Note(inc)
  return onError(self, inc, isNew)
end

-- Event trace ------------------------------------------------------------------------------------------
local fire = Kernel.Fire
local function short(v)
  if type(v) == "table" then return "{...}" end
  if type(v) == "string" and #v > 40 then return v:sub(1, 40) .. "..." end
  return tostring(v)
end
local function traced(self, signal, ...)
  local n = select("#", ...)
  local args = {}
  for i = 1, math.min(n, 3) do args[i] = short((select(i, ...))) end
  local ring = X.ring
  ring[#ring + 1] = string.format("%.1f  %s  %s", GetTime(), tostring(signal), table.concat(args, ", "))
  if #ring > X.max then table.remove(ring, 1) end
  if X.open then X.Paint() end
  return fire(self, signal, ...)
end
function X.SetTrace(on)
  Kernel.Fire = on and traced or fire
  if not on then X.ring = {} end
end

-- Trace window: the last 20 signals, newest first.
PUI.Layout:RegisterElement("sentinel.trace", { label = "Event trace", owner = "Sentinel", size = { 420, 300 }, default = { point = "CENTER", x = 0, y = 0 } })
function X.Build()
  local f = PUI:CreateFrame("Frame", "PhoenixUISentinelTrace", UIParent, nil, "Sentinel")
  f:SetSize(420, 300)
  PUI.Layout:Place(f, "sentinel.trace")
  f:SetFrameStrata("DIALOG")
  PUI.Theme:Backdrop(f, "surface.0")
  f.title = f:CreateFontString(nil, "OVERLAY"); f.title:SetFontObject(PUI.Media:FontObject("normal")); f.title:SetPoint("TOPLEFT", 10, -8)
  f.title:SetText("Phoenix event trace")
  f.close = CreateFrame("Button", nil, f); f.close:SetSize(18, 18); f.close:SetPoint("TOPRIGHT", -6, -6)
  f.close.text = f.close:CreateFontString(nil, "OVERLAY"); f.close.text:SetFontObject(PUI.Media:FontObject("small")); f.close.text:SetPoint("CENTER")
  f.close.text:SetText("x")
  f.close:SetScript("OnClick", function() f:Hide(); X.open = false end)
  X.lines = {}
  for i = 1, 20 do
    local l = f:CreateFontString(nil, "OVERLAY"); l:SetFontObject(PUI.Media:FontObject("small"))
    l:SetPoint("TOPLEFT", 10, -26 - (i - 1) * 13); l:SetJustifyH("LEFT")
    X.lines[i] = l
  end
  X.frame = f
  return f
end
function X.Paint()
  local f = X.frame
  if not f then return end
  local ring = X.ring
  for i = 1, 20 do
    local line = ring[#ring - i + 1]
    if i == 1 and not line then line = o.trace and "No signals yet." or "The trace is off (Sentinel settings, Developer event trace)." end
    X.lines[i]:SetText(line or "")
  end
end
function X.Toggle()
  local f = X.frame or X.Build()
  if X.open then f:Hide(); X.open = false return end
  f:Show(); X.open = true; X.Paint()
end
PUI.Slash:Register("trace", function() X.Toggle() end, "show Phoenix's internal event trace (turn it on in Sentinel settings)")

local apply = S.ApplyReporter
function S:ApplyReporter(key, value)
  if key == "trace" then X.SetTrace(value) end
  if key == "recorder" and S.Recorder then S.Recorder.Apply(value) end
  return apply(self, key, value)
end
