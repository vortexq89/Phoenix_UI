local _, ns = ...
local L = ns.L
local Skin, Secret, W, Style, Theme = ns.Skin, ns.Secret, ns.Widgets, ns.Style, ns.Theme

--[[ DataTexts: one slim, Edit Mode movable info bar (FPS, latency, speed, durability, gold, clock, bugs, free bag
    slots, equipped item level, friends and guild online, new mail). Each segment is an accent glyph + value +
    muted unit label, in the order you drag them to on the settings page (db.order, a comma list so saved
    profiles stay plain strings). Segments with a window behind them open it on click, out of combat only.
    The bugs segment shows this session's error count (Bugs module), flashes on a new one and opens the bug
    viewer. Slow-changing segments (bags, item level, friends, guild, mail) refresh on their events; the
    1 s ticker only redraws the bar and is stopped while the bar is hidden.
    2.0 S13b: a second panel (segments moved there by right-click on the settings page), fixed width with
    alignment, mouseover fade, spec / loot spec, keystone (retail), coordinates and volume segments, gold with
    copper and account totals (every character seen + the warband bank), realm time, a durability warning
    level, and rich tooltips (hidden in combat if you like). The experience / reputation bar is DataTexts/Bar.lua. ]]
local M = ns:NewModule("DataTexts", {
    label = "DATATEXTS", desc = "DATATEXTS_DESC", category = "interface", order = 90,
    defaults = {
        fps = true, latency = true, speed = false, durability = true, gold = false, clock = true, bugs = true,
        bags = false, itemlevel = false, friends = false, guild = false, mail = false,
        spec = false, keystone = false, coords = false, volume = false, currency = false,
        currency1 = 0, currency2 = 0, currency3 = 0,
        order = "fps,latency,speed,durability,gold,currency,bags,itemlevel,friends,guild,mail,spec,keystone,coords,volume,clock,bugs",
        order2 = "", panel2 = false, width = 0, justify = "LEFT", mouseover = false,
        clock24 = true, clockRealm = false, goldCopper = false, goldAccount = true, durabilityWarn = 25,
        tooltips = true, combatTips = true,
        xpBar = false, xpRep = true, rested = true, barWidth = 520, barHeight = 10, barTextMode = "mouseover",
        barHonor = false, barTexture = "", barReverse = false, barSmooth = true, barGradient = "none",
        barText = Style.Text(10, { outline = "OUTLINE" }),
        background = true, scale = 1,
        backdrop = Style.Background({ alpha = 0.94 }),
        border = Style.Border({ style = "shadow" }),
        value = Style.Text(12), unitText = Style.Text(10),
        icons = true, colorValues = true, spacing = 16, height = 26, strata = "LOW",
    },
})

local ORDER = { "fps", "latency", "speed", "durability", "gold", "currency", "bags", "itemlevel", "friends", "guild", "mail", "spec",
    "keystone", "coords", "volume", "clock", "bugs" }
M.ORDER = ORDER
local KNOWN = {}
for i, key in ipairs(ORDER) do KNOWN[key] = i end
-- Segment glyphs whose icon name differs from the key.
local ICON = { bags = "items", spec = "spec", keystone = "mythicplus", coords = "maps", volume = "sound", currency = "gold" }
-- Segments that need a client feature (ns:Supports).
local FEATURE = { keystone = "mythicplus" }
M.FEATURE = FEATURE
M.ICON = ICON

-- The saved order with unknown keys dropped and any segment it does not name yet appended in default order.
function M:Order(list)
    local out, seen = {}, {}
    for key in tostring(list or self.db.order or ""):gmatch("[^,%s]+") do
        if KNOWN[key] and not seen[key] then out[#out + 1] = key; seen[key] = true end
    end
    for _, key in ipairs(ORDER) do if not seen[key] then out[#out + 1] = key end end
    return out
end

-- Segments on the second panel (its own saved order); empty when the second panel is off.
function M:Order2(list)
    if not self.db.panel2 and not list then return {} end
    local out, seen = {}, {}
    for key in tostring(list or self.db.order2 or ""):gmatch("[^,%s]+") do
        if KNOWN[key] and not seen[key] then out[#out + 1] = key; seen[key] = true end
    end
    return out
end

-- Panel 1 shows every segment the second panel does not.
function M:Order1()
    local on2 = {}
    for _, key in ipairs(self:Order2()) do on2[key] = true end
    local out = {}
    for _, key in ipairs(self:Order()) do if not on2[key] then out[#out + 1] = key end end
    return out
end

-- Moves a segment to panel 2 (appended) or back to panel 1.
function M:MoveToPanel(key, panel)
    local list = {}
    for _, k in ipairs(self:Order2(self.db.order2)) do if k ~= key then list[#list + 1] = k end end
    if panel == 2 then list[#list + 1] = key end
    ns.DB:Set(self, "order2", table.concat(list, ","))
end
local bars = {}     -- the live panels (see M:NewBar)
local ICON_SIZE = 12

local function bugsModule()
    local b = ns:GetModule("Bugs")
    return b and b:IsEnabled() and b or nil
end

local function colorFor(good, ok, value, invert)
    if invert then value = -value; good = -good; ok = -ok end
    if value >= good then return "state.success" elseif value >= ok then return "state.warning" end
    return "state.danger"
end

local PROVIDERS = {
    fps = function()
        local fps = math.floor(GetFramerate() + 0.5)
        return fps, "FPS", colorFor(60, 30, fps)
    end,
    latency = function()
        local _, _, home, world = GetNetStats()
        local ms = math.max(home, world)
        return ms, "ms", colorFor(100, 200, ms, true)
    end,
    speed = function()
        local speed = GetUnitSpeed("player")
        if Secret.IsSecret(speed) then return "—", "%" end
        return math.floor(speed / BASE_MOVEMENT_SPEED * 100 + 0.5), "%"
    end,
    durability = function()
        local lowest = 100
        for slot = INVSLOT_HEAD, INVSLOT_LAST_EQUIPPED do
            local cur, max = GetInventoryItemDurability(slot)
            if cur and max and max > 0 then lowest = math.min(lowest, math.floor(cur / max * 100)) end
        end
        local warn = M.db.durabilityWarn
        return lowest, L.DT_DURABILITY_UNIT, colorFor(math.min(100, warn * 2), warn, lowest)
    end,
    gold = function()
        if M.db.goldCopper then return C_CurrencyInfo.GetCoinTextureString(GetMoney()), "" end
        return BreakUpLargeNumbers(math.floor(GetMoney() / 10000)), L.DT_GOLD_UNIT
    end,
    clock = function()
        return M.ClockText(M.db.clockRealm, M.db.clock24)
    end,
    spec = function()
        local name = M.SpecName()
        return name or "—", ""
    end,
    keystone = function()
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        local level = C_MythicPlus.GetOwnedKeystoneLevel()
        if type(mapID) ~= "number" or type(level) ~= "number" then return "—", "" end
        return "+" .. level, C_ChallengeMode.GetMapUIInfo(mapID) or ""
    end,
    coords = function()
        local x, y = ns.Util.PlayerMapXY()
        if not x then return "—", "" end
        return ("%.1f, %.1f"):format(x * 100, y * 100), ""
    end,
    volume = function()
        local v = tonumber((C_CVar.GetCVar("Sound_MasterVolume"))) or 0
        local muted = C_CVar.GetCVar("Sound_EnableAllSound") == "0"
        return math.floor(v * 100 + 0.5), "%", muted and "text.muted" or nil
    end,
    bugs = function()
        local unique = bugsModule():Counts()
        return unique, L.DT_BUGS_UNIT, unique > 0 and "state.danger" or "state.success"
    end,
    bags = function()
        local free = 0
        for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
            free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
        end
        return free, L.DT_BAGS_UNIT, colorFor(10, 3, free)
    end,
    itemlevel = function()
        local _, equipped = GetAverageItemLevel()
        return equipped and ("%.1f"):format(equipped) or "—", L.DT_ITEMLEVEL_UNIT
    end,
    friends = function()
        local n = C_FriendList.GetNumOnlineFriends() or 0
        local _, bnOnline = BNGetNumFriends()
        return n + (bnOnline or 0), L.DT_ONLINE_UNIT
    end,
    guild = function()
        if not IsInGuild() then return "—", "" end
        local _, online = GetNumGuildMembers()
        return online or 0, L.DT_ONLINE_UNIT
    end,
    mail = function()
        local has = HasNewMail()
        return has and L.DT_MAIL_NEW or L.DT_MAIL_NONE, "", has and "state.success" or "text.muted"
    end,
    currency = function()
        local parts = {}
        for _, c in ipairs(M:PickedCurrencies()) do
            parts[#parts + 1] = ("|T%s:12:12:0:0:64:64:5:59:5:59|t %s"):format(tostring(c.icon), BreakUpLargeNumbers(c.quantity))
        end
        if #parts == 0 then return "—", "" end
        return table.concat(parts, "  "), ""
    end,
}

---------------------------------------------------------------- currencies (picker on the options page)
M.CURRENCY_SLOTS = 3
-- The currencies picked in the three slots that the client knows: { id, name, quantity, max, icon }.
function M:PickedCurrencies()
    local out = {}
    for i = 1, M.CURRENCY_SLOTS do
        local id = tonumber(self.db["currency" .. i])
        local info = id and id > 0 and C_CurrencyInfo.GetCurrencyInfo(id)
        if info and info.name then
            out[#out + 1] = { id = id, name = info.name, quantity = tonumber(info.quantity) or 0,
                max = tonumber(info.maxQuantity) or 0, icon = info.iconFileID }
        end
    end
    return out
end

-- Every currency in your currency list (headers expanded as the game has them), for the picker: { id, name }.
function M.CurrencyChoices()
    local out = {}
    local n = tonumber((C_CurrencyInfo.GetCurrencyListSize())) or 0
    for i = 1, n do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and not info.isHeader and info.name then
            local link = C_CurrencyInfo.GetCurrencyListLink(i)
            local id = link and C_CurrencyInfo.GetCurrencyIDFromLink(link)
            if type(id) == "number" and id > 0 then out[#out + 1] = { id = id, name = info.name } end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- "14:05" / "2:05" + "PM", local or realm time.
function M.ClockText(realm, h24)
    local hour, minute
    if realm then hour, minute = GetGameTime() else hour, minute = tonumber((date("%H"))), tonumber((date("%M"))) end
    if h24 then return ("%02d:%02d"):format(hour, minute), "" end
    local suffix = hour >= 12 and TIMEMANAGER_PM or TIMEMANAGER_AM
    hour = hour % 12
    if hour == 0 then hour = 12 end
    return ("%d:%02d"):format(hour, minute), suffix
end

-- Current specialization name and the loot specialization's (nil when it follows the current spec).
function M.SpecName()
    local index = C_SpecializationInfo.GetSpecialization()
    local name
    if index then name = select(2, C_SpecializationInfo.GetSpecializationInfo(index)) end
    local lootID = GetLootSpecialization()
    local loot = type(lootID) == "number" and lootID > 0 and select(2, GetSpecializationInfoByID(lootID)) or nil
    return name, loot
end

-- Windows a click opens (never in combat: opening protected panels from addon code there is blocked).
local OPEN = {
    bags = function() ToggleAllBags() end,
    itemlevel = function() ToggleCharacter("PaperDollFrame") end,
    friends = function() ToggleFriendsFrame(FRIEND_TAB_FRIENDS) end,
    guild = function() if IsInGuild() then ToggleGuildFrame() end end,
    durability = function() ToggleCharacter("PaperDollFrame") end,
    gold = function() ToggleAllBags() end,
    spec = function() PlayerSpellsUtil.ToggleClassTalentOrSpecFrame() end,
    keystone = function() PVEFrame_ToggleFrame("ChallengesFrame") end,
    currency = function() ToggleCharacter("TokenFrame") end,
    coords = function() ToggleWorldMap() end,
}
local TIP = { fps = "DT_FPS", latency = "DT_LATENCY", speed = "DT_SPEED", durability = "DT_DURABILITY", gold = "DT_GOLD",
    clock = "DT_CLOCK", bags = "DT_BAGS", itemlevel = "DT_ITEMLEVEL", friends = "DT_FRIENDS", guild = "DT_GUILD",
    mail = "DT_MAIL", spec = "DT_SPEC", keystone = "DT_KEYSTONE", coords = "DT_COORDS", volume = "DT_VOLUME",
    currency = "DT_CURRENCY" }
M.TIP = TIP

-- A segment is shown when enabled here, when its client feature exists and, for bugs, when Bugs is running.
local function wanted(key)
    if FEATURE[key] and not ns:Supports(FEATURE[key]) then return false end
    return M.db[key] and (key ~= "bugs" or bugsModule() ~= nil)
end
M.Wanted = wanted

---------------------------------------------------------------- tooltips
local MAX_LINES = 15
local function money(copper) return C_CurrencyInfo.GetCoinTextureString(math.max(0, copper or 0)) end
local function line(label, value) return Theme:Wrap(label, "text.secondary") .. "  " .. tostring(value) end

-- Every character's gold, saved account-wide when seen (ns.DB.sv.global.gold[name - realm] = copper).
function M:SaveGold()
    local g = ns.DB.sv and ns.DB.sv.global
    if not g then return end
    g.gold = type(g.gold) == "table" and g.gold or {}
    g.gold[ns.Util.PlayerKey()] = GetMoney()
end

local function warbandMoney()
    if not (C_Bank and C_Bank.FetchDepositedMoney and Enum.BankType) then return 0 end
    local ok, v = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
    return ok and tonumber(v) or 0
end
M.WarbandMoney = warbandMoney

-- A count from the client, or 0 while it is not loaded yet.
local function count(v) return type(v) == "number" and v or 0 end

local TIPS = {
    latency = function()
        local _, _, home, world = GetNetStats()
        return line(L.DT_HOME, home .. " ms") .. "\n" .. line(L.DT_WORLD, world .. " ms")
    end,
    durability = function()
        local out = {}
        for slot = INVSLOT_HEAD, INVSLOT_LAST_EQUIPPED do
            local cur, max = GetInventoryItemDurability(slot)
            local link = GetInventoryItemLink("player", slot)
            if cur and max and max > 0 and link then
                local pct = math.floor(cur / max * 100)
                out[#out + 1] = line(link, Theme:Wrap(pct .. "%", colorFor(M.db.durabilityWarn * 2, M.db.durabilityWarn, pct)))
            end
        end
        return table.concat(out, "\n")
    end,
    gold = function()
        local out, total = {}, 0
        local saved = M.db.goldAccount and ns.DB.sv and ns.DB.sv.global and ns.DB.sv.global.gold or {}
        local list = {}
        for name, copper in pairs(saved) do list[#list + 1] = { name = name, copper = tonumber(copper) or 0 } end
        if not M.db.goldAccount then list = { { name = ns.Util.PlayerKey(), copper = GetMoney() } } end
        table.sort(list, function(a, b) return a.copper > b.copper end)
        for i, c in ipairs(list) do
            total = total + c.copper
            if i <= MAX_LINES then out[#out + 1] = line(c.name, money(c.copper)) end
        end
        if M.db.goldAccount then
            local bank = warbandMoney()
            total = total + bank
            out[#out + 1] = line(L.DT_WARBAND_BANK, money(bank))
            out[#out + 1] = line(L.DT_TOTAL, money(total))
        end
        return table.concat(out, "\n")
    end,
    clock = function()
        return line(L.DT_LOCAL_TIME, table.concat({ M.ClockText(false, M.db.clock24) }, " ")) .. "\n"
            .. line(L.DT_REALM_TIME, table.concat({ M.ClockText(true, M.db.clock24) }, " "))
    end,
    bags = function()
        local free, total = 0, 0
        for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
            free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
            total = total + (C_Container.GetContainerNumSlots(bag) or 0)
        end
        return line(L.DT_BAGS, ("%d / %d"):format(total - free, total))
    end,
    friends = function()
        local out = {}
        for i = 1, count(C_FriendList.GetNumFriends()) do
            local f = C_FriendList.GetFriendInfoByIndex(i)
            if f and f.connected and #out < MAX_LINES then out[#out + 1] = line(f.name or "", f.area or "") end
        end
        for i = 1, count((BNGetNumFriends())) do
            local a = C_BattleNet.GetFriendAccountInfo(i)
            local game = a and a.gameAccountInfo
            if game and game.isOnline and #out < MAX_LINES then
                out[#out + 1] = line(a.accountName or "", game.characterName or game.clientProgram or "")
            end
        end
        return table.concat(out, "\n")
    end,
    guild = function()
        if not IsInGuild() then return nil end
        local out = {}
        for i = 1, count((GetNumGuildMembers())) do
            local name, rank, _, level, _, zone, _, _, online = GetGuildRosterInfo(i)
            if online and #out < MAX_LINES then
                out[#out + 1] = line(Ambiguate(name or "", "guild"), ("%s · %s · %s"):format(level or "", rank or "", zone or ""))
            end
        end
        return table.concat(out, "\n")
    end,
    spec = function()
        local name, loot = M.SpecName()
        return line(L.DT_SPEC, name or "—") .. "\n" .. line(L.DT_LOOT_SPEC, loot or (name and L.DT_LOOT_CURRENT:format(name)) or "—")
    end,
    keystone = function()
        local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        local level = C_MythicPlus.GetOwnedKeystoneLevel()
        local out = {}
        if type(mapID) == "number" and type(level) == "number" then
            out[1] = line(C_ChallengeMode.GetMapUIInfo(mapID) or "", "+" .. level)
        else
            out[1] = L.DT_NO_KEY
        end
        local score = count(C_ChallengeMode.GetOverallDungeonScore())
        if score > 0 then out[#out + 1] = line(L.DT_RATING, score) end
        return table.concat(out, "\n")
    end,
    coords = function()
        local zone, sub = GetZoneText(), GetMinimapZoneText()
        return sub ~= "" and sub ~= zone and (zone .. " · " .. sub) or zone
    end,
    volume = function() return L.DT_VOLUME_TIP end,
    currency = function()
        local out = {}
        for _, c in ipairs(M:PickedCurrencies()) do
            local amount = c.max > 0 and ("%s / %s"):format(BreakUpLargeNumbers(c.quantity), BreakUpLargeNumbers(c.max))
                or BreakUpLargeNumbers(c.quantity)
            out[#out + 1] = line(c.name, amount)
        end
        return #out > 0 and table.concat(out, "\n") or L.DT_CURRENCY_NONE
    end,
}
M.TIPS = TIPS

-- Title + body for one segment (body nil when there is nothing to add).
function M:TooltipFor(key)
    local body = self.db.tooltips and TIPS[key] and TIPS[key]() or nil
    if OPEN[key] then body = (body and body ~= "" and body .. "\n\n" or "") .. L.DT_CLICK_TIP end
    return L[TIP[key]], body
end

local function showTip(seg, key)
    if M.db.combatTips and InCombatLockdown() then return end
    W.ShowTooltip(seg, M:TooltipFor(key))
end

---------------------------------------------------------------- bar object (shared with the options preview)
-- o = { frame, bg, segments = {}, live = bool }. Only the live bar wires the bugs segment's mouse actions.
function M:NewBar(parent, live)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(200, 26)
    local bg = CreateFrame("Frame", nil, f)
    bg:SetAllPoints()
    bg:SetFrameLevel(f:GetFrameLevel())
    return { frame = f, bg = bg, segments = {}, live = live }
end

local function segment(o, key)
    local s = o.segments[key]
    if s then return s end
    s = CreateFrame("Frame", nil, o.frame)
    s:SetHeight(22)
    s.icon = ns.Icons:Create(s, ICON[key] or key, ICON_SIZE, "accent.primary")
    s.icon:SetPoint("LEFT")
    s.value = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    s.value:SetPoint("LEFT", s.icon, "RIGHT", 5, 0)
    s.unit = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    s.unit:SetPoint("LEFT", s.value, "RIGHT", 3, 0)
    if key == "bugs" and o.live then
        s.glow = W.Texture(s, "BACKGROUND", 0, ns.Media.textures.CIRCLE)
        s.glow:SetSize(ICON_SIZE * 2.4, ICON_SIZE * 2.4)
        s.glow:SetPoint("CENTER", s.icon)
        s.glow:SetAlpha(0)
        Skin:Register(s.glow, function(self) W.Color(self, "state.danger", 0.6) end)
        s:EnableMouse(true)
        s:SetScript("OnMouseUp", function() local b = bugsModule(); if b then b:OpenViewer() end end)
        s:SetScript("OnEnter", function(self)
            local unique, total = bugsModule():Counts()
            W.ShowTooltip(self, L.BUGS, L.BUGS_INDICATOR_TIP:format(unique, total))
        end)
        s:SetScript("OnLeave", W.HideTooltip)
    elseif o.live then
        s:EnableMouse(true)
        s:SetScript("OnEnter", function(self) showTip(self, key) end)
        s:SetScript("OnLeave", W.HideTooltip)
        if OPEN[key] then
            s:SetScript("OnMouseUp", function() if not InCombatLockdown() then OPEN[key]() end end)
        end
        if key == "volume" then
            s:EnableMouseWheel(true)
            s:SetScript("OnMouseWheel", function(_, delta)
                local v = tonumber((C_CVar.GetCVar("Sound_MasterVolume"))) or 0
                C_CVar.SetCVar("Sound_MasterVolume", math.max(0, math.min(1, v + delta * 0.05)))
                if bars[1] then M:Update() end
            end)
        end
    end
    o.segments[key] = s
    return s
end

function M:StyleBar(o)
    local db = self.db
    o.bg:SetShown(db.background)
    Skin:Backdrop(o.bg, db.backdrop, "bg.base")
    Skin:BorderSpec(o.bg, db.border, "border.subtle")
    o.frame:SetHeight(db.height)
    for key, s in pairs(o.segments) do
        Skin:TextSpec(s.value, db.value, "number")
        Skin:TextSpec(s.unit, db.unitText, "small", "text.muted")
        ns.Icons:Apply(s.icon, ICON[key] or key, ICON_SIZE) -- re-pick the atlas tier for the current scale
        s.icon:SetShown(db.icons)
    end
end

-- values: { [key] = { value, unit, token } } for the keys to show, laid out in `order` (default: panel 1's).
-- A fixed width (db.width > 0) keeps the panel that wide and aligns the segments by db.justify.
function M:FillBar(o, values, order)
    local db = self.db
    local x = 10
    local shown = {}
    for _, key in ipairs(order or self:Order1()) do
        local v = values[key]
        local s = o.segments[key]
        if v then
            if not s then
                s = segment(o, key)
                self:StyleBar(o)
            end
            s.value:SetText(v[1])
            s.unit:SetText(v[2] or "")
            s.value:SetTextColor(Skin:SpecColor(db.value.color, db.colorValues and v[3] or "text.primary"))
            s.value:ClearAllPoints()
            if db.icons then s.value:SetPoint("LEFT", s.icon, "RIGHT", 5, 0) else s.value:SetPoint("LEFT") end
            s:SetWidth((db.icons and ICON_SIZE + 5 or 0) + s.value:GetStringWidth() + s.unit:GetStringWidth() + 4)
            shown[#shown + 1] = { s = s, x = x }
            x = x + s:GetWidth() + db.spacing
            s:Show()
        elseif s then
            s:Hide()
        end
    end
    local content = math.max(40, x - db.spacing + 8)
    local width = db.width > 0 and db.width or content
    local shift = 0
    if db.width > 0 and db.justify == "CENTER" then shift = (width - content) / 2
    elseif db.width > 0 and db.justify == "RIGHT" then shift = width - content end
    for _, e in ipairs(shown) do
        e.s:ClearAllPoints()
        e.s:SetPoint("LEFT", o.frame, "LEFT", e.x + math.max(0, shift), 0)
    end
    o.frame:SetWidth(width)
end

function M:Values()
    local values = {}
    for _, key in ipairs(ORDER) do
        if wanted(key) then values[key] = { PROVIDERS[key]() } end
    end
    return values
end

function M:Update()
    local values = self:Values()
    if bars[1] then self:FillBar(bars[1], values, self:Order1()) end
    if bars[2] then self:FillBar(bars[2], values, self:Order2()) end
end
local function update() M:Update() end

-- Mouseover only: a panel stays faded out until the cursor is over it (checked 10 times a second).
local function fader(o)
    local elapsed = 0
    o.frame:HookScript("OnUpdate", function(f, dt)
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        local want = (not M.db.mouseover or f:IsMouseOver()) and 1 or 0
        if f:GetAlpha() ~= want then f:SetAlpha(want) end
    end)
end

local function build(i)
    local o = M:NewBar(UIParent, true)
    local key = i == 1 and "DataTexts" or "DataTexts2"
    local name = ns.title .. " – " .. (i == 1 and L.DATATEXTS or L.DT_PANEL2)
    ns.EditMode:Register(o.frame, { key = key, name = name,
        default = { point = "BOTTOM", x = 0, y = i == 1 and 4 or 34 } })
    fader(o)
    bars[i] = o
    return o
end

local function startTicker()
    if not M.ticker then M.ticker = C_Timer.NewTicker(1, update) end
end
local function stopTicker()
    if M.ticker then M.ticker:Cancel(); M.ticker = nil end
end

-- Coalesces bursts of bag/roster events into one redraw on the next frame.
local pending
local function soon()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function() pending = nil; if bars[1] and bars[1].frame:IsShown() then update() end end)
end

function M:OnEnable()
    if not bars[1] then
        build(1)
        bars[1].frame:HookScript("OnShow", startTicker)
        bars[1].frame:HookScript("OnHide", stopTicker)
    end
    bars[1].frame:Show()
    self:SaveGold()
    self:Refresh()
    startTicker()
    ns.Events:On("PLAYER_MONEY", self, function() M:SaveGold(); update() end)
    ns.Events:On("UPDATE_INVENTORY_DURABILITY", self, update)
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED",
        "GUILD_ROSTER_UPDATE", "UPDATE_PENDING_MAIL", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_LOOT_SPEC_UPDATED",
        "ZONE_CHANGED_NEW_AREA", "CVAR_UPDATE" }) do
        ns.Events:On(event, self, soon)
    end
    if ns:Supports("mythicplus") then
        ns.Events:On("CHALLENGE_MODE_MAPS_UPDATE", self, soon)
    end
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
    ns.Events:Listen("PUI_BUG", self, function(_, _, _report, isNew)
        update()
        local b = bugsModule()
        local seg
        for _, o in pairs(bars) do seg = seg or (o.segments.bugs and o.segments.bugs:IsShown() and o.segments.bugs) end
        if isNew and seg and b and b.db.flash then b.Pulse(seg.glow) end
    end)
    if self.EnableBar then self:EnableBar() end
end

function M:OnDisable()
    stopTicker()
    for _, o in pairs(bars) do o.frame:Hide() end
    if self.DisableBar then self:DisableBar() end
end

function M:Refresh()
    if not bars[1] then return end
    if self.db.panel2 and not bars[2] then build(2) end
    for i, o in pairs(bars) do
        o.frame:SetScale(self.db.scale)
        o.frame:SetFrameStrata(self.db.strata)
        o.frame:SetShown(i == 1 or self.db.panel2)
        o.frame:SetAlpha(self.db.mouseover and 0 or 1)
        self:StyleBar(o)
    end
    update()
    if self.RefreshBar then self:RefreshBar() end
end

function M:GetBars() return bars end
