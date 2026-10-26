local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Chat history (plan 5.10: searchable history; upgrade: filters by channel,
-- player and date). Only plain lines are stored (the filter never hands a
-- secret here); lines are kept across reloads when "Remember lines" is on, in
-- PhoenixUIDB.chatHistory (outside profiles), trimmed by count and age.
-- The search window filters live as you type; results can be copied.
local _, ns = ...
local CH, T = ns.CH, ns.Text
local Schema, Theme, Media = PUI.Schema, PUI.Theme, PUI.Media
local OWNER = "Chat"
local s = CH.settings

local HI = { mem = {}, filter = { q = "", channel = "", player = "", range = "all" } }
ns.History = HI
CH.History = HI

HI.CHANNELS = { "", "say", "yell", "party", "raid", "instance", "guild", "officer", "whisper", "channel", "community", "system", "emote" }
HI.CHANNEL_LABELS = { [""] = "All", say = "Say", yell = "Yell", party = "Party", raid = "Raid", instance = "Instance", guild = "Guild",
  officer = "Officer", whisper = "Whispers", channel = "Channels", community = "Communities", system = "System", emote = "Emotes" }
HI.RANGES = { "today", "week", "month", "all" }
HI.RANGE_LABELS = { today = "Today", week = "7 days", month = "30 days", all = "All" }

function HI.List()
  if s.persistHistory and PUI.DB and PUI.DB.sv then
    PUI.DB.sv.chatHistory = PUI.DB.sv.chatHistory or {}
    return PUI.DB.sv.chatHistory
  end
  return HI.mem
end

-- Trim by count and age (pure over the list).
function HI.Trim(list, maxLines, keepDays, now)
  local cutoff = keepDays > 0 and (now - keepDays * 86400) or nil
  local drop = 0
  while list[drop + 1] and ((#list - drop > maxLines) or (cutoff and list[drop + 1].t < cutoff)) do drop = drop + 1 end
  if drop > 0 then
    for i = 1, #list - drop do list[i] = list[i + drop] end
    for i = #list, #list - drop + 1, -1 do list[i] = nil end
  end
  return drop
end

function HI.Add(event, msg, author, channelName, lineID)
  if not s.history then return end
  if not CH.Plain(msg) then return end
  local list = HI.List()
  list[#list + 1] = { t = time(), ch = CH.CHANNEL_OF[event] or "system", name = channelName, author = author,
    text = T.Truncate(msg, 512), line = lineID }
  if #list > s.historyLines + 50 then HI.Trim(list, s.historyLines, s.historyDays, time()) end
  if HI.frame and HI.frame:IsShown() then HI.Render() end
end

function HI.ByLine(lineID)
  if not lineID then return nil end
  local list = HI.List()
  for i = #list, 1, -1 do if list[i].line == lineID then return list[i] end end
  return nil
end

function HI.Range(range, now)
  now = now or time()
  if range == "today" then
    local d = date("*t", now)
    return now - (d.hour * 3600 + d.min * 60 + d.sec)
  elseif range == "week" then return now - 7 * 86400
  elseif range == "month" then return now - 30 * 86400 end
  return nil
end

function HI.Query(f)
  f = f or HI.filter
  return T.Search(HI.List(), { q = f.q, channel = f.channel, player = f.player, from = HI.Range(f.range) }, 500)
end

function HI.Format(e)
  local who = e.author and (e.author:match("^[^%-]+") .. ": ") or ""
  local where = e.name and ("[" .. e.name .. "] ") or ("[" .. (HI.CHANNEL_LABELS[e.ch] or e.ch) .. "] ")
  return date("%m-%d %H:%M", e.t) .. " " .. where .. who .. e.text
end

function HI.CopyAll()
  local lines, list = {}, HI.List()
  for i = math.max(1, #list - 300), #list do lines[#lines + 1] = HI.Format(list[i]) end
  PUI.Dialogs:Copy("Chat history", table.concat(lines, "\n"), "Ctrl+C to copy")
end

-- Search window ------------------------------------------------------------
local function chip(parent, text, onClick)
  local b = PUI:CreateFrame("Button", nil, parent, nil, OWNER)
  b:SetHeight(20)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFontObject(Media:FontObject("small"))
  b.text:SetPoint("CENTER")
  b.text:SetText(text)
  b:SetWidth(math.max(44, (b.text:GetStringWidth() or 30) + 16))
  b:SetScript("OnClick", onClick)
  return b
end
local function paintChip(b, on)
  local r, g, bl = Theme:Color(on and "accent" or "surface.2")
  b.bg:SetColorTexture(r, g, bl, on and 0.85 or 0.9)
end

local function input(parent, w, hint, onChange)
  local e = PUI:CreateFrame("EditBox", nil, parent, "SearchBoxTemplate", OWNER)
  e:SetSize(w, 20)
  e:SetAutoFocus(false)
  local ins = e.Instructions
  if type(ins) == "table" and ins.SetText then ins:SetText(hint) end
  e:HookScript("OnTextChanged", function(self) onChange(self:GetText() or "") end)
  return e
end

function HI.Build()
  if HI.frame then return HI.frame end
  local f = PUI:CreateFrame("Frame", "PhoenixUI_ChatHistory", UIParent, nil, OWNER)
  f:SetSize(620, 420)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.5)
  f.title = f:CreateFontString(nil, "OVERLAY")
  f.title:SetFontObject(Media:FontObject("header"))
  f.title:SetPoint("TOPLEFT", 14, -12)
  f.title:SetText("Chat history")
  local close = PUI:CreateFrame("Button", nil, f, "UIPanelCloseButton", OWNER)
  close:SetPoint("TOPRIGHT", 2, 2)
  f.q = input(f, 230, "Search text or name", function(v) HI.filter.q = v; HI.Render() end)
  f.q:SetPoint("TOPLEFT", 16, -40)
  f.player = input(f, 140, "Player", function(v) HI.filter.player = v; HI.Render() end)
  f.player:SetPoint("LEFT", f.q, "RIGHT", 10, 0)
  f.copy = PUI:CreateFrame("Button", nil, f, "UIPanelButtonTemplate", OWNER)
  f.copy:SetSize(110, 22)
  f.copy:SetPoint("TOPRIGHT", -16, -38)
  f.copy:SetText("Copy results")
  f.copy:SetScript("OnClick", function()
    local out = {}
    for _, e in ipairs(HI.results or {}) do table.insert(out, 1, HI.Format(e)) end
    PUI.Dialogs:Copy("Chat history results", table.concat(out, "\n"), "Ctrl+C to copy")
  end)
  f.chips, f.ranges = {}, {}
  local x = 16
  for _, id in ipairs(HI.CHANNELS) do
    local b = chip(f, HI.CHANNEL_LABELS[id], function() HI.filter.channel = id; HI.Render() end)
    b:SetPoint("TOPLEFT", x, -68)
    x = x + b:GetWidth() + 4
    if x > 560 then x = 16 end
    f.chips[id] = b
  end
  x = 16
  for _, id in ipairs(HI.RANGES) do
    local b = chip(f, HI.RANGE_LABELS[id], function() HI.filter.range = id; HI.Render() end)
    b:SetPoint("TOPLEFT", x, -94)
    x = x + b:GetWidth() + 4
    f.ranges[id] = b
  end
  f.count = f:CreateFontString(nil, "OVERLAY")
  f.count:SetFontObject(Media:FontObject("small"))
  f.count:SetPoint("TOPRIGHT", -18, -98)
  f.list = PUI:CreateFrame("ScrollingMessageFrame", nil, f, nil, OWNER)
  f.list:SetPoint("TOPLEFT", 16, -122)
  f.list:SetPoint("BOTTOMRIGHT", -16, 14)
  f.list:SetFontObject(Media:FontObject("body"))
  f.list:SetJustifyH("LEFT")
  f.list:SetFading(false)
  f.list:SetMaxLines(500)
  f.list:EnableMouseWheel(true)
  f.list:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
  tinsert(UISpecialFrames, "PhoenixUI_ChatHistory")
  f:Hide()
  HI.frame = f
  return f
end

function HI.Render()
  local f = HI.frame
  if not f then return end
  for id, b in pairs(f.chips) do paintChip(b, HI.filter.channel == id) end
  for id, b in pairs(f.ranges) do paintChip(b, HI.filter.range == id) end
  HI.results = HI.Query()
  f.list:Clear()
  for i = #HI.results, 1, -1 do f.list:AddMessage(HI.Format(HI.results[i])) end
  f.count:SetText(#HI.results .. " match" .. (#HI.results == 1 and "" or "es"))
end

function HI.Show()
  HI.Build():Show()
  HI.Render()
end

local key = CH.Key
key("history", { type = "toggle", default = true, label = "Searchable history",
  tooltip = "Keeps recent chat lines so you can search them by text, channel, player and date (/pui chat history).", mode = "simple",
  searchTags = { "history", "search", "copy" } })
key("persistHistory", { type = "toggle", default = true, label = "Remember lines after reload",
  tooltip = "Keeps history across reloads and logins. Lines the game kept secret are never stored.", mode = "advanced" })
key("historyLines", { type = "range", default = 2000, min = 200, max = 10000, step = 100, label = "Lines kept",
  tooltip = "How many lines history keeps before the oldest are dropped.", mode = "advanced" })
key("historyDays", { type = "range", default = 14, min = 0, max = 90, step = 1, label = "Days kept",
  tooltip = "Lines older than this are dropped. 0 keeps them until the line limit.", mode = "advanced" })
