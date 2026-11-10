local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin

--[[ ScrollFrame with a slim themed bar (no Blizzard scroll templates). GUI polish plan §6: the thumb is a 4 px
    rounded pill in the 8 px gutter right of the content (content never sits under it), brighter while the pointer
    is over the list, accent while it is dragged. It can be dragged, and a click in the gutter jumps there. The drag
    follows the pointer on a C_Timer ticker that stops on release (no OnUpdate). ]]
local BAR_W, GUTTER, MIN_THUMB = 4, 8, 28

function W:Scroll(parent)
    local s = CreateFrame("ScrollFrame", nil, parent)
    s.child = CreateFrame("Frame", nil, s)
    s.child:SetSize(1, 1)
    s:SetScrollChild(s.child)
    s:EnableMouseWheel(true)
    -- the gutter and the thumb are siblings of the scroll frame: a scroll frame clips what it holds
    s.gutter = CreateFrame("Button", nil, parent)
    s.gutter:SetPoint("TOPLEFT", s, "TOPRIGHT", 0, 0)
    s.gutter:SetPoint("BOTTOMLEFT", s, "BOTTOMRIGHT", 0, 0)
    s.gutter:SetWidth(GUTTER)
    s.gutter:SetFrameLevel(s:GetFrameLevel() + 5)
    s.track = W.Texture(s.gutter, "BACKGROUND", 1)
    s.track:SetPoint("TOP", 0, 0); s.track:SetPoint("BOTTOM", 0, 0)
    s.track:SetWidth(1)
    s.grip = CreateFrame("Button", nil, s.gutter)
    s.grip:SetWidth(GUTTER)
    s.thumb = W.Texture(s.grip, "ARTWORK", 2)
    Skin:RoundFill(s.grip, s.thumb, BAR_W / 2, (GUTTER - BAR_W) / 2, 0)

    local function range() return math.max(0, s:GetVerticalScrollRange() or 0) end
    local function paint()
        local hot = s.dragging or s.grip.hover
        if hot then
            W.Color(s.thumb, "accent.primary", 1)
        else
            s.thumb:SetVertexColor(1, 1, 1, (s.hover or s.gutter.hover) and 0.34 or 0.18)
        end
        s.track:SetVertexColor(1, 1, 1, 0.05)
    end

    function s:UpdateBar()
        local r, h = range(), self:GetHeight()
        if r <= 0.5 or not h or h <= 0 then
            self.gutter:Hide()
            return
        end
        local thumbH = math.max(MIN_THUMB, h * h / (h + r))
        local y = (h - thumbH) * math.min(1, self:GetVerticalScroll() / r)
        self.thumbH = thumbH
        self.grip:SetHeight(thumbH)
        self.grip:ClearAllPoints()
        self.grip:SetPoint("TOPLEFT", self.gutter, "TOPLEFT", 0, -y)
        self.gutter:Show()
        paint()
    end

    -- the scroll offset that puts the thumb's middle at the pointer
    local function scrollAtCursor()
        local _, cy = GetCursorPosition()
        local top, h = s:GetTop(), s:GetHeight()
        local scale = s:GetEffectiveScale()
        if type(cy) ~= "number" or not (top and h and scale and scale > 0) then return nil end
        local thumbH = s.thumbH or MIN_THUMB
        local free = h - thumbH
        if free <= 0 then return 0 end
        local at = (top - cy / scale) - thumbH / 2 + (s.dragOffset or 0)
        return math.max(0, math.min(1, at / free)) * range()
    end
    local function stopDrag()
        s.dragging = nil
        if s.ticker then s.ticker:Cancel(); s.ticker = nil end
        paint()
    end
    s.grip:SetScript("OnMouseDown", function()
        s.dragging, s.dragOffset = true, 0
        -- keep the spot of the thumb that was grabbed under the pointer
        local want = scrollAtCursor()
        if want and range() > 0 then
            local free = s:GetHeight() - (s.thumbH or MIN_THUMB)
            s.dragOffset = (s:GetVerticalScroll() - want) / range() * free
        end
        s.ticker = C_Timer.NewTicker(0.016, function()
            if not (s.dragging and IsMouseButtonDown("LeftButton")) then return stopDrag() end
            local v = scrollAtCursor()
            if v then s:SetVerticalScroll(v); s:UpdateBar() end
        end)
        paint()
    end)
    s.grip:SetScript("OnMouseUp", stopDrag)
    s.grip:SetScript("OnHide", stopDrag)
    s.grip:SetScript("OnEnter", function(self) self.hover = true; paint() end)
    s.grip:SetScript("OnLeave", function(self) self.hover = false; paint() end)
    s.gutter:SetScript("OnEnter", function(self) self.hover = true; paint() end)
    s.gutter:SetScript("OnLeave", function(self) self.hover = false; paint() end)
    s.gutter:SetScript("OnClick", function()
        s.dragOffset = 0
        local v = scrollAtCursor()
        if v then s:SetVerticalScroll(v); s:UpdateBar() end
    end)

    s:SetScript("OnMouseWheel", function(self, delta)
        local r = range()
        local target = math.max(0, math.min(r, self:GetVerticalScroll() - delta * 48))
        ns.Anim:Tween(self, 0.12, self:GetVerticalScroll(), target, function(v)
            self:SetVerticalScroll(v)
            self:UpdateBar()
        end)
    end)
    s:SetScript("OnScrollRangeChanged", function(self) self:UpdateBar() end)
    s:SetScript("OnSizeChanged", function(self, w)
        self.child:SetWidth(w)
        self:UpdateBar()
    end)
    s:SetScript("OnEnter", function(self) self.hover = true; self:UpdateBar() end)
    s:SetScript("OnLeave", function(self) self.hover = false; self:UpdateBar() end)
    s:SetScript("OnHide", function(self) self.gutter:Hide() end)
    s:SetScript("OnShow", function(self) self:UpdateBar() end)
    s.gutter:Hide()
    return s
end
