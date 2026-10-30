local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ Shared shell for the Phoenix replacement windows (mail has its own older copy of the same idea): a Phoenix
    window that stands in for a Blizzard window while that window is open. The Blizzard window keeps its open
    state (Escape, its events, bag right-clicks and "is it open" checks behave as usual); Skin:Tuck only makes
    it see-through and parks its children on a hidden holder. Each replacement has its own Skins switch (off:
    the reskinned Blizzard window, live) and an arrow button for Blizzard's window for the rest of this visit.
    opts: key (db switch), frame (global name), title, width, height, build(r) (fills r.body), layout(r),
    close() (how our close button closes the Blizzard window), ready() (optional: false = show Blizzard's),
    isOpen() (optional: whether the visit is on, when the window's own shown state lags, e.g. a closing animation),
    place(win) (optional: anchors our window on every open), strata (optional), mover (optional
    Movers store, when the window keeps its own place), combat (optional: true = also stands in during
    combat; only for windows with no protected child, see Skin:Tuck). ]]

local PAD, HEAD = 10, 34

function M.Replacement(opts)
    local r = { opts = opts, visit = false }

    function r.On() return M:IsEnabled() and M.db[opts.key] and true or false end
    function r.Blizzard() return _G[opts.frame] end
    function r.Open()
        local f = r.Blizzard()
        if not (f and f:IsShown()) then return false end
        return not opts.isOpen or opts.isOpen(f) and true or false
    end

    local function build()
        local win = CreateFrame("Frame", "PhoenixUI_" .. opts.frame, UIParent)
        win:SetSize(opts.width, opts.height)
        win:SetFrameStrata(opts.strata or "MEDIUM")
        win:SetToplevel(true)
        win:SetClampedToScreen(true)
        win:EnableMouse(true)
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -110)
        win:Hide()
        win.title = W.Text(win, "heading", "accent.primary")
        win.title:SetPoint("TOPLEFT", PAD, -PAD - 2)
        win.title:SetText(opts.title)
        win.close = W:IconButton(win, "close", 22, CLOSE)
        win.close:SetPoint("TOPRIGHT", -PAD + 4, -PAD + 4)
        win.close.onClick = function() opts.close() end
        win.blizz = W:IconButton(win, "link", 22, ns.L.SKINS_OWN_BLIZZARD)
        win.blizz:SetPoint("RIGHT", win.close, "LEFT", -4, 0)
        win.blizz.onClick = function() r.visit = true; r:Sync() end
        win.body = CreateFrame("Frame", nil, win)
        win.body:SetPoint("TOPLEFT", PAD, -PAD - HEAD)
        win.body:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        r.win, r.body = win, win.body
        opts.build(r)
        win:SetScript("OnShow", function() r:Layout() end)
        Skin:Register(win, function(self)
            Skin:Panel(self, "base", { border = "border.strong" })
            r:Layout()
        end)
        local movers = ns:GetModule("Movers")
        if movers then movers:Register(opts.key, win, opts.title, opts.mover) end
    end

    function r:Layout()
        if self.win and self.win:IsShown() then opts.layout(self) end
    end

    local pending
    function r:Soon()
        if pending then return end
        pending = true
        C_Timer.After(0.05, function() pending = nil; r:Layout() end)
    end

    function r:Sync()
        local want = r.On() and not r.visit and r.Open() and (not opts.ready or opts.ready())
        if want then
            if not r.win then build() end
            if not Skin:Tuck(r.Blizzard(), opts.combat) then want = false end
        end
        if not want then
            if r.win then r.win:Hide() end
            if r.Blizzard() then Skin:Untuck(r.Blizzard(), opts.combat) end
            return
        end
        if opts.place and not r.win:IsShown() then opts.place(r.win) end
        r.win:Show()
        r:Layout()
    end

    -- Call when the Blizzard window opens (resets the this-visit arrow) and closes.
    function r:Opened() r.visit = false; C_Timer.After(0, function() r:Sync() end) end
    function r:Closed() r.visit = false; r:Sync() end
    return r
end

--[[ Where a replacement opens: on the Blizzard window's own spot (its Edit Mode or UI panel place, or under the
    mouse for loot) or, with the db[placeKey] choice "own", at a place of the player's (layout mode; db[posKey]).
    Returns place(win) for opts.place and a Movers store for opts.mover. getR() returns the replacement. ]]
function M.ReplacePlace(placeKey, posKey, frame, getR)
    local function place(win)
        local blizz, pos = _G[frame], M.db[posKey]
        win:ClearAllPoints()
        if M.db[placeKey] ~= "own" and blizz then
            win:SetScale(1)
            win:SetPoint("TOPLEFT", blizz, "TOPLEFT", 0, 0)
        elseif type(pos) == "table" and pos.point then
            win:SetScale(ns.Util.SafeScale(pos.scale or 1))
            win:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
        else
            win:SetScale(1)
            win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -120)
        end
    end
    local function again() local r = getR(); if r and r.win then place(r.win) end end
    local mover = {
        active = function() return M.db[placeKey] == "own" end,
        get = function() local p = M.db[posKey]; return type(p) == "table" and p.point and p or nil end,
        set = function(v) M.db[posKey] = { point = v.point, x = v.x, y = v.y, scale = v.scale } end,
        apply = again,
        reset = function() M.db[posKey] = {}; again() end,
    }
    return place, mover, again
end

-- Hooks the Blizzard window's own show / hide (for windows opened by toggles, not by an event).
function M.ReplacementHook(r)
    local f = r.Blizzard()
    if not f or r.hooked then return f ~= nil end
    r.hooked = true
    f:HookScript("OnShow", function() if r.onOpen then r.onOpen() end; r:Opened() end)
    f:HookScript("OnHide", function() r:Closed() end)
    ns.Events:On("PLAYER_REGEN_ENABLED", r, function() r:Sync() end)
    return true
end

-- A scrolling list of Phoenix rows (icon, title, sub line, right text, status bar, progress fill).
-- list.Set(items, paint, onClick): items any array; paint(row, item) fills the row; offset kept by wheel.
function M.ReplaceList(parent, rows, rowH, width, iconSize)
    local list = CreateFrame("Frame", nil, parent)
    list:SetSize(width, rows * rowH)
    list.rows, list.offset = {}, 0
    for i = 1, rows do
        local b = CreateFrame("Button", nil, list)
        b:SetSize(width, rowH - 2)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.bg = W.Texture(b, "BACKGROUND", 0); b.bg:SetAllPoints()
        b.fill = W.Texture(b, "BACKGROUND", 1); b.fill:SetPoint("TOPLEFT"); b.fill:SetPoint("BOTTOMLEFT"); b.fill:SetWidth(1)
        b.bar = W.Texture(b, "ARTWORK", 1); b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(3)
        local x = 10
        if iconSize then
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetSize(iconSize, iconSize)
            b.icon:SetPoint("LEFT", 8, 0)
            x = iconSize + 16
        end
        b.right = W.Text(b, "small", "text.secondary"); b.right:SetPoint("TOPRIGHT", -8, -5)
        b.title = W.Text(b, "body", "text.primary"); b.title:SetPoint("TOPLEFT", x, -5)
        b.title:SetPoint("RIGHT", b.right, "LEFT", -6, 0); b.title:SetJustifyH("LEFT")
        b.sub = W.Text(b, "small", "text.muted"); b.sub:SetPoint("BOTTOMLEFT", x, 5)
        b.sub:SetPoint("RIGHT", -8, 0); b.sub:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self, button) if list.onClick and self.item then list.onClick(self.item, button, self) end end)
        b:SetScript("OnEnter", function(self) if list.onEnter and self.item then list.onEnter(self.item, self) end end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        list.rows[i] = b
    end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, d)
        self.offset = self.offset - d * 2
        if self.items then self.Set(self.items, self.paint) end
    end)
    function list.Set(items, paint)
        list.items, list.paint = items, paint
        list.offset = math.max(0, math.min(list.offset, #items - rows))
        for i, b in ipairs(list.rows) do
            local item = items[list.offset + i]
            b.item = item
            if item then
                b.fill:SetWidth(1); b.fill:Hide(); b.bar:Hide()
                if b.icon then b.icon:SetDesaturated(false) end
                W.Color(b.bg, "bg.raised", 0.6)
                paint(b, item)
                b:Show()
            else
                b:Hide()
            end
        end
    end
    -- Selected / progress helpers for paint functions.
    function list.Mark(b, token, alpha) W.Color(b.bg, token, alpha) end
    function list.Bar(b, token) b.bar:Show(); W.Color(b.bar, token, 1) end
    function list.Progress(b, frac)
        frac = math.max(0, math.min(1, tonumber(frac) or 0))
        if frac <= 0 then return end
        b.fill:SetWidth(math.max(1, (b:GetWidth() or width) * frac))
        W.Color(b.fill, "accent.primary", 0.22)
        b.fill:Show()
    end
    return list
end

-- An item card for replacement windows: the thing's own icon in a frame of its quality colour, name (quality colour),
-- count on the icon, a small line under the name. M.PaintCard(c, d): d = { texture, name, count, quality, sub, dim }.
function M.ReplaceCard(parent, width, height)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(width, height)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local size = height - 8
    c.box = CreateFrame("Frame", nil, c)
    c.box:SetSize(size + 2, size + 2)
    c.box:SetPoint("LEFT", 3, 0)
    c.icon = c.box:CreateTexture(nil, "ARTWORK")
    c.icon:SetPoint("TOPLEFT", 1, -1)
    c.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    Skin:Icon(c.icon)
    Skin:Border(c.box, "border.subtle")
    c.count = c.box:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    c.count:SetPoint("BOTTOMRIGHT", -2, 2)
    c.name = W.Text(c, "body", "text.primary")
    c.name:SetPoint("TOPLEFT", c.box, "TOPRIGHT", 6, -2)
    c.name:SetPoint("RIGHT", -4, 0)
    c.sub = W.Text(c, "small", "text.muted")
    c.sub:SetPoint("BOTTOMLEFT", c.box, "BOTTOMRIGHT", 6, 2)
    c.sub:SetPoint("RIGHT", -4, 0)
    return c
end

function M.PaintCard(c, d, border)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- a quest icon atlas may have been on this card before
    c.icon:SetTexture(d.texture)
    c.icon:SetDesaturated(d.dim and true or false)
    c.count:SetText((tonumber(d.count) or 0) > 1 and BreakUpLargeNumbers(d.count) or "")
    c.name:SetText(d.name or "")
    c.sub:SetText(d.sub or "")
    local q = M.QualityBar and M.QualityBar(d.quality)
    if q then
        Skin:SetBorderColor(c.box, q.r, q.g, q.b, 1)
        c.name:SetTextColor(q.r, q.g, q.b, 1)
    else
        Skin:SetBorderColor(c.box, "border.subtle")
        Skin:Text(c.name, "body", "text.primary")
    end
    Skin:Panel(c, "raised", { border = border or "border.subtle" })
    c:Show()
end

-- The game's own quest icon (offer or in-progress look: daily, campaign, important, legendary, ready ...) on one of our
-- textures. The look comes from QuestUtil's getters; we apply it ourselves so our icon keeps its size (QuestUtil's
-- apply helpers resize the texture to the atlas). q: questID plus the gossip / greeting fields.
function M.QuestIcon(tex, active, q)
    local util = QuestUtil
    local get = util and (active and util.GetQuestIconActiveForQuestID or util.GetQuestIconOfferForQuestID)
    tex:SetTexCoord(0, 1, 0, 1)
    if not (get and q and q.questID) then tex:SetTexture(nil); return end
    local asset, isAtlas
    if active then
        asset, isAtlas = get(q.questID, q.isComplete, q.isLegendary, q.frequency, q.isRepeatable or q.repeatable, q.isImportant,
            q.isMeta, q.questInfoID)
    else
        asset, isAtlas = get(q.questID, q.isLegendary, q.frequency, q.isRepeatable or q.repeatable, q.isImportant, q.isMeta, q.questInfoID)
    end
    if isAtlas then tex:SetAtlas(asset) else tex:SetTexture(asset) end
end

-- A row of Phoenix buttons acting as tabs: defs = { { key, label } }; returns t with t.Paint(current).
function M.ReplaceTabs(parent, defs, width, onPick)
    local t, prev = { buttons = {} }, nil
    for _, d in ipairs(defs) do
        local b = W:Button(parent, d.label, "secondary", nil, width)
        b:SetHeight(22)
        -- never cut a label ("Reputati..." in the t146 character window; longer still in other locales)
        b:SetWidth(math.max(width or 0, math.ceil(b.label:GetStringWidth() + 20)))
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 0, 0) end
        b.onClick = function() onPick(d.key) end
        t.buttons[d.key], prev = b, b
    end
    function t.Paint(current)
        for key, b in pairs(t.buttons) do
            b.variant = key == current and "primary" or "secondary"
            local idle = b:GetScript("OnLeave")
            if idle then idle(b) end
        end
    end
    return t
end

--[[ A Phoenix panel standing in for one part of a Blizzard window that otherwise stays Blizzard's (a recipe list
    beside Blizzard's crafting page, the quest list inside the world map). The Blizzard part is tucked; our
    panel sits on its parent over the same rectangle, so the rest of the window lines up with it.
    opts: key (db switch), host() (the Blizzard part, or nil while its addon is not loaded), build(o) (fills
    o.panel), layout(o). Hooks the host's own show / hide; switch off or arrow: Blizzard's part, live. ]]
function M.Overlay(opts)
    local o = { opts = opts, visit = false }
    function o.On() return M:IsEnabled() and M.db[opts.key] and true or false end
    local function build(host)
        local p = CreateFrame("Frame", nil, host:GetParent())
        p:SetAllPoints(host)
        p:SetFrameLevel(host:GetFrameLevel() + 5)
        p:EnableMouse(true)
        p:Hide()
        p.blizz = W:IconButton(p, "link", 18, ns.L.SKINS_OWN_BLIZZARD)
        p.blizz:SetPoint("TOPRIGHT", -2, -2)
        p.blizz.onClick = function() o.visit = true; o:Sync() end
        o.panel = p
        opts.build(o)
        Skin:Register(p, function(self) Skin:Panel(self, "base", { border = "border.subtle" }); o:Layout() end)
    end
    function o:Layout() if self.panel and self.panel:IsShown() then opts.layout(self) end end
    local pending
    function o:Soon()
        if pending then return end
        pending = true
        C_Timer.After(0.05, function() pending = nil; o:Layout() end)
    end
    function o:Sync()
        local host = opts.host()
        local want = host and o.On() and not o.visit and host.IsVisible and host:IsVisible()
        if want then
            if not o.panel then build(host) end
            if not Skin:Tuck(host) then want = false end
        end
        if not want then
            if o.panel then o.panel:Hide() end
            if host then Skin:Untuck(host) end
            return
        end
        o.panel:Show()
        o:Layout()
    end
    function o:Hook()
        local host = opts.host()
        if not host or o.hooked then return host ~= nil end
        o.hooked = true
        host:HookScript("OnShow", function() o.visit = false; C_Timer.After(0, function() o:Sync() end) end)
        host:HookScript("OnHide", function() o.visit = false; o:Sync() end)
        ns.Events:On("PLAYER_REGEN_ENABLED", o, function() o:Sync() end)
        return true
    end
    return o
end
