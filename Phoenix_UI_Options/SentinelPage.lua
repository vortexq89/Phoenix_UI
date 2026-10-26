local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Sentinel viewer (mockup 14): grouped, deduplicated incidents in the options
-- window. Tabs This session / All / Resolved, a filter box, counts by kind,
-- an incident list and a detail pane (message, build/zone/combat, numbered
-- stack, locals, a hint) with Mark resolved and Copy report. Incident text is
-- already plain text from Capture; nothing here reads live game values.
local Options, Theme = PUI.Options, PUI.Theme
local Model, Schema, Kit, A = Options.Model, PUI.Schema, Options.Kit, Options.Assets
local SP = { tab = "session", filter = "" }
Options.SentinelPage = SP
Options.views = Options.views or {}

local LIST_W, ITEM_H = 380, 78
local KIND = {
  error = { "Lua error", "err" }, secret = { "Secret value", "err" }, taint = { "Taint block", "warn" },
  perf = { "Performance", "info" }, drift = { "API drift", "warn" }, integrity = { "Integrity", "warn" },
  test = { "Test", "muted" }, heartbeat = { "Heartbeat", "muted" },
}
local HINTS = {
  secret = "Secret values can't be compared or used in arithmetic in combat. Pass them to a StatusBar, FontString or duration object instead.",
  taint = "A protected action was blocked. Phoenix queues protected work until combat ends; another addon may have tainted this path.",
  perf = "A frame update went over budget. Check the sampler numbers and the module's update rate.",
}

local function S() return PUI.Sentinel end

function SP.Resolved(inc) return inc.resolvedAt ~= nil and inc.resolvedAt >= (inc.lastSeen or 0) end

-- Incidents for a tab and filter, newest first.
function SP.Items(tab, filter)
  local out, q = {}, (filter or ""):lower()
  for _, inc in ipairs(S().Viewer:List(tab == "session")) do
    local resolved = SP.Resolved(inc)
    local keep = (tab == "resolved") == resolved or (tab == "all")
    if keep and q ~= "" then
      keep = ((inc.message or "") .. " " .. (inc.stack or "") .. " " .. (inc.module or "")):lower():find(q, 1, true) ~= nil
    end
    if keep then out[#out + 1] = inc end
  end
  return out
end

local function firstLine(inc)
  local file = (inc.stack or ""):match("([%w_]+/[^\n:]+:%d+)")
  return file or (inc.module or "?")
end

local function stampShort(t) return t and date("%H:%M", t) or "?" end

local function monoBox(parent, h)
  local box = CreateFrame("Frame", nil, parent)
  box:SetHeight(h)
  local bg = Theme:Slice(box, A.control, 20, "BACKGROUND")
  bg:SetVertexColor(0.03, 0.035, 0.045, 1)
  box.text = Kit.Text(box, "mono", "text.secondary")
  box.text:SetPoint("TOPLEFT", 14, -12)
  box.text:SetPoint("RIGHT", -14, 0)
  box.text:SetJustifyH("LEFT")
  box.text:SetJustifyV("TOP")
  box.text:SetSpacing(5)
  return box
end

local function buildHeader(v)
  v.crumb = Kit.Text(v, "small", "muted")
  v.crumb:SetPoint("TOPLEFT", 30, -22)
  v.crumb:SetText("System   >   Sentinel")
  local icon = Kit.Icon(v, A.Icon("sentinel"), 44)
  icon:SetPoint("TOPLEFT", 30, -44)
  local title = Kit.Text(v, "display", "text.primary")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, 2)
  title:SetText("Sentinel")
  local desc = Kit.Text(v, "text", "muted")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  desc:SetText("Every Lua error, taint block and slow frame, grouped, deduplicated and ready to copy.")
  v.clear = Kit.Button(v, "Clear all", 110, function() S().Capture:Clear(); SP:Refresh(v) end, "danger")
  v.clear:SetPoint("TOPRIGHT", -30, -52)
  v.export = Kit.Button(v, "Export report", 130, function()
    local text, why = S().Export:Build()
    S().Panel:ShowCopy(text or why)
  end, "secondary")
  v.export:SetPoint("RIGHT", v.clear, "LEFT", -10, 0)
  v.settings = Kit.Button(v, "Settings", 90, function() Options.rawPage = "Sentinel"; Options:Render() end, "ghost")
  v.settings:SetPoint("RIGHT", v.export, "LEFT", -10, 0)
  v.share = Kit.Toggle(v, function(on) Model.Commit("sentinel.optIn", on) end)
  v.share:SetPoint("RIGHT", v.settings, "LEFT", -12, 0)
  local st = Kit.Text(v, "label", "text.secondary")
  st:SetPoint("RIGHT", v.share, "LEFT", -8, 0)
  st:SetText("Share reports")
end

local function buildTabs(v)
  v.tabs = Kit.Segmented(v, { "session", "all", "resolved" }, { "This session", "All", "Resolved" }, function(t)
    SP.tab = t
    SP.selected = nil
    SP:Refresh(v)
  end)
  v.tabs:SetPoint("TOPLEFT", 30, -118)
  local search = CreateFrame("EditBox", nil, v)
  search:SetSize(240, 30)
  search:SetPoint("LEFT", v.tabs, "RIGHT", 14, 0)
  search:SetAutoFocus(false)
  search:SetFontObject(Kit.FontObject("text"))
  search:SetTextInsets(12, 12, 0, 0)
  local bg = Theme:Slice(search, A.control, 20)
  bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  search.hint = Kit.Text(search, "small", "muted")
  search.hint:SetPoint("LEFT", 12, 0)
  search.hint:SetText("Filter by file or message")
  search:SetScript("OnTextChanged", function(self)
    search.hint:SetShown(self:GetText() == "")
    SP.filter = self:GetText()
    SP:Refresh(v)
  end)
  search:SetScript("OnEscapePressed", search.ClearFocus)
  v.search = search
  v.badges = {}
  local prev
  for i, spec in ipairs({ { "err", "errors" }, { "warn", "taint" }, { "info", "perf" } }) do
    local b = Kit.Badge(v, "", spec[1])
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -6, 0) else b:SetPoint("TOPRIGHT", -30, -123) end
    b.word = spec[2]
    v.badges[i] = b
    prev = b
  end
end

local function item(v, i)
  local b = v.items[i]
  if b then return b end
  b = CreateFrame("Button", nil, v.listChild)
  b:SetSize(LIST_W - 20, ITEM_H)
  b.sel = Theme:Slice(b, A.card, 28, "BACKGROUND")
  Theme:Paint(b.sel, "err", 0.10, "vertex")
  b.ring = Theme:Slice(b, A.borderSoft, 28, "BORDER")
  Theme:Paint(b.ring, "err", 0.6, "vertex")
  b.dot = b:CreateTexture(nil, "ARTWORK")
  b.dot:SetSize(7, 7)
  b.dot:SetPoint("TOPLEFT", 14, -16)
  b.title = Kit.Text(b, "label", "text.primary")
  b.title:SetPoint("TOPLEFT", 28, -12)
  b.title:SetPoint("RIGHT", -52, 0)
  b.title:SetJustifyH("LEFT")
  b.title:SetMaxLines(1)
  b.msg = Kit.Text(b, "small", "text.secondary")
  b.msg:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -5)
  b.msg:SetPoint("RIGHT", -14, 0)
  b.msg:SetJustifyH("LEFT")
  b.msg:SetMaxLines(2)
  b.time = Kit.Text(b, "small", "muted")
  b.time:SetPoint("BOTTOMLEFT", 28, 10)
  b.count = Kit.Badge(b, "", "err")
  b.count:SetPoint("TOPRIGHT", -10, -9)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.03)
  b:SetScript("OnClick", function(self) SP.selected = self.hash; SP:Refresh(v) end)
  v.items[i] = b
  return b
end

local function buildDetail(v)
  local d = Kit.Card(v)
  d:SetPoint("TOPLEFT", 30 + LIST_W + 16, -164)
  d:SetPoint("BOTTOMRIGHT", -30, 24)
  d.kind = Kit.Badge(d, "", "err")
  d.kind:SetPoint("TOPLEFT", 20, -18)
  d.seen = Kit.Badge(d, "", "neutral")
  d.seen:SetPoint("LEFT", d.kind, "RIGHT", 6, 0)
  d.when = Kit.Badge(d, "", "neutral")
  d.when:SetPoint("LEFT", d.seen, "RIGHT", 6, 0)
  d.copy = Kit.Button(d, "Copy report", 130, function()
    if SP.current then S().Panel:ShowCopy(S().Viewer:Text(SP.current)) end
  end, "primary")
  d.copy:SetPoint("TOPRIGHT", -16, -12)
  d.resolve = Kit.Button(d, "Mark resolved", 130, function()
    local inc = SP.current
    if inc then inc.resolvedAt = SP.Resolved(inc) and nil or (inc.lastSeen or time()); SP:Refresh(v) end
  end, "secondary")
  d.resolve:SetPoint("RIGHT", d.copy, "LEFT", -8, 0)
  d.title = Kit.Text(d, "mono", "text.primary")
  d.title:SetFont(Kit.FontPath("JetBrains Mono"), 14, "")
  d.title:SetPoint("TOPLEFT", 20, -58)
  d.title:SetPoint("RIGHT", -20, 0)
  d.title:SetJustifyH("LEFT")
  d.meta = Kit.Text(d, "small", "muted")
  d.meta:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -10)
  local s1 = Kit.Section(d, "Stack")
  s1:SetPoint("TOPLEFT", d.meta, "BOTTOMLEFT", 0, -16)
  d.stack = monoBox(d, 120)
  d.stack:SetPoint("TOPLEFT", s1, "BOTTOMLEFT", 0, -8)
  d.stack:SetPoint("RIGHT", -20, 0)
  local s2 = Kit.Section(d, "Locals")
  s2:SetPoint("TOPLEFT", d.stack, "BOTTOMLEFT", 0, -16)
  d.locals = monoBox(d, 96)
  d.locals:SetPoint("TOPLEFT", s2, "BOTTOMLEFT", 0, -8)
  d.locals:SetPoint("RIGHT", -20, 0)
  d.hint = CreateFrame("Frame", nil, d)
  d.hint:SetHeight(52)
  d.hint:SetPoint("TOPLEFT", d.locals, "BOTTOMLEFT", 0, -14)
  d.hint:SetPoint("RIGHT", -20, 0)
  local hb = Theme:Slice(d.hint, A.control, 20, "BACKGROUND")
  Theme:Paint(hb, "warn", 0.10, "vertex")
  local he = Theme:Slice(d.hint, A.borderSoft, 28, "BORDER")
  Theme:Paint(he, "warn", 0.35, "vertex")
  local hi = Kit.Icon(d.hint, A.Icon("wisdom"), 20)
  hi:SetPoint("LEFT", 12, 0)
  d.hint.text = Kit.Text(d.hint, "small", "text.secondary")
  d.hint.text:SetPoint("LEFT", hi, "RIGHT", 10, 0)
  d.hint.text:SetPoint("RIGHT", -12, 0)
  d.hint.text:SetJustifyH("LEFT")
  d.empty = Kit.Text(d, "body", "muted")
  d.empty:SetPoint("CENTER")
  d.empty:SetText("No incident selected.")
  v.detail = d
end

local function build(host)
  local v = CreateFrame("Frame", nil, host)
  v:SetAllPoints()
  buildHeader(v)
  buildTabs(v)
  local list = CreateFrame("ScrollFrame", nil, v)
  list:SetPoint("TOPLEFT", 30, -164)
  list:SetPoint("BOTTOMLEFT", 30, 24)
  list:SetWidth(LIST_W)
  local lbg = Kit.Card(v)
  lbg:SetAllPoints(list)
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, self:GetScrollChild():GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 60)))
  end)
  v.listChild = CreateFrame("Frame", nil, list)
  v.listChild:SetSize(LIST_W, 10)
  list:SetScrollChild(v.listChild)
  list:SetFrameLevel(lbg:GetFrameLevel() + 2)
  v.items = {}
  v.none = Kit.Text(v.listChild, "small", "muted")
  v.none:SetPoint("TOP", 0, -24)
  buildDetail(v)
  function v:OnSetting(key) if key == "sentinel.optIn" then SP:Refresh(self) end end
  Options.views.sentinel = v
  return v
end

local function numbered(stack)
  local out, n = {}, 0
  for line in tostring(stack or ""):gmatch("[^\n]+") do
    n = n + 1
    if n > 8 then out[#out + 1] = "   ..."; break end
    out[#out + 1] = string.format("%d  %s", n, line)
  end
  return #out > 0 and table.concat(out, "\n") or "(none)"
end

function SP:ShowDetail(v, inc)
  local d = v.detail
  self.current = inc
  for _, r in ipairs({ d.kind, d.seen, d.when, d.copy, d.resolve, d.title, d.meta, d.stack, d.locals, d.hint }) do r:SetShown(inc ~= nil) end
  d.empty:SetShown(inc == nil)
  if not inc then return end
  local k = KIND[inc.kind] or { inc.kind or "?", "warn" }
  d.kind:SetText(k[1])
  d.seen:SetText("Seen " .. (inc.count or 0) .. "x")
  d.when:SetText("First " .. stampShort(inc.firstSeen) .. "  -  last " .. stampShort(inc.lastSeen))
  d.resolve:SetLabel(SP.Resolved(inc) and "Reopen" or "Mark resolved")
  d.title:SetText(firstLine(inc) .. ": " .. tostring(inc.message or ""):sub(1, 160))
  local ctx = inc.context or {}
  d.meta:SetText(string.format("Build |cffece8e2%s|r    Phoenix |cffece8e2%s|r    Zone |cffece8e2%s|r    Combat |cffece8e2%s|r",
    tostring(inc.build or "?"), tostring(inc.addonVersion or "?"), tostring(ctx.zone or "?"), ctx.combat and "yes" or "no"))
  d.stack.text:SetText(numbered(inc.stack))
  d.locals.text:SetText((inc.locals ~= nil and inc.locals ~= "") and tostring(inc.locals):sub(1, 600) or "(none)")
  local hint = HINTS[inc.kind]
  d.hint:SetShown(hint ~= nil)
  d.hint.text:SetText(hint and ("|cffffc24bHint:|r " .. hint) or "")
end

function SP:Refresh(v)
  local s = S()
  v.share:SetValue_(Schema:Get("sentinel.optIn") and true or false)
  local session, all = s.Viewer:List(true), s.Viewer:List(false)
  local resolved = 0
  for _, inc in ipairs(all) do if SP.Resolved(inc) then resolved = resolved + 1 end end
  v.tabs:SetValue_(self.tab)
  v.tabs:SetLabels({ "This session - " .. #session, "All - " .. #all, "Resolved - " .. resolved })
  local counts = { 0, 0, 0 }
  for _, inc in ipairs(session) do
    if inc.kind == "error" or inc.kind == "secret" then counts[1] = counts[1] + 1
    elseif inc.kind == "taint" then counts[2] = counts[2] + 1
    elseif inc.kind == "perf" then counts[3] = counts[3] + 1 end
  end
  for i, b in ipairs(v.badges) do b:SetText(counts[i] .. " " .. b.word) end
  local items = SP.Items(self.tab, self.filter)
  local current
  for i, inc in ipairs(items) do
    local b = item(v, i)
    local k = KIND[inc.kind] or { "?", "warn" }
    b.hash = inc.hash
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 10, -10 - (i - 1) * (ITEM_H + 6))
    Theme:Paint(b.dot, SP.Resolved(inc) and "muted" or k[2])
    b.title:SetText((SP.Resolved(inc) and "Resolved - " or "") .. firstLine(inc))
    b.msg:SetText(tostring(inc.message or ""):sub(1, 140))
    b.time:SetText(stampShort(inc.lastSeen))
    b.count:SetText("x" .. (inc.count or 0))
    local on = (self.selected == nil and i == 1) or self.selected == inc.hash
    if on then current = inc end
    b.sel:SetShown(on)
    b.ring:SetShown(on)
    b:SetAlpha(SP.Resolved(inc) and 0.6 or 1)
    b:Show()
  end
  for i = #items + 1, #v.items do v.items[i]:Hide() end
  v.none:SetText(#items == 0 and "Nothing here. Clean session." or "")
  v.listChild:SetHeight(#items * (ITEM_H + 6) + 20)
  self:ShowDetail(v, current)
end

function SP:Show(host)
  local v = Options.views.sentinel or build(host)
  v:Show()
  self:Refresh(v)
end
