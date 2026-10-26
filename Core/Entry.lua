local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Entry points besides /pui: a "Phoenix UI" button on the Game Menu, the
-- Addon Compartment entry (TOC AddonCompartmentFunc) and a minimap button.
-- All three are Phoenix-owned frames; Blizzard frames are only hooked with
-- HookScript (no fields written, no secure functions replaced).
local Entry = { ICON = "Interface\\AddOns\\Phoenix_UI\\Media\\Logo\\PhoenixUI_Icon_64" }
PUI.Entry = Entry

function Entry:Open(button)
  if button == "RightButton" then PUI.OptionsHost:OpenStudio() else PUI.OptionsHost:OpenOptions() end
end

local MEDIA = {
  card = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Card_R24",
  border = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Border_Soft",
  control = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Control_R16",
  ring = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Controls\\Thumb_Ring",
  knob = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Controls\\Knob",
  glow = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Glow\\Radial",
  glyph = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\Logo\\Logo_Glyph_256",
}
Entry.MEDIA = MEDIA

local function text(parent, font, size, token)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(PUI.Media:Path("font", font) or PUI.Media:Font("Friz Quadrata"), size, "")
  PUI.Theme:Paint(fs, token or "text.primary", 1, "text")
  return fs
end

local function version()
  local v = C_AddOns.GetAddOnMetadata(PUI.ADDON_NAME, "Version") or ""
  if v:find("project%-version") then v = "dev" end
  return v
end

-- Game Menu (mockup 13): a Phoenix-styled entry docked to the top edge of
-- the menu. It is our own frame (Blizzard's buttons and layout are untouched).
function Entry:BuildGameMenu()
  local menu = rawget(_G, "GameMenuFrame")
  if self.menuButton or not menu then return self.menuButton end
  local b = CreateFrame("Button", "PhoenixUIGameMenuButton", UIParent)
  b:SetSize(200, 38)
  b:SetFrameStrata("DIALOG")
  b:SetPoint("BOTTOM", menu, "TOP", 0, 4)
  local bg = PUI.Theme:Slice(b, MEDIA.card, 28, "BACKGROUND")
  bg:SetVertexColor(0.09, 0.08, 0.08, 0.96)
  local edge = PUI.Theme:Slice(b, MEDIA.border, 28, "BORDER")
  PUI.Theme:Paint(edge, "accent", 0.9, "vertex")
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(24, 24)
  icon:SetPoint("LEFT", 10, 0)
  icon:SetTexture(self.ICON)
  local label = text(b, "Rajdhani Bold", 15)
  label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  label:SetText("PHOENIX  |cffff7a1aUI|r")
  local ver = text(b, "JetBrains Mono", 10, "muted")
  ver:SetPoint("RIGHT", -10, 0)
  ver:SetText(version())
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 3, -3)
  hl:SetPoint("BOTTOMRIGHT", -3, 3)
  hl:SetColorTexture(1, 0.48, 0.1, 0.08)
  b:SetScript("OnClick", function()
    HideUIPanel(menu)
    Entry:Open("LeftButton")
  end)
  b:Hide()
  menu:HookScript("OnShow", function() if Entry.menuEnabled then b:Show() end end)
  menu:HookScript("OnHide", function() b:Hide() end)
  self.menuButton = b
  return b
end

-- Addon Compartment entry (TOC AddonCompartmentFunc) and a minimap button.
-- All three are Phoenix-owned frames; Blizzard frames are only hooked with
-- HookScript (no fields written, no secure functions replaced).
local Entry = { ICON = "Interface\\AddOns\\Phoenix_UI\\Media\\Logo\\PhoenixUI_Icon_64" }
PUI.Entry = Entry

function Entry:Open(button)
  if button == "RightButton" then PUI.OptionsHost:OpenStudio() else PUI.OptionsHost:OpenOptions() end
end

-- Game Menu: our own button anchored above the menu, shown with it.
function Entry:BuildGameMenu()
  local menu = rawget(_G, "GameMenuFrame")
  if self.menuButton or not menu then return self.menuButton end
  local b = CreateFrame("Button", "PhoenixUIGameMenuButton", UIParent, "UIPanelButtonTemplate")
  b:SetSize(180, 26)
  b:SetText("Phoenix UI")
  b:SetFrameStrata("DIALOG")
  b:SetPoint("BOTTOM", menu, "TOP", 0, 6)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("LEFT", 6, 0)
  icon:SetTexture(self.ICON)
  b:SetScript("OnClick", function()
    HideUIPanel(menu)
    Entry:Open("LeftButton")
  end)
  b:Hide()
  menu:HookScript("OnShow", function() if Entry.menuEnabled then b:Show() end end)
  menu:HookScript("OnHide", function() b:Hide() end)
  self.menuButton = b
  return b
end

-- Addon Compartment (named in Phoenix_UI.toc).
_G.PhoenixUI_OnAddonCompartmentClick = function(_, button) Entry:Click(button) end

-- Minimap button: dragged around the minimap edge; the drag follows the cursor
-- through the Ticker, registered only while dragging.
local DRAG_KEY = "entry.minimapDrag"

function Entry:PlaceMinimap()
  local b, map = self.mini, rawget(_G, "Minimap")
  if not (b and map) then return end
  local angle = math.rad(PUI.Schema:Get("general.minimapAngle").angle or 225)
  local r = map:GetWidth() / 2 + 14
  b:ClearAllPoints()
  b:SetPoint("CENTER", map, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function Entry:DragStep()
  local map = rawget(_G, "Minimap")
  local mx, my = map:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = map:GetEffectiveScale()
  local deg = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
  PUI.Schema:Set("general.minimapAngle", { angle = math.floor(deg + 0.5) })
end

-- Status line for the tooltip: Sentinel errors this session.
function Entry:Health()
  local S = PUI.Sentinel
  local list = S and S.Viewer and S.Viewer:List(true)
  local n = list and #list or 0
  return n, n == 0 and "Healthy" or (n .. (n == 1 and " error" or " errors"))
end

local function hintRow(tip, y, keys, what)
  local x = 14
  for _, k in ipairs(keys) do
    local chip = CreateFrame("Frame", nil, tip)
    chip:SetHeight(16)
    local bg = PUI.Theme:Slice(chip, MEDIA.control, 20, "BACKGROUND")
    bg:SetVertexColor(0.16, 0.17, 0.21, 1)
    local t = text(chip, "JetBrains Mono", 9, "text.secondary")
    t:SetPoint("CENTER")
    t:SetText(k)
    chip:SetWidth(#k * 6 + 12)
    chip:SetPoint("TOPLEFT", x, y)
    x = x + chip:GetWidth() + 4
  end
  local t = text(tip, "Inter", 11, "text.secondary")
  t:SetPoint("TOPLEFT", x + 2, y - 2)
  t:SetText(what)
end

-- Phoenix-styled hover card (mockup 13) instead of the GameTooltip.
function Entry:BuildTip()
  if self.tip then return self.tip end
  local tip = CreateFrame("Frame", "PhoenixUIMinimapTip", UIParent)
  tip:SetSize(260, 128)
  tip:SetFrameStrata("TOOLTIP")
  local bg = PUI.Theme:Slice(tip, MEDIA.card, 28, "BACKGROUND")
  bg:SetVertexColor(0.07, 0.075, 0.09, 0.97)
  local edge = PUI.Theme:Slice(tip, MEDIA.border, 28, "BORDER")
  edge:SetVertexColor(1, 1, 1, 0.12)
  local icon = tip:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("TOPLEFT", 14, -12)
  icon:SetTexture(self.ICON)
  local title = text(tip, "Rajdhani Bold", 14)
  title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  title:SetText("PHOENIX  |cffff7a1aUI|r")
  tip.badge = CreateFrame("Frame", nil, tip)
  tip.badge:SetSize(70, 18)
  tip.badge:SetPoint("TOPRIGHT", -12, -12)
  tip.badgeBg = PUI.Theme:Slice(tip.badge, MEDIA.control, 20, "BACKGROUND")
  tip.badgeText = text(tip.badge, "Inter SemiBold", 10, "ok")
  tip.badgeText:SetPoint("CENTER")
  hintRow(tip, -40, { "Left" }, "Open settings")
  hintRow(tip, -60, { "Right" }, "Studio")
  hintRow(tip, -80, { "Shift", "Left" }, "Sentinel")
  tip.foot = text(tip, "Inter", 10, "muted")
  tip.foot:SetPoint("BOTTOMLEFT", 14, 12)
  tip:Hide()
  self.tip = tip
  return tip
end

function Entry:ShowTip(owner)
  local tip = self:BuildTip()
  local n, status = self:Health()
  local token = n == 0 and "ok" or "err"
  tip.badgeText:SetText(status)
  PUI.Theme:Paint(tip.badgeText, token, 1, "text")
  PUI.Theme:Paint(tip.badgeBg, token, 0.16, "vertex")
  tip.badge:SetWidth(math.max(60, (tip.badgeText:GetStringWidth() or 40) + 16))
  tip.foot:SetText("Profile: " .. (PUI.DB:GetProfileName() or "Default") .. "  -  " .. n .. (n == 1 and " error" or " errors"))
  tip:ClearAllPoints()
  tip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -10, 0)
  tip:Show()
end

function Entry:Click(button)
  if button == "LeftButton" and IsShiftKeyDown() then
    local c = PUI.Slash.commands.sentinel
    if c then return c.fn("") end
  end
  self:Open(button)
end

-- Minimap button (mockup 13): 44 px ember ring with a soft glow and the
-- phoenix glyph, dragged around the minimap edge.
function Entry:BuildMinimap()
  local map = rawget(_G, "Minimap")
  if self.mini or not map then return self.mini end
  local b = CreateFrame("Button", "PhoenixUIMinimapButton", map)
  b:SetSize(44, 44)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(map:GetFrameLevel() + 8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local glow = b:CreateTexture(nil, "BACKGROUND")
  glow:SetSize(70, 70)
  glow:SetPoint("CENTER")
  glow:SetTexture(MEDIA.glow)
  PUI.Theme:Paint(glow, "accent", 0.45, "vertex")
  local disc = b:CreateTexture(nil, "BORDER")
  disc:SetSize(38, 38)
  disc:SetPoint("CENTER")
  disc:SetTexture(MEDIA.knob)
  disc:SetVertexColor(0.07, 0.07, 0.09, 1)
  local ring = b:CreateTexture(nil, "ARTWORK")
  ring:SetAllPoints()
  ring:SetTexture(MEDIA.ring)
  PUI.Theme:Paint(ring, "accent", 1, "vertex")
  local glyph = b:CreateTexture(nil, "OVERLAY")
  glyph:SetSize(24, 24)
  glyph:SetPoint("CENTER")
  glyph:SetTexture(MEDIA.glyph)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetSize(56, 56)
  hl:SetPoint("CENTER")
  hl:SetTexture(MEDIA.glow)
  hl:SetBlendMode("ADD")
  PUI.Theme:Paint(hl, "accent", 0.5, "vertex")
  b:SetScript("OnClick", function(_, button) Entry:Click(button) end)
  b:SetScript("OnDragStart", function() if Entry.tip then Entry.tip:Hide() end; PUI.Ticker:Register(DRAG_KEY, 0.02, function() Entry:DragStep() end, "Core") end)
  b:SetScript("OnDragStop", function() PUI.Ticker:Unregister(DRAG_KEY) end)
  b:SetScript("OnEnter", function(self) Entry:ShowTip(self) end)
  b:SetScript("OnLeave", function() if Entry.tip then Entry.tip:Hide() end end)
  self.mini = b
  return b
end

PUI.Schema:Register("general.gameMenuButton", {
  type = "toggle", default = true,
  label = "Game Menu button", tooltip = "Adds a Phoenix UI button above the Escape menu.",
  mode = "advanced", owner = "Options", searchTags = { "menu", "escape", "open" },
  apply = function(value)
    Entry.menuEnabled = value
    if value then Entry:BuildGameMenu() elseif Entry.menuButton then Entry.menuButton:Hide() end
  end,
})

PUI.Schema:Register("general.minimapButton", {
  type = "toggle", default = true,
  label = "Minimap button", tooltip = "Shows the Phoenix UI button on the minimap edge. Left-click opens options, right-click opens Studio, Shift-click opens Sentinel, drag to move.",
  mode = "simple", owner = "Options", searchTags = { "minimap", "icon", "open" },
  apply = function(value)
    if value then
      local b = Entry:BuildMinimap()
      if b then Entry:PlaceMinimap(); b:Show() end
    elseif Entry.mini then
      Entry.mini:Hide()
    end
  end,
})

PUI.Schema:Register("general.minimapAngle", {
  type = "layout", default = { angle = 225 },
  label = "Minimap button position", tooltip = "Angle of the minimap button around the minimap.",
  mode = "advanced", owner = "Options",
  apply = function() Entry:PlaceMinimap() end,
})
