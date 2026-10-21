local _, ns = ...
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media

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

-- Track with accent fill, round thumb and an editable value box.
function W:Slider(parent, min, max, step, isPercent)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(W.CONTROL_WIDTH, 22)
    s.min, s.max, s.step, s.isPercent = min, max, step, isPercent
    s.value = min

    local bar = CreateFrame("Button", nil, s)
    bar:SetPoint("LEFT", 0, 0)
    bar:SetPoint("RIGHT", -56, 0)
    bar:SetHeight(18)
    s.bar = bar
    s.track = W.Texture(bar, "ARTWORK", 0, Media.textures.PILL)
    s.track:SetPoint("LEFT"); s.track:SetPoint("RIGHT"); s.track:SetHeight(4)
    s.fill = W.Texture(bar, "ARTWORK", 1, Media.textures.PILL)
    s.fill:SetPoint("LEFT"); s.fill:SetHeight(4)
    s.glow = W.Texture(bar, "ARTWORK", 2, Media.textures.CIRCLE)
    s.glow:SetSize(24, 24)
    s.thumb = W.Texture(bar, "OVERLAY", 3, Media.textures.CIRCLE)
    s.thumb:SetSize(14, 14)

    local box = CreateFrame("EditBox", nil, s)
    box:SetSize(48, 22)
    box:SetPoint("RIGHT")
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    box:SetTextInsets(2, 2, 0, 0)
    s.box = box

    local function layout(self)
        local w = self.bar:GetWidth()
        local p = (self.max > self.min) and (self.value - self.min) / (self.max - self.min) or 0
        local x = math.max(0, math.min(w, w * p))
        self.fill:SetWidth(math.max(0.01, x))
        self.thumb:ClearAllPoints(); self.thumb:SetPoint("CENTER", self.bar, "LEFT", x, 0)
        self.glow:ClearAllPoints(); self.glow:SetPoint("CENTER", self.thumb)
        if not self.box:HasFocus() then self.box:SetText(fmt(self.value, self.step, self.isPercent)) end
    end

    Skin:Register(s, function(self)
        W.Color(self.track, "border.subtle")
        self.fill:SetVertexColor(1, 1, 1, 1)
        Skin:Gradient(self.fill, "HORIZONTAL", "accent.primary", "accent.secondary")
        self.thumb:SetVertexColor(1, 1, 1, 1)
        W.Color(self.glow, "accent.glow", self.dragging and 0.7 or 0)
        Skin:Panel(self.box, "sunken", { border = "border.subtle" })
        self.box:SetFont(Theme:Font("number"))
        self.box:SetTextColor(Theme:Color("text.primary"))
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
        W.Color(s.glow, "accent.glow", 0.7)
        setFromCursor(s)
        bar:SetScript("OnUpdate", function() setFromCursor(s) end)
    end)
    bar:SetScript("OnMouseUp", function()
        s.dragging = false
        W.Color(s.glow, "accent.glow", 0)
        bar:SetScript("OnUpdate", nil)
        if s.onCommit then s.onCommit(s, s.value) end
    end)
    bar:SetScript("OnEnter", function() if not s.dragging then W.Color(s.glow, "accent.glow", 0.35) end end)
    bar:SetScript("OnLeave", function() if not s.dragging then W.Color(s.glow, "accent.glow", 0) end end)
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
    box:SetScript("OnEditFocusGained", function(self) Skin:SetBorderColor(self, "accent.primary"); self:HighlightText() end)
    box:SetScript("OnEditFocusLost", function(self) Skin:SetBorderColor(self, "border.subtle"); layout(s) end)

    function s:SetValue(v) self.value = snap(tonumber(v) or self.min, self.min, self.max, self.step); layout(self) end
    function s:GetValue() return self.value end
    s.SetEnabledState = W.SetEnabledState
    return s
end
