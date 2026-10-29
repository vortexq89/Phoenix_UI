local _, ns = ...
local W, Skin = ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ Shared shell for the Phoenix replacement windows (mail has its own older copy of the same idea): a Phoenix
    window that stands in for a Blizzard window while that window is open. The Blizzard window keeps its open
    state (Escape, its events, bag right-clicks and "is it open" checks behave as usual); Skin:Tuck only makes
    it see-through and parks its children on a hidden holder. Each replacement has its own Skins switch (off:
    the reskinned Blizzard window, live) and an arrow button for Blizzard's window for the rest of this visit.
    opts: key (db switch), frame (global name), title, width, height, build(r) (fills r.body), layout(r),
    close() (how our close button closes the Blizzard window), ready() (optional: false = show Blizzard's). ]]

local PAD, HEAD = 10, 34

function M.Replacement(opts)
    local r = { opts = opts, visit = false }

    function r.On() return M:IsEnabled() and M.db[opts.key] and true or false end
    function r.Blizzard() return _G[opts.frame] end
    function r.Open() local f = r.Blizzard(); return f and f:IsShown() and true or false end

    local function build()
        local win = CreateFrame("Frame", "PhoenixUI_" .. opts.frame, UIParent)
        win:SetSize(opts.width, opts.height)
        win:SetFrameStrata("MEDIUM")
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
        if movers then movers:Register(opts.key, win, opts.title) end
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
            if not Skin:Tuck(r.Blizzard()) then want = false end
        end
        if not want then
            if r.win then r.win:Hide() end
            if r.Blizzard() then Skin:Untuck(r.Blizzard()) end
            return
        end
        r.win:Show()
        r:Layout()
    end

    -- Call when the Blizzard window opens (resets the this-visit arrow) and closes.
    function r:Opened() r.visit = false; C_Timer.After(0, function() r:Sync() end) end
    function r:Closed() r.visit = false; r:Sync() end
    return r
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

-- A row of Phoenix buttons acting as tabs: defs = { { key, label } }; returns t with t.Paint(current).
function M.ReplaceTabs(parent, defs, width, onPick)
    local t, prev = { buttons = {} }, nil
    for _, d in ipairs(defs) do
        local b = W:Button(parent, d.label, "secondary", nil, width)
        b:SetHeight(22)
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
