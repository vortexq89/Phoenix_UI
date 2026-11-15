-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L, W, Skin, Theme, Secret = ns.L, ns.Widgets, ns.Skin, ns.Theme, ns.Secret
local M = ns.modules.Automation

--[[ Paladin blessings (NaowhForever's paladin blessings): for paladins, a small window with you and your group
    and your blessing on each one, its time left, or "Missing" in the danger colour. A blessing is a helpful aura
    you cast on that member (C_UnitAuras "HELPFUL|PLAYER"; your own Righteous Fury and auras are not counted on
    yourself). Click a row to target that member (a secure target button, made and placed out of combat). Aura
    values that are secret are shown as "On", never compared. Events only (UNIT_AURA, roster, combat end). ]]

local OWNER = {}
local ROW_H, ROWS = 18, 40
local win

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end

local function members()
    local out = { "player" }
    local n = tonumber((GetNumGroupMembers())) or 0
    if IsInRaid() then
        out = {}
        for i = 1, n do out[#out + 1] = "raid" .. i end
    else
        for i = 1, math.max(0, n - 1) do out[#out + 1] = "party" .. i end
    end
    return out
end

-- Your longest blessing on a unit: { name, left } (left nil = unknown or secret), or nil when missing.
function M.BlessingOn(unit, auraAt, now)
    local best
    for i = 1, 40 do
        local a = auraAt(unit, i)
        if not a then break end
        local name, exp = a.name, a.expirationTime
        if plain(name) and not (unit == "player" and plain(a.duration) and a.duration == 0) then
            local left = plain(exp) and exp > 0 and (exp - now) or nil
            if not best or (left and (not best.left or left > best.left)) then best = { name = name, left = left } end
        end
    end
    return best
end

local function auraAt(unit, i)
    local U = C_UnitAuras
    return U and U.GetAuraDataByIndex and U.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
end

function M.IsPaladin() local _, c = UnitClass("player"); return c == "PALADIN" end

local function row(i)
    local r = CreateFrame("Button", nil, win, "SecureActionButtonTemplate")
    r:RegisterForClicks("AnyUp", "AnyDown")
    r:SetAttribute("type", "target")
    r:SetHeight(ROW_H - 2)
    r:SetPoint("TOPLEFT", 4, -20 - (i - 1) * ROW_H)
    r:SetPoint("RIGHT", -4, 0)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.name = W.Text(r, "small", "text.primary", "LEFT")
    r.name:SetPoint("LEFT", 4, 0)
    r.value = W.Text(r, "small", "text.secondary", "RIGHT")
    r.value:SetPoint("RIGHT", -4, 0)
    r.name:SetPoint("RIGHT", r.value, "LEFT", -4, 0)
    win.rows[i] = r
    return r
end

local function build()
    win = CreateFrame("Frame", "PhoenixUI_Blessings", UIParent)
    win.rows = {}
    win.title = W.Text(win, "small", "text.secondary", "LEFT")
    win.title:SetPoint("TOPLEFT", 6, -5)
    win.title:SetText(L.BLESS_TITLE)
    Skin:Register(win, function(self) Skin:Panel(self, "base", { border = "border.subtle" }) end)
    local movers = ns:GetModule("Movers")
    if movers then
        movers:Register("auto.blessings", win, L.BLESS_TITLE, {
            active = function() return M:IsEnabled() and M.db.blessings and M.IsPaladin() end,
            get = function() local d = M.db; return { point = d.blessPoint, x = d.blessX, y = d.blessY } end,
            set = function(v)
                local d = M.db
                d.blessPoint, d.blessX, d.blessY = v.point or d.blessPoint, v.x or d.blessX, v.y or d.blessY
            end,
            apply = function() M:UpdateBlessings() end,
            preview = function() M:UpdateBlessings() end,
            reset = function()
                local d, f = M.db, M.defaults
                d.blessPoint, d.blessX, d.blessY = f.blessPoint, f.blessX, f.blessY
                M:UpdateBlessings()
            end,
        })
    end
end

local function paint(list)
    local now = GetTime()
    for i, r in ipairs(win.rows) do
        local u = list[i]
        if u and r:IsShown() then
            local _, class = UnitClass(u)
            local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if c then r.name:SetTextColor(c.r, c.g, c.b) else W.Color(r.name, "text.primary") end
            r.name:SetText(UnitName(u) or "?")
            local b = UnitExists(u) and M.BlessingOn(u, auraAt, now)
            r.bg:SetColorTexture(0, 0, 0, 0.35)
            if b then
                r.value:SetText(b.left and (b.name .. "  " .. SecondsToTime(math.floor(b.left), true)) or L.BLESS_ON)
                r.value:SetTextColor(Theme:Color("text.secondary"))
            else
                r.value:SetText(L.BLESS_MISSING)
                r.value:SetTextColor(Theme:Color("state.danger"))
            end
        end
    end
end

function M:UpdateBlessings()
    local d = self.db
    local want = d.blessings and self:IsEnabled() and M.IsPaladin()
    if not want then
        if win and not InCombatLockdown() then win:Hide() end
        return
    end
    if not win then
        if InCombatLockdown() then return end
        build()
    end
    local list = members()
    if not InCombatLockdown() then
        local shown = math.min(#list, ROWS)
        for i = 1, shown do
            local r = win.rows[i] or row(i)
            r:SetAttribute("unit", list[i])
            r:Show()
        end
        for i = shown + 1, #win.rows do win.rows[i]:Hide() end
        win:SetSize(d.blessWidth, 24 + math.max(1, shown) * ROW_H)
        win:ClearAllPoints()
        win:SetPoint(d.blessPoint, UIParent, d.blessPoint, d.blessX, d.blessY)
        win:Show()
    end
    paint(list)
end
function M:BlessingsWindow() return win end

function M:SetupBlessings()
    if self.blessHooked then return end
    self.blessHooked = true
    local function update() ns.SafeCall(M.UpdateBlessings, M) end
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
        ns.Events:On(e, OWNER, update)
    end
    ns.Events:On("UNIT_AURA", OWNER, function() if win and win:IsShown() then update() end end)
    update()
end

-- live: a changed blessings setting applies at once
local previous = M.OnSettingChanged
function M:OnSettingChanged(key, ...)
    if previous then previous(self, key, ...) end
    if type(key) == "string" and key:find("^bless") then ns.SafeCall(M.UpdateBlessings, self) end
end
