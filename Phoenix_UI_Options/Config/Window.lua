local _, ns = ...
local L = ns.L
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media

--[[ The standalone Phoenix UI configuration window (ARCHITECTURE §9).
    Built lazily on first open. Pages: one per module key plus the built-in pages registered with
    Config:RegisterPage (home, fonts, textures, sounds, presets, profiles, diagnostics, about). The sidebar is
    grouped by Config.GROUPS (Groups.lua). ]]
local Config = ns.Config or {} -- the front door from Phoenix_UI/UI/Launcher.lua; its methods are replaced here
ns.Config = Config
Config.loaded = true
Config.pages, Config.builders, Config.navRows = {}, {}, {}

local HEADER_H, SIDEBAR_W, FOOTER_H = 56, 216, 40
local MIN_SCALE, MAX_SCALE = 0.7, 1.4
local MIN_W, MIN_H, MAX_W, MAX_H = 860, 540, 1600, 1100
local DEFAULT_W, DEFAULT_H = 1100, 720

-- info = { label = L key, icon = name, object = module-like page table, schema = table or function } names the
-- page in the sidebar and lets search index its rows.
Config.pageInfo = {}
function Config:RegisterPage(key, builder, info)
    self.builders[key] = builder
    if info then self.pageInfo[key] = info end
end

---------------------------------------------------------------- frame
local function uiStore() return ns.DB.sv.global.ui end

local function savePosition(f)
    local point, _, rel, x, y = f:GetPoint(1)
    local s = uiStore()
    s.point, s.rel, s.x, s.y = point, rel, x, y
    s.w, s.h = f:GetSize()
end

local function buildHeader(f)
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT"); h:SetPoint("TOPRIGHT"); h:SetHeight(HEADER_H)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() f:StartMoving() end)
    h:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
    f.header = h

    h.emblem = h:CreateTexture(nil, "ARTWORK")
    h.emblem:SetSize(34, 34)
    ns.Icons:Brand(h.emblem, "emblem", 34)
    h.emblem:SetPoint("LEFT", 18, 0)
    h.brand = W.Text(h, "brand", "text.primary")
    h.brand:SetPoint("LEFT", h.emblem, "RIGHT", 10, 1)
    h.brand:SetText("PHOENIX")
    h.brandUI = W.Text(h, "heading", "accent.primary")
    h.brandUI:SetPoint("LEFT", h.brand, "RIGHT", 6, -1)
    h.brandUI:SetText("UI")
    h.version = W:Badge(h, "v" .. ns.version, "accent.primary")
    h.version:SetPoint("LEFT", h.brandUI, "RIGHT", 10, 0)

    h.close = W:IconButton(h, "close", 30, L.CLOSE)
    h.close.danger = true
    h.close:SetPoint("RIGHT", -12, 0)
    h.close.onClick = function() f:Hide() end
    h.reload = W:IconButton(h, "reload", 30, L.RELOAD_UI, L.RELOAD_UI_DESC)
    h.reload:SetPoint("RIGHT", h.close, "LEFT", -4, 0)
    h.reload.onClick = function() C_UI.Reload() end
    h.editmode = W:IconButton(h, "editmode", 30, L.OPEN_EDIT_MODE, L.OPEN_EDIT_MODE_DESC)
    h.editmode:SetPoint("RIGHT", h.reload, "LEFT", -4, 0)
    h.editmode.onClick = function() f:Hide(); ns.EditMode:Open() end

    h.search = W:Input(h, 260, L.SEARCH_PLACEHOLDER)
    h.search:SetPoint("RIGHT", h.editmode, "LEFT", -14, 0)
    h.search:SetHeight(30)
    h.search:SetTextInsets(32, 10, 0, 0)
    h.search.placeholder:ClearAllPoints()
    h.search.placeholder:SetPoint("LEFT", 32, 0)
    h.searchIcon = W.Icon(h.search, "search", 14)
    h.searchIcon:SetPoint("LEFT", 11, 0)
    h.search.onTextChanged = function(_, text) Config:Search(text) end
    h.search:HookScript("OnEscapePressed", function(self) self:SetValue(""); Config:Search("") end)

    h.line = W.Texture(h, "ARTWORK", 2)
    h.line:SetPoint("BOTTOMLEFT"); h.line:SetPoint("BOTTOMRIGHT")
    h.line:SetHeight(2)
    h.glow = W.Texture(h, "ARTWORK", 1, Media.textures.FADE_V)
    h.glow:SetPoint("BOTTOMLEFT", 0, 2); h.glow:SetPoint("BOTTOMRIGHT", 0, 2)
    h.glow:SetHeight(18)
    h.glow:SetTexCoord(0, 1, 1, 0)

    Skin:Register(h, function(self)
        Skin:Panel(self, "raised", { border = false })
        Skin:Text(self.brand, "brand", "text.primary")
        Skin:Text(self.brandUI, "heading", "accent.primary")
        self.line:SetVertexColor(1, 1, 1, 1)
        local r2, g2, b2 = Theme:Color("accent.secondary")
        self.line:SetGradient("HORIZONTAL", Theme:ColorObj("accent.primary"), CreateColor(r2, g2, b2, 0))
        self.glow:SetVertexColor(1, 1, 1, 1)
        local r, g, b = Theme:Color("accent.primary")
        self.glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.10), CreateColor(r, g, b, 0))
        W.Color(self.searchIcon, "text.muted")
    end)
end

-- One sidebar row. kind: "entry" (a page, indented under its group), "group" (a collapsible heading) or
-- "single" (a group with one page: the heading itself opens it).
local function navRow(parent, key, label, icon, kind)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(32)
    r.key, r.kind = key, kind
    r.bg = W.Texture(r, "BACKGROUND")
    r.bg:SetPoint("TOPLEFT", 8, 0); r.bg:SetPoint("BOTTOMRIGHT", -8, 0)
    r.bar = W.Texture(r, "ARTWORK")
    r.bar:SetPoint("TOPLEFT", r.bg, "TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT", r.bg, "BOTTOMLEFT")
    r.bar:SetWidth(2)
    local entry = kind == "entry"
    r.icon = W.Icon(r, icon, entry and 14 or 16)
    r.icon:SetPoint("LEFT", entry and 40 or 20, 0)
    r.label = W.Text(r, entry and "body" or "heading", "text.secondary")
    r.label:SetPoint("LEFT", r.icon, "RIGHT", entry and 9 or 10, 0)
    r.label:SetPoint("RIGHT", -30, 0)
    r.label:SetText(entry and label or label:upper())
    r.label:SetWordWrap(false)
    r.dot = W:Dot(r, 6)
    r.dot:SetPoint("RIGHT", -20, 0)
    if kind == "group" then
        r.chevron = W.Icon(r, "chevron-right", 10)
        r.chevron:SetPoint("RIGHT", -20, 0)
        r.dot:Hide()
    end
    local font = entry and "body" or "heading"
    function r:Paint()
        local m = ns.modules[self.key]
        local lit = self.active or (self.kind == "group" and self.childActive and not self.expanded)
        if lit then
            W.Color(self.bg, "accent.soft")
            self.bar:SetVertexColor(1, 1, 1, 1)
            Skin:Gradient(self.bar, "VERTICAL", "accent.secondary", "accent.primary")
            self.bar:Show()
            W.Color(self.icon, "accent.primary")
            Skin:Text(self.label, font, "text.primary")
        else
            W.Color(self.bg, "bg.hover", self.hover and 0.9 or 0)
            self.bar:Hide()
            local on = self.hover or self.childActive
            W.Color(self.icon, (self.childActive and "accent.primary") or (on and "text.primary") or "text.muted")
            Skin:Text(self.label, font, on and "text.primary" or "text.secondary")
        end
        if self.chevron then
            ns.Icons:Apply(self.chevron, self.expanded and "chevron-down" or "chevron-right", 10)
            W.Color(self.chevron, self.hover and "text.primary" or "text.muted")
        elseif m and not m.locked then
            local token = (m.state == "errored" and "state.danger") or (m.needsReload and "state.warning")
                or (m:IsEnabled() and "state.success") or "text.muted"
            W.Color(self.dot, token, m:IsEnabled() and 1 or 0.5)
            self.dot:Show()
        else
            self.dot:Hide()
        end
    end
    r:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    r:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    r:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if self.kind == "group" then Config:ToggleGroup(self.group.key) else Config:Show(self.key) end
    end)
    Skin:Register(r, function(self) self:Paint() end)
    return r
end

local function buildSidebar(f)
    local sb = CreateFrame("Frame", nil, f)
    sb:SetPoint("TOPLEFT", 0, -HEADER_H)
    sb:SetPoint("BOTTOMLEFT", 0, FOOTER_H)
    sb:SetWidth(SIDEBAR_W)
    f.sidebar = sb
    sb.edge = W.Texture(sb, "BORDER")
    sb.edge:SetPoint("TOPRIGHT"); sb.edge:SetPoint("BOTTOMRIGHT")
    sb.edge:SetWidth(1)
    Skin:Register(sb, function(self)
        Skin:Panel(self, "base", { border = false })
        Skin:SetPanelColor(self, "bg.sunken")
        W.Color(self.edge, "border.subtle")
    end)

    local scroll = W:Scroll(sb)
    scroll:SetPoint("TOPLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", -8, 10)
    sb.scroll = scroll
    local c = scroll.child
    Config.groupRows = {}
    for _, g in ipairs(Config:Groups()) do
        local single = #g.entries == 1
        local head
        if single then
            local key = g.entries[1]
            local label = g.key == "home" and L.HOME or L[g.label]
            head = navRow(c, key, label, g.icon, "single")
            Config.navRows[key] = head
        else
            head = navRow(c, g.key, L[g.label], g.icon, "group")
            head.children = {}
            for _, key in ipairs(g.entries) do
                local label, icon = Config:EntryInfo(key)
                local row = navRow(c, key, label, icon, "entry")
                row.group = g
                Config.navRows[key] = row
                head.children[#head.children + 1] = row
            end
        end
        head.group = g
        Config.groupRows[#Config.groupRows + 1] = head
    end
    Config:LayoutSidebar()
end

local function groupStore()
    local s = uiStore()
    if type(s.groups) ~= "table" then s.groups = {} end
    return s.groups
end

-- Stacks the group headings and the entries of expanded groups.
function Config:LayoutSidebar()
    if not self.frame then return end
    local c = self.frame.sidebar.scroll.child
    local open = groupStore()
    local y = 0
    for i, head in ipairs(self.groupRows) do
        if i > 1 then y = y + 2 end
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
        head:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        y = y + 32
        if head.children then
            head.expanded = open[head.group.key] == true
            head.childActive = false
            for _, row in ipairs(head.children) do
                if row.key == self.current then head.childActive = true end
                row:SetShown(head.expanded)
                if head.expanded then
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
                    row:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
                    y = y + 30
                end
            end
            if head.expanded then y = y + 4 end
        end
        head:Paint()
    end
    c:SetHeight(y + 8)
    self.frame.sidebar.scroll:UpdateBar()
end

function Config:ToggleGroup(key, expand)
    local open = groupStore()
    if expand == nil then expand = not open[key] end
    open[key] = expand or nil
    self:LayoutSidebar()
end

-- Opens the group that holds key (used when a page is shown from search, a link or /pui).
function Config:RevealEntry(key)
    local g = self:GroupOf(key)
    if g and #g.entries > 1 then
        local open = groupStore()
        if not open[g.key] then open[g.key] = true end
    end
    self:LayoutSidebar()
end

local function buildFooter(f)
    local ft = CreateFrame("Frame", nil, f)
    ft:SetPoint("BOTTOMLEFT"); ft:SetPoint("BOTTOMRIGHT"); ft:SetHeight(FOOTER_H)
    ft.profileIcon = W.Icon(ft, "profiles", 12)
    ft.profileIcon:SetPoint("LEFT", 16, 0)
    ft.profile = W.Text(ft, "small", "text.secondary")
    ft.profile:SetPoint("LEFT", ft.profileIcon, "RIGHT", 6, 0)
    ft.statusIcon = W.Icon(ft, "preview", 12, "text.muted")
    ft.statusIcon:SetPoint("LEFT", SIDEBAR_W + 24, 0)
    ft.status = W.Text(ft, "small", "text.muted")
    ft.status:SetPoint("LEFT", ft.statusIcon, "RIGHT", 6, 0)
    ft.close = W:Button(ft, L.CLOSE, "secondary", "close")
    ft.close:SetHeight(26)
    ft.close:SetPoint("RIGHT", -26, 0)
    ft.close.onClick = function() f:Hide() end
    ft.reload = W:Button(ft, L.RELOAD_UI, "primary", "reload")
    ft.reload:SetHeight(26)
    ft.reload:SetPoint("RIGHT", ft.close, "LEFT", -8, 0)
    ft.reload.onClick = function() C_UI.Reload() end
    -- Window scale: applied when the drag ends, so the slider does not move away under the cursor.
    ft.scale = W:Slider(ft, MIN_SCALE, MAX_SCALE, 0.05, true)
    ft.scale:SetWidth(150)
    ft.scale:SetPoint("RIGHT", ft.reload, "LEFT", -18, 0)
    ft.scale:SetValue(uiStore().scale or 1)
    ft.scale.onChange = function(_, v)
        uiStore().scale = v
        if not IsMouseButtonDown("LeftButton") then f:SetScale(v) end
    end
    ft.scale.bar:HookScript("OnMouseUp", function() f:SetScale(uiStore().scale or 1) end)
    ft.scaleLabel = W.Text(ft, "small", "text.muted", "RIGHT")
    ft.scaleLabel:SetPoint("RIGHT", ft.scale, "LEFT", -8, 0)
    ft.scaleLabel:SetText(L.WINDOW_SCALE:upper())
    ft.status:SetPoint("RIGHT", ft.scaleLabel, "LEFT", -16, 0)
    f.footer = ft
    Skin:Register(ft, function(self)
        Skin:Panel(self, "sunken", { border = "border.subtle" })
        W.Color(self.profileIcon, "accent.primary")
        Skin:Text(self.profile, "small", "text.secondary")
        Skin:Text(self.status, "small", self.statusToken or "text.muted")
        W.Color(self.statusIcon, self.statusToken or "text.muted")
        Skin:Text(self.scaleLabel, "small", "text.muted")
    end)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip.tex = W.Icon(grip, "resize", 14, "text.muted", "OVERLAY")
    grip.tex:SetPoint("CENTER")
    Skin:Register(grip, function(self) W.Color(self.tex, "text.muted") end)
    grip:SetScript("OnEnter", function(self) W.Color(self.tex, "accent.primary") end)
    grip:SetScript("OnLeave", function(self) W.Color(self.tex, "text.muted") end)
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); savePosition(f) end)
end

local STATUS_ICON = {
    ["state.success"] = "success", ["state.warning"] = "warning", ["state.danger"] = "error", ["state.info"] = "about",
}

-- Footer status line; the leading glyph follows the token unless an explicit icon is given.
function Config:SetStatus(text, token, icon)
    if not self.frame then return end
    local ft = self.frame.footer
    ft.statusToken = token or "text.muted"
    ft.status:SetText(text or "")
    ft.status:SetTextColor(Theme:Color(ft.statusToken))
    ns.Icons:Apply(ft.statusIcon, icon or STATUS_ICON[ft.statusToken] or "preview", 12)
    W.Color(ft.statusIcon, ft.statusToken)
    ft.statusIcon:SetShown((text or "") ~= "")
end

function Config:UpdateFooter()
    if not self.frame then return end
    local n = 0
    for _, m in ipairs(ns.moduleList) do if m:IsEnabled() and not m.locked then n = n + 1 end end
    self.frame.footer.profile:SetText(L.PROFILE_LABEL:format(ns.DB:GetProfileName()) .. "   ·   " .. L.MODULES_ACTIVE:format(n))
    if InCombatLockdown() then self:SetStatus(L.STATUS_COMBAT, "state.warning", "lock") else self:SetStatus(L.STATUS_LIVE) end
end

function Config:Build()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "PhoenixUI_Config", UIParent) -- name required by UISpecialFrames (Esc to close)
    tinsert(UISpecialFrames, "PhoenixUI_Config")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    local s = uiStore()
    f:SetSize(s.w or DEFAULT_W, s.h or DEFAULT_H)
    f:SetPoint(s.point or "CENTER", UIParent, s.rel or "CENTER", s.x or 0, s.y or 0)
    f:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(s.scale) or 1)))
    Skin:Register(f, function(self) Skin:Panel(self, "base", { border = "border.strong", shadow = 18 }) end)
    self.frame = f

    buildHeader(f)
    buildSidebar(f)
    buildFooter(f)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", SIDEBAR_W, -HEADER_H)
    content:SetPoint("BOTTOMRIGHT", 0, FOOTER_H)
    content:SetClipsChildren(true)
    f.content = content
    f.ambient = W.Texture(content, "BACKGROUND", 1, Media.textures.FADE_V)
    f.ambient:SetPoint("TOPLEFT"); f.ambient:SetPoint("TOPRIGHT"); f.ambient:SetHeight(160)
    Skin:Register(f.ambient, function(t) W.Color(t, "accent.primary", 0.05) end)

    f:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        if self.InvalidateSearch then self:InvalidateSearch() end
        self:UpdateFooter()
        for _, row in pairs(self.navRows) do row:Paint() end
        if self.current and self.pages[self.current] and self.pages[self.current].Refresh then self.pages[self.current]:Refresh() end
    end)
    f:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        W.HideTooltip()
    end)
    f:SetScript("OnSizeChanged", function()
        local page = self.current and self.pages[self.current]
        if page and page.Layout then page:Layout() end
    end)

    ns.Events:Listen("PUI_MODULE_STATE", self, function(_, _, key)
        local row = self.navRows[key]
        if row then row:Paint() end
        local page = self.pages[key]
        if page and page.Refresh and f:IsShown() then page:Refresh() end
        self:UpdateFooter()
    end)
    ns.Events:Listen("PUI_PROFILE_CHANGED", self, function()
        if f:IsShown() then
            local page = self.pages[self.current]
            if page and page.Refresh then page:Refresh() end
            self:UpdateFooter()
        end
    end)
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function() self:UpdateFooter() end)
    ns.Events:Listen("PUI_COMBAT_END", self, function() self:UpdateFooter() end)
    return f
end

-- /pui reset: forget the saved size and position.
function Config:ResetPosition()
    wipe(uiStore())
    local f = self.frame
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint("CENTER")
    f:SetSize(DEFAULT_W, DEFAULT_H)
    f:SetScale(1)
    f.footer.scale:SetValue(1)
end

function Config:Show(key)
    local f = self:Build()
    key = key or self.current or "home"
    if not self:EntryExists(key) then key = "home" end
    if self.current and self.pages[self.current] then self.pages[self.current]:Hide() end
    local page = self.pages[key]
    if not page then
        page = (self.builders[key] or self.BuildModulePage)(f.content, key)
        page:SetAllPoints(f.content)
        self.pages[key] = page
    end
    local previous = self.current
    self.current = key
    for k, row in pairs(self.navRows) do
        row.active = (k == key)
        row:Paint()
    end
    self:RevealEntry(key)
    if page.Refresh then page:Refresh() end
    if page.Layout then page:Layout() end
    if self.results then self.results:Hide() end
    if not f:IsShown() then
        f:Show()
    end
    if previous ~= key then ns.Anim:FadeIn(page, 0.14) else page:Show() end
    return page
end

function Config:Toggle(key)
    local f = self:Build()
    if f:IsShown() and (not key or key == self.current) then f:Hide() else self:Show(key) end
end
