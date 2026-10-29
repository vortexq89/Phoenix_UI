local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local M = ns:GetModule("Bags")

--[[ Process items (EllesmereUI reference: bag quick actions). A small Phoenix window lists every item in your bags
    that a processing spell you know works on: disenchanting, milling, prospecting or picking a lock. Each cell is a
    secure spell button of ours (type "spell" with target-bag / target-slot, SecureTemplates.lua), so one click of
    yours casts the spell on that item. Blizzard's bag buttons are never touched or parented to, so bags open and
    close in combat as always. Cells are made, filled and the window shown or hidden out of combat only; during
    combat a refresh waits for its end. Which items qualify comes from the item's own tooltip lines (the game's
    Millable / Prospectable / Locked strings) and, for disenchanting, uncommon to epic weapons and armour. ]]

local DE, MILL, PROSPECT, PICK = 13262, 51005, 31252, 1804 -- spellIDs(retail): Disenchant, Milling, Prospecting, Pick Lock
M.PROCESS_SPELLS = { DE, MILL, PROSPECT, PICK }
local COLS, CELL, GAP, MAX = 8, 36, 4, 48
local EQUIP = { [Enum.ItemClass.Weapon] = true, [Enum.ItemClass.Armor] = true }

local function known(id)
    local ok, v = pcall(C_SpellBook.IsSpellKnown, id)
    return ok and v == true
end

function M.KnownProcessSpells()
    local out = {}
    for _, id in ipairs(M.PROCESS_SPELLS) do if known(id) then out[id] = true end end
    return out
end

-- Pure: which known spell (if any) processes an item. lines = set of the tooltip's left texts.
function M.ProcessSpellFor(lines, classID, quality, equipLoc, have)
    if type(have) ~= "table" then return nil end
    lines = lines or {}
    if have[PICK] and LOCKED and lines[LOCKED] then return PICK end
    if have[MILL] and ITEM_MILLABLE and lines[ITEM_MILLABLE] then return MILL end
    if have[PROSPECT] and ITEM_PROSPECTABLE and lines[ITEM_PROSPECTABLE] then return PROSPECT end
    if have[DE] and EQUIP[classID] and type(quality) == "number" and quality >= 2 and quality <= 4
        and type(equipLoc) == "string" and equipLoc ~= "" then
        return DE
    end
    return nil
end

local function tooltipLines(bag, slot)
    local set = {}
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if ok and type(data) == "table" and type(data.lines) == "table" then
        for _, line in ipairs(data.lines) do
            if type(line.leftText) == "string" then set[line.leftText] = true end
        end
    end
    return set
end

-- Every processable item: { bag, slot, spell, icon, count }.
function M:ProcessableItems()
    local have, out = M.KnownProcessSpells(), {}
    if not next(have) then return out end
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked then
                local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(info.itemID)
                local spell = M.ProcessSpellFor(tooltipLines(bag, slot), classID, info.quality, equipLoc, have)
                if spell then
                    out[#out + 1] = { bag = bag, slot = slot, spell = spell, icon = info.iconFileID, count = info.stackCount }
                    if #out >= MAX then return out end
                end
            end
        end
    end
    return out
end

local win
local function newCell(i)
    local b = CreateFrame("Button", "PhoenixUI_ProcessCell" .. i, win, "SecureActionButtonTemplate")
    b:SetSize(CELL, CELL)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "spell")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.spellIcon = b:CreateTexture(nil, "OVERLAY")
    b.spellIcon:SetSize(14, 14)
    b.spellIcon:SetPoint("TOPRIGHT", -1, -1)
    b.count = W.Text(b, "small", "text.primary", "RIGHT")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    Skin:Border(b, "border.subtle")
    b:HookScript("OnEnter", function(self)
        Skin:SetBorderColor(self, "accent.primary")
        if not self.bag then return end
        local link = C_Container.GetContainerItemLink(self.bag, self.slot)
        if not link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function(self) Skin:SetBorderColor(self, "border.subtle"); GameTooltip:Hide() end)
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    b:SetPoint("TOPLEFT", 16 + col * (CELL + GAP), -64 - row * (CELL + GAP))
    return b
end

local function build()
    win = W:Popup(L.BAGS_PROCESS, 16 * 2 + COLS * CELL + (COLS - 1) * GAP, 120, "items")
    win.hint = W.Text(win, "small", "text.secondary")
    win.hint:SetPoint("TOPLEFT", 16, -40); win.hint:SetPoint("RIGHT", -16, 0)
    win.empty = W.Text(win, "body", "text.secondary", "CENTER")
    win.empty:SetPoint("TOPLEFT", 16, -70); win.empty:SetPoint("RIGHT", -16, 0)
    win.empty:SetText(L.BAGS_PROCESS_EMPTY)
    win.cells = {}
    win.close.onClick = function() ns.Combat:Run("bags.process.close", function() win:Hide() end) end
    return win
end

local function fill()
    if not (win and win:IsShown()) then return end
    local items = M:ProcessableItems()
    for i = 1, math.max(#items, #win.cells) do
        local it, b = items[i], win.cells[i]
        if it then
            b = b or newCell(i)
            win.cells[i] = b
            b.bag, b.slot = it.bag, it.slot
            b:SetAttribute("spell", it.spell)
            b:SetAttribute("target-bag", it.bag)
            b:SetAttribute("target-slot", it.slot)
            b.icon:SetTexture(it.icon)
            b.spellIcon:SetTexture(C_Spell.GetSpellTexture(it.spell))
            b.count:SetText((it.count or 1) > 1 and it.count or "")
            b:Show()
        elseif b then
            b.bag, b.slot = nil, nil
            b:Hide()
        end
    end
    local rows = math.max(1, math.ceil(#items / COLS))
    win:SetHeight(64 + rows * (CELL + GAP) + 12)
    win.empty:SetShown(#items == 0)
    win.hint:SetText(L.BAGS_PROCESS_HINT:format(#items))
end

function M:RefreshProcess() ns.Combat:Run("bags.process.fill", fill) end

function M:ToggleProcess()
    if InCombatLockdown() then ns:Print(L.BAGS_PROCESS_COMBAT); return end
    if not (ns:Supports("bagProcess") and self:IsEnabled() and self.db.process) then return end
    win = win or build()
    if win:IsShown() then win:Hide(); return end
    win:Show()
    fill()
    return win
end

function M:CanProcess()
    return ns:Supports("bagProcess") and self:IsEnabled() and self.db.process and next(M.KnownProcessSpells()) ~= nil
end

function M:SetupProcess()
    if self.processHooked then return end
    self.processHooked = true
    local owner = {}
    ns.Events:On("BAG_UPDATE_DELAYED", owner, function() if win and win:IsShown() then M:RefreshProcess() end end)
end
