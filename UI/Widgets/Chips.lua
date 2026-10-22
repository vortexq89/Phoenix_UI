local _, ns = ...
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media

--[[ Chips: a wrapping row of pill buttons. Used for element switchers (Bar 1 … Pet, Player … Arena), preview
    states, filters and module pickers.
    W:Chips(parent, items, multi) with items { {value=, label=, icon=?, tip=?}, ... }
      single: value is the picked key; Shift-click adds or removes a chip in :GetExtra() (the "also edit" set)
      multi:  value is a set { [value] = true }
    :SetWidth(w) re-wraps; the height follows the rows (:GetHeight()). onChange(self, value, shift). ]]
local H, GAP, PADX = 22, 6, 12

local function paintChip(c, on, extra)
    local hover = c.hover and not c.owner.disabled
    W.Color(c.edge, on and "accent.primary" or (extra and "accent.secondary") or (hover and "border.strong" or "border.subtle"),
        (on or extra) and 0.9 or 1)
    W.Color(c.fill, on and "accent.soft" or (hover and "bg.hover" or "bg.sunken"))
    -- accent.soft is translucent: it lies over a sunken base so an active chip reads on any panel
    W.Color(c.base, "bg.sunken")
    Skin:Text(c.label, "small", on and "accent.text" or ((hover or extra) and "text.primary" or "text.secondary"))
    if c.icon then ns.Icons:Tint(c.icon, on and "accent.primary" or "text.muted") end
end

function W:Chips(parent, items, multi)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(10, H)
    s.multi, s.chips, s.extra = multi, {}, {}
    s.value = multi and {} or nil

    function s:Paint()
        for _, c in ipairs(self.chips) do
            if c:IsShown() then
                local on
                if self.multi then on = self.value[c.value] == true else on = self.value == c.value end
                paintChip(c, on, not self.multi and self.extra[c.value])
            end
        end
    end

    local function chip(i)
        local c = s.chips[i]
        if c then return c end
        c = CreateFrame("Button", nil, s)
        c.owner = s
        c:SetHeight(H)
        c.edge = W.Texture(c, "BACKGROUND", 0, Media.textures.PILL)
        c.edge:SetAllPoints()
        c.base = W.Texture(c, "BACKGROUND", 1, Media.textures.PILL)
        c.base:SetPoint("TOPLEFT", 1, -1); c.base:SetPoint("BOTTOMRIGHT", -1, 1)
        c.fill = W.Texture(c, "BACKGROUND", 2, Media.textures.PILL)
        c.fill:SetPoint("TOPLEFT", 1, -1); c.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        c.label = W.Text(c, "small", "text.secondary", "CENTER")
        c:SetScript("OnEnter", function(self)
            self.hover = true
            s:Paint()
            if self.tip then W.ShowTooltip(self, self.label:GetText(), self.tip) end
        end)
        c:SetScript("OnLeave", function(self) self.hover = false; s:Paint(); W.HideTooltip() end)
        c:SetScript("OnClick", function(self)
            if s.disabled then return end
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            local shift = IsShiftKeyDown()
            if s.multi then
                s.value[self.value] = not s.value[self.value] or nil
            elseif shift and self.value ~= s.value then
                s.extra[self.value] = not s.extra[self.value] or nil
            else
                s.value = self.value
                s.extra[self.value] = nil
            end
            s:Paint()
            if s.onChange then s.onChange(s, s.value, shift and not s.multi) end
        end)
        Skin:Register(c, function() s:Paint() end)
        s.chips[i] = c
        return c
    end

    function s:Arrange()
        local width = self:GetWidth()
        if not width or width < 40 then width = 10000 end
        local x, y, rowW = 0, 0, 0
        for _, c in ipairs(self.chips) do
            if c:IsShown() then
                local w = c:GetWidth()
                if x > 0 and x + w > width then
                    x, y = 0, y + H + GAP
                end
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", x, -y)
                x = x + w + GAP
                rowW = math.max(rowW, x - GAP)
            end
        end
        self.naturalWidth = rowW
        self:SetHeight(y + H)
    end

    function s:SetItems(list)
        for _, c in ipairs(self.chips) do c:Hide() end
        for i, item in ipairs(list) do
            local c = chip(i)
            c.value, c.tip = item.value, item.tip
            c.label:SetText(item.label or tostring(item.value))
            if item.icon then
                c.icon = c.icon or W.Icon(c, item.icon, 11)
                ns.Icons:Apply(c.icon, item.icon, 11)
                c.icon:ClearAllPoints()
                c.icon:SetPoint("LEFT", PADX - 2, 0)
                c.icon:Show()
                c.label:SetPoint("CENTER", 7, 0)
            else
                if c.icon then c.icon:Hide(); c.icon = nil end
                c.label:SetPoint("CENTER", 0, 0)
            end
            c:SetWidth(math.floor(c.label:GetUnboundedStringWidth() + PADX * 2 + (item.icon and 14 or 0) + 0.5))
            c:Show()
        end
        self:Arrange()
        self:Paint()
    end

    function s:SetValue(v)
        if self.multi then self.value = type(v) == "table" and v or {} else self.value = v; wipe(self.extra) end
        self:Paint()
    end
    function s:GetValue() return self.value end
    -- single mode: the chips Shift-clicked besides the picked one
    function s:GetExtra() return self.extra end
    function s:ClearExtra() wipe(self.extra); self:Paint() end
    s.SetEnabledState = W.SetEnabledState
    s:SetScript("OnSizeChanged", function(self) self:Arrange() end)
    s:SetItems(items or {})
    return s
end
