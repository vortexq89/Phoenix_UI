local ADDON, ns = ...
local L = ns.L

--[[ More ways into the settings besides /pui (UI/Launcher.lua already adds the AddOns compartment entry and
    the Options → AddOns landing page):
    * a minimap button (our own, LibDBIcon-style: round, on the minimap edge, drag to move around it,
      left-click opens, right-click opens Movers mode); its angle and visibility live in PhoenixUIDB.launcher
    * a "Phoenix UI" button in the Game Menu (Esc), added through GameMenuFrame:AddButton each time the menu
      builds its buttons
    ]]
local Launcher = ns.Launcher -- UI/Launcher.lua
local owner = {}

local ICON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Textures\\Emblem64"
local RADIUS_PAD = 10 -- button centre sits this far outside the minimap edge
local button, dragTicker

local function store()
    local sv = ns.DB and ns.DB.sv
    if not sv then return { angle = 225, hide = false } end
    if type(sv.launcher) ~= "table" then sv.launcher = { angle = 225, hide = false } end
    return sv.launcher
end

local function open() ns.Config:Toggle() end
local function movers()
    local m = ns.modules.Movers
    if m and m:IsEnabled() then m:SetUnlocked(not m:IsUnlocked()) else ns.Config:Show("Movers") end
end

---------------------------------------------------------------- minimap button
local function place()
    local a = math.rad(store().angle or 225)
    local r = (Minimap:GetWidth() / 2) + RADIUS_PAD
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

-- While dragging: follow the cursor around the minimap edge (a short ticker, stopped on release).
local function follow()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    if not (mx and cx) then return end
    store().angle = math.floor(math.deg(math.atan2(cy / s - my, cx / s - mx)) + 0.5) % 360
    place()
end

local function build()
    button = CreateFrame("Button", "PhoenixUI_MinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetSize(24, 24)
    button.bg:SetPoint("CENTER")
    button.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexture(ICON)
    button.ring = button:CreateTexture(nil, "OVERLAY")
    button.ring:SetSize(54, 54)
    button.ring:SetPoint("TOPLEFT")
    button.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", function(_, b) if b == "RightButton" then movers() else open() end end)
    button:SetScript("OnDragStart", function(self)
        self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
        if dragTicker then dragTicker:Cancel() end
        dragTicker = C_Timer.NewTicker(0.02, follow)
    end)
    button:SetScript("OnDragStop", function(self)
        self.icon:SetTexCoord(0, 1, 0, 1)
        if dragTicker then dragTicker:Cancel(); dragTicker = nil end
        follow()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.LAUNCHER_TITLE)
        GameTooltip:AddLine(L.LAUNCHER_LEFT, 1, 1, 1)
        GameTooltip:AddLine(L.LAUNCHER_RIGHT, 1, 1, 1)
        GameTooltip:AddLine(L.LAUNCHER_DRAG, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function Launcher:IsShown() return not store().hide end

function Launcher:SetShown(on)
    store().hide = not on
    self:Refresh()
end

function Launcher:Refresh()
    if store().hide then
        if button then button:Hide() end
        return
    end
    if not button then build() end
    place()
    button:Show()
end

---------------------------------------------------------------- Game Menu (Esc)
local function addMenuButton(menu)
    if type(menu.AddButton) ~= "function" then return end
    menu:AddButton(L.LAUNCHER_TITLE, function()
        HideUIPanel(GameMenuFrame)
        ns.Config:Show()
    end)
end

local function hookGameMenu()
    local menu = GameMenuFrame
    if type(menu) ~= "table" or type(menu.InitButtons) ~= "function" or Launcher.menuHooked then return end
    Launcher.menuHooked = true
    hooksecurefunc(menu, "InitButtons", addMenuButton)
end

ns.Events:On("PLAYER_LOGIN", owner, function()
    ns.SafeCall(Launcher.Refresh, Launcher)
    ns.SafeCall(hookGameMenu)
end)
