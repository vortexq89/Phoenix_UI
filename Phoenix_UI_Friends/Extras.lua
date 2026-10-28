local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Friends, deferred batch C:
--  * class icon themes: the game's class icons (default), class-colour squares
--    or class-colour letters.
--  * frame border and tab accent: Phoenix's own overlay on the friends frame
--    (a child frame; Blizzard's frame and tabs are only read and hooked).
--  * add-friend search: typing in Blizzard's add-friend box lists matching
--    guild members and recent players; a click fills the box.
-- Blocked by design: removing Battle.net app-only rows from Blizzard's own list
-- would mean replacing Blizzard's list data, which taints the friends frame;
-- they stay dimmed (and are left out of the Phoenix panel).
local _, ns = ...
local Schema = PUI.Schema
local F, D, K, P = ns.F, ns.Data, ns.Skin, ns.Panel
local OWNER = "Friends"
local s = F.settings
local X = {}
F.Extras = X

-- Class icon themes ----------------------------------------------------------------------------------
X.THEMES = { "atlas", "square", "letter" }
function X.ThemeIcon(button, e)
  local p = K.decorated[button]
  if not (p and e and e.classFile and s.classIcons) then return end
  local letter = rawget(p, "letter")
  if not letter then letter = button:CreateFontString(nil, "OVERLAY"); letter:SetFontObject(PUI.Media:FontObject("small")); letter:SetAllPoints(p.icon); p.letter = letter end
  local c = C_ClassColor.GetClassColor(e.classFile)
  if s.iconTheme == "square" and c then
    p.icon:SetColorTexture(c.r, c.g, c.b, 1); letter:SetText("")
  elseif s.iconTheme == "letter" and c then
    p.icon:SetColorTexture(0.06, 0.07, 0.08, 0.9)
    letter:SetText(e.classFile:sub(1, 1)); letter:SetTextColor(c.r, c.g, c.b)
  else letter:SetText("") end
  letter:SetShown(s.skin and s.iconTheme == "letter")
end
local paint = K.Paint
function K.Paint(button, st)
  paint(button, st)
  if st.skin then X.ThemeIcon(button, K.EntryFor(button)) end
end

-- Frame border and tab accent --------------------------------------------------------------------
X.TABS = 4
function X.PaintFrame()
  local host = rawget(_G, "FriendsFrame")
  local want = F.active and s.frameStyle and host ~= nil
  if not want then if X.overlay then X.overlay:Hide() end return false end
  local o = X.overlay
  if not o then
    o = PUI:CreateFrame("Frame", "PhoenixUIFriendsOverlay", host, nil, OWNER)
    o:SetAllPoints(host); o:EnableMouse(false)
    o.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
      local t = o:CreateTexture(nil, "OVERLAY")
      t:SetPoint(side[1]); t:SetPoint(side[2])
      if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
      o.edges[i] = t
    end
    o.tabs = {}
    for i = 1, X.TABS do o.tabs[i] = o:CreateTexture(nil, "OVERLAY") end
    X.overlay = o
  end
  local c = s.frameColor
  for _, t in ipairs(o.edges) do t:SetColorTexture(c.r, c.g, c.b, s.borderAlpha) end
  local selected = host.selectedTab
  for i, t in ipairs(o.tabs) do
    local tab = rawget(_G, "FriendsFrameTab" .. i)
    if tab and s.tabLine then
      t:ClearAllPoints(); t:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 6, 4); t:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 4); t:SetHeight(2)
      t:SetColorTexture(c.r, c.g, c.b, selected == i and 1 or 0.25)
      t:Show()
    else t:Hide() end
  end
  o:Show()
  return true
end
function X.HookFrame()
  local host = rawget(_G, "FriendsFrame")
  if X.frameHooked or not host then return false end
  X.frameHooked = true
  host:HookScript("OnShow", X.PaintFrame)
  for i = 1, X.TABS do
    local tab = rawget(_G, "FriendsFrameTab" .. i)
    if tab then tab:HookScript("OnClick", X.PaintFrame) end
  end
  return true
end

-- Add-friend search --------------------------------------------------------------------------------
X.SUGGEST = 6
function X.Suggestions(text)
  if not text or #text < 2 then return {} end
  local out = {}
  for _, e in ipairs(D.Search(text, { D.Guild(), D.Recent() })) do
    if e.name then out[#out + 1] = e end
    if #out >= X.SUGGEST then break end
  end
  return out
end
function X.ShowSuggestions(box)
  local f = X.drop
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUIAddFriendSearch", UIParent, nil, OWNER)
    f:SetSize(200, 20); f:SetFrameStrata("DIALOG")
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.96)
    f.rows = {}
    for i = 1, X.SUGGEST do
      local b = CreateFrame("Button", nil, f); b:SetSize(196, 18); b:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 18)
      b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetFontObject(PUI.Media:FontObject("small")); b.text:SetPoint("LEFT", 4, 0)
      b:SetScript("OnClick", function(self) if self.name and X.box then X.box:SetText(self.name); X.box:SetCursorPosition(#self.name) end; f:Hide() end)
      f.rows[i] = b
    end
    X.drop = f
  end
  X.box = box
  local list = s.addFriendSearch and X.Suggestions(box:GetText()) or {}
  if #list == 0 then f:Hide(); return 0 end
  for i, b in ipairs(f.rows) do
    local e = list[i]
    b.name = e and e.name
    if e then b.text:SetText(e.name .. "  |cffb0b0b0" .. (e.source or "") .. "|r"); b:Show() else b:Hide() end
  end
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -4, -2)
  f:SetHeight(4 + #list * 18)
  f:Show()
  return #list
end
function X.HookAddFriend()
  local box = rawget(_G, "AddFriendNameEditBox")
  if X.boxHooked or not box then return false end
  X.boxHooked = true
  box:HookScript("OnTextChanged", function(self, user) if F.active and user ~= false then X.ShowSuggestions(self) end end)
  box:HookScript("OnHide", function() if X.drop then X.drop:Hide() end end)
  return true
end

PUI.Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then X.HookFrame(); X.HookAddFriend(); X.PaintFrame() end end)
PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then X.PaintFrame(); if X.drop then X.drop:Hide() end end end)

local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[name] = v; F.Refresh(); X.PaintFrame() end
  F.schema["friends." .. name] = def
  Schema:Register("friends." .. name, def)
  s[name] = Schema:Get("friends." .. name)
end
key("iconTheme", { type = "select", default = "atlas", choices = X.THEMES, choiceLabels = { atlas = "Game class icons", square = "Class-colour squares", letter = "Class-colour letters" },
  label = "Class icon look", tooltip = "How class icons on friend rows look." })
key("frameStyle", { type = "toggle", default = true, mode = "simple", label = "Phoenix border and tabs", tooltip = "A thin accent border on the friends frame and an accent line under the open tab." })
key("frameColor", { type = "color", default = { r = 0.91, g = 0.64, b = 0.24, a = 1 }, label = "Border and tab colour", tooltip = "Colour of the border and the tab line." })
key("borderAlpha", { type = "range", default = 0.6, min = 0, max = 1, step = 0.05, label = "Border opacity", tooltip = "How strong the border is (0 hides it, the tab line stays)." })
key("tabLine", { type = "toggle", default = true, label = "Line under the open tab", tooltip = "An accent line under the open tab." })
key("addFriendSearch", { type = "toggle", default = true, mode = "simple", label = "Suggestions when adding a friend", tooltip = "Typing in the add-friend box lists matching guild members and recent players; click one to fill the box." })
