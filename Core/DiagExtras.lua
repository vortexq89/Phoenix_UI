local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Diagnostics extras (deferred batch D):
--  * Self-measurement through the game's addon profiler, after a signature
--    check (the API table, the metric enum and a plain number back for
--    Phoenix's own addon). Without a verified profiler everything here says
--    "unavailable" and falls back to Phoenix's own timer.
--  * Top-addons readout: the five heaviest addons, read only on hover.
--  * A/B pairs: code registers two variants of the same work; the A/B window
--    runs them interleaved and shows both averages and the difference.
-- Read-only and frame-free except the A/B window; values that come back
-- secret are dropped, never compared.
local Diag = PUI.Diag
local X = { pairs = {}, order = {} }
Diag.Extras = X

local function plain(v) return type(v) == "number" and not PUI.Secret.IsSecret(v) end

-- Signature check: returns true, metric or false, reason.
function X.Verify()
  local api = rawget(_G, "C_AddOnProfiler")
  if type(api) ~= "table" then return false, "the game's addon profiler is missing" end
  for _, f in ipairs({ "IsEnabled", "GetAddOnMetric", "GetApplicationMetric" }) do
    if type(api[f]) ~= "function" then return false, "C_AddOnProfiler." .. f .. " is missing" end
  end
  local enum = Enum and Enum.AddOnProfilerMetric
  local metric = enum and enum.RecentAverageTime
  if type(metric) ~= "number" then return false, "Enum.AddOnProfilerMetric.RecentAverageTime is missing" end
  if not api.IsEnabled() then return false, "the game's addon profiler is turned off" end
  if not plain(api.GetAddOnMetric(PUI.ADDON_NAME, metric)) then return false, "GetAddOnMetric did not return a plain number" end
  return true, metric
end

-- { ok, reason, phoenix (ms), app (ms), share (0-100), rows = { {name, ms} } }
function X.SelfMeasure()
  local ok, metric = X.Verify()
  if not ok then return { ok = false, reason = metric } end
  local rows, total = {}, 0
  for i = 1, C_AddOns.GetNumAddOns() do
    local name = C_AddOns.GetAddOnInfo(i)
    if type(name) == "string" and name:find("^Phoenix_UI") and C_AddOns.IsAddOnLoaded(i) then
      local ms = C_AddOnProfiler.GetAddOnMetric(name, metric)
      if plain(ms) then rows[#rows + 1] = { name = name, ms = ms }; total = total + ms end
    end
  end
  table.sort(rows, function(a, b) return a.ms > b.ms end)
  local app = C_AddOnProfiler.GetApplicationMetric(metric)
  if not plain(app) then app = nil end
  return { ok = true, phoenix = total, app = app, share = app and app > 0 and total / app * 100 or nil, rows = rows }
end

-- Top k addons by recent average time (hover only).
function X.TopAddons(k)
  local ok, metric = X.Verify()
  if not ok or type(C_AddOnProfiler.GetTopKAddOnsForMetric) ~= "function" then return nil end
  local list = C_AddOnProfiler.GetTopKAddOnsForMetric(metric, k or 5)
  local out = {}
  for _, r in ipairs(type(list) == "table" and list or {}) do
    if type(r) == "table" and type(r.addOnName) == "string" and plain(r.metricValue) then out[#out + 1] = { name = r.addOnName, ms = r.metricValue } end
  end
  return out
end

function X.TopText(k)
  local top = X.TopAddons(k)
  if not top then return { "Top addons: the game's profiler is not available." } end
  local out = { "Top addons (recent average per frame)" }
  for i, r in ipairs(top) do out[#out + 1] = string.format("%d. %s  %.3f ms", i, r.name, r.ms) end
  if #top == 0 then out[#out + 1] = "No readings yet." end
  return out
end

-- Hover helper for any frame: shows the top-addons readout in GameTooltip.
function X.HoverTop(frame)
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    for i, line in ipairs(X.TopText(5)) do
      if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 1, 1, 1) end
    end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- One timed call: the game's MeasureCall when the signature checks out
-- (results.elapsedMilliseconds), otherwise Phoenix's own clock.
function X.Measure(fn)
  local api = rawget(_G, "C_AddOnProfiler")
  if X.Verify() and api and type(api.MeasureCall) == "function" then
    local res = api.MeasureCall(fn)
    if type(res) == "table" and plain(res.elapsedMilliseconds) then return res.elapsedMilliseconds, "game" end
  end
  local t0 = GetTimePreciseSec(); fn(); return (GetTimePreciseSec() - t0) * 1000, "own"
end

-- A/B registry --------------------------------------------------------------------------------------
function X.RegisterAB(id, label, a, b, labelA, labelB)
  if not X.pairs[id] then X.order[#X.order + 1] = id end
  X.pairs[id] = { id = id, label = label, a = a, b = b, labelA = labelA or "A", labelB = labelB or "B" }
end
-- Interleaved run: A,B then B,A alternately so warm-up and drift hit both.
function X.RunAB(id, rounds)
  local p = X.pairs[id]
  if not p then return nil end
  rounds = rounds or 100
  local ta, tb, how = 0, 0, "own"
  for i = 1, rounds do
    local first, second = p.a, p.b
    if i % 2 == 0 then first, second = p.b, p.a end
    local m1, h = X.Measure(first)
    local m2 = X.Measure(second)
    how = h
    if first == p.a then ta, tb = ta + m1, tb + m2 else ta, tb = ta + m2, tb + m1 end
  end
  local avgA, avgB = ta / rounds, tb / rounds
  local r = { id = id, label = p.label, labelA = p.labelA, labelB = p.labelB, a = avgA, b = avgB, rounds = rounds, how = how,
    diff = avgA > 0 and (avgB - avgA) / avgA * 100 or 0 }
  X.last = r
  return r
end
function X.ABText(r)
  if not r then return { "A/B: pick a pair and press Run." } end
  return {
    string.format("%s  (%d rounds, %s clock)", r.label, r.rounds, r.how == "game" and "game profiler" or "Phoenix"),
    string.format("A  %-28s %8.4f ms", r.labelA, r.a),
    string.format("B  %-28s %8.4f ms", r.labelB, r.b),
    string.format("B is %s%.1f%% %s than A", "", math.abs(r.diff), r.diff > 0 and "slower" or "faster"),
  }
end

-- Built-in pair: Phoenix's diagnostics text with and without the module scan.
X.RegisterAB("diag.collect", "Diagnostics report", function() Diag:Collect() end, function() Diag:Text() end, "collect only", "collect and format")

-- A/B window ----------------------------------------------------------------------------------------
PUI.Layout:RegisterElement("diag.ab", { label = "A/B report", owner = "Sentinel", size = { 440, 170 }, default = { point = "CENTER", x = 0, y = 120 } })
function X.ShowAB(id)
  local f = X.abFrame
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUIDiagAB", UIParent, nil, "Sentinel")
    f:SetSize(440, 170)
    PUI.Layout:Place(f, "diag.ab")
    f:SetFrameStrata("DIALOG")
    PUI.Theme:Backdrop(f, "surface.0")
    X.abLines = {}
    for n = 1, 5 do
      local l = f:CreateFontString(nil, "OVERLAY"); l:SetFontObject(PUI.Media:FontObject(n == 1 and "normal" or "small"))
      l:SetPoint("TOPLEFT", 12, -10 - (n - 1) * 18); l:SetJustifyH("LEFT")
      X.abLines[n] = l
    end
    local function btn(text, x, fn)
      local b = CreateFrame("Button", nil, f); b:SetSize(96, 22); b:SetPoint("BOTTOMLEFT", x, 10)
      PUI.Theme:Backdrop(b, "surface.1")
      local t = b:CreateFontString(nil, "OVERLAY"); t:SetFontObject(PUI.Media:FontObject("small")); t:SetPoint("CENTER"); t:SetText(text)
      b:SetScript("OnClick", fn)
      return b
    end
    btn("Next pair", 12, function()
      local i = 1
      for n, pid in ipairs(X.order) do if pid == X.abId then i = n % #X.order + 1 end end
      X.abId = X.order[i]; X.PaintAB()
    end)
    btn("Run", 116, function() if not InCombatLockdown() then X.RunAB(X.abId); X.PaintAB() end end)
    btn("Close", 332, function() f:Hide() end)
    X.abFrame = f
  end
  X.abId = id or X.abId or X.order[1]
  X.PaintAB()
  f:Show()
end
function X.PaintAB()
  local r = X.last and X.last.id == X.abId and X.last or nil
  local lines = r and X.ABText(r) or { "A/B: " .. tostring(X.pairs[X.abId] and X.pairs[X.abId].label), "Press Run (never in combat).", "", "", "" }
  lines[5] = string.format("Pair %s of %d", X.abId or "-", #X.order)
  for n = 1, 5 do X.abLines[n]:SetText(lines[n] or "") end
end
PUI.Slash:Register("ab", function(rest) X.ShowAB(rest ~= "" and rest or nil) end, "A/B timing window for registered pairs")

-- The report gains the self-measurement block.
local text = Diag.Text
function Diag:Text()
  local out = { text(self) }
  local m = X.SelfMeasure()
  if not m.ok then out[#out + 1] = "\nSelf-measurement: unavailable (" .. m.reason .. ")"
  else
    out[#out + 1] = string.format("\nSelf-measurement (game profiler, signature checked): Phoenix %.3f ms per frame%s",
      m.phoenix, m.share and string.format(", %.1f%% of all addons and the UI", m.share) or "")
    for _, r in ipairs(m.rows) do out[#out + 1] = string.format("  %-32s %.3f ms", r.name, r.ms) end
  end
  return table.concat(out, "\n")
end
