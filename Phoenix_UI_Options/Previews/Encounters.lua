local _, ns = ...
local L, P = ns.L, ns.Previews

-- A boss warning banner over a short timeline in Phoenix bars: built by the module's own CreateBar /
-- StyleBar and CreateWarningLine / StyleWarningLine, so it is the same code that draws a real encounter.
-- Sample data only; nothing here touches the encounter APIs. A client without the game's timeline or
-- warnings (WoW Forever) previews what Phoenix draws there: the pull and break bars.
local BARS = {
    { label = "PREVIEW_ENC_1", icon = 3, left = 3.4, total = 30 },
    { label = "PREVIEW_ENC_2", icon = 5, left = 11, total = 40 },
    { label = "PREVIEW_ENC_3", icon = 8, left = 24, total = 45 },
    { label = "ENC_PULL_BAR", icon = 9, left = 38, total = 60 },
}
local TIMER_BARS = {
    { label = "ENC_PULL_BAR", icon = 9, left = 4.2, total = 10 },
    { label = "ENC_BREAK_BAR", icon = 2, left = 272, total = 300 },
}
local MAX_W = 340

P:Register("encounters", {
    module = "Encounters",
    height = 196,
    build = function(stage, m)
        local bars = m:HasFeature("timeline") and BARS or TIMER_BARS
        local warn = m:CreateWarningLine(stage)
        warn:SetPoint("TOP", 0, -14)
        warn:SetWidth(MAX_W + 120)
        warn.icon:SetTexture(P.SAMPLE.icons[6])
        local list = CreateFrame("Frame", nil, stage)
        list:SetPoint("TOP", warn, "BOTTOM", 0, -14)
        list.bars = {}
        for i, def in ipairs(bars) do
            local f = m:CreateBar(list)
            f.icon:SetTexture(P.SAMPLE.icons[def.icon])
            f.def = def
            list.bars[i] = f
        end
        return function()
            local db = m.db.timeline
            local phoenixBars = db.display == "phoenix"
            m:StyleWarningLine(warn, "high")
            warn.text:SetText(L.PREVIEW_ENC_WARN)
            warn:SetShown(m:HasFeature("warnings") and m.db.warnings.display == "phoenix")
            local w, h = math.min(db.width, MAX_W), math.min(db.height, 30)
            list:SetSize(w, #bars * (h + db.spacing))
            for i, f in ipairs(list.bars) do
                local def = f.def
                m:StyleBar(f, db.emphasize and def.left <= db.emphasizeAt)
                f:SetSize(w, h)
                f.iconHolder:SetSize(h, h)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", 0, -(i - 1) * (h + db.spacing))
                f.bar:SetMinMaxValues(0, def.total)
                f.bar:SetValue(def.left)
                f.name:SetText(L[def.label])
                f.time:SetText(m.FormatTime(def.left))
                f:SetAlpha((phoenixBars or bars == TIMER_BARS) and 1 or 0.35)
            end
        end
    end,
})
