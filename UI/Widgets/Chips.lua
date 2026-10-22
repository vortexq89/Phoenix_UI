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

--[[ W:OrderChips(parent, spec): drag-to-reorder chips (Data Texts segments, bag categories). Drag a chip and drop
    it where the accent marker shows. spec = { order = fn() -> keys, label = fn(key), icon = fn(key)|nil,
    dimmed = fn(key), tip = fn(key), onReorder = fn(keys), onRightClick = fn(key)|nil }.
    :Layout() redraws from spec.order(); :SetValue() does the same (settings rows call it on reset). ]]
local CHIP_H, CHIP_GAP = 26, 6
function W:OrderChips(parent, spec)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(2 * CHIP_H + CHIP_GAP)
    holder.chips = {}
    holder.marker = W.Texture(holder, "OVERLAY", 2, Media.textures.WHITE)
    holder.marker:SetSize(2, CHIP_H)
    holder.marker:Hide()
    Skin:Register(holder.marker, function(t) W.Color(t, "accent.primary") end)

    local function chip(key)
        local c = holder.chips[key]
        if c then return c end
        c = CreateFrame("Button", nil, holder)
        c:SetHeight(CHIP_H)
        local icon = spec.icon and spec.icon(key)
        if icon then
            c.icon = W.Icon(c, icon, 13, "accent.primary")
            c.icon:SetPoint("LEFT", 8, 0)
        end
        c.text = W.Text(c, "small", "text.primary", "LEFT")
        c.text:SetPoint("LEFT", c.icon or c, c.icon and "RIGHT" or "LEFT", c.icon and 6 or 10, 0)
        c.text:SetText(spec.label(key))
        c:SetWidth(c.text:GetUnboundedStringWidth() + (c.icon and 38 or 20))
        c:RegisterForDrag("LeftButton")
        c:RegisterForClicks("RightButtonUp")
        c.key = key
        Skin:Register(c, function(self) Skin:Panel(self, "sunken", { border = "border.default" }) end)
        c:SetScript("OnEnter", function(self) W.ShowTooltip(self, spec.label(key), spec.tip and spec.tip(key)) end)
        c:SetScript("OnLeave", W.HideTooltip)
        c:SetScript("OnDragStart", function(self) holder:BeginDrag(self) end)
        c:SetScript("OnDragStop", function() holder:EndDrag() end)
        c:SetScript("OnClick", function() if spec.onRightClick then spec.onRightClick(key); holder:Layout() end end)
        holder.chips[key] = c
        return c
    end

    -- Lays the chips out left to right, wrapping; keeps the slot rectangles for the drop test.
    function holder:Layout()
        local width = self:GetWidth()
        if not width or width <= 0 then width = W.CONTROL_WIDTH * 2 end
        local x, y = 0, 0
        self.slots = {}
        local order = spec.order()
        for i, key in ipairs(order) do
            local c = chip(key)
            if x > 0 and x + c:GetWidth() > width then x, y = 0, y - (CHIP_H + CHIP_GAP) end
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", x, y)
            c:SetAlpha(spec.dimmed and spec.dimmed(key) and 0.45 or 1)
            c:Show()
            self.slots[i] = { key = key, x = x, y = y, w = c:GetWidth() }
            x = x + c:GetWidth() + CHIP_GAP
        end
        for key, c in pairs(self.chips) do
            local listed = false
            for _, k in ipairs(order) do if k == key then listed = true end end
            if not listed then c:Hide() end
        end
        self:SetHeight(-y + CHIP_H)
    end

    function holder:SetValue() self:Layout() end

    -- Index the dragged chip would take for the cursor position, from the slot rectangles.
    local function dropIndex()
        local cx, cy = GetCursorPosition()
        local scale = holder:GetEffectiveScale()
        local left, top = holder:GetLeft(), holder:GetTop()
        if not (left and top) then return nil end
        cx, cy = cx / scale - left, cy / scale - top
        local best, bestDist = #holder.slots + 1, math.huge
        for i, sl in ipairs(holder.slots) do
            local mid = sl.y - CHIP_H / 2
            if math.abs(cy - mid) <= CHIP_H then
                local d = math.abs(cx - sl.x)
                if d < bestDist then best, bestDist = i, d end
                local dEnd = math.abs(cx - (sl.x + sl.w))
                if dEnd < bestDist then best, bestDist = i + 1, dEnd end
            end
        end
        return best
    end
    holder.DropIndex = dropIndex

    function holder:BeginDrag(c)
        self.dragging = c
        c:SetAlpha(0.6)
        self:SetScript("OnUpdate", function()
            local i = dropIndex()
            local sl = i and (self.slots[i] or self.slots[#self.slots])
            if not sl then self.marker:Hide(); return end
            local x = self.slots[i] and sl.x - CHIP_GAP / 2 - 1 or sl.x + sl.w + CHIP_GAP / 2 - 1
            self.marker:ClearAllPoints()
            self.marker:SetPoint("TOPLEFT", x, sl.y)
            self.marker:Show()
        end)
    end

    -- Moves key from its index to target (an insertion index before the move) and saves the list.
    function holder:Move(key, target)
        local order = spec.order()
        local from
        for i, k in ipairs(order) do if k == key then from = i end end
        if target and from and target ~= from and target ~= from + 1 then
            table.remove(order, from)
            if target > from then target = target - 1 end
            table.insert(order, target, key)
            spec.onReorder(order)
        end
        self:Layout()
    end

    function holder:EndDrag()
        local c = self.dragging
        self:SetScript("OnUpdate", nil)
        self.marker:Hide()
        self.dragging = nil
        if c then self:Move(c.key, dropIndex()) end
    end

    holder:SetScript("OnSizeChanged", function(self) self:Layout() end)
    holder:Layout()
    return holder
end
