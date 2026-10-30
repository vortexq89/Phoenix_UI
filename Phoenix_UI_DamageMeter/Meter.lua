local _, ns = ...
local L, Skin, Theme, W, Secret = ns.L, ns.Skin, ns.Theme, ns.Widgets, ns.Secret
local M = ns.modules.DamageMeter

--[[ Phoenix damage meter windows (docs/DAMAGE_METER.md). Data comes only from Blizzard's C_DamageMeter API, the
    same source EllesmereUI's meter reads; the code here is Phoenix's own. In combat amounts, rates and other
    players' names are secret: they go straight to StatusBar:SetValue, AbbreviateNumbers and SetFormattedText and are
    never compared, sorted, added or stored. Everything that needs arithmetic (spell tooltips, per-target lists,
    compare, report, the per-fight graph) runs only on plain values, which the game hands out after combat.
    Never-secret fields (classFilename, specIconID, isLocalPlayer, deathRecapID) drive colours, icons, role filters
    and pinning. Repaints are coalesced on C_Timer (no OnUpdate); the clock ticker exists only in combat.
    Views of one window: list (players), spells (one player), targets (one player), compare (two players), graph
    (your amount per recorded fight). ]]

local OWNER = {}
local MAX_WINDOWS = 3
local wins = {}
M.meterWindows = wins

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
local function plainNumber(v) return type(v) == "number" and not Secret.IsSecret(v) end
local function inCombat() return InCombatLockdown() or UnitAffectingCombat("player") end

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
local ENEMY_TAKEN = 10

-- Window presets: { windows = n, types for window 1..n }.
M.PRESETS = {
    solo = { 0 }, dps = { 1, 8 }, healer = { 3, 4, 6 }, tank = { 7, 0, 5 }, raid = { 1, 3, 9 }, mplus = { 0, 5, 8 },
}

local SESSION_OVERALL, SESSION_CURRENT = 0, 1

function M:MeterAvailable()
    return C_DamageMeter ~= nil and C_DamageMeter.GetCombatSessionFromType ~= nil
end
function M:UsesPhoenixMeter() return self:IsEnabled() and self.db.engine == "phoenix" and self:MeterAvailable() end

local function cfgOf(i) return M.db.meter["win" .. i] end

---------------------------------------------------------------- data (secret-safe)
local function sessionType(cfg) return cfg.overall and SESSION_OVERALL or SESSION_CURRENT end

local function session(cfg, meterType)
    local DM, t = C_DamageMeter, meterType or cfg.type
    local ok, s
    if cfg.segment and cfg.segment > 0 and DM.GetCombatSessionFromID then
        ok, s = pcall(DM.GetCombatSessionFromID, cfg.segment, t)
        if ok and s then return s end
    end
    ok, s = pcall(DM.GetCombatSessionFromType, sessionType(cfg), t)
    return ok and s or nil
end
M.ReadSession = session

local function sourceDetail(cfg, meterType, guid, creature)
    local DM = C_DamageMeter
    local ok, s
    if cfg.segment and cfg.segment > 0 and DM.GetCombatSessionSourceFromID then
        ok, s = pcall(DM.GetCombatSessionSourceFromID, cfg.segment, meterType, guid, creature)
    elseif DM.GetCombatSessionSourceFromType then
        ok, s = pcall(DM.GetCombatSessionSourceFromType, sessionType(cfg), meterType, guid, creature)
    end
    return ok and s or nil
end

-- Fight length in whole seconds as "m:ss"; nil when unknown or secret.
function M.Clock(seconds)
    if not plainNumber(seconds) then return nil end
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
        local ok, d = pcall(DM.GetSessionDurationSeconds, sessionType(cfg))
        return ok and d or nil
    end
end

-- Fight length of window i's segment (the big timer follows window 1).
function M.Duration(i) return duration(cfgOf(i)) end

-- Value text: AbbreviateNumbers and SetFormattedText accept secret values. Formats: both "1.2M (8.1K)",
-- pipe "1.2M | 8.1K", total, rate.
M.FORMATS = { "both", "pipe", "total", "rate" }
function M.PaintValue(fs, mode, fmt, total, perSecond)
    if mode.deaths then fs:SetText("") return end
    if mode.rate or mode.count or fmt == "total" then fs:SetText(AbbreviateNumbers(total)) return end
    if fmt == "rate" then fs:SetText(AbbreviateNumbers(perSecond)) return end
    fs:SetFormattedText(fmt == "pipe" and "%s | %s" or "%s (%s)", AbbreviateNumbers(total), AbbreviateNumbers(perSecond))
end

-- Role of a spec icon (never secret), from the client's spec table: "TANK", "HEALER" or "DAMAGER".
local roleByIcon
function M.RoleOfIcon(icon)
    local map = roleByIcon
    if not map then
        map = {}
        local SI = C_SpecializationInfo
        if GetNumClasses and GetSpecializationInfoForClassID and SI and SI.GetNumSpecializationsForClassID then
            for classID = 1, tonumber((GetNumClasses())) or 0 do
                for i = 1, tonumber((SI.GetNumSpecializationsForClassID(classID))) or 0 do
                    local _, _, _, specIcon, role = GetSpecializationInfoForClassID(classID, i)
                    if specIcon then map[specIcon] = role end
                end
            end
        end
        if next(map) then roleByIcon = map end -- keep only a filled table (spec data may load late)
    end
    return icon and map[icon]
end

-- Visible list for a window: filtered by role (never-secret spec icon), with the player's own row pinned to the
-- last slot when it would fall off. Returns { { src, rank } ... }.
function M.VisibleSources(sources, db)
    local out, rank, mine = {}, 0, nil
    local filter = db.filter
    for _, src in ipairs(sources) do
        local keep = filter == "all" or M.RoleOfIcon(src.specIconID) == filter
        if keep then
            rank = rank + 1
            if #out < db.rows then out[#out + 1] = { src = src, rank = rank }
            elseif src.isLocalPlayer and not mine then mine = { src = src, rank = rank } end
        end
    end
    if mine and db.pinSelf and #out > 0 then out[#out] = mine end
    return out
end

---------------------------------------------------------------- frames
local function chip(parent, token)
    local b = CreateFrame("Button", nil, parent)
    b.text = W.Text(b, "small", token or "text.primary", "LEFT")
    b.text:SetPoint("LEFT", 6, 0)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self) self.bg:SetAlpha(0.4) end)
    b:SetScript("OnLeave", function(self) self.bg:SetAlpha(0.18) end)
    function b:SetLabel(text)
        self.text:SetText(text)
        self:SetWidth(math.max(22, (self.text:GetStringWidth() or 20) + 12))
    end
    return b
end

local function makeRow(win, i)
    local r = CreateFrame("StatusBar", nil, win.body)
    r:SetMinMaxValues(0, 1)
    r:SetValue(0)
    r.track = r:CreateTexture(nil, "BACKGROUND")
    r.track:SetAllPoints()
    r.alt = r:CreateTexture(nil, "ARTWORK", nil, 4) -- compare: the second player's amount as a thin line
    r.alt:SetPoint("BOTTOMLEFT")
    r.alt:SetHeight(3)
    r.sheen = r:CreateTexture(nil, "ARTWORK", nil, 3)
    r.sheen:SetPoint("TOPLEFT"); r.sheen:SetPoint("TOPRIGHT")
    r.icon = r:CreateTexture(nil, "OVERLAY")
    r.icon:SetPoint("LEFT", 2, 0)
    r.iconFrame = CreateFrame("Frame", nil, r) -- the icon border (Rows: icon border)
    r.iconFrame:SetAllPoints(r.icon)
    r.rank = W.Text(r, "small", "text.secondary", "RIGHT")
    r.name = W.Text(r, "small", "text.primary", "LEFT")
    r.value = W.Text(r, "small", "text.primary", "RIGHT")
    r.ilvl = W.Text(r, "small", "text.muted", "RIGHT") -- item level after the name (Rows: item level)
    r.mine = CreateFrame("Frame", nil, r)
    r.mine:SetAllPoints()
    r.slot = i
    if not win.preview then
        r:EnableMouse(true)
        r:SetScript("OnMouseUp", function(self, button) M:RowClick(win, self, button) end)
        r:SetScript("OnEnter", function(self) M:RowTooltip(win, self) end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    win.rows[i] = r
    return r
end

local function menu(owner, build)
    if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(owner, build) end
end

local function setView(win, view) win.view = view; M:RefreshMeter() end

local function modeMenu(win)
    menu(win.mode, function(_, root)
        for _, g in ipairs(M.MODES) do
            root:CreateTitle(L[g.title])
            for _, m in ipairs(g) do
                root:CreateRadio(L[m.label], function() return cfgOf(win.id).type == m.id end, function()
                    cfgOf(win.id).type = m.id
                    setView(win, nil)
                end)
            end
        end
    end)
end

local function segmentMenu(win)
    menu(win.segment, function(_, root)
        local cfg = cfgOf(win.id)
        local function pick(seg, overall)
            return function() cfg.segment, cfg.overall = seg, overall; setView(win, nil) end
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

local CHANNELS = {
    { value = "AUTO", label = "DM_CH_AUTO" }, { value = "PARTY", label = "DM_CH_PARTY" }, { value = "RAID", label = "DM_CH_RAID" },
    { value = "INSTANCE_CHAT", label = "DM_CH_INSTANCE" }, { value = "GUILD", label = "DM_CH_GUILD" },
    { value = "SELF", label = "DM_CH_SELF" },
}
M.CHANNELS = CHANNELS

local function windowMenu(win)
    menu(win.more, function(_, root)
        local db = M.db.meter
        local report = root:CreateButton(L.DM_REPORT)
        for _, ch in ipairs(CHANNELS) do
            report:CreateButton(L[ch.label], function() M:Report(win, ch.value) end)
        end
        root:CreateButton(L.DM_GRAPH, function() setView(win, { kind = "graph" }) end)
        root:CreateDivider()
        root:CreateTitle(L.DM_FILTER)
        for _, f in ipairs({ { "all", "DM_FILTER_ALL" }, { "TANK", "DM_FILTER_TANK" }, { "HEALER", "DM_FILTER_HEALER" },
            { "DAMAGER", "DM_FILTER_DAMAGER" } }) do
            root:CreateRadio(L[f[2]], function() return db.filter == f[1] end, function() db.filter = f[1]; M:RefreshMeter() end)
        end
        root:CreateDivider()
        root:CreateTitle(L.DM_PRESET)
        for _, p in ipairs({ "solo", "dps", "healer", "tank", "raid", "mplus" }) do
            root:CreateButton(L["DM_PRESET_" .. p:upper()], function() M:ApplyPreset(p) end)
        end
        root:CreateDivider()
        root:CreateCheckbox(L.DM_PIN_SELF, function() return db.pinSelf end, function() db.pinSelf = not db.pinSelf; M:RefreshMeter() end)
        root:CreateCheckbox(L.DM_LOCK, function() return db.lock end, function() db.lock = not db.lock; M:RefreshMeter() end)
    end)
end

local function build(i, parent)
    local win = CreateFrame("Frame", not parent and ("PhoenixUI_Meter" .. i) or nil, parent or UIParent)
    win.id, win.rows, win.preview = i, {}, parent ~= nil
    win:SetClampedToScreen(true)
    win.header = CreateFrame("Frame", nil, win)
    win.header:SetPoint("TOPLEFT"); win.header:SetPoint("TOPRIGHT")
    win.headerBg = win.header:CreateTexture(nil, "BACKGROUND", nil, 1) -- header colour (Windows: header colour)
    win.headerBg:SetAllPoints()
    win.line = win.header:CreateTexture(nil, "ARTWORK")
    win.line:SetPoint("BOTTOMLEFT"); win.line:SetPoint("BOTTOMRIGHT")
    win.line:SetHeight(1)
    win.mode = chip(win.header, "accent.primary")
    win.mode:SetPoint("LEFT", 3, 0)
    win.segment = chip(win.header, "text.secondary")
    win.segment:SetPoint("LEFT", win.mode, "RIGHT", 3, 0)
    win.more = chip(win.header, "text.secondary")
    win.more:SetPoint("RIGHT", -3, 0)
    win.more:SetLabel("...")
    win.reset = chip(win.header, "text.secondary")
    win.reset:SetPoint("RIGHT", win.more, "LEFT", -3, 0)
    win.reset:SetLabel(L.DM_RESET)
    win.clock = W.Text(win.header, "number", "text.secondary", "RIGHT")
    win.body = CreateFrame("Frame", nil, win)
    win.body:SetPoint("BOTTOMRIGHT", -2, 2)
    win.empty = W.Text(win.body, "small", "text.secondary", "CENTER")
    win.empty:SetPoint("CENTER")
    win.bars = {} -- graph columns
    if not win.preview then
        win.mode:SetScript("OnClick", function(_, button)
            if win.view then setView(win, nil) elseif button == "RightButton" then segmentMenu(win) else modeMenu(win) end
        end)
        win.segment:SetScript("OnClick", function() segmentMenu(win) end)
        win.reset:SetScript("OnClick", function() M:ResetData() end)
        win.more:SetScript("OnClick", function() windowMenu(win) end)
    end
    Skin:Register(win, function(self)
        Skin:Panel(self, "base", { border = "border.subtle" })
        M.PaintHeader(self)
        for _, c in ipairs({ self.mode, self.segment, self.reset, self.more }) do W.Color(c.bg, "bg.raised", 0.18) end
        M.styleGen = (M.styleGen or 0) + 1
    end)
    if not win.preview then
        local movers = ns:GetModule("Movers")
        if movers then
            movers:Register("dm.meter" .. i, win, L.DM_WINDOW_N:format(i), {
                active = function() return M:UsesPhoenixMeter() and i <= M.db.meter.windows and not M.db.meter.lock end,
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
    end
    return win
end

---------------------------------------------------------------- painting
-- Shared look of one row (real windows and the settings preview): texture, fonts, sizes, track and sheen.
function M:StyleRow(r, y, width)
    local db = self.db.meter
    local h = db.rowHeight
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetSize(width, h)
    r:SetStatusBarTexture(self:BarTexture())
    local tr, tg, tb = Theme:Color("bg.sunken")
    r.track:SetColorTexture(tr, tg, tb, db.trackAlpha)
    r.sheen:SetHeight(math.max(1, math.floor(h / 2)))
    r.sheen:SetColorTexture(1, 1, 1, db.sheen and 0.06 or 0)
    r.icon:SetSize(h - 2, h - 2)
    r.icon:SetShown(db.specIcon)
    if not db.specIcon then ns.SpecIcon:SetShown(r.icon, false) end
    local left = db.specIcon and h + 2 or 4
    r.rank:ClearAllPoints()
    r.rank:SetShown(db.rank)
    if db.rank then
        r.rank:SetPoint("LEFT", left, 0)
        r.rank:SetWidth(20)
        left = left + 22
    end
    -- text offsets (Rows: name / value offset) and the item level between them
    r.name:ClearAllPoints(); r.value:ClearAllPoints(); r.ilvl:ClearAllPoints()
    r.name:SetPoint("LEFT", left + db.nameX, db.nameY)
    r.value:SetPoint("RIGHT", -4 + db.valueX, db.valueY)
    r.ilvl:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
    r.ilvl:SetText("")
    r.name:SetPoint("RIGHT", db.ilvl == "name" and r.ilvl or r.value, "LEFT", -6, 0)
    r.iconFrame:SetShown(db.specIcon and db.iconBorder ~= "none")
    if r.styleGen ~= self.styleGen then
        r.styleGen = self.styleGen
        Skin:TextSpec(r.name, self.db.name, "unit", "text.primary")
        Skin:TextSpec(r.value, self.db.value, "number", "text.primary")
        Skin:TextSpec(r.rank, self.db.value, "number", "text.primary")
        Skin:TextSpec(r.ilvl, self.db.value, "number", "text.muted")
    end
    r.alt:Hide()
end

local function barColor(class)
    local db = M.db.meter
    if db.barColor == "class" and class then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    elseif db.barColor == "custom" then
        local c = db.customColor
        return c.r, c.g, c.b
    end
    local r, g, b = Theme:Color("accent.primary")
    return r, g, b
end

local function textColor(fs, on, class, token)
    local c = on and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then fs:SetTextColor(c.r, c.g, c.b) else fs:SetTextColor(Theme:Color(token)) end
end

-- Paints one source row: secret amounts and names only reach their sinks.
function M:PaintSource(r, mode, src, maxAmount, rank)
    local db = self.db.meter
    if mode.deaths then r:SetMinMaxValues(0, 1); r:SetValue(1)
    else r:SetMinMaxValues(0, maxAmount); r:SetValue(src.totalAmount) end
    local class = src.classFilename
    local cr, cg, cb = barColor(class)
    r:SetStatusBarColor(cr, cg, cb, db.barAlpha)
    if db.specIcon then
        if src.specIconID and src.specIconID ~= 0 then
            r.icon:SetTexture(src.specIconID)
            ns.SpecIcon:Apply(r.icon, db.iconStyle, class)
        else
            r.icon:SetTexture(nil)
            ns.SpecIcon:SetShown(r.icon, false)
        end
    end
    if db.specIcon and db.iconBorder ~= "none" then M.PaintIconBorder(r.iconFrame, db.iconBorder, class) end
    if db.ilvl == "name" then
        local il = M:ItemLevelOf(src)
        r.ilvl:SetText(il and tostring(il) or "")
        if il then r.ilvl:SetTextColor(M.ItemLevelColor(il)) end
    end
    r.rank:SetText(rank .. ".")
    r.name:SetText(src.name)
    textColor(r.name, db.nameClassColor, class, "text.primary")
    textColor(r.value, db.valueClassColor, class, "text.primary")
    M.PaintValue(r.value, mode, db.valueFormat, src.totalAmount, src.amountPerSecond)
    if src.isLocalPlayer then Skin:Border(r.mine, "accent.primary", 1); r.mine:Show() else r.mine:Hide() end
    r.src, r.rankShown = src, rank
end

local function spellLabel(id)
    if not plainNumber(id) then return "", nil end
    return C_Spell.GetSpellName(id) or "", C_Spell.GetSpellTexture(id)
end

local function paintSpell(r, spell, maxAmount, rank, other, otherMax)
    local db = M.db.meter
    r:SetMinMaxValues(0, maxAmount)
    r:SetValue(spell.totalAmount)
    r:SetStatusBarColor(barColor(nil))
    local name, icon = spellLabel(spell.spellID)
    r.icon:SetTexture(icon)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.rank:SetText(rank .. ".")
    r.name:SetText(name)
    r.name:SetTextColor(Theme:Color("text.primary"))
    r.value:SetTextColor(Theme:Color("text.primary"))
    if other ~= nil then -- compare (plain values only): "A | B", B as a thin line under the bar
        r.value:SetFormattedText("%s |cff8a8f99| %s|r", AbbreviateNumbers(spell.totalAmount), AbbreviateNumbers(other))
        local w = r:GetWidth() or 0
        local frac = (otherMax and otherMax > 0) and math.min(1, other / otherMax) or 0
        r.alt:SetWidth(math.max(1, w * frac))
        r.alt:SetColorTexture(Theme:Color("text.primary"))
        r.alt:SetShown(frac > 0)
    else
        M.PaintValue(r.value, {}, db.valueFormat, spell.totalAmount, spell.amountPerSecond)
    end
    r.mine:Hide()
    r.spellID = plainNumber(spell.spellID) and spell.spellID or nil
    r.src = nil
end

local function paintPlain(r, name, amount, maxAmount, rank, class)
    r:SetMinMaxValues(0, maxAmount > 0 and maxAmount or 1)
    r:SetValue(amount)
    r:SetStatusBarColor(barColor(class))
    r.icon:SetTexture(nil)
    r.rank:SetText(rank .. ".")
    r.name:SetText(name)
    r.value:SetText(AbbreviateNumbers(amount))
    r.mine:Hide()
    r.src, r.spellID = nil, nil
end

-- Per-target list of one player (plain values only): the enemies they hit, read from Enemy Damage Taken.
function M.Targets(cfg, playerName)
    local s = session(cfg, ENEMY_TAKEN)
    local out = {}
    if not (s and plain(playerName)) then return out end
    for _, enemy in ipairs(s.combatSources or {}) do
        if plain(enemy.sourceGUID) and plain(enemy.name) then
            local d = sourceDetail(cfg, ENEMY_TAKEN, enemy.sourceGUID, enemy.sourceCreatureID)
            local total = 0
            for _, spell in ipairs(d and d.combatSpells or {}) do
                local det = spell.combatSpellDetails
                if det and plain(det.unitName) and det.unitName == playerName and plainNumber(spell.totalAmount) then
                    total = total + spell.totalAmount
                end
            end
            if total > 0 then out[#out + 1] = { name = enemy.name, amount = total } end
        end
    end
    table.sort(out, function(a, b) return a.amount > b.amount end)
    return out
end

-- Your amount in each recorded fight (plain values only), oldest first: { { name, amount } ... }.
function M.FightSeries(meterType, limit)
    local DM, out = C_DamageMeter, {}
    local list = DM.GetAvailableCombatSessions and DM.GetAvailableCombatSessions() or {}
    for i = math.max(1, #list - (limit or 12) + 1), #list do
        local s = list[i]
        local ok, data = pcall(DM.GetCombatSessionFromID, s.sessionID, meterType)
        local amount = 0
        for _, src in ipairs(ok and data and data.combatSources or {}) do
            if src.isLocalPlayer and plainNumber(src.totalAmount) then amount = src.totalAmount end
        end
        out[#out + 1] = { name = s.name ~= "" and s.name or L.DM_SEG_FIGHT:format(i), amount = amount,
            clock = M.Clock(s.durationSeconds) }
    end
    return out
end

local function hideRows(win, from)
    for i = from, #win.rows do win.rows[i]:Hide() end
end

local function paintGraph(win, width, height)
    local cfg = cfgOf(win.id)
    local series = inCombat() and {} or M.FightSeries(cfg.type, 12)
    local top = 0
    for _, p in ipairs(series) do if p.amount > top then top = p.amount end end
    local n = #series
    local gap = 3
    local bw = n > 0 and math.max(4, math.floor((width - gap * (n - 1)) / n)) or 0
    for i = 1, math.max(n, #win.bars) do
        local b = win.bars[i]
        if not b and i <= n then
            b = CreateFrame("Frame", nil, win.body)
            b.fill = b:CreateTexture(nil, "ARTWORK")
            b.fill:SetPoint("BOTTOMLEFT"); b.fill:SetPoint("BOTTOMRIGHT")
            b.label = W.Text(b, "small", "text.secondary", "CENTER")
            b.label:SetPoint("BOTTOM", b, "TOP", 0, 2)
            b:EnableMouse(true)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.point.name)
                GameTooltip:AddDoubleLine(L[M.Mode(cfgOf(win.id).type).label], AbbreviateNumbers(self.point.amount), 0.7, 0.7, 0.7, 1, 1, 1)
                if self.point.clock then GameTooltip:AddDoubleLine(L.DM_CLOCK, self.point.clock, 0.7, 0.7, 0.7, 1, 1, 1) end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            win.bars[i] = b
        end
        if b then
            local p = series[i]
            b:SetShown(p ~= nil)
            if p then
                b.point = p
                b:ClearAllPoints()
                b:SetPoint("BOTTOMLEFT", (i - 1) * (bw + gap), 0)
                b:SetSize(bw, height - 14)
                local frac = top > 0 and p.amount / top or 0
                b.fill:SetHeight(math.max(1, (height - 14) * frac))
                local r, g, bl = Theme:Color("accent.primary")
                b.fill:SetColorTexture(r, g, bl, i == n and 1 or 0.55)
                b.label:SetText(i == n and AbbreviateNumbers(p.amount) or "")
            end
        end
    end
    win.empty:SetText(inCombat() and L.DM_AFTER_COMBAT or L.DM_EMPTY)
    win.empty:SetShown(n == 0)
end

local function visible(db)
    if M.hiddenByKey then return false end
    local movers = ns:GetModule("Movers")
    if movers and movers:IsUnlocked() then return true end
    if db.visibility == "combat" then return inCombat() end
    if db.visibility == "group" then return IsInGroup() end
    return true
end

-- Lays out the window frame; returns the body width and row area height.
function M:LayoutWindow(win)
    local db = self.db.meter
    local hh = db.headerHeight
    local rowsH = db.rows * (db.rowHeight + db.spacing) - db.spacing
    win:SetSize(db.width, hh + 4 + rowsH)
    win.header:SetHeight(hh)
    for _, c in ipairs({ win.mode, win.segment, win.reset, win.more }) do c:SetHeight(hh - 6) end
    win.reset:SetShown(not db.hideReset)
    win.clock:ClearAllPoints()
    win.clock:SetPoint("RIGHT", db.hideReset and win.more or win.reset, "LEFT", -6, 0)
    win.body:SetPoint("TOPLEFT", 2, -hh - 2)
    M.PaintHeader(win)
    return db.width - 4, rowsH
end

-- Spells, compare and targets views of one window; returns the rows shown.
function M:PaintDetail(win, cfg, view, row)
    local db = self.db.meter
    if view.kind == "targets" then
        win.mode:SetLabel("< " .. view.name .. " · " .. L.DM_TARGETS)
        local list = M.Targets(cfg, view.name)
        local top = list[1] and list[1].amount or 1
        for i = 1, math.min(#list, db.rows) do paintPlain(row(i), list[i].name, list[i].amount, top, i) end
        return math.min(#list, db.rows)
    end
    win.mode:SetLabel("< " .. view.name .. (view.kind == "compare" and (" vs " .. view.otherName) or ""))
    local d = sourceDetail(cfg, cfg.type, view.guid, view.creature)
    local spells = d and d.combatSpells or {}
    local other, otherMax = nil, 0
    if view.kind == "compare" then
        other = {}
        local o = sourceDetail(cfg, cfg.type, view.otherGuid, view.otherCreature)
        for _, sp in ipairs(o and o.combatSpells or {}) do
            if plainNumber(sp.spellID) and plainNumber(sp.totalAmount) then
                other[sp.spellID] = sp.totalAmount
                if sp.totalAmount > otherMax then otherMax = sp.totalAmount end
            end
        end
    end
    for i = 1, math.min(#spells, db.rows) do
        local sp = spells[i]
        local b = other and (plainNumber(sp.spellID) and other[sp.spellID] or 0) or nil
        paintSpell(row(i), sp, d.maxAmount, i, b, otherMax)
    end
    return math.min(#spells, db.rows)
end

function M:PaintWindow(win)
    local db, cfg = self.db.meter, cfgOf(win.id)
    local mode = M.Mode(cfg.type)
    local width, height = self:LayoutWindow(win)
    win:ClearAllPoints()
    win:SetPoint(cfg.point, UIParent, cfg.point, cfg.x, cfg.y)
    win:SetAlpha(inCombat() and 1 or db.idleAlpha)
    win:EnableMouse(not db.lock)
    for _, c in ipairs({ win.mode, win.segment, win.reset, win.more }) do c:EnableMouse(not db.lock) end
    local view = win.view
    win.segment:SetShown(not view)
    win.segment:SetLabel(cfg.segment > 0 and L.DM_SEG_SAVED or (cfg.overall and L.DM_SEG_OVERALL or L.DM_SEG_CURRENT))
    win.clock:SetText(db.clock and M.Clock(duration(cfg)) or "")
    win.empty:SetText(L.DM_EMPTY)
    local step = db.rowHeight + db.spacing
    for _, b in ipairs(win.bars) do b:SetShown(view and view.kind == "graph" or false) end
    if view and view.kind == "graph" then
        win.mode:SetLabel("< " .. L.DM_GRAPH)
        hideRows(win, 1)
        return paintGraph(win, width, height)
    end
    local shown
    local function row(i)
        local r = win.rows[i] or makeRow(win, i)
        r:Show()
        self:StyleRow(r, (i - 1) * step, width)
        if win.locked ~= db.lock then r:EnableMouse(not db.lock) end
        return r
    end
    if not view then
        win.mode:SetLabel(L[mode.text] .. (db.filter ~= "all" and (" · " .. L["DM_FILTER_" .. db.filter]) or ""))
        local s = session(cfg)
        local list = M.VisibleSources(s and s.combatSources or {}, db)
        for i, e in ipairs(list) do self:PaintSource(row(i), mode, e.src, s.maxAmount, e.rank) end
        shown = #list
    else
        shown = self:PaintDetail(win, cfg, view, row)
    end
    win.locked = db.lock
    hideRows(win, shown + 1)
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
    self:UpdateBigTimer()
    self:UpdateClockTicker()
    self:ApplyKeys()
end

-- Coalesce bursts of meter events into one repaint after `rate` seconds.
function M:QueueMeter()
    if self.dirty then return end
    self.dirty = true
    C_Timer.After(self.db.meter.rate, function() if M.dirty then ns.SafeCall(M.RefreshMeter, M) end end)
end

function M:UpdateClockTicker()
    local db = self.db.meter
    local want = self:UsesPhoenixMeter() and (db.clock or db.bigTimer.enabled) and inCombat()
    if want and not self.clockTicker then
        self.clockTicker = C_Timer.NewTicker(1, function()
            for i, win in pairs(wins) do
                if win:IsShown() and M.db.meter.clock then win.clock:SetText(M.Clock(duration(cfgOf(i))) or "") end
            end
            M:PaintBigTimer()
        end)
    elseif not want and self.clockTicker then
        self.clockTicker:Cancel()
        self.clockTicker = nil
    end
end

---------------------------------------------------------------- interaction
local function tell(text) UIErrorsFrame:AddMessage(text, Theme:Color("text.secondary")) end

-- Plain identity of the source behind a row, or nil (in combat GUIDs and names are secret).
local function plainSource(r)
    local src = r.src
    if not src or not plain(src.sourceGUID) or not plain(src.name) then return nil end
    return { guid = src.sourceGUID, creature = src.sourceCreatureID, name = src.name }
end

-- Click: spells. Shift-click: targets. Ctrl-click two players: compare. Right-click: back.
function M:RowClick(win, r, button)
    if button == "RightButton" then if win.view then setView(win, nil) end return end
    if win.view then return end
    local mode = M.Mode(cfgOf(win.id).type)
    if mode.deaths then return end
    local who = plainSource(r)
    if not who then tell(L.DM_BREAKDOWN_LATER) return end
    if IsControlKeyDown() then
        local a = win.compareFrom
        if a and a.guid ~= who.guid then
            win.compareFrom = nil
            return setView(win, { kind = "compare", guid = a.guid, creature = a.creature, name = a.name,
                otherGuid = who.guid, otherCreature = who.creature, otherName = who.name })
        end
        win.compareFrom = who
        return tell(L.DM_COMPARE_PICK:format(who.name))
    end
    who.kind = IsShiftKeyDown() and "targets" or "spells"
    setView(win, who)
end

-- Last hits before a death (Deaths mode), from the client's death recap; secret fields are skipped.
function M.RecapLines(recapID, limit)
    local out = {}
    if not (plainNumber(recapID) and recapID > 0 and C_DeathRecap and C_DeathRecap.GetRecapEvents) then return out end
    local ok, events = pcall(C_DeathRecap.GetRecapEvents, recapID)
    if not (ok and type(events) == "table") then return out end
    for i = 1, math.min(#events, limit or 5) do
        local e = events[i]
        local name = plain(e.spellName) and e.spellName or (plain(e.event) and e.event) or "?"
        local amount = plainNumber(e.amount) and AbbreviateNumbers(e.amount) or ""
        local hp = plainNumber(e.currentHP) and AbbreviateNumbers(e.currentHP) or nil
        out[#out + 1] = { name = name, amount = amount, hp = hp }
    end
    return out
end

function M:RowTooltip(win, r)
    if not self.db.meter.tooltip then return end
    GameTooltip:SetOwner(r, "ANCHOR_LEFT")
    if r.spellID then
        GameTooltip:SetSpellByID(r.spellID)
        return GameTooltip:Show()
    end
    GameTooltip:SetText(r.name:GetText())
    local src = r.src
    if src and not win.view and self.db.meter.ilvl ~= "off" then
        local il = M:ItemLevelOf(src)
        if il then GameTooltip:AddLine(L.DM_ILVL_TIP:format(il), M.ItemLevelColor(il)) end
    end
    if src and not win.view then
        local mode = M.Mode(cfgOf(win.id).type)
        if mode.deaths then
            GameTooltip:AddLine(L.DM_RECAP, Theme:Color("accent.primary"))
            for _, e in ipairs(M.RecapLines(src.deathRecapID, 6)) do
                GameTooltip:AddDoubleLine(e.name, e.amount .. (e.hp and ("  |cff8a8f99" .. e.hp .. "|r") or ""), 1, 1, 1, 1, 0.4, 0.4)
            end
        else
            local who = plainSource(r)
            if who then
                local d = sourceDetail(cfgOf(win.id), cfgOf(win.id).type, who.guid, who.creature)
                local spells = d and d.combatSpells or {}
                if #spells > 0 then GameTooltip:AddLine(L.DM_TOP_SPELLS, Theme:Color("accent.primary")) end
                for i = 1, math.min(#spells, 6) do
                    local name = spellLabel(spells[i].spellID)
                    GameTooltip:AddDoubleLine(name, AbbreviateNumbers(spells[i].totalAmount), 1, 1, 1, 1, 1, 1)
                end
            else
                GameTooltip:AddLine(L.DM_BREAKDOWN_LATER, Theme:Color("text.secondary"))
            end
            GameTooltip:AddLine(L.DM_TIP_CLICK, Theme:Color("text.secondary"))
        end
    end
    GameTooltip:Show()
end

-- Report the window's top rows to chat (plain values only, so after combat).
function M.ReportLines(win, count)
    local cfg = cfgOf(win.id)
    local mode = M.Mode(cfg.type)
    local s = session(cfg)
    local lines = { L.DM_REPORT_HEAD:format(L[mode.label],
        cfg.segment > 0 and L.DM_SEG_SAVED or (cfg.overall and L.DM_SEG_OVERALL or L.DM_SEG_CURRENT)) }
    for i, src in ipairs(s and s.combatSources or {}) do
        if i > count then break end
        if not (plain(src.name) and plainNumber(src.totalAmount)) then return nil end
        lines[#lines + 1] = ("%d. %s  %s"):format(i, src.name, AbbreviateNumbers(src.totalAmount))
    end
    return lines
end

function M.ResolveChannel(ch)
    if ch ~= "AUTO" then return ch end
    if IsInGroup(2) then return "INSTANCE_CHAT" end -- 2: LE_PARTY_CATEGORY_INSTANCE
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return "SELF"
end

function M:Report(win, ch)
    local lines = not inCombat() and M.ReportLines(win, self.db.meter.reportLines)
    if not lines then return tell(L.DM_AFTER_COMBAT) end
    local channel = M.ResolveChannel(ch)
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage
    if not send then channel = "SELF" end
    for _, line in ipairs(lines) do
        if channel == "SELF" then DEFAULT_CHAT_FRAME:AddMessage(line) else send(line, channel) end
    end
end

function M:ApplyPreset(key)
    local p = M.PRESETS[key]
    if not p then return end
    local db = self.db.meter
    db.windows = #p
    for i, t in ipairs(p) do cfgOf(i).type, cfgOf(i).segment, cfgOf(i).overall = t, 0, false end
    for _, win in pairs(wins) do win.view = nil end
    self:RefreshMeter()
end

function M:ResetData()
    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then C_DamageMeter.ResetAllCombatSessions() end
    for _, win in pairs(wins) do win.view, win.compareFrom = nil, nil end
    self:RefreshMeter()
end

function M:ToggleShown()
    self.hiddenByKey = not self.hiddenByKey
    self:RefreshMeter()
end

---------------------------------------------------------------- keybinds (override bindings, out of combat)
local keyOwner = CreateFrame("Frame")
local toggleBtn = CreateFrame("Button", "PhoenixUI_MeterToggle", UIParent)
toggleBtn:Hide()
toggleBtn:SetScript("OnClick", function() M:ToggleShown() end)
local resetBtn = CreateFrame("Button", "PhoenixUI_MeterReset", UIParent)
resetBtn:Hide()
resetBtn:SetScript("OnClick", function() M:ResetData() end)

function M:ApplyKeys(off)
    local db = self.db.meter
    local sig = off and "" or (tostring(db.toggleKey) .. "|" .. tostring(db.resetKey) .. tostring(self:UsesPhoenixMeter()))
    if sig == self.keySig then return end
    self.keySig = sig
    local movers = ns:GetModule("Movers")
    local norm = movers and movers.NormalizeKey or function() return nil end
    ns.Combat:Run("dm.keys", function()
        ClearOverrideBindings(keyOwner)
        if off or not M:UsesPhoenixMeter() then return end
        local t, r = norm(db.toggleKey), norm(db.resetKey)
        if t then SetOverrideBindingClick(keyOwner, true, t, toggleBtn:GetName(), "LeftButton") end
        if r then SetOverrideBindingClick(keyOwner, true, r, resetBtn:GetName(), "LeftButton") end
    end)
end

---------------------------------------------------------------- settings preview (the real row code, sample data)
local SAMPLE = {
    -- name, -, class, total, per second, you, spec icon (file ids: Fire, Retribution, Beast Mastery, Protection, Holy)
    { "PREVIEW_PARTY_DPS1", 1, "MAGE", 2410000, 26800, false, 135810 },
    { "PREVIEW_UNIT_PLAYER", 0.86, "PALADIN", 2070000, 23000, true, 135873 },
    { "PREVIEW_PARTY_DPS2", 0.74, "HUNTER", 1780000, 19800, false, 461112 },
    { "PREVIEW_PARTY_TANK", 0.41, "WARRIOR", 988000, 11000, false, 132341 },
    { "PREVIEW_PARTY_HEALER", 0.12, "PRIEST", 290000, 3200, false, 237542 },
}
function M:BuildPreview(parent)
    local win = build(1, parent)
    win.mode:SetLabel(L.DM_SHORT_DAMAGE)
    return win, function()
        local db = self.db.meter
        local keepRows = db.rows
        db.rows = #SAMPLE
        local width = self:LayoutWindow(win)
        db.rows = keepRows
        win.segment:SetLabel(L.DM_SEG_CURRENT)
        win.clock:SetText(db.clock and "2:41" or "")
        win.empty:Hide()
        local mode = M.Mode(0)
        for i, s in ipairs(SAMPLE) do
            local r = win.rows[i] or makeRow(win, i)
            r:Show()
            self:StyleRow(r, (i - 1) * (db.rowHeight + db.spacing), width)
            self:PaintSource(r, mode, { name = L[s[1]], classFilename = s[3], totalAmount = s[4], amountPerSecond = s[5],
                isLocalPlayer = s[6], specIconID = s[7] }, SAMPLE[1][4], i)
        end
    end
end

---------------------------------------------------------------- engine and lifecycle
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
    self:SetupExtras()
    self:RefreshMeter()
end

-- Plugin switched off (live): windows, keys and the clock go away, Blizzard's meter comes back as it was.
function M:StopMeter()
    for _, win in pairs(wins) do win:Hide() end
    if self.clockTicker then self.clockTicker:Cancel(); self.clockTicker = nil end
    self:StopExtras()
    self:ApplyKeys(true)
    self:ApplyEngine(true)
end
