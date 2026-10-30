local _, ns = ...
local L = ns.L
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media
local Config = ns.Config
--[[ Home v4 "Flow" (DESIGN_SYSTEM_V3 §11): the hero banner with the look presets, live stats, then cards packed
    into 3 / 2 / 1 columns with no gaps: one card per rail group listing its modules (on/off switch and how many
    settings each has), this week (Great Vault and Mythic+ season), health (including which font is in use),
    quick actions and what's new. The group filter narrows the module rows. ]]
local PAD, GAP, ROW_H, WEEK_H, HERO_H = 20, 12, 30, 132, 150
local THREE_AT, TWO_AT = 980, 640
local PRESETS = { "ember", "frost", "fel", "arcane", "class" }

-- One module row in a group card: tile, name, settings count, the on/off switch; click opens the page.
local function moduleCard(parent, m)
    local c = CreateFrame("Button", nil, parent)
    c:SetHeight(ROW_H)
    c.module = m
    c.bg = W.Texture(c, "BACKGROUND", 0)
    c.bg:SetPoint("TOPLEFT", 6, 0); c.bg:SetPoint("BOTTOMRIGHT", -6, 0)
    c.iconBg = W.Texture(c, "ARTWORK", 0, Media.textures.ROUNDED)
    c.iconBg:SetSize(22, 22)
    c.iconBg:SetPoint("LEFT", 14, 0)
    c.icon = W.Icon(c, m.icon, 13)
    c.icon:SetPoint("CENTER", c.iconBg)
    c.label = W.Text(c, "body", "text.primary")
    c.label:SetPoint("LEFT", c.iconBg, "RIGHT", 10, 0)
    c.label:SetText(L[m.label])
    c.label:SetWordWrap(false)
    c.now, c.target = Config:Depth(m.key)
    -- players see how many settings a module has; the plan-v2 depth target is a developer metric only
    c.depth = W.Text(c, "small", "text.muted", "RIGHT")
    c.depth:SetText(tostring(c.now or 0))
    if not m.locked then
        c.toggle = W:Toggle(c)
        c.toggle:SetPoint("RIGHT", -14, 0)
        c.toggle.onChange = function(_, v) ns:SetModuleEnabled(m.key, v) end
        c.depth:SetPoint("RIGHT", c.toggle, "LEFT", -10, 0)
    else
        c.depth:SetPoint("RIGHT", -14, 0)
    end
    c.label:SetPoint("RIGHT", c.depth, "LEFT", -8, 0)
    c.dot = W:Dot(c, 5)
    c.dot:SetPoint("TOPRIGHT", c.iconBg, "TOPRIGHT", 2, 2)
    c.sep = W:Separator(c)
    c.sep:SetPoint("TOPLEFT", 14, 0); c.sep:SetPoint("TOPRIGHT", -14, 0)

    function c:Paint()
        local on = m:IsEnabled()
        W.Color(self.bg, "bg.hover", self.hover and 0.9 or 0)
        W.TileColor(self.iconBg, self.icon, on and "accent.soft" or "bg.sunken", (not on) and 0.95 or nil)
        W.Color(self.icon, on and "accent.primary" or "text.muted")
        Skin:Text(self.label, "body", on and "text.primary" or "text.secondary")
        Skin:Text(self.depth, "small", "text.muted")
        local token = (m.state == "errored" and "state.danger") or (m.needsReload and "state.warning")
        if token and not m.locked then W.Color(self.dot, token); self.dot:Show() else self.dot:Hide() end
        if self.toggle then self.toggle:SetValue(m.db.enabled) end
    end
    Skin:Register(c, c.Paint)
    c:SetScript("OnEnter", function(self)
        self.hover = true
        self:Paint()
        W.ShowTooltip(self, L[m.label], L[m.desc] .. "\n\n" .. L.SETTINGS_COUNT:format(self.now or 0))
    end)
    c:SetScript("OnLeave", function(self) self.hover = false; self:Paint(); W.HideTooltip() end)
    c:SetScript("OnClick", function() PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON); Config:Show(m.key) end)
    return c
end

---------------------------------------------------------------- side cards (health, quick actions, news)
local function sideLine(parent, icon)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(22)
    r.icon = W.Icon(r, icon, 12)
    r.icon:SetPoint("LEFT", 2, 0)
    r.text = W.Text(r, "desc", "text.secondary")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.text:SetPoint("RIGHT")
    r.text:SetWordWrap(false)
    function r:Set(text, token)
        self.text:SetText(text)
        W.Color(self.icon, token or "text.muted")
        Skin:Text(self.text, "desc", "text.secondary")
    end
    return r
end

local function quickAction(parent, label, icon, func)
    local b = W:Button(parent, label, "secondary", icon)
    b:SetHeight(28)
    b.onClick = func
    return b
end

local NEWS = { L.HOME_NEW_1, L.HOME_NEW_2, L.HOME_NEW_3, L.HOME_NEW_4 }

local function buildSide(parent)
    local sd = CreateFrame("Frame", nil, parent)
    sd.health = W:Card(sd, L.HOME_HEALTH, "success")
    sd.health.lines = { sideLine(sd.health, "success"), sideLine(sd.health, "reload"), sideLine(sd.health, "bugs"),
        sideLine(sd.health, "lock"), sideLine(sd.health, "fonts") }
    sd.actions = W:Card(sd, L.HOME_QUICK, "presets")
    sd.actions.buttons = {
        quickAction(sd.actions, L.LAYOUT_MODE, "layout", function() Config.frame.header.layout.onClick() end),
        quickAction(sd.actions, L.TEST_FRAMES, "test", function() Config.frame.header.test.onClick() end),
        quickAction(sd.actions, L.PROFILES, "profiles", function() Config:Show("profiles") end),
        quickAction(sd.actions, L.PRESETS, "presets", function() Config:Show("presets") end),
    }
    sd.news = W:Card(sd, L.HOME_NEW, "bell")
    sd.news.lines = {}
    for i, key in ipairs(NEWS) do
        local fs = W.Text(sd.news, "desc", "text.secondary")
        fs:SetWordWrap(true)
        fs:SetJustifyH("LEFT")
        fs:SetText("·  " .. key)
        sd.news.lines[i] = fs
        Skin:Register(fs, function(t) Skin:Text(t, "desc", "text.secondary") end)
    end

    function sd:Refresh()
        local errored, reload = 0, 0
        for _, m in ipairs(ns.moduleList) do
            if m.state == "errored" then errored = errored + 1 end
            if m.needsReload then reload = reload + 1 end
        end
        local h = self.health.lines
        if errored > 0 then h[1]:Set(L.HOME_HEALTH_ERRORED:format(errored), "state.danger")
        else h[1]:Set(L.HOME_HEALTH_OK, "state.success") end
        if reload > 0 then h[2]:Set(L.HOME_HEALTH_RELOAD:format(reload), "state.warning")
        else h[2]:Set(L.HOME_HEALTH_NO_RELOAD, "state.success") end
        local bugs = ns.modules.Bugs
        local unique = bugs and bugs:IsEnabled() and bugs:Counts() or 0
        if unique > 0 then h[3]:Set(L.HOME_HEALTH_BUGS:format(unique), "state.warning")
        else h[3]:Set(L.HOME_HEALTH_NO_BUGS, "state.success") end
        if InCombatLockdown() then h[4]:Set(L.STATUS_COMBAT, "state.warning")
        else h[4]:Set(L.HOME_HEALTH_COMBAT_OK, "state.success") end
        -- which font the UI uses: Expressway found on this PC, Phoenix Font, or the Cyrillic / game fallback
        local src, from = Media:DefaultFontSource()
        local name = (src == "expressway" and L.FONT_SRC_EXPRESSWAY:format(from or "?")) or (src == "cyrillic" and L.FONT_SRC_CYRILLIC)
            or (src == "game" and L.FONT_SRC_GAME) or L.FONT_SRC_PHOENIX
        h[5]:Set(L.HOME_HEALTH_FONT:format(name), "accent.primary")
    end


    -- lays each card out for `width` (the column width) and sets its height
    function sd:Arrange(width)
        local inner = width - 32
        local hy = 40
        for _, line in ipairs(self.health.lines) do
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", 16, -hy); line:SetPoint("TOPRIGHT", -16, -hy)
            hy = hy + 24
        end
        self.health:SetHeight(hy + 10)
        local bw = (inner - 8) / 2
        for i, b in ipairs(self.actions.buttons) do
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 16 + col * (bw + 8), -(40 + row * 36))
            b:SetWidth(bw)
        end
        self.actions:SetHeight(40 + math.ceil(#self.actions.buttons / 2) * 36 + 8)
        local ny = 40
        for _, fs in ipairs(self.news.lines) do
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", 16, -ny)
            fs:SetWidth(inner)
            ny = ny + math.max(16, fs:GetStringHeight()) + 8
        end
        self.news:SetHeight(ny + 6)
    end
    return sd
end


local function statChip(parent, icon)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(10, 54)
    s.icon = W.Icon(s, icon, 18)
    s.icon:SetPoint("LEFT", 16, 0)
    s.value = W.Text(s, "number", "text.primary")
    s.value:SetPoint("TOPLEFT", s.icon, "TOPRIGHT", 12, 6)
    s.label = W.Text(s, "small", "text.muted")
    s.label:SetPoint("TOPLEFT", s.value, "BOTTOMLEFT", 0, -3)
    Skin:Register(s, function(self)
        Skin:Panel(self, "raised", { border = "border.subtle" })
        W.Color(self.icon, "accent.primary")
        Skin:Text(self.value, "number", "text.primary", 16)
        Skin:Text(self.label, "small", "text.muted")
    end)
    function s:Set(value, label) self.value:SetText(value); self.label:SetText(label:upper()) end
    return s
end

local function presetSwatch(parent, key)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(22, 22)
    b.ring = W.Texture(b, "BACKGROUND", 0, Media.textures.CIRCLE)
    b.ring:SetAllPoints()
    b.fill = W.Texture(b, "ARTWORK", 0, Media.textures.CIRCLE)
    b.fill:SetPoint("TOPLEFT", 3, -3); b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    function b:Paint()
        local p = Theme:PresetColors(key)
        self.fill:SetVertexColor(1, 1, 1, 1)
        local top, bottom = p.secondary, p.primary
        self.fill:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], 1), CreateColor(top[1], top[2], top[3], 1))
        local active = Theme.settings.preset == key
        if active then W.Color(self.ring, "text.primary") else W.Color(self.ring, "bg.base", self.hover and 0.6 or 0) end
    end
    Skin:Register(b, b.Paint)
    W.AttachTooltip(b, L["THEME_" .. key:upper()], L.THEME_SWATCH_TIP)
    b:HookScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    b:HookScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.DB:Set(ns:GetModule("General"), "theme.preset", key)
    end)
    return b
end

local function buildHero(parent)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(HERO_H)
    h.glow = W.Texture(h, "BACKGROUND", 1)
    h.glow:SetAllPoints()
    h.emblem = W.Texture(h, "BORDER", 0)
    h.emblem:SetSize(200, 200)
    h.emblem:SetPoint("RIGHT", 40, -10)
    ns.Icons:Brand(h.emblem, "emblem", 200)
    ns.EmblemFX:Attach(h.emblem, 200)
    h.logo = W.Texture(h, "ARTWORK", 0)
    h.logo:SetSize(300, 75)
    ns.Icons:Brand(h.logo, "logo", 300)
    h.logo:SetPoint("TOPLEFT", 14, -12)
    h.tagline = W.Text(h, "desc", "text.secondary")
    h.tagline:SetPoint("TOPLEFT", 26, -86)
    h.tagline:SetText(L.TAGLINE)
    h.accentLabel = W.Text(h, "heading", "text.muted")
    h.accentLabel:SetPoint("BOTTOMLEFT", 26, 20)
    h.accentLabel:SetText(L.ACCENT:upper())
    local prev
    h.swatches = {}
    for i, key in ipairs(PRESETS) do
        local s = presetSwatch(h, key)
        s:SetPoint("LEFT", prev or h.accentLabel, "RIGHT", i == 1 and 12 or 6, 0)
        h.swatches[i], prev = s, s
    end
    h.edit = W:Button(h, L.OPEN_EDIT_MODE, "primary", "editmode")
    h.edit:SetPoint("BOTTOMRIGHT", -20, 18)
    h.edit.onClick = function() Config.frame:Hide(); ns.EditMode:Open() end
    h.profiles = W:Button(h, L.PROFILES, "secondary", "profiles")
    h.profiles:SetPoint("RIGHT", h.edit, "LEFT", -8, 0)
    h.profiles.onClick = function() Config:Show("profiles") end
    Skin:Register(h, function(self)
        Skin:Panel(self, "raised", { border = "border.subtle" })
        local r, g, b = Theme:Color("accent.primary")
        self.glow:SetVertexColor(1, 1, 1, 1)
        self.glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.16), CreateColor(r, g, b, 0.02))
        W.Color(self.emblem, "accent.primary", 0.10)
        Skin:Text(self.tagline, "desc", "text.secondary", 12)
        Skin:Text(self.accentLabel, "heading", "text.muted")
    end)
    return h
end

---------------------------------------------------------------- this week (ns.Weekly)
local PIP = 14

local function weekCard(parent)
    local c = W:Card(parent, L.HOME_WEEK, "clock")
    c:SetHeight(WEEK_H)
    c.tracks = {}
    for i, track in ipairs(ns.Weekly.TRACKS) do
        local r = CreateFrame("Frame", nil, c)
        r:SetSize(10, 22)
        r:SetPoint("TOPLEFT", 16, -40 - (i - 1) * 26)
        r:SetPoint("RIGHT", c, "CENTER", 0, 0)
        r.label = W.Text(r, "body", "text.secondary")
        r.label:SetPoint("LEFT")
        r.label:SetWidth(96)
        r.label:SetText(L[track.label])
        r.pips = {}
        for p = 1, 3 do
            local t = W.Texture(r, "ARTWORK")
            t:SetSize(PIP, PIP)
            t:SetPoint("LEFT", r.label, "RIGHT", (p - 1) * (PIP + 6), 0)
            r.pips[p] = t
        end
        r.value = W.Text(r, "number", "text.primary")
        r.value:SetPoint("LEFT", r.pips[3], "RIGHT", 12, 0)
        r.track = track
        c.tracks[i] = r
    end
    c.rating = W.Text(c, "number", "text.primary", "RIGHT")
    c.rating:SetPoint("TOPRIGHT", -20, -40)
    c.ratingLabel = W.Text(c, "small", "text.muted", "RIGHT")
    c.ratingLabel:SetPoint("TOPRIGHT", c.rating, "BOTTOMRIGHT", 0, -4)
    c.ratingLabel:SetText(L.HOME_SEASON_RATING:upper())
    c.runs = W.Text(c, "small", "text.secondary", "RIGHT")
    c.runs:SetPoint("TOPRIGHT", c.ratingLabel, "BOTTOMRIGHT", 0, -10)
    Skin:Register(c, function(self)
        Skin:Text(self.rating, "number", "text.primary", 26)
        Skin:Text(self.ratingLabel, "small", "text.muted")
        Skin:Text(self.runs, "small", "text.secondary")
        for _, r in ipairs(self.tracks) do
            Skin:Text(r.label, "body", "text.secondary")
            Skin:Text(r.value, "number", "text.primary")
        end
        if self.data then self:Paint(self.data) end
    end)

    -- data: { tracks = { [key] = Weekly:Track() }, season = Weekly:Season() }; sample data for previews works too
    function c:Paint(data)
        self.data = data
        for _, r in ipairs(self.tracks) do
            local t = data.tracks[r.track.key] or { slots = {}, progress = 0, done = 0 }
            for p, pip in ipairs(r.pips) do
                local slot = t.slots[p]
                W.Color(pip, slot and slot.done and "accent.primary" or "bg.sunken", slot and 1 or 0.6)
            end
            local nextSlot = t.slots[t.done + 1]
            if nextSlot then
                r.value:SetFormattedText("%d / %d", math.min(t.progress, nextSlot.threshold), nextSlot.threshold)
                r.value:SetTextColor(Theme:Color("text.primary"))
            elseif #t.slots > 0 then
                r.value:SetText(L.HOME_VAULT_DONE)
                r.value:SetTextColor(Theme:Color("state.success"))
            else
                r.value:SetText("—")
                r.value:SetTextColor(Theme:Color("text.muted"))
            end
        end
        local s = data.season
        self.rating:SetText(s.rating > 0 and BreakUpLargeNumbers(math.floor(s.rating)) or "—")
        local color = s.rating > 0 and C_ChallengeMode.GetDungeonScoreRarityColor(s.rating)
        if color and color.GetRGB then self.rating:SetTextColor(color:GetRGB()) else
            self.rating:SetTextColor(Theme:Color("text.muted")) end
        if s.runs > 0 then
            self.runs:SetText(L.HOME_RUNS_WEEK:format(s.runs) .. "  ·  " .. L.HOME_BEST_WEEK:format(s.best))
        else
            self.runs:SetText(L.HOME_NO_RUNS)
        end
    end

    function c:Update()
        local data = { tracks = {}, season = ns.Weekly:Season() }
        for _, track in ipairs(ns.Weekly.TRACKS) do data.tracks[track.key] = ns.Weekly:Track(track) end
        self:Paint(data)
    end
    return c
end


local function build(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.scroll = W:Scroll(page)
    page.scroll:SetPoint("TOPLEFT")
    page.scroll:SetPoint("BOTTOMRIGHT", -10, 0)
    local child = page.scroll.child

    page.hero = buildHero(child)
    page.hero:SetPoint("TOPLEFT", PAD, -PAD)
    page.hero:SetPoint("TOPRIGHT", -PAD, -PAD)
    page.stats = { statChip(child, "addon"), statChip(child, "profiles"), statChip(child, "theme"), statChip(child, "fonts") }
    -- Great Vault and Mythic+ only exist on retail (ns.FEATURES)
    if ns:Supports("vault") then
        page.week = weekCard(child)
        local function weekly() if page:IsVisible() then page.week:Update() end end
        ns.Events:On("WEEKLY_REWARDS_UPDATE", page.week, weekly)
        ns.Events:On("CHALLENGE_MODE_MAPS_UPDATE", page.week, weekly)
    end
    page.side = buildSide(child)
    page.side:SetSize(1, 1)
    page.side:SetPoint("TOPLEFT")
    for _, k in ipairs({ "health", "actions", "news" }) do page.side[k]:SetParent(child) end

    -- one card per rail group, its module rows inside
    page.groupCards, page.cards = {}, {}
    for _, g in ipairs(Config:Groups()) do
        local gc
        for _, key in ipairs(g.entries) do
            local m = ns.modules[key]
            if m and not m.hidden and not m.locked then
                if not gc then
                    gc = W:Card(child, L[g.label] or g.label, g.icon)
                    gc.group, gc.rows = g.key, {}
                    gc.count = W:Badge(gc, "", "text.muted")
                    gc.count:SetPoint("LEFT", gc.header, "RIGHT", 8, 0)
                    gc.open = W:IconButton(gc, "chevron-right", 20, L[g.label] or g.label, L.HOME_OPEN_GROUP)
                    gc.open:SetPoint("TOPRIGHT", -10, -10)
                    local gk = g.key
                    gc.open.onClick = function() Config:OpenGroup(gk) end
                    page.groupCards[#page.groupCards + 1] = gc
                end
                local c = moduleCard(gc, m)
                c.group = g.key
                gc.rows[#gc.rows + 1] = c
                page.cards[#page.cards + 1] = c
            end
        end
    end
    -- filter: every rail group that has a module, plus "Off" (modules switched off)
    local filters = { { value = "all", label = L.FILTER_ALL } }
    for _, gc in ipairs(page.groupCards) do
        for _, g in ipairs(Config:Groups()) do
            if g.key == gc.group then filters[#filters + 1] = { value = g.key, label = L[g.label], icon = g.icon } end
        end
    end
    filters[#filters + 1] = { value = "off", label = L.FILTER_OFF }
    page.filter = W:Chips(child, filters)
    page.filter:SetValue("all")
    page.filter.onChange = function() page:Layout() end

    local function passes(c)
        local f = page.filter:GetValue()
        if f == "off" then return not c.module:IsEnabled() end
        return f == "all" or c.group == f
    end

    -- v4 has no dock: the side cards are part of the columns
    function page:SetDocked() self.docked = false; self:Layout() end

    function page:Layout()
        local w = self.scroll:GetWidth() - PAD * 2
        if w <= 0 then return end
        local y = PAD + HERO_H + GAP
        local n = #self.stats
        local sw = (w - GAP * (n - 1)) / n
        for i, s in ipairs(self.stats) do
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", child, "TOPLEFT", PAD + (i - 1) * (sw + GAP), -y)
            s:SetWidth(sw)
        end
        y = y + 54 + GAP + 4
        self.filter:ClearAllPoints()
        self.filter:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -y)
        self.filter:SetWidth(w)
        self.filter:Arrange()
        y = y + self.filter:GetHeight() + GAP
        local cols = w >= THREE_AT and 3 or (w >= TWO_AT and 2 or 1)
        local cw = math.floor((w - (cols - 1) * GAP) / cols)
        self.side:Arrange(cw)
        -- the cards, in order; each goes into the shortest column (masonry: no gaps under short cards)
        local blocks = {}
        if self.week then blocks[#blocks + 1] = self.week end
        blocks[#blocks + 1] = self.side.health
        for _, gc in ipairs(self.groupCards) do
            local ry, k = 40, 0
            for _, c in ipairs(gc.rows) do
                if passes(c) then
                    c:ClearAllPoints()
                    c:SetPoint("TOPLEFT", gc, "TOPLEFT", 0, -ry)
                    c:SetPoint("TOPRIGHT", gc, "TOPRIGHT", 0, -ry)
                    c.sep:SetShown(k > 0)
                    c:Show()
                    ry, k = ry + ROW_H, k + 1
                else
                    c:Hide()
                end
            end
            gc.count:Set(tostring(#gc.rows), "text.muted")
            gc:SetHeight(ry + 8)
            gc:SetShown(k > 0)
            if k > 0 then blocks[#blocks + 1] = gc end
        end
        blocks[#blocks + 1] = self.side.actions
        blocks[#blocks + 1] = self.side.news
        local colY = {}
        for i = 1, cols do colY[i] = y end
        for _, b in ipairs(blocks) do
            local col = 1
            for i = 2, cols do if colY[i] < colY[col] then col = i end end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", child, "TOPLEFT", PAD + (col - 1) * (cw + GAP), -colY[col])
            b:SetWidth(cw)
            b:Show()
            colY[col] = colY[col] + b:GetHeight() + GAP
        end
        local bottom = y
        for i = 1, cols do bottom = math.max(bottom, colY[i]) end
        child:SetHeight(bottom - GAP + PAD)
        self.scroll:UpdateBar()
    end

    function page:Refresh()
        local on, total = 0, 0
        for _, m in ipairs(ns.moduleList) do
            if not m.locked and not m.hidden then
                total = total + 1
                if m:IsEnabled() then on = on + 1 end
            end
        end
        self.stats[1]:Set(L.MODULES_ON_COUNT:format(on, total), L.MODULES_ENABLED)
        self.stats[2]:Set(ns.DB:GetProfileName(), L.ACTIVE_PROFILE)
        self.stats[3]:Set(L["THEME_" .. Theme.settings.preset:upper()], L.THEME)
        local src = Media:DefaultFontSource()
        self.stats[4]:Set(src == "expressway" and "Expressway" or (src == "phoenix" and "Phoenix Font")
            or (src == "cyrillic" and "PT Sans Narrow") or L.FONT_SRC_GAME, L.HOME_FONT_STAT)
        for _, c in ipairs(self.cards) do c:Paint() end
        if self.week then
            ns.Weekly:Request()
            self.week:Update()
        end
        for _, s in ipairs(self.hero.swatches) do s:Paint() end
        self.side:Refresh()
        self:Layout()
    end
    ns.Events:Listen("PUI_THEME_CHANGED", page, function() if page:IsShown() then page:Refresh() end end)
    page.scroll:HookScript("OnSizeChanged", function() page:Layout() end)
    return page
end

Config:RegisterPage("home", build, { label = "HOME", icon = "home" })
