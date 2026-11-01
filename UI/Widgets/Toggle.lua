local _, ns = ...
local W = ns.Widgets

--[[ Switch in the EllesmereUI look (specs/001-settings-window FR-001): a flat 40x20 track with a square knob 2 px
    inside it. Off: grey track, half-white knob. On: accent track, white knob. The knob slides and the colours blend
    over 0.075 s on ns.Anim (no OnUpdate of its own); reduced motion jumps straight to the end. ]]
local function mix(a, b, p) return a + (b - a) * p end

function W:Toggle(parent)
    local E = W.EUI.toggle
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(E.w, E.h)
    t.track = W.Texture(t, "ARTWORK", 0)
    t.track:SetAllPoints()
    t.knob = W.Texture(t, "OVERLAY", 2)
    local knob = E.h - E.pad * 2
    t.knob:SetSize(knob, knob)
    t.value = false
    t.progress = 0

    local function apply(self, p)
        self.progress = p
        local x = mix(E.pad, self:GetWidth() - E.pad - knob, p)
        self.knob:ClearAllPoints()
        self.knob:SetPoint("LEFT", self, "LEFT", x, 0)
        local r, g, b = ns.Theme:Color("accent.primary")
        local off = E.offRGB
        local lift = self.hover and 0.1 or 0
        self.track:SetVertexColor(mix(off, r, p), mix(off, g, p), mix(off, b, p), math.min(1, mix(E.offA, E.onA, p) + lift))
        local ka = mix(E.knobOffA, E.knobOnA, p)
        self.knob:SetVertexColor(1, 1, 1, self.hover and math.min(1, ka + 0.2) or ka)
    end

    local function paint(self, animate)
        local target = self.value and 1 or 0
        if animate then
            ns.Anim:Tween(self, E.slide, self.progress, target, function(v) apply(self, v) end)
        else
            apply(self, target)
        end
    end
    t.Paint = paint
    ns.Skin:Register(t, function(self) paint(self, false) end)

    t:SetScript("OnEnter", function(self) self.hover = true; apply(self, self.progress) end)
    t:SetScript("OnLeave", function(self) self.hover = false; apply(self, self.progress) end)
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
    paint(t, false)
    return t
end
