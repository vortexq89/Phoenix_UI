local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- More surfaces without a window (skins v2): raid warning, boss emote and
-- UI error text, mirror timers (breath, fatigue), chat bubbles in the open
-- world, UI widgets and the encounter alt power bar, help tips and movie
-- subtitles. Fonts and Phoenix textures only, recorded and reverted; status
-- bar textures are swapped through the widget's own setter and restored.
-- Chat bubbles inside instances are forbidden frames: C.Usable skips them.
local _, ns = ...
local SK = ns.SK
local C = SK.Controls
local Theme, Media, Ticker = PUI.Theme, PUI.Media, PUI.Ticker
local S2 = { bars = setmetatable({}, { __mode = "k" }), bubbles = setmetatable({}, { __mode = "k" }) }
SK.Surfaces2 = S2

-- Text: raid warnings, boss emotes, UI errors ----------------------------------------------
S2.TEXT = { "RaidWarningFrame", "RaidBossEmoteFrame", "UIErrorsFrame" }
local function textFrame(f, _, id)
  if not C.Usable(f) then return end
  for _, k in ipairs({ "slot1", "slot2", "Slot1", "Slot2" }) do local fs = f[k]; if type(fs) == "table" and fs.SetFontObject then SK.Font(id, fs, "large") end end
  if f.GetFont and f.SetFont and f:GetObjectType() ~= "FontString" and type(f.slot1) ~= "table" then
    local file, size, flags = f:GetFont()
    local mine = Media:FontObject("large")
    local mfile, _, mflags = mine and mine:GetFont()
    if file and mfile then
      f:SetFont(mfile, size, mflags or flags)
      C.Own(id, function() f:SetFont(file, size, flags) end)
    end
  end
end
SK.Register("textAlerts", { label = "Raid warnings and errors", frames = S2.TEXT, parts = {}, extra = textFrame })

-- Bars: mirror timers and the encounter alt power bar -------------------------------------------
function S2.Bar(id, bar)
  if not (bar and bar.GetStatusBarTexture and C.Usable(bar)) or S2.bars[bar] then return false end
  local path = C.Tex("Scroll_Thumb")
  local old = bar:GetStatusBarTexture()
  local oldPath = old and old.GetTexture and old:GetTexture()
  if path then bar:SetStatusBarTexture(path) end
  S2.bars[bar] = true
  local bg = C.Over(id, bar, "bg", "BACKGROUND", "Panel_EmberGlass", -8)
  bg:ClearAllPoints(); bg:SetPoint("TOPLEFT", -2, 2); bg:SetPoint("BOTTOMRIGHT", 2, -2)
  local text = C.K(bar, "Text") or C.K(bar, "text")
  if text then SK.Font(id, text, "small") end
  C.Own(id, function() S2.bars[bar] = nil; if oldPath then bar:SetStatusBarTexture(oldPath) end end)
  return true
end
local function mirror(f, _, id)
  for _, child in ipairs({ f:GetChildren() }) do
    local bar = C.K(child, "StatusBar") or (child.GetStatusBarTexture and child)
    if bar then S2.Bar(id, bar) end
    C.Fade(id, C.K(child, "Border"))
  end
end
SK.Register("mirrorTimers", { label = "Breath and fatigue timers", frames = { "MirrorTimerContainer", "MirrorTimer1", "MirrorTimer2", "MirrorTimer3" }, parts = {}, extra = mirror })

-- Widgets (top centre, below minimap, power bar) -----------------------------------------------
S2.WIDGETS = { "UIWidgetTopCenterContainerFrame", "UIWidgetBelowMinimapContainerFrame", "UIWidgetPowerBarContainerFrame", "PlayerPowerBarAlt" }
function S2.Widget(id, w)
  if not C.Usable(w) then return end
  for _, k in ipairs({ "Text", "LeftText", "RightText", "Label" }) do local fs = w[k]; if type(fs) == "table" and fs.GetObjectType and fs:GetObjectType() == "FontString" then SK.Font(id, fs, "small") end end
  local bar = C.K(w, "Bar") or C.K(w, "statusBar")
  if bar then S2.Bar(id, bar) end
end
local function widgets(f, _, id)
  local function run() for _, w in pairs(type(f.widgetFrames) == "table" and f.widgetFrames or {}) do S2.Widget(id, w) end end
  if f.GetName and f:GetName() == "PlayerPowerBarAlt" then
    local bar = C.K(f, "statusFrame") or f
    if bar.GetStatusBarTexture then S2.Bar(id, bar) end
    return
  end
  SK.Extras2.Hook(f, "UpdateWidgetLayout", id, run)
  run()
end
SK.Register("widgets", { label = "Widgets and alt power", frames = S2.WIDGETS, parts = {}, extra = widgets })

-- Help tips ------------------------------------------------------------------------------
function S2.HelpTip(id, tip)
  if not C.Usable(tip) then return end
  for _, k in ipairs({ "Bg", "Background" }) do C.Fade(id, C.K(tip, k)) end
  C.Fade(id, C.K(tip, "NineSlice"))
  local bg = C.Over(id, tip, "panel", "BACKGROUND", "Panel_EmberGlass", -8); bg:ClearAllPoints(); bg:SetAllPoints()
  local edge = C.Over(id, tip, "edge", "BORDER", "Border_R10_1px"); edge:ClearAllPoints(); edge:SetAllPoints()
  Theme:Paint(edge, "accent", 0.9, "vertex")
  local text = C.K(tip, "Text"); if text then SK.Font(id, text, "body") end
end
local function helpTips(_, _, id)
  local ht = rawget(_G, "HelpTip")
  if type(ht) ~= "table" or S2.helpHooked then return end
  local function run() local pool = ht.framePool; if pool and pool.EnumerateActive then for tip in pool:EnumerateActive() do S2.HelpTip(id, tip) end end end
  if type(ht.Show) == "function" then S2.helpHooked = true; hooksecurefunc(ht, "Show", function() if SK.applied[id] then securecallfunction(run) end end) end
  run()
end
SK.Register("helpTips", { label = "Help tips", global = true, parts = {}, extra = helpTips })

-- Subtitles ---------------------------------------------------------------------------------
local function subtitles(f, _, id)
  for _, k in ipairs({ "Subtitle1", "Subtitle2" }) do local fs = C.K(f, k) or rawget(_G, "SubtitlesFrameSubtitle" .. k:sub(-1)); if fs then SK.Font(id, fs, "large") end end
end
SK.Register("subtitles", { label = "Movie subtitles", frames = { "SubtitlesFrame" }, parts = {}, extra = subtitles })

-- Chat bubbles (open world only) --------------------------------------------------------------
function S2.Bubble(id, holder)
  if not C.Usable(holder) or S2.bubbles[holder] then return false end
  local bubble = holder:GetChildren()
  if not (bubble and C.Usable(bubble)) then return false end
  S2.bubbles[holder] = true
  for _, r in ipairs({ bubble:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then C.Fade(id, r)
    elseif r.GetObjectType and r:GetObjectType() == "FontString" then SK.Font(id, r, "body") end
  end
  C.Fade(id, C.K(bubble, "Tail"))
  local bg = C.Over(id, bubble, "panel", "BACKGROUND", "Panel_EmberGlass", -8); bg:ClearAllPoints(); bg:SetAllPoints()
  local edge = C.Over(id, bubble, "edge", "BORDER", "Border_R10_1px"); edge:ClearAllPoints(); edge:SetAllPoints()
  Theme:Paint(edge, "line", 1, "vertex")
  C.Own(id, function() S2.bubbles[holder] = nil end)
  return true
end
function S2.ScanBubbles(id)
  local api = C_ChatBubbles
  if not (api and api.GetAllChatBubbles) then return 0 end
  local n = 0
  for _, holder in ipairs(api.GetAllChatBubbles(false) or {}) do if S2.Bubble(id, holder) then n = n + 1 end end
  return n
end
local BUBBLE_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" }
local function bubbles(_, _, id)
  if S2.bubbleFrame then return end
  local f = PUI:CreateFrame("Frame", nil, UIParent, nil, "Skins")
  for _, e in ipairs(BUBBLE_EVENTS) do f:RegisterEvent(e) end
  -- Bubbles appear a frame after the chat event: one short Ticker step, then off.
  f:SetScript("OnEvent", function()
    if not SK.applied[id] then return end
    Ticker:Register("skins.bubbles", 0.05, function() Ticker:Unregister("skins.bubbles"); S2.ScanBubbles(id) end, "Skins")
  end)
  S2.bubbleFrame = f
end
SK.Register("chatBubbles", { label = "Chat bubbles", global = true, parts = {}, extra = bubbles })

-- Surface list (Packs.lua turns these into switches). { id, label, tooltip, group, extras }
for _, sf in ipairs({
  { "textAlerts", "Raid warnings and errors", "Phoenix fonts on raid warnings, boss emotes and the red error text." },
  { "mirrorTimers", "Breath and fatigue timers", "Phoenix bars for breath, fatigue and feign death timers." },
  { "widgets", "Widgets and alt power", "Phoenix fonts and bars on top-centre and minimap widgets and the encounter power bar." },
  { "helpTips", "Help tips", "Phoenix panel on Blizzard's tutorial help tips." },
  { "subtitles", "Movie subtitles", "Phoenix font on cinematic subtitles." },
  { "chatBubbles", "Chat bubbles", "Phoenix chat bubbles in the open world (Blizzard locks them inside instances)." },
}) do table.insert(SK.SURFACES, sf) end
