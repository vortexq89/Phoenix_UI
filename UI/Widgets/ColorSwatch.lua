local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin

-- Swatch that opens Blizzard's ColorPickerFrame (via SetupColorPickerAndShow, never by writing its fields).
-- Value is { r, g, b[, a] }.
function W:ColorSwatch(parent, hasAlpha)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(44, 22)
    c.hasAlpha = hasAlpha
    c.checker = W.Texture(c, "BACKGROUND", 1)
    c.checker:SetPoint("TOPLEFT", 3, -3); c.checker:SetPoint("BOTTOMRIGHT", -3, 3)
    c.swatch = W.Texture(c, "ARTWORK")
    c.swatch:SetPoint("TOPLEFT", 3, -3); c.swatch:SetPoint("BOTTOMRIGHT", -3, 3)
    c.value = { 1, 1, 1, 1 }
    Skin:Register(c, function(self)
        Skin:Panel(self, "sunken", { border = "border.strong" })
        W.Color(self.checker, "border.strong")
        self.swatch:SetVertexColor(self.value[1], self.value[2], self.value[3], self.value[4] or 1)
    end)
    c:SetScript("OnEnter", function(self) if not self.disabled then Skin:SetBorderColor(self, "accent.primary") end end)
    c:SetScript("OnLeave", function(self) Skin:SetBorderColor(self, "border.strong") end)

    local function commit(self, r, g, b, a)
        self.value = { r, g, b, a }
        self.swatch:SetVertexColor(r, g, b, a or 1)
        if self.onChange then self.onChange(self, self.value) end
    end

    c:SetScript("OnClick", function(self)
        if self.disabled then return end
        local v = self.value
        local prev = { v[1], v[2], v[3], v[4] }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = v[1], g = v[2], b = v[3], opacity = v[4] or 1, hasOpacity = self.hasAlpha,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                commit(self, r, g, b, self.hasAlpha and ColorPickerFrame:GetColorAlpha() or nil)
            end,
            opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                commit(self, r, g, b, ColorPickerFrame:GetColorAlpha())
            end,
            cancelFunc = function() commit(self, prev[1], prev[2], prev[3], prev[4]) end,
        })
    end)
    function c:SetValue(v)
        if type(v) ~= "table" then return end
        self.value = { v[1] or 1, v[2] or 1, v[3] or 1, v[4] }
        self.swatch:SetVertexColor(self.value[1], self.value[2], self.value[3], self.value[4] or 1)
    end
    function c:GetValue() return self.value end
    c.SetEnabledState = W.SetEnabledState
    return c
end
