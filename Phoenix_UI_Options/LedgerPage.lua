local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- "Changes & uninstall" page (plan 1.22, G6): every game setting (CVar), key
-- binding and Blizzard frame Phoenix changed, with who changed it, your value
-- before, Phoenix's value and the value now; one-click restore per entry; and
-- "Uninstall Phoenix", which gives everything back (only where the value is
-- still Phoenix's; values you changed since are left alone), turns every
-- module off and explains how to remove the addon. Confirmed in Phoenix's own
-- dialog (no StaticPopup, G5).
local Options, Theme = PUI.Options, PUI.Theme
local Kit, A = Options.Kit, Options.Assets
local CVars, Bindings, FrameLedger, Ledger = PUI.CVars, PUI.Bindings, PUI.FrameLedger, PUI.Ledger
local Page = {}
Options.LedgerPage = Page
Options.views = Options.views or {}

local ROW, PAD = 40, 30

-- Plain rows for the three sections (unit-tested): { section, title, detail, state, kind, restore = fn }.
function Page.Entries()
  local out = {}
  for _, r in ipairs(CVars:List()) do
    out[#out + 1] = { section = "Game settings", title = r.name,
      detail = "Yours before: " .. tostring(r.prior) .. "   Phoenix: " .. tostring(r.ours) .. "   Now: " .. tostring(r.current)
        .. "   (" .. table.concat(r.owners, ", ") .. ")",
      state = r.stillOurs and "Phoenix value" or "Changed by you", kind = r.stillOurs and "accent" or "neutral",
      restore = function() CVars:RestoreName(r.name) end }
  end
  for _, b in ipairs(Bindings:List()) do
    out[#out + 1] = { section = "Key bindings", title = b.key, detail = tostring(b.action) .. "   (" .. b.owner .. ")",
      state = "Override", kind = "accent", restore = function() Bindings:Release(b.owner, b.key) end }
  end
  for _, f in ipairs(FrameLedger:List()) do
    out[#out + 1] = { section = "Blizzard frames", title = f.id, detail = "Hidden or moved by " .. f.owner,
      state = "Taken over", kind = "accent", restore = function() FrameLedger:Release(f.owner, f.id) end }
  end
  return out
end

local function build(host)
  local v = CreateFrame("Frame", nil, host)
  v:SetAllPoints()
  v.icon = Kit.Icon(v, A.Icon("general"), 44)
  v.icon:SetPoint("TOPLEFT", PAD, -40)
  v.title = Kit.Text(v, "display", "text.primary")
  v.title:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", 14, 2)
  v.title:SetText("Changes & uninstall")
  v.desc = Kit.Text(v, "text", "muted")
  v.desc:SetPoint("TOPLEFT", v.title, "BOTTOMLEFT", 0, -4)
  v.desc:SetText("Everything Phoenix changed outside its own frames. Restore puts back the value you had before.")

  v.summary = Kit.Card(v)
  v.summary:SetPoint("TOPLEFT", PAD, -116)
  v.summary:SetPoint("TOPRIGHT", -PAD, -116)
  v.summary:SetHeight(84)
  v.counts = Kit.Text(v.summary, "title", "text.primary")
  v.counts:SetPoint("TOPLEFT", 20, -18)
  v.note = Kit.Text(v.summary, "small", "muted")
  v.note:SetPoint("TOPLEFT", v.counts, "BOTTOMLEFT", 0, -6)
  v.note:SetPoint("RIGHT", -260, 0)
  v.note:SetJustifyH("LEFT")
  v.uninstall = Kit.Button(v.summary, "Uninstall Phoenix", 200, function() Page.ConfirmUninstall() end, "danger")
  v.uninstall:SetPoint("RIGHT", -20, 0)

  v.card = Kit.Card(v)
  v.card:SetPoint("TOPLEFT", PAD, -212)
  v.card:SetPoint("BOTTOMRIGHT", -PAD, 24)
  local scroll = CreateFrame("ScrollFrame", nil, v.card)
  scroll:SetPoint("TOPLEFT", 16, -12)
  scroll:SetPoint("BOTTOMRIGHT", -16, 12)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(10, 10)
  scroll:SetScrollChild(child)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * ROW * 2)))
  end)
  v.scroll, v.child = scroll, child
  v.empty = Kit.Text(v.card, "text", "muted")
  v.empty:SetPoint("CENTER")
  v.empty:SetText("Phoenix has not changed any game setting, key binding or Blizzard frame.")
  v.status = Kit.Text(v, "small", "ok")
  v.status:SetPoint("BOTTOMLEFT", PAD + 4, 6)
  v.rows, v.heads = {}, {}
  Options.views.ledger = v
  return v
end

local function head(v, i)
  local h = v.heads[i]
  if h then return h end
  h = Kit.Section(v.child, "")
  v.heads[i] = h
  return h
end

local function row(v, i)
  local r = v.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, v.child)
  r:SetHeight(ROW)
  r.title = Kit.Text(r, "body", "text.primary")
  r.title:SetPoint("LEFT", 4, 7)
  r.detail = Kit.Text(r, "small", "muted")
  r.detail:SetPoint("LEFT", 4, -9)
  r.detail:SetPoint("RIGHT", -240, 0)
  r.detail:SetWordWrap(false)
  r.badge = Kit.Badge(r, "", "accent")
  r.badge:SetPoint("RIGHT", -110, 0)
  r.restore = Kit.Button(r, "Restore", 92, nil, "secondary")
  r.restore:SetPoint("RIGHT", -4, 0)
  r.restore:SetHeight(26)
  local line = Kit.Divider(r)
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
  v.rows[i] = r
  return r
end

function Page:Show(host)
  local v = Options.views.ledger or build(host)
  v:Show()
  local s = Ledger.Summary()
  v.counts:SetText(string.format("%d game setting(s)  -  %d key binding(s)  -  %d Blizzard frame(s)", s.cvars + s.cvarsChanged, s.bindings, s.frames))
  v.note:SetText("Uninstall gives all of it back (values you changed yourself since are kept), turns every Phoenix module off "
    .. "and keeps your profiles. Then disable Phoenix UI in the AddOns list.")
  local list = Page.Entries()
  local width = (v.scroll:GetRight() and v.scroll:GetLeft()) and (v.scroll:GetRight() - v.scroll:GetLeft()) or 900
  v.child:SetWidth(width)
  local y, section, hi = 0, nil, 0
  for i, e in ipairs(list) do
    if e.section ~= section then
      section = e.section
      hi = hi + 1
      local h = head(v, hi)
      h:SetText(section:upper())
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", 0, -y - 6)
      h:Show()
      y = y + 28
    end
    local r = row(v, i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", v.child, "RIGHT", 0, 0)
    r.title:SetText(e.title)
    r.detail:SetText(e.detail)
    r.badge:SetText(e.state)
    r.restore:SetScript("OnClick", function()
      e.restore()
      Page.Status("Restored " .. e.title .. ".", "ok")
      Page:Show(host)
    end)
    r:Show()
    y = y + ROW
  end
  for i = #list + 1, #v.rows do v.rows[i]:Hide() end
  for i = hi + 1, #v.heads do v.heads[i]:Hide() end
  v.child:SetHeight(math.max(10, y))
  v.empty:SetShown(#list == 0)
  v.count = #list
end

function Page.Status(text, kind)
  local v = Options.views.ledger
  if not v then return end
  v.status:SetText(text or "")
  Theme:Paint(v.status, kind == "err" and "err" or "ok", 1, "text")
end

function Page.ConfirmUninstall()
  PUI.Dialogs:Confirm({
    title = "Uninstall Phoenix?",
    text = "Every game setting, key binding and Blizzard frame Phoenix changed goes back to how you had it, and every Phoenix "
      .. "module turns off. Your profiles are kept. Afterwards, disable Phoenix UI in the AddOns list.",
    accept = "Uninstall", cancel = "Keep Phoenix", danger = true,
    onAccept = function()
      local r = Ledger.Uninstall()
      Page.Status(string.format("Done: %d setting(s), %d binding(s), %d frame(s) restored; %d module(s) turned off. "
        .. "You can now disable Phoenix UI in the AddOns list.", r.cvars, r.bindings, r.frames, r.modules), "ok")
      if Options.views.ledger and Options.views.ledger:IsShown() then Page:Show(Options.frame.host) end
    end,
  })
end
