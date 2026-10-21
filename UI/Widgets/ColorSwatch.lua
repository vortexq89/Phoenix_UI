local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin

-- Swatch that opens Blizzard's ColorPickerFrame through SetupColorPickerAndShow (never by writing its fields).
-- Values use the same shape as the saved settings: { r = , g = , b = [, a = ] }. With a token set, false
-- means "follow the theme": the swatch shows the token's colour and right-click returns to it.
function W:ColorSwatch(parent, hasAlpha, token)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(44, 24)
    c.hasAlpha = hasAlpha
    c.checker = W.Texture(c, "BACKGROUND", 1)
    c.checker:SetPoint("TOPLEFT", 3, -3); c.checker:SetPoint("BOTTOMRIGHT", -3, 3)
    c.swatch = W.Texture(c, "ARTWORK")
    c.swatch:SetPoint("TOPLEFT", 3, -3); c.swatch:SetPoint("BOTTOMRIGHT", -3, 3)
    c.value = { r = 1, g = 1, b = 1 }
    c.token = token
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local function paint(self)
        local v = self.value
        if type(v) ~= "table" then
            local r, g, b, a = ns.Theme:Color(self.token or "text.primary")
            self.swatch:SetVertexColor(r, g, b, a)
        else
            self.swatch:SetVertexColor(v.r, v.g, v.b, v.a or 1)
        end
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

    c:SetScript("OnClick", function(self, button)
        if self.disabled then return end
        if button == "RightButton" then
            if self.token then
                self.value = false
                paint(self)
                if self.onChange then self.onChange(self, false) end
            end
            return
        end
        local v = self.value
        local followedTheme = type(v) ~= "table"
        if followedTheme then
            local r, g, b, a = ns.Theme:Color(self.token or "text.primary")
            v = { r = r, g = g, b = b, a = self.hasAlpha and a or nil }
        end
        local prev = { v.r, v.g, v.b, v.a }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = v.r, g = v.g, b = v.b, opacity = v.a or 1, hasOpacity = self.hasAlpha,
            swatchFunc = function() fromPicker(self) end,
            opacityFunc = function() fromPicker(self) end,
            cancelFunc = function()
                if followedTheme then
                    self.value = false
                    paint(self)
                    if self.onChange then self.onChange(self, false) end
                else
                    commit(self, prev[1], prev[2], prev[3], prev[4])
                end
            end,
        })
    end)
    function c:SetValue(v)
        if type(v) ~= "table" then
            if self.token then self.value = false; paint(self) end
            return
        end
        self.value = { r = v.r or 1, g = v.g or 1, b = v.b or 1, a = v.a }
        paint(self)
    end
    function c:GetValue() return self.value end
    if token then W.AttachTooltip(c, ns.L.COLOR_THEME_HINT) end
    c.SetEnabledState = W.SetEnabledState
    return c
end
