local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Wisdom, review gap: SimulationCraft export. Builds the profile text SimC
-- reads (character, spec, talents, equipped gear with bonus IDs, enchants and
-- gems, optionally bag gear as commented lines) and shows it in Phoenix's
-- copy dialog. Paste it into SimulationCraft or Raidbots. Read-only: nothing
-- is sent anywhere.
local _, ns = ...
local Schema, Secret = PUI.Schema, PUI.Secret
local OWNER = "Wisdom"
local S = { s = { simc = true, simcBags = false } }
ns.SimC = S
if PUI.Wisdom then PUI.Wisdom.SimC = S end
local s = S.s

S.SLOTS = { { 1, "head" }, { 2, "neck" }, { 3, "shoulder" }, { 15, "back" }, { 5, "chest" }, { 4, "shirt" }, { 19, "tabard" },
  { 9, "wrist" }, { 10, "hands" }, { 6, "waist" }, { 7, "legs" }, { 8, "feet" }, { 11, "finger1" }, { 12, "finger2" },
  { 13, "trinket1" }, { 14, "trinket2" }, { 16, "main_hand" }, { 17, "off_hand" } }
S.EQUIP_SLOT = { INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_CLOAK = "back",
  INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands", INVTYPE_WAIST = "waist",
  INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet", INVTYPE_FINGER = "finger1", INVTYPE_TRINKET = "trinket1",
  INVTYPE_WEAPON = "main_hand", INVTYPE_2HWEAPON = "main_hand", INVTYPE_WEAPONMAINHAND = "main_hand", INVTYPE_RANGED = "main_hand",
  INVTYPE_RANGEDRIGHT = "main_hand", INVTYPE_WEAPONOFFHAND = "off_hand", INVTYPE_HOLDABLE = "off_hand", INVTYPE_SHIELD = "off_hand" }

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
local function token(text) return (tostring(text or ""):lower():gsub("[%s%-']", "_"):gsub("[^%w_]", "")) end
S.Token = token

-- ItemString(link) -> ",id=1,bonus_id=2/3,enchant_id=4,gem_id=5/6" (nil for a bad link)
function S.ItemString(link)
  if type(link) ~= "string" or not plain(link) then return nil end
  local body = link:match("item:([%-%d:]+)")
  if not body then return nil end
  local f = {}
  for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
  local id = tonumber(f[1])
  if not id then return nil end
  local out = { ",id=" .. id }
  local enchant = tonumber(f[2])
  local gems = {}
  for i = 3, 6 do local g = tonumber(f[i]); if g and g > 0 then gems[#gems + 1] = g end end
  local nb = tonumber(f[13]) or 0
  local bonus = {}
  for i = 1, nb do local b = tonumber(f[13 + i]); if b then bonus[#bonus + 1] = b end end
  if #bonus > 0 then out[#out + 1] = ",bonus_id=" .. table.concat(bonus, "/") end
  if enchant and enchant > 0 then out[#out + 1] = ",enchant_id=" .. enchant end
  if #gems > 0 then out[#out + 1] = ",gem_id=" .. table.concat(gems, "/") end
  return table.concat(out)
end

function S.Talents()
  local id = C_ClassTalents.GetActiveConfigID()
  if type(id) ~= "number" then return nil end
  local str = C_Traits.GenerateImportString(id)
  return plain(str) and type(str) == "string" and str ~= "" and str or nil
end

-- Build() -> profile text
function S.Build()
  local name = UnitName("player")
  local _, class = UnitClass("player")
  local _, race = UnitRace("player")
  local lines = { "# Phoenix UI SimulationCraft export" }
  lines[#lines + 1] = string.format('%s="%s"', token(class), plain(name) and name or "Player")
  lines[#lines + 1] = "level=" .. tostring(UnitLevel("player"))
  lines[#lines + 1] = "race=" .. token(race)
  lines[#lines + 1] = "region=" .. token(GetCurrentRegionName and GetCurrentRegionName() or "us")
  lines[#lines + 1] = "server=" .. token(GetNormalizedRealmName() or "")
  local spec = C_SpecializationInfo.GetSpecialization()
  if type(spec) == "number" and spec > 0 then
    local _, specName = C_SpecializationInfo.GetSpecializationInfo(spec)
    if plain(specName) and specName then lines[#lines + 1] = "spec=" .. token(specName) end
  end
  local talents = S.Talents()
  if talents then lines[#lines + 1] = "talents=" .. talents end
  lines[#lines + 1] = ""
  for _, slot in ipairs(S.SLOTS) do
    local str = S.ItemString(GetInventoryItemLink("player", slot[1]))
    if str then lines[#lines + 1] = slot[2] .. "=" .. str end
  end
  if s.simcBags then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "### Gear from bags"
    for bag = 0, 4 do
      for i = 1, C_Container.GetContainerNumSlots(bag) or 0 do
        local link = C_Container.GetContainerItemLink(bag, i)
        local equip = link and select(9, C_Item.GetItemInfo(link))
        local slot = equip and S.EQUIP_SLOT[equip]
        local str = slot and S.ItemString(link)
        if str then lines[#lines + 1] = "# " .. slot .. "=" .. str end
      end
    end
  end
  return table.concat(lines, "\n")
end

function S.Show()
  local text = S.Build()
  PUI.Dialogs:Copy("SimulationCraft export", text, "Ctrl+C, then paste into SimulationCraft or Raidbots.")
  return text
end

PUI.Slash:Register("simc", function()
  if not s.simc then return PUI.Slash.Print("SimC export is off (Wisdom page).") end
  S.Show()
end, "copy your character as a SimulationCraft profile")

local function key(name, def)
  def.owner = OWNER
  def.apply = function(v) s[name] = v end
  Schema:Register("wisdom." .. name, def)
  s[name] = Schema:Get("wisdom." .. name)
end
key("simc", { type = "toggle", default = true, mode = "simple", label = "SimC export",
  tooltip = "/pui simc opens your character as a SimulationCraft profile, ready to copy into SimulationCraft or Raidbots.", searchTags = { "simc", "simulationcraft", "raidbots" } })
key("simcBags", { type = "toggle", default = false, mode = "advanced", label = "SimC export includes bag gear",
  tooltip = "Adds gear from your bags as commented lines, so Raidbots Top Gear can compare it." })
