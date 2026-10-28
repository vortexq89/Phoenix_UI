local _, ns = ...
local Skin, W = ns.Skin, ns.Widgets
local M = ns:GetModule("Bags")

--[[ Bag and bank chrome, skins plan window 4 (the slots themselves are dressed in Bags.lua): an accent tick
    under the title, a Phoenix close glyph, the search field as a sunken Phoenix field whose border turns
    accent while you type, a thin divider above the gold footer, and the bank's tab buttons as a side rail
    whose selected tab is outlined in the accent (the warband bank uses the secondary accent). Item icons and
    the tab icons the game shows are never changed. Art is faded with alpha, every new region is ours (weak
    side tables), scripts are only post-hooked, and nothing is moved or resized, so bags stay untainted.
    Colours follow the live accent: everything is painted through Skin:Register. ]]

local chrome = setmetatable({}, { __mode = "k" }) -- [blizzard frame] = our pieces
local SEARCH_ART = { "Left", "Middle", "Right", "Mid" }
local CLOSE_ART = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }

-- Accent token for the bank in view: the warband (account) bank gets the secondary accent.
function M.BankAccent(bankType)
    local account = Enum and Enum.BankType and Enum.BankType.Account
    return (account ~= nil and bankType == account) and "accent.secondary" or "accent.primary"
end

local function closeGlyph(button)
    if not button or chrome[button] then return end
    for _, g in ipairs(CLOSE_ART) do
        local tex = button[g] and button[g](button)
        if tex then Skin:HideRegion(tex) end
    end
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints()
    holder:SetFrameLevel(button:GetFrameLevel() + 1)
    local glyph = W.Icon(holder, "close", 12, "text.secondary")
    glyph:SetPoint("CENTER")
    chrome[button] = holder
    button:HookScript("OnEnter", function() ns.Icons:Tint(glyph, "accent.primary") end)
    button:HookScript("OnLeave", function() ns.Icons:Tint(glyph, "text.secondary") end)
end

function M.SkinSearch(box)
    if not box or chrome[box] then return end
    for _, k in ipairs(SEARCH_ART) do
        local r = box[k]
        if type(r) == "table" and r.SetAlpha then Skin:HideRegion(r) end
    end
    local o = { focus = false }
    chrome[box] = o
    local function paint(self)
        Skin:Panel(self, "sunken", { border = o.focus and "accent.primary" or "border.subtle" })
    end
    box:HookScript("OnEditFocusGained", function(self) o.focus = true; paint(self) end)
    box:HookScript("OnEditFocusLost", function(self) o.focus = false; paint(self) end)
    Skin:Register(box, paint)
end

-- One bag or bank window: title tick, close glyph, footer divider.
function M.DressChrome(frame)
    if not frame or chrome[frame] then return chrome[frame] end
    local c = {}
    chrome[frame] = c
    c.tick = W.Texture(frame, "ARTWORK", 2)
    c.tick:SetHeight(1)
    c.tick:SetPoint("TOPLEFT", 8, -24); c.tick:SetPoint("TOPRIGHT", -8, -24)
    local money = frame.MoneyFrame
    if money then
        c.divider = W.Texture(frame, "ARTWORK", 1)
        c.divider:SetHeight(1)
        c.divider:SetPoint("BOTTOMLEFT", money, "TOPLEFT", -4, 4)
        c.divider:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    end
    closeGlyph(frame.CloseButton)
    Skin:Register(c.tick, function(tex)
        local on = M:IsEnabled() and M.db.skin
        tex:SetShown(on and true or false)
        Skin:Gradient(tex, "HORIZONTAL", "accent.primary", "accent.secondary", 1, 0.15)
        if c.divider then c.divider:SetShown(on and true or false); W.Color(c.divider, "border.subtle") end
    end)
    return c
end

-- Bank tab buttons (side rail): the selected one outlined in the bank's accent.
local rail = setmetatable({}, { __mode = "k" })
function M.PaintBankTabs(panel)
    if not (panel and M:IsEnabled() and M.db.bankSkin) then return end
    local pool = panel.bankTabPool
    if not (pool and pool.EnumerateActive) then return end
    local accent = M.BankAccent(panel.GetActiveBankType and panel:GetActiveBankType())
    for tab in pool:EnumerateActive() do
        local o = rail[tab]
        if not o then
            if type(tab.Border) == "table" and tab.Border.SetAlpha then Skin:HideRegion(tab.Border) end
            o = CreateFrame("Frame", nil, tab)
            o:SetAllPoints()
            Skin:Border(o, "border.subtle")
            rail[tab] = o
        end
        local selected = tab.IsSelected and tab:IsSelected()
        Skin:SetBorderColor(o, selected and accent or "border.subtle")
    end
end

function M:DressAllChrome()
    if not self.db.skin then return end
    for i = 1, NUM_CONTAINER_FRAMES or 0 do
        local f = _G["ContainerFrame" .. i]
        if f then M.DressChrome(f) end
    end
    if _G.ContainerFrameCombinedBags then M.DressChrome(_G.ContainerFrameCombinedBags) end
    M.SkinSearch(_G.BagItemSearchBox)
    if self.db.bankSkin then
        if _G.BankFrame then M.DressChrome(_G.BankFrame) end
        M.SkinSearch(_G.BankItemSearchBox)
    end
end

local chromeHooked
function M:SetupChrome()
    self:DressAllChrome()
    if chromeHooked then return end
    chromeHooked = true
    local panel = _G.BankPanel
    if panel and panel.RefreshBankTabs then
        hooksecurefunc(panel, "RefreshBankTabs", function(p) M.PaintBankTabs(p) end)
    end
    ns.Events:On("BANKFRAME_OPENED", self, function() M:DressAllChrome(); M.PaintBankTabs(_G.BankPanel) end)
    ns.Events:Listen("PUI_THEME_CHANGED", self, function() M.PaintBankTabs(_G.BankPanel) end)
end
