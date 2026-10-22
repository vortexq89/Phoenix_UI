local _, ns = ...
local L, W, Skin, Theme, Config = ns.L, ns.Widgets, ns.Skin, ns.Theme, ns.Config
local C = ns.SimCard

--[[ Sim page: pick gear on a paperdoll and in your bags, choose what to sim, prepare the request, reload.
    The pinned preview is the results card (Previews/Sim.lua); history rows switch what it shows. ]]

local GROUP_KEY = {
    head = "HEAD", neck = "NECK", shoulder = "SHOULDER", back = "BACK", chest = "CHEST", wrist = "WRIST",
    hands = "HANDS", waist = "WAIST", legs = "LEGS", feet = "FEET", finger = "FINGER", trinket = "TRINKET",
    main_hand = "MAIN", off_hand = "OFF", weapon = "WEAPON",
}
local function slotLabel(group) return GROUP_KEY[group] and L["SIM_SLOT_" .. GROUP_KEY[group]] or tostring(group) end

local function Sim() return ns.modules.Sim end

---------------------------------------------------------------- item picker
local LIST_ROWS, ROW_H, DOLL = 10, 26, 34
-- Empty equipment slot art (Interface\PaperDoll\UI-PaperDoll-Slot-*), as the character frame shows it.
local EMPTY_SLOT = {
    [1] = 136516, [2] = 136519, [3] = 136526, -- fileID: Head, Neck, Shoulder
    [15] = 136512, [5] = 136512, [9] = 136530, -- fileID: Chest (back and chest), Wrists
    [10] = 136515, [6] = 136529, [7] = 136517, [8] = 136513, -- fileID: Hands, Waist, Legs, Feet
    [11] = 136514, [12] = 136514, [13] = 136528, [14] = 136528, -- fileID: Finger, Trinket
    [16] = 136518, [17] = 136524, -- fileID: MainHand, SecondaryHand
}

local function qualityColor(q)
    local c = ITEM_QUALITY_COLORS[q or 1]
    if c then return c.r, c.g, c.b end
    return Theme:Color("text.primary")
end

local function checkbox(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(16, 16)
    b.fill = W.Texture(b, "BACKGROUND")
    b.fill:SetAllPoints()
    b.mark = W.Icon(b, "check", 12, "bg.base")
    b.mark:SetPoint("CENTER")
    function b:SetChecked(on)
        self.on = on
        if on then W.Color(self.fill, "accent.primary") else W.Color(self.fill, "bg.sunken") end
        self.mark:SetShown(on)
    end
    Skin:Register(b, function(self) Skin:Border(self, "border.strong"); self:SetChecked(self.on) end)
    return b
end

local function showItemTip(owner, link)
    if not link then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

local function buildPicker(row)
    local p = CreateFrame("Frame", nil, row)
    p.filter = nil -- slot group or nil (all)
    p.offset = 0

    -- paperdoll: two columns of equipped slots; a click filters the bag list to that slot
    p.doll = {}
    local m = Sim()
    for i, slot in ipairs(m.PAPERDOLL) do
        local b = CreateFrame("Button", nil, p)
        b:SetSize(DOLL, DOLL)
        local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
        b:SetPoint("TOPLEFT", col * (DOLL + 6), -line * (DOLL + 6))
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.level = W.Text(b, "number", "text.primary", "CENTER")
        b.level:SetPoint("BOTTOM", 0, 2)
        b.count = W.Text(b, "small", "bg.base", "CENTER")
        b.badge = W.Texture(b, "OVERLAY", 1)
        b.badge:SetSize(14, 14)
        b.badge:SetPoint("TOPRIGHT", 3, 3)
        b.count:SetPoint("CENTER", b.badge, "CENTER")
        b.slot = slot
        b:SetScript("OnClick", function(self)
            local g = m.SLOT_GROUP[self.slot]
            p.filter = p.filter ~= g and g or nil
            p.offset = 0
            p:Paint()
        end)
        b:SetScript("OnEnter", function(self)
            if self.item then showItemTip(self, self.item.link) else
                W.ShowTooltip(self, slotLabel(m.SLOT_GROUP[self.slot]), L.SIM_SLOT_EMPTY)
            end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide(); W.HideTooltip() end)
        p.doll[i] = b
    end
    local listLeft = 2 * (DOLL + 6) + 14

    p.title = W.Text(p, "heading", "text.secondary")
    p.title:SetPoint("TOPLEFT", listLeft, -4)
    p.clear = W:Button(p, L.SIM_CLEAR, "ghost", "close")
    p.clear:SetPoint("TOPRIGHT", 0, 2)
    p.clear.onClick = function()
        wipe(m.selected)
        ns.Events:Fire("PUI_SIM_CHANGED")
    end
    p.all = W:Button(p, L.SIM_ALL_SLOTS, "ghost", "filter")
    p.all:SetPoint("RIGHT", p.clear, "LEFT", -6, 0)
    p.all.onClick = function() p.filter = nil; p.offset = 0; p:Paint() end

    p.rows = {}
    for i = 1, LIST_ROWS do
        local r = CreateFrame("Button", nil, p)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", listLeft, -30 - (i - 1) * ROW_H)
        r:SetPoint("RIGHT")
        r.hl = W.Texture(r, "BACKGROUND")
        r.hl:SetAllPoints()
        r.check = checkbox(r)
        r.check:SetPoint("LEFT", 6, 0)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("LEFT", r.check, "RIGHT", 8, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.sim = W.Text(r, "number", "text.secondary", "RIGHT")
        r.sim:SetPoint("RIGHT", -8, 0)
        r.sim:SetWidth(70)
        r.slot = W.Text(r, "small", "text.muted", "RIGHT")
        r.slot:SetPoint("RIGHT", r.sim, "LEFT", -6, 0)
        r.slot:SetWidth(80)
        r.level = W.Text(r, "number", "text.primary", "RIGHT")
        r.level:SetPoint("RIGHT", r.slot, "LEFT", -6, 0)
        r.level:SetWidth(36)
        r.name = W.Text(r, "body", "text.primary")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", r.level, "LEFT", -8, 0)
        local function flip()
            if r.item then m:Toggle(r.item.key, not m.selected[r.item.key]) end
        end
        r:SetScript("OnClick", flip)
        r.check:SetScript("OnClick", flip)
        r:SetScript("OnEnter", function(self)
            W.Color(self.hl, "bg.hover", 0.6)
            if self.item then showItemTip(self, self.item.link) end
        end)
        r:SetScript("OnLeave", function(self) W.Color(self.hl, "bg.hover", 0); GameTooltip:Hide() end)
        p.rows[i] = r
    end
    p.empty = W.Text(p, "desc", "text.muted")
    p.empty:SetPoint("TOPLEFT", listLeft, -36)
    p.empty:SetPoint("RIGHT")
    p.empty:SetWordWrap(true)
    p.more = W.Text(p, "small", "text.muted", "RIGHT")
    p.more:SetPoint("TOPRIGHT", p.rows[LIST_ROWS], "BOTTOMRIGHT", -8, -4)
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, math.min(self.offset - delta * 3, math.max(0, #(self.items or {}) - LIST_ROWS)))
        self:Paint()
    end)

    local function paintDoll(self, equipped, counts)
        for _, b in ipairs(self.doll) do
            local it = equipped[b.slot]
            b.item = it
            local g = m.SLOT_GROUP[b.slot]
            b.icon:SetTexture(it and it.icon or EMPTY_SLOT[b.slot])
            b.icon:SetDesaturated(not it)
            b.level:SetText(it and it.level > 0 and it.level or "")
            local n = counts[g] or 0
            if g == "main_hand" or g == "off_hand" then n = n + (counts.weapon or 0) end
            b.count:SetText(n > 0 and n or "")
            b.badge:SetShown(n > 0)
            W.Color(b.badge, "accent.primary")
            Skin:Border(b, self.filter and m.Fits(self.filter, g) and "accent.primary" or "border.subtle")
        end
    end

    local function paintRow(r, it, index)
        r.item = it
        r:SetShown(it ~= nil)
        if not it then return end
        r.check:SetChecked(m.selected[it.key] and true or false)
        r.icon:SetTexture(it.icon)
        r.name:SetText(it.name)
        r.name:SetTextColor(qualityColor(it.quality))
        r.level:SetText(it.level > 0 and it.level or "")
        r.slot:SetText(slotLabel(it.slot))
        local res = index[it.key]
        r.sim:SetText(res and C.Signed(res.pct, "%.1f%%") or "")
        if res then r.sim:SetTextColor(Theme:Color(res.pct >= 0 and "state.success" or "state.danger")) end
    end

    function p:Paint()
        local bag = m:BagItems()
        local counts = {}
        for _, it in ipairs(bag) do
            if m.selected[it.key] then counts[it.slot] = (counts[it.slot] or 0) + 1 end
        end
        paintDoll(self, m:Equipped(), counts)
        local list = {}
        for _, it in ipairs(bag) do
            if not self.filter or m.Fits(it.slot, self.filter) or m.Fits(self.filter, it.slot) then list[#list + 1] = it end
        end
        self.items = list
        self.offset = math.min(self.offset, math.max(0, #list - LIST_ROWS))
        local index = m:Index()
        for i, r in ipairs(self.rows) do paintRow(r, list[self.offset + i], index) end
        local selected = #m:SelectedItems(bag)
        self.title:SetText(L.SIM_PICK_TITLE:format(self.filter and slotLabel(self.filter) or L.SIM_ALL_SLOTS,
            #list, selected))
        self.empty:SetText(#list == 0 and (self.filter and L.SIM_PICK_NONE_SLOT or L.SIM_PICK_NONE) or "")
        self.more:SetText(#list > LIST_ROWS and L.SIM_PICK_SCROLL:format(self.offset + 1,
            math.min(#list, self.offset + LIST_ROWS), #list) or "")
        self.all:SetShown(self.filter ~= nil)
    end

    Skin:Register(p, function(self)
        Skin:Text(self.title, "heading", "text.secondary")
        for _, r in ipairs(self.rows) do
            W.Color(r.hl, "bg.hover", 0)
            Skin:Text(r.slot, "small", "text.muted"); Skin:Text(r.level, "number", "text.primary")
        end
        if self:IsVisible() then self:Paint() end
    end)
    ns.Events:Listen("PUI_SIM_CHANGED", p, function() if p:IsVisible() then p:Paint() end end)
    p:SetScript("OnShow", p.Paint)
    p:Paint()
    return p
end

---------------------------------------------------------------- footer: mode, prepare, reload
local function modes()
    local out = {}
    for _, mode in ipairs(Sim().MODES) do out[#out + 1] = { value = mode, label = C.ModeLabel(mode) } end
    return out
end

local function buildFooter(row)
    local m = Sim()
    local f = CreateFrame("Frame", nil, row)
    f.mode = W:Segmented(f, modes())
    f.mode:SetPoint("TOPLEFT", 0, 0)
    f.mode.onChange = function(_, v) ns.DB:Set(m, "mode", v) end
    f.prepare = W:Button(f, L.SIM_PREPARE, "primary", "sim")
    f.prepare:SetPoint("TOPRIGHT", 0, 0)
    f.prepare.onClick = function()
        local id, err = m:Prepare()
        if id then
            Config:SetStatus(L.SIM_PREPARED, "state.success", "sim")
        else
            Config:SetStatus(L[err] or err, "state.danger", "warning")
        end
    end
    f.reload = W:Button(f, L.SIM_RELOAD, "primary", "reload")
    f.reload:SetPoint("TOPRIGHT", 0, 0)
    f.reload.onClick = function() if not InCombatLockdown() then ReloadUI() end end
    f.cancel = W:Button(f, L.SIM_CANCEL, "ghost", "close")
    f.cancel:SetPoint("RIGHT", f.prepare, "LEFT", -8, 0)
    f.cancel.onClick = function() m:Cancel() end
    f.dot = W:Dot(f, 8)
    f.dot:SetPoint("TOPLEFT", f.mode, "BOTTOMLEFT", 0, -16)
    f.status = W.Text(f, "desc", "text.secondary")
    f.status:SetPoint("TOPLEFT", f.mode, "BOTTOMLEFT", 14, -12)
    f.status:SetPoint("RIGHT")
    f.status:SetWordWrap(true)
    f.hint = W.Text(f, "small", "text.muted")
    f.hint:SetPoint("TOPLEFT", f.status, "BOTTOMLEFT", 0, -6)
    f.hint:SetPoint("RIGHT")
    f.hint:SetWordWrap(true)

    local STATE_TOKEN = { ready = "state.warning", sent = "state.info", waiting = "state.warning", idle = "text.muted" }
    function f:Paint()
        self.mode:SetValue(m.db.mode)
        local state, text = m:Status()
        self.status:SetText(text)
        W.Color(self.dot, STATE_TOKEN[state])
        local ready = state == "ready"
        self.reload:SetShown(ready)
        self.prepare:SetShown(not ready)
        self.cancel:SetShown(state ~= "idle")
        self.cancel:ClearAllPoints()
        self.cancel:SetPoint("RIGHT", ready and self.reload or self.prepare, "LEFT", -8, 0)
        local items = m:SelectedItems()
        local sets = m:SetCount(m.db.mode, items, m:Equipped())
        local hint = L["SIM_HINT_" .. m.db.mode:upper()]
        if m.db.mode == "compare" or m.db.mode == "best" then
            hint = hint .. "  " .. L.SIM_SETS:format(sets)
            if m.db.mode == "best" and sets > m.MAX_COMBOS then hint = hint .. "  " .. L.SIM_ERR_COMBOS end
        end
        self.hint:SetText(hint)
        W.SetEnabledState(self.prepare, not InCombatLockdown())
    end
    Skin:Register(f, function(self) if self:IsVisible() then self:Paint() end end)
    ns.Events:Listen("PUI_SIM_CHANGED", f, function() if f:IsVisible() then f:Paint() end end)
    ns.Events:Listen("PUI_SETTING_CHANGED", f, function(_, _, key) if key == "Sim" and f:IsVisible() then f:Paint() end end)
    f:SetScript("OnShow", f.Paint)
    f:Paint()
    return f
end

---------------------------------------------------------------- history
local HISTORY_ROWS = 10

local function buildHistory(row)
    local m = Sim()
    local h = CreateFrame("Frame", nil, row)
    h.rows = {}
    for i = 1, HISTORY_ROWS do
        local r = CreateFrame("Button", nil, h)
        r:SetHeight(24)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
        r:SetPoint("RIGHT")
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.hl = W.Texture(r, "BACKGROUND")
        r.hl:SetAllPoints()
        r.when = W.Text(r, "number", "text.secondary")
        r.when:SetPoint("LEFT", 8, 0)
        r.when:SetWidth(96)
        r.mode = W.Text(r, "body", "text.primary")
        r.mode:SetPoint("LEFT", r.when, "RIGHT", 8, 0)
        r.mode:SetWidth(150)
        r.best = W.Text(r, "number", "text.primary", "RIGHT")
        r.best:SetPoint("RIGHT", -8, 0)
        r.best:SetWidth(90)
        r.dps = W.Text(r, "number", "text.primary", "RIGHT")
        r.dps:SetPoint("RIGHT", r.best, "LEFT", -8, 0)
        r.dps:SetWidth(90)
        r.fight = W.Text(r, "desc", "text.muted")
        r.fight:SetPoint("LEFT", r.mode, "RIGHT", 8, 0)
        r.fight:SetPoint("RIGHT", r.dps, "LEFT", -8, 0)
        r:SetScript("OnClick", function(self, button)
            if not self.result then return end
            if button == "RightButton" then m:Delete(self.result.id) return end
            m.test = nil
            m.shown = self.result.id
            ns.Events:Fire("PUI_SIM_CHANGED")
        end)
        r:SetScript("OnEnter", function(self)
            W.Color(self.hl, "bg.hover", 0.6)
            W.ShowTooltip(self, L.SIM_HISTORY_TIP_TITLE, L.SIM_HISTORY_TIP)
        end)
        r:SetScript("OnLeave", function(self) h:PaintRow(self); W.HideTooltip() end)
        h.rows[i] = r
    end
    h.empty = W.Text(h, "desc", "text.muted")
    h.empty:SetPoint("TOPLEFT", 8, -4)
    h.empty:SetText(L.SIM_HISTORY_EMPTY)

    function h:PaintRow(r)
        local on = r.result and (m.shown == r.result.id or (not m.shown and r.index == 1))
        W.Color(r.hl, on and "accent.primary" or "bg.hover", on and 0.14 or 0)
    end
    function h:Paint()
        local list = m:History()
        for i, r in ipairs(self.rows) do
            local res = list[i]
            r.result, r.index = res, i
            r:SetShown(res ~= nil)
            if res then
                r.when:SetText(date("%d %b %H:%M", res.finished))
                r.mode:SetText(C.ModeLabel(res.mode))
                r.fight:SetText(C.FightText(res.fight))
                if res.state == "done" then
                    r.dps:SetText(C.Big(res.dps))
                    local best = res.sets[1]
                    if best then
                        r.best:SetText(("%s%.1f%%"):format(best.pct >= 0 and "+" or "-", math.abs(best.pct)))
                        r.best:SetTextColor(Theme:Color(best.pct >= 0 and "state.success" or "state.danger"))
                    else
                        r.best:SetText("")
                    end
                else
                    r.dps:SetText("")
                    r.best:SetText(res.state == "declined" and L.SIM_DECLINED or L.SIM_FAILED)
                    r.best:SetTextColor(Theme:Color("state.danger"))
                end
                self:PaintRow(r)
            end
        end
        self.empty:SetShown(#list == 0)
    end
    Skin:Register(h, function(self) if self:IsVisible() then self:Paint() end end)
    ns.Events:Listen("PUI_SIM_CHANGED", h, function() if h:IsVisible() then h:Paint() end end)
    h:SetScript("OnShow", h.Paint)
    h:Paint()
    return h
end

---------------------------------------------------------------- mirror rows (the settings live in Tooltip and Bags)
local function mirror(moduleKey, key, label, desc)
    local target
    for _, item in ipairs(ns.options[moduleKey] or {}) do if item.key == key then target = item end end
    local owner = ns.modules[moduleKey]
    return { type = "toggle", label = label, desc = desc, default = true,
        get = function() return owner.db[key] end, set = function(_, v) ns.DB:Set(owner, key, v) end,
        disabled = function() return not owner:IsEnabled() end, link = { key = moduleKey, item = target } }
end

local function styles()
    local out = {}
    for _, s in ipairs(Sim().STYLES) do out[#out + 1] = { value = s, label = C.StyleLabel(s) } end
    return out
end

ns:RegisterOptions("Sim", {
    { type = "preview", kind = "sim" },
    { type = "header", label = "SIM_START", icon = "sim", wide = true },
    { type = "description", text = "SIM_INTRO" },
    { type = "custom", label = "SIM_PICK", fullWidth = true, height = 340, get = function() return true end,
      build = function(row) return buildPicker(row) end },
    { type = "custom", label = "SIM_RUN", fullWidth = true, height = 128, get = function() return true end,
      build = function(row) return buildFooter(row) end },

    { type = "header", label = "SIM_FIGHT", icon = "encounters" },
    { type = "select", key = "fight.style", label = "SIM_FIGHT_STYLE", desc = "SIM_FIGHT_STYLE_DESC", values = styles,
      keywords = "patchwerk dungeon slice movement cleave simc fight style" },
    { type = "range", key = "fight.targets", label = "SIM_TARGETS", min = 1, max = 10, step = 1 },
    { type = "range", key = "fight.length", label = "SIM_LENGTH", desc = "SIM_LENGTH_DESC", min = 60, max = 600, step = 30 },
    { type = "button", label = "SIM_TEST", desc = "SIM_TEST_DESC", button = "SIM_TEST_BUTTON", icon = "test",
      func = function(m)
          m.test = not m.test
          ns.Events:Fire("PUI_SIM_CHANGED")
          Config:SetStatus(m.test and L.SIM_TEST_ON or L.SIM_TEST_OFF, "state.info", "test")
      end },

    { type = "header", label = "SIM_HISTORY", icon = "clock" },
    { type = "custom", label = "SIM_HISTORY_LIST", fullWidth = true, height = 10 * 24 + 40, get = function() return true end,
      build = function(row) return buildHistory(row) end },

    { type = "header", label = "SIM_SHOW", icon = "tooltip" },
    { type = "range", key = "maxAge", label = "SIM_MAX_AGE", desc = "SIM_MAX_AGE_DESC", min = 1, max = 14, step = 1 },
    mirror("Tooltip", "simLine", "TOOLTIP_SIM", "TOOLTIP_SIM_DESC"),
    mirror("Bags", "simArrow", "BAGS_SIM_ARROW", "BAGS_SIM_ARROW_DESC"),

    { type = "header", label = "SIM_APP", icon = "upload" },
    { type = "description", text = "SIM_APP_TEXT" },
})
