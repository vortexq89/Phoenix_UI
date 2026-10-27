local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Friends panel (mockup 19 "invite search", "Copy BattleTag"): Phoenix's own
-- window docked beside Blizzard's friends list. One search box across
-- friends, guild and recent players, source tabs, sort, the app-only and
-- offline filters, and actions for the selected row: invite, whisper, copy
-- BattleTag (the shared copy box) and note (Blizzard's own note dialog).
local _, ns = ...
local D = ns.Data
local P = { rows = {}, source = "all" }
ns.Panel = P
local ROWS = 14

local function font(fs, role) fs:SetFontObject(PUI.Media:FontObject(role or "small")) end
local function button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22); b:SetText(text); b:SetScript("OnClick", onClick)
  return b
end

-- Results(s) -> filtered, sorted entries for the current tab and search.
function P.Results(s, query, source)
  local sources = {}
  if source == "all" or source == "friends" then sources[#sources + 1] = D.Friends() end
  if (source == "all" and s.searchGuild) or source == "guild" then sources[#sources + 1] = D.Guild() end
  if (source == "all" and s.searchRecent) or source == "recent" then sources[#sources + 1] = D.Recent() end
  local list = D.Search(query, sources)
  list = D.Filter(list, { hideAppOnly = s.hideAppOnly, hideOffline = s.hideOffline })
  return D.Sort(list, s.sort)
end

function P.Build(s)
  local f = PUI:CreateFrame("Frame", "PhoenixUIFriendsPanel", UIParent, nil, "Friends")
  f:SetSize(300, 120 + ROWS * s.rowHeight)
  PUI.Theme:Backdrop(f, "surface.0")
  local accent = f:CreateTexture(nil, "ARTWORK"); accent:SetPoint("TOPLEFT"); accent:SetPoint("TOPRIGHT"); accent:SetHeight(2)
  PUI.Theme:Paint(accent, "accent")
  f.title = f:CreateFontString(nil, "OVERLAY"); font(f.title, "header"); f.title:SetPoint("TOPLEFT", 12, -10)
  local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  box:SetSize(270, 20); box:SetPoint("TOPLEFT", 16, -34); box:SetAutoFocus(false)
  box:SetScript("OnTextChanged", function(b) P.query = b:GetText(); P.Paint(s) end)
  box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
  f.search = box
  f.tabs = {}
  for i, id in ipairs({ "all", "friends", "guild", "recent" }) do
    local t = button(f, ({ all = "All", friends = "Friends", guild = "Guild", recent = "Recent" })[id], 68, function() P.source = id; P.Paint(s) end)
    t:SetPoint("TOPLEFT", 12 + (i - 1) * 70, -58)
    f.tabs[id] = t
  end
  local acts = {
    button(f, "Invite", 66, function() P.Invite() end), button(f, "Whisper", 66, function() P.Whisper() end),
    button(f, "BattleTag", 74, function() P.CopyTag() end), button(f, "Note", 60, function() P.Note() end),
  }
  for i, b in ipairs(acts) do b:SetPoint("BOTTOMLEFT", 10 + (i - 1) * 70, 10) end
  f.acts = acts
  P.frame = f
  return f
end

local function row(f, i, s)
  local r = P.rows[i]
  if not r then
    r = CreateFrame("Button", nil, f)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
    r.orb = r:CreateTexture(nil, "ARTWORK"); r.orb:SetSize(8, 8); r.orb:SetPoint("LEFT", 4, 0)
    r.name = r:CreateFontString(nil, "OVERLAY"); font(r.name, "normal"); r.name:SetPoint("TOPLEFT", 18, -2)
    r.info = r:CreateFontString(nil, "OVERLAY"); font(r.info, "small"); r.info:SetPoint("BOTTOMLEFT", 18, 2)
    r.tag = r:CreateFontString(nil, "OVERLAY"); font(r.tag, "small"); r.tag:SetPoint("RIGHT", -6, 0)
    r:SetScript("OnClick", function(self) P.selected = self.entry; P.Paint(ns.F.settings) end)
    r:SetScript("OnDoubleClick", function(self) P.selected = self.entry; P.Whisper() end)
    P.rows[i] = r
  end
  r:SetSize(276, s.rowHeight)
  r:ClearAllPoints(); r:SetPoint("TOPLEFT", 12, -84 - (i - 1) * (s.rowHeight + 2))
  return r
end

function P.Paint(s)
  local f = P.frame
  if not (f and f:IsShown()) then return end
  local list = P.Results(s, P.query, P.source)
  local online = 0
  for _, e in ipairs(list) do if e.online then online = online + 1 end end
  f.title:SetText(string.format("Friends  -  %d online", online))
  for id, t in pairs(f.tabs) do t:SetAlpha(id == P.source and 1 or 0.6) end
  f:SetHeight(120 + ROWS * (s.rowHeight + 2))
  for i = 1, ROWS do
    local e = list[i]
    local r = row(f, i, s)
    r.entry = e
    r:SetShown(e ~= nil)
    if e then
      local c = s.classNames and e.classFile and C_ClassColor.GetClassColor(e.classFile)
      r.name:SetText(e.name or e.battleTag or "?")
      if c and e.online then r.name:SetTextColor(c.r, c.g, c.b) else r.name:SetTextColor(e.online and 1 or 0.55, e.online and 1 or 0.55, e.online and 1 or 0.55) end
      local info = e.online and (e.zone or (e.appOnly and "Battle.net app") or "") or "Offline"
      if s.activity and e.activity and e.online then info = info .. "  -  " .. e.activity end
      if e.note and s.notesInList and e.note ~= "" then info = info .. "  (" .. e.note .. ")" end
      r.info:SetText(info)
      r.tag:SetText((s.regionIcons and e.region or "") .. (e.source ~= "friends" and ("  " .. e.source) or ""))
      local sc = ns.Skin.STATUS_COLORS[e.status] or ns.Skin.STATUS_COLORS.offline
      r.orb:SetColorTexture(sc[1], sc[2], sc[3], 1)
      if P.selected == e then PUI.Theme:Paint(r.bg, "accent", 0.25) else PUI.Theme:Paint(r.bg, "surface.1", 0.6) end
    end
  end
  P.shown = math.min(#list, ROWS)
  local sel = P.selected
  f.acts[1]:SetEnabled(sel ~= nil and sel.online)
  f.acts[2]:SetEnabled(sel ~= nil and sel.online)
  f.acts[3]:SetEnabled(sel ~= nil and sel.battleTag ~= nil)
  f.acts[4]:SetEnabled(sel ~= nil and sel.source == "friends")
end

function P.Invite()
  local e = P.selected
  if not (e and e.online and e.name) then return end
  local target = e.realm and not e.name:find("-", 1, true) and (e.name .. "-" .. e.realm) or e.name
  C_PartyInfo.InviteUnit(target)
end
function P.Whisper()
  local e = P.selected
  if not e then return end
  if e.kind == "bnet" and e.account and rawget(_G, "ChatFrame_SendBNetTell") then ChatFrame_SendBNetTell(e.account)
  elseif e.name and rawget(_G, "ChatFrame_SendTell") then ChatFrame_SendTell(e.name) end
end
function P.CopyTag()
  local e = P.selected
  if e and e.battleTag then PUI.Dialogs:Copy("BattleTag", e.battleTag, "Ctrl+C to copy") end
end
function P.Note()
  local e = P.selected
  if not (e and e.source == "friends") then return end
  if e.kind == "bnet" then StaticPopup_Show("SET_BNFRIENDNOTE", e.account, nil, e.index) else StaticPopup_Show("SET_FRIENDNOTE", e.name) end
end

function P.Dock(s)
  local f = P.frame or P.Build(s)
  local host = rawget(_G, "FriendsFrame")
  f:ClearAllPoints()
  if host and s.dock == "right" then f:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, 0)
  elseif host and s.dock == "left" then f:SetPoint("TOPRIGHT", host, "TOPLEFT", -4, 0)
  else PUI.Layout:Place(f, "friends.panel") end
end
function P.Show(s, show)
  local f = P.frame or P.Build(s)
  f:SetShown(show)
  if show then P.Dock(s); P.Paint(s) end
end
