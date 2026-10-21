local _, ns = ...
local W, Theme, Skin = ns.Widgets, ns.Theme, ns.Skin

function W:Input(parent, width, placeholder)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width or W.CONTROL_WIDTH, 26)
    e:SetAutoFocus(false)
    e:SetTextInsets(10, 10, 0, 0)
    e.placeholder = W.Text(e, "desc", "text.muted")
    e.placeholder:SetPoint("LEFT", 10, 0)
    e.placeholder:SetText(placeholder or "")
    Skin:Register(e, function(self)
        Skin:Panel(self, "sunken", { border = self:HasFocus() and "accent.primary" or "border.subtle" })
        self:SetFont(Theme:Font("body"))
        self:SetTextColor(Theme:Color("text.primary"))
        Skin:Text(self.placeholder, "desc", "text.muted")
    end)
    e:SetScript("OnEditFocusGained", function(self) Skin:SetBorderColor(self, "accent.primary") end)
    e:SetScript("OnEditFocusLost", function(self) Skin:SetBorderColor(self, "border.subtle") end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if self.onChange then self.onChange(self, self:GetText()) end
    end)
    e:SetScript("OnTextChanged", function(self, user)
        self.placeholder:SetShown(self:GetText() == "")
        if user and self.onTextChanged then self.onTextChanged(self, self:GetText()) end
    end)
    function e:SetValue(v) self:SetText(v or ""); self.placeholder:SetShown((v or "") == "") end
    function e:GetValue() return self:GetText() end
    e.SetEnabledState = W.SetEnabledState
    return e
end

-- Multi-line text area (profile export/import) inside a scroll frame.
function W:TextArea(parent, width, height)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, height)
    local scroll = W:Scroll(holder)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    local e = CreateFrame("EditBox", nil, scroll.child)
    e:SetMultiLine(true)
    e:SetAutoFocus(false)
    e:SetPoint("TOPLEFT")
    e:SetWidth(width - 28)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnTextChanged", function(self)
        scroll.child:SetHeight(math.max(self:GetHeight(), 1))
        scroll:UpdateBar()
    end)
    e:SetScript("OnCursorChanged", function(_, _, y, _, h)
        local top = -y
        local view = scroll:GetHeight()
        local cur = scroll:GetVerticalScroll()
        if top < cur then scroll:SetVerticalScroll(top) elseif top + h > cur + view then scroll:SetVerticalScroll(top + h - view) end
        scroll:UpdateBar()
    end)
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", function() e:SetFocus() end)
    holder:SetScript("OnSizeChanged", function(_, w) e:SetWidth(math.max(40, w - 28)) end)
    holder.edit = e
    Skin:Register(holder, function(self)
        Skin:Panel(self, "sunken", { border = "border.subtle" })
        e:SetFont(Theme:Font("small"))
        e:SetTextColor(Theme:Color("text.secondary"))
    end)
    function holder:SetValue(v) e:SetText(v or ""); e:SetCursorPosition(0); scroll:SetVerticalScroll(0) end
    function holder:GetValue() return e:GetText() end
    return holder
end
