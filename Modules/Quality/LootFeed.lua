local _, ns = ...
local L, Secret = ns.L, ns.Secret
local M = ns.modules.Quality

--[[ Loot feed (EllesmereUI Forever Essentials reference; both clients). A short-lived stack of Phoenix item
    cards for what you gain: looted, received and crafted items (the item's real icon in its quality frame,
    count, item level and slot for gear, how many you now carry), money and currencies. The same thing again
    within the time adds to its card. Items come from your own CHAT_MSG_LOOT lines, matched against the
    client's localized LOOT_ITEM_*_SELF formats, so every language works; a line that is secret (Midnight
    restrictions in an instance fight) is skipped, never read. Money is the rise of GetMoney() outside a
    vendor, mailbox, trade or auction house; currencies come from CURRENCY_DISPLAY_UPDATE's own change.
    Cards are the shared replacement-window card (Skins); the stack is movable in Layout mode. ]]

local OWNER = {}
local ROW_H, GAP = 40, 4
local FADE = 1            -- the last second of a card fades out
local feed, ticker
local cards = {}          -- shown entries, newest first: { key, texture, name, count, quality, sub, at }
local money, busy = nil, 0

---------------------------------------------------------------- parsing (pure)
-- A client format ("You receive loot: %sx%d.") as an anchored Lua pattern capturing the link and count.
function M.LootPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    -- placeholders (also positional ones, "%1$s") become markers first, then the rest is escaped
    local p = fmt:gsub("%%%d*%$?s", "\001"):gsub("%%%d*%$?d", "\002")
    p = p:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    p = p:gsub("\001", "(.+)"):gsub("\002", "(%%d+)")
    return "^" .. p .. "$"
end

local patterns
local function lootPatterns()
    if patterns then return patterns end
    local out = {}
    -- multiple-count formats first: the single one would also match "…x3"
    for _, name in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF_MULTIPLE",
        "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF" }) do
        local p = M.LootPattern(_G[name])
        if p then out[#out + 1] = p end
    end
    if #out > 0 then patterns = out end
    return out
end

-- The item link and count in one of your loot lines, or nil (someone else's loot, a roll, anything else).
function M.LootParse(msg, list)
    if type(msg) ~= "string" then return nil end
    for _, p in ipairs(list or lootPatterns()) do
        local link, count = msg:match(p)
        if link then return link, tonumber(count) or 1 end
    end
    return nil
end

-- Add a gain to the feed: an entry with the same key within the time adds its count and starts its time again.
function M.LootFeedAdd(list, e, now, maxRows)
    for i, c in ipairs(list) do
        if c.key == e.key then
            c.count = (c.count or 0) + (e.count or 0)
            c.at, c.sub = now, e.sub or c.sub
            if e.amount then c.amount = (c.amount or 0) + e.amount end
            table.remove(list, i)
            table.insert(list, 1, c)
            return c
        end
    end
    e.at = now
    table.insert(list, 1, e)
    while #list > maxRows do table.remove(list) end
    return e
end

---------------------------------------------------------------- entries
local function itemEntry(link, count)
    local name, _, quality, _, _, _, _, _, equipLoc, texture = C_Item.GetItemInfo(link)
    if not texture then texture = select(5, C_Item.GetItemInfoInstant(link)) end
    local id = tonumber(link:match("item:(%d+)"))
    if not id and not texture then return nil end
    if (tonumber(quality) or 1) < (M.db.feed.minQuality or 0) then return nil end
    local sub = {}
    if type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" and _G[equipLoc] then
        local level = tonumber((C_Item.GetDetailedItemLevelInfo(link)))
        if level and level > 0 then sub[#sub + 1] = L.LOOTW_LEVEL:format(level) end
        sub[#sub + 1] = _G[equipLoc]
    end
    local have = id and tonumber((C_Item.GetItemCount(id)))
    if have and have > 0 then sub[#sub + 1] = L.QUALITY_FEED_HAVE:format(have) end
    return { key = "i" .. (id or link), texture = texture, name = name or link:match("%[(.-)%]") or link, count = count,
        quality = quality, sub = table.concat(sub, "  ·  "), link = link }
end

local function moneyEntry(amount)
    return { key = "money", texture = C_CurrencyInfo.GetCoinIcon(amount), amount = amount, count = 0, quality = nil }
end

local function currencyEntry(id, change)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not (info and info.name) then return nil end
    return { key = "c" .. id, texture = info.iconFileID, name = info.name, count = change, quality = info.quality,
        sub = L.QUALITY_FEED_HAVE:format(tonumber(info.quantity) or 0), currencyID = id }
end

---------------------------------------------------------------- the stack
local function onEnter(card)
    local e = card.entry
    if not e then return end
    GameTooltip:SetOwner(card, "ANCHOR_LEFT")
    if e.link then GameTooltip:SetHyperlink(e.link)
    elseif e.currencyID and GameTooltip.SetCurrencyByID then GameTooltip:SetCurrencyByID(e.currencyID)
    else GameTooltip:SetText(e.name or "") end
    GameTooltip:Show()
end

local function card(i)
    local c = ns.Widgets.ItemCard(feed, M.db.feed.width, ROW_H)
    c:SetScript("OnEnter", onEnter)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c:SetScript("OnClick", function(self)
        local e = self.entry
        if e and e.link and IsModifiedClick("CHATLINK") then ChatFrameUtil.InsertLink(e.link) end
    end)
    feed.cards[i] = c
    return c
end

local function build()
    feed = CreateFrame("Frame", "PhoenixUI_LootFeed", UIParent)
    feed:SetFrameStrata("MEDIUM")
    feed:SetClampedToScreen(true)
    feed.cards = {}
    local movers = ns:GetModule("Movers")
    if movers then
        movers:Register("quality.lootFeed", feed, L.QUALITY_FEED, {
            active = function() return M:IsEnabled() and M.db.feed.enabled end,
            get = function() local f = M.db.feed; return { point = f.point, x = f.x, y = f.y } end,
            set = function(v) local f = M.db.feed; f.point, f.x, f.y = v.point or f.point, v.x or f.x, v.y or f.y end,
            apply = function() M:ApplyLootFeed() end,
            preview = function() M:ApplyLootFeed() end,
            reset = function()
                local d, f = M.defaults.feed, M.db.feed
                f.point, f.x, f.y = d.point, d.x, d.y
                M:ApplyLootFeed()
            end,
        })
    end
end

-- What Layout mode and the settings preview show: your last real gains, or a money card (the game's coin icon).
local recent = {}
local function sample()
    if #recent > 0 then return recent end
    return { moneyEntry(123456) }
end
function M:LootFeedSample() return sample() end

function M.LootFeedPaint(c, e, alpha)
    local d = { texture = e.texture, count = e.count, quality = e.quality, sub = e.sub,
        name = e.key == "money" and C_CurrencyInfo.GetCoinTextureString(e.amount or 0) or e.name }
    ns.Widgets.PaintItemCard(c, d)
    c.entry = e
    c:SetAlpha(alpha)
end

function M:ApplyLootFeed()
    local d = self.db.feed
    local movers = ns:GetModule("Movers")
    local unlocked = movers and movers:IsUnlocked()
    local on = self:IsEnabled() and d.enabled
    if not on then
        if feed then feed:Hide() end
        if ticker then ticker:Cancel(); ticker = nil end
        return
    end
    if not feed then build() end
    local list = (#cards == 0 and unlocked) and sample() or cards
    local now = GetTime()
    local up = d.grow ~= "down"
    feed:SetSize(d.width, ROW_H)
    feed:ClearAllPoints()
    feed:SetPoint(d.point, UIParent, d.point, d.x, d.y)
    for i = 1, math.max(#feed.cards, #list) do
        local c = feed.cards[i] or (list[i] and card(i))
        if c then
            local e = list[i]
            if e then
                c:SetWidth(d.width)
                c:ClearAllPoints()
                local off = (i - 1) * (ROW_H + GAP)
                if up then c:SetPoint("BOTTOMLEFT", feed, "BOTTOMLEFT", 0, off)
                else c:SetPoint("TOPLEFT", feed, "TOPLEFT", 0, -off) end
                local left = (e.at and d.duration - (now - e.at)) or d.duration
                M.LootFeedPaint(c, e, list == cards and math.max(0, math.min(1, left / FADE)) or 1)
            else
                c:Hide(); c.entry = nil
            end
        end
    end
    feed:Show()
    if #cards > 0 and not ticker then
        ticker = C_Timer.NewTicker(0.2, function() ns.SafeCall(M.LootFeedTick, M) end)
    end
end

-- Drop cards past their time; the stack closes up. The ticker only runs while cards are shown.
function M:LootFeedTick()
    local now, dur = GetTime(), self.db.feed.duration
    for i = #cards, 1, -1 do
        if now - cards[i].at >= dur then table.remove(cards, i) end
    end
    if #cards == 0 and ticker then ticker:Cancel(); ticker = nil end
    self:ApplyLootFeed()
end

function M:LootFeedPush(e)
    if not (e and self:IsEnabled() and self.db.feed.enabled) then return end
    M.LootFeedAdd(cards, e, GetTime(), self.db.feed.rows)
    wipe(recent)
    for i = 1, math.min(3, #cards) do recent[i] = cards[i] end
    self:ApplyLootFeed()
end
function M:LootFeedCards() return cards end
function M:LootFeedClear() wipe(cards); self:ApplyLootFeed() end

---------------------------------------------------------------- sources
function M.LootFeedChat(msg)
    local f = M.db.feed
    if not (M:IsEnabled() and f.enabled and f.items) or Secret.IsSecret(msg) then return end
    local link, count = M.LootParse(msg)
    if link then M:LootFeedPush(itemEntry(link, count)) end
end

function M.LootFeedMoney()
    local now = GetMoney()
    local before = money
    money = now
    local f = M.db.feed
    if not (before and f.enabled and f.money and M:IsEnabled()) or busy > 0 then return end
    if now > before then M:LootFeedPush(moneyEntry(now - before)) end
end

function M.LootFeedCurrency(id, change)
    local f = M.db.feed
    if not (M:IsEnabled() and f.enabled and f.currency) then return end
    if type(id) ~= "number" or type(change) ~= "number" or Secret.IsSecret(change) or change <= 0 then return end
    M:LootFeedPush(currencyEntry(id, change))
end

function M:SetupLootFeed()
    if self.feedHooked then return end
    self.feedHooked = true
    money = GetMoney()
    ns.Events:On("CHAT_MSG_LOOT", OWNER, function(_, _, msg) ns.SafeCall(M.LootFeedChat, msg) end)
    ns.Events:On("PLAYER_MONEY", OWNER, function() ns.SafeCall(M.LootFeedMoney) end)
    ns.Events:On("CURRENCY_DISPLAY_UPDATE", OWNER, function(_, _, id, _, change) ns.SafeCall(M.LootFeedCurrency, id, change) end)
    -- money that changes hands at a vendor, mailbox, trade or auction house is not loot
    for open, close in pairs({ MERCHANT_SHOW = "MERCHANT_CLOSED", MAIL_SHOW = "MAIL_CLOSED", TRADE_SHOW = "TRADE_CLOSED",
        AUCTION_HOUSE_SHOW = "AUCTION_HOUSE_CLOSED" }) do
        local shown = false
        ns.Events:On(open, OWNER, function() if not shown then shown = true; busy = busy + 1 end end)
        ns.Events:On(close, OWNER, function()
            if shown then shown = false; busy = math.max(0, busy - 1) end
            money = GetMoney()
        end)
    end
end
