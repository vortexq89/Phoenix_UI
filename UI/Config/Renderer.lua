local _, ns = ...
local L = ns.L
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media
local Config = ns.Config

--[[ Schema renderer: turns ns.options[moduleKey] into cards of rows. Every control writes through
    ns.DB:Set so the live UI updates immediately (live preview). ]]
local PAD, CARD_GAP, ROW_H, ROW_H_DESC = 24, 14, 36, 50

local function text(key) return key and (L[key] or key) or "" end

local function getValue(m, item)
    if item.get then return item.get(m) end
    return ns.Util.GetPath(m.db, item.key)
end

local function setValue(m, item, value)
    if item.set then
        item.set(m, value)
        ns.Events:Fire("PUI_SETTING_CHANGED", m.key, item.key or item.label, value)
    else
        ns.DB:Set(m, item.key, value)
    end
    if item.reload then
        m.needsReload = true
        Config:SetStatus(L.STATUS_RELOAD, "state.warning")
    elseif item.combat and InCombatLockdown() then
        Config:SetStatus(L.STATUS_AFTER_COMBAT, "state.warning")
    end
end

local function makeControl(row, m, item)
    local t = item.type
    local c
    if t == "toggle" then
        c = W:Toggle(row)
    elseif t == "range" then
        c = W:Slider(row, item.min, item.max, item.step, item.percent)
    elseif t == "select" then
        c = W:Dropdown(row, function()
            local values = type(item.values) == "function" and item.values(m) or item.values
            local out = {}
            for i, v in ipairs(values) do out[i] = { value = v.value, label = text(v.label) } end
            return out
        end)
    elseif t == "font" then
        c = W:Dropdown(row, function()
            local list = Media:List("font")
            if item.allowDefault then table.insert(list, 1, { value = "", label = L.DEFAULT }) end
            return list
        end, "font")
    elseif t == "texture" then
        c = W:Dropdown(row, function() return Media:List("statusbar") end, "bar")
    elseif t == "color" then
        c = W:ColorSwatch(row, item.alpha)
    elseif t == "input" then
        c = W:Input(row, item.width)
    elseif t == "custom" then
        return item.build(row, m)
    elseif t == "button" then
        c = W:Button(row, text(item.button or item.label), item.variant or "secondary", item.icon)
        c.onClick = function() item.func(m) end
        return c
    end
    if c then
        c.onChange = function(_, value) setValue(m, item, value) end
    end
    return c
end

local function buildRow(card, m, item)
    local row = CreateFrame("Frame", nil, card)
    row.item = item
    local hasDesc = item.desc ~= nil
    row:SetHeight(item.height or (hasDesc and ROW_H_DESC or ROW_H))
    row.hl = W.Texture(row, "BACKGROUND", 2)
    row.hl:SetAllPoints()
    row.flash = W.Texture(row, "BACKGROUND", 3)
    row.flash:SetAllPoints()
    row.flash:SetAlpha(0)
    row.label = W.Text(row, "body", "text.primary")
    row.label:SetText(text(item.label))
    if hasDesc then
        row.label:SetPoint("TOPLEFT", 16, -9)
        row.desc = W.Text(row, "desc", "text.muted")
        row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
        row.desc:SetPoint("RIGHT", row, "RIGHT", -(W.CONTROL_WIDTH + 40), 0)
        row.desc:SetText(text(item.desc))
    else
        row.label:SetPoint("LEFT", 16, 0)
    end
    row.label:SetPoint("RIGHT", row, "RIGHT", -(W.CONTROL_WIDTH + 40), 0)
    if item.reload or item.combat then
        row.badge = W:Badge(row, item.reload and L.BADGE_RELOAD or L.BADGE_COMBAT, item.reload and "state.warning" or "state.info")
        row.badge:SetPoint("LEFT", row.label, "LEFT", row.label:GetUnboundedStringWidth() + 8, 0)
    end
    row.control = makeControl(row, m, item)
    if row.control and item.fullWidth then
        if not hasDesc then
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", 16, -10)
        end
        row.control:SetPoint("TOPLEFT", 16, hasDesc and -48 or -32)
        row.control:SetPoint("BOTTOMRIGHT", -16, 12)
    elseif row.control then
        row.control:SetPoint("RIGHT", -16, 0)
    end
    Skin:Register(row, function(self)
        W.Color(self.hl, "bg.hover", 0)
        W.Color(self.flash, "accent.primary", 0.22)
        Skin:Text(self.label, "body", "text.primary")
        if self.desc then Skin:Text(self.desc, "desc", "text.muted") end
    end)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) W.Color(self.hl, "bg.hover", 0.55) end)
    row:SetScript("OnLeave", function(self) W.Color(self.hl, "bg.hover", 0) end)
    row:SetScript("OnMouseUp", function(self)
        if item.type == "toggle" and self.control and not self.control.disabled then self.control:Click() end
    end)

    function row:Refresh()
        local hidden = item.hidden and item.hidden(m)
        self.hiddenState = hidden
        local c = self.control
        if c and c.SetValue and item.type ~= "button" and (item.key or item.get) then c:SetValue(getValue(m, item)) end
        local enabled = not (item.disabled and item.disabled(m))
        if c then W.SetEnabledState(c, enabled) end
        self.label:SetAlpha(enabled and 1 or 0.45)
    end

    function row:Flash()
        ns.Anim:Tween(self.flash, 0.9, 1, 0, function(v)
            self.flash:SetAlpha(math.abs(math.sin(v * math.pi * 2)) * v)
        end)
    end
    return row
end

local function buildDescription(card, item)
    local row = CreateFrame("Frame", nil, card)
    row.text = W.Text(row, "desc", "text.secondary")
    row.text:SetWordWrap(true)
    row.text:SetPoint("TOPLEFT", 16, -4)
    row.text:SetPoint("RIGHT", -16, 0)
    row.text:SetText(text(item.text))
    row.item = item
    row.isDescription = true
    Skin:Register(row, function(self) Skin:Text(self.text, "desc", "text.secondary") end)
    function row:Refresh() end
    function row:Flash() end
    return row
end

-- Page header shared by all module pages.
local function buildPageHeader(page, m)
    local h = CreateFrame("Frame", nil, page.scroll.child)
    h:SetHeight(84)
    h.iconBg = W.Texture(h, "ARTWORK", 0, Media.textures.ROUNDED)
    h.iconBg:SetSize(48, 48)
    h.iconBg:SetPoint("TOPLEFT", PAD, -20)
    h.icon = W.Icon(h, m.icon:match("[^\\]+$"), 24)
    h.icon:SetPoint("CENTER", h.iconBg)
    h.title = W.Text(h, "title", "text.primary")
    h.title:SetPoint("TOPLEFT", h.iconBg, "TOPRIGHT", 14, -4)
    h.title:SetText(text(m.label))
    h.desc = W.Text(h, "desc", "text.secondary")
    h.desc:SetPoint("TOPLEFT", h.title, "BOTTOMLEFT", 0, -6)
    h.desc:SetPoint("RIGHT", -180, 0)
    h.desc:SetText(text(m.desc))
    if not m.locked then
        h.toggle = W:Toggle(h)
        h.toggle:SetPoint("TOPRIGHT", -PAD, -30)
        h.toggle.onChange = function(_, v) ns:SetModuleEnabled(m.key, v) end
        h.toggleLabel = W.Text(h, "small", "text.secondary", "RIGHT")
        h.toggleLabel:SetPoint("RIGHT", h.toggle, "LEFT", -10, 0)
        h.state = W:Badge(h, "", "state.success")
        h.state:SetPoint("TOPRIGHT", h.toggle, "BOTTOMRIGHT", 0, -8)
    end
    Skin:Register(h, function(self)
        W.Color(self.iconBg, "accent.soft", 0.9)
        W.Color(self.icon, "accent.primary")
        Skin:Text(self.title, "title", "text.primary")
        Skin:Text(self.desc, "desc", "text.secondary")
        if self.toggleLabel then Skin:Text(self.toggleLabel, "small", "text.secondary") end
    end)
    function h:Refresh()
        if not self.toggle then return end
        self.toggle:SetValue(m.db.enabled)
        self.toggleLabel:SetText(m.db.enabled and L.ENABLED or L.DISABLED)
        if m.state == "errored" then
            self.state:Set(L.STATE_ERROR, "state.danger"); self.state:Show()
        elseif m.needsReload then
            self.state:Set(L.BADGE_RELOAD, "state.warning"); self.state:Show()
        elseif m:IsEnabled() then
            self.state:Set(L.STATE_ACTIVE, "state.success"); self.state:Show()
        else
            self.state:Hide()
        end
    end
    return h
end

function Config.BuildModulePage(parent, key)
    return Config.BuildSchemaPage(parent, ns.modules[key], ns.options[key])
end

-- m: a module or a module-like table { key, label, desc, icon, locked = true, db = {} }.
function Config.BuildSchemaPage(parent, m, schema)
    local key = m.key
    local page = CreateFrame("Frame", nil, parent)
    page.scroll = W:Scroll(page)
    page.scroll:SetPoint("TOPLEFT", 0, 0)
    page.scroll:SetPoint("BOTTOMRIGHT", -10, 0)
    local child = page.scroll.child
    page.header = buildPageHeader(page, m)
    page.header:SetPoint("TOPLEFT"); page.header:SetPoint("TOPRIGHT")
    page.cards, page.rows = {}, {}

    schema = schema or {}
    local card
    for _, item in ipairs(schema) do
        if item.type == "header" or not card then
            card = W:Card(child, item.type == "header" and text(item.label) or nil)
            card.rows = {}
            card.title = item.type == "header" and text(item.label) or text(m.label)
            page.cards[#page.cards + 1] = card
        end
        if item.type ~= "header" then
            local row = item.type == "description" and buildDescription(card, item) or buildRow(card, m, item)
            row.section = card.title
            card.rows[#card.rows + 1] = row
            page.rows[#page.rows + 1] = row
        end
    end
    if #page.cards == 0 then
        card = W:Card(child, nil)
        card.rows = { buildDescription(card, { text = "NO_OPTIONS" }) }
        page.cards[1] = card
    end

    function page:Layout()
        local y = 84
        for _, c in ipairs(self.cards) do
            local cy = c.hasHeader and 40 or 10
            for i, row in ipairs(c.rows) do
                if row.hiddenState then
                    row:Hide()
                else
                    row:Show()
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -cy)
                    row:SetPoint("TOPRIGHT", c, "TOPRIGHT", -1, -cy)
                    if row.isDescription then row:SetHeight(row.text:GetStringHeight() + 12) end
                    if not row.sep and i > 1 then
                        row.sep = W:Separator(row)
                        row.sep:SetPoint("TOPLEFT", 16, 0); row.sep:SetPoint("TOPRIGHT", -16, 0)
                    end
                    cy = cy + row:GetHeight()
                end
            end
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -y)
            c:SetPoint("TOPRIGHT", child, "TOPRIGHT", -PAD, -y)
            c:SetHeight(cy + 10)
            y = y + cy + 10 + CARD_GAP
        end
        child:SetHeight(y + PAD)
        self.scroll:UpdateBar()
    end

    function page:Refresh()
        self.header:Refresh()
        for _, row in ipairs(self.rows) do row:Refresh() end
        self:Layout()
    end

    function page:Focus(item)
        for _, row in ipairs(self.rows) do
            if row.item == item then
                local top = child:GetTop() - row:GetTop() - 80
                self.scroll:SetVerticalScroll(math.max(0, math.min(self.scroll:GetVerticalScrollRange(), top)))
                self.scroll:UpdateBar()
                row:Flash()
            end
        end
    end

    ns.Events:Listen("PUI_SETTING_CHANGED", page, function(_, _, moduleKey)
        if page:IsShown() and moduleKey == key then
            for _, row in ipairs(page.rows) do
                if row.item.disabled or row.item.hidden then row:Refresh() end
            end
            page:Layout()
        end
    end)
    return page
end
