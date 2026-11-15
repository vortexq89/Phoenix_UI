local _, ns = ...
local Secret, U = ns.Secret, ns.Util
local M = ns.modules.Automation

--[[ Auto summon pet (EllesmereUI Forever Essentials reference; both clients). When the game takes your
    companion away (a loading screen, death, a flight, a vehicle), Phoenix brings one back a moment later:
    a random favourite (any random pet while you have none) or the pet you had out last. A pet you put away
    yourself stays away until you summon one again: the journal's summon / dismiss calls are read from
    post-hooks, and a pet that vanishes while nothing took it is counted as put away too.
    C_PetJournal summons are #nocombat: never in combat, and never while dead, mounted, flying, on a taxi,
    in a vehicle, stealthed, casting, in a pet battle, or in an instance (dungeon, raid, battleground, arena). ]]

local OWNER = {}
local DELAY = 2      -- seconds after a trigger: a load, landing or resurrection settles first
local TAKEN = 4      -- seconds a removal cause (load, death, taxi, vehicle) explains a vanished pet
local ours = false   -- our own summon call is running (the hooks skip it)
local takenAt = 0    -- when the game last had a reason to take the pet
local hadPet = false
local queued = false

local function char()
    local g = M.global
    g.pets = type(g.pets) == "table" and g.pets or {}
    local key = U.PlayerKey()
    g.pets[key] = type(g.pets[key]) == "table" and g.pets[key] or {}
    return g.pets[key]
end

local function summoned()
    local guid = C_PetJournal.GetSummonedPetGUID()
    if Secret.IsSecret(guid) then return nil end
    return guid
end

-- Why not now: nil when a pet may be summoned, else a short reason (tests read it).
function M.PetBlocked()
    if InCombatLockdown() or UnitAffectingCombat("player") then return "combat" end
    if UnitIsDeadOrGhost("player") then return "dead" end
    if IsMounted() or IsFlying() or UnitOnTaxi("player") or UnitInVehicle("player") then return "moving" end
    if IsStealthed() then return "stealth" end
    if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then return "petbattle" end
    local inside, kind = IsInInstance()
    if inside and kind ~= "none" and kind ~= "scenario" then return "instance" end
    local casting, channel = UnitCastingInfo("player"), UnitChannelInfo("player")
    if Secret.IsSecret(casting) or Secret.IsSecret(channel) then return "casting" end -- never compared
    if casting ~= nil or channel ~= nil then return "casting" end
    return nil
end

-- The call to make: "guid", guid | "random", favouritesOnly | nil.
function M.PetChoice(mode, last, summonable, hasFavourites)
    if mode == "last" and type(last) == "string" and summonable(last) then return "guid", last end
    return "random", hasFavourites and true or false
end

function M:SummonPet()
    if not (self:IsEnabled() and self.db.petSummon) then return false end
    local c = char()
    if c.dismissed or summoned() or M.PetBlocked() then return false end
    local how, arg = M.PetChoice(self.db.petMode, c.last, function(guid)
        return C_PetJournal.PetIsSummonable(guid) and true or false
    end, C_PetJournal.HasFavoritePets())
    ours = true
    local ok = pcall(function()
        if how == "guid" then C_PetJournal.SummonPetByGUID(arg) else C_PetJournal.SummonRandomPet(arg) end
    end)
    ours = false
    return ok
end

local function queue()
    if queued or not (M:IsEnabled() and M.db.petSummon) then return end
    queued = true
    C_Timer.After(DELAY, function()
        queued = false
        ns.SafeCall(M.SummonPet, M)
    end)
end

local function taken() takenAt = GetTime(); queue() end

-- The pet list changed: remember the pet you have out, or count a pet that vanished for no reason as put away.
function M.PetChanged()
    local guid = summoned()
    local c = char()
    if guid then
        c.last, c.dismissed = guid, nil
    elseif hadPet and not ours and GetTime() - takenAt > TAKEN and not UnitIsDeadOrGhost("player")
        and not UnitOnTaxi("player") and not UnitInVehicle("player") then
        c.dismissed = true
    end
    hadPet = guid ~= nil
end

-- Your own journal calls (the Summon / Dismiss button, a macro): put away or summoned by you.
local function byYou(dismiss)
    if ours then return end
    C_Timer.After(0.5, function()
        local c = char()
        if dismiss or not summoned() then c.dismissed = true else c.dismissed, c.last = nil, summoned() end
    end)
end

function M:SetupPetSummon()
    if self.petHooked or not C_PetJournal then return end
    self.petHooked = true
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", function() byYou(false) end)
    hooksecurefunc(C_PetJournal, "SummonRandomPet", function() byYou(false) end)
    if C_PetJournal.DismissSummonedPet then hooksecurefunc(C_PetJournal, "DismissSummonedPet", function() byYou(true) end) end
    if type(DismissCompanion) == "function" then hooksecurefunc("DismissCompanion", function() byYou(true) end) end
    ns.Events:On("COMPANION_UPDATE", OWNER, function(_, _, kind)
        if kind == nil or kind == "CRITTER" then ns.SafeCall(M.PetChanged) end
    end)
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_DEAD" }) do
        ns.Events:On(e, OWNER, taken)
    end
    ns.Events:On("UNIT_ENTERED_VEHICLE", OWNER, function(_, _, unit) if unit == "player" then taken() end end)
    ns.Events:On("UNIT_EXITED_VEHICLE", OWNER, function(_, _, unit) if unit == "player" then taken() end end)
    -- each of these may take the pet (or end what kept it away): note the moment, then try again shortly
    for _, e in ipairs({ "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST", "PLAYER_REGEN_ENABLED",
        "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_STEALTH", "ZONE_CHANGED_NEW_AREA" }) do
        ns.Events:On(e, OWNER, taken)
    end
end
