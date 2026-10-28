local _, ns = ...
local L, Skin, Theme, Media = ns.L, ns.Skin, ns.Theme, ns.Media
local M = ns.modules.UnitFrames

--[[ Detached player resource bars and the totem bar (plan v2 S18, EllesmereUI ResourceBars / WindTools parity).

    Resource bars  One movable block (Layout mode) of plain bars for the player: health, power, a druid's mana
                   while shapeshifted, the class resource (the player frame's own pips code, M:UpdateClassPower, on
                   a frame of ours) and a spec bar. Rows that have nothing to show collapse when `collapse` is on, so
                   the block shifts up. Health and power are secret in combat: they only reach SetMinMaxValues /
                   SetValue and the tag format strings (the same tags as the frames).
    Spec bars      Ironfur, Ignore Pain, Sweeping Strikes, Soul Fragments and Ebon Might: the player's own aura
                   (C_UnitAuras.GetPlayerAuraBySpellID), drawn as its stacks or its remaining time (a duration
                   object handed to StatusBar:SetTimerDuration), with its stacks or absorb as text. Retail only.
    Totem bar      Four secure buttons (SecureActionButtonTemplate, type "destroytotem" on right click: DestroyTotem
                   is protected) showing GetTotemInfo's icon and GetTotemDuration's swipe; empty slots fade
                   through SetAlphaFromBoolean (the "have totem" flag can be secret). Built, sized and placed out of
                   combat. With it on, the game's TotemFrame stays out of sight. ]]

local Enum_ = Enum or {}
local TIMER = Enum_.StatusBarTimerDirection or {}
local INTERP = Enum_.StatusBarInterpolation or {}
local PT = Enum_.PowerType or {}
local plain = M.plain

local IRONFUR, IGNORE_PAIN = 192081, 190456 -- spellIDs(retail): Ironfur, Ignore Pain
local SWEEPING_STRIKES = 260708 -- spellIDs(retail): Sweeping Strikes
local SOUL_FRAGMENTS = 203981 -- spellIDs(retail): Soul Fragments
local EBON_MIGHT = 395296 -- spellIDs(retail): Ebon Might
local GUARDIAN, PROTECTION_WARRIOR, ARMS, VENGEANCE, AUGMENTATION = 104, 73, 71, 581, 1473

-- spec ID -> { spell, mode = "stacks"|"time", max = stacks, text = "stacks"|"absorb"|nil }
M.SPEC_BARS = {
    [GUARDIAN] = { spell = IRONFUR, mode = "time", text = "stacks" },
    [PROTECTION_WARRIOR] = { spell = IGNORE_PAIN, mode = "time", text = "absorb" },
    [ARMS] = { spell = SWEEPING_STRIKES, mode = "time" },
    [VENGEANCE] = { spell = SOUL_FRAGMENTS, mode = "stacks", max = 6, text = "stacks" },
    [AUGMENTATION] = { spell = EBON_MIGHT, mode = "time" },
}

local function playerSpec()
    local api = C_SpecializationInfo
    local index = api and api.GetSpecialization and api.GetSpecialization()
    local id = plain(index) and index and api.GetSpecializationInfo and api.GetSpecializationInfo(index) or nil
    return plain(id) and id or nil
end
M.PlayerSpecID = playerSpec

---------------------------------------------------------------- rows (pure)
--[[ Which rows a block shows, top to bottom, and where: { { key, y, h }, … }, total height. `active` says which rows
    have something to draw now; a row that has nothing collapses when `collapse` is on, else it keeps its room. ]]
M.RESOURCE_ROWS = { "health", "power", "mana", "class", "spec" }
function M.ResourceRows(r, active)
    local out, y = {}, 0
    for _, key in ipairs(M.RESOURCE_ROWS) do
        local cfg = key == "mana" and r.power or r[key]
        local on = cfg and cfg.show and (key ~= "mana" or r.power.mana)
        if on and (active[key] or not r.collapse) then
            local h = key == "mana" and math.max(3, math.floor(r.power.height * 0.6 + 0.5)) or cfg.height
            out[#out + 1] = { key = key, y = y, h = h, empty = not active[key] }
            y = y + h + r.spacing
        end
    end
    return out, math.max(1, y - r.spacing)
end

---------------------------------------------------------------- resource block
local block
local function bar(parent)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetStatusBarTexture(Media.textures.WHITE)
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(Media.textures.WHITE)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetWordWrap(false)
    b:Hide()
    return b
end

-- The block's widgets: built once, the preview builds its own with the same function.
function M:BuildResources(parent, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", opts.name, parent)
    f:SetSize(220, 40)
    -- (Live and Sample sources read f.unit / f.unitKey / f.sample: this frame is "the player")
    f.unit, f.unitKey, f.sample, f.detached, f.noLayout = "player", "player", opts.sample, true, true
    f.rows = { health = bar(f), power = bar(f), mana = bar(f), spec = bar(f) }
    f.ClassPower = CreateFrame("Frame", nil, f)
    f.ClassPower.pips = {}
    f.ClassPower.bar = CreateFrame("StatusBar", nil, f.ClassPower)
    f.ClassPower.bar:SetStatusBarTexture(Media.textures.WHITE)
    f.ClassPower.bar:SetMinMaxValues(0, 1)
    f.ClassPower.bar:SetAllPoints()
    f.ClassPower.bar.bg = f.ClassPower.bar:CreateTexture(nil, "BACKGROUND")
    f.ClassPower.bar.bg:SetAllPoints()
    f.ClassPower.bar.bg:SetTexture(Media.textures.WHITE)
    f.ClassPower.bar:Hide()
    f.ClassPower:Hide()
    f.rows.class = f.ClassPower
    return f
end

-- Sample data for the preview's resource block: one entry per class (power, class resource, spec bar, druid mana).
local CLASS_SAMPLE = {
    WARRIOR = { powerToken = "RAGE", power = 64, powerMax = 100, spec = IGNORE_PAIN },
    PALADIN = { powerToken = "MANA", classPowerKind = "HolyPower", classPower = 3, classPowerMax = 5 },
    HUNTER = { powerToken = "FOCUS", power = 72, powerMax = 100 },
    ROGUE = { powerToken = "ENERGY", power = 80, powerMax = 100, classPowerKind = "ComboPoints", classPower = 5, classPowerMax = 7 },
    PRIEST = { powerToken = "MANA" },
    DEATHKNIGHT = { powerToken = "RUNIC_POWER", power = 55, powerMax = 125, classPowerKind = "Runes", classPower = 4,
                    classPowerMax = 6 },
    SHAMAN = { powerToken = "MANA" },
    MAGE = { powerToken = "MANA", classPowerKind = "ArcaneCharges", classPower = 2, classPowerMax = 4 },
    WARLOCK = { powerToken = "MANA", classPowerKind = "SoulShards", classPower = 3, classPowerMax = 5 },
    MONK = { powerToken = "ENERGY", power = 70, powerMax = 100, classPowerKind = "Chi", classPower = 4, classPowerMax = 6 },
    DRUID = { powerToken = "ENERGY", power = 66, powerMax = 100, classPowerKind = "ComboPoints", classPower = 3,
              classPowerMax = 5, manaShift = true, spec = IRONFUR },
    DEMONHUNTER = { powerToken = "FOCUS", power = 90, powerMax = 120, spec = SOUL_FRAGMENTS },
    EVOKER = { powerToken = "MANA", classPowerKind = "Essence", classPower = 4, classPowerMax = 6, spec = EBON_MIGHT },
}
M.RESOURCE_SAMPLE = CLASS_SAMPLE

-- The preview's sample for a class (pure apart from the spell name lookup).
function M.ResourceSample(classFile)
    local c = CLASS_SAMPLE[classFile] or CLASS_SAMPLE.PALADIN
    local s = { name = "", class = CLASS_SAMPLE[classFile] and classFile or "PALADIN", hp = 412000, hpMax = 520000,
                power = c.power or 162000, powerMax = c.powerMax or 250000, powerToken = c.powerToken,
                classPowerKind = c.classPowerKind, classPower = c.classPower, classPowerMax = c.classPowerMax,
                manaShift = c.manaShift }
    if c.spec then
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(c.spec)
        s.specBar = { value = 0.6, label = type(name) == "string" and name or "" }
    end
    return s
end

local function texture(r)
    return r.texture ~= "" and Media:Bar(r.texture) or Theme:Bar()
end

-- What each row has to draw now (sample frames carry classPowerKind, specBar, manaShift).
function M:ResourceActive(f)
    local s = f.sample
    local active = { health = true, power = true }
    if s then
        active.class = s.classPowerKind ~= nil
        active.spec = s.specBar ~= nil and ns:Supports("specBars")
        active.mana = s.manaShift and true or false
        return active
    end
    active.class = M.ReadClassPower() ~= nil
    active.spec = ns:Supports("specBars") and M.SPEC_BARS[playerSpec() or 0] ~= nil
    local kind = UnitPowerType("player")
    local _, file = UnitClass("player")
    active.mana = plain(kind) and kind ~= (PT.Mana or 0) and plain(file) and file == "DRUID"
    return active
end

function M:LayoutResources(f)
    local r = self.db.resources
    f:SetFrameStrata(r.strata)
    f:SetWidth(r.width)
    local rows, height = M.ResourceRows(r, self:ResourceActive(f))
    f:SetHeight(height)
    for _, b in pairs(f.rows) do b:Hide() end
    local tex = texture(r)
    for _, row in ipairs(rows) do
        local b = f.rows[row.key]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -row.y)
        b:SetSize(r.width, row.h)
        b:Show()
        if b ~= f.ClassPower then
            b:SetStatusBarTexture(tex)
            Skin:BorderSpec(b, r.border, "border.black")
            Skin:Backdrop(b, r.background, "bg.sunken")
            local spec = (row.key == "health" and r.health.text) or (row.key == "power" and r.power.text) or nil
            if spec then
                Skin:TextSpec(b.text, spec, "number", "text.primary")
                Skin:Place(b.text, b, spec)
                b.text:SetShown(spec.show ~= false)
            else
                Skin:TextSpec(b.text, r.power.text, "number", "text.primary")
                Skin:Place(b.text, b, { anchor = "RIGHT" })
            end
        end
    end
    f.layoutRows = rows
    local d = self.db.percentDecimals
    f.compiledHealth = M.CompileTags(r.health.tag, d)
    f.compiledPower = M.CompileTags(r.power.tag, d)
end

local function drawSpec(f, b)
    local s = f.sample
    local def = s and s.specBar or M.SPEC_BARS[playerSpec() or 0]
    if not def then return end
    local r, g, bl = Theme:Color("state.warning")
    b:SetStatusBarColor(r, g, bl)
    b.bg:SetVertexColor(r * 0.2, g * 0.2, bl * 0.2, 0.9)
    if s then
        b:SetMinMaxValues(0, 1)
        b:SetValue(def.value or 0.6)
        b.text:SetText(def.label or "")
        return
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, def.spell)
    if not ok or aura == nil then b:SetMinMaxValues(0, 1); b:SetValue(0); b.text:SetText(""); return end
    if def.mode == "stacks" then
        b:SetMinMaxValues(0, def.max or 5)
        b:SetValue(aura.applications or 0)
    else
        local okD, d = pcall(C_UnitAuras.GetAuraDuration, "player", aura.auraInstanceID)
        if okD and d and b.SetTimerDuration then
            pcall(b.SetTimerDuration, b, d, INTERP.Immediate, TIMER.RemainingTime)
        else
            b:SetMinMaxValues(0, 1); b:SetValue(1)
        end
    end
    if def.text == "stacks" then
        pcall(function() b.text:SetText(C_UnitAuras.GetAuraApplicationDisplayCount("player", aura.auraInstanceID, 1, 99)) end)
    elseif def.text == "absorb" then
        pcall(function() b.text:SetText(M:Number(aura.points and aura.points[1] or 0)) end)
    else
        b.text:SetText("")
    end
end

function M:UpdateResources(f)
    if not f then return end
    local r = self.db.resources
    local src = self:SourceOf(f)
    -- rows appear and collapse as resources come and go (a plain frame: any time)
    local active = self:ResourceActive(f)
    local sig = (active.class and "c" or "") .. (active.spec and "s" or "") .. (active.mana and "m" or "")
    if sig ~= f.activeSig then f.activeSig = sig; self:LayoutResources(f) end
    local h, p, m = f.rows.health, f.rows.power, f.rows.mana
    if h:IsShown() then
        h:SetMinMaxValues(0, src:HealthMax(f))
        h:SetValue(src:Health(f))
        local cr, cg, cb = ns.Util.ClassColor(src:ClassFile(f) or select(2, UnitClass("player")))
        h:SetStatusBarColor(cr, cg, cb)
        h.bg:SetVertexColor(cr * 0.2, cg * 0.2, cb * 0.2, 0.9)
        M.ApplyTags(h.text, f.compiledHealth, f, src)
    end
    if p:IsShown() then
        local kind, token = src:PowerType(f)
        p:SetMinMaxValues(0, src:PowerMax(f))
        p:SetValue(src:Power(f))
        local pr, pg, pb = M.PowerColor(token, kind)
        p:SetStatusBarColor(pr, pg, pb)
        p.bg:SetVertexColor(pr * 0.2, pg * 0.2, pb * 0.2, 0.9)
        M.ApplyTags(p.text, f.compiledPower, f, src)
    end
    if m:IsShown() then
        local manaKind = PT.Mana or 0
        if f.sample then m:SetMinMaxValues(0, 1); m:SetValue(0.7) else
            m:SetMinMaxValues(0, UnitPowerMax("player", manaKind))
            m:SetValue(UnitPower("player", manaKind))
        end
        local mr, mg, mb = M.PowerColor("MANA", manaKind)
        m:SetStatusBarColor(mr, mg, mb)
        m.bg:SetVertexColor(mr * 0.2, mg * 0.2, mb * 0.2, 0.9)
        m.text:SetText("")
    end
    if f.ClassPower:IsShown() or active.class then
        if f.ClassPower:IsShown() then self:UpdateClassPower(f) end
    end
    if f.rows.spec:IsShown() then drawSpec(f, f.rows.spec) end
    if not f.sample then
        local ooc = not InCombatLockdown()
        f:SetAlpha((r.combatOnly and ooc) and r.oocAlpha or 1)
    end
end

local function resourceStore()
    return {
        active = function() return M:IsEnabled() and M:IsPhoenix() and M.db.resources.enabled end,
        get = function() local r = M.db.resources; return { point = r.point, x = r.x, y = r.y, scale = r.scale } end,
        set = function(v)
            local r = M.db.resources
            r.point, r.x, r.y = v.point or r.point, v.x or r.x, v.y or r.y
            if v.scale then r.scale = v.scale end
        end,
        apply = function() M:RefreshResources() end,
        reset = function()
            local d, r = M.DEFAULTS.resources, M.db.resources
            r.point, r.x, r.y, r.scale = d.point, d.x, d.y, d.scale
            M:RefreshResources()
        end,
    }
end

local function placeBlock()
    if not block then return end
    local r = M.db.resources
    local scale = r.scale > 0 and r.scale or 1
    block:SetScale(scale)
    block:ClearAllPoints()
    block:SetPoint(r.point, UIParent, r.point, r.x / scale, r.y / scale)
    block:SetShown(r.enabled)
    block.activeSig = nil
    M:LayoutResources(block)
    M:UpdateResources(block)
end

local function spawnBlock()
    block = M:BuildResources(UIParent, { name = "PhoenixUI_Resources" })
    M.resourceBlock = block
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("uf.resources", block, L.UF_RESOURCES, resourceStore()) end
    local function update() if block:IsShown() then ns.SafeCall(M.UpdateResources, M, block) end end
    local E = ns.Events
    for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
        "UNIT_AURA" }) do
        E:OnUnit(ev, block, update, "player")
    end
    for _, ev in ipairs({ "RUNE_POWER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM",
        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD" }) do
        E:On(ev, block, update)
    end
    -- runes recharge without events
    block.elapsed = 0
    block:SetScript("OnUpdate", function(self, e)
        self.elapsed = self.elapsed + e
        if self.elapsed < 0.1 then return end
        self.elapsed = 0
        if self.hasRunes then ns.SafeCall(M.UpdateClassPower, M, self) end
    end)
    placeBlock()
end

---------------------------------------------------------------- totem bar
local MAX = type(MAX_TOTEMS) == "number" and MAX_TOTEMS or 4
local totems

-- Slot offsets for n buttons of `size` and `spacing` growing RIGHT / LEFT / UP / DOWN (pure).
function M.TotemSlots(n, size, spacing, growth)
    local out = {}
    for i = 1, n do
        local d = (i - 1) * (size + spacing)
        if growth == "LEFT" then out[i] = { -d, 0 }
        elseif growth == "UP" then out[i] = { 0, d }
        elseif growth == "DOWN" then out[i] = { 0, -d }
        else out[i] = { d, 0 } end
    end
    return out
end

function M:BuildTotemButton(parent, slot, secure)
    local b = CreateFrame("Button", nil, parent, secure and "SecureActionButtonTemplate" or nil)
    b.slot = slot
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetAllPoints()
    b.Cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.Cooldown:SetAllPoints()
    b.Cooldown:SetDrawEdge(false)
    b.Cooldown:SetReverse(true)
    if secure then
        b:RegisterForClicks("RightButtonUp")
        b:SetAttribute("type2", "destroytotem")
        b:SetAttribute("totem-slot", slot)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
            if GameTooltip.SetTotem then GameTooltip:SetTotem(self.slot) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

function M:StyleTotemButton(b)
    local t = self.db.totems
    b:SetSize(t.size, t.size)
    Skin:IconZoom(b.Icon, t.zoom)
    Skin:BorderSpec(b, t.border, "border.black")
    local fs = b.Cooldown.GetCountdownFontString and b.Cooldown:GetCountdownFontString()
    if fs then
        Skin:TextSpec(fs, t.duration, "number", "text.primary")
        b.Cooldown:SetHideCountdownNumbers(t.duration.show == false)
    end
end

function M:UpdateTotem(b)
    local have, _, start, duration, icon = GetTotemInfo(b.slot)
    b.Icon:SetTexture(icon)
    if plain(have) then b:SetAlpha(have and 1 or 0) else b:SetAlphaFromBoolean(have, 1, 0) end
    if GetTotemDuration then
        local ok, d = pcall(GetTotemDuration, b.slot)
        if ok and d then b.Cooldown:SetCooldownFromDurationObject(d) end
    elseif plain(start) and plain(duration) and type(duration) == "number" and duration > 0 then
        b.Cooldown:SetCooldown(start, duration)
    end
end

local function totemStore()
    return {
        active = function() return M:IsEnabled() and M:IsPhoenix() and M.db.totems.style == "phoenix" end,
        get = function() local t = M.db.totems; return { point = t.point, x = t.x, y = t.y } end,
        set = function(v) local t = M.db.totems; t.point, t.x, t.y = v.point or t.point, v.x or t.x, v.y or t.y end,
        apply = function() M:RefreshResources() end,
        reset = function()
            local d, t = M.DEFAULTS.totems, M.db.totems
            t.point, t.x, t.y = d.point, d.x, d.y
            M:RefreshResources()
        end,
    }
end

local function placeTotemBar()
    if not totems or InCombatLockdown() then return end
    local t = M.db.totems
    local slots = M.TotemSlots(MAX, t.size, t.spacing, t.growth)
    local horizontal = t.growth == "LEFT" or t.growth == "RIGHT"
    local span = MAX * t.size + (MAX - 1) * t.spacing
    totems:SetSize(horizontal and span or t.size, horizontal and t.size or span)
    totems:ClearAllPoints()
    totems:SetPoint(t.point, UIParent, t.point, t.x, t.y)
    local anchor = (t.growth == "LEFT" and "TOPRIGHT") or (t.growth == "UP" and "BOTTOMLEFT") or "TOPLEFT"
    for i, b in ipairs(totems.buttons) do
        M:StyleTotemButton(b)
        b:ClearAllPoints()
        b:SetPoint(anchor, totems, anchor, slots[i][1], slots[i][2])
        M:UpdateTotem(b)
    end
    totems:SetShown(t.style == "phoenix")
end

local function spawnTotems()
    totems = CreateFrame("Frame", "PhoenixUI_Totems", UIParent)
    totems.buttons = {}
    for i = 1, MAX do totems.buttons[i] = M:BuildTotemButton(totems, i, true) end
    M.totemBar = totems
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("uf.totems", totems, L.UF_TOTEMS, totemStore()) end
    local function update() for _, b in ipairs(totems.buttons) do ns.SafeCall(M.UpdateTotem, M, b) end end
    ns.Events:On("PLAYER_TOTEM_UPDATE", totems, update)
    ns.Events:On("PLAYER_ENTERING_WORLD", totems, update)
    placeTotemBar()
end

---------------------------------------------------------------- lifecycle
function M:SpawnResources()
    if not block then spawnBlock() end
    if not totems then spawnTotems() end
end

function M:RefreshResources()
    if block then placeBlock() end
    ns.Combat:Run("uf.totembar", placeTotemBar)
end
