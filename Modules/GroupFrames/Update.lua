local _, ns = ...
local L, Media = ns.L, ns.Media
local M = ns.modules.GroupFrames
local UF = ns.modules.UnitFrames

--[[ The group parts of a button (on top of Unit Frames' own): dispel highlight, phase icon, HoT corners / buff row,
    debuff row or centre, big defensive, private aura anchors, power bar by role and the role icon hidden in combat.
    The same code draws the header buttons, the Test frames and the options preview (plain sample data).

    12.x: aura data is never read. Which auras show is decided by filter strings (C_UnitAuras.GetUnitAuras with
    HELPFUL|PLAYER|RAID_IN_COMBAT, HARMFUL|RAID_PLAYER_DISPELLABLE, HELPFUL|BIG_DEFENSIVE …); icons, stacks and
    timers go to sinks (UnitFrames.ShowAura). The dispel colour comes from the dispel colour curve
    (C_UnitAuras.GetAuraDispelTypeColor) and is only handed to SetVertexColor. Range is UnitInRange through
    SetAlphaFromBoolean (UnitFrames.UpdateRange); the phase reason and roles pass plain() first. ]]

local WHITE = Media.textures.WHITE
local CORNERS = { "TOPRIGHT", "BOTTOMRIGHT", "TOPLEFT", "BOTTOMLEFT" }
local SIDES = { "top", "bottom", "left", "right" }

local function plain(v) return M.plain(v) end
local function yes(v) return plain(v) and v and true or false end

---------------------------------------------------------------- build
local function container(b, kind)
    local c = CreateFrame("Frame", nil, b)
    c.key, c.kind = b.unitKey, kind
    c:SetAllPoints(b.Health)
    c:SetFrameLevel(b:GetFrameLevel() + 5)
    return c
end

function M:BuildGroupParts(b)
    -- dispel highlight: border lines, a flat overlay and a bottom-up gradient (one shows, by mode)
    local hl = CreateFrame("Frame", nil, b)
    hl:SetAllPoints()
    hl:SetFrameLevel(b:GetFrameLevel() + 4)
    hl.lines = {}
    for _, side in ipairs(SIDES) do
        local t = hl:CreateTexture(nil, "OVERLAY", nil, 6)
        t:SetTexture(WHITE)
        hl.lines[side] = t
    end
    hl.fill = hl:CreateTexture(nil, "OVERLAY", nil, 4)
    hl.fill:SetTexture(WHITE)
    hl.fill:SetAllPoints(b.Health)
    hl.grad = hl:CreateTexture(nil, "OVERLAY", nil, 5)
    hl.grad:SetTexture(Media.textures.FADE_V)
    hl.grad:SetAllPoints(b.Health)
    hl:Hide()
    b.DispelHL = hl
    b.Phase = b.TextLayer:CreateTexture(nil, "OVERLAY", nil, 3)
    b.Phase:Hide()
    b.HoTs = container(b, "buffs")
    b.DebuffRow = container(b, "debuffs")
    b.Defensive = container(b, "buffs")
    b.Private = CreateFrame("Frame", nil, b)
    b.Private:SetAllPoints(b.Health)
    b.Private:SetFrameLevel(b:GetFrameLevel() + 7)
    b.Private.slots = {}
    b.groupContainers = { b.HoTs, b.DebuffRow, b.Defensive }
end

---------------------------------------------------------------- layout
local function placeButtons(c, n, size, a, place)
    for i = 1, n do
        local btn = UF.AuraButton(c, i)
        btn:SetSize(size, size)
        btn:ClearAllPoints()
        place(btn, i)
        UF.StyleAuraButton(btn, a)
    end
    for i = n + 1, #(c.buttons or {}) do c.buttons[i]:Hide() end
    c.max = n
end

function M:LayoutParts(b, p)
    p = p or UF:Unit(b.unitKey)
    local ga, a = p.groupAuras, p.auras
    -- dispel highlight
    local d = p.dispel
    local hl = b.DispelHL
    local t = math.max(1, d.size or 2)
    local L_ = hl.lines
    L_.top:ClearAllPoints(); L_.top:SetPoint("TOPLEFT"); L_.top:SetPoint("TOPRIGHT"); L_.top:SetHeight(t)
    L_.bottom:ClearAllPoints(); L_.bottom:SetPoint("BOTTOMLEFT"); L_.bottom:SetPoint("BOTTOMRIGHT"); L_.bottom:SetHeight(t)
    L_.left:ClearAllPoints(); L_.left:SetPoint("TOPLEFT"); L_.left:SetPoint("BOTTOMLEFT"); L_.left:SetWidth(t)
    L_.right:ClearAllPoints(); L_.right:SetPoint("TOPRIGHT"); L_.right:SetPoint("BOTTOMRIGHT"); L_.right:SetWidth(t)
    for _, side in ipairs(SIDES) do L_[side]:SetShown(d.mode == "border") end
    hl.fill:SetShown(d.mode == "overlay")
    hl.fill:SetAlpha(d.alpha or 0.3)
    hl.grad:SetShown(d.mode == "gradient")
    hl.grad:SetAlpha(math.min(1, (d.alpha or 0.3) * 2))
    -- phase icon in the middle
    local s = p.icons.size + 4
    b.Phase:ClearAllPoints()
    b.Phase:SetPoint("CENTER", b.Health, "CENTER", 0, 0)
    ns.Icons:Apply(b.Phase, "maps", s)
    -- HoTs / buffs: the four corners or a row from the bottom right
    local bu = ga.buffs
    b.HoTs:SetShown(bu.mode ~= "off")
    if bu.mode == "corners" then
        placeButtons(b.HoTs, math.min(4, bu.max), bu.size, a, function(btn, i)
            btn:SetPoint(CORNERS[i], b.HoTs, CORNERS[i], (CORNERS[i]:find("LEFT") and 1 or -1), (CORNERS[i]:find("TOP") and -1 or 1))
        end)
    elseif bu.mode == "row" then
        placeButtons(b.HoTs, bu.max, bu.size, a, function(btn, i)
            btn:SetPoint("BOTTOMRIGHT", b.HoTs, "BOTTOMRIGHT", -1 - (i - 1) * (bu.size + 1), 1)
        end)
    else
        placeButtons(b.HoTs, 0, bu.size, a, function() end)
    end
    -- debuffs: a row from the bottom left or a centred row
    local de = ga.debuffs
    b.DebuffRow:SetShown(de.mode ~= "off")
    if de.mode == "center" then
        local total = de.max * de.size + (de.max - 1)
        placeButtons(b.DebuffRow, de.max, de.size, a, function(btn, i)
            btn:SetPoint("LEFT", b.DebuffRow, "CENTER", -total / 2 + (i - 1) * (de.size + 1), 0)
        end)
    elseif de.mode == "row" then
        placeButtons(b.DebuffRow, de.max, de.size, a, function(btn, i)
            btn:SetPoint("BOTTOMLEFT", b.DebuffRow, "BOTTOMLEFT", 1 + (i - 1) * (de.size + 1), 1)
        end)
    else
        placeButtons(b.DebuffRow, 0, de.size, a, function() end)
    end
    -- the big defensive (or an external) on the left edge
    local df = ga.defensive
    b.Defensive:SetShown(df.enabled)
    placeButtons(b.Defensive, df.enabled and 1 or 0, df.size, a, function(btn)
        btn:SetPoint("LEFT", b.Defensive, "LEFT", 2, 0)
    end)
    -- private aura slots on the right edge (the game draws into them)
    local pa = ga.private
    for i = 1, math.max(pa.max, #b.Private.slots) do
        local slot = b.Private.slots[i] or CreateFrame("Frame", nil, b.Private)
        b.Private.slots[i] = slot
        slot:SetSize(pa.size, pa.size)
        slot:ClearAllPoints()
        slot:SetPoint("RIGHT", b.Private, "RIGHT", -2 - (i - 1) * (pa.size + 1), 0)
        slot:SetShown(pa.enabled and i <= pa.max)
    end
    b.partsDone = true
end

---------------------------------------------------------------- private auras
function M:AnchorPrivate(b)
    local api = C_UnitAuras
    for _, slot in ipairs(b.Private and b.Private.slots or {}) do
        if slot.anchorID and api and api.RemovePrivateAuraAnchor then pcall(api.RemovePrivateAuraAnchor, slot.anchorID) end
        slot.anchorID = nil
    end
    if b.sample or not b.unit or not (api and api.AddPrivateAuraAnchor) then return end
    local pa = UF:Unit(b.unitKey).groupAuras.private
    if not pa.enabled then return end
    if not b.partsDone then self:LayoutParts(b) end
    for i = 1, pa.max do
        local slot = b.Private.slots[i]
        if slot then
            local ok, id = pcall(api.AddPrivateAuraAnchor, {
                unitToken = b.unit, auraIndex = i, parent = slot,
                showCountdownFrame = pa.countdown, showCountdownNumbers = pa.numbers,
                iconInfo = { iconWidth = pa.size, iconHeight = pa.size,
                    iconAnchor = { point = "CENTER", relativeTo = slot, relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
            })
            if ok then slot.anchorID = id end
        end
    end
end

---------------------------------------------------------------- drawing

-- r, g, b, a may be secret (from the dispel colour curve): they only reach SetVertexColor
local function paint(b, r, g, bl, a)
    local hl = b.DispelHL
    for _, side in ipairs(SIDES) do hl.lines[side]:SetVertexColor(r, g, bl, a) end
    hl.fill:SetVertexColor(r, g, bl, a)
    hl.grad:SetVertexColor(r, g, bl, a)
    hl:Show()
end

local function dispel(b, p)
    local hl = b.DispelHL
    if p.dispel.mode == "off" then hl:Hide(); return end
    if b.sample then
        local r, g, bl = ns.Util.DispelColor(b.sample.dispel)
        if r then paint(b, r, g, bl, 1) else hl:Hide() end
        return
    end
    local api = C_UnitAuras
    if not (api and api.GetUnitAuras and api.GetAuraDispelTypeColor) then hl:Hide(); return end
    local ok, list = pcall(api.GetUnitAuras, b.unit, M.DispelFilter(p.dispel.mine), 1)
    local aura = ok and type(list) == "table" and list[1] or nil
    local curve = aura and UF.DispelCurve()
    if not curve then hl:Hide(); return end
    local okc, color = pcall(api.GetAuraDispelTypeColor, b.unit, aura.auraInstanceID, curve)
    if okc and color and color.GetRGBA then paint(b, color:GetRGBA()) else hl:Hide() end
end

local function fill(c, b, filter, kind, a, samples)
    local shown = 0
    local n = c.max or 0
    if n > 0 and c:IsShown() then
        if b.sample then
            for i, s in ipairs(samples or {}) do
                if i > n then break end
                UF.ShowSampleAura(UF.AuraButton(c, i), s, kind, a, i)
                shown = i
            end
        elseif C_UnitAuras and C_UnitAuras.GetUnitAuras then
            local ok, list = pcall(C_UnitAuras.GetUnitAuras, b.unit, filter, n)
            if ok and type(list) == "table" then
                for i = 1, math.min(#list, n) do
                    if list[i] then
                        ns.SafeCall(UF.ShowAura, UF.AuraButton(c, i), b.unit, list[i], kind, a)
                        shown = i
                    end
                end
            end
        end
    end
    for i = shown + 1, #(c.buttons or {}) do c.buttons[i]:Hide() end
    return shown
end

local function auras(b, p)
    local ga, a = p.groupAuras, p.auras
    local s = b.sample or {}
    fill(b.HoTs, b, M.BUFF_FILTERS[ga.buffs.filter] or M.BUFF_FILTERS.mine, "buffs", a, s.buffs)
    fill(b.DebuffRow, b, M.DEBUFF_FILTERS[ga.debuffs.filter] or M.DEBUFF_FILTERS.all, "debuffs", a, s.debuffs)
    if ga.defensive.enabled then
        local n = fill(b.Defensive, b, "HELPFUL|BIG_DEFENSIVE", "buffs", a, s.defensive and { s.defensive } or nil)
        if n == 0 and not b.sample then fill(b.Defensive, b, M.BUFF_FILTERS.external, "buffs", a) end
    end
end

local function phase(b, p)
    local show = false
    if p.icons.phase then
        if b.sample then
            show = b.sample.phase and true or false
        else
            local reason = UnitPhaseReason(b.unit)
            show = (plain(reason) and reason ~= nil) or yes(UnitInOtherParty(b.unit))
        end
    end
    b.Phase:SetShown(show)
end

local function roleIcon(b, p)
    if p.roleCombat and not b.sample and InCombatLockdown() then b.Role:Hide() end
end

-- Everything on one button (live or sample).
function M:UpdateButton(b)
    if not (b.unit or b.sample) or not b.unitKey then return end
    local p = UF:Unit(b.unitKey)
    local src = UF:SourceOf(b)
    if b.unit and not b.sample and not yes(UnitExists(b.unit)) then return end
    -- power bar by role: a change re-lays the button out (its power bar is not protected)
    local noPower = not M.PowerFor(p, src:Role(b))
    if noPower ~= (b.noPower or false) then b.noPower = noPower; b.layoutDone = nil end
    if not b.layoutDone then b.partsDone = nil end
    UF:UpdateAll(b)
    if not b.layoutDone then return end
    if not b.partsDone then self:LayoutParts(b, p) end
    ns.SafeCall(dispel, b, p)
    ns.SafeCall(auras, b, p)
    ns.SafeCall(phase, b, p)
    roleIcon(b, p)
end

-- f.onUnitEvent from UnitFrames.WatchUnit: group parts for the event group that fired
function M.OnUnitEvent(b, group, ev)
    if not b.unitKey then return end
    local p = UF:Unit(b.unitKey)
    if not b.partsDone then return end
    if group == "auras" then
        dispel(b, p); auras(b, p)
    elseif ev == "UNIT_PHASE" or ev == "UNIT_OTHER_PARTY_CHANGED" then
        phase(b, p)
    elseif ev == "UNIT_IN_RANGE_UPDATE" then
        UF:UpdateRange(b, UF:SourceOf(b))
    elseif group == "texts" then
        local noPower = not M.PowerFor(p, UF:SourceOf(b):Role(b))
        if noPower ~= (b.noPower or false) then M:UpdateButton(b) end
        roleIcon(b, p)
    end
end

---------------------------------------------------------------- samples
local I = "Interface\\Icons\\"
local ICON = { renew = I .. "Spell_Holy_Renew", rejuv = I .. "Spell_Nature_Rejuvenation", shield = I .. "Spell_Holy_PowerWordShield",
    wall = I .. "Ability_Warrior_ShieldWall", pain = I .. "Spell_Shadow_ShadowWordPain", curse = I .. "Spell_Shadow_CurseOfTounges",
    poison = I .. "Ability_Rogue_DualWeild", disease = I .. "Spell_Shadow_AbominationExplosion" }
M.SAMPLE_ICONS = ICON
local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "HUNTER", "ROGUE", "PALADIN", "DRUID", "SHAMAN", "WARLOCK", "DEATHKNIGHT",
    "MONK", "DEMONHUNTER", "EVOKER" }
local POWER = { WARRIOR = "RAGE", ROGUE = "ENERGY", DEATHKNIGHT = "RUNIC_POWER", DEMONHUNTER = "FURY", MONK = "ENERGY",
    HUNTER = "FOCUS" }
local PARTY_NAMES = { "PREVIEW_PARTY_TANK", "PREVIEW_PARTY_HEALER", "PREVIEW_UNIT_PLAYER", "PREVIEW_PARTY_DPS1",
    "PREVIEW_PARTY_DPS2" }
local DEBUFFS = { { icon = ICON.pain, dispel = "Magic", duration = 18, elapsed = 4 },
    { icon = ICON.curse, dispel = "Curse", duration = 30, elapsed = 10 },
    { icon = ICON.poison, dispel = "Poison", count = 3 }, { icon = ICON.disease, dispel = "Disease" } }

local HEALER_CLASSES = { "PRIEST", "DRUID", "SHAMAN", "MONK", "EVOKER", "PALADIN", "PRIEST", "DRUID" }
local HP = { 0.95, 0.82, 0.64, 0.38, 1, 0.71, 0.22, 0.88, 0.55 }
local READY = { [9] = "summon", [14] = "notready", [17] = "res" }

local function member(i, n, role, class)
    local hpMax = role == "TANK" and 720000 or 480000
    return {
        name = n <= 5 and L[PARTY_NAMES[i]] or L.GF_SAMPLE_NAME:format(i),
        class = class, role = role, hp = math.floor(hpMax * HP[((i - 1) % #HP) + 1]), hpMax = hpMax, power = 60,
        powerMax = 100, powerToken = POWER[class] or "MANA", group = tostring(math.floor((i - 1) / 5) + 1),
        leader = i == 1, heal = (i % 4 == 0) and 50000 or 0, absorb = role == "TANK" and 90000 or 0,
    }
end

-- the states spread over the fake group: HoTs, a dispellable debuff, aggro, dead, offline, out of range …
local function states(s, i, n)
    if i % 6 == 2 then
        s.buffs = { { icon = ICON.renew, duration = 12, elapsed = 3 }, { icon = ICON.rejuv, duration = 15, elapsed = 6 } }
    end
    if i % 4 == 0 then
        local d = DEBUFFS[((i / 4 - 1) % #DEBUFFS) + 1]
        s.debuffs, s.dispel = { d }, d.dispel
    end
    if i == 1 then s.threat = 3; s.marker = 8; s.defensive = { icon = ICON.wall, duration = 8, elapsed = 2 } end
    if i % 11 == 5 then s.dead = true; s.hp = 0 end
    s.offline = i % 13 == 7 or nil
    s.far = (i % 7 == 3 and n > 5) or nil
    s.ready = READY[i]
    s.phase = i == 19 or nil
    if i == 2 then s.healAbsorb = 60000 end
end

-- A fake group of n (5, 20 or 40): plain data for UnitFrames' sample source plus the group parts.
function M.SampleGroup(n)
    local out = {}
    local tanks = n <= 5 and 1 or 2
    local healers = n <= 5 and 1 or math.max(2, math.floor(n / 5))
    for i = 1, n do
        local class, role = CLASSES[((i - 1) % #CLASSES) + 1], "DAMAGER"
        if i <= tanks then
            role, class = "TANK", i == 1 and "WARRIOR" or "PALADIN"
        elseif i <= tanks + healers then
            role, class = "HEALER", HEALER_CLASSES[i - tanks] or "PRIEST"
        end
        local s = member(i, n, role, class)
        states(s, i, n)
        out[i] = s
    end
    return out
end

--[[ Draws a fake group of n with profile `key` into parent (Test frames, the options preview): plain frames from
    UnitFrames:Build, laid out like the headers lay theirs. pool: the caller's frame cache. -> width, height ]]
function M:DrawSampleGroup(parent, key, n, pool)
    local p = self:Profile(key)
    local per = (key == "party" or M.SplitGroups(p)) and 5 or p.perColumn
    local slots = M.Slots(p, n, per)
    local c = M.Corner(p.growth, p.groupGrowth)
    local samples = M.SampleGroup(n)
    for i = 1, n do
        local f = pool[i]
        if not f then
            f = UF:Build(parent, "group." .. key, { sample = samples[i] })
            f:EnableMouse(false)
            self:BuildGroupParts(f)
            pool[i] = f
        end
        if f.unitKey ~= "group." .. key then
            f.unitKey = "group." .. key
            f.Buffs.key, f.Debuffs.key = f.unitKey, f.unitKey
            for _, cont in ipairs(f.groupContainers) do cont.key = f.unitKey end
        end
        f.sample = samples[i]
        f.noPower = not M.PowerFor(p, samples[i].role)
        f.layoutDone, f.partsDone = nil, nil
        f:ClearAllPoints()
        f:SetPoint(c, parent, c, slots[i][1], slots[i][2])
        f:Show()
        self:UpdateButton(f)
    end
    for i = n + 1, #pool do pool[i]:Hide() end
    return M.GroupSize(p, n, per)
end

---------------------------------------------------------------- Test frames
local testRoot, testPool
function M:ShowPhoenixTest(show)
    if not self:IsSpawned() then return show and false or true end
    if show then
        if InCombatLockdown() then return false end
        local n = self.db.testSize
        n = (n == 5 or n == 40) and n or 20
        local key = n == 5 and "party" or (n == 40 and "large" or "raid")
        testRoot = testRoot or CreateFrame("Frame", nil, UIParent)
        testPool = testPool or {}
        for _, h in pairs(M.headers) do h:Hide() end
        local p = self:Profile(key)
        local scale = (p.scale or 1) > 0 and p.scale or 1
        testRoot:SetScale(scale)
        testRoot:SetFrameStrata(p.strata or "LOW")
        testRoot:ClearAllPoints()
        testRoot:SetPoint(p.point, UIParent, p.point, p.x / scale, p.y / scale)
        local w, h = self:DrawSampleGroup(testRoot, key, n, testPool)
        testRoot:SetSize(w, h)
        testRoot:Show()
        return true
    end
    if testRoot then testRoot:Hide() end
    self:Layout() -- the real headers come back (out of combat)
    return true
end
M.TEST_SIZES = { 5, 20, 40 }
