local _, ns = ...
local L = ns.L
local M = ns:GetModule("CastBars")

--[[ Casts on me: a stack of cast bars for enemy casts aimed at you (nameplate units). Who a spell targets can be
    a secret value, so it is never read or compared: each claimed slot is shown through
    Region:SetAlphaFromBoolean(PlayerIsSpellTarget(unit)), which the game resolves itself. A cast on someone
    else therefore holds a slot invisibly until it ends. Off by default (Cast Bars > Target > Casts on me). ]]
local KEY = "onme"
local MAX = 6
local slotOf = {} -- unit -> bar

local function isPlate(unit) return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil end
M.IsPlateUnit = isPlate

local function bars() return M.bars[KEY] or {} end

-- A free slot: a bar not running a cast (a fading one is taken over).
function M.FreeOnMeSlot(list, count)
    for i = 1, math.min(count, #list) do
        local f = list[i]
        if not f.active and not f.unitClaim then return f end
    end
end

local function release(f)
    if f.unitClaim then slotOf[f.unitClaim] = nil end
    f.unitClaim, f.unit = nil, nil
end

local function aimAtMe(f, unit)
    if not PlayerIsSpellTarget then f:SetAlpha(1); return end
    local ok, yes = pcall(PlayerIsSpellTarget, unit)
    if ok then f:SetAlphaFromBoolean(yes, 1, 0) else f:SetAlpha(0) end
end

local function onEvent(_, event, unit, ...)
    if not isPlate(unit) then return end
    local b = M:Bar(KEY)
    if not (M:IsEnabled() and b.enabled) then return end
    local f = slotOf[unit]
    local starting = event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_EMPOWER_START"
    if not f and starting then
        local okA, hostile = pcall(UnitCanAttack, "player", unit)
        if okA and M.plain(hostile) and not hostile then return end
        f = M.FreeOnMeSlot(bars(), math.min(MAX, b.count or 4))
        if not f then return end
        f.unit, f.unitClaim, slotOf[unit] = unit, unit, f
    end
    if not f then return end
    M:OnCastEvent(f, event, unit, ...)
    if f.active then aimAtMe(f, unit) else release(f) end
end

function M:SpawnOnMe()
    if M.holders[KEY] then return end
    local holder = CreateFrame("Frame", "PhoenixUI_CB_onme", UIParent)
    holder:SetSize(1, 1)
    M.holders[KEY], M.bars[KEY] = holder, {}
    for i = 1, MAX do
        local f = M:BuildBar(holder, KEY, { name = "PhoenixUI_CB_onme" .. i })
        f.index, f.ev = i, {}
        f:SetScript("OnUpdate", M.OnBarUpdate)
        f:Hide()
        M.bars[KEY][i] = f
    end
    for _, ev in ipairs(M.CAST_EVENTS) do ns.Events:On(ev, holder, onEvent) end
    ns.Events:On("NAME_PLATE_UNIT_REMOVED", holder, function(_, _, unit)
        local f = slotOf[unit]
        if f then f.active = nil; f:Hide(); release(f) end
    end)
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("cb." .. KEY, holder, L.CB_ONME, M.MoverStore(KEY)) end
    M:RefreshOnMe()
end

function M:RefreshOnMe()
    local list = M.bars[KEY]
    if not list then return end
    local b = M:Bar(KEY)
    M.PlaceKey(KEY)
    for i, f in ipairs(list) do
        if not b.enabled or i > (b.count or 4) then f.active = nil; f:Hide(); release(f) end
    end
end
M.ONME_KEY = KEY
