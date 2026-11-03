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
                   combat. With it on, the game's TotemFrame stays out of sight.
    Review 31      A spark on each fill, a darker-to-full gradient, damage / heal absorbs on the health row (the
                   frames' own sinks: UnitGetTotalAbsorbs into a StatusBar anchored on the fill), a power threshold
                   colour (a step alpha curve read by UnitPowerPercent, so a secret power still lights it) and
                   visibility rules (combat, a hostile target, group, instance, not mounted) faded to a chosen alpha. ]]

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
-- row orders (t169): the class resource or the power bar on top, for a block that sits under the character
M.RESOURCE_ORDERS = {
    default = M.RESOURCE_ROWS,
    classTop = { "class", "spec", "health", "power", "mana" },
    powerTop = { "power", "mana", "class", "spec", "health" },
    noHealthTop = { "class", "power", "mana", "spec", "health" },
}
function M.ResourceRows(r, active)
    local out, y = {}, 0
    for _, key in ipairs(M.RESOURCE_ORDERS[r.order or "default"] or M.RESOURCE_ROWS) do
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
local function bar(parent, absorbs)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetStatusBarTexture(Media.textures.WHITE)
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(Media.textures.WHITE)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetWordWrap(false)
    if absorbs then
        b:SetClipsChildren(true)
        b.absorb = CreateFrame("StatusBar", nil, b)
        b.absorb:SetPoint("TOPLEFT", b:GetStatusBarTexture(), "TOPRIGHT")
        b.absorb:SetPoint("BOTTOMLEFT", b:GetStatusBarTexture(), "BOTTOMRIGHT")
        b.absorb:SetMinMaxValues(0, 1)
        b.absorb:SetValue(0)
        b.healAbsorb = CreateFrame("StatusBar", nil, b)
        b.healAbsorb:SetReverseFill(true)
        b.healAbsorb:SetPoint("TOPRIGHT", b:GetStatusBarTexture(), "TOPRIGHT")
        b.healAbsorb:SetPoint("BOTTOMRIGHT", b:GetStatusBarTexture(), "BOTTOMRIGHT")
        b.healAbsorb:SetMinMaxValues(0, 1)
        b.healAbsorb:SetValue(0)
    else
        -- the power threshold overlay: the fill's own shape in the threshold colour, its alpha from a step curve
        b.over = b:CreateTexture(nil, "ARTWORK", nil, 2)
        b.over:SetAllPoints(b:GetStatusBarTexture())
        b.over:SetAlpha(0)
    end
    b:Hide()
    return b
end

-- Visibility rules (pure, smoke-tested): state = { combat, target, group, instance, mounted }.
M.RESOURCE_VIS = { "always", "combat", "target", "combatTarget", "group", "instance" }
function M.ResourceVisible(r, st)
    if r.hideMounted and st.mounted and not st.combat then return false end
    local v = r.visibility or "always"
    if v == "combat" then return st.combat and true or false end
    if v == "target" then return st.target and true or false end
    if v == "combatTarget" then return (st.combat or st.target) and true or false end
    if v == "group" then return st.group and true or false end
    if v == "instance" then return st.instance and true or false end
    return true
end

local INSTANCE_KINDS = { party = true, raid = true, scenario = true, arena = true, pvp = true }
local function visState()
    local hostile = UnitExists("target") and UnitCanAttack("player", "target")
    local _, kind = IsInInstance()
    return { combat = InCombatLockdown() or UnitAffectingCombat("player"), target = plain(hostile) and hostile,
             group = IsInGroup(), instance = INSTANCE_KINDS[kind] or false,
             mounted = IsMounted() or (UnitInVehicle and UnitInVehicle("player")) }
end
M.ResourceVisState = visState

-- 0 below the threshold, 1 from it up (a fraction of max power); one curve per threshold.
local thresholdCurve, thresholdAt
local function thresholdAlphaCurve(pct)
    if thresholdAt == pct then return thresholdCurve or nil end
    thresholdAt, thresholdCurve = pct, false
    if C_CurveUtil and C_CurveUtil.CreateCurve and Enum.LuaCurveType then
        local ok, c = pcall(function()
            local curve = C_CurveUtil.CreateCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            curve:AddPoint(0, 0)
            curve:AddPoint(math.min(1, math.max(0.001, pct / 100)), 1)
            return curve
        end)
        if ok and c then thresholdCurve = c end
    end
    return thresholdCurve or nil
end

-- The fill colour, flat or a darker-to-full gradient along the bar.
local function paint(b, r, g, bl, gradient)
    local tex = b:GetStatusBarTexture()
    if gradient and tex and tex.SetGradient and CreateColor then
        b:SetStatusBarColor(1, 1, 1)
        tex:SetGradient("HORIZONTAL", CreateColor(r * 0.55, g * 0.55, bl * 0.55, 1), CreateColor(r, g, bl, 1))
    else
        b:SetStatusBarColor(r, g, bl)
    end
end
M.PaintResourceBar = paint

-- The block's widgets: built once, the preview builds its own with the same function.
function M:BuildResources(parent, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", opts.name, parent)
    f:SetSize(220, 40)
    -- (Live and Sample sources read f.unit / f.unitKey / f.sample: this frame is "the player")
    f.unit, f.unitKey, f.sample, f.detached, f.noLayout = "player", "player", opts.sample, true, true
    f.rows = { health = bar(f, true), power = bar(f), mana = bar(f), spec = bar(f) }
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
                manaShift = c.manaShift, absorb = 90000, healAbsorb = 30000 }
    if c.spec then
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(c.spec)
        s.specBar = { value = 0.6, label = type(name) == "string" and name or "" }
    end
    return s
end

-- Power ticks (t169): "50, 80" -> { 50, 80 } (plain numbers the user typed; up to 5, positive only)
function M.ParseTicks(text)
    local out = {}
    for n in tostring(text or ""):gmatch("[%d%.]+") do
        local v = tonumber(n)
        if v and v > 0 and #out < 5 then out[#out + 1] = v end
    end
    return out
end

-- where each tick sits across a bar of width w for a power max (nil when the max is not a plain number)
function M.TickOffsets(ticks, max, w)
    if not (plain(max) and type(max) == "number" and max > 0) then return nil end
    local out = {}
    for _, v in ipairs(ticks) do
        if v < max then out[#out + 1] = math.floor(w * v / max + 0.5) end
    end
    return out
end

local function drawTicks(f, b, r, max)
    b.ticks = b.ticks or {}
    local offs = M.TickOffsets(M.ParseTicks(r.power.ticks), max, r.width)
    if not offs then return end -- a secret max: the ticks stay where they were
    local c = r.power.tickColor
    for i, x in ipairs(offs) do
        local t = b.ticks[i] or b:CreateTexture(nil, "OVERLAY", nil, 2)
        b.ticks[i] = t
        -- the v8.1 tick piece (2 px, tinted) on the phoenix-wings look; else a 1 px line
        local art = ns.Art and ns.Art.PaintSlot and ns.Art:PaintSlot(t, "Resources.tick")
        if not art then t:SetTexture(Media.textures.WHITE); t:SetTexCoord(0, 1, 0, 1) end
        t:SetVertexColor(c.r, c.g, c.b, c.a or 0.8)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", b, "TOPLEFT", x - (art and 1 or 0), 0)
        t:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", x - (art and 1 or 0), 0)
        t:SetWidth(art and 2 or 1)
        t:Show()
    end
    for i = #offs + 1, #b.ticks do b.ticks[i]:Hide() end
    f.tickSig = r.power.ticks
end
M.DrawResourceTicks = drawTicks

local SMOOTH = Enum_.StatusBarInterpolation and Enum_.StatusBarInterpolation.ExponentialEaseOut
local function setValue(b, v, smooth)
    if smooth and SMOOTH then b:SetValue(v, SMOOTH) else b:SetValue(v) end
end

-- health row colour: class / fixed / theme accent
local function healthColor(r, classFile)
    local mode = r.health.color
    if mode == "fixed" then local c = r.health.fixed; return c.r, c.g, c.b end
    if mode == "theme" then return Theme:Color("accent.primary") end
    return ns.Util.ClassColor(classFile)
end
-- power row colour: power type / class / fixed
local function powerColor(r, token, kind, classFile)
    local mode = r.power.color
    if mode == "fixed" then local c = r.power.fixed; return c.r, c.g, c.b end
    if mode == "class" then return ns.Util.ClassColor(classFile) end
    return M.PowerColor(token, kind)
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
            Skin:FillSpark(b, r.spark and row.key ~= "spec")
            if b.over then
                b.over:SetTexture(tex)
                local c = r.power.thresholdColor
                b.over:SetVertexColor(c.r, c.g, c.b, 1)
                if row.key ~= "power" or (r.power.threshold or 0) <= 0 then b.over:SetAlpha(0) end
            end
            if b.absorb then
                b.absorb:SetSize(r.width, row.h)
                b.absorb:SetStatusBarTexture(Media:Bar("FineStripes"))
                b.absorb:SetStatusBarColor(self:Color("absorb"))
                b.absorb:SetAlpha(0.75)
                b.absorb:SetShown(r.health.absorb)
                b.healAbsorb:SetSize(r.width, row.h)
                b.healAbsorb:SetStatusBarTexture(Media:Bar("Stripes"))
                b.healAbsorb:SetStatusBarColor(self:Color("healAbsorb"))
                b.healAbsorb:SetAlpha(0.7)
                b.healAbsorb:SetShown(r.health.healAbsorb)
            end
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

local function drawHealth(f, h, r, src)
    local hmax = src:HealthMax(f)
    h:SetMinMaxValues(0, hmax)
    setValue(h, src:Health(f), r.smooth and not f.sample)
    local cr, cg, cb = healthColor(r, src:ClassFile(f) or select(2, UnitClass("player")))
    paint(h, cr, cg, cb, r.gradient)
    if r.health.absorb then h.absorb:SetMinMaxValues(0, hmax); h.absorb:SetValue(src:Absorbs(f)) end
    if r.health.healAbsorb then h.healAbsorb:SetMinMaxValues(0, hmax); h.healAbsorb:SetValue(src:HealAbsorbs(f)) end
    h.bg:SetVertexColor(cr * 0.2, cg * 0.2, cb * 0.2, 0.9)
    M.ApplyTags(h.text, f.compiledHealth, f, src)
end

-- the threshold overlay's alpha: the step curve on live power, a plain compare on sample frames
local function drawThreshold(f, p, r, src, kind, max)
    local th = r.power.threshold or 0
    if th <= 0 then return end
    if f.sample then
        local v = src:Power(f)
        local hit = type(v) == "number" and type(max) == "number" and max > 0 and v / max * 100 >= th
        p.over:SetAlpha(hit and 1 or 0)
        return
    end
    local curve = thresholdAlphaCurve(th)
    local ok, a = false, 0
    if curve then ok, a = pcall(UnitPowerPercent, "player", kind, false, curve) end
    p.over:SetAlpha(ok and a or 0)
end

local function drawPower(f, p, r, src)
    local kind, token = src:PowerType(f)
    local max = src:PowerMax(f)
    p:SetMinMaxValues(0, max)
    setValue(p, src:Power(f), r.smooth and not f.sample)
    local pr, pg, pb = powerColor(r, token, kind, src:ClassFile(f) or select(2, UnitClass("player")))
    drawTicks(f, p, r, max)
    paint(p, pr, pg, pb, r.gradient)
    drawThreshold(f, p, r, src, kind, max)
    p.bg:SetVertexColor(pr * 0.2, pg * 0.2, pb * 0.2, 0.9)
    M.ApplyTags(p.text, f.compiledPower, f, src)
end

local function drawMana(f, m, r)
    local manaKind = PT.Mana or 0
    if f.sample then m:SetMinMaxValues(0, 1); m:SetValue(0.7) else
        m:SetMinMaxValues(0, UnitPowerMax("player", manaKind))
        m:SetValue(UnitPower("player", manaKind))
    end
    local mr, mg, mb = M.PowerColor("MANA", manaKind)
    paint(m, mr, mg, mb, r.gradient)
    m.bg:SetVertexColor(mr * 0.2, mg * 0.2, mb * 0.2, 0.9)
    m.text:SetText("")
end

function M:UpdateResources(f)
    if not f then return end
    local r = self.db.resources
    local src = self:SourceOf(f)
    -- rows appear and collapse as resources come and go (a plain frame: any time)
    local active = self:ResourceActive(f)
    local sig = (active.class and "c" or "") .. (active.spec and "s" or "") .. (active.mana and "m" or "")
    if sig ~= f.activeSig then f.activeSig = sig; self:LayoutResources(f) end
    if f.rows.health:IsShown() then drawHealth(f, f.rows.health, r, src) end
    if f.rows.power:IsShown() then drawPower(f, f.rows.power, r, src) end
    if f.rows.mana:IsShown() then drawMana(f, f.rows.mana, r) end
    if f.ClassPower:IsShown() then self:UpdateClassPower(f) end
    if f.rows.spec:IsShown() then drawSpec(f, f.rows.spec) end
    if not f.sample then
        local ooc = not InCombatLockdown()
        local a = (r.combatOnly and ooc) and r.oocAlpha or 1
        if not M.ResourceVisible(r, visState()) then a = math.min(a, r.hiddenAlpha or 0) end
        f:SetAlpha(a)
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
    if M.SyncRuneFollower then M.SyncRuneFollower() end
end

local OWNER_RUNES = {}
local function spawnBlock()
    block = M:BuildResources(UIParent, { name = "PhoenixUI_Resources" })
    M.resourceBlock = block
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("uf.resources", block, L.UF_RESOURCES, resourceStore()) end
    local function update() if block:IsShown() then ns.SafeCall(M.UpdateResources, M, block) end end
    local E = ns.Events
    for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
        "UNIT_AURA", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" }) do
        E:OnUnit(ev, block, update, "player")
    end
    for _, ev in ipairs({ "RUNE_POWER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM",
        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
        "PLAYER_MOUNT_DISPLAY_CHANGED", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA" }) do
        E:On(ev, block, update)
    end
    -- runes recharge without events: a 0.1 s follower, only while the class has runes (death knights)
    block.elapsed = 0
    local function runeTick(self, e)
        self.elapsed = self.elapsed + e
        if self.elapsed < 0.1 then return end
        self.elapsed = 0
        if self.hasRunes then ns.SafeCall(M.UpdateClassPower, M, self) else self:SetScript("OnUpdate", nil) end
    end
    local function syncRunes() block:SetScript("OnUpdate", block.hasRunes and runeTick or nil) end
    for _, ev in ipairs({ "RUNE_POWER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ENTERING_WORLD" }) do
        E:On(ev, OWNER_RUNES, function() syncRunes() end)
    end
    M.SyncRuneFollower = syncRunes
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
    M:SpawnImbues() -- Imbues.lua: weapon enchant icons
end

function M:RefreshResources()
    if block then placeBlock() end
    ns.Combat:Run("uf.totembar", placeTotemBar)
    M:UpdateImbues()
end
