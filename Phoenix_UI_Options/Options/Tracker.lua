local _, ns = ...
local Opt = ns.Opt

--[[ Cooldown Manager (plan v2 S12; module key "Tracker"). The scope bar picks one of Blizzard's four viewers or one
    of the three Phoenix custom bars; every "viewers.@…" row belongs to it. Which spells the viewers show is
    Blizzard's own choice (the Choose spells button); Phoenix re-lays their icons on its grid, dresses them, adds
    glows, keybinds and visibility rules. Countdown numbers come from Cooldown Text unless a viewer claims them. ]]
local function v(m, key) return m:Viewer(key) end
local function unstyled(m, key) return not v(m, key).style end
local function round(m, key) return unstyled(m, key) or not v(m, key).square end
local function isBars(_, key) return key == "bars" end
local function notBars(_, key) return key ~= "bars" end
local function isCustom(_, key) return ns.modules.Tracker.IsCustom(key) end
local function notCustom(_, key) return not ns.modules.Tracker.IsCustom(key) end
local function notIcons(_, key) return key == "bars" end
local function noGrid(m, key) return unstyled(m, key) or not v(m, key).layout.enabled end
local function noGridBars(m, key) return isBars(m, key) or noGrid(m, key) end
local function notEssential(_, key) return key ~= "essential" end
local function timerCT(m, key) return unstyled(m, key) or v(m, key).timerSource ~= "own" end
local function noReady(m, key) return v(m, key).readyGlow == "none" end
local function noProc(m, key) return v(m, key).procGlow == "none" or v(m, key).procGlow == "blizzard" end
local function editmode(m, key) return not ns.modules.Tracker.IsCustom(key) and v(m, key).position.mode == "editmode" end
local function remOff(m) return not m.db.reminders.enabled end
local function customOff(m, key) return isCustom(m, key) and not v(m, key).enabled end

local function notCustomBars(m, key) return notCustom(m, key) or v(m, key).display ~= "bars" end
local DISPLAY = { { value = "icons", label = "TRACKER_DISPLAY_ICONS" }, { value = "bars", label = "TRACKER_DISPLAY_BARS" } }

--[[ Spell picker (EllesmereUI parity): your spellbook's active spells as icons, filtered by a search box; a click
    adds the spell to the custom bar's list or takes it out. Talent conditions ("?ID" / "!ID") typed in the list stay. ]]
local W = ns.Widgets
local PICK_COLS, PICK_ROWS, PICK_SIZE = 12, 2, 26
function ns.Opt.SpellbookSpells()
    local out, api = {}, C_SpellBook
    if not (api and api.GetNumSpellBookSkillLines and api.GetSpellBookSkillLineInfo and api.GetSpellBookItemInfo) then return out end
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local seen = {}
    local okN, lines = pcall(api.GetNumSpellBookSkillLines)
    for line = 1, okN and tonumber(lines) or 0 do
        local info = api.GetSpellBookSkillLineInfo(line)
        local isT = type(info) == "table"
        local first = isT and tonumber(info.itemIndexOffset)
        local count = isT and tonumber(info.numSpellBookItems)
        if first and count and not info.shouldHide then
            for i = first + 1, first + count do
                local s = api.GetSpellBookItemInfo(i, bank)
                s = type(s) == "table" and s or nil
                local id = s and s.spellID
                if id and not s.isPassive and not s.isOffSpec and not seen[id] and type(s.name) == "string" then
                    seen[id] = true
                    out[#out + 1] = { id = id, name = s.name, icon = s.iconID }
                end
            end
        end
    end
    return out
end

-- the list without / with one spell id (other entries and their talent conditions are kept as typed)
function ns.Opt.ToggleListSpell(list, id)
    local parts, found = {}, false
    for part in tostring(list or ""):gmatch("[^,;\n]+") do
        local p = part:gsub("^%s+", ""):gsub("%s+$", "")
        local pid = tonumber(p:match("^(%d+)"))
        if pid == id then found = true elseif p ~= "" then parts[#parts + 1] = p end
    end
    if not found then parts[#parts + 1] = tostring(id) end
    return table.concat(parts, ", "), not found
end

local function inList(list, id)
    for part in tostring(list or ""):gmatch("[^,;\n]+") do
        if tonumber(part:match("^%s*(%d+)")) == id then return true end
    end
    return false
end

local function spellPicker(row, m, page)
    local h = CreateFrame("Frame", nil, row)
    h:SetSize(PICK_COLS * (PICK_SIZE + 4), 26 + PICK_ROWS * (PICK_SIZE + 4))
    h.search = W:Input(h, 200, ns.L.TRACKER_PICK_SEARCH)
    h.search:SetPoint("TOPLEFT")
    h.cells = {}
    for i = 1, PICK_COLS * PICK_ROWS do
        local b = CreateFrame("Button", nil, h)
        b:SetSize(PICK_SIZE, PICK_SIZE)
        b:SetPoint("TOPLEFT", ((i - 1) % PICK_COLS) * (PICK_SIZE + 4), -26 - math.floor((i - 1) / PICK_COLS) * (PICK_SIZE + 4))
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.mark = CreateFrame("Frame", nil, b)
        b.mark:SetPoint("TOPLEFT", -2, 2); b.mark:SetPoint("BOTTOMRIGHT", 2, -2)
        ns.Skin:Border(b.mark, "accent.primary", 2)
        if ns.Art and ns.Art.DressSlot then
            ns.Art:DressSlot(b, "IconGallery.cell", { out = 3, scale = 0.5, layer = "BACKGROUND", level = 0 })
        end
        b:SetScript("OnClick", function(self)
            local key = page and page.scope and page.scope.unit
            if not (key and self.id) then return end
            local list = ns.Opt.ToggleListSpell(m:Viewer(key).list, self.id)
            ns.DB:Set(m, "viewers." .. key .. ".list", list)
            if m.RefreshCustom then m:RefreshCustom() end
            h:SetValue()
        end)
        b:SetScript("OnEnter", function(self)
            if not self.id then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.id)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        h.cells[i] = b
    end
    function h:SetValue()
        local key = page and page.scope and page.scope.unit
        local list = key and m.IsCustom(key) and m:Viewer(key).list or ""
        local q = (self.search:GetText() or ""):lower()
        local shown = 0
        for _, s in ipairs(ns.Opt.SpellbookSpells()) do
            if shown >= #self.cells then break end
            if q == "" or s.name:lower():find(q, 1, true) then
                shown = shown + 1
                local b = self.cells[shown]
                b.id = s.id
                b.icon:SetTexture(s.icon)
                b.mark:SetShown(inList(list, s.id))
                b:Show()
            end
        end
        for i = shown + 1, #self.cells do self.cells[i].id = nil; self.cells[i]:Hide() end
    end
    h.search.onTextChanged = function() h:SetValue() end
    ns.Events:Listen("PUI_SETTING_CHANGED", h, function(_, _, key) if key == "Tracker" then h:SetValue() end end)
    h:SetValue()
    return h
end

local SCOPE = {
    { value = "essential", label = "TRACKER_ESSENTIAL" }, { value = "utility", label = "TRACKER_UTILITY" },
    { value = "buffs", label = "TRACKER_BUFFS" }, { value = "bars", label = "TRACKER_BARS" },
    { value = "custom1", label = "TRACKER_CUSTOM1" }, { value = "custom2", label = "TRACKER_CUSTOM2" },
    { value = "custom3", label = "TRACKER_CUSTOM3" },
}
local WRAP = { { value = "DOWN", label = "GROW_DOWN" }, { value = "UP", label = "GROW_UP" },
    { value = "RIGHT", label = "GROW_RIGHT" }, { value = "LEFT", label = "GROW_LEFT" } }
local BAR_WRAP = { { value = "DOWN", label = "GROW_DOWN" }, { value = "UP", label = "GROW_UP" } }
local OVERFLOW = { { value = "row", label = "TRACKER_OVERFLOW_ROW" }, { value = "hide", label = "TRACKER_OVERFLOW_HIDE" },
    { value = "utility", label = "TRACKER_OVERFLOW_UTILITY" } }
local POSITION = { { value = "editmode", label = "TRACKER_POS_EDITMODE" }, { value = "mover", label = "TRACKER_POS_MOVER" } }
local BAR_ICON = { { value = "LEFT", label = "ANCHOR_LEFT" }, { value = "RIGHT", label = "ANCHOR_RIGHT" },
    { value = "OFF", label = "OFF" } }
local TIMER = { { value = "cooldowntext", label = "TRACKER_TIMER_CT" }, { value = "own", label = "TRACKER_TIMER_OWN" } }
local PROC = { { value = "blizzard", label = "AB_STYLE_BLIZZARD" }, { value = "pixel", label = "AB_GLOW_PIXEL" },
    { value = "autocast", label = "AB_GLOW_AUTOCAST" }, { value = "button", label = "AB_GLOW_BUTTON" },
    { value = "none", label = "AB_STYLE_NONE" } }
local READY = { { value = "none", label = "AB_STYLE_NONE" }, { value = "pixel", label = "AB_GLOW_PIXEL" },
    { value = "autocast", label = "AB_GLOW_AUTOCAST" }, { value = "button", label = "AB_GLOW_BUTTON" } }
local SHOW = { { value = "always", label = "TRACKER_SHOW_ALWAYS" }, { value = "cooldown", label = "TRACKER_SHOW_COOLDOWN" },
    { value = "ready", label = "TRACKER_SHOW_READY" } }
local VIS = { { value = "always", label = "TRACKER_VIS_ALWAYS" }, { value = "combat", label = "TRACKER_VIS_COMBAT" },
    { value = "target", label = "TRACKER_VIS_TARGET" }, { value = "combatOrTarget", label = "TRACKER_VIS_EITHER" },
    { value = "never", label = "TRACKER_VIS_NEVER" } }

local function sounds()
    local out = { { value = "", label = "NONE" } }
    for _, s in ipairs(ns.Media:List("sound")) do out[#out + 1] = { value = s.value, label = s.label } end
    return out
end

-- The spec filters: one toggle per specialization slot of your class (1-4, in the talent pane's order).
local function specRow(row, i)
    return Opt.With(row, { type = "toggle", key = "viewers.@.visibility.spec" .. i, combat = true,
        hidden = function()
            local _, _, classID = UnitClass("player")
            local n = classID and C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 4
            return i > n
        end })
end

local function toggleTest(m)
    if not m:IsEnabled() then return end
    if not m:ShowTest(not m.testShown) then ns.Config:SetStatus(ns.L.UF_TEST_COMBAT, "state.warning", "warning") end
end

local function openLayout()
    local movers = ns:GetModule("Movers")
    if not movers or not movers:IsEnabled() then
        ns.Config:SetStatus(ns.L.AB_LAYOUT_NEEDS_MOVERS, "state.warning", "warning")
        return
    end
    ns.Config.frame:Hide()
    movers:SetUnlocked(true)
end

-- Blizzard's Cooldown Manager switch belongs to Quality of Life; this row mirrors it and links there.
local cdmGet, cdmSet = ns.Combat.CVarAccessors("cooldownViewerEnabled")
local cdmLink = setmetatable({ key = "Quality" }, { __index = function(_, k)
    if k ~= "item" then return nil end
    for _, item in ipairs(ns.options.Quality or {}) do if item.label == "COOLDOWN_MANAGER" then return item end end
end })
local function cvarRow()
    return { type = "toggle", label = "COOLDOWN_MANAGER", desc = "COOLDOWN_MANAGER_DESC", get = cdmGet, set = cdmSet,
        combat = true, keywords = "enable cooldown manager blizzard advanced options", link = cdmLink }
end

ns:RegisterOptions("Tracker", {
    { type = "scope", key = "viewers", label = "TRACKER_VIEWER", values = SCOPE },
    { type = "preview", kind = "tracker" },
    ------------------------------------------------------------ Layout
    { type = "tab", label = "TRACKER_TAB_LAYOUT" },
    { type = "header", label = "TRACKER_MANAGER", icon = "tracker" },
    cvarRow(),
    { type = "button", label = "TRACKER_OPEN_CDM", desc = "TRACKER_OPEN_CDM_DESC", button = "BUGS_OPEN", icon = "tracker",
      keywords = "cooldown manager spells auras choose", func = function(m) m:OpenCooldownManager() end },
    { type = "button", label = "TRACKER_TEST", desc = "TRACKER_TEST_DESC", button = "GF_TEST_BUTTON", icon = "test",
      func = toggleTest, keywords = "test sample preview world" },
    { type = "button", label = "UF_LAYOUT_MODE", desc = "TRACKER_LAYOUT_MODE_DESC", button = "AB_LAYOUT_MODE_BUTTON",
      icon = "movers", combat = true, func = openLayout, keywords = "move drag unlock position" },
    { type = "header", label = "TRACKER_CUSTOM", icon = "items", hidden = notCustom },
    { type = "toggle", key = "viewers.@.enabled", label = "TRACKER_CUSTOM_ENABLE", desc = "TRACKER_CUSTOM_ENABLE_DESC",
      hidden = notCustom },
    { type = "input", key = "viewers.@.list", label = "TRACKER_CUSTOM_LIST", desc = "TRACKER_CUSTOM_LIST_DESC", hidden = notCustom,
      disabled = customOff, width = 320, keywords = "spell id item trinket list custom" },
    { type = "custom", label = "TRACKER_PICK", desc = "TRACKER_PICK_DESC", height = 92, hidden = notCustom, disabled = customOff,
      build = spellPicker, keywords = "spell picker spellbook choose add" },
    { type = "select", key = "viewers.@.display", label = "TRACKER_DISPLAY", desc = "TRACKER_DISPLAY_DESC", values = DISPLAY,
      hidden = notCustom, disabled = customOff, keywords = "bars buff bars cooldown bars icons" },
    { type = "range", key = "viewers.@.barWidth", label = "TRACKER_BAR_WIDTH", min = 60, max = 400, step = 1,
      hidden = notCustomBars, disabled = customOff },
    { type = "color", key = "viewers.@.barColor", label = "TRACKER_BAR_COLOR", reset = true, token = "accent.primary",
      hidden = notCustomBars, disabled = customOff },
    { type = "button", label = "TRACKER_MOBILITY", desc = "TRACKER_MOBILITY_DESC", button = "TRACKER_MOBILITY_BUTTON",
      icon = "speed", hidden = notCustom, disabled = customOff, keywords = "movement mobility blink dash sprint",
      func = function(m, page)
          local key = page and page.scope and page.scope.unit
          if key then m:FillMobility(key); if page.Refresh then page:Refresh() end end
      end },
    { type = "toggle", key = "viewers.@.trinkets", label = "TRACKER_CUSTOM_TRINKETS", desc = "TRACKER_CUSTOM_TRINKETS_DESC",
      hidden = notCustom, disabled = customOff },
    { type = "select", key = "viewers.@.show", label = "TRACKER_SHOW", desc = "TRACKER_SHOW_DESC", values = SHOW,
      hidden = notCustom, disabled = customOff },
    { type = "toggle", key = "viewers.@.charges", label = "TRACKER_CHARGES", desc = "TRACKER_CHARGES_DESC",
      hidden = notCustom, disabled = customOff },
    { type = "toggle", key = "viewers.@.tooltips", label = "TRACKER_TOOLTIPS", hidden = notCustom, disabled = customOff },
    { type = "header", label = "TRACKER_LAYOUT", icon = "grid" },
    { type = "toggle", key = "viewers.@.layout.enabled", label = "TRACKER_LAYOUT_ON", desc = "TRACKER_LAYOUT_ON_DESC",
      disabled = unstyled, hidden = isCustom, keywords = "grid rows icons per row size spacing" },
    { type = "range", key = "viewers.@.layout.size", label = "ICON_SIZE", min = 16, max = 80, step = 1, disabled = noGrid,
      hidden = isBars },
    { type = "range", key = "viewers.@.layout.perRow", label = "TRACKER_PER_ROW", min = 1, max = 20, step = 1,
      disabled = noGrid, hidden = isBars },
    { type = "range", key = "viewers.@.layout.rows", label = "AB_ROWS", min = 1, max = 6, step = 1, disabled = noGrid,
      hidden = isBars },
    { type = "range", key = "viewers.@.layout.rowDelta", label = "TRACKER_ROW_DELTA", desc = "TRACKER_ROW_DELTA_DESC",
      min = -20, max = 20, step = 1, disabled = noGrid, hidden = isBars },
    { type = "range", key = "viewers.@.layout.spacing", label = "TRACKER_SPACING", min = 0, max = 20, step = 1,
      disabled = noGrid },
    { type = "select", key = "viewers.@.layout.growth", label = "AB_GROW", values = Opt.GROWTH, disabled = noGrid,
      hidden = isBars },
    { type = "select", key = "viewers.@.layout.wrap", label = "AB_WRAP", desc = "AB_WRAP_DESC", values = WRAP,
      disabled = noGridBars, hidden = isBars },
    { type = "toggle", key = "viewers.@.layout.center", label = "TRACKER_CENTER", desc = "TRACKER_CENTER_DESC",
      disabled = noGrid, hidden = isBars },
    { type = "toggle", key = "viewers.@.layout.keepInPlace", label = "TRACKER_KEEP", desc = "TRACKER_KEEP_DESC",
      disabled = noGrid, hidden = isCustom },
    { type = "select", key = "viewers.@.layout.overflow", label = "TRACKER_OVERFLOW", desc = "TRACKER_OVERFLOW_DESC",
      values = OVERFLOW, disabled = noGrid, hidden = notEssential },
    { type = "range", key = "viewers.@.layout.width", label = "UF_WIDTH", min = 80, max = 400, step = 1, disabled = noGrid,
      hidden = notBars },
    { type = "range", key = "viewers.@.layout.height", label = "UF_HEIGHT", min = 12, max = 48, step = 1, disabled = noGrid,
      hidden = notBars },
    { type = "select", key = "viewers.@.layout.wrap", label = "AB_WRAP", values = BAR_WRAP, disabled = noGrid, hidden = notBars },
    { type = "select", key = "viewers.@.layout.iconSide", label = "TRACKER_BAR_ICON", values = BAR_ICON, disabled = noGrid,
      hidden = notBars },
    { type = "toggle", key = "viewers.@.layout.reverse", label = "TRACKER_REVERSE", disabled = noGrid, hidden = notBars },
    { type = "header", label = "TRACKER_POSITION", icon = "movers" },
    { type = "select", key = "viewers.@.position.mode", label = "TRACKER_POS", desc = "TRACKER_POS_DESC", values = POSITION,
      hidden = isCustom, disabled = noGrid, combat = true },
    { type = "range", key = "viewers.@.position.scale", label = "SCALE", min = 0.5, max = 2, step = 0.05, percent = true,
      disabled = editmode },
    ------------------------------------------------------------ Appearance
    { type = "tab", label = "TAB_APPEARANCE" },
    { type = "header", label = "TRACKER_ICONS", icon = "tracker" },
    { type = "toggle", gate = true, key = "viewers.@.style", label = "TRACKER_SKIN", desc = "TRACKER_SKIN_DESC", reload = true,
      keywords = "cooldown manager weakauras skin", hidden = isCustom },
    { type = "toggle", key = "viewers.@.square", label = "TRACKER_SQUARE", desc = "TRACKER_SQUARE_DESC", disabled = unstyled,
      cog = { { type = "range", key = "viewers.@.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } },
    Opt.With(Opt.Border("viewers.@.border"), { disabled = round }),
    { type = "toggle", key = "viewers.@.hideDebuffBorder", label = "TRACKER_DEBUFF_BORDER", desc = "TRACKER_DEBUFF_BORDER_DESC",
      disabled = unstyled, hidden = isCustom },
    { type = "header", label = "TRACKER_BAR", icon = "textures", hidden = notBars },
    { type = "texture", key = "viewers.@.texture", label = "BAR_TEXTURE", allowDefault = true, hidden = notBars, disabled = unstyled },
    { type = "color", key = "viewers.@.barColor", label = "TRACKER_BAR_COLOR", token = "accent.primary", reset = true,
      hidden = notBars, disabled = unstyled },
    { type = "select", key = "viewers.@.gradient", label = "TRACKER_GRADIENT", desc = "TRACKER_GRADIENT_DESC", values = Opt.GRADIENT,
      hidden = notBars, disabled = unstyled, keywords = "gradient shade shading fill" },
    Opt.With(Opt.Background("viewers.@.background"), { hidden = notBars, disabled = unstyled }),
    { type = "header", label = "TRACKER_STATE", icon = "cooldowntext", hidden = notIcons },
    { type = "toggle", key = "viewers.@.desaturate", label = "TRACKER_DESAT", desc = "TRACKER_DESAT_DESC", disabled = unstyled,
      hidden = notIcons, keywords = "grey gray desaturate cooldown" },
    { type = "toggle", key = "viewers.@.hideGCD", label = "TRACKER_HIDE_GCD", desc = "TRACKER_HIDE_GCD_DESC", disabled = unstyled,
      hidden = notIcons, keywords = "global cooldown gcd swipe" },
    { type = "range", key = "viewers.@.swipeAlpha", label = "TRACKER_SWIPE", min = 0, max = 1, step = 0.05, percent = true,
      disabled = unstyled, hidden = notIcons },
    { type = "toggle", key = "viewers.@.rangeTint", label = "TRACKER_RANGE", desc = "TRACKER_RANGE_DESC", disabled = unstyled,
      hidden = function(m, key) return notIcons(m, key) or isCustom(m, key) end },
    { type = "toggle", key = "viewers.@.keybinds", label = "TRACKER_KEYBINDS", desc = "TRACKER_KEYBINDS_DESC", disabled = unstyled,
      hidden = function(_, key) return key == "buffs" or key == "bars" end, keywords = "hotkey keybind binding" },
    { type = "header", label = "TRACKER_GLOWS", icon = "bell", hidden = notIcons },
    { type = "select", key = "viewers.@.procGlow", label = "TRACKER_PROC", desc = "TRACKER_PROC_DESC", values = PROC,
      disabled = unstyled, hidden = notIcons, keywords = "glow proc overlay alert",
      cog = { { type = "color", key = "viewers.@.procColor", label = "AB_PROC_COLOR", token = "accent.glow", reset = true,
        disabled = noProc } } },
    { type = "input", key = "auraGlows", label = "TRACKER_AURA_GLOWS", desc = "TRACKER_AURA_GLOWS_DESC", hidden = notIcons,
      keywords = "aura buff glow while proc highlight" },
    { type = "select", key = "viewers.@.readyGlow", label = "TRACKER_READY", desc = "TRACKER_READY_DESC", values = READY,
      disabled = unstyled, hidden = notIcons, keywords = "glow ready off cooldown",
      cog = { { type = "color", key = "viewers.@.readyColor", label = "TRACKER_READY_COLOR", token = "state.success", reset = true,
        disabled = noReady },
        { type = "range", key = "viewers.@.readyTime", label = "TRACKER_READY_TIME", min = 0.5, max = 5, step = 0.5,
          disabled = noReady } } },
    ------------------------------------------------------------ Text
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "TRACKER_TEXT", icon = "fonts", wide = true },
    { type = "select", key = "viewers.@.timerSource", label = "TRACKER_TIMER_SOURCE", desc = "TRACKER_TIMER_SOURCE_DESC",
      values = TIMER, disabled = unstyled, keywords = "countdown numbers cooldown text" },
    Opt.Text("viewers.@.timer", "TRACKER_TIMER_FONT", { max = 28, row = { disabled = timerCT } }),
    Opt.Text("viewers.@.count", "TRACKER_COUNT_FONT", { max = 24, row = { disabled = unstyled } }),
    Opt.Text("viewers.@.keybind", "TRACKER_KEYBIND_FONT", { max = 20, row = { disabled = unstyled,
        hidden = function(_, key) return key == "buffs" or key == "bars" end } }),
    Opt.Text("viewers.@.name", "TRACKER_NAME_FONT", { max = 20, row = { disabled = unstyled, hidden = notBars } }),
    ------------------------------------------------------------ Reminders
    { type = "tab", label = "TRACKER_TAB_REMINDERS" },
    { type = "header", label = "TRACKER_REMINDERS", icon = "bell" },
    { type = "toggle", gate = true, key = "reminders.enabled", label = "TRACKER_R_ENABLE", desc = "TRACKER_R_ENABLE_DESC",
      keywords = "reminder flask food rune oil buff pet healthstone missing" },
    { type = "toggle", key = "reminders.instancesOnly", label = "TRACKER_R_INSTANCES", desc = "TRACKER_R_INSTANCES_DESC",
      disabled = remOff },
    { type = "toggle", key = "reminders.flask", label = "TRACKER_R_FLASK", disabled = remOff, feature = "cdmReminders" },
    { type = "toggle", key = "reminders.food", label = "TRACKER_R_FOOD", disabled = remOff, feature = "cdmReminders" },
    { type = "toggle", key = "reminders.rune", label = "TRACKER_R_RUNE", disabled = remOff, feature = "cdmReminders" },
    { type = "toggle", key = "reminders.raidBuff", label = "TRACKER_R_RAIDBUFF", desc = "TRACKER_R_RAIDBUFF_DESC",
      disabled = remOff, feature = "cdmReminders" },
    { type = "toggle", key = "reminders.oil", label = "TRACKER_R_OIL", disabled = remOff },
    { type = "toggle", key = "reminders.pet", label = "TRACKER_R_PET", disabled = remOff },
    { type = "toggle", key = "reminders.healthstone", label = "TRACKER_R_HEALTHSTONE", desc = "TRACKER_R_HEALTHSTONE_DESC",
      disabled = remOff },
    { type = "toggle", key = "reminders.readyMana", label = "TRACKER_R_MANA", desc = "TRACKER_R_MANA_DESC", disabled = remOff,
      cog = { { type = "range", key = "reminders.manaPercent", label = "TRACKER_R_MANA_PCT", min = 10, max = 100, step = 5 } } },
    { type = "range", key = "reminders.size", label = "ICON_SIZE", min = 20, max = 64, step = 1, disabled = remOff },
    { type = "select", key = "reminders.sound", label = "TRACKER_R_SOUND", values = sounds, disabled = remOff },
    { type = "description", text = "TRACKER_NOTE" },
    ------------------------------------------------------------ Visibility
    { type = "tab", label = "TAB_BEHAVIOUR" },
    { type = "header", label = "AB_VISIBILITY", icon = "opacity" },
    { type = "select", key = "viewers.@.visibility.mode", label = "TRACKER_VIS", desc = "TRACKER_VIS_DESC", values = VIS,
      keywords = "show hide combat target visibility" },
    { type = "toggle", key = "viewers.@.visibility.mounted", label = "TRACKER_VIS_MOUNTED" },
    { type = "toggle", key = "viewers.@.visibility.vehicle", label = "TRACKER_VIS_VEHICLE" },
    { type = "header", label = "TRACKER_SPECS", icon = "spec" },
    specRow({ label = "TRACKER_SPEC_1" }, 1), specRow({ label = "TRACKER_SPEC_2" }, 2),
    specRow({ label = "TRACKER_SPEC_3" }, 3), specRow({ label = "TRACKER_SPEC_4" }, 4),
    { type = "button", label = "TRACKER_PROFILES", desc = "TRACKER_PROFILES_DESC", button = "TRACKER_PROFILES_BUTTON",
      icon = "profiles", keywords = "per spec profile automatic",
      func = function() ns.Config:Show("profiles") end },
    { type = "header", label = "TRACKER_FADE", icon = "opacity" },
    { type = "toggle", key = "fade.enabled", label = "TRACKER_FADE_OOC", desc = "TRACKER_FADE_OOC_DESC",
      keywords = "hide out of combat opacity alpha",
      cog = { { type = "range", key = "fade.alpha", label = "TRACKER_FADE_ALPHA", min = 0, max = 1, step = 0.05, percent = true } } },
})
