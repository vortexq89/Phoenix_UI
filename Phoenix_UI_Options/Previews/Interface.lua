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

P:Register("itemlevel", {
    module = "ItemLevel",
    height = 120,
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
                b.level:SetPoint("TOPRIGHT", -1, -2)
                b.level:SetJustifyH("RIGHT")
                b.sample = s
                holder.items[i] = b
            end
            return holder
        end
        local gear, bags = slots(GEAR, 38), slots(BAGS, 34)
        gear.caption = caption(stage, gear, L.ITEMLEVEL_CHARACTER)
        bags.caption = caption(stage, bags, L.ITEMLEVEL_BAGS)
        return function(self)
            local db = m.db
            local w = self:GetWidth()
            gear:ClearAllPoints(); gear:SetPoint("CENTER", self, "LEFT", w * 0.36, 8)
            bags:ClearAllPoints(); bags:SetPoint("CENTER", self, "LEFT", w * 0.8, 8)
            for _, group in ipairs({ { gear, db.character }, { bags, db.bags } }) do
                local holder, on = group[1], group[2]
                holder:SetAlpha(on and 1 or 0.35)
                for _, b in ipairs(holder.items) do
                    local q = b.sample[3]
                    Skin:Border(b, "border.black")
                    if on then
                        Skin:Text(b.level, "number", nil, db.size)
                        local r, g, bl = C_Item.GetItemQualityColor(q)
                        if db.qualityColor and r then b.level:SetTextColor(r, g, bl) else b.level:SetTextColor(1, 1, 1) end
                        b.level:SetText(b.sample[2])
                    else
                        b.level:SetText("")
                    end
                end
            end
        end
    end,
})

---------------------------------------------------------------- bags
-- { icon index, item level (nil = no level), quality, count, upgrade }; one empty slot at the end.
local BAG_ITEMS = { { 2, 701, 4, nil, true }, { 6, 0, 1, 20 }, { 9, 688, 3 }, { 3, 0, 2, 5 }, { 11, 714, 4, nil, true },
    { 5, 0, 1, 200 }, { 8, 672, 2 }, { 1, 0, 3, 3 }, { 12, 695, 4 }, { 4, 0, 1, 12 }, { 7, 0, 0, 8 }, false }

P:Register("bags", {
    module = "Bags",
    height = 170,
    build = function(stage, m)
        local il = ns.modules.ItemLevel
        local win = CreateFrame("Frame", nil, stage)
        win:SetSize(6 * 40 + 22, 2 * 40 + 52)
        win:SetPoint("CENTER")
        win.title = P.Text(win, "OVERLAY")
        win.title:SetPoint("TOPLEFT", 12, -10)
        win.title:SetText(L.BAGS_PREVIEW_TITLE)
        win.items = {}
        for i, s in ipairs(BAG_ITEMS) do
            local b = CreateFrame("Frame", nil, win)
            b:SetSize(36, 36)
            b:SetPoint("TOPLEFT", 12 + ((i - 1) % 6) * 40, -32 - math.floor((i - 1) / 6) * 40)
            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints()
            b.bg:SetTexture(Media.textures.WHITE)
            if s then
                b.tex = b:CreateTexture(nil, "ARTWORK")
                b.tex:SetAllPoints()
                b.tex:SetTexture(P.SAMPLE.icons[(s[1] - 1) % #P.SAMPLE.icons + 1])
                b.level = P.Text(b, "OVERLAY")
                b.level:SetPoint("TOPRIGHT", -1, -2)
                b.count = P.Text(b, "OVERLAY")
                b.count:SetPoint("BOTTOMRIGHT", -2, 2)
                b.arrow = ns.Icons:Create(b, "arrow-up", 14, "state.success")
                b.arrow:SetPoint("TOPLEFT", 1, -1)
            end
            b.sample = s
            win.items[i] = b
        end
        return function()
            local db = m.db
            if db.skin then
                Skin:Panel(win, "base", { border = "border.strong", shadow = 10, sheen = 22 })
                Skin:Text(win.title, "heading", "accent.primary", 12)
            else
                Skin:Panel(win, "raised", { border = "border.default" })
                Skin:Text(win.title, "body", "text.secondary", 12)
            end
            for _, b in ipairs(win.items) do
                local s = b.sample
                W.Color(b.bg, db.skin and "bg.sunken" or "bg.raised")
                if s then
                    if db.skin then Skin:IconZoom(b.tex, 0.08) else b.tex:SetTexCoord(0, 1, 0, 1) end
                    local r, g, bl = C_Item.GetItemQualityColor(s[3])
                    local colored = db.skin and db.quality and s[3] >= 2 and r
                    if colored then
                        Skin:BorderSpec(b, { style = "solid", size = 1, color = { r = r, g = g, b = bl } })
                    else
                        Skin:BorderSpec(b, { style = "solid", size = 1 }, "border.black")
                    end
                    local showLevel = il and il.db.bags and s[2] > 0
                    if showLevel then
                        Skin:Text(b.level, "number", nil, il.db.size)
                        if il.db.qualityColor and r then b.level:SetTextColor(r, g, bl) else b.level:SetTextColor(1, 1, 1) end
                    end
                    b.level:SetText(showLevel and s[2] or "")
                    Skin:Text(b.count, "number", "text.primary", db.skin and db.countSize or 12, "OUTLINE")
                    b.count:SetText(s[4] or "")
                    b.arrow:SetShown(db.upgrade and s[5] or false)
                else
                    Skin:BorderSpec(b, { style = "solid", size = 1 }, "border.subtle")
                end
            end
        end
    end,
})

---------------------------------------------------------------- window skins
P:Register("skins", {
    module = "Skins",
    height = 150,
    build = function(stage, m)
        local function window(title, buttons)
            local f = CreateFrame("Frame", nil, stage)
            f:SetSize(150, 30 + buttons * 22)
            f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
            f.bg:SetAllPoints()
            f.title = P.Text(f, "OVERLAY")
            f.title:SetPoint("TOP", 0, -9)
            f.title:SetText(title)
            f.buttons = {}
            for i = 1, buttons do
                local b = CreateFrame("Frame", nil, f)
                b:SetSize(120, 18)
                b:SetPoint("TOP", 0, -28 - (i - 1) * 22)
                b.fill = b:CreateTexture(nil, "ARTWORK")
                b.fill:SetAllPoints()
                f.buttons[i] = b
            end
            f.caption = caption(stage, f, L.DISABLED)
            return f
        end
        local menu = window(L.SKINS_GAMEMENU, 4)
        local ready = window(L.SKINS_READYCHECK, 2)
        local popup = window(L.SKINS_POPUPS, 1)
        local items = { { menu, "gameMenu" }, { ready, "readyCheck" }, { popup, "popups" } }
        return function(self)
            local w = self:GetWidth()
            for i, it in ipairs(items) do
                local f, on = it[1], m.db[it[2]]
                f:ClearAllPoints()
                f:SetPoint("CENTER", self, "LEFT", w * (i - 0.5) / #items, 6)
                if on then
                    f.bg:Hide()
                    Skin:Panel(f, "base", { border = "border.strong", shadow = 8, sheen = 20 })
                    Skin:Text(f.title, "heading", "accent.primary", 11)
                    for _, b in ipairs(f.buttons) do
                        b.fill:SetTexture(Media.textures.WHITE)
                        b.fill:SetVertexColor(Theme:Color("bg.raised"))
                        Skin:Border(b, "border.subtle")
                    end
                else
                    -- the stock dialog look, for comparison
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
                f.caption:SetShown(not on)
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
        return function()
            f.dim:SetVertexColor(0, 0, 0, 0.55)
            f.figure:SetVertexColor(Theme:Color("text.muted"))
            f.figure:SetAlpha(0.35)
            Skin:Panel(f.bar, "base", { border = false })
            Skin:SetPanelColor(f.bar, "bg.sunken")
            f.line:SetGradient("HORIZONTAL", Theme:ColorObj("accent.primary"), CreateColor(0, 0, 0, 0))
            Skin:Text(f.name, "title", "text.primary", 14)
            local r, g, b = ns.Util.ClassColor("MAGE")
            f.name:SetTextColor(r, g, b)
            f.name:SetText(L.PREVIEW_UNIT_PLAYER)
            Skin:Text(f.info, "body", "text.secondary", 10)
            f.info:SetText(L.PREVIEW_TT_LEVEL)
            Skin:Text(f.timer, "number", "accent.primary", 18)
            f.timer:SetText("04:12")
            f.spin:SetShown(m.db.spin and not Theme.settings.reduceMotion)
        end
    end,
})
