local _, ns = ...
local L, P, Skin, Theme = ns.L, ns.Previews, ns.Skin, ns.Theme

--[[ The cast bar picked in the scope bar. Phoenix mode: three bars built by CastBars itself (M:BuildBar / LayoutBar /
    StartSample, the code that draws the real bars) fed frozen sample casts - a cast, a channel and a locked cast
    (an empowered cast for the player) - so latency, ticks, stages, the kick tick and the glows all show. Nothing
    reads a unit. For the player (S18) the GCD bar (on the cast bar or standalone) and the swing bar (with its hand
    labels) show too, drawn by the same CastBars code. Blizzard mode: the 2.0 skin drawn on plain bars. State: the interrupted flash. ]]
local STATES = {
    { sample = "PREVIEW_SPELL_CAST", barType = "standard", value = 0.62, time = "1.1", icon = 1 },
    { sample = "PREVIEW_SPELL_CHANNEL", barType = "channel", value = 0.4, time = "2.6", icon = 4 },
    { sample = "PREVIEW_SPELL_LOCKED", barType = "uninterruptable", value = 0.8, time = "0.4", icon = 3 },
}
local W_BAR, H_BAR = 220, 18
local MAX_W, MAX_H = 300, 30

local function samplesFor(key)
    local icons = ns.modules.UnitFrames and ns.modules.UnitFrames.SAMPLE_ICONS or {}
    local me = UnitName("player") or "Phoenix"
    local enemy = key ~= "player" and key ~= "pet"
    local third = key == "player"
        and { kind = "empower", name = L.PREVIEW_SPELL_EMPOWER, icon = icons.bomb, total = 3.2, elapsed = 1.9,
              stages = { 0.25, 0.25, 0.25, 0.25 } }
        or { kind = "cast", name = L.PREVIEW_SPELL_LOCKED, icon = icons.sentry, total = 2.8, elapsed = 2.2, locked = true }
    return {
        { kind = "cast", name = L.PREVIEW_SPELL_CAST, icon = icons.fireball, total = 2.5, elapsed = 1.55,
          latency = 0.08, kick = enemy and 0.7 or nil, target = enemy and me or nil, important = enemy },
        { kind = "channel", name = L.PREVIEW_SPELL_CHANNEL, icon = icons.storm, total = 3, elapsed = 1.2, ticks = 5,
          targeted = enemy },
        third,
    }
end

local function legacy(stage, m)
    local rows, holder = {}, CreateFrame("Frame", nil, stage)
    holder:SetAllPoints()
    for i, state in ipairs(STATES) do
        local bar = P.Bar(holder, state.value, W_BAR, H_BAR)
        bar:SetPoint("TOP", 14, -16 - (i - 1) * 38)
        local icon = P.Icon(holder, H_BAR + 6, state.icon)
        icon:SetPoint("RIGHT", bar, "LEFT", -6, 0)
        icon.edge = CreateFrame("Frame", nil, icon)
        icon.edge:SetAllPoints()
        local text = P.Text(bar)
        text:SetPoint("LEFT", 6, 0)
        local time = P.Text(bar)
        time:SetPoint("RIGHT", -6, 0)
        local lag = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        lag:SetTexture(ns.Media.textures.WHITE)
        lag:SetPoint("TOPRIGHT"); lag:SetPoint("BOTTOMRIGHT"); lag:SetWidth(W_BAR * 0.08)
        rows[i] = { bar = bar, icon = icon, text = text, time = time, lag = lag, state = state }
    end
    return holder, function(view, unit)
        local key = (unit == "target" or unit == "focus") and unit or "player"
        local cut = view.states.interrupted
        local db = m.db
        for i, r in ipairs(rows) do
            if db.style then
                m:StyleFrame(r.bar, key)
                r.bar:SetStatusBarColor(m:FillColor(key, r.state.barType))
                m:StyleTexts(r.text, r.time, key)
            else
                r.bar:SetStatusBarTexture(ns.Media.textures.WHITE)
                r.bar:SetStatusBarColor(Theme:Color("state.warning"))
                Skin:Text(r.text, "body"); Skin:Text(r.time, "number")
            end
            local player = key == "player"
            r.icon:SetShown(player and db.icon)
            Skin:IconZoom(r.icon.tex, db.iconZoom)
            Skin:Border(r.icon.edge, "border.black")
            r.time:SetShown(not player or db.timer)
            r.lag:SetShown(player and db.latency and i == 1)
            r.lag:SetVertexColor(Theme:Color("state.danger"))
            r.lag:SetAlpha(0.45)
            r.text:SetText(L[r.state.sample])
            r.time:SetText(r.state.time)
            r.bar:SetValue(r.state.value)
            if cut and i == 1 then
                -- the first bar shows the interrupted flash: full, red, labelled
                r.bar:SetValue(1)
                r.bar:SetStatusBarColor(Theme:Color("state.danger"))
                r.text:SetText(INTERRUPTED)
                r.time:SetText("")
            end
        end
    end
end

-- The player's extras: a GCD sample under the first bar or on its own, and a frozen swing bar.
local function drawExtras(stage, m, built, first, bottom)
    local x = built.extras
    if not x then
        x = { gcd = P.Bar(stage, 0.45, 100, 4) }
        if m.BuildSwingFrame then x.swing = m:BuildSwingFrame(stage) end
        built.extras = x
    end
    local g, c = m.db.gcd, m.db.swing
    local y = bottom
    x.gcd:SetShown(g.enabled and ns:Supports("gcdBar") and first ~= nil)
    if x.gcd:IsShown() then
        m:StyleGCDSample(x.gcd)
        x.gcd:ClearAllPoints()
        if g.attach == "free" then
            x.gcd:SetSize(math.min(g.width, MAX_W), g.height)
            x.gcd:SetPoint("TOP", stage, "TOP", 0, y)
            y = y - g.height - 8
        else
            x.gcd:SetPoint("TOPLEFT", first.Bar, "BOTTOMLEFT", 0, -g.gap)
            x.gcd:SetPoint("TOPRIGHT", first.Bar, "BOTTOMRIGHT", 0, -g.gap)
            x.gcd:SetHeight(g.height)
        end
    end
    local s = x.swing
    if not s then return end
    s:SetShown(c.enabled and ns:Supports("swingTimer"))
    if not s:IsShown() then return end
    m:LayoutSwingFrame(s, true)
    s:SetWidth(math.min(c.width, MAX_W))
    s:ClearAllPoints()
    s:SetPoint("TOP", stage, "TOP", 0, y)
    s.main:SetMinMaxValues(0, 1); s.main:SetValue(0.55)
    s.off:SetMinMaxValues(0, 1); s.off:SetValue(0.3)
    s.text:SetText("1.2")
end

P:Register("castbar", {
    module = "CastBars",
    height = 190,
    states = { { key = "interrupted", label = "PREVIEW_STATE_INTERRUPTED", icon = "error" } },
    build = function(stage, m)
        local old, drawOld = legacy(stage, m)
        local built = {}
        return function(view, unit)
            local phoenix = m.db.mode == "phoenix" and m.Bar ~= nil and m.BuildBar ~= nil
            old:SetShown(not phoenix)
            for k, list in pairs(built) do if k ~= "extras" then for _, f in ipairs(list) do f:Hide() end end end
            if built.extras then
                built.extras.gcd:Hide()
                if built.extras.swing then built.extras.swing:Hide() end
            end
            if not phoenix then drawOld(view, unit); return end
            local key = m.TOKENS[unit] and unit or "player"
            local list = built[key]
            if not list then
                list = {}
                for i = 1, 3 do
                    local f = m:BuildBar(stage, key, { preview = true })
                    f:EnableMouse(false)
                    list[i] = f
                end
                built[key] = list
            end
            local b = m:Bar(key)
            local w, h = math.min(b.width, MAX_W), math.min(b.height, MAX_H)
            local g = m.Geometry(b, w, h)
            local shift = (g.icon and b.iconDetached) and ((b.icon == "left" and 1 or -1) * (g.icon[3] + b.iconGap) / 2) or 0
            local pitch = math.max(h + 18, 40)
            local samples = samplesFor(key)
            for i, f in ipairs(list) do
                m:LayoutBar(f, w, h)
                f:ClearAllPoints()
                f:SetPoint("TOP", stage, "TOP", shift, -18 - (i - 1) * pitch)
                local s = samples[i]
                s.frozen = true
                m:StartSample(f, s)
                if view.states.interrupted and i == 1 then
                    f.sample = nil
                    m:EndCast(f, "interrupted")
                    f.hideAt = nil
                    f.sample = s
                end
                f:SetAlpha(1)
                f:Show()
            end
            if key == "player" then drawExtras(stage, m, built, list[1], -18 - #list * pitch) end
        end
    end,
})
