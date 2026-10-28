local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Error reporter window (mockup 15; BugSack parity + upgrades). Tabs:
-- Errors (sessions this / previous / all, source every addon / Phoenix /
-- others, plain search, previous / next with a counter, message, stack and
-- locals, fingerprint, resolved state, copy, share with a player, preview
-- of the upload, send now, wipe behind a confirm), Diagnostics and
-- Profiler. Built on first open; everything shown is plain stored text.
local S = PUI.Sentinel
local R = { index = 1, tab = "errors" }
S.Reporter = R
local Schema = PUI.Schema

local function font(fs, role) fs:SetFontObject(PUI.Media:FontObject(role or "small")) end
local function button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22); b:SetText(text); b:SetScript("OnClick", onClick)
  return b
end
local function stamp(t) return t and date("%H:%M", t) or "?" end

R.format, R.collapsed = "plain", {}
function R:Opts()
  return { session = self.session or Schema:Get("sentinel.viewerSession"), source = self.source or Schema:Get("sentinel.viewerSource"), query = self.query,
    severity = self.severity or "all" }
end
function R:Grouped() return Schema:Get("sentinel.viewerGroup") ~= "flat" end
-- The list the viewer steps through: severity-filtered, and in section order when grouped.
function R:List()
  local opts = self:Opts()
  local out = {}
  if self:Grouped() then
    for _, g in ipairs(S.Sections:Groups(opts)) do for _, inc in ipairs(g.errors) do out[#out + 1] = inc end end
    return out
  end
  for _, inc in ipairs(S.Store:List(opts)) do
    if opts.severity == "all" or (inc.severity or "S2") == opts.severity then out[#out + 1] = inc end
  end
  return out
end
function R:IsCollapsed(addon)
  local c = self.collapsed[addon]
  if c == nil then return Schema:Get("sentinel.viewerCollapsed") and true or false end
  return c
end
function R:ToggleSection(addon) self.collapsed[addon] = not self:IsCollapsed(addon); self:Paint() end
function R:CycleFormat()
  local F = S.Sections.FORMATS
  for i = 1, #F do if F[i] == self.format then self.format = F[i % #F + 1]; break end end
  self:Paint()
  return self.format
end
function R:CurrentGroup()
  local inc = self:Current()
  if not inc then return nil end
  local name = S.Sections.AddonOf(inc)
  for _, g in ipairs(S.Sections:Groups(self:Opts())) do if g.addon == name then return g end end
end
function R:CopyError() local inc = self:Current(); return PUI.Dialogs:Copy("Error (" .. self.format .. ")", inc and S.Sections.ErrorText(inc, self.format) or "No errors.", "Ctrl+C to copy") end
function R:CopyGroup() local g = self:CurrentGroup(); return PUI.Dialogs:Copy("Addon section (" .. self.format .. ")", g and S.Sections.GroupText(g, self.format) or "No errors.", "Ctrl+C to copy") end
function R:CopyAll() return PUI.Dialogs:Copy("Every error (" .. self.format .. ")", S.Sections:AllText(self:Opts(), self.format), "Ctrl+C to copy") end
function R:ClearSession()
  PUI.Dialogs:Confirm({ title = "Clear this session", text = "Delete this session's errors from this PC? Earlier sessions and resolved states are kept.",
    accept = "Clear", cancel = "Keep", danger = true, onAccept = function() S.Sections:ClearSession(); S.Alerts:Seen(); R.index = 1; R:Paint() end })
end

-- Text(inc, i, n) -> the body for one error (also used by Copy).
function R.Text(inc, i, n)
  if not inc then return "No errors here. Errors are never hidden: try All sessions or Every addon." end
  local state, label = S.Store:State(inc)
  local lines = {
    string.format("Error %d of %d    [x%d]  %s%s", i or 1, n or 1, inc.count or 1, inc.other and ("addon " .. tostring(inc.addon)) or ("Phoenix " .. tostring(inc.module)),
      inc.severity and ("  " .. inc.severity) or ""),
    tostring(inc.message or ""),
    "",
    "Stack:",
    (inc.stack and inc.stack ~= "") and inc.stack or "(none)",
    "",
    "Locals:",
    (inc.locals and inc.locals ~= "") and inc.locals or "(none)",
    "",
    string.format("First %s   last %s   build %s   %s   fingerprint %s", stamp(inc.firstSeen), stamp(inc.lastSeen), tostring(inc.build or PUI.BUILD),
      tostring(inc.addonVersion or S:Version()), S.Store.Fingerprint(inc)),
    "State: " .. label .. (state == "ignored" and " (no alerts; still listed)" or ""),
    inc.other and "Privacy: other addons' errors stay on this PC" .. (Schema:Get("sentinel.uploadOthers") and " unless uploads include them (on)" or " (uploads exclude them)")
      or "Privacy: names -> [player], GUIDs keep only their kind (see Preview)",
  }
  return table.concat(lines, "\n")
end

function R:Build()
  local f = PUI:CreateFrame("Frame", "PhoenixUISentinelReporter", UIParent, nil, "Sentinel")
  f:SetSize(940, 580); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH")
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "PhoenixUISentinelReporter")
  PUI.Theme:Backdrop(f, "surface.0")
  local accent = f:CreateTexture(nil, "ARTWORK"); accent:SetPoint("TOPLEFT"); accent:SetPoint("TOPRIGHT"); accent:SetHeight(2)
  PUI.Theme:Paint(accent, "accent")
  f.title = f:CreateFontString(nil, "OVERLAY"); font(f.title, "header"); f.title:SetPoint("TOPLEFT", 14, -12)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 0, 0)
  f.tabs = {}
  for i, t in ipairs({ { "errors", "Errors" }, { "diag", "Diagnostics" }, { "profile", "Profiler" } }) do
    local b = button(f, t[2], 96, function() R.tab = t[1]; R:Paint() end)
    b:SetPoint("TOPRIGHT", -30 - (3 - i) * 100, -10); f.tabs[t[1]] = b
  end
  f.filters = {}
  local x = 14
  for _, t in ipairs({ { "session", "this", "This session" }, { "session", "previous", "Previous" }, { "session", "all", "All" },
    { "source", "phoenix", "Phoenix only" }, { "source", "others", "Other addons" }, { "source", "all", "Every addon" } }) do
    local b = button(f, t[3], t[3]:len() * 7 + 18, function() R[t[1]] = t[2]; R.index = 1; R:Paint() end)
    b:SetPoint("TOPLEFT", x, -40); x = x + b:GetWidth() + 4
    b.group, b.value = t[1], t[2]
    f.filters[#f.filters + 1] = b
  end
  local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  search:SetSize(150, 20); search:SetPoint("TOPRIGHT", -18, -41); search:SetAutoFocus(false)
  search:SetScript("OnTextChanged", function(b) R.query = b:GetText(); R.index = 1; R:Paint() end)
  search:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
  f.search = search
  -- Severity chip row + the Phoenix vs other addons split.
  f.chips = {}
  local cx = 14
  for _, sev in ipairs({ "all", "S0", "S1", "S2", "S3" }) do
    local b = button(f, sev == "all" and "All" or sev, 64, function() R.severity = sev; R.index = 1; R:Paint() end)
    b:SetPoint("TOPLEFT", cx, -66); cx = cx + 68
    b.value = sev
    f.chips[#f.chips + 1] = b
  end
  f.split = f:CreateFontString(nil, "OVERLAY"); font(f.split, "small"); f.split:SetPoint("LEFT", f.chips[#f.chips], "RIGHT", 12, 0)
  f.split:SetPoint("RIGHT", -18, 0); f.split:SetJustifyH("LEFT")
  PUI.Theme:Paint(f.split, "text.secondary", nil, "text")
  -- Sections sidebar: one collapsible header per addon, its errors under it.
  local side = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  side:SetPoint("TOPLEFT", 14, -96); side:SetPoint("BOTTOMLEFT", 14, 92); side:SetWidth(270)
  local list = CreateFrame("Frame", nil, side); list:SetSize(270, 10)
  side:SetScrollChild(list)
  PUI.Theme:Backdrop(side, "surface.1")
  f.side, f.sideList, f.rows = side, list, {}
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -96); scroll:SetPoint("BOTTOMRIGHT", -34, 92)
  f.scroll = scroll
  local box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true); box:SetFontObject(ChatFontSmall); box:SetWidth(700); box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", function() f:Hide() end)
  box:SetScript("OnTextChanged", function(b, user) if user and R.bodyText then b:SetText(R.bodyText) end end)
  scroll:SetScrollChild(box)
  f.body = box
  local row1 = {
    button(f, "< Prev", 70, function() R:Step(-1) end), button(f, "Next >", 70, function() R:Step(1) end),
    button(f, "Copy error", 80, function() R:CopyError() end),
    button(f, "Copy addon", 84, function() R:CopyGroup() end),
    button(f, "Copy all", 70, function() R:CopyAll() end),
    button(f, "Format: plain", 110, function() R:CycleFormat() end),
    button(f, "Send to player...", 120, function() R:ShowShare() end),
    button(f, "Preview upload", 110, function() PUI.Dialogs:Copy("What leaves this PC", S.Upload:PreviewText()) end),
    button(f, "Report to dashboard", 140, function() S.Panel:SendNow() end),
  }
  local row2 = {
    button(f, "Mark known", 90, function() R:Mark("known") end), button(f, "Ignore alerts", 100, function() R:Mark("ignored") end),
    button(f, "Fixed in this version", 150, function() R:Mark("fixed", S:Version()) end), button(f, "Mark new", 80, function() R:Mark("new") end),
    button(f, "Clear session...", 110, function() R:ClearSession() end),
    button(f, "Wipe all...", 80, function() R:ConfirmWipe() end),
  }
  for i, b in ipairs(row1) do b:SetPoint("BOTTOMLEFT", i == 1 and 14 or 0, 58); if i > 1 then b:SetPoint("LEFT", row1[i - 1], "RIGHT", 4, 0) end end
  for i, b in ipairs(row2) do b:SetPoint("BOTTOMLEFT", i == 1 and 14 or 0, 32); if i > 1 then b:SetPoint("LEFT", row2[i - 1], "RIGHT", 4, 0) end end
  f.row1, f.row2 = row1, row2
  f.formatButton = row1[6]
  f.status = f:CreateFontString(nil, "OVERLAY"); font(f.status, "small"); f.status:SetPoint("BOTTOMLEFT", 14, 12)
  PUI.Theme:Paint(f.status, "text.secondary", nil, "text")
  -- Share box (you start it; the receiver gets a prompt).
  local sh = CreateFrame("Frame", nil, f)
  sh:SetSize(260, 96); sh:SetPoint("BOTTOMRIGHT", -14, 88); PUI.Theme:Backdrop(sh, "surface.1"); sh:Hide()
  sh.label = sh:CreateFontString(nil, "OVERLAY"); font(sh.label, "small"); sh.label:SetPoint("TOPLEFT", 8, -8); sh.label:SetWidth(244); sh.label:SetJustifyH("LEFT")
  sh.to = CreateFrame("EditBox", nil, sh, "InputBoxTemplate"); sh.to:SetSize(150, 20); sh.to:SetPoint("BOTTOMLEFT", 14, 8); sh.to:SetAutoFocus(false)
  sh.send = button(sh, "Send", 70, function() R:DoShare(sh.to:GetText()) end); sh.send:SetPoint("BOTTOMRIGHT", -8, 8)
  f.share = sh
  self.frame = f
  return f
end

function R:Current()
  local list = self:List()
  self.index = math.max(1, math.min(self.index, #list))
  return list[self.index], #list
end
function R:Step(d) self.index = self.index + d; self:Paint() end
function R:Mark(state, ver)
  local inc = self:Current()
  if not inc then return end
  S.Store:SetState(inc.hash, state, ver)
  self:Paint()
end
function R:ConfirmWipe()
  PUI.Dialogs:Confirm({ title = "Wipe error reports", text = "Delete every stored error (Phoenix and other addons) from this PC? Resolved states are kept.",
    accept = "Wipe", cancel = "Keep", danger = true, onAccept = function() S.Store:Wipe(true); S.Alerts:Seen(); R.index = 1; R:Paint() end })
end
function R:ShowShare()
  local sh = self.frame.share
  local inc = self:Current()
  if not inc then return end
  local packed = S.Share.Pack(inc)
  local n = #S.Share.Split(packed, S.Share.CHUNK)
  sh.label:SetText(string.format("Send this report to a player.\nSize %.1f KB - %d chunks - checksum %s\nThey get an accept prompt first.", #packed / 1024, n, S.Share.Checksum(packed)))
  sh:SetShown(not sh:IsShown())
end
function R:DoShare(target)
  local inc = self:Current()
  if not inc then return nil end
  local r, why = S.Share:Offer(inc, target)
  self.frame.share:Hide()
  PUI.Slash.Print(r and string.format("offered the report to %s (%d chunks); it is sent once they accept", target, r.chunks) or ("not sent: " .. tostring(why)))
  return r
end

-- Sidebar rows (pooled): section headers and error rows.
function R:Row(i)
  local f = self.frame
  local r = f.rows[i]
  if not r then
    r = CreateFrame("Button", nil, f.sideList)
    r:SetSize(262, 20)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
    r.text = r:CreateFontString(nil, "OVERLAY"); font(r.text, "small"); r.text:SetPoint("LEFT", 6, 0); r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
    r:SetScript("OnClick", function(b)
      if b.addon then R:ToggleSection(b.addon) elseif b.index then R.index = b.index; R:Paint() end
    end)
    f.rows[i] = r
  end
  return r
end
local function firstLineOf(text) return ((tostring(text or "")):match("^[^\n]*") or ""):sub(1, 90) end
function R:SectionRows()
  local rows = {}
  local cur = self:Current()
  local index = 0
  for _, g in ipairs(S.Sections:Groups(self:Opts())) do
    local closed = self:IsCollapsed(g.addon)
    rows[#rows + 1] = { addon = g.addon, header = true, text = string.format("%s %s  %d / x%d", closed and "+" or "-", g.addon, g.count, g.events),
      tip = S.Sections.GroupHeader(g), phoenix = g.phoenix }
    for _, inc in ipairs(g.errors) do
      index = index + 1
      if not closed then rows[#rows + 1] = { index = index, text = string.format("   x%d  %s", inc.count or 1, firstLineOf(inc.message)), on = inc == cur } end
    end
  end
  return rows
end
function R:PaintSections()
  local f = self.frame
  local grouped = self:Grouped() and self.tab == "errors" and not self.received
  f.side:SetShown(grouped)
  f.scroll:SetPoint("TOPLEFT", grouped and 296 or 14, -96)
  f.body:SetWidth(grouped and 590 or 870)
  local rows = grouped and self:SectionRows() or {}
  for i, d in ipairs(rows) do
    local r = self:Row(i)
    r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 21)
    r.addon, r.index = d.header and d.addon or nil, d.index
    r.text:SetText(d.text)
    PUI.Theme:Paint(r.bg, d.header and "surface.2" or (d.on and "accent" or "surface.1"), d.on and 0.35 or 1)
    PUI.Theme:Paint(r.text, d.header and (d.phoenix and "accent" or "text.primary") or "text.secondary", nil, "text")
    r:Show()
  end
  for i = #rows + 1, #f.rows do f.rows[i]:Hide() end
  f.sideList:SetHeight(math.max(10, #rows * 21 + 8))
end
function R:PaintFilters()
  local o = self:Opts()
  for _, b in ipairs(self.frame.filters) do b:SetAlpha(o[b.group] == b.value and 1 or 0.55) end
  local counts = S.Sections:SeverityCounts({ session = o.session, source = o.source, query = o.query })
  for _, b in ipairs(self.frame.chips) do
    b:SetText((b.value == "all" and "All" or b.value) .. " " .. (counts[b.value] or 0))
    b:SetAlpha(o.severity == b.value and 1 or 0.55)
  end
  for id, b in pairs(self.frame.tabs) do b:SetAlpha(id == self.tab and 1 or 0.55) end
end
function R:SetBody(text)
  self.bodyText = text
  self.frame.body:SetText(text)
end
function R:Paint()
  local f = self.frame
  if not (f and f:IsShown()) then return end
  self:PaintFilters()
  local errors = self.tab == "errors"
  for _, b in ipairs(f.filters) do b:SetShown(errors) end
  f.search:SetShown(errors)
  for _, b in ipairs(f.row1) do b:SetShown(errors) end
  for _, b in ipairs(f.row2) do b:SetShown(errors) end
  for _, b in ipairs(f.chips) do b:SetShown(errors) end
  f.split:SetShown(errors)
  f.formatButton:SetText("Format: " .. self.format)
  local sp = S.Sections:Split(self:Opts())
  local conflicts = S.Sections:Conflicts()
  local hint = conflicts[1] and string.format("   possible conflict: %s (%d shared session%s)", conflicts[1].addon, conflicts[1].sessions, conflicts[1].sessions == 1 and "" or "s") or ""
  f.split:SetText(string.format("Phoenix %d (x%d)   other addons %d (x%d)%s%s", sp.phoenix, sp.phoenixEvents, sp.others, sp.otherEvents, hint,
    PUI.SentinelHook.flooded > 0 and string.format("   flood guard skipped %d", PUI.SentinelHook.flooded) or ""))
  self:PaintSections()
  local c = S.Store:Counts()
  f.title:SetText(string.format("Sentinel  -  error reports   this session %d  -  previous %d  -  all %d", c.session, c.previous, c.all))
  if self.tab == "diag" then self:SetBody(PUI.Diag:Text())
  elseif self.tab == "profile" then self:SetBody(PUI.Profiler:ReportText())
  elseif self.received then self:SetBody(self.received)
  else
    local inc, n = self:Current()
    self:SetBody(R.Text(inc, self.index, n))
  end
  f.status:SetText(S.Upload:Status())
end

function R:Open(inc)
  local f = self.frame or self:Build()
  self.received = nil
  self.tab = "errors"
  f:Show()
  if inc then
    self.session, self.source = "all", "all"
    for i, x in ipairs(self:List()) do if x == inc then self.index = i end end
  end
  S.Alerts:Seen()
  self:Paint()
end
function R:OpenReceived(i)
  local rep = S.db.received and S.db.received[i]
  if not rep then return end
  local f = self.frame or self:Build()
  f:Show()
  self.received = string.format("Received from %s at %s (checksum verified)\n\n%s\n\nStack:\n%s\n\nLocals:\n%s", tostring(rep.receivedFrom), stamp(rep.receivedAt),
    tostring(rep.message), tostring(rep.stack or "(none)"), tostring(rep.locals or "(none)"))
  self:Paint()
end
function R:Toggle() if self.frame and self.frame:IsShown() then self.frame:Hide() else self:Open() end end

PUI.Links:Register("sentinel", function(hash)
  local inc = S.db.incidents[hash] or (S.db.others and S.db.others[hash])
  R:Open(inc)
end)
