local _, ns = ...
local W, Skin, Media, Icons = ns.Widgets, ns.Skin, ns.Media, ns.Icons

-- variant: "primary" (accent gradient), "secondary" (raised), "ghost" (transparent), "danger"
function W:Button(parent, text, variant, icon, width)
    variant = variant or "secondary"
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 120, 28)
    b.variant = variant
    b.fill = W.Texture(b, "BACKGROUND", 1)
    b.fill:SetAllPoints()
    b.shine = W.Texture(b, "BACKGROUND", 2, Media.textures.FADE_V)
    b.shine:SetPoint("TOPLEFT", 1, -1); b.shine:SetPoint("TOPRIGHT", -1, -1); b.shine:SetHeight(14)
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

    local function idle(self)
        local v = self.variant
        self.shine:SetVertexColor(1, 1, 1, v == "primary" and 0.18 or 0.04)
        if v == "primary" then
            self.fill:SetVertexColor(1, 1, 1, 1)
            Skin:Gradient(self.fill, "HORIZONTAL", "accent.primary", "accent.secondary")
            Skin:Text(self.label, "body", "bg.base")
            self.label:SetShadowOffset(0, 0)
            Skin:SetBorderColor(self, "accent.primary")
            if self.icon then Icons:SetState(self.icon, nil); Icons:Tint(self.icon, "bg.base") end
        else
            self.fill:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1))
            if v == "danger" then
                W.Color(self.fill, "state.danger", 0.14)
                Skin:Text(self.label, "body", "state.danger")
                Skin:SetBorderColor(self, "state.danger")
            elseif v == "ghost" then
                W.Color(self.fill, "bg.hover", 0)
                Skin:Text(self.label, "body", "text.secondary")
                Skin:SetBorderColor(self, 0, 0, 0, 0)
            else
                W.Color(self.fill, "bg.raised")
                Skin:Text(self.label, "body", "text.primary")
                Skin:SetBorderColor(self, "border.strong")
            end
            if self.icon then
                Icons:SetState(self.icon, nil)
                Icons:Tint(self.icon, v == "danger" and "state.danger" or "text.secondary")
            end
        end
    end
    Skin:Border(b, "border.strong")
    Skin:Register(b, idle)
    b:SetScript("OnEnter", function(self)
        if self.disabled then return end
        if self.variant == "primary" then
            self.shine:SetVertexColor(1, 1, 1, 0.32)
        else
            W.Color(self.fill, self.variant == "danger" and "state.danger" or "bg.hover", self.variant == "danger" and 0.26 or 1)
            if self.icon then Icons:SetState(self.icon, self.variant == "danger" and "danger" or "active") end
            Skin:SetBorderColor(self, self.variant == "danger" and "state.danger" or "accent.primary")
        end
    end)
    b:SetScript("OnLeave", idle)
    b:SetScript("OnMouseDown", function(self)
        if not self.disabled and not self.pressed then self.pressed = true; self.label:AdjustPointsOffset(0, -1) end
    end)
    b:SetScript("OnMouseUp", function(self)
        if self.pressed then self.pressed = false; self.label:AdjustPointsOffset(0, 1) end
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
