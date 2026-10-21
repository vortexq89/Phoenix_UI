local _, ns = ...
local L = ns.L
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media

--[[ The standalone Phoenix UI configuration window (ARCHITECTURE §9).
    Built lazily on first open. Pages: "home", "profiles", "about" and one per module key. ]]
local Config = {}
ns.Config = Config
Config.pages, Config.builders, Config.navRows = {}, {}, {}

local HEADER_H, SIDEBAR_W, FOOTER_H = 56, 216, 28
local MIN_W, MIN_H, MAX_W, MAX_H = 860, 540, 1600, 1100
local CATEGORY_LABEL = {
    system = "CAT_SYSTEM", interface = "CAT_INTERFACE", combat = "CAT_COMBAT", social = "CAT_SOCIAL", utility = "CAT_UTILITY",
}
local CATEGORY_ICON = {
    system = "cat-system", interface = "cat-interface", combat = "cat-combat", social = "cat-social", utility = "cat-utility",
}

function Config:RegisterPage(key, builder)
    self.builders[key] = builder
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

local function navRow(parent, key, label, icon)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(32)
    r.key = key
    r.bg = W.Texture(r, "BACKGROUND")
    r.bg:SetPoint("TOPLEFT", 8, 0); r.bg:SetPoint("BOTTOMRIGHT", -8, 0)
    r.bar = W.Texture(r, "ARTWORK")
    r.bar:SetPoint("TOPLEFT", r.bg, "TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT", r.bg, "BOTTOMLEFT")
    r.bar:SetWidth(2)
    r.icon = W.Icon(r, icon, 16)
    r.icon:SetPoint("LEFT", 22, 0)
    r.label = W.Text(r, "body", "text.secondary")
    r.label:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
    r.label:SetPoint("RIGHT", -30, 0)
    r.label:SetText(label)
    r.dot = W:Dot(r, 6)
    r.dot:SetPoint("RIGHT", -20, 0)
    function r:Paint()
        local m = ns.modules[self.key]
        if self.active then
            W.Color(self.bg, "accent.soft")
            self.bar:SetVertexColor(1, 1, 1, 1)
            Skin:Gradient(self.bar, "VERTICAL", "accent.secondary", "accent.primary")
            self.bar:Show()
            W.Color(self.icon, "accent.primary")
            Skin:Text(self.label, "body", "text.primary")
        else
            W.Color(self.bg, "bg.hover", self.hover and 0.9 or 0)
            self.bar:Hide()
            W.Color(self.icon, self.hover and "text.primary" or "text.muted")
            Skin:Text(self.label, "body", self.hover and "text.primary" or "text.secondary")
        end
        if m and not m.locked then
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
        Config:Show(self.key)
    end)
    Skin:Register(r, function(self) self:Paint() end)
    Config.navRows[key] = r
    return r
end

local function groupLabel(parent, text, icon)
    local g = CreateFrame("Frame", nil, parent)
    g:SetSize(SIDEBAR_W - 40, 16)
    g.icon = W.Icon(g, icon, 12, "text.muted")
    g.icon:SetPoint("LEFT", 0, 0)
    g.text = W.Text(g, "heading", "text.muted")
    g.text:SetPoint("LEFT", g.icon, "RIGHT", 7, 0)
    g.text:SetText(text:upper())
    Skin:Register(g, function(self)
        Skin:Text(self.text, "heading", "text.muted")
        W.Color(self.icon, "accent.primary", 0.75)
    end)
    return g
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
    local c = scroll.child
    local y = 0
    local function add(widget, h, x)
        widget:SetPoint("TOPLEFT", c, "TOPLEFT", x or 0, -y)
        if widget.SetPoint and widget.GetObjectType and widget:GetObjectType() == "Button" then
            widget:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        end
        y = y + h
    end
    add(navRow(c, "home", L.HOME, "home"), 34)
    for _, cat in ipairs(ns.categories) do
        local any = false
        for _, m in ipairs(ns.moduleList) do if m.category == cat and not m.hidden then any = true end end
        if any then
            y = y + 10
            add(groupLabel(c, L[CATEGORY_LABEL[cat]], CATEGORY_ICON[cat]), 22, 20)
            for _, m in ipairs(ns.moduleList) do
                if m.category == cat and not m.hidden then add(navRow(c, m.key, L[m.label], m.icon), 32) end
            end
        end
    end
    y = y + 10
    add(groupLabel(c, L.CAT_PHOENIX, "cat-phoenix"), 22, 20)
    add(navRow(c, "profiles", L.PROFILES, "profiles"), 32)
    add(navRow(c, "about", L.ABOUT, "about"), 32)
    c:SetHeight(y + 8)
end

local function buildFooter(f)
    local ft = CreateFrame("Frame", nil, f)
    ft:SetPoint("BOTTOMLEFT"); ft:SetPoint("BOTTOMRIGHT"); ft:SetHeight(FOOTER_H)
    ft.profileIcon = W.Icon(ft, "profiles", 12)
    ft.profileIcon:SetPoint("LEFT", 16, 0)
    ft.profile = W.Text(ft, "small", "text.secondary")
    ft.profile:SetPoint("LEFT", ft.profileIcon, "RIGHT", 6, 0)
    ft.status = W.Text(ft, "small", "text.muted", "CENTER")
    ft.status:SetPoint("CENTER", 8, 0)
    ft.statusIcon = W.Icon(ft, "preview", 12, "text.muted")
    ft.statusIcon:SetPoint("RIGHT", ft.status, "LEFT", -6, 0)
    ft.credit = W.Text(ft, "small", "text.muted", "RIGHT")
    ft.credit:SetPoint("RIGHT", -30, 0)
    ft.credit:SetText(ns.title .. "  ·  " .. L.BY_AUTHOR)
    f.footer = ft
    Skin:Register(ft, function(self)
        Skin:Panel(self, "sunken", { border = "border.subtle" })
        W.Color(self.profileIcon, "accent.primary")
        Skin:Text(self.profile, "small", "text.secondary")
        Skin:Text(self.status, "small", self.statusToken or "text.muted")
        W.Color(self.statusIcon, self.statusToken or "text.muted")
        Skin:Text(self.credit, "small", "text.muted")
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
    f:SetSize(s.w or 1000, s.h or 660)
    f:SetPoint(s.point or "CENTER", UIParent, s.rel or "CENTER", s.x or 0, s.y or 0)
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

function Config:Show(key)
    local f = self:Build()
    key = key or self.current or "home"
    if not self.builders[key] and not ns.modules[key] then key = "home" end
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
