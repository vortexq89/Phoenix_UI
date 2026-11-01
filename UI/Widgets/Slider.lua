local _, ns = ...
local W, Theme, Skin = ns.Widgets, ns.Theme, ns.Skin

local function snap(v, min, max, step)
    v = math.max(min, math.min(max, v))
    if step and step > 0 then v = min + math.floor((v - min) / step + 0.5) * step end
    return ns.Util.Round(v, 4)
end

local function fmt(v, step, isPercent)
    if isPercent then return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
    if step and step >= 1 then return ("%d"):format(v) end
    local text = ("%.2f"):format(v):gsub("0+$", "")
    return (text:gsub("%.$", ""))
end

-- EllesmereUI slider (specs/001 FR-003): a flat 4 px track (white 0.16), an accent fill (0.75), a square 14 px accent
-- thumb and a 40x26 value box (dark at 0.25, white 0.02 border, dim text).
function W:Slider(parent, min, max, step, isPercent)
    local E = W.EUI.slider
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(W.CONTROL_WIDTH, 26)
    s.min, s.max, s.step, s.isPercent = min, max, step, isPercent
    s.value = min

    local bar = CreateFrame("Button", nil, s)
    bar:SetPoint("LEFT", 0, 0)
    bar:SetPoint("RIGHT", -52, 0)
    bar:SetHeight(20)
    s.bar = bar
    s.track = W.Texture(bar, "ARTWORK", 0)
    s.track:SetPoint("LEFT"); s.track:SetPoint("RIGHT"); s.track:SetHeight(4)
    s.fill = W.Texture(bar, "ARTWORK", 1)
    s.fill:SetPoint("LEFT"); s.fill:SetHeight(4)
    s.thumb = W.Texture(bar, "OVERLAY", 3)
    s.thumb:SetSize(14, 14)

    local box = CreateFrame("EditBox", nil, s)
    box:SetSize(40, 26)
    box:SetPoint("RIGHT")
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    box:SetTextInsets(2, 2, 0, 0)
    box:SetMaxLetters(7)
    s.box = box
    box.bg = W.Texture(box, "BACKGROUND", 0)
    box.bg:SetAllPoints()
    box.bg:SetVertexColor(E.input[1], E.input[2], E.input[3], E.inputA)
    Skin:Border(box)

    local function layout(self)
        local w = self.bar:GetWidth()
        local p = (self.max > self.min) and (self.value - self.min) / (self.max - self.min) or 0
        local x = math.max(0, math.min(w, w * p))
        self.fill:SetWidth(math.max(0.01, x))
        self.thumb:ClearAllPoints(); self.thumb:SetPoint("CENTER", self.bar, "LEFT", x, 0)
        if not self.box:HasFocus() then self.box:SetText(fmt(self.value, self.step, self.isPercent)) end
    end

    Skin:Register(s, function(self)
        self.track:SetVertexColor(1, 1, 1, E.trackA)
        local r, g, b = Theme:Color("accent.primary")
        self.fill:SetVertexColor(r, g, b, E.fillA)
        self.thumb:SetVertexColor(r, g, b, 1)
        Skin:SetBorderColor(self.box, 1, 1, 1, E.inputBorderA)
        self.box:SetFont(Theme:Font("number"))
        local tr, tg, tb = Theme:Color("text.secondary")
        self.box:SetTextColor(tr, tg, tb, 1)
        layout(self)
    end)

    local function setFromCursor(self)
        local left, w = self.bar:GetLeft(), self.bar:GetWidth()
        if not left or w <= 0 then return end
        local x = GetCursorPosition() / self.bar:GetEffectiveScale()
        local v = snap(self.min + (x - left) / w * (self.max - self.min), self.min, self.max, self.step)
        if v ~= self.value then
            self.value = v
            layout(self)
            if self.onChange then self.onChange(self, v) end
        end
    end

    bar:SetScript("OnMouseDown", function()
        if s.disabled then return end
        s.dragging = true
        setFromCursor(s)
        -- follows the cursor on a C_Timer ticker while the button is held (no OnUpdate)
        if s.dragTicker then s.dragTicker:Cancel() end
        s.dragTicker = C_Timer.NewTicker(0.016, function() setFromCursor(s) end)
    end)
    bar:SetScript("OnMouseUp", function()
        s.dragging = false
        if s.dragTicker then s.dragTicker:Cancel(); s.dragTicker = nil end
        if s.onCommit then s.onCommit(s, s.value) end
    end)
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(_, delta)
        if s.disabled then return end
        local v = snap(s.value + delta * (s.step or (s.max - s.min) / 20), s.min, s.max, s.step)
        if v ~= s.value then s.value = v; layout(s); if s.onChange then s.onChange(s, v) end end
    end)
    bar:SetScript("OnSizeChanged", function() layout(s) end)

    box:SetScript("OnEnterPressed", function(self)
        local text = self:GetText():gsub("%%", "")
        local n = tonumber(text)
        if n then
            if s.isPercent then n = n / 100 end
            s.value = snap(n, s.min, s.max, s.step)
            if s.onChange then s.onChange(s, s.value) end
        end
        self:ClearFocus()
        layout(s)
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); layout(s) end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnEditFocusLost", function() layout(s) end)

    function s:SetValue(v) self.value = snap(tonumber(v) or self.min, self.min, self.max, self.step); layout(self) end
    function s:GetValue() return self.value end
    s.SetEnabledState = W.SetEnabledState
    return s
end
