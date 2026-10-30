local _, ns = ...
local L, Skin, Theme, W, Secret = ns.L, ns.Skin, ns.Theme, ns.Widgets, ns.Secret
local M = ns.modules.DamageMeter

--[[ Phoenix damage meter windows (docs/DAMAGE_METER.md). Data comes only from Blizzard's C_DamageMeter API, the
    same source EllesmereUI's meter reads; the code here is Phoenix's own. In combat amounts, rates and other
    players' names are secret: they go straight to StatusBar:SetValue, AbbreviateNumbers and SetFormattedText and are
    never compared, sorted, added or stored. Repaints are coalesced on C_Timer (no OnUpdate); the fight clock ticks
    from a C_Timer ticker that exists only in combat. ]]

local OWNER = {}
local MAX_WINDOWS = 3
local HEADER_H = 22
local wins = {}

-- Meter types (Enum.DamageMeterType values), grouped for the mode menu; `rate` marks the per-second types.
M.MODES = {
    { title = "DM_GROUP_DAMAGE", { id = 0, label = "DM_MODE_DAMAGE", text = "DM_SHORT_DAMAGE" },
        { id = 1, label = "DM_MODE_DPS", text = "DM_SHORT_DPS", rate = true } },
    { title = "DM_GROUP_HEALING", { id = 2, label = "DM_MODE_HEALING", text = "DM_SHORT_HEALING" },
        { id = 3, label = "DM_MODE_HPS", text = "DM_SHORT_HPS", rate = true },
        { id = 4, label = "DM_MODE_ABSORBS", text = "DM_SHORT_ABSORBS" } },
    { title = "DM_GROUP_UTILITY", { id = 5, label = "DM_MODE_INTERRUPTS", text = "DM_SHORT_INTERRUPTS", count = true },
        { id = 6, label = "DM_MODE_DISPELS", text = "DM_SHORT_DISPELS", count = true },
        { id = 9, label = "DM_MODE_DEATHS", text = "DM_SHORT_DEATHS", deaths = true } },
    { title = "DM_GROUP_TAKEN", { id = 7, label = "DM_MODE_TAKEN", text = "DM_SHORT_TAKEN" },
        { id = 8, label = "DM_MODE_AVOIDABLE", text = "DM_SHORT_AVOIDABLE" },
        { id = 10, label = "DM_MODE_ENEMY", text = "DM_SHORT_ENEMY" } },
}
local modeById = {}
for _, g in ipairs(M.MODES) do for _, m in ipairs(g) do modeById[m.id] = m end end
function M.Mode(id) return modeById[id] or modeById[0] end

local SESSION_OVERALL, SESSION_CURRENT = 0, 1

function M:MeterAvailable()
    return C_DamageMeter ~= nil and C_DamageMeter.GetCombatSessionFromType ~= nil
end
function M:UsesPhoenixMeter() return self:IsEnabled() and self.db.engine == "phoenix" and self:MeterAvailable() end

---------------------------------------------------------------- data (secret-safe)
-- The session a window shows: a saved segment id (plain number from GetAvailableCombatSessions) or Current/Overall.
local function session(cfg)
    local DM = C_DamageMeter
    local ok, s
    if cfg.segment and cfg.segment > 0 and DM.GetCombatSessionFromID then
        ok, s = pcall(DM.GetCombatSessionFromID, cfg.segment, cfg.type)
        if ok and s then return s end
    end
    ok, s = pcall(DM.GetCombatSessionFromType, cfg.overall and SESSION_OVERALL or SESSION_CURRENT, cfg.type)
    return ok and s or nil
end
M.ReadSession = session

-- Fight length in whole seconds as "m:ss"; nil when unknown or secret.
function M.Clock(seconds)
    if type(seconds) ~= "number" or Secret.IsSecret(seconds) then return nil end
    seconds = math.floor(seconds)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function duration(cfg)
    local DM = C_DamageMeter
    if cfg.segment and cfg.segment > 0 and DM.GetAvailableCombatSessions then
        for _, s in ipairs(DM.GetAvailableCombatSessions() or {}) do
            if s.sessionID == cfg.segment then return s.durationSeconds end
        end
    end
    if DM.GetSessionDurationSeconds then
        local ok, d = pcall(DM.GetSessionDurationSeconds, cfg.overall and SESSION_OVERALL or SESSION_CURRENT)
        return ok and d or nil
    end
end

-- Value text: everything goes through AbbreviateNumbers / SetFormattedText, which accept secret values.
function M.PaintValue(fs, mode, fmt, total, perSecond)
    if mode.deaths then fs:SetText("") return end
    if mode.rate or mode.count or fmt == "total" then fs:SetText(AbbreviateNumbers(total)) return end
    if fmt == "rate" then fs:SetText(AbbreviateNumbers(perSecond)) return end
    fs:SetFormattedText("%s (%s)", AbbreviateNumbers(total), AbbreviateNumbers(perSecond))
end

---------------------------------------------------------------- frames
local function cfgOf(i) return M.db.meter["win" .. i] end

local function chip(parent, token)
    local b = CreateFrame("Button", nil, parent)
    b.text = W.Text(b, "small", token or "text.primary", "LEFT")
    b.text:SetPoint("LEFT", 6, 0)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b:SetHeight(HEADER_H - 6)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self) self.bg:SetAlpha(0.35) end)
    b:SetScript("OnLeave", function(self) self.bg:SetAlpha(0.18) end)
    function b:SetLabel(text)
        self.text:SetText(text)
        self:SetWidth(math.max(24, (self.text:GetStringWidth() or 20) + 12))
    end
    return b
end

local function makeRow(win, i)
    local r = CreateFrame("StatusBar", nil, win.body)
    r:SetMinMaxValues(0, 1)
    r:SetValue(0)
    r.track = r:CreateTexture(nil, "BACKGROUND")
    r.track:SetAllPoints()
    r.sheen = r:CreateTexture(nil, "ARTWORK", nil, 3)
    r.sheen:SetPoint("TOPLEFT"); r.sheen:SetPoint("TOPRIGHT")
    r.icon = r:CreateTexture(nil, "OVERLAY")
    r.icon:SetPoint("LEFT", 2, 0)
    r.rank = W.Text(r, "small", "text.secondary", "RIGHT")
    r.name = W.Text(r, "small", "text.primary", "LEFT")
    r.value = W.Text(r, "small", "text.primary", "RIGHT")
    r.value:SetPoint("RIGHT", -4, 0)
    r.name:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
    r.mine = CreateFrame("Frame", nil, r)
    r.mine:SetAllPoints()
    r.index = i
    r:EnableMouse(true)
    r:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then M:Back(win) else M:OpenBreakdown(win, self.index) end
    end)
    r:SetScript("OnEnter", function(self) M:RowTooltip(win, self) end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.rows[i] = r
    return r
end

local function menu(owner, build)
    if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(owner, build) end
end

local function modeMenu(win)
    menu(win.mode, function(_, root)
        for _, g in ipairs(M.MODES) do
            root:CreateTitle(L[g.title])
            for _, m in ipairs(g) do
                root:CreateRadio(L[m.label], function() return cfgOf(win.id).type == m.id end, function()
                    cfgOf(win.id).type = m.id
                    win.focus = nil
                    M:RefreshMeter()
                end)
            end
        end
    end)
end

local function segmentMenu(win)
    menu(win.segment, function(_, root)
        local cfg = cfgOf(win.id)
        local function pick(seg, overall)
            return function() cfg.segment, cfg.overall = seg, overall; win.focus = nil; M:RefreshMeter() end
        end
        root:CreateRadio(L.DM_SEG_CURRENT, function() return cfg.segment == 0 and not cfg.overall end, pick(0, false))
        root:CreateRadio(L.DM_SEG_OVERALL, function() return cfg.segment == 0 and cfg.overall end, pick(0, true))
        local list = C_DamageMeter.GetAvailableCombatSessions and C_DamageMeter.GetAvailableCombatSessions() or {}
        if #list > 0 then root:CreateTitle(L.DM_SEG_FIGHTS) end
        for i = #list, math.max(1, #list - 14), -1 do
            local s = list[i]
            local label = (s.name and s.name ~= "" and s.name or L.DM_SEG_FIGHT:format(i))
            local clock = M.Clock(s.durationSeconds)
            if clock then label = label .. "  |cff8a8f99" .. clock .. "|r" end
            root:CreateRadio(label, function() return cfg.segment == s.sessionID end, pick(s.sessionID, false))
        end
        root:CreateDivider()
        root:CreateButton(L.DM_RESET_ALL, function() M:ResetData() end)
    end)
end

local function build(i)
    local win = CreateFrame("Frame", "PhoenixUI_Meter" .. i, UIParent)
    win.id, win.rows = i, {}
    win:SetClampedToScreen(true)
    win.header = CreateFrame("Frame", nil, win)
    win.header:SetPoint("TOPLEFT"); win.header:SetPoint("TOPRIGHT")
    win.header:SetHeight(HEADER_H)
    win.line = win.header:CreateTexture(nil, "ARTWORK")
    win.line:SetPoint("BOTTOMLEFT"); win.line:SetPoint("BOTTOMRIGHT")
    win.line:SetHeight(1)
    win.mode = chip(win.header, "accent.primary")
    win.mode:SetPoint("LEFT", 3, 0)
    win.mode:SetScript("OnClick", function(_, button)
        if win.focus then M:Back(win) elseif button == "RightButton" then segmentMenu(win) else modeMenu(win) end
    end)
    win.segment = chip(win.header, "text.secondary")
    win.segment:SetPoint("LEFT", win.mode, "RIGHT", 3, 0)
    win.segment:SetScript("OnClick", function() segmentMenu(win) end)
    win.reset = chip(win.header, "text.secondary")
    win.reset:SetPoint("RIGHT", -3, 0)
    win.reset:SetLabel(L.DM_RESET)
    win.reset:SetScript("OnClick", function() M:ResetData() end)
    win.clock = W.Text(win.header, "number", "text.secondary", "RIGHT")
    win.clock:SetPoint("RIGHT", win.reset, "LEFT", -6, 0)
    win.body = CreateFrame("Frame", nil, win)
    win.body:SetPoint("TOPLEFT", 2, -HEADER_H - 2)
    win.body:SetPoint("BOTTOMRIGHT", -2, 2)
    win.empty = W.Text(win.body, "small", "text.secondary", "CENTER")
    win.empty:SetPoint("CENTER")
    win.empty:SetText(L.DM_EMPTY)
    Skin:Register(win, function(self)
        Skin:Panel(self, "base", { border = "border.subtle" })
        Skin:Gradient(self.line, "HORIZONTAL", "accent.primary", "accent.primary", 0.9, 0)
        for _, c in ipairs({ self.mode, self.segment, self.reset }) do W.Color(c.bg, "bg.raised", 0.18) end
    end)
    local movers = ns:GetModule("Movers")
    if movers then
        movers:Register("dm.meter" .. i, win, L.DM_WINDOW_N:format(i), {
            active = function() return M:UsesPhoenixMeter() and i <= M.db.meter.windows end,
            get = function() local c = cfgOf(i); return { point = c.point, x = c.x, y = c.y } end,
            set = function(v) local c = cfgOf(i); c.point, c.x, c.y = v.point or c.point, v.x or c.x, v.y or c.y end,
            apply = function() M:RefreshMeter() end,
            preview = function() M:RefreshMeter() end,
            reset = function()
                local d, c = M.defaults.meter["win" .. i], cfgOf(i)
                c.point, c.x, c.y = d.point, d.x, d.y
                M:RefreshMeter()
            end,
        })
    end
    wins[i] = win
    return win
end
M.meterWindows = wins

---------------------------------------------------------------- painting
local function layoutRow(r, db, y, width)
    local h = db.rowHeight
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetSize(width, h)
    r:SetStatusBarTexture(Theme:Bar())
    r.track:SetColorTexture(0, 0, 0, 0.35)
    r.sheen:SetHeight(math.max(1, math.floor(h / 2)))
    r.sheen:SetColorTexture(1, 1, 1, 0.06)
    r.icon:SetSize(h - 2, h - 2)
    r.icon:SetShown(db.specIcon)
    local left = db.specIcon and h + 2 or 4
    r.rank:ClearAllPoints()
    r.rank:SetShown(db.rank)
    if db.rank then
        r.rank:SetPoint("LEFT", left, 0)
        r.rank:SetWidth(18)
        left = left + 20
    end
    r.name:SetPoint("LEFT", left, 0)
end

local function paintSource(r, db, mode, src, maxAmount)
    if mode.deaths then r:SetMinMaxValues(0, 1); r:SetValue(1)
    else r:SetMinMaxValues(0, maxAmount); r:SetValue(src.totalAmount) end
    local class = src.classFilename
    local c = db.classColor and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then r:SetStatusBarColor(c.r, c.g, c.b, 0.85) else r:SetStatusBarColor(Theme:Color("accent.primary")) end
    if db.specIcon then
        if src.specIconID and src.specIconID ~= 0 then r.icon:SetTexture(src.specIconID); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else r.icon:SetTexture(nil) end
    end
    r.rank:SetText(r.index .. ".")
    r.name:SetText(src.name)
    M.PaintValue(r.value, mode, db.valueFormat, src.totalAmount, src.amountPerSecond)
    if src.isLocalPlayer then Skin:Border(r.mine, "accent.primary", 1); r.mine:Show() else r.mine:Hide() end
end

local function paintSpell(r, db, spell, maxAmount)
    r:SetMinMaxValues(0, maxAmount)
    r:SetValue(spell.totalAmount)
    r:SetStatusBarColor(Theme:Color("accent.primary"))
    local id = spell.spellID
    local plain = type(id) == "number" and not Secret.IsSecret(id)
    r.icon:SetTexture(plain and C_Spell.GetSpellTexture(id) or nil)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.rank:SetText(r.index .. ".")
    r.name:SetText(plain and (C_Spell.GetSpellName(id) or "") or "")
    M.PaintValue(r.value, { }, db.valueFormat, spell.totalAmount, spell.amountPerSecond)
    r.mine:Hide()
end

-- Spells of the focused source (out of combat only: the GUID must be plain to be passed back to the API).
local function breakdown(win, cfg)
    local f, DM = win.focus, C_DamageMeter
    local ok, s
    if cfg.segment and cfg.segment > 0 and DM.GetCombatSessionSourceFromID then
        ok, s = pcall(DM.GetCombatSessionSourceFromID, cfg.segment, cfg.type, f.guid, f.creature)
    elseif DM.GetCombatSessionSourceFromType then
        ok, s = pcall(DM.GetCombatSessionSourceFromType, cfg.overall and SESSION_OVERALL or SESSION_CURRENT, cfg.type,
            f.guid, f.creature)
    end
    return ok and s or nil
end
M.ReadBreakdown = breakdown

local function visible(db)
    local movers = ns:GetModule("Movers")
    if movers and movers:IsUnlocked() then return true end
    if db.visibility == "combat" then return InCombatLockdown() or UnitAffectingCombat("player") end
    if db.visibility == "group" then return IsInGroup() end
    return true
end

function M:PaintWindow(win)
    local db, cfg = self.db.meter, cfgOf(win.id)
    local mode = M.Mode(cfg.type)
    local rowsH = db.rows * (db.rowHeight + db.spacing) - db.spacing
    win:SetSize(db.width, HEADER_H + 4 + rowsH)
    win:ClearAllPoints()
    win:SetPoint(cfg.point, UIParent, cfg.point, cfg.x, cfg.y)
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    win:SetAlpha(inCombat and 1 or db.idleAlpha)
    if win.focus then win.mode:SetLabel("< " .. win.focus.name) else win.mode:SetLabel(L[mode.text]) end
    win.segment:SetShown(not win.focus)
    win.segment:SetLabel(cfg.segment > 0 and L.DM_SEG_SAVED or (cfg.overall and L.DM_SEG_OVERALL or L.DM_SEG_CURRENT))
    win.clock:SetText(db.clock and M.Clock(duration(cfg)) or "")
    local list, maxAmount
    if win.focus then
        local s = breakdown(win, cfg)
        list = s and s.combatSpells or {}
        if s then maxAmount = s.maxAmount end
    else
        local s = session(cfg)
        list = s and s.combatSources or {}
        if s then maxAmount = s.maxAmount end
    end
    local width = db.width - 4
    local shown = math.min(#list, db.rows)
    for i = 1, math.max(#win.rows, db.rows) do
        local r = win.rows[i] or (i <= db.rows and makeRow(win, i))
        if r then
            local e = i <= shown and list[i]
            r:SetShown(e and true or false)
            if e then
                layoutRow(r, db, (i - 1) * (db.rowHeight + db.spacing), width)
                if win.focus then paintSpell(r, db, e, maxAmount) else paintSource(r, db, mode, e, maxAmount) end
            end
        end
    end
    win.empty:SetShown(shown == 0)
end

function M:RefreshMeter()
    self.dirty = false
    local on = self:UsesPhoenixMeter()
    local db = self.db.meter
    for i = 1, MAX_WINDOWS do
        local want = on and i <= db.windows
        local win = wins[i] or (want and build(i))
        if win then
            if want and visible(db) then ns.SafeCall(self.PaintWindow, self, win); win:Show() else win:Hide() end
        end
    end
    self:UpdateClockTicker()
end

-- Coalesce bursts of meter events into one repaint after `rate` seconds.
function M:QueueMeter()
    if self.dirty then return end
    self.dirty = true
    C_Timer.After(self.db.meter.rate, function() if M.dirty then ns.SafeCall(M.RefreshMeter, M) end end)
end

function M:UpdateClockTicker()
    local want = self:UsesPhoenixMeter() and self.db.meter.clock and (InCombatLockdown() or UnitAffectingCombat("player"))
    if want and not self.clockTicker then
        self.clockTicker = C_Timer.NewTicker(1, function()
            for i, win in pairs(wins) do
                if win:IsShown() then win.clock:SetText(M.Clock(duration(cfgOf(i))) or "") end
            end
        end)
    elseif not want and self.clockTicker then
        self.clockTicker:Cancel()
        self.clockTicker = nil
    end
end

---------------------------------------------------------------- interaction
function M:OpenBreakdown(win, index)
    if win.focus then return end
    local s = session(cfgOf(win.id))
    local src = s and s.combatSources and s.combatSources[index]
    if not src then return end
    local guid, name = src.sourceGUID, src.name
    if Secret.IsSecret(guid) or Secret.IsSecret(name) or M.Mode(cfgOf(win.id).type).deaths then
        UIErrorsFrame:AddMessage(L.DM_BREAKDOWN_LATER, Theme:Color("text.secondary"))
        return
    end
    win.focus = { guid = guid, creature = src.sourceCreatureID, name = name or "?" }
    self:RefreshMeter()
end

function M:Back(win)
    if not win.focus then return end
    win.focus = nil
    self:RefreshMeter()
end

function M:RowTooltip(win, r)
    GameTooltip:SetOwner(r, "ANCHOR_LEFT")
    GameTooltip:SetText(r.name:GetText())
    if not win.focus then
        GameTooltip:AddLine(L.DM_TIP_CLICK, Theme:Color("text.secondary"))
    end
    GameTooltip:Show()
end

function M:ResetData()
    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then C_DamageMeter.ResetAllCombatSessions() end
    for _, win in pairs(wins) do win.focus = nil end
    self:RefreshMeter()
end

-- Blizzard's own meter window is switched off while the Phoenix windows are in use (deferred out of combat);
-- the API keeps recording either way. Switching back restores what the player had.
function M:ApplyEngine(off)
    if not self:MeterAvailable() then return end
    local phoenix = not off and self:UsesPhoenixMeter()
    local saved = self.db.meter
    if phoenix then
        if saved.blizzardWas == nil then saved.blizzardWas = C_CVar.GetCVarBool("damageMeterEnabled") and true or false end
        ns.Combat:Run("cvar.damageMeterEnabled", C_CVar.SetCVar, "damageMeterEnabled", "0")
    elseif saved.blizzardWas ~= nil then
        ns.Combat:Run("cvar.damageMeterEnabled", C_CVar.SetCVar, "damageMeterEnabled", saved.blizzardWas and "1" or "0")
        saved.blizzardWas = nil
    end
end

function M:SetupMeter()
    if not self:MeterAvailable() then return end
    if not self.meterHooked then
        self.meterHooked = true
        local function queue() if M:IsEnabled() then M:QueueMeter() end end
        local function now() if M:IsEnabled() then ns.SafeCall(M.RefreshMeter, M) end end
        for _, e in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED" }) do
            ns.Events:On(e, OWNER, queue)
        end
        ns.Events:On("DAMAGE_METER_RESET", OWNER, now)
        for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
            ns.Events:On(e, OWNER, now)
        end
    end
    self:ApplyEngine()
    self:RefreshMeter()
end

-- Plugin switched off (live): windows and the clock go away, Blizzard's meter comes back as it was.
function M:StopMeter()
    for _, win in pairs(wins) do win:Hide() end
    if self.clockTicker then self.clockTicker:Cancel(); self.clockTicker = nil end
    self:ApplyEngine(true)
end
