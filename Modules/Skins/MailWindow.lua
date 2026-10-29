local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix mail window: our own inbox and send form fed by the mail API, in the Phoenix look. Inbox: one
    row per letter (sender, subject, gold / COD / attachment count, days left) and a reading pane with the
    letter, its attachments (the items' own icons), Take gold, Reply, Return and Delete, plus Open all.
    Send: To, Subject, the letter, gold and twelve attachment slots (drop an item on a slot, or right-click it
    in your bags while the Send tab is open), postage, Send. Skins > "Phoenix mail window" off brings back
    Blizzard's mailbox (reskinned), live; the arrow button opens Blizzard's mailbox for this visit only.

    Safety: Blizzard's MailFrame stays open the whole visit (Escape, bag right-clicks and every "is the mail
    open" check behave as usual); Skin:Tuck only makes it see-through and parks its child frames. Every
    action is the game's own mail call on your click; a COD letter asks for a second click that names the
    price before anything is paid. Open all takes one thing per step and stops when your bags are full. ]]

local ROWS, ROW_H, W_LIST, W_READ, HEAD, PAD = 8, 40, 270, 330, 34, 10
local win, selected, offset, codArmed, tab = nil, nil, 0, nil, "inbox"
local visitBlizzard, openingAll

local function on() return M:IsEnabled() and M.db.ownMail and true or false end
M.MailWindowOn = on

local function count() return GetInboxNumItems and tonumber((GetInboxNumItems())) or 0 end

-- One letter as plain values (no secret values in the mail API).
function M.MailHeader(i)
    if not GetInboxHeaderInfo then return nil end
    local _, _, sender, subject, money, cod, days, items, wasRead = GetInboxHeaderInfo(i)
    if subject == nil and sender == nil then return nil end
    return { sender = tostring(sender or UNKNOWN or "?"), subject = tostring(subject or ""), money = tonumber(money) or 0,
        cod = tonumber(cod) or 0, days = tonumber(days) or 0, items = tonumber(items) or 0, read = wasRead == true }
end

-- The next thing Open all should take: { index, kind = "money" | "item", slot } or nil. COD letters are skipped.
function M.MailNextTake(n, header, item)
    for i = 1, n do
        local h = header(i)
        if h and h.cod == 0 then
            if h.money > 0 then return { index = i, kind = "money" } end
            if h.items > 0 then
                for a = 1, (tonumber(ATTACHMENTS_MAX_RECEIVE) or 16) do
                    if item(i, a) then return { index = i, kind = "item", slot = a } end
                end
            end
        end
    end
    return nil
end

local function itemAt(i, a) return GetInboxItem and GetInboxItem(i, a) ~= nil end

local function bagsFull()
    local free = 0
    for bag = 0, (tonumber(NUM_BAG_SLOTS) or 4) do free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0) end
    return free == 0
end

local function money(v)
    local s = C_CurrencyInfo.GetCoinTextureString(tonumber(v) or 0)
    return type(s) == "string" and s or tostring(tonumber(v) or 0)
end

---------------------------------------------------------------- inbox
local function paintRow(r, h, index)
    r.index = index
    r.sender:SetText(h.sender)
    r.subject:SetText(h.subject)
    local bits = {}
    if h.cod > 0 then bits[#bits + 1] = L.MAILW_COD:format(money(h.cod))
    elseif h.money > 0 then bits[#bits + 1] = money(h.money) end
    if h.items > 0 then bits[#bits + 1] = L.MAILW_ITEMS:format(h.items) end
    bits[#bits + 1] = L.MAILW_DAYS:format(math.floor(h.days))
    r.info:SetText(table.concat(bits, "  "))
    local sel = index == selected
    r.bg:SetVertexColor(ns.Theme:Color(sel and "accent.primary" or "bg.raised"))
    r.bg:SetAlpha(sel and 0.25 or (h.read and 0.35 or 0.7))
    r.bar:SetShown(h.cod > 0 or sel)
    W.Color(r.bar, h.cod > 0 and "state.danger" or "accent.primary", 1)
    Skin:Text(r.sender, "body", h.read and "text.secondary" or "text.primary", 12)
    r:Show()
end

local function attachmentButton(i)
    local b = win.attach[i]
    if b then return b end
    b = CreateFrame("Button", nil, win.read)
    b:SetSize(32, 32)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    Skin:Border(b, "border.subtle")
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInboxItem(selected, self.slot)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self) M:MailTake(selected, self.slot) end)
    win.attach[i] = b
    return b
end

-- Takes one attachment (slot) or the gold (slot nil). COD needs a second click on the same thing.
function M:MailTake(index, slot)
    local h = index and M.MailHeader(index)
    if not h then return end
    if h.cod > 0 and slot then
        local key = index .. ":" .. slot
        if codArmed ~= key then codArmed = key; self:LayoutMail(); return end
    end
    codArmed = nil
    if slot then TakeInboxItem(index, slot) else TakeInboxMoney(index) end
end

local function layoutRead()
    local r = win.read
    local h = selected and M.MailHeader(selected)
    r.none:SetShown(not h)
    for _, el in ipairs({ r.from, r.subject, r.body, r.take, r.reply, r.ret, r.del, r.cod }) do el:SetShown(h ~= nil) end
    for _, b in ipairs(win.attach) do b:Hide() end
    if not h then return end
    r.from:SetText(L.MAILW_FROM:format(h.sender))
    r.subject:SetText(h.subject)
    local text = GetInboxText and GetInboxText(selected)
    r.body:SetText(type(text) == "string" and text or "")
    local n = 0
    for a = 1, (tonumber(ATTACHMENTS_MAX_RECEIVE) or 16) do
        local name, _, texture, stack = GetInboxItem(selected, a)
        if name or texture then
            n = n + 1
            local b = attachmentButton(n)
            b.slot = a
            b.icon:SetTexture(texture)
            b.count:SetText((tonumber(stack) or 0) > 1 and stack or "")
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", r.body, "BOTTOMLEFT", ((n - 1) % 8) * 36, -8 - math.floor((n - 1) / 8) * 36)
            Skin:SetBorderColor(b, codArmed == selected .. ":" .. a and "state.danger" or "border.subtle")
            b:Show()
        end
    end
    r.cod:SetShown(h.cod > 0)
    r.cod:SetText(codArmed and L.MAILW_COD_CONFIRM:format(money(h.cod)) or L.MAILW_COD:format(money(h.cod)))
    r.take:SetShown(h.money > 0)
    r.take:SetText(L.MAILW_TAKE:format(money(h.money)))
    r.del:SetShown(not InboxItemCanDelete or InboxItemCanDelete(selected))
end

function M:LayoutMail()
    if not (win and win:IsShown()) then return end
    win.inbox:SetShown(tab == "inbox")
    win.send:SetShown(tab == "send")
    for key, t in pairs(win.tabBtns) do
        t.variant = key == tab and "primary" or "secondary"
        local idle = t:GetScript("OnLeave")
        if idle then idle(t) end
    end
    if tab == "send" then self:LayoutSend(); return end
    local n = count()
    if selected and selected > n then selected = nil end
    offset = math.max(0, math.min(offset, n - ROWS))
    for i = 1, ROWS do
        local index = offset + i
        local h = index <= n and M.MailHeader(index)
        if h then paintRow(win.rows[i], h, index) else win.rows[i]:Hide() end
    end
    win.empty:SetShown(n == 0)
    layoutRead()
end

---------------------------------------------------------------- send
local function sendSlot(i)
    local b = CreateFrame("Button", nil, win.send)
    b:SetSize(34, 34)
    b.slot = i
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    local function click(self, button) ClickSendMailItemButton(self.slot, button == "RightButton") end
    b:SetScript("OnClick", click)
    b:SetScript("OnReceiveDrag", function(self) ClickSendMailItemButton(self.slot) end)
    b:SetScript("OnDragStart", function(self) ClickSendMailItemButton(self.slot) end)
    b:SetScript("OnEnter", function(self)
        if not GetSendMailItem(self.slot) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSendMailItem(self.slot)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Skin:Panel(b, "sunken", { border = "border.subtle" })
    return b
end

function M.MailCopper(g, s, c)
    return math.max(0, math.floor(tonumber(g) or 0)) * 10000 + math.max(0, math.floor(tonumber(s) or 0)) * 100
        + math.max(0, math.floor(tonumber(c) or 0))
end

function M:LayoutSend()
    local s = win.send
    for i, b in ipairs(s.slots) do
        local name, _, texture, stack = GetSendMailItem(i)
        b.icon:SetTexture(texture)
        b.icon:SetShown(name ~= nil or texture ~= nil)
        b.count:SetText((tonumber(stack) or 0) > 1 and stack or "")
    end
    s.postage:SetText(L.MAILW_POSTAGE:format(money(GetSendMailPrice and GetSendMailPrice() or 0)))
end

function M:MailSend()
    local s = win.send
    local to = s.to:GetText() or ""
    if to == "" then s.to:SetFocus(); return end
    local subject = s.subject:GetText() or ""
    if subject == "" then
        local name = GetSendMailItem(1)
        subject = name or ""
    end
    SetSendMailMoney(M.MailCopper(s.gold:GetText(), 0, 0))
    SendMail(to, subject, s.body.edit:GetText() or "")
end

local function clearSend()
    if not win then return end
    local s = win.send
    for _, e in ipairs({ s.to, s.subject, s.gold }) do e:SetValue("") end
    s.body.edit:SetText("")
end

local function syncBlizzardTab()
    -- Blizzard's own tab state, so right-clicking an item in the bags attaches it while our Send tab is open.
    if type(MailFrameTab_OnClick) == "function" then MailFrameTab_OnClick(nil, tab == "send" and 2 or 1) end
end

---------------------------------------------------------------- frame
local function label(parent, text)
    local fs = W.Text(parent, "small", "text.muted")
    fs:SetText(text)
    return fs
end

local function build()
    win = CreateFrame("Frame", "PhoenixUI_Mail", UIParent)
    win:SetSize(W_LIST + W_READ + 3 * PAD, HEAD + ROWS * ROW_H + 2 * PAD + 40)
    win:SetFrameStrata("MEDIUM")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -110)
    win:Hide()
    win.title = W.Text(win, "heading", "accent.primary")
    win.title:SetPoint("TOPLEFT", PAD, -PAD - 2)
    win.title:SetText(L.MAILW_TITLE)
    win.tabBtns = {}
    local prev
    for _, key in ipairs({ "inbox", "send" }) do
        local b = W:Button(win, key == "inbox" and L.MAILW_INBOX or L.MAILW_SEND, "secondary", nil, 90)
        b:SetHeight(22)
        b:SetPoint("LEFT", prev or win.title, "RIGHT", prev and 6 or 16, 0)
        b.onClick = function() tab = key; syncBlizzardTab(); M:LayoutMail() end
        win.tabBtns[key], prev = b, b
    end
    win.close = W:IconButton(win, "close", 22, CLOSE)
    win.close:SetPoint("TOPRIGHT", -PAD + 4, -PAD + 4)
    win.close.onClick = function() if CloseMail then CloseMail() end end
    win.blizz = W:IconButton(win, "link", 22, L.MAILW_BLIZZARD)
    win.blizz:SetPoint("RIGHT", win.close, "LEFT", -4, 0)
    win.blizz.onClick = function() visitBlizzard = true; M:SyncMail() end

    -- inbox: list + reading pane
    local inbox = CreateFrame("Frame", nil, win)
    inbox:SetPoint("TOPLEFT", PAD, -PAD - HEAD)
    inbox:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    win.inbox = inbox
    win.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, inbox)
        r:SetSize(W_LIST, ROW_H - 2)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r.bg = W.Texture(r, "BACKGROUND", 0); r.bg:SetAllPoints()
        r.bar = W.Texture(r, "ARTWORK", 1); r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(2)
        r.sender = W.Text(r, "body", "text.primary"); r.sender:SetPoint("TOPLEFT", 8, -5)
        r.sender:SetPoint("RIGHT", -8, 0); r.sender:SetJustifyH("LEFT")
        r.subject = W.Text(r, "small", "text.secondary"); r.subject:SetPoint("BOTTOMLEFT", 8, 5)
        r.subject:SetPoint("RIGHT", -90, 0); r.subject:SetJustifyH("LEFT")
        r.info = W.Text(r, "small", "text.muted"); r.info:SetPoint("BOTTOMRIGHT", -8, 5)
        r:SetScript("OnClick", function(self) selected, codArmed = self.index, nil; M:LayoutMail() end)
        r:Hide()
        win.rows[i] = r
    end
    inbox:EnableMouseWheel(true)
    inbox:SetScript("OnMouseWheel", function(_, d) offset = offset - d; M:LayoutMail() end)
    win.empty = W.Text(inbox, "body", "text.muted")
    win.empty:SetPoint("TOPLEFT", 8, -8)
    win.empty:SetText(L.MAILW_EMPTY)
    win.openAll = W:Button(inbox, L.MAILW_OPEN_ALL, "primary", "mail", W_LIST)
    win.openAll:SetPoint("BOTTOMLEFT", 0, 0)
    win.openAll.onClick = function() M:MailOpenAll() end

    local read = CreateFrame("Frame", nil, inbox)
    read:SetPoint("TOPLEFT", W_LIST + PAD, 0)
    read:SetPoint("BOTTOMRIGHT")
    win.read, win.attach = read, {}
    read.none = W.Text(read, "body", "text.muted"); read.none:SetPoint("CENTER"); read.none:SetText(L.MAILW_PICK)
    read.from = W.Text(read, "small", "text.muted"); read.from:SetPoint("TOPLEFT", 10, -10)
    read.subject = W.Text(read, "heading", "text.primary"); read.subject:SetPoint("TOPLEFT", read.from, "BOTTOMLEFT", 0, -4)
    read.subject:SetPoint("RIGHT", -10, 0); read.subject:SetJustifyH("LEFT")
    read.body = W.Text(read, "body", "text.secondary"); read.body:SetPoint("TOPLEFT", read.subject, "BOTTOMLEFT", 0, -10)
    read.body:SetPoint("RIGHT", -10, 0); read.body:SetJustifyH("LEFT"); read.body:SetJustifyV("TOP")
    read.body:SetHeight(120)
    read.cod = W.Text(read, "small", "state.danger"); read.cod:SetPoint("BOTTOMLEFT", 10, 40)
    read.take = W:Button(read, "", "primary", "gold", 150); read.take:SetPoint("BOTTOMLEFT", 10, 8)
    read.take.onClick = function() M:MailTake(selected, nil) end
    read.reply = W:Button(read, L.MAILW_REPLY, "secondary", nil, 70); read.reply:SetPoint("LEFT", read.take, "RIGHT", 6, 0)
    read.reply.onClick = function()
        local h = selected and M.MailHeader(selected)
        if not h then return end
        tab = "send"; syncBlizzardTab(); M:LayoutMail()
        win.send.to:SetValue(h.sender); win.send.subject:SetValue("RE: " .. h.subject)
    end
    read.ret = W:IconButton(read, "reset", 24, L.MAILW_RETURN); read.ret:SetPoint("BOTTOMRIGHT", -40, 10)
    read.ret.onClick = function() if selected then ReturnInboxItem(selected); selected = nil end end
    read.del = W:IconButton(read, "delete", 24, L.MAILW_DELETE); read.del:SetPoint("BOTTOMRIGHT", -10, 10)
    read.del.onClick = function() if selected then DeleteInboxItem(selected); selected = nil end end

    -- send form
    local send = CreateFrame("Frame", nil, win)
    send:SetPoint("TOPLEFT", PAD, -PAD - HEAD)
    send:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    send:Hide()
    win.send = send
    local toL = label(send, L.MAILW_TO); toL:SetPoint("TOPLEFT", 0, -4)
    send.to = W:Input(send, 220); send.to:SetPoint("TOPLEFT", 0, -20)
    local subL = label(send, L.MAILW_SUBJECT); subL:SetPoint("TOPLEFT", 236, -4)
    send.subject = W:Input(send, 360); send.subject:SetPoint("TOPLEFT", 236, -20)
    send.body = W:TextArea(send, W_LIST + W_READ - 0, 150); send.body:SetPoint("TOPLEFT", 0, -56)
    send.slots = {}
    for i = 1, (tonumber(ATTACHMENTS_MAX_SEND) or 12) do
        local b = sendSlot(i)
        b:SetPoint("TOPLEFT", ((i - 1) % 12) * 38, -216 - math.floor((i - 1) / 12) * 38)
        send.slots[i] = b
    end
    local gL = label(send, L.MAILW_GOLD); gL:SetPoint("BOTTOMLEFT", 0, 36)
    send.gold = W:Input(send, 110); send.gold:SetPoint("BOTTOMLEFT", 0, 6)
    send.gold:SetNumeric(true)
    send.postage = W.Text(send, "small", "text.muted"); send.postage:SetPoint("LEFT", send.gold, "RIGHT", 12, 0)
    send.go = W:Button(send, L.MAILW_SEND, "primary", "mail", 120); send.go:SetPoint("BOTTOMRIGHT", 0, 6)
    send.go.onClick = function() M:MailSend() end

    win:SetScript("OnShow", function() M:LayoutMail() end)
    Skin:Register(win, function(self)
        Skin:Panel(self, "base", { border = "border.strong" })
        Skin:Panel(read, "sunken", { border = "border.subtle" })
        M:LayoutMail()
    end)
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("mail", win, L.MAILW_TITLE) end
end

---------------------------------------------------------------- open all
local function stepOpenAll()
    if not openingAll or not (win and win:IsShown()) then openingAll = nil; return end
    local nxt = M.MailNextTake(count(), M.MailHeader, itemAt)
    if not nxt or (nxt.kind == "item" and bagsFull()) then openingAll = nil; M:LayoutMail(); return end
    if nxt.kind == "money" then TakeInboxMoney(nxt.index) else TakeInboxItem(nxt.index, nxt.slot) end
    C_Timer.After(0.35, stepOpenAll)
end
function M:MailOpenAll()
    if openingAll then return end
    openingAll = true
    stepOpenAll()
end

---------------------------------------------------------------- open / close follow Blizzard's mailbox
local function mailOpen() return MailFrame and MailFrame:IsShown() and true or false end

function M:SyncMail()
    local want = on() and not visitBlizzard and mailOpen()
    if want then
        if not win then build() end
        if not Skin:Tuck(MailFrame) then want = false end
    end
    if not want then
        openingAll = nil
        if win then win:Hide() end
        if MailFrame then Skin:Untuck(MailFrame) end
        return
    end
    win:Show()
    self:LayoutMail()
end

local listening
function M:SetupMailWindow()
    if listening then self:SyncMail(); return end
    listening = true
    local owner = {}
    ns.Events:On("MAIL_SHOW", owner, function()
        visitBlizzard, selected, offset, codArmed, tab = false, nil, 0, nil, "inbox"
        C_Timer.After(0, function() M:SyncMail() end)
    end)
    ns.Events:On("MAIL_CLOSED", owner, function() visitBlizzard = false; M:SyncMail() end)
    ns.Events:On("PLAYER_REGEN_ENABLED", owner, function() M:SyncMail() end)
    ns.Events:On("MAIL_SEND_SUCCESS", owner, function() clearSend(); M:LayoutMail() end)
    for _, event in ipairs({ "MAIL_INBOX_UPDATE", "MAIL_SEND_INFO_UPDATE", "MAIL_SUCCESS", "MAIL_FAILED",
        "SEND_MAIL_MONEY_CHANGED", "SEND_MAIL_COD_CHANGED" }) do
        ns.Events:On(event, owner, function() M:LayoutMail() end)
    end
    self:SyncMail()
end
M.SETUPS[#M.SETUPS + 1] = "SetupMailWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncMail"

function M:GetMailWindow() return win end
