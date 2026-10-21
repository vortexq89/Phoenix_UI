local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin

-- Swatch that opens Blizzard's ColorPickerFrame through SetupColorPickerAndShow (never by writing its fields).
-- Values use the same shape as the saved settings: { r = , g = , b = [, a = ] }.
function W:ColorSwatch(parent, hasAlpha)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(44, 24)
    c.hasAlpha = hasAlpha
    c.checker = W.Texture(c, "BACKGROUND", 1)
    c.checker:SetPoint("TOPLEFT", 3, -3); c.checker:SetPoint("BOTTOMRIGHT", -3, 3)
    c.swatch = W.Texture(c, "ARTWORK")
    c.swatch:SetPoint("TOPLEFT", 3, -3); c.swatch:SetPoint("BOTTOMRIGHT", -3, 3)
    c.value = { r = 1, g = 1, b = 1 }

    local function paint(self)
        local v = self.value
        self.swatch:SetVertexColor(v.r, v.g, v.b, v.a or 1)
    end

    Skin:Register(c, function(self)
        Skin:Panel(self, "sunken", { border = "border.strong" })
        W.Color(self.checker, "border.strong")
        paint(self)
    end)
    c:SetScript("OnEnter", function(self) if not self.disabled then Skin:SetBorderColor(self, "accent.primary") end end)
    c:SetScript("OnLeave", function(self) Skin:SetBorderColor(self, "border.strong") end)

    local function commit(self, r, g, b, a)
        self.value = { r = r, g = g, b = b, a = self.hasAlpha and a or nil }
        paint(self)
        if self.onChange then self.onChange(self, self.value) end
    end

    local function fromPicker(self)
        local r, g, b = ColorPickerFrame:GetColorRGB()
        commit(self, r, g, b, ColorPickerFrame:GetColorAlpha())
    end

    c:SetScript("OnClick", function(self)
        if self.disabled then return end
        local v = self.value
        local prev = { v.r, v.g, v.b, v.a }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = v.r, g = v.g, b = v.b, opacity = v.a or 1, hasOpacity = self.hasAlpha,
            swatchFunc = function() fromPicker(self) end,
            opacityFunc = function() fromPicker(self) end,
            cancelFunc = function() commit(self, prev[1], prev[2], prev[3], prev[4]) end,
        })
    end)
    function c:SetValue(v)
        if type(v) ~= "table" then return end
        self.value = { r = v.r or 1, g = v.g or 1, b = v.b or 1, a = v.a }
        paint(self)
    end
    function c:GetValue() return self.value end
    c.SetEnabledState = W.SetEnabledState
    return c
end
