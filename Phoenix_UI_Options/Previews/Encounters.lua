local _, ns = ...
local L, P, W = ns.L, ns.Previews, ns.Widgets

--[[ Boss mod live preview, one section per bar group (t202): Messages (the warning banner), Bars (the
    normal timeline stack), Emphasised bars (their own stack) and Pull and break bars. Every part is built
    and styled by the module's own CreateBar / StyleBar and CreateWarningLine / StyleWarningLine, the code that
    draws a real encounter, and a click on a part jumps to its settings. Sample data only; nothing here
    touches the encounter APIs. A client without the game's timeline (WoW Forever) shows the pull and break
    bars only. ]]
local BARS = {
    { label = "PREVIEW_ENC_2", icon = 5, left = 11, total = 40 },
    { label = "PREVIEW_ENC_3", icon = 8, left = 24, total = 45 },
}
local BIG = { label = "PREVIEW_ENC_1", icon = 3, left = 3.4, total = 30 }
local TIMER_BARS = {
    { label = "ENC_PULL_BAR", icon = 9, left = 4.2, total = 10 },
    { label = "ENC_BREAK_BAR", icon = 2, left = 272, total = 300 },
}
local COL_W, MAX_H = 220, 26

local function sample(m, list, defs, group, emphasized)
    for i, f in ipairs(list.bars) do
        local def, db = defs[i], m:BarGroup(group)
        m:StyleBar(f, emphasized or (group == "bars" and m.db.timeline.emphasize and def.left <= m.db.timeline.emphasizeAt), group)
        local w, h = math.min(db.width, COL_W), math.min(db.height, MAX_H)
        f:SetSize(w, h)
        f.iconHolder:SetSize(h, h)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 0, -(i - 1) * (h + math.min(db.spacing, 6)))
        f.bar:SetMinMaxValues(0, def.total)
        f.bar:SetValue(m.BarValue(m.db.timeline.fill, def.left, def.total))
        f.name:SetText(L[def.label])
        f.time:SetText(m.FormatTime(def.left))
    end
    local db = m:BarGroup(group)
    list:SetSize(math.min(db.width, COL_W), #defs * (math.min(db.height, MAX_H) + 6))
end

local function section(stage, m, title, defs, hotKey)
    local s = CreateFrame("Frame", nil, stage)
    s.title = W.Text(s, "small", "text.muted", "LEFT")
    s.title:SetPoint("TOPLEFT")
    s.title:SetText(title)
    s.list = CreateFrame("Frame", nil, s)
    s.list:SetPoint("TOPLEFT", 0, -16)
    s.list.bars = {}
    for i, def in ipairs(defs) do
        local f = m:CreateBar(s.list)
        f.icon:SetTexture(P.SAMPLE.icons[def.icon])
        s.list.bars[i] = f
    end
    s:SetSize(COL_W, 16 + #defs * (MAX_H + 6))
    P.Hot(stage, s, hotKey, title)
    return s
end

P:Register("encounters", {
    module = "Encounters",
    width = 480,
    height = 236,
    build = function(stage, m)
        local timeline = m:HasFeature("timeline")
        local warn = m:CreateWarningLine(stage)
        warn:SetPoint("TOP", 0, -12)
        warn:SetWidth(460)
        warn.icon:SetTexture(P.SAMPLE.icons[6])
        P.Hot(stage, warn, "warnings.lines", L.ENC_PREVIEW_MSG)
        local bars = section(stage, m, L.ENC_PREVIEW_BARS, BARS, "timeline.width")
        bars:SetPoint("TOPLEFT", 12, -64)
        local big = section(stage, m, L.ENC_BIG_STACK, { BIG }, "timeline.big.width")
        big:SetPoint("TOPRIGHT", -12, -64)
        local timers = section(stage, m, L.ENC_TIMER_STACK, TIMER_BARS, "timeline.timerBars.width")
        timers:SetPoint("TOPRIGHT", -12, -128)
        return function()
            local db = m.db.timeline
            m:StyleWarningLine(warn, "high")
            warn.text:SetText(L.PREVIEW_ENC_WARN)
            warn:SetShown(m:HasFeature("warnings") and m.db.warnings.display == "phoenix")
            local phoenixBars = db.display == "phoenix"
            sample(m, bars.list, BARS, "bars")
            bars:SetShown(timeline)
            bars:SetAlpha(phoenixBars and 1 or 0.35)
            local moved = db.emphasizeMove
            sample(m, big.list, { BIG }, moved and "big" or "bars", true)
            big:SetShown(timeline)
            big:SetAlpha(phoenixBars and moved and 1 or 0.35)
            sample(m, timers.list, TIMER_BARS, db.timerBars.move and "timers" or "bars")
            timers:SetAlpha(db.timerBars.move and 1 or 0.6)
            timers:ClearAllPoints()
            if timeline then timers:SetPoint("TOPRIGHT", -12, -128) else timers:SetPoint("TOP", 0, -64) end
        end
    end,
})
