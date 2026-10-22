local _, ns = ...
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media

-- Pill switch, 38x20. Knob slides; track fills with the accent gradient when on.
function W:Toggle(parent)
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(38, 20)
    t.track = W.Texture(t, "ARTWORK", 0, Media.textures.PILL)
    t.track:SetAllPoints()
    t.edge = W.Texture(t, "ARTWORK", 1, Media.textures.PILL)
    t.edge:SetPoint("TOPLEFT", 1, -1); t.edge:SetPoint("BOTTOMRIGHT", -1, 1)
    t.glow = W.Texture(t, "BACKGROUND", 0, Media.textures.PILL)
    t.glow:SetPoint("TOPLEFT", -3, 3); t.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    t.knob = W.Texture(t, "OVERLAY", 2, Media.textures.CIRCLE)
    t.knob:SetSize(14, 14)
    t.mark = W.Icon(t, "check", 10, "accent.primary", "OVERLAY")
    t.mark:SetDrawLayer("OVERLAY", 3)
    t.mark:SetPoint("CENTER", t.knob, "CENTER", 0, 0)
    t.value = false
    t.knobX = 3

    local function place(x)
        t.knobX = x
        t.knob:ClearAllPoints()
        t.knob:SetPoint("LEFT", x, 0)
    end

    local function paint(self, animate)
        local on = self.value
        if on then
            self.track:SetVertexColor(1, 1, 1, 1)
            Skin:Gradient(self.track, "HORIZONTAL", "accent.primary", "accent.secondary")
            self.edge:SetAlpha(0)
            self.knob:SetVertexColor(1, 1, 1, 1)
            self.mark:Show()
            ns.Icons:Tint(self.mark, "accent.primary")
            W.Color(self.glow, "accent.glow", self.hover and 0.5 or 0.25)
        else
            self.track:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1))
            W.Color(self.track, self.hover and "border.strong" or "border.subtle")
            self.edge:SetAlpha(1)
            W.Color(self.edge, "bg.sunken")
            W.Color(self.knob, self.hover and "text.primary" or "text.secondary")
            self.mark:Hide()
            self.glow:SetVertexColor(0, 0, 0, 0)
        end
        local target = on and 21 or 3
        if animate then
            ns.Anim:Tween(self.knob, 0.1, self.knobX, target, place)
        else
            place(target)
        end
    end
    t.Paint = paint
    Skin:Register(t, function(self) paint(self, false) end)

    t:SetScript("OnEnter", function(self) self.hover = true; paint(self, false) end)
    t:SetScript("OnLeave", function(self) self.hover = false; paint(self, false) end)
    t:SetScript("OnClick", function(self)
        if self.disabled then return end
        self.value = not self.value
        PlaySound(self.value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        paint(self, true)
        if self.onChange then self.onChange(self, self.value) end
    end)
    function t:SetValue(v) self.value = v and true or false; paint(self, false) end
    function t:GetValue() return self.value end
    t.SetEnabledState = W.SetEnabledState
    return t
end
