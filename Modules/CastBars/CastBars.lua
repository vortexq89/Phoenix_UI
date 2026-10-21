local _, ns = ...
local Theme, Skin, Secret = ns.Theme, ns.Skin, ns.Secret

--[[ CastBars: Phoenix look for Blizzard's player/target/focus cast bars, plus player-only extras
    (spell icon, remaining time, latency zone). Target/focus cast data may be secret: we only
    restyle those, never read their values. ]]
local M = ns:NewModule("CastBars", {
    label = "CASTBARS", desc = "CASTBARS_DESC", category = "interface", order = 40, reloadOnToggle = true,
    defaults = { style = true, icon = true, timer = true, latency = true, classColor = false },
})

local ART = { "Border", "BorderShield", "TextBorder", "Background", "DropShadow" }
local TYPE_TOKEN = { channel = "state.info", uninterruptable = "text.muted", interrupted = "state.danger" }
local bars = {}
local extras

local function plain(v) return not Secret.IsSecret(v) end

local function fill(bar)
    if not (M:IsEnabled() and M.db.style and bars[bar]) then return end
    bar:SetStatusBarTexture(Theme:Bar())
    local barType = bar.barType
    local token = plain(barType) and TYPE_TOKEN[barType]
    if token then
        bar:SetStatusBarColor(Theme:Color(token))
    elseif bar == PlayerCastingBarFrame and M.db.classColor then
        local _, classFile = UnitClass("player")
        bar:SetStatusBarColor(ns.Util.ClassColor(classFile))
    else
        bar:SetStatusBarColor(Theme:Color("accent.primary"))
    end
end

local function style(bar)
    for _, key in ipairs(ART) do Skin:HideRegion(bar[key]) end
    Skin:Register(bar, function(self)
        Skin:Panel(self, "sunken", { border = "border.black", shadow = 6, inset = -1 })
        if self.Text then Skin:Text(self.Text, "body", "text.primary", 11) end
        if self.CastTimeText then Skin:Text(self.CastTimeText, "number", "text.primary", 11) end
        fill(self)
    end)
    hooksecurefunc(bar, "UpdateBarFillTexture", fill)
end

---------------------------------------------------------------- player extras
-- Returns texture, startMs, endMs, isChannel for the player's cast, or nil when nothing is cast
-- or the data is secret (then the extras simply stay hidden).
local function castInfo()
    local name, _, texture, startMs, endMs = UnitCastingInfo("player")
    if not plain(name) then return nil end
    if name then return texture, startMs, endMs, false end
    name, _, texture, startMs, endMs = UnitChannelInfo("player")
    if not plain(name) or not name then return nil end
    return texture, startMs, endMs, true
end

-- The timer reads the end time cached at cast start instead of querying the cast every frame, and
-- the text is refreshed at 20 Hz. The frame is a child of the cast bar, so OnUpdate stops when it hides.
local TIMER_INTERVAL = 0.05

local function buildExtras()
    local bar = PlayerCastingBarFrame
    local e = CreateFrame("Frame", nil, bar)
    e:SetAllPoints()
    e.icon = e:CreateTexture(nil, "ARTWORK")
    e.icon:SetPoint("RIGHT", bar, "LEFT", -6, 0)
    e.iconBorder = CreateFrame("Frame", nil, e)
    e.iconBorder:SetAllPoints(e.icon)
    e.time = e:CreateFontString(nil, "OVERLAY")
    e.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    e.lag = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    e.lag:SetTexture(ns.Media.textures.WHITE)
    Skin:Register(e, function(self)
        Skin:Icon(self.icon)
        Skin:Border(self.iconBorder, "border.black")
        Skin:Text(self.time, "number", "text.primary", 11)
        self.lag:SetVertexColor(Theme:Color("state.danger"))
        self.lag:SetAlpha(0.45)
    end)
    e.elapsed = 0
    e:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < TIMER_INTERVAL then return end
        self.elapsed = 0
        if self.endTime then
            self.time:SetFormattedText("%.1f", math.max(0, self.endTime - GetTime()))
        else
            self.time:SetText("")
        end
    end)
    return e
end

local function onCastStart()
    if not extras then return end
    local texture, startMs, endMs, channel = castInfo()
    local db = M.db
    local size = PlayerCastingBarFrame:GetHeight() + 6
    extras.icon:SetSize(size, size)
    extras.icon:SetShown(db.icon and texture ~= nil)
    extras.iconBorder:SetShown(db.icon and texture ~= nil)
    if texture then extras.icon:SetTexture(texture) end
    local known = startMs and plain(startMs) and plain(endMs) and endMs > startMs
    extras.endTime = (db.timer and known) and endMs / 1000 or nil
    extras.time:SetText("")
    extras.lag:Hide()
    if db.latency and known then
        local _, _, _, world = GetNetStats()
        local fraction = math.min(1, world / (endMs - startMs))
        extras.lag:ClearAllPoints()
        extras.lag:SetPoint("TOP"); extras.lag:SetPoint("BOTTOM")
        extras.lag:SetPoint(channel and "LEFT" or "RIGHT")
        extras.lag:SetWidth(math.max(1, PlayerCastingBarFrame:GetWidth() * fraction))
        extras.lag:Show()
    end
end

local function onCastStop()
    if extras then extras.endTime = nil end
end

local START_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE" }
local STOP_EVENTS = { "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP" }

function M:OnEnable()
    for _, bar in ipairs({ PlayerCastingBarFrame, TargetFrame and TargetFrame.spellbar, FocusFrame and FocusFrame.spellbar }) do
        if bar then bars[bar] = true end
    end
    if self.db.style then
        for bar in pairs(bars) do style(bar) end
    end
    extras = buildExtras()
    for _, event in ipairs(START_EVENTS) do ns.Events:OnUnit(event, self, onCastStart, "player") end
    for _, event in ipairs(STOP_EVENTS) do ns.Events:OnUnit(event, self, onCastStop, "player") end
end

function M:Refresh()
    for bar in pairs(bars) do fill(bar) end
    onCastStart()
end
