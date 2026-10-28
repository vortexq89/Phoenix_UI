local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Diagnostics page (deferred batch D): its own entry under System. Shows the
-- live diagnostics report (with the game-profiler self-measurement), the
-- top-addons readout on hover, and buttons for the profiler, the A/B window,
-- the event trace and the recorder. "Settings" shows the developer settings
-- that now live on this page (profiler, CPU chip, trace, recorder).
local Options, Schema = PUI.Options, PUI.Schema
local Kit, A = Options.Kit, Options.Assets
local Page = {}
Options.DiagPage = Page
Options.views = Options.views or {}
Options.CUSTOM.Diagnostics = function() return Options.DiagPage end
local Model = Options.Model
Model.PAGE_LABEL.Diagnostics = "Diagnostics"
Model.VIRTUAL[#Model.VIRTUAL + 1] = "Diagnostics" -- review fix: its keys are all Advanced, so the page needs to be virtual to show in Simple mode
Options.Nav.INFO.Diagnostics = { "diagnostics", "Diagnostics", "Versions, modules, CPU and memory, the game profiler, A/B timing and developer tools." }
for _, g in ipairs(Options.Nav.GROUPS) do
  if g[1] == "System" then
    local list = g[2]
    for i, v in ipairs(list) do if v == "Sentinel" then table.insert(list, i + 1, "Diagnostics"); break end end
  end
end
Page.KEYS = { "sentinel.profiler", "sentinel.cpuChip", "sentinel.trace", "sentinel.recorder" }
for _, k in ipairs(Page.KEYS) do local def = Schema:Def(k); if def then def.page = "Diagnostics" end end

local PAD = 30
-- Plain lines (unit-tested): the report split into lines, capped.
function Page.Lines(max)
  local out = {}
  for line in (PUI.Diag:Text() .. "\n"):gmatch("([^\n]*)\n") do
    out[#out + 1] = line
    if #out >= (max or 40) then break end
  end
  return out
end

local function build(host)
  local v = CreateFrame("Frame", nil, host)
  v:SetAllPoints()
  v.icon = Kit.Icon(v, A.Icon("sentinel"), 44)
  v.icon:SetPoint("TOPLEFT", PAD, -40)
  v.title = Kit.Text(v, "display", "text.primary")
  v.title:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", 14, 2)
  v.title:SetText("Diagnostics")
  v.desc = Kit.Text(v, "text", "muted")
  v.desc:SetPoint("TOPLEFT", v.title, "BOTTOMLEFT", 0, -4)
  v.desc:SetText("Everything a problem report needs. Hover the CPU line for the heaviest addons right now.")
  local x = PAD
  local function button(label, width, fn, kind)
    local b = Kit.Button(v, label, width, fn, kind or "secondary")
    b:SetPoint("TOPLEFT", x, -110)
    x = x + width + 10
    return b
  end
  v.copy = button("Copy report", 130, function() PUI.Dialogs:Copy("Phoenix UI diagnostics", PUI.Diag:Text(), "Ctrl+C to copy into a report") end)
  v.profile = button("Profiler", 110, function()
    local P = PUI.Profiler
    if P.running then P:Stop() else P:Start() end
    Page:Show(host)
  end)
  v.ab = button("A/B timing", 120, function() PUI.Diag.Extras.ShowAB() end)
  v.trace = button("Event trace", 120, function() local S = PUI.Sentinel; if S and S.Extras then S.Extras.Toggle() end end, "ghost")
  v.record = button("Recorder", 110, function() local S = PUI.Sentinel; if S and S.Recorder then S.Recorder.Show() end end, "ghost")
  v.settings = button("Settings", 100, function() Options.rawPage = "Diagnostics"; Options:Render() end, "ghost")
  v.card = Kit.Card(v)
  v.card:SetPoint("TOPLEFT", PAD, -150)
  v.card:SetPoint("BOTTOMRIGHT", -PAD, 24)
  v.lines = {}
  for i = 1, 40 do
    local l = Kit.Text(v.card, "body", i == 1 and "text.primary" or "muted")
    l:SetPoint("TOPLEFT", 16, -12 - (i - 1) * 17)
    v.lines[i] = l
  end
  -- The CPU / self-measurement area gets the top-addons hover.
  v.hover = CreateFrame("Frame", nil, v.card)
  v.hover:SetPoint("TOPLEFT", 0, 0); v.hover:SetPoint("TOPRIGHT", 0, 0); v.hover:SetHeight(120)
  v.hover:EnableMouse(true)
  PUI.Diag.Extras.HoverTop(v.hover)
  Options.views.diagnostics = v
  return v
end

function Page:Show(host)
  local v = Options.views.diagnostics or build(host)
  v:Show()
  v.profile:SetLabel(PUI.Profiler.running and "Stop profiler" or "Start profiler")
  local lines = Page.Lines(40)
  for i = 1, 40 do v.lines[i]:SetText(lines[i] or "") end
  v.count = #lines
end
