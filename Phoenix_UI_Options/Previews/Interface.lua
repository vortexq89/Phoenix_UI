local _, ns = ...
local L, P = ns.L, ns.Previews
local W, Skin, Media, Theme = ns.Widgets, ns.Skin, ns.Media, ns.Theme

--[[ Previews for the minimap, item level labels, window skins and the AFK screen. Fixed sample data;
    each follows its module's saved settings. ]]

-- "Off" caption under a sample whose feature is turned off.
local function caption(parent, anchor, text)
    local fs = P.Caption(parent, text)
    fs:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
    return fs
end

---------------------------------------------------------------- minimap
-- Element glyphs around the map edge: Blizzard's buttons the page can tuck away.
local ELEMENTS = {
    { key = "tracking", icon = "search", point = "TOPLEFT", x = 4, y = -4 },
    { key = "mail", icon = "mail", point = "TOPLEFT", x = 4, y = -24 },
    { key = "calendar", icon = "layout", point = "TOPRIGHT", x = -26, y = -4 },
    { key = "difficulty", icon = "heart", point = "TOPLEFT", x = 24, y = -4 },
    { key = "expansion", icon = "maps", point = "BOTTOMLEFT", x = 4, y = 4 },
    { key = "compartment", icon = "cog", point = "TOPRIGHT", x = -4, y = -24 },
}

P:Register("minimap", {
    module = "Minimap",
    height = 190,
    build = function(stage, m)
        local map = CreateFrame("Frame", nil, stage)
        map:SetSize(130, 130)
        map:SetPoint("CENTER", -40, -4)
        map.mask = map:CreateMaskTexture()
        map.mask:SetAllPoints()
        local layers = {}
        local function layer(tex, r, g, b, a, w, h, x, y)
            local t = map:CreateTexture(nil, "ARTWORK", nil, #layers % 7)
            t:SetTexture(tex)
            t:SetVertexColor(r, g, b, a)
            if w then t:SetSize(w, h); t:SetPoint("CENTER", x, y) else t:SetAllPoints() end
            layers[#layers + 1] = t
            return t
        end
        -- terrain: ground, two meadows, a lake and a road
        layer(Media.textures.WHITE, 0.16, 0.19, 0.13, 1)
        layer(Media.textures.CIRCLE, 0.24, 0.33, 0.18, 0.9, 90, 70, -26, 24)
        layer(Media.textures.CIRCLE, 0.28, 0.36, 0.2, 0.8, 70, 80, 34, -30)
        layer(Media.textures.CIRCLE, 0.15, 0.28, 0.4, 0.95, 46, 34, 30, 30)
        local road = layer(Media.textures.WHITE, 0.55, 0.47, 0.33, 0.8, 150, 5, 0, -4)
        road:SetRotation(math.rad(-24))
        local arrow = map:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
        arrow:SetSize(24, 24)
        arrow:SetPoint("CENTER", -4, -4)
        -- the visible band (the whole map unless rectangular): border and texts sit on it, as in game
        local band = CreateFrame("Frame", nil, map)
        band:SetFrameLevel(map:GetFrameLevel() + 2)
        map.coords = P.Text(band, "OVERLAY")
        map.clock = P.Text(stage, "OVERLAY")
        map.zone = P.Text(stage, "OVERLAY")
        map.zone:SetPoint("BOTTOM", band, "TOP", 0, 6)
        map.clock:SetPoint("TOP", band, "BOTTOM", 0, -5)
        map.elements = {}
        for _, e in ipairs(ELEMENTS) do
            local g = ns.Icons:Create(band, e.icon, 12, "text.secondary")
            g:SetPoint(e.point, band, e.point, e.x, e.y)
            map.elements[e.key] = g
        end
        map.zoom = P.Text(band, "OVERLAY")
        map.zoom:SetPoint("BOTTOMRIGHT", -6, 4)
        -- the button bin: its corner glyph and the open flyout with a few sample addon buttons
        local binBtn = CreateFrame("Frame", nil, band)
        binBtn:SetSize(18, 18)
        binBtn:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", -22, 4)
        binBtn:SetFrameLevel(band:GetFrameLevel() + 2)
        binBtn.icon = ns.Icons:Create(binBtn, "bin", 11, "accent.primary")
        binBtn.icon:SetPoint("CENTER")
        local fly = CreateFrame("Frame", nil, stage)
        fly:SetPoint("TOPLEFT", map, "TOPRIGHT", 14, 0)
        fly.cells = {}
        local SAMPLE = { "items", "maps", "chat", "bugs", "tracker", "sound" }
        for i, icon in ipairs(SAMPLE) do
            local c = CreateFrame("Frame", nil, fly)
            c.icon = ns.Icons:Create(c, icon, 12, "text.secondary")
            c.icon:SetPoint("CENTER")
            fly.cells[i] = c
        end
        return function()
            local db = m.db
            local shape = m:Shape()
            local round = shape == "ROUND"
            map.mask:SetTexture(m.MaskFor(shape, db.rectHeight) or Media.textures.CIRCLE,
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            for _, t in ipairs(layers) do
                t:RemoveMaskTexture(map.mask)
                t:AddMaskTexture(map.mask)
            end
            local inset = m.BandInset(shape, db.rectHeight, map:GetHeight())
            band:ClearAllPoints()
            band:SetPoint("TOPLEFT", 0, -inset)
            band:SetPoint("BOTTOMRIGHT", 0, inset)
            if round then
                Skin:BorderSpec(band, { style = "none", shadow = "none" })
            else
                Skin:BorderSpec(band, db.border, "border.black")
            end
            Skin:TextSpec(map.coords, db.coordsText, "number", "text.primary")
            Skin:Place(map.coords, band, db.coordsText)
            map.coords:SetText(m.FormatCoords(0.482, 0.617, db.coordDecimals))
            map.coords:SetShown(db.coords)
            Skin:TextSpec(map.zone, db.zone, "heading", db.zonePvP and "state.success" or "accent.primary")
            map.zone:SetText(L.PREVIEW_ZONE)
            map.zone:SetShown(db.zoneText)
            Skin:TextSpec(map.clock, db.clockText, "number", "text.primary")
            map.clock:SetText("14:32")
            map.clock:SetShown(db.clock)
            for key, g in pairs(map.elements) do g:SetShown(db[key] ~= false) end
            Skin:Text(map.zoom, "number", "text.secondary", 12, "OUTLINE")
            map.zoom:SetText("+ -")
            map.zoom:SetShown(db.zoomButtons)
            binBtn:SetShown(db.bin)
            fly:SetShown(db.bin)
            Skin:Panel(binBtn, "raised", { border = "border.default" })
            Skin:Panel(fly, "raised", { border = "border.default" })
            local cols = math.max(1, db.binColumns or 4)
            local size = math.floor((db.binSize or 28) * 22 / 28 + 0.5)
            for i, c in ipairs(fly.cells) do
                c:SetSize(size, size)
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", 6 + ((i - 1) % cols) * (size + 2), -6 - math.floor((i - 1) / cols) * (size + 2))
                Skin:Panel(c, "sunken", { border = "border.subtle" })
            end
            fly:SetSize(12 + math.min(#fly.cells, cols) * (size + 2) - 2, 12 + math.ceil(#fly.cells / cols) * (size + 2) - 2)
        end
    end,
})

---------------------------------------------------------------- item level
local GEAR = { { 2, 684, 4 }, { 4, 678, 4 }, { 7, 671, 3 }, { 5, 688, 4 }, { 10, 665, 3 }, { 12, 691, 5 } }
local BAGS = { { 1, 674, 3 }, { 8, 659, 2 }, { 11, 680, 4 }, { 6, 662, 3 } }

-- Stats panel sample: { label, value } rows under two category titles.
local STAT_ROWS = { { "STAT_CRITICAL_STRIKE", "24%" }, { "STAT_HASTE", "18%" }, { "STAT_MASTERY", "41%" },
    { "STAT_VERSATILITY", "9%" } }

local function statsSample(stage)
    local f = CreateFrame("Frame", nil, stage)
    f:SetSize(120, 22 + #STAT_ROWS * 15)
    f.title = P.Text(f, "OVERLAY")
    f.title:SetPoint("TOP", 0, -4)
    f.title:SetText(_G.STAT_CATEGORY_ENHANCEMENTS or L.ITEMLEVEL_STATS)
    f.titleBg = f:CreateTexture(nil, "BACKGROUND")
    f.titleBg:SetPoint("TOPLEFT"); f.titleBg:SetPoint("TOPRIGHT"); f.titleBg:SetHeight(20)
    f.rows = {}
    for i, s in ipairs(STAT_ROWS) do
        local r = CreateFrame("Frame", nil, f)
        r:SetSize(120, 15)
        r:SetPoint("TOP", 0, -20 - (i - 1) * 15)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetTexture(Media.textures.WHITE)
        r.label = P.Text(r, "OVERLAY"); r.label:SetPoint("LEFT", 4, 0)
        r.label:SetText(tostring(_G[s[1]] or s[1]))
        r.value = P.Text(r, "OVERLAY"); r.value:SetPoint("RIGHT", -4, 0)
        r.value:SetText(s[2])
        f.rows[i] = r
    end
    return f
end

local function paintStats(f, on)
    if on then
        f.titleBg:SetTexture(Media.textures.WHITE); f.titleBg:SetVertexColor(Theme:Color("bg.base"))
        Skin:Text(f.title, "heading", "accent.primary", 12)
    else
        f.titleBg:SetTexture(Media.textures.WHITE); f.titleBg:SetVertexColor(0.25, 0.2, 0.1, 0.9)
        f.title:SetFontObject(GameFontNormal)
    end
    for i, r in ipairs(f.rows) do
        r.bg:SetShown(i % 2 == 0)
        if on then
            r.bg:SetVertexColor(Theme:Color("bg.raised"))
            Skin:Text(r.label, "body", "text.secondary", 11); Skin:Text(r.value, "number", "text.primary", 11)
        else
            r.bg:SetVertexColor(0.3, 0.3, 0.3, 0.5)
            r.label:SetFontObject(GameFontNormalSmall); r.value:SetFontObject(GameFontHighlightSmall)
        end
    end
end

P:Register("itemlevel", {
    module = "ItemLevel",
    height = 120,
    width = 680,
    build = function(stage, m)
        local function slots(list, size)
            local holder = CreateFrame("Frame", nil, stage)
            holder:SetSize(#list * (size + 6) - 6, size)
            holder.items = {}
            for i, s in ipairs(list) do
                local b = P.Icon(holder, size, s[1])
                b:SetPoint("LEFT", (i - 1) * (size + 6), 0)
                Skin:Icon(b.tex)
                b.level = P.Text(b, "OVERLAY")
                b.extra = P.Text(b, "OVERLAY")
                b.extra:SetPoint("BOTTOMLEFT", 1, 1); b.extra:SetPoint("BOTTOMRIGHT", -1, 1)
                b.sample = s
                holder.items[i] = b
            end
            return holder
        end
        local gear, bags = slots(GEAR, 38), slots(BAGS, 34)
        gear.caption = caption(stage, gear, L.ITEMLEVEL_CHARACTER)
        bags.caption = caption(stage, bags, L.ITEMLEVEL_BAGS)
        local stats = statsSample(stage)
        stats.caption = caption(stage, stats, L.ITEMLEVEL_STATS)
        return function(self)
            local db = m.db
            local w = self:GetWidth()
            gear:ClearAllPoints(); gear:SetPoint("CENTER", self, "LEFT", w * 0.27, 8)
            bags:ClearAllPoints(); bags:SetPoint("CENTER", self, "LEFT", w * 0.6, 8)
            stats:ClearAllPoints(); stats:SetPoint("CENTER", self, "LEFT", w * 0.88, 8)
            paintStats(stats, db.statsPanel)
            for gi, group in ipairs({ { gear, db.character }, { bags, db.bags } }) do
                local holder, on = group[1], group[2]
                holder:SetAlpha(on and 1 or 0.35)
                for i, b in ipairs(holder.items) do
                    Skin:Border(b, "border.black")
                    if on then
                        m:StyleLabel(b.level, b)
                        b.level:SetTextColor(m.ColorFor(b.sample[3]))
                        b.level:SetText(b.sample[2])
                    else
                        b.level:SetText("")
                    end
                    -- sample details on two worn items: an upgrade track and an empty socket
                    local parts = {}
                    if on and gi == 1 and db.track and i == 1 then parts[#parts + 1] = L.ITEMLEVEL_SAMPLE_TRACK end
                    if on and gi == 1 and db.gems and i == 3 then parts[#parts + 1] = "|cffff4d5e" .. L.ITEMLEVEL_NO_GEM .. "|r" end
                    Skin:Text(b.extra, "small", "text.secondary", math.max(8, db.size - 3), "OUTLINE")
                    b.extra:SetText(table.concat(parts, " · "))
                end
            end
        end
    end,
})

---------------------------------------------------------------- bags
-- { icon index, item level (0 = none), quality, count, upgrade, category, flag } with flag "new" | "junk" | "boe".
local BAG_ITEMS = { { 2, 701, 4, nil, true, "equipment", "new" }, { 6, 0, 1, 20, nil, "consumables" },
    { 9, 688, 3, nil, nil, "equipment", "boe" }, { 3, 0, 2, 5, nil, "reagents" }, { 11, 714, 4, nil, true, "equipment" },
    { 5, 0, 1, 200, nil, "reagents" }, { 8, 0, 0, 1, nil, "junk", "junk" }, { 1, 0, 3, 3, nil, "consumables" },
    { 12, 695, 4, nil, nil, "equipment" }, { 4, 0, 1, 12, nil, "consumables" }, { 7, 0, 0, 8, nil, "junk", "junk" },
    { 10, 0, 1, 1, nil, "quest" } }
local PREVIEW_COLS, MAX_W = 8, 520

local function bagSlot(win)
    local b = CreateFrame("Frame", nil, win)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(Media.textures.WHITE)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.level = P.Text(b, "OVERLAY")
    b.level:SetPoint("TOPRIGHT", -1, -2)
    b.count = P.Text(b, "OVERLAY")
    b.bind = P.Text(b, "OVERLAY")
    b.bind:SetPoint("BOTTOMLEFT", 2, 2)
    b.arrow = ns.Icons:Create(b, "arrow-up", 14, "state.success")
    b.arrow:SetPoint("TOPLEFT", 1, -1)
    b.coin = ns.Icons:Create(b, "gold", 12, "state.warning")
    b.coin:SetPoint("TOPLEFT", 2, -2)
    b.glow = CreateFrame("Frame", nil, b)
    b.glow:SetAllPoints()
    return b
end

-- Preview sections: categories in the saved order (sorted like the window), or one block.
local function bagSections(m, items)
    local db, sections = m.db, {}
    if db.view ~= "categories" then return { { list = items } } end
    local by = {}
    for _, b in ipairs(items) do
        local cat = b.sample[6]
        if b.sample[7] == "new" and not m:CategoryHidden("new") then cat = "new" end
        if m:CategoryHidden(cat) then cat = "other" end
        by[cat] = by[cat] or {}
        table.insert(by[cat], b)
    end
    for _, key in ipairs(m:CategoryOrder()) do
        if by[key] then
            table.sort(by[key], function(x, y)
                local sx, sy = x.sample, y.sample
                if db.catSort == "quality" and sx[3] ~= sy[3] then return sx[3] > sy[3] end
                if db.catSort == "ilvl" and sx[2] ~= sy[2] then return sx[2] > sy[2] end
                return sx[1] < sy[1]
            end)
            sections[#sections + 1] = { label = m.CAT_LABEL[key], list = by[key] }
        end
    end
    return sections
end

local function paintBagSlot(b, db, il)
    local s = b.sample
    W.Color(b.bg, db.skin and "bg.sunken" or "bg.raised")
    if db.skin then Skin:IconZoom(b.tex, 0.08) else b.tex:SetTexCoord(0, 1, 0, 1) end
    b.tex:SetDesaturated(db.junkDim and s[7] == "junk")
    local r, g, bl = C_Item.GetItemQualityColor(s[3])
    local spec = {}
    for k, v in pairs(db.slotBorder) do spec[k] = v end
    if db.skin and db.quality and s[3] >= 2 and r then spec.color = { r = r, g = g, b = bl } end
    if db.skin then Skin:BorderSpec(b, spec, "border.black")
    else Skin:BorderSpec(b, { style = "solid", size = 1 }, "border.black") end
    local showLevel = il and il.db.bags and s[2] > 0
    if showLevel then
        Skin:Text(b.level, "number", nil, il.db.size)
        if il.db.qualityColor and r then b.level:SetTextColor(r, g, bl) else b.level:SetTextColor(1, 1, 1) end
    end
    b.level:SetText(showLevel and s[2] or "")
    Skin:TextSpec(b.count, db.count, "number")
    Skin:Place(b.count, b, db.count)
    b.count:SetText(s[4] and s[4] > 1 and s[4] or "")
    b.arrow:SetShown(db.upgrade and s[5] or false)
    b.coin:SetShown(db.junk and s[7] == "junk")
    Skin:Text(b.bind, "small", "text.secondary", 9, "OUTLINE")
    b.bind:SetText(db.bind and s[7] == "boe" and L.BAGS_BOE or "")
    local glow = s[7] == "new" and db.newGlow == "phoenix"
    if glow then Skin:BorderSpec(b.glow, { style = "ember", size = 1 }) end
    b.glow:SetShown(glow)
end

P:Register("bags", {
    module = "Bags",
    height = 230,
    build = function(stage, m)
        local il = ns.modules.ItemLevel
        local win = CreateFrame("Frame", nil, stage)
        win:SetPoint("CENTER")
        win.title = P.Text(win, "OVERLAY")
        win.title:SetPoint("TOPLEFT", 10, -10)
        win.title:SetText(L.BAGS)
        win.search = CreateFrame("Frame", nil, win)
        win.search:SetSize(110, 16)
        win.search:SetPoint("TOPRIGHT", -34, -8)
        win.searchText = P.Text(win.search, "OVERLAY")
        win.searchText:SetPoint("LEFT", 6, 0)
        win.searchText:SetText(SEARCH)
        win.sort = ns.Icons:Create(win, "layout", 14, "text.secondary")
        win.sort:SetPoint("TOPRIGHT", -12, -9)
        win.money = P.Text(win, "OVERLAY")
        win.money:SetPoint("BOTTOMRIGHT", -10, 8)
        win.money:SetText("12,480 g")
        win.free = P.Text(win, "OVERLAY")
        win.free:SetPoint("BOTTOMLEFT", 10, 8)
        win.free:SetText(L.BAGS_FREE:format(23))
        -- the bag bar beside the title (the second bag "hovered": its slots stay bright)
        win.bagBar = {}
        for i = 1, 5 do
            local t = win:CreateTexture(nil, "ARTWORK")
            t:SetSize(16, 16)
            t:SetPoint("LEFT", win.title, "RIGHT", 10 + (i - 1) * 19, 0)
            t:SetTexture(P.SAMPLE.icons[(i + 2) % #P.SAMPLE.icons + 1])
            win.bagBar[i] = t
        end
        win.items, win.heads = {}, {}
        for i, s in ipairs(BAG_ITEMS) do
            local b = bagSlot(win)
            b.tex:SetTexture(P.SAMPLE.icons[(s[1] - 1) % #P.SAMPLE.icons + 1])
            b.sample = s
            win.items[i] = b
        end
        local function head(i)
            if not win.heads[i] then win.heads[i] = P.Text(win, "OVERLAY") end
            return win.heads[i]
        end
        return function()
            local db = m.db
            local phoenix = m:UsesWindow()
            local size = phoenix and math.min(db.slotSize, 40) or 36
            local gap = phoenix and db.spacing or 4
            local cols = phoenix and math.min(db.columns, PREVIEW_COLS) or 6
            local sections = bagSections(m, win.items)
            local y = 32
            for i, sec in ipairs(sections) do
                local fs = head(i)
                if sec.label then
                    Skin:Text(fs, "small", "text.muted", 10)
                    fs:SetText(("%s  %d"):format(sec.label, #sec.list))
                    fs:ClearAllPoints()
                    fs:SetPoint("TOPLEFT", 10, -y)
                    fs:Show()
                    y = y + 15
                else
                    fs:Hide()
                end
                for n, b in ipairs(sec.list) do
                    b:SetSize(size, size)
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", 10 + ((n - 1) % cols) * (size + gap), -y - math.floor((n - 1) / cols) * (size + gap))
                end
                y = y + math.ceil(#sec.list / cols) * (size + gap) + 4
            end
            for i = #sections + 1, #win.heads do win.heads[i]:Hide() end
            local width = math.min(MAX_W, cols * (size + gap) - gap + 20)
            win:SetSize(math.max(width, 250), y + 24)
            if db.skin then
                Skin:Backdrop(win, db.backdrop, "bg.base")
                Skin:BorderSpec(win, db.border, "border.strong")
                Skin:TextSpec(win.title, db.title, "heading", "accent.primary")
            else
                Skin:Panel(win, "raised", { border = "border.default" })
                Skin:Text(win.title, "body", "text.secondary", 12)
            end
            win.search:SetShown(phoenix and db.search)
            Skin:Panel(win.search, "sunken", { border = "border.subtle" })
            Skin:Text(win.searchText, "small", "text.muted", 10)
            win.sort:SetShown(phoenix and db.sortButton)
            Skin:Text(win.money, "small", "text.secondary", 11)
            Skin:Text(win.free, "small", "text.secondary", 11)
            win.money:SetShown(not phoenix or db.footer)
            win.free:SetShown(phoenix and db.freeCount)
            for _, b in ipairs(win.items) do paintBagSlot(b, db, il) end
            local bar = phoenix and db.bagBar
            for _, t in ipairs(win.bagBar) do t:SetShown(bar) end
        end
    end,
})

---------------------------------------------------------------- window skins
-- A character-style window (title strip, close button, inset, tabs) beside the three dialogs, each in the
-- Phoenix look when its switch is on and in a stock-like look when off.
local function skinSample(stage, title, buttons, w)
    local f = CreateFrame("Frame", nil, stage)
    f:SetSize(w or 130, 30 + buttons * 22)
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    f.bg:SetAllPoints()
    f.title = P.Text(f, "OVERLAY")
    f.title:SetPoint("TOP", 0, -8)
    f.title:SetText(title)
    f.buttons = {}
    for i = 1, buttons do
        local b = CreateFrame("Frame", nil, f)
        b:SetSize((w or 130) - 30, 18)
        b:SetPoint("TOP", 0, -28 - (i - 1) * 22)
        b.fill = b:CreateTexture(nil, "ARTWORK")
        b.fill:SetAllPoints()
        f.buttons[i] = b
    end
    f.caption = caption(stage, f, L.DISABLED)
    return f
end

local function stockLook(f)
    Skin:Panel(f, "base", { border = "border.black" })
    f.bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
    f.bg:Show()
    f.title:SetFontObject(GameFontNormal)
    for _, b in ipairs(f.buttons) do
        b.fill:SetTexture(Media.textures.WHITE)
        b.fill:SetVertexColor(0.45, 0.08, 0.06, 1)
        Skin:Border(b, "border.black")
    end
end

P:Register("skins", {
    module = "Skins",
    height = 190,
    build = function(stage, m)
        local char = skinSample(stage, L.SKINS_CHARACTER, 0, 190)
        char:SetHeight(140)
        char.strip = char:CreateTexture(nil, "BACKGROUND", nil, -5)
        char.strip:SetTexture(Media.textures.WHITE)
        char.strip:SetPoint("TOPLEFT", 1, -1)
        char.strip:SetPoint("TOPRIGHT", -1, -1)
        char.strip:SetHeight(22)
        char.close = ns.Icons:Create(char, "close", 12, "text.secondary")
        char.close:SetPoint("TOPRIGHT", -6, -5)
        char.inset = CreateFrame("Frame", nil, char)
        char.inset:SetPoint("TOPLEFT", 8, -28)
        char.inset:SetPoint("BOTTOMRIGHT", -8, 8)
        char.tabs = {}
        for i = 1, 3 do
            local t = CreateFrame("Frame", nil, char)
            t:SetSize(56, 20)
            t:SetPoint("TOPLEFT", char, "BOTTOMLEFT", 6 + (i - 1) * 60, 2)
            t.text = P.Text(t, "OVERLAY")
            t.text:SetPoint("CENTER")
            t.text:SetText(i)
            char.tabs[i] = t
        end
        local menu = skinSample(stage, L.SKINS_GAMEMENU, 4)
        local ready = skinSample(stage, L.SKINS_READYCHECK, 2)
        local popup = skinSample(stage, L.SKINS_POPUPS, 1)
        local alert = skinSample(stage, L.SKINS_ALERTS, 0, 110)
        alert:SetHeight(44)
        alert.icon = ns.Icons:Create(alert, "gold", 16, "accent.primary")
        alert.icon:SetPoint("BOTTOM", 0, 6)
        local items = { { char, "character" }, { menu, "gameMenu" }, { ready, "readyCheck" }, { popup, "popups" },
            { alert, "alerts" } }
        return function(self)
            local db = m.db
            local w = self:GetWidth()
            for i, it in ipairs(items) do
                local f, on = it[1], m.db[it[2]]
                f:ClearAllPoints()
                f:SetPoint("CENTER", self, "LEFT", w * (i - 0.5) / #items, 10)
                if on then
                    f.bg:Hide()
                    Skin:Backdrop(f, db.backdrop, "bg.base")
                    Skin:BorderSpec(f, db.border, "border.strong")
                    Skin:Text(f.title, "heading", db.titleStyle == "minimal" and "text.primary" or "accent.primary", 11)
                    for _, b in ipairs(f.buttons) do
                        b.fill:SetTexture(Media.textures.WHITE)
                        b.fill:SetVertexColor(Theme:Color("bg.raised"))
                        Skin:Border(b, "border.subtle")
                    end
                else
                    stockLook(f)
                end
                f.caption:SetShown(not on)
            end
            local on = db.character
            char.strip:SetShown(on and db.titleStyle == "phoenix")
            W.Color(char.strip, "bg.raised")
            char.close:SetShown(on and db.closeStyle == "phoenix")
            Skin:Panel(char.inset, on and "sunken" or "base", { border = on and "border.subtle" or "border.black" })
            for i, t in ipairs(char.tabs) do
                local sel = i == 1
                if on and db.tabs then
                    Skin:Panel(t, sel and "raised" or "sunken", { border = sel and "accent.primary" or "border.subtle" })
                    Skin:Text(t.text, "small", sel and "accent.text" or "text.secondary")
                else
                    Skin:Panel(t, "base", { border = "border.black" })
                    t.text:SetFontObject(GameFontNormalSmall)
                end
            end
        end
    end,
})

---------------------------------------------------------------- AFK screen
P:Register("afk", {
    module = "AFK",
    height = 150,
    build = function(stage, m)
        local f = CreateFrame("Frame", nil, stage)
        f:SetPoint("TOPLEFT", 10, -10)
        f:SetPoint("BOTTOMRIGHT", -10, 10)
        f.dim = f:CreateTexture(nil, "BACKGROUND")
        f.dim:SetAllPoints()
        f.dim:SetTexture(Media.textures.WHITE)
        f.figure = f:CreateTexture(nil, "ARTWORK")
        f.figure:SetTexture(Media.textures.CIRCLE)
        f.figure:SetSize(56, 56)
        f.figure:SetPoint("RIGHT", -40, 18)
        f.spin = W.Icon(f, "reload", 14, "text.muted")
        f.spin:SetPoint("TOP", f.figure, "BOTTOM", 0, -4)
        f.bar = CreateFrame("Frame", nil, f)
        f.bar:SetPoint("BOTTOMLEFT", 0, 12); f.bar:SetPoint("BOTTOMRIGHT", 0, 12)
        f.bar:SetHeight(46)
        f.line = f.bar:CreateTexture(nil, "ARTWORK")
        f.line:SetTexture(Media.textures.WHITE)
        f.line:SetPoint("TOPLEFT"); f.line:SetPoint("TOPRIGHT")
        f.line:SetHeight(2)
        f.logo = f.bar:CreateTexture(nil, "ARTWORK")
        f.logo:SetSize(120, 30)
        ns.Icons:Brand(f.logo, "logo", 120)
        f.logo:SetPoint("LEFT", 14, 0)
        f.name = P.Text(f.bar, "OVERLAY")
        f.name:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 14, -2)
        f.info = P.Text(f.bar, "OVERLAY")
        f.info:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
        f.timer = P.Text(f.bar, "OVERLAY")
        f.timer:SetPoint("RIGHT", -16, 0)
        f.stats = P.Text(f.bar, "OVERLAY")
        f.stats:SetPoint("RIGHT", f.timer, "LEFT", -18, 0)
        return function()
            local db = m.db
            f.dim:SetVertexColor(0, 0, 0, db.dim)
            f.figure:SetVertexColor(Theme:Color("text.muted"))
            f.figure:SetAlpha(0.35)
            f.figure:SetShown(db.showModel)
            Skin:Panel(f.bar, "base", { border = false })
            Skin:SetPanelColor(f.bar, "bg.sunken")
            f.line:SetGradient("HORIZONTAL", Theme:ColorObj("accent.primary"), CreateColor(0, 0, 0, 0))
            Skin:Text(f.name, "title", "text.primary", 14)
            local r, g, b = ns.Util.ClassColor("MAGE")
            f.name:SetTextColor(r, g, b)
            f.name:SetText(L.PREVIEW_UNIT_PLAYER)
            Skin:Text(f.info, "body", "text.secondary", 10)
            f.info:SetText(L.PREVIEW_TT_LEVEL .. (db.showGuild and ("  ·  " .. L.PREVIEW_TT_GUILD) or ""))
            Skin:TextSpec(f.timer, db.timer, "number", "accent.primary")
            f.timer:SetFont(f.timer:GetFont(), math.min(db.timer.size, 22), select(3, f.timer:GetFont()))
            f.timer:SetText("04:12")
            Skin:Text(f.stats, "body", "text.secondary", 10)
            f.stats:SetText(db.stats and m.StatsText(642, ns:Supports("mythicplus") and 2840 or nil, 3,
                ns:Supports("vault") and 9 or nil) or "")
            f.spin:SetShown(db.showModel and db.spin and not Theme.settings.reduceMotion)
        end
    end,
})

---------------------------------------------------------------- quality of life (S16)
-- The combat banner, the flight timer, a loot feed card, the cursor ring and a merchant item tinted
-- as already known.
P:Register("quality", {
    module = "Quality",
    height = 210,
    build = function(stage, m)
        local banner = P.Text(stage, "OVERLAY")
        banner:SetPoint("TOPRIGHT", -24, -18)
        local item = P.Icon(stage, 36, 9)
        item:SetPoint("BOTTOMLEFT", 26, 18)
        item.caption = P.Text(stage, "OVERLAY")
        item.caption:SetPoint("LEFT", item, "RIGHT", 8, 0)
        local ring = stage:CreateTexture(nil, "OVERLAY")
        ring:SetTexture(Media.textures.RING_CIRCLE)
        ring:SetPoint("CENTER", stage, "BOTTOMRIGHT", -70, 44)
        local arrow = W.Icon(stage, "chevron-left", 12, "text.primary")
        arrow:SetPoint("CENTER", ring, "CENTER", 0, 0)
        -- the flight timer at its real height: your last destination (or a sample), a learned time
        local flight = CreateFrame("Frame", nil, stage)
        flight:SetPoint("TOPLEFT", 16, -72)
        flight.fill = CreateFrame("StatusBar", nil, flight)
        flight.fill:SetPoint("TOPLEFT", 2, -2); flight.fill:SetPoint("BOTTOMRIGHT", -2, 2)
        flight.fill:SetMinMaxValues(0, 1)
        flight.icon = W.Icon(flight.fill, "maps", 14, "text.primary", "OVERLAY")
        flight.icon:SetPoint("LEFT", 5, 0)
        flight.time = W.Text(flight.fill, "small", "text.primary", "RIGHT")
        flight.time:SetPoint("RIGHT", -6, 0)
        flight.name = W.Text(flight.fill, "small", "text.primary", "LEFT")
        flight.name:SetPoint("LEFT", flight.icon, "RIGHT", 5, 0)
        flight.name:SetPoint("RIGHT", flight.time, "LEFT", -6, 0)
        flight.name:SetWordWrap(false)
        flight.caption = caption(stage, flight, L.QUALITY_FLIGHT)
        -- a loot feed card at its real size: your last gain (or the game's coin card)
        local feedCard = W.ItemCard(stage, 220, 40)
        feedCard:SetPoint("TOPRIGHT", -24, -60)
        feedCard.caption = caption(stage, feedCard, L.QUALITY_FEED)
        return function()
            local db = m.db
            local fd = db.flight
            flight:SetSize(math.min(fd.width, 300), 22)
            Skin:Panel(flight, "base", { border = "border.subtle" })
            flight.fill:SetStatusBarTexture(Theme:Bar())
            flight.fill:SetStatusBarColor(Theme:Color("accent.primary"))
            flight.fill:SetValue(0.4)
            flight.name:SetText(m:FlightLastName() or L.QUALITY_FLIGHT_SAMPLE)
            flight.time:SetText(m.FlightTimeText(83, true, 0))
            flight:SetAlpha(fd.enabled and 1 or 0.35)
            m.LootFeedPaint(feedCard, m:LootFeedSample()[1], db.feed.enabled and 1 or 0.35)
            feedCard:SetWidth(math.min(db.feed.width, 260))
            Skin:Text(banner, "title", "state.danger", 18, "OUTLINE")
            banner:SetText(L.QUALITY_COMBAT_IN)
            banner:SetAlpha(db.combatAlert and 1 or 0.3)
            Skin:Border(item, "border.black")
            if db.knownTint then item.tex:SetVertexColor(0.35, 0.95, 0.4) else item.tex:SetVertexColor(1, 1, 1) end
            Skin:Text(item.caption, "body", "text.secondary", 11)
            item.caption:SetText(db.knownTint and L.QUALITY_KNOWN or L.OFF)
            local size = math.min(db.ringSize, 90)
            ring:SetSize(size, size)
            ring:SetVertexColor(Theme:Color("accent.primary"))
            ring:SetAlpha(db.cursorRing and 1 or 0.2)
        end
    end,
})
