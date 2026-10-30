local _, ns = ...
local L, Skin, Theme, W, Secret = ns.L, ns.Skin, ns.Theme, ns.Widgets, ns.Secret
local M = ns.modules.DamageMeter

--[[ Meter extras (docs/DAMAGE_METER.md §5): item level per player, the standalone big fight timer, header colours
    and icon borders. Item levels come from the game's inspect data, read out of combat only: group members are
    inspected one at a time (every 1.5 s, never in combat or while the inspect window is open), cached by GUID,
    and a row shows its player's value when the row's GUID is a plain value (your own row always). ]]
local OWNER = {}
local cache, pending, queue = {}, {}, {}
local ticker, timer

local function inCombat() return InCombatLockdown() or UnitAffectingCombat("player") end
local function plain(v) return v ~= nil and not Secret.IsSecret(v) end

---------------------------------------------------------------- item level
function M:ItemLevelOf(src)
    if src.isLocalPlayer then
        local _, equipped = GetAverageItemLevel()
        return equipped and equipped > 0 and math.floor(equipped) or nil
    end
    local guid = src.sourceGUID
    if plain(guid) then return cache[guid] end
end

-- Colour against yours: at or above it green, within 10 levels plain, further below amber.
function M.ItemLevelColor(il)
    local _, mine = GetAverageItemLevel()
    mine = mine or 0
    if il >= mine then return Theme:Color("state.success") end
    if il >= mine - 10 then return Theme:Color("text.primary") end
    return Theme:Color("state.warning")
end

local function groupUnits()
    local out, n = {}, tonumber(GetNumGroupMembers()) or 0
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, IsInRaid() and n or math.max(0, n - 1) do out[#out + 1] = prefix .. i end
    return out
end

local function step()
    if inCombat() or (InspectFrame and InspectFrame:IsShown()) then return end
    local unit = table.remove(queue, 1)
    if not unit then
        if ticker then ticker:Cancel(); ticker = nil end
        return
    end
    local guid = UnitGUID(unit)
    if plain(guid) and not cache[guid] and CanInspect(unit) then
        pending[guid] = unit
        NotifyInspect(unit)
    end
end

function M:ScanItemLevels()
    if inCombat() or self.db.meter.ilvl == "off" or not self:UsesPhoenixMeter() then return end
    wipe(queue)
    for _, unit in ipairs(groupUnits()) do
        local guid = UnitGUID(unit)
        if plain(guid) and not cache[guid] and UnitIsPlayer(unit) then queue[#queue + 1] = unit end
    end
    if #queue > 0 and not ticker then ticker = C_Timer.NewTicker(1.5, step) end
end

local function inspected(_, _, guid)
    local unit = plain(guid) and pending[guid]
    if not unit then return end
    pending[guid] = nil
    local il = C_PaperDollInfo.GetInspectItemLevel and C_PaperDollInfo.GetInspectItemLevel(unit)
    if plain(il) and il > 0 then
        cache[guid] = math.floor(il)
        M:QueueMeter()
    end
end

M.InspectStep, M.OnInspectReady, M.ilvlCache = step, inspected, cache -- the smoke harness drives the queue

---------------------------------------------------------------- header colour and icon border
local function headerRGB()
    local db = M.db.meter
    if db.headerColor == "class" then
        local _, class = UnitClass("player")
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    elseif db.headerColor == "custom" then
        local c = db.headerCustom
        return c.r, c.g, c.b
    end
    return Theme:Color("accent.primary")
end

function M.PaintHeader(win)
    local db = M.db.meter
    if db.headerColor == "none" then
        win.headerBg:Hide()
        win.line:Hide()
        return
    end
    local r, g, b = headerRGB()
    win.line:Show()
    win.line:SetColorTexture(1, 1, 1, 1)
    win.line:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.9), CreateColor(r, g, b, 0))
    win.headerBg:Show()
    win.headerBg:SetColorTexture(r, g, b, db.headerAlpha)
end

function M.PaintIconBorder(frame, style, class)
    if style == "class" then
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            Skin:Border(frame, "border.subtle", 1)
            return Skin:SetBorderColor(frame, c.r, c.g, c.b, 1)
        end
    end
    Skin:Border(frame, "border.subtle", 1)
end

---------------------------------------------------------------- big timer
local function buildTimer()
    timer = CreateFrame("Frame", "PhoenixUI_MeterTimer", UIParent)
    M.bigTimerFrame = timer
    timer:SetSize(140, 44)
    timer:SetClampedToScreen(true)
    timer.text = W.Text(timer, "number", "text.primary", "CENTER")
    timer.text:SetPoint("CENTER")
    timer.label = W.Text(timer, "small", "text.secondary", "CENTER")
    timer.label:SetPoint("TOP", timer.text, "BOTTOM", 0, -2)
    local movers = ns:GetModule("Movers")
    if movers then
        local function cfg() return M.db.meter.bigTimer end
        movers:Register("dm.timer", timer, L.DM_BIGTIMER, {
            active = function() return M:UsesPhoenixMeter() and cfg().enabled end,
            get = function() local c = cfg(); return { point = c.point, x = c.x, y = c.y } end,
            set = function(v) local c = cfg(); c.point, c.x, c.y = v.point or c.point, v.x or c.x, v.y or c.y end,
            apply = function() M:UpdateBigTimer() end,
            preview = function() M:UpdateBigTimer() end,
            reset = function()
                local d, c = M.defaults.meter.bigTimer, cfg()
                c.point, c.x, c.y = d.point, d.x, d.y
                M:UpdateBigTimer()
            end,
        })
    end
end

function M:PaintBigTimer()
    if not (timer and timer:IsShown()) then return end
    timer.text:SetText(M.Clock(M.Duration(1)) or "0:00")
end

function M:UpdateBigTimer()
    local c = self.db.meter.bigTimer
    local movers = ns:GetModule("Movers")
    local unlocked = movers and movers:IsUnlocked()
    local want = self:UsesPhoenixMeter() and c.enabled and (unlocked or not c.combatOnly or inCombat())
    if not want then
        if timer then timer:Hide() end
        return
    end
    if not timer then buildTimer() end
    timer:ClearAllPoints()
    timer:SetPoint(c.point, UIParent, c.point, c.x, c.y)
    Skin:TextSpec(timer.text, self.db.bigTimerText, "number", "text.primary")
    timer.label:SetText(c.label and L.DM_BIGTIMER_LABEL or "")
    timer:SetSize(math.max(80, (timer.text:GetStringWidth() or 60) + 24), 44)
    timer:Show()
    self:PaintBigTimer()
end

---------------------------------------------------------------- lifecycle
function M:SetupExtras()
    ns.Events:On("INSPECT_READY", OWNER, inspected)
    ns.Events:Listen("PUI_SPECICON_STYLE", OWNER, function() M:RefreshMeter() end)
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
        ns.Events:On(e, OWNER, function() M:ScanItemLevels() end)
    end
    self:ScanItemLevels()
end

function M:StopExtras()
    ns.Events:OffAll(OWNER)
    if ticker then ticker:Cancel(); ticker = nil end
    wipe(queue); wipe(pending)
    if timer then timer:Hide() end
end
