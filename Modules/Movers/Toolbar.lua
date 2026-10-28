local _, ns = ...
local L = ns.L
local W, Skin = ns.Widgets, ns.Skin
local M = ns:GetModule("Movers")

--[[ Unlock-mode toolbar: which frame is selected, cycle frames, nudge, scale, opacity, reset, grid/snap,
    done. A Phoenix-owned, draggable frame; built on first unlock. ]]
local WIDTH, HEIGHT = 820, 96

-- The options page that holds the selected frame's settings, from its mover key prefix.
local PAGES = { ab = "ActionBars", auras = "Auras", bags = "Bags", cb = "CastBars", cdm = "Tracker",
    gf = "GroupFrames", pvp = "PvP", quests = "Quests", tooltip = "Tooltip", uf = "UnitFrames" }
function M.SettingsPageOf(e)
    if not e or not e.key then return nil end
    return PAGES[e.key:match("^([%a]+)%.")]
end

local function cycle(dir)
    local list, cur = {}, M:GetSelected()
    for _, e in ipairs(M:GetEntries()) do if M.Usable(e) then list[#list + 1] = e end end
    if #list == 0 then return end
    local index = 1
    for i, e in ipairs(list) do if e == cur then index = i end end
    M:Select(list[(index - 1 + dir) % #list + 1])
end

function M:BuildToolbar()
    local t = CreateFrame("Frame", nil, UIParent)
    t:SetSize(WIDTH, HEIGHT)
    t:SetPoint("TOP", 0, -40)
    t:SetFrameStrata("FULLSCREEN_DIALOG")
    t:SetClampedToScreen(true)
    t:SetMovable(true)
    t:EnableMouse(true)
    t:RegisterForDrag("LeftButton")
    t:SetScript("OnDragStart", t.StartMoving)
    t:SetScript("OnDragStop", t.StopMovingOrSizing)
    t.accent = W.Texture(t, "ARTWORK", 2)
    t.accent:SetPoint("TOPLEFT"); t.accent:SetPoint("TOPRIGHT"); t.accent:SetHeight(2)

    t.icon = W.Icon(t, "movers", 16, "accent.primary")
    t.icon:SetPoint("TOPLEFT", 16, -16)
    t.title = W.Text(t, "heading", "text.secondary")
    t.title:SetPoint("LEFT", t.icon, "RIGHT", 8, 0)
    t.title:SetText(L.MOVERS:upper())
    t.prev = W:IconButton(t, "chevron-left", 24, L.MOVERS_PREV_FRAME)
    t.prev:SetPoint("LEFT", t.title, "RIGHT", 14, 0)
    t.prev.onClick = function() cycle(-1) end
    t.name = W.Text(t, "body", "accent.primary", "CENTER")
    t.name:SetPoint("LEFT", t.prev, "RIGHT", 4, 0)
    t.name:SetWidth(190)
    t.name:SetWordWrap(false)
    t.next = W:IconButton(t, "chevron-right", 24, L.MOVERS_NEXT_FRAME)
    t.next:SetPoint("LEFT", t.name, "RIGHT", 4, 0)
    t.next.onClick = function() cycle(1) end
    t.pos = W.Text(t, "number", "text.muted")
    t.pos:SetPoint("LEFT", t.next, "RIGHT", 10, 0)

    t.done = W:Button(t, L.MOVERS_DONE, "primary", "check", 96)
    t.done:SetPoint("TOPRIGHT", -12, -10)
    t.done.onClick = function() M:SetUnlocked(false) end
    t.snap = W:IconButton(t, "snap", 28, L.MOVERS_SNAP, L.MOVERS_SNAP_DESC)
    t.snap:SetPoint("RIGHT", t.done, "LEFT", -8, 0)
    t.snap.onClick = function() ns.DB:Set(M, "snap", not M.db.snap) end
    t.grid = W:IconButton(t, "grid", 28, L.MOVERS_GRID, L.MOVERS_GRID_DESC)
    t.grid:SetPoint("RIGHT", t.snap, "LEFT", -4, 0)
    t.grid.onClick = function() M:ShowGrid(not M.db.grid) end
    -- off: boxes only for frames on screen; on: also hidden ones (empty party frames, Blizzard message frames)
    t.hidden = W:IconButton(t, "preview", 28, L.MOVERS_SHOW_HIDDEN, L.MOVERS_SHOW_HIDDEN_DESC)
    t.hidden:SetPoint("RIGHT", t.grid, "LEFT", -4, 0)
    t.hidden.onClick = function()
        M.db.showHidden = not M.db.showHidden
        M:SetUnlocked(true)
    end

    -- second row: nudge, scale, opacity, reset
    local arrows = {}
    local dirs = { { "arrow-left", -1, 0, L.DIR_LEFT }, { "arrow-up", 0, 1, L.DIR_UP },
        { "arrow-down", 0, -1, L.DIR_DOWN }, { "arrow-right", 1, 0, L.DIR_RIGHT } }
    for i, d in ipairs(dirs) do
        local b = W:IconButton(t, d[1], 26, d[4], L.MOVERS_NUDGE_DESC)
        b:SetPoint("BOTTOMLEFT", 12 + (i - 1) * 28, 12)
        b.onClick = function()
            local e = M:GetSelected()
            local step = IsShiftKeyDown() and 10 or 1
            if e then M.Nudge(e, d[2] * step, d[3] * step) end
        end
        arrows[i] = b
    end
    t.arrows = arrows
    t.scaleIcon = W.Icon(t, "resize", 12, "text.secondary")
    t.scaleIcon:SetPoint("LEFT", arrows[4], "RIGHT", 16, 0)
    t.scale = W:Slider(t, 0.5, 2, 0.05, true)
    t.scale:SetWidth(170)
    t.scale:SetPoint("LEFT", t.scaleIcon, "RIGHT", 8, 0)
    t.scale.onChange = function(_, v) local e = M:GetSelected(); if e then M.SetFrameScale(e, v) end end
    t.alphaIcon = W.Icon(t, "opacity", 12, "text.secondary")
    t.alphaIcon:SetPoint("LEFT", t.scale, "RIGHT", 16, 0)
    t.alpha = W:Slider(t, 0.2, 1, 0.05, true)
    t.alpha:SetWidth(150)
    t.alpha:SetPoint("LEFT", t.alphaIcon, "RIGHT", 8, 0)
    t.alpha.onChange = function(_, v) local e = M:GetSelected(); if e then M.SetFrameAlpha(e, v) end end
    W.AttachTooltip(t.scale.bar, L.SCALE, L.MOVERS_OVERLAY_TIP)
    W.AttachTooltip(t.alpha.bar, L.MOVERS_OPACITY, L.MOVERS_OVERLAY_TIP)
    t.reset = W:Button(t, L.RESET, "secondary", "reset", 96)
    t.reset:SetPoint("BOTTOMRIGHT", -12, 12)
    t.reset.onClick = function() local e = M:GetSelected(); if e then M:ResetFrame(e.key) end end
    -- open the selected frame's own settings (size, layout, visibility) next to the movers
    t.settings = W:Button(t, L.MOVERS_SETTINGS, "secondary", "cog", 110)
    t.settings:SetPoint("RIGHT", t.reset, "LEFT", -8, 0)
    t.settings.onClick = function()
        local page = M.SettingsPageOf(M:GetSelected())
        if page and ns.Config and ns.Config.Show then ns.Config:Show(page) end
    end

    Skin:Register(t, function(self)
        Skin:Panel(self, "raised", { border = "border.strong", shadow = 14, sheen = 30 })
        self.accent:SetVertexColor(1, 1, 1, 1)
        Skin:Gradient(self.accent, "HORIZONTAL", "accent.primary", "accent.secondary")
        Skin:Text(self.title, "heading", "text.secondary")
        Skin:Text(self.name, "body", "accent.primary")
        Skin:Text(self.pos, "number", "text.muted")
    end)

    function t:Update()
        local e = M:GetSelected()
        local f = e and M.Usable(e)
        self.name:SetText(e and M:LabelOf(e) or "—")
        local s = e and M.db.frames[e.key]
        self.pos:SetText(s and s.point and ("%s %d, %d"):format(s.point, s.x, s.y) or L.MOVERS_DEFAULT_POS)
        self.grid.active, self.snap.active = M.db.grid, M.db.snap
        ns.Icons:SetState(self.grid.icon, M.db.grid and "active" or nil)
        ns.Icons:SetState(self.snap.icon, M.db.snap and "active" or nil)
        W.SetEnabledState(self.scale, f ~= nil and not e.noScale)
        W.SetEnabledState(self.alpha, f ~= nil and not e.noAlpha)
        W.SetEnabledState(self.reset, s ~= nil)
        if f then
            self.scale:SetValue((s and s.scale) or f:GetScale())
            self.alpha:SetValue((s and s.alpha) or f:GetAlpha())
        end
    end
    t:Hide()
    return t
end
