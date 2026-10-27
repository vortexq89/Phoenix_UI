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

function R:Opts()
  return { session = self.session or Schema:Get("sentinel.viewerSession"), source = self.source or Schema:Get("sentinel.viewerSource"), query = self.query }
end
function R:List() return S.Store:List(self:Opts()) end

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
  f:SetSize(760, 500); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH")
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
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 14, -70); scroll:SetPoint("BOTTOMRIGHT", -34, 92)
  local box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true); box:SetFontObject(ChatFontSmall); box:SetWidth(700); box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", function() f:Hide() end)
  box:SetScript("OnTextChanged", function(b, user) if user and R.bodyText then b:SetText(R.bodyText) end end)
  scroll:SetScrollChild(box)
  f.body = box
  local row1 = {
    button(f, "< Prev", 70, function() R:Step(-1) end), button(f, "Next >", 70, function() R:Step(1) end),
    button(f, "Copy", 60, function() PUI.Dialogs:Copy("Error report", R.Text(R:Current(), R.index, #R:List()), "Ctrl+C to copy") end),
    button(f, "Share with player...", 140, function() R:ShowShare() end),
    button(f, "Preview upload", 110, function() PUI.Dialogs:Copy("What leaves this PC", S.Upload:PreviewText()) end),
    button(f, "Send to dashboard now", 160, function() S.Panel:SendNow() end),
  }
  local row2 = {
    button(f, "Mark known", 90, function() R:Mark("known") end), button(f, "Ignore alerts", 100, function() R:Mark("ignored") end),
    button(f, "Fixed in this version", 150, function() R:Mark("fixed", S:Version()) end), button(f, "Mark new", 80, function() R:Mark("new") end),
    button(f, "Wipe...", 70, function() R:ConfirmWipe() end),
  }
  for i, b in ipairs(row1) do b:SetPoint("BOTTOMLEFT", i == 1 and 14 or 0, 58); if i > 1 then b:SetPoint("LEFT", row1[i - 1], "RIGHT", 4, 0) end end
  for i, b in ipairs(row2) do b:SetPoint("BOTTOMLEFT", i == 1 and 14 or 0, 32); if i > 1 then b:SetPoint("LEFT", row2[i - 1], "RIGHT", 4, 0) end end
  f.row1, f.row2 = row1, row2
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

function R:PaintFilters()
  local o = self:Opts()
  for _, b in ipairs(self.frame.filters) do b:SetAlpha(o[b.group] == b.value and 1 or 0.55) end
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
