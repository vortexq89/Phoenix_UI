local _, ns = ...
local L = ns.L
local W, Skin, Media, Theme = ns.Widgets, ns.Skin, ns.Media, ns.Theme
local Config = ns.Config
local U = ns.Util

--[[ Tools > Presets: three complete looks, applied in one click, with Undo for the session. A preset only
    writes settings that already exist (the same values you could pick by hand); it never adds or renames
    saved keys. "Follow the theme" puts every font and texture row that allows it back to Default, so the
    whole interface takes the preset's General choices. The same cards open once on a first install. ]]
local PRESETS = {
    { key = "ember", label = "PRESET_EMBER", desc = "PRESET_EMBER_DESC",
      general = { preset = "ember", barTexture = "Satin", uiFont = "", unitFont = "" },
      border = "shadow" },
    { key = "clean", label = "PRESET_CLEAN", desc = "PRESET_CLEAN_DESC",
      general = { preset = "frost", barTexture = "Flat", uiFont = "InterMedium", unitFont = "InterSemiBold" },
      border = "solid" },
    { key = "vivid", label = "PRESET_VIVID", desc = "PRESET_VIVID_DESC",
      general = { preset = "arcane", barTexture = "Gloss", uiFont = "BarlowSemiCondSemiBold", unitFont = "BarlowCondBold" },
      border = "glow" },
}
Config.PRESETS = PRESETS

-- Border style rows each preset sets (module, path); scoped paths list every unit.
local BORDERS = {
    { "Auras", "border.style" }, { "NamePlates", "border.style" }, { "GroupFrames", "border.style" },
    { "CastBars", "bars.player.border.style" }, { "CastBars", "bars.target.border.style" },
    { "CastBars", "bars.focus.border.style" },
    { "Tracker", "viewers.essential.border.style" }, { "Tracker", "viewers.utility.border.style" },
    { "Tracker", "viewers.buffs.border.style" }, { "Tracker", "viewers.bars.border.style" },
}

local undo -- { { m, path, old }, ... } of the last preset applied this session

local function set(changes, m, path, value)
    if not (m and m.db) then return end
    local old = U.GetPath(m.db, path)
    if old == nil or U.Equal(old, value) then return end
    changes[#changes + 1] = { m, path, U.DeepCopy(old) }
    ns.DB:Set(m, path, value)
end

-- Every font/texture row that can follow the theme, as (module, path) pairs.
local function followRows()
    local out = {}
    if not Config.MirrorCollect then return out end
    for _, kind in ipairs({ "font", "texture" }) do
        for _, e in ipairs(Config.MirrorCollect(kind)) do
            if e.item.allowDefault then
                if e.units then
                    for _, u in ipairs(e.units) do out[#out + 1] = { e.m, (e.item.key:gsub("@", u)) } end
                else
                    out[#out + 1] = { e.m, e.item.key }
                end
            end
        end
    end
    return out
end

function Config:ApplyPreset(key)
    local p
    for _, it in ipairs(PRESETS) do if it.key == key then p = it end end
    if not p then return 0 end
    local changes = {}
    local general = ns.modules.General
    for k, v in pairs(p.general) do set(changes, general, "theme." .. k, v) end
    for _, b in ipairs(BORDERS) do
        local m = ns.modules[b[1]]
        if m and U.GetPath(m.defaults, b[2]) ~= nil then set(changes, m, b[2], p.border) end
    end
    for _, r in ipairs(followRows()) do set(changes, r[1], r[2], "") end
    undo = changes
    ns.Theme:Apply(general.db.theme)
    return #changes
end

function Config:UndoPreset()
    if not undo then return 0 end
    local n = #undo
    for i = n, 1, -1 do
        local c = undo[i]
        ns.DB:Set(c[1], c[2], c[3])
    end
    undo = nil
    ns.Theme:Apply(ns.modules.General.db.theme)
    return n
end

function Config:CanUndoPreset() return undo ~= nil end

---------------------------------------------------------------- the look card
-- A preview of one look: accent strip, three bars in its texture and colours, a name in its unit font.
local function lookCard(parent, p, width, onApply)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(width, 150)
    c.accent = W.Texture(c, "ARTWORK", 2)
    c.accent:SetPoint("TOPLEFT", 1, -1); c.accent:SetPoint("TOPRIGHT", -1, -1)
    c.accent:SetHeight(2)
    c.title = c:CreateFontString(nil, "OVERLAY")
    c.title:SetPoint("TOPLEFT", 14, -14)
    c.desc = W.Text(c, "small", "text.secondary", "LEFT")
    c.desc:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -6)
    c.desc:SetPoint("RIGHT", -14, 0)
    c.desc:SetWordWrap(true)
    c.bars = {}
    for i, v in ipairs({ 0.86, 0.6, 0.34 }) do
        local b = CreateFrame("StatusBar", nil, c)
        b:SetMinMaxValues(0, 1); b:SetValue(v)
        b:SetHeight(i == 1 and 16 or 10)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.edge = CreateFrame("Frame", nil, b)
        b.edge:SetAllPoints()
        c.bars[i] = b
    end
    c.bars[1]:SetPoint("BOTTOMLEFT", 14, 50); c.bars[1]:SetPoint("BOTTOMRIGHT", -14, 50)
    c.bars[2]:SetPoint("TOPLEFT", c.bars[1], "BOTTOMLEFT", 0, -5); c.bars[2]:SetPoint("RIGHT", -14, 0)
    c.bars[3]:SetPoint("TOPLEFT", c.bars[2], "BOTTOMLEFT", 0, -4); c.bars[3]:SetPoint("RIGHT", -14, 0)
    c.name = c.bars[1]:CreateFontString(nil, "OVERLAY")
    c.name:SetPoint("LEFT", 6, 0)
    c.apply = W:Button(c, L.PRESET_APPLY, "primary", "check", 110)
    c.apply:SetPoint("BOTTOMRIGHT", -12, 10)
    c.apply.onClick = function() onApply(p) end
    local function paint(self)
        local colors = Theme:PresetColors(p.general.preset)
        local pr, pg, pb = unpack(colors.primary)
        local sr, sg, sb = unpack(colors.secondary)
        Skin:Panel(self, "raised", { border = "border.subtle" })
        self.accent:SetColorTexture(pr, pg, pb, 1)
        local unitFont = p.general.unitFont ~= "" and Media:Font(p.general.unitFont) or Theme:Font("unit")
        local uiFont = p.general.uiFont ~= "" and Media:Font(p.general.uiFont) or Theme:Font("body")
        self.title:SetFont(uiFont, 15, "")
        self.title:SetTextColor(Theme:Color("text.primary"))
        self.title:SetText(L[p.label])
        self.desc:SetText(L[p.desc])
        local tex = Media:Bar(p.general.barTexture)
        local fills = { { pr, pg, pb }, { sr, sg, sb }, { Theme:Color("state.info") } }
        for i, b in ipairs(self.bars) do
            b:SetStatusBarTexture(tex)
            b:SetStatusBarColor(fills[i][1], fills[i][2], fills[i][3])
            b.bg:SetTexture(tex)
            b.bg:SetVertexColor(0.08, 0.08, 0.1, 0.85)
            Skin:BorderSpec(b.edge, { style = p.border, size = 1, color = false }, "border.black")
        end
        self.name:SetFont(unitFont, 11, "OUTLINE")
        self.name:SetText(L.PREVIEW_UNIT_PLAYER)
    end
    Skin:Register(c, paint)
    return c
end

---------------------------------------------------------------- page
local page = { key = "presets", label = "PRESETS", desc = "PRESETS_DESC", icon = "presets", locked = true, db = {} }

local function refreshPage()
    local pg = Config.pages and Config.pages[Config.current]
    if pg and pg.Refresh then pg:Refresh() end
end

local function applied(p)
    local n = Config:ApplyPreset(p.key)
    Config:SetStatus(L.PRESET_APPLIED:format(L[p.label], n), "state.success", "presets")
    refreshPage()
end

local function cardsRow(row)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetPoint("TOPLEFT", 16, -6)
    holder:SetPoint("BOTTOMRIGHT", -16, 6)
    holder.cards = {}
    local function layout()
        local w = holder:GetWidth()
        if not w or w <= 0 then return end
        local cw = math.floor((w - 2 * 12) / 3)
        for i, c in ipairs(holder.cards) do
            c:SetWidth(cw)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", (i - 1) * (cw + 12), 0)
        end
    end
    for i, p in ipairs(PRESETS) do holder.cards[i] = lookCard(holder, p, 220, applied) end
    holder:SetScript("OnSizeChanged", layout)
    layout()
    return holder
end

local schema = {
    { type = "header", label = "PRESETS_LOOKS", icon = "presets", wide = true },
    { type = "description", text = "PRESETS_INTRO" },
    { type = "custom", label = "PRESETS_LOOKS", fullWidth = true, height = 166, build = cardsRow },
    { type = "header", label = "PRESETS_UNDO_HEADER", icon = "reset" },
    { type = "button", label = "PRESETS_UNDO", desc = "PRESETS_UNDO_DESC", button = "PRESETS_UNDO_BUTTON", icon = "reset",
      func = function()
          local n = Config:UndoPreset()
          Config:SetStatus(n > 0 and L.PRESET_UNDONE:format(n) or L.PRESET_NOTHING, n > 0 and "state.success" or nil, "reset")
          refreshPage()
      end },
    { type = "button", label = "PRESETS_PICKER", desc = "PRESETS_PICKER_DESC", button = "PRESETS_PICKER_BUTTON", icon = "preview",
      func = function() Config:ShowStylePicker(true) end },
}

Config:RegisterPage("presets", function(parent)
    return Config.BuildSchemaPage(parent, page, schema)
end, { label = page.label, icon = page.icon, object = page, schema = schema })

---------------------------------------------------------------- first-install style picker
local picker
function Config:ShowStylePicker(force)
    local ui = ns.DB.sv.global.ui
    if not force and (ui.stylePicked or not ns.DB.fresh) then return end
    if InCombatLockdown() then return end
    if not picker then
        picker = W:Popup(L.STYLE_PICKER_TITLE, 760, 286, "presets")
        picker.intro = W.Text(picker, "body", "text.secondary", "LEFT")
        picker.intro:SetPoint("TOPLEFT", 18, -44)
        picker.intro:SetPoint("RIGHT", -18, 0)
        picker.intro:SetWordWrap(true)
        picker.intro:SetText(L.STYLE_PICKER_INTRO)
        picker.cards = {}
        for i, p in ipairs(PRESETS) do
            local c = lookCard(picker, p, 232, function(choice)
                applied(choice)
                ui.stylePicked = choice.key
                picker:Hide()
            end)
            c:SetPoint("TOPLEFT", 18 + (i - 1) * 244, -80)
            picker.cards[i] = c
        end
        picker.skip = W:Button(picker, L.STYLE_PICKER_SKIP, "secondary", nil, 140)
        picker.skip:SetPoint("BOTTOMRIGHT", -18, 14)
        picker.skip.onClick = function() ui.stylePicked = "skip"; picker:Hide() end
        picker.close.onClick = picker.skip.onClick
    end
    picker:Show()
    return picker
end
