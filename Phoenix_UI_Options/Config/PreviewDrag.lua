local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin

--[[ ns.PreviewDrag — size and place a module by dragging its live preview.

    Every preview stage gets two grips in its bottom-right corner: "resize" (drag to change the element's width and
    height, or its size / scale when it has no width) and "move" (drag to change its X / Y offset). Parts a preview
    marks with P.Hot also get edge grips of their own: the right edge drives width, the bottom edge height, the
    corner both, and dragging the part's body moves it. Which settings a drag drives is read from the page's own
    range rows (the same rows below the preview), so nothing is mapped by hand per module and a new module gets it
    for free. Every change is written through Config.SetRowValue, the path the sliders take, so it applies live,
    honours multi-select and scope (@), is clamped to the row's min / max and snapped to its step.

    No OnUpdate: while a button is held a C_Timer ticker samples the cursor and stops itself on release. ]]
local D = {}
ns.PreviewDrag = D

D.TICK = 0.03
D.LEAF = {
    w = { width = 1, length = 2, barWidth = 3, w = 4 },
    h = { height = 1, barHeight = 2, h = 3 },
    s = { size = 1, iconSize = 2, buttonSize = 3, scale = 9 },
    x = { x = 1, offsetX = 2, xOffset = 3 },
    y = { y = 1, offsetY = 2, yOffset = 3 },
}

-- binSize, worldMapScale, windowScale …: a size / scale row under another name, ranked after the exact names
function D.Suffix(axis, leaf)
    if axis ~= "s" or leaf:match("^border") or leaf:match("^font") or leaf:match("^shadow") or leaf:match("^text") then return nil end
    if leaf:match("%lSize$") or leaf:match("%lScale$") then return 20 end
end

local function split(key)
    local prefix, leaf = key:match("^(.*%.)([^.]+)$")
    return prefix or "", leaf or key
end

-- The rows a drag can drive: { w, h, s, x, y } (each a row item or nil), all sharing one element prefix.
-- `prefix` (from a P.Hot part) narrows the search to that element; otherwise the element of the first width /
-- size row on the page wins, so a corner drag never mixes one bar's width with another's height.
function D.Pick(page, m, prefix)
    if not (page and page.rows) then return nil end
    local unit = page.scope and page.scope.unit
    local sets, order = {}, {}
    for _, row in ipairs(page.rows) do
        local it = row.item
        if it and it.type == "range" and type(it.key) == "string" and not it.get
            and not (it.hidden and it.hidden(m, unit)) and not (it.disabled and it.disabled(m, unit)) then
            local p, leaf = split(it.key)
            if not prefix or p == prefix then
                for axis, leaves in pairs(D.LEAF) do
                    local rank = leaves[leaf] or D.Suffix(axis, leaf)
                    if rank then
                        local set = sets[p]
                        if not set then set = { rank = {} }; sets[p] = set; order[#order + 1] = p end
                        if not set[axis] or rank < set.rank[axis] then set[axis], set.rank[axis] = it, rank end
                    end
                end
            end
        end
    end
    for _, p in ipairs(order) do
        local set = sets[p]
        if set.w or set.h or set.s or prefix then
            return { w = set.w, h = set.h, s = set.s, x = set.x, y = set.y, prefix = p }
        end
    end
    return nil
end

local function snap(it, v)
    local step = it.step or 1
    if step > 0 then v = math.floor(v / step + 0.5) * step end
    if it.min then v = math.max(it.min, v) end
    if it.max then v = math.min(it.max, v) end
    if step >= 1 then v = math.floor(v + 0.5) end
    return v
end
D.Snap = snap

-- New values for a drag of (dx, dy) stage units from the start values. mode: "size" | "w" | "h" | "move".
-- Screen Y grows upward, so dragging down (dy < 0) makes the element taller and moves it down.
function D.Step(pick, start, mode, dx, dy)
    local out = {}
    if mode == "move" then
        if pick.x then out.x = snap(pick.x, start.x + dx) end
        if pick.y then out.y = snap(pick.y, start.y + dy) end
        return out
    end
    if (mode == "size" or mode == "w") and pick.w then out.w = snap(pick.w, start.w + dx) end
    if (mode == "size" or mode == "h") and pick.h then out.h = snap(pick.h, start.h - dy) end
    if mode == "size" and pick.s and not pick.w and not pick.h then
        local grow = (dx - dy) / 2
        local _, leaf = split(pick.s.key)
        if leaf == "scale" or leaf:match("Scale$") then
            out.s = snap(pick.s, start.s * (1 + grow / 200))
        else
            out.s = snap(pick.s, start.s + grow)
        end
    end
    return out
end

local function cursor(frame)
    local x, y = GetCursorPosition()
    local s = frame:GetEffectiveScale()
    if not s or s <= 0 then s = 1 end
    return (x or 0) / s, (y or 0) / s
end

local active
function D:Stop()
    if not active then return end
    if active.ticker then active.ticker:Cancel() end
    local a = active
    active = nil
    if a.done then a.done() end
end

-- Begins a drag on `frame` (the grip) for `page`; `prefix` narrows it to one element. Returns the drag or nil.
function D:Begin(page, m, frame, mode, prefix)
    self:Stop()
    local pick = self.Pick(page, m, prefix)
    if not pick then return nil end
    if mode == "move" and not (pick.x or pick.y) then return nil end
    if mode ~= "move" and not (pick.w or pick.h or pick.s) then return nil end
    local get, set = ns.Config.GetRowValue, ns.Config.SetRowValue
    local start = {}
    for _, axis in ipairs({ "w", "h", "s", "x", "y" }) do
        if pick[axis] then start[axis] = tonumber(get(page, m, pick[axis])) or pick[axis].min or 0 end
    end
    local cx, cy = cursor(frame)
    local last = {}
    local drag = { page = page, m = m, pick = pick, mode = mode, start = start }
    function drag.Move(nx, ny)
        local vals = D.Step(pick, start, mode, nx - cx, ny - cy)
        for axis, v in pairs(vals) do
            if v ~= (last[axis] or start[axis]) then
                last[axis] = v
                set(page, m, pick[axis], v)
            end
        end
        drag.moved = drag.moved or next(vals) ~= nil and (nx ~= cx or ny ~= cy)
        return vals
    end
    drag.ticker = C_Timer.NewTicker(self.TICK, function()
        if not IsMouseButtonDown("LeftButton") then D:Stop(); return end
        drag.Move(cursor(frame))
    end)
    active = drag
    return drag
end
function D:Active() return active end

---------------------------------------------------------------- grips
local function grip(parent, icon, title, desc, size)
    local b = CreateFrame("Button", nil, parent)
    b.puiGrip = true -- not sample content: the stage's fit-to-content measure skips it
    b:SetSize(size or 18, size or 18)
    b:EnableMouse(true)
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetPoint("CENTER")
    ns.Icons:Apply(b.icon, icon, 12)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    Skin:Register(b, function(self)
        W.Color(self.bg, "bg.raised", 0.85)
        W.Color(self.icon, "accent.text", 1)
    end)
    b:SetScript("OnEnter", function(self) W.ShowTooltip(self, title, desc) end)
    b:SetScript("OnLeave", function() W.HideTooltip() end)
    return b
end

local function wire(b, page, m, mode, prefix)
    b:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.drag = D:Begin(page, m, self, mode, prefix and prefix(self))
    end)
    b:SetScript("OnMouseUp", function(self)
        if self.drag and active == self.drag then D:Stop() end
        self.drag = nil
    end)
end

-- The two stage grips; shown only while the page has rows they can drive.
function D:Attach(stage, page, m)
    if stage.puiGrips then return stage.puiGrips end
    local size = grip(stage, "resize", ns.L.PREVIEW_DRAG_SIZE, ns.L.PREVIEW_DRAG_SIZE_DESC)
    size:SetPoint("BOTTOMRIGHT", -4, 4)
    size:SetFrameLevel(stage:GetFrameLevel() + 40)
    local move = grip(stage, "movers", ns.L.PREVIEW_DRAG_MOVE, ns.L.PREVIEW_DRAG_MOVE_DESC)
    move:SetPoint("RIGHT", size, "LEFT", -4, 0)
    move:SetFrameLevel(stage:GetFrameLevel() + 40)
    wire(size, page, m, "size")
    wire(move, page, m, "move")
    stage.puiGrips = { size = size, move = move }
    function stage.puiGrips:Sync()
        local pick = D.Pick(page, m)
        self.size:SetShown(pick and (pick.w or pick.h or pick.s) and true or false)
        self.move:SetShown(pick and (pick.x or pick.y) and true or false)
    end
    stage.puiGrips:Sync()
    ns.Events:Listen("PUI_SETTING_CHANGED", stage.puiGrips, function(_, _, key)
        if key == m.key and stage:IsVisible() then stage.puiGrips:Sync() end
    end)
    return stage.puiGrips
end

-- Edge grips and a draggable body on one P.Hot part (hot.key like "bars.@.width" names the element).
function D:AttachHot(hot, page, m)
    if hot.puiEdges then return end
    local function prefix(b) return split((b.hot or hot).key or "") end
    local function edge(mode, a1, a2, w, h)
        local e = CreateFrame("Button", nil, hot)
        e:SetFrameLevel(hot:GetFrameLevel() + 2)
        e:SetPoint(a1); e:SetPoint(a2)
        if w then e:SetWidth(w) end
        if h then e:SetHeight(h) end
        e.hot = hot
        wire(e, page, m, mode, prefix)
        return e
    end
    hot.puiEdges = {
        w = edge("w", "TOPRIGHT", "BOTTOMRIGHT", 6, nil),
        h = edge("h", "BOTTOMLEFT", "BOTTOMRIGHT", nil, 6),
    }
    local c = edge("size", "BOTTOMRIGHT", "BOTTOMRIGHT", 10, 10)
    hot.puiEdges.corner = c
    c:SetFrameLevel(hot:GetFrameLevel() + 3)
    -- the body: a press that turns into a drag moves the part; a press that does not stays a click
    hot:RegisterForDrag("LeftButton")
    hot:SetScript("OnDragStart", function(self) self.drag = D:Begin(page, m, self, "move", (split(self.key or ""))) end)
    hot:SetScript("OnDragStop", function(self)
        if self.drag and active == self.drag then D:Stop() end
        self.suppress = self.drag and self.drag.moved
        self.drag = nil
    end)
end

