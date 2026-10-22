local _, ns = ...

--[[ ns.flavor: which game this client is. Phoenix ships one code base for two games that share Mainline's UI
    architecture (docs/research/wow-forever.md):
      "retail"  — World of Warcraft: Midnight (Interface 120105, Phoenix_UI.toc)
      "forever" — WoW Forever (Interface 16001, game type "forever"/"camelot", Phoenix_UI_Forever.toc)
    The client's own interface number decides: it is always plain and set before any addon code runs, while
    WOW_PROJECT_ID read the same as Mainline's on early Forever builds.

    Features are what differs, not flavours: a module or an option row names the feature it needs
    (`feature = "mythicplus"`) and ns:Supports(feature) answers per client. Content features are fixed per
    flavour (Forever has no Mythic+, Great Vault or SimulationCraft support); Blizzard systems that a client
    may or may not run ask the game itself (C_EncounterTimeline.IsFeatureAvailable). ]]
local INTERFACE = select(4, GetBuildInfo())
local FOREVER = type(INTERFACE) == "number" and INTERFACE >= 16000 and INTERFACE < 20000

ns.flavor = FOREVER and "forever" or "retail"
ns.interface = INTERFACE
ns.gameName = FOREVER and "WoW Forever" or "World of Warcraft" -- product names, the same in every locale

-- The game's own "is this system on this client" check; a missing API reads as available (older retail).
local function available(api)
    return function()
        if not (api and api.IsFeatureAvailable) then return true end
        local ok, yes = pcall(api.IsFeatureAvailable)
        return not ok or yes ~= false
    end
end

ns.FEATURES = {
    -- Keystones, ratings and the Challenge Mode timer (Blizzard_ChallengesUI loads on "standard, mists" only).
    mythicplus = { retail = true },
    -- Great Vault progress on Home (no weekly chest in Forever's level-60 Azeroth).
    vault = { retail = true },
    -- SimulationCraft models the current retail expansion only.
    sim = { retail = true },
    -- Skyriding (bonus bar 5 paging on bar 1): Forever's Azeroth has no dragonriding.
    skyriding = { retail = true },
    -- Swing timer: PLAYER_SWING and C_SwingTimer exist on WoW Forever only (Blizzard_SwingTimer).
    swingTimer = { forever = true },
    -- GCD bar: the Global Cooldown spell (61304) is not in Forever's spell table.
    gcdBar = { retail = true },
    -- Cooldown Manager reminders for flasks, food, augment runes and raid buffs: the aura IDs are retail's.
    cdmReminders = { retail = true },
    -- Minimap crafting order indicator: Forever's minimap indicator template has no CraftingOrderFrame.
    craftingOrders = { retail = true },
    -- World map coordinates: Forever's world map already shows the player's (WorldMapFrame PlayerCoords).
    worldMapCoords = { retail = true },
    -- Mythic raids (20 players, groups 1-4): Forever's raids have no Mythic difficulty.
    mythicRaid = { retail = true },
    -- Boss timeline and warnings: Blizzard_EncounterTimeline / _EncounterWarnings load on "standard" only.
    encounterTimeline = available(C_EncounterTimeline),
    encounterWarnings = available(C_EncounterWarnings),
}
-- Choosing a specialization (and so per-spec profiles): WoW Forever can switch it off per class.
-- C_SpecializationInfo.IsSpecSelectionEnabled only exists on Forever 1.60.1 (absent on retail 12.1.5).
ns.FEATURES.specSelection = function()
    local api = C_SpecializationInfo
    local check = api and api.IsSpecSelectionEnabled -- luacheck: ignore 143 (Forever-only API)
    local _, _, classID = UnitClass("player")
    if not (check and classID) then return true end
    local ok, yes = pcall(check, classID)
    return not ok or yes ~= false
end
-- The game's master "boss warnings" switch covers both.
ns.FEATURES.encounterAlerts = function()
    return ns:Supports("encounterTimeline") or ns:Supports("encounterWarnings")
end

-- True when `feature` works on this client; "!feature" is true where it does not (a row that replaces another).
-- Unknown names are supported (a typo must never hide a page).
function ns:Supports(feature)
    if feature == nil then return true end
    if feature:sub(1, 1) == "!" then return not ns:Supports(feature:sub(2)) end
    local rule = ns.FEATURES[feature]
    if rule == nil then return true end
    if type(rule) == "function" then return rule() and true or false end
    return rule[ns.flavor] == true
end

-- Drops the schema rows whose feature this client lacks. A `tab` row carrying a feature takes its whole tab
-- with it; cogs are filtered too. The list (and any row) is returned as is when nothing is dropped, so rows
-- keep their identity; otherwise a new list or row copy is made (schemas are shared, never edited in place).
function ns:FilterSchema(list)
    local out, skipTab, changed = {}, false, false
    for _, item in ipairs(list) do
        if item.type == "tab" then skipTab = not ns:Supports(item.feature) end
        if skipTab or not ns:Supports(item.feature) then
            changed = true
        else
            if type(item.cog) == "table" then
                local cog = ns:FilterSchema(item.cog)
                if cog ~= item.cog then
                    local copy = {}
                    for k, v in pairs(item) do copy[k] = v end
                    copy.cog, item, changed = cog, copy, true
                end
            end
            out[#out + 1] = item
        end
    end
    return changed and out or list
end
