local _, ns = ...
local L, P, Skin, Theme, W = ns.L, ns.Previews, ns.Skin, ns.Theme, ns.Widgets

-- Theme sampler: the interface font roles, the unit font, three bars in the chosen texture and power / dispel colour chips.
P:Register("theme", {
    module = "General",
    height = 128,
    build = function(stage)
        local card = CreateFrame("Frame", nil, stage)
        card:SetSize(270, 100)
        card:SetPoint("LEFT", 16, 0)
        card.heading = P.Text(card)
        card.heading:SetPoint("TOPLEFT", 14, -14)
        card.body = P.Text(card)
        card.body:SetPoint("TOPLEFT", card.heading, "BOTTOMLEFT", 0, -10)
        card.desc = P.Text(card)
        card.desc:SetPoint("TOPLEFT", card.body, "BOTTOMLEFT", 0, -5)
        card.tick = W.Texture(card, "ARTWORK")
        card.tick:SetSize(10, 2)
        card.tick:SetPoint("RIGHT", card.heading, "LEFT", -5, 0)
        local bars = {}
        local TOKENS = { "accent.primary", "state.success", "state.info" }
        local VALUES = { 0.82, 0.64, 0.4 }
        for i = 1, 3 do
            local b = P.Bar(stage, VALUES[i], 220, 16)
            b:SetPoint("TOPRIGHT", -24, -18 - (i - 1) * 30)
            b.text = P.Text(b)
            b.text:SetPoint("RIGHT", -6, 0)
            b.token = TOKENS[i]
            bars[i] = b
        end
        -- power and dispel colour chips (General's overrides, else the game's colours)
        local chips = {}
        local CHIPS = { "MANA", "RAGE", "ENERGY", "FOCUS", "RUNIC_POWER", "Magic", "Curse", "Disease", "Poison", "Bleed" }
        for i = 1, #CHIPS do
            local c = W.Texture(stage, "ARTWORK")
            c:SetSize(14, 14)
            c:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -24 - (#CHIPS - i) * 20 - (i <= 5 and 8 or 0), -104)
            c.key = CHIPS[i]
            chips[i] = c
        end
        return function()
            for i, c in ipairs(chips) do
                local r, g, b
                if i <= 5 then r, g, b = ns.Util.PowerColor(c.key) else r, g, b = ns.Util.DispelColor(c.key) end
                c:SetColorTexture(r or 0.5, g or 0.5, b or 0.5, 1)
            end
            Skin:Panel(card, "raised", { border = "border.subtle", sheen = 28 })
            Skin:Text(card.heading, "heading", "text.secondary")
            Skin:Text(card.body, "body", "text.primary")
            Skin:Text(card.desc, "desc", "text.muted")
            card.tick:SetVertexColor(1, 1, 1, 1)
            Skin:Gradient(card.tick, "HORIZONTAL", "accent.primary", "accent.secondary")
            card.heading:SetText(L.PREVIEW_THEME_HEADING:upper())
            card.body:SetText(L.PREVIEW_THEME_BODY)
            card.desc:SetText(L.PREVIEW_THEME_DESC)
            for i, b in ipairs(bars) do
                b:SetStatusBarTexture(Theme:Bar())
                b:SetStatusBarColor(Theme:Color(b.token))
                Skin:Backdrop(b, { alpha = 0.9 }, "bg.sunken")
                Skin:Border(b, "border.black")
                Skin:Text(b.text, "unit", "text.primary", 12)
                b.text:SetText(("%d%%"):format(VALUES[i] * 100))
            end
        end
    end,
})
