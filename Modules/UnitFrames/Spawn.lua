local _, ns = ...
local L = ns.L
local M = ns.modules.UnitFrames

--[[ Phoenix mode: the secure unit buttons, Blizzard's frames parked, events, Test frames and Layout mode.

    Each unit gets a SecureUnitButtonTemplate button (boss and arena: five, stacked inside a plain holder). The
    attributes are Blizzard's own conventions: `unit`, `*type1 = target`, `*type2 = togglemenu`; Unit Watch
    shows the button while its unit exists. Click bindings work through SecureUnitButton_OnClick, Clique through
    the ClickCastFrames table. Size, place, scale and strata are protected: they change out of combat only.
    Blizzard's player, target (with its target of target), focus and boss frames are parked in a hidden frame
    (events off, hidden, re-parented); arena frames only when Phoenix's arena frames are on. Their cast bars are
    lent to the Phoenix frames (cast bar anchor) unless Phoenix's Cast Bars (S9) draw that unit: then the Phoenix
    bar sits on the anchor and Blizzard's stays parked. ]]

local frames, holders, byToken = {}, {}, {}
M.frames, M.holders, M.byToken = frames, holders, byToken
local parking, spawned
local tests = {}

-- Blizzard's frames per unit key (top-level frames only: children such as the pet frame or target of target
-- follow their parent).
local BLIZZARD = {
    player = { "PlayerFrame" }, target = { "TargetFrame" }, focus = { "FocusFrame" },
    boss = { "Boss1TargetFrame", "Boss2TargetFrame", "Boss3TargetFrame", "Boss4TargetFrame", "Boss5TargetFrame" },
    arena = { "CompactArenaFrame" },
}
M.BLIZZARD_FRAMES = BLIZZARD
-- Blizzard cast bars lent to our cast bar anchors
local SPELLBARS = { target = { "TargetFrameSpellBar" }, focus = { "FocusFrameSpellBar" },
    boss = { "Boss1TargetFrameSpellBar", "Boss2TargetFrameSpellBar", "Boss3TargetFrameSpellBar", "Boss4TargetFrameSpellBar",
             "Boss5TargetFrameSpellBar" } }

---------------------------------------------------------------- Blizzard parking
local function parkFrame(name)
    local fr = _G[name]
    if type(fr) ~= "table" or not fr.SetParent or fr:IsForbidden() then return end
    fr:UnregisterAllEvents()
    fr:Hide()
    fr:SetParent(parking)
    for _, part in ipairs({ "healthbar", "manabar", "powerBarAlt" }) do
        local bar = rawget(fr, part)
        if type(bar) == "table" and bar.UnregisterAllEvents then bar:UnregisterAllEvents() end
    end
end

local function parkBlizzard()
    if not parking then
        parking = CreateFrame("Frame", "PhoenixUI_UnitFrameParking", UIParent)
        parking:Hide()
    end
    for key, list in pairs(BLIZZARD) do
        if key ~= "arena" or M:Unit("arena").enabled then
            for _, name in ipairs(list) do parkFrame(name) end
        end
    end
    if BossTargetFrameContainer and BossTargetFrameContainer.UnregisterAllEvents then BossTargetFrameContainer:UnregisterAllEvents() end
end

---------------------------------------------------------------- cast bar anchors (S9 hook-up point)
-- Phoenix cast bars (Modules/CastBars) call M:CastBarAnchor(key, index) for the frame to sit on. Units the Cast Bars
-- module does not draw (it is off, in Blizzard mode, or that bar is off) get Blizzard's own target, focus and boss
-- cast bar lent to the anchor instead: it keeps its own events and drawing.
function M:CastBarAnchor(key, index)
    local list = frames[key]
    local f = list and list[index or 1]
    return f and f.CastAnchor or nil, f
end

local lent, placing = {}, {} -- Blizzard cast bar -> our frame; bars being placed by us (never fields on theirs)
local function anchorSpellbar(bar)
    local f = lent[bar]
    if not f or placing[bar] then return end
    placing[bar] = true
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", f.CastAnchor, "TOPLEFT", (f.CastAnchor:GetHeight() or 14) + 4, 0)
    bar:SetPoint("BOTTOMRIGHT", f.CastAnchor, "BOTTOMRIGHT", 0, 0)
    placing[bar] = nil
end

local function castBarsOwn(key)
    local cb = ns.modules.CastBars
    return cb and cb.Owns and cb:Owns(key)
end

local function lendSpellbars()
    for key, names in pairs(SPELLBARS) do
        local u = M:Unit(key)
        if castBarsOwn(key) then names = {} end
        for i, name in ipairs(names) do
            local bar = _G[name]
            local f = frames[key] and frames[key][i]
            if type(bar) == "table" and f and u.enabled and u.cast.attach ~= "none" and not bar:IsForbidden() then
                local anchor = f.CastAnchor
                -- the bar asks its parent where to sit; our anchor answers like a plain frame would
                anchor.ShouldAnchorSpellBarToAuraContainer = anchor.ShouldAnchorSpellBarToAuraContainer or function() return false end
                anchor.powerBarAlt = anchor.powerBarAlt or anchor
                if not lent[bar] then
                    hooksecurefunc(bar, "AdjustPosition", anchorSpellbar)
                end
                lent[bar] = f
                bar:SetParent(anchor)
                bar:SetScale(1)
                anchorSpellbar(bar)
            end
        end
    end
end

---------------------------------------------------------------- spawning
local function store(key)
    return {
        active = function() return M:IsEnabled() and M:IsPhoenix() and M:Unit(key).enabled end,
        get = function()
            local u = M:Unit(key)
            return { point = u.point, x = u.x, y = u.y, scale = u.scale }
        end,
        set = function(s)
            local u = M:Unit(key)
            u.point, u.x, u.y = s.point or u.point, s.x or u.x, s.y or u.y
            if s.scale then u.scale = s.scale end
        end,
        apply = function() M:Place(key) end,
        reset = function()
            local d, u = M.DEFAULTS.units[key], M:Unit(key)
            u.point, u.x, u.y, u.scale = d.point, d.x, d.y, d.scale
            M:Place(key)
        end,
    }
end
M.MoverStore = store

local function secureSetup(f, token)
    f:SetAttribute("unit", token)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    if token == "player" or token == "pet" then f:SetAttribute("toggleForVehicle", true) end
    f:RegisterForClicks("AnyUp")
    f:EnableMouse(true)
    -- Clique and other click-casting addons read this shared table
    local clickCast = rawget(_G, "ClickCastFrames")
    if type(clickCast) ~= "table" then clickCast = {}; rawset(_G, "ClickCastFrames", clickCast) end
    clickCast[f] = true
    RegisterUnitWatch(f)
    f.watched = true
end

local function spawnKey(key)
    local token = M.TOKENS[key]
    local holder = CreateFrame("Frame", "PhoenixUI_UF_" .. key, UIParent)
    holder:SetSize(1, 1)
    holders[key] = holder
    frames[key] = {}
    for i, t in ipairs(token) do
        local f = M:Build(holder, key, { secure = true, token = t, name = "PhoenixUI_UF_" .. t })
        f.index = i
        secureSetup(f, t)
        frames[key][i] = f
        byToken[t] = f
        f.ev = {}
        f:HookScript("OnShow", function(self) M:UpdateAll(self) end)
    end
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("uf." .. key, holder, L["UF_" .. key:upper()], store(key)) end
end

-- Position, size and stacking of one unit key's frames (out of combat).
local function placeNow(key)
    local holder, list = holders[key], frames[key]
    if not holder then return end
    local u = M:Unit(key)
    local scale = u.scale > 0 and u.scale or 1
    holder:SetScale(scale)
    holder:SetFrameStrata(u.strata)
    local n = #list
    local W, H = u.width, u.height
    local step = H + u.spacing
    local horizontal = u.growth == "LEFT" or u.growth == "RIGHT"
    if horizontal then step = W + u.spacing end
    holder:SetSize(horizontal and (W + (n - 1) * step) or W, horizontal and H or (H + (n - 1) * step))
    holder:ClearAllPoints()
    holder:SetPoint(u.point, UIParent, u.point, u.x / scale, u.y / scale)
    for i, f in ipairs(list) do
        M:Layout(f)
        f:ClearAllPoints()
        local off = (i - 1) * step
        if u.growth == "UP" then f:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, off)
        elseif u.growth == "RIGHT" then f:SetPoint("TOPLEFT", holder, "TOPLEFT", off, 0)
        elseif u.growth == "LEFT" then f:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -off, 0)
        else f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -off) end
        if u.enabled then
            if not f.watched then RegisterUnitWatch(f); f.watched = true end
        else
            if f.watched then UnregisterUnitWatch(f); f.watched = nil end
            f:Hide()
        end
        M:UpdateAll(f)
    end
    -- Phoenix cast bars re-fit the anchors
    ns.Events:Fire("PUI_UF_LAYOUT", key)
end

function M:Place(key)
    ns.Combat:Run("uf.place." .. key, placeNow, key)
end

---------------------------------------------------------------- events
local UNIT_EVENTS = {
    health = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
               "UNIT_HEAL_PREDICTION", "UNIT_CONNECTION", "UNIT_FLAGS" },
    power = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE" },
    texts = { "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION" },
    portrait = { "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" },
    auras = { "UNIT_AURA" },
    threat = { "UNIT_THREAT_SITUATION_UPDATE" },
    cast = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
             "UNIT_SPELLCAST_SUCCEEDED" },
}
local HANDLER = {
    health = function(f) local s = M:SourceOf(f); M:UpdateHealth(f, s); M:UpdateTexts(f, s); M:UpdateIndicators(f, s) end,
    power = function(f)
        local s = M:SourceOf(f)
        M:UpdatePower(f, s); M:UpdateTexts(f, s)
        if f.ClassPower then M:UpdateClassPower(f) end
    end,
    texts = function(f) local s = M:SourceOf(f); M:UpdateTexts(f, s); M:UpdateHealth(f, s); M:UpdateIndicators(f, s) end,
    portrait = function(f) M:UpdatePortrait(f, M:SourceOf(f)) end,
    auras = function(f) M:UpdateAuras(f) end,
    threat = function(f) M:UpdateIndicators(f, M:SourceOf(f)) end,
    -- spell cost prediction: only the player frame with the option on listens further
    cast = function(f)
        if f.unit ~= "player" or not M:Unit(f.unitKey).powerBar.cost then return end
        local s = M:SourceOf(f)
        M:UpdateCost(f, s, (s:PowerType(f)))
    end,
}

--[[ (Re)registers a frame's unit events for the unit it shows now (vehicles swap player and pet; group header
    buttons change units with the roster). f.ev is the frame's event owner; f.onUnitEvent(f, group, event), when
    set, runs after the shared handler (Group Frames: dispel highlight, aggro, states). `extra` adds more events
    under the group "extra" (handled by f.onUnitEvent only). A nil unit only unregisters. ]]
local function watchUnit(f, unit, extra)
    f.ev = f.ev or {}
    ns.Events:OffAll(f.ev)
    f.unit = unit
    if not unit then return end
    local function add(group, ev, fn)
        ns.Events:OnUnit(ev, f.ev, function()
            if not f:IsVisible() then return end
            if fn then ns.SafeCall(fn, f) end
            if f.onUnitEvent then ns.SafeCall(f.onUnitEvent, f, group, ev) end
        end, unit)
    end
    for group, list in pairs(UNIT_EVENTS) do
        if group ~= "cast" or unit == "player" then
            for _, ev in ipairs(list) do add(group, ev, HANDLER[group]) end
        end
    end
    for _, ev in ipairs(extra or {}) do add("extra", ev) end
end
M.WatchUnit = watchUnit

local function eachFrame(fn)
    for _, key in ipairs(M.UNITS) do
        for _, f in ipairs(frames[key] or {}) do fn(f, key) end
    end
end

local function updateAll() eachFrame(function(f) if f:IsVisible() then M:UpdateAll(f) end end) end
local function updateKey(key) for _, f in ipairs(frames[key] or {}) do if f:IsVisible() then M:UpdateAll(f) end end end

-- the player frame shows the vehicle while the player drives one (the pet frame then shows the player)
local function vehicleSwap()
    local p, pet = byToken.player, byToken.pet
    local inVehicle = UnitHasVehicleUI("player")
    inVehicle = M.plain(inVehicle) and inVehicle
    if p then watchUnit(p, inVehicle and "vehicle" or "player"); M:UpdateAll(p) end
    if pet then watchUnit(pet, inVehicle and "player" or "pet"); M:UpdateAll(pet) end
end

local tickers
local function tick()
    -- unit tokens without their own events (target of target, focus target) and range
    for _, key in ipairs({ "targettarget", "focustarget" }) do updateKey(key) end
    eachFrame(function(f)
        if f:IsVisible() then
            M:UpdateRange(f, M:SourceOf(f))
            if f.hasRunes then M:UpdateClassPower(f) end
        end
    end)
end

local function registerEvents()
    eachFrame(function(f) watchUnit(f, f.token) end)
    local E = ns.Events
    E:On("PLAYER_TARGET_CHANGED", M, function() updateKey("target"); updateKey("targettarget"); eachFrame(function(f)
        if f:IsVisible() then M:UpdateIndicators(f, M:SourceOf(f)) end end) end)
    E:On("PLAYER_FOCUS_CHANGED", M, function() updateKey("focus"); updateKey("focustarget") end)
    E:On("UNIT_PET", M, function() updateKey("pet") end)
    E:On("INSTANCE_ENCOUNTER_ENGAGE_UNIT", M, function() updateKey("boss") end)
    E:On("ARENA_OPPONENT_UPDATE", M, function() updateKey("arena") end)
    E:On("ARENA_PREP_OPPONENT_SPECIALIZATIONS", M, function() updateKey("arena") end)
    E:On("RAID_TARGET_UPDATE", M, function() eachFrame(function(f) if f:IsVisible() then M:UpdateIndicators(f, M:SourceOf(f)) end end) end)
    E:On("GROUP_ROSTER_UPDATE", M, updateAll)
    E:On("PARTY_LEADER_CHANGED", M, updateAll)
    E:On("PLAYER_ENTERING_WORLD", M, function() vehicleSwap(); updateAll() end)
    E:On("PLAYER_UPDATE_RESTING", M, function() updateKey("player") end)
    E:On("PLAYER_REGEN_ENABLED", M, updateAll)
    E:On("PLAYER_REGEN_DISABLED", M, function() eachFrame(function(f)
        if f:IsVisible() then M:UpdateIndicators(f, M:SourceOf(f)); M:UpdateRange(f, M:SourceOf(f)) end end) end)
    E:On("READY_CHECK", M, updateAll)
    E:On("READY_CHECK_CONFIRM", M, updateAll)
    E:On("READY_CHECK_FINISHED", M, function() C_Timer.After(6, updateAll) end)
    E:On("INCOMING_RESURRECT_CHANGED", M, updateAll)
    E:On("INCOMING_SUMMON_CHANGED", M, updateAll)
    E:On("RUNE_POWER_UPDATE", M, function() updateKey("player") end)
    E:On("UPDATE_SHAPESHIFT_FORM", M, function() updateKey("player") end)
    E:On("PLAYER_SPECIALIZATION_CHANGED", M, function() updateKey("player") end)
    E:On("UNIT_ENTERED_VEHICLE", M, function(_, _, unit) if unit == "player" then vehicleSwap() end end)
    E:On("UNIT_EXITED_VEHICLE", M, function(_, _, unit) if unit == "player" then vehicleSwap() end end)
    E:Listen("PUI_THEME_CHANGED", M, function() M.ResetDispelCurve(); M:RefreshPhoenix() end)
    if not tickers then tickers = C_Timer.NewTicker(0.2, function() ns.SafeCall(tick) end) end
end

---------------------------------------------------------------- totems
-- Blizzard's totem bar lives under the parked player frame: it moves under the Phoenix player frame.
local totemHooked, totemPlacing
local function placeTotems()
    local tf, p = TotemFrame, byToken.player
    if type(tf) ~= "table" or not p or tf:IsForbidden() or InCombatLockdown() then return end
    totemPlacing = true
    if tf:GetParent() ~= UIParent then tf:SetParent(UIParent) end
    tf:ClearAllPoints()
    tf:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -(M:Unit("player").powerBar.position == "below" and 14 or 6))
    totemPlacing = nil
end

local function adoptTotems()
    if type(TotemFrame) ~= "table" then return end
    placeTotems()
    if not totemHooked then
        totemHooked = true
        hooksecurefunc(TotemFrame, "SetPoint", function()
            if not totemPlacing and M:IsEnabled() then ns.Combat:Run("uf.totems", placeTotems) end
        end)
    end
end

---------------------------------------------------------------- lifecycle
local function spawn()
    if spawned then return end
    spawned = true
    parkBlizzard()
    for _, key in ipairs(M.UNITS) do spawnKey(key) end
    for _, key in ipairs(M.UNITS) do placeNow(key) end
    lendSpellbars()
    adoptTotems()
    registerEvents()
    vehicleSwap()
end

function M:EnablePhoenix()
    ns.Combat:Run("uf.spawn", spawn)
end

function M:RefreshPhoenix()
    if not spawned then return end
    for _, key in ipairs(M.UNITS) do self:Place(key) end
    ns.Combat:Run("uf.spellbars", lendSpellbars)
    ns.Combat:Run("uf.totems", placeTotems)
end

---------------------------------------------------------------- Test frames
--[[ Test frames: the real Phoenix frames, released from Unit Watch, filled with sample data and shown (out of
    combat; combat ends the test). Sample data is plain, so every element is drawn, including ones the game
    would hide (boss 2-5, arena, absorbs, class resource). ]]
local I = "Interface\\Icons\\"
local ICON = {
    fireball = I .. "Spell_Fire_Fireball02", flame = I .. "Spell_Fire_FlameBolt", bomb = I .. "Ability_Mage_LivingBomb",
    shield = I .. "Spell_Holy_PowerWordShield", shout = I .. "Ability_Warrior_BattleShout", pain = I .. "Spell_Shadow_ShadowWordPain",
    storm = I .. "Spell_Frost_IceStorm", bolt = I .. "Spell_Nature_Lightning", watch = I .. "INV_Misc_PocketWatch_01",
    sentry = I .. "Spell_Holy_MagicalSentry",
}
M.SAMPLE_ICONS = ICON
local function sample(key, i)
    i = i or 1
    local _, class = UnitClass("player")
    local base = {
        player = { name = UnitName("player") or "Phoenix", level = 90, class = class, hp = 412000, hpMax = 520000,
                   absorb = 60000, heal = 140000, power = 162000, cost = 40000, powerMax = 250000, powerToken = "MANA", leader = true,
                   role = "HEALER", combat = true, classPowerKind = "HolyPower", classPower = 3, classPowerMax = 5, marker = 8 },
        target = { name = L.PREVIEW_MOB_HOSTILE, level = 92, classification = "elite", reaction = 2, hp = 1830000,
                   hpMax = 3200000, healAbsorb = 120000, power = 80, powerMax = 100, powerToken = "RAGE", threat = 3, marker = 7,
                   buffs = { { icon = ICON.shield, duration = 30, elapsed = 8 }, { icon = ICON.shout, count = 3 } },
                   debuffs = { { icon = ICON.pain, duration = 18, elapsed = 3, dispel = "Magic" },
                               { icon = ICON.storm, notMine = true, dispel = "Curse" },
                               { icon = ICON.bomb, count = 2, dispel = "Poison" } } },
        targettarget = { name = UnitName("player") or "Phoenix", class = class, hp = 412000, hpMax = 520000 },
        focus = { name = L.PREVIEW_MOB_FRIENDLY, level = 91, class = "PRIEST", hp = 98000, hpMax = 410000, power = 120000,
                  powerMax = 300000, powerToken = "MANA", far = true, role = "HEALER",
                  debuffs = { { icon = ICON.bolt, duration = 12, elapsed = 2, dispel = "Disease" } } },
        focustarget = { name = L.PREVIEW_MOB_HOSTILE, reaction = 2, hp = 1830000, hpMax = 3200000 },
        pet = { name = L.PREVIEW_UNIT_PET, level = 90, reaction = 5, hp = 160000, hpMax = 200000, power = 70, powerMax = 100,
                powerToken = "FOCUS" },
        boss = { name = i == 1 and L.PREVIEW_MOB_BOSS or (L.UF_BOSS .. " " .. i), level = "??", classification = "worldboss", reaction = 2,
                 hp = ({ 7600000, 5100000, 9800000, 2400000, 6600000 })[i] or 5000000, hpMax = 10000000,
                 absorb = i == 2 and 900000 or 0, power = 40, powerMax = 100, powerToken = "ENERGY", marker = i,
                 alt = i == 1 and 64 or nil,
                 debuffs = { { icon = ICON.pain, duration = 18, elapsed = 6 }, { icon = ICON.bomb, count = 4 } } },
        arena = { name = L.UF_SAMPLE_ARENA:format(i), class = ({ "WARRIOR", "MAGE", "PRIEST", "ROGUE", "DRUID" })[i] or "MAGE",
                  hp = ({ 410000, 260000, 380000, 180000, 300000 })[i] or 300000, hpMax = 450000, power = 60, powerMax = 100,
                  powerToken = ({ "RAGE", "MANA", "MANA", "ENERGY", "MANA" })[i] or "MANA",
                  debuffs = { { icon = ICON.flame, duration = 6, elapsed = 1, dispel = "Magic" } } },
    }
    return base[key] or base.target
end
M.SampleData = sample

function M:ShowPhoenixTest(show)
    if not spawned then return show and false or true end
    for _, key in ipairs(M.UNITS) do
        local u = self:Unit(key)
        for i, f in ipairs(frames[key]) do
            if show and u.enabled then
                if f.watched then UnregisterUnitWatch(f); f.watched = nil end
                f.sample = sample(key, i)
                tests[f] = true
                f.layoutDone = nil
                f:Show()
                M:UpdateAll(f)
            elseif tests[f] then
                tests[f] = nil
                f.sample = nil
                -- (combat starting ends the test: the hand-back to Unit Watch waits for it to end)
                ns.Combat:Run("uf.test." .. f.token, function()
                    f:Hide()
                    if M:Unit(key).enabled and not f.watched then RegisterUnitWatch(f); f.watched = true end
                    M:UpdateAll(f)
                end)
            end
        end
    end
    return true
end
