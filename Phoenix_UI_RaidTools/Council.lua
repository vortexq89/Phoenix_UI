local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Raid Tools, review gap: Council, a small loot council between Phoenix users.
-- The loot master runs /pui council <item link>: everyone in the group with
-- Council on gets a Phoenix prompt (Need, Minor, Transmog, Pass) and the
-- answer goes back with their equipped item level; the loot master sees the
-- answers in one window. It only talks; it never hands out loot.
-- Addon messages are paused by the game during some encounters
-- (C_ChatInfo.InChatMessagingLockdown); Council says so and waits for you.
local _, ns = ...
local Schema, Secret = PUI.Schema, PUI.Secret
local RT = ns.RT
local OWNER = "RaidTools"
local C = { PREFIX = "PHXCouncil", answers = {}, item = nil }
RT.Council = C
local s = { council = false, councilSeconds = 60 }
C.s = s
C.CHOICES = { "Need", "Minor", "Transmog", "Pass" }

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
local function channel() return IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil) end
function C.Send(msg)
  local ch = channel()
  if not ch then return false, "you are not in a group" end
  if C_ChatInfo.InChatMessagingLockdown() then
    if PUI.Toast then PUI.Toast:Show("Council waits: the game pauses addon messages in this encounter", "warn", true) end
    return false, "paused by the game"
  end
  C_ChatInfo.SendAddonMessage(C.PREFIX, msg, ch)
  return true
end

-- Start(link): the loot master asks the group.
function C.Start(link)
  if not s.council then return false, "Council is off" end
  if type(link) ~= "string" or not link:find("item:") then return false, "shift-click an item into the command" end
  C.item = link
  wipe(C.answers)
  local ok, why = C.Send("ASK\t" .. link)
  if ok then C.ShowResults() end
  return ok, why
end
function C.Answer(choice)
  if not C.asked then return false end
  local ilvl = select(2, GetAverageItemLevel())
  local ok = C.Send(string.format("ANS\t%s\t%d", choice, math.floor(tonumber(ilvl) or 0)))
  C.asked = nil
  if C.prompt then C.prompt:Hide() end
  return ok
end
function C.OnMessage(_, prefix, msg, _, sender)
  if prefix ~= C.PREFIX or not s.council or not (plain(msg) and plain(sender)) or type(msg) ~= "string" then return end
  local kind, a, b = msg:match("^(%u+)\t([^\t]*)\t?(.*)$")
  if kind == "ASK" and a then
    C.asked = a
    C.ShowPrompt(a)
  elseif kind == "ANS" and C.item and a then
    C.answers[sender] = { choice = a, ilvl = tonumber(b) or 0 }
    C.ShowResults()
  end
end

-- Windows ---------------------------------------------------------------------------------------------------
local function text(parent, size) local fs = parent:CreateFontString(nil, "OVERLAY"); fs:SetFontObject(PUI.Media:FontObject(size or "small")); return fs end
local function frame(name, w, h, title)
  local f = PUI:CreateFrame("Frame", name, UIParent, nil, OWNER)
  f:SetSize(w, h); f:SetFrameStrata("DIALOG"); f:SetPoint("CENTER", 0, 140)
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.94)
  f.line = f:CreateTexture(nil, "BORDER"); f.line:SetPoint("TOPLEFT"); f.line:SetPoint("TOPRIGHT"); f.line:SetHeight(2)
  f.line:SetColorTexture(PUI.Theme:Color("accent"))
  f.title = text(f, "normal"); f.title:SetPoint("TOPLEFT", 8, -6); f.title:SetText(title)
  f.close = CreateFrame("Button", nil, f); f.close:SetSize(16, 16); f.close:SetPoint("TOPRIGHT", -4, -4)
  f.close.text = text(f.close); f.close.text:SetAllPoints(); f.close.text:SetText("x")
  f.close:SetScript("OnClick", function() f:Hide() end)
  return f
end
function C.ShowPrompt(link)
  local f = C.prompt
  if not f then
    f = frame("PhoenixUICouncilPrompt", 300, 74, "Council")
    f.item = text(f); f.item:SetPoint("TOPLEFT", 8, -24); f.item:SetWidth(284); f.item:SetJustifyH("LEFT")
    f.buttons = {}
    for i, choice in ipairs(C.CHOICES) do
      local b = CreateFrame("Button", nil, f); b:SetSize(68, 18); b:SetPoint("BOTTOMLEFT", 8 + (i - 1) * 72, 8)
      b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(1, 1, 1, 0.08)
      b.text = text(b); b.text:SetAllPoints(); b.text:SetText(choice)
      b:SetScript("OnClick", function() C.Answer(choice) end)
      f.buttons[i] = b
    end
    f.anim = f:CreateAnimationGroup()
    f.wait = f.anim:CreateAnimation("Alpha"); f.wait:SetFromAlpha(1); f.wait:SetToAlpha(1)
    f.anim:SetScript("OnFinished", function() C.asked = nil; f:Hide() end)
    C.prompt = f
  end
  f.item:SetText(link)
  f.wait:SetDuration(s.councilSeconds)
  f:Show(); f.anim:Stop(); f.anim:Play()
  return f
end
-- Rows() -> sorted { name, choice, ilvl } (Need first, then Minor, Transmog, Pass; lower item level first)
function C.Rows()
  local rank = {}
  for i, c in ipairs(C.CHOICES) do rank[c] = i end
  local out = {}
  for name, a in pairs(C.answers) do out[#out + 1] = { name = name, choice = a.choice, ilvl = a.ilvl } end
  table.sort(out, function(x, y)
    local rx, ry = rank[x.choice] or 9, rank[y.choice] or 9
    if rx ~= ry then return rx < ry end
    if x.ilvl ~= y.ilvl then return x.ilvl < y.ilvl end
    return x.name < y.name
  end)
  return out
end
function C.ShowResults()
  local f = C.results
  if not f then
    f = frame("PhoenixUICouncilResults", 300, 220, "Council answers")
    f.item = text(f); f.item:SetPoint("TOPLEFT", 8, -24)
    f.rows = {}
    C.results = f
  end
  f.item:SetText(C.item or "")
  local rows = C.Rows()
  for i = 1, math.max(#rows, #f.rows) do
    local fs = f.rows[i]
    if not fs then fs = text(f); fs:SetPoint("TOPLEFT", 8, -40 - (i - 1) * 14); f.rows[i] = fs end
    local r = rows[i]
    if r and i <= 12 then fs:SetText(string.format("%s  |cffe8a33d%s|r  %d", r.name, r.choice, r.ilvl)); fs:Show() else fs:Hide() end
  end
  f:Show()
  return f
end

C.events = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
C.events:SetScript("OnEvent", C.OnMessage)
function C.Track()
  C.events:UnregisterAllEvents()
  if s.council and RT.active then
    C_ChatInfo.RegisterAddonMessagePrefix(C.PREFIX)
    C.events:RegisterEvent("CHAT_MSG_ADDON")
  end
end
PUI.Kernel:On("MODULE_ENABLED", function(name) if name == OWNER then C.Track() end end)
PUI.Kernel:On("MODULE_DISABLED", function(name) if name == OWNER then C.Track() end end)
PUI.Slash:Register("council", function(rest)
  local ok, why = C.Start(rest)
  if not ok then PUI.Slash.Print("Council: " .. tostring(why)) end
end, "ask your group about an item (loot council)")

local function key(name, def)
  def.owner = OWNER
  def.apply = function(v) s[name] = v; C.Track() end
  RT.schema["rt." .. name] = def
  Schema:Register("rt." .. name, def)
  s[name] = Schema:Get("rt." .. name)
end
key("council", { type = "toggle", default = false, mode = "simple", label = "Council (loot council)",
  tooltip = "/pui council <item> asks your group Need, Minor, Transmog or Pass; answers come back with item level. Others need Phoenix with Council on.",
  searchTags = { "loot", "council" } })
key("councilSeconds", { type = "range", default = 60, min = 15, max = 180, step = 5, mode = "advanced", label = "Council answer time",
  tooltip = "How long the question stays on screen before it closes by itself." })
C.Track()
