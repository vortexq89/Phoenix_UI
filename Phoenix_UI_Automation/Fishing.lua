local _, ns = ...
local M = ns.modules.Automation

--[[ Fishing helper (EllesmereUI Forever Essentials reference; both clients). While you fish, the bobber's
    splash is easy to hear: Phoenix lifts the effects volume and lowers music and ambience for the cast, and
    turns auto loot on, then puts all four back the moment the channel ends (or after a /reload, from the saved
    copy). Only CVars are touched; nothing casts for you. The cast is recognised by name: a channel whose spell is
    called like your Fishing profession (GetProfessions' fishing slot, in the client's language). No IDs or data
    are shipped. ]]

local OWNER = {}
local CVARS = { "Sound_SFXVolume", "Sound_MusicVolume", "Sound_AmbienceVolume", "autoLootDefault" }

-- The CVar values for a cast from your settings (pure).
function M.FishingCVars(boost)
    return { Sound_SFXVolume = "1", Sound_MusicVolume = boost and "0" or nil, Sound_AmbienceVolume = boost and "0" or nil,
             autoLootDefault = "1" }
end

-- Your Fishing profession's name (the cast carries the same name), or nil without it.
local function fishingName()
    if type(GetProfessions) ~= "function" then return nil end
    local fishing = select(4, GetProfessions())
    if not fishing then return nil end
    local name = GetProfessionInfo(fishing)
    return type(name) == "string" and name ~= "" and name or nil
end

local function isFishing(spellID, nameOf, profession)
    if type(spellID) ~= "number" or ns.Secret.IsSecret(spellID) then return false end
    local want = profession or fishingName()
    local n = (nameOf or C_Spell.GetSpellName)(spellID)
    return want ~= nil and type(n) == "string" and n == want
end
M.IsFishingSpell = isFishing

local function restore()
    local saved = M.global and M.global.fishingSaved
    if not saved then return end
    for k, v in pairs(saved) do C_CVar.SetCVar(k, v) end
    M.global.fishingSaved = nil
end
M.RestoreFishing = restore

function M:StartFishing()
    if not self.db.fishing or self.global.fishingSaved then return end
    local saved = {}
    for _, k in ipairs(CVARS) do saved[k] = C_CVar.GetCVar(k) end
    self.global.fishingSaved = saved
    for k, v in pairs(M.FishingCVars(self.db.fishingQuiet)) do C_CVar.SetCVar(k, v) end
end

function M:SetupFishing()
    if self.fishingHooked then return end
    self.fishingHooked = true
    restore() -- a cast cut off by a /reload or crash
    ns.Events:OnUnit("UNIT_SPELLCAST_CHANNEL_START", OWNER, function(_, _, _, _, spellID)
        if M:IsEnabled() and isFishing(spellID) then M:StartFishing() end
    end, "player")
    ns.Events:OnUnit("UNIT_SPELLCAST_CHANNEL_STOP", OWNER, function() restore() end, "player")
end
