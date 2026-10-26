local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Panel (/pui sentinel): incident list, what is collected, opt-in, taint log
-- and sampler switches, export string and "Send now". Built on first open.
local S = PUI.Sentinel
local Panel = {}
S.Panel = Panel


local COLLECTED = "Collected locally: Phoenix errors (message, stack, locals), taint blocks, settings problems, "
  .. "missing game APIs, your class/spec/level, zone and difficulty, combat flag, group size, Phoenix settings, "
  .. "loaded addon names and versions, FPS/latency/CPU. Never: chat text, other players' names, friends, addon messages. "
  .. "Your character name only if you allow it."

local function button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function toggleLabel(key, on, off)
  return PUI.Schema:Get(key) and on or off
end

function Panel:Build()
  local f = PUI:CreateFrame("Frame", "PhoenixUISentinelPanel", UIParent, nil, "Sentinel")
  f:SetSize(620, 500)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "PhoenixUISentinelPanel")
  PUI.Theme:Backdrop(f, "surface.0")
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText("Phoenix UI - Sentinel")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  f.status:SetPoint("RIGHT", -14, 0)
  f.status:SetJustifyH("LEFT")
  local info = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  info:SetPoint("TOPLEFT", f.status, "BOTTOMLEFT", 0, -6)
  info:SetPoint("RIGHT", -14, 0)
  info:SetJustifyH("LEFT")
  info:SetText(COLLECTED)
  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -8)
  sep:SetPoint("RIGHT", -14, 0)
  PUI.Theme:Paint(sep, "line")

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", -32, 106)
  local box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true)
  box:SetFontObject(ChatFontSmall)
  box:SetWidth(560)
  box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  scroll:SetScrollChild(box)
  f.box = box

  local row1 = {
    button(f, "", 140, function() Panel:Flip("sentinel.optIn") end),
    button(f, "", 140, function() Panel:Flip("sentinel.taintLogSession") end),
    button(f, "", 140, function() Panel:Flip("sentinel.perfSampler") end),
    button(f, "", 140, function() Panel:Flip("sentinel.safeMode") end),
  }
  local row2 = {
    button(f, "Incidents", 140, function() Panel:ShowList() end),
    button(f, "Export string", 140, function() Panel:ShowExport() end),
    button(f, "Send now", 140, function() Panel:SendNow() end),
    button(f, "Clear", 140, function() S.Capture:Clear(); Panel:ShowList() end),
  }
  local row3 = {
    button(f, "< Newer", 140, function() Panel:Step(-1) end),
    button(f, "Older >", 140, function() Panel:Step(1) end),
    button(f, "Copy", 140, function() Panel:CopySelected() end),
    button(f, "Copy all from this session", 140, function() Panel:CopySession() end),
  }
  for i = 1, 4 do
    row3[i]:SetPoint("BOTTOMLEFT", 14 + (i - 1) * 148, 72)
    row1[i]:SetPoint("BOTTOMLEFT", 14 + (i - 1) * 148, 42)
    row2[i]:SetPoint("BOTTOMLEFT", 14 + (i - 1) * 148, 12)
  end
  f.toggles = row1
  self.frame = f
  return f
end

function Panel:Flip(key)
  PUI.Schema:Set(key, not PUI.Schema:Get(key))
  self:Refresh()
end

function Panel:Refresh()
  local f = self.frame
  local db = S.db
  local n, total = 0, 0
  for _, inc in pairs(db.incidents) do n = n + 1; total = total + inc.count end
  local last = db.lastSent and (date("%Y-%m-%d %H:%M", db.lastSent.at) .. " (" .. db.lastSent.reports .. " reports, " .. db.lastSent.via .. ")") or "never"
  f.status:SetText(string.format("Incidents: %d (%d occurrences)   Sharing: %s   Last report: %s   Error capture: %s",
    n, total, db.optIn and "on" or "off", last, PUI.SentinelHook.mode or "?"))
  f.toggles[1]:SetText(toggleLabel("sentinel.optIn", "Sharing: on", "Sharing: off"))
  f.toggles[2]:SetText(toggleLabel("sentinel.taintLogSession", "Taint log: on", "Taint log: off"))
  f.toggles[3]:SetText(toggleLabel("sentinel.perfSampler", "Sampler: on", "Sampler: off"))
  f.toggles[4]:SetText(toggleLabel("sentinel.safeMode", "Safe mode: on", "Safe mode: off"))
end

function Panel:ShowList()
  local lines = {}
  local list = S.Viewer:List(false)
  self.selected = nil
  for i = 1, #list do
    local inc = list[i]
    lines[#lines + 1] = string.format("%d. [%s][%s][%s] x%d  %s", i, inc.severity or "?", inc.kind, inc.module, inc.count, inc.message:sub(1, 160))
  end
  if #list > 0 then lines[#lines + 1] = "\nUse 'Older >' to open an incident, then 'Copy'." end
  for name in pairs(S.db.safeModed) do lines[#lines + 1] = "Safe mode: " .. name .. " (use /pui sentinel enable " .. name .. ")" end
  if #lines == 0 then lines[1] = "No incidents. Use /pui sentinel induce to create a test error." end
  self.frame.box:SetText(table.concat(lines, "\n"))
  self:Refresh()
end

function Panel:ShowExport()
  local text, why = S.Export:Build()
  self.frame.box:SetText(text or why)
  if text then
    self.frame.box:SetFocus()
    self.frame.box:HighlightText()
  end
  self:Refresh()
end

-- Writes SavedVariables to disk by reloading; the Companion uploads from there.
function Panel:SendNow()
  if not S.db.optIn then
    self:Open()
    self.frame.box:SetText("Turn on 'Sharing' first. Nothing leaves this computer while it is off.")
    return
  end
  S.db.lastSent = { at = time(), reports = 0, via = "companion" }
  for _ in pairs(S.db.incidents) do S.db.lastSent.reports = S.db.lastSent.reports + 1 end
  C_UI.Reload()
end

-- Selection: index into the newest-first list; nil shows the overview list.
function Panel:Select(index)
  local list = S.Viewer:List(false)
  if #list == 0 then self.selected = nil; return self:ShowList() end
  index = math.max(1, math.min(#list, index))
  self.selected = index
  self.frame.box:SetText(string.format("Incident %d of %d\n\n", index, #list) .. S.Viewer:Text(list[index]))
  self:Refresh()
  return list[index]
end

function Panel:Step(delta)
  if not self.selected then
    if delta > 0 then return self:Select(1) end
    return
  end
  local nextIndex = self.selected + delta
  if nextIndex < 1 then return self:ShowList() end
  return self:Select(nextIndex)
end

-- Plain-text copy window: one selectable edit box, text highlighted for Ctrl+C.
function Panel:BuildCopy()
  local c = PUI:CreateFrame("Frame", "PhoenixUISentinelCopy", UIParent, nil, "Sentinel")
  c:SetSize(600, 420)
  c:SetPoint("CENTER", 20, -20)
  c:SetFrameStrata("DIALOG")
  c:EnableMouse(true)
  tinsert(UISpecialFrames, "PhoenixUISentinelCopy")
  PUI.Theme:Backdrop(c, "surface.1")
  local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText("Copy (Ctrl+C), then Escape")
  local close = CreateFrame("Button", nil, c, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  local scroll = CreateFrame("ScrollFrame", nil, c, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -36)
  scroll:SetPoint("BOTTOMRIGHT", -32, 14)
  local box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true)
  box:SetFontObject(ChatFontSmall)
  box:SetWidth(550)
  box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", function() c:Hide() end)
  -- Read-only: any edit snaps back to the copied text.
  box:SetScript("OnTextChanged", function(b, user) if user and c.copyText then b:SetText(c.copyText); b:HighlightText() end end)
  scroll:SetScrollChild(box)
  c.copyBox = box
  self.copy = c
  return c
end

function Panel:ShowCopy(text)
  local c = self.copy or self:BuildCopy()
  c.copyText = text
  c.copyBox:SetText(text)
  c:Show()
  c.copyBox:SetFocus()
  c.copyBox:HighlightText()
  return c
end

function Panel:CopySelected()
  local list = S.Viewer:List(false)
  local inc = self.selected and list[self.selected] or list[1]
  if not inc then return self:ShowCopy("No incidents.") end
  return self:ShowCopy(S.Viewer:Text(inc))
end

function Panel:CopySession()
  return self:ShowCopy(S.Viewer:SessionText())
end

function Panel:Open()
  local f = self.frame or self:Build()
  f:Show()
  self:ShowList()
end

function Panel:Toggle()
  if self.frame and self.frame:IsShown() then self.frame:Hide() else self:Open() end
end
