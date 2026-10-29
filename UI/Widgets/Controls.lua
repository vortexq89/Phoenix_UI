local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin

---------------------------------------------------------------- segmented control
--[[ A row of joined buttons. items: { {value=, label=, icon=?}, ... }. multi = true makes every segment an
    independent switch (value is then a set: { [value] = true }). ]]
function W:Segmented(parent, items, multi, segWidth)
    local s = CreateFrame("Frame", nil, parent)
    s:SetHeight(26)
    s.multi, s.buttons = multi, {}
    s.value = multi and {} or nil

    local function paint(self)
        for _, b in ipairs(self.buttons) do
            local on
            if self.multi then on = self.value[b.value] else on = self.value == b.value end
            if on then
                b.fill:SetVertexColor(1, 1, 1, 1)
                Skin:Gradient(b.fill, "HORIZONTAL", "accent.primary", "accent.secondary")
                b.fill:SetAlpha(b.hover and 1 or 0.92)
                Skin:Text(b.label, "small", "bg.base")
                b.label:SetShadowOffset(0, 0)
            else
                b.fill:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1))
                W.Color(b.fill, b.hover and "bg.hover" or "bg.sunken")
                b.fill:SetAlpha(1)
                Skin:Text(b.label, "small", b.hover and "text.primary" or "text.secondary")
            end
            if b.icon then ns.Icons:Tint(b.icon, on and "bg.base" or "text.secondary") end
        end
    end
    s.Paint = paint

    function s:SetItems(list)
        for _, b in ipairs(self.buttons) do b:Hide() end
        local x = 0
        for i, item in ipairs(list) do
            local b = self.buttons[i]
            if not b then
                b = CreateFrame("Button", nil, self)
                b:SetHeight(26)
                b.fill = W.Texture(b, "BACKGROUND")
                b.fill:SetAllPoints()
                b.label = W.Text(b, "small", "text.secondary", "CENTER")
                b:SetScript("OnEnter", function(btn) btn.hover = true; paint(self) end)
                b:SetScript("OnLeave", function(btn) btn.hover = false; paint(self) end)
                b:SetScript("OnClick", function(btn)
                    if self.disabled then return end
                    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                    if self.multi then
                        self.value[btn.value] = not self.value[btn.value] or nil
                    else
                        self.value = btn.value
                    end
                    paint(self)
                    if self.onChange then self.onChange(self, self.value) end
                end)
                self.buttons[i] = b
            end
            b.value = item.value
            b.label:SetText((item.label or tostring(item.value)):upper())
            if item.icon then
                b.icon = b.icon or W.Icon(b, item.icon, 12)
                ns.Icons:Apply(b.icon, item.icon, 12)
                b.icon:SetPoint("LEFT", 8, 0)
                b.label:SetPoint("CENTER", 7, 0)
            else
                if b.icon then b.icon:Hide() end
                b.label:SetPoint("CENTER")
            end
            local w = segWidth or math.max(56, b.label:GetStringWidth() + (item.icon and 38 or 22))
            b:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("LEFT", x, 0)
            x = x + w + 1
            b:Show()
        end
        self:SetWidth(math.max(1, x - 1))
        paint(self)
    end

    function s:SetValue(v)
        if self.multi then self.value = type(v) == "table" and v or {} else self.value = v end
        paint(self)
    end
    function s:GetValue() return self.value end
    s.SetEnabledState = W.SetEnabledState
    Skin:Register(s, function(self)
        Skin:Border(self, "border.subtle")
        paint(self)
    end)
    s:SetItems(items or {})
    return s
end

---------------------------------------------------------------- tabs
-- Segmented tab strip for sub-modules: one compact rail, each tab an icon (from our set) and a label, the open tab
-- filled with the accent tint and underlined. items: { {value=, label=, icon=}, ... }
local TAB_H, TAB_PAD, TAB_GAP = 30, 12, 2
function W:Tabs(parent, items)
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(TAB_H + 4)
    t.tabs = {}
    t.bg = W.Texture(t, "BACKGROUND")
    t.bg:SetPoint("TOPLEFT"); t.bg:SetPoint("BOTTOMLEFT")
    t.line = W.Texture(t, "BORDER")
    t.line:SetPoint("BOTTOMLEFT"); t.line:SetPoint("BOTTOMRIGHT")
    t.line:SetHeight(1)

    local function paint(self)
        W.Color(self.line, "border.subtle")
        W.Color(self.bg, "bg.sunken", 0.9)
        for _, b in ipairs(self.tabs) do
            local on = b.value == self.value
            if on then W.Color(b.fill, "accent.soft") else W.Color(b.fill, "bg.hover", b.hover and 0.8 or 0) end
            b.bar:SetShown(on)
            if on then
                b.bar:SetVertexColor(1, 1, 1, 1)
                Skin:Gradient(b.bar, "HORIZONTAL", "accent.primary", "accent.secondary")
            end
            if b.icon then W.Color(b.icon, on and "accent.primary" or (b.hover and "text.primary" or "text.muted")) end
            Skin:Text(b.label, "body", on and "text.primary" or (b.hover and "text.primary" or "text.secondary"))
        end
    end

    local x = 2
    for i, item in ipairs(items) do
        local b = CreateFrame("Button", nil, t)
        b:SetHeight(TAB_H)
        b.value = item.value
        b.fill = W.Texture(b, "BACKGROUND", 1)
        b.fill:SetAllPoints()
        b.bar = W.Texture(b, "ARTWORK", 2)
        b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetPoint("BOTTOMRIGHT"); b.bar:SetHeight(2)
        local left = TAB_PAD
        if item.icon then
            b.icon = W.Icon(b, item.icon, 14)
            b.icon:SetPoint("LEFT", TAB_PAD, 0)
            left = TAB_PAD + 20
        end
        b.label = W.Text(b, "body", "text.secondary", "LEFT")
        b.label:SetPoint("LEFT", left, 0)
        b.label:SetText(item.label)
        b:SetWidth(math.floor(b.label:GetStringWidth() + left + TAB_PAD + 0.5))
        b:SetPoint("BOTTOMLEFT", x, 1)
        x = x + b:GetWidth() + TAB_GAP
        b:SetScript("OnEnter", function(btn) btn.hover = true; paint(t) end)
        b:SetScript("OnLeave", function(btn) btn.hover = false; paint(t) end)
        b:SetScript("OnClick", function(btn)
            if t.value == btn.value then return end
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            t.value = btn.value
            paint(t)
            if t.onChange then t.onChange(t, btn.value) end
        end)
        t.tabs[i] = b
    end
    t.bg:SetWidth(x)
    t.value = items[1] and items[1].value
    function t:SetValue(v) self.value = v; paint(self) end
    function t:GetValue() return self.value end
    Skin:Register(t, paint)
    return t
end

---------------------------------------------------------------- colour swatch group
--[[ Two or more swatches side by side (e.g. health colour + background colour). Each swatch is a normal
    W:ColorSwatch; onChange(group, value, index). ]]
function W:ColorPair(parent, count, hasAlpha, tokens)
    local g = CreateFrame("Frame", nil, parent)
    g:SetSize(count * 40 - 4, 24)
    g.swatches = {}
    for i = 1, count do
        local sw = W:ColorSwatch(g, hasAlpha)
        sw:SetSize(36, 24)
        sw:SetPoint("LEFT", (i - 1) * 40, 0)
        sw.token = tokens and tokens[i]
        sw.onChange = function(_, v) if g.onChange then g.onChange(g, v, i) end end
        g.swatches[i] = sw
    end
    function g:SetValue(values)
        for i, sw in ipairs(self.swatches) do sw:SetValue(values and values[i]) end
    end
    function g:GetValue()
        local out = {}
        for i, sw in ipairs(self.swatches) do out[i] = sw:GetValue() end
        return out
    end
    function g:SetEnabledState(enabled)
        for _, sw in ipairs(self.swatches) do W.SetEnabledState(sw, enabled) end
    end
    return g
end

---------------------------------------------------------------- popover (sub-option cogs)
--[[ One shared floating panel. W:Popover(owner, title, build) clears it, calls build(content) -> height and
    shows it beside owner. Clicking outside, Escape on a field, or hiding the owner closes it. ]]
local pop
local function getPopover()
    if pop then return pop end
    pop = CreateFrame("Frame", nil, UIParent)
    pop:SetFrameStrata("FULLSCREEN_DIALOG")
    pop:SetFrameLevel(20)
    pop:SetClampedToScreen(true)
    pop:EnableMouse(true)
    pop.accent = W.Texture(pop, "ARTWORK", 2)
    pop.accent:SetPoint("TOPLEFT"); pop.accent:SetPoint("TOPRIGHT")
    pop.accent:SetHeight(2)
    pop.title = W.Text(pop, "heading", "text.secondary")
    pop.title:SetPoint("TOPLEFT", 16, -14)
    pop.close = W:IconButton(pop, "close", 22)
    pop.close:SetPoint("TOPRIGHT", -6, -6)
    pop.close.onClick = function() pop:Hide() end
    Skin:Register(pop, function(self)
        Skin:Panel(self, "raised", { border = "border.strong", shadow = 14 })
        self.accent:SetVertexColor(1, 1, 1, 1)
        Skin:Gradient(self.accent, "HORIZONTAL", "accent.primary", "accent.secondary")
        Skin:Text(self.title, "heading", "text.secondary")
    end)
    pop:SetScript("OnEvent", function(self)
        if self:IsMouseOver() or (self.owner and self.owner:IsMouseOver()) then return end
        -- dropdown lists and the colour picker opened from inside the popover sit outside it
        if ColorPickerFrame:IsShown() then return end
        for _, f in ipairs(self.keepOpen) do if f:IsShown() and f:IsMouseOver() then return end end
        self:Hide()
    end)
    pop:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    pop:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        if self.content then self.content:Hide() end
        if self.owner and self.owner.SetActive then self.owner:SetActive(false) end
        self.owner = nil
    end)
    pop.keepOpen = {}
    pop:Hide()
    return pop
end

-- Frames that may receive clicks while the popover stays open (shared dropdown list).
function W.PopoverKeepOpen(frame)
    local p = getPopover()
    p.keepOpen[#p.keepOpen + 1] = frame
end

function W:Popover(owner, title, content, width, height)
    local p = getPopover()
    if p:IsShown() and p.owner == owner then p:Hide(); return end
    p:Hide()
    p.owner, p.content = owner, content
    content:SetParent(p)
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", 0, -36)
    content:SetPoint("TOPRIGHT", 0, -36)
    content:SetHeight(height)
    content:Show()
    p.title:SetText((title or ""):upper())
    p:SetSize(width or 380, height + 46)
    p:ClearAllPoints()
    p:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 8, -6)
    if owner.SetActive then owner:SetActive(true) end
    ns.Anim:FadeIn(p, 0.1)
    return p
end

function W.HidePopover() if pop then pop:Hide() end end

---------------------------------------------------------------- cog button
function W:Cog(parent)
    local b = W:IconButton(parent, "cog", 24, ns.L.MORE_OPTIONS)
    function b:SetActive(on)
        self.active = on
        ns.Icons:SetState(self.icon, on and "active" or nil)
    end
    b.SetEnabledState = W.SetEnabledState
    return b
end
