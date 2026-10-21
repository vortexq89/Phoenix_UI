local _, ns = ...
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media

local ROW, MAX_ROWS = 24, 10
local popup

local function getPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    popup.rows = {}
    popup.offset = 0
    Skin:Register(popup, function(f) Skin:Panel(f, "raised", { border = "border.strong", shadow = 12 }) end)
    popup.scroll = W.Texture(popup, "OVERLAY", 2)
    popup.scroll:SetWidth(2)
    popup:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math.max(0, #self.items - MAX_ROWS)
        self.offset = math.max(0, math.min(maxOffset, self.offset - delta))
        self:Render()
    end)
    -- Close when clicking anywhere else.
    popup:SetScript("OnUpdate", function(self)
        local clicked = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        if clicked and not self:IsMouseOver() and not self.owner:IsMouseOver() then
            self:Hide()
        end
    end)
    popup:SetScript("OnHide", function(self) if self.owner then self.owner:SetOpen(false) end end)

    function popup:Row(i)
        local r = self.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, self)
        r:SetHeight(ROW)
        r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW)
        r:SetPoint("TOPRIGHT", -6, -4 - (i - 1) * ROW)
        r.hl = W.Texture(r, "BACKGROUND")
        r.hl:SetAllPoints()
        r.bar = W.Texture(r, "BORDER")
        r.bar:SetPoint("TOPLEFT", 6, -5); r.bar:SetPoint("BOTTOMRIGHT", -6, 5)
        r.label = W.Text(r, "body", "text.primary")
        r.label:SetPoint("RIGHT", -26, 0)
        r.icon = W.Icon(r, "user", 14)
        r.icon:SetPoint("LEFT", 10, 0)
        r.check = W.Icon(r, "check", 12, "accent.primary")
        r.check:SetPoint("RIGHT", -8, 0)
        r:SetScript("OnEnter", function(b) W.Color(b.hl, "bg.hover") end)
        r:SetScript("OnLeave", function(b) W.Color(b.hl, "bg.hover", 0) end)
        r:SetScript("OnClick", function(b)
            local owner = popup.owner
            popup:Hide()
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            owner:SetValue(b.value)
            if owner.onChange then owner.onChange(owner, b.value) end
        end)
        self.rows[i] = r
        return r
    end

    function popup:Render()
        local owner = self.owner
        for i = 1, MAX_ROWS do
            local item = self.items[i + self.offset]
            local r = self:Row(i)
            if item then
                r.value = item.value
                r.label:SetText(item.label)
                r.label:ClearAllPoints()
                r.label:SetPoint("RIGHT", -26, 0)
                if item.icon then
                    ns.Icons:Apply(r.icon, item.icon, 14)
                    ns.Icons:Tint(r.icon, item.value == owner.value and "accent.primary" or "text.secondary")
                    r.icon:Show()
                    r.label:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
                else
                    r.icon:Hide()
                    r.label:SetPoint("LEFT", 10, 0)
                end
                if owner.preview == "font" then
                    r.label:SetFont(Media:Font(item.value), 13, "")
                else
                    Skin:Text(r.label, "body", "text.primary")
                end
                if owner.preview == "bar" then
                    r.bar:SetTexture(Media:Bar(item.value))
                    W.Color(r.bar, "accent.primary", 0.55)
                    r.bar:Show()
                else
                    r.bar:Hide()
                end
                r.label:SetTextColor(Theme:Color(item.value == owner.value and "accent.text" or "text.primary"))
                r.check:SetShown(item.value == owner.value)
                W.Color(r.hl, "bg.hover", 0)
                r:Show()
            else
                r:Hide()
            end
        end
        local n = #self.items
        if n > MAX_ROWS then
            local h = self:GetHeight() - 8
            self.scroll:SetHeight(h * MAX_ROWS / n)
            self.scroll:ClearAllPoints()
            self.scroll:SetPoint("TOPRIGHT", -3, -4 - h * self.offset / n)
            W.Color(self.scroll, "accent.primary", 0.8)
            self.scroll:Show()
        else
            self.scroll:Hide()
        end
    end
    popup:Hide()
    return popup
end

-- items: { {value=, label=, icon=?}, ... } or function() -> items. preview: nil | "font" | "bar"
function W:Dropdown(parent, items, preview, width)
    local d = CreateFrame("Button", nil, parent)
    d:SetSize(width or W.CONTROL_WIDTH, 26)
    d.items, d.preview = items, preview
    d.label = W.Text(d, "body", "text.primary")
    d.label:SetPoint("LEFT", 10, 0)
    d.label:SetPoint("RIGHT", -26, 0)
    d.icon = W.Icon(d, "user", 14, "accent.primary")
    d.icon:SetPoint("LEFT", 9, 0)
    d.icon:Hide()
    d.arrow = W.Icon(d, "chevron-down", 12)
    d.arrow:SetPoint("RIGHT", -9, 0)
    Skin:Register(d, function(self)
        Skin:Panel(self, "sunken", { border = self.open and "accent.primary" or "border.subtle" })
        Skin:Text(self.label, "body", "text.primary")
        if self.preview == "font" and self.value then self.label:SetFont(Media:Font(self.value), 12, "") end
        ns.Icons:Tint(self.arrow, self.open and "accent.primary" or "text.secondary")
    end)
    d:SetScript("OnEnter", function(self) if not self.open and not self.disabled then Skin:SetBorderColor(self, "border.strong") end end)
    d:SetScript("OnLeave", function(self) if not self.open then Skin:SetBorderColor(self, "border.subtle") end end)

    function d:GetItems()
        return type(self.items) == "function" and self.items() or self.items
    end
    function d:SetOpen(open)
        self.open = open
        Skin:SetBorderColor(self, open and "accent.primary" or "border.subtle")
        ns.Icons:Tint(self.arrow, open and "accent.primary" or "text.secondary")
    end
    function d:SetValue(v)
        self.value = v
        local text, icon = tostring(v or ""), nil
        for _, item in ipairs(self:GetItems()) do
            if item.value == v then text, icon = item.label, item.icon end
        end
        self.label:SetText(text)
        self.label:ClearAllPoints()
        self.label:SetPoint("RIGHT", -26, 0)
        if icon then
            ns.Icons:Apply(self.icon, icon, 14)
            self.icon:Show()
            self.label:SetPoint("LEFT", self.icon, "RIGHT", 7, 0)
        else
            self.icon:Hide()
            self.label:SetPoint("LEFT", 10, 0)
        end
        if self.preview == "font" and v then self.label:SetFont(Media:Font(v), 12, "") end
    end
    function d:GetValue() return self.value end
    d.SetEnabledState = W.SetEnabledState

    d:SetScript("OnClick", function(self)
        if self.disabled then return end
        local p = getPopup()
        if p:IsShown() and p.owner == self then p:Hide(); return end
        p:Hide()
        p.owner, p.items, p.offset = self, self:GetItems(), 0
        for i, item in ipairs(p.items) do
            if item.value == self.value and i > MAX_ROWS then p.offset = math.min(i - 1, #p.items - MAX_ROWS) end
        end
        p:SetSize(math.max(self:GetWidth(), 180), math.min(#p.items, MAX_ROWS) * ROW + 8)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
        self:SetOpen(true)
        p:Render()
        ns.Anim:FadeIn(p, 0.1)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
    end)
    d:SetScript("OnHide", function(self) if popup and popup.owner == self then popup:Hide() end end)
    return d
end
