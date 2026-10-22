local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin

local Opt = ns.Opt

-- Drag-to-reorder: one chip per segment (dimmed when the segment is off). Drag a chip and drop it where the
-- accent marker shows; the order is saved as a comma list and the bar and preview follow at once.
local CHIP_H, GAP = 26, 6
local LABEL = { fps = "DT_FPS", latency = "DT_LATENCY", speed = "DT_SPEED", durability = "DT_DURABILITY", gold = "DT_GOLD",
    clock = "DT_CLOCK", bugs = "DT_BUGS", bags = "DT_BAGS", itemlevel = "DT_ITEMLEVEL", friends = "DT_FRIENDS",
    guild = "DT_GUILD", mail = "DT_MAIL" }

local function orderRow(row, m)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetHeight(2 * CHIP_H + GAP)
    holder.chips = {}
    holder.marker = W.Texture(holder, "OVERLAY", 2, ns.Media.textures.WHITE)
    holder.marker:SetSize(2, CHIP_H)
    holder.marker:Hide()
    Skin:Register(holder.marker, function(t) W.Color(t, "accent.primary") end)

    local function chip(key)
        local c = holder.chips[key]
        if c then return c end
        c = CreateFrame("Button", nil, holder)
        c:SetHeight(CHIP_H)
        c.icon = W.Icon(c, m.ICON[key] or key, 13, "accent.primary")
        c.icon:SetPoint("LEFT", 8, 0)
        c.text = W.Text(c, "small", "text.primary", "LEFT")
        c.text:SetPoint("LEFT", c.icon, "RIGHT", 6, 0)
        c.text:SetText(L[LABEL[key]])
        c:SetWidth(c.text:GetUnboundedStringWidth() + 38)
        c:RegisterForDrag("LeftButton")
        c.key = key
        Skin:Register(c, function(self) Skin:Panel(self, "sunken", { border = "border.default" }) end)
        c:SetScript("OnEnter", function(self) W.ShowTooltip(self, L[LABEL[key]], L.DT_ORDER_TIP) end)
        c:SetScript("OnLeave", W.HideTooltip)
        c:SetScript("OnDragStart", function(self) holder:BeginDrag(self) end)
        c:SetScript("OnDragStop", function() holder:EndDrag() end)
        holder.chips[key] = c
        return c
    end

    -- Lays the chips out left to right, wrapping; returns the slot rectangles in order.
    function holder:Layout(order)
        local width = self:GetWidth()
        if not width or width <= 0 then width = W.CONTROL_WIDTH * 2 end
        local x, y = 0, 0
        self.slots = {}
        for i, key in ipairs(order) do
            local c = chip(key)
            if x > 0 and x + c:GetWidth() > width then x, y = 0, y - (CHIP_H + GAP) end
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", x, y)
            c:SetAlpha(m.db[key] and 1 or 0.45)
            c:Show()
            self.slots[i] = { key = key, x = x, y = y, w = c:GetWidth() }
            x = x + c:GetWidth() + GAP
        end
        self:SetHeight(-y + CHIP_H)
    end

    function holder:SetValue() self:Layout(m:Order()) end

    -- Index the dragged chip would take for the cursor position, from the slot rectangles.
    local function dropIndex()
        local cx, cy = GetCursorPosition()
        local scale = holder:GetEffectiveScale()
        local left, top = holder:GetLeft(), holder:GetTop()
        if not (left and top) then return nil end
        cx, cy = cx / scale - left, cy / scale - top
        local best, bestDist = #holder.slots + 1, math.huge
        for i, sl in ipairs(holder.slots) do
            local mid = sl.y - CHIP_H / 2
            if math.abs(cy - mid) <= CHIP_H then
                local d = math.abs(cx - sl.x)
                if d < bestDist then best, bestDist = i, d end
                local dEnd = math.abs(cx - (sl.x + sl.w))
                if dEnd < bestDist then best, bestDist = i + 1, dEnd end
            end
        end
        return best
    end

    function holder:BeginDrag(c)
        self.dragging = c
        c:SetAlpha(0.6)
        self:SetScript("OnUpdate", function()
            local i = dropIndex()
            local sl = i and (self.slots[i] or self.slots[#self.slots])
            if not sl then self.marker:Hide(); return end
            local x = self.slots[i] and sl.x - GAP / 2 - 1 or sl.x + sl.w + GAP / 2 - 1
            self.marker:ClearAllPoints()
            self.marker:SetPoint("TOPLEFT", x, sl.y)
            self.marker:Show()
        end)
    end

    function holder:EndDrag()
        local c = self.dragging
        self:SetScript("OnUpdate", nil)
        self.marker:Hide()
        self.dragging = nil
        if not c then return end
        local target = dropIndex()
        local order = m:Order()
        local from
        for i, key in ipairs(order) do if key == c.key then from = i end end
        if target and from and target ~= from and target ~= from + 1 then
            table.remove(order, from)
            if target > from then target = target - 1 end
            table.insert(order, target, c.key)
            ns.DB:Set(m, "order", table.concat(order, ","))
        end
        self:Layout(m:Order())
    end

    holder:SetScript("OnSizeChanged", function(self) self:Layout(m:Order()) end)
    ns.Events:Listen("PUI_SETTING_CHANGED", holder, function(_, _, key) if key == "DataTexts" then holder:Layout(m:Order()) end end)
    holder:Layout(m:Order())
    return holder
end

ns:RegisterOptions("DataTexts", {
    { type = "preview", kind = "datatexts" },
    { type = "header", label = "DT_SEGMENTS", icon = "datatexts" },
    { type = "toggle", key = "fps", label = "DT_FPS", keywords = "framerate" },
    { type = "toggle", key = "latency", label = "DT_LATENCY", keywords = "ping ms" },
    { type = "toggle", key = "speed", label = "DT_SPEED", keywords = "movement" },
    { type = "toggle", key = "durability", label = "DT_DURABILITY", keywords = "repair armor" },
    { type = "toggle", key = "gold", label = "DT_GOLD", keywords = "money" },
    { type = "toggle", key = "clock", label = "DT_CLOCK", keywords = "time" },
    { type = "toggle", key = "clock24", label = "DT_CLOCK24", disabled = function(m) return not m.db.clock end },
    { type = "toggle", key = "bugs", label = "DT_BUGS", desc = "DT_BUGS_DESC", keywords = "errors lua",
      disabled = function() local b = ns:GetModule("Bugs"); return not (b and b:IsEnabled()) end },
    { type = "toggle", key = "bags", label = "DT_BAGS", desc = "DT_BAGS_DESC", keywords = "free slots inventory space" },
    { type = "toggle", key = "itemlevel", label = "DT_ITEMLEVEL", desc = "DT_ITEMLEVEL_DESC", keywords = "ilvl gear average" },
    { type = "toggle", key = "friends", label = "DT_FRIENDS", desc = "DT_FRIENDS_DESC", keywords = "battle.net online" },
    { type = "toggle", key = "guild", label = "DT_GUILD", desc = "DT_GUILD_DESC", keywords = "members online" },
    { type = "toggle", key = "mail", label = "DT_MAIL", desc = "DT_MAIL_DESC", keywords = "mailbox letter" },
    { type = "custom", key = "order", label = "DT_ORDER", desc = "DT_ORDER_DESC", fullWidth = true, height = 112, resettable = true,
      keywords = "drag reorder arrange sort", build = orderRow },
    { type = "header", label = "DT_STYLE", icon = "theme" },
    { type = "toggle", key = "background", label = "DT_BACKGROUND", desc = "DT_BACKGROUND_DESC",
      cog = Opt.Flat(Opt.Background("backdrop", nil, "bg.base"), Opt.Border("border", nil, "border.subtle")) },
    { type = "range", key = "scale", label = "SCALE", min = 0.6, max = 2, step = 0.05, percent = true },
    { type = "range", key = "height", label = "DT_HEIGHT", min = 18, max = 40, step = 1 },
    { type = "range", key = "spacing", label = "DT_SPACING", min = 4, max = 40, step = 1 },
    { type = "select", key = "strata", label = "FRAME_STRATA", values = Opt.STRATA, keywords = "layer above below" },
    { type = "header", label = "DT_TEXT", icon = "fonts" },
    Opt.Text("value", "DT_VALUE_FONT", { max = 20 }),
    Opt.Text("unitText", "DT_UNIT_FONT", { max = 18, token = "text.muted" }),
    { type = "toggle", key = "colorValues", label = "DT_COLOR_VALUES", desc = "DT_COLOR_VALUES_DESC" },
    { type = "toggle", key = "icons", label = "DT_ICONS" },
    { type = "button", label = "DT_MOVE", desc = "DT_MOVE_DESC", button = "OPEN_EDIT_MODE", icon = "editmode",
      func = function() ns.Config.frame:Hide(); ns.EditMode:Open() end },
})
