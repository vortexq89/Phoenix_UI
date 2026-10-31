local _, ns = ...
local W = ns.Widgets

-- ScrollFrame with a slim themed bar (no Blizzard scroll templates).
function W:Scroll(parent)
    local s = CreateFrame("ScrollFrame", nil, parent)
    s.child = CreateFrame("Frame", nil, s)
    s.child:SetSize(1, 1)
    s:SetScrollChild(s.child)
    s:EnableMouseWheel(true)
    s.track = W.Texture(s, "OVERLAY", 1)
    s.track:SetPoint("TOPRIGHT", s, "TOPRIGHT", 6, 0)
    s.track:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", 6, 0)
    s.track:SetWidth(3)
    s.thumb = W.Texture(s, "OVERLAY", 2)
    s.thumb:SetWidth(3)

    function s:UpdateBar()
        local range = self:GetVerticalScrollRange()
        local h = self:GetHeight()
        if range <= 0.5 or h <= 0 then
            self.track:Hide(); self.thumb:Hide()
            return
        end
        local thumbH = math.max(24, h * h / (h + range))
        local y = (h - thumbH) * (self:GetVerticalScroll() / range)
        self.thumb:SetHeight(thumbH)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 6, -y)
        W.Color(self.track, "border.subtle", 0.5)
        W.Color(self.thumb, self:IsMouseOver() and "accent.primary" or "border.strong")
        self.track:Show(); self.thumb:Show()
    end

    s:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        local target = math.max(0, math.min(range, self:GetVerticalScroll() - delta * 48))
        ns.Anim:Tween(self, 0.12, self:GetVerticalScroll(), target, function(v)
            self:SetVerticalScroll(v)
            self:UpdateBar()
        end)
    end)
    s:SetScript("OnScrollRangeChanged", function(self) self:UpdateBar() end)
    s:SetScript("OnSizeChanged", function(self, w)
        self.child:SetWidth(w)
        self:UpdateBar()
    end)
    s:SetScript("OnEnter", function(self) self:UpdateBar() end)
    s:SetScript("OnLeave", function(self) self:UpdateBar() end)
    return s
end
