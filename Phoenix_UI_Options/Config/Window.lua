local _, ns = ...
local L = ns.L
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media

--[[ The Phoenix UI settings window v2 (S6; ARCHITECTURE §9, docs/plan_v2/PLAN_V2.md §4).

      ┌ top bar: brand · search ······· profile · Layout · Test frames · close ──────────────────────┐
      │ rail │ module list │ page (header · tabs · element chips · cards)        │ preview dock (380+) │
      └ footer: auto-saved · status line · pixel-perfect scale · window scale · reload when needed ────┘

    The rail holds the seven groups of Config.GROUPS (Groups.lua); the list shows the picked group's pages
    with their depth meters and on/off dots. Pages are built lazily: one per module key, plus the built-in
    pages registered with Config:RegisterPage (home, fonts, textures, sounds, presets, profiles,
    diagnostics, about). A page's live preview (or its side panel, on Home) sits in the dock when the window
    is at least DOCK_AT wide, and pins to the top of the page when it is narrower. ]]
local Config = ns.Config or {} -- the front door from Phoenix_UI/UI/Launcher.lua; its methods are replaced here
ns.Config = Config
Config.loaded = true
Config.pages, Config.builders, Config.navRows = {}, {}, {}

local TOP_H, RAIL_W, LIST_W, FOOTER_H = 52, 64, 212, 34
local DOCK_MIN, DOCK_MAX, DOCK_AT = 380, 460, 1100
local MIN_SCALE, MAX_SCALE = 0.7, 1.4
local MIN_W, MIN_H, MAX_W, MAX_H = 900, 560, 1800, 1200
local DEFAULT_W, DEFAULT_H = 1280, 800
local RAIL_BTN = 52

-- info = { label = L key, icon = name, object = module-like page table, schema = table or function } names the
-- page in the list and lets search index its rows.
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

-- 768 / physical height: the UI scale at which one UI pixel is one screen pixel.
local function pixelPerfect()
    local _, ph = GetPhysicalScreenSize()
    if not ph or ph <= 0 then return nil end
    return 768 / ph
end

---------------------------------------------------------------- top bar
local function profileItems()
    local out = {}
    for _, name in ipairs(ns.DB:GetProfiles()) do out[#out + 1] = { value = name, label = name, icon = "profiles" } end
    return out
end

-- Test frames: unit frames, cast bars, auras and the Cooldown Manager together; the unit frames' state leads (one button, one state).
local TEST_MODULES = { "UnitFrames", "CastBars", "Auras", "Tracker" }
local function toggleTestFrames()
    local live = {}
    for _, name in ipairs(TEST_MODULES) do
        local m = ns.modules[name]
        if m and m:IsEnabled() and m.ShowTest then live[#live + 1] = m end
    end
    if #live == 0 then
        Config:SetStatus(L.TEST_FRAMES_OFF, "state.warning", "warning")
        return
    end
    local show = not live[1].testShown
    local ok = true
    for _, m in ipairs(live) do
        if (m.testShown and true or false) ~= show and not m:ShowTest(show) then ok = false end
    end
    if not ok then Config:SetStatus(L.UF_TEST_COMBAT, "state.warning", "warning") end
end

local function layoutMode(f)
    f:Hide()
    local movers = ns.modules.Movers
    if movers and movers:IsEnabled() and movers.SetUnlocked then movers:SetUnlocked(true) else ns.EditMode:Open() end
end

local function buildTopBar(f)
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT"); h:SetPoint("TOPRIGHT"); h:SetHeight(TOP_H)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() f:StartMoving() end)
    h:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
    f.header = h

    h.emblem = h:CreateTexture(nil, "ARTWORK")
    h.emblem:SetSize(28, 28)
    ns.Icons:Brand(h.emblem, "emblem", 28)
    h.emblem:SetPoint("LEFT", 18, 0)
    h.brand = W.Text(h, "brand", "text.primary")
    h.brand:SetPoint("LEFT", h.emblem, "RIGHT", 9, 1)
    h.brand:SetText("PHOENIX")
    h.brandUI = W.Text(h, "heading", "accent.primary")
    h.brandUI:SetPoint("LEFT", h.brand, "RIGHT", 5, -1)
    h.brandUI:SetText("UI")
    h.version = W:Badge(h, "v" .. ns.version, "accent.primary")
    h.version:SetPoint("LEFT", h.brandUI, "RIGHT", 10, 0)

    h.close = W:IconButton(h, "close", 30, L.CLOSE)
    h.close.danger = true
    h.close:SetPoint("RIGHT", -12, 0)
    h.close.onClick = function() f:Hide() end
    h.test = W:Button(h, L.TEST_FRAMES, "secondary", "test")
    h.test:SetHeight(28)
    h.test:SetPoint("RIGHT", h.close, "LEFT", -10, 0)
    h.test.onClick = toggleTestFrames
    W.AttachTooltip(h.test, L.TEST_FRAMES, L.TEST_FRAMES_DESC)
    h.layout = W:Button(h, L.LAYOUT_MODE, "secondary", "layout")
    h.layout:SetHeight(28)
    h.layout:SetPoint("RIGHT", h.test, "LEFT", -6, 0)
    h.layout.onClick = function() layoutMode(f) end
    W.AttachTooltip(h.layout, L.LAYOUT_MODE, L.LAYOUT_MODE_DESC)
    h.editmode = h.layout -- older callers (and the slash help) know it by this name
    h.profile = W:Dropdown(h, profileItems, nil, 176)
    h.profile:SetPoint("RIGHT", h.layout, "LEFT", -10, 0)
    h.profile:SetHeight(28)
    h.profile.onChange = function(_, name) ns.DB:SetProfile(name) end
    W.AttachTooltip(h.profile, L.PROFILE, L.PROFILE_SWITCH_DESC)

    h.search = W:Input(h, 320, L.SEARCH_PLACEHOLDER)
    h.search:SetHeight(30)
    h.search:SetTextInsets(32, 12, 0, 0)
    h.search.placeholder:ClearAllPoints()
    h.search.placeholder:SetPoint("LEFT", 32, 0)
    h.searchIcon = W.Icon(h.search, "search", 14)
    h.searchIcon:SetPoint("LEFT", 11, 0)
    h.search.onTextChanged = function(_, text) Config:Search(text) end
    h.search:HookScript("OnEscapePressed", function(self) self:SetValue(""); Config:Search("") end)

    h.line = W.Texture(h, "ARTWORK", 2)
    h.line:SetPoint("BOTTOMLEFT"); h.line:SetPoint("BOTTOMRIGHT")
    h.line:SetHeight(1)
    h.glow = W.Texture(h, "ARTWORK", 1, Media.textures.FADE_V)
    h.glow:SetPoint("BOTTOMLEFT", 0, 1); h.glow:SetPoint("BOTTOMRIGHT", 0, 1)
    h.glow:SetHeight(14)
    h.glow:SetTexCoord(0, 1, 1, 0)

    -- the search box centres between the brand and the tools; it narrows before it overlaps either
    function h:Arrange()
        local width = self:GetWidth() or DEFAULT_W
        local left = 18 + 28 + 9 + self.brand:GetStringWidth() + 5 + self.brandUI:GetStringWidth() + 10 + self.version:GetWidth() + 24
        local right = 12 + 30 + 10 + self.test:GetWidth() + 6 + self.layout:GetWidth() + 10 + self.profile:GetWidth() + 24
        local room = width - left - right
        local w = math.max(160, math.min(360, room))
        self.search:SetWidth(w)
        self.search:ClearAllPoints()
        self.search:SetPoint("LEFT", self, "LEFT", left + math.max(0, (room - w) / 2), 0)
    end
    h:SetScript("OnSizeChanged", function(self) self:Arrange() end)

    Skin:Register(h, function(self)
        Skin:Panel(self, "raised", { border = false })
        Skin:Text(self.brand, "brand", "text.primary", 17)
        Skin:Text(self.brandUI, "heading", "accent.primary")
        self.line:SetVertexColor(1, 1, 1, 1)
        local r2, g2, b2 = Theme:Color("accent.secondary")
        self.line:SetGradient("HORIZONTAL", Theme:ColorObj("accent.primary"), CreateColor(r2, g2, b2, 0))
        self.glow:SetVertexColor(1, 1, 1, 1)
        local r, g, b = Theme:Color("accent.primary")
        self.glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.08), CreateColor(r, g, b, 0))
        W.Color(self.searchIcon, "text.muted")
    end)
end

---------------------------------------------------------------- icon rail
local function railButton(parent, g)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(RAIL_BTN, RAIL_BTN)
    b.group = g
    b.bg = W.Texture(b, "BACKGROUND", 0, Media.textures.ROUNDED)
    b.bg:SetAllPoints()
    b.bar = W.Texture(b, "ARTWORK", 1)
    b.bar:SetSize(2, 22)
    b.bar:SetPoint("LEFT", parent, "LEFT", 0, 0)
    b.bar:SetPoint("TOP", b, "TOP", 0, -15)
    b.icon = W.Icon(b, g.icon, 18)
    b.icon:SetPoint("TOP", 0, -10)
    b.label = W.Text(b, "small", "text.muted", "CENTER")
    b.label:SetPoint("BOTTOM", 0, 7)
    b.label:SetPoint("LEFT", 2, 0); b.label:SetPoint("RIGHT", -2, 0)
    b.label:SetText(L[g.label] or g.label)
    function b:Paint()
        local on = Config.group == self.group.key
        W.Color(self.bg, on and "accent.soft" or "bg.hover", on and 1 or (self.hover and 0.9 or 0))
        self.bar:SetShown(on)
        self.bar:SetVertexColor(1, 1, 1, 1)
        Skin:Gradient(self.bar, "VERTICAL", "accent.secondary", "accent.primary")
        W.Color(self.icon, on and "accent.primary" or (self.hover and "text.primary" or "text.secondary"))
        Skin:Text(self.label, "small", on and "text.primary" or (self.hover and "text.secondary" or "text.muted"), 9)
    end
    b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    b:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        Config:OpenGroup(self.group.key)
    end)
    Skin:Register(b, function(self) self:Paint() end)
    return b
end

local function buildRail(f)
    local r = CreateFrame("Frame", nil, f)
    r:SetPoint("TOPLEFT", 0, -TOP_H)
    r:SetPoint("BOTTOMLEFT", 0, FOOTER_H)
    r:SetWidth(RAIL_W)
    r.edge = W.Texture(r, "BORDER")
    r.edge:SetPoint("TOPRIGHT"); r.edge:SetPoint("BOTTOMRIGHT")
    r.edge:SetWidth(1)
    r.buttons = {}
    Skin:Register(r, function(self)
        Skin:Panel(self, "base", { border = false })
        Skin:SetPanelColor(self, "bg.sunken")
        W.Color(self.edge, "border.subtle")
    end)
    f.rail = r
end

function Config:BuildRail()
    local r = self.frame.rail
    for _, b in ipairs(r.buttons) do b:Hide() end
    wipe(r.buttons)
    local y = 10
    for _, g in ipairs(self:Groups()) do
        local b = railButton(r, g)
        b:SetPoint("TOP", r, "TOP", 0, -y)
        y = y + RAIL_BTN + 6
        r.buttons[#r.buttons + 1] = b
    end
end

---------------------------------------------------------------- module list
-- One page row: icon, name, a depth meter (settings now against the plan v2 target) and the on/off dot.
local function navRow(parent, key)
    local label, icon = Config:EntryInfo(key)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(32)
    r.key = key
    r.bg = W.Texture(r, "BACKGROUND")
    r.bg:SetPoint("TOPLEFT", 8, 0); r.bg:SetPoint("BOTTOMRIGHT", -8, 0)
    r.bar = W.Texture(r, "ARTWORK")
    r.bar:SetPoint("TOPLEFT", r.bg, "TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT", r.bg, "BOTTOMLEFT")
    r.bar:SetWidth(2)
    r.icon = W.Icon(r, icon, 14)
    r.icon:SetPoint("LEFT", 18, 0)
    r.label = W.Text(r, "body", "text.secondary")
    r.label:SetPoint("LEFT", r.icon, "RIGHT", 9, 0)
    r.label:SetPoint("RIGHT", -64, 0)
    r.label:SetText(label)
    r.label:SetWordWrap(false)
    r.meter = W.Texture(r, "ARTWORK", 0, Media.textures.PILL)
    r.meter:SetSize(32, 3)
    r.meter:SetPoint("RIGHT", -26, 0)
    r.fill = W.Texture(r, "ARTWORK", 1, Media.textures.PILL)
    r.fill:SetHeight(3)
    r.fill:SetPoint("LEFT", r.meter, "LEFT")
    r.dot = W:Dot(r, 6)
    r.dot:SetPoint("RIGHT", -14, 0)
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
        local now, target = Config:Depth(self.key)
        self.now, self.target = now, target
        local show = target ~= nil and target > 0
        self.meter:SetShown(show)
        self.fill:SetShown(show and now > 0)
        if show then
            W.Color(self.meter, "border.subtle")
            self.fill:SetVertexColor(1, 1, 1, 1)
            Skin:Gradient(self.fill, "HORIZONTAL", "accent.primary", "accent.secondary")
            self.fill:SetWidth(math.max(2, 32 * math.min(1, now / target)))
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
    r:SetScript("OnEnter", function(self)
        self.hover = true
        self:Paint()
        if self.target then W.ShowTooltip(self, self.label:GetText(), L.DEPTH_TIP:format(self.now, self.target)) end
    end)
    r:SetScript("OnLeave", function(self) self.hover = false; self:Paint(); W.HideTooltip() end)
    r:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        Config:Show(self.key)
    end)
    Skin:Register(r, function(self) self:Paint() end)
    return r
end

local function heading(parent)
    local fs = W.Text(parent, "heading", "text.muted")
    Skin:Register(fs, function(t) Skin:Text(t, "heading", "text.muted") end)
    return fs
end

local function buildList(f)
    local sb = CreateFrame("Frame", nil, f)
    sb:SetPoint("TOPLEFT", RAIL_W, -TOP_H)
    sb:SetPoint("BOTTOMLEFT", RAIL_W, FOOTER_H)
    sb:SetWidth(LIST_W)
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
    scroll:SetPoint("TOPLEFT", 0, -12)
    scroll:SetPoint("BOTTOMRIGHT", -8, 10)
    sb.scroll = scroll
    sb.headings = {}
end

-- Rows of every page, made once; LayoutSidebar shows the open group's.
function Config:BuildList()
    local c = self.frame.sidebar.scroll.child
    for _, g in ipairs(self:Groups()) do
        for _, key in ipairs(g.entries) do
            if not self.navRows[key] then self.navRows[key] = navRow(c, key) end
        end
    end
end

function Config:LayoutSidebar()
    if not self.frame then return end
    local sb = self.frame.sidebar
    local c = sb.scroll.child
    for _, row in pairs(self.navRows) do row:Hide() end
    for _, fs in ipairs(sb.headings) do fs:Hide() end
    local g
    for _, group in ipairs(self:Groups()) do if group.key == self.group then g = group end end
    local y, n = 0, 0
    local function head(textKey)
        n = n + 1
        local fs = sb.headings[n] or heading(c)
        sb.headings[n] = fs
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", c, "TOPLEFT", 18, -(y + 8))
        fs:SetText((L[textKey] or textKey):upper())
        fs:Show()
        y = y + 28
    end
    if g then
        for i, section in ipairs(g.sections) do
            if i > 1 then y = y + 8 end
            head(section.heading or g.label)
            for _, key in ipairs(section.entries) do
                local row = self.navRows[key]
                if row then
                    row.active = key == self.current
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
                    row:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
                    row:Show()
                    row:Paint()
                    y = y + 32
                end
            end
        end
    end
    c:SetHeight(y + 8)
    sb.scroll:UpdateBar()
    for _, b in ipairs(self.frame.rail.buttons) do b:Paint() end
end

-- The rail: pick a group (its last page opens, or its first).
function Config:OpenGroup(key)
    local g
    for _, group in ipairs(self:Groups()) do if group.key == key then g = group end end
    if not g then return end
    local last = uiStore().lastPage
    local target = type(last) == "table" and last[key]
    if not (target and self:EntryExists(target) and self:GroupOf(target) == g) then target = g.entries[1] end
    self:Show(target)
end

-- Kept for callers from the 13-group layout: "expand" a group = open it on the rail.
function Config:ToggleGroup(key, expand)
    if expand == false then return end
    self:OpenGroup(key)
end

-- Selects the group that holds key (used when a page is shown from search, a link or /pui).
function Config:RevealEntry(key)
    local g = self:GroupOf(key)
    self.group = g and g.key or self.group
    self:LayoutSidebar()
end

---------------------------------------------------------------- preview dock
local function buildDock(f)
    local d = CreateFrame("Frame", nil, f)
    d:SetPoint("TOPRIGHT", 0, -TOP_H)
    d:SetPoint("BOTTOMRIGHT", 0, FOOTER_H)
    d:SetWidth(DOCK_MIN)
    d.edge = W.Texture(d, "BORDER")
    d.edge:SetPoint("TOPLEFT"); d.edge:SetPoint("BOTTOMLEFT")
    d.edge:SetWidth(1)
    Skin:Register(d, function(self)
        Skin:Panel(self, "base", { border = false })
        Skin:SetPanelColor(self, "bg.sunken")
        W.Color(self.edge, "border.subtle")
    end)
    d:EnableMouse(true)
    d:Hide()
    f.dock = d
end

-- Puts the current page's preview (or side panel) in the dock when the window is wide enough.
function Config:LayoutShell()
    local f = self.frame
    if not f then return end
    local width = f:GetWidth() or DEFAULT_W
    local page = self.current and self.pages[self.current]
    local side = page and (page.pinned or page.side)
    local docked = side ~= nil and width >= DOCK_AT
    local dockW = math.floor(math.max(DOCK_MIN, math.min(DOCK_MAX, width * 0.3)))
    f.dock:SetWidth(dockW)
    f.dock:SetShown(docked)
    f.content:ClearAllPoints()
    f.content:SetPoint("TOPLEFT", RAIL_W + LIST_W, -TOP_H)
    if docked then f.content:SetPoint("BOTTOMRIGHT", f.dock, "BOTTOMLEFT", 0, 0)
    else f.content:SetPoint("BOTTOMRIGHT", 0, FOOTER_H) end
    if page and page.SetDocked then page:SetDocked(docked and f.dock or nil) end
end

---------------------------------------------------------------- footer
local function buildFooter(f)
    local ft = CreateFrame("Frame", nil, f)
    ft:SetPoint("BOTTOMLEFT"); ft:SetPoint("BOTTOMRIGHT"); ft:SetHeight(FOOTER_H)
    ft.savedIcon = W.Icon(ft, "success", 12, "state.success")
    ft.savedIcon:SetPoint("LEFT", 16, 0)
    ft.saved = W.Text(ft, "small", "text.secondary")
    ft.saved:SetPoint("LEFT", ft.savedIcon, "RIGHT", 6, 0)
    ft.saved:SetText(L.AUTO_SAVED)
    ft.statusIcon = W.Icon(ft, "preview", 12, "text.muted")
    ft.statusIcon:SetPoint("LEFT", ft.saved, "RIGHT", 14, 0)
    ft.status = W.Text(ft, "small", "text.muted")
    ft.status:SetPoint("LEFT", ft.statusIcon, "RIGHT", 6, 0)
    -- profile and module count live in the top bar and on Home now; the old fields stay for callers
    ft.profile = ft.saved
    ft.reload = W:Button(ft, L.RELOAD_UI, "primary", "reload")
    ft.reload:SetHeight(24)
    ft.reload:SetPoint("RIGHT", -26, 0)
    ft.reload.onClick = function() C_UI.Reload() end
    ft.reload:Hide()
    -- Window scale: applied when the drag ends, so the slider does not move away under the cursor.
    ft.scale = W:Slider(ft, MIN_SCALE, MAX_SCALE, 0.05, true)
    ft.scale:SetWidth(132)
    ft.scale:SetPoint("RIGHT", -26, 0)
    ft.scale:SetValue(uiStore().scale or 1)
    ft.scale.onChange = function(_, v)
        uiStore().scale = v
        if not IsMouseButtonDown("LeftButton") then f:SetScale(v) end
    end
    ft.scale.bar:HookScript("OnMouseUp", function() f:SetScale(uiStore().scale or 1) end)
    ft.scaleLabel = W.Text(ft, "small", "text.muted", "RIGHT")
    ft.scaleLabel:SetPoint("RIGHT", ft.scale, "LEFT", -8, 0)
    ft.scaleLabel:SetText(L.WINDOW_SCALE:upper())
    ft.pixel = W.Text(ft, "small", "text.muted", "RIGHT")
    ft.pixel:SetPoint("RIGHT", ft.scaleLabel, "LEFT", -18, 0)
    ft.status:SetPoint("RIGHT", ft.pixel, "LEFT", -16, 0)
    function ft:Arrange()
        local reload = self.reload:IsShown()
        self.scale:ClearAllPoints()
        if reload then self.scale:SetPoint("RIGHT", self.reload, "LEFT", -16, 0) else self.scale:SetPoint("RIGHT", -26, 0) end
        local pp = pixelPerfect()
        self.pixel:SetText(pp and L.PIXEL_PERFECT:format(pp) or "")
    end
    f.footer = ft
    Skin:Register(ft, function(self)
        Skin:Panel(self, "sunken", { border = "border.subtle" })
        W.Color(self.savedIcon, "state.success")
        Skin:Text(self.saved, "small", "text.secondary")
        Skin:Text(self.status, "small", self.statusToken or "text.muted")
        W.Color(self.statusIcon, self.statusToken or "text.muted")
        Skin:Text(self.scaleLabel, "small", "text.muted")
        Skin:Text(self.pixel, "small", "text.muted")
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
    if text == L.STATUS_RELOAD then
        ft.reload:Show()
        ft:Arrange()
    end
end

function Config:UpdateFooter()
    local f = self.frame
    if not f then return end
    local reload = false
    for _, m in ipairs(ns.moduleList) do if m.needsReload then reload = true end end
    f.footer.reload:SetShown(reload)
    f.footer:Arrange()
    f.header.profile:SetValue(ns.DB:GetProfileName())
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
    -- windows saved by the 13-group layout (1100 x 720) grow once to the v2 default
    if s.v ~= 2 then s.w, s.h, s.v = nil, nil, 2 end
    f:SetSize(s.w or DEFAULT_W, s.h or DEFAULT_H)
    f:SetPoint(s.point or "CENTER", UIParent, s.rel or "CENTER", s.x or 0, s.y or 0)
    f:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(s.scale) or 1)))
    Skin:Register(f, function(self) Skin:Panel(self, "base", { border = "border.strong", shadow = 18 }) end)
    self.frame = f

    buildTopBar(f)
    buildRail(f)
    buildList(f)
    buildDock(f)
    buildFooter(f)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", RAIL_W + LIST_W, -TOP_H)
    content:SetPoint("BOTTOMRIGHT", 0, FOOTER_H)
    content:SetClipsChildren(true)
    f.content = content
    f.ambient = W.Texture(content, "BACKGROUND", 1, Media.textures.FADE_V)
    f.ambient:SetPoint("TOPLEFT"); f.ambient:SetPoint("TOPRIGHT"); f.ambient:SetHeight(160)
    Skin:Register(f.ambient, function(t) W.Color(t, "accent.primary", 0.04) end)

    self:BuildRail()
    self:BuildList()
    f.header:Arrange()

    f:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        if self.InvalidateSearch then self:InvalidateSearch() end
        if self.UpdateSearchHint then self:UpdateSearchHint() end
        self:UpdateFooter()
        for _, row in pairs(self.navRows) do row:Paint() end
        if self.current and self.pages[self.current] and self.pages[self.current].Refresh then self.pages[self.current]:Refresh() end
    end)
    f:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        W.HideTooltip()
        f.header.search:ClearFocus()
    end)
    f:SetScript("OnSizeChanged", function()
        f.header:Arrange()
        self:LayoutShell()
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
    if self.current and self.pages[self.current] then
        local old = self.pages[self.current]
        if old.SetDocked and old.docked then old:SetDocked(nil) end
        old:Hide()
    end
    local page = self.pages[key]
    if not page then
        page = (self.builders[key] or self.BuildModulePage)(f.content, key)
        page:SetAllPoints(f.content)
        self.pages[key] = page
    end
    local previous = self.current
    self.current = key
    local g = self:GroupOf(key)
    if g then
        local last = uiStore().lastPage
        if type(last) ~= "table" then last = {}; uiStore().lastPage = last end
        last[g.key] = key
    end
    self:RevealEntry(key)
    if page.Refresh then page:Refresh() end
    self:LayoutShell()
    if page.Layout then page:Layout() end
    if self.results then self.results:Hide() end
    if not f:IsShown() then
        f:Show()
    end
    if previous ~= key then
        ns.Anim:FadeIn(page, 0.14)
        if page.pinned and page.docked then ns.Anim:FadeIn(page.pinned, 0.14) end
    else
        page:Show()
    end
    return page
end

function Config:Toggle(key)
    local f = self:Build()
    if f:IsShown() and (not key or key == self.current) then f:Hide() else self:Show(key) end
end
