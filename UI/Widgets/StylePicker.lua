local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin

--[[ Style picker: border styles, shadows and backdrops chosen by sight. The face shows a small sample of the
    current choice; the popup is a grid of cards, each a sample panel drawn by the very ns.Skin code that dresses
    the real frames (BorderSpec / Backdrop), so what you point at is what you get. Pointing at a card calls
    owner.onHover(owner, value) for the page preview, like the dropdown and media pickers.
    W:StylePicker(parent, kind, values) kind: "border" | "shadow" | "backdrop"; values: { {value=, label=}, ... }
    API mirrors W:Dropdown: SetValue, GetValue, onChange(self, value), onHover(self, value|nil). ]]
local COLS, CARD_W, CARD_H, PAD, GAP = 3, 112, 74, 12, 8
local popup

-- Draws `value` of `kind` onto sample frame f (a small panel).
local function sample(f, kind, value)
    if kind == "backdrop" then
        Skin:BorderSpec(f, { style = "solid", size = 1 }, "border.black")
        Skin:Backdrop(f, { alpha = 0.95, style = value }, "accent.primary")
    elseif kind == "shadow" then
        Skin:Backdrop(f, { alpha = 1 }, "bg.raised")
        Skin:BorderSpec(f, { style = "solid", size = 1, shadow = value == "auto" and "none" or value }, "border.black")
    else
        Skin:Backdrop(f, { alpha = 1 }, "bg.raised")
        Skin:BorderSpec(f, { style = value, size = 1 }, "border.black")
    end
end

local function labelOf(values, v)
    for _, e in ipairs(values) do if e.value == v then return L[e.label] or e.label end end
    return v and tostring(v) or ""
end

local function card(parent)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(CARD_W, CARD_H)
    c.sample = CreateFrame("Frame", nil, c)
    c.sample:SetSize(52, 26)
    c.sample:SetPoint("TOP", 0, -14)
    c.name = W.Text(c, "small", "text.secondary", "CENTER")
    c.name:SetPoint("BOTTOMLEFT", 6, 9); c.name:SetPoint("BOTTOMRIGHT", -6, 9)
    c.check = W.Icon(c, "check", 11, "accent.primary")
    c.check:SetPoint("TOPRIGHT", -6, -6)
    function c:Paint()
        local on = popup.owner and self.value == popup.owner.value
        Skin:Panel(self, self.hover and "hover" or "sunken",
            { border = on and "accent.primary" or (self.hover and "border.strong" or "border.subtle") })
        Skin:Text(self.name, "small", on and "accent.text" or (self.hover and "text.primary" or "text.secondary"))
        self.check:SetShown(on and true or false)
    end
    c:SetScript("OnEnter", function(self)
        self.hover = true
        self:Paint()
        local o = popup.owner
        if o and o.onHover then o.onHover(o, self.value) end
    end)
    c:SetScript("OnLeave", function(self)
        self.hover = false
        self:Paint()
        local o = popup.owner
        if o and o.onHover and not popup:IsMouseOver() then o.onHover(o, nil) end
    end)
    c:SetScript("OnClick", function(self)
        local o = popup.owner
        popup:Hide()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        o:SetValue(self.value)
        if o.onChange then o.onChange(o, self.value) end
    end)
    return c
end

local function getPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(120)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup.cards = {}
    Skin:Register(popup, function(f) Skin:Panel(f, "raised", { border = "border.strong", shadow = 12 }) end)
    popup:SetScript("OnEvent", function(self)
        if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
    end)
    popup:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    popup:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        if self.owner then
            self.owner:SetOpen(false)
            if self.owner.onHover then self.owner.onHover(self.owner, nil) end
        end
    end)
    -- a list opened from inside a cog popover must not close that popover
    W.PopoverKeepOpen(popup)
    popup:Hide()
    return popup
end

function W.StylePickerPopup() return getPopup() end

function W:StylePicker(parent, kind, values)
    local d = CreateFrame("Button", nil, parent)
    d:SetSize(W.CONTROL_WIDTH, 26)
    d.kind, d.values = kind, values
    d.swatch = CreateFrame("Frame", nil, d)
    d.swatch:SetSize(18, 12)
    d.swatch:SetPoint("LEFT", 9, 0)
    d.label = W.Text(d, "body", "text.primary")
    d.label:SetPoint("LEFT", d.swatch, "RIGHT", 9, 0)
    d.label:SetPoint("RIGHT", -24, 0)
    d.chev = W.Icon(d, "chevron-down", 10)
    d.chev:SetPoint("RIGHT", -9, 0)

    local function paint(self)
        local border = (self.open and "accent.primary") or (self.hover and not self.disabled and "border.strong") or "border.subtle"
        Skin:Panel(self, "sunken", { border = border })
        Skin:Text(self.label, "body", "text.primary")
        W.Color(self.chev, self.open and "accent.primary" or "text.muted")
        sample(self.swatch, self.kind, self.value)
    end
    d.Paint = paint
    Skin:Register(d, paint)
    d:SetScript("OnEnter", function(self) self.hover = true; paint(self) end)
    d:SetScript("OnLeave", function(self) self.hover = false; paint(self) end)

    function d:SetOpen(open) self.open = open; paint(self) end
    d:SetScript("OnClick", function(self)
        if self.disabled then return end
        local p = getPopup()
        if p:IsShown() and p.owner == self then p:Hide(); return end
        p:Hide()
        p.owner = self
        for _, c in ipairs(p.cards) do c:Hide() end
        for i, e in ipairs(self.values) do
            local c = p.cards[i] or card(p)
            p.cards[i] = c
            c.value = e.value
            c.name:SetText(L[e.label] or e.label)
            local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", PAD + col * (CARD_W + GAP), -(PAD + row * (CARD_H + GAP)))
            sample(c.sample, self.kind, e.value)
            c:Show()
            c:Paint()
        end
        local rows = math.ceil(#self.values / COLS)
        p:SetSize(PAD * 2 + COLS * CARD_W + (COLS - 1) * GAP, PAD * 2 + rows * CARD_H + (rows - 1) * GAP)
        p:ClearAllPoints()
        p:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -4)
        self:SetOpen(true)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        ns.Anim:FadeIn(p, 0.1)
    end)

    function d:SetValue(v)
        self.value = v
        self.label:SetText(labelOf(self.values, v))
        paint(self)
    end
    function d:GetValue() return self.value end
    d.SetEnabledState = W.SetEnabledState
    return d
end
