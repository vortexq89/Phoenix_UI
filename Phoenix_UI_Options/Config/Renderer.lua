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

    Layout v4 "Flow" (DESIGN_SYSTEM_V3 §11): a header that stays put (module tile, breadcrumb, title, summary,
    changed-from-default count, Reset page, Move on screen, the Enabled switch, Live preview) with the element chips
    under it; the page's sub-pages are listed in the window's rail, not as tabs. Cards pack into 3 / 2 / 1 columns
    by width (each goes into the shortest column, so there are no gaps); every card folds to its header, and a
    folded card shows summary chips of its current values. Inside a card, rows keep one line: label left,
    control right; rows without a description pair up two per line only in a card wide enough for it. ]]
-- EllesmereUI's measured page (t228): 45 px side pad, sections 40 high (title 8 px over a 1 px line), rows flush
-- under it, and no gap between sections (the next title's own 40 px is the space)
local PAD, CARD_GAP, ROW_H, ROW_H_DESC, TWO_COLUMNS_AT, THREE_COLUMNS_AT = 45, 12, 32, 48, 640, 980
Config.CARD_GAP_MAX = CARD_GAP + 8 -- the page-spacing smoke test: more than this between two cards is an empty band
local CELL_H, TOGGLE_CELL_H, PAIR_AT, HEADER_H = 60, 34, 560, 78
local CARD_HEAD, CHIP_MAX = 40, 5
Config.HEADER_H = HEADER_H
local POPOVER_W = 400
-- rows that can share a line: no description, a control that fits half a card
local COMPACT = { toggle = true, range = true, select = true, font = true, texture = true, sound = true, style = true,
    color = true, input = true }
-- controls that stretch to the cell's width in paired layout
local STRETCH = { range = true, select = true, font = true, texture = true, sound = true, style = true, input = true }

local function text(key) return key and (L[key] or key) or "" end
local rowTip -- defined after the reset helpers
local needWidth -- defined before the page builder

---------------------------------------------------------------- values (scope aware)
local function resolve(page, key)
    if page.scope and key and key:find("@", 1, true) then return (key:gsub("@", page.scope.unit)) end
    return key
end

local function getValue(page, m, item)
    if item.get then return item.get(m, page.scope and page.scope.unit) end
    return U.GetPath(m.db, resolve(page, item.key))
end

--[[ Undo (GUI polish plan §8): every change made in the settings window is recorded with the values it replaced,
    newest last, up to UNDO_MAX steps. A slider drag (or any quick run of changes to the same setting) is one step.
    Rows with their own setter (item.set) are not recorded: their change is not one saved value. ]]
local UNDO_MAX, UNDO_MERGE = 50, 1.5
Config.undo = Config.undo or {}
local function record(m, path, nowKey)
    local stack, now = Config.undo, GetTime()
    local top = stack[#stack]
    if top and top.key == nowKey and now - top.at < UNDO_MERGE then
        top.at = now
        for _, e in ipairs(top) do if e.m == m and e.path == path then return end end
    else
        top = { key = nowKey, at = now, label = nil }
        stack[#stack + 1] = top
        if #stack > UNDO_MAX then table.remove(stack, 1) end
    end
    local old = U.GetPath(m.db, path)
    top[#top + 1] = { m = m, path = path, old = type(old) == "table" and U.DeepCopy(old) or old }
end
Config.RecordUndo = record
-- names the newest step after its row ("Undo: Bar texture") and refreshes the footer button
function Config.NameUndo(undoKey, item)
    local top = Config.undo[#Config.undo]
    if top and top.key == undoKey and item.label then top.label = text(item.label) end
    if Config.UpdateUndo then Config:UpdateUndo() end
end

function Config:CanUndo() return #self.undo > 0 end
function Config:Undo()
    local step = table.remove(self.undo)
    if not step then return false end
    for i = #step, 1, -1 do
        local e = step[i]
        ns.DB:Set(e.m, e.path, type(e.old) == "table" and U.DeepCopy(e.old) or e.old)
    end
    local page = self.current and self.pages[self.current]
    if page and page.Refresh then page:Refresh() end
    if page and page.preview then page.preview:Redraw() end
    self:SetStatus(step.label and L.UNDO_DONE_NAMED:format(step.label) or L.UNDO_DONE, "state.success", "reset")
    if self.UpdateUndo then self:UpdateUndo() end
    return true
end

local function setValue(page, m, item, value, key)
    key = key or item.key
    local undoKey = m.key .. ":" .. tostring(key)
    if item.set then
        item.set(m, value, page.scope and page.scope.unit)
        ns.Events:Fire("PUI_SETTING_CHANGED", m.key, key or item.label, value)
    elseif page.scope and key:find("@", 1, true) then
        -- item.single: a per-element value (a position) that must never be copied onto the other selected elements
        local targets = item.single and { page.scope.unit } or page:Targets()
        -- item.relative: an offset (a bar's X / Y): the picked element takes the value, the others move by the same
        -- amount, so a selected group keeps its shape instead of stacking on one spot
        local delta = item.relative and tonumber(value) and (value - (tonumber(U.GetPath(m.db, (key:gsub("@", page.scope.unit)))) or value))
        for _, unit in ipairs(targets) do
            local path = key:gsub("@", unit)
            record(m, path, undoKey)
            local v = value
            if delta and unit ~= page.scope.unit then v = (tonumber(U.GetPath(m.db, path)) or 0) + delta end
            ns.DB:Set(m, path, type(v) == "table" and U.DeepCopy(v) or v)
        end
        if #targets > 1 and page.scope.bar then page.scope.bar.units:Flash(targets) end
    else
        record(m, key, undoKey)
        ns.DB:Set(m, key, value)
    end
    Config.NameUndo(undoKey, item)
    if item.reload then
        m.needsReload = true
        m.reloadKeys = m.reloadKeys or {}
        m.reloadKeys[item] = true
        -- the row's badge turns into a "Reload needed" button: one click reloads
        for _, r in ipairs(page.rows or {}) do
            if r.item == item and r.ArmReload then r:ArmReload() end
        end
    elseif item.combat and InCombatLockdown() then
        Config:SetStatus(L.STATUS_AFTER_COMBAT, "state.warning")
    end
end

-- Do the elements being edited (Targets) hold different values for this row? Rows with their own getter,
-- single rows and rows outside the scope are never mixed.
function Config.IsMixed(page, m, item)
    if not (page.scope and page.Targets and not item.get and not item.single and not item.relative) then return false end
    local targets = page:Targets()
    if #targets < 2 or item.type == "button" then return false end
    if item.type == "colors" then -- a colour group is mixed when any of its keys differs
        for _, key in ipairs(item.keys or {}) do
            if key:find("@", 1, true) then
                local first = U.GetPath(m.db, (key:gsub("@", targets[1])))
                for i = 2, #targets do
                    if not U.Equal(U.GetPath(m.db, (key:gsub("@", targets[i]))), first) then return true end
                end
            end
        end
        return false
    end
    if not (item.key and item.key:find("@", 1, true)) then return false end
    local first = U.GetPath(m.db, (item.key:gsub("@", targets[1])))
    for i = 2, #targets do
        if not U.Equal(U.GetPath(m.db, (item.key:gsub("@", targets[i]))), first) then return true end
    end
    return false
end

Config.SetRowValue = setValue -- the path every control takes (the smoke harness drives it directly)
Config.GetRowValue = getValue

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

-- A row's owner (specs/002 T001): a row on a global page may belong to another module (module = "General");
-- it then reads, writes, resets and counts on that module, so no saved key moves.
local function ownerOf(m, item)
    local o = item.module and ns.modules[item.module]
    return o or m
end
Config.RowOwner = ownerOf

-- Restores one row (and the rows behind its cog). Returns true when something changed.
local function resetItem(page, m, item)
    m = ownerOf(m, item)
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
    if item.combat then lines[#lines + 1] = L.TIP_COMBAT end
    if item.reload then lines[#lines + 1] = L.TIP_RELOAD_APPLY end
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
        return item.build(row, m, page)
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
    if not page.scope or item.get or item.set or item.single or item.relative then return false end
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

-- Sync to all (specs/001 T014, EllesmereUI's sync icon): a row with sync = { "other.path", ... } outside the
-- element chips copies its value to every listed setting of the same module. Returns how many it set.
local function syncToAll(m, item)
    local v = U.GetPath(m.db, item.key)
    local n = 0
    for _, path in ipairs(item.sync) do
        if path ~= item.key then
            ns.DB:Set(m, path, type(v) == "table" and U.DeepCopy(v) or v)
            n = n + 1
        end
    end
    Config:SetStatus(L.APPLIED_TO_ALL:format(text(item.label)), "state.success", "apply-all")
    return n
end
Config.SyncRowToAll = syncToAll

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
    if type(item.sync) == "table" and type(item.key) == "string" and not isScoped(page, item) then
        row.applyAll = W:IconButton(row, "apply-all", 20, L.APPLY_ALL_ROW, L.APPLY_ALL_ROW_DESC)
        row.applyAll.onClick = function()
            syncToAll(m, item)
            row:Flash()
        end
    elseif isScoped(page, item) then
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
    m = ownerOf(m, item)
    local row = CreateFrame("Frame", nil, card)
    row.item = item
    local hasDesc = item.desc ~= nil
    row.compact = COMPACT[item.type] and not hasDesc and not item.fullWidth and not item.gate and true or false
    row:SetHeight(item.height or (hasDesc and ROW_H_DESC or ROW_H))
    row.hl = W.Texture(row, "BACKGROUND", 2)
    row.hl:SetAllPoints()
    W.Color(row.hl, "bg.hover", 0)
    -- the flash only exists while it plays: a hidden texture can never tint a row by accident
    row.flash = W.Texture(row, "BACKGROUND", 3)
    row.flash:SetAllPoints()
    row.flash:SetAlpha(0)
    row.flash:Hide()
    row.label = W.Text(row, "body", "text.primary")
    -- one line, cut with "..." at the text column (the full label is in the row tooltip): a wrapped label
    -- ran into the control or the row below
    row.label:SetWordWrap(false)
    -- a row with a description grows with its text (Measure), so its label may take a second line before the
    -- "...": narrow three-column cards (Fonts, Textures) cut "Unit Frames · Name font" to "Unit Frames · ..."
    if hasDesc then row.label:SetWordWrap(true); row.label:SetMaxLines(2) end
    row.label:SetText(text(item.label))
    if item.icon and item.type == "toggle" then row.icon = W.Icon(row, item.icon, 14, "accent.primary") end
    row.control = makeControl(row, page, m, item)
    row.controlW = row.control and row.control:GetWidth() or W.CONTROL_WIDTH
    if hasDesc then
        row.desc = W.Text(row, "desc", "text.muted")
        row.desc:SetWordWrap(true)
        row.desc:SetText(text(item.desc))
    end
    -- no badge at rest (specs/003 T009): a row that hands Blizzard frames over says so in its tooltip, and only
    -- after it is changed does a "Reload needed" button appear next to its label (one click applies it)
    if item.reload then
        row.badge = W:Badge(row, L.RELOAD_NEEDED, "accent.primary", "reload")
        row.badge:Hide()
        function row.ArmReload(self)
            local b = self.badge
            b:Set(L.RELOAD_NEEDED, "accent.primary")
            b:EnableMouse(true)
            b:SetScript("OnMouseUp", function() C_UI.Reload() end)
            b:SetScript("OnEnter", function(me) W.ShowTooltip(me, L.RELOAD_NEEDED, L.RELOAD_NEEDED_TIP) end)
            b:SetScript("OnLeave", function() W.HideTooltip() end)
            self.reloadArmed = true
            b:Show()
            if self.Arrange and self.lastArrange then self:Arrange(unpack(self.lastArrange)) end
        end
        if m.needsReload and m.reloadKeys and m.reloadKeys[item] then row:ArmReload() end
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
        W.ShowTooltip(self.label, text(item.label), rowTip(page, m, item, not (self.desc and self.desc:IsShown())), true)
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
    local function controlWidth(r, width)
        return math.min(r.controlW, math.max(112, math.floor((width or 400) * 0.42)))
    end

    -- A full-width control sits under its label. One with its own height (c.natural) keeps it and the row grows
    -- to fit it, instead of being squeezed into the row (the Textures specimen ran past its panel: layout_lint).
    local function placeFullWidth(c)
        local topY = hasDesc and -48 or -32
        c:SetPoint("TOPLEFT", 16, topY)
        if c.natural then
            c:SetPoint("TOPRIGHT", -16, topY)
            row:SetHeight(math.max(item.height or 0, math.floor(-topY + c:GetHeight() + 12 + 0.5)))
        else
            c:SetPoint("BOTTOMRIGHT", -16, 12)
        end
    end

    local function arrangeLine(self, c, icons, mode, indent, width)
        if c then
            c:ClearAllPoints()
            -- a narrow card (3 columns) gives the control about two fifths of the row, so the label keeps its words
            if STRETCH[item.type] then c:SetWidth(controlWidth(row, width)) end
        end
        if c and item.fullWidth then
            placeFullWidth(c)
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
        self.lastArrange = { mode, width }
        self.mode, self.textW = mode, nil
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
        if self.badge and not self.reloadArmed then self.badge:Hide() end
        if self.badge and self.reloadArmed then
            self.badge:ClearAllPoints()
            -- after the label text, but never past the text column into the control
            -- a label that would be cut short keeps its words: the badge folds to its icon (the tooltip names it)
            local badgeW = math.max(64, (self.badge.text:GetUnboundedStringWidth() or 0) + 26)
            local full = self.label:GetUnboundedStringWidth() + 8 + badgeW > (self.textW or 140)
            self.badge.text:SetShown(not full)
            if full then
                self.badge:SetSize(20, 16); self.badge.icon:ClearAllPoints(); self.badge.icon:SetPoint("CENTER")
            else
                self.badge:Set(L.RELOAD_NEEDED, "accent.primary")
                self.badge.icon:ClearAllPoints(); self.badge.icon:SetPoint("LEFT", 6, 0)
            end
            local room = math.max(0, (self.textW or 140) - (self.badge:GetWidth() or 0) - 8)
            if self.textW then self.label:SetWidth(math.max(40, room)) end
            local labelW = math.min(self.label:GetUnboundedStringWidth(), self.label:GetWidth(), room)
            self.badge:SetPoint("LEFT", self.label, "LEFT", labelW + 8, 0)
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
                if self.control.natural then self.control:SetPoint("TOPRIGHT", -16, -math.floor(top + 8)) end
                -- and the row is as tall as the control really is (chips that wrap to a second line ran into
                -- the next row: layout_lint, Bags › Categories)
                local ch = tonumber(self.control.GetHeight and self.control:GetHeight()) or 0
                local room = math.max(base - 48, ch + 10)
                self:SetHeight(math.max(base, math.floor(top + 8 + room + 0.5)))
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
        self.flash:Show()
        ns.Anim:Tween(self.flash, 0.9, 1, 0, function(v)
            self.flash:SetAlpha(math.abs(math.sin(v * math.pi * 2)) * v)
        end, function() self.flash:SetAlpha(0); self.flash:Hide() end)
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
    -- a text given as a function (a status line) is read again on every refresh, not only when built
    function row:Refresh()
        if type(item.text) == "function" then self.text:SetText(item.text()) end
    end
    function row:Flash() end
    -- the height follows the wrapped text at the new width; measured before the width was set, a long help
    -- line (Unit Frames tags) kept a one-line height and ran over the rows under it (specs/003)
    function row:Arrange(_, width)
        if width then self.text:SetWidth(math.max(60, width - 32)) end
        self:Measure()
    end
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
--[[ v4 "Flow" header, outside the scroll so it stays put: module tile, breadcrumb (group > page > sub-page), title
    with the one-line summary beside it; on the right "N changed" (settings away from their defaults), Reset page,
    Move on screen and the Enabled switch; under them the Live preview switch on pages with a preview. ]]
local function changedCount(page)
    local n = 0
    for _, row in ipairs(page.rows or {}) do
        if row.IsModified and row.item.key ~= "enabled" and row:IsModified() then n = n + 1 end
    end
    return n
end
Config.ChangedCount = changedCount

local function buildPageHeader(page, m, schema)
    local h = CreateFrame("Frame", nil, page)
    h:SetHeight(HEADER_H)
    h:SetFrameLevel(page:GetFrameLevel() + 20)
    if Config.DragHandle then Config.DragHandle(h) end -- the page header moves the window (t213 #22)
    h.bg = W.Texture(h, "BACKGROUND", 0)
    h.bg:SetAllPoints()
    -- a faint accent wash from the module tile, so the header reads as the page's banner
    h.glow = W.Texture(h, "BACKGROUND", 1)
    h.glow:SetPoint("TOPLEFT"); h.glow:SetPoint("BOTTOMLEFT"); h.glow:SetWidth(520)
    h.iconBg = W.Texture(h, "ARTWORK", 0, Media.textures.ROUNDED)
    h.iconBg:SetSize(52, 52)
    h.iconBg:SetPoint("TOPLEFT", PAD, -14)
    h.icon = W.Icon(h, m.icon, 26, "accent.primary")
    h.icon:SetPoint("CENTER", h.iconBg)
    -- the module tile in Ember Bevel: the framed module icon fills the 52 px tile (the flat tile and glyph fade)
    h.bevel = ns.ChromeBevel and ns.ChromeBevel:Attach(h.icon, "module-" .. tostring(m.key):lower(), 52)
    if h.bevel then
        local function tile() h.iconBg:SetAlpha(ns.ChromeBevel.Enabled() and 0 or 1) end
        tile()
        h.bevel.onSync = tile
    end
    h.crumb = W.Text(h, "small", "text.muted")
    h.crumb:SetPoint("TOPLEFT", h.iconBg, "TOPRIGHT", 14, 2)
    h.crumb:SetWordWrap(false)
    h.title = W.Text(h, "title", "text.primary")
    h.title:SetPoint("TOPLEFT", h.crumb, "BOTTOMLEFT", 0, -4)
    h.title:SetText(text(m.label))
    h.desc = W.Text(h, "desc", "text.secondary")
    -- the summary has its own line under the title (GUI polish plan §1): beside the title it wrapped into the
    -- breadcrumb and the buttons (layout_lint). One line, under the buttons' row; a long one ends in "…" and the
    -- full text is the tooltip of that line.
    -- (its own box from under the title to the header's right edge: the buttons' row is above it)
    h.descArea = CreateFrame("Frame", nil, h)
    h.descArea:SetPoint("TOPLEFT", h.title, "BOTTOMLEFT", 0, -3)
    h.descArea:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -56, 0)
    h.desc:SetPoint("TOPLEFT", h.descArea, "TOPLEFT")
    h.desc:SetPoint("TOPRIGHT", h.descArea, "TOPRIGHT")
    h.desc:SetJustifyH("LEFT")
    h.desc:SetWordWrap(false)
    h.desc:SetMaxLines(1)
    h.descWraps = 1
    h.desc:SetText(text(m.desc))
    h.descHit = CreateFrame("Frame", nil, h)
    h.descHit:SetAllPoints(h.desc)
    W.AttachTooltip(h.descHit, text(m.label), text(m.desc))
    page.settingCount = Config.CountSettings(schema)
    -- "N settings" now lives in the tooltip of the title; the line under the title is the summary
    h.count = W.Text(h, "small", "text.muted")
    h.count:SetText(L.SETTINGS_COUNT:format(page.settingCount))
    h.count:Hide()
    h.state = W:Badge(h, "", "state.success")

    h.state:Hide()
    local anchor
    if not m.locked then
        h.toggle = W:Toggle(h)
        h.toggle:SetPoint("TOPRIGHT", -56, -20)
        h.toggle.onChange = function(_, v) ns:SetModuleEnabled(m.key, v) end
        h.toggleLabel = W.Text(h, "small", "text.secondary", "RIGHT")
        h.toggleLabel:SetPoint("RIGHT", h.toggle, "LEFT", -8, 0)
        anchor = h.toggleLabel
    end
    h.move = W:Button(h, L.LAYOUT_MODE, "secondary", "movers")
    h.move:SetHeight(28)
    h.move.onClick = function()
        local f = Config.frame
        if f and f.footer and f.footer.layout then f.footer.layout.onClick() end
    end
    W.AttachTooltip(h.move, L.LAYOUT_MODE, L.LAYOUT_MODE_DESC)
    if anchor then h.move:SetPoint("RIGHT", anchor, "LEFT", -18, 0) else h.move:SetPoint("TOPRIGHT", -56, -20) end
    anchor = h.move
    if hasDefaults(m) then
        h.reset = W:Button(h, L.RESET_MODULE, "ghost", "reset")
        h.reset:SetHeight(28)
        W.AttachTooltip(h.reset, L.RESET_MODULE, L.RESET_MODULE_DESC)
        h.reset:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
        armReset(h.reset, L.RESET_MODULE_CONFIRM:format(text(m.label)), function() resetModule(page, m) end)
        anchor = h.reset
    end
    h.changed = W:Badge(h, "", "accent.primary")
    h.changed:SetPoint("RIGHT", anchor, "LEFT", -10, 0)
    -- the breadcrumb and the title stop before the buttons (a long German title ran under "Modul zurücksetzen":
    -- layout_lint); a cut one ends in "…", and the full name is in the summary's tooltip
    h.state:ClearAllPoints()
    h.state:SetPoint("RIGHT", h.changed, "LEFT", -8, 0)
    -- (a box from the tile to the badges: TOP* anchors only, since a RIGHT anchor would also pin the text's
    -- vertical centre to the badge row)
    h.textArea = CreateFrame("Frame", nil, h)
    h.textArea:SetPoint("TOPLEFT", h.iconBg, "TOPRIGHT", 14, 2)
    h.textArea:SetPoint("BOTTOMRIGHT", h.state, "BOTTOMLEFT", -12, -40)
    h.crumb:ClearAllPoints()
    h.crumb:SetPoint("TOPLEFT", h.textArea, "TOPLEFT")
    h.crumb:SetPoint("TOPRIGHT", h.textArea, "TOPRIGHT")
    h.title:ClearAllPoints()
    h.title:SetPoint("TOPLEFT", h.crumb, "BOTTOMLEFT", 0, -4)
    h.title:SetPoint("TOPRIGHT", h.crumb, "BOTTOMRIGHT", 0, -4)
    for _, fs in ipairs({ h.crumb, h.title }) do
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
    end
    h.changed:Hide()
    W.AttachTooltip(h.changed, L.CHANGED_TITLE, L.CHANGED_DESC)
    -- clicking the count walks through the changed settings, one per click
    h.changed:EnableMouse(true)
    h.changed:SetScript("OnMouseUp", function()
        local list = {}
        for _, row in ipairs(page.rows or {}) do
            if row.IsModified and row.item.key ~= "enabled" and row:IsModified() then list[#list + 1] = row end
        end
        if #list == 0 then return end
        h.walk = (h.walk or 0) % #list + 1
        page:Focus(list[h.walk].item)
    end)
    h.line = W.Texture(h, "BORDER")
    h.line:SetHeight(1)
    h.line:SetPoint("BOTTOMLEFT", PAD, 0); h.line:SetPoint("BOTTOMRIGHT", -PAD, 0)
    -- design v2: the accent line under the header fades in from the left and flares on the right (Media/Window)
    h.flare = W.Texture(h, "OVERLAY", 0, Media.window.HEADER_GLOW)
    h.flare:SetBlendMode("ADD")
    h.flare:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, 20); h.flare:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", 0, 20)
    h.flare:SetHeight(32)
    Skin:Register(h, function(self)
        local Art = ns.Art
        W.Color(self.bg, "bg.base", Art and (Art.Enabled() or Art.WindowArt()) and Art:Token("panel.alpha.header") or nil)
        local r, g, b = ns.Theme:Color("accent.primary")
        self.glow:SetVertexColor(1, 1, 1, 1)
        self.glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.06), CreateColor(r, g, b, 0))
        self.flare:SetShown(Art and Art.WindowArt() and true or false)
        self.flare:SetVertexColor(r, g, b, 0.85)
        W.TileColor(self.iconBg, self.icon, "accent.soft")
        W.Color(self.icon, "accent.primary")
        Skin:Text(self.crumb, "small", "text.muted")
        Skin:Text(self.title, "title", "text.primary")
        Skin:Text(self.desc, "desc", "text.secondary")
        if self.toggleLabel then Skin:Text(self.toggleLabel, "small", "text.secondary") end
        Skin:Text(self.count, "small", "text.muted")
        W.Color(self.line, "border.subtle", 0.7)
    end)
    function h:Crumb()
        local g = Config.GroupOf and Config:GroupOf(m.key)
        local parts = { g and (L[g.label] or g.label) or nil, text(m.label) }
        local tl = page.tabList and page.tabList[page.tab or 1]
        if tl and #page.tabList > 1 then parts[#parts + 1] = tl.label end
        self.crumb:SetText(table.concat(parts, "  \226\128\186  "))
    end
    function h:Changed()
        local n = changedCount(page)
        if n > 0 then self.changed:Set(L.CHANGED_COUNT:format(n), "accent.primary"); self.changed:Show() else self.changed:Hide() end
    end
    function h:Refresh()
        local state, token
        if m.state == "errored" then state, token = L.STATE_ERROR, "state.danger"
        elseif m.needsReload then state, token = L.BADGE_RELOAD, "state.warning"
        end -- "on" is already said by the switch; the badge only appears when something needs attention
        if state then self.state:Set(state, token); self.state:Show() else self.state:Hide() end
        self:Crumb()
        self:Changed()
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
    local scopeSrc = type(item.values) == "function" and item.values(m) or item.values
    for i, v in ipairs(scopeSrc) do values[i] = { value = v.value, label = text(v.label) } end
    page.scope = { unit = values[1].value, mode = "this", multi = {}, root = item.key, values = values }
    local scope = page.scope

    -- v4: the chips sit in the fixed header area, under the title (the page scrolls under them)
    local bar = CreateFrame("Frame", nil, page)
    scope.bar = bar
    bar.inHeader = true
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
    end, nil, 170)
    bar.copy.placeholder = L.COPY_SETTINGS_FROM -- "Copy settings from…": the dropdown names itself
    bar.copy:SetValue(nil)
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

    -- GUI polish plan §1: one toolbar card. Top line: what is being edited and the Shift hint; under it the element
    -- chips on the left and, on the right, "Copy settings from…" and the Edit all switch (no label stacked over the
    -- dropdown any more). Narrow pages put the tools on their own line under the chips.
    local INSET, TOOL_GAP = 12, 16
    function bar:Arrange(width)
        self:SetWidth(width)
        self.copyLabel:Hide()
        self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", INSET, -10)
        local toolsW = self.copy:GetWidth() + TOOL_GAP + self.allLabel:GetStringWidth() + 8 + self.all:GetWidth()
        local room = width - 2 * INSET - toolsW - 24
        self.units:ClearAllPoints(); self.units:SetPoint("TOPLEFT", INSET, -30)
        local function tools(anchor, y)
            self.all:ClearAllPoints(); self.all:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -INSET, y)
            self.allLabel:ClearAllPoints(); self.allLabel:SetPoint("RIGHT", self.all, "LEFT", -8, 0)
            self.copy:ClearAllPoints(); self.copy:SetPoint("RIGHT", self.allLabel, "LEFT", -TOOL_GAP, 0)
        end
        if room < 220 then
            self.units:SetWidth(width - 2 * INSET)
            self.units:Arrange() -- wrap now: OnSizeChanged comes a frame later, after the height below is read
            local h = self.units:GetHeight()
            tools(self, -(30 + h + 8))
            self:SetHeight(30 + h + 8 + 26 + 10)
        else
            self.units:SetWidth(room)
            self.units:Arrange()
            tools(self, -30)
            self:SetHeight(30 + math.max(self.units:GetHeight(), 26) + 10)
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
            relayout()
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
        if ns.Art and ns.Art.WindowArt() then
            Skin:Panel(self, "raised", { border = "border.subtle", round = W.EUI.radius.card, alpha = "section" })
        else
            Skin:HidePanel(self)
        end
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

-- Quick edit: a click on a part of the preview opens the part's size and layout sliders right there (the
-- same settings as the rows below, written through setValue so multi-select and live apply hold).
local QUICK = { width = 1, height = 2, buttons = 3, rows = 4, size = 5, spacing = 6, spacingX = 7, spacingY = 8, scale = 9, x = 10, y = 11 }
local function quickEdit(page, m, key, anchor)
    local prefix = key and key:match("^(.*%.)[^.]+$")
    if not (prefix and anchor and page.rows) then return nil end
    local items = {}
    for _, row in ipairs(page.rows) do
        local it = row.item
        local leaf = it.key and it.key:sub(1, #prefix) == prefix and it.key:sub(#prefix + 1)
        if it.type == "range" and leaf and QUICK[leaf] and not (it.disabled and it.disabled(m)) then
            items[#items + 1] = it
        end
    end
    if #items == 0 then return nil end
    table.sort(items, function(a, b) return QUICK[a.key:sub(#prefix + 1)] < QUICK[b.key:sub(#prefix + 1)] end)
    local content = CreateFrame("Frame")
    local y = 4
    for i = 1, math.min(#items, 8) do
        local it = items[i]
        local lab = W.Text(content, "small", "text.secondary")
        lab:SetPoint("TOPLEFT", 12, -y)
        lab:SetText(text(it.label))
        local sl = W:Slider(content, it.min or 0, it.max or 100, it.step or 1, it.percent)
        sl:SetPoint("TOPLEFT", 12, -(y + 16))
        sl:SetPoint("RIGHT", -12, 0)
        sl:SetValue(getValue(page, m, it))
        sl.onChange = function(_, v) setValue(page, m, it, v) end
        y = y + 50
    end
    return W:Popover(anchor, L.QUICK_EDIT, content, 300, y), #items
end
Config.QuickEdit = quickEdit

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
    card.pane.onHot = function(key, hot)
        -- a press that became a drag (moving the part) is not also a click
        if hot and hot.suppress then hot.suppress = nil; return end
        if page.FocusKey then page:FocusKey(key) end
        quickEdit(page, m, key, hot)
        local ui = ns.DB.sv.global.ui
        if not ui.previewHintDismissed then ui.previewHintDismissed = true; page:Layout() end
    end
    -- drag the preview to size and place the element (Config/PreviewDrag.lua)
    ns.PreviewDrag:Attach(card.pane, page, m)
    card.pane.attachHot = function(hot) ns.PreviewDrag:AttachHot(hot, page, m) end
    for _, hot in ipairs(card.pane.hots or {}) do card.pane.attachHot(hot) end
    card.tag = W.Text(card, "small", "accent.text", "RIGHT")
    card.shade = W.Texture(card, "BACKGROUND", -1, Media.textures.FADE_V)
    card.shade:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, 0)
    card.shade:SetPoint("TOPRIGHT", card, "BOTTOMRIGHT", 0, 0)
    card.shade:SetHeight(14)
    card.shade:Hide()
    card.fold = W:IconButton(card, "hide", 22, L.PREVIEW_FOLD, L.PREVIEW_FOLD_DESC)
    card.fold:SetPoint("TOPRIGHT", -10, -9)
    -- Keep on screen: by default the preview scrolls away with the page, so the fixed chrome (header, chips,
    -- footer) stays within the 20% height budget (DESIGN_SYSTEM_V3 principle 2). Pinned, it sticks to the top.
    card.keepBtn = W:IconButton(card, "lock", 22, L.PREVIEW_KEEP, L.PREVIEW_KEEP_DESC)
    card.keepBtn:SetPoint("RIGHT", card.fold, "LEFT", -4, 0)
    card.keep = previewStore()[m.key .. ":keep"] == true
    local function paintKeep()
        card.keepBtn:SetAlpha(card.keep and 1 or 0.45)
    end
    card.keepBtn.onClick = function()
        card.keep = not card.keep
        previewStore()[m.key .. ":keep"] = card.keep or nil
        paintKeep()
        page:Stick()
    end
    paintKeep()
    card.tag:SetPoint("RIGHT", card.keepBtn, "LEFT", -8, 0)
    -- the obvious way to size and place the element: its width, height and offsets in one popover
    local sizeKey
    local function find(list, depth)
        if type(list) ~= "table" or depth > 6 or sizeKey then return end
        if list.type == "range" and type(list.key) == "string" and list.key:match("%.width$") then sizeKey = list.key; return end
        for _, v in ipairs(list) do find(v, depth + 1) end
        if type(list.items) == "table" then find(list.items, depth + 1) end
    end
    find(type(page.schema) == "function" and page.schema() or page.schema, 0)
    if sizeKey then
        card.size = W:Button(card, L.SIZE_POSITION, "secondary", "resize", 150)
        card.size:SetHeight(24)
        card.size:SetPoint("RIGHT", card.tag, "LEFT", -10, 0)
        card.size.onClick = function(b) quickEdit(page, m, sizeKey, b) end
    end
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
    card.hint = W.Text(card, "small", "text.primary", "CENTER")
    card.hint:SetWordWrap(false)
    card.hint:SetText(L.PREVIEW_BAND_HINT)
    local world = item.world or worldAction(m)
    if world then
        card.world = W:Button(card, L.PREVIEW_WORLD, "ghost", "test")
        card.world:SetHeight(24)
        card.world.onClick = function() world(m, page) end
    end
    -- the band look: no card panel, title or keep pin (the band never scrolls away)
    card.band = true
    card.header:Hide()
    if card.icon then card.icon:Hide() end
    if card.tick then card.tick:Hide() end
    card.keepBtn:Hide()
    card.tag:SetAlpha(0) -- the toolbar's picked chip already says which element the preview shows
    card.wash = W.Texture(card, "BACKGROUND", -8)
    card.wash:SetAllPoints()
    card.rule = W.Texture(card, "BORDER", 0)
    card.rule:SetPoint("BOTTOMLEFT"); card.rule:SetPoint("BOTTOMRIGHT")
    Skin:Register(card, function(self)
        Skin:HidePanel(self)
        self.wash:SetColorTexture(0, 0, 0, 0.10)
        self.rule:SetColorTexture(1, 1, 1, 0.06)
        self.rule:SetHeight(PixelUtil.ConvertPixelsToUIForRegion(1, self))
    end)
    Skin:Register(card.shade, function(t)
        t:SetTexCoord(0, 1, 0, 1)
        W.Color(t, "bg.base", 0.9)
    end)
    Skin:Register(card.hint, function(fs)
        Skin:Text(fs, "small", "text.primary")
        fs:SetTextColor(1, 1, 1, 0.45)
    end)
    function card:Tag()
        self.tag:SetText(page.scope and page.scope:Label():upper() or "")
    end
    --[[ EllesmereUI's live preview (owner, 8 Nov): a fixed band across the whole content width between the editing
        toolbar and the settings, never scrolling away. No card, no title: a faint dark wash with a hairline under
        it, the real frame centred with 20 px above and below, and one muted line under it that says a click on a part
        jumps to its setting (gone for good after the first such click). Phoenix's extras sit in a slim row at the top:
        the preview states on the left; Size & position, Show in world and fold on the right. ]]
    local BAND_PAD, TOOL_ROW_H, HINT_H = 20, 26, 29
    function card:Apply()
        local width = self:GetWidth()
        if not width or width < 50 then width = 360 end
        local inner = width - 2 * PAD
        local open = not self.collapsed
        local y = 12
        if self.states then
            self.states:SetShown(open)
            self.states:ClearAllPoints()
            self.states:SetPoint("TOPLEFT", PAD, -y)
            self.states:SetWidth(math.max(120, inner - 360))
        end
        if self.world then
            self.world:SetShown(open)
            self.world:ClearAllPoints()
            self.world:SetPoint("RIGHT", self.fold, "LEFT", -6, 0)
        end
        if self.size then
            self.size:ClearAllPoints()
            self.size:SetPoint("RIGHT", (self.world and self.world:IsShown()) and self.world or self.fold, "LEFT", -6, 0)
        end
        self.fold:ClearAllPoints(); self.fold:SetPoint("TOPRIGHT", -PAD + 4, -y)
        local rowH = math.max(TOOL_ROW_H, open and self.states and self.states:GetHeight() or 0)
        y = y + rowH
        self.pane:SetShown(open)
        if open then
            y = y + BAND_PAD - 8
            local scale = self.pane:Fit(inner)
            local dx = -(self.pane.contentShift or 0) -- centre the drawn sample in the band
            self.pane:ClearAllPoints()
            self.pane:SetPoint("TOPLEFT", self, "TOPLEFT", PAD / scale + dx, -y / scale)
            self.pane:SetPoint("TOPRIGHT", self, "TOPRIGHT", -PAD / scale + dx, -y / scale)
            y = y + self.pane:GetHeight() * scale + BAND_PAD
        end
        local hint = open and not ns.DB.sv.global.ui.previewHintDismissed
        self.hint:SetShown(hint)
        if hint then
            self.hint:ClearAllPoints()
            self.hint:SetPoint("BOTTOM", self, "BOTTOM", 0, 17)
            y = y + HINT_H - 12
        end
        ns.Icons:Apply(self.fold.icon, self.collapsed and "preview" or "hide", 11)
        self:SetHeight(open and y or (12 + TOOL_ROW_H + 10))
        self:Tag()
    end
    page.preview = card.pane
    page.pinned = card
    return card
end

---------------------------------------------------------------- pages
function Config.BuildModulePage(parent, key)
    local m = ns.modules[key]
    if m and m.placeholder then return Config.BuildSchemaPage(parent, m, Config.placeholderSchema) end
    return Config.BuildSchemaPage(parent, m, ns.options[key])
end

-- the hairline above a row and the zebra shade: every other line a shade lighter, so a long card reads across
local function lineLook(r, _, n)
    if not r.sep then
        r.sep = W:Separator(r)
        r.sep:SetPoint("TOPLEFT", 16, 0); r.sep:SetPoint("TOPRIGHT", -16, 0)
    end
    r.sep:SetShown(false) -- EllesmereUI rows have no hairlines, only the bands (t228)
    -- EllesmereUI row bands (specs/001 T012): lines alternate black 0.1 / 0.2 under the controls
    if not r.band then r.band = W.Texture(r, "BACKGROUND", 1) end
    -- inside a glass section (Window art) the bands stop short of its rounded edges
    local inset = ns.Art and ns.Art.WindowArt() and 8 or 0
    r.band:ClearAllPoints(); r.band:SetPoint("TOPLEFT", inset, 0); r.band:SetPoint("BOTTOMRIGHT", -inset, 0)
    local R = W.EUI.row
    r.bandA = n % 2 == 1 and R.evenA or R.oddA
    r.band:SetVertexColor(0, 0, 0, r.bandA)
    r.zebra = n % 2 == 1
end

local function placeGate(c, row)
    row:Show()
    row:Arrange("gate", 0)
    row:ClearAllPoints()
    row:SetPoint("TOPRIGHT", c, "TOPRIGHT", -48, -8)
end

local function hiddenIn(c, row) return row.hiddenState or c.collapsed end

-- Rows of one card, laid out: paired rows two per line when the card is wide enough. Returns the height.
local function layoutRows(c, width)
    local cy = c.hasHeader and (CARD_HEAD + 1) or 0
    -- EllesmereUI two-up lines (specs/001 T012): two 350 wide halves 42 apart, every line at least 50 high
    local R = W.EUI.row
    local pair = width >= math.max(PAIR_AT, 2 * R.dualW + R.dualGap)
    local cellW = math.floor((width - 2 - R.dualGap) / 2)
    local visible = {}
    for _, row in ipairs(c.rows) do
        if row == c.gateRow then
            placeGate(c, row)
        elseif hiddenIn(c, row) then
            row:Hide()
        else
            visible[#visible + 1] = row
        end
    end
    local i, first, n = 1, true, 0
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
            local w = together and cellW or width
            r:SetWidth(w)
            r:Arrange(together and "cell" or "line", w)
            r:Measure()
            r:SetPoint("TOPLEFT", c, "TOPLEFT", (j - 1) * (cellW + R.dualGap), -cy)
            lineLook(r, first, n)
            h = math.max(h, r:GetHeight())
        end
        if not row.item.height then h = math.max(h, R.h) end
        for _, r in ipairs(rows) do r:SetHeight(h) end
        first = false
        n = n + 1
        cy = cy + h
        i = i + #rows
    end
    return cy, #visible > 0 or c.gateRow ~= nil or c.collapsed
end

-- m: a module or a module-like table { key, label, desc, icon, locked = true, db = {}, singleColumn = bool }.
-- A sub-page shows its first section's icon (in the rail).
local function tabIcon(page, tab, item)
    local tl = item.type == "header" and tab and page.tabList[tab]
    if tl and not tl.icon then tl.icon = item.icon end
end

-- Folded cards: where each card's state is kept (per module and card title, account-wide like the window).
local function foldStore()
    local ui = ns.DB.sv.global.ui
    if type(ui.folded) ~= "table" then ui.folded = {} end
    return ui.folded
end

-- Summary chips of a folded card: the current value of its first compact rows ("Bottom", "Scale 1.00", a switch
-- that is on by its name). Returns up to CHIP_MAX strings.
local function summaryOf(page, m, card)
    local out = {}
    for _, row in ipairs(card.rows) do
        if #out >= CHIP_MAX then break end
        local item = row.item
        if row.compact ~= nil and row ~= card.gateRow and not row.hiddenState and (item.key or item.get) then
            local v = getValue(page, m, item)
            local label = text(item.label)
            if #label > 18 then label = label:sub(1, 17) .. "\226\128\166" end
            if item.type == "toggle" then
                if v then out[#out + 1] = label end
            else
                local d = describe(item, m, v)
                if d and d ~= "" then out[#out + 1] = item.type == "range" and (label .. " " .. d) or d end
            end
        end
    end
    return out
end

local function chip(card, i)
    card.chips = card.chips or {}
    local c = card.chips[i]
    if c then return c end
    c = CreateFrame("Frame", nil, card)
    c:SetHeight(18)
    c.bg = W.Texture(c, "BACKGROUND", 0, Media.textures.PILL)
    c.bg:SetAllPoints()
    c.text = W.Text(c, "small", "text.secondary", "CENTER")
    c.text:SetPoint("CENTER")
    Skin:Register(c, function(self) W.Color(self.bg, "bg.sunken"); Skin:Text(self.text, "small", "text.secondary", 11) end)
    card.chips[i] = c
    return c
end

-- the card header: title, setting count, fold chevron; folded, the summary chips fill the rest of the line
local function decorateCard(page, m, card)
    card.count = W:Badge(card, tostring(0), "text.muted")
    card.count:SetPoint("LEFT", card.header, "RIGHT", 8, 0)
    card.chev = W.Icon(card, "chevron-down", 12, "text.muted")
    card.chev:SetPoint("TOPRIGHT", -4, -20) -- on the title line (t228)
    card.fold = CreateFrame("Button", nil, card)
    card.fold:SetPoint("TOPLEFT", 0, 0); card.fold:SetPoint("TOPRIGHT", -36, 0); card.fold:SetHeight(CARD_HEAD - 2)
    card.fold:SetFrameLevel(card:GetFrameLevel() + 1)
    card.foldKey = m.key .. "/" .. (card.title or "")
    card.collapsed = foldStore()[card.foldKey] == true
    card.fold:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        card.collapsed = not card.collapsed
        foldStore()[card.foldKey] = card.collapsed or nil
        page:Layout()
    end)
    card.fold:SetScript("OnEnter", function() W.Color(card.chev, "text.primary") end)
    card.fold:SetScript("OnLeave", function() W.Color(card.chev, "text.muted") end)
    W.AttachTooltip(card.fold, card.title or "", L.CARD_FOLD_TIP)
    if card.reset then card.reset:ClearAllPoints(); card.reset:SetPoint("TOPRIGHT", -22, -14) end
    function card:Chips()
        for _, c in ipairs(self.chips or {}) do c:Hide() end
        if not self.collapsed then return end
        local x = 22 + self.header:GetStringWidth() + 8 + (self.count:IsShown() and self.count:GetWidth() + 10 or 0)
        local limit = (self:GetWidth() or 300) - 70
        for i, s in ipairs(summaryOf(page, m, self)) do
            local c = chip(self, i)
            c.text:SetText(s)
            local w = math.floor(c.text:GetStringWidth() + 16)
            if x + w > limit then break end
            c:SetWidth(w)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", self, "TOPLEFT", x, -17)
            c:Show()
            x = x + w + 6
        end
    end
end

-- the narrowest card a row of fixed-width controls (a name box and its button) still fits in
function needWidth(c)
    if c.needW then return c.needW end
    local need = 0
    for _, row in ipairs(c.rows or {}) do
        local ctrl = row.control
        if ctrl and row.item.type == "custom" and not row.item.fullWidth then
            local w = ctrl:GetWidth() or 0
            if w > 0 then need = math.max(need, w + (row.icon and 38 or 16) + 32 + 160) end
        end
    end
    c.needW = need
    return need
end

local function newCard(page, m, child, item, tab)
    local isHead = item.type == "header"
    local card = W:Card(child, isHead and text(item.label) or nil, isHead and item.icon or nil, true)
    card.headH = CARD_HEAD
    card.header:ClearAllPoints()
    card.header:SetPoint("BOTTOMLEFT", card, "TOPLEFT", item.icon and isHead and 22 or 16, -(CARD_HEAD - 8))
    card.rows = {}
    card.tab = tab or 1
    card.wide = isHead and item.wide
    card.title = isHead and text(item.label) or text(m.label)
    if isHead then
        card.reset = W:IconButton(card, "reset", 22, L.RESET_CARD, L.RESET_CARD_DESC)
        card.reset:SetPoint("TOPRIGHT", -22, -14)
        card.reset:Hide()
        armReset(card.reset, L.RESET_CARD_CONFIRM:format(card.title), function() resetCard(page, m, card) end)
        decorateCard(page, m, card)
    end
    return card
end

local function countCards(page)
    for _, c in ipairs(page.cards) do
        if c.count then
            local n = 0
            for _, row in ipairs(c.rows) do if row.compact ~= nil and row ~= c.gateRow then n = n + 1 end end
            c.count:Set(tostring(n), "text.muted")
            c.count:SetShown(n > 0)
        end
    end
end

local TAB_BAR_H = 40 -- EllesmereUI's tab bar under the page header (specs/001 T010)
Config.TAB_BAR_H = TAB_BAR_H

local function makeRouter(page, key)
    -- sub-pages: tabs along the bottom of the page header, EllesmereUI style (specs/001 T010); the router keeps
    -- the tabs API (SetValue / onChange) that search, links and the smoke tests use
    if #page.tabList > 1 then
        page.tabs = { value = 1 }
        local items = {}
        for i, t in ipairs(page.tabList) do items[i] = { value = i, label = t.label } end
        local h = page.header
        h.tabBar = W:Tabs(h, items)
        h.tabBar:SetPoint("BOTTOMLEFT", PAD - 12, 0); h.tabBar:SetPoint("BOTTOMRIGHT", -PAD, 0)
        h:SetHeight(HEADER_H + TAB_BAR_H)
        page.headerH = HEADER_H + TAB_BAR_H
        h.tabBar.onChange = function(_, v) page.tabs.onChange(page.tabs, v) end
        function page.tabs:SetValue(v) self.value = v; page.tab = v; h.tabBar:SetValue(v) end
        function page.tabs:GetValue() return self.value end
        page.tabs.onChange = function(_, v)
            local ui = ns.DB.sv.global.ui
            if type(ui.lastTab) ~= "table" then ui.lastTab = {} end
            ui.lastTab[key] = v
            page.tabs.value = v
            page.tab = v
            page.header.tabBar:SetValue(v)
            W.HidePopover()
            page:Layout()
            page.scroll:SetVerticalScroll(0)
            page.scroll:UpdateBar()
            page.header:Crumb()
            if Config.LayoutSidebar and Config.current == key then Config:LayoutSidebar() end
        end
    end
    -- the sub-page last open on this module opens again (EllesmereUI keeps the last page per module too)
    local last = type(ns.DB.sv.global.ui.lastTab) == "table" and ns.DB.sv.global.ui.lastTab[key]
    if page.tabs and type(last) == "number" and page.tabList[last] then page.tabs:SetValue(last) end
    function page:SetTab(v)
        if self.tabs then self.tabs:SetValue(v); self.tabs.onChange(self.tabs, v) end
    end
end

-- Whole-pixel columns: the remainder of (width - gaps) / cols goes to the first columns one pixel each, so 1114 px
-- at 3 columns is 362 / 361 / 361 (not 360.67 three times, which drifts off the pixel grid). Returns the narrowest
-- width and each column's x and width.
local function pixelColumns(width, cols)
    local avail = math.floor(width) - (cols - 1) * CARD_GAP
    local colW = math.floor(avail / cols)
    local extra = avail - colW * cols
    local colX, colWs, x = {}, {}, PAD
    for i = 1, cols do
        colWs[i] = colW + (i <= extra and 1 or 0)
        colX[i] = x
        x = x + colWs[i] + CARD_GAP
    end
    return colW, colX, colWs
end

function Config.BuildSchemaPage(parent, m, schema)
    local key = m.key
    local page = CreateFrame("Frame", nil, parent)
    page.scroll = W:Scroll(page)
    page.scroll:SetPoint("TOPLEFT", 0, -HEADER_H)
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
            page.tabList[tab] = { value = tab, label = text(item.label), icon = item.icon }
            card = nil
        elseif t == "scope" then
            page.tops[#page.tops + 1] = buildScope(page, m, item)
        elseif t == "preview" then
            buildPreview(page, m, item)
        else
            tabIcon(page, tab, item)
            if t == "header" or not card then
                card = newCard(page, m, child, item, tab)
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
    page.tab = 1
    countCards(page)
    makeRouter(page, key)

    local function layoutCard(c, width)
        c:SetWidth(width)
        local cy, any = layoutRows(c, width)
        -- a glass section (Window art) keeps a little room under its last row, clear of the rounded corners
        local foot = (ns.Art and ns.Art.WindowArt() and not c.collapsed and cy > CARD_HEAD + 1) and 8 or 0
        c:SetHeight(c.collapsed and (CARD_HEAD + 1) or (cy + foot))
        if c.chev then
            ns.Icons:Apply(c.chev, c.collapsed and "chevron-right" or "chevron-down", 12)
            c:Chips()
        end
        if c.reset then
            local modified = false
            for _, row in ipairs(c.rows) do
                if row.IsModified and row:IsModified() then modified = true; break end
            end
            c.reset:SetShown(modified)
        end
        return any
    end

    -- columns by width: 3 from THREE_COLUMNS_AT, 2 from TWO_COLUMNS_AT
    local function columns(width, onPage)
        if m.singleColumn or onPage < 2 then return 1 end
        if width >= THREE_COLUMNS_AT and onPage > 2 then return 3 end
        if width >= TWO_COLUMNS_AT then return 2 end
        return 1
    end
    Config.Columns = Config.Columns or columns
    -- EllesmereUI pages are one column of sections (specs/001 T012); a page may ask for columns (columnsOK)
    local function pageColumns(pg, width, n) return pg.columnsOK and columns(width, n) or 1 end

    -- the live preview band sits in the fixed area too, across the whole content width; returns the new top
    -- A module that is off says so once, with its switch, instead of a page of settings that seem to do nothing
    -- (GUI polish plan §8). The settings stay editable and apply when it is turned on. Returns the new top.
    function page:PlaceOffBanner(top, width)
        local off = m and not m.locked and not m.placeholder and m.IsEnabled and not m:IsEnabled()
        local b = self.offBanner
        if not off then
            if b then b:Hide() end
            return top
        end
        if not b then
            b = CreateFrame("Frame", nil, self)
            b:SetHeight(44)
            b:SetFrameLevel(self.scroll:GetFrameLevel() + 12)
            b.icon = W.Icon(b, "warning", 16, "state.warning")
            b.icon:SetPoint("LEFT", 16, 0)
            b.text = W.Text(b, "body", "text.primary", "LEFT")
            b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
            b.text:SetWordWrap(false)
            b.on = W:Button(b, L.MODULE_OFF_TURN_ON, "primary", "check")
            b.on:SetHeight(28)
            b.on:SetPoint("RIGHT", -12, 0)
            b.text:SetPoint("RIGHT", b.on, "LEFT", -12, 0)
            b.on.onClick = function() ns:SetModuleEnabled(m.key, true) end
            b.fill = W.Texture(b, "BACKGROUND", 0)
            Skin:RoundFill(b, b.fill, W.EUI.radius.card)
            Skin:SetRound(b, W.EUI.radius.card)
            Skin:Border(b)
            Skin:Register(b, function(f)
                local r, g, bl = ns.Theme:Color("state.warning")
                f.fill:SetVertexColor(r, g, bl, 0.10)
                Skin:SetBorderColor(f, r, g, bl, 0.45)
                W.Color(f.icon, "state.warning")
                Skin:Text(f.text, "body", "text.primary")
            end)
            self.offBanner = b
        end
        b.text:SetText(L.MODULE_OFF_BANNER:format(text(m.label)))
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, -(top + 10))
        b:SetWidth(width)
        b:Show()
        return top + 10 + b:GetHeight() + 4
    end

    function page:PlaceBand(top, width)
        local pc = self.pinned
        if not pc or self.docked then return top end
        pc:ClearAllPoints()
        pc:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -top)
        pc:SetWidth(width + 2 * PAD)
        pc:Apply()
        pc:Show()
        return top + pc:GetHeight()
    end

    function page:Layout()
        local width = math.max(320, child:GetWidth() - 2 * PAD)
        -- the fixed area: header, then the element chips; the scroll starts under them
        local top = self.headerH or HEADER_H
        for _, t in ipairs(self.tops) do
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, -(top + 10))
            if t.Arrange then t:Arrange(width) else t:SetWidth(width) end
            top = top + 10 + t:GetHeight()
        end
        if #self.tops > 0 then top = top + 6 end
        top = self:PlaceBand(top, width)
        top = self:PlaceOffBanner(top, width)
        if self.fixedTop ~= top then
            self.fixedTop = top
            self.scroll:ClearAllPoints()
            self.scroll:SetPoint("TOPLEFT", 0, -top)
            self.scroll:SetPoint("BOTTOMRIGHT", -10, 0)
        end
        local y = 0 -- the first section's own 40 px title band is the top space (t228)
        if self.pinned and not self.docked then y = 12 end -- a little air under the preview band
        local onPage = 0
        for _, c in ipairs(self.cards) do
            if not self.tabs or c.tab == self.tab then onPage = onPage + 1 end
        end
        -- EllesmereUI pages are one column of sections (specs/001 T012); Home keeps its own columns
        local cols = pageColumns(self, width, onPage)
        local colW, colX, colWs = pixelColumns(width, cols)
        local colY = {}
        for i = 1, cols do colY[i] = y end
        local function lowest() local v = y; for i = 1, cols do v = math.max(v, colY[i]) end; return v end
        -- cards that span the page (wide ones, and ones whose controls need more room than a column) go first,
        -- so the columns under them end level and nothing leaves a gap
        local order = {}
        for _, c in ipairs(self.cards) do
            c.spans = cols == 1 or c.wide or needWidth(c) > colW
            if c.spans then order[#order + 1] = c end
        end
        for _, c in ipairs(self.cards) do if not c.spans then order[#order + 1] = c end end
        for _, c in ipairs(order) do
            local onTab = not self.tabs or c.tab == self.tab
            local spans = c.spans
            -- a column card is sized for the narrowest column, then widened to its column once placed
            if onTab and layoutCard(c, spans and width or colW) then
                c:Show()
                c:ClearAllPoints()
                if spans then
                    local t = lowest()
                    c:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -t)
                    for i = 1, cols do colY[i] = t + c:GetHeight() + CARD_GAP end
                else
                    -- masonry: the shortest column takes the next card, so columns stay level and gap-free
                    local col = 1
                    for i = 2, cols do if colY[i] < colY[col] then col = i end end
                    if colWs[col] ~= colW then layoutCard(c, colWs[col]) end
                    c:SetPoint("TOPLEFT", child, "TOPLEFT", colX[col], -colY[col])
                    colY[col] = colY[col] + c:GetHeight() + CARD_GAP
                end
            else
                c:Hide()
            end
        end
        -- a full PAD of room under the last card, so the last row clears the footer edge at full scroll (specs/003 T004)
        child:SetHeight(lowest() + PAD) -- one PAD under the last row: clears the footer, no empty band (t228)
        self.scroll:UpdateBar()
        self.header:Changed()
        self:Stick()
    end

    -- keeps the pinned preview card in its slot, or at the top once its slot scrolls past (not when docked)
    local STICK_TOP = 6
    function page:Stick()
        local pc = self.pinned
        if not pc or not self.pinnedY or self.docked then
            if pc then pc.shade:Hide() end
            return
        end
        local top = self.pinnedY - self.scroll:GetVerticalScroll()
        -- stuck only once its slot has really scrolled away: the slot starts at 0, and "< STICK_TOP" hid the card
        -- on every page at scroll 0, leaving its empty band above the first section (Forever screenshots 11-07)
        local stuck = top < 0
        -- not kept on screen: once its slot scrolls under the header the preview gets out of the way
        pc:SetShown(not stuck or pc.keep)
        if stuck and not pc.keep then
            pc.shade:Hide()
            self.stuck = false
            return
        end
        pc:ClearAllPoints()
        pc:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, -((self.fixedTop or self.headerH or HEADER_H) + math.max(STICK_TOP, top)))
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
                    self.header:Crumb()
                    if Config.current == key then Config:LayoutSidebar() end
                end
                -- a folded card opens to show the row
                if row.card.collapsed then
                    row.card.collapsed = false
                    foldStore()[row.card.foldKey] = nil
                end
                self:Layout()
                local clear = 40 -- the preview band sits above the scroll area now, so nothing covers the row
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
