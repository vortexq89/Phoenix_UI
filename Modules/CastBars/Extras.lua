local _, ns = ...
local L, Skin, Media, Theme = ns.L, ns.Skin, ns.Media, ns.Theme
local M = ns.modules.CastBars
local extras = M.extras

--[[ Player extras beside the cast bar.
    GCD bar   a thin bar on the player cast bar's edge, or (S18) a standalone bar with its own width and
              Layout-mode mover, fed the global cooldown's duration object (C_Spell.GetSpellCooldownDuration) and
              faded out through SetAlphaFromBoolean(duration:IsZero()).
    Swing     WoW Forever only (ns:Supports("swingTimer")): PLAYER_SWING gives each swing's length (main hand,
              off hand, ranged); a main bar and a thin off-hand bar fill over it. Its own Layout-mode mover.
              S18: optional "MH" / "OH" labels, and a range cue that dims the bars while the target is out of
              melee reach (C_Spell.IsSpellInRange of Auto Attack; an unknown answer keeps them lit). ]]

local GCD_SPELL = 61304 -- spellIDs(retail): Global Cooldown
local AUTO_ATTACK = 6603 -- spellIDs: Auto Attack
local Enum_ = Enum or {}
local TIMER = Enum_.StatusBarTimerDirection or {}
local INTERP = Enum_.StatusBarInterpolation or {}
local SWING = Enum_.PlayerSwingType or { MainHand = 0, OffHand = 1, Ranged = 2 }

local function statusBar(parent)
    local s = CreateFrame("StatusBar", nil, parent)
    s:SetMinMaxValues(0, 1)
    s:SetValue(0)
    return s
end

local function look(s, token, colorKey)
    local b = M:Bar("player")
    s:SetStatusBarTexture(b.texture ~= "" and Media:Bar(b.texture) or Theme:Bar())
    s:GetStatusBarTexture():SetVertexColor(Skin:SpecColor(M.db.colors[colorKey], token))
    Skin:Backdrop(s, b.background, "bg.sunken")
    Skin:BorderSpec(s, b.border, "border.black")
end

---------------------------------------------------------------- GCD
local function gcdUpdate(g)
    if not (C_Spell and C_Spell.GetSpellCooldownDuration) then g:Hide(); return end
    local ok, d = pcall(C_Spell.GetSpellCooldownDuration, GCD_SPELL)
    if not ok or not d then g:SetAlpha(0); return end
    if g.SetTimerDuration then pcall(g.SetTimerDuration, g, d, INTERP.Immediate, TIMER.RemainingTime) end
    local okZ, zero = pcall(d.IsZero, d)
    if okZ then g:SetAlphaFromBoolean(zero, 0, 1) end
end

local function gcdStore()
    return {
        active = function() return M:IsEnabled() and M:IsPhoenix() and M.db.gcd.enabled and M.db.gcd.attach == "free"
            and ns:Supports("gcdBar") end,
        get = function() local c = M.db.gcd; return { point = c.point, x = c.x, y = c.y } end,
        set = function(v) local c = M.db.gcd; c.point, c.x, c.y = v.point or c.point, v.x or c.x, v.y or c.y end,
        apply = function() M:RefreshExtras() end,
        reset = function()
            local d, c = M.DEFAULTS.gcd, M.db.gcd
            c.point, c.x, c.y = d.point, d.x, d.y
            M:RefreshExtras()
        end,
    }
end

local function buildGCD()
    local holder = M.holders.player
    local g = statusBar(holder)
    -- the standalone bar's own holder (Layout mode moves it)
    g.free = CreateFrame("Frame", "PhoenixUI_CB_gcd", UIParent)
    g.free:SetSize(260, 4)
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("cb.gcd", g.free, L.CB_GCD, gcdStore()) end
    g.elapsed = 0
    g:SetScript("OnUpdate", function(self, e)
        self.elapsed = self.elapsed + e
        if self.elapsed < 0.1 then return end
        self.elapsed = 0
        if not self.sample then gcdUpdate(self) end
    end)
    extras.gcd = g
    return g
end

local function layoutGCD()
    local g = M.extras.gcd
    if not g then return end
    local c = M.db.gcd
    local p = M.bars.player and M.bars.player[1]
    local free = c.attach == "free"
    g:SetShown(c.enabled and ns:Supports("gcdBar") and (free or (M:Bar("player").enabled and p ~= nil)))
    g.free:SetShown(g:IsShown() and free)
    if not g:IsShown() then return end
    g:ClearAllPoints()
    if free then
        g:SetParent(g.free)
        g.free:ClearAllPoints()
        g.free:SetPoint(c.point, UIParent, c.point, c.x, c.y)
        g.free:SetSize(c.width, c.height)
        g:SetAllPoints(g.free)
    else
        g:SetParent(M.holders.player)
        g:SetPoint("TOPLEFT", p.Bar, "BOTTOMLEFT", 0, -c.gap)
        g:SetPoint("TOPRIGHT", p.Bar, "BOTTOMRIGHT", 0, -c.gap)
        g:SetHeight(c.height)
    end
    look(g, "text.secondary", "gcd")
end

---------------------------------------------------------------- swing timer (WoW Forever)
local function swingStore()
    return {
        active = function() return M:IsEnabled() and M:IsPhoenix() and M.db.swing.enabled and ns:Supports("swingTimer") end,
        get = function() local s = M.db.swing; return { point = s.point, x = s.x, y = s.y } end,
        set = function(v) local s = M.db.swing; s.point, s.x, s.y = v.point or s.point, v.x or s.x, v.y or s.y end,
        apply = function() M:RefreshExtras() end,
        reset = function()
            local d, s = M.DEFAULTS.swing, M.db.swing
            s.point, s.x, s.y = d.point, d.x, d.y
            M:RefreshExtras()
        end,
    }
end

-- Out of melee reach? true / false, or nil when the game cannot say (no target, a secret answer).
function M.SwingOutOfRange()
    if not (C_Spell and C_Spell.IsSpellInRange) or not UnitExists("target") then return nil end
    local ok, near = pcall(C_Spell.IsSpellInRange, AUTO_ATTACK, "target")
    if not ok or not M.plain(near) or near == nil then return nil end
    return not near
end

local function swingTick(self)
    local now = GetTime()
    if M.db.swing.rangeCue and not self.sample then
        self:SetAlpha(M.SwingOutOfRange() and 0.35 or 1)
    else
        self:SetAlpha(1)
    end
    local any = false
    for _, bar in ipairs({ self.main, self.off }) do
        if bar.start then
            local t = math.min(bar.total, now - bar.start)
            bar:SetValue(t)
            if bar == self.main then self.text:SetFormattedText("%.1f", math.max(0, bar.total - t)) end
            if now - bar.start < bar.total + 1.5 then any = true else bar.start = nil end
        elseif self.sample then
            bar.start, bar.total = now, 2.6 -- Test casts: keep swinging
            any = true
        end
    end
    if not any and not self.sample then self:Hide() end
end

local function buildSwing()
    local s = CreateFrame("Frame", "PhoenixUI_CB_swing", UIParent)
    s.main = statusBar(s)
    s.off = statusBar(s)
    s.text = s.main:CreateFontString(nil, "OVERLAY")
    s.mainLabel = s.main:CreateFontString(nil, "OVERLAY")
    s.offLabel = s.off:CreateFontString(nil, "OVERLAY")
    s:SetScript("OnUpdate", swingTick)
    s:Hide()
    extras.swing = s
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("cb.swing", s, L.CB_SWING, swingStore()) end
    return s
end

local function layoutSwing()
    local s = M.extras.swing
    if not s then return end
    local c = M.db.swing
    s:ClearAllPoints()
    s:SetPoint(c.point, UIParent, c.point, c.x, c.y)
    s:SetSize(c.width, c.height + (c.offhand and (math.max(2, math.floor(c.height / 2)) + 2) or 0))
    s.main:ClearAllPoints()
    s.main:SetPoint("TOPLEFT"); s.main:SetPoint("TOPRIGHT")
    s.main:SetHeight(c.height)
    s.off:ClearAllPoints()
    s.off:SetPoint("TOPLEFT", s.main, "BOTTOMLEFT", 0, -2); s.off:SetPoint("TOPRIGHT", s.main, "BOTTOMRIGHT", 0, -2)
    s.off:SetHeight(math.max(2, math.floor(c.height / 2)))
    look(s.main, "accent.primary", "swing")
    look(s.off, "accent.primary", "swing")
    Skin:TextSpec(s.text, c.text, "number", "text.primary")
    Skin:Place(s.text, s.main, c.text)
    s.text:SetShown(c.text.show ~= false)
    for _, pair in ipairs({ { s.mainLabel, s.main, L.CB_SWING_MH }, { s.offLabel, s.off, L.CB_SWING_OH } }) do
        local fs, b, label = pair[1], pair[2], pair[3]
        Skin:Text(fs, "small", "text.secondary", math.max(7, math.min(11, b:GetHeight() + 2)))
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", b, "LEFT", 3, 0)
        fs:SetText(label)
        fs:SetShown(c.labels and (b ~= s.off or c.offhand))
    end
    if not (c.enabled and ns:Supports("swingTimer")) then s:Hide() end
end

local function onSwing(_, _, duration, kind)
    local s = M.extras.swing
    if not (s and M.db.swing.enabled) or not M.plain(duration) or type(duration) ~= "number" then return end
    local bar = (kind == SWING.OffHand) and s.off or s.main
    if bar == s.off and not M.db.swing.offhand then return end
    bar.start, bar.total = GetTime(), math.max(0.1, duration)
    bar:SetMinMaxValues(0, bar.total)
    s:Show()
end

---------------------------------------------------------------- lifecycle
function M:SpawnExtras()
    buildGCD()
    ns.Events:On("SPELL_UPDATE_COOLDOWN", self, function() if extras.gcd and extras.gcd:IsShown() then gcdUpdate(extras.gcd) end end)
    if ns:Supports("swingTimer") then
        buildSwing()
        ns.Events:On("PLAYER_SWING", self, onSwing)
    end
    self:RefreshExtras()
end

function M:RefreshExtras()
    layoutGCD()
    layoutSwing()
end

-- Test casts show the extras with sample data too.
function M:TestExtras(show)
    local g, s = extras.gcd, extras.swing
    if g then
        g.sample = show or nil
        if show and g:IsShown() then g:SetMinMaxValues(0, 1); g:SetValue(0.6); g:SetAlpha(1) end
    end
    if s then
        s.sample = show or nil
        if show and self.db.swing.enabled then
            for _, bar in ipairs({ s.main, s.off }) do bar.start, bar.total = GetTime(), 2.6; bar:SetMinMaxValues(0, 2.6) end
            s:Show()
        end
    end
end
