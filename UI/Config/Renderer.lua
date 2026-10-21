local _, ns = ...
local L = ns.L
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media
local Config = ns.Config
local U = ns.Util

--[[ Schema renderer: turns ns.options[moduleKey] into a page. Every control writes through ns.DB:Set,
    which fires PUI_SETTING_CHANGED, so the game UI and the page's live preview update immediately.

    Item types: header (starts a card; wide = true spans both columns), tab (starts a sub-module tab),
    toggle, range (slider + numeric box), select, font, texture (live-sample pickers), color (theme-token
    aware swatch), colors (swatch group), input, button, custom, description, preview (live mock of the
    module, UI/Previews), scope (unit/bar selector with "Apply to" and "Copy settings from").
    Any row may carry cog = { items } — sub-options in a popover behind a cog button.
    Keys may contain "@": it stands for the unit picked in the page's scope bar. ]]
local PAD, CARD_GAP, ROW_H, ROW_H_DESC, TWO_COLUMNS_AT = 24, 16, 36, 52, 760
local POPOVER_W = 400

local function text(key) return key and (L[key] or key) or "" end

---------------------------------------------------------------- values (scope aware)
local function resolve(page, key)
    if page.scope and key and key:find("@", 1, true) then return (key:gsub("@", page.scope.unit)) end
    return key
end

local function getValue(page, m, item)
    if item.get then return item.get(m, page.scope and page.scope.unit) end
    return U.GetPath(m.db, resolve(page, item.key))
end

local function setValue(page, m, item, value, key)
    key = key or item.key
    if item.set then
        item.set(m, value, page.scope and page.scope.unit)
        ns.Events:Fire("PUI_SETTING_CHANGED", m.key, key or item.label, value)
    elseif page.scope and key:find("@", 1, true) then
        for _, unit in ipairs(page:Targets()) do
            ns.DB:Set(m, (key:gsub("@", unit)), type(value) == "table" and U.DeepCopy(value) or value)
        end
    else
        ns.DB:Set(m, key, value)
    end
    if item.reload then
        m.needsReload = true
        Config:SetStatus(L.STATUS_RELOAD, "state.warning")
    elseif item.combat and InCombatLockdown() then
        Config:SetStatus(L.STATUS_AFTER_COMBAT, "state.warning")
    end
end

---------------------------------------------------------------- controls
local function makeControl(row, page, m, item)
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
            for i, v in ipairs(values) do out[i] = { value = v.value, label = text(v.label), icon = v.icon } end
            return out
        end)
    elseif t == "font" then
        c = W:Dropdown(row, function()
            local list = Media:List("font")
            if item.allowDefault then table.insert(list, 1, { value = "", label = L.DEFAULT }) end
            return list
        end, "font")
    elseif t == "texture" then
        c = W:Dropdown(row, function()
            local list = Media:List("statusbar")
            if item.allowDefault then table.insert(list, 1, { value = "", label = L.DEFAULT }) end
            return list
        end, "bar")
    elseif t == "color" then
        c = W:ColorSwatch(row, item.alpha, item.reset and item.token or nil)
    elseif t == "colors" then
        c = W:ColorPair(row, #item.keys, item.alpha, item.tokens)
        c.onChange = function(_, value, i) setValue(page, m, item, value, item.keys[i]) end
        for i, sw in ipairs(c.swatches) do
            if item.labels and item.labels[i] then W.AttachTooltip(sw, text(item.labels[i]), L.COLOR_THEME_HINT) end
        end
        return c
    elseif t == "input" then
        c = W:Input(row, item.width)
    elseif t == "custom" then
        return item.build(row, m)
    elseif t == "button" then
        c = W:Button(row, text(item.button or item.label), item.variant or "secondary", item.icon)
        c.onClick = function() item.func(m, page) end
        return c
    end
    if c then
        c.onChange = function(_, value) setValue(page, m, item, value) end
    end
    return c
end

local buildRow

-- Sub-options behind a cog: rows built on first open into a frame the shared popover adopts.
local function openCog(row, page, m, item)
    local content = row.cogContent
    if not content then
        content = CreateFrame("Frame", nil, row)
        content.rows = {}
        content.isCog = true
        local y = 0
        for _, child in ipairs(item.cog) do
            local r = buildRow(content, page, m, child)
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            if #content.rows > 0 then
                r.sep = W:Separator(r)
                r.sep:SetPoint("TOPLEFT", 16, 0); r.sep:SetPoint("TOPRIGHT", -16, 0)
            end
            y = y + r:GetHeight()
            content.rows[#content.rows + 1] = r
        end
        content.height = y + 6
        row.cogContent = content
        page.cogRows = page.cogRows or {}
        for _, r in ipairs(content.rows) do page.cogRows[#page.cogRows + 1] = r end
    end
    for _, r in ipairs(content.rows) do r:Refresh() end
    W:Popover(row.cog, text(item.label), content, POPOVER_W, content.height)
end

function buildRow(card, page, m, item)
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
    row.control = makeControl(row, page, m, item)
    local cw = row.control and not item.fullWidth and row.control:GetWidth() or W.CONTROL_WIDTH
    local right = cw + 32 + (item.cog and 30 or 0)
    if hasDesc then
        row.label:SetPoint("TOPLEFT", 16, -9)
        row.desc = W.Text(row, "desc", "text.muted")
        row.desc:SetWordWrap(true)
        row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
        row.desc:SetPoint("RIGHT", row, "RIGHT", -right, 0)
        row.desc:SetText(text(item.desc))
    else
        row.label:SetPoint("LEFT", 16, 0)
    end
    row.label:SetPoint("RIGHT", row, "RIGHT", -right, 0)
    if item.reload or item.combat then
        row.badge = W:Badge(row, item.reload and L.BADGE_RELOAD or L.BADGE_COMBAT,
            item.reload and "state.warning" or "state.info", item.reload and "reload" or "lock")
        row.badge:SetPoint("LEFT", row.label, "LEFT", math.min(row.label:GetUnboundedStringWidth(), 140) + 8, 0)
    end
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
    if item.cog then
        assert(not card.isCog, "cog rows cannot nest: use ns.Opt.Flat")
        row.cog = W:Cog(row)
        if row.control then row.cog:SetPoint("RIGHT", row.control, "LEFT", -6, 0) else row.cog:SetPoint("RIGHT", -16, 0) end
        row.cog.onClick = function() openCog(row, page, m, item) end
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

    function row:Measure()
        if self.desc then
            local h = 9 + self.label:GetStringHeight() + 4 + self.desc:GetStringHeight() + 10
            self:SetHeight(math.max(item.height or ROW_H_DESC, math.floor(h + 0.5)))
        end
    end

    function row:Refresh()
        local hidden = item.hidden and item.hidden(m, page.scope and page.scope.unit)
        self.hiddenState = hidden
        local c = self.control
        if c and c.SetValue and item.type == "colors" then
            local values = {}
            for i, key in ipairs(item.keys) do values[i] = U.GetPath(m.db, resolve(page, key)) end
            c:SetValue(values)
        elseif c and c.SetValue and item.type ~= "button" and (item.key or item.get) then
            c:SetValue(getValue(page, m, item))
        end
        local enabled = not (item.disabled and item.disabled(m, page.scope and page.scope.unit))
        if c then (c.SetEnabledState or W.SetEnabledState)(c, enabled) end
        if self.cog then W.SetEnabledState(self.cog, enabled) end
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
    function row:Measure() self:SetHeight(self.text:GetStringHeight() + 12) end
    return row
end

---------------------------------------------------------------- page header
local function buildPageHeader(page, m)
    local h = CreateFrame("Frame", nil, page.scroll.child)
    h:SetHeight(84)
    h.iconBg = W.Texture(h, "ARTWORK", 0, Media.textures.ROUNDED)
    h.iconBg:SetSize(48, 48)
    h.iconBg:SetPoint("TOPLEFT", PAD, -20)
    h.icon = W.Icon(h, m.icon, 24, "accent.primary")
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

---------------------------------------------------------------- scope bar (unit / bar selector)
--[[ item = { type = "scope", key = "units", values = { {value=, label=}, ... } }. Rows whose key contains
    "@" edit m.db[key][unit]. "Apply to" sends each change to this unit, all units or a chosen set;
    "Copy settings from" replaces the targets' settings with another unit's. ]]
local function buildScope(page, m, item)
    local values = {}
    for i, v in ipairs(item.values) do values[i] = { value = v.value, label = text(v.label) } end
    page.scope = { unit = values[1].value, mode = "this", multi = {}, root = item.key, values = values }
    local scope = page.scope

    local bar = CreateFrame("Frame", nil, page.scroll.child)
    bar:SetHeight(84)
    bar.title = W.Text(bar, "heading", "text.secondary")
    bar.title:SetPoint("TOPLEFT", 16, -14)
    bar.title:SetText(text(item.label or "EDITING"):upper())
    bar.units = W:Segmented(bar, values)
    bar.units:SetPoint("TOPLEFT", 16, -34)
    bar.units:SetValue(scope.unit)

    bar.applyLabel = W.Text(bar, "heading", "text.secondary")
    bar.applyLabel:SetText(L.APPLY_TO:upper())
    bar.apply = W:Segmented(bar, {
        { value = "this", label = L.APPLY_THIS }, { value = "all", label = L.APPLY_ALL },
        { value = "multi", label = L.APPLY_MULTIPLE },
    })
    bar.apply:SetValue("this")
    bar.apply:SetPoint("TOPRIGHT", -16, -34)
    bar.applyLabel:SetPoint("BOTTOMLEFT", bar.apply, "TOPLEFT", 0, 6)
    bar.multi = W:Segmented(bar, values, true)
    bar.multi:SetPoint("TOPLEFT", bar.units, "BOTTOMLEFT", 0, -26)
    bar.multiLabel = W.Text(bar, "small", "text.muted")
    bar.multiLabel:SetPoint("BOTTOMLEFT", bar.multi, "TOPLEFT", 0, 5)
    bar.multiLabel:SetText(L.APPLY_MULTIPLE_HINT)

    bar.copyLabel = W.Text(bar, "small", "text.muted", "RIGHT")
    bar.copyLabel:SetText(L.COPY_SETTINGS_FROM)
    bar.copy = W:Dropdown(bar, function()
        local out = {}
        for _, v in ipairs(values) do if v.value ~= scope.unit then out[#out + 1] = v end end
        return out
    end, nil, 130)
    bar.copyGo = W:Button(bar, L.COPY, "secondary", "copy")
    bar.copyGo:SetPoint("BOTTOMRIGHT", -16, 14)
    bar.copy:SetPoint("RIGHT", bar.copyGo, "LEFT", -6, 0)
    bar.copyLabel:SetPoint("RIGHT", bar.copy, "LEFT", -8, 0)

    function page:Targets()
        if scope.mode == "all" then
            local out = {}
            for i, v in ipairs(values) do out[i] = v.value end
            return out
        elseif scope.mode == "multi" then
            local out, seen = { scope.unit }, { [scope.unit] = true }
            for _, v in ipairs(values) do
                if scope.multi[v.value] and not seen[v.value] then out[#out + 1] = v.value; seen[v.value] = true end
            end
            return out
        end
        return { scope.unit }
    end

    local function relayout()
        local multi = scope.mode == "multi"
        bar.multi:SetShown(multi)
        bar.multiLabel:SetShown(multi)
        bar:SetHeight(multi and 118 or 84)
        bar.copyGo:SetEnabledState(bar.copy:GetValue() ~= nil)
        page:Layout()
    end

    bar.units.onChange = function(_, v)
        scope.unit = v
        bar.copy:SetValue(nil)
        page:Refresh()
        relayout()
        if page.preview then page.preview:Redraw() end
    end
    bar.apply.onChange = function(_, v) scope.mode = v; relayout() end
    bar.multi.onChange = function(_, v) scope.multi = v end
    bar.copy.onChange = function() relayout() end
    bar.copyGo.onClick = function()
        local src = bar.copy:GetValue()
        local data = src and m.db[scope.root] and m.db[scope.root][src]
        if type(data) ~= "table" then return end
        for _, unit in ipairs(page:Targets()) do
            if unit ~= src then ns.DB:Set(m, scope.root .. "." .. unit, U.DeepCopy(data)) end
        end
        Config:SetStatus(L.COPIED_FROM:format(text(bar.copy.current and bar.copy.current.label or src)), "state.success")
        page:Refresh()
    end

    Skin:Register(bar, function(self)
        Skin:Panel(self, "raised", { border = "border.subtle", sheen = 28 })
        Skin:Text(self.title, "heading", "text.secondary")
        Skin:Text(self.applyLabel, "heading", "text.secondary")
        Skin:Text(self.multiLabel, "small", "text.muted")
        Skin:Text(self.copyLabel, "small", "text.muted")
    end)
    bar.multi:Hide(); bar.multiLabel:Hide()
    bar.copyGo:SetEnabledState(false)
    return bar
end

---------------------------------------------------------------- preview card
local function buildPreview(page, m, item)
    local card = W:Card(page.scroll.child, text(item.label or "LIVE_PREVIEW"), "preview")
    card.isPreview = true
    card.pane = ns.Previews:Create(item.kind, card, m, page)
    card.pane:SetPoint("TOPLEFT", 16, -40)
    card.pane:SetPoint("TOPRIGHT", -16, -40)
    card.hint = W.Text(card, "small", "text.muted", "RIGHT")
    card.hint:SetPoint("TOPRIGHT", -18, -17)
    card.hint:SetText(L.PREVIEW_HINT)
    Skin:Register(card.hint, function(fs) Skin:Text(fs, "small", "text.muted") end)
    page.preview = card.pane
    return card
end

---------------------------------------------------------------- pages
function Config.BuildModulePage(parent, key)
    return Config.BuildSchemaPage(parent, ns.modules[key], ns.options[key])
end

-- m: a module or a module-like table { key, label, desc, icon, locked = true, db = {}, singleColumn = bool }.
function Config.BuildSchemaPage(parent, m, schema)
    local key = m.key
    local page = CreateFrame("Frame", nil, parent)
    page.scroll = W:Scroll(page)
    page.scroll:SetPoint("TOPLEFT", 0, 0)
    page.scroll:SetPoint("BOTTOMRIGHT", -10, 0)
    local child = page.scroll.child
    page.header = buildPageHeader(page, m)
    page.header:SetPoint("TOPLEFT"); page.header:SetPoint("TOPRIGHT")
    page.cards, page.rows, page.tops, page.tabList = {}, {}, {}, {}

    schema = schema or {}
    local card, tab
    for _, item in ipairs(schema) do
        local t = item.type
        if t == "tab" then
            tab = #page.tabList + 1
            page.tabList[tab] = { value = tab, label = text(item.label) }
            card = nil
        elseif t == "scope" then
            page.tops[#page.tops + 1] = buildScope(page, m, item)
        elseif t == "preview" then
            page.tops[#page.tops + 1] = buildPreview(page, m, item)
        else
            if t == "header" or not card then
                card = W:Card(child, t == "header" and text(item.label) or nil, t == "header" and item.icon or nil)
                card.rows = {}
                card.tab = tab or 1
                card.wide = t == "header" and item.wide
                card.title = t == "header" and text(item.label) or text(m.label)
                page.cards[#page.cards + 1] = card
            end
            if t ~= "header" then
                local row = t == "description" and buildDescription(card, item) or buildRow(card, page, m, item)
                row.section = card.title
                row.card = card
                card.rows[#card.rows + 1] = row
                page.rows[#page.rows + 1] = row
            end
        end
    end
    if #page.cards == 0 and #page.tops == 0 then
        card = W:Card(child, nil)
        card.rows = { buildDescription(card, { text = "NO_OPTIONS" }) }
        card.tab = 1
        page.cards[1] = card
    end
    if #page.tabList > 1 then
        page.tabs = W:Tabs(child, page.tabList)
        page.tab = 1
        page.tabs.onChange = function(_, v)
            page.tab = v
            W.HidePopover()
            page:Layout()
            page.scroll:SetVerticalScroll(0)
            page.scroll:UpdateBar()
        end
    end

    local function layoutCard(c, width)
        local cy = c.hasHeader and 40 or 8
        local first = true
        for _, row in ipairs(c.rows) do
            if row.hiddenState then
                row:Hide()
            else
                row:Show()
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -cy)
                row:SetWidth(width - 2)
                row:Measure()
                if not row.sep then
                    row.sep = W:Separator(row)
                    row.sep:SetPoint("TOPLEFT", 16, 0); row.sep:SetPoint("TOPRIGHT", -16, 0)
                end
                row.sep:SetShown(not first)
                first = false
                cy = cy + row:GetHeight()
            end
        end
        c:SetSize(width, cy + 8)
        return not first
    end

    function page:Layout()
        local width = math.max(320, child:GetWidth() - 2 * PAD)
        local y = 84
        if self.tabs then
            self.tabs:ClearAllPoints()
            self.tabs:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -y + 6)
            self.tabs:SetPoint("TOPRIGHT", child, "TOPRIGHT", -PAD, -y + 6)
            y = y + 34 + 12
        end
        for _, top in ipairs(self.tops) do
            top:ClearAllPoints()
            top:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -y)
            top:SetWidth(width)
            if top.isPreview then top:SetHeight(40 + top.pane:GetHeight() + 16) end
            y = y + top:GetHeight() + CARD_GAP
        end
        local onPage = 0
        for _, c in ipairs(self.cards) do
            if not self.tabs or c.tab == self.tab then onPage = onPage + 1 end
        end
        -- a lone card spans the page instead of leaving an empty column beside it
        local cols = (not m.singleColumn and width >= TWO_COLUMNS_AT and onPage > 1) and 2 or 1
        local colW = math.floor((width - (cols - 1) * CARD_GAP) / cols)
        local colY = { y, y }
        for _, c in ipairs(self.cards) do
            local onTab = not self.tabs or c.tab == self.tab
            if onTab and layoutCard(c, (cols == 1 or c.wide) and width or colW) then
                c:Show()
                c:ClearAllPoints()
                if cols == 1 or c.wide then
                    local top = math.max(colY[1], colY[2])
                    c:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -top)
                    colY[1] = top + c:GetHeight() + CARD_GAP
                    colY[2] = colY[1]
                else
                    local col = colY[2] < colY[1] and 2 or 1
                    c:SetPoint("TOPLEFT", child, "TOPLEFT", PAD + (col - 1) * (colW + CARD_GAP), -colY[col])
                    colY[col] = colY[col] + c:GetHeight() + CARD_GAP
                end
            else
                c:Hide()
            end
        end
        child:SetHeight(math.max(colY[1], colY[2]) + PAD - CARD_GAP)
        self.scroll:UpdateBar()
    end

    function page:Refresh()
        self.header:Refresh()
        for _, row in ipairs(self.rows) do row:Refresh() end
        for _, row in ipairs(self.cogRows or {}) do row:Refresh() end
        self:Layout()
    end

    local function owns(row, item)
        if row.item == item then return true end
        for _, sub in ipairs(row.item.cog or {}) do if sub == item then return true end end
        return false
    end

    function page:Focus(item)
        for _, row in ipairs(self.rows) do
            if owns(row, item) then
                if self.tabs and row.card.tab ~= self.tab then
                    self.tab = row.card.tab
                    self.tabs:SetValue(self.tab)
                    self:Layout()
                end
                local top = child:GetTop() - row:GetTop() - 80
                self.scroll:SetVerticalScroll(math.max(0, math.min(self.scroll:GetVerticalScrollRange(), top)))
                self.scroll:UpdateBar()
                row:Flash()
            end
        end
    end

    page:HookScript("OnHide", W.HidePopover)
    -- the first layout can run before the scroll frame has a size; columns are settled once it has one
    page.scroll:HookScript("OnSizeChanged", function() page:Layout() end)
    ns.Events:Listen("PUI_SETTING_CHANGED", page, function(_, _, moduleKey)
        if page:IsShown() and moduleKey == key then
            for _, row in ipairs(page.rows) do
                if row.item.disabled or row.item.hidden then row:Refresh() end
            end
            for _, row in ipairs(page.cogRows or {}) do
                if row.item.disabled or row.item.hidden then row:Refresh() end
            end
            page:Layout()
        end
    end)
    return page
end
