local _, ns = ...
local L = ns.L
local W, Theme, Skin, Media = ns.Widgets, ns.Theme, ns.Skin, ns.Media
local Config = ns.Config

--[[ Home: hero banner, quick theme switch, live stats, this week (Great Vault and Mythic+ season)
    and a grid of module cards. ]]
local PAD, GAP, CARD_MIN_W, CARD_H, WEEK_H = 24, 12, 236, 108, 132
local PRESETS = { "ember", "frost", "fel", "arcane", "class" }

local function moduleCard(parent, m)
    local c = CreateFrame("Button", nil, parent)
    c:SetHeight(CARD_H)
    c.module = m
    c.iconBg = W.Texture(c, "ARTWORK", 0, Media.textures.ROUNDED)
    c.iconBg:SetSize(34, 34)
    c.iconBg:SetPoint("TOPLEFT", 14, -14)
    c.icon = W.Icon(c, m.icon, 18)
    c.icon:SetPoint("CENTER", c.iconBg)
    c.label = W.Text(c, "body", "text.primary")
    c.label:SetPoint("TOPLEFT", c.iconBg, "TOPRIGHT", 10, -2)
    c.label:SetPoint("RIGHT", -60, 0)
    c.label:SetText(L[m.label])
    c.cat = W.Text(c, "small", "text.muted")
    c.cat:SetPoint("TOPLEFT", c.label, "BOTTOMLEFT", 0, -3)
    c.cat:SetText(L["CAT_" .. m.category:upper()]:upper())
    c.desc = W.Text(c, "desc", "text.secondary")
    c.desc:SetWordWrap(true)
    c.desc:SetMaxLines(2)
    c.desc:SetJustifyV("TOP")
    c.desc:SetPoint("TOPLEFT", c.iconBg, "BOTTOMLEFT", 0, -10)
    c.desc:SetPoint("BOTTOMRIGHT", -14, 10)
    c.desc:SetText(L[m.desc])
    if not m.locked then
        c.toggle = W:Toggle(c)
        c.toggle:SetPoint("TOPRIGHT", -14, -16)
        c.toggle.onChange = function(_, v) ns:SetModuleEnabled(m.key, v) end
    end
    c.dot = W:Dot(c, 6)
    c.dot:SetPoint("TOPRIGHT", c.iconBg, "TOPRIGHT", 2, 2)

    function c:Paint()
        Skin:Panel(self, "raised", { border = self.hover and "accent.primary" or "border.subtle", sheen = 24 })
        local on = m:IsEnabled()
        W.Color(self.iconBg, on and "accent.soft" or "bg.sunken", 0.95)
        W.Color(self.icon, on and "accent.primary" or "text.muted")
        Skin:Text(self.label, "body", "text.primary")
        Skin:Text(self.cat, "small", "text.muted")
        Skin:Text(self.desc, "desc", "text.secondary")
        local token = (m.state == "errored" and "state.danger") or (m.needsReload and "state.warning") or (on and "state.success")
        if token and not m.locked then W.Color(self.dot, token); self.dot:Show() else self.dot:Hide() end
        if self.toggle then self.toggle:SetValue(m.db.enabled) end
    end
    Skin:Register(c, c.Paint)
    c:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
    c:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
    c:SetScript("OnClick", function() PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON); Config:Show(m.key) end)
    return c
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
    h:SetHeight(168)
    h.glow = W.Texture(h, "BACKGROUND", 1)
    h.glow:SetAllPoints()
    h.emblem = W.Texture(h, "BORDER", 0)
    h.emblem:SetSize(220, 220)
    h.emblem:SetPoint("RIGHT", 40, -10)
    ns.Icons:Brand(h.emblem, "emblem", 220)
    h.logo = W.Texture(h, "ARTWORK", 0)
    h.logo:SetSize(336, 84)
    ns.Icons:Brand(h.logo, "logo", 336)
    h.logo:SetPoint("TOPLEFT", 14, -12)
    h.tagline = W.Text(h, "desc", "text.secondary")
    h.tagline:SetPoint("TOPLEFT", 28, -96)
    h.tagline:SetText(L.TAGLINE)
    h.accentLabel = W.Text(h, "heading", "text.muted")
    h.accentLabel:SetPoint("BOTTOMLEFT", 28, 22)
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
    page.stats = { statChip(child, "addon"), statChip(child, "profiles"), statChip(child, "theme") }
    page.week = weekCard(child)
    local function weekly() if page:IsVisible() then page.week:Update() end end
    ns.Events:On("WEEKLY_REWARDS_UPDATE", page.week, weekly)
    ns.Events:On("CHALLENGE_MODE_MAPS_UPDATE", page.week, weekly)

    page.gridTitle = W.Text(child, "heading", "text.muted")
    page.gridTitle:SetText(L.MODULES:upper())
    Skin:Register(page.gridTitle, function(fs) Skin:Text(fs, "heading", "text.muted") end)
    page.cards = {}
    for _, m in ipairs(ns.moduleList) do
        if not m.hidden and not m.locked then page.cards[#page.cards + 1] = moduleCard(child, m) end
    end

    function page:Layout()
        local w = self.scroll:GetWidth() - PAD * 2
        if w <= 0 then return end
        local y = PAD + 168 + GAP
        local sw = (w - GAP * 2) / 3
        for i, s in ipairs(self.stats) do
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", child, "TOPLEFT", PAD + (i - 1) * (sw + GAP), -y)
            s:SetWidth(sw)
        end
        y = y + 54 + GAP
        self.week:ClearAllPoints()
        self.week:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -y)
        self.week:SetWidth(w)
        y = y + WEEK_H + 22
        self.gridTitle:ClearAllPoints()
        self.gridTitle:SetPoint("TOPLEFT", child, "TOPLEFT", PAD, -y)
        y = y + 22
        local cols = math.max(2, math.floor((w + GAP) / (CARD_MIN_W + GAP)))
        local cw = (w - (cols - 1) * GAP) / cols
        for i, c in ipairs(self.cards) do
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", child, "TOPLEFT", PAD + col * (cw + GAP), -(y + row * (CARD_H + GAP)))
            c:SetWidth(cw)
        end
        local rows = math.ceil(#self.cards / cols)
        child:SetHeight(y + rows * (CARD_H + GAP) + PAD)
        self.scroll:UpdateBar()
    end

    function page:Refresh()
        local on, total = 0, 0
        for _, m in ipairs(ns.moduleList) do
            if not m.locked then
                total = total + 1
                if m:IsEnabled() then on = on + 1 end
            end
        end
        self.stats[1]:Set(("%d / %d"):format(on, total), L.MODULES_ENABLED)
        self.stats[2]:Set(ns.DB:GetProfileName(), L.ACTIVE_PROFILE)
        self.stats[3]:Set(L["THEME_" .. Theme.settings.preset:upper()], L.THEME)
        for _, c in ipairs(self.cards) do c:Paint() end
        ns.Weekly:Request()
        self.week:Update()
        for _, s in ipairs(self.hero.swatches) do s:Paint() end
    end
    ns.Events:Listen("PUI_THEME_CHANGED", page, function() if page:IsShown() then page:Refresh() end end)
    return page
end

Config:RegisterPage("home", build)
