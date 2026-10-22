local _, ns = ...
local L = ns.L
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media

--[[ Card picker for fonts, status-bar textures and sounds.

    The control looks like a dropdown, but its face is a real sample of the choice: a font name set in the
    font itself, a texture drawn as a bar, a sound with a play button. The popup is a grid of cards:

      statusbar  three columns of bar-shaped strips in one neutral tint, so the texture's own shading is
                 what you compare (the chosen card wears the accent border and a check mark)
      font       two columns, each with the family name and a pangram set in the face
      sound      three columns with a play button; clicking the card selects, the button only listens

    Long lists are virtualised (only visible cards exist), filtered by a search box and a style/category
    dropdown, and pointing at a card calls owner.onHover(owner, value) so the page preview can try it.
    API mirrors W:Dropdown: SetValue, GetValue, onChange(self, value), onHover(self, value|nil). ]]
local PAD, GAP, HEAD = 12, 8, 46
local SPEC = {
    statusbar = { cols = 3, h = 52, rows = 6, width = 600 },
    font      = { cols = 2, h = 60, rows = 6, width = 600 },
    sound     = { cols = 3, h = 40, rows = 7, width = 600 },
}
local SAMPLE = "The quick brown fox · 0123"
local SAMPLE_RU = "Съешь же ещё · 0123"

-- Filter labels: bar styles (MEDIA_STYLE_*), font categories (MEDIA_CAT_*), "phoenix" and "shared" (MEDIA_*).
local function filterLabel(key)
    local up = key:upper()
    -- a missing key comes back as itself
    for _, label in ipairs({ L["MEDIA_STYLE_" .. up], L["MEDIA_CAT_" .. up], L["MEDIA_" .. up] }) do
        if not label:find("^MEDIA_") then return label end
    end
    return key
end

local function filterKey(kind, item)
    if item.group == "LibSharedMedia" then return "shared" end
    if kind == "statusbar" then return item.style or "phoenix" end
    if kind == "font" then return item.category or "phoenix" end
    return "phoenix"
end

local function playSound(item)
    if item and item.sound then PlaySoundFile(item.sound, "Master") end
end

local popup

local function makeCard(parent)
    local c = CreateFrame("Button", nil, parent)
    c:RegisterForClicks("LeftButtonUp")
    c.strip = W.Texture(c, "ARTWORK")
    c.name = W.Text(c, "small", "text.secondary")
    c.sample = c:CreateFontString(nil, "OVERLAY")
    c.sample:SetWordWrap(false)
    c.check = W.Icon(c, "check", 12, "accent.primary")
    c.check:SetPoint("TOPRIGHT", -7, -7)
    c.play = W:IconButton(c, "play", 24, L.MEDIA_PLAY)
    c.play:SetPoint("LEFT", 6, 0)
    c.play.onClick = function() playSound(c.item) end
    function c:Paint()
        local on = self.item and popup.owner and self.item.value == popup.owner.value
        local border = on and "accent.primary" or (self.hover and "border.strong" or "border.subtle")
        Skin:Panel(self, self.hover and "hover" or "sunken", { border = border })
        Skin:Text(self.name, "small", on and "accent.text" or (self.hover and "text.primary" or "text.secondary"))
        self.check:SetShown(on and true or false)
    end
    c:SetScript("OnEnter", function(self)
        self.hover = true
        self:Paint()
        local owner = popup.owner
        if owner and owner.onHover and self.item then owner.onHover(owner, self.item.value) end
    end)
    c:SetScript("OnLeave", function(self)
        self.hover = false
        self:Paint()
        local owner = popup.owner
        if owner and owner.onHover and not popup:IsMouseOver() then owner.onHover(owner, nil) end
    end)
    c:SetScript("OnClick", function(self)
        local owner = popup.owner
        local value = self.item.value
        popup:Hide()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        owner:SetValue(value)
        if owner.onChange then owner.onChange(owner, value) end
    end)
    return c
end

-- Lays one card out for its kind.
local function dress(c, kind, item)
    c.item = item
    c.strip:Hide(); c.sample:Hide(); c.play:Hide()
    c.name:ClearAllPoints()
    c.name:SetText(item.label)
    if kind == "statusbar" then
        c.strip:ClearAllPoints()
        c.strip:SetPoint("TOPLEFT", 8, -8)
        c.strip:SetPoint("TOPRIGHT", -8, -8)
        c.strip:SetHeight(20)
        c.strip:SetTexture(item.texture or Media:Bar(item.value))
        c.strip:SetVertexColor(Theme:Color("text.secondary"))
        c.strip:Show()
        c.name:SetPoint("BOTTOMLEFT", 9, 7)
        c.name:SetPoint("RIGHT", -22, 0)
    elseif kind == "font" then
        c.name:SetPoint("TOPLEFT", 10, -8)
        c.name:SetPoint("RIGHT", -24, 0)
        if item.font then
            c.sample:SetFont(item.font, 16, "")
        else
            Skin:Text(c.sample, "body", "text.primary")
        end
        c.sample:SetTextColor(Theme:Color("text.primary"))
        c.sample:SetText(Media.needsCyrillic and SAMPLE_RU or SAMPLE)
        c.sample:ClearAllPoints()
        c.sample:SetPoint("BOTTOMLEFT", 10, 9)
        c.sample:SetPoint("RIGHT", -10, 0)
        c.sample:SetJustifyH("LEFT")
        c.sample:Show()
    else
        c.play:SetShown(item.sound ~= nil)
        c.name:SetPoint("LEFT", item.sound and 34 or 10, 0)
        c.name:SetPoint("RIGHT", -24, 0)
    end
    c:Paint()
end

local function getPopup()
    if popup then return popup end
    local p = CreateFrame("Frame", nil, UIParent)
    popup = p
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetFrameLevel(100) -- under the shared dropdown list, which hosts the style filter
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:EnableMouseWheel(true)
    p.cards, p.offset = {}, 0
    Skin:Register(p, function(f) Skin:Panel(f, "raised", { border = "border.strong", shadow = 14 }) end)
    p.search = W:Input(p, 240, L.DROPDOWN_FILTER)
    p.search:SetPoint("TOPLEFT", PAD, -PAD)
    p.search.onTextChanged = function(_, text) p.query = text; p:Filter() end
    p.search:SetScript("OnEscapePressed", function() p:Hide() end)
    p.filter = W:Dropdown(p, function() return p.filters or {} end, nil, 170)
    p.filter:SetPoint("LEFT", p.search, "RIGHT", 8, 0)
    p.filter.onChange = function(_, v) p.category = v; p:Filter() end
    p.count = W.Text(p, "small", "text.muted", "RIGHT")
    p.count:SetPoint("TOPRIGHT", -PAD - 4, -PAD - 7)
    p.grid = CreateFrame("Frame", nil, p)
    p.grid:SetPoint("TOPLEFT", PAD, -HEAD)
    p.grid:SetPoint("BOTTOMRIGHT", -PAD - 6, PAD)
    p.bar = W.Texture(p, "OVERLAY", 2)
    p.bar:SetWidth(3)
    p.empty = W.Text(p.grid, "desc", "text.muted", "CENTER")
    p.empty:SetPoint("CENTER")
    p.empty:SetText(L.MEDIA_NONE)
    Skin:Register(p.count, function(fs) Skin:Text(fs, "small", "text.muted") end)

    p:SetScript("OnMouseWheel", function(self, delta)
        local spec = SPEC[self.kind]
        local rows = math.ceil(#self.visible / spec.cols)
        self.offset = math.max(0, math.min(math.max(0, rows - spec.rows), self.offset - delta))
        self:Render()
    end)
    p:SetScript("OnEvent", function(self)
        -- the filter dropdown's own list lives outside the popup; clicks there must not close it
        if not self:IsMouseOver() and not self.owner:IsMouseOver() and not W.DropdownListIsMouseOver() then self:Hide() end
    end)
    p:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    p:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        self.search:ClearFocus()
        W.HideDropdownList()
        if self.owner then
            self.owner:SetOpen(false)
            if self.owner.onHover then self.owner.onHover(self.owner, nil) end
        end
    end)

    function p:Filter()
        local q = (self.query or ""):lower()
        local out = {}
        for _, item in ipairs(self.items) do
            local okCat = not self.category or self.category == "all" or filterKey(self.kind, item) == self.category
            if okCat and (q == "" or tostring(item.label):lower():find(q, 1, true)) then out[#out + 1] = item end
        end
        self.visible, self.offset = out, 0
        self:Render()
    end

    function p:Render()
        local spec = SPEC[self.kind]
        local w = (self.grid:GetWidth() - (spec.cols - 1) * GAP) / spec.cols
        local first = self.offset * spec.cols
        local n = spec.cols * spec.rows
        for i = 1, n do
            local c = self.cards[i]
            local item = self.visible[first + i]
            if item then
                if not c then c = makeCard(self.grid); self.cards[i] = c end
                local col, row = (i - 1) % spec.cols, math.floor((i - 1) / spec.cols)
                c:SetSize(w, spec.h)
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", col * (w + GAP), -row * (spec.h + GAP))
                dress(c, self.kind, item)
                c:Show()
            elseif c then
                c:Hide()
            end
        end
        for i = n + 1, #self.cards do self.cards[i]:Hide() end
        self.empty:SetShown(#self.visible == 0)
        self.count:SetText(L.MEDIA_COUNT:format(#self.visible))
        local rows = math.ceil(#self.visible / spec.cols)
        if rows > spec.rows then
            local h = self.grid:GetHeight()
            self.bar:SetHeight(math.max(20, h * spec.rows / rows))
            self.bar:ClearAllPoints()
            self.bar:SetPoint("TOPRIGHT", -5, -HEAD - (h - self.bar:GetHeight()) * self.offset / (rows - spec.rows))
            W.Color(self.bar, "accent.primary", 0.8)
            self.bar:Show()
        else
            self.bar:Hide()
        end
    end
    p:Hide()
    W.PopoverKeepOpen(p)
    return p
end

function W.MediaPickerPopup() return popup end

function W:MediaPicker(parent, kind, items, width)
    local d = CreateFrame("Button", nil, parent)
    d:SetSize(width or W.CONTROL_WIDTH, 26)
    d.kind, d.items = kind, items
    d.strip = W.Texture(d, "BORDER")
    d.strip:SetPoint("TOPLEFT", 4, -4); d.strip:SetPoint("BOTTOMRIGHT", -24, 4)
    d.strip:Hide()
    d.label = W.Text(d, "body", "text.primary")
    d.label:SetPoint("LEFT", kind == "sound" and 30 or 10, 0)
    d.label:SetPoint("RIGHT", -26, 0)
    d.arrow = W.Icon(d, "chevron-down", 12)
    d.arrow:SetPoint("RIGHT", -9, 0)
    if kind == "sound" then
        d.play = W:IconButton(d, "play", 22, L.MEDIA_PLAY)
        d.play:SetPoint("LEFT", 3, 0)
        d.play.onClick = function() playSound(d.current) end
    end

    local function sample(self)
        local item = self.current
        if self.kind == "font" then
            if item and item.font then self.label:SetFont(item.font, 13, "") else Skin:Text(self.label, "body", "text.primary") end
        elseif self.kind == "statusbar" and item then
            self.strip:SetTexture(item.texture or Media:Bar(item.value))
            W.Color(self.strip, "accent.primary", 0.75)
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

    function d:GetItems() return type(self.items) == "function" and self.items() or self.items end
    function d:SetOpen(open)
        self.open = open
        Skin:SetBorderColor(self, open and "accent.primary" or "border.subtle")
        ns.Icons:Tint(self.arrow, open and "accent.primary" or "text.secondary")
    end
    function d:SetValue(v)
        self.value, self.current = v, nil
        for _, item in ipairs(self:GetItems()) do
            if item.value == v then self.current = item end
        end
        self.label:SetText(self.current and self.current.label or tostring(v or ""))
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
        p.owner, p.kind, p.items, p.query, p.category = self, self.kind, self:GetItems(), "", "all"
        -- filter entries: every style/category present, in list order
        local seen, filters = {}, { { value = "all", label = L.MEDIA_ALL } }
        for _, item in ipairs(p.items) do
            local key = filterKey(self.kind, item)
            if not seen[key] then
                seen[key] = true
                filters[#filters + 1] = { value = key, label = filterLabel(key) }
            end
        end
        p.filters = filters
        p.filter:SetValue("all")
        p.filter:SetShown(#filters > 2)
        p.search:SetValue("")
        local spec = SPEC[self.kind]
        p:SetSize(spec.width, HEAD + spec.rows * (spec.h + GAP) - GAP + PAD)
        p:ClearAllPoints()
        -- open below the control, or above it when there is no room
        local bottom = self:GetBottom() or 0
        if bottom * self:GetEffectiveScale() / UIParent:GetEffectiveScale() < p:GetHeight() + 20 then
            p:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 4)
        else
            p:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -4)
        end
        self:SetOpen(true)
        p:Filter()
        -- start with the current choice in view
        for i, item in ipairs(p.visible) do
            if item.value == self.value then
                local row = math.floor((i - 1) / spec.cols)
                local rows = math.ceil(#p.visible / spec.cols)
                p.offset = math.max(0, math.min(row - 1, rows - spec.rows))
                break
            end
        end
        p:Render()
        ns.Anim:FadeIn(p, 0.1)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
    end)
    d:SetScript("OnHide", function(self) if popup and popup.owner == self then popup:Hide() end end)
    return d
end
