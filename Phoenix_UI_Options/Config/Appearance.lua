local _, ns = ...
local L = ns.L
local W, Skin, Media = ns.Widgets, ns.Skin, ns.Media
local Config = ns.Config
local U = ns.Util

--[[ Appearance & Media: Fonts, Textures and Sounds.

    The Fonts and Textures pages mirror every font or texture setting in every module, grouped like the
    sidebar, so the whole interface can be dressed from one place. They do not have settings of their own:
    each row reads and writes the module's own saved value (scoped rows, such as per-unit bar textures, write
    every unit). "Everywhere at once" applies one choice to all of them, or hands them all back to the theme
    font/texture chosen under General. The arrow beside a row opens it in its module.

    The Sounds page lists the bundled sounds and countdown voices so they can be heard before a module uses
    them. ]]

-- Mirror rows for every option of this type, found by walking each module's schema (cog rows included).
local function collect(kind)
    local out = {}
    for _, g in ipairs(Config:Groups()) do
        for _, key in ipairs(g.entries) do
            local m = ns.modules[key]
            local schema = m and ns.options[key]
            if schema then
                local units, unitLabels
                for _, item in ipairs(schema) do
                    if item.type == "scope" then
                        units, unitLabels = {}, {}
                        for i, v in ipairs(item.values) do units[i], unitLabels[i] = v.value, L[v.label] end
                    end
                end
                local function visit(item, parent)
                    if item.type == kind and item.key and not item.get then
                        local scoped = item.key:find("@", 1, true) ~= nil
                        out[#out + 1] = { group = g, m = m, item = item, parent = parent,
                            units = scoped and units or nil, unitLabels = scoped and unitLabels or nil }
                    end
                    for _, sub in ipairs(item.cog or {}) do visit(sub, item) end
                end
                for _, item in ipairs(schema) do visit(item) end
            end
        end
    end
    return out
end

local function paths(e)
    if not e.units then return { e.item.key } end
    local out = {}
    for i, u in ipairs(e.units) do out[i] = (e.item.key:gsub("@", u)) end
    return out
end

local function mirrorRow(kind, e)
    local m, item = e.m, e.item
    local label = L[m.label] .. "  ·  " .. L[(e.parent and e.parent.label) or item.label]
    local desc
    if e.units then
        desc = L.MIRROR_EVERY_UNIT:format(table.concat(e.unitLabels, ", "))
    end
    local first = paths(e)[1]
    return {
        type = kind, label = label, desc = desc, allowDefault = item.allowDefault,
        default = U.GetPath(m.defaults, first),
        get = function() return U.GetPath(m.db, first) end,
        set = function(_, v)
            for _, p in ipairs(paths(e)) do ns.DB:Set(m, p, v) end
        end,
        link = { key = m.key, item = e.parent or item },
        disabled = item.disabled and function() return item.disabled(m) end or nil,
        mirror = e,
    }
end

local function applyAll(kind, value)
    local n = 0
    for _, e in ipairs(collect(kind)) do
        if value ~= "" or e.item.allowDefault then
            for _, p in ipairs(paths(e)) do ns.DB:Set(e.m, p, value); n = n + 1 end
        end
    end
    return n
end

-- The "everywhere at once" row: a picker, Apply, and Follow theme. The specimen shows the picked or
-- pointed-at entry large.
local function applyRow(kind, page)
    return function(row)
        local holder = CreateFrame("Frame", nil, row)
        holder:SetSize(W.CONTROL_WIDTH + 252, 28)
        local media = kind == "font" and "font" or "statusbar"
        local pick = W:MediaPicker(holder, media, function() return Media:List(media) end)
        pick:SetPoint("LEFT")
        local go = W:Button(holder, L.MIRROR_APPLY, "primary", "check", 116)
        go:SetPoint("LEFT", pick, "RIGHT", 8, 0)
        local theme = W:Button(holder, L.MIRROR_FOLLOW_THEME, "secondary", "theme", 120)
        theme:SetPoint("LEFT", go, "RIGHT", 6, 0)
        W.AttachTooltip(theme, L.MIRROR_FOLLOW_THEME, L.MIRROR_FOLLOW_THEME_DESC)
        go:SetEnabledState(false)
        pick.onChange = function(_, v)
            go:SetEnabledState(v ~= nil)
            if page.specimen then page.specimen:Show(v) end
        end
        pick.onHover = function(_, v)
            if page.specimen then page.specimen:Show(v or pick:GetValue()) end
        end
        go.onClick = function()
            local v = pick:GetValue()
            if not v then return end
            local n = applyAll(kind, v)
            local name = pick.current and pick.current.label or v
            Config:SetStatus(L.MIRROR_APPLIED:format(name, n), "state.success")
            if page.Refresh then page:Refresh() end
        end
        theme.onClick = function()
            local n = applyAll(kind, "")
            Config:SetStatus(L.MIRROR_FOLLOWING:format(n), "state.success", "theme")
            if page.Refresh then page:Refresh() end
        end
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", 16, 0)
        return holder
    end
end

-- A large sample of the font or texture being considered.
local function specimenRow(kind, page)
    return function(row)
        local s = CreateFrame("Frame", nil, row)
        s:SetPoint("TOPLEFT", 16, -8)
        s:SetPoint("BOTTOMRIGHT", -16, 8)
        Skin:Register(s, function(self) Skin:Panel(self, "sunken", { border = "border.subtle" }) end)
        if kind == "font" then
            s.big = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            s.big:SetPoint("TOPLEFT", 14, -12)
            s.big:SetPoint("RIGHT", -14, 0)
            s.big:SetJustifyH("LEFT")
            s.small = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            s.small:SetPoint("TOPLEFT", s.big, "BOTTOMLEFT", 0, -8)
            s.small:SetPoint("RIGHT", -14, 0)
            s.small:SetJustifyH("LEFT")
            s.small:SetWordWrap(true)
        else
            s.bars = {}
            local values = { 0.92, 0.64, 0.38 }
            for i, v in ipairs(values) do
                local b = CreateFrame("StatusBar", nil, s)
                b:SetMinMaxValues(0, 1)
                b:SetValue(v)
                b:SetHeight(i == 1 and 26 or 16)
                b.bg = b:CreateTexture(nil, "BACKGROUND")
                b.bg:SetAllPoints()
                s.bars[i] = b
            end
            s.bars[1]:SetPoint("TOPLEFT", 14, -12); s.bars[1]:SetPoint("TOPRIGHT", -14, -12)
            s.bars[2]:SetPoint("TOPLEFT", s.bars[1], "BOTTOMLEFT", 0, -8); s.bars[2]:SetPoint("RIGHT", -14, 0)
            s.bars[3]:SetPoint("TOPLEFT", s.bars[2], "BOTTOMLEFT", 0, -6); s.bars[3]:SetPoint("RIGHT", -14, 0)
        end
        s.name = W.Text(s, "small", "text.muted", "RIGHT")
        s.name:SetPoint("BOTTOMRIGHT", -12, 8)
        local TOKENS = { "state.success", "accent.primary", "state.danger" }
        function s:Show(value)
            value = value or ""
            local label = value == "" and L.DEFAULT or value
            for _, it in ipairs(Media:List(kind == "font" and "font" or "statusbar")) do
                if it.value == value then label = it.label end
            end
            self.name:SetText(label:upper())
            if kind == "font" then
                local path = value ~= "" and Media:Font(value) or (ns.Theme:Font("body"))
                self.big:SetFont(path, 26, "")
                self.big:SetText(L.SPECIMEN_LINE)
                self.small:SetFont(path, 13, "")
                self.small:SetText(L.SPECIMEN_TEXT)
                self.big:SetTextColor(ns.Theme:Color("text.primary"))
                self.small:SetTextColor(ns.Theme:Color("text.secondary"))
            else
                local path = value ~= "" and Media:Bar(value) or ns.Theme:Bar()
                for i, b in ipairs(self.bars) do
                    b:SetStatusBarTexture(path)
                    b:SetStatusBarColor(ns.Theme:Color(TOKENS[i]))
                    b.bg:SetTexture(path)
                    ns.Widgets.Color(b.bg, "bg.sunken", 0.85)
                end
            end
        end
        page.specimen = s
        s:Show(nil)
        return s
    end
end

local PAGES = {
    font = { key = "fonts", label = "APPEARANCE_FONTS", desc = "APPEARANCE_FONTS_DESC", icon = "fonts",
        intro = { text = "APPEARANCE_FONTS_INTRO" }, pick = { label = "MIRROR_PICK_FONT" }, specimen = 128 },
    texture = { key = "textures", label = "APPEARANCE_TEXTURES", desc = "APPEARANCE_TEXTURES_DESC", icon = "textures",
        intro = { text = "APPEARANCE_TEXTURES_INTRO" }, pick = { label = "MIRROR_PICK_TEXTURE" }, specimen = 112 },
}

local function mirrorSchema(kind)
    local page, def = {}, PAGES[kind]
    local schema = {
        { type = "header", label = "MIRROR_EVERYWHERE", icon = def.icon, wide = true },
        { type = "description", text = def.intro.text },
        { type = "custom", label = "SPECIMEN", fullWidth = true, height = def.specimen, build = specimenRow(kind, page) },
        { type = "custom", label = def.pick.label, build = applyRow(kind, page) },
    }
    local lastGroup
    for _, e in ipairs(collect(kind)) do
        if e.group ~= lastGroup then
            schema[#schema + 1] = { type = "header", label = e.group.label, icon = e.group.icon }
            lastGroup = e.group
        end
        schema[#schema + 1] = mirrorRow(kind, e)
    end
    return schema, page
end

local function mirrorPage(kind)
    local def = PAGES[kind]
    local key, label, icon = def.key, def.label, def.icon
    local object = { key = key, label = label, desc = def.desc, icon = icon, locked = true, db = {}, defaults = {} }
    local schema, state
    local function getSchema()
        if not schema then schema, state = mirrorSchema(kind) end
        return schema
    end
    Config:RegisterPage(key, function(parent)
        local page = Config.BuildSchemaPage(parent, object, getSchema())
        -- the specimen and apply rows talk to the page through this table
        setmetatable(state, { __index = page })
        state.Refresh = function() page:Refresh() end
        -- other pages change the same settings: stay current
        ns.Events:Listen("PUI_SETTING_CHANGED", page, function()
            if page:IsShown() then for _, row in ipairs(page.rows) do row:Refresh() end end
        end)
        return page
    end, { label = label, icon = icon, object = object, schema = getSchema })
end

mirrorPage("font")
mirrorPage("texture")

---------------------------------------------------------------- sounds
local sounds = { key = "sounds", label = "APPEARANCE_SOUNDS", desc = "APPEARANCE_SOUNDS_DESC", icon = "sound", locked = true, db = {} }

local function playButton(row, play)
    local b = W:Button(row, L.MEDIA_PLAY, "secondary", "sound", 96)
    b.onClick = play
    return b
end

-- Counts n..1 with the voice, one number a second (the way the tracker counts down).
local function countdown(voice, from)
    for i = from, 1, -1 do
        C_Timer.After(from - i, function() PlaySoundFile(Media:Voice(voice, i), "Master") end)
    end
end

local function soundSchema()
    local schema = {
        { type = "header", label = "SOUNDS_LIBRARY", icon = "sound", wide = true },
        { type = "description", text = "SOUNDS_LIBRARY_DESC" },
    }
    for _, s in ipairs(Media.sounds) do
        schema[#schema + 1] = { type = "custom", label = s.label, desc = "SOUNDS_ALERT_DESC",
            build = function(row) return playButton(row, function() Media:PlaySound(s.key) end) end }
    end
    schema[#schema + 1] = { type = "header", label = "SOUNDS_VOICES", icon = "tracker", wide = true }
    schema[#schema + 1] = { type = "description", text = "SOUNDS_VOICES_DESC" }
    for _, v in ipairs(Media.voices) do
        schema[#schema + 1] = { type = "custom", label = v.name, desc = "SOUNDS_VOICE_DESC",
            build = function(row) return playButton(row, function() countdown(v.key, 5) end) end }
    end
    schema[#schema + 1] = { type = "header", label = "CREDITS", icon = "heart", wide = true }
    schema[#schema + 1] = { type = "description", text = "SOUNDS_CREDITS" }
    return schema
end

local soundCache
local function getSounds()
    soundCache = soundCache or soundSchema()
    return soundCache
end
Config:RegisterPage("sounds", function(parent)
    return Config.BuildSchemaPage(parent, sounds, getSounds())
end, { label = sounds.label, icon = sounds.icon, object = sounds, schema = getSounds })

-- exposed for the smoke test
Config.MirrorCollect, Config.MirrorApplyAll = collect, applyAll
