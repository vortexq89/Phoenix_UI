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
    ns.Skin:RoundFill(t, t.track, E.h / 2) -- a pill track and a round knob (design v2)
    t.knob = W.Texture(t, "OVERLAY", 2, ns.Media.textures.CIRCLE)
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

--[[ Checkbox in the EllesmereUI look (specs/001 FR-002): an 18 px warm box with a faint white border; checked
    shows a solid accent square 2 px inside and an accent border at 0.15. Same API as the switch. ]]
function W:Checkbox(parent)
    local E = W.EUI.checkbox
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(18, 18)
    c.box = W.Texture(c, "BACKGROUND", 0)
    c.box:SetAllPoints()
    c.mark = W.Texture(c, "ARTWORK", 0)
    c.mark:SetPoint("TOPLEFT", 2, -2); c.mark:SetPoint("BOTTOMRIGHT", -2, 2)
    ns.Skin:SetRound(c, W.EUI.radius.box)
    ns.Skin:RoundFill(c, c.box)
    ns.Skin:Border(c)
    c.value = false
    local function paint(self)
        local r, g, b = ns.Theme:Color("accent.primary")
        local a = (self.value or self.hover) and 1 or 0.8
        local fr, fg, fb = W.RGB(E.box)
        self.box:SetVertexColor(fr, fg, fb, a)
        self.mark:SetVertexColor(r, g, b, 1)
        self.mark:SetShown(self.value)
        if self.value then ns.Skin:SetBorderColor(self, r, g, b, E.checkedBorderA)
        else ns.Skin:SetBorderColor(self, 1, 1, 1, E.borderA * a) end
    end
    c.Paint = paint
    ns.Skin:Register(c, paint)
    c:SetScript("OnEnter", function(self) self.hover = true; paint(self) end)
    c:SetScript("OnLeave", function(self) self.hover = false; paint(self) end)
    c:SetScript("OnClick", function(self)
        if self.disabled then return end
        self.value = not self.value
        PlaySound(self.value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        paint(self)
        if self.onChange then self.onChange(self, self.value) end
    end)
    function c:SetValue(v) self.value = v and true or false; paint(self) end
    function c:GetValue() return self.value end
    c.SetEnabledState = W.SetEnabledState
    paint(c)
    return c
end
