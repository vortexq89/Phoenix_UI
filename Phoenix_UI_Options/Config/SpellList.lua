local _, ns = ...
local W, Skin, L = ns.Widgets, ns.Skin, ns.L

--[[ A list of spells or items shown as what it holds (docs/BUILD_LOOP.md, page checklist "Lists"): one tile per
    entry with the real icon, the name on hover, right-click to take it out, drag to reorder, and a "+" tile that
    opens a picker of the character's own spells (or the items in their bags) with a search box. The stored value
    stays the comma separated text the module already reads, so every typed form (names, item:ID, trinket1,
    conditions such as ?ID or :MAGE, pairs such as 11366=48108) is kept as typed and can still be edited as text
    in the picker.

    ns.Opt.SpellList{ key, label, desc, items = bool, rows = n, … } returns the schema row. ]]
local TILE, GAP = 30, 4
local PICK_COLS, PICK_ROWS, PICK_TILE = 10, 4, 30
local UNKNOWN = 134400 -- the question mark icon (file id)

local function api(name, space)
    local t = space and _G[space]
    local fn = (type(t) == "table" and t[name]) or _G[name]
    return type(fn) == "function" and fn or nil
end

local function split(list)
    local parts = {}
    for part in tostring(list or ""):gmatch("[^,;\n]+") do
        local p = part:gsub("^%s+", ""):gsub("%s+$", "")
        if p ~= "" then parts[#parts + 1] = p end
    end
    return parts
end
local function join(parts) return table.concat(parts, ", ") end

-- What an entry is: { kind = "spell" | "item" | "slot" | "name" | "other", id, name }.
local function describe(part, items)
    local lower = part:lower()
    local item = lower:match("^item:(%d+)")
    local slot = lower:match("^trinket([12])")
    local num = part:match("^(%d+)")
    if item then return { kind = "item", id = tonumber(item) } end
    if slot then return { kind = "slot", id = 12 + tonumber(slot) } end
    if lower:match("^macro:") then return { kind = "other", name = part } end
    if num then return { kind = items and "item" or "spell", id = tonumber(num) } end
    return { kind = "name", name = part }
end
ns.Opt.SpellListDescribe = describe

local function look(d)
    local icon, name
    if d.kind == "spell" or d.kind == "name" then
        local tex, nm = api("GetSpellTexture", "C_Spell"), api("GetSpellName", "C_Spell")
        local what = d.id or d.name
        icon = tex and tex(what)
        name = nm and nm(what) or d.name
    elseif d.kind == "item" then
        local tex, nm = api("GetItemIconByID", "C_Item"), api("GetItemNameByID", "C_Item")
        icon = tex and tex(d.id)
        name = nm and nm(d.id)
    elseif d.kind == "slot" then
        icon = GetInventoryItemTexture("player", d.id)
        name = d.id == 13 and L.SPELLLIST_TRINKET1 or L.SPELLLIST_TRINKET2
    else
        name = d.name
    end
    return icon or UNKNOWN, name
end

-- The items in the bags that can be used, each once: { id, name, icon }.
local function bagItems()
    local out, seen = {}, {}
    local slots, info = api("GetContainerNumSlots", "C_Container"), api("GetContainerItemInfo", "C_Container")
    local spell = api("GetItemSpell", "C_Item")
    if not (slots and info) then return out end
    for bag = 0, 5 do
        for slot = 1, tonumber(slots(bag)) or 0 do
            local it = info(bag, slot)
            local id = type(it) == "table" and it.itemID
            if id and not seen[id] and (not spell or spell(id)) then
                seen[id] = true
                local nm = api("GetItemNameByID", "C_Item")
                out[#out + 1] = { id = id, name = nm and nm(id) or tostring(id), icon = it.iconFileID }
            end
        end
    end
    return out
end

local function tile(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.edge = CreateFrame("Frame", nil, b)
    b.edge:SetAllPoints()
    Skin:Register(b.edge, function(e) Skin:Border(e, b.on and "accent.primary" or "border.subtle") end)
    return b
end

local function gameTip(owner, d, hint)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if d.kind == "spell" and d.id then GameTooltip:SetSpellByID(d.id)
    elseif d.kind == "item" and d.id then GameTooltip:SetHyperlink("item:" .. d.id)
    elseif d.kind == "slot" then GameTooltip:SetInventoryItem("player", d.id)
    else GameTooltip:SetText(d.name or "") end
    if hint then GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

local function build(row, m, page, item)
    local h = CreateFrame("Frame", nil, row)
    h:SetHeight((item.rows or 2) * (TILE + GAP))
    h.tiles = {}
    local function value() return tostring(ns.Config.GetRowValue(page, m, item) or "") end
    local function store(parts)
        ns.Config.SetRowValue(page, m, item, join(parts))
        h:SetValue()
        if h.picker and h.picker:IsVisible() then h.picker:Refresh() end
    end

    h.empty = W.Text(h, "desc", "text.muted")
    h.empty:SetPoint("LEFT", TILE + 10, 0)
    h.empty:SetText(L.SPELLLIST_EMPTY)

    h.add = tile(h, TILE)
    h.add.plus = W.Text(h.add, "title", "accent.text", "CENTER")
    h.add.plus:SetPoint("CENTER", 0, 1)
    h.add.plus:SetText("+")
    h.add:SetScript("OnEnter", function(self)
        W.ShowTooltip(self, L.SPELLLIST_ADD, item.items and L.SPELLLIST_ADD_ITEMS or L.SPELLLIST_ADD_DESC)
    end)
    h.add:SetScript("OnLeave", W.HideTooltip)

    -- drag a tile onto another to move it there
    local function indexAtCursor()
        local x, y = GetCursorPosition()
        local s = h:GetEffectiveScale()
        x, y = x / s, y / s
        for i, t in ipairs(h.tiles) do
            if t:IsShown() and t:GetLeft() and x >= t:GetLeft() - GAP / 2 and x <= t:GetRight() + GAP / 2
                and y >= t:GetBottom() - GAP / 2 and y <= t:GetTop() + GAP / 2 then return i end
        end
    end
    local function entry(i)
        local t = h.tiles[i]
        if t then return t end
        t = tile(h, TILE)
        t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        t:RegisterForDrag("LeftButton")
        t:SetScript("OnEnter", function(self) gameTip(self, self.d, L.SPELLLIST_TIP) end)
        t:SetScript("OnLeave", function() GameTooltip:Hide() end)
        t:SetScript("OnClick", function(self, button)
            if button ~= "RightButton" then return end
            local parts = split(value())
            table.remove(parts, self.index)
            GameTooltip:Hide()
            store(parts)
        end)
        t:SetScript("OnDragStart", function(self) self:SetAlpha(0.5); self.dragging = true end)
        t:SetScript("OnDragStop", function(self)
            self:SetAlpha(1)
            if not self.dragging then return end
            self.dragging = nil
            local to = indexAtCursor()
            if not to or to == self.index then return end
            local parts = split(value())
            local moved = table.remove(parts, self.index)
            if moved then table.insert(parts, math.min(to, #parts + 1), moved); store(parts) end
        end)
        h.tiles[i] = t
        return t
    end

    function h:SetValue()
        local parts = split(value())
        local w = self:GetWidth()
        local cols = math.max(4, math.floor(((w and w > 0) and w or 560) / (TILE + GAP)))
        local room = cols * (item.rows or 2) - 1
        local shown = math.min(#parts, room)
        for i = 1, shown do
            local t = entry(i)
            t.index, t.d = i, describe(parts[i], item.items)
            t.icon:SetTexture((look(t.d)))
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", ((i - 1) % cols) * (TILE + GAP), -math.floor((i - 1) / cols) * (TILE + GAP))
            t:Show()
        end
        for i = shown + 1, #self.tiles do self.tiles[i]:Hide() end
        self.add:ClearAllPoints()
        self.add:SetPoint("TOPLEFT", (shown % cols) * (TILE + GAP), -math.floor(shown / cols) * (TILE + GAP))
        self.empty:SetShown(#parts == 0)
        self.count = #parts
    end

    -- the picker: search, the character's spells (or bag items) as tiles, and the list as text
    local function picker()
        local p = h.picker
        if p then return p end
        p = CreateFrame("Frame", nil, h)
        p.search = W:Input(p, 220, item.items and L.SPELLLIST_SEARCH_ITEMS or L.TRACKER_PICK_SEARCH)
        p.search:SetPoint("TOPLEFT", 12, 0)
        p.cells = {}
        for i = 1, PICK_COLS * PICK_ROWS do
            local b = tile(p, PICK_TILE)
            b:SetPoint("TOPLEFT", 12 + ((i - 1) % PICK_COLS) * (PICK_TILE + GAP), -34 - math.floor((i - 1) / PICK_COLS) * (PICK_TILE + GAP))
            b:SetScript("OnEnter", function(self) gameTip(self, { kind = item.items and "item" or "spell", id = self.id }) end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function(self)
                local parts, found = split(value()), false
                for k = #parts, 1, -1 do
                    local d = describe(parts[k], item.items)
                    if d.id == self.id and d.kind ~= "slot" then table.remove(parts, k); found = true end
                end
                if not found then parts[#parts + 1] = tostring(self.id) end
                store(parts)
            end)
            p.cells[i] = b
        end
        p.textLabel = W.Text(p, "small", "text.muted")
        p.textLabel:SetPoint("TOPLEFT", 12, -38 - PICK_ROWS * (PICK_TILE + GAP))
        p.textLabel:SetText(L.SPELLLIST_TEXT)
        p.text = W:Input(p, PICK_COLS * (PICK_TILE + GAP) - GAP)
        p.text:SetPoint("TOPLEFT", p.textLabel, "BOTTOMLEFT", 0, -4)
        p.text.onChange = function(_, v) store(split(v)) end
        function p:Refresh()
            local have = {}
            for _, part in ipairs(split(value())) do
                local d = describe(part, item.items)
                if d.id and d.kind ~= "slot" then have[d.id] = true end
            end
            local q = (self.search:GetText() or ""):lower()
            local n = 0
            for _, s in ipairs(item.items and bagItems() or ns.Opt.SpellbookSpells()) do
                if n >= #self.cells then break end
                if q == "" or tostring(s.name):lower():find(q, 1, true) then
                    n = n + 1
                    local b = self.cells[n]
                    b.id, b.on = s.id, have[s.id] or false
                    b.icon:SetTexture(s.icon)
                    Skin:Border(b.edge, b.on and "accent.primary" or "border.subtle")
                    b:Show()
                end
            end
            for i = n + 1, #self.cells do self.cells[i]:Hide() end
            if not self.text:HasFocus() then self.text:SetValue(value()) end
        end
        p.search.onTextChanged = function() p:Refresh() end
        p.height = 38 + PICK_ROWS * (PICK_TILE + GAP) + 16 + 30 + 8
        h.picker = p
        return p
    end
    h.add:SetScript("OnClick", function(self)
        local p = picker()
        W:Popover(self, L[item.label] or L.SPELLLIST_ADD, p, PICK_COLS * (PICK_TILE + GAP) - GAP + 24, p.height)
        if p:IsVisible() then p:Refresh() end
    end)

    function h:SetEnabledState(on)
        self:SetAlpha(on and 1 or 0.4)
        self.add:EnableMouse(on)
        for _, t in ipairs(self.tiles) do t:EnableMouse(on) end
    end
    h:SetScript("OnSizeChanged", function(self) self:SetValue() end)
    h:SetValue()
    return h
end

function ns.Opt.SpellList(item)
    item.type, item.fullWidth, item.resettable = "custom", true, true
    item.height = (item.rows or 2) * (TILE + GAP) + 6
    item.build = function(row, m, page) return build(row, m, page, item) end
    return item
end
