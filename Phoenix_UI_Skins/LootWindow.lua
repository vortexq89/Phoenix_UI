local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix loot window: our own list of what a corpse, chest or fishing bobber holds, fed by the loot API.
    One row per slot: the item's own icon in a frame of its quality colour, its name in that colour, the stack
    count, item level and slot for gear, a quest tag, a "locked" note for slots that are not yours yet. Coin
    first, then (by choice) best quality first. Click loots one slot; Loot all takes every free slot on your
    click; shift-click links, ctrl-click previews. Bind-on-pickup and roll popups stay Blizzard's own.

    Place: by default it sits where Blizzard's loot window would be (your Edit Mode spot, or under the mouse
    when "Open loot window at mouse" is on); "Own place" uses the Phoenix mover instead.
    Safety: Blizzard's LootFrame stays open the whole visit (Escape and its own close still end looting); the
    shared Replacement shell tucks it. It holds no protected child, so the tuck may also run in combat (looting
    mid-fight is common). Skins > "Phoenix loot window" off: Blizzard's loot window (reskinned), live. ]]

local ROWS, ROW_H, WIDTH, ICON = 7, 42, 250, 34
local r

-- One loot slot as plain values (loot data is never secret), or nil for an emptied slot.
function M.LootSlotData(slot)
    if LootSlotHasItem and not LootSlotHasItem(slot) then return nil end
    local texture, name, quantity, currencyID, quality, locked, isQuestItem, questID, isActive, isCoin = GetLootSlotInfo(slot)
    if not texture and not name then return nil end
    if currencyID and CurrencyContainerUtil and CurrencyContainerUtil.GetCurrencyContainerInfo then
        name, texture, quantity, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, quantity, name, texture, quality)
    end
    local d = { slot = slot, texture = texture, name = tostring(name or ""), quantity = tonumber(quantity) or 0,
        quality = tonumber(quality), locked = locked and true or false, coin = isCoin and true or false,
        currency = currencyID ~= nil, quest = questID and not isActive and "start" or ((questID or isQuestItem) and "quest") or nil }
    local link = not d.coin and GetLootSlotLink and GetLootSlotLink(slot) or nil
    d.link = type(link) == "string" and link or nil
    if d.link and C_Item.GetItemInfoInstant then
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(d.link)
        if type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
            d.slotName = _G[equipLoc]
            d.level = tonumber((C_Item.GetDetailedItemLevelInfo(d.link)))
        end
    end
    return d
end

-- Rows in display order: coin first; "quality" = best quality next, then slot order.
function M.LootOrder(list, sort)
    table.sort(list, function(a, b)
        if a.coin ~= b.coin then return a.coin end
        if sort == "quality" and (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
        return a.slot < b.slot
    end)
    return list
end

function M.LootSlots()
    local out = {}
    for slot = 1, (tonumber(GetNumLootItems and GetNumLootItems()) or 0) do
        local d = M.LootSlotData(slot)
        if d then out[#out + 1] = d end
    end
    return M.LootOrder(out, M.db.lootSort)
end

-- Loot all: one LootSlot per free slot, on the player's click. Locked slots (a roll or another player's) are skipped.
function M:LootAll()
    local n = 0
    for _, d in ipairs(M.LootSlots()) do
        if not d.locked then LootSlot(d.slot); n = n + 1 end
    end
    return n
end

local function onClick(d)
    if d.link and IsModifiedClick("CHATLINK") then ChatFrameUtil.InsertLink(d.link); return end
    if d.link and IsModifiedClick("DRESSUP") and DressUpLink then DressUpLink(d.link); return end
    if d.locked then return end
    LootSlot(d.slot)
end

local function onEnter(d, row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if d.currency then GameTooltip:SetLootCurrency(d.slot) elseif not d.coin then GameTooltip:SetLootItem(d.slot) end
    GameTooltip:Show()
end

local function iconBox(b)
    if b.box then return b.box end
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(ICON + 2, ICON + 2)
    b.box:SetPoint("CENTER", b.icon, "CENTER")
    Skin:Border(b.box, "border.subtle")
    Skin:Icon(b.icon)
    b.count = b.box:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    return b.box
end

local function paint(b, d)
    iconBox(b)
    b.icon:SetTexture(d.texture)
    b.icon:SetDesaturated(d.locked)
    b.count:SetText(d.quantity > 1 and not d.coin and d.quantity or "")
    local c = M.QualityBar(d.quality)
    if c then
        Skin:SetBorderColor(b.box, c.r, c.g, c.b, 1)
        b.bar:Show(); b.bar:SetVertexColor(c.r, c.g, c.b, 1)
        b.title:SetTextColor(c.r, c.g, c.b, 1)
    else
        Skin:SetBorderColor(b.box, "border.subtle")
        Skin:Text(b.title, "body", "text.primary")
    end
    b.title:SetText(d.coin and d.name:gsub("\n", " ") or d.name)
    local sub = {}
    if d.level and d.level > 0 then sub[#sub + 1] = L.LOOTW_LEVEL:format(d.level) end
    if d.slotName then sub[#sub + 1] = d.slotName end
    if d.quest == "start" then sub[#sub + 1] = L.LOOTW_QUEST_START elseif d.quest then sub[#sub + 1] = L.LOOTW_QUEST end
    b.sub:SetText(table.concat(sub, "  ·  "))
    b.right:SetText(d.locked and L.LOOTW_LOCKED or "")
    if d.quest then r.list.Mark(b, "accent.primary", 0.16) end
end

local function layout()
    local slots = M.LootSlots()
    r.list.Set(slots, paint)
    local shown = math.max(1, math.min(ROWS, #slots))
    r.win:SetHeight(34 + 20 + shown * ROW_H + 38)
    r.none:SetShown(#slots == 0)
    local free = 0
    for _, d in ipairs(slots) do if not d.locked then free = free + 1 end end
    r.all:SetEnabledState(free > 0)
    r.all:SetText(L.LOOTW_ALL:format(free))
    r.win.title:SetText(IsFishingLoot and IsFishingLoot() and L.LOOTW_FISHING or L.LOOTW_TITLE)
end

local function build(rr)
    r = rr
    r.list = M.ReplaceList(r.body, ROWS, ROW_H, WIDTH, ICON)
    r.list:SetPoint("TOPLEFT", 0, 0)
    r.list.onClick, r.list.onEnter = onClick, onEnter
    r.none = W.Text(r.body, "small", "text.muted")
    r.none:SetPoint("TOPLEFT", 4, -12)
    r.none:SetText(L.LOOTW_EMPTY)
    r.all = W:Button(r.body, "", "primary", "items", WIDTH)
    r.all:SetHeight(26)
    r.all:SetPoint("BOTTOMLEFT", 0, 0)
    r.all.onClick = function() M:LootAll() end
end

local loot
local place, mover, reposition = M.ReplacePlace("lootPlace", "lootPos", "LootFrame", function() return loot end)

loot = M.Replacement({ key = "ownLoot", frame = "LootFrame", title = L.LOOTW_TITLE, strata = "HIGH", combat = true,
    width = WIDTH + 20, height = 34 + 20 + ROWS * ROW_H + 38, build = build, layout = layout, place = place, mover = mover,
    -- Blizzard's window plays a short closing animation after LOOT_CLOSED; its own isOpen flag drops at once.
    isOpen = function(f) return f.isOpen ~= false end,
    -- Edit Mode shows Blizzard's loot window as a placeholder to drag: leave that one alone.
    ready = function()
        local em = _G.EditModeManagerFrame
        return not (em and em.IsEditModeActive and em:IsEditModeActive())
    end,
    close = function() if CloseLoot then CloseLoot() end end })
M.LootReplacement = loot

local listening
function M:SetupLootWindow()
    if listening then loot:Sync(); return end
    listening = true
    ns.Events:On("LOOT_OPENED", loot, function() loot:Opened() end)
    ns.Events:On("LOOT_CLOSED", loot, function() loot:Closed() end)
    ns.Events:On("LOOT_SLOT_CLEARED", loot, function() loot:Soon() end)
    ns.Events:On("LOOT_SLOT_CHANGED", loot, function() loot:Soon() end)
    ns.Events:On("GET_ITEM_INFO_RECEIVED", loot, function() if loot.win and loot.win:IsShown() then loot:Soon() end end)
    loot:Sync()
end
function M:SyncLoot()
    loot:Sync()
    if loot.win and loot.win:IsShown() then reposition() end -- a new place choice applies to the open window
end
M.SETUPS[#M.SETUPS + 1] = "SetupLootWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncLoot"
