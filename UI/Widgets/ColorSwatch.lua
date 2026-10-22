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
            self.swatch:SetVertexColor(Skin:SpecColor(v))
        end
        if self.onPaint then self.onPaint(self) end
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
        if not followedTheme and v.token then
            local r, g, b, a = Skin:SpecColor(v)
            v = { r = r, g = g, b = b, a = self.hasAlpha and a or nil }
        end
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
        self.value = { r = v.r or 1, g = v.g or 1, b = v.b or 1, a = v.a, token = v.token }
        paint(self)
    end
    -- external writes (the Class / Theme chips) go through here so the swatch, its value and onChange agree
    function c:Commit(v)
        if v == false and not self.token then return end
        if v == false then self.value = false else self:SetValue(v) end
        paint(self)
        if self.onChange then self.onChange(self, self.value) end
    end
    function c:GetValue() return self.value end
    if token then W.AttachTooltip(c, ns.L.COLOR_THEME_HINT) end
    c.SetEnabledState = W.SetEnabledState
    return c
end

--[[ A colour row's control: [Class] [Theme] chips and the swatch. Theme returns the row to its theme token
    (saved as false), Class follows the player's class colour live (saved as { token = "class" }), and the
    swatch picks any colour. The chip that matches the saved value is lit. ]]
function W:ColorField(parent, hasAlpha, token)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(44 + 2 * 52 + 8, 24)
    f.swatch = W:ColorSwatch(f, hasAlpha, token)
    f.swatch:SetPoint("RIGHT")
    f.chips = W:Chips(f, {
        { value = "class", label = ns.L.COLOR_CLASS, tip = ns.L.COLOR_CLASS_TIP },
        { value = "theme", label = ns.L.COLOR_THEME, tip = ns.L.COLOR_THEME_TIP },
    })
    f.chips:SetPoint("RIGHT", f.swatch, "LEFT", -8, 0)
    f.chips:SetWidth(200)
    f.chips:SetWidth(f.chips.naturalWidth or 100)
    f:SetWidth(44 + 8 + (f.chips.naturalWidth or 100))
    local function lit(sw)
        local v = sw.value
        f.chips:SetValue((v == false and "theme") or (type(v) == "table" and v.token == "class" and "class") or nil)
    end
    f.swatch.onPaint = lit
    f.chips.onChange = function(_, which)
        if which == "class" then f.swatch:Commit({ r = 1, g = 1, b = 1, token = "class" }) else f.swatch:Commit(false) end
    end
    f.swatch.onChange = function(_, v) if f.onChange then f.onChange(f, v) end end
    function f:SetValue(v) self.swatch:SetValue(v); lit(self.swatch) end
    function f:GetValue() return self.swatch:GetValue() end
    function f:SetEnabledState(enabled)
        W.SetEnabledState(self.swatch, enabled)
        W.SetEnabledState(self.chips, enabled)
    end
    lit(f.swatch)
    return f
end
