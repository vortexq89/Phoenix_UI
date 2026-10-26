local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Entry points besides /pui: a "Phoenix UI" button on the Game Menu, the
-- Addon Compartment entry (TOC AddonCompartmentFunc) and a minimap button.
-- All three are Phoenix-owned frames; Blizzard frames are only hooked with
-- HookScript (no fields written, no secure functions replaced).
local Entry = { ICON = "Interface\\AddOns\\Phoenix_UI\\Media\\PhoenixIcon" }
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
_G.PhoenixUI_OnAddonCompartmentClick = function(_, button) Entry:Open(button) end

-- Minimap button: dragged around the minimap edge; the drag follows the cursor
-- through the Ticker, registered only while dragging.
local DRAG_KEY = "entry.minimapDrag"

function Entry:PlaceMinimap()
  local b, map = self.mini, rawget(_G, "Minimap")
  if not (b and map) then return end
  local angle = math.rad(PUI.Schema:Get("general.minimapAngle").angle or 225)
  local r = map:GetWidth() / 2 + 8
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

function Entry:BuildMinimap()
  local map = rawget(_G, "Minimap")
  if self.mini or not map then return self.mini end
  local b = CreateFrame("Button", "PhoenixUIMinimapButton", map)
  b:SetSize(28, 28)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(map:GetFrameLevel() + 8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(self.ICON)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture(self.ICON)
  hl:SetBlendMode("ADD")
  hl:SetAlpha(0.35)
  b:SetScript("OnClick", function(_, button) Entry:Open(button) end)
  b:SetScript("OnDragStart", function() PUI.Ticker:Register(DRAG_KEY, 0.02, function() Entry:DragStep() end, "Core") end)
  b:SetScript("OnDragStop", function() PUI.Ticker:Unregister(DRAG_KEY) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Phoenix UI")
    GameTooltip:AddLine("Left-click: options   Right-click: Studio   Drag: move", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
  label = "Minimap button", tooltip = "Shows the Phoenix UI button on the minimap edge. Left-click opens options, right-click opens Studio, drag to move.",
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
