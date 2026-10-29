local _, ns = ...
local L = ns.L
local W, Skin, Theme = ns.Widgets, ns.Skin, ns.Theme
local Config = ns.Config
local U = ns.Util

--[[ The installer: one window, nine steps (welcome, look, UI scale, accent, action bars, unit frames, chat,
    windows, finish). A step rail on the left, the step's choices in the middle and a live preview on the right;
    every choice is written straight away through ns.DB:Set (so the real frames change behind the window too)
    and the preview is drawn from the same saved values. Back, Next and Skip on every step, the close button
    leaves the rest untouched. Opens once on a first install and again with /pui install or Tools > Presets. ]]
local WIN_W, WIN_H, RAIL_W, PREVIEW_W, PAD, FOOT_H = 900, 580, 196, 300, 18, 54
local CONTENT_W = WIN_W - RAIL_W - PREVIEW_W - 4 * PAD
local ROW = 34

local inst
local I = {}
Config.Installer = I

local function mod(key) return ns.modules[key] end
local function get(m, path) return m and m.db and U.GetPath(m.db, path) end
local function set(m, path, v)
    if not (m and m.db) or U.GetPath(m.db, path) == nil then return end
    ns.DB:Set(m, path, v)
    if inst then inst:Preview() end
end

-- Module switch: live where the module allows it, otherwise remembered for the finish step's reload.
local function setModule(key, v)
    local m = mod(key)
    if not m or m.locked then return end
    ns:SetModuleEnabled(key, v)
    if m.reloadOnToggle then I.reload = true end
    if inst then inst:Preview(); inst:Refresh() end
end

---------------------------------------------------------------- small builders
local function label(parent, text, y, role, token)
    local fs = W.Text(parent, role or "body", token or "text.primary", "LEFT")
    fs:SetPoint("TOPLEFT", 0, y); fs:SetPoint("RIGHT", 0, 0)
    fs:SetWordWrap(true)
    fs:SetText(text)
    return fs
end

local function toggleRow(parent, y, text, getV, setV)
    local r = CreateFrame("Frame", nil, parent)
    r:SetPoint("TOPLEFT", 0, y); r:SetPoint("RIGHT", 0, 0); r:SetHeight(ROW)
    r.label = W.Text(r, "body", "text.primary", "LEFT")
    r.label:SetPoint("LEFT", 0, 0); r.label:SetPoint("RIGHT", -48, 0)
    r.label:SetText(text)
    r.toggle = W:Toggle(r)
    r.toggle:SetPoint("RIGHT", 0, 0)
    r.toggle.onChange = function(_, v) setV(v) end
    r.line = W.Texture(r, "BACKGROUND")
    r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT"); r.line:SetHeight(1)
    Skin:Register(r, function(self) W.Color(self.line, "border.subtle", 1) end)
    function r:Sync() self.toggle:SetValue(getV() and true or false) end
    return r
end

local function chipsRow(parent, y, items, getV, setV)
    local c = W:Chips(parent, items)
    c:SetPoint("TOPLEFT", 0, y)
    c:SetWidth(CONTENT_W)
    c.onChange = function(_, v) setV(v) end
    function c:Sync() self:SetValue(getV()) end
    return c
end

local function sliderRow(parent, y, text, min, max, step, getV, setV, percent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetPoint("TOPLEFT", 0, y); r:SetPoint("RIGHT", 0, 0); r:SetHeight(ROW + 14)
    r.label = W.Text(r, "body", "text.primary", "LEFT")
    r.label:SetPoint("TOPLEFT", 0, 0)
    r.label:SetText(text)
    r.slider = W:Slider(r, min, max, step, percent)
    r.slider:SetPoint("TOPLEFT", 0, -20); r.slider:SetPoint("RIGHT", 0, 0)
    r.slider.onChange = function(_, v) setV(v) end
    function r:Sync() self.slider:SetValue(getV() or min) end
    return r
end

local function swatchBar(parent, height)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetHeight(height)
    b:SetMinMaxValues(0, 1)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
    b.text = W.Text(b, "unit", "text.primary", "LEFT"); b.text:SetPoint("LEFT", 6, 0)
    return b
end

local function playerColor()
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return Theme:Color("accent.primary")
end

---------------------------------------------------------------- steps
-- Each step: key, label (L key), icon, build(body) -> list of rows with :Sync(), preview(pv) -> pv:Paint().
local STEPS = {}
local function step(t) STEPS[#STEPS + 1] = t; return t end

step({ key = "welcome", label = "INST_WELCOME", icon = "home",
    build = function(body)
        label(body, L.INST_WELCOME_TITLE, 0, "title")
        label(body, L.INST_WELCOME_BODY, -34, "body", "text.secondary")
        return {}
    end,
    preview = function(pv)
        pv.emblem = pv:CreateTexture(nil, "ARTWORK")
        pv.emblem:SetSize(128, 128); pv.emblem:SetPoint("CENTER", 0, 24)
        ns.Icons:Brand(pv.emblem, "emblem", 128)
        pv.name = W.Text(pv, "brand", "accent.primary", "CENTER"); pv.name:SetPoint("TOP", pv.emblem, "BOTTOM", 0, -10)
        pv.ver = W.Text(pv, "small", "text.muted", "CENTER"); pv.ver:SetPoint("TOP", pv.name, "BOTTOM", 0, -4)
        function pv:Paint() self.name:SetText(ns.title or "Phoenix UI"); self.ver:SetText(tostring(ns.version or "")) end
    end })

step({ key = "look", label = "INST_LOOK", icon = "presets",
    build = function(body)
        label(body, L.INST_LOOK_DESC, 0, "desc", "text.secondary")
        for i, p in ipairs(Config.PRESETS or {}) do
            local c = Config.LookCard(body, p, CONTENT_W, function(choice)
                Config:ApplyPreset(choice.key)
                ns.DB.sv.global.ui.stylePicked = choice.key
                inst:Preview(); inst:Refresh()
            end)
            c:SetHeight(118)
            c:SetPoint("TOPLEFT", 0, -26 - (i - 1) * 126)
        end
        return {}
    end,
    preview = function(pv)
        pv.bars = {}
        for i = 1, 3 do
            local b = swatchBar(pv, i == 1 and 22 or 12)
            b:SetPoint("TOPLEFT", 16, -60 - (i - 1) * 30); b:SetPoint("RIGHT", -16, 0)
            pv.bars[i] = b
        end
        function pv:Paint()
            local tex = Theme:Bar()
            local fills = { { Theme:Color("accent.primary") }, { Theme:Color("accent.secondary") }, { Theme:Color("state.info") } }
            for i, b in ipairs(self.bars) do
                b:SetStatusBarTexture(tex); b:SetStatusBarColor(fills[i][1], fills[i][2], fills[i][3])
                b:SetValue(({ 0.86, 0.6, 0.34 })[i])
                b.bg:SetTexture(tex); b.bg:SetVertexColor(0.08, 0.08, 0.1, 0.85)
            end
            self.bars[1].text:SetText(UnitName("player") or "")
        end
    end })

step({ key = "scale", label = "INST_SCALE", icon = "resize",
    build = function(body)
        local g = mod("General")
        label(body, L.INST_SCALE_DESC, 0, "desc", "text.secondary")
        local rows = {}
        rows[1] = chipsRow(body, -40, { { value = "pixel", label = L.SETUP_SCALE_PIXEL }, { value = "game", label = L.SETUP_SCALE_GAME } },
            function() return get(g, "scale.enabled") and "pixel" or "game" end,
            function(v) set(g, "scale.enabled", v == "pixel"); if v == "pixel" then set(g, "scale.auto", true) end end)
        rows[2] = toggleRow(body, -80, L.INST_SCALE_AUTO, function() return get(g, "scale.auto") end,
            function(v) set(g, "scale.auto", v) end)
        rows[3] = sliderRow(body, -124, L.INST_SCALE_VALUE, 0.4, 1.15, 0.01,
            function() return get(g, "scale.value") end, function(v) set(g, "scale.auto", false); set(g, "scale.value", v) end)
        return rows
    end,
    preview = function(pv)
        pv.box = CreateFrame("Frame", nil, pv); pv.box:SetPoint("CENTER", 0, 10)
        pv.boxText = W.Text(pv.box, "body", "text.primary", "CENTER"); pv.boxText:SetPoint("CENTER")
        pv.info = W.Text(pv, "small", "text.muted", "CENTER"); pv.info:SetPoint("BOTTOM", 0, 16)
        function pv:Paint()
            local g = mod("General")
            local s = get(g, "scale.enabled") and tonumber(get(g, "scale.value")) or (UIParent:GetScale() or 1)
            local px = math.floor(160 * s + 0.5)
            self.box:SetSize(px, px * 0.5)
            Skin:Panel(self.box, "raised", { border = "accent.primary" })
            self.boxText:SetText(("%d%%"):format(math.floor(s * 100 + 0.5)))
            self.info:SetText(L.INST_SCALE_INFO:format(s))
        end
    end })

step({ key = "accent", label = "INST_ACCENT", icon = "palette",
    build = function(body)
        local g = mod("General")
        label(body, L.INST_ACCENT_DESC, 0, "desc", "text.secondary")
        local items = {}
        for _, p in ipairs(Theme.presets) do
            if p.key ~= "custom" then items[#items + 1] = { value = p.key, label = L[p.label] } end
        end
        return { chipsRow(body, -40, items, function() return get(g, "theme.preset") end, function(v)
            set(g, "theme.preset", v); Theme:Apply(g.db.theme); inst:Preview()
        end) }
    end,
    preview = function(pv)
        pv.sw = {}
        for i, tok in ipairs({ "accent.primary", "accent.secondary", "bg.raised", "bg.hover", "border.subtle" }) do
            local t = W.Texture(pv, "ARTWORK"); t:SetSize(44, 20); t:SetPoint("TOPLEFT", 16 + (i - 1) * 52, -54)
            pv.sw[i] = { t, tok }
        end
        pv.toggle = W:Toggle(pv); pv.toggle:SetPoint("TOPLEFT", 16, -96); pv.toggle:SetValue(true)
        pv.btn = W:Button(pv, L.PRESET_APPLY, "primary", "check", 120); pv.btn:SetPoint("TOPLEFT", 16, -132)
        pv.btn2 = W:Button(pv, L.RELOAD_NEEDED, "secondary", "reload", 140); pv.btn2:SetPoint("LEFT", pv.btn, "RIGHT", 8, 0)
        pv.slider = W:Slider(pv, 0, 1, 0.01, true); pv.slider:SetPoint("TOPLEFT", 16, -176); pv.slider:SetPoint("RIGHT", -16, 0)
        pv.slider:SetValue(0.6)
        function pv:Paint() for _, s in ipairs(self.sw) do W.Color(s[1], s[2], 1) end end
    end })

local BARS = { "bar1", "bar2", "bar3", "bar4", "bar5" }
step({ key = "bars", label = "INST_BARS", icon = "actionbars", module = "ActionBars",
    build = function(body)
        local ab = mod("ActionBars")
        local rows = {}
        for i, key in ipairs(BARS) do
            rows[i] = toggleRow(body, -36 - (i - 1) * ROW, L.INST_BARS_SHOW:format(i),
                function() return get(ab, "bars." .. key .. ".enabled") end,
                function(v) set(ab, "bars." .. key .. ".enabled", v) end)
        end
        rows[#rows + 1] = sliderRow(body, -36 - #BARS * ROW - 6, L.INST_BARS_SIZE, 24, 64, 1,
            function() return get(ab, "bars.bar1.width") end,
            function(v)
                for _, key in ipairs(BARS) do set(ab, "bars." .. key .. ".width", v); set(ab, "bars." .. key .. ".height", v) end
            end)
        return rows
    end,
    preview = function(pv)
        pv.cells = {}
        function pv:Paint()
            local ab = mod("ActionBars")
            for _, c in ipairs(self.cells) do c:Hide() end
            local n, y = 0, -50
            local size = math.min(22, math.max(12, math.floor((tonumber(get(ab, "bars.bar1.width")) or 40) / 2.2)))
            for _, key in ipairs(BARS) do
                if get(ab, "bars." .. key .. ".enabled") then
                    for i = 1, 12 do
                        n = n + 1
                        local c = self.cells[n]
                        if not c then c = W.Texture(self, "ARTWORK"); self.cells[n] = c end
                        c:SetSize(size, size); c:ClearAllPoints()
                        c:SetPoint("TOPLEFT", 12 + (i - 1) * (size + 1), y)
                        W.Color(c, i % 4 == 1 and "accent.primary" or "bg.hover", i % 4 == 1 and 0.55 or 1)
                        c:Show()
                    end
                    y = y - size - 4
                end
            end
        end
    end })

local UNITS = { "player", "target" }
step({ key = "frames", label = "INST_FRAMES", icon = "unitframes", module = "UnitFrames",
    build = function(body)
        local uf = mod("UnitFrames")
        local rows = {}
        rows[1] = chipsRow(body, -40,
            { { value = "class", label = L.INST_COLOR_CLASS }, { value = "reaction", label = L.INST_COLOR_REACTION } },
            function() return get(uf, "units.player.bar.color") end,
            function(v) for _, u in ipairs(UNITS) do set(uf, "units." .. u .. ".bar.color", v) end end)
        rows[2] = toggleRow(body, -84, L.INST_PORTRAITS, function() return get(uf, "units.player.portrait") ~= "hide" end,
            function(v) for _, u in ipairs(UNITS) do set(uf, "units." .. u .. ".portrait", v and "game" or "hide") end end)
        return rows
    end,
    preview = function(pv)
        pv.frames = {}
        for i, u in ipairs(UNITS) do
            local b = swatchBar(pv, 30); b:SetPoint("TOPLEFT", 16, -56 - (i - 1) * 50); b:SetPoint("RIGHT", -16, 0)
            b.port = W.Texture(b, "ARTWORK"); b.port:SetSize(30, 30); b.port:SetPoint("RIGHT", b, "LEFT", -2, 0)
            pv.frames[i] = { b, u }
        end
        function pv:Paint()
            local uf = mod("UnitFrames")
            local tex = Theme:Bar()
            for i, f in ipairs(self.frames) do
                local b, u = f[1], f[2]
                local by = get(uf, "units." .. u .. ".bar.color")
                local r, g, bb = playerColor()
                if by == "reaction" then r, g, bb = 0.24, 0.86, 0.59 end
                b:SetStatusBarTexture(tex); b:SetStatusBarColor(r, g, bb); b:SetValue(i == 1 and 0.82 or 0.46)
                b.bg:SetTexture(tex); b.bg:SetVertexColor(0.08, 0.08, 0.1, 0.85)
                b.text:SetText(i == 1 and (UnitName("player") or "") or L.INST_TARGET)
                local port = get(uf, "units." .. u .. ".portrait") ~= "hide"
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", port and 50 or 16, -56 - (i - 1) * 50); b:SetPoint("RIGHT", -16, 0)
                b.port:SetShown(port); W.Color(b.port, "bg.hover", 1)
            end
        end
    end })

local CHAT = { { "fade", L.INST_CHAT_FADE }, { "urls", L.INST_CHAT_URLS }, { "copyButton", L.INST_CHAT_COPY },
    { "pillTabs", L.INST_CHAT_TABS } }
step({ key = "chat", label = "INST_CHAT", icon = "chat", module = "Chat",
    build = function(body)
        local ch = mod("Chat")
        local rows = {}
        for i, e in ipairs(CHAT) do
            rows[i] = toggleRow(body, -36 - (i - 1) * ROW, e[2], function() return get(ch, e[1]) end,
                function(v) set(ch, e[1], v) end)
        end
        return rows
    end,
    preview = function(pv)
        pv.tabs = {}
        for i, t in ipairs({ GENERAL or "General", GUILD or "Guild", WHISPER or "Whisper" }) do
            local f = CreateFrame("Frame", nil, pv); f:SetSize(72, 20); f:SetPoint("TOPLEFT", 16 + (i - 1) * 76, -50)
            f.t = W.Text(f, "small", "text.primary", "CENTER"); f.t:SetPoint("CENTER"); f.t:SetText(t)
            pv.tabs[i] = f
        end
        pv.lines = W.Text(pv, "desc", "text.primary", "LEFT"); pv.lines:SetPoint("TOPLEFT", 16, -80); pv.lines:SetPoint("RIGHT", -16, 0)
        pv.lines:SetSpacing(4)
        function pv:Paint()
            local ch = mod("Chat")
            local pill = get(ch, "pillTabs")
            for i, f in ipairs(self.tabs) do
                Skin:Panel(f, i == 1 and "raised" or "base", { border = i == 1 and "accent.primary" or (pill and "border.subtle" or nil) })
            end
            local link = get(ch, "urls") and Theme:Wrap("[phoenixui.gg]", "accent.primary") or "phoenixui.gg"
            local copy = get(ch, "copyButton") and ("\n" .. Theme:Wrap(L.INST_CHAT_COPY, "text.muted")) or ""
            self.lines:SetText(L.INST_CHAT_SAMPLE:format(link) .. copy)
            self.lines:SetAlpha(1)
        end
    end })

local SKINS = { { "gameMenu", L.INST_SKIN_MENU }, { "microMenu", L.INST_SKIN_MICRO }, { "character", L.INST_SKIN_CHAR },
    { "mail", L.INST_SKIN_MAIL }, { "merchant", L.INST_SKIN_MERCHANT }, { "friends", L.INST_SKIN_FRIENDS } }
step({ key = "skins", label = "INST_SKINS", icon = "skins", module = "Skins",
    build = function(body)
        local sk = mod("Skins")
        local rows = {}
        for i, e in ipairs(SKINS) do
            rows[i] = toggleRow(body, -36 - (i - 1) * ROW, e[2], function() return get(sk, e[1]) end,
                function(v) set(sk, e[1], v) end)
        end
        return rows
    end,
    preview = function(pv)
        pv.rows = {}
        for i, e in ipairs(SKINS) do
            local f = CreateFrame("Frame", nil, pv); f:SetHeight(24)
            f:SetPoint("TOPLEFT", 16, -50 - (i - 1) * 28); f:SetPoint("RIGHT", -16, 0)
            f.bar = W.Texture(f, "ARTWORK"); f.bar:SetPoint("TOPLEFT"); f.bar:SetPoint("BOTTOMLEFT"); f.bar:SetWidth(2)
            f.t = W.Text(f, "body", "text.primary", "LEFT"); f.t:SetPoint("LEFT", 10, 0); f.t:SetText(e[2])
            pv.rows[i] = { f, e[1] }
        end
        function pv:Paint()
            local sk = mod("Skins")
            for _, r in ipairs(self.rows) do
                local on = get(sk, r[2])
                Skin:Panel(r[1], on and "raised" or "sunken", { border = on and "border.subtle" or nil })
                W.Color(r[1].bar, "accent.primary", on and 1 or 0)
                Skin:Text(r[1].t, "body", on and "text.primary" or "text.muted")
            end
        end
    end })

step({ key = "finish", label = "INST_FINISH", icon = "check",
    build = function(body)
        label(body, L.INST_FINISH_TITLE, 0, "title")
        body.text = label(body, "", -34, "body", "text.secondary")
        body.arrange = W:Button(body, L.SETUP_ARRANGE, "secondary", "movers", 200)
        body.arrange:SetPoint("TOPLEFT", 0, -150)
        body.arrange.onClick = function()
            I:Finish(true)
        end
        return { { Sync = function() body.text:SetText(I.reload and L.INST_FINISH_RELOAD or L.INST_FINISH_BODY) end } }
    end,
    preview = function(pv)
        pv.list = W.Text(pv, "desc", "text.primary", "LEFT"); pv.list:SetPoint("TOPLEFT", 16, -50); pv.list:SetPoint("RIGHT", -16, 0)
        pv.list:SetSpacing(5)
        function pv:Paint()
            local out = {}
            for i = 2, #STEPS - 1 do
                local s = STEPS[i]
                local seen = I.visited and I.visited[s.key]
                out[#out + 1] = (seen and Theme:Wrap("+ ", "state.success") or Theme:Wrap("- ", "text.muted")) .. L[s.label]
            end
            self.list:SetText(table.concat(out, "\n"))
        end
    end })
I.STEPS = STEPS

---------------------------------------------------------------- window
local function buildRail(f)
    f.rail = CreateFrame("Frame", nil, f)
    f.rail:SetPoint("TOPLEFT", 1, -44); f.rail:SetPoint("BOTTOMLEFT", 1, FOOT_H)
    f.rail:SetWidth(RAIL_W)
    f.rail.items = {}
    for i, s in ipairs(STEPS) do
        local b = CreateFrame("Button", nil, f.rail)
        b:SetHeight(40); b:SetPoint("TOPLEFT", 0, -(i - 1) * 42); b:SetPoint("RIGHT", 0, 0)
        b.bar = W.Texture(b, "ARTWORK", 1); b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(2)
        b.num = W.Text(b, "number", "text.muted", "CENTER"); b.num:SetPoint("LEFT", 12, 0); b.num:SetWidth(16)
        b.num:SetText(tostring(i))
        b.icon = W.Icon(b, s.icon, 16, "text.secondary"); b.icon:SetPoint("LEFT", 34, 0)
        b.label = W.Text(b, "body", "text.primary", "LEFT"); b.label:SetPoint("LEFT", 58, 0); b.label:SetPoint("RIGHT", -8, 0)
        b.label:SetText(L[s.label])
        b:SetScript("OnClick", function() I:Go(i) end)
        f.rail.items[i] = b
    end
    Skin:Register(f.rail, function(self) Skin:Panel(self, "sunken") end)
end

local function buildFooter(f)
    f.progress = W.Texture(f, "ARTWORK", 2)
    f.progress:SetPoint("BOTTOMLEFT", 1, FOOT_H); f.progress:SetHeight(2)
    f.next = W:Button(f, L.INST_NEXT, "primary", "arrow-right", 130); f.next:SetPoint("BOTTOMRIGHT", -PAD, 14)
    f.back = W:Button(f, L.INST_BACK, "secondary", "arrow-left", 110); f.back:SetPoint("RIGHT", f.next, "LEFT", -8, 0)
    f.skip = W:Button(f, L.INST_SKIP, "secondary", nil, 110); f.skip:SetPoint("BOTTOMLEFT", RAIL_W + PAD, 14)
    f.next.onClick = function()
        if I.index >= #STEPS then I:Finish(false) else I:Go(I.index + 1) end
    end
    f.back.onClick = function() I:Go(I.index - 1) end
    f.skip.onClick = function() I:Go(#STEPS) end
    f.close.onClick = function() I:Finish(false) end
end

local function build()
    local f = W:Popup(L.INST_TITLE, WIN_W, WIN_H, "presets")
    buildRail(f)
    f.stepTitle = W.Text(f, "title", "text.primary", "LEFT")
    f.stepTitle:SetPoint("TOPLEFT", RAIL_W + PAD, -56)
    f.pages, f.previews = {}, {}
    f.previewFrame = CreateFrame("Frame", nil, f)
    f.previewFrame:SetPoint("TOPRIGHT", -PAD, -56); f.previewFrame:SetPoint("BOTTOMRIGHT", -PAD, FOOT_H + PAD)
    f.previewFrame:SetWidth(PREVIEW_W)
    f.previewLabel = W.Text(f.previewFrame, "heading", "accent.primary", "LEFT")
    f.previewLabel:SetPoint("TOPLEFT", 16, -16); f.previewLabel:SetText(L.INST_PREVIEW:upper())
    Skin:Register(f.previewFrame, function(self) Skin:Panel(self, "sunken", { border = "border.subtle" }) end)
    buildFooter(f)
    function f:Preview()
        local pv = self.previews[I.index]
        if pv and pv.Paint then pv:Paint() end
    end
    function f:Refresh()
        local page = self.pages[I.index]
        for _, r in ipairs(page and page.rows or {}) do if r.Sync then r:Sync() end end
    end
    return f
end

local function pageFor(i)
    local f, s = inst, STEPS[i]
    if f.pages[i] then return f.pages[i], f.previews[i] end
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", RAIL_W + PAD, -92); body:SetWidth(CONTENT_W); body:SetPoint("BOTTOM", 0, FOOT_H + PAD)
    local m = s.module and mod(s.module)
    local y = 0
    if m then
        body.enable = toggleRow(body, 0, L.INST_USE:format(L[m.label] or m.key), function() return m.db.enabled end,
            function(v) setModule(m.key, v) end)
        y = -ROW - 6
    end
    local inner = CreateFrame("Frame", nil, body)
    inner:SetPoint("TOPLEFT", 0, y); inner:SetPoint("BOTTOMRIGHT")
    body.rows = s.build(inner) or {}
    if body.enable then table.insert(body.rows, 1, body.enable) end
    local pv = CreateFrame("Frame", nil, f.previewFrame)
    pv:SetAllPoints()
    s.preview(pv)
    f.pages[i], f.previews[i] = body, pv
    return body, pv
end

local function paintRail()
    for i, b in ipairs(inst.rail.items) do
        local cur, done = i == I.index, I.visited[STEPS[i].key]
        W.Color(b.bar, "accent.primary", cur and 1 or 0)
        ns.Icons:Tint(b.icon, cur and "accent.primary" or (done and "text.primary" or "text.muted"))
        Skin:Text(b.label, "body", cur and "accent.text" or (done and "text.primary" or "text.secondary"))
        Skin:Text(b.num, "number", cur and "accent.primary" or "text.muted")
    end
end

function I:Go(i)
    if not inst then return end
    i = math.max(1, math.min(#STEPS, i))
    self.index = i
    self.visited[STEPS[i].key] = true
    for k, p in pairs(inst.pages) do p:SetShown(k == i) end
    for k, p in pairs(inst.previews) do p:SetShown(k == i) end
    local body, pv = pageFor(i)
    body:Show(); pv:Show()
    inst.stepTitle:SetText(L[STEPS[i].label])
    inst.back:SetShown(i > 1)
    inst.skip:SetShown(i < #STEPS)
    inst.next:SetText(i == #STEPS and (self.reload and L.INST_DONE_RELOAD or L.INST_DONE) or L.INST_NEXT)
    inst.progress:SetWidth(math.max(2, (WIN_W - 2) * i / #STEPS))
    W.Color(inst.progress, "accent.primary", 1)
    inst:Refresh(); inst:Preview(); paintRail()
    return body
end

function I:Finish(arrange)
    local ui = ns.DB.sv.global.ui
    ui.setupStarted, ui.stylePicked, ui.modulesPicked, ui.setupDone = true, ui.stylePicked or "skip", true, true
    if inst then inst:Hide() end
    if self.reload then ReloadUI() return end
    if arrange then
        local mv = mod("Movers")
        if mv and mv:IsEnabled() then
            if _G.PhoenixUI_Config then _G.PhoenixUI_Config:Hide() end
            mv:SetUnlocked(true)
        end
    end
end

-- Opens the installer at a step (default: the first). Not in combat: half the steps move secure frames.
function Config:ShowInstaller(index)
    if InCombatLockdown() then ns:Print(L.INST_COMBAT) return end
    if not inst then inst = build(); I.visited = {} end
    I.reload = I.reload or false
    local ui = ns.DB.sv.global.ui
    ui.setupStarted = true
    ui.stylePicked = ui.stylePicked or "skip" -- the first-install prompt has been shown; a pick overwrites it
    inst:Show()
    I:Go(index or 1)
    return inst
end

-- The installer replaces the old three-popup wizard: first install, Tools > Presets and /pui install.
function Config:RunSetupWizard() return Config:ShowInstaller(1) end
local oldPicker = Config.ShowStylePicker
function Config:ShowStylePicker(force)
    if force then return oldPicker(self, force) end
    local ui = ns.DB.sv.global.ui
    if ui.stylePicked or not ns.DB.fresh then return end
    return Config:ShowInstaller(1)
end
-- A /reload in the middle of a first install brings the installer back at its last step.
local oldFinish = Config.ShowSetupFinish
function Config:ShowSetupFinish(force)
    if force then return oldFinish(self, force) end
    local ui = ns.DB.sv.global.ui
    if ui.setupDone or not ui.setupStarted then return end
    return Config:ShowInstaller(#STEPS)
end
