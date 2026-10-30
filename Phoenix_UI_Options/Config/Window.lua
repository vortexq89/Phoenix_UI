local _, ns = ...
local L = ns.L
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media

--[[ The Phoenix UI settings window v4 "Flow" (DESIGN_SYSTEM_V3 §11, concept A).

      ┌ rail (236) ─────────┬ page: header that stays put (tile · crumb · title · N changed · Reset · Move · on/off) ┐
      │ brand · search      │       element chips                                                                │
      │ ▾ Bars              │       cards packed into 3 / 2 / 1 columns, each folds to a line of summary chips    │
      │   Action Bars       │                                                                    (close, top right)│
      │     › Layout …      │                                                                                     │
      │ ▸ Frames  Unit …    │                                                                                     │
      └ footer: profile · Layout · Test frames · auto-saved · status ······ pixel-perfect · window scale · reload ─┘

    The rail holds the seven groups of Config.GROUPS (Groups.lua) as heads: the open group lists its pages (with
    their on/off dots) and the open page lists its sub-pages under it; a closed group names its pages on one line.
    Pages are built lazily: one per module key, plus the built-in pages registered with Config:RegisterPage
    (home, fonts, textures, sounds, presets, profiles, diagnostics, about). The window is resizable (its size is
    kept); a page's live preview sits at the top of the page and stays there while the settings scroll. ]]
local Config = ns.Config or {} -- the front door from Phoenix_UI/UI/Launcher.lua; its methods are replaced here
ns.Config = Config
Config.loaded = true
Config.pages, Config.builders, Config.navRows = {}, {}, {}

local TOP_H, RAIL_W, LIST_W, FOOTER_H = 0, 236, 0, 32
local HEAD_H = 96 -- the rail head: brand and search
local NAV_ROW, NAV_HEAD, NAV_GROUP, NAV_SUB, NAV_LINE = 28, 22, 34, 24, 16
local DOCK_MIN, DOCK_MAX = 380, 460
local MIN_SCALE, MAX_SCALE = 0.7, 1.4
local DEFAULT_W, DEFAULT_H = 1400, 860
local MIN_W, MIN_H = 1100, 700
local SCREEN_W, SCREEN_H = 0.8, 0.85 -- the window never covers more of the screen than this
Config.RAIL_W, Config.MIN_W, Config.MIN_H = RAIL_W, MIN_W, MIN_H

-- info = { label = L key, icon = name, object = module-like page table, schema = table or function } names the
-- page in the list and lets search index its rows.
Config.pageInfo = {}
function Config:RegisterPage(key, builder, info)
    self.builders[key] = builder
    if info then self.pageInfo[key] = info end
end

---------------------------------------------------------------- frame
local function uiStore() return ns.DB.sv.global.ui end

local snapPosition
local function savePosition(f)
    if snapPosition then snapPosition(f) end
    local point, _, rel, x, y = f:GetPoint(1)
    local s = uiStore()
    s.point, s.rel, s.x, s.y = point, rel, x, y
    s.w, s.h = f:GetSize()
end

-- The window scale is relative to a readable base: with a very small UI scale (0.53 on a 1440p screen)
-- the window is scaled up so its text is as large as at Blizzard's default UI scale (about 0.71).
local function readable()
    local e = UIParent:GetEffectiveScale() or 1
    if e <= 0 then return 1 end
    return math.max(1, math.min(1.6, 0.71 / e))
end
-- The window keeps the size the player gave it (DEFAULT_W x DEFAULT_H at first, never under MIN_W x MIN_H); it
-- never follows page content. Small screens get a lower scale instead of a cramped window, keeping it within
-- SCREEN_W x SCREEN_H of the screen.
local function wanted()
    local s = uiStore()
    local w = math.max(MIN_W, math.floor(tonumber(s.w) or DEFAULT_W))
    local h = math.max(MIN_H, math.floor(tonumber(s.h) or DEFAULT_H))
    return w, h
end
local function fitToScreen(f)
    local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
    if type(uw) ~= "number" or uw <= 0 or type(uh) ~= "number" or uh <= 0 then return end
    local w, h = wanted()
    if f:GetWidth() ~= w or f:GetHeight() ~= h then f:SetSize(w, h) end
    local scale = f:GetScale() or 1
    if uw * SCREEN_W / scale < w or uh * SCREEN_H / scale < h then
        f:SetScale(math.max(0.5, math.min(scale, uw * SCREEN_W / w, uh * SCREEN_H / h)))
    end
end
Config.FitToScreen = fitToScreen
Config.SCREEN_W, Config.SCREEN_H = SCREEN_W, SCREEN_H

-- Puts the window's top-left corner on a whole screen pixel: a window that sits between pixels draws its
-- 1px borders and its text half on one pixel and half on the next (soft text, 2px grey lines).
function snapPosition(f)
    local left, top = f:GetLeft(), f:GetTop()
    if type(left) ~= "number" or type(top) ~= "number" then return end
    local unit = PixelUtil.ConvertPixelsToUIForRegion(1, f)
    if not unit or unit <= 0 then return end
    local x = math.floor(left / unit + 0.5) * unit
    local y = math.floor((top - UIParent:GetHeight() / f:GetScale()) / unit + 0.5) * unit
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end
Config.SnapPosition = snapPosition

-- A new scale changes how many UI units one screen pixel is: borders are re-measured (1 screen pixel) and
-- the window is put back on the pixel grid.
local function setScale(f, v)
    f:SetScale(v * readable())
    fitToScreen(f)
    snapPosition(f)
    Skin:Reapply()
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


---------------------------------------------------------------- rail head (brand, search) and close
local function buildTopBar(f)
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT"); h:SetSize(RAIL_W, HEAD_H)
    h:SetFrameLevel(f:GetFrameLevel() + 10)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() f:StartMoving() end)
    h:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
    f.header = h

    h.emblem = h:CreateTexture(nil, "ARTWORK")
    h.emblem:SetSize(26, 26)
    ns.Icons:Brand(h.emblem, "emblem", 26)
    ns.EmblemFX:Attach(h.emblem, 26)
    h.emblem:SetPoint("TOPLEFT", 16, -16)
    h.brand = W.Text(h, "brand", "text.primary")
    h.brand:SetPoint("LEFT", h.emblem, "RIGHT", 8, 1)
    h.brand:SetText("PHOENIX")
    h.brandUI = W.Text(h, "heading", "accent.primary")
    h.brandUI:SetPoint("LEFT", h.brand, "RIGHT", 5, -1)
    h.brandUI:SetText("UI")
    h.version = W:Badge(h, "v" .. ns.version, "accent.primary")
    h.version:SetPoint("LEFT", h.brandUI, "RIGHT", 8, 0)

    -- close: the window's top-right corner, over the page header
    h.close = W:IconButton(f, "close", 28, L.CLOSE)
    h.close.danger = true
    h.close:SetPoint("TOPRIGHT", -12, -12)
    h.close:SetFrameLevel(f:GetFrameLevel() + 60)
    h.close.onClick = function() f:Hide() end

    h.search = W:Input(h, RAIL_W - 28, L.SEARCH_PLACEHOLDER)
    h.search:SetHeight(30)
    h.search:SetPoint("TOPLEFT", 14, -54)
    h.search:SetTextInsets(32, 12, 0, 0)
    h.search.placeholder:ClearAllPoints()
    h.search.placeholder:SetPoint("LEFT", 32, 0)
    h.searchIcon = W.Icon(h.search, "search", 14)
    h.searchIcon:SetPoint("LEFT", 11, 0)
    h.search.onTextChanged = function(_, text) Config:Search(text) end
    h.search:HookScript("OnEscapePressed", function(self) self:SetValue(""); Config:Search("") end)

    function h:Arrange() self.search:SetWidth(RAIL_W - 28) end
    Skin:Register(h, function(self)
        Skin:Text(self.brand, "brand", "text.primary", 16)
        Skin:Text(self.brandUI, "heading", "accent.primary")
        W.Color(self.searchIcon, "text.muted")
    end)
end

---------------------------------------------------------------- rail: group heads, pages, sub-pages
-- A group head: icon, name, the number of pages; closed, a muted line under it names the pages.
local function groupHead(parent, g)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(NAV_GROUP)
    b.group = g
    b.bg = W.Texture(b, "BACKGROUND", 0)
    b.bg:SetPoint("TOPLEFT", 6, -1); b.bg:SetPoint("BOTTOMRIGHT", -6, 1)
    b.icon = W.Icon(b, g.icon, 16)
    b.icon:SetPoint("TOPLEFT", 14, -9)
    b.label = W.Text(b, "heading", "text.secondary")
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 9, 0)
    b.label:SetText(L[g.label] or g.label)
    b.chev = W.Icon(b, "chevron-right", 11, "text.muted")
    b.chev:SetPoint("TOPRIGHT", -14, -12)
    b.count = W.Text(b, "small", "text.muted", "RIGHT")
    b.count:SetPoint("RIGHT", b.chev, "LEFT", -6, 0)
    b.line = W.Text(b, "small", "text.muted")
    b.line:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -3)
    b.line:SetPoint("RIGHT", -14, 0)
    b.line:SetWordWrap(false)
    b.line:SetJustifyH("LEFT")
    function b:Paint()
        local open = Config.group == self.group.key
        W.Color(self.bg, "bg.hover", self.hover and 0.9 or 0)
        W.Color(self.icon, open and "accent.primary" or (self.hover and "text.primary" or "text.secondary"))
        Skin:Text(self.label, "heading", open and "text.primary" or (self.hover and "text.primary" or "text.secondary"))
        Skin:Text(self.count, "small", "text.muted")
        Skin:Text(self.line, "small", "text.muted", 11)
        ns.Icons:Apply(self.chev, open and "chevron-down" or "chevron-right", 11)
        W.Color(self.chev, "text.muted")
    end
    b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    b:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if Config.group == self.group.key and Config:GroupOf(Config.current) == self.group then
            -- the open group's head folds it (the page stays open)
            Config.group = nil
            Config:LayoutSidebar()
        else
            Config:OpenGroup(self.group.key)
        end
    end)
    Skin:Register(b, function(self) self:Paint() end)
    return b
end

-- A sub-page row under the open page: a short tick, its name; the current one in the accent.
local function subRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(NAV_SUB)
    r.tick = W.Texture(r, "ARTWORK")
    r.tick:SetSize(6, 1)
    r.tick:SetPoint("LEFT", 40, 0)
    r.label = W.Text(r, "desc", "text.muted")
    r.label:SetPoint("LEFT", r.tick, "RIGHT", 8, 0)
    r.label:SetPoint("RIGHT", -14, 0)
    r.label:SetWordWrap(false)
    function r:Paint()
        local on = self.page and self.page.tab == self.tab
        W.Color(self.tick, on and "accent.primary" or "border.strong")
        Skin:Text(self.label, "desc", on and "accent.primary" or (self.hover and "text.primary" or "text.muted"))
    end
    r:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    r:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    r:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if self.page and self.page.SetTab then self.page:SetTab(self.tab) end
    end)
    Skin:Register(r, function(self) self:Paint() end)
    return r
end

local function buildRail(f)
    -- kept for callers that know the v2 rail; the group heads live in the list now
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(1, 1)
    r:SetPoint("TOPLEFT")
    r.buttons = {}
    f.rail = r
end

function Config:BuildRail()
    local r = self.frame.rail
    local c = self.frame.sidebar.scroll.child
    for _, b in ipairs(r.buttons) do b:Hide() end
    wipe(r.buttons)
    for _, g in ipairs(self:Groups()) do
        if not (#g.entries == 1 and g.entries[1] == g.key) then r.buttons[#r.buttons + 1] = groupHead(c, g) end
    end
end

---------------------------------------------------------------- page rows
-- One page row: icon, name and the on/off dot.
local function navRow(parent, key)
    local label, icon = Config:EntryInfo(key)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(NAV_ROW)
    r.key = key
    r.bg = W.Texture(r, "BACKGROUND")
    r.bg:SetPoint("TOPLEFT", 6, -1); r.bg:SetPoint("BOTTOMRIGHT", -6, 1)
    r.bar = W.Texture(r, "ARTWORK")
    r.bar:SetPoint("TOPLEFT", r.bg, "TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT", r.bg, "BOTTOMLEFT")
    r.bar:SetWidth(2)
    r.icon = W.Icon(r, icon, 15)
    r.icon:SetPoint("LEFT", 16, 0)
    r.label = W.Text(r, "body", "text.secondary")
    r.label:SetPoint("LEFT", r.icon, "RIGHT", 9, 0)
    r.label:SetPoint("RIGHT", -28, 0)
    r.label:SetText(label)
    r.label:SetWordWrap(false)
    r.dot = W:Dot(r, 6)
    r.dot:SetPoint("RIGHT", -16, 0)
    -- the dot is the module's switch, as EllesmereUI's sidebar toggles: click turns the module on or off
    local m0 = ns.modules[key]
    if m0 and not m0.locked then
        r.switch = CreateFrame("Button", nil, r)
        r.switch:SetSize(20, 20)
        r.switch:SetPoint("CENTER", r.dot, "CENTER")
        r.switch:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            ns:SetModuleEnabled(key, not m0.db.enabled)
            r:Paint()
        end)
        r.switch:SetScript("OnEnter", function(self)
            W.ShowTooltip(self, r.label:GetText(), (m0.db.enabled and L.ENABLED or L.DISABLED) .. " \226\128\148 " .. L.NAV_SWITCH_TIP)
        end)
        r.switch:SetScript("OnLeave", function() W.HideTooltip() end)
    end
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
        self.now, self.target = Config:Depth(self.key)
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
    r:SetScript("OnLeave", function(self) self.hover = false; self:Paint(); W.HideTooltip() end)
    r:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        Config:Show(self.key)
    end)
    Skin:Register(r, function(self) self:Paint() end)
    return r
end

-- Section heading inside the open group: small caps label with a hairline running to the edge.
local function heading(parent)
    local fs = W.Text(parent, "small", "text.muted")
    fs.line = W.Texture(parent, "ARTWORK")
    fs.line:SetHeight(1)
    fs.line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    fs.line:SetPoint("RIGHT", parent, "RIGHT", -14, 0)
    Skin:Register(fs, function(t) Skin:Text(t, "small", "text.muted", 10); W.Color(t.line, "border.subtle", 0.6) end)
    return fs
end

local function buildList(f)
    local sb = CreateFrame("Frame", nil, f)
    sb:SetPoint("TOPLEFT", 0, 0)
    sb:SetPoint("BOTTOMLEFT", 0, FOOTER_H)
    sb:SetWidth(RAIL_W)
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
    scroll:SetPoint("TOPLEFT", 0, -HEAD_H)
    scroll:SetPoint("BOTTOMRIGHT", -6, 8)
    sb.scroll = scroll
    sb.headings, sb.subs = {}, {}
end

-- Rows of every page, made once; LayoutSidebar places them.
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
    for _, fs in ipairs(sb.headings) do fs:Hide(); fs.line:Hide() end
    for _, r in ipairs(sb.subs) do r:Hide() end
    local heads = {}
    for _, b in ipairs(self.frame.rail.buttons) do heads[b.group.key] = b; b:Hide() end
    local y, n, ns_ = 4, 0, 0
    local function place(frame, h, x)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", c, "TOPLEFT", x or 0, -y)
        frame:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        frame:Show()
        y = y + h
    end
    local function head(textKey)
        n = n + 1
        local fs = sb.headings[n] or heading(c)
        sb.headings[n] = fs
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", c, "TOPLEFT", 40, -(y + 6))
        fs:SetText((L[textKey] or textKey):upper())
        fs:Show(); fs.line:Show()
        y = y + NAV_HEAD
    end
    local function subs(key)
        local page = self.pages[key]
        if key ~= self.current or not (page and page.tabs and page.tabList) then return end
        for i, t in ipairs(page.tabList) do
            ns_ = ns_ + 1
            local r = sb.subs[ns_] or subRow(c)
            sb.subs[ns_] = r
            r.page, r.tab = page, i
            r.label:SetText(t.label)
            place(r, NAV_SUB)
            r:Paint()
        end
        y = y + 4
    end
    for _, g in ipairs(self:Groups()) do
        local b = heads[g.key]
        if not b then
            -- Home: a plain page row at the top
            for _, key in ipairs(g.entries) do
                local row = self.navRows[key]
                if row then row.active = key == self.current; place(row, NAV_ROW + 4); row:Paint() end
            end
            y = y + 6
        else
            local open = self.group == g.key
            local names = {}
            for _, key in ipairs(g.entries) do names[#names + 1] = (self:EntryInfo(key)) end
            b.count:SetText(tostring(#g.entries))
            b.line:SetText(table.concat(names, " \194\183 "))
            b.line:SetShown(not open)
            place(b, open and NAV_GROUP or (NAV_GROUP + NAV_LINE - 4))
            b:Paint()
            if open then
                local single = #g.sections == 1
                for i, section in ipairs(g.sections) do
                    if i > 1 then y = y + 2 end
                    if not single and section.heading then head(section.heading) end
                    for _, key in ipairs(section.entries) do
                        local row = self.navRows[key]
                        if row then
                            row.active = key == self.current
                            place(row, NAV_ROW, 14)
                            row:Paint()
                            subs(key)
                        end
                    end
                end
                y = y + 8
            end
        end
    end
    c:SetHeight(y + 8)
    sb.scroll:UpdateBar()
end

-- A group head: open the group (its last page, or its first).
function Config:OpenGroup(key)
    local g
    for _, group in ipairs(self:Groups()) do if group.key == key then g = group end end
    if not g then return end
    local last = uiStore().lastPage
    local target = type(last) == "table" and last[key]
    if not (target and self:EntryExists(target) and self:GroupOf(target) == g) then target = g.entries[1] end
    self:Show(target)
end

-- Kept for callers from the 13-group layout: "expand" a group = open it.
function Config:ToggleGroup(key, expand)
    if expand == false then return end
    self:OpenGroup(key)
end

-- Opens the group that holds key (used when a page is shown from search, a link or /pui).
function Config:RevealEntry(key)
    local g = self:GroupOf(key)
    self.group = g and g.key or self.group
    self:LayoutSidebar()
end

---------------------------------------------------------------- preview dock
-- v4 has no dock: previews sit at the top of the page, and Home's side cards are part of its columns. The frame
-- stays (hidden) for callers that ask about it.
local function buildDock(f)
    local d = CreateFrame("Frame", nil, f)
    d:SetPoint("TOPRIGHT", 0, 0)
    d:SetPoint("BOTTOMRIGHT", 0, FOOTER_H)
    d:SetWidth(DOCK_MIN)
    d:Hide()
    f.dock = d
end

function Config:LayoutShell()
    local f = self.frame
    if not f then return end
    local page = self.current and self.pages[self.current]
    f.dock:Hide()
    f.dock:SetWidth(DOCK_MIN + 0 * DOCK_MAX)
    f.content:ClearAllPoints()
    f.content:SetPoint("TOPLEFT", RAIL_W + LIST_W, -TOP_H)
    f.content:SetPoint("BOTTOMRIGHT", 0, FOOTER_H)
    if page and page.SetDocked and page.docked then page:SetDocked(nil) end
end

---------------------------------------------------------------- footer
local function buildFooter(f)
    local ft = CreateFrame("Frame", nil, f)
    ft:SetPoint("BOTTOMLEFT"); ft:SetPoint("BOTTOMRIGHT"); ft:SetHeight(FOOTER_H)
    ft:EnableMouse(true)
    ft:RegisterForDrag("LeftButton")
    ft:SetScript("OnDragStart", function() f:StartMoving() end)
    ft:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
    local h = f.header
    -- the tools: profile, Layout mode, Test frames (the header fields stay for callers)
    ft.profileDD = W:Dropdown(ft, profileItems, nil, 172)
    ft.profileDD:SetPoint("LEFT", 14, 0)
    ft.profileDD:SetHeight(26)
    ft.profileDD.onChange = function(d, name) ns.DB:SetProfile(name); d:SetValue(name) end
    ft.profileDD:SetValue(ns.DB:GetProfileName())
    W.AttachTooltip(ft.profileDD, L.PROFILE, L.PROFILE_SWITCH_DESC)
    ft.layout = W:Button(ft, L.LAYOUT_MODE, "secondary", "layout")
    ft.layout:SetHeight(26)
    ft.layout:SetPoint("LEFT", ft.profileDD, "RIGHT", 8, 0)
    ft.layout.onClick = function() layoutMode(f) end
    W.AttachTooltip(ft.layout, L.LAYOUT_MODE, L.LAYOUT_MODE_DESC)
    ft.test = W:Button(ft, L.TEST_FRAMES, "secondary", "test")
    ft.test:SetHeight(26)
    ft.test:SetPoint("LEFT", ft.layout, "RIGHT", 6, 0)
    ft.test.onClick = toggleTestFrames
    W.AttachTooltip(ft.test, L.TEST_FRAMES, L.TEST_FRAMES_DESC)
    h.profile, h.layout, h.test = ft.profileDD, ft.layout, ft.test
    h.editmode = ft.layout -- older callers (and the slash help) know it by this name

    ft.savedIcon = W.Icon(ft, "success", 12, "state.success")
    ft.savedIcon:SetPoint("LEFT", ft.test, "RIGHT", 18, 0)
    ft.saved = W.Text(ft, "small", "text.secondary")
    ft.saved:SetPoint("LEFT", ft.savedIcon, "RIGHT", 6, 0)
    ft.saved:SetText(L.AUTO_SAVED)
    ft.statusIcon = W.Icon(ft, "preview", 12, "text.muted")
    ft.statusIcon:SetPoint("LEFT", ft.saved, "RIGHT", 14, 0)
    ft.status = W.Text(ft, "small", "text.muted")
    ft.status:SetPoint("LEFT", ft.statusIcon, "RIGHT", 6, 0)
    ft.status:SetWordWrap(false)
    ft.profile = ft.saved
    ft.reload = W:Button(ft, L.RELOAD_UI, "primary", "reload")
    ft.reload:SetHeight(24)
    ft.reload:SetPoint("RIGHT", -30, 0)
    ft.reload.onClick = function() C_UI.Reload() end
    ft.reload:Hide()
    -- Window scale: applied when the drag ends, so the slider does not move away under the cursor.
    ft.scale = W:Slider(ft, MIN_SCALE, MAX_SCALE, 0.05, true)
    ft.scale:SetWidth(120)
    ft.scale:SetPoint("RIGHT", -30, 0)
    ft.scale:SetValue(uiStore().scale or 1)
    ft.scale.onChange = function(_, v)
        uiStore().scale = v
        if not IsMouseButtonDown("LeftButton") then setScale(f, v) end
    end
    ft.scale.bar:HookScript("OnMouseUp", function() setScale(f, uiStore().scale or 1) end)
    ft.scaleLabel = W.Text(ft, "small", "text.muted", "RIGHT")
    ft.scaleLabel:SetPoint("RIGHT", ft.scale, "LEFT", -8, 0)
    ft.scaleLabel:SetText(L.WINDOW_SCALE:upper())
    ft.pixel = W.Text(ft, "small", "text.muted", "RIGHT")
    ft.pixel:SetPoint("RIGHT", ft.scaleLabel, "LEFT", -18, 0)
    ft.status:SetPoint("RIGHT", ft.pixel, "LEFT", -16, 0)
    -- resize grip, bottom-right corner
    ft.grip = CreateFrame("Button", nil, ft)
    ft.grip:SetSize(16, 16)
    ft.grip:SetPoint("BOTTOMRIGHT", -3, 3)
    ft.grip.icon = W.Icon(ft.grip, "resize", 12, "text.muted")
    ft.grip.icon:SetPoint("CENTER")
    ft.grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    ft.grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        local w, hh = f:GetSize()
        local s = uiStore()
        s.w, s.h = math.max(MIN_W, math.floor(w + 0.5)), math.max(MIN_H, math.floor(hh + 0.5))
        fitToScreen(f)
        savePosition(f)
    end)
    ft.grip:SetScript("OnEnter", function(self) W.Color(self.icon, "text.primary") end)
    ft.grip:SetScript("OnLeave", function(self) W.Color(self.icon, "text.muted") end)
    function ft:Arrange()
        local reload = self.reload:IsShown()
        self.scale:ClearAllPoints()
        if reload then self.scale:SetPoint("RIGHT", self.reload, "LEFT", -16, 0) else self.scale:SetPoint("RIGHT", -30, 0) end
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
        W.Color(self.grip.icon, "text.muted")
    end)
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
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    local s = uiStore()
    -- v4: the window is resizable; sizes kept by the fixed v3 window start again from the Flow default
    if s.v ~= 4 then s.w, s.h, s.v = nil, nil, 4 end
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H) end
    f:SetSize(wanted())
    f:SetPoint(s.point or "CENTER", UIParent, s.rel or "CENTER", s.x or 0, s.y or 0)
    setScale(f, math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(s.scale) or 1)))
    Skin:Register(f, function(self) Skin:Panel(self, "base", { border = "border.strong", shadow = 18 }) end)
    self.frame = f
    for _, ev in ipairs({ "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
        ns.Events:On(ev, f, function() setScale(f, math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(uiStore().scale) or 1))) end)
    end

    buildList(f)
    buildTopBar(f)
    buildRail(f)
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
        f.header.profile:SetValue(ns.DB:GetProfileName())
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
        local page = self.current and self.pages[self.current]
        if page and page.Layout and f:IsShown() then page:Layout() end
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
    uiStore().v = 4
    setScale(f, 1)
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
