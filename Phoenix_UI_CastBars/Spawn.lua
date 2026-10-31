local _, ns = ...
local L = ns.L
local M = ns.modules.CastBars

--[[ Phoenix mode: one bar per unit token (boss and arena: five, stacked in a holder), Blizzard's bars parked, unit
    events, the player's GCD and (WoW Forever) swing bars, Test casts and Layout mode.

    A target, focus, boss or arena bar set to "attach" sits on that unit frame's cast bar anchor
    (UnitFrames:CastBarAnchor, S8) while the Phoenix unit frame uses one; otherwise it stands alone at its own
    position and joins Layout mode. Our bars are plain frames (no secure template): they show, hide and draw in
    combat. Blizzard's bars for the units we draw are parked: events off, hidden, and kept hidden if Blizzard
    shows or re-binds them (OnShow / SetUnit hooks). Handing them back needs a reload. ]]

local bars, holders = {}, {}
M.bars, M.holders = bars, holders
local spawned
local extras = {}
M.extras = extras

local BLIZZARD = {
    player = { "PlayerCastingBarFrame" }, pet = { "PetCastingBarFrame" },
    target = { "TargetFrameSpellBar" }, focus = { "FocusFrameSpellBar" },
    boss = { "Boss1TargetFrameSpellBar", "Boss2TargetFrameSpellBar", "Boss3TargetFrameSpellBar", "Boss4TargetFrameSpellBar",
             "Boss5TargetFrameSpellBar" },
}
M.BLIZZARD_BARS = BLIZZARD

---------------------------------------------------------------- Blizzard parking
local parked = {}
local function keepHidden(self)
    if parked[self] then self:Hide() end
end
local function rebound(self)
    if parked[self] then self:UnregisterAllEvents(); self:Hide() end
end

local function park(name)
    local fr = _G[name]
    if type(fr) ~= "table" or not fr.Hide or fr:IsForbidden() then return end
    fr:UnregisterAllEvents()
    fr:Hide()
    if parked[fr] == nil then
        fr:HookScript("OnShow", keepHidden)
        if type(fr.SetUnit) == "function" then hooksecurefunc(fr, "SetUnit", rebound) end
    end
    parked[fr] = true
end

local function parkBlizzard()
    for key, names in pairs(BLIZZARD) do
        if M:Bar(key).enabled then
            for _, name in ipairs(names) do park(name) end
        end
    end
end

---------------------------------------------------------------- anchoring
-- The Unit Frames anchor a bar sits on, or nil when it stands alone.
local function anchorOf(key, index)
    local b = M:Bar(key)
    if b.attach ~= "frame" or not M.ATTACHABLE[key] then return nil end
    local uf = ns.modules.UnitFrames
    if not (uf and uf:IsEnabled() and uf.IsPhoenix and uf:IsPhoenix() and uf.CastBarAnchor) then return nil end
    local anchor = uf:CastBarAnchor(key, index)
    if anchor and anchor.active then return anchor end
    return nil
end
M.AnchorOf = anchorOf

function M:IsAttached(key) return anchorOf(key, 1) ~= nil end

local function placeKey(key)
    local holder, list = holders[key], bars[key]
    if not holder then return end
    local b = M:Bar(key)
    local scale = b.scale > 0 and b.scale or 1
    holder:SetScale(scale)
    holder:SetFrameStrata(b.strata)
    local n = #list
    local horizontal = b.growth == "LEFT" or b.growth == "RIGHT"
    local step = (horizontal and b.width or b.height) + b.spacing
    holder:SetSize(horizontal and (b.width + (n - 1) * step) or b.width, horizontal and b.height or (b.height + (n - 1) * step))
    holder:ClearAllPoints()
    holder:SetPoint(b.point, UIParent, b.point, b.x / scale, b.y / scale)
    for i, f in ipairs(list) do
        local anchor = anchorOf(key, i)
        f:ClearAllPoints()
        if anchor then
            f:SetParent(anchor)
            f:SetFrameLevel(anchor:GetFrameLevel() + 2)
            M:LayoutBar(f, anchor:GetWidth(), anchor:GetHeight())
            f:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        else
            f:SetParent(holder)
            M:LayoutBar(f, b.width, b.height)
            local off = (i - 1) * step
            if b.growth == "UP" then f:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, off)
            elseif b.growth == "RIGHT" then f:SetPoint("TOPLEFT", holder, "TOPLEFT", off, 0)
            elseif b.growth == "LEFT" then f:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -off, 0)
            else f:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -off) end
        end
        if not b.enabled then M:StopSample(f); f.active = nil; f:Hide() end
    end
end
M.PlaceKey = placeKey

local function store(key)
    return {
        active = function() return M:IsEnabled() and M:IsPhoenix() and M:Bar(key).enabled and not M:IsAttached(key) end,
        get = function()
            local b = M:Bar(key)
            return { point = b.point, x = b.x, y = b.y, scale = b.scale }
        end,
        set = function(s)
            local b = M:Bar(key)
            b.point, b.x, b.y = s.point or b.point, s.x or b.x, s.y or b.y
            if s.scale then b.scale = s.scale end
        end,
        apply = function() placeKey(key) end,
        reset = function()
            local d, b = M.DEFAULTS.bars[key], M:Bar(key)
            b.point, b.x, b.y, b.scale = d.point, d.x, d.y, d.scale
            placeKey(key)
        end,
    }
end
M.MoverStore = store

---------------------------------------------------------------- events
local function watch(f, token)
    ns.Events:OffAll(f.ev)
    local function handler(_, event, unit, ...)
        if unit ~= f.unit then return end
        M:OnCastEvent(f, event, unit, ...)
    end
    for _, ev in ipairs(M.CAST_EVENTS) do
        if token == "player" then
            ns.Events:OnUnit(ev, f.ev, handler, "player", "vehicle")
        else
            ns.Events:OnUnit(ev, f.ev, handler, token)
        end
    end
end

local function eachBar(fn)
    for _, key in ipairs(M.KEYS) do
        for _, f in ipairs(bars[key] or {}) do fn(f, key) end
    end
end

local function resync(key)
    if not M:Bar(key).enabled then return end
    for _, f in ipairs(bars[key] or {}) do
        if not f.sample then f.hideAt = nil; f.active = nil; M:ShowCast(f) end
    end
end
M.Resync = resync

local function vehicleSwap()
    local p = bars.player and bars.player[1]
    if not p then return end
    local inVehicle = UnitHasVehicleUI and UnitHasVehicleUI("player")
    p.unit = (M.plain(inVehicle) and inVehicle) and "vehicle" or "player"
    resync("player")
end

local function registerEvents()
    eachBar(function(f) watch(f, f.token) end)
    local E = ns.Events
    E:On("PLAYER_TARGET_CHANGED", M, function() resync("target") end)
    E:On("PLAYER_FOCUS_CHANGED", M, function() resync("focus") end)
    E:On("UNIT_PET", M, function(_, _, unit) if unit == "player" then resync("pet") end end)
    E:On("INSTANCE_ENCOUNTER_ENGAGE_UNIT", M, function() resync("boss") end)
    E:On("ARENA_OPPONENT_UPDATE", M, function() resync("arena") end)
    E:On("PLAYER_ENTERING_WORLD", M, function() vehicleSwap(); for _, key in ipairs(M.KEYS) do resync(key) end end)
    E:On("UNIT_ENTERED_VEHICLE", M, function(_, _, unit) if unit == "player" then vehicleSwap() end end)
    E:On("UNIT_EXITED_VEHICLE", M, function(_, _, unit) if unit == "player" then vehicleSwap() end end)
    -- the unit frames moved or resized their cast bar anchors
    E:Listen("PUI_UF_LAYOUT", M, function() for key in pairs(M.ATTACHABLE) do placeKey(key) end end)
end

---------------------------------------------------------------- spawning
local function spawnKey(key)
    local holder = CreateFrame("Frame", "PhoenixUI_CB_" .. key, UIParent)
    holder:SetSize(1, 1)
    holders[key] = holder
    bars[key] = {}
    for i, token in ipairs(M.TOKENS[key]) do
        local f = M:BuildBar(holder, key, { name = "PhoenixUI_CB_" .. token })
        f.token, f.unit, f.index, f.ev = token, token, i, {}
        f:SetScript("OnUpdate", M.OnBarUpdate)
        f:Hide()
        bars[key][i] = f
    end
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("cb." .. key, holder, L.CB_MOVER:format(L["UF_" .. key:upper()]), store(key)) end
end

local function spawn()
    if spawned then return end
    spawned = true
    for _, key in ipairs(M.KEYS) do spawnKey(key) end
    for _, key in ipairs(M.KEYS) do placeKey(key) end
    parkBlizzard()
    registerEvents()
    M:SpawnExtras() -- Extras.lua
    vehicleSwap()
end

function M:EnablePhoenix() spawn() end

function M:RefreshPhoenix()
    if not spawned then return end
    for _, key in ipairs(M.KEYS) do placeKey(key) end
    parkBlizzard()
    self:RefreshExtras()
    for _, key in ipairs(M.KEYS) do resync(key) end
end

---------------------------------------------------------------- Test casts
local function samples(key, i)
    local icons = ns.modules.UnitFrames and ns.modules.UnitFrames.SAMPLE_ICONS or {}
    local me = UnitName("player") or "Phoenix"
    local list = {
        player = { kind = "cast", name = L.PREVIEW_SPELL_CAST, icon = icons.fireball, total = 2.5, latency = 0.08 },
        target = { kind = "cast", name = L.PREVIEW_SPELL_CAST, icon = icons.bolt, total = 3, kick = 0.45, target = me,
                   important = true, targeted = true, ending = "interrupted" },
        focus = { kind = "channel", name = L.PREVIEW_SPELL_CHANNEL, icon = icons.storm, total = 4, locked = true },
        pet = { kind = "channel", name = L.PREVIEW_SPELL_CHANNEL, icon = icons.flame, total = 3 },
        boss = ({ { kind = "empower", name = L.PREVIEW_SPELL_EMPOWER, icon = icons.bomb, total = 3.2,
                    stages = { 0.25, 0.25, 0.25, 0.25 } },
                  { kind = "cast", name = L.PREVIEW_SPELL_LOCKED, icon = icons.sentry, total = 2.8, locked = true },
                  { kind = "channel", name = L.PREVIEW_SPELL_CHANNEL, icon = icons.storm, total = 3.5, kick = 0.3 } })[(i - 1) % 3 + 1],
        arena = ({ { kind = "cast", name = L.PREVIEW_SPELL_CAST, icon = icons.pain, total = 1.8, kick = 0.6,
                     ending = "interrupted" },
                   { kind = "channel", name = L.PREVIEW_SPELL_CHANNEL, icon = icons.shield, total = 3,
                     targeted = true } })[(i - 1) % 2 + 1],
    }
    local s = list[key] or list.player
    local copy = {}
    for k, v in pairs(s) do copy[k] = v end
    copy.loop = true
    copy.elapsed = (i - 1) * 0.35
    return copy
end
M.Samples = samples

function M:ShowPhoenixTest(show)
    if not spawned then return show and false or true end
    eachBar(function(f, key)
        if show and self:Bar(key).enabled then
            self:StartSample(f, samples(key, f.index))
        elseif f.sample then
            self:StopSample(f)
            if not show then self:ShowCast(f) end
        end
    end)
    self:TestExtras(show)
    return true
end
