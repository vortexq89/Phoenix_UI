local _, ns = ...
local L, Skin, Theme, W, Secret = ns.L, ns.Skin, ns.Theme, ns.Widgets, ns.Secret
local M = ns.modules.DamageMeter

--[[ Threat meter (WoW Forever; EllesmereUI reference: the meter's threat type). A small Phoenix window: you and
    your group on your target, highest threat first, as bars of the threat percentage (100% = pulls aggro),
    the tank's row marked. Read from UnitDetailedThreatSituation on UNIT_THREAT_LIST_UPDATE, target and roster
    changes (no timer). Forever's threat values are plain; any value that is secret anyway is skipped, never
    compared. Shown in combat with a hostile target (or always, with "In combat only" off); movable in Layout mode. ]]

local OWNER = {}
local ROW_H, GAP = 16, 2
local win

-- Group units to read: player, party or raid members (and pets are left out).
local function units()
    local out = { "player" }
    local n = GetNumGroupMembers() or 0
    if IsInRaid() then
        out = {}
        for i = 1, n do out[#out + 1] = "raid" .. i end
    else
        for i = 1, math.max(0, n - 1) do out[#out + 1] = "party" .. i end
    end
    return out
end

-- Sorted rows { name, pct, tank, class } from a reader (unit -> isTanking, status, pct); secret values dropped.
function M.ThreatRows(list, read, nameOf, classOf)
    local rows = {}
    for _, u in ipairs(list) do
        local tanking, _, pct = read(u)
        if type(pct) == "number" and not Secret.IsSecret(pct) and not Secret.IsSecret(tanking) then
            rows[#rows + 1] = { name = nameOf(u), pct = pct, tank = tanking and true or false, class = classOf(u) }
        end
    end
    table.sort(rows, function(a, b) return a.pct > b.pct end)
    return rows
end

local function row(i)
    local r = CreateFrame("StatusBar", nil, win)
    r:SetMinMaxValues(0, 100)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.name = W.Text(r, "small", "text.primary", "LEFT")
    r.name:SetPoint("LEFT", 4, 0)
    r.value = W.Text(r, "small", "text.primary", "RIGHT")
    r.value:SetPoint("RIGHT", -4, 0)
    r.name:SetPoint("RIGHT", r.value, "LEFT", -4, 0)
    win.rows[i] = r
    return r
end

local function build()
    win = CreateFrame("Frame", "PhoenixUI_Threat", UIParent)
    win.rows = {}
    win.title = W.Text(win, "small", "text.secondary", "LEFT")
    win.title:SetPoint("TOPLEFT", 6, -5)
    win.title:SetText(L.DM_THREAT)
    Skin:Register(win, function(self) Skin:Panel(self, "base", { border = "border.subtle" }) end)
    local movers = ns:GetModule("Movers")
    if movers then
        movers:Register("dm.threat", win, L.DM_THREAT, {
            active = function() return M:IsEnabled() and M.db.threat.enabled end,
            get = function() local t = M.db.threat; return { point = t.point, x = t.x, y = t.y } end,
            set = function(v) local t = M.db.threat; t.point, t.x, t.y = v.point or t.point, v.x or t.x, v.y or t.y end,
            apply = function() M:UpdateThreat() end,
            reset = function()
                local d, t = M.defaults.threat, M.db.threat
                t.point, t.x, t.y = d.point, d.x, d.y
                M:UpdateThreat()
            end,
        })
    end
end

local function classOf(u) local _, c = UnitClass(u); return c end
local function nameOf(u) return UnitName(u) end
local function read(u)
    if not UnitExists("target") then return nil end
    return UnitDetailedThreatSituation(u, "target")
end

function M:UpdateThreat()
    local t = self.db.threat
    if not (t.enabled and ns:Supports("threatMeter")) then if win then win:Hide() end return end
    if not win then build() end
    local want = UnitExists("target") and UnitCanAttack("player", "target") and (not t.combatOnly or InCombatLockdown()
        or UnitAffectingCombat("player"))
    local movers = ns:GetModule("Movers")
    if not want and not (movers and movers:IsUnlocked()) then win:Hide() return end
    local rows = want and M.ThreatRows(units(), read, nameOf, classOf) or {}
    local shown = math.min(#rows, t.rows)
    win:SetSize(t.width, 22 + math.max(1, shown) * (ROW_H + GAP))
    win:ClearAllPoints()
    win:SetPoint(t.point, UIParent, t.point, t.x, t.y)
    for i = 1, math.max(#win.rows, t.rows) do
        local r = win.rows[i] or (i <= t.rows and row(i))
        if r then
            local e = i <= shown and rows[i]
            r:SetShown(e and true or false)
            if e then
                r:SetStatusBarTexture(Theme:Bar())
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 4, -20 - (i - 1) * (ROW_H + GAP))
                r:SetPoint("RIGHT", -4, 0)
                r:SetHeight(ROW_H)
                r:SetValue(e.pct)
                local c = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
                if c then r:SetStatusBarColor(c.r, c.g, c.b) else r:SetStatusBarColor(Theme:Color("accent.primary")) end
                r.bg:SetColorTexture(0, 0, 0, 0.35)
                r.name:SetText(e.tank and L.DM_THREAT_TANK:format(e.name or "?") or (e.name or "?"))
                r.value:SetFormattedText("%d%%", e.pct)
            end
        end
    end
    win:Show()
end

function M:SetupThreat()
    if self.threatHooked or not ns:Supports("threatMeter") then return end
    self.threatHooked = true
    local function update() ns.SafeCall(M.UpdateThreat, M) end
    for _, e in ipairs({ "UNIT_THREAT_LIST_UPDATE", "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED",
        "PLAYER_REGEN_DISABLED" }) do
        ns.Events:On(e, OWNER, update)
    end
    update()
end
