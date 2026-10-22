local _, ns = ...
local L, Theme, Skin = ns.L, ns.Theme, ns.Skin
local M = ns.modules.UnitFrames

--[[ Element updates. Each one reads its facts from a source: Live (the game, through secret-safe calls) or Sample
    (plain numbers for the preview and Test frames). The same update code draws both, so the preview cannot drift
    from the real frame.

    Secret rules kept here: a value that may be secret is handed to a sink untouched (SetValue, SetMinMaxValues,
    SetFormattedText, SetTexture, SetSpriteSheetCell, SetAlphaFromBoolean, SetDesaturated, curve evaluation).
    Anything we branch on (is it a player, dead, which class, which power type) goes through plain() and has a
    neutral fallback when it is secret. ]]

local plain = M.plain
local ScaleTo100 = CurveConstants and CurveConstants.ScaleTo100
local INTERP = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local PT = Enum.PowerType or {}

local function yes(v) return plain(v) and v and true or false end

-- UTF-8 aware cut of a plain string to n characters.
function M.Truncate(s, n)
    if type(s) ~= "string" or not plain(s) or not n or n <= 0 then return s end
    local count, last = 0, #s
    for pos in s:gmatch("()[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > n then last = pos - 1; break end
    end
    return s:sub(1, last)
end

local CLASSIFICATION = { worldboss = "B", rareelite = "R+", elite = "+", rare = "R", trivial = "-", minus = "-" }

---------------------------------------------------------------- live source
local Live = {}
M.Live = Live

function Live:Exists(f) return yes(UnitExists(f.unit)) end
-- A plain name's nickname (General list "Name=Nick"), else the name itself.
function M.Nickname(name)
    if not plain(name) or type(name) ~= "string" then return name end
    local nicks = M.db and M.db.nicknames
    if type(nicks) ~= "string" or nicks == "" then return name end
    return M.ParseNicknames(nicks)[name] or name
end
function Live:Name(f, n)
    local name = UnitName(f.unit)
    if name == nil then return "" end
    return M.Truncate(M.Nickname(name), n or M:Unit(f.unitKey).nameLength)
end
function Live:Level(f)
    local lvl = UnitEffectiveLevel(f.unit)
    if plain(lvl) and type(lvl) == "number" and lvl <= 0 then return "??" end
    return lvl or ""
end
-- The level in the game's difficulty colour (plain levels only; a secret one is drawn as is).
function M.ColorLevel(lvl)
    if not plain(lvl) or type(lvl) ~= "number" then return lvl or "" end
    if lvl <= 0 then return "|cffff2020??|r" end
    local c = GetCreatureDifficultyColor and GetCreatureDifficultyColor(lvl)
    if not c then return tostring(lvl) end
    return ("|cff%02x%02x%02x%d|r"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), lvl)
end
function Live:LevelColored(f) return M.ColorLevel(UnitEffectiveLevel(f.unit)) end
-- The player's threat on the unit as a percentage (0-100; may be secret: it only reaches the format string).
function Live:ThreatPercent(f)
    if f.unit == "player" then return 0 end
    local _, _, pct = UnitDetailedThreatSituation("player", f.unit)
    if pct == nil then return 0 end
    return pct
end
-- An arena enemy's specialization (its name), from the arena opponent spec; "" elsewhere.
function M.ArenaSpecID(unit)
    local index = type(unit) == "string" and tonumber(unit:match("^arena(%d)$"))
    local specID = index and GetArenaOpponentSpec and GetArenaOpponentSpec(index)
    if plain(specID) and type(specID) == "number" and specID > 0 then return specID end
    return nil
end
function Live:SpecName(f)
    local specID = M.ArenaSpecID(f.unit)
    if not specID then return "" end
    local _, name = GetSpecializationInfoByID(specID)
    return name or ""
end
function Live:TargetName(f)
    local name = UnitName(f.unit .. "target")
    if name == nil then return "" end
    return M.Truncate(M.Nickname(name), M:Unit(f.unitKey).nameLength)
end
function Live:Classification(f)
    local c = UnitClassification(f.unit)
    return plain(c) and CLASSIFICATION[c] or ""
end
function Live:ClassName(f)
    if not yes(UnitIsPlayer(f.unit)) then return "" end
    local name = UnitClass(f.unit)
    return name or ""
end
function Live:IsPlayer(f) return yes(UnitIsPlayer(f.unit)) end
function Live:ClassFile(f)
    if not self:IsPlayer(f) then return nil end
    local _, file = UnitClass(f.unit)
    return plain(file) and file or nil
end
function Live:Reaction(f) return UnitReaction(f.unit, "player") end
function Live:Tapped(f) return yes(UnitIsTapDenied(f.unit)) end
function Live:Dead(f) return yes(UnitIsDeadOrGhost(f.unit)) end
function Live:Ghost(f) return yes(UnitIsGhost(f.unit)) end
function Live:Offline(f) return yes(UnitIsPlayer(f.unit)) and not yes(UnitIsConnected(f.unit)) end
function Live:Status(f)
    if self:Offline(f) then return L.UF_OFFLINE end
    if self:Ghost(f) then return L.UF_GHOST end
    if self:Dead(f) then return L.UF_DEAD end
    return ""
end
function Live:Group(f)
    local idx = UnitInRaid(f.unit)
    if not (plain(idx) and idx) then return "" end
    local _, _, sub = GetRaidRosterInfo(idx)
    return plain(sub) and sub or ""
end
function Live:Away(f)
    if yes(UnitIsAFK(f.unit)) then return L.UF_AFK end
    if yes(UnitIsDND(f.unit)) then return L.UF_DND end
    return ""
end
function Live:Guild(f)
    local guild = GetGuildInfo(f.unit)
    if guild == nil then return "" end
    return guild
end
--[[ An NPC's title: the second line of the game's unit tooltip data when it is not the level line ("Level 80 …").
    Players and secret lines give "". Read through C_TooltipInfo (no tooltip is shown). ]]
function M.TitleFromLines(lines, levelWord)
    local line = type(lines) == "table" and lines[2]
    local text = line and line.leftText
    if not plain(text) or type(text) ~= "string" or text == "" then return "" end
    if type(levelWord) == "string" and levelWord ~= "" and text:find(levelWord, 1, true) then return "" end
    return text
end
function Live:Title(f)
    if yes(UnitIsPlayer(f.unit)) or not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return "" end
    local ok, data = pcall(C_TooltipInfo.GetUnit, f.unit)
    if not ok or not plain(data) or type(data) ~= "table" then return "" end
    return M.TitleFromLines(data.lines, LEVEL)
end
function Live:GuildOrTitle(f)
    if yes(UnitIsPlayer(f.unit)) then return self:Guild(f) end
    return self:Title(f)
end
function Live:Health(f) return UnitHealth(f.unit) end
function Live:HealthMax(f) return UnitHealthMax(f.unit) end
function Live:HealthText(f, kind)
    local u = f.unit
    if kind == "max" then return M:Number(UnitHealthMax(u)) end
    if kind == "deficit" then return M:Number(UnitHealthMissing(u, true)) end
    return M:Number(UnitHealth(u))
end
function Live:HealthPercent(f) return ScaleTo100 and UnitHealthPercent(f.unit, true, ScaleTo100) or 0 end
function Live:AbsorbText(f) return M:Number(UnitGetTotalAbsorbs(f.unit)) end
function Live:Absorbs(f) return UnitGetTotalAbsorbs(f.unit) end
function Live:HealAbsorbs(f) return UnitGetTotalHealAbsorbs(f.unit) end
function Live:IncomingHeals(f, mine)
    local v = UnitGetIncomingHeals(f.unit, mine and "player" or nil)
    if plain(v) and v == nil then return 0 end
    return v
end
-- The cost, in the unit's current power, of the spell the player is casting now; nil when there is none or a value
-- is secret. Channels are left out: their cost is already paid when the channel starts.
function Live:SpellCost(f, kind)
    if f.unit ~= "player" or not (C_Spell and C_Spell.GetSpellPowerCost) then return nil end
    local spellID = select(9, UnitCastingInfo("player"))
    if not plain(spellID) or type(spellID) ~= "number" then return nil end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or not plain(costs) or type(costs) ~= "table" then return nil end
    for _, c in ipairs(costs) do
        if plain(c.type) and c.type == kind and plain(c.cost) and type(c.cost) == "number" and c.cost > 0 then return c.cost end
    end
    return nil
end
function Live:PowerType(f)
    local kind, token = UnitPowerType(f.unit)
    return plain(kind) and kind or 0, plain(token) and token or nil
end
function Live:Power(f, kind) return UnitPower(f.unit, kind) end
function Live:PowerMax(f, kind) return UnitPowerMax(f.unit, kind) end
function Live:PowerText(f, kind)
    if kind == "max" then return M:Number(UnitPowerMax(f.unit)) end
    return M:Number(UnitPower(f.unit))
end
function Live:PowerPercent(f) return ScaleTo100 and UnitPowerPercent(f.unit, nil, false, ScaleTo100) or 0 end
function Live:AltPowerID(f)
    local id = UnitPowerBarID(f.unit)
    return plain(id) and id or 0
end
function Live:AltPowerText(f)
    if self:AltPowerID(f) == 0 then return "" end
    return M:Number(UnitPower(f.unit, PT.Alternate or 10))
end
function Live:HealthColorFromCurve(f)
    local curve = M:HealthCurve()
    if not curve then return nil end
    local ok, color = pcall(UnitHealthPercent, f.unit, true, curve)
    if ok and type(color) == "table" and color.GetRGB then return color end
    return nil
end
function Live:HealthFraction() return nil end
function Live:Leader(f) return yes(UnitIsGroupLeader(f.unit)) end
function Live:RaidMarker(f) return GetRaidTargetIndex(f.unit) end
function Live:Role(f)
    -- arena enemies have no group role: their spec's role
    local specID = M.ArenaSpecID(f.unit)
    if specID and GetSpecializationRoleByID then
        local role = GetSpecializationRoleByID(specID)
        return plain(role) and role ~= "NONE" and role or nil
    end
    local r = UnitGroupRolesAssigned(f.unit)
    return plain(r) and r ~= "NONE" and r or nil
end
function Live:InCombat(f) return yes(UnitAffectingCombat(f.unit)) end
function Live:Resting(f) return f.unit == "player" and yes(IsResting()) end
function Live:PvP(f)
    local u = f.unit
    if yes(UnitIsPVPFreeForAll(u)) then return "ffa" end
    if yes(UnitIsPVP(u)) then return "pvp" end
    return nil
end
function Live:RawClassification(f)
    local c = UnitClassification(f.unit)
    return plain(c) and c or "normal"
end
function Live:Threat(f)
    local s = UnitThreatSituation(f.unit)
    return plain(s) and s or nil
end
function Live:ReadyCheck(f)
    local status = GetReadyCheckStatus(f.unit)
    if plain(status) and status then return status end
    if C_IncomingSummon and C_IncomingSummon.HasIncomingSummon and yes(C_IncomingSummon.HasIncomingSummon(f.unit)) then
        return "summon"
    end
    if yes(UnitHasIncomingResurrection(f.unit)) then return "res" end
    return nil
end
function Live:InRange(f)
    local u = f.unit
    if u == "player" then return true end
    local grouped = yes(UnitInParty(u)) or (plain(UnitInRaid(u)) and UnitInRaid(u) ~= nil)
    if grouped then return UnitInRange(u) end -- may be secret: only ever passed to SetAlphaFromBoolean
    -- a spell picked for range (arena: a 40 yd spell) answers in combat too; its answer may be secret
    local spell = M:Unit(f.unitKey).rangeSpell
    if type(spell) == "string" and spell ~= "" and C_Spell and C_Spell.IsSpellInRange then
        local ok, near = pcall(C_Spell.IsSpellInRange, tonumber(spell) or spell, u)
        if ok and near ~= nil then return near end
    end
    if InCombatLockdown() then return true end -- distance checks on other units are combat-restricted
    local ok, near = pcall(CheckInteractDistance, u, 4)
    if ok and plain(near) then return near and true or false end
    return true
end
function Live:IsTarget(f) return f.unit ~= "target" and yes(UnitIsUnit(f.unit, "target")) end
function Live:IsFocus(f) return f.unit ~= "focus" and yes(UnitIsUnit(f.unit, "focus")) end
-- Who of my group targets this unit: class files of the player and party members (max 5).
function Live:TargetedBy(f)
    local out = {}
    for _, who in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
        if yes(UnitExists(who)) and yes(UnitIsUnit(who .. "target", f.unit)) then
            local _, file = UnitClass(who)
            out[#out + 1] = plain(file) and file or "PRIEST"
        end
    end
    return out
end
-- Out of sight (stealth, arena pillars): the unit exists but cannot be seen.
function Live:Hidden(f) return not yes(UnitIsVisible(f.unit)) end

---------------------------------------------------------------- sample source
-- f.sample = { name, level, class, classification, hp, hpMax, absorb, healAbsorb, heal, power, powerMax, powerToken,
--   reaction, dead, offline, leader, marker, role, combat, resting, pvp, threat, ready, buffs, debuffs, alt, … }
local Sample = {}
M.Sample = Sample
local function sv(f) return f.sample or {} end
function Sample:Exists() return true end
function Sample:Name(f, n) return M.Truncate(M.Nickname(sv(f).name or ""), n or M:Unit(f.unitKey).nameLength) end
function Sample:Level(f) return sv(f).level or "" end
function Sample:Classification(f) return CLASSIFICATION[sv(f).classification or ""] or "" end
function Sample:RawClassification(f) return sv(f).classification or "normal" end
function Sample:ClassName(f) return sv(f).className or "" end
function Sample:IsPlayer(f) return sv(f).class ~= nil end
function Sample:ClassFile(f) return sv(f).class end
function Sample:Reaction(f) return sv(f).reaction or 5 end
function Sample:Tapped(f) return sv(f).tapped or false end
function Sample:Dead(f) return sv(f).dead or false end
function Sample:Ghost() return false end
function Sample:Offline(f) return sv(f).offline or false end
Sample.Status = Live.Status
function Sample:Group(f) return sv(f).group or "" end
function Sample:Away() return "" end
function Sample:Guild(f) return sv(f).guild or "" end
function Sample:Title(f) return sv(f).title or "" end
function Sample:GuildOrTitle(f) local s = sv(f); return s.title or s.guild or "" end
function Sample:Health(f) return sv(f).hp or 0 end
function Sample:HealthMax(f) return sv(f).hpMax or 1 end
function Sample:HealthText(f, kind)
    local s = sv(f)
    if kind == "max" then return M:Number(s.hpMax or 0) end
    if kind == "deficit" then return M:Number((s.hpMax or 0) - (s.hp or 0)) end
    return M:Number(s.hp or 0)
end
function Sample:HealthPercent(f) local s = sv(f); return (s.hp or 0) / math.max(1, s.hpMax or 1) * 100 end
function Sample:HealthFraction(f) local s = sv(f); return (s.hp or 0) / math.max(1, s.hpMax or 1) end
function Sample:AbsorbText(f) return M:Number(sv(f).absorb or 0) end
function Sample:Absorbs(f) return sv(f).absorb or 0 end
function Sample:HealAbsorbs(f) return sv(f).healAbsorb or 0 end
function Sample:IncomingHeals(f, mine)
    local s = sv(f)
    if mine then return s.myHeal or math.floor((s.heal or 0) * 0.6) end
    return s.heal or 0
end
function Sample:SpellCost(f) return sv(f).cost end
function Sample:PowerType(f)
    local t = sv(f).powerToken or "MANA"
    return PT[({ MANA = "Mana", RAGE = "Rage", ENERGY = "Energy", FOCUS = "Focus", RUNIC_POWER = "RunicPower" })[t] or "Mana"] or 0, t
end
function Sample:Power(f, kind)
    local s = sv(f)
    if kind and kind ~= select(1, self:PowerType(f)) then return s.classPower or 0 end
    return s.power or 0
end
function Sample:PowerMax(f, kind)
    local s = sv(f)
    if kind and kind ~= select(1, self:PowerType(f)) then return s.classPowerMax or 5 end
    return s.powerMax or 1
end
function Sample:PowerText(f, kind)
    local s = sv(f)
    return M:Number(kind == "max" and (s.powerMax or 0) or (s.power or 0))
end
function Sample:PowerPercent(f) local s = sv(f); return (s.power or 0) / math.max(1, s.powerMax or 1) * 100 end
function Sample:AltPowerID(f) return sv(f).alt and 1 or 0 end
function Sample:AltPowerText(f) return sv(f).alt and M:Number(sv(f).alt) or "" end
function Sample:HealthColorFromCurve() return nil end
function Sample:Leader(f) return sv(f).leader or false end
function Sample:RaidMarker(f) return sv(f).marker end
function Sample:Role(f) return sv(f).role end
function Sample:InCombat(f) return sv(f).combat or false end
function Sample:Resting(f) return sv(f).resting or false end
function Sample:PvP(f) return sv(f).pvp end
function Sample:Threat(f) return sv(f).threat end
function Sample:ReadyCheck(f) return sv(f).ready end
function Sample:InRange(f) return not sv(f).far end
function Sample:IsTarget(f) return sv(f).isTarget or false end
function Sample:IsFocus(f) return sv(f).isFocus or false end
function Sample:TargetedBy(f) return sv(f).targetedBy or {} end
function Sample:Hidden(f) return sv(f).stealth or false end
function Sample:ThreatPercent(f) return sv(f).threatPct or 0 end
function Sample:LevelColored(f) return M.ColorLevel(sv(f).level) end
function Sample:SpecName(f) return sv(f).specName or "" end
function Sample:TargetName(f) return sv(f).targetName or "" end

function M:SourceOf(f) return f.sample and Sample or Live end

---------------------------------------------------------------- health
local function setBar(bar, value, smooth)
    if smooth and INTERP then bar:SetValue(value, INTERP) else bar:SetValue(value) end
end

local function healthColor(f, src, u)
    local db = M.db
    if src:Offline(f) then return M:Color("offline") end
    if src:Dead(f) then return M:Color("dead") end
    if src:Tapped(f) then return M:Color("tapped") end
    local mode = u.bar.color
    if mode == "class" then
        local file = src:ClassFile(f)
        if file then return ns.Util.ClassColor(file) end
        local r, g, b = M.ReactionColor(src:Reaction(f))
        if r then return r, g, b end
    elseif mode == "reaction" then
        local r, g, b = M.ReactionColor(src:Reaction(f))
        if r then return r, g, b end
        local file = src:ClassFile(f)
        if file then return ns.Util.ClassColor(file) end
    elseif mode == "health" then
        local p = src:HealthFraction(f)
        if p then return M:CurveColor(p) end
        return nil, "curve"
    elseif mode == "fixed" then
        return Skin:SpecColor(u.bar.fixed, "accent.primary")
    end
    return Skin:SpecColor(db.colors.fixed, M.COLOR_TOKENS.fixed)
end

function M:UpdateHealth(f, src)
    local u = self:Unit(f.unitKey)
    local bar = f.Health
    bar:SetMinMaxValues(0, src:HealthMax(f))
    setBar(bar, src:Health(f), u.bar.smooth and not f.sample)
    local r, g, b = healthColor(f, src, u)
    if r == nil and g == "curve" then
        local color = src:HealthColorFromCurve(f)
        if color then bar:SetStatusBarColor(color:GetRGB()) else bar:SetStatusBarColor(self:Color("high")) end
        r, g, b = self:Color("mid")
    else
        if u.bar.dark then
            -- dark mode: a dim bar over a coloured background
            bar:SetStatusBarColor(0.14, 0.14, 0.16)
        else
            bar:SetStatusBarColor(r, g, b)
        end
    end
    local bg = bar.bg
    if u.bar.bg ~= "none" then
        if u.bar.dark then
            bg:SetVertexColor(r or 0.5, g or 0.1, b or 0.1, u.bar.bgAlpha)
        elseif type(u.bar.bgColor) == "table" then
            local br, bgc, bb = Skin:SpecColor(u.bar.bgColor, "bg.sunken")
            bg:SetVertexColor(br, bgc, bb, u.bar.bgAlpha)
        else
            bg:SetVertexColor((r or 0.2) * 0.25, (g or 0.2) * 0.25, (b or 0.2) * 0.25, u.bar.bgAlpha)
        end
    end
    self:UpdatePrediction(f, src)
end

function M:UpdatePrediction(f, src)
    local u = self:Unit(f.unitKey)
    local ab = u.absorb
    local max = src:HealthMax(f)
    local show = ab.show
    f.Absorb:SetShown(show)
    if show then
        f.Absorb:SetMinMaxValues(0, max)
        f.Absorb:SetValue(src:Absorbs(f))
    end
    f.HealAbsorb:SetShown(ab.healAbsorb)
    if ab.healAbsorb then
        f.HealAbsorb:SetMinMaxValues(0, max)
        f.HealAbsorb:SetValue(src:HealAbsorbs(f))
    end
    f.HealPred:SetShown(ab.prediction)
    f.HealPred:SetMinMaxValues(0, max)
    f.HealPred:SetValue(ab.prediction and src:IncomingHeals(f) or 0)
    f.HealMine:SetShown(ab.prediction)
    f.HealMine:SetMinMaxValues(0, max)
    f.HealMine:SetValue(ab.prediction and src:IncomingHeals(f, true) or 0)
end

---------------------------------------------------------------- power
function M:UpdatePower(f, src)
    local u = self:Unit(f.unitKey)
    local pb = u.powerBar
    if not f.Power:IsShown() and pb.show ~= "mana" then return self:UpdateAltPower(f, src) end
    local kind, token = src:PowerType(f)
    if pb.show == "mana" then
        local isMana = kind == (PT.Mana or 0)
        if f.Power.manaOnly ~= isMana then
            f.Power.manaOnly = isMana
            f.Power:SetAlpha(isMana and 1 or 0)
        end
    else
        f.Power:SetAlpha(1)
    end
    f.Power:SetMinMaxValues(0, src:PowerMax(f))
    setBar(f.Power, src:Power(f), pb.smooth and not f.sample)
    local r, g, b
    if pb.color == "class" and src:ClassFile(f) then
        r, g, b = ns.Util.ClassColor(src:ClassFile(f))
    elseif pb.color == "fixed" then
        r, g, b = Skin:SpecColor(pb.fixed, "accent.primary")
    else
        r, g, b = M.PowerColor(token, kind)
    end
    f.Power:SetStatusBarColor(r, g, b)
    M.PowerGradient(f.Power, pb.gradient, r, g, b)
    f.Power.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.9)
    self:UpdateCost(f, src, kind)
    self:UpdateAltPower(f, src)
end

-- A power fill that darkens along its length ("horizontal") or height ("vertical"); "none" is flat.
function M.PowerGradient(bar, mode, r, g, b)
    local tex = bar:GetStatusBarTexture()
    if not (tex and tex.SetGradient) then return end
    if mode == "horizontal" or mode == "vertical" then
        tex:SetVertexColor(1, 1, 1)
        tex:SetGradient(mode == "horizontal" and "HORIZONTAL" or "VERTICAL", CreateColor(r * 0.55, g * 0.55, b * 0.55, 1),
            CreateColor(r, g, b, 1))
        bar.gradientOn = true
    elseif bar.gradientOn then
        tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 1))
        bar.gradientOn = nil
    end
end

function M:UpdateCost(f, src, kind)
    local pb = self:Unit(f.unitKey).powerBar
    -- (the cost is drawn back from a left-to-right fill's end only)
    local cost = pb.cost and f.Power:IsShown() and (pb.direction or "RIGHT") == "RIGHT" and src:SpellCost(f, kind) or nil
    f.CostPred:SetShown(cost ~= nil)
    if cost then
        f.CostPred:SetMinMaxValues(0, src:PowerMax(f))
        f.CostPred:SetValue(cost)
    end
end

function M:UpdateAltPower(f, src)
    local u = self:Unit(f.unitKey)
    local id = u.powerBar.alt and src:AltPowerID(f) or 0
    local show = id ~= 0
    f.AltPower:SetShown(show)
    if not show then return end
    local kind = PT.Alternate or 10
    if f.sample then
        f.AltPower:SetMinMaxValues(0, 100)
        f.AltPower:SetValue(f.sample.alt or 0)
    else
        f.AltPower:SetMinMaxValues(0, UnitPowerMax(f.unit, kind))
        f.AltPower:SetValue(UnitPower(f.unit, kind))
    end
    local r, g, b = Theme:Color("state.info")
    f.AltPower:SetStatusBarColor(r, g, b)
    f.AltPower.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.9)
end

---------------------------------------------------------------- texts
local function nameColor(f, src, u)
    local mode = u.nameColor
    if mode == "class" then
        local file = src:ClassFile(f)
        if file then return ns.Util.ClassColor(file) end
        local r, g, b = M.ReactionColor(src:Reaction(f))
        if r then return r, g, b end
    elseif mode == "reaction" then
        local r, g, b = M.ReactionColor(src:Reaction(f))
        if r then return r, g, b end
    end
    return Skin:SpecColor(u.name.color, "text.primary")
end

function M:UpdateTexts(f, src)
    local u = self:Unit(f.unitKey)
    local c = f.compiled
    if not c then return end
    M.ApplyTags(f.NameText, c.name, f, src)
    if u.nameColor ~= "white" then f.NameText:SetTextColor(nameColor(f, src, u)) end
    local status = src:Status(f)
    if status ~= "" then
        f.HealthText:SetText(status)
        f.HealthText:SetAlpha(1)
    else
        M.ApplyTags(f.HealthText, c.health, f, src)
        local curve = u.hideFull and M.FullCurve()
        if u.hideFull and f.sample then
            f.HealthText:SetAlpha(src:HealthFraction(f) >= 1 and 0 or 1)
        elseif curve and not f.sample then
            local ok, a = pcall(UnitHealthPercent, f.unit, true, curve)
            if ok then f.HealthText:SetAlpha(a) end
        else
            f.HealthText:SetAlpha(1)
        end
    end
    M.ApplyTags(f.PowerText, c.power, f, src)
    M.ApplyTags(f.InfoText, c.info, f, src)
    if f.Strip:IsShown() and f.compiledStrip then M.ApplyTags(f.Strip.text, f.compiledStrip, f, src) end
end

---------------------------------------------------------------- portrait
-- The game's art for an elite (winged gold), rare elite (gold) or rare (silver star) portrait; nil for others.
local PORTRAIT_ART = { elite = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged",
    worldboss = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", rareelite = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold",
    rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star" }
M.PORTRAIT_ART = PORTRAIT_ART

function M:UpdatePortrait(f, src)
    local u = self:Unit(f.unitKey)
    if not f.PortraitHolder:IsShown() then return end
    local art = u.portraitArt and u.portraitPos ~= "overlay" and PORTRAIT_ART[src:RawClassification(f)]
    if art then f.PortraitArt:SetAtlas(art) end
    f.PortraitArt:SetShown(art and true or false)
    local mode = u.portrait
    if mode == "model" then
        if f.sample then
            f.Model:ClearModel()
            f.Model:SetUnit("player")
        else
            f.Model:SetUnit(f.unit)
        end
        f.Model:SetPortraitZoom(1)
        f.Model:SetCamDistanceScale(1)
        return
    end
    local tex = f.Portrait
    local z = u.portraitZoom or 0
    if mode == "class" and src:ClassFile(f) then
        tex:SetTexCoord(0, 1, 0, 1)
        local atlas = GetClassAtlas(src:ClassFile(f))
        if atlas then tex:SetAtlas(atlas) end
        return
    end
    tex:SetTexCoord(z, 1 - z, z, 1 - z)
    if f.sample then
        if f.sample.class then
            local atlas = GetClassAtlas(f.sample.class)
            if atlas then tex:SetAtlas(atlas) end
        else
            SetPortraitTexture(tex, "player")
        end
    else
        SetPortraitTexture(tex, f.unit)
    end
end

---------------------------------------------------------------- indicators
-- A raid marker texture for an index that may be secret (SetSpriteSheetCell takes it as is); nil hides it.
function M.ShowMarker(tex, idx)
    if idx ~= nil and not plain(idx) then
        pcall(tex.SetSpriteSheetCell, tex, idx, 4, 4)
        tex:Show()
    elseif idx then
        SetRaidTargetIconTexture(tex, idx)
        tex:Show()
    else
        tex:Hide()
    end
end

local function marker(f, src, ic)
    if ic.marker then M.ShowMarker(f.Marker, src:RaidMarker(f)) else f.Marker:Hide() end
end

local function roleAndStates(f, src, ic, u)
    f.Leader:SetShown(ic.leader and src:Leader(f))
    -- arena: the healer badge shows the role icon for healers even with role icons off
    local healerOnly = not ic.role and u.widgets and u.widgets.healer
    local role = (ic.role or healerOnly) and src:Role(f)
    if healerOnly and role ~= "HEALER" then role = nil end
    if role then f.Role:SetAtlas(GetMicroIconForRole(role)) end
    f.Role:SetShown(role and true or false)
    f.Combat:SetShown(ic.combat and src:InCombat(f))
    local rest = ic.resting and src:Resting(f) and not src:InCombat(f)
    f.Resting:SetText(rest and "Zzz" or "")
    f.Resting:SetShown(rest)
    local pvp = ic.pvp and src:PvP(f)
    if pvp then
        ns.Icons:Apply(f.PvP, "pvp", ic.size + 4)
        f.PvP:SetVertexColor(Theme:Color(pvp == "ffa" and "state.warning" or "state.danger"))
    end
    f.PvP:SetShown(pvp and true or false)
end

local ELITE = { elite = "state.warning", worldboss = "state.warning", rareelite = "text.secondary" }
-- The elite / boss / rare badge for a (plain) classification; hidden for normal units.
function M.ShowClassification(tex, class, size)
    if ELITE[class] then
        ns.Icons:Apply(tex, "boss", size)
        tex:SetVertexColor(Theme:Color(ELITE[class]))
        tex:Show()
    elseif class == "rare" then
        tex:SetAtlas(M.ATLAS.rare)
        tex:SetSize(size, size)
        tex:SetVertexColor(1, 1, 1)
        tex:Show()
    else
        tex:Hide()
    end
end

local function elite(f, src, ic)
    if ic.elite then M.ShowClassification(f.Elite, src:RawClassification(f), ic.size + 2) else f.Elite:Hide() end
end

local READY = { ready = "READY_CHECK_READY_TEXTURE", notready = "READY_CHECK_NOT_READY_TEXTURE",
    waiting = "READY_CHECK_WAITING_TEXTURE" }
local function threatAndReady(f, src, ic)
    local threat = ic.threat and src:Threat(f)
    if threat and threat > 0 then
        local r, g, b = GetThreatStatusColor(threat)
        Skin:BorderSpec(f.ThreatGlow, { style = "glow", size = 2, color = { r = r, g = g, b = b, a = 1 } }, "state.danger")
    end
    f.ThreatGlow:SetShown(threat and threat > 0 or false)
    local ready = ic.ready and src:ReadyCheck(f)
    if READY[ready] then
        f.Ready:SetTexture(_G[READY[ready]])
    elseif ready == "summon" then
        ns.Icons:Apply(f.Ready, "arrow-down", ic.size + 6)
    elseif ready == "res" then
        ns.Icons:Apply(f.Ready, "heart", ic.size + 6)
    end
    f.Ready:SetShown(ready and true or false)
end

function M:UpdateIndicators(f, src)
    local u = self:Unit(f.unitKey)
    local ic = u.icons
    marker(f, src, ic)
    roleAndStates(f, src, ic, u)
    elite(f, src, ic)
    threatAndReady(f, src, ic)
    f.TargetMark:SetShown(u.targetBorder and src:IsTarget(f))
end

---------------------------------------------------------------- range and fading
function M:UpdateRange(f, src)
    local u = self:Unit(f.unitKey)
    local alpha = 1
    if u.oocFade and not f.sample and not InCombatLockdown() then alpha = u.oocAlpha end
    if f.Trinket then alpha = self:ArenaAlpha(f, alpha) end
    if not u.rangeFade then f:SetAlpha(alpha); return end
    local inRange = src:InRange(f)
    if plain(inRange) then
        f:SetAlpha(inRange and alpha or math.min(alpha, u.rangeAlpha))
    else
        f:SetAlphaFromBoolean(inRange, alpha, math.min(alpha, u.rangeAlpha))
    end
end

---------------------------------------------------------------- auras
local FILTERS = {
    buffs = { all = "HELPFUL", player = "HELPFUL|PLAYER", raid = "HELPFUL|RAID" },
    debuffs = { all = "HARMFUL", player = "HARMFUL|PLAYER", raid = "HARMFUL|RAID" },
}
M.AURA_FILTERS = FILTERS

local dispelCurve
local function dispelColors()
    if dispelCurve ~= nil then return dispelCurve or nil end
    dispelCurve = false
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.LuaCurveType) then return nil end
    local ok, c = pcall(function()
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        -- x is the dispel type ID (SpellDispelType): 1 Magic, 2 Curse, 3 Disease, 4 Poison, 9 Enrage, 11 Bleed;
        -- anything else draws no dispel border
        local function add(i, col)
            if col then curve:AddPoint(i, CreateColor(col.r, col.g, col.b, 1)) else curve:AddPoint(i, CreateColor(0, 0, 0, 0)) end
        end
        -- General's dispel colour overrides, else the game's colours
        local function col(kind)
            local r, g, b = ns.Util.DispelColor(kind)
            return r and { r = r, g = g, b = b } or nil
        end
        add(0); add(1, col("Magic")); add(2, col("Curse")); add(3, col("Disease"))
        add(4, col("Poison")); add(5); add(9, col("Bleed")); add(10); add(11, col("Bleed"))
        add(12)
        return curve
    end)
    if ok and c then dispelCurve = c end
    return dispelCurve or nil
end

M.DispelCurve = dispelColors
-- rebuilt on the next use after a dispel colour changes (theme change)
function M.ResetDispelCurve() dispelCurve = nil end

local function showAura(b, unit, aura, kind, a)
    b.unit, b.auraInstanceID = unit, aura.auraInstanceID
    b.Icon:SetTexture(aura.icon)
    local id = aura.auraInstanceID
    pcall(function()
        b.Count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit, id, 2, 99))
    end)
    local okD, duration = pcall(C_UnitAuras.GetAuraDuration, unit, id)
    if okD and duration then
        b.Cooldown:SetCooldownFromDurationObject(duration)
        b.Cooldown:Show()
    else
        b.Cooldown:Clear()
    end
    if kind == "debuffs" and a.dispel then
        local curve = dispelColors()
        local ok, color = false, nil
        if curve then ok, color = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, id, curve) end
        if ok and color then
            b.Dispel:SetVertexColor(color:GetRGBA())
            b.Dispel:Show()
        else
            b.Dispel:Hide()
        end
    else
        b.Dispel:Hide()
    end
    if kind == "debuffs" and a.desat then
        local ok, notMine = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, id, "HARMFUL|PLAYER")
        if ok then b.Icon:SetDesaturated(notMine) end
    else
        b.Icon:SetDesaturated(false)
    end
    b:Show()
end

M.ShowAura = showAura

local function showSample(b, s, kind, a, i)
    b.unit, b.auraInstanceID = nil, nil
    b.Icon:SetTexture(s.icon or M.SAMPLE_ICONS.fireball)
    b.Count:SetText((s.count or 0) > 1 and s.count or "")
    b.Cooldown:Clear()
    if s.duration then b.Cooldown:SetCooldown(GetTime() - (s.elapsed or 0), s.duration) end
    local r, g, bl
    if kind == "debuffs" and a.dispel and s.dispel then r, g, bl = ns.Util.DispelColor(s.dispel) end
    if r then b.Dispel:SetVertexColor(r, g, bl, 1); b.Dispel:Show() else b.Dispel:Hide() end
    b.Icon:SetDesaturated(kind == "debuffs" and a.desat and s.notMine or false)
    b.index = i
    b:Show()
end
M.ShowSampleAura = showSample

function M:UpdateAuras(f)
    local u = self:Unit(f.unitKey)
    local a = u.auras
    for _, kind in ipairs({ "buffs", "debuffs" }) do
        local container = kind == "buffs" and f.Buffs or f.Debuffs
        local where = a[kind]
        local buttons = container.buttons or {}
        local shown = 0
        if where ~= "off" then
            if f.sample then
                for i, s in ipairs(f.sample[kind] or {}) do
                    if i > a.max then break end
                    showSample(M.AuraButton(container, i), s, kind, a, i)
                    shown = i
                end
            elseif C_UnitAuras and C_UnitAuras.GetUnitAuras then
                local filter = FILTERS[kind][a[kind == "buffs" and "buffFilter" or "debuffFilter"]] or FILTERS[kind].all
                local ok, list = pcall(C_UnitAuras.GetUnitAuras, f.unit, filter, a.max)
                if ok and type(list) == "table" then
                    for i = 1, math.min(#list, a.max) do
                        local aura = list[i]
                        if aura then
                            ns.SafeCall(showAura, M.AuraButton(container, i), f.unit, aura, kind, a)
                            shown = i
                        end
                    end
                end
            end
        end
        for i = shown + 1, #buttons do buttons[i]:Hide() end
    end
end

---------------------------------------------------------------- class resource (player)
--[[ The player's own resource: pips for combo points, holy power, chi, soul shards, arcane charges and essence;
    runes with their recharge; Brewmaster stagger as a bar. When the count or maximum is secret the pips cannot be
    lit one by one (that needs a compare), so the resource is drawn as one bar instead. ]]
local CLASS_POWER = {
    ROGUE = "ComboPoints", PALADIN = "HolyPower", WARLOCK = "SoulShards", EVOKER = "Essence", DEATHKNIGHT = "Runes",
}
local SPEC_POWER = { [269] = "Chi", [62] = "ArcaneCharges", [268] = "Stagger" } -- Windwalker, Arcane, Brewmaster

function M.ClassPowerKind(classFile, specID, powerToken)
    if classFile == "DRUID" then return powerToken == "ENERGY" and "ComboPoints" or nil end
    if classFile == "MONK" or classFile == "MAGE" then return SPEC_POWER[specID] end
    return CLASS_POWER[classFile]
end

local function pip(cp, i)
    local p = cp.pips[i]
    if not p then
        p = CreateFrame("StatusBar", nil, cp)
        p:SetStatusBarTexture(ns.Media.textures.WHITE)
        p:SetMinMaxValues(0, 1)
        p.bg = p:CreateTexture(nil, "BACKGROUND")
        p.bg:SetAllPoints()
        p.bg:SetTexture(ns.Media.textures.WHITE)
        cp.pips[i] = p
    end
    return p
end

-- Round pips mask their fill and background with a circle (once made, added or removed as the shape changes).
local NO_PIP_BORDER = { style = "none", shadow = "none" }
local function pipMask(p, round)
    if round and not p.mask then
        p.mask = p:CreateMaskTexture()
        p.mask:SetAllPoints()
        p.mask:SetTexture(ns.Media.textures.MASK_CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    if (p.masked or false) == round then return end
    local fill = p:GetStatusBarTexture()
    if round then
        fill:AddMaskTexture(p.mask); p.bg:AddMaskTexture(p.mask)
    else
        fill:RemoveMaskTexture(p.mask); p.bg:RemoveMaskTexture(p.mask)
    end
    p.masked = round
end

-- Where pip i sits in its slot for a shape: bars fill the slot, squares and circles are as big as the slot and
-- the bar height allow, centred in the slot. Returns x, y, w, h (pure).
function M.PipRect(shape, slotX, slotW, height)
    slotW, height = math.max(1, slotW), math.max(1, height)
    if shape ~= "square" and shape ~= "round" then return slotX, 0, slotW, height end
    local size = math.min(slotW, height)
    return slotX + math.floor((slotW - size) / 2 + 0.5), -math.floor((height - size) / 2 + 0.5), size, size
end

local CP_TOKEN = { ComboPoints = "COMBO_POINTS", HolyPower = "HOLY_POWER", SoulShards = "SOUL_SHARDS",
    Essence = "ESSENCE", Runes = "RUNES", Chi = "CHI", ArcaneCharges = "ARCANE_CHARGES" }
local function cpColor(kind, charged)
    local db = M.db.classPower
    if charged then return M:Color("charged") end
    if db.color == "class" then
        local _, file = UnitClass("player")
        return ns.Util.ClassColor(plain(file) and file or nil)
    elseif db.color == "theme" then
        return Theme:Color("accent.primary")
    end
    local r, g, b = ns.Util.PowerColor(CP_TOKEN[kind])
    if r then return r, g, b end
    return Theme:Color("accent.primary")
end

-- What the player's resource is right now: { kind, cur, max, charged = {…}|nil, runes = {…}|nil }.
local function readRunes()
    local runes = {}
    for i = 1, 6 do
        local start, duration, ready = GetRuneCooldown(i)
        runes[i] = { start = plain(start) and start or 0, duration = plain(duration) and duration or 0,
                     ready = plain(ready) and ready or false }
    end
    return runes
end

function M.ReadClassPower()
    local _, file = UnitClass("player")
    local api = C_SpecializationInfo
    local spec = api and api.GetSpecialization and api.GetSpecialization()
    local specID = plain(spec) and spec and api.GetSpecializationInfo and api.GetSpecializationInfo(spec) or nil
    local _, token = UnitPowerType("player")
    local kind = M.ClassPowerKind(plain(file) and file or nil, plain(specID) and specID or nil, plain(token) and token or nil)
    if kind == "Runes" then return { kind = kind, max = 6, runes = readRunes() } end
    if kind == "Stagger" then return M.db.classPower.stagger and { kind = kind } or nil end
    if not (kind and PT[kind]) then return nil end
    local points = GetUnitChargedPowerPoints and GetUnitChargedPowerPoints("player")
    return { kind = kind, cur = UnitPower("player", PT[kind]), max = UnitPowerMax("player", PT[kind]),
             charged = plain(points) and points or nil }
end

-- Thin dark lines between the pips of a resource drawn as one bar (or bar pips without spacing): n slots across
-- the bar's length; vertical bars stack them up the height.
local function separators(cp, n, show)
    cp.seps = cp.seps or {}
    local vertical = M.db.classPower.orientation == "VERTICAL"
    local used = 0
    if show and type(n) == "number" and n > 1 and n <= 10 then
        local len = vertical and cp:GetHeight() or cp:GetWidth()
        for i = 1, n - 1 do
            local t = cp.seps[i]
            if not t then
                t = cp:CreateTexture(nil, "OVERLAY", nil, 6)
                t:SetTexture(ns.Media.textures.WHITE)
                cp.seps[i] = t
            end
            t:ClearAllPoints()
            local at = math.floor(len * i / n + 0.5)
            if vertical then
                t:SetPoint("BOTTOMLEFT", cp, "BOTTOMLEFT", 0, at); t:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT", 0, at)
                t:SetHeight(1)
            else
                t:SetPoint("TOPLEFT", cp, "TOPLEFT", at, 0); t:SetPoint("BOTTOMLEFT", cp, "BOTTOMLEFT", at, 0)
                t:SetWidth(1)
            end
            t:SetVertexColor(0, 0, 0, 0.85)
            t:Show()
            used = i
        end
    end
    for i = used + 1, #cp.seps do cp.seps[i]:Hide() end
end
M.ClassPowerSeparators = separators

-- The count over the resource (plain or secret: it only reaches the format string).
local function countText(cp, info)
    local db = M.db.classPower
    local spec = db.text
    if not (spec and spec.show) or info.runes or info.kind == "Stagger" then
        if cp.text then cp.text:Hide() end
        return
    end
    if not cp.text then
        cp.textLayer = CreateFrame("Frame", nil, cp)
        cp.textLayer:SetAllPoints()
        cp.textLayer:SetFrameLevel(cp:GetFrameLevel() + 8)
        cp.text = cp.textLayer:CreateFontString(nil, "OVERLAY")
    end
    Skin:TextSpec(cp.text, spec, "number", "text.primary")
    Skin:Place(cp.text, cp, spec)
    cp.text:SetFormattedText("%d", info.cur or 0)
    cp.text:Show()
end

-- Out-of-combat fade and "hide when full" (plain counts only); sample frames never fade.
local function cpAlpha(cp, info, sample)
    local db = M.db.classPower
    local full = not info.runes and plain(info.cur) and plain(info.max) and info.cur == info.max
    local ooc = not InCombatLockdown()
    if sample then cp:SetAlpha(1); return end
    cp:SetAlpha(((db.hideFull and full and ooc) or (db.fade and ooc)) and 0 or 1)
end

-- one bar for stagger, or when the count or maximum is secret (pips would need a compare)
local function drawSingle(cp, info, live)
    local db = M.db.classPower
    for _, p in ipairs(cp.pips) do p:Hide() end
    local bar = cp.bar
    bar:Show()
    bar:SetOrientation(db.orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
    if info.kind == "Stagger" and live then
        bar:SetMinMaxValues(0, UnitHealthMax("player"))
        bar:SetValue(UnitStagger("player") or 0)
        bar:SetStatusBarColor(Theme:Color("state.warning"))
    else
        bar:SetMinMaxValues(0, info.max or 5)
        bar:SetValue(info.cur or 0)
        bar:SetStatusBarColor(cpColor(info.kind))
    end
    bar.bg:SetVertexColor(0, 0, 0, 0.6)
    Skin:BorderSpec(bar, db.border, "border.black")
    separators(cp, plain(info.max) and info.max or nil, db.separators and info.kind ~= "Stagger")
end

local function runeOrder(runes, n, sorted)
    local order = {}
    for i = 1, n do order[i] = i end
    if runes and sorted then
        table.sort(order, function(a, b)
            local ra, rb = runes[a], runes[b]
            if ra.ready ~= rb.ready then return ra.ready end
            return (ra.start + ra.duration) < (rb.start + rb.duration)
        end)
    end
    return order
end

local function pipValue(info, i, order, now)
    if info.runes then
        local rune = info.runes[order[i]]
        if rune.ready then return 1 end
        return rune.duration > 0 and math.min(1, (now - rune.start) / rune.duration) or 0
    end
    return (i <= (info.cur or 0)) and 1 or 0
end

local function drawPips(cp, info)
    local db = M.db.classPower
    cp.bar:Hide()
    local n = math.max(1, math.min(10, info.max or 5))
    local vertical = db.orientation == "VERTICAL"
    local slots = M.Pips(n, vertical and cp:GetHeight() or cp:GetWidth(), db.spacing)
    local hot = db.threshold > 0 and not info.runes and (info.cur or 0) >= db.threshold
    local order = runeOrder(info.runes, n, db.runesSorted)
    local chargedSet = {}
    for _, i in ipairs(info.charged or {}) do chargedSet[i] = true end
    local now, height = GetTime(), vertical and cp:GetWidth() or cp:GetHeight()
    for i = 1, n do
        local p = pip(cp, i)
        local x, y, w, h = M.PipRect(db.shape, slots[i][1], slots[i][2], height)
        p:ClearAllPoints()
        if vertical then
            -- pips stack from the bottom: the slot runs up the height, the rect's y is the cross offset
            p:SetPoint("BOTTOMLEFT", cp, "BOTTOMLEFT", -y, x)
            p:SetSize(h, w)
            p:SetOrientation("VERTICAL")
        else
            p:SetPoint("TOPLEFT", cp, "TOPLEFT", x, y)
            p:SetSize(w, h)
            p:SetOrientation("HORIZONTAL")
        end
        local round = db.shape == "round"
        pipMask(p, round)
        local r, g, b = cpColor(info.kind, chargedSet[i])
        if hot and not chargedSet[i] then r, g, b = M:Color("threshold") end
        p:SetStatusBarColor(r, g, b)
        p.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2, 0.85)
        Skin:BorderSpec(p, round and NO_PIP_BORDER or db.border, "border.black")
        local value = pipValue(info, i, order, now)
        p:SetValue(value)
        p:SetAlpha(value >= 1 and 1 or (value > 0 and 0.6 or db.emptyAlpha))
        p:Show()
    end
    for i = n + 1, #cp.pips do cp.pips[i]:Hide() end
    separators(cp, n, db.separators and db.shape == "bar" and db.spacing == 0)
end

-- Lays out and fills the class resource (sample frames carry classPowerKind / classPower / classPowerMax).
function M:UpdateClassPower(f)
    local cp = f.ClassPower
    if not cp then return end
    local db = self.db.classPower
    local info
    if f.sample then
        local s = f.sample
        info = s.classPowerKind and { kind = s.classPowerKind, cur = s.classPower, max = s.classPowerMax, charged = s.charged }
    else
        info = M.ReadClassPower()
    end
    local was = f.classPowerActive
    f.classPowerActive = (f.detached or db.show ~= "off") and info ~= nil
    if was ~= f.classPowerActive and not f.noLayout and not (f.secure and InCombatLockdown()) then self:Layout(f) end
    f.hasRunes = info and info.runes ~= nil
    cp:SetShown(f.classPowerActive)
    if not f.classPowerActive then return end
    local single = info.kind == "Stagger" or not plain(info.cur) or not plain(info.max)
        or (not info.runes and type(info.max) ~= "number")
    if single then drawSingle(cp, info, not f.sample) else drawPips(cp, info) end
    countText(cp, info)
    cpAlpha(cp, info, f.sample)
end

---------------------------------------------------------------- arena
--[[ Racial abilities by race file: the spell whose icon the racial slot shows and its cooldown (seconds) once we see
    it used. Arena enemies' casts are often secret: then the icon stays without a cooldown. ]]
local RACIALS = {
    Human = { 59752, 180 }, -- spellIDs(retail): Will to Survive
    Scourge = { 7744, 120 }, -- spellIDs(retail): Will of the Forsaken
    Dwarf = { 20594, 120 }, -- spellIDs(retail): Stoneform
    Gnome = { 20589, 60 }, -- spellIDs(retail): Escape Artist
    NightElf = { 58984, 120 }, -- spellIDs(retail): Shadowmeld
    Tauren = { 20549, 90 }, -- spellIDs(retail): War Stomp
    Troll = { 26297, 180 }, -- spellIDs(retail): Berserking
    Orc = { 20572, 120 }, -- spellIDs(retail): Blood Fury
    BloodElf = { 28730, 120 }, -- spellIDs(retail): Arcane Torrent
    Draenei = { 59542, 180 }, -- spellIDs(retail): Gift of the Naaru
    Goblin = { 69070, 90 }, -- spellIDs(retail): Rocket Jump
    Worgen = { 68992, 120 }, -- spellIDs(retail): Darkflight
    Pandaren = { 107079, 120 }, -- spellIDs(retail): Quaking Palm
    Dracthyr = { 368970, 90 }, -- spellIDs(retail): Tail Swipe
}
M.RACIALS = RACIALS

--[[ The class icon's aura: crowd control on the enemy first, then its big defensive, then an important buff.
    Each kind is one filtered list (C_UnitAuras.GetUnitAuras); the first entry is drawn. ]]
local ICON_AURAS = { { "HARMFUL|CROWD_CONTROL", "cc" }, { "HELPFUL|BIG_DEFENSIVE", "defensive" },
    { "HELPFUL|IMPORTANT", "important" } }
M.ICON_AURAS = ICON_AURAS

function M.FindIconAura(unit)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return nil end
    for _, entry in ipairs(ICON_AURAS) do
        local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, entry[1], 1)
        if ok and type(list) == "table" and list[1] then return list[1], entry[2] end
    end
    return nil
end

local function classIcon(f, u, src)
    local ci = f.ClassIcon
    if not (ci and u.classIcon) then return end
    local file = src:ClassFile(f)
    local specID = f.sample and f.sample.specID or M.ArenaSpecID(f.unit)
    local atlas = file and GetClassAtlas and GetClassAtlas(file)
    if atlas then
        ci.Icon:SetAtlas(atlas)
    elseif specID then
        local _, _, _, icon = GetSpecializationInfoByID(specID)
        if icon then ci.Icon:SetTexture(icon) end
    end
    -- the aura on top
    local aura, kind
    if not u.classIconAuras then
        aura = nil
    elseif f.sample then
        local sa = f.sample.iconAura
        if sa then aura, kind = sa, sa.kind end
    else
        aura, kind = M.FindIconAura(f.unit)
    end
    ci.Aura:SetShown(aura ~= nil)
    ci.Glow:SetShown(aura ~= nil and u.auraGlow)
    if not aura then ci.Cooldown:Clear(); return end
    ci.Aura:SetTexture(aura.icon)
    if f.sample then
        ci.Cooldown:SetCooldown(GetTime() - (aura.elapsed or 0), aura.duration or 6)
    else
        local ok, d = pcall(C_UnitAuras.GetAuraDuration, f.unit, aura.auraInstanceID)
        if ok and d then ci.Cooldown:SetCooldownFromDurationObject(d) else ci.Cooldown:Clear() end
    end
    if u.auraGlow then
        Skin:BorderSpec(ci.Glow, { style = "solid", size = 2, color = false, shadow = "none" }, M.COLOR_TOKENS[kind] or "state.danger")
        local c = M.db.colors[kind]
        if type(c) == "table" then Skin:BorderSpec(ci.Glow, { style = "solid", size = 2, color = c, shadow = "none" }, "state.danger") end
    end
end

local function racial(f, u)
    if not (f.Racial and u.racial) then return end
    local race
    if f.sample then race = f.sample.race else
        local _, file = UnitRace(f.unit)
        race = plain(file) and file or nil
    end
    local entry = race and RACIALS[race]
    f.Racial:SetShown(entry ~= nil)
    if not entry then return end
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(entry[1])
    if icon then f.Racial.Icon:SetTexture(icon) end
    if f.sample and f.sample.racialUsed then f.Racial.Cooldown:SetCooldown(GetTime() - f.sample.racialUsed, entry[2]) end
end

-- A seen cast of an arena enemy's racial (plain spell IDs only) starts the racial's cooldown.
function M:OnArenaCast(f, spellID)
    if not (f and f.Racial and plain(spellID)) then return end
    for _, entry in pairs(RACIALS) do
        if entry[1] == spellID then f.Racial.Cooldown:SetCooldown(GetTime(), entry[2]); return end
    end
end

local function widgets(f, u, src)
    local w = u.widgets or {}
    f.FocusMark:SetShown(w.focus and src:IsFocus(f) or false)
    local list = w.targets and src:TargetedBy(f) or {}
    for i, p in ipairs(f.Targets.pips) do
        local file = list[i]
        if file then p:SetVertexColor(ns.Util.ClassColor(file)) end
        p:SetShown(file ~= nil)
    end
end

-- The sample DR tray (Test frames and the preview): plain icons in the real tray's place and look.
local DR_SAMPLE = { { icon = "Interface\\Icons\\Spell_Nature_Polymorph", elapsed = 4, duration = 18 },
    { icon = "Interface\\Icons\\Ability_Rogue_KidneyShot", elapsed = 11, duration = 18, immune = true },
    { icon = "Interface\\Icons\\Spell_Shadow_Possession", elapsed = 15, duration = 18 } }
M.DR_SAMPLE = DR_SAMPLE

function M.DrawSampleDR(f, u)
    local dr = u.dr
    local box = f.DR
    local n = (f.sample and f.sample.dr) or 0
    for i = 1, math.max(n, #box.samples) do
        local b = box.samples[i]
        if i <= n then
            if not b then
                b = CreateFrame("Frame", nil, box)
                b.Icon = b:CreateTexture(nil, "ARTWORK")
                b.Icon:SetAllPoints()
                b.Cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
                b.Cooldown:SetAllPoints()
                b.Cooldown:SetReverse(true)
                b.Immune = CreateFrame("Frame", nil, b)
                b.Immune:SetAllPoints()
                b.Immune:SetFrameLevel(b.Cooldown:GetFrameLevel() + 2)
                b.isPhoenixSample = true
                box.samples[i] = b
            end
            local s = DR_SAMPLE[(i - 1) % #DR_SAMPLE + 1]
            M.PlaceDRItem(b, box, i, dr)
            b.Icon:SetTexture(s.icon)
            M.StyleDRItem(b, dr)
            b.Cooldown:SetCooldown(GetTime() - s.elapsed, s.duration)
            b.Immune:SetShown(dr.immune and s.immune or false)
            b:Show()
        elseif b then
            b:Hide()
        end
    end
end

-- Item i of a DR tray: grows away from the frame (left of a left tray, right of a right one).
function M.PlaceDRItem(item, box, i, dr)
    item:ClearAllPoints()
    item:SetSize(dr.size, dr.size)
    local off = (i - 1) * (dr.size + dr.spacing)
    if box.side == "RIGHT" then
        item:SetPoint("LEFT", box, "LEFT", off, 0)
    else
        item:SetPoint("RIGHT", box, "RIGHT", -off, 0)
    end
end

-- The DR look on any tray item (ours or the game's): zoom, border, countdown font, immune border.
function M.StyleDRItem(item, dr)
    if item.Icon then Skin:IconZoom(item.Icon, dr.zoom) end
    local edge = M.DREdge(item)
    Skin:BorderSpec(edge, dr.border, "border.black")
    local cd = item.Cooldown
    local fs = cd and cd.GetCountdownFontString and cd:GetCountdownFontString()
    if fs then
        Skin:TextSpec(fs, dr.text, "number", "text.primary")
        cd:SetHideCountdownNumbers(dr.text.show == false)
    end
    local immune = item.isPhoenixSample and item.Immune
    if immune then Skin:BorderSpec(immune, { style = "solid", size = 2, color = false, shadow = "none" }, "state.danger") end
end

-- Our border frame on a tray item (a child frame: nothing is written into the game's own item).
local edges = setmetatable({}, { __mode = "k" })
function M.DREdge(item)
    local e = edges[item]
    if not e then
        e = CreateFrame("Frame", nil, item)
        e:SetAllPoints()
        edges[item] = e
    end
    return e
end

function M:UpdateArena(f)
    if not f.Trinket then return end
    local u = self:Unit("arena")
    local src = self:SourceOf(f)
    f.Trinket:SetShown(u.trinket)
    f.Spec:SetShown(u.spec)
    classIcon(f, u, src)
    racial(f, u)
    widgets(f, u, src)
    if f.sample then
        if u.trinket then
            f.Trinket.Icon:SetTexture(f.sample.trinketIcon or M.SAMPLE_ICONS.watch)
            if f.sample.trinketUsed then f.Trinket.Cooldown:SetCooldown(GetTime() - f.sample.trinketUsed, 120) end
        end
        if u.spec then f.Spec.Icon:SetTexture(f.sample.specIcon or M.SAMPLE_ICONS.sentry) end
        M.DrawSampleDR(f, u)
        return
    end
    M.DrawSampleDR(f, u) -- (no sample: hides the sample icons)
    if u.trinket and not f.trinketAdopted and C_PvP and C_PvP.GetArenaCrowdControlInfo then
        local ok, spellID, start, duration = pcall(C_PvP.GetArenaCrowdControlInfo, f.unit)
        -- restricted (secret) in rated play: then the game's own trinket (adopted, Arena.lua) draws it
        if ok and plain(spellID) and spellID then
            local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
            if icon then f.Trinket.Icon:SetTexture(icon) end
            if plain(start) and plain(duration) and type(start) == "number" and type(duration) == "number" then
                f.Trinket.Cooldown:SetCooldown(start / 1000, duration / 1000)
            end
        end
    end
    if u.spec then
        local specID = M.ArenaSpecID(f.unit)
        if specID then
            local _, _, _, icon = GetSpecializationInfoByID(specID)
            if icon then f.Spec.Icon:SetTexture(icon) end
        end
    end
end

-- Stealth: an arena enemy out of sight keeps its frame, faded.
function M:ArenaAlpha(f, alpha)
    if not f.Trinket then return alpha end
    local u = self:Unit("arena")
    if self:SourceOf(f):Hidden(f) then return math.min(alpha, u.stealthAlpha or 0.45) end
    return alpha
end

---------------------------------------------------------------- everything
function M:UpdateAll(f)
    if not f.layoutDone then
        if f.secure and not f.headerChild and InCombatLockdown() then return end
        self:Layout(f)
    end
    local src = self:SourceOf(f)
    if not f.sample and not src:Exists(f) then return end
    ns.SafeCall(self.UpdateHealth, self, f, src)
    ns.SafeCall(self.UpdatePower, self, f, src)
    ns.SafeCall(self.UpdateTexts, self, f, src)
    ns.SafeCall(self.UpdatePortrait, self, f, src)
    ns.SafeCall(self.UpdateIndicators, self, f, src)
    ns.SafeCall(self.UpdateAuras, self, f)
    ns.SafeCall(self.UpdateClassPower, self, f)
    ns.SafeCall(self.UpdateArena, self, f)
    ns.SafeCall(self.UpdateRange, self, f, src)
end

---------------------------------------------------------------- mouse
function M:OnEnterFrame(f)
    local u = self:Unit(f.unitKey)
    if u.highlight then f.Highlight:Show() end
    if f.sample or not f.unit then return end
    local mode = u.tooltip
    if mode == "never" or (mode == "ooc" and InCombatLockdown()) then return end
    if UnitFrame_OnEnter then
        f.unit = f.unit -- (Blizzard's handler reads self.unit)
        UnitFrame_OnEnter(f)
    end
end

function M:OnLeaveFrame(f)
    f.Highlight:Hide()
    if f.sample then return end
    if UnitFrame_OnLeave then UnitFrame_OnLeave(f) else GameTooltip:Hide() end
end
