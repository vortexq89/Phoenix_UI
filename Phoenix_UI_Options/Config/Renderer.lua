local _, ns = ...
local L = ns.L
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media
local Config = ns.Config
local U = ns.Util

--[[ Schema renderer v2 (S6): turns ns.options[moduleKey] into a page. Every control writes through ns.DB:Set,
    which fires PUI_SETTING_CHANGED, so the game UI and the live preview update immediately.

    Item types: header (starts a card; wide = true spans both columns), tab (starts a page tab), toggle,
    range (slider + numeric box), select, font, texture, sound (live-sample card pickers), style (border /
    shadow / backdrop picker drawn by ns.Skin), color (swatch; classToken adds the Class / Theme chips),
    colors (swatch group), input, button, custom, description, preview (live mock, Previews/), scope
    (element chips: Bar 1 … Pet, Player … Arena, with Copy from and Apply to all).
    Any row may carry cog = { items }: sub-options in a popover behind a cog button. A toggle with
    gate = true right after a header becomes that card's section switch: it sits in the card header and
    the card's other rows are off while it is off.
    Keys may contain "@": it stands for the element picked in the page's chips; such rows get a ⇄ button
    that copies their value to every element.

    Layout: cards in one or two columns; inside a card, rows without a description pair up two per line
    (label above control) once the card is wide enough, and rows with one keep a full line. ]]
local PAD, CARD_GAP, ROW_H, ROW_H_DESC, TWO_COLUMNS_AT = 24, 16, 36, 52, 760
local CELL_H, TOGGLE_CELL_H, PAIR_AT, HEADER_H = 60, 38, 400, 96
local POPOVER_W = 400
-- rows that can share a line: no description, a control that fits half a card
local COMPACT = { toggle = true, range = true, select = true, font = true, texture = true, sound = true, style = true,
    color = true, input = true }
-- controls that stretch to the cell's width in paired layout
local STRETCH = { range = true, select = true, font = true, texture = true, sound = true, style = true, input = true }

local function text(key) return key and (L[key] or key) or "" end
local rowTip -- defined after the reset helpers

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
        -- item.single: a per-element value (a position) that must never be copied onto the other selected elements
        local targets = item.single and { page.scope.unit } or page:Targets()
        for _, unit in ipairs(targets) do
            ns.DB:Set(m, (key:gsub("@", unit)), type(value) == "table" and U.DeepCopy(value) or value)
        end
        if #targets > 1 and page.scope.bar then page.scope.bar.units:Flash(targets) end
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

-- Do the elements being edited (Targets) hold different values for this row? Rows with their own getter,
-- single rows and rows outside the scope are never mixed.
function Config.IsMixed(page, m, item)
    if not (page.scope and page.Targets and item.key and not item.get and not item.single) then return false end
    if not item.key:find("@", 1, true) or item.type == "button" or item.type == "colors" then return false end
    local targets = page:Targets()
    if #targets < 2 then return false end
    local first = U.GetPath(m.db, (item.key:gsub("@", targets[1])))
    for i = 2, #targets do
        if not U.Equal(U.GetPath(m.db, (item.key:gsub("@", targets[i]))), first) then return true end
    end
    return false
end

Config.SetRowValue = setValue -- the path every control takes (the smoke harness drives it directly)

---------------------------------------------------------------- reset to default
-- The default of a row comes from the module's defaults at the same path (scope aware). Rows backed by
-- get/set (CVars, profiles) carry item.default when they can be reset; otherwise they are left alone.
local function defaultOf(page, m, item, key)
    if item.get or item.set then return item.default end
    key = key or item.key
    if not key or not m.defaults then return nil end
    local path = resolve(page, key)
    local v = U.GetPath(m.defaults, path)
    if v == nil and page.scope and key:find("@", 1, true) then
        -- per-unit tables may only exist in defaults for the first unit; fall back to its value
        v = U.GetPath(m.defaults, (key:gsub("@", page.scope.values[1].value)))
    end
    return v
end

local function resettable(page, m, item)
    if item.type == "colors" then
        for _, key in ipairs(item.keys) do if defaultOf(page, m, item, key) ~= nil then return true end end
        return false
    end
    if item.type == "button" or item.type == "description" then return false end
    if item.type == "custom" and not item.resettable then return false end
    return defaultOf(page, m, item) ~= nil
end

-- Restores one row (and the rows behind its cog). Returns true when something changed.
local function resetItem(page, m, item)
    local changed = false
    if item.type == "colors" then
        for _, key in ipairs(item.keys) do
            local d = defaultOf(page, m, item, key)
            if d ~= nil then setValue(page, m, item, U.DeepCopy(d), key); changed = true end
        end
    elseif resettable(page, m, item) then
        setValue(page, m, item, U.DeepCopy(defaultOf(page, m, item)))
        changed = true
    end
    for _, sub in ipairs(item.cog or {}) do
        if resetItem(page, m, sub) then changed = true end
    end
    return changed
end

---------------------------------------------------------------- row tooltip
-- Every row explains itself on hover: its description when the row has no room for one, the default
-- value, how to reset it, and whether it needs a reload or waits for combat to end.
local function describe(item, m, v)
    local t = item.type
    if t == "toggle" then return v and L.TIP_ON or L.OFF end
    if t == "range" and type(v) == "number" then
        if item.percent then return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
        return (item.step or 1) < 1 and ("%.2f"):format(v):gsub("0+$", ""):gsub("%.$", "") or tostring(v)
    end
    if t == "select" or t == "style" then
        local values = type(item.values) == "function" and item.values(m) or item.values or {}
        for _, e in ipairs(values) do if e.value == v then return text(e.label) end end
    end
    if (t == "font" or t == "texture" or t == "sound") and type(v) == "string" then
        return v == "" and L.DEFAULT or v
    end
    return nil
end

function rowTip(page, m, item, withDesc)
    local lines = {}
    if withDesc and item.desc then lines[#lines + 1] = text(item.desc) end
    if item.tip then lines[#lines + 1] = text(item.tip) end
    if resettable(page, m, item) and item.type ~= "colors" then
        local d = describe(item, m, defaultOf(page, m, item))
        if d then lines[#lines + 1] = L.TIP_DEFAULT:format(d) end
    end
    if resettable(page, m, item) then lines[#lines + 1] = L.TIP_RESET end
    if item.reload then lines[#lines + 1] = L.TIP_RELOAD end
    if item.combat then lines[#lines + 1] = L.TIP_COMBAT end
    return #lines > 0 and table.concat(lines, "\n") or nil
end

---------------------------------------------------------------- hover preview
--[[ Pointing at an entry of a dropdown or picker shows it in the page's preview before it is chosen: the
    value is written straight into the profile table without firing PUI_SETTING_CHANGED (so the real frames
    are untouched), the preview redraws, and the saved value is put back when the pointer leaves or the list
    closes. Only plain (non get/set) rows on pages with a preview take part. ]]
local hover -- { page, m, path, original }

local function endHover()
    local h = hover
    if not h then return end
    hover = nil
    U.SetPath(h.m.db, h.path, h.original)
    if h.page.preview then h.page.preview:Redraw() end
end
Config.EndHoverPreview = endHover

local function hoverPreview(page, m, item, value)
    if value == nil then endHover(); return end
    if not page.preview or item.get or item.set or not item.key then return end
    local path = resolve(page, item.key)
    if hover and hover.path ~= path then endHover() end
    if not hover then hover = { page = page, m = m, path = path, original = U.GetPath(m.db, path) } end
    U.SetPath(m.db, path, value)
    page.preview:Redraw()
end

-- a logout or reload while a list is open must never save the hovered value
ns.Events:On("PLAYER_LOGOUT", Config, endHover)

---------------------------------------------------------------- setting counts (page header, module list depth)
local SETTING = { toggle = true, range = true, select = true, font = true, texture = true, sound = true, style = true,
    color = true, input = true }

-- Settings a schema offers: every control row and every row behind a cog (colour groups count each swatch).
function Config.CountSettings(schema)
    local n = 0
    local function walk(list)
        for _, item in ipairs(list or {}) do
            if item.type == "colors" then n = n + #(item.keys or {})
            elseif SETTING[item.type] or (item.type == "custom" and item.label and item.label ~= "") then n = n + 1 end
            walk(item.cog)
        end
    end
    walk(type(schema) == "function" and schema() or schema)
    return n
end

---------------------------------------------------------------- controls
local MEDIA_KIND = { font = "font", sound = "sound", texture = "statusbar" }
local HOVERS = { select = true, font = true, texture = true, style = true }

local function mediaPicker(row, item, kind)
    return W:MediaPicker(row, kind, function()
        local list = Media:List(kind)
        if item.allowDefault then table.insert(list, 1, { value = "", label = L.DEFAULT }) end
        return list
    end)
end

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
    elseif t == "style" then
        c = W:StylePicker(row, item.kind or "border", item.values)
    elseif MEDIA_KIND[t] then
        c = mediaPicker(row, item, MEDIA_KIND[t])
    elseif t == "color" then
        c = (item.classToken and W.ColorField or W.ColorSwatch)(W, row, item.alpha, item.reset and item.token or nil)
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
        if HOVERS[t] then
            c.onHover = function(_, value) hoverPreview(page, m, item, value) end
        end
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
            r:SetWidth(POPOVER_W)
            r:Arrange("line", POPOVER_W)
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

-- Right-click on a row restores its default; a reset arrow beside the control does the same and only shows
-- while the row differs from its default. A left click on a toggle row flips the toggle.
local function attachReset(row, page, m, item)
    row:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if self.control and self.control.disabled then return end
            if resetItem(page, m, item) then
                PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
                self:Refresh()
                for _, r in ipairs(self.cogContent and self.cogContent.rows or {}) do r:Refresh() end
                self:Flash()
                Config:SetStatus(L.RESET_ROW_DONE:format(text(item.label)), "state.success", "reset")
            end
            return
        end
        if item.type == "toggle" and self.control and not self.control.disabled then self.control:Click() end
    end)
    if resettable(page, m, item) then
        row.reset = W:IconButton(row, "reset", 20, L.RESET_ROW, L.RESET_ROW_HINT)
        row.reset.onClick = function() row:GetScript("OnMouseUp")(row, "RightButton") end
        row.reset:Hide()
    end
end

-- Keys a row writes, with "@" still in them (colour groups write several).
local function rowKeys(item)
    if item.type == "colors" then return item.keys end
    return item.key and { item.key } or {}
end

local function isScoped(page, item)
    if not page.scope or item.get or item.set or item.single then return false end
    for _, key in ipairs(rowKeys(item)) do if key:find("@", 1, true) then return true end end
    return false
end

-- ⇄ copies this row's value from the picked element to every element of the page's chips.
local function applyToAll(page, m, item)
    local n = 0
    for _, key in ipairs(rowKeys(item)) do
        local v = U.GetPath(m.db, resolve(page, key))
        for _, e in ipairs(page.scope.values) do
            if e.value ~= page.scope.unit then
                ns.DB:Set(m, (key:gsub("@", e.value)), type(v) == "table" and U.DeepCopy(v) or v)
                n = n + 1
            end
        end
    end
    Config:SetStatus(L.APPLIED_TO_ALL:format(text(item.label)), "state.success", "apply-all")
    if page.scope.bar then
        local all = {}
        for k, e in ipairs(page.scope.values) do all[k] = e.value end
        page.scope.bar.units:Flash(all)
    end
    return n
end
Config.ApplyRowToAll = applyToAll

-- Buttons beside the control: the cog (sub-options) or, on mirror rows, an arrow to the original row;
-- on element pages the ⇄ apply-to-all button.
local function attachSide(row, card, page, m, item)
    if item.cog then
        assert(not card.isCog, "cog rows cannot nest: use ns.Opt.Flat")
        row.cog = W:Cog(row)
        row.cog.onClick = function() openCog(row, page, m, item) end
    elseif item.link then
        row.cog = W:IconButton(row, "chevron-right", 22, L.OPEN_IN_MODULE, L[ns.modules[item.link.key].label])
        row.cog.onClick = function()
            local target = Config:Show(item.link.key)
            if target.Focus then C_Timer.After(0.05, function() target:Focus(item.link.item) end) end
        end
    end
    if isScoped(page, item) then
        row.applyAll = W:IconButton(row, "apply-all", 20, L.APPLY_ALL_ROW, L.APPLY_ALL_ROW_DESC)
        row.applyAll.onClick = function()
            applyToAll(page, m, item)
            row:Flash()
        end
    end
end

-- The icon buttons of a row, nearest the control first.
local function sideIcons(row)
    local out = {}
    if row.cog then out[#out + 1] = row.cog end
    if row.applyAll then out[#out + 1] = row.applyAll end
    if row.reset then out[#out + 1] = row.reset end
    return out
end

function buildRow(card, page, m, item)
    local row = CreateFrame("Frame", nil, card)
    row.item = item
    local hasDesc = item.desc ~= nil
    row.compact = COMPACT[item.type] and not hasDesc and not item.fullWidth and not item.gate and true or false
    row:SetHeight(item.height or (hasDesc and ROW_H_DESC or ROW_H))
    row.hl = W.Texture(row, "BACKGROUND", 2)
    row.hl:SetAllPoints()
    row.flash = W.Texture(row, "BACKGROUND", 3)
    row.flash:SetAllPoints()
    row.flash:SetAlpha(0)
    row.label = W.Text(row, "body", "text.primary")
    row.label:SetText(text(item.label))
    if item.icon and item.type == "toggle" then row.icon = W.Icon(row, item.icon, 14, "accent.primary") end
    row.control = makeControl(row, page, m, item)
    row.controlW = row.control and row.control:GetWidth() or W.CONTROL_WIDTH
    if hasDesc then
        row.desc = W.Text(row, "desc", "text.muted")
        row.desc:SetWordWrap(true)
        row.desc:SetText(text(item.desc))
    end
    if item.reload or item.combat then
        row.badge = W:Badge(row, item.reload and L.BADGE_RELOAD or L.BADGE_COMBAT,
            item.reload and "state.warning" or "state.info", item.reload and "reload" or "lock")
    end
    attachSide(row, card, page, m, item)
    Skin:Register(row, function(self)
        W.Color(self.hl, "bg.hover", 0)
        W.Color(self.flash, "accent.primary", 0.22)
        Skin:Text(self.label, "body", "text.primary")
        if self.icon then ns.Icons:Tint(self.icon, "accent.primary") end
        if self.desc then Skin:Text(self.desc, "desc", "text.muted") end
    end)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        W.Color(self.hl, "bg.hover", 0.55)
        W.ShowTooltip(self.label, text(item.label), rowTip(page, m, item, not (self.desc and self.desc:IsShown())))
    end)
    row:SetScript("OnLeave", function(self) W.Color(self.hl, "bg.hover", 0); W.HideTooltip() end)
    attachReset(row, page, m, item)

    --[[ mode "line": label left, control right (description under the label)
         mode "cell": label above a control that spans the cell (paired rows)
         mode "gate": the control alone, in a card header ]]
    local function arrangeGate(self, c, icons)
        self.label:Hide()
        if self.desc then self.desc:Hide() end
        if self.badge then self.badge:Hide() end
        if c then c:ClearAllPoints(); c:SetPoint("RIGHT", -2, 0) end
        -- the label and description are hidden in the card header, so the switch carries them as a tooltip
        if c and not self.gateTip then
            self.gateTip = true
            W.AttachTooltip(c, text(item.label), item.desc and text(item.desc) or nil)
        end
        local anchor = c
        for _, b in ipairs(icons) do
            b:SetPoint("RIGHT", anchor or self, anchor and "LEFT" or "RIGHT", -4, 0)
            anchor = b
        end
        self:SetSize((c and c:GetWidth() or 0) + #icons * 24 + 8, 28)
    end

    -- a paired cell: label on top, the control under it
    local function arrangeCell(self, c, icons, width, indent)
        if c then
            c:ClearAllPoints()
            if STRETCH[item.type] then c:SetWidth(math.max(80, width - 28)) end
            c:SetPoint("TOPLEFT", 14, -28)
        end
        local anchor
        for _, b in ipairs(icons) do
            if anchor then b:SetPoint("RIGHT", anchor, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", -8, -4) end
            anchor = b
        end
        self.label:SetPoint("TOPLEFT", indent - 2, -9)
        self.label:SetWidth(math.max(40, width - indent - #icons * 24 - 10))
        self:SetHeight(item.height or CELL_H)
    end

    -- a full line (or a toggle cell): label and description left, the control right
    local function arrangeLine(self, c, icons, mode, indent, width)
        if c then
            c:ClearAllPoints()
            if STRETCH[item.type] then c:SetWidth(row.controlW) end
        end
        if c and item.fullWidth then
            c:SetPoint("TOPLEFT", 16, hasDesc and -48 or -32)
            c:SetPoint("BOTTOMRIGHT", -16, 12)
        elseif c then
            c:SetPoint("RIGHT", mode == "cell" and -14 or -16, 0)
        end
        local anchor = (c and not item.fullWidth) and c or nil
        for _, b in ipairs(icons) do
            if anchor then b:SetPoint("RIGHT", anchor, "LEFT", anchor == c and -6 or -2, 0)
            else b:SetPoint("TOPRIGHT", -16, -8) end
            anchor = b
        end
        local right = ((c and not item.fullWidth) and c:GetWidth() or 0) + #icons * 24 + 32
        -- explicit text widths: anchors resolve a frame later, so a wrapped description measured from them
        -- reads as one line and spills into the next row. The text column ends before the control column.
        local textW = math.max(60, (width or W.CONTROL_WIDTH * 2) - indent - right)
        self.textW = textW
        self.label:SetWidth(textW)
        if self.desc and mode ~= "cell" then
            self.desc:Show()
            self.label:SetPoint("TOPLEFT", indent, -9)
            self.desc:SetPoint("TOPLEFT", self.label, "BOTTOMLEFT", 0, -4)
            self.desc:SetWidth(item.fullWidth and math.max(60, (width or 0) - 32) or textW)
        elseif item.fullWidth then
            self.label:SetPoint("TOPLEFT", 16, -10)
        else
            if self.desc then self.desc:Hide() end
            self.label:SetPoint("LEFT", indent, 0)
        end
        if mode == "cell" then self:SetHeight(item.height or TOGGLE_CELL_H) end
    end

    function row:Arrange(mode, width)
        self.mode = mode
        local c = self.control
        local icons = sideIcons(self)
        for _, b in ipairs(icons) do b:ClearAllPoints() end
        self.label:ClearAllPoints()
        if self.icon then self.icon:ClearAllPoints() end
        if self.desc then self.desc:ClearAllPoints() end
        local indent = self.icon and 38 or 16
        if mode == "gate" then return arrangeGate(self, c, icons) end
        self.label:Show()
        if mode == "cell" and item.type ~= "toggle" then
            arrangeCell(self, c, icons, width, indent)
        else
            arrangeLine(self, c, icons, mode, indent, width)
        end
        if self.icon then self.icon:SetPoint("RIGHT", self.label, "LEFT", -8, 0) end
        if self.badge then
            self.badge:ClearAllPoints()
            self.badge:SetPoint("LEFT", self.label, "LEFT", math.min(self.label:GetUnboundedStringWidth(), 140) + 8, 0)
            self.badge:Show()
        end
    end

    function row:Measure()
        if self.desc and self.desc:IsShown() and self.mode ~= "gate" then
            local top = 9 + self.label:GetStringHeight() + 4 + self.desc:GetStringHeight()
            if item.fullWidth and self.control then
                -- the control sits under the wrapped description, never on top of it
                local base = item.height or ROW_H_DESC
                self.control:SetPoint("TOPLEFT", 16, -math.floor(top + 8))
                self:SetHeight(math.max(base, math.floor(base - 48 + top + 8 + 0.5)))
            else
                self:SetHeight(math.max(item.height or ROW_H_DESC, math.floor(top + 10 + 0.5)))
            end
        end
    end

    -- a card's section switch (gate) turns its other rows off
    local function gatedOff()
        local gate = row.card and row.card.gateRow
        return gate ~= nil and gate ~= row and not getValue(page, m, gate.item)
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
        self:ShowMixed(Config.IsMixed(page, m, item))
        local enabled = not (item.disabled and item.disabled(m, page.scope and page.scope.unit)) and not gatedOff()
        self.enabledState = enabled
        if self.reset then self.reset:SetShown(enabled and self:IsModified()) end
        if c then (c.SetEnabledState or W.SetEnabledState)(c, enabled) end
        if self.cog then W.SetEnabledState(self.cog, enabled) end
        if self.applyAll then W.SetEnabledState(self.applyAll, enabled) end
        self.label:SetAlpha(enabled and 1 or 0.45)
        if self.icon then self.icon:SetAlpha(enabled and 1 or 0.45) end
    end

    -- "MIXED": the selected elements hold different values for this row (multi-select / Edit all)
    function row:ShowMixed(on)
        if on and not self.mixed then
            self.mixed = W.Text(self, "small", "state.warning")
            self.mixed:SetText(L.MIXED_VALUES:upper())
            self.mixed:SetPoint("LEFT", self.label, "RIGHT", 8, 0)
        end
        if self.mixed then self.mixed:SetShown(on and true or false) end
    end

    function row:IsModified()
        if item.type == "colors" then
            for _, key in ipairs(item.keys) do
                local d = defaultOf(page, m, item, key)
                if d ~= nil and not U.Equal(U.GetPath(m.db, resolve(page, key)), d) then return true end
            end
            return false
        end
        local d = defaultOf(page, m, item)
        return d ~= nil and not U.Equal(getValue(page, m, item), d)
    end

    function row:Flash()
        ns.Anim:Tween(self.flash, 0.9, 1, 0, function(v)
            self.flash:SetAlpha(math.abs(math.sin(v * math.pi * 2)) * v)
        end)
    end
    row:Arrange("line", W.CONTROL_WIDTH * 2)
    return row
end

local function buildDescription(card, item)
    local row = CreateFrame("Frame", nil, card)
    row.text = W.Text(row, "desc", "text.secondary")
    row.text:SetWordWrap(true)
    row.text:SetPoint("TOPLEFT", 16, -4)
    row.text:SetPoint("RIGHT", -16, 0)
    row.text:SetText(type(item.text) == "function" and item.text() or text(item.text))
    row.item = item
    row.isDescription = true
    Skin:Register(row, function(self) Skin:Text(self.text, "desc", "text.secondary") end)
    function row:Refresh() end
    function row:Flash() end
    function row:Arrange(_, width) if width then self.text:SetWidth(math.max(60, width - 32)) end end
    function row:Measure() self:SetHeight(math.floor(self.text:GetStringHeight() + 12.5)) end
    return row
end

---------------------------------------------------------------- card and module reset
-- Wide resets need a second click within 3 s; the button turns red while armed.
local function armReset(button, prompt, action)
    button.onClick = function(self)
        if self.armed then
            self.armed = nil
            self.danger = nil
            if self.icon then ns.Icons:SetState(self.icon, nil) end
            action()
            return
        end
        self.armed, self.danger = true, true
        if self.icon then ns.Icons:SetState(self.icon, "danger") end
        Config:SetStatus(prompt, "state.warning", "reset")
        C_Timer.After(3, function()
            if self.armed then
                self.armed, self.danger = nil, nil
                if self.icon then ns.Icons:SetState(self.icon, nil) end
                Config:UpdateFooter()
            end
        end)
    end
end

local function resetCard(page, m, card)
    for _, row in ipairs(card.rows) do
        if row.item and not row.isDescription then resetItem(page, m, row.item) end
    end
    page:Refresh()
    Config:SetStatus(L.RESET_CARD_DONE:format(card.title), "state.success", "reset")
end

local function hasDefaults(m)
    for k in pairs(m.defaults or {}) do if k ~= "enabled" then return true end end
    return false
end

-- Every setting of the module back to its default; the module stays enabled or disabled as it is.
local function resetModule(page, m)
    for k, v in pairs(m.defaults) do
        if k ~= "enabled" then ns.DB:Set(m, k, U.DeepCopy(v)) end
    end
    ns.Combat:Run("reset." .. m.key, function()
        if m:IsEnabled() then ns.SafeCall(m.Refresh, m) end
    end)
    page:Refresh()
    if page.preview then page.preview:Redraw() end
    Config:SetStatus(L.RESET_MODULE_DONE:format(text(m.label)), "state.success", "reset")
end

---------------------------------------------------------------- page header
--[[ Title, the one line that says how the module works, its setting count and state, then Reset module and
    the enable switch on the right. ]]
local function buildPageHeader(page, m, schema)
    local h = CreateFrame("Frame", nil, page.scroll.child)
    h:SetHeight(HEADER_H)
    h.iconBg = W.Texture(h, "ARTWORK", 0, Media.textures.ROUNDED)
    h.iconBg:SetSize(44, 44)
    h.iconBg:SetPoint("TOPLEFT", PAD, -22)
    h.icon = W.Icon(h, m.icon, 22, "accent.primary")
    h.icon:SetPoint("CENTER", h.iconBg)
    h.title = W.Text(h, "title", "text.primary")
    h.title:SetPoint("TOPLEFT", h.iconBg, "TOPRIGHT", 14, -1)
    h.title:SetText(text(m.label))
    h.desc = W.Text(h, "desc", "text.secondary")
    h.desc:SetPoint("TOPLEFT", h.title, "BOTTOMLEFT", 0, -5)
    h.desc:SetPoint("RIGHT", -250, 0)
    h.desc:SetText(text(m.desc))
    h.count = W:Badge(h, "", "text.muted", "cog")
    h.count:SetPoint("TOPLEFT", h.desc, "BOTTOMLEFT", 0, -7)
    page.settingCount = Config.CountSettings(schema)
    h.count:Set(L.SETTINGS_COUNT:format(page.settingCount), "text.muted")
    h.count:SetShown(page.settingCount > 0)
    h.state = W:Badge(h, "", "state.success")
    h.state:SetPoint("LEFT", h.count, "RIGHT", 6, 0)
    h.state:Hide()
    if not m.locked then
        h.toggle = W:Toggle(h)
        h.toggle:SetPoint("TOPRIGHT", -PAD, -30)
        h.toggle.onChange = function(_, v) ns:SetModuleEnabled(m.key, v) end
        h.toggleLabel = W.Text(h, "small", "text.secondary", "RIGHT")
        h.toggleLabel:SetPoint("RIGHT", h.toggle, "LEFT", -8, 0)
    end
    if hasDefaults(m) then
        h.reset = W:Button(h, L.RESET_MODULE, "ghost", "reset")
        h.reset:SetHeight(26)
        W.AttachTooltip(h.reset, L.RESET_MODULE, L.RESET_MODULE_DESC)
        if h.toggle then h.reset:SetPoint("RIGHT", h.toggleLabel, "LEFT", -14, 0)
        else h.reset:SetPoint("TOPRIGHT", -PAD, -27) end
        armReset(h.reset, L.RESET_MODULE_CONFIRM:format(text(m.label)), function() resetModule(page, m) end)
    end
    h.line = W.Texture(h, "BORDER")
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT", PAD, 0); h.line:SetPoint("BOTTOMRIGHT", -PAD, 0)
    Skin:Register(h, function(self)
        W.Color(self.iconBg, "accent.soft", 0.9)
        W.Color(self.icon, "accent.primary")
        Skin:Text(self.title, "title", "text.primary", 20)
        Skin:Text(self.desc, "desc", "text.secondary")
        if self.toggleLabel then Skin:Text(self.toggleLabel, "small", "text.secondary") end
        W.Color(self.line, "border.subtle", 0.7)
    end)
    function h:Refresh()
        local state, token
        if m.state == "errored" then state, token = L.STATE_ERROR, "state.danger"
        elseif m.needsReload then state, token = L.BADGE_RELOAD, "state.warning"
        elseif not m.locked and m:IsEnabled() then state, token = L.STATE_ACTIVE, "state.success" end
        if state then self.state:Set(state, token); self.state:Show() else self.state:Hide() end
        if self.state:IsShown() and not self.count:IsShown() then
            self.state:ClearAllPoints(); self.state:SetPoint("TOPLEFT", self.desc, "BOTTOMLEFT", 0, -7)
        end
        if not self.toggle then return end
        self.toggle:SetValue(m.db.enabled)
        self.toggleLabel:SetText((m.db.enabled and L.ENABLED or L.DISABLED):upper())
    end
    return h
end

---------------------------------------------------------------- element chips (unit / bar selector)
--[[ item = { type = "scope", key = "units", values = { {value=, label=}, ... } }. Rows whose key contains
    "@" edit m.db[key][element]. Click a chip to edit that element; Shift-click more chips to edit several at
    once; "Edit all" links every element. "Copy from" replaces the edited elements' settings with another
    element's, and each "@" row has a ⇄ button that sends its value to every element. ]]
local function buildScope(page, m, item)
    local values = {}
    for i, v in ipairs(item.values) do values[i] = { value = v.value, label = text(v.label) } end
    page.scope = { unit = values[1].value, mode = "this", multi = {}, root = item.key, values = values }
    local scope = page.scope

    local bar = CreateFrame("Frame", nil, page.scroll.child)
    scope.bar = bar
    bar:SetHeight(64)
    bar.title = W.Text(bar, "heading", "text.muted")
    bar.title:SetPoint("TOPLEFT", 0, -2)
    bar.title:SetText(text(item.label or "EDITING"):upper())
    bar.hint = W.Text(bar, "small", "text.muted")
    bar.hint:SetPoint("LEFT", bar.title, "RIGHT", 10, 0)
    bar.hint:SetText(L.CHIPS_SHIFT_HINT)
    bar.units = W:Chips(bar, values)
    bar.units:SetPoint("TOPLEFT", 0, -20)
    bar.units:SetValue(scope.unit)

    bar.all = W:Toggle(bar)
    bar.allLabel = W.Text(bar, "small", "text.secondary", "RIGHT")
    bar.allLabel:SetText(L.APPLY_ALL:upper())
    W.AttachTooltip(bar.all, L.APPLY_ALL, L.APPLY_ALL_DESC)
    bar.copy = W:Dropdown(bar, function()
        local out = {}
        for _, v in ipairs(values) do if v.value ~= scope.unit then out[#out + 1] = v end end
        return out
    end, nil, 150)
    bar.copy.placeholder = L.COPY_SETTINGS_FROM
    bar.copyLabel = W.Text(bar, "small", "text.secondary", "RIGHT")
    bar.copyLabel:SetText(L.COPY_SETTINGS_FROM:upper())

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

    function bar:Arrange(width)
        self:SetWidth(width)
        self.all:ClearAllPoints(); self.all:SetPoint("TOPRIGHT", 0, -20)
        self.allLabel:ClearAllPoints(); self.allLabel:SetPoint("RIGHT", self.all, "LEFT", -8, 0)
        self.copy:ClearAllPoints(); self.copy:SetPoint("RIGHT", self.allLabel, "LEFT", -18, 0)
        self.copyLabel:ClearAllPoints(); self.copyLabel:SetPoint("BOTTOMLEFT", self.copy, "TOPLEFT", 0, 5)
        local room = width - (150 + 18 + self.allLabel:GetStringWidth() + 8 + 38) - 24
        if room < 220 then
            -- narrow pages: chips get a line of their own above the tools
            self.units:SetWidth(width)
            self.all:ClearAllPoints(); self.all:SetPoint("TOPRIGHT", self.units, "BOTTOMRIGHT", 0, -10)
            self.copy:ClearAllPoints(); self.copy:SetPoint("RIGHT", self.allLabel, "LEFT", -18, 0)
            self.copyLabel:ClearAllPoints(); self.copyLabel:SetPoint("RIGHT", self.copy, "LEFT", -8, 0)
            self:SetHeight(20 + self.units:GetHeight() + 10 + 26 + 4)
        else
            self.units:SetWidth(room)
            self:SetHeight(20 + math.max(self.units:GetHeight(), 26) + 6)
        end
    end

    -- the hint line names what is being edited once more than one element is selected
    local function summary()
        local t = page:Targets()
        if #t < 2 then bar.hint:SetText(L.CHIPS_SHIFT_HINT); return end
        local names = {}
        for _, unit in ipairs(t) do
            for _, v in ipairs(values) do if v.value == unit then names[#names + 1] = v.label end end
        end
        bar.hint:SetText(L.EDITING_SEVERAL:format(#t) .. ": " .. table.concat(names, ", "))
    end
    scope.Summary = summary

    local function relayout()
        page:Layout()
        if page.preview then page.preview:Redraw() end
        if page.pinned then page.pinned:Tag() end
    end

    bar.units.onChange = function(chips, v, shift)
        if shift then
            scope.multi = U.DeepCopy(chips:GetExtra())
            if scope.mode ~= "all" then scope.mode = next(scope.multi) and "multi" or "this" end
            summary()
            page:Refresh()
            return
        end
        scope.unit = v
        scope.multi = {}
        if scope.mode ~= "all" then scope.mode = "this" end
        bar.copy:SetValue(nil)
        summary()
        page:Refresh()
        relayout()
    end
    bar.all.onChange = function(_, on)
        scope.mode = on and "all" or (next(scope.multi) and "multi" or "this")
        Config:SetStatus(on and L.APPLY_ALL_ON or L.APPLY_ALL_OFF, on and "state.warning" or nil, "apply-all")
        summary()
        page:Refresh()
    end
    bar.copy.onChange = function(_, src)
        local data = src and m.db[scope.root] and m.db[scope.root][src]
        if type(data) ~= "table" then return end
        -- every setting except where each element sits (item.keep, default point/x/y): copying a bar's position
        -- would stack the bars on top of each other
        local keep = item.keep or { "point", "x", "y", "relativePoint", "relativeTo", "enabled" }
        for _, unit in ipairs(page:Targets()) do
            if unit ~= src then
                local copy, old = U.DeepCopy(data), m.db[scope.root][unit]
                for _, k in ipairs(keep) do if type(old) == "table" then copy[k] = old[k] end end
                ns.DB:Set(m, scope.root .. "." .. unit, copy)
            end
        end
        bar.units:Flash(page:Targets())
        Config:SetStatus(L.COPIED_FROM:format(text(bar.copy.current and bar.copy.current.label or src)), "state.success", "copy")
        bar.copy:SetValue(nil)
        page:Refresh()
    end
    Skin:Register(bar, function(self)
        Skin:Text(self.title, "heading", "text.muted")
        Skin:Text(self.hint, "small", "text.muted")
        Skin:Text(self.allLabel, "small", "text.secondary")
        Skin:Text(self.copyLabel, "small", "text.secondary")
    end)
    function scope:Label()
        for _, v in ipairs(values) do if v.value == scope.unit then return v.label end end
        return ""
    end
    return bar
end

---------------------------------------------------------------- live preview
--[[ The preview card: docked in the window's right column when there is room (Config:LayoutShell), otherwise
    pinned at the top of the page, where it sticks once the header scrolls away. State chips force sample
    states (low health, casting …), the eye folds it, and "Show in world" opens the module's test frames. ]]
local function previewStore()
    local ui = ns.DB.sv.global.ui
    if type(ui.previews) ~= "table" then ui.previews = {} end
    return ui.previews
end

-- What "Show in world" does for a module: its test frames, a sample encounter, or nothing.
local function worldAction(m)
    if m.ShowTest then
        return function()
            if not m:IsEnabled() then Config:SetStatus(L.PREVIEW_WORLD_OFF, "state.warning", "warning"); return end
            if not m:ShowTest(not m.testShown) then Config:SetStatus(L.UF_TEST_COMBAT, "state.warning", "warning") end
        end
    elseif m.Test then
        return function()
            if not m:IsEnabled() then Config:SetStatus(L.PREVIEW_WORLD_OFF, "state.warning", "warning"); return end
            if m:Test() then Config:SetStatus(L.PREVIEW_WORLD_ON, "state.success", "test") end
        end
    end
end

local function buildPreview(page, m, item)
    local card = W:Card(page, text(item.label or "LIVE_PREVIEW"), "preview")
    card.isPreview = true
    card:SetFrameLevel(page.scroll:GetFrameLevel() + 10)
    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", function(_, delta)
        if not page.docked then page.scroll:GetScript("OnMouseWheel")(page.scroll, delta) end
    end)
    card.pane = ns.Previews:Create(item.kind, card, m, page)
    -- a click on a part of the preview jumps to that part's setting and flashes it
    card.pane.onHot = function(key) if page.FocusKey then page:FocusKey(key) end end
    card.tag = W.Text(card, "small", "accent.text", "RIGHT")
    card.shade = W.Texture(card, "BACKGROUND", -1, Media.textures.FADE_V)
    card.shade:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, 0)
    card.shade:SetPoint("TOPRIGHT", card, "BOTTOMRIGHT", 0, 0)
    card.shade:SetHeight(14)
    card.shade:Hide()
    card.fold = W:IconButton(card, "hide", 22, L.PREVIEW_FOLD, L.PREVIEW_FOLD_DESC)
    card.fold:SetPoint("TOPRIGHT", -10, -9)
    card.tag:SetPoint("RIGHT", card.fold, "LEFT", -8, 0)
    card.collapsed = previewStore()[m.key] == false
    card.fold.onClick = function()
        card.collapsed = not card.collapsed
        previewStore()[m.key] = not card.collapsed and nil or false
        page:Layout()
        Config:LayoutShell()
    end
    local states = ns.Previews:States(item.kind)
    if states then
        local values = {}
        for i, st in ipairs(states) do values[i] = { value = st.key, label = text(st.label), icon = st.icon } end
        card.states = W:Chips(card, values, true)
        card.states.onChange = function(_, set)
            card.pane.states = set
            card.pane:Redraw()
        end
        W.AttachTooltip(card.states, L.PREVIEW_STATES, L.PREVIEW_STATES_DESC)
    end
    card.hint = W.Text(card, "small", "text.muted")
    card.hint:SetWordWrap(true)
    card.hint:SetText(L.PREVIEW_HINT)
    local world = item.world or worldAction(m)
    if world then
        card.world = W:Button(card, L.PREVIEW_WORLD, "secondary", "test")
        card.world:SetHeight(26)
        card.world.onClick = function() world(m, page) end
    end
    Skin:Register(card.shade, function(t)
        t:SetTexCoord(0, 1, 0, 1)
        W.Color(t, "bg.base", 0.9)
    end)
    Skin:Register(card.hint, function(fs) Skin:Text(fs, "small", "text.muted") end)
    function card:Tag()
        self.tag:SetText(page.scope and page.scope:Label():upper() or "")
    end
    -- docked: fills the column, states and hint wrap under the title; pinned: compact, beside the page
    function card:Apply(docked)
        local width = self:GetWidth()
        if not width or width < 50 then width = 360 end
        local inner = width - 32
        local y = 40
        local open = not self.collapsed
        if self.states then
            self.states:SetShown(open)
            self.states:ClearAllPoints()
            self.states:SetPoint("TOPLEFT", 16, -y)
            self.states:SetWidth(inner)
            if open then y = y + self.states:GetHeight() + 10 end
        end
        self.pane:SetShown(open)
        local scale = self.pane:Fit(inner)
        self.pane:ClearAllPoints()
        self.pane:SetPoint("TOPLEFT", self, "TOPLEFT", 16 / scale, -y / scale)
        self.pane:SetPoint("TOPRIGHT", self, "TOPRIGHT", -16 / scale, -y / scale)
        if open then y = y + self.pane:GetHeight() * scale + 10 end
        self.hint:SetShown(open and docked)
        if open and docked then
            self.hint:ClearAllPoints()
            self.hint:SetPoint("TOPLEFT", 16, -y)
            self.hint:SetWidth(inner)
            y = y + self.hint:GetStringHeight() + 10
        end
        if self.world then
            self.world:SetShown(open)
            if open then
                self.world:ClearAllPoints()
                self.world:SetPoint("TOPLEFT", 16, -y)
                self.world:SetPoint("TOPRIGHT", -16, -y)
                y = y + 26 + 12
            end
        end
        ns.Icons:Apply(self.fold.icon, self.collapsed and "preview" or "hide", 11)
        self:SetHeight(open and (y + 4) or 40)
        self:Tag()
    end
    page.preview = card.pane
    page.pinned = card
    return card
end

---------------------------------------------------------------- pages
function Config.BuildModulePage(parent, key)
    return Config.BuildSchemaPage(parent, ns.modules[key], ns.options[key])
end

-- Rows of one card, laid out: paired rows two per line when the card is wide enough. Returns the height.
local function layoutRows(c, width)
    local cy = c.hasHeader and 42 or 8
    local pair = width >= PAIR_AT
    local cellW = math.floor((width - 2) / 2)
    local visible = {}
    for _, row in ipairs(c.rows) do
        if row == c.gateRow then
            row:Show()
            row:Arrange("gate", 0)
            row:ClearAllPoints()
            row:SetPoint("TOPRIGHT", c, "TOPRIGHT", c.reset and -38 or -12, -7)
        elseif row.hiddenState then
            row:Hide()
        else
            visible[#visible + 1] = row
        end
    end
    local i, first = 1, true
    while i <= #visible do
        local row, nextRow = visible[i], visible[i + 1]
        local kind = row.compact and (row.item.type == "toggle" and "toggle" or "control")
        local nextKind = nextRow and nextRow.compact and (nextRow.item.type == "toggle" and "toggle" or "control")
        local together = pair and kind and kind == nextKind
        local rows = together and { row, nextRow } or { row }
        local h = 0
        for j, r in ipairs(rows) do
            r:Show()
            r:ClearAllPoints()
            local w = together and cellW or (width - 2)
            r:SetWidth(w)
            r:Arrange(together and "cell" or "line", w)
            r:Measure()
            r:SetPoint("TOPLEFT", c, "TOPLEFT", 1 + (j - 1) * cellW, -cy)
            if not r.sep then
                r.sep = W:Separator(r)
                r.sep:SetPoint("TOPLEFT", 16, 0); r.sep:SetPoint("TOPRIGHT", -16, 0)
            end
            r.sep:SetShown(not first)
            h = math.max(h, r:GetHeight())
        end
        if together then for _, r in ipairs(rows) do r:SetHeight(h) end end
        first = false
        cy = cy + h
        i = i + #rows
    end
    return cy, #visible > 0 or c.gateRow ~= nil
end

-- m: a module or a module-like table { key, label, desc, icon, locked = true, db = {}, singleColumn = bool }.
function Config.BuildSchemaPage(parent, m, schema)
    local key = m.key
    local page = CreateFrame("Frame", nil, parent)
    page.scroll = W:Scroll(page)
    page.scroll:SetPoint("TOPLEFT", 0, 0)
    page.scroll:SetPoint("BOTTOMRIGHT", -10, 0)
    local child = page.scroll.child
    schema = schema or {}
    page.schema = schema
    page.header = buildPageHeader(page, m, schema)
    page.header:SetPoint("TOPLEFT"); page.header:SetPoint("TOPRIGHT")
    page.cards, page.rows, page.tops, page.tabList = {}, {}, {}, {}

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
            buildPreview(page, m, item)
        else
            if t == "header" or not card then
                card = W:Card(child, t == "header" and text(item.label) or nil, t == "header" and item.icon or nil)
                card.rows = {}
                card.tab = tab or 1
                card.wide = t == "header" and item.wide
                card.title = t == "header" and text(item.label) or text(m.label)
                if t == "header" then
                    local thisCard = card
                    card.reset = W:IconButton(card, "reset", 22, L.RESET_CARD, L.RESET_CARD_DESC)
                    card.reset:SetPoint("TOPRIGHT", -10, -9)
                    card.reset:Hide()
                    armReset(card.reset, L.RESET_CARD_CONFIRM:format(card.title), function() resetCard(page, m, thisCard) end)
                end
                page.cards[#page.cards + 1] = card
            end
            if t ~= "header" then
                local row = t == "description" and buildDescription(card, item) or buildRow(card, page, m, item)
                row.section = card.title
                row.card = card
                if item.gate and t == "toggle" and #card.rows == 0 and card.hasHeader then card.gateRow = row end
                card.rows[#card.rows + 1] = row
                page.rows[#page.rows + 1] = row
            end
        end
    end
    if #page.cards == 0 and #page.tops == 0 and not page.pinned then
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
        local cy, any = layoutRows(c, width)
        c:SetSize(width, cy + 8)
        if c.reset then
            local modified = false
            for _, row in ipairs(c.rows) do
                if row.IsModified and row:IsModified() then modified = true; break end
            end
            c.reset:SetShown(modified)
        end
        return any
    end

    function page:Layout()
        local width = math.max(320, child:GetWidth() - 2 * PAD)
        local y = HEADER_H + 14
        if self.tabs then
            self.tabs:ClearAllPoints()
            self.tabs:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -y + 6)
            self.tabs:SetPoint("TOPRIGHT", child, "TOPRIGHT", -PAD, -y + 6)
            y = y + 34 + 14
        end
        if self.pinned and not self.docked then
            local pc = self.pinned
            pc:SetWidth(width)
            pc:Apply(false)
            self.pinnedY = y
            y = y + pc:GetHeight() + CARD_GAP
        end
        for _, top in ipairs(self.tops) do
            top:ClearAllPoints()
            top:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -y)
            if top.Arrange then top:Arrange(width) else top:SetWidth(width) end
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
        self:Stick()
    end

    -- keeps the pinned preview card in its slot, or at the top once its slot scrolls past (not when docked)
    local STICK_TOP = 10
    function page:Stick()
        local pc = self.pinned
        if not pc or not self.pinnedY or self.docked then
            if pc then pc.shade:Hide() end
            return
        end
        local top = self.pinnedY - self.scroll:GetVerticalScroll()
        local stuck = top < STICK_TOP
        pc:ClearAllPoints()
        pc:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, -math.max(STICK_TOP, top))
        pc.shade:SetShown(stuck)
        self.stuck = stuck
    end

    -- Config:LayoutShell moves the preview between the dock and the page
    function page:SetDocked(dock)
        local pc = self.pinned
        if not pc then return end
        self.docked = dock ~= nil
        pc:SetParent(dock or self)
        pc:SetFrameLevel((dock or self.scroll):GetFrameLevel() + 10)
        pc:ClearAllPoints()
        if dock then
            pc:SetPoint("TOPLEFT", dock, "TOPLEFT", 14, -14)
            pc:SetPoint("TOPRIGHT", dock, "TOPRIGHT", -14, -14)
            pc:Apply(true)
        end
        self:Layout()
    end

    function page:Refresh()
        self.header:Refresh()
        for _, row in ipairs(self.rows) do row:Refresh() end
        for _, row in ipairs(self.cogRows or {}) do row:Refresh() end
        self:Layout()
        if self.docked and self.pinned then self.pinned:Apply(true) end
    end

    local function owns(row, item)
        if row.item == item then return true end
        for _, sub in ipairs(row.item.cog or {}) do if sub == item then return true end end
        return false
    end

    function page:FocusKey(k)
        for _, row in ipairs(self.rows) do
            if row.item.key == k then self:Focus(row.item); return true end
        end
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
                local clear = (self.pinned and not self.docked) and (self.pinned:GetHeight() + 30) or 80
                local top = child:GetTop() - row:GetTop() - clear
                self.scroll:SetVerticalScroll(math.max(0, math.min(self.scroll:GetVerticalScrollRange(), top)))
                self.scroll:UpdateBar()
                row:Flash()
            end
        end
    end

    page:HookScript("OnHide", function()
        W.HidePopover()
        endHover()
    end)
    page.scroll:HookScript("OnVerticalScroll", function() page:Stick() end)
    -- the first layout can run before the scroll frame has a size; columns are settled once it has one
    page.scroll:HookScript("OnSizeChanged", function() page:Layout() end)
    ns.Events:Listen("PUI_SETTING_CHANGED", page, function(_, _, moduleKey)
        if page:IsShown() and moduleKey == key then
            for _, row in ipairs(page.rows) do
                if row.item.disabled or row.item.hidden or row.card.gateRow then row:Refresh()
                elseif row.reset then row.reset:SetShown(row:IsModified()) end
            end
            for _, row in ipairs(page.cogRows or {}) do
                if row.item.disabled or row.item.hidden then row:Refresh() end
            end
            page:Layout()
        end
    end)
    return page
end
