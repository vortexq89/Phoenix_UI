local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Minimap (plan 5.7, mockup 14, owners 1.O): shape, size and border on a
-- dedicated host; Blizzard cluster parts hidden one by one (alpha only, never
-- reparented); zone / clock / coordinates / instance difficulty texts; the
-- coordinates conflict notice (nothing changes until the user picks); the
-- queue eye countdown read from PUI.Queue (Group Finder owns it); a middle-click
-- micro menu; a friends tooltip; indicators (Great Vault, calendar invites);
-- a ping announcer; scroll zoom with reset. The player's own layout is
-- captured on first enable and restored when the module turns off.
-- Texts refresh on one Ticker entry that exists only while a text is shown.
local _, ns = ...
local Schema, CQ, Ticker, Media, Theme, Secret = PUI.Schema, PUI.CombatQueue, PUI.Ticker, PUI.Media, PUI.Theme, PUI.Secret
local OWNER = "Minimap"

local MM = { active = false, saved = {} }
ns.MM = MM
PUI.Minimap = MM

local s = { shape = "square", size = 200, hideCluster = true, clock = true, zone = true, coords = false,
  borderSize = 2, borderColor = { r = 0, g = 0, b = 0, a = 1 }, oocAlpha = 1, scrollZoom = true, zoomReset = 10, rotate = "game",
  zonePos = "TOP", zoneColor = "pvp", clockPos = "BOTTOM", clock24 = true, clockServer = false, coordsPos = "BOTTOMLEFT",
  coordsDecimals = 1, coordsInstances = false, coordsColor = { r = 1, g = 1, b = 1, a = 1 }, fontSize = 12,
  difficulty = true, difficultyPos = "TOPRIGHT", difficultySize = false, coordsOwner = "ask",
  queueEye = true, queueSound = "None", queueAt = 10, queueColor = { r = 1, g = 0.82, b = 0.2, a = 1 },
  middleClick = "micro", friends = false, friendsCap = 10, friendsNotes = true, indicators = true, ping = false,
  hide = { zoom = false, tracking = false, calendar = false, mail = false, craft = false, expansion = false, compartment = false, instance = false } }
MM.settings = s
MM.MASKS = { square = "Interface\\Buttons\\WHITE8X8", circle = "Interface\\Masks\\CircleMaskScalable" }
MM.POSITIONS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local POS_LABELS = { TOPLEFT = "Top left", TOP = "Top", TOPRIGHT = "Top right", LEFT = "Left", RIGHT = "Right",
  BOTTOMLEFT = "Bottom left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom right" }

------------------------------------------------------------------------------
-- Blizzard parts (each hidden by alpha only, so secure parents never change).
local function cluster() return rawget(_G, "MinimapCluster") end
-- Child frames are plain fields on Blizzard frames; rawget never invokes a metatable.
local function child(obj, k) return type(obj) == "table" and rawget(obj, k) or nil end
local PARTS = {
  border = function() return child(cluster(), "BorderTop") end,
  zonebar = function() return child(cluster(), "ZoneTextButton") end,
  compass = function() return rawget(_G, "MinimapCompassTexture") end,
  zoom = function() return child(Minimap, "ZoomIn"), child(Minimap, "ZoomOut") end,
  tracking = function() return child(cluster(), "Tracking") end,
  calendar = function() return rawget(_G, "GameTimeFrame") end,
  mail = function() return child(child(cluster(), "IndicatorFrame"), "MailFrame") end,
  craft = function() return child(child(cluster(), "IndicatorFrame"), "CraftingOrderFrame") end,
  expansion = function() return rawget(_G, "ExpansionLandingPageMinimapButton") end,
  compartment = function() return rawget(_G, "AddonCompartmentFrame") end,
  instance = function() return child(cluster(), "InstanceDifficulty") end,
}
MM.Child = child
MM.PARTS = PARTS
MM.PART_LABELS = { zoom = "Zoom buttons", tracking = "Tracking button", calendar = "Calendar button", mail = "Mail icon",
  craft = "Crafting order icon", expansion = "Expansion summary button", compartment = "Addon compartment",
  instance = "Blizzard instance difficulty badge" }
MM.PART_ORDER = { "zoom", "tracking", "calendar", "mail", "craft", "expansion", "compartment", "instance" }

local function partHidden(name)
  if name == "border" or name == "zonebar" or name == "compass" then return s.hideCluster end
  return s.hide[name] == true
end

local function setPart(name, hidden)
  local a, b = PARTS[name]()
  for _, part in ipairs({ a or false, b or false }) do
    if type(part) == "table" and part.SetAlpha then
      if MM.saved[part] == nil then MM.saved[part] = part:GetAlpha() end
      part:SetAlpha(hidden and 0 or MM.saved[part])
    end
  end
end

------------------------------------------------------------------------------
-- Instance difficulty text ("M+16", "H", "25N", "LFR", "D").
local DIFF = { [1] = "N", [2] = "H", [8] = "M+", [23] = "M", [24] = "TW", [33] = "TW", [7] = "LFR", [17] = "LFR",
  [14] = "N", [15] = "H", [16] = "M", [3] = "N", [4] = "N", [5] = "H", [6] = "H", [9] = "40", [205] = "F", [208] = "D",
  [150] = "N", [151] = "TW", [167] = "TW", [216] = "Q" }
MM.DIFF = DIFF
function MM.DifficultyText(diffID, maxPlayers, keyLevel, withSize)
  if type(diffID) ~= "number" or diffID == 0 then return "" end
  local tag = DIFF[diffID]
  if not tag then return "" end
  if diffID == 8 then return (type(keyLevel) == "number" and keyLevel > 0) and ("M+" .. keyLevel) or "M+" end
  if withSize and type(maxPlayers) == "number" and maxPlayers > 5 and tag ~= "LFR" then return maxPlayers .. tag end
  return tag
end

function MM.CurrentDifficulty()
  local _, kind, diffID, _, maxPlayers = GetInstanceInfo()
  if kind == "none" then return "" end
  local level = 0
  if diffID == 8 then level = C_ChallengeMode.GetActiveKeystoneInfo() or 0 end
  return MM.DifficultyText(diffID, maxPlayers, level, s.difficultySize)
end

------------------------------------------------------------------------------
-- Coordinates and the conflict with Blizzard's built-in coordinates (1.O).
MM.BLIZZ_COORDS = "minimapShowPlayerCoords"
function MM.BlizzardCoordsOn() return C_CVar.GetCVar(MM.BLIZZ_COORDS) == "1" end
-- True when Phoenix may draw its coordinates (minimap text, Data Bars block).
function MM.CoordsAllowed()
  if s.coordsOwner == "blizzard" then return false end
  if s.coordsOwner == "phoenix" then return true end
  return not MM.BlizzardCoordsOn() -- "ask": nothing changes while Blizzard's are on
end

function MM.Coords(decimals)
  local map = C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  if Secret.IsSecret(x) or Secret.IsSecret(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
  local d = decimals or s.coordsDecimals
  return string.format("%." .. d .. "f, %." .. d .. "f", x * 100, y * 100)
end

MM.coordsAsked = false
function MM.CoordsNotice()
  if MM.coordsAsked or s.coordsOwner ~= "ask" or not (s.coords and MM.BlizzardCoordsOn()) then return end
  MM.coordsAsked = true
  PUI.Dialogs:Confirm({ title = "Phoenix UI: map coordinates",
    text = "Blizzard now shows coordinates itself. Who should show them? Nothing changes until you pick; you can change it later under Minimap > Coordinates.",
    accept = "Phoenix coords", cancel = "Blizzard coords",
    onAccept = function() Schema:Set("mm.coords.owner", "phoenix") end,
    onCancel = function() Schema:Set("mm.coords.owner", "blizzard") end })
end

local function applyCoordsOwner()
  if MM.active and s.coordsOwner == "phoenix" and s.coords then
    PUI.CVars:Set(OWNER, MM.BLIZZ_COORDS, "0")
  else
    PUI.CVars:Restore(OWNER, MM.BLIZZ_COORDS)
  end
end

------------------------------------------------------------------------------
-- Texts
local function clockText(set)
  set = set or s
  if set.clockServer then
    local h, m = GetGameTime()
    if set.clock24 then return string.format("%02d:%02d", h, m) end
    return string.format("%d:%02d %s", (h % 12 == 0) and 12 or h % 12, m, h < 12 and "AM" or "PM")
  end
  local t = date(set.clock24 and "%H:%M" or "%I:%M %p")
  if not set.clock24 then t = t:gsub("^0", "") end
  return t
end
MM.ClockText = clockText

local ZONE_COLORS = { sanctuary = { 0.41, 0.8, 0.94 }, arena = { 1, 0.1, 0.1 }, friendly = { 0.1, 1, 0.1 },
  hostile = { 1, 0.1, 0.1 }, contested = { 1, 0.7, 0 }, combat = { 1, 0.1, 0.1 } }
function MM.ZoneColor(set)
  set = set or s
  if set.zoneColor == "white" then return 1, 1, 1 end
  if set.zoneColor == "accent" then return Theme:Color("accent") end
  local pvp = GetZonePVPInfo()
  local c = ZONE_COLORS[pvp or ""] or { 1, 0.9, 0.7 }
  return c[1], c[2], c[3]
end

local texts
local INSET = { TOPLEFT = { 4, -4 }, TOP = { 0, -4 }, TOPRIGHT = { -4, -4 }, LEFT = { 4, 0 }, RIGHT = { -4, 0 },
  BOTTOMLEFT = { 4, 4 }, BOTTOM = { 0, 4 }, BOTTOMRIGHT = { -4, 4 } }
-- PlaceTexts(host, list, settings): the one paint path for the real minimap
-- and the options preview.
function MM.PlaceTexts(host, list, set)
  set = set or s
  for k, pos in pairs({ zone = set.zonePos, clock = set.clockPos, coords = set.coordsPos, difficulty = set.difficultyPos }) do
    local fs = list[k]
    if fs then
      fs:ClearAllPoints()
      local o = INSET[pos] or INSET.TOP
      fs:SetPoint(pos, host, pos, o[1], o[2])
      local font, _, flags = fs:GetFont()
      if font then fs:SetFont(font, set.fontSize, flags) end
    end
  end
  if list.coords then local c = set.coordsColor; list.coords:SetTextColor(c.r, c.g, c.b, c.a or 1) end
  if list.queue then local c = set.queueColor; list.queue:SetTextColor(c.r, c.g, c.b, c.a or 1) end
  if list.zone then list.zone:SetTextColor(MM.ZoneColor(set)) end
end

local function buildTexts()
  if texts then return texts end
  texts = {}
  for _, k in ipairs({ "clock", "zone", "coords", "difficulty", "queue", "friends", "indicators", "ping" }) do
    local fs = Minimap:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(Media:FontObject("number"))
    fs:Hide()
    texts[k] = fs
  end
  texts.queue:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 6, 22)
  texts.indicators:SetPoint("TOP", Minimap, "BOTTOM", 0, -4)
  texts.ping:SetPoint("CENTER", Minimap, "CENTER", 0, 24)
  texts.friends:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -4, 22)
  MM.texts = texts
  return texts
end

local function tick()
  if not texts then return end
  if s.clock then texts.clock:SetText(clockText()) end
  if s.zone then texts.zone:SetText(GetMinimapZoneText()); texts.zone:SetTextColor(MM.ZoneColor()) end
  if s.coords then
    local _, kind = GetInstanceInfo()
    local show = MM.CoordsAllowed() and (s.coordsInstances or kind == "none")
    texts.coords:SetShown(show)
    if show then texts.coords:SetText(MM.Coords() or "") end
  end
end
MM.Tick = tick

------------------------------------------------------------------------------
-- Queue eye: reads PUI.Queue (Group Finder owns the countdown).
local queueBeeped = false
function MM.QueueText()
  local left = PUI.Queue and PUI.Queue:Remaining()
  if not left then return nil end
  return PUI.Format.Duration(left, 0)
end

local function queueTick()
  if not texts then return end
  local text = MM.QueueText()
  if not text then
    texts.queue:Hide()
    if Ticker:IsRegistered("mm.queue") then Ticker:Unregister("mm.queue") end
    return
  end
  texts.queue:SetText(text)
  texts.queue:Show()
  local left = PUI.Queue:Remaining() or 0
  if not queueBeeped and left <= s.queueAt and s.queueSound ~= "None" then
    queueBeeped = true
    Media:PlaySound(s.queueSound)
  end
end
MM.QueueTick = queueTick

function MM.OnQueue()
  if not (MM.active and s.queueEye) then
    if texts then texts.queue:Hide() end
    if Ticker:IsRegistered("mm.queue") then Ticker:Unregister("mm.queue") end
    return
  end
  buildTexts()
  if PUI.Queue:Pop() and not Ticker:IsRegistered("mm.queue") then
    queueBeeped = false
    Ticker:Register("mm.queue", 0.2, queueTick, OWNER)
  end
  queueTick()
end
PUI.Kernel:On("QUEUE_CHANGED", function() if MM.active then MM.OnQueue() end end)

------------------------------------------------------------------------------
-- Middle-click micro menu: Phoenix's own list calling Blizzard's toggles.
MM.MICRO = {
  { "Character", "ToggleCharacter", "PaperDollFrame" }, { "Spellbook", "PlayerSpellsUtil.ToggleSpellBookFrame" },
  { "Talents", "PlayerSpellsUtil.ToggleClassTalentFrame" }, { "Achievements", "ToggleAchievementFrame" },
  { "Quest log", "ToggleQuestLog" }, { "Guild & communities", "ToggleGuildFrame" }, { "Group Finder", "PVEFrame_ToggleFrame" },
  { "Collections", "ToggleCollectionsJournal" }, { "Adventure guide", "ToggleEncounterJournal" }, { "Shop", "ToggleStoreUI" },
  { "Calendar", "ToggleCalendar" }, { "Friends", "ToggleFriendsFrame" },
}

local function resolve(path)
  local obj = _G
  for part in path:gmatch("[^%.]+") do
    obj = type(obj) == "table" and rawget(obj, part) or nil
    if obj == nil then return nil end
  end
  return obj
end
MM.Resolve = resolve

function MM.RunMicro(i)
  local e = MM.MICRO[i]
  if not e or InCombatLockdown() then return false end
  local fn = resolve(e[2])
  if type(fn) ~= "function" then return false end
  if e[3] then fn(e[3]) else fn() end
  return true
end

local menu
function MM.ToggleMenu()
  if InCombatLockdown() then return end
  if not menu then
    menu = PUI:CreateFrame("Frame", "PhoenixUI_MinimapMenu", UIParent, "BackdropTemplate", OWNER)
    Theme:Backdrop(menu, "surface.1")
    menu:SetFrameStrata("DIALOG")
    menu:SetSize(180, 12 + #MM.MICRO * 20)
    menu.rows = {}
    for i, e in ipairs(MM.MICRO) do
      local b = CreateFrame("Button", nil, menu)
      b:SetSize(168, 20)
      b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
      b.text = b:CreateFontString(nil, "OVERLAY")
      b.text:SetFontObject(Media:FontObject("label"))
      b.text:SetPoint("LEFT", 6, 0)
      b.text:SetText(e[1])
      b.hl = b:CreateTexture(nil, "HIGHLIGHT")
      b.hl:SetAllPoints()
      b.hl:SetColorTexture(1, 1, 1, 0.08)
      b:SetScript("OnClick", function() MM.RunMicro(i); menu:Hide() end)
      menu.rows[i] = b
    end
    menu:Hide()
    MM.menu = menu
  end
  if menu:IsShown() then menu:Hide(); return end
  menu:ClearAllPoints()
  menu:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -6, 0)
  menu:Show()
end

function MM.OnMouseUp(_, button)
  if not MM.active or button ~= "MiddleButton" or InCombatLockdown() then return end
  if s.middleClick == "micro" then MM.ToggleMenu()
  elseif s.middleClick == "calendar" then local fn = resolve("ToggleCalendar"); if type(fn) == "function" then fn() end
  elseif s.middleClick == "tracking" then
    local t = child(child(cluster(), "Tracking"), "Button")
    if t and type(t.OpenMenu) == "function" then t:OpenMenu() end
  end
end

------------------------------------------------------------------------------
-- Friends tooltip: online WoW friends and Battle.net friends in game, capped,
-- with notes on a second line.
function MM.FriendLines(cap, notes)
  local out = {}
  local n = C_FriendList.GetNumFriends() or 0
  for i = 1, n do
    local f = C_FriendList.GetFriendInfoByIndex(i)
    if f and f.connected then
      out[#out + 1] = { name = f.name, where = f.area or "", note = notes and f.notes or nil }
    end
  end
  local numBN = select(2, BNGetNumFriends()) or 0
  for i = 1, numBN do
    local a = C_BattleNet.GetFriendAccountInfo(i)
    local g = a and a.gameAccountInfo
    if g and g.isOnline and g.clientProgram == "WoW" and g.characterName then
      out[#out + 1] = { name = g.characterName, where = g.areaName or "", note = notes and a.note or nil }
    end
  end
  local total = #out
  while #out > cap do out[#out] = nil end
  return out, total
end

function MM.ShowFriends(owner)
  local tip = GameTooltip
  tip:SetOwner(owner, "ANCHOR_LEFT")
  local list, total = MM.FriendLines(s.friendsCap, s.friendsNotes)
  tip:AddLine(string.format("Friends (%d online, cap %d)", total, s.friendsCap), 1, 0.82, 0)
  for _, f in ipairs(list) do
    tip:AddDoubleLine(f.name, f.where, 1, 1, 1, 0.7, 0.7, 0.7)
    if f.note and f.note ~= "" then tip:AddLine("   " .. f.note, 0.55, 0.55, 0.6) end
  end
  tip:Show()
end

------------------------------------------------------------------------------
-- Indicators: Great Vault ready and pending calendar invites.
function MM.IndicatorText()
  local parts = {}
  if C_WeeklyRewards.HasAvailableRewards() then parts[#parts + 1] = "Great Vault ready" end
  local inv = C_Calendar.GetNumPendingInvites() or 0
  if inv > 0 then parts[#parts + 1] = inv == 1 and "1 calendar invite" or (inv .. " calendar invites") end
  return table.concat(parts, "  -  ")
end

local friendsHover
local function refreshIndicators()
  if not texts then return end
  texts.indicators:SetShown(MM.active and s.indicators)
  if s.indicators then texts.indicators:SetText(MM.IndicatorText()) end
  texts.difficulty:SetShown(MM.active and s.difficulty)
  if s.difficulty then texts.difficulty:SetText(MM.CurrentDifficulty()) end
  texts.friends:SetShown(MM.active and s.friends)
  if s.friends then
    texts.friends:SetText(string.format("%d friends", select(2, MM.FriendLines(999, false))))
    if not friendsHover then
      friendsHover = PUI:CreateFrame("Frame", nil, Minimap, nil, OWNER)
      friendsHover:SetAllPoints(texts.friends)
      friendsHover:EnableMouse(true)
      friendsHover:SetScript("OnEnter", function(self) MM.ShowFriends(self) end)
      friendsHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
  end
  if friendsHover then friendsHover:SetShown(MM.active and s.friends) end
end
MM.RefreshIndicators = refreshIndicators

-- Ping announcer: who pinged the minimap, shown for 3 s (one-shot Ticker entry).
function MM.OnPing(unit)
  if not (MM.active and s.ping and texts) then return end
  local name = UnitName(unit)
  if not name or Secret.IsSecret(name) then return end
  texts.ping:SetText(name .. " pinged")
  texts.ping:Show()
  if Ticker:IsRegistered("mm.ping") then Ticker:Unregister("mm.ping") end
  Ticker:Register("mm.ping", 3, function() texts.ping:Hide(); Ticker:Unregister("mm.ping") end, OWNER)
end

------------------------------------------------------------------------------
-- Zoom: mouse wheel and an automatic reset (one-shot Ticker entry).
function MM.ScheduleZoomReset()
  if Ticker:IsRegistered("mm.zoom") then Ticker:Unregister("mm.zoom") end
  if s.zoomReset <= 0 or Minimap:GetZoom() == 0 then return end
  Ticker:Register("mm.zoom", s.zoomReset, function() Minimap:SetZoom(0); Ticker:Unregister("mm.zoom") end, OWNER)
end

function MM.OnWheel(_, delta)
  if not (MM.active and s.scrollZoom) then return end
  local z = Minimap:GetZoom() + (delta > 0 and 1 or -1)
  z = math.max(0, math.min(Minimap:GetZoomLevels() - 1, z))
  Minimap:SetZoom(z)
  MM.ScheduleZoomReset()
end

------------------------------------------------------------------------------
-- Border on its own host frame, re-anchored on every apply.
function MM.PaintBorder(border, host, set)
  set = set or s
  local px = set.borderSize
  border:ClearAllPoints()
  border:SetPoint("TOPLEFT", host, "TOPLEFT", -px, px)
  border:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", px, -px)
  local c = set.borderColor
  border.tex:SetColorTexture(c.r, c.g, c.b, c.a or 1)
  border:SetShown(px > 0 and set.shape == "square")
end

local function ensureBorder()
  if MM.border then return MM.border end
  local b = PUI:CreateFrame("Frame", nil, Minimap, nil, OWNER)
  b:SetFrameLevel(math.max(0, Minimap:GetFrameLevel() - 1))
  b.tex = b:CreateTexture(nil, "BACKGROUND")
  b.tex:SetAllPoints()
  MM.border = b
  return b
end

------------------------------------------------------------------------------
-- First-install capture (stored once; the restore target on disable).
function MM.Capture()
  local cap = Schema:Get("mm.captured")
  if cap and cap.size then return cap end
  cap = { size = { Minimap:GetWidth(), Minimap:GetHeight() } }
  Schema:Set("mm.captured", cap)
  return cap
end

local hooked = false
local function hook()
  if hooked then return end
  hooked = true
  Minimap:HookScript("OnMouseUp", MM.OnMouseUp)
  Minimap:HookScript("OnMouseWheel", MM.OnWheel)
end

local function oocAlpha()
  if not MM.active then return end
  if InCombatLockdown() then
    Minimap:SetAlpha(1)
    CQ.Defer("mm.alpha", function() if MM.active then Minimap:SetAlpha(s.oocAlpha) end end)
  else
    Minimap:SetAlpha(s.oocAlpha)
  end
end

function MM.Apply()
  if not MM.active then return end
  local t = buildTexts()
  MM.PlaceTexts(Minimap, t, s)
  for _, k in ipairs({ "clock", "zone", "coords" }) do t[k]:SetShown(s[k]) end
  local need = s.clock or s.zone or s.coords
  if need and not Ticker:IsRegistered("mm.texts") then Ticker:Register("mm.texts", 1, tick, OWNER)
  elseif not need and Ticker:IsRegistered("mm.texts") then Ticker:Unregister("mm.texts") end
  tick()
  for name in pairs(PARTS) do setPart(name, partHidden(name)) end
  Minimap:SetMaskTexture(MM.MASKS[s.shape])
  MM.PaintBorder(ensureBorder(), Minimap, s)
  oocAlpha()
  Minimap:EnableMouseWheel(s.scrollZoom)
  if s.rotate == "on" then PUI.CVars:Set(OWNER, "rotateMinimap", "1")
  elseif s.rotate == "off" then PUI.CVars:Set(OWNER, "rotateMinimap", "0")
  else PUI.CVars:Restore(OWNER, "rotateMinimap") end
  applyCoordsOwner()
  MM.CoordsNotice()
  refreshIndicators()
  MM.OnQueue()
  PUI.Kernel:Fire("MINIMAP_APPLIED")
  CQ.Defer("mm.size", function()
    if not MM.active then return end
    Minimap:SetSize(s.size, s.size)
  end)
end

local function onEnable(mod)
  MM.active = true
  MM.Capture()
  hook()
  mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() tick(); refreshIndicators() end)
  for _, ev in ipairs({ "PLAYER_DIFFICULTY_CHANGED", "CHALLENGE_MODE_START", "PLAYER_ENTERING_WORLD", "WEEKLY_REWARDS_UPDATE",
    "CALENDAR_UPDATE_PENDING_INVITES", "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED" }) do
    mod:RegisterEvent(ev, refreshIndicators)
  end
  mod:RegisterEvent("MINIMAP_PING", function(_, unit) MM.OnPing(unit) end)
  mod:RegisterEvent("PLAYER_REGEN_DISABLED", oocAlpha)
  MM.Apply()
end

local function onDisable()
  MM.active = false
  for _, key in ipairs({ "mm.texts", "mm.queue", "mm.zoom", "mm.ping" }) do
    if Ticker:IsRegistered(key) then Ticker:Unregister(key) end
  end
  if texts then for _, fs in pairs(texts) do fs:Hide() end end
  if friendsHover then friendsHover:Hide() end
  if MM.border then MM.border:Hide() end
  if menu then menu:Hide() end
  for part, alpha in pairs(MM.saved) do part:SetAlpha(alpha) end
  wipe(MM.saved)
  Minimap:SetMaskTexture(MM.MASKS.circle)
  Minimap:SetAlpha(1)
  PUI.CVars:Restore(OWNER, "rotateMinimap")
  PUI.CVars:Restore(OWNER, MM.BLIZZ_COORDS)
  PUI.Kernel:Fire("MINIMAP_APPLIED")
  CQ.Defer("mm.size", function()
    if MM.active then return end
    local cap = Schema:Get("mm.captured")
    if cap and cap.size then Minimap:SetSize(cap.size[1], cap.size[2]) end
  end)
end

------------------------------------------------------------------------------
-- Settings (every look and behaviour is a setting; Simple first, depth in Advanced).
local schema = {}
MM.schema = schema
local function key(k, field, def, sub)
  def.owner = OWNER
  def.apply = function(value)
    if sub then s[sub][field] = value else s[field] = value end
    MM.Apply()
  end
  def.searchTags = def.searchTags or { "minimap", "map" }
  schema[k] = def
end
local function posChoice(default, label, tip)
  return { type = "select", default = default, choices = MM.POSITIONS, choiceLabels = POS_LABELS, label = label, tooltip = tip, mode = "advanced" }
end
key("mm.shape", "shape", { type = "select", default = "square", choices = { "square", "circle" }, label = "Minimap shape",
  tooltip = "Square or round minimap.", mode = "simple" })
key("mm.size", "size", { type = "range", default = 200, min = 120, max = 400, step = 1, label = "Minimap size",
  tooltip = "Width and height of the minimap.", mode = "simple" })
key("mm.borderSize", "borderSize", { type = "range", default = 2, min = 0, max = 8, step = 1, label = "Border thickness",
  tooltip = "Border around the square minimap; 0 hides it.", mode = "simple" })
key("mm.borderColor", "borderColor", { type = "color", default = { r = 0, g = 0, b = 0, a = 1 }, label = "Border colour",
  tooltip = "Colour of the minimap border.", mode = "advanced" })
key("mm.oocAlpha", "oocAlpha", { type = "range", default = 1, min = 0.2, max = 1, step = 0.05, label = "Opacity out of combat",
  tooltip = "Fade the minimap while you are out of combat; it is always fully visible in combat.", mode = "advanced" })
key("mm.hideCluster", "hideCluster", { type = "toggle", default = true, label = "Hide minimap border and zone bar",
  tooltip = "Fades out Blizzard's minimap border, zone bar and compass ring; Phoenix shows the zone itself.", mode = "simple" })
key("mm.clock", "clock", { type = "toggle", default = true, label = "Clock", tooltip = "Shows the time on the minimap.", mode = "simple" })
key("mm.zone", "zone", { type = "toggle", default = true, label = "Zone name", tooltip = "Shows the zone name on the minimap.", mode = "simple" })
key("mm.coords", "coords", { type = "toggle", default = false, label = "Coordinates",
  tooltip = "Player coordinates on the minimap. If Blizzard's own coordinates are on you are asked who shows them; nothing changes until you pick.", mode = "simple" })
key("mm.scrollZoom", "scrollZoom", { type = "toggle", default = true, label = "Zoom with the mouse wheel",
  tooltip = "Scroll over the minimap to zoom in and out.", mode = "simple" })
key("mm.zoomReset", "zoomReset", { type = "range", default = 10, min = 0, max = 60, step = 1, label = "Reset zoom after (seconds)",
  tooltip = "Zooms back out this many seconds after you last zoomed; 0 keeps your zoom.", mode = "advanced" })
key("mm.rotate", "rotate", { type = "select", default = "game", choices = { "game", "on", "off" },
  choiceLabels = { game = "Leave as the game has it", on = "Rotate with the camera", off = "North always up" },
  label = "Rotate minimap", tooltip = "Rotation is a game setting; Phoenix records your old value and puts it back when you change this or turn the module off.", mode = "advanced" })
key("mm.middleClick", "middleClick", { type = "select", default = "micro", choices = { "micro", "tracking", "calendar", "none" },
  choiceLabels = { micro = "Micro menu", tracking = "Tracking menu", calendar = "Calendar", none = "Nothing" },
  label = "Middle-click on the minimap", tooltip = "What a middle click on the minimap opens. The micro menu lists Character, Spellbook, Talents, Collections, Group Finder and more.", mode = "simple" })
-- Texts tab
key("mm.text.fontSize", "fontSize", { type = "range", default = 12, min = 8, max = 20, step = 1, label = "Text size",
  tooltip = "Font size of every minimap text.", mode = "simple" })
key("mm.text.zonePos", "zonePos", posChoice("TOP", "Zone position", "Where the zone name sits on the minimap."))
key("mm.text.zoneColor", "zoneColor", { type = "select", default = "pvp", choices = { "pvp", "white", "accent" },
  choiceLabels = { pvp = "By zone type (sanctuary, contested...)", white = "White", accent = "Accent colour" },
  label = "Zone colour", tooltip = "How the zone name is coloured.", mode = "advanced" })
key("mm.text.clockPos", "clockPos", posChoice("BOTTOM", "Clock position", "Where the clock sits on the minimap."))
key("mm.text.clock24", "clock24", { type = "toggle", default = true, label = "24-hour clock", tooltip = "24-hour time instead of AM/PM.", mode = "simple" })
key("mm.text.clockServer", "clockServer", { type = "toggle", default = false, label = "Server time",
  tooltip = "Show realm time instead of your computer's time.", mode = "advanced" })
key("mm.text.difficulty", "difficulty", { type = "toggle", default = true, label = "Instance difficulty",
  tooltip = "Short difficulty text inside instances, such as M+16, H, M, LFR or TW.", mode = "simple" })
key("mm.text.difficultyPos", "difficultyPos", posChoice("TOPRIGHT", "Difficulty position", "Where the difficulty text sits."))
key("mm.text.difficultySize", "difficultySize", { type = "toggle", default = false, label = "Add group size",
  tooltip = "Adds the raid size to the difficulty, such as 25H.", mode = "advanced" })
-- Coordinates tab
key("mm.coords.owner", "coordsOwner", { type = "select", default = "ask", choices = { "ask", "phoenix", "blizzard" },
  choiceLabels = { ask = "Ask me (nothing changes)", phoenix = "Phoenix coords (Blizzard's off, restored if you change back)", blizzard = "Blizzard coords (Phoenix hides its own)" },
  label = "Who shows coordinates", tooltip = "Blizzard can show coordinates itself. Pick who shows them; the Data Bars coordinates block follows this too.", mode = "simple",
  searchTags = { "coordinates", "coords", "conflict", "blizzard" } })
key("mm.coords.decimals", "coordsDecimals", { type = "range", default = 1, min = 0, max = 2, step = 1, label = "Coordinate decimals",
  tooltip = "Digits after the decimal point.", mode = "advanced" })
key("mm.coords.position", "coordsPos", posChoice("BOTTOMLEFT", "Coordinates position", "Where the coordinates sit."))
key("mm.coords.color", "coordsColor", { type = "color", default = { r = 1, g = 1, b = 1, a = 1 }, label = "Coordinates colour",
  tooltip = "Colour of the coordinates text.", mode = "advanced" })
key("mm.coords.instances", "coordsInstances", { type = "toggle", default = false, label = "Show in instances",
  tooltip = "Coordinates are usually unavailable inside instances; on keeps the text where the game allows it.", mode = "advanced" })
-- Queue eye tab
key("mm.queue.eye", "queueEye", { type = "toggle", default = true, label = "Queue-pop countdown",
  tooltip = "When a dungeon, raid or battleground invite pops, a countdown shows by the queue eye. Group Finder owns the timer; the minimap only shows it.", mode = "simple",
  searchTags = { "queue", "countdown", "lfg", "pop", "minimap" } })
key("mm.queue.sound", "queueSound", { type = "select", default = "None", choices = function() return Media:List("sound") end, preview = "sound",
  label = "Countdown warning sound", tooltip = "Sound played once when the invite is about to expire.", mode = "advanced" })
key("mm.queue.at", "queueAt", { type = "range", default = 10, min = 3, max = 30, step = 1, label = "Warn at (seconds left)",
  tooltip = "When the warning sound plays.", mode = "advanced" })
key("mm.queue.color", "queueColor", { type = "color", default = { r = 1, g = 0.82, b = 0.2, a = 1 }, label = "Countdown colour",
  tooltip = "Colour of the countdown text.", mode = "advanced" })
-- Extras tab
key("mm.extra.indicators", "indicators", { type = "toggle", default = true, label = "Indicators",
  tooltip = "Great Vault ready and pending calendar invites under the minimap.", mode = "simple" })
key("mm.extra.friends", "friends", { type = "toggle", default = false, label = "Friends count and tooltip",
  tooltip = "Online friends count on the minimap; hover it for the list.", mode = "simple" })
key("mm.extra.friendsCap", "friendsCap", { type = "range", default = 10, min = 1, max = 50, step = 1, label = "Friends tooltip cap",
  tooltip = "Most friends listed in the tooltip.", mode = "advanced" })
key("mm.extra.friendsNotes", "friendsNotes", { type = "toggle", default = true, label = "Friend notes on a second line",
  tooltip = "Shows each friend's note under their name.", mode = "advanced" })
key("mm.extra.ping", "ping", { type = "toggle", default = false, label = "Ping announcer",
  tooltip = "Shows who pinged the minimap for a few seconds.", mode = "advanced" })
-- Blizzard parts tab (each hidden by alpha only)
for _, name in ipairs(MM.PART_ORDER) do
  key("mm.hide." .. name, name, { type = "toggle", default = false, label = "Hide " .. MM.PART_LABELS[name]:lower(),
    tooltip = "Fades out Blizzard's " .. MM.PART_LABELS[name]:lower() .. ". It comes back when you turn this off or the module off.", mode = "advanced" }, "hide")
end
schema["mm.captured"] = { type = "layout", default = {}, owner = OWNER, label = "Captured minimap layout",
  tooltip = "Your minimap as it was before Phoenix changed it.", mode = "advanced", apply = function() end }

MM.module = PUI:RegisterModule(OWNER, {
  label = "Minimap", tooltip = "Phoenix minimap: shape, border, texts, coordinates, queue countdown, addon button bin and more.", enabledByDefault = false,
  schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end

PUI.Slash:Register("minimap", function(rest)
  if rest == "restore" then
    Schema:Set("module.Minimap", false)
    PUI.Slash.Print("Minimap put back the way it was before Phoenix.")
  else
    PUI.OptionsHost:OpenOptions("Minimap")
  end
end, "[restore]: open the minimap page, or put your old minimap back")
