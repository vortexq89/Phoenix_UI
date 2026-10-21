local _, ns = ...
local L = ns.L
local Theme, Skin, Secret, W = ns.Theme, ns.Skin, ns.Secret, ns.Widgets

--[[ DataTexts: one slim, Edit Mode movable info bar (FPS, latency, speed, durability, gold, clock, bugs).
    Each segment is an accent glyph + value + muted unit label. The bugs segment shows this session's
    error count (Bugs module), flashes on a new one and opens the bug viewer on click. ]]
local M = ns:NewModule("DataTexts", {
    label = "DATATEXTS", desc = "DATATEXTS_DESC", category = "interface", order = 90,
    defaults = {
        fps = true, latency = true, speed = false, durability = true, gold = false, clock = true, bugs = true,
        clock24 = true, background = true, scale = 1,
    },
})

local ORDER = { "fps", "latency", "speed", "durability", "gold", "clock", "bugs" }
local bar, segments = nil, {}
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
}

-- A segment is shown when enabled here and, for bugs, when the Bugs module is running.
local function wanted(key)
    return M.db[key] and (key ~= "bugs" or bugsModule() ~= nil)
end

local function segment(key)
    local s = segments[key]
    if s then return s end
    s = CreateFrame("Frame", nil, bar)
    s:SetHeight(22)
    s.icon = ns.Icons:Create(s, key, ICON_SIZE, "accent.primary")
    s.icon:SetPoint("LEFT")
    s.value = s:CreateFontString(nil, "OVERLAY")
    s.value:SetPoint("LEFT", s.icon, "RIGHT", 5, 0)
    s.unit = s:CreateFontString(nil, "OVERLAY")
    s.unit:SetPoint("LEFT", s.value, "RIGHT", 3, 0)
    Skin:Register(s, function(self)
        Skin:Text(self.value, "number", "text.primary", 12)
        Skin:Text(self.unit, "small", "text.muted", 10)
    end)
    if key == "bugs" then
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
    end
    segments[key] = s
    return s
end

local function layout()
    local x = 10
    for _, key in ipairs(ORDER) do
        local s = segments[key]
        if wanted(key) then
            s = segment(key)
            s:ClearAllPoints()
            s:SetPoint("LEFT", bar, "LEFT", x, 0)
            s:SetWidth(ICON_SIZE + 5 + s.value:GetStringWidth() + s.unit:GetStringWidth() + 4)
            x = x + s:GetWidth() + 16
            s:Show()
        elseif s then
            s:Hide()
        end
    end
    bar:SetWidth(math.max(40, x - 8))
end

local function update()
    for _, key in ipairs(ORDER) do
        if wanted(key) then
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
    ns.Events:Listen("PUI_BUG", self, function(_, _, _report, isNew)
        update()
        local b = bugsModule()
        if isNew and segments.bugs and segments.bugs:IsShown() and b and b.db.flash then b.Pulse(segments.bugs.glow) end
    end)
end

function M:OnDisable()
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    if bar then bar:Hide() end
end

function M:Refresh()
    if not bar then return end
    bar.bg:SetShown(self.db.background)
    bar:SetScale(self.db.scale)
    for key, s in pairs(segments) do ns.Icons:Apply(s.icon, key, ICON_SIZE) end -- re-pick the atlas tier for the new scale
    update()
end
