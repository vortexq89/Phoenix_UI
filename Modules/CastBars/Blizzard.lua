local _, ns = ...
local Theme, Skin, Secret, Media = ns.Theme, ns.Skin, ns.Secret, ns.Media

--[[ CastBars, Blizzard mode (the 2.0 behaviour, kept as the fallback): Phoenix look for Blizzard's player, target
    and focus cast bars, plus player-only extras (spell icon, remaining time, latency zone). Target/focus cast data
    may be secret: we only restyle those, never read their values. Uses the same per-bar look keys as Phoenix mode
    (texture, border, background, text, time, colors) and the 2.0 top-level toggles (style, icon, timer, latency,
    classColor, iconZoom). ]]
local M = ns.modules.CastBars

local ART = { "Border", "BorderShield", "TextBorder", "Background", "DropShadow" }
local TYPE_TOKEN = { channel = "state.info", uninterruptable = "text.muted", interrupted = "state.danger" }
local TYPE_COLOR = { channel = "channel", uninterruptable = "locked" }
local bars = {}   -- bar -> "player" | "target" | "focus"
local extras

local function plain(v) return not Secret.IsSecret(v) end

---------------------------------------------------------------- style (shared with the options preview)

function M:BarTexture(key)
    local b = self:Bar(key)
    return b.texture ~= "" and Media:Bar(b.texture) or Theme:Bar()
end

-- Fill colour for a cast of barType ("standard", "channel", "uninterruptable", "interrupted" …).
function M:FillColor(key, barType)
    local b = self:Bar(key)
    local slot = TYPE_COLOR[barType]
    if slot and type(b.colors[slot]) == "table" then return Skin:SpecColor(b.colors[slot]) end
    local token = TYPE_TOKEN[barType]
    if token then return Theme:Color(token) end
    if key == "player" and self.db.classColor then
        local _, classFile = UnitClass("player")
        return ns.Util.ClassColor(classFile)
    end
    return Skin:SpecColor(b.colors.cast, "accent.primary")
end

function M:StyleFrame(bar, key)
    local b = self:Bar(key)
    Skin:Backdrop(bar, b.background, "bg.sunken")
    Skin:BorderSpec(bar, b.border, "border.black")
    bar:SetStatusBarTexture(self:BarTexture(key))
end

function M:StyleTexts(text, time, key)
    local b = self:Bar(key)
    if text then Skin:TextSpec(text, b.text, "body", "text.primary") end
    if time then Skin:TextSpec(time, b.time, "number", "text.primary") end
end

local function fill(bar)
    local key = M:IsEnabled() and not M:IsPhoenix() and M.db.style and bars[bar]
    if not key then return end
    bar:SetStatusBarTexture(M:BarTexture(key))
    local barType = bar.barType
    bar:SetStatusBarColor(M:FillColor(key, plain(barType) and barType or nil))
end

local function style(bar)
    for _, key in ipairs(ART) do Skin:HideRegion(bar[key]) end
    Skin:Register(bar, function(self)
        local key = bars[self]
        M:StyleFrame(self, key)
        M:StyleTexts(self.Text, self.CastTimeText, key)
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
        Skin:IconZoom(self.icon, M.db.iconZoom)
        Skin:Border(self.iconBorder, "border.black")
        M:StyleTexts(nil, self.time, "player")
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
    local known = plain(startMs) and plain(endMs) and startMs and endMs and endMs > startMs
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
-- No UNIT_SPELLCAST_FAILED: it also fires for a second spell pressed during a cast that carries on.
local STOP_EVENTS = { "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_STOP" }

function M:EnableBlizzard()
    bars[PlayerCastingBarFrame] = "player"
    if TargetFrame and TargetFrame.spellbar then bars[TargetFrame.spellbar] = "target" end
    if FocusFrame and FocusFrame.spellbar then bars[FocusFrame.spellbar] = "focus" end
    if self.db.style then
        for bar in pairs(bars) do style(bar) end
    end
    extras = buildExtras()
    for _, event in ipairs(START_EVENTS) do ns.Events:OnUnit(event, self, onCastStart, "player") end
    for _, event in ipairs(STOP_EVENTS) do ns.Events:OnUnit(event, self, onCastStop, "player") end
end

function M:RefreshBlizzard()
    if self.db.style then
        for bar, key in pairs(bars) do
            self:StyleFrame(bar, key)
            self:StyleTexts(bar.Text, bar.CastTimeText, key)
            fill(bar)
        end
    end
    if extras then
        Skin:IconZoom(extras.icon, self.db.iconZoom)
        self:StyleTexts(nil, extras.time, "player")
    end
    onCastStart()
end
