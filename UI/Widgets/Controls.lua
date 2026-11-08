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
            -- EllesmereUI segments (specs/001 T007): the chosen one is a flat accent at 0.75 with white text; the
            -- others are button-grey with soft white text
            local E = W.EUI.button
            b.label:SetShadowOffset(0, 0)
            Skin:Text(b.label, "small", "text.primary")
            if on then
                local r, g, bl = ns.Theme:Color("accent.primary")
                b.fill:SetVertexColor(r, g, bl, b.hover and 0.9 or 0.75)
                b.label:SetTextColor(1, 1, 1, 1)
            else
                local fr, fg, fb = W.RGB(E.bg)
                b.fill:SetVertexColor(fr, fg, fb, b.hover and E.bgHoverA or E.bgA)
                b.label:SetTextColor(1, 1, 1, b.hover and E.textHoverA or E.textA)
            end
            if b.icon then ns.Icons:Tint(b.icon, on and "text.primary" or "text.secondary") end
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
        Skin:Border(self)
        Skin:SetBorderColor(self, 1, 1, 1, W.EUI.button.borderA)
        paint(self)
    end)
    s:SetItems(items or {})
    return s
end

---------------------------------------------------------------- tabs
--[[ Tab strip for sub-pages (GUI polish plan §1). Each tab is measured with its real font; when the strip runs out
    of room it first tightens its padding, then moves the tabs that do not fit into a "More" menu at the end, so tabs
    never run over each other, the page header or the buttons. The open tab is always on the strip (it takes the
    last visible place when it would be in the menu). Open tab: white on a soft accent pill with a 2 px accent
    underline; the others white 0.62 (0.86 hovered). items: { {value=, label=, icon=}, ... } ]]
local TAB_H, TAB_PAD, TAB_PAD_TIGHT, TAB_GAP = 30, 12, 7, 2
W.TAB_PAD, W.TAB_PAD_TIGHT = TAB_PAD, TAB_PAD_TIGHT
function W:Tabs(parent, items)
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(TAB_H + 4)
    t.tabs = {}
    t.items = items
    t.bg = W.Texture(t, "BACKGROUND")
    t.bg:SetPoint("TOPLEFT"); t.bg:SetPoint("BOTTOMLEFT")
    t.line = W.Texture(t, "BORDER")
    t.line:SetPoint("BOTTOMLEFT"); t.line:SetPoint("BOTTOMRIGHT")
    t.line:SetHeight(1)

    local function paint(self)
        self.line:SetVertexColor(1, 1, 1, 0.05)
        self.bg:SetVertexColor(0, 0, 0, 0)
        local N = W.EUI.nav
        local ar, ag, ab = ns.Theme:Color("accent.primary")
        local all = { unpack(self.tabs) }
        if self.more then all[#all + 1] = self.more end
        for _, b in ipairs(all) do
            local on = b.value ~= nil and b.value == self.value
            if on then b.fill:SetVertexColor(ar, ag, ab, 0.12)
            else b.fill:SetVertexColor(1, 1, 1, b.hover and 0.04 or 0) end
            b.bar:SetShown(on)
            if on then b.bar:SetVertexColor(ar, ag, ab, 1) end
            local a = on and N.selectedA or (b.hover and N.hoverA or 0.62)
            if b.icon then W.Color(b.icon, "text.primary", a) end
            Skin:Text(b.label, "body", "text.primary")
            b.label:SetTextColor(1, 1, 1, a)
        end
    end

    local function select(value)
        if t.value == value then return end
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        t.value = value
        t:Arrange()
        if t.onChange then t.onChange(t, value) end
    end

    local function tab(item)
        local b = CreateFrame("Button", nil, t)
        b:SetHeight(TAB_H)
        b.value = item and item.value
        b.fill = W.Texture(b, "BACKGROUND", 1)
        b.fill:SetAllPoints()
        Skin:RoundFill(b, b.fill, 6) -- design v2: the open tab sits on a soft accent pill
        b.bar = W.Texture(b, "ARTWORK", 2)
        b.bar:SetPoint("BOTTOMLEFT", 6, 0); b.bar:SetPoint("BOTTOMRIGHT", -6, 0); b.bar:SetHeight(2)
        if item and item.icon then b.icon = W.Icon(b, item.icon, 14) end
        b.label = W.Text(b, "body", "text.secondary", "LEFT")
        b.label:SetWordWrap(false)
        b:SetScript("OnEnter", function(btn) btn.hover = true; paint(t) end)
        b:SetScript("OnLeave", function(btn) btn.hover = false; paint(t) end)
        return b
    end

    for i, item in ipairs(items) do
        local b = tab(item)
        b.label:SetText(item.label)
        b:SetScript("OnClick", function(btn) select(btn.value) end)
        t.tabs[i] = b
    end
    -- the overflow menu: "More" lists the tabs that did not fit; it shows the open tab's name when that is inside
    t.more = tab(nil)
    t.more.chev = W.Icon(t.more, "chevron-down", 10)
    t.more:SetScript("OnClick", function(btn)
        local hidden = {}
        for _, b in ipairs(t.tabs) do if not b:IsShown() then hidden[#hidden + 1] = b end end
        if #hidden == 0 or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        MenuUtil.CreateContextMenu(btn, function(_, root)
            for _, b in ipairs(hidden) do
                root:CreateRadio(b.label:GetText() or "", function() return t.value == b.value end, function() select(b.value) end)
            end
        end)
    end)
    t.more:Hide()

    local function natural(b, pad)
        local left = pad + (b.icon and 20 or 0)
        return math.floor(b.label:GetUnboundedStringWidth() + left + pad + (b.chev and 14 or 0) + 0.5), left
    end
    local function place(b, x, pad)
        local w, left = natural(b, pad)
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", x, 1)
        b.x = x
        if b.icon then b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", pad, 0) end
        b.label:ClearAllPoints(); b.label:SetPoint("LEFT", left, 0)
        if b.chev then b.chev:ClearAllPoints(); b.chev:SetPoint("LEFT", b.label, "RIGHT", 5, 0) end
        b:Show()
        return x + w + TAB_GAP
    end

    -- lays the tabs out for the strip's width: full padding, then tight padding, then the More menu
    function t:Arrange()
        -- the labels get their font before they are measured (a stale font made German tabs overlap: layout_lint)
        for _, b in ipairs(self.tabs) do Skin:Text(b.label, "body", "text.primary") end
        Skin:Text(self.more.label, "body", "text.primary")
        local avail = self:GetWidth()
        if type(avail) ~= "number" or avail <= 0 then avail = math.huge end
        local function width(pad, list)
            local x = 2
            for _, b in ipairs(list) do x = x + natural(b, pad) + TAB_GAP end
            return x
        end
        local pad = width(TAB_PAD, self.tabs) <= avail and TAB_PAD or TAB_PAD_TIGHT
        local shown = { unpack(self.tabs) }
        self.overflow = width(pad, shown) > avail
        if self.overflow then
            self.more.label:SetText(ns.L and ns.L.TABS_MORE or "More")
            local moreW = natural(self.more, pad) + TAB_GAP
            while #shown > 1 and width(pad, shown) + moreW > avail do table.remove(shown) end
            -- the open tab is always on the strip: it takes the last visible place
            local open
            for _, b in ipairs(self.tabs) do if b.value == self.value then open = b end end
            local visible = false
            for _, b in ipairs(shown) do if b == open then visible = true end end
            if open and not visible then
                shown[#shown] = open
                while #shown > 1 and width(pad, shown) + moreW > avail do table.remove(shown, #shown - 1) end
            end
        end
        for _, b in ipairs(self.tabs) do b:Hide() end
        local x = 2
        for _, b in ipairs(shown) do x = place(b, x, pad) end
        if self.overflow then x = place(self.more, x, pad) else self.more:Hide() end
        self.pad = pad
        self.bg:SetWidth(x)
        paint(self)
    end

    t.value = items[1] and items[1].value
    function t:SetValue(v) self.value = v; self:Arrange() end
    function t:GetValue() return self.value end
    t:SetScript("OnSizeChanged", function(self) self:Arrange() end)
    Skin:Register(t, function(self) self:Arrange() end)
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
