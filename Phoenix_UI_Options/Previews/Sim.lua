local _, ns = ...
local L, P, W, Skin, Theme = ns.L, ns.Previews, ns.Widgets, ns.Skin, ns.Theme

--[[ The Sim results card: DPS, the compared sets with their gain or loss, or the stat weights. One painter for
    the page's results card and the pinned preview (sample result), so both always look the same. ]]
local C = {}
ns.SimCard = C

local ROWS, ROW_H = 6, 22
local STYLE_KEY = { Patchwerk = "PATCHWERK", CastingPatchwerk = "CASTING", LightMovement = "LIGHT",
    HeavyMovement = "HEAVY", HecticAddCleave = "HECTIC", DungeonSlice = "SLICE", DungeonRoute = "ROUTE" }
local STAT_KEY = { Str = "STR", Agi = "AGI", Int = "INT", Crit = "CRIT", Haste = "HASTE", Mastery = "MASTERY", Vers = "VERS" }
local MODES = { gear = true, compare = true, best = true, weights = true }

function C.ModeLabel(mode) return MODES[mode] and L["SIM_MODE_" .. mode:upper()] or tostring(mode or "") end
function C.StyleLabel(style) return STYLE_KEY[style] and L["SIM_FIGHT_" .. STYLE_KEY[style]] or tostring(style or "") end
local function statLabel(stat) return STAT_KEY[stat] and L["SIM_STAT_" .. STAT_KEY[stat]] or stat end

local function big(n) return BreakUpLargeNumbers(math.floor((n or 0) + 0.5)) end
C.Big = big

function C:New(parent)
    local c = CreateFrame("Frame", nil, parent)
    c.dps = W.Text(c, "number", "text.primary")
    c.dps:SetPoint("TOPLEFT", 0, -2)
    c.unit = W.Text(c, "small", "text.muted")
    c.unit:SetPoint("BOTTOMLEFT", c.dps, "BOTTOMRIGHT", 6, 3)
    c.when = W.Text(c, "small", "text.muted", "RIGHT")
    c.when:SetPoint("TOPRIGHT", 0, -4)
    c.sub = W.Text(c, "desc", "text.secondary")
    c.sub:SetPoint("TOPLEFT", c.dps, "BOTTOMLEFT", 0, -4)
    c.sub:SetPoint("RIGHT")
    c.note = W.Text(c, "desc", "text.muted")
    c.note:SetPoint("TOPLEFT", c.sub, "BOTTOMLEFT", 0, -10)
    c.note:SetPoint("RIGHT")
    c.note:SetWordWrap(true)
    c.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, c)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", c.sub, "BOTTOMLEFT", 0, -8 - (i - 1) * ROW_H)
        r:SetPoint("RIGHT", c, "RIGHT")
        r.track = W.Texture(r, "BACKGROUND", 1)
        r.track:SetPoint("BOTTOMLEFT", 0, 2); r.track:SetPoint("BOTTOMRIGHT", 0, 2)
        r.track:SetHeight(3)
        r.fill = W.Texture(r, "BACKGROUND", 2)
        r.fill:SetPoint("BOTTOMLEFT", r.track, "BOTTOMLEFT")
        r.fill:SetHeight(3)
        r.label = W.Text(r, "body", "text.primary")
        r.label:SetPoint("LEFT", 0, 2)
        r.delta = W.Text(r, "number", "text.primary", "RIGHT")
        r.delta:SetPoint("RIGHT", 0, 2)
        r.delta:SetWidth(120)
        r.value = W.Text(r, "number", "text.secondary", "RIGHT")
        r.value:SetPoint("RIGHT", r.delta, "LEFT", -8, 0)
        r.value:SetWidth(80)
        r.label:SetPoint("RIGHT", r.value, "LEFT", -8, 0)
        c.rows[i] = r
    end
    Skin:Register(c, function(self)
        Skin:Text(self.dps, "number", "text.primary", 24)
        Skin:Text(self.unit, "small", "text.muted")
        Skin:Text(self.when, "small", "text.muted")
        Skin:Text(self.sub, "desc", "text.secondary")
        for _, r in ipairs(self.rows) do
            W.Color(r.track, "bg.hover", 0.6)
            Skin:Text(r.label, "body", "text.primary"); Skin:Text(r.value, "number", "text.secondary")
        end
        if self.last then C:Paint(self, self.last) end
    end)
    c.height = 44 + 8 + ROWS * ROW_H
    return c
end

local function fightText(f)
    if not f or f.style == "" then return "" end
    local parts = { C.StyleLabel(f.style) }
    if (f.length or 0) > 0 then parts[#parts + 1] = L.SIM_FIGHT_LENGTH:format(math.floor(f.length / 60 + 0.5)) end
    if (f.targets or 0) > 1 then parts[#parts + 1] = L.SIM_FIGHT_TARGETS:format(f.targets) end
    return table.concat(parts, " · ")
end
C.FightText = fightText

local function setRow(r, label, value, delta, frac, token)
    r:Show()
    r.label:SetText(label)
    r.value:SetText(value)
    r.delta:SetText(delta or "")
    r.delta:SetTextColor(Theme:Color(token or "text.primary"))
    W.Color(r.fill, token or "accent.primary", 0.9)
    r.fill:SetWidth(math.max(1, (r:GetWidth() or 300) * math.min(1, math.max(0, frac or 0))))
    r.fill:SetShown((frac or 0) > 0)
end

local function paintWeights(c, r)
    local list = {}
    for stat, v in pairs(r.weights or {}) do list[#list + 1] = { stat = stat, v = v } end
    table.sort(list, function(a, b) return a.v > b.v end)
    for i, e in ipairs(list) do
        if c.rows[i] then
            setRow(c.rows[i], statLabel(e.stat), ("%.2f"):format(e.v), nil, e.v, "accent.primary")
        end
    end
    if #list == 0 then c.note:SetText(L.SIM_NO_WEIGHTS) end
end

local function signed(n, fmt)
    return (n >= 0 and "+" or "-") .. fmt:format(math.abs(n))
end

local function paintSets(c, r)
    local sets = r.sets or {}
    local maxAbs = 0
    for _, s in ipairs(sets) do maxAbs = math.max(maxAbs, math.abs(s.pct)) end
    for i = 1, math.min(#sets, ROWS) do
        local s = sets[i]
        local delta = (s.delta >= 0 and "+" or "-") .. big(math.abs(s.delta)) .. "  " .. signed(s.pct, "%.1f%%")
        setRow(c.rows[i], s.label, big(s.dps), delta, maxAbs > 0 and math.abs(s.pct) / maxAbs or 0,
            s.delta >= 0 and "state.success" or "state.danger")
    end
    if r.mode ~= "gear" and #sets == 0 then c.note:SetText(L.SIM_NO_SETS) end
    if #sets > ROWS then c.note:SetText(L.SIM_MORE_SETS:format(#sets - ROWS)) end
end
C.Signed = signed

local function paintHead(c, r)
    local Sim = ns.modules.Sim
    c.when:SetText(r.finished > 0 and L.SIM_WHEN:format(("%.1f"):format(r.seconds), Sim:Age(r.finished)) or "")
    local sub = {}
    if r.spec ~= "" then sub[#sub + 1] = r.spec end
    if MODES[r.mode] then sub[#sub + 1] = C.ModeLabel(r.mode) end
    local fight = fightText(r.fight)
    if fight ~= "" then sub[#sub + 1] = fight end
    c.sub:SetText(table.concat(sub, " · "))
end

-- result: a saved result (Sim.lua cleanResult) or nil (empty state).
function C:Paint(c, r)
    c.last = r
    for _, row in ipairs(c.rows) do row:Hide() end
    c.note:SetText("")
    if not r then
        c.dps:SetText("—"); c.unit:SetText(""); c.when:SetText(""); c.sub:SetText("")
        c.note:SetText(L.SIM_EMPTY)
        return
    end
    paintHead(c, r)
    if r.state ~= "done" then
        c.dps:SetText(r.state == "declined" and L.SIM_DECLINED or L.SIM_FAILED)
        c.dps:SetTextColor(Theme:Color(r.state == "declined" and "state.warning" or "state.danger"))
        c.unit:SetText("")
        c.note:SetText((tostring(r.error or ""):gsub("|", "||")))
        return
    end
    c.dps:SetTextColor(Theme:Color("text.primary"))
    c.dps:SetText(big(r.dps))
    c.unit:SetText(L.SIM_DPS_UNIT:format(big(r.dpsError)))
    if r.mode == "weights" then paintWeights(c, r) else paintSets(c, r) end
end

-- The result the page shows: the history entry you clicked, else your latest; the sample in test mode or
-- before your first sim.
function C:Current(m)
    if m.test then return m:Sample(), true end
    local data = m:Data()
    local r = m.shown and data.results[m.shown] or m:Latest()
    if r then return r, false end
    return m:Sample(), true
end

P:Register("sim", {
    module = "Sim",
    height = 222,
    build = function(stage, m)
        local card = C:New(stage)
        card:SetPoint("TOPLEFT", 24, -18)
        card:SetPoint("TOPRIGHT", -24, -18)
        card:SetHeight(card.height)
        card.badge = W:Badge(stage, L.SIM_SAMPLE_BADGE, "state.info", "test")
        card.badge:SetPoint("BOTTOMRIGHT", -12, 10)
        ns.Events:Listen("PUI_SIM_CHANGED", stage, function() if stage:IsVisible() then stage:Redraw() end end)
        return function()
            local r, sample = C:Current(m)
            if sample and m.db.mode == "weights" then r.mode = "weights" end
            C:Paint(card, r)
            card.badge:SetShown(sample)
        end
    end,
})
