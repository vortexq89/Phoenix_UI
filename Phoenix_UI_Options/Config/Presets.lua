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
    c.title = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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
    c.name = c.bars[1]:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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

Config.LookCard = lookCard

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
    { type = "button", label = "SETUP_WIZARD", desc = "SETUP_WIZARD_DESC", button = "SETUP_WIZARD_BUTTON", icon = "presets",
      keywords = "first install setup wizard start", func = function() Config:RunSetupWizard() end },
    { type = "button", label = "MODPICK_OPEN", desc = "MODPICK_OPEN_DESC", button = "MODPICK_OPEN_BUTTON", icon = "addon",
      keywords = "modules choose enable disable first install", func = function() Config:ShowModulePicker(true) end },
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
    ui.setupStarted = true
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
                Config:ShowModulePicker(Config.wizardForce)
            end)
            c:SetPoint("TOPLEFT", 18 + (i - 1) * 244, -80)
            picker.cards[i] = c
        end
        picker.skip = W:Button(picker, L.STYLE_PICKER_SKIP, "secondary", nil, 140)
        picker.skip:SetPoint("BOTTOMRIGHT", -18, 14)
        picker.skip.onClick = function()
            ui.stylePicked = "skip"; picker:Hide(); Config:ShowModulePicker(Config.wizardForce)
        end
        picker.close.onClick = picker.skip.onClick
    end
    picker:Show()
    return picker
end

---------------------------------------------------------------- first-install module picker
--[[ The second step of a first install: every optional module with its icon, name and one-line description,
    switched on or off before anything is applied. Nothing changes until Apply; modules that only take effect
    after a reload turn the button into "Apply and reload". Reopen it any time from Tools > Presets. ]]
local modPicker
local COLS, ROW_H, COL_W = 2, 44, 362

local function pickable()
    local out = {}
    for _, m in ipairs(ns.moduleList) do
        if not m.locked and not m.hidden and m.db then out[#out + 1] = m end
    end
    return out
end

local function modRow(parent, m, onToggle)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(COL_W, ROW_H - 4)
    r.icon = W.Icon(r, m.icon, 16, "accent.primary")
    r.icon:SetPoint("LEFT", 10, 0)
    r.label = W.Text(r, "body", "text.primary")
    r.label:SetPoint("TOPLEFT", 36, -5)
    r.label:SetPoint("RIGHT", -56, 0)
    r.label:SetText(L[m.label] or m.label)
    r.desc = W.Text(r, "small", "text.muted")
    r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -2)
    r.desc:SetPoint("RIGHT", -56, 0)
    r.desc:SetText(L[m.desc] or "")
    r.toggle = W:Toggle(r)
    r.toggle:SetPoint("RIGHT", -10, 0)
    r.toggle.onChange = function(_, v) onToggle(m, v) end
    Skin:Register(r, function(self)
        Skin:Panel(self, "raised", { border = "border.subtle" })
        Skin:Text(self.label, "body", "text.primary")
        Skin:Text(self.desc, "small", "text.muted")
    end)
    return r
end

local pending = {} -- module -> chosen state, applied together

local function needsReload()
    for m, v in pairs(pending) do
        if m.reloadOnToggle and v ~= m.db.enabled then return true end
    end
    return false
end

local function refreshApply()
    modPicker.apply:SetText(needsReload() and L.MODPICK_APPLY_RELOAD or L.MODPICK_APPLY)
end

function Config:ShowModulePicker(force)
    local ui = ns.DB.sv.global.ui
    if not force and (ui.modulesPicked or not ns.DB.fresh) then return end
    if InCombatLockdown() then return end
    wipe(pending)
    if not modPicker then
        local mods = pickable()
        local rows = math.ceil(#mods / COLS)
        modPicker = W:Popup(L.MODPICK_TITLE, COLS * (COL_W + 10) + 26, 130 + rows * ROW_H, "addon")
        modPicker.intro = W.Text(modPicker, "body", "text.secondary", "LEFT")
        modPicker.intro:SetPoint("TOPLEFT", 18, -44)
        modPicker.intro:SetPoint("RIGHT", -18, 0)
        modPicker.intro:SetWordWrap(true)
        modPicker.intro:SetText(L.MODPICK_INTRO)
        modPicker.rows = {}
        for i, m in ipairs(mods) do
            local r = modRow(modPicker, m, function(mod, v) pending[mod] = v; refreshApply() end)
            local col, line = (i - 1) % COLS, math.floor((i - 1) / COLS)
            r:SetPoint("TOPLEFT", 18 + col * (COL_W + 10), -78 - line * ROW_H)
            r.module = m
            modPicker.rows[i] = r
        end
        modPicker.apply = W:Button(modPicker, L.MODPICK_APPLY, "primary", "check", 180)
        modPicker.apply:SetPoint("BOTTOMRIGHT", -18, 14)
        modPicker.keep = W:Button(modPicker, L.MODPICK_KEEP, "secondary", nil, 160)
        modPicker.keep:SetPoint("RIGHT", modPicker.apply, "LEFT", -10, 0)
    end
    for _, r in ipairs(modPicker.rows) do r.toggle:SetValue(r.module.db.enabled) end
    modPicker.keep.onClick = function() ui.modulesPicked = true; modPicker:Hide(); Config:ShowSetupFinish(Config.wizardForce) end
    modPicker.close.onClick = modPicker.keep.onClick
    modPicker.apply.onClick = function()
        local reload = needsReload()
        local n = 0
        for m, v in pairs(pending) do
            if v ~= m.db.enabled then ns:SetModuleEnabled(m.key, v); n = n + 1 end
        end
        ui.modulesPicked = true
        modPicker:Hide()
        if reload then ReloadUI() return end -- the last step opens after the reload (UI/Launcher.lua)
        Config:SetStatus(L.MODPICK_DONE:format(n), "state.success", "addon")
        refreshPage()
        Config:ShowSetupFinish(Config.wizardForce)
    end
    refreshApply()
    modPicker:Show()
    return modPicker
end

---------------------------------------------------------------- first-install last step: scale and layout
--[[ Third and last step of the setup wizard (style -> modules -> this): pick the UI scale (pixel-perfect for
    this screen, or keep the game's), then finish or go straight to Layout mode to arrange the frames. Opens by
    itself once after the module step (also after its reload); rerun the whole wizard from Presets. ]]
local finish
function Config:ShowSetupFinish(force)
    local ui = ns.DB.sv.global.ui
    if not force and (ui.setupDone or not ui.setupStarted) then return end
    if InCombatLockdown() then return end
    Config.wizardForce = nil
    local gen = ns.modules.General
    if not finish then
        finish = W:Popup(L.SETUP_FINISH_TITLE, 560, 230, "layout")
        finish.intro = W.Text(finish, "body", "text.secondary", "LEFT")
        finish.intro:SetPoint("TOPLEFT", 18, -44)
        finish.intro:SetPoint("RIGHT", -18, 0)
        finish.intro:SetWordWrap(true)
        finish.intro:SetText(L.SETUP_FINISH_INTRO)
        finish.scaleLabel = W.Text(finish, "heading", "text.muted")
        finish.scaleLabel:SetPoint("TOPLEFT", 18, -96)
        finish.scaleLabel:SetText(L.SETUP_SCALE:upper())
        finish.scale = W:Chips(finish, { { value = "pixel", label = L.SETUP_SCALE_PIXEL },
            { value = "game", label = L.SETUP_SCALE_GAME } })
        finish.scale:SetPoint("TOPLEFT", 18, -116)
        finish.scale.onChange = function(_, v)
            if not gen or not gen.db then return end
            ns.DB:Set(gen, "scale.enabled", v == "pixel")
            if v == "pixel" then ns.DB:Set(gen, "scale.auto", true) end
        end
        finish.arrange = W:Button(finish, L.SETUP_ARRANGE, "primary", "movers", 190)
        finish.arrange:SetPoint("BOTTOMRIGHT", -18, 14)
        finish.done = W:Button(finish, L.SETUP_DONE, "secondary", "check", 140)
        finish.done:SetPoint("RIGHT", finish.arrange, "LEFT", -10, 0)
        local function close()
            ui.setupDone = true
            finish:Hide()
        end
        finish.done.onClick = close
        finish.close.onClick = close
        finish.arrange.onClick = function()
            close()
            local mv = ns.modules.Movers
            if mv and mv:IsEnabled() then
                if _G.PhoenixUI_Config then _G.PhoenixUI_Config:Hide() end
                mv:SetUnlocked(true)
            end
        end
    end
    finish.scale:SetValue(gen and gen.db and gen.db.scale and gen.db.scale.enabled and "pixel" or "game")
    finish:Show()
    return finish
end

-- The whole wizard again (Presets > Setup wizard): every step opens even when it was done before.
function Config:RunSetupWizard()
    Config.wizardForce = true
    return Config:ShowStylePicker(true)
end
