local _, ns = ...
local W, Skin, Icons = ns.Widgets, ns.Skin, ns.Icons

-- EllesmereUI buttons (specs/001 FR-005). variant: "secondary" (flat warm fill 0.6, white 0.3 border, text 0.55),
-- "primary" (accent fill), "ghost" (no fill or border), "danger" (red text and border). Hover lifts the alphas.
function W:Button(parent, text, variant, icon, width)
    local E = W.EUI.button
    variant = variant or "secondary"
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 120, 28)
    b.variant = variant
    b.fill = W.Texture(b, "BACKGROUND", 1)
    b.fill:SetAllPoints()
    b.label = W.Text(b, "body", "text.primary", "CENTER")
    if icon then
        b.icon = W.Icon(b, icon, 14)
        b.icon:SetPoint("LEFT", 10, 0)
        b.label:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.label:SetPoint("RIGHT", -10, 0)
    else
        b.label:SetPoint("LEFT", 8, 0); b.label:SetPoint("RIGHT", -8, 0)
    end
    b.label:SetText(text or "")
    if not width and text then b:SetWidth(math.max(72, b.label:GetStringWidth() + (icon and 46 or 28))) end

    local function paint(self, hover)
        local v = self.variant
        self.label:SetShadowOffset(0, 0)
        if v == "primary" then
            local r, g, bl = ns.Theme:Color("accent.primary")
            self.fill:SetVertexColor(r, g, bl, hover and 1 or 0.85)
            Skin:Text(self.label, "body", "bg.base")
            Skin:SetBorderColor(self, r, g, bl, 1)
            if self.icon then Icons:SetState(self.icon, nil); Icons:Tint(self.icon, "bg.base") end
            return
        end
        if v == "ghost" then
            self.fill:SetVertexColor(1, 1, 1, hover and 0.04 or 0)
            Skin:SetBorderColor(self, 0, 0, 0, 0)
        else
            local fr, fg, fb = W.RGB(E.bg)
            self.fill:SetVertexColor(fr, fg, fb, hover and E.bgHoverA or E.bgA)
        end
        if v == "danger" then
            local r, g, bl = ns.Theme:Color("state.danger")
            Skin:Text(self.label, "body", "state.danger")
            Skin:SetBorderColor(self, r, g, bl, hover and 0.9 or 0.6)
        else
            Skin:Text(self.label, "body", "text.primary")
            self.label:SetTextColor(1, 1, 1, hover and E.textHoverA or E.textA)
            if v ~= "ghost" then Skin:SetBorderColor(self, 1, 1, 1, hover and E.borderHoverA or E.borderA) end
        end
        if self.icon then
            Icons:SetState(self.icon, nil)
            Icons:Tint(self.icon, v == "danger" and "state.danger" or "text.secondary")
        end
    end
    local function idle(self) paint(self, false) end
    Skin:SetRound(b, W.EUI.radius.control)
    Skin:RoundFill(b, b.fill)
    Skin:Border(b, "border.strong")
    Skin:Register(b, idle)
    b:SetScript("OnEnter", function(self) if not self.disabled then paint(self, true) end end)
    b:SetScript("OnLeave", idle)
    b:SetScript("OnMouseDown", function(self)
        if not self.disabled and not self.pressed then
            self.pressed = true; self.label:AdjustPointsOffset(0, -1)
        end
    end)
    b:SetScript("OnMouseUp", function(self)
        if self.pressed then
            self.pressed = false; self.label:AdjustPointsOffset(0, 1)
        end
    end)
    b:SetScript("OnClick", function(self, ...)
        if self.disabled then return end
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if self.onClick then self.onClick(self, ...) end
    end)
    b.SetEnabledState = W.SetEnabledState
    function b:SetText(t) self.label:SetText(t) end
    return b
end

-- Square icon-only button (header actions, close).
function W:IconButton(parent, icon, size, tooltipTitle, tooltipText)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 28, size or 28)
    b.fill = W.Texture(b, "BACKGROUND")
    b.fill:SetAllPoints()
    b.icon = W.Icon(b, icon, math.floor((size or 28) * 0.5))
    b.icon:SetPoint("CENTER")
    local function rest(self)
        W.Color(self.fill, "bg.hover", 0)
        Icons:SetState(self.icon, self.active and "active" or nil)
    end
    Skin:Register(b, rest)
    b:SetScript("OnEnter", function(self)
        W.Color(self.fill, "bg.hover", 1)
        Icons:SetState(self.icon, self.danger and "danger" or "active")
    end)
    b:SetScript("OnLeave", rest)
    b:SetScript("OnClick", function(self, ...)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if self.onClick then self.onClick(self, ...) end
    end)
    if tooltipTitle then W.AttachTooltip(b, tooltipTitle, tooltipText) end
    return b
end
