local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix quest window: our own quest dialog fed by the quest offer API, for all four of the game's pages.
    Greeting: the NPC's quests (in progress first, then new), each with the game's own quest icon. Offer: the
    story, the objectives and every reward (items and currencies with their own icons framed in their quality
    colour, spells, gold, experience, honor, title, renown), Accept / Decline. Progress: what you still need
    (items, currencies, gold), Continue / Goodbye. Turn-in: pick a reward card (the one worth most at a vendor
    carries the Quests page's coin), Complete; a quest that costs gold asks for a second click naming the price.

    Safety: Blizzard's QuestFrame stays open the whole visit (Escape and every "is the quest window open" check
    behave as usual); the shared Replacement shell tucks it. Each button is the game's own call that Blizzard's
    button makes. PvP-flagged offers keep Blizzard's window (their confirmation popup is Blizzard's to show).
    Skins > "Phoenix quest window" off: Blizzard's window, reskinned, live; the arrow shows it for this visit. ]]

local WIDTH, VIEW_H, CARD_W, CARD_H, GAP = 360, 330, 176, 40, 6
local r
local choice, payArmed = 0, false

local function panel(name) local p = _G[name]; return p and p.IsShown and p:IsShown() end

-- Which of the game's four pages is up: "greeting" | "detail" | "progress" | "reward" | nil.
function M.QuestPage()
    if panel("QuestFrameRewardPanel") then return "reward" end
    if panel("QuestFrameProgressPanel") then return "progress" end
    if panel("QuestFrameDetailPanel") then return "detail" end
    if panel("QuestFrameGreetingPanel") then return "greeting" end
    return nil
end

local function itemCard(kind, i)
    local name, texture, count, quality, usable = GetQuestItemInfo(kind, i)
    return { type = kind, index = i, kind = "item", name = name, texture = texture, count = count, quality = quality,
        dim = usable == false, link = GetQuestItemLink and GetQuestItemLink(kind, i) }
end

local function currencyCard(kind, i, info)
    info = info or (C_QuestOffer and C_QuestOffer.GetQuestRewardCurrencyInfo and C_QuestOffer.GetQuestRewardCurrencyInfo(kind, i))
    if type(info) ~= "table" then return nil end
    return { type = kind, index = i, kind = "currency", name = info.name, texture = info.texture, quality = info.quality,
        count = info.totalRewardAmount or info.requiredAmount }
end

local function num(fn) return tonumber(fn and fn()) or 0 end

local function addChoices(o)
    for i = 1, num(GetNumQuestChoices) do
        local isCurrency = GetQuestItemInfoLootType and GetQuestItemInfoLootType("choice", i) == 1
        o.choices[#o.choices + 1] = isCurrency and currencyCard("choice", i) or itemCard("choice", i)
    end
end

local function addRewards(o, questID)
    for i = 1, num(GetNumQuestRewards) do o.rewards[#o.rewards + 1] = itemCard("reward", i) end
    local qi = C_QuestInfoSystem
    if not qi then return end
    for i, info in ipairs(qi.GetQuestRewardCurrencies and qi.GetQuestRewardCurrencies(questID) or {}) do
        o.rewards[#o.rewards + 1] = currencyCard("reward", i, info)
    end
    for _, spellID in ipairs(qi.GetQuestRewardSpells and qi.GetQuestRewardSpells(questID) or {}) do
        local info = qi.GetQuestRewardSpellInfo and qi.GetQuestRewardSpellInfo(questID, spellID)
        if type(info) == "table" and info.texture then
            o.rewards[#o.rewards + 1] = { kind = "spell", spellID = spellID, name = info.name, texture = info.texture }
        end
    end
end

local function addRequired(o)
    for i = 1, num(GetNumQuestItems) do o.required[#o.required + 1] = itemCard("required", i) end
    local get = C_QuestOffer and C_QuestOffer.GetQuestRequiredCurrencyInfo
    for i = 1, num(GetNumQuestCurrencies) do
        local c = get and currencyCard("required", i, get(i))
        if c then o.required[#o.required + 1] = c end
    end
end

local function addRenown(o)
    local get = C_QuestOffer and C_QuestOffer.GetQuestOfferMajorFactionReputationRewards
    local data = C_MajorFactions and C_MajorFactions.GetMajorFactionData
    if not (get and data) then return end
    for _, rep in ipairs(get() or {}) do
        local f = data(rep.factionID)
        if type(f) == "table" and f.name then o.extras[#o.extras + 1] = L.QUESTW_RENOWN:format(rep.rewardAmount or 0, f.name) end
    end
end

-- Everything the page offers or asks for, as plain cards and numbers.
function M.QuestOffer()
    local o = { choices = {}, rewards = {}, required = {}, extras = {} }
    addChoices(o)
    addRewards(o, GetQuestID and GetQuestID())
    addRequired(o)
    addRenown(o)
    o.money, o.xp, o.honor, o.cost = num(GetRewardMoney), num(GetRewardXP), num(GetRewardHonor), num(GetQuestMoneyToGet)
    o.title = GetRewardTitle and GetRewardTitle() or nil
    return o
end

local function money(v)
    local s = C_CurrencyInfo.GetCoinTextureString(tonumber(v) or 0)
    return type(s) == "string" and s or tostring(tonumber(v) or 0)
end

-- The reward to take: the picked card, the only choice, or 0 when the quest offers none. nil = still to pick.
function M.QuestChoice(n, picked)
    if n == 0 then return 0 end
    if n == 1 then return 1 end
    if picked and picked >= 1 and picked <= n then return picked end
    return nil
end

function M:QuestPrimary()
    local page = M.QuestPage()
    if page == "detail" then
        if QuestGetAutoAccept and QuestGetAutoAccept() then AcknowledgeAutoAcceptQuest() else AcceptQuest() end
    elseif page == "progress" then
        if IsQuestCompletable() then CompleteQuest() end
    elseif page == "reward" then
        local pick = M.QuestChoice(tonumber(GetNumQuestChoices()) or 0, choice)
        if not pick then if r then r:Layout() end; return end
        local cost = tonumber(GetQuestMoneyToGet()) or 0
        if cost > 0 and not payArmed then payArmed = true; if r then r:Layout() end; return end
        payArmed = false
        GetQuestReward(pick)
    end
end

---------------------------------------------------------------- content pools (inside the scroll child)
local function header(i)
    local h = r.headers[i]
    if not h then h = W.Text(r.child, "small", "accent.primary"); r.headers[i] = h end
    h:Show()
    return h
end

local function cardClick(self)
    local d = self.data
    if not d then return end
    if d.link and IsModifiedClick("CHATLINK") then ChatFrameUtil.InsertLink(d.link); return end
    if d.link and IsModifiedClick("DRESSUP") and DressUpLink then DressUpLink(d.link); return end
    if d.questRow then
        if d.active then SelectActiveQuest(d.questRow) else SelectAvailableQuest(d.questRow) end
        return
    end
    if d.type == "choice" and M.QuestPage() == "reward" then choice, payArmed = d.index, false; r:Layout() end
end

local function card(i)
    local c = r.cards[i]
    if c then return c end
    c = M.ReplaceCard(r.child, CARD_W, CARD_H)
    c:SetScript("OnClick", cardClick)
    c:SetScript("OnEnter", function(self)
        local d = self.data
        if not d or d.questRow then Skin:SetBorderColor(self, "accent.primary"); return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if d.kind == "spell" then GameTooltip:SetSpellByID(d.spellID)
        elseif d.kind == "currency" then GameTooltip:SetQuestCurrency(d.type, d.index)
        else GameTooltip:SetQuestItem(d.type, d.index) end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self) GameTooltip:Hide(); Skin:SetBorderColor(self, self.border or "border.subtle") end)
    c.mark = W.Icon(c, "gold", 14, "accent.primary", "OVERLAY")
    c.mark:SetPoint("TOPRIGHT", -3, -3)
    r.cards[i] = c
    return c
end

-- A layout pass: y runs down the scroll child; headers and cards come from the pools in order.
local function cursor() return { y = 0, nHead = 0, nCard = 0 } end

local function head(cur, text)
    cur.nHead = cur.nHead + 1
    local h = header(cur.nHead)
    h:SetText(text)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 0, cur.y - 6)
    cur.y = cur.y - 24
end

-- Lays cards two per row (wide = one per row).
local function placeCards(cur, list, wide, paint)
    for k, d in ipairs(list) do
        cur.nCard = cur.nCard + 1
        local c = card(cur.nCard)
        c.data = d
        c:SetWidth(wide and WIDTH or CARD_W)
        c:ClearAllPoints()
        local col = wide and 0 or (k - 1) % 2
        local row = wide and (k - 1) or math.floor((k - 1) / 2)
        c:SetPoint("TOPLEFT", col * (CARD_W + GAP), cur.y - row * (CARD_H + GAP))
        paint(c, d)
    end
    cur.y = cur.y - (wide and #list or math.ceil(#list / 2)) * (CARD_H + GAP)
end

local function line(cur, fs, text)
    if type(text) ~= "string" or text == "" then fs:Hide(); return end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 0, cur.y - 2)
    fs:SetText(text)
    fs:Show()
    cur.y = cur.y - math.ceil(fs:GetStringHeight() or 0) - 6
end

local function plainPaint(c, d) c.border = "border.subtle"; c.mark:Hide(); M.PaintCard(c, d) end

local function paintQuest(c, d)
    plainPaint(c, d)
    M.QuestIcon(c.icon, d.active, d)
    if d.trivial then Skin:Text(c.name, "body", "text.muted") end
end

-- The greeting page's quests: in progress first, then new ones.
function M.QuestGreetingRows()
    local active, new = {}, {}
    for i = 1, num(GetNumActiveQuests) do
        local t, done = GetActiveTitle(i)
        active[#active + 1] = { questRow = i, active = true, name = t, isComplete = done,
            questID = GetActiveQuestID and GetActiveQuestID(i),
            trivial = IsActiveQuestTrivial and IsActiveQuestTrivial(i), sub = done and L.GOSSIPW_READY or nil }
    end
    for i = 1, num(GetNumAvailableQuests) do
        local trivial, freq, rep, legendary, qid, important, meta = GetAvailableQuestInfo(i)
        new[#new + 1] = { questRow = i, name = GetAvailableTitle(i), trivial = trivial, frequency = freq, isRepeatable = rep,
            isLegendary = legendary, questID = qid, isImportant = important, isMeta = meta, sub = trivial and L.GOSSIPW_TRIVIAL or nil }
    end
    return active, new
end

local function greetingPage(cur)
    local active, new = M.QuestGreetingRows()
    if #active > 0 then head(cur, L.GOSSIPW_ACTIVE); placeCards(cur, active, true, paintQuest) end
    if #new > 0 then head(cur, L.GOSSIPW_AVAILABLE); placeCards(cur, new, true, paintQuest) end
end

local function progressPage(cur, o)
    if #o.required > 0 or o.cost > 0 then head(cur, L.QUESTW_REQUIRED) end
    placeCards(cur, o.required, false, plainPaint)
    if o.cost > 0 then head(cur, L.QUESTW_COSTS:format(money(o.cost))) end
end

local function extrasText(o)
    local bits = {}
    if o.money > 0 then bits[#bits + 1] = money(o.money) end
    if o.xp > 0 then bits[#bits + 1] = L.QUESTW_XP:format(BreakUpLargeNumbers(o.xp)) end
    if o.honor > 0 then bits[#bits + 1] = L.QUESTW_HONOR:format(o.honor) end
    if type(o.title) == "string" and o.title ~= "" then bits[#bits + 1] = L.QUESTW_TITLE_REWARD:format(o.title) end
    for _, e in ipairs(o.extras) do bits[#bits + 1] = e end
    return table.concat(bits, "   ")
end

local function rewardsPage(cur, o, page)
    local count = #o.choices
    local Q, best = ns.modules.Quests, nil
    if page == "reward" and count > 1 and Q and Q.db and Q.db.rewardMark and Q.BestVendorReward then best = Q.BestVendorReward(count) end
    if count > 0 then
        head(cur, count == 1 and L.QUESTW_RECEIVE or (page == "reward" and L.QUESTW_CHOOSE or L.QUESTW_CHOICES))
        placeCards(cur, o.choices, false, function(c, d)
            local picked = page == "reward" and count > 1 and d.index == choice
            c.border = picked and "accent.primary" or "border.subtle"
            M.PaintCard(c, d, c.border)
            if picked then Skin:SetPanelColor(c, "bg.hover") end
            c.mark:SetShown(best == d.index)
        end)
    end
    local extra = extrasText(o)
    if #o.rewards > 0 or (count == 0 and extra ~= "") then head(cur, count > 0 and L.QUESTW_ALSO or L.QUESTW_RECEIVE) end
    placeCards(cur, o.rewards, false, plainPaint)
    line(cur, r.extra, extra)
end

local PAGE_TEXT = { greeting = "GetGreetingText", detail = "GetQuestText", progress = "GetProgressText", reward = "GetRewardText" }

local function footer(page, o)
    local auto = page == "detail" and QuestGetAutoAccept and QuestGetAutoAccept() and true or false
    r.win.close:SetShown(not auto)
    r.hint:SetText("")
    r.primary:SetShown(page ~= "greeting" and page ~= nil)
    r.secondary:SetShown(not auto)
    r.secondary:SetText(page == "detail" and L.QUESTW_DECLINE or (page == "reward" and CANCEL or GOODBYE or CLOSE))
    if page == "detail" then
        r.primary:SetText(auto and OKAY or L.QUESTW_ACCEPT); r.primary:SetEnabledState(true)
    elseif page == "progress" then
        local can = IsQuestCompletable and IsQuestCompletable() and true or false
        r.primary:SetText(L.QUESTW_CONTINUE); r.primary:SetEnabledState(can)
        if not can then r.hint:SetText(L.QUESTW_NOT_YET) end
    elseif page == "reward" then
        local pick = M.QuestChoice(#o.choices, choice)
        r.primary:SetText(L.QUESTW_COMPLETE); r.primary:SetEnabledState(pick ~= nil)
        if not pick then r.hint:SetText(L.QUESTW_PICK) elseif payArmed then r.hint:SetText(L.QUESTW_PAY:format(money(o.cost))) end
    end
end

local function layout()
    for _, h in ipairs(r.headers) do h:Hide() end
    for _, c in ipairs(r.cards) do c:Hide() end
    r.obj:Hide(); r.extra:Hide()
    local page, o, cur = M.QuestPage(), M.QuestOffer(), cursor()
    local textFn = page and _G[PAGE_TEXT[page]]
    r.text:SetText(textFn and textFn() or "")
    cur.y = -(math.ceil(r.text:GetStringHeight() or 0) + 6)
    local title = GetTitleText and GetTitleText()
    r.win.title:SetText(page ~= "greeting" and type(title) == "string" and title ~= "" and title or L.QUESTW_TITLE)
    if page == "detail" then
        local obj = GetObjectiveText and GetObjectiveText()
        if type(obj) == "string" and obj ~= "" then head(cur, L.QUESTW_OBJECTIVES); line(cur, r.obj, obj) end
    end
    if page == "greeting" then greetingPage(cur)
    elseif page == "progress" then progressPage(cur, o)
    elseif page == "detail" or page == "reward" then rewardsPage(cur, o, page) end
    r.child:SetHeight(math.max(1, -cur.y))
    r.scroll:UpdateScrollChildRect()
    footer(page, o)
end

local function build(rr)
    r = rr
    r.headers, r.cards = {}, {}
    r.scroll = CreateFrame("ScrollFrame", nil, r.body)
    r.scroll:SetPoint("TOPLEFT", 0, 0)
    r.scroll:SetSize(WIDTH, VIEW_H)
    r.child = CreateFrame("Frame", nil, r.scroll)
    r.child:SetSize(WIDTH, 1)
    r.scroll:SetScrollChild(r.child)
    r.scroll:EnableMouseWheel(true)
    r.scroll:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, (r.child:GetHeight() or 0) - VIEW_H)
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 30)))
    end)
    r.text = W.Text(r.child, "body", "text.secondary")
    r.text:SetWordWrap(true); r.text:SetJustifyV("TOP"); r.text:SetWidth(WIDTH - 4)
    r.text:SetPoint("TOPLEFT", 0, 0)
    r.obj = W.Text(r.child, "body", "text.primary")
    r.obj:SetWordWrap(true); r.obj:SetJustifyV("TOP"); r.obj:SetWidth(WIDTH - 4)
    r.extra = W.Text(r.child, "body", "text.primary")
    r.extra:SetWordWrap(true); r.extra:SetWidth(WIDTH - 4)
    r.primary = W:Button(r.body, "", "primary", nil, 150)
    r.primary:SetHeight(26)
    r.primary:SetPoint("BOTTOMLEFT", 0, 0)
    r.primary.onClick = function() M:QuestPrimary() end
    r.secondary = W:Button(r.body, "", "secondary", nil, 110)
    r.secondary:SetHeight(26)
    r.secondary:SetPoint("BOTTOMRIGHT", 0, 0)
    r.secondary.onClick = function() CloseQuest() end
    r.hint = W.Text(r.body, "small", "state.warning")
    r.hint:SetPoint("BOTTOMLEFT", r.primary, "TOPLEFT", 0, 6)
    r.hint:SetPoint("RIGHT", 0, 0)
end

local quest
local place, mover, reposition = M.ReplacePlace("questPlace", "questPos", "QuestFrame", function() return quest end)

quest = M.Replacement({ key = "ownQuest", frame = "QuestFrame", title = L.QUESTW_TITLE,
    width = WIDTH + 20, height = 34 + 20 + VIEW_H + 8 + 26 + 24, build = build, layout = layout,
    place = place, mover = mover, close = function() CloseQuest() end,
    -- PvP-flagged offers need Blizzard's own confirmation popup: their page stays Blizzard's.
    ready = function() return not (M.QuestPage() == "detail" and QuestFlagsPVP and QuestFlagsPVP()) end })
M.QuestReplacement = quest

local function newPage()
    choice, payArmed = 0, false
    if quest.win and quest.scroll then quest.scroll:SetVerticalScroll(0) end
    C_Timer.After(0, function() quest:Sync() end)
end

function M:SetupQuestWindow()
    if quest.listening then quest:Sync(); return end
    if not M.ReplacementHook(quest) then return end
    quest.listening = true
    for _, event in ipairs({ "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
        ns.Events:On(event, quest, newPage)
    end
    for _, event in ipairs({ "QUEST_ITEM_UPDATE", "GET_ITEM_INFO_RECEIVED", "QUEST_LOG_UPDATE" }) do
        ns.Events:On(event, quest, function() if quest.win and quest.win:IsShown() then quest:Soon() end end)
    end
    quest:Sync()
end
function M:SyncQuest()
    quest:Sync()
    if quest.win and quest.win:IsShown() then reposition(); quest:Layout() end
end
M.SETUPS[#M.SETUPS + 1] = "SetupQuestWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncQuest"
