local _, ns = ...
local L = ns.L
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media

--[[ Dropdown with a shared popup. Long lists get a type-to-filter search box, items may carry a
    group heading (item.group), and the "font" / "bar" previews draw every entry as a live sample:
    font names in their own face, statusbar textures as tinted strips. ]]
local ROW, HEAD, MAX_ROWS, SEARCH_AT, SEARCH_H = 24, 20, 12, 12, 34
local popup

local function fontOf(item) return item.font or Media:Font(item.value) end
local function barOf(item) return item.texture or Media:Bar(item.value) end

-- Visible entries: matching items with a heading row before each new group.
local function filter(items, query)
    local out, groups, lastGroup = {}, {}, nil
    for _, item in ipairs(items) do if item.group then groups[item.group] = true end end
    local multi = next(groups) ~= nil and next(groups, next(groups)) ~= nil
    query = query and query:lower() or ""
    for _, item in ipairs(items) do
        local label = tostring(item.label or item.value)
        if query == "" or label:lower():find(query, 1, true) then
            if multi and item.group ~= lastGroup then
                out[#out + 1] = { heading = item.group }
                lastGroup = item.group
            end
            out[#out + 1] = item
        end
    end
    return out
end

local function getPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(120)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    popup.rows = {}
    popup.offset = 0
    Skin:Register(popup, function(f) Skin:Panel(f, "raised", { border = "border.strong", shadow = 12 }) end)
    popup.scroll = W.Texture(popup, "OVERLAY", 2)
    popup.scroll:SetWidth(2)
    popup.search = W:Input(popup, 100, L.DROPDOWN_FILTER)
    popup.search:SetPoint("TOPLEFT", 6, -5)
    popup.search:SetPoint("TOPRIGHT", -6, -5)
    popup.search.onTextChanged = function(_, text)
        popup.query, popup.offset = text, 0
        popup.visible = filter(popup.items, text)
        popup:Render()
    end
    popup.search:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math.max(0, #self.visible - MAX_ROWS)
        self.offset = math.max(0, math.min(maxOffset, self.offset - delta))
        self:Render()
    end)
    -- Close when clicking anywhere else.
    popup:SetScript("OnEvent", function(self)
        if not self:IsMouseOver() and not self.owner:IsMouseOver() then self:Hide() end
    end)
    popup:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    popup:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        self.search:ClearFocus()
        if self.owner then self.owner:SetOpen(false) end
    end)

    function popup:Row(i)
        local r = self.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, self)
        r:SetHeight(ROW)
        r.hl = W.Texture(r, "BACKGROUND")
        r.hl:SetAllPoints()
        r.bar = W.Texture(r, "BORDER")
        r.bar:SetPoint("TOPLEFT", 6, -4); r.bar:SetPoint("BOTTOMRIGHT", -6, 4)
        r.label = W.Text(r, "body", "text.primary")
        r.label:SetPoint("RIGHT", -26, 0)
        r.icon = W.Icon(r, "user", 14)
        r.icon:SetPoint("LEFT", 10, 0)
        r.check = W.Icon(r, "check", 12, "accent.primary")
        r.check:SetPoint("RIGHT", -8, 0)
        r:SetScript("OnEnter", function(b) if not b.heading then W.Color(b.hl, "bg.hover") end end)
        r:SetScript("OnLeave", function(b) W.Color(b.hl, "bg.hover", 0) end)
        r:SetScript("OnClick", function(b)
            if b.heading then return end
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
        local top = self.hasSearch and SEARCH_H or 4
        local y = top
        for i = 1, MAX_ROWS do
            local item = self.visible[i + self.offset]
            local r = self:Row(i)
            if item then
                r.heading = item.heading ~= nil
                r:SetHeight(r.heading and HEAD or ROW)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 4, -y)
                r:SetPoint("TOPRIGHT", -6, -y)
                y = y + r:GetHeight()
                r.value = item.value
                r.label:ClearAllPoints()
                r.label:SetPoint("RIGHT", -26, 0)
                r.bar:Hide(); r.check:Hide(); r.icon:Hide()
                W.Color(r.hl, "bg.hover", 0)
                if r.heading then
                    r.label:SetPoint("LEFT", 10, -2)
                    Skin:Text(r.label, "heading", "text.muted")
                    r.label:SetText(tostring(item.heading):upper())
                else
                    if item.icon then
                        ns.Icons:Apply(r.icon, item.icon, 14)
                        ns.Icons:Tint(r.icon, item.value == owner.value and "accent.primary" or "text.secondary")
                        r.icon:Show()
                        r.label:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
                    else
                        r.label:SetPoint("LEFT", owner.preview == "bar" and 14 or 10, 0)
                    end
                    if owner.preview == "font" then
                        r.label:SetFont(fontOf(item), 13, "")
                    else
                        Skin:Text(r.label, "body", "text.primary")
                    end
                    if owner.preview == "bar" then
                        r.bar:SetTexture(barOf(item))
                        -- neutral light tint shows the texture's own shading; the chosen one wears the accent
                        if item.value == owner.value then W.Color(r.bar, "accent.primary", 0.95)
                        else W.Color(r.bar, "text.secondary", 0.9) end
                        r.bar:Show()
                        r.label:SetShadowColor(0, 0, 0, 1)
                        r.label:SetShadowOffset(1, -1)
                    end
                    r.label:SetText(item.label)
                    r.label:SetTextColor(Theme:Color(item.value == owner.value and "accent.text" or "text.primary"))
                    if owner.preview == "bar" then r.label:SetTextColor(Theme:Color("text.primary")) end
                    r.check:SetShown(item.value == owner.value)
                end
                r:Show()
            else
                r:Hide()
            end
        end
        local n = #self.visible
        if n > MAX_ROWS then
            local h = self:GetHeight() - top - 4
            self.scroll:SetHeight(h * MAX_ROWS / n)
            self.scroll:ClearAllPoints()
            self.scroll:SetPoint("TOPRIGHT", -3, -top - h * self.offset / n)
            W.Color(self.scroll, "accent.primary", 0.8)
            self.scroll:Show()
        else
            self.scroll:Hide()
        end
    end
    popup:Hide()
    W.PopoverKeepOpen(popup) -- choosing from a list inside a cog popover keeps the popover open
    return popup
end

-- items: { {value=, label=, icon=?, group=?, font=?, texture=?}, ... } or function() -> items.
-- preview: nil | "font" | "bar"
function W:Dropdown(parent, items, preview, width)
    local d = CreateFrame("Button", nil, parent)
    d:SetSize(width or W.CONTROL_WIDTH, 26)
    d.items, d.preview = items, preview
    d.strip = W.Texture(d, "BORDER")
    d.strip:SetPoint("TOPLEFT", 4, -4); d.strip:SetPoint("BOTTOMRIGHT", -24, 4)
    d.strip:Hide()
    d.label = W.Text(d, "body", "text.primary")
    d.label:SetPoint("LEFT", 10, 0)
    d.label:SetPoint("RIGHT", -26, 0)
    d.icon = W.Icon(d, "user", 14, "accent.primary")
    d.icon:SetPoint("LEFT", 9, 0)
    d.icon:Hide()
    d.arrow = W.Icon(d, "chevron-down", 12)
    d.arrow:SetPoint("RIGHT", -9, 0)

    local function sample(self)
        local item = self.current
        if self.preview == "font" and item then self.label:SetFont(fontOf(item), 12, "") end
        if self.preview == "bar" and item then
            self.strip:SetTexture(barOf(item))
            W.Color(self.strip, "accent.primary", 0.7)
            self.strip:Show()
            self.label:SetShadowColor(0, 0, 0, 1)
            self.label:SetShadowOffset(1, -1)
        else
            self.strip:Hide()
        end
    end

    Skin:Register(d, function(self)
        Skin:Panel(self, "sunken", { border = self.open and "accent.primary" or "border.subtle" })
        Skin:Text(self.label, "body", "text.primary")
        sample(self)
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
        self.current = nil
        local text, icon = tostring(v or ""), nil
        for _, item in ipairs(self:GetItems()) do
            if item.value == v then text, icon, self.current = item.label, item.icon, item end
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
        Skin:Text(self.label, "body", "text.primary")
        sample(self)
    end
    function d:GetValue() return self.value end
    d.SetEnabledState = W.SetEnabledState

    d:SetScript("OnClick", function(self)
        if self.disabled then return end
        local p = getPopup()
        if p:IsShown() and p.owner == self then p:Hide(); return end
        p:Hide()
        p.owner, p.items, p.offset, p.query = self, self:GetItems(), 0, ""
        p.hasSearch = #p.items >= SEARCH_AT
        p.search:SetShown(p.hasSearch)
        p.search:SetValue("")
        p.visible = filter(p.items, "")
        for i, item in ipairs(p.visible) do
            if item.value == self.value and i > MAX_ROWS then p.offset = math.max(0, math.min(i - 3, #p.visible - MAX_ROWS)) end
        end
        local rows = math.min(#p.visible, MAX_ROWS)
        p:SetSize(math.max(self:GetWidth(), self.preview and 240 or 180),
            rows * ROW + (p.hasSearch and SEARCH_H or 4) + 4)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
        self:SetOpen(true)
        p:Render()
        ns.Anim:FadeIn(p, 0.1)
        if p.hasSearch then p.search:SetFocus() end
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
    end)
    d:SetScript("OnHide", function(self) if popup and popup.owner == self then popup:Hide() end end)
    return d
end
