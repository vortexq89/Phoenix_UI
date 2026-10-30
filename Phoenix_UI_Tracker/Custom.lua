local _, ns = ...
local L, Skin, Secret = ns.L, ns.Skin, ns.Secret
local M = ns.modules.Tracker

--[[ Custom bars: Phoenix's own icon rows for spells, items and trinkets the Cooldown Manager cannot show (it only
    offers your class's spells). Everything is secret-safe in combat:
      cooldown   C_Spell.GetSpellCooldownDuration -> Cooldown:SetCooldownFromDurationObject (charges: the recharge
                 from C_Spell.GetSpellChargeDuration, the count from C_Spell.GetSpellDisplayCount -> SetText)
      ready      duration:IsZero() only reaches sinks: SetDesaturation(EvaluateColorValueFromBoolean), the ready
                 glow's and the icon's SetAlphaFromBoolean ("show only on cooldown / when ready")
      items      C_Item.GetItemCooldown (plain for items) and C_Item.GetItemCount; trinkets from the equipped slots
    The GCD is hidden only when C_Spell.GetSpellCooldown says so in a plain value. Proc glows use the game's own
    spell alert (ActionButtonSpellAlertManager) or a Phoenix glow. Icons keep their place (an icon cannot move on a
    secret answer); the bar lays out once per list change, out of combat or in. ]]

local bars = {}       -- key -> { icons = {}, entries = {} }
local samples = {}    -- key -> { frames }
M.customBars = bars
local NAME_CACHE = {}

local function newIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetAllPoints()
    f.Cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.Cooldown:SetAllPoints()
    f.Cooldown:SetDrawEdge(false)
    f.Charge = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.Charge:SetAllPoints()
    f.Charge:SetDrawSwipe(false)
    f.Charge:SetHideCountdownNumbers(true)
    f.holder = CreateFrame("Frame", nil, f)
    f.holder:SetAllPoints(f.Icon)
    f.holder:SetFrameLevel(f:GetFrameLevel() + 4)
    f.Count = f.holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Keybind = f.holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink((e.kind == "spell" and "spell:" or "item:") .. e.id)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

-- bar display: a StatusBar to the right of the icon. Spells drain through StatusBar:SetTimerDuration (the
-- duration object stays secret-safe); items get a plain start / duration; without the API the bar stays full.
local function barPart(f)
    if f.Bar then return f.Bar end
    local b = CreateFrame("StatusBar", nil, f)
    b:SetMinMaxValues(0, 1)
    b:SetValue(1)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.name:SetPoint("LEFT", 4, 0)
    b.name:SetJustifyH("LEFT")
    b.track = b:CreateTexture(nil, "BACKGROUND", nil, -6)
    b.track:SetPoint("TOPLEFT", -2, 2)
    b.track:SetPoint("BOTTOMRIGHT", 2, -2)
    f.Bar = b
    return b
end
M.CustomBarPart = barPart

local function layoutBar(key, f, e, size)
    local v = M:Viewer(key)
    if v.display ~= "bars" then if f.Bar then f.Bar:Hide() end return 0 end
    local b = barPart(f)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
    b:SetSize(v.barWidth or 180, size)
    M:StyleBar(key, b, b.name)
    -- v8.1 track (THEME_API §7.04 MythicPlus.forces / DamageMeter.row.track); the flat look keeps the backdrop
    local A = ns.Art
    local art = A and A.PaintSlot and A:PaintSlot(b.track, "DamageMeter.row.track", 0.5)
    b.track:SetShown(art and true or false)
    if art then ns.Art.OutlineText(b.name) end
    local name = e.kind == "spell" and C_Spell.GetSpellName and C_Spell.GetSpellName(e.id)
        or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(e.id))
    b.name:SetText(name or "")
    b:Show()
    return (v.barWidth or 180) + 4
end

local function fillBar(f, d)
    local b = f.Bar
    if not (b and b:IsShown()) then return end
    if d and b.SetTimerDuration then
        local ok = pcall(b.SetTimerDuration, b, d, Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate,
            Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime)
        if ok then return end
    end
    b:SetMinMaxValues(0, 1)
    b:SetValue(1)
end
M.FillCustomBar = fillBar

local function styleIcon(key, f)
    local v = M:Viewer(key)
    M:StyleIcon(key, f.Icon, f.holder, nil, f.Count, f.Keybind)
    Skin:Place(f.Count, f.holder, v.count)
    local ct = ns:Loaded("CooldownText")
    if ct and ct.Claim then ct:Claim(f.Cooldown, v.timerSource == "own") end
    if v.timerSource == "own" then
        local fs = f.Cooldown:GetCountdownFontString()
        if fs then Skin:TextSpec(fs, v.timer, "number", "text.primary") end
    end
    f.Cooldown:SetSwipeColor(0, 0, 0, v.swipeAlpha)
    f:EnableMouse(v.tooltips and true or false)
end

---------------------------------------------------------------- the list
local function knownSpell(id)
    local api = C_SpellBook
    if not (api and api.IsSpellKnown) then return true end
    local ok, yes = pcall(api.IsSpellKnown, id)
    if not ok or Secret.IsSecret(yes) then return true end
    return yes and true or false
end

local function resolveName(name)
    if NAME_CACHE[name] ~= nil then return NAME_CACHE[name] or nil end
    local ok, id = pcall(C_Spell.GetSpellIDForSpellIdentifier, name)
    id = ok and type(id) == "number" and not Secret.IsSecret(id) and id or nil
    NAME_CACHE[name] = id or false
    return id
end

local function itemCount(id)
    local ok, n = pcall(C_Item.GetItemCount, id, false, true)
    if not ok or Secret.IsSecret(n) then return 1 end
    return tonumber(n) or 0
end

-- Movement cooldowns per class (spell IDs; unknown or untalented ones are skipped like any entry).
M.MOBILITY = {
    WARRIOR = { 6544, 100, 3411 }, PALADIN = { 190784, 1044 }, HUNTER = { 781, 186257 },
    ROGUE = { 2983, 36554, 195457 }, PRIEST = { 121536, 73325 }, DEATHKNIGHT = { 48265, 212552 },
    SHAMAN = { 58875, 192063, 79206 }, MAGE = { 1953, 212653 }, WARLOCK = { 48020, 111400 },
    MONK = { 109132, 115008, 119996 }, DRUID = { 1850, 252216, 102401 }, DEMONHUNTER = { 195072, 198793, 189110 },
    EVOKER = { 358267 },
}
-- "Movement row": fills a custom bar's list with the class's movement spells.
function M:FillMobility(key, class)
    class = class or select(2, UnitClass("player"))
    local ids = M.MOBILITY[class]
    if not ids then return nil end
    local list = table.concat(ids, ", ")
    ns.DB:Set(self, "viewers." .. key .. ".list", list)
    return list
end

-- The entries a custom bar shows now: known spells, items you carry, equipped trinkets with a use.
function M:CustomEntries(key)
    local v, out = self:Viewer(key), {}
    local list = M.ParseList(v.list)
    if v.trinkets then
        list[#list + 1] = { kind = "slot", id = 13 }
        list[#list + 1] = { kind = "slot", id = 14 }
    end
    for _, e in ipairs(list) do
        if e.kind == "name" then
            local id = resolveName(e.name)
            if id then e = { kind = "spell", id = id, need = e.need, without = e.without } end
        end
        if (e.need and not knownSpell(e.need)) or (e.without and knownSpell(e.without)) then
            -- talent condition not met: skipped
        elseif e.kind == "slot" then
            local item = GetInventoryItemID("player", e.id)
            local hasUse = item and C_Item.GetItemSpell and C_Item.GetItemSpell(item)
            if item and hasUse then out[#out + 1] = { kind = "item", id = item, slot = e.id } end
        elseif e.kind == "spell" and knownSpell(e.id) then
            out[#out + 1] = e
        elseif e.kind == "item" and itemCount(e.id) > 0 then
            out[#out + 1] = e
        end
    end
    return out
end

---------------------------------------------------------------- secret-safe updates
-- `known` says whether `zero` was read at all: zero itself may be secret, so it is never compared or tested here.
local function applyReady(key, f, zero, known)
    local v = M:Viewer(key)
    if not known then return end
    local curve = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
    if v.desaturate and curve then
        local ok, d = pcall(curve, zero, 0, 1)
        if ok then f.Icon:SetDesaturation(d) end
    else
        f.Icon:SetDesaturation(0)
    end
    if v.show == "cooldown" then f:SetAlphaFromBoolean(zero, 0, 1)
    elseif v.show == "ready" then f:SetAlphaFromBoolean(zero, 1, 0)
    else f:SetAlpha(1) end
    if v.readyGlow ~= "none" then
        local r, g, b, a = M:GlowColor(key, "readyColor")
        local glow = ns.Glow:Show(f, v.readyGlow, r, g, b, a, "ready")
        glow:SetAlphaFromBoolean(zero, 1, 0)
    else
        ns.Glow:Hide(f, "ready")
    end
end

local function onGCD(id)
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    local gcd = ok and type(info) == "table" and info.isOnGCD
    return not Secret.IsSecret(gcd) and gcd == true
end

local function updateSpell(key, f, id)
    local v = M:Viewer(key)
    local zero, known = nil, false
    if v.hideGCD and onGCD(id) then
        f.Cooldown:Clear()
        zero, known = true, true
    else
        local ok, d = pcall(C_Spell.GetSpellCooldownDuration, id)
        if ok and d then
            pcall(f.Cooldown.SetCooldownFromDurationObject, f.Cooldown, d)
            fillBar(f, d)
            local okZ, z = pcall(d.IsZero, d)
            if okZ then zero, known = z, true end
        end
    end
    if v.charges and C_Spell.GetSpellChargeDuration then
        local ok, d = pcall(C_Spell.GetSpellChargeDuration, id)
        if ok and d then pcall(f.Charge.SetCooldownFromDurationObject, f.Charge, d) end
        local okC, text = pcall(C_Spell.GetSpellDisplayCount, id)
        if okC then f.Count:SetText(text) else f.Count:SetText("") end
    else
        f.Charge:Clear()
        f.Count:SetText("")
    end
    applyReady(key, f, zero, known)
    local okO, lit = pcall(C_SpellActivationOverlay.IsSpellOverlayed, id)
    M:CustomProc(key, f, okO and not Secret.IsSecret(lit) and lit == true)
end

local function updateItem(key, f, id)
    local start, duration, enable = C_Item.GetItemCooldown(id)
    pcall(CooldownFrame_Set, f.Cooldown, start, duration, enable)
    local plain = not Secret.IsSecret(duration) and not Secret.IsSecret(start)
    if f.Bar and f.Bar:IsShown() and plain then -- item cooldowns are plain: fraction left, set on each poll
        local left = (tonumber(duration) or 0) > 1.5 and math.max(0, (start + duration - GetTime()) / duration) or 0
        f.Bar:SetMinMaxValues(0, 1)
        f.Bar:SetValue(1 - left)
    end
    local zero = plain and (tonumber(duration) or 0) <= 1.5
    local n = itemCount(id)
    f.Count:SetText(n > 1 and n or "")
    f.Charge:Clear()
    applyReady(key, f, zero, plain)
end

-- Changes only on a transition (the poll runs every 0.25 s; re-showing Blizzard's alert would restart its animation).
function M:CustomProc(key, f, on)
    local style = self:Viewer(key).procGlow
    local want = on and style or "none"
    if f.procStyle == want then return end
    local manager = ActionButtonSpellAlertManager
    if f.procStyle == "blizzard" and manager then manager:HideAlert(f) end
    ns.Glow:Hide(f, "proc")
    f.procStyle = want
    if want == "blizzard" then
        if manager then manager:ShowAlert(f) end
    elseif want ~= "none" then
        local r, g, b, a = M:GlowColor(key, "procColor")
        ns.Glow:Show(f, want, r, g, b, a, "proc")
    end
end

local function updateIcon(key, f)
    local e = f.entry
    if not e then return end
    if e.kind == "spell" then updateSpell(key, f, e.id) else updateItem(key, f, e.id) end
end

---------------------------------------------------------------- build and lay out
local function texture(e)
    if e.kind == "spell" then return C_Spell.GetSpellTexture(e.id) end
    return C_Item.GetItemIconByID(e.id)
end

function M:BuildCustom(key)
    local b = bars[key]
    if not b then b = { icons = {} }; bars[key] = b end
    local v = self:Viewer(key)
    local entries = (self:IsEnabled() and v.enabled) and self:CustomEntries(key) or {}
    b.entries = entries
    local k = v.position.scale or 1
    local Lk = {}
    for name, val in pairs(v.layout) do Lk[name] = val end
    Lk.size, Lk.spacing, Lk.overflow = math.floor(v.layout.size * k + 0.5), math.floor(v.layout.spacing * k + 0.5), "row"
    local barsMode = v.display == "bars"
    if barsMode then Lk.perRow, Lk.growth, Lk.wrap = 1, "RIGHT", Lk.wrap == "UP" and "UP" or "DOWN"; Lk.rowDelta = 0 end
    local pos, w, h = M.Grid(#entries, Lk)
    local a = self:PlaceAnchor(key, w + (barsMode and (v.barWidth or 180) + 4 or 0), h)
    for i, e in ipairs(entries) do
        local f = b.icons[i] or newIcon(a)
        b.icons[i] = f
        f.entry = e
        f:SetSize(pos[i].size, pos[i].size)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", a, "TOPLEFT", pos[i].x, -pos[i].y)
        f.Icon:SetTexture(texture(e))
        styleIcon(key, f)
        layoutBar(key, f, e, pos[i].size)
        local text = v.keybinds and e.kind == "spell" and M.KeyForSpell(e.id) or nil
        f.Keybind:SetText(text or "")
        f:Show()
        M:CustomProc(key, f, false) -- settings may have changed: the next update redraws the proc glow
        ns.SafeCall(updateIcon, key, f)
    end
    for i = #entries + 1, #b.icons do
        local f = b.icons[i]
        f.entry = nil
        f:Hide()
        ns.Glow:Hide(f, "ready")
        M:CustomProc(key, f, false)
    end
end

function M:UpdateCustom()
    for key, b in pairs(bars) do
        for _, f in ipairs(b.icons) do if f.entry and f:IsShown() then ns.SafeCall(updateIcon, key, f) end end
    end
end

function M:ApplyCustomAlpha(state)
    for _, def in ipairs(M.VIEWERS) do
        local a = def.custom and M.anchors[def.key]
        if a then a:SetAlpha(self:AlphaFor(def.key, state)) end
    end
end

---------------------------------------------------------------- lifecycle
local UPDATE_EVENTS = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "BAG_UPDATE_COOLDOWN",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" }
local REBUILD_EVENTS = { "SPELLS_CHANGED", "TRAIT_CONFIG_UPDATED",
    "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_SPECIALIZATION_CHANGED",
    "UPDATE_BINDINGS" }

function M:EnableCustom()
    for _, ev in ipairs(UPDATE_EVENTS) do self:On(ev, M.UpdateCustom) end
    for _, ev in ipairs(REBUILD_EVENTS) do self:On(ev, M.RefreshCustom) end
    -- readiness changes without an event when a cooldown runs out: a light poll of the shown icons
    if not self.customTicker then
        self.customTicker = C_Timer.NewTicker(0.25, function() if M:IsEnabled() then ns.SafeCall(M.UpdateCustom, M) end end)
    end
end

function M:DisableCustom()
    for key in pairs(bars) do
        for _, f in ipairs(bars[key].icons) do f.entry = nil; f:Hide() end
    end
end

function M:RefreshCustom()
    for _, def in ipairs(M.VIEWERS) do
        if def.custom then ns.SafeCall(M.BuildCustom, M, def.key) end
    end
end

---------------------------------------------------------------- Test: samples where everything sits
local I = {
    "Interface\\Icons\\Spell_Fire_Fireball02", "Interface\\Icons\\Spell_Frost_IceStorm",
    "Interface\\Icons\\Spell_Holy_PowerWordShield", "Interface\\Icons\\Ability_Warrior_ShieldWall",
    "Interface\\Icons\\Spell_Nature_Lightning", "Interface\\Icons\\Ability_Rogue_Sprint",
    "Interface\\Icons\\Spell_Arcane_TeleportDalaran", "Interface\\Icons\\Ability_Mage_LivingBomb",
    "Interface\\Icons\\Ability_Warrior_BattleShout", "Interface\\Icons\\INV_Misc_PocketWatch_01",
}
M.SAMPLE_ICONS = I
local COUNTS = { essential = 7, utility = 6, buffs = 5, bars = 3, custom1 = 4, custom2 = 3, custom3 = 3 }
-- per sample: icon, seconds left on a 30 s cooldown (0 = ready), stacks / charges text, proc
local SAMPLE = { { 1, 0, "", true }, { 2, 8 }, { 3, 0 }, { 4, 24, "2" }, { 5, 0 }, { 6, 12 }, { 7, 0 }, { 8, 3, "3" },
    { 9, 0 }, { 10, 18 } }

local function sampleIcons(key, n)
    local s = samples[key]
    if not s then s = {}; samples[key] = s end
    local v = M:Viewer(key)
    local k = (v.position.mode == "mover" or M.IsCustom(key)) and (v.position.scale or 1) or 1
    local Lk = {}
    for name, val in pairs(v.layout) do Lk[name] = val end
    Lk.size, Lk.spacing = math.floor(v.layout.size * k + 0.5), math.floor(v.layout.spacing * k + 0.5)
    local pos, w, h = M.Grid(n, Lk)
    local a = M:PlaceAnchor(key, w, h)
    for i = 1, n do
        local f = s[i] or newIcon(a)
        s[i] = f
        local d, p = SAMPLE[i], pos[i]
        f:SetShown(p ~= nil)
        if p then
            f:SetSize(p.size, p.size)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", a, "TOPLEFT", p.x, -p.y)
            f.Icon:SetTexture(I[d[1]])
            styleIcon(key, f)
            f:EnableMouse(false)
            if d[2] > 0 then CooldownFrame_Set(f.Cooldown, GetTime() - (30 - d[2]), 30, 1) else f.Cooldown:Clear() end
            f.Icon:SetDesaturated(v.desaturate and d[2] > 0 or false)
            f.Count:SetText(d[3] or "")
            f.Keybind:SetText(v.keybinds and ("S" .. i) or "")
            local r, g, b = M:GlowColor(key, "procColor")
            if d[4] and v.procGlow ~= "none" then ns.Glow:Show(f, v.procGlow == "blizzard" and "button" or v.procGlow, r, g, b, 1, "proc")
            else ns.Glow:Hide(f, "proc") end
        end
    end
end

local function sampleBars(key, n)
    local s = samples[key]
    if not s then s = {}; samples[key] = s end
    local v = M:Viewer(key)
    local L_ = v.layout
    local ys, total = M.Stack(n, { height = L_.height, spacing = L_.spacing, wrap = L_.wrap })
    local a = M:PlaceAnchor(key, L_.width, total)
    for i = 1, n do
        local f = s[i]
        if not f then
            f = CreateFrame("Frame", nil, a)
            f.icon = newIcon(f)
            f.Bar = CreateFrame("StatusBar", nil, f)
            f.Bar:SetMinMaxValues(0, 1)
            f.name = f.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            f.name:SetPoint("LEFT", 4, 0)
            f.time = f.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            f.time:SetPoint("RIGHT", -4, 0)
            s[i] = f
        end
        f:Show()
        f:SetSize(L_.width, L_.height)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -ys[i])
        f.icon:SetSize(L_.height, L_.height)
        f.icon:ClearAllPoints()
        f.icon:SetPoint(L_.iconSide == "RIGHT" and "RIGHT" or "LEFT", f, L_.iconSide == "RIGHT" and "RIGHT" or "LEFT", 0, 0)
        f.icon:SetShown(L_.iconSide ~= "OFF")
        f.icon.Icon:SetTexture(I[SAMPLE[i + 1][1]])
        styleIcon(key, f.icon)
        f.Bar:ClearAllPoints()
        f.Bar:SetPoint("TOPLEFT", f, "TOPLEFT", L_.iconSide == "LEFT" and L_.height + 2 or 0, 0)
        f.Bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", L_.iconSide == "RIGHT" and -(L_.height + 2) or 0, 0)
        M:StyleBar(key, f.Bar, f.name, f.time)
        f.Bar:SetValue(1 - i * 0.25)
        f.name:SetText(L["PREVIEW_TRACKER_BUFF_" .. i] or "")
        f.time:SetText(("%.1f"):format(16 - i * 4.5))
    end
end

function M:DrawTest()
    self:HideTest()
    for _, def in ipairs(M.VIEWERS) do
        local v = self:Viewer(def.key)
        if not def.custom or v.enabled then
            local n = COUNTS[def.key]
            if def.bars then sampleBars(def.key, n) else sampleIcons(def.key, n) end
        end
    end
    self:DrawReminderTest() -- Reminders.lua
end

function M:HideTest()
    for _, s in pairs(samples) do
        for _, f in ipairs(s) do
            f:Hide()
            ns.Glow:Hide(f, "proc")
        end
    end
    if self.HideReminderTest then self:HideReminderTest() end
    if self:IsEnabled() then
        for key in pairs(self.viewerFrames) do self:QueueLayout(key) end
        self:RefreshCustom()
    end
end
