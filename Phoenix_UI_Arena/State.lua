local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Arena state (plan 5.21 "Arena", 1.O "Arena match timer, dampening,
-- Shadowsight", "DR display"): pure, unit-tested pieces the frames draw from.
--  * opponent lifecycle: prep (spec only) -> seen -> unseen (stealthed or out of
--    sight) -> destroyed (left) -> cleared; a stale enemy keeps a greyed frame.
--  * racial and trinket state machine: some racials share a cooldown with the
--    PvP trinket. When one is used, the other is locked for the shared time
--    unless its own cooldown is already longer. Only plain spell IDs are read;
--    a hidden (secret) spell ID is skipped, never compared.
-- No combat log (closed in Midnight): trinket times come from the game
-- (C_PvP.GetArenaCrowdControlInfo) and racials from UNIT_SPELLCAST_SUCCEEDED.
local _, ns = ...
local Secret = PUI.Secret
local ST = { units = {} }
ns.State = ST

ST.UNITS = { "arena1", "arena2", "arena3", "arena4", "arena5" }

-- Racials with their own cooldown and the time they lock (and are locked by)
-- the PvP trinket. Original data table (spell ID -> race, cd, shared seconds).
ST.RACIALS = {
  [59752] = { race = "Human", cd = 180, shared = 90 },        -- Will to Survive
  [7744] = { race = "Scourge", cd = 120, shared = 30 },       -- Will of the Forsaken
  [20594] = { race = "Dwarf", cd = 120, shared = 30 },        -- Stoneform
  [20589] = { race = "Gnome", cd = 60, shared = 0 },          -- Escape Artist
  [58984] = { race = "NightElf", cd = 120, shared = 0 },      -- Shadowmeld
  [20549] = { race = "Tauren", cd = 90, shared = 0 },         -- War Stomp
  [107079] = { race = "Pandaren", cd = 120, shared = 0 },     -- Quaking Palm
  [265221] = { race = "DarkIronDwarf", cd = 120, shared = 30 }, -- Fireblood
  [69070] = { race = "Goblin", cd = 90, shared = 0 },         -- Rocket Jump
  [256948] = { race = "VoidElf", cd = 180, shared = 0 },      -- Spatial Rift
  [312411] = { race = "Vulpera", cd = 90, shared = 0 },       -- Bag of Tricks
  [287712] = { race = "KulTiran", cd = 150, shared = 0 },     -- Haymaker
  [368970] = { race = "Dracthyr", cd = 90, shared = 0 },      -- Tail Swipe
  [436344] = { race = "EarthenDwarf", cd = 120, shared = 0 }, -- Azerite Surge
}
ST.TRINKET_CD = 120
-- One icon per race for the racial slot before the racial is seen.
ST.RACE_ICON = { Human = 136129, Scourge = 136187, Dwarf = 136225, Gnome = 132309, NightElf = 132089, Tauren = 132368,
  Pandaren = 572035, DarkIronDwarf = 1786406, Goblin = 370769, VoidElf = 1724004, Vulpera = 3193419, KulTiran = 1723987,
  Dracthyr = 4622488, EarthenDwarf = 5788303 }

function ST.Unit(unit)
  local u = ST.units[unit]
  if not u then
    u = { unit = unit, life = "none", racial = { ends = 0 }, trinket = { ends = 0 }, trinketUses = 0, dr = {}, drHistory = {} }
    ST.units[unit] = u
  end
  return u
end
function ST.Reset() wipe(ST.units) end

-- Lifecycle from ARENA_OPPONENT_UPDATE reasons (plain strings).
local LIFE = { seen = "seen", unseen = "unseen", destroyed = "left", cleared = "none" }
function ST.SetLife(unit, reason)
  local u = ST.Unit(unit)
  local life = LIFE[reason]
  if life then u.life = life end
  return u.life
end
function ST.Prep(unit, specID)
  local u = ST.Unit(unit)
  if u.life == "none" then u.life = "prep" end
  u.spec = specID
  return u
end

-- Trinket used (from the game's CC info, plain times) -> lock the racial.
function ST.TrinketUsed(unit, now, duration)
  local u = ST.Unit(unit)
  duration = duration or ST.TRINKET_CD
  u.trinket.ends = now + duration
  u.trinketUses = u.trinketUses + 1
  local r = u.racialInfo
  if r and r.shared > 0 then u.racial.ends = math.max(u.racial.ends, now + r.shared) end
  return u
end
-- Racial cast seen (spellID must be plain) -> own cooldown and the trinket lock.
function ST.RacialUsed(unit, spellID, now)
  if spellID == nil or Secret.IsSecret(spellID) then return nil end
  local r = ST.RACIALS[spellID]
  if not r then return nil end
  local u = ST.Unit(unit)
  u.racialInfo, u.racialSpell = r, spellID
  u.racial.ends = now + r.cd
  if r.shared > 0 then u.trinket.ends = math.max(u.trinket.ends, now + r.shared) end
  return u
end
function ST.Remaining(slot, now) return math.max(0, (slot.ends or 0) - now) end

-- Race seen on the frame (UnitRace English name, plain or skipped).
function ST.SetRace(unit, race)
  if race == nil or Secret.IsSecret(race) then return end
  local u = ST.Unit(unit)
  u.race = race
  if not u.racialInfo then
    for id, r in pairs(ST.RACIALS) do if r.race == race then u.racialInfo, u.racialSpell = r, id end end
  end
end
