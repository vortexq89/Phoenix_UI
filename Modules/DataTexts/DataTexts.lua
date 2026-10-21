local _, ns = ...
local L = ns.L
local Theme, Skin, Media, Secret = ns.Theme, ns.Skin, ns.Media, ns.Secret

--[[ DataTexts: one slim, Edit Mode movable info bar (FPS, latency, speed, durability, gold, clock).
    Each segment is a value + muted unit label; segments are separated by small ember dots. ]]
local M = ns:NewModule("DataTexts", {
    label = "DATATEXTS", desc = "DATATEXTS_DESC", category = "interface", order = 90,
    defaults = {
        fps = true, latency = true, speed = false, durability = true, gold = false, clock = true,
        clock24 = true, background = true, scale = 1,
    },
})

local ORDER = { "fps", "latency", "speed", "durability", "gold", "clock" }
local bar, segments = nil, {}

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
        return ms, "MS", colorFor(100, 200, ms, true)
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
}

local function segment(key)
    local s = segments[key]
    if s then return s end
    s = CreateFrame("Frame", nil, bar)
    s:SetHeight(22)
    s.value = s:CreateFontString(nil, "OVERLAY")
    s.value:SetPoint("LEFT")
    s.unit = s:CreateFontString(nil, "OVERLAY")
    s.unit:SetPoint("LEFT", s.value, "RIGHT", 3, 0)
    s.dot = s:CreateTexture(nil, "ARTWORK")
    s.dot:SetTexture(Media.textures.CIRCLE)
    s.dot:SetSize(4, 4)
    s.dot:SetPoint("RIGHT", s, "LEFT", -8, 0)
    Skin:Register(s, function(self)
        Skin:Text(self.value, "number", "text.primary", 12)
        Skin:Text(self.unit, "small", "text.muted", 10)
        self.dot:SetVertexColor(Theme:Color("accent.primary"))
    end)
    segments[key] = s
    return s
end

local function layout()
    local x, first = 10, true
    for _, key in ipairs(ORDER) do
        local s = segments[key]
        if M.db[key] then
            s = segment(key)
            s:ClearAllPoints()
            s:SetPoint("LEFT", bar, "LEFT", x, 0)
            s.dot:SetShown(not first)
            s:SetWidth(s.value:GetStringWidth() + s.unit:GetStringWidth() + 4)
            x = x + s:GetWidth() + 18
            first = false
            s:Show()
        elseif s then
            s:Hide()
        end
    end
    bar:SetWidth(math.max(40, x - 8))
end

local function update()
    for _, key in ipairs(ORDER) do
        if M.db[key] then
            local s = segment(key)
            local value, unit, token = PROVIDERS[key]()
            s.value:SetText(value)
            s.unit:SetText(unit or "")
            s.value:SetTextColor(Theme:Color(token or "text.primary"))
        end
    end
    layout()
end

local function build()
    bar = CreateFrame("Frame", nil, UIParent)
    bar:SetSize(200, 26)
    bar:SetFrameStrata("LOW")
    bar.bg = CreateFrame("Frame", nil, bar)
    bar.bg:SetAllPoints()
    bar.bg:SetFrameLevel(bar:GetFrameLevel())
    Skin:Register(bar.bg, function(self) Skin:Panel(self, "base", { border = "border.subtle", shadow = 6 }) end)
    ns.EditMode:Register(bar, { key = "DataTexts", name = ns.title .. " – " .. L.DATATEXTS, default = { point = "BOTTOM", x = 0, y = 4 } })
end

function M:OnEnable()
    if not bar then build() end
    bar:Show()
    self:Refresh()
    self.ticker = C_Timer.NewTicker(1, update)
    ns.Events:On("PLAYER_MONEY", self, update)
    ns.Events:On("UPDATE_INVENTORY_DURABILITY", self, update)
end

function M:OnDisable()
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    if bar then bar:Hide() end
end

function M:Refresh()
    if not bar then return end
    bar.bg:SetShown(self.db.background)
    bar:SetScale(self.db.scale)
    update()
end
