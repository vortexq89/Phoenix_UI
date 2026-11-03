-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L = ns.L
local M = ns.modules.Tracker

--[[ Aura bars: one timer bar per watched player aura (spell IDs in auraBars.list), shown while the aura is up.
    Presence comes from C_UnitAuras.GetPlayerAuraBySpellID; the aura table and its duration object are handed to
    the widgets as they are (StatusBar:SetTimerDuration, FontString:SetText), never compared, so secret auras in
    combat still drive the bar. Refreshes are batched on C_Timer after UNIT_AURA; nothing runs per frame. ]]

local holder, bars = nil, {}

function M.ParseAuraBarList(text)
    local out = {}
    for id in tostring(text or ""):gmatch("%d+") do out[#out + 1] = tonumber(id) end
    return out
end

local function db() return M.db.auraBars end

local function store()
    return {
        active = function() return M:IsEnabled() and db().enabled end,
        get = function() local p = db(); return { point = p.point, x = p.x, y = p.y } end,
        set = function(val)
            local p = db()
            p.point, p.x, p.y = val.point or p.point, val.x or p.x, val.y or p.y
        end,
        apply = function() M:RefreshAuraBars() end,
        reset = function()
            local p, d = db(), M.defaults.auraBars
            p.point, p.x, p.y = d.point, d.x, d.y
            M:RefreshAuraBars()
        end,
    }
end

local function ensureHolder()
    if holder then return holder end
    holder = CreateFrame("Frame", "PhoenixUI_CDM_auraBars", UIParent)
    holder:SetSize(200, 18)
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("cdm.auraBars", holder, L.TRACKER_AURABARS, store()) end
    return holder
end

local function barFor(i)
    if bars[i] then return bars[i] end
    local f = CreateFrame("Frame", nil, holder)
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetPoint("TOPLEFT")
    f.Bar = CreateFrame("StatusBar", nil, f)
    f.Bar:SetMinMaxValues(0, 1)
    f.Bar:SetValue(1)
    f.Bar.name = f.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Bar.name:SetPoint("LEFT", 4, 0)
    f.Bar.name:SetJustifyH("LEFT")
    f.Bar.track = f.Bar:CreateTexture(nil, "BACKGROUND", nil, -6)
    f.Bar.track:SetPoint("TOPLEFT", -2, 2)
    f.Bar.track:SetPoint("BOTTOMRIGHT", 2, -2)
    bars[i] = f
    return f
end

local function aura(id)
    local api = C_UnitAuras
    if not (api and api.GetPlayerAuraBySpellID) then return nil end
    local ok, a = pcall(api.GetPlayerAuraBySpellID, id)
    if ok and type(a) == "table" then return a end
    return nil
end

local function duration(a)
    local api = C_UnitAuras
    if not (api and api.GetAuraDuration and a.auraInstanceID) then return nil end
    local ok, d = pcall(api.GetAuraDuration, "player", a.auraInstanceID)
    return ok and d or nil
end

local function fill(b, d)
    if d and b.SetTimerDuration then
        local ok = pcall(b.SetTimerDuration, b, d, Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate,
            Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime)
        if ok then return end
    end
    b:SetMinMaxValues(0, 1)
    b:SetValue(1)
end

local function style(f, p)
    local h = p.height
    f:SetSize(p.width, h)
    f.Icon:SetSize(h, h)
    f.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.Bar:ClearAllPoints()
    f.Bar:SetPoint("TOPLEFT", f.Icon, "TOPRIGHT", 2, 0)
    f.Bar:SetPoint("BOTTOMRIGHT")
    M:StyleBar("bars", f.Bar, f.Bar.name)
    local A = ns.Art
    local art = A and A.PaintSlot and A:PaintSlot(f.Bar.track, "DamageMeter.row.track", 0.5)
    f.Bar.track:SetShown(art and true or false)
    if art then A.OutlineText(f.Bar.name) end
end

-- (list of { id, aura }) for what is up now; the smoke test reads it.
function M:ActiveAuraBars()
    local out = {}
    local p = db()
    if not (self:IsEnabled() and p.enabled) then return out end
    for _, id in ipairs(M.ParseAuraBarList(p.list)) do
        local a = aura(id)
        if a then out[#out + 1] = { id = id, aura = a } end
    end
    return out
end

local function draw(list)
    ensureHolder()
    local p = db()
    local step = p.height + p.spacing
    holder:SetSize(p.width, math.max(p.height, #list * step - p.spacing))
    holder:ClearAllPoints()
    holder:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    for i, e in ipairs(list) do
        local f = barFor(i)
        style(f, p)
        f:ClearAllPoints()
        local y = (i - 1) * step
        if p.grow == "UP" then f:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, y)
        else f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y) end
        f.Icon:SetTexture(e.aura.icon or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(e.id)))
        f.Bar.name:SetText(e.aura.name or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(e.id)) or "")
        fill(f.Bar, e.aura.duration or duration(e.aura))
        f:Show()
    end
    for i = #list + 1, #bars do bars[i]:Hide() end
    holder:SetShown(#list > 0)
end

function M:RefreshAuraBars()
    if self.auraBarTest then return end
    local list = self:ActiveAuraBars()
    if #list > 0 or holder then draw(list) end
end

function M:DrawAuraBarTest()
    self.auraBarTest = true
    draw({ { id = 1459, aura = { name = L.TRACKER_AURABARS, icon = 135932 } },
        { id = 1126, aura = { name = L.TRACKER_AURABARS, icon = 136078 } } })
end

function M:HideAuraBarTest()
    self.auraBarTest = nil
    if holder then holder:Hide() end
    if self:IsEnabled() then self:RefreshAuraBars() end
end

local pending = false
local function queue()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        if M:IsEnabled() then ns.SafeCall(M.RefreshAuraBars, M) end
    end)
end
M.QueueAuraBars = queue

function M:EnableAuraBars()
    ensureHolder()
    self:On("UNIT_AURA", function(_, _, unit) if unit == "player" then queue() end end)
    self:On("PLAYER_ENTERING_WORLD", queue)
    queue()
end

function M:DisableAuraBars()
    if holder then holder:Hide() end
end
