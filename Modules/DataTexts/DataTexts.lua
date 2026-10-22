local _, ns = ...
local L = ns.L
local Skin, Secret, W, Style = ns.Skin, ns.Secret, ns.Widgets, ns.Style

--[[ DataTexts: one slim, Edit Mode movable info bar (FPS, latency, speed, durability, gold, clock, bugs, free bag
    slots, equipped item level, friends and guild online, new mail). Each segment is an accent glyph + value +
    muted unit label, in the order you drag them to on the settings page (db.order, a comma list so saved
    profiles stay plain strings). Segments with a window behind them open it on click, out of combat only.
    The bugs segment shows this session's error count (Bugs module), flashes on a new one and opens the bug
    viewer. Slow-changing segments (bags, item level, friends, guild, mail) refresh on their events; the
    1 s ticker only redraws the bar and is stopped while the bar is hidden. ]]
local M = ns:NewModule("DataTexts", {
    label = "DATATEXTS", desc = "DATATEXTS_DESC", category = "interface", order = 90,
    defaults = {
        fps = true, latency = true, speed = false, durability = true, gold = false, clock = true, bugs = true,
        bags = false, itemlevel = false, friends = false, guild = false, mail = false,
        order = "fps,latency,speed,durability,gold,bags,itemlevel,friends,guild,mail,clock,bugs",
        clock24 = true, background = true, scale = 1,
        backdrop = Style.Background({ alpha = 0.94 }),
        border = Style.Border({ style = "shadow" }),
        value = Style.Text(12), unitText = Style.Text(10),
        icons = true, colorValues = true, spacing = 16, height = 26, strata = "LOW",
    },
})

local ORDER = { "fps", "latency", "speed", "durability", "gold", "bags", "itemlevel", "friends", "guild", "mail", "clock", "bugs" }
M.ORDER = ORDER
local KNOWN = {}
for i, key in ipairs(ORDER) do KNOWN[key] = i end
-- Segment glyphs whose icon name differs from the key.
local ICON = { bags = "items" }
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
local bar           -- the live bar object (see M:NewBar)
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
        return lowest, L.DT_DURABILITY_UNIT, colorFor(50, 20, lowest)
    end,
    gold = function()
        return BreakUpLargeNumbers(math.floor(GetMoney() / 10000)), L.DT_GOLD_UNIT
    end,
    clock = function()
        local t = date(M.db.clock24 and "%H:%M" or "%I:%M")
        return t, M.db.clock24 and "" or date("%p")
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
}

-- Windows a click opens (never in combat: opening protected panels from addon code there is blocked).
local OPEN = {
    bags = function() ToggleAllBags() end,
    itemlevel = function() ToggleCharacter("PaperDollFrame") end,
    friends = function() ToggleFriendsFrame(FRIEND_TAB_FRIENDS) end,
    guild = function() if IsInGuild() then ToggleGuildFrame() end end,
    durability = function() ToggleCharacter("PaperDollFrame") end,
    gold = function() ToggleAllBags() end,
}
local TIP = { fps = "DT_FPS", latency = "DT_LATENCY", speed = "DT_SPEED", durability = "DT_DURABILITY", gold = "DT_GOLD",
    clock = "DT_CLOCK", bags = "DT_BAGS", itemlevel = "DT_ITEMLEVEL", friends = "DT_FRIENDS", guild = "DT_GUILD",
    mail = "DT_MAIL" }

-- A segment is shown when enabled here and, for bugs, when the Bugs module is running.
local function wanted(key)
    return M.db[key] and (key ~= "bugs" or bugsModule() ~= nil)
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
    s.value = s:CreateFontString(nil, "OVERLAY")
    s.value:SetPoint("LEFT", s.icon, "RIGHT", 5, 0)
    s.unit = s:CreateFontString(nil, "OVERLAY")
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
        s:SetScript("OnEnter", function(self)
            W.ShowTooltip(self, L[TIP[key]], OPEN[key] and L.DT_CLICK_TIP or nil)
        end)
        s:SetScript("OnLeave", W.HideTooltip)
        if OPEN[key] then
            s:SetScript("OnMouseUp", function() if not InCombatLockdown() then OPEN[key]() end end)
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

-- values: { [key] = { value, unit, token } } for the keys to show, laid out in the saved order.
function M:FillBar(o, values)
    local db = self.db
    local x = 10
    for _, key in ipairs(self:Order()) do
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
            s:ClearAllPoints()
            s:SetPoint("LEFT", o.frame, "LEFT", x, 0)
            s:SetWidth((db.icons and ICON_SIZE + 5 or 0) + s.value:GetStringWidth() + s.unit:GetStringWidth() + 4)
            x = x + s:GetWidth() + db.spacing
            s:Show()
        elseif s then
            s:Hide()
        end
    end
    o.frame:SetWidth(math.max(40, x - db.spacing + 8))
end

local function update()
    local values = {}
    for _, key in ipairs(ORDER) do
        if wanted(key) then values[key] = { PROVIDERS[key]() } end
    end
    M:FillBar(bar, values)
end

local function build()
    bar = M:NewBar(UIParent, true)
    ns.EditMode:Register(bar.frame, { key = "DataTexts", name = ns.title .. " – " .. L.DATATEXTS,
        default = { point = "BOTTOM", x = 0, y = 4 } })
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
    C_Timer.After(0.2, function() pending = nil; if bar and bar.frame:IsShown() then update() end end)
end

function M:OnEnable()
    if not bar then
        build()
        bar.frame:HookScript("OnShow", startTicker)
        bar.frame:HookScript("OnHide", stopTicker)
    end
    bar.frame:Show()
    self:Refresh()
    startTicker()
    ns.Events:On("PLAYER_MONEY", self, update)
    ns.Events:On("UPDATE_INVENTORY_DURABILITY", self, update)
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED",
        "GUILD_ROSTER_UPDATE", "UPDATE_PENDING_MAIL" }) do
        ns.Events:On(event, self, soon)
    end
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
    ns.Events:Listen("PUI_BUG", self, function(_, _, _report, isNew)
        update()
        local b = bugsModule()
        local seg = bar.segments.bugs
        if isNew and seg and seg:IsShown() and b and b.db.flash then b.Pulse(seg.glow) end
    end)
end

function M:OnDisable()
    stopTicker()
    if bar then bar.frame:Hide() end
end

function M:Refresh()
    if not bar then return end
    bar.frame:SetScale(self.db.scale)
    bar.frame:SetFrameStrata(self.db.strata)
    self:StyleBar(bar)
    update()
end
