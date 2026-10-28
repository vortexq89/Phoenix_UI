local _, ns = ...
local L, Skin, W = ns.L, ns.Skin, ns.Widgets
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
    if not button then return end
    if chrome[button] then
        for _, g in ipairs(CLOSE_ART) do
            local tex = button[g] and button[g](button)
            if tex then Skin:HideRegion(tex) end
        end
        chrome[button]:Show()
        return
    end
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
    if not box then return end
    if chrome[box] then
        for _, k in ipairs(SEARCH_ART) do
            local r = box[k]
            if type(r) == "table" and r.SetAlpha then Skin:HideRegion(r) end
        end
        Skin:Register(box, chrome[box].paint)
        return
    end
    for _, k in ipairs(SEARCH_ART) do
        local r = box[k]
        if type(r) == "table" and r.SetAlpha then Skin:HideRegion(r) end
    end
    local o = { focus = false }
    chrome[box] = o
    local function paint(self)
        if not (M:IsEnabled() and M.db.skin) then return end
        Skin:Panel(self, "sunken", { border = o.focus and "accent.primary" or "border.subtle" })
    end
    o.paint = paint
    box:HookScript("OnEditFocusGained", function(self) o.focus = true; paint(self) end)
    box:HookScript("OnEditFocusLost", function(self) o.focus = false; paint(self) end)
    Skin:Register(box, paint)
end

-- Live switch off: Blizzard's close button and search field art back, our tick and divider hidden.
function M.UndressChrome(frame)
    local c = frame and chrome[frame]
    if not c then return end
    if c.tick then c.tick:Hide() end
    if c.divider then c.divider:Hide() end
    local close = frame.CloseButton
    if close and chrome[close] then
        for _, g in ipairs(CLOSE_ART) do
            local tex = close[g] and close[g](close)
            if tex then Skin:Restore(tex) end
        end
        chrome[close]:Hide()
    end
end

function M.UnskinSearch(box)
    if not (box and chrome[box]) then return end
    for _, k in ipairs(SEARCH_ART) do
        local r = box[k]
        if type(r) == "table" then Skin:Restore(r) end
    end
    Skin:Restore(box)
end

-- One bag or bank window: title tick, close glyph, footer divider.
function M.DressChrome(frame)
    if not frame then return end
    if chrome[frame] then
        local c = chrome[frame]
        closeGlyph(frame.CloseButton)
        c.tick:Show()
        if c.divider then c.divider:Show() end
        return c
    end
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
    if not panel then return end
    local pool = panel.bankTabPool
    if not (pool and pool.EnumerateActive) then return end
    if not (M:IsEnabled() and M.db.bankSkin and M.db.skin) then
        for tab in pool:EnumerateActive() do
            local o = rail[tab]
            if o then o:Hide(); Skin:Restore(tab.Border) end
        end
        return
    end
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
        if type(tab.Border) == "table" and tab.Border.SetAlpha then Skin:HideRegion(tab.Border) end
        o:Show()
        local selected = tab.IsSelected and tab:IsSelected()
        Skin:SetBorderColor(o, selected and accent or "border.subtle")
    end
end

function M:DressAllChrome()
    if self.RefreshChips then self:RefreshChips() end
    local on = self:IsEnabled() and self.db.skin
    local bank = on and self.db.bankSkin
    local frames = {}
    for i = 1, NUM_CONTAINER_FRAMES or 0 do frames[#frames + 1] = _G["ContainerFrame" .. i] end
    frames[#frames + 1] = _G.ContainerFrameCombinedBags
    for _, f in ipairs(frames) do
        if on then M.DressChrome(f) else M.UndressChrome(f) end
    end
    if on then M.SkinSearch(_G.BagItemSearchBox) else M.UnskinSearch(_G.BagItemSearchBox) end
    if _G.BankFrame then
        if bank then M.DressChrome(_G.BankFrame) else M.UndressChrome(_G.BankFrame) end
    end
    if bank then M.SkinSearch(_G.BankItemSearchBox) else M.UnskinSearch(_G.BankItemSearchBox) end
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
    -- theme changes reach the bank tabs through Bags:Refresh (one PUI_THEME_CHANGED listener per owner)
end

---------------------------------------------------------------- category chips (plan window 4)
--[[ A row of chips above the combined bag: All, New, Equipment, Consumables, Reagents, Quest, Junk. Picking one
    dims every slot that is not in that category with a dark layer of ours over the slot (the item buttons are
    never hidden, moved or changed, so using and dragging items works as always). The same categories as the
    Phoenix bag window (M:Categorize). The chips hide with the bag skin switch, live. ]]
M.CHIPS = { "all", "new", "equipment", "consumables", "reagents", "quest", "junk" }
M.activeChip = "all"
local dims = setmetatable({}, { __mode = "k" })
local chipRow

-- Should a slot of category `cat` be dimmed while `chip` is picked?
function M.ChipDims(chip, cat)
    if not chip or chip == "all" then return false end
    return cat ~= chip
end

function M.DimSlot(button, bag, slot)
    if not button then return end
    local dim = dims[button]
    local on = M:IsEnabled() and M.db.skin and M.activeChip ~= "all"
    if not on then if dim then dim:Hide() end; return end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local quest = C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
    local s = M.SlotInfo(ItemLocation:CreateFromBagAndSlot(bag, slot))
    local cat = M:Categorize(bag, info, quest, s)
    if not dim then
        local holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints()
        holder:SetFrameLevel(button:GetFrameLevel() + 4)
        dim = holder:CreateTexture(nil, "OVERLAY", nil, 7)
        dim:SetTexture(ns.Media.textures.WHITE)
        dim:SetAllPoints()
        dims[button] = dim
    end
    W.Color(dim, "bg.base", 0.72)
    dim:SetShown(M.ChipDims(M.activeChip, cat))
end

local function paintChips()
    if not chipRow then return end
    for _, c in ipairs(chipRow.chips) do
        local sel = c.key == M.activeChip
        Skin:Panel(c, sel and "raised" or "sunken", { border = sel and "accent.primary" or "border.subtle" })
        Skin:Text(c.label, "small", sel and "accent.text" or "text.secondary")
    end
end
M.PaintChips = paintChips

function M:RefreshChips()
    local bag = _G.ContainerFrameCombinedBags
    local on = self:IsEnabled() and self.db.skin
    if not on then
        if chipRow then chipRow:Hide() end
        if self.activeChip ~= "all" then self.activeChip = "all" end
        for _, dim in pairs(dims) do dim:Hide() end
        return
    end
    if not bag then return end
    if not chipRow then
        chipRow = CreateFrame("Frame", nil, bag)
        chipRow:SetHeight(18)
        chipRow:SetPoint("BOTTOMLEFT", bag, "TOPLEFT", 6, 2)
        chipRow:SetPoint("BOTTOMRIGHT", bag, "TOPRIGHT", -6, 2)
        chipRow.chips = {}
        local prev
        for _, key in ipairs(self.CHIPS) do
            local c = CreateFrame("Button", nil, chipRow)
            c.key = key
            c.label = W.Text(c, "small", "text.secondary", "CENTER")
            c.label:SetPoint("CENTER")
            c.label:SetText(L["BAGS_CAT_" .. key:upper()])
            c:SetSize(math.max(34, (c.label:GetStringWidth() or 30) + 12), 18)
            if prev then c:SetPoint("LEFT", prev, "RIGHT", 3, 0) else c:SetPoint("LEFT") end
            c:SetScript("OnClick", function(self)
                M.activeChip = (M.activeChip == self.key) and "all" or self.key
                paintChips()
                M:Refresh()
            end)
            chipRow.chips[#chipRow.chips + 1] = c
            prev = c
        end
    end
    chipRow:Show()
    paintChips()
end
