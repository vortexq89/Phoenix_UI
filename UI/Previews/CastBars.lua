local _, ns = ...
local L, P, Skin, Theme = ns.L, ns.Previews, ns.Skin, ns.Theme

-- The selected cast bar in its three states (cast, channel, uninterruptible), styled by CastBars.
local STATES = {
    { sample = "PREVIEW_SPELL_CAST", barType = "standard", value = 0.62, time = "1.1", icon = 1 },
    { sample = "PREVIEW_SPELL_CHANNEL", barType = "channel", value = 0.4, time = "2.6", icon = 4 },
    { sample = "PREVIEW_SPELL_LOCKED", barType = "uninterruptable", value = 0.8, time = "0.4", icon = 3 },
}
local W_BAR, H_BAR = 220, 18

P:Register("castbar", {
    module = "CastBars",
    height = 132,
    build = function(stage, m)
        local rows = {}
        for i, state in ipairs(STATES) do
            local bar = P.Bar(stage, state.value, W_BAR, H_BAR)
            bar:SetPoint("TOP", 14, -16 - (i - 1) * 38)
            local icon = P.Icon(stage, H_BAR + 6, state.icon)
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
        return function(_, unit)
            local key = (unit == "target" or unit == "focus") and unit or "player"
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
            end
        end
    end,
})
