local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Embers, review addition: the window comforts people know from restyled
-- Blizzard meters, written for Phoenix's own windows:
--  * fade: the header, backdrop and border rest at a low alpha and come back
--    while the mouse is over the window (rows stay readable).
--  * scrolling: the mouse wheel scrolls the rows; there is no scroll bar
--    (an optional thin accent line shows where you are).
--  * dock: windows sit side by side or stacked inside one container with a
--    single Studio mover ("Embers dock"), or stay free with their own movers.
--  * type menu: a click on the header opens a Phoenix list of meter types
--    (and fights, with a right click) instead of cycling through them.
--  * report queue (workaround W9): where the game blocks addon chat (Mythic+,
--    PvP, encounters), a report waits and posts after the key, match or boss
--    ends, out of combat; Say and Yell need your click, so those ask first.
--    Meanwhile the report opens in the copy box for a manual paste.
local _, ns = ...
local EM, Window = ns.EM, ns.Window
local Schema, Theme, Media, Layout = PUI.Schema, PUI.Theme, PUI.Media, PUI.Layout
local OWNER = EM.OWNER
local s = { fade = false, fadeAlpha = 0.15, wheel = true, scrollLine = false, dock = "free", dockGap = 2, typeMenu = true, typeMenuSessions = true }
local D = { s = s }
EM.Dock = D

-- Fade --------------------------------------------------------------------------------------------------------
function D.Chrome(w, alpha)
  w.title:SetAlpha(alpha)
  local look = Window.LOOKS[EM.settings.look] or Window.LOOKS.phoenix
  w.bg:SetAlpha(alpha * (EM.settings.bgAlpha or 1) * look.bgScale)
  local pixel = PUI.Look.s.borderStyle == "pixel"
  for _, e in ipairs(w.outline) do e:SetAlpha(pixel and alpha or 0) end
end
function D.Hover(w, over)
  w.hover = over
  if not s.fade then return D.Chrome(w, 1) end
  D.Chrome(w, over and 1 or s.fadeAlpha)
end
local function left(w) if not w.frame:IsMouseOver() then D.Hover(w, false) end end

-- Scrolling ---------------------------------------------------------------------------------------------------
function D.Scroll(w, delta)
  if not s.wheel then return false end
  local shown = math.min(EM.settings.rows, 25)
  local maxOff = math.max(0, #(w.data or {}) - shown)
  w.offset = math.max(0, math.min(maxOff, (w.offset or 0) - delta))
  Window.Update(w)
  return w.offset
end
local visible = Window.Visible
function Window.Visible(data, shown, pin)
  local off = D.offset or 0
  if off <= 0 then return visible(data, shown, pin) end
  local list = {}
  for i = 1, shown do list[i] = data[i + off] end
  return list
end
local function paintScroll(w)
  local line = w.scrollLine
  local n, shown = #(w.data or {}), math.min(EM.settings.rows, 25)
  if not (s.scrollLine and n > shown) then line:Hide() return end
  local h = w.frame:GetHeight() or 0
  line:SetHeight(math.max(6, h * shown / n))
  line:ClearAllPoints()
  line:SetPoint("TOPRIGHT", w.frame, "TOPRIGHT", 0, -(h - line:GetHeight()) * (w.offset or 0) / math.max(1, n - shown))
  line:SetColorTexture(Theme:Color("accent"))
  line:Show()
end

-- Type menu ---------------------------------------------------------------------------------------------------
function D.Menu(w, what)
  local m = D.menu
  if not m then
    m = PUI:CreateFrame("Frame", "PhoenixUI_EmbersMenu", UIParent, nil, OWNER)
    m:SetFrameStrata("DIALOG"); m:SetWidth(150); m:Hide()
    m.bg = Theme:Backdrop(m, "surface.2")
    m.edge = Theme:Outline(m, "accent", 0.6)
    m.items = {}
    D.menu = m
  end
  local list = what == "source" and EM.SESSIONS or EM.METERS
  local labels = what == "source" and EM.SESSION_LABELS or EM.METER_LABELS
  local cur = what == "source" and w.source or w.meter
  for i, value in ipairs(list) do
    local b = m.items[i]
    if not b then
      b = PUI:CreateFrame("Button", nil, m, nil, OWNER)
      b:SetHeight(18); b:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 18); b:SetPoint("RIGHT", -2, 0)
      b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.08); b.hl:Hide()
      b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFontObject(Media:FontObject("small")); b.text:SetPoint("LEFT", 6, 0)
      b:SetScript("OnEnter", function(self) self.hl:Show() end)
      b:SetScript("OnLeave", function(self) self.hl:Hide() end)
      b:SetScript("OnClick", function(self) D.Pick(self.window, self.what, self.value) end)
      m.items[i] = b
    end
    b.window, b.what, b.value = w, what, value
    b.text:SetText(labels[value] or value)
    if value == cur then b.text:SetTextColor(Theme:Color("accent")) else b.text:SetTextColor(0.9, 0.9, 0.9) end
    b:Show()
  end
  for i = #list + 1, #m.items do m.items[i]:Hide() end
  m:SetHeight(#list * 18 + 4)
  m:ClearAllPoints(); m:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 0, -2)
  m.window, m.what = w, what
  m:Show()
  return m
end
function D.Pick(w, what, value)
  Schema:Set("embers.w" .. w.index .. (what == "source" and ".session" or ".meter"), value)
  if D.menu then D.menu:Hide() end
end
local cycle = Window.Cycle
function Window.Cycle(w, what)
  if s.typeMenu and (what == "meter" or s.typeMenuSessions) then
    if D.menu and D.menu:IsShown() and D.menu.window == w and D.menu.what == what then D.menu:Hide() return end
    return D.Menu(w, what)
  end
  return cycle(w, what)
end

-- Dock --------------------------------------------------------------------------------------------------------
PUI.Layout:RegisterElement("embers.dock", { label = "Embers dock", owner = OWNER, size = { 240, 180 },
  default = { point = "BOTTOMRIGHT", x = -19, y = 45 } })
function D.Container()
  if D.frame then return D.frame end
  local f = PUI:CreateFrame("Frame", "PhoenixUI_EmbersDock", UIParent, nil, OWNER)
  f:SetSize(240, 180)
  D.frame = f
  return f
end
-- Arrange(): docked windows chain inside the container; free windows go back to their own movers.
function D.Arrange()
  local list = {}
  for i = 1, #EM.windows do local w = EM.windows[i]; if w.frame:IsShown() then list[#list + 1] = w end end
  if s.dock == "free" or not EM.active then
    if D.frame then D.frame:Hide() end
    for _, w in ipairs(list) do if w.docked then w.docked = nil; Layout:Place(w.frame, "embers.window" .. w.index) end end
    return 0
  end
  local c = D.Container()
  c:Show()
  Layout:Place(c, "embers.dock")
  local wSum, hSum, wMax, hMax = 0, 0, 0, 0
  for i, w in ipairs(list) do
    local f = w.frame
    Layout.frames["embers.window" .. w.index] = nil -- the dock places it now
    w.docked = true
    f:ClearAllPoints()
    if i == 1 then f:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    elseif s.dock == "row" then f:SetPoint("TOPLEFT", list[i - 1].frame, "TOPRIGHT", s.dockGap, 0)
    else f:SetPoint("TOPLEFT", list[i - 1].frame, "BOTTOMLEFT", 0, -s.dockGap) end
    local fw, fh = f:GetWidth() or 0, f:GetHeight() or 0
    wSum, hSum = wSum + fw + (i > 1 and s.dockGap or 0), hSum + fh + (i > 1 and s.dockGap or 0)
    wMax, hMax = math.max(wMax, fw), math.max(hMax, fh)
  end
  if s.dock == "row" then c:SetSize(math.max(1, wSum), math.max(1, hMax)) else c:SetSize(math.max(1, wMax), math.max(1, hSum)) end
  return #list
end

-- Wiring into the windows ---------------------------------------------------------------------------------------
local create = Window.Create
function Window.Create(index)
  local w = create(index)
  local f = w.frame
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta) D.Scroll(w, delta) end)
  f:SetScript("OnEnter", function() D.Hover(w, true) end)
  f:SetScript("OnLeave", function() left(w) end)
  w.title:HookScript("OnEnter", function() D.Hover(w, true) end)
  w.title:HookScript("OnLeave", function() left(w) end)
  for _, r in ipairs(w.rows) do
    r:HookScript("OnEnter", function() D.Hover(w, true) end)
    r:HookScript("OnLeave", function() left(w) end)
  end
  w.scrollLine = f:CreateTexture(nil, "OVERLAY")
  w.scrollLine:SetWidth(2); w.scrollLine:Hide()
  return w
end
local update = Window.Update
function Window.Update(w)
  D.offset = s.wheel and w.offset or 0
  update(w)
  D.offset = 0
  if w.scrollLine then paintScroll(w) end
  if w.title then D.Hover(w, w.hover == true) end
end

local refresh = EM.RefreshWindows
function EM.RefreshWindows()
  refresh()
  D.Arrange()
end
PUI.Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then D.Arrange() end end)
PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then D.Arrange() end end)

-- Report queue (W9) ------------------------------------------------------------------------------------------------
D.queued = nil
D.HARDWARE = { SAY = true, YELL = true }
function D.Post()
  local q = D.queued
  if not q then return false end
  local ok, why = EM.CanReport()
  if not ok then return false, why end
  D.queued = nil
  D.events:UnregisterAllEvents()
  if D.HARDWARE[q.channel] then
    PUI.Dialogs:Confirm({ title = "Post the Embers report?", text = "The fight is over: post the report to " .. q.channel:lower() .. " now?",
      accept = "Post", onAccept = function() EM.Report(q.index, q.channel) end })
    return true
  end
  return EM.Report(q.index, q.channel)
end
local report = EM.Report
function EM.Report(index, channel)
  local ok, why = report(index, channel)
  if ok or not s.queueReport then return ok, why end
  local seg = (Schema:Get("embers.segments") or {})[index or 1]
  if not seg then return ok, why end
  D.queued = { index = index or 1, channel = (channel or "SAY"):upper() }
  local e = D.events
  e:RegisterEvent("CHALLENGE_MODE_COMPLETED"); e:RegisterEvent("PVP_MATCH_COMPLETE"); e:RegisterEvent("ENCOUNTER_END")
  PUI.CombatQueue.Defer("embers.report", function() if D.queued and not C_ChatInfo.InChatMessagingLockdown() then D.Post() end end)
  if PUI.Toast then PUI.Toast:Show("Embers report waits until chat is allowed (" .. why .. ")", "warn", true) end
  if s.reportCopy then PUI.Dialogs:Copy("Embers report", table.concat(EM.ReportLines(seg), "\n"), "Ctrl+C to paste it yourself.") end
  return false, "queued"
end
D.events = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
D.events:SetScript("OnEvent", function()
  -- the key/match/boss just ended: post once combat is over (CombatQueue runs it now when already out of combat)
  PUI.CombatQueue.Defer("embers.report", function() D.Post() end)
end)

local function key(name, def)
  def.owner = OWNER
  def.apply = function(v)
    s[name] = v
    if D.menu then D.menu:Hide() end
    if EM.active then EM.RefreshWindows() end
  end
  EM.schema["embers." .. name] = def
  Schema:Register("embers." .. name, def)
  s[name] = Schema:Get("embers." .. name)
end
key("fade", { type = "toggle", default = false, mode = "simple", label = "Fade the header until hovered",
  tooltip = "The header, background and border fade out and come back while your mouse is over the window; the rows stay." })
key("fadeAlpha", { type = "range", default = 0.15, min = 0, max = 0.9, step = 0.05, mode = "advanced", label = "Faded header opacity",
  tooltip = "How visible the header and background are while the mouse is away." })
key("wheel", { type = "toggle", default = true, mode = "simple", label = "Scroll rows with the mouse wheel",
  tooltip = "The mouse wheel scrolls through everyone in the fight; there is no scroll bar." })
key("scrollLine", { type = "toggle", default = false, mode = "advanced", label = "Thin scroll marker",
  tooltip = "A thin accent line at the right edge shows where you are while scrolled." })
key("dock", { type = "select", default = "free", choices = { "free", "row", "column" },
  choiceLabels = { free = "Free (each window has its own mover)", row = "Docked side by side", column = "Docked in a column" },
  mode = "simple", label = "Window layout", tooltip = "Dock several meter windows together under one Studio mover (Embers dock), or leave them free." })
key("dockGap", { type = "range", default = 2, min = 0, max = 20, step = 1, mode = "advanced", label = "Docked window gap",
  tooltip = "Space between docked windows." })
key("typeMenu", { type = "toggle", default = true, mode = "simple", label = "Pick the meter from a list",
  tooltip = "A click on a window's header opens a Phoenix list of meter types instead of cycling through them." })
key("typeMenuSessions", { type = "toggle", default = true, mode = "advanced", label = "Pick the fight from a list",
  tooltip = "A right click on the header opens a list of fights (current, overall, last saved) instead of cycling." })
key("queueReport", { type = "toggle", default = true, mode = "simple", label = "Post blocked reports later",
  tooltip = "Where the game blocks addon chat (Mythic+, PvP, boss fights), a report waits and posts when the key, match or boss ends. Say and Yell ask you first." })
key("reportCopy", { type = "toggle", default = true, mode = "advanced", label = "Open a blocked report in the copy box",
  tooltip = "While a report waits, it also opens in the copy box so you can paste it yourself." })
